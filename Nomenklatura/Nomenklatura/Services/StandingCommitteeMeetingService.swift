//
//  StandingCommitteeMeetingService.swift
//  Nomenklatura
//
//  Service for managing Standing Committee meeting phase gameplay.
//  Generates agenda items from current game state, resolves votes,
//  and handles vote-of-no-confidence challenges.
//

import Foundation
import os.log

private let meetingLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "SCMeeting")

// MARK: - Standing Committee Meeting Service

@MainActor
final class StandingCommitteeMeetingService {
    static let shared = StandingCommitteeMeetingService()

    private init() {}

    // MARK: - Meeting Scheduling

    /// Check if a Standing Committee meeting should occur this turn
    func shouldHaveMeeting(game: Game) -> Bool {
        guard let committee = game.standingCommittee else { return false }

        let config = CampaignLoader.shared.getColdWarCampaign()
        let frequency = config.leadershipConfig?.meetingFrequency ?? 4
        let turnsSinceLastMeeting = game.turnNumber - committee.lastMeetingTurn

        // Crisis override: always meet if stability is critical
        if game.stability < 25 && turnsSinceLastMeeting >= 2 {
            return true
        }

        // Regular schedule
        return turnsSinceLastMeeting >= frequency
    }

    // MARK: - Agenda Generation

    /// Generate agenda items based on the current game state.
    /// This supplements any pending agenda already on the committee.
    func generateStateBasedAgenda(game: Game) -> [CommitteeAgendaItem] {
        var items: [CommitteeAgendaItem] = []
        let turn = game.turnNumber

        // Economic crisis -> budget/reform proposal
        // NOTE: treasury is a clamped 0-100 stat, so thresholds/effects use that scale.
        if game.treasury < 30 || game.industrialOutput < 30 {
            items.append(CommitteeAgendaItem(
                title: "Emergency Economic Measures",
                description: "The State Planning Commission reports critical shortfalls. Industrial output and treasury reserves demand urgent intervention from the Standing Committee.",
                category: .economic,
                priority: game.treasury < 15 ? .critical : .urgent,
                sponsorId: findEconomicSponsor(game: game),
                turnSubmitted: turn,
                effects: ["treasury": 15, "industrialOutput": 5, "popularSupport": -3]
            ))
        }

        // Food crisis
        if game.foodSupply < 35 {
            items.append(CommitteeAgendaItem(
                title: "Food Supply Emergency",
                description: "Collective farm output has fallen below acceptable levels. Rationing may be necessary. The Agricultural Ministry requests emergency procurement authority.",
                category: .economic,
                priority: .critical,
                sponsorId: findEconomicSponsor(game: game),
                turnSubmitted: turn,
                effects: ["foodSupply": 8, "treasury": -10, "popularSupport": -5]
            ))
        }

        // Military threat -> defense proposal
        if game.militaryLoyalty < 40 {
            items.append(CommitteeAgendaItem(
                title: "Military Readiness Review",
                description: "Reports of declining discipline and loyalty within the armed forces require committee attention. The General Staff requests increased funding and political commissar reinforcements.",
                category: .security,
                priority: .urgent,
                sponsorId: findMilitarySponsor(game: game),
                turnSubmitted: turn,
                effects: ["militaryLoyalty": 8, "treasury": -15]
            ))
        }

        // Low stability -> order restoration
        if game.stability < 40 {
            items.append(CommitteeAgendaItem(
                title: "Restoration of Public Order",
                description: "Unrest and dissatisfaction threaten the stability of the state. The Security Ministry proposes expanded surveillance and public reassurance campaigns.",
                category: .security,
                priority: game.stability < 25 ? .critical : .important,
                sponsorId: findSecuritySponsor(game: game),
                turnSubmitted: turn,
                effects: ["stability": 6, "popularSupport": -4]
            ))
        }

        // Low international standing -> diplomatic initiative
        if game.internationalStanding < 35 {
            items.append(CommitteeAgendaItem(
                title: "Diplomatic Offensive",
                description: "Our international position has weakened considerably. The Foreign Ministry proposes a new round of bilateral negotiations and cultural exchanges to restore our standing among nations.",
                category: .foreign,
                priority: .important,
                sponsorId: findDiplomaticSponsor(game: game),
                turnSubmitted: turn,
                effects: ["internationalStanding": 7, "treasury": -8]
            ))
        }

        // Low popular support -> populist measures
        if game.popularSupport < 35 {
            items.append(CommitteeAgendaItem(
                title: "Consumer Goods Initiative",
                description: "Public dissatisfaction is growing. The Council of Ministers proposes redirecting resources to consumer goods production to demonstrate the Party's commitment to the people's welfare.",
                category: .policy,
                priority: .important,
                sponsorId: nil,
                turnSubmitted: turn,
                effects: ["popularSupport": 8, "industrialOutput": -3, "treasury": -10]
            ))
        }

        // Low elite loyalty -> patronage/promotion measures
        if game.eliteLoyalty < 40 {
            items.append(CommitteeAgendaItem(
                title: "Cadre Rotation and Appointments",
                description: "Loyalty among the Party elite has declined. The Organizational Department proposes a rotation of key appointments to reinforce patronage networks and reward faithful service.",
                category: .personnel,
                priority: .important,
                sponsorId: findChairSponsor(game: game),
                turnSubmitted: turn,
                effects: ["eliteLoyalty": 7, "stability": -2]
            ))
        }

        // Limit to max 3 state-based items per meeting
        return Array(items.sorted { priorityValue($0.priority) > priorityValue($1.priority) }.prefix(3))
    }

    // MARK: - Player Actions

    /// Create a player-proposed agenda item
    func createPlayerProposal(
        title: String,
        description: String,
        category: CommitteeAgendaItem.AgendaCategory,
        effects: [String: Int],
        game: Game
    ) -> CommitteeAgendaItem {
        CommitteeAgendaItem(
            title: title,
            description: description,
            category: category,
            priority: .important,
            sponsorId: "player",
            turnSubmitted: game.turnNumber,
            effects: effects
        )
    }

    // MARK: - Vote Resolution

    /// Resolve a vote on an agenda item, returning the result.
    /// The player's influence is weighted by powerConsolidationScore.
    func resolveVote(
        item: CommitteeAgendaItem,
        playerVote: PlayerVote,
        game: Game
    ) -> SCMeetingVoteResult {
        guard let committee = game.standingCommittee else {
            return SCMeetingVoteResult(
                item: item,
                passed: false,
                votesFor: [],
                votesAgainst: [],
                abstentions: [],
                playerInfluenceApplied: false
            )
        }

        let config = CampaignLoader.shared.getColdWarCampaign()
        let leadershipConfig = config.leadershipConfig ?? LeadershipConfig()

        // Get all SC members as characters
        let members = committee.memberIds.compactMap { memberId in
            game.characters.first { $0.templateId == memberId && $0.isAlive }
        }

        var votesFor: [SCMemberVote] = []
        var votesAgainst: [SCMemberVote] = []
        var abstentions: [SCMemberVote] = []

        // RNG snapshot for ceremonial-vote roll. Threaded through game.rng
        // so seeded reproductions stay deterministic.
        var rng = game.rng
        defer { game.rng = rng }

        // Determine each member's vote
        for member in members {
            var vote = determineMemberVote(
                member: member,
                item: item,
                playerVote: playerVote,
                committee: committee,
                game: game
            )

            // CEREMONIAL ROLE: A character co-opted via "Promote Sideways"
            // still attends meetings but their vote barely counts. Multiplier
            // is 0.3 — modeled as a 70% chance their actual preference is
            // downgraded to an abstention ("going through the motions").
            // The remaining 30% of the time their vote registers normally.
            // Net effect: ceremonial members contribute ~0.3 vote weight.
            if member.hasCeremonialRole(in: game) && vote != .abstain {
                if Double.random(in: 0..<1, using: &rng) >= 0.3 {
                    vote = .abstain
                }
            }

            // CANDIDATE MEMBERS: per SCRank, candidate votes are advisory —
            // they attend and speak, but only full members (and the chair)
            // carry weight in the tally. Record their preference as an
            // abstention so the UI shows attendance without letting a
            // probationary member swing the outcome.
            let isWeightedVoter = committee.fullMemberIds.contains(member.templateId)
                || member.templateId == committee.chairId
            if !isWeightedVoter {
                vote = .abstain
            }

            let memberVote = SCMemberVote(
                characterId: member.templateId,
                characterName: member.name,
                factionId: member.factionId,
                isChair: member.templateId == committee.chairId
            )

            switch vote {
            case .for:
                votesFor.append(memberVote)
            case .against:
                votesAgainst.append(memberVote)
            case .abstain:
                abstentions.append(memberVote)
            }
        }

        // Apply player's vote weight (influenced by chairmanship tier)
        var playerInfluenceApplied = false
        if committee.playerIsOnCommittee {
            let playerMemberVote = SCMemberVote(
                characterId: "player",
                characterName: "You",
                factionId: game.playerFactionId,
                isChair: committee.playerIsChair
            )

            // Player's effective vote weight scales with chairmanship tier — the
            // mechanical face of committee deference: a Compromise Chairman gets a
            // single vote the others can outvote; a Supreme Chairman's vote is
            // ceremonial-strength. Floored by the leadership config's base weight so
            // the existing GS double-vote is never reduced. (Tiers 2026-06.)
            let baseWeight = max(1, leadershipConfig.gsVoteWeight)
            let totalWeight = max(baseWeight, game.chairmanshipTier.voteWeight)

            for _ in 0..<totalWeight {
                switch playerVote {
                case .for:
                    votesFor.append(playerMemberVote)
                case .against:
                    votesAgainst.append(playerMemberVote)
                case .abstain:
                    abstentions.append(playerMemberVote)
                }
            }

            playerInfluenceApplied = totalWeight > 1
        }

        let passed = votesFor.count > votesAgainst.count

        return SCMeetingVoteResult(
            item: item,
            passed: passed,
            votesFor: votesFor,
            votesAgainst: votesAgainst,
            abstentions: abstentions,
            playerInfluenceApplied: playerInfluenceApplied
        )
    }

    /// Apply the effects of a passed agenda item to the game
    func applyItemEffects(item: CommitteeAgendaItem, game: Game) {
        for (stat, change) in item.effects {
            game.applyStat(stat, change: change)
        }
    }

    // MARK: - Vote of No Confidence

    /// Check if hostile SC members will propose a vote of no confidence.
    /// This triggers when enough members have low disposition toward the player.
    func checkNoConfidenceRisk(game: Game) -> NoConfidenceCheck {
        guard let committee = game.standingCommittee,
              committee.playerIsOnCommittee else {
            return NoConfidenceCheck(isTriggered: false, hostileMembers: [], hostileCount: 0, threshold: 0)
        }

        let members = committee.memberIds.compactMap { memberId in
            game.characters.first { $0.templateId == memberId && $0.isAlive }
        }

        // Count hostile members (disposition < 25 toward player)
        let hostileMembers = members.filter { $0.disposition < 25 }
        let votingMembers = members.filter { committee.fullMemberIds.contains($0.templateId) }
        let threshold = (votingMembers.count / 2) + 1

        // Need a majority of full members hostile to trigger
        let hostileFullMembers = hostileMembers.filter { committee.fullMemberIds.contains($0.templateId) }

        return NoConfidenceCheck(
            isTriggered: hostileFullMembers.count >= threshold,
            hostileMembers: hostileMembers,
            hostileCount: hostileFullMembers.count,
            threshold: threshold
        )
    }

    /// Resolve a vote of no confidence against the player
    func resolveNoConfidenceVote(game: Game) -> NoConfidenceResult {
        var rng = game.rng
        defer { game.rng = rng }
        guard let committee = game.standingCommittee else {
            return NoConfidenceResult(passed: false, votesFor: 0, votesAgainst: 0, narrative: "")
        }

        let members = committee.fullMemberIds.compactMap { memberId in
            game.characters.first { $0.templateId == memberId && $0.isAlive }
        }

        var votesForRemoval = 0
        var votesAgainstRemoval = 0

        for member in members {
            let dispositionToPlayer = member.disposition

            // Hostile members vote for removal
            // Loyal members defend player
            // Paranoid/cautious members may abstain or follow the majority
            var voteScore = dispositionToPlayer

            // Loyal personality bonus for player
            voteScore += member.personalityLoyal / 4

            // Same faction as player = more likely to defend
            if member.factionId == game.playerFactionId {
                voteScore += 20
            }

            // Ambitious members may see opportunity in removal
            if member.personalityAmbitious > 70 {
                voteScore -= 15
            }

            // Random variance
            voteScore += Int.random(in: -10...10, using: &rng)

            if voteScore >= 50 {
                votesAgainstRemoval += 1  // Defend player
            } else {
                votesForRemoval += 1      // Remove player
            }
        }

        let passed = votesForRemoval > votesAgainstRemoval

        let narrative: String
        if passed {
            narrative = "The Standing Committee has voted to remove you from your position. The vote was \(votesForRemoval) to \(votesAgainstRemoval). Your allies were insufficient to prevent the motion."
        } else {
            narrative = "The vote of no confidence failed \(votesForRemoval) to \(votesAgainstRemoval). Your position is secure for now, but the challenge has exposed dangerous fractures within the Committee."
        }

        return NoConfidenceResult(
            passed: passed,
            votesFor: votesForRemoval,
            votesAgainst: votesAgainstRemoval,
            narrative: narrative
        )
    }

    // MARK: - Meeting Completion

    /// Record the meeting results and update committee state
    func completeMeeting(results: [SCMeetingVoteResult], game: Game) {
        guard let committee = game.standingCommittee else { return }

        // Record the meeting
        let atmosphere = determineAtmosphere(results: results, game: game)
        let meeting = CommitteeMeeting(
            turnHeld: game.turnNumber,
            attendeeIds: committee.memberIds,
            itemsDiscussed: results.map { $0.item.id },
            decisionsReached: results.map { result in
                let outcome: CommitteeDecision.DecisionOutcome = result.passed ? .approved : .rejected
                return CommitteeDecision(
                    agendaItemId: result.item.id,
                    outcome: outcome,
                    votingRecord: VotingRecord(
                        votesFor: result.votesFor.count,
                        votesAgainst: result.votesAgainst.count,
                        abstentions: result.abstentions.count,
                        isUnanimous: result.votesAgainst.isEmpty && result.abstentions.isEmpty
                    ),
                    dissenterIds: result.votesAgainst.map { $0.characterId },
                    narrativeSummary: result.passed ? "Motion carried." : "Motion defeated."
                )
            },
            atmosphere: atmosphere
        )

        var minutes = committee.meetingMinutes
        minutes.append(meeting)
        committee.meetingMinutes = minutes

        committee.lastMeetingTurn = game.turnNumber

        // Clear pending agenda
        committee.pendingAgenda = []

        // Apply effects of passed items
        for result in results where result.passed {
            applyItemEffects(item: result.item, game: game)
            StandingCommitteeService.shared.resolveLawChangeIfNeeded(item: result.item, passed: true, game: game)
        }

        // Update faction balance
        StandingCommitteeService.shared.updateFactionBalance(committee: committee, game: game)

        meetingLogger.info("SC meeting completed: \(results.count) items, \(results.filter { $0.passed }.count) passed")
    }

    // MARK: - Private Helpers

    private func determineMemberVote(
        member: GameCharacter,
        item: CommitteeAgendaItem,
        playerVote: PlayerVote,
        committee: StandingCommittee,
        game: Game
    ) -> PlayerVote {
        var rng = game.rng
        defer { game.rng = rng }
        var voteScore = 50  // Neutral starting point

        // Disposition toward player affects alignment with player's vote
        // Members who dislike the player actively oppose their preferred outcome
        let dispositionBonus = (member.disposition - 50) / 2
        switch playerVote {
        case .for:
            voteScore += dispositionBonus
        case .against:
            voteScore -= dispositionBonus
        case .abstain:
            break
        }

        // Same faction as sponsor? Strong support
        if let sponsorId = item.sponsorId,
           let sponsor = game.characters.first(where: { $0.templateId == sponsorId }),
           sponsor.factionId == member.factionId {
            voteScore += 20
        }

        // OPPOSING faction to sponsor? Push against
        if let sponsorId = item.sponsorId,
           let sponsor = game.characters.first(where: { $0.templateId == sponsorId }),
           sponsor.factionId != member.factionId && sponsor.factionId != nil {
            voteScore -= 10  // Inter-faction rivalry creates opposition
        }

        // Category alignment with personality — also creates opposition for misaligned members
        switch item.category {
        case .security:
            voteScore += (member.personalityRuthless - 50) / 4  // Can go negative if not ruthless
        case .personnel:
            voteScore += (member.personalityAmbitious - 50) / 4
        case .economic:
            voteScore += (member.personalityCompetent - 50) / 4
        case .ideological:
            voteScore += (member.personalityLoyal - 50) / 4
        default:
            break
        }

        // Ambitious members may oppose to position themselves as alternatives
        // audit-tuning: ambitious members should be pragmatic, not reflexively against the chair
        if member.personalityAmbitious > 65 && member.disposition < 30 {
            voteScore -= 12
        }

        // Loyal personality: follow the chair's lead (only if chair voted)
        if member.templateId != committee.chairId && playerVote != .abstain {
            let loyaltyInfluence = max(0, member.personalityLoyal - 40) / 5
            switch playerVote {
            case .for: voteScore += loyaltyInfluence
            case .against: voteScore -= loyaltyInfluence  // Follow chair either way
            case .abstain: break
            }
        }

        // Paranoid members hedge — wider abstention range
        if member.personalityParanoid > 60 {
            voteScore = max(30, min(70, voteScore))
        }

        // Grudge against player: oppose their vote
        if member.grudgeLevel < -40 {
            let grudgePenalty = abs(member.grudgeLevel) / 5
            switch playerVote {
            case .for: voteScore -= grudgePenalty
            case .against: voteScore += grudgePenalty
            case .abstain: break
            }
        }

        // Random variance — wider for early game uncertainty
        // audit-tuning: prior variance was so wide outcomes felt chaotic rather than strategic
        let variance = game.turnNumber < 5 ? Int.random(in: -8...8, using: &rng) : Int.random(in: -6...6, using: &rng)
        voteScore += variance

        if voteScore > 55 {
            return .for
        } else if voteScore < 45 {
            return .against
        } else {
            return .abstain
        }
    }

    private func determineAtmosphere(results: [SCMeetingVoteResult], game: Game) -> CommitteeMeeting.MeetingAtmosphere {
        let rejectedCount = results.filter { !$0.passed }.count
        let totalDissent = results.reduce(0) { $0 + $1.votesAgainst.count }

        if game.stability < 30 || rejectedCount > results.count / 2 {
            return .confrontational
        } else if totalDissent > results.count * 2 || game.stability < 50 {
            return .tense
        } else if rejectedCount == 0 && totalDissent == 0 {
            return .harmonious
        }
        return .performative
    }

    private func priorityValue(_ priority: CommitteeAgendaItem.AgendaPriority) -> Int {
        switch priority {
        case .routine: return 1
        case .important: return 2
        case .urgent: return 3
        case .critical: return 4
        }
    }

    // MARK: - Sponsor Finders

    private func findEconomicSponsor(game: Game) -> String? {
        game.characters
            .filter { $0.isAlive && ($0.factionId == "reformists" || $0.factionId == "youth_league") }
            .max(by: { ($0.positionIndex ?? 0) < ($1.positionIndex ?? 0) })?
            .templateId
    }

    private func findMilitarySponsor(game: Game) -> String? {
        game.characters
            .filter { $0.isAlive && ($0.positionIndex ?? 0) >= 5 }
            .first(where: { $0.factionId == "old_guard" })?
            .templateId
    }

    private func findSecuritySponsor(game: Game) -> String? {
        game.characters
            .filter { $0.isAlive && ($0.positionIndex ?? 0) >= 5 }
            .first(where: { $0.personalityRuthless > 60 })?
            .templateId
    }

    private func findDiplomaticSponsor(game: Game) -> String? {
        game.characters
            .filter { $0.isAlive && ($0.positionIndex ?? 0) >= 5 }
            .first(where: { $0.factionId == "reformists" })?
            .templateId
    }

    private func findChairSponsor(game: Game) -> String? {
        game.standingCommittee?.chairId
    }
}

// MARK: - Meeting Result Types

enum PlayerVote: String {
    case `for`
    case against
    case abstain
}

struct SCMemberVote: Identifiable {
    let id = UUID()
    let characterId: String
    let characterName: String
    let factionId: String?
    let isChair: Bool
}

struct SCMeetingVoteResult: Identifiable {
    let id = UUID()
    let item: CommitteeAgendaItem
    let passed: Bool
    let votesFor: [SCMemberVote]
    let votesAgainst: [SCMemberVote]
    let abstentions: [SCMemberVote]
    let playerInfluenceApplied: Bool
}

struct NoConfidenceCheck {
    let isTriggered: Bool
    let hostileMembers: [GameCharacter]
    let hostileCount: Int
    let threshold: Int
}

struct NoConfidenceResult {
    let passed: Bool
    let votesFor: Int
    let votesAgainst: Int
    let narrative: String
}
