//
//  SCProposalGenerator.swift
//  Nomenklatura
//
//  Generates autonomous proposals from Standing Committee members based on
//  their goals, faction interests, and current game state. Creates a living
//  political simulation where NPCs actively shape policy.
//

import Foundation
import os.log

private let proposalLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "SCProposals")

// MARK: - SC Proposal Generator

@MainActor
struct SCProposalGenerator {

    // MARK: - Main Entry Point

    /// Generate proposals from all SC members for this turn
    /// Called from PoliticalAIService.processPoliticalActivity()
    static func generateProposals(game: Game) -> [SCProposalResult] {
        guard let committee = game.standingCommittee else { return [] }

        var results: [SCProposalResult] = []

        // Track titles used this turn to prevent duplicate proposals
        var usedTitlesThisTurn: Set<String> = Set(committee.pendingAgenda.map { $0.title })

        // Get player-submitted agenda items to detect overlap
        let playerAgendaCategories = committee.pendingAgenda
            .filter { $0.sponsorId == "player" || $0.sponsorId == nil }
            .map { $0.category }

        for memberId in committee.memberIds {
            guard let member = game.characters.first(where: { $0.templateId == memberId && $0.isAlive }),
                  shouldProposeThisTurn(member: member, committee: committee, game: game) else {
                continue
            }

            if let proposal = generateProposal(for: member, committee: committee, game: game, excludeTitles: usedTitlesThisTurn) {
                // Mark title as used for subsequent iterations
                usedTitlesThisTurn.insert(proposal.title)
                // Submit to committee agenda
                StandingCommitteeService.shared.submitAgendaItem(
                    to: committee,
                    title: proposal.title,
                    description: proposal.description,
                    category: proposal.category,
                    priority: proposal.priority,
                    sponsor: member,
                    game: game,
                    effects: proposal.effects
                )

                results.append(SCProposalResult(
                    sponsorId: member.templateId,
                    sponsorName: member.name,
                    proposal: proposal,
                    turnSubmitted: game.turnNumber
                ))

                // Check for overlap with player agenda items
                let hasOverlap = playerAgendaCategories.contains(proposal.category)

                // Log to journal so player is aware of committee activity
                JournalService.shared.onCommitteeProposal(
                    sponsor: member,
                    proposalTitle: proposal.title,
                    description: proposal.description,
                    isPlayerOverlap: hasOverlap,
                    game: game
                )

                proposalLogger.info("\(member.name) proposed: \(proposal.title) (overlap: \(hasOverlap))")
            }
        }

        // Ensure at least one proposal per turn for immersive committee activity
        if results.isEmpty && game.turnNumber > 2 {
            if let guaranteedProposal = generateGuaranteedProposal(committee: committee, game: game, excludeTitles: usedTitlesThisTurn) {
                results.append(guaranteedProposal)
            }
        }

        return results
    }

    // MARK: - Non-Proposal Political Actions

    /// Generate non-proposal political actions from SC members
    /// These include: attacks on colleagues, resignation threats, backroom deals, voting bloc formation
    /// Called from PoliticalAIService to supplement proposal generation with living political drama
    static func generateNonProposalActions(game: Game) -> [SCPoliticalAction] {
        guard let committee = game.standingCommittee else { return [] }

        var actions: [SCPoliticalAction] = []

        // Low base chance per turn (5%) - these are dramatic events
        guard Int.random(in: 1...100) <= 8 else { return [] }

        // Exclude ceremonial-role members from initiating dramatic moves.
        // A sidelined character isn't going to start coalition fights or
        // backroom deals — that's exactly the power we just stripped from
        // them. They can still appear as `target` (others can attack them)
        // but never as `initiator`.
        let members = committee.memberIds.compactMap { memberId in
            game.characters.first(where: { $0.templateId == memberId && $0.isActive })
        }.filter { !$0.hasCeremonialRole(in: game) }

        guard members.count >= 2 else { return [] }

        // Check for various non-proposal actions

        // 1. SC member attacks another member (based on grudges)
        if let attackAction = checkSCMemberAttack(members: members, game: game) {
            actions.append(attackAction)
        }

        // 2. Resignation threat (under pressure or frustrated)
        if let resignAction = checkResignationThreat(members: members, game: game) {
            actions.append(resignAction)
        }

        // 3. Voting bloc formation
        if let blocAction = checkVotingBlocFormation(members: members, game: game) {
            actions.append(blocAction)
        }

        // 4. Backroom deal (if player has high network)
        if game.network >= 50, let dealAction = checkBackroomDeal(members: members, game: game) {
            actions.append(dealAction)
        }

        // Limit to 1 action per turn
        return Array(actions.prefix(1))
    }

    /// Check if an SC member attacks another based on grudges
    private static func checkSCMemberAttack(members: [GameCharacter], game: Game) -> SCPoliticalAction? {
        // Find members with grudges against other SC members
        for attacker in members {
            for target in members where attacker.id != target.id {
                // Check if there's a hostile relationship
                if let relationship = game.npcRelationships.first(where: {
                    $0.sourceCharacterId == attacker.templateId &&
                    $0.targetCharacterId == target.templateId &&
                    $0.grudgeLevel >= 50
                }) {
                    // Ruthless attackers are more likely to strike
                    let attackChance = (attacker.personalityRuthless / 3) + (relationship.grudgeLevel / 4)
                    guard Int.random(in: 1...100) <= attackChance else { continue }

                    let attackTypes: [(String, String, SCVisibilityLevel)] = [
                        ("Confrontation in Committee",
                         "During a heated Standing Committee session, \(attacker.name) openly challenged \(target.name)'s competence, demanding an explanation for recent failures. The room fell silent as the two traded accusations.",
                         .public),
                        ("Public Criticism",
                         "\(attacker.name) delivered a pointed critique of \(target.name)'s department in the latest Politburo review, citing 'systematic failures' and 'inadequate leadership.' The attack caught many off guard.",
                         .public),
                        ("Investigation Request",
                         "Your sources report that \(attacker.name) has privately requested an investigation into \(target.name)'s conduct. The CCDI is reportedly considering the request.",
                         .intel),
                        ("Coalition Against",
                         "\(attacker.name) is quietly building a coalition of SC members opposed to \(target.name). Informal discussions suggest a coordinated effort to isolate them.",
                         .secret)
                    ]

                    guard let attack = attackTypes.randomElement() else { continue }

                    return SCPoliticalAction(
                        actionType: .scAttack,
                        headline: attack.0,
                        details: attack.1,
                        visibilityLevel: attack.2,
                        initiator: attacker,
                        target: target
                    )
                }
            }
        }
        return nil
    }

    /// Check if an SC member threatens resignation
    private static func checkResignationThreat(members: [GameCharacter], game: Game) -> SCPoliticalAction? {
        for member in members {
            // Conditions for resignation threat:
            // - Under investigation
            // - Very frustrated goals
            // - Low security need (feels threatened)
            // - OR principled opposition (high ideological commitment but losing faction)

            var threatChance = 0

            if member.currentStatus == .underInvestigation {
                threatChance += 15
            }

            if let goal = member.primaryGoal, goal.frustrationLevel > 80 {
                threatChance += 10
            }

            if member.npcNeeds.security < 20 {
                threatChance += 8
            }

            // Principled resignation (rare but dramatic)
            if member.npcNeeds.ideologicalCommitment > 80 {
                // Check if their faction is losing
                if let factionId = member.factionId,
                   let faction = game.factions.first(where: { $0.factionId == factionId }),
                   faction.power < 30 {
                    threatChance += 12
                }
            }

            guard threatChance > 0 && Int.random(in: 1...100) <= threatChance else { continue }

            let threatTypes: [(String, String, SCVisibilityLevel)] = [
                ("Resignation Threat",
                 "In a dramatic moment, \(member.name) threatened to resign from the Standing Committee, citing 'impossible conditions' and 'lack of support.' Whether genuine or tactical, the threat has sent ripples through the leadership.",
                 .public),
                ("Health Retirement Rumor",
                 "Whispers suggest \(member.name) is considering stepping down from the Standing Committee, citing health concerns. Some believe this is a tactical retreat; others sense genuine exhaustion.",
                 .rumor),
                ("Principled Stand",
                 "\(member.name) is reportedly preparing a statement of resignation in protest of current policies. Such an act would be unprecedented and deeply destabilizing.",
                 .secret)
            ]

            guard let threat = threatTypes.randomElement() else { continue }

            return SCPoliticalAction(
                actionType: .resignationThreat,
                headline: threat.0,
                details: threat.1,
                visibilityLevel: threat.2,
                initiator: member
            )
        }
        return nil
    }

    /// Check for voting bloc formation
    private static func checkVotingBlocFormation(members: [GameCharacter], game: Game) -> SCPoliticalAction? {
        // Find members of the same faction
        var factionMembers: [String: [GameCharacter]] = [:]
        for member in members {
            if let factionId = member.factionId {
                factionMembers[factionId, default: []].append(member)
            }
        }

        // Look for faction with 2+ SC members who might coordinate
        for (factionId, factionMemberList) in factionMembers where factionMemberList.count >= 2 {
            guard let faction = game.factions.first(where: { $0.factionId == factionId }) else { continue }

            // 10% chance if faction has multiple SC members
            guard Int.random(in: 1...100) <= 10 else { continue }

            guard let leadMember = factionMemberList.first else { continue }
            let otherMembers = factionMemberList.dropFirst().map { $0.name }.joined(separator: " and ")

            return SCPoliticalAction(
                actionType: .votingBlocFormed,
                headline: "\(faction.name) Faction Consolidating",
                details: "Your sources report that \(leadMember.name) has been coordinating with \(otherMembers) to form a unified voting bloc within the Standing Committee. They appear to be aligning their positions on upcoming matters.",
                visibilityLevel: .intel,
                initiator: leadMember,
                involvedFaction: faction
            )
        }
        return nil
    }

    /// Check for backroom deals (high network reveals these)
    private static func checkBackroomDeal(members: [GameCharacter], game: Game) -> SCPoliticalAction? {
        guard members.count >= 2 else { return nil }

        // 15% chance if player has network >= 50
        guard Int.random(in: 1...100) <= 15 else { return nil }

        guard let member1 = members.randomElement(),
              let member2 = members.filter({ $0.id != member1.id }).randomElement() else {
            return nil
        }

        let deals: [(String, String)] = [
            ("Private Meeting Observed",
             "Your informants report a lengthy private meeting between \(member1.name) and \(member2.name) at an undisclosed location. The subject of their discussion remains unknown, but such meetings rarely concern routine matters."),
            ("Unusual Coordination",
             "Analysis of recent votes shows unusual coordination between \(member1.name) and \(member2.name), suggesting a private understanding. They've voted identically on the last several contentious issues."),
            ("Exchange of Favors",
             "Sources suggest \(member1.name) and \(member2.name) have reached an informal agreement. \(member1.name) reportedly supported \(member2.name)'s recent initiative in exchange for future consideration on an unspecified matter."),
            ("Secret Understanding",
             "A trusted source reports that \(member1.name) and \(member2.name) have reached a secret understanding regarding committee business. Details are sparse, but your source believes it involves upcoming personnel decisions.")
        ]

        guard let deal = deals.randomElement() else { return nil }

        return SCPoliticalAction(
            actionType: .backroomDeal,
            headline: deal.0,
            details: deal.1,
            visibilityLevel: .secret,
            initiator: member1,
            target: member2
        )
    }

    /// Generate a guaranteed proposal when no NPC proposed this turn
    private static func generateGuaranteedProposal(committee: StandingCommittee, game: Game, excludeTitles: Set<String>) -> SCProposalResult? {
        // Pick a random SC member to generate a routine proposal.
        // Filter out ceremonial-role members (Co-opt Rival "Promote Sideways"
        // path) — falling back to them here would let a sidelined character
        // keep proposing once per turn and defeat the velvet-coffin effect.
        let eligibleMembers = committee.memberIds.compactMap { memberId in
            game.characters.first(where: { $0.templateId == memberId && $0.isAlive })
        }.filter { !$0.hasCeremonialRole(in: game) }

        guard let member = eligibleMembers.randomElement() else { return nil }

        // Generate a routine proposal from expanded pool
        let routineProposals: [ProposalContent] = [
            ProposalContent(
                title: "Administrative Efficiency Review",
                description: "\(member.name) proposes a review of bureaucratic procedures to improve efficiency.",
                category: .policy,
                priority: .routine,
                proposalType: .institutionalReform,
                effects: [:]
            ),
            ProposalContent(
                title: "Quarterly Progress Report",
                description: "\(member.name) requests a formal progress report on current initiatives.",
                category: .policy,
                priority: .routine,
                proposalType: .institutionalReform,
                effects: [:]
            ),
            ProposalContent(
                title: "Resource Allocation Update",
                description: "\(member.name) proposes adjustments to resource allocation based on current needs.",
                category: .economic,
                priority: .routine,
                proposalType: .economicReform,
                effects: [:]
            ),
            ProposalContent(
                title: "Inter-Ministry Coordination Assessment",
                description: "\(member.name) proposes reviewing coordination mechanisms between ministries.",
                category: .policy,
                priority: .routine,
                proposalType: .institutionalReform,
                effects: [:]
            ),
            ProposalContent(
                title: "Cadre Training Program Review",
                description: "\(member.name) proposes evaluating the effectiveness of current cadre training programs.",
                category: .personnel,
                priority: .routine,
                proposalType: .personnelChange,
                effects: [:]
            ),
            ProposalContent(
                title: "Production Quota Compliance Report",
                description: "\(member.name) requests a comprehensive report on regional quota fulfillment.",
                category: .economic,
                priority: .routine,
                proposalType: .policyReview,
                effects: [:]
            ),
            ProposalContent(
                title: "State Asset Inventory Audit",
                description: "\(member.name) proposes a systematic audit of state enterprise assets.",
                category: .economic,
                priority: .routine,
                proposalType: .economicReform,
                effects: [:]
            ),
            ProposalContent(
                title: "Public Communications Guidelines Update",
                description: "\(member.name) proposes updating guidelines for official public communications.",
                category: .policy,
                priority: .routine,
                proposalType: .institutionalReform,
                effects: [:]
            )
        ]

        // Filter out already-used titles
        let available = routineProposals.filter { !excludeTitles.contains($0.title) }
        guard let proposal = available.randomElement() else { return nil }

        StandingCommitteeService.shared.submitAgendaItem(
            to: committee,
            title: proposal.title,
            description: proposal.description,
            category: proposal.category,
            priority: proposal.priority,
            sponsor: member,
            game: game,
            effects: proposal.effects
        )

        JournalService.shared.onCommitteeProposal(
            sponsor: member,
            proposalTitle: proposal.title,
            description: proposal.description,
            isPlayerOverlap: false,
            game: game
        )

        return SCProposalResult(
            sponsorId: member.templateId,
            sponsorName: member.name,
            proposal: proposal,
            turnSubmitted: game.turnNumber
        )
    }

    // MARK: - Proposal Decision Logic

    /// Determine if an NPC should propose this turn
    private static func shouldProposeThisTurn(member: GameCharacter, committee: StandingCommittee, game: Game) -> Bool {
        // Base 25% chance - high enough for active committee feel
        var chance = 25

        // GS proposes more often (setting agenda)
        if member.templateId == committee.chairId {
            chance += 25
        }

        // Increase if faction is losing power
        if let factionId = member.factionId,
           let faction = game.factions.first(where: { $0.factionId == factionId }),
           faction.power < 40 {
            chance += 15
        }

        // Increase if ambitious personality
        if member.personalityAmbitious > 70 {
            chance += 15
        }

        // Increase during crises
        if game.stability < 40 {
            chance += 20
        }

        // Increase if member has active goals that could be advanced
        if hasAdvanceableGoals(member: member, game: game) {
            chance += 15
        }

        // Decrease if there are too many pending items (avoid spam)
        let pendingCount = committee.pendingAgenda.count
        if pendingCount >= 6 {
            chance -= (pendingCount - 5) * 5
        }

        // CEREMONIAL ROLE: A character co-opted via "Promote Sideways"
        // is functionally sidelined — they should rarely propose anything
        // of substance. Apply a 0.2× multiplier to their proposal chance.
        // Floor of 1 (not the usual 5) so they can still occasionally
        // submit something for flavor, but the corridor mostly forgets
        // them.
        if member.hasCeremonialRole(in: game) {
            chance = Int((Double(chance) * 0.2).rounded())
            return Int.random(in: 1...100) <= max(chance, 1)
        }

        return Int.random(in: 1...100) <= max(chance, 5)
    }

    /// Generate a proposal based on character's situation
    private static func generateProposal(for member: GameCharacter, committee: StandingCommittee, game: Game, excludeTitles: Set<String>) -> ProposalContent? {
        // Priority order for proposal generation:

        // 1. Crisis response (if stability < 30)
        if game.stability < 30 {
            if let crisis = generateCrisisProposal(member: member, game: game, excludeTitles: excludeTitles) {
                return crisis
            }
        }

        // 2. Faction protection (if faction losing)
        if let factionProposal = generateFactionProtectionProposal(member: member, game: game, excludeTitles: excludeTitles) {
            return factionProposal
        }

        // 3. Succession law change (faction interests, elderly leader, ambitious NPC)
        // 15% base chance when conditions are met
        if Int.random(in: 1...100) <= 15 {
            if let successionProposal = generateSuccessionProposal(member: member, game: game, excludeTitles: excludeTitles) {
                return successionProposal
            }
        }

        // 4. Goal advancement (active NPC goals)
        if let goalProposal = generateGoalDrivenProposal(member: member, game: game, excludeTitles: excludeTitles) {
            return goalProposal
        }

        // 5. Opportunistic (random beneficial proposal)
        return generateOpportunisticProposal(member: member, game: game, excludeTitles: excludeTitles)
    }

    // MARK: - Crisis Proposals

    private static func generateCrisisProposal(member: GameCharacter, game: Game, excludeTitles: Set<String>) -> ProposalContent? {
        var crisisProposals: [ProposalContent] = []

        // Economic crisis options (3 variants)
        if game.industrialOutput < 40 {
            crisisProposals.append(contentsOf: [
                ProposalContent(
                    title: "Emergency Economic Measures",
                    description: "\(member.name) proposes emergency measures to address the economic crisis, including resource reallocation and production quotas adjustment.",
                    category: .economic,
                    priority: .urgent,
                    proposalType: .economicReform,
                    effects: ["industrialOutput": 5, "popularSupport": -3]
                ),
                ProposalContent(
                    title: "Industrial Output Recovery Plan",
                    description: "\(member.name) proposes mobilizing additional labor and extending factory hours to meet production targets.",
                    category: .economic,
                    priority: .urgent,
                    proposalType: .economicReform,
                    effects: ["industrialOutput": 7, "popularSupport": -5]
                ),
                ProposalContent(
                    title: "State Enterprise Emergency Audit",
                    description: "\(member.name) proposes identifying and replacing underperforming factory managers to restore productivity.",
                    category: .economic,
                    priority: .urgent,
                    proposalType: .personnelChange,
                    effects: ["industrialOutput": 4, "eliteLoyalty": -4]
                )
            ])
        }

        // Security crisis options (3 variants)
        if game.stability < 25 {
            crisisProposals.append(contentsOf: [
                ProposalContent(
                    title: "Stability Restoration Initiative",
                    description: "\(member.name) proposes enhanced security measures and political education campaigns to restore order.",
                    category: .security,
                    priority: .critical,
                    proposalType: .securityCrackdown,
                    effects: ["stability": 8, "popularSupport": -5, "eliteLoyalty": 3]
                ),
                ProposalContent(
                    title: "Public Order Enforcement Directive",
                    description: "\(member.name) proposes expanding militia presence and implementing curfews in troubled regions.",
                    category: .security,
                    priority: .critical,
                    proposalType: .securityCrackdown,
                    effects: ["stability": 10, "popularSupport": -8]
                ),
                ProposalContent(
                    title: "Counter-Revolutionary Vigilance Campaign",
                    description: "\(member.name) proposes a mass campaign to identify and neutralize destabilizing elements.",
                    category: .security,
                    priority: .critical,
                    proposalType: .purge,
                    effects: ["stability": 6, "popularSupport": -4, "eliteLoyalty": -3]
                )
            ])
        }

        // Elite loyalty crisis options (3 variants)
        if game.eliteLoyalty < 30 {
            crisisProposals.append(contentsOf: [
                ProposalContent(
                    title: "Party Unity Campaign",
                    description: "\(member.name) proposes a campaign to strengthen Party discipline and loyalty among cadres.",
                    category: .ideological,
                    priority: .urgent,
                    proposalType: .ideologicalCampaign,
                    effects: ["eliteLoyalty": 10, "stability": -3]
                ),
                ProposalContent(
                    title: "Cadre Self-Criticism Sessions",
                    description: "\(member.name) proposes mandatory self-criticism sessions for all officials to renew revolutionary commitment.",
                    category: .ideological,
                    priority: .urgent,
                    proposalType: .ideologicalCampaign,
                    effects: ["eliteLoyalty": 8, "stability": -2]
                ),
                ProposalContent(
                    title: "Leadership Loyalty Verification",
                    description: "\(member.name) proposes comprehensive background reviews for officials in sensitive positions.",
                    category: .security,
                    priority: .urgent,
                    proposalType: .investigation,
                    effects: ["eliteLoyalty": 6, "stability": -4]
                )
            ])
        }

        // Popular support crisis options (3 variants)
        if game.popularSupport < 25 {
            crisisProposals.append(contentsOf: [
                ProposalContent(
                    title: "People's Welfare Initiative",
                    description: "\(member.name) proposes increased investment in public services and living standards.",
                    category: .economic,
                    priority: .urgent,
                    proposalType: .welfareProgram,
                    effects: ["popularSupport": 12, "industrialOutput": -5]
                ),
                ProposalContent(
                    title: "Consumer Goods Priority Program",
                    description: "\(member.name) proposes temporarily redirecting resources to produce essential consumer goods.",
                    category: .economic,
                    priority: .urgent,
                    proposalType: .economicReform,
                    effects: ["popularSupport": 10, "industrialOutput": -4]
                ),
                ProposalContent(
                    title: "Public Grievance Resolution Commission",
                    description: "\(member.name) proposes establishing channels for citizens to report local official misconduct.",
                    category: .policy,
                    priority: .urgent,
                    proposalType: .institutionalReform,
                    effects: ["popularSupport": 8, "eliteLoyalty": -5]
                )
            ])
        }

        // Filter out already-used titles and select randomly
        let available = crisisProposals.filter { !excludeTitles.contains($0.title) }
        return available.randomElement()
    }

    // MARK: - Faction Protection Proposals

    private static func generateFactionProtectionProposal(member: GameCharacter, game: Game, excludeTitles: Set<String>) -> ProposalContent? {
        guard let factionId = member.factionId,
              let faction = game.factions.first(where: { $0.factionId == factionId }),
              faction.power < 45 else {
            return nil
        }

        // Generate faction-specific protective proposals (expanded pools)
        let factionProposals: [String: [ProposalContent]] = [
            "reformists": [
                ProposalContent(
                    title: "Market Reform Expansion",
                    description: "\(member.name) proposes expanding market mechanisms to improve economic efficiency.",
                    category: .economic,
                    priority: .important,
                    proposalType: .economicReform,
                    targetFactionId: factionId,
                    effects: ["industrialOutput": 5]
                ),
                ProposalContent(
                    title: "Administrative Modernization",
                    description: "\(member.name) proposes streamlining bureaucratic procedures and promoting merit-based advancement.",
                    category: .personnel,
                    priority: .routine,
                    proposalType: .personnelChange,
                    targetFactionId: factionId,
                    effects: ["stability": 2]
                ),
                ProposalContent(
                    title: "Economic Liberalization Pilot Zone",
                    description: "\(member.name) proposes establishing a special economic zone to test market-oriented policies.",
                    category: .economic,
                    priority: .important,
                    proposalType: .economicReform,
                    targetFactionId: factionId,
                    effects: ["industrialOutput": 4, "eliteLoyalty": -3]
                ),
                ProposalContent(
                    title: "Foreign Investment Framework",
                    description: "\(member.name) proposes creating guidelines for limited foreign capital participation in state enterprises.",
                    category: .foreign,
                    priority: .important,
                    proposalType: .foreignPolicy,
                    targetFactionId: factionId,
                    effects: ["internationalStanding": 5, "eliteLoyalty": -4]
                )
            ],
            "conservatives": [
                ProposalContent(
                    title: "Strengthen Central Planning",
                    description: "\(member.name) proposes reinforcing state control over key economic sectors.",
                    category: .economic,
                    priority: .important,
                    proposalType: .economicReform,
                    targetFactionId: factionId,
                    effects: ["eliteLoyalty": 5, "industrialOutput": -3]
                ),
                ProposalContent(
                    title: "Ideological Rectification Campaign",
                    description: "\(member.name) proposes a campaign to combat ideological deviation and strengthen Party orthodoxy.",
                    category: .ideological,
                    priority: .important,
                    proposalType: .ideologicalCampaign,
                    targetFactionId: factionId,
                    effects: ["eliteLoyalty": 8, "popularSupport": -5]
                ),
                ProposalContent(
                    title: "Revolutionary Tradition Preservation",
                    description: "\(member.name) proposes mandatory revolutionary history education and heritage protection.",
                    category: .ideological,
                    priority: .routine,
                    proposalType: .ideologicalCampaign,
                    targetFactionId: factionId,
                    effects: ["eliteLoyalty": 4]
                ),
                ProposalContent(
                    title: "Anti-Revisionism Resolution",
                    description: "\(member.name) proposes formally condemning ideological deviations from orthodox socialist principles.",
                    category: .ideological,
                    priority: .important,
                    proposalType: .ideologicalCampaign,
                    targetFactionId: factionId,
                    effects: ["eliteLoyalty": 6, "popularSupport": -3]
                )
            ],
            "military": [
                ProposalContent(
                    title: "Defense Modernization Program",
                    description: "\(member.name) proposes increased investment in military capabilities and defense industry.",
                    category: .security,
                    priority: .important,
                    proposalType: .militaryExpansion,
                    targetFactionId: factionId,
                    effects: ["militaryLoyalty": 10, "industrialOutput": -5]
                ),
                ProposalContent(
                    title: "Veterans Benefits Enhancement",
                    description: "\(member.name) proposes improving pensions and housing for military veterans and their families.",
                    category: .economic,
                    priority: .routine,
                    proposalType: .welfareProgram,
                    targetFactionId: factionId,
                    effects: ["militaryLoyalty": 6, "popularSupport": 3]
                ),
                ProposalContent(
                    title: "Civil Defense Readiness Initiative",
                    description: "\(member.name) proposes expanding civil defense training and emergency preparedness programs.",
                    category: .security,
                    priority: .routine,
                    proposalType: .militaryExpansion,
                    targetFactionId: factionId,
                    effects: ["militaryLoyalty": 4, "stability": 2]
                )
            ],
            "regional": [
                ProposalContent(
                    title: "Regional Development Initiative",
                    description: "\(member.name) proposes increased autonomy and investment for regional governments.",
                    category: .economic,
                    priority: .routine,
                    proposalType: .regionalPolicy,
                    targetFactionId: factionId,
                    effects: ["popularSupport": 5, "eliteLoyalty": -3]
                ),
                ProposalContent(
                    title: "Provincial Infrastructure Investment",
                    description: "\(member.name) proposes directing resources to improve regional transportation and utilities.",
                    category: .economic,
                    priority: .routine,
                    proposalType: .regionalPolicy,
                    targetFactionId: factionId,
                    effects: ["popularSupport": 4, "industrialOutput": 2]
                ),
                ProposalContent(
                    title: "Local Language and Culture Preservation",
                    description: "\(member.name) proposes protecting regional cultural heritage and minority language education.",
                    category: .policy,
                    priority: .routine,
                    proposalType: .regionalPolicy,
                    targetFactionId: factionId,
                    effects: ["popularSupport": 3, "eliteLoyalty": -2]
                )
            ]
        ]

        // Find proposals for this faction or use generic
        let proposals = factionProposals[factionId] ?? [
            ProposalContent(
                title: "Strengthen \(faction.name) Representation",
                description: "\(member.name) proposes measures to better represent \(faction.name) interests in policy decisions.",
                category: .personnel,
                priority: .routine,
                proposalType: .factionSupport,
                targetFactionId: factionId,
                effects: [:]
            )
        ]

        // Filter out already-used titles
        let available = proposals.filter { !excludeTitles.contains($0.title) }
        return available.randomElement()
    }

    // MARK: - Goal-Driven Proposals

    private static func generateGoalDrivenProposal(member: GameCharacter, game: Game, excludeTitles: Set<String>) -> ProposalContent? {
        // Check member's active goals
        let goals = member.npcGoals.filter { $0.isActive }
        var candidates: [ProposalContent] = []

        for goal in goals {
            switch goal.goalType {
            case .seekPromotion:
                // Propose personnel changes that could benefit them
                let rivalId = findRivalInPath(member: member, game: game)
                candidates.append(contentsOf: [
                    ProposalContent(
                        title: "Personnel Review Initiative",
                        description: "\(member.name) proposes a comprehensive review of leadership positions to ensure the most capable cadres are in key roles.",
                        category: .personnel,
                        priority: .important,
                        proposalType: .personnelChange,
                        targetCharacterId: rivalId,
                        effects: [:]
                    ),
                    ProposalContent(
                        title: "Leadership Capability Assessment",
                        description: "\(member.name) proposes evaluating current officials against revolutionary standards and modern competencies.",
                        category: .personnel,
                        priority: .important,
                        proposalType: .personnelChange,
                        targetCharacterId: rivalId,
                        effects: [:]
                    ),
                    ProposalContent(
                        title: "Merit-Based Advancement Framework",
                        description: "\(member.name) proposes establishing clearer criteria for identifying and promoting talented cadres.",
                        category: .personnel,
                        priority: .routine,
                        proposalType: .institutionalReform,
                        effects: ["eliteLoyalty": -2]
                    )
                ])

            case .destroyRival:
                if let targetId = goal.targetCharacterId {
                    candidates.append(contentsOf: [
                        ProposalContent(
                            title: "Anti-Corruption Investigation",
                            description: "\(member.name) proposes investigating irregularities in certain administrative units.",
                            category: .security,
                            priority: .urgent,
                            proposalType: .investigation,
                            targetCharacterId: targetId,
                            effects: ["stability": -2]
                        ),
                        ProposalContent(
                            title: "Financial Irregularities Audit",
                            description: "\(member.name) proposes a thorough audit of fund management in select departments.",
                            category: .security,
                            priority: .urgent,
                            proposalType: .investigation,
                            targetCharacterId: targetId,
                            effects: ["stability": -3]
                        ),
                        ProposalContent(
                            title: "Cadre Conduct Review",
                            description: "\(member.name) proposes reviewing adherence to Party discipline among senior officials.",
                            category: .security,
                            priority: .important,
                            proposalType: .investigation,
                            targetCharacterId: targetId,
                            effects: ["eliteLoyalty": -3]
                        )
                    ])
                }

            case .expandInfluence:
                candidates.append(contentsOf: [
                    ProposalContent(
                        title: "Organizational Restructuring",
                        description: "\(member.name) proposes reorganizing certain departments to improve efficiency.",
                        category: .personnel,
                        priority: .routine,
                        proposalType: .personnelChange,
                        effects: [:]
                    ),
                    ProposalContent(
                        title: "Departmental Jurisdiction Clarification",
                        description: "\(member.name) proposes resolving overlapping responsibilities between ministries.",
                        category: .policy,
                        priority: .routine,
                        proposalType: .institutionalReform,
                        effects: [:]
                    ),
                    ProposalContent(
                        title: "Cross-Ministry Coordination Committee",
                        description: "\(member.name) proposes establishing a permanent coordination body for inter-departmental matters.",
                        category: .policy,
                        priority: .routine,
                        proposalType: .institutionalReform,
                        effects: ["stability": 2]
                    )
                ])

            case .protectPosition:
                candidates.append(contentsOf: [
                    ProposalContent(
                        title: "Strengthen Institutional Safeguards",
                        description: "\(member.name) proposes measures to protect institutional stability and continuity.",
                        category: .policy,
                        priority: .important,
                        proposalType: .institutionalReform,
                        effects: ["stability": 3]
                    ),
                    ProposalContent(
                        title: "Procedural Transparency Enhancement",
                        description: "\(member.name) proposes clearer documentation requirements for personnel decisions.",
                        category: .policy,
                        priority: .routine,
                        proposalType: .institutionalReform,
                        effects: ["stability": 2]
                    ),
                    ProposalContent(
                        title: "Tenure Protection Guidelines",
                        description: "\(member.name) proposes establishing minimum terms and due process for leadership positions.",
                        category: .personnel,
                        priority: .important,
                        proposalType: .institutionalReform,
                        effects: ["eliteLoyalty": 3, "stability": 2]
                    )
                ])

            case .implementReform:
                candidates.append(contentsOf: [
                    ProposalContent(
                        title: "Reform Implementation Acceleration",
                        description: "\(member.name) proposes accelerating ongoing reform initiatives.",
                        category: .policy,
                        priority: .important,
                        proposalType: .economicReform,
                        effects: ["industrialOutput": 3, "eliteLoyalty": -3]
                    ),
                    ProposalContent(
                        title: "Pilot Program Expansion",
                        description: "\(member.name) proposes extending successful reform experiments to additional regions.",
                        category: .economic,
                        priority: .important,
                        proposalType: .economicReform,
                        effects: ["industrialOutput": 4, "eliteLoyalty": -2]
                    ),
                    ProposalContent(
                        title: "Reform Progress Evaluation",
                        description: "\(member.name) proposes a comprehensive assessment of ongoing modernization efforts.",
                        category: .policy,
                        priority: .routine,
                        proposalType: .policyReview,
                        effects: [:]
                    )
                ])

            case .purgeEnemies:
                candidates.append(contentsOf: [
                    ProposalContent(
                        title: "Party Discipline Enforcement",
                        description: "\(member.name) proposes strengthening discipline inspection and accountability mechanisms.",
                        category: .security,
                        priority: .urgent,
                        proposalType: .purge,
                        effects: ["eliteLoyalty": -5, "stability": 5]
                    ),
                    ProposalContent(
                        title: "Counter-Revolutionary Element Investigation",
                        description: "\(member.name) proposes identifying and removing hostile elements from Party ranks.",
                        category: .security,
                        priority: .urgent,
                        proposalType: .purge,
                        effects: ["eliteLoyalty": -6, "stability": 4]
                    ),
                    ProposalContent(
                        title: "Ideological Purity Campaign",
                        description: "\(member.name) proposes a campaign to root out those with bourgeois or counter-revolutionary tendencies.",
                        category: .ideological,
                        priority: .urgent,
                        proposalType: .ideologicalCampaign,
                        effects: ["eliteLoyalty": -4, "stability": 3]
                    )
                ])

            default:
                continue
            }
        }

        // Filter out already-used titles
        let available = candidates.filter { !excludeTitles.contains($0.title) }
        return available.randomElement()
    }

    // MARK: - Opportunistic Proposals

    private static func generateOpportunisticProposal(member: GameCharacter, game: Game, excludeTitles: Set<String>) -> ProposalContent? {
        // Generate based on current game state opportunities
        var opportunities: [ProposalContent] = []

        // If economy is doing well, propose expansion
        if game.industrialOutput > 60 {
            opportunities.append(contentsOf: [
                ProposalContent(
                    title: "Economic Expansion Program",
                    description: "\(member.name) proposes leveraging current economic strength for strategic investments.",
                    category: .economic,
                    priority: .routine,
                    proposalType: .economicReform,
                    effects: ["industrialOutput": 5, "popularSupport": 3]
                ),
                ProposalContent(
                    title: "Industrial Capacity Enhancement",
                    description: "\(member.name) proposes reinvesting surplus production into expanding factory capabilities.",
                    category: .economic,
                    priority: .routine,
                    proposalType: .economicReform,
                    effects: ["industrialOutput": 4]
                )
            ])
        }

        // If stability is high, propose reforms
        if game.stability > 70 {
            opportunities.append(contentsOf: [
                ProposalContent(
                    title: "Administrative Improvement Initiative",
                    description: "\(member.name) proposes using the current stable period to implement gradual improvements.",
                    category: .policy,
                    priority: .routine,
                    proposalType: .institutionalReform,
                    effects: ["stability": -3, "industrialOutput": 5]
                ),
                ProposalContent(
                    title: "Bureaucratic Streamlining Proposal",
                    description: "\(member.name) proposes simplifying administrative procedures during this period of stability.",
                    category: .policy,
                    priority: .routine,
                    proposalType: .institutionalReform,
                    effects: ["stability": -2, "popularSupport": 3]
                )
            ])
        }

        // If international standing is low, propose diplomatic initiative
        if game.internationalStanding < 40 {
            opportunities.append(contentsOf: [
                ProposalContent(
                    title: "Diplomatic Engagement Initiative",
                    description: "\(member.name) proposes improving international relations through diplomatic outreach.",
                    category: .foreign,
                    priority: .important,
                    proposalType: .foreignPolicy,
                    effects: ["internationalStanding": 8]
                ),
                ProposalContent(
                    title: "Foreign Trade Promotion",
                    description: "\(member.name) proposes expanding trade missions to improve economic ties with friendly nations.",
                    category: .foreign,
                    priority: .routine,
                    proposalType: .foreignPolicy,
                    effects: ["internationalStanding": 5, "industrialOutput": 2]
                )
            ])
        }

        // Expanded pool of routine procedural proposals (always available)
        opportunities.append(contentsOf: [
            ProposalContent(
                title: "Budget Allocation Review",
                description: "\(member.name) proposes reviewing budget allocations for the coming period.",
                category: .economic,
                priority: .routine,
                proposalType: .budgetChange,
                effects: [:]
            ),
            ProposalContent(
                title: "Policy Implementation Assessment",
                description: "\(member.name) proposes assessing the implementation of recent policy decisions.",
                category: .policy,
                priority: .routine,
                proposalType: .policyReview,
                effects: [:]
            ),
            ProposalContent(
                title: "Cadre Performance Evaluation Standards",
                description: "\(member.name) proposes updating the criteria used to evaluate official performance.",
                category: .personnel,
                priority: .routine,
                proposalType: .institutionalReform,
                effects: [:]
            ),
            ProposalContent(
                title: "State Enterprise Efficiency Audit",
                description: "\(member.name) proposes a routine audit of state enterprise productivity and resource usage.",
                category: .economic,
                priority: .routine,
                proposalType: .economicReform,
                effects: [:]
            ),
            ProposalContent(
                title: "Revolutionary Merit Recognition Ceremony",
                description: "\(member.name) proposes organizing a ceremony to honor exemplary Party members and workers.",
                category: .ideological,
                priority: .routine,
                proposalType: .ideologicalCampaign,
                effects: ["eliteLoyalty": 2, "popularSupport": 2]
            ),
            ProposalContent(
                title: "Inter-Ministry Coordination Report",
                description: "\(member.name) proposes a formal review of cooperation between government ministries.",
                category: .policy,
                priority: .routine,
                proposalType: .policyReview,
                effects: [:]
            ),
            ProposalContent(
                title: "Quarterly Economic Indicators Review",
                description: "\(member.name) proposes presenting the latest economic statistics for committee discussion.",
                category: .economic,
                priority: .routine,
                proposalType: .policyReview,
                effects: [:]
            ),
            ProposalContent(
                title: "Administrative Procedures Modernization",
                description: "\(member.name) proposes updating outdated bureaucratic processes for greater efficiency.",
                category: .policy,
                priority: .routine,
                proposalType: .institutionalReform,
                effects: ["stability": 1]
            ),
            ProposalContent(
                title: "Public Services Quality Assessment",
                description: "\(member.name) proposes evaluating citizen satisfaction with government services.",
                category: .policy,
                priority: .routine,
                proposalType: .policyReview,
                effects: [:]
            ),
            ProposalContent(
                title: "Personnel Record Verification",
                description: "\(member.name) proposes a routine update of official personnel files and credentials.",
                category: .personnel,
                priority: .routine,
                proposalType: .personnelChange,
                effects: [:]
            ),
            ProposalContent(
                title: "Departmental Budget Reconciliation",
                description: "\(member.name) proposes reconciling ministry budgets with actual expenditures.",
                category: .economic,
                priority: .routine,
                proposalType: .budgetChange,
                effects: [:]
            ),
            ProposalContent(
                title: "Regulatory Compliance Update",
                description: "\(member.name) proposes reviewing and updating administrative regulations.",
                category: .policy,
                priority: .routine,
                proposalType: .institutionalReform,
                effects: [:]
            )
        ])

        // Filter out already-used titles
        let available = opportunities.filter { !excludeTitles.contains($0.title) }
        return available.randomElement()
    }

    // MARK: - Succession Law Proposals

    /// Generate proposals to change the leadership succession law
    /// Triggers: elderly leader, faction interests, ambitious NPCs, recent succession failures
    private static func generateSuccessionProposal(member: GameCharacter, game: Game, excludeTitles: Set<String>) -> ProposalContent? {
        let currentMode = SuccessionLawService.shared.getCurrentMode(game: game)

        // Check trigger conditions
        var shouldPropose = false
        var preferredMode: SuccessionMode? = nil

        // 1. Check if General Secretary is elderly (succession becomes relevant)
        let gsAge = Int(game.variables["general_secretary_age"] ?? "55") ?? 55
        if gsAge >= 70 {
            shouldPropose = true
        }

        // 2. Check faction interests - each faction prefers different succession modes
        if let factionId = member.factionId {
            switch factionId {
            case "reformists", "youth_league":
                // Meritocrats prefer open competition or collective decision
                if currentMode == .familyPrivilege || currentMode == .revolutionaryContinuity {
                    shouldPropose = true
                    preferredMode = member.personalityAmbitious > 60 ? .partyElection : .collectiveDecision
                }
            case "princelings":
                // Dynasties prefer family privilege
                if currentMode != .familyPrivilege && currentMode != .designatedSuccessor {
                    shouldPropose = true
                    preferredMode = .familyPrivilege
                }
            case "old_guard", "conservatives":
                // Old guard prefers stability/autocracy
                if currentMode == .partyElection || currentMode == .collectiveDecision {
                    shouldPropose = true
                    preferredMode = .designatedSuccessor
                }
            default:
                break
            }
        }

        // 3. Ambitious NPCs seeking open competition (personal advantage)
        if member.personalityAmbitious > 75 && currentMode != .partyElection {
            shouldPropose = true
            preferredMode = .partyElection
        }

        // 4. Low probability base chance for variety
        if !shouldPropose && Int.random(in: 1...100) <= 5 {
            shouldPropose = true
        }

        guard shouldPropose else { return nil }

        // Generate appropriate proposal based on member's interests
        var candidates: [ProposalContent] = []

        // Proposals for each target succession mode
        switch preferredMode ?? suggestModeForMember(member: member, game: game) {
        case .collectiveDecision:
            candidates.append(contentsOf: [
                ProposalContent(
                    title: "Restore Collective Leadership Principle",
                    description: "\(member.name) proposes returning to the collective decision-making model for leadership succession, ensuring the Standing Committee has final say in selecting successors from approved candidates.",
                    category: .policy,
                    priority: .important,
                    proposalType: .successionLawChange,
                    effects: ["eliteLoyalty": 5, "stability": 3]
                ),
                ProposalContent(
                    title: "Strengthen Committee Authority in Succession",
                    description: "\(member.name) proposes reinforcing the Standing Committee's role in leadership transitions, preventing any individual from unilaterally determining succession.",
                    category: .policy,
                    priority: .important,
                    proposalType: .successionLawChange,
                    effects: ["eliteLoyalty": 4]
                )
            ])

        case .designatedSuccessor:
            candidates.append(contentsOf: [
                ProposalContent(
                    title: "Orderly Succession Protocol",
                    description: "\(member.name) proposes allowing the current leader to designate a preferred successor, subject to Standing Committee confirmation, to ensure smooth transitions.",
                    category: .policy,
                    priority: .important,
                    proposalType: .successionLawChange,
                    effects: ["stability": 5, "eliteLoyalty": -3]
                ),
                ProposalContent(
                    title: "Successor Designation Framework",
                    description: "\(member.name) proposes establishing a formal process for leadership to identify and prepare successors, with Committee oversight.",
                    category: .policy,
                    priority: .important,
                    proposalType: .successionLawChange,
                    effects: ["stability": 4]
                )
            ])

        case .familyPrivilege:
            candidates.append(contentsOf: [
                ProposalContent(
                    title: "Revolutionary Family Continuity",
                    description: "\(member.name) proposes recognizing that families with revolutionary credentials should receive priority consideration in succession, honoring the sacrifices of founding generations.",
                    category: .policy,
                    priority: .important,
                    proposalType: .successionLawChange,
                    effects: ["eliteLoyalty": -5, "stability": 2]
                ),
                ProposalContent(
                    title: "Hereditary Succession Rights",
                    description: "\(member.name) proposes that family members of deceased leaders should receive preferential treatment in succession decisions, ensuring continuity of vision.",
                    category: .policy,
                    priority: .urgent,
                    proposalType: .successionLawChange,
                    effects: ["eliteLoyalty": -6, "popularSupport": -3]
                )
            ])

        case .partyElection:
            candidates.append(contentsOf: [
                ProposalContent(
                    title: "Democratic Centralism in Succession",
                    description: "\(member.name) proposes that all eligible Politburo members should compete for succession through Party election, ensuring the most capable leader emerges.",
                    category: .policy,
                    priority: .important,
                    proposalType: .successionLawChange,
                    effects: ["eliteLoyalty": 8, "stability": -5]
                ),
                ProposalContent(
                    title: "Merit-Based Leadership Selection",
                    description: "\(member.name) proposes expanding the pool of succession candidates to all senior officials, allowing open competition based on merit and accomplishment.",
                    category: .policy,
                    priority: .important,
                    proposalType: .successionLawChange,
                    effects: ["eliteLoyalty": 6, "stability": -4]
                )
            ])

        case .revolutionaryContinuity:
            candidates.append(contentsOf: [
                ProposalContent(
                    title: "Revolutionary Continuity Protocol",
                    description: "\(member.name) proposes that in the interest of stability, the leader's designated successor should automatically assume power, without Committee intervention.",
                    category: .policy,
                    priority: .critical,
                    proposalType: .successionLawChange,
                    effects: ["stability": 8, "eliteLoyalty": -10, "popularSupport": -5]
                ),
                ProposalContent(
                    title: "Consolidate Succession Authority",
                    description: "\(member.name) proposes removing Standing Committee oversight from succession, allowing the current leader to directly choose their replacement.",
                    category: .policy,
                    priority: .urgent,
                    proposalType: .successionLawChange,
                    effects: ["stability": 6, "eliteLoyalty": -8]
                )
            ])
        }

        // Filter out already-used titles
        let available = candidates.filter { !excludeTitles.contains($0.title) }
        return available.randomElement()
    }

    /// Suggest succession mode based on member's personality and faction
    private static func suggestModeForMember(member: GameCharacter, game: Game) -> SuccessionMode {
        // Ambitious members prefer open competition
        if member.personalityAmbitious > 70 {
            return .partyElection
        }

        // Risk-averse prefer stability
        if member.personalityAmbitious < 30 {
            return .designatedSuccessor
        }

        // Faction-based preference
        if let factionId = member.factionId {
            switch factionId {
            case "princelings":
                return .familyPrivilege
            case "reformists", "youth_league":
                return .partyElection
            case "old_guard":
                return .revolutionaryContinuity
            default:
                return .collectiveDecision
            }
        }

        return .collectiveDecision
    }

    // MARK: - Helper Methods

    private static func hasAdvanceableGoals(member: GameCharacter, game: Game) -> Bool {
        return member.npcGoals.contains { goal in
            goal.isActive && [.seekPromotion, .destroyRival, .expandInfluence, .implementReform].contains(goal.goalType)
        }
    }

    private static func findRivalInPath(member: GameCharacter, game: Game) -> String? {
        // Find characters blocking this member's advancement
        guard let memberPosition = member.positionIndex else { return nil }

        return game.characters.first { char in
            guard char.isAlive,
                  let charPosition = char.positionIndex,
                  charPosition > memberPosition,
                  charPosition <= memberPosition + 2,
                  char.templateId != member.templateId else {
                return false
            }
            // Same track or shared positions
            return char.positionTrack == member.positionTrack || charPosition >= 7
        }?.templateId
    }
}

// MARK: - Supporting Types

struct ProposalContent {
    let title: String
    let description: String
    let category: CommitteeAgendaItem.AgendaCategory
    let priority: CommitteeAgendaItem.AgendaPriority
    let proposalType: ProposalType
    var targetCharacterId: String? = nil
    var targetFactionId: String? = nil
    var effects: [String: Int] = [:]

    enum ProposalType {
        case economicReform
        case securityCrackdown
        case ideologicalCampaign
        case personnelChange
        case foreignPolicy
        case institutionalReform
        case investigation
        case purge
        case militaryExpansion
        case regionalPolicy
        case factionSupport
        case welfareProgram
        case budgetChange
        case policyReview
        case successionLawChange  // NEW: Proposals to change leadership succession law
    }
}

struct SCProposalResult {
    let sponsorId: String
    let sponsorName: String
    let proposal: ProposalContent
    let turnSubmitted: Int
}

// MARK: - SC Political Actions (Non-Proposal)

struct SCPoliticalAction {
    let actionType: SCPoliticalActionType
    let headline: String
    let details: String
    let visibilityLevel: SCVisibilityLevel
    var initiator: GameCharacter
    var target: GameCharacter? = nil
    var involvedFaction: GameFaction? = nil
}

/// Visibility levels for SC political actions (mirrors EventVisibilityLevel)
enum SCVisibilityLevel: String, Codable {
    case `public` = "public"
    case rumor = "rumor"
    case intel = "intel"
    case secret = "secret"
}

enum SCPoliticalActionType: String, Codable {
    case scAttack = "sc_attack"                 // SC member attacks another
    case resignationThreat = "resignation_threat" // Member threatens to resign
    case votingBlocFormed = "voting_bloc_formed"  // Faction coordinates votes
    case backroomDeal = "backroom_deal"           // Secret deal between members
}
