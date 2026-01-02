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

        // Get player-submitted agenda items to detect overlap
        let playerAgendaCategories = committee.pendingAgenda
            .filter { $0.sponsorId == "player" || $0.sponsorId == nil }
            .map { $0.category }

        for memberId in committee.memberIds {
            guard let member = game.characters.first(where: { $0.templateId == memberId && $0.isAlive }),
                  shouldProposeThisTurn(member: member, committee: committee, game: game) else {
                continue
            }

            if let proposal = generateProposal(for: member, committee: committee, game: game) {
                // Submit to committee agenda
                StandingCommitteeService.shared.submitAgendaItem(
                    to: committee,
                    title: proposal.title,
                    description: proposal.description,
                    category: proposal.category,
                    priority: proposal.priority,
                    sponsor: member,
                    game: game
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
            if let guaranteedProposal = generateGuaranteedProposal(committee: committee, game: game) {
                results.append(guaranteedProposal)
            }
        }

        return results
    }

    /// Generate a guaranteed proposal when no NPC proposed this turn
    private static func generateGuaranteedProposal(committee: StandingCommittee, game: Game) -> SCProposalResult? {
        // Pick a random SC member to generate a routine proposal
        let eligibleMembers = committee.memberIds.compactMap { memberId in
            game.characters.first(where: { $0.templateId == memberId && $0.isAlive })
        }

        guard let member = eligibleMembers.randomElement() else { return nil }

        // Generate a routine proposal
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
            )
        ]

        guard let proposal = routineProposals.randomElement() else { return nil }

        StandingCommitteeService.shared.submitAgendaItem(
            to: committee,
            title: proposal.title,
            description: proposal.description,
            category: proposal.category,
            priority: proposal.priority,
            sponsor: member,
            game: game
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

        return Int.random(in: 1...100) <= max(chance, 5)
    }

    /// Generate a proposal based on character's situation
    private static func generateProposal(for member: GameCharacter, committee: StandingCommittee, game: Game) -> ProposalContent? {
        // Priority order for proposal generation:

        // 1. Crisis response (if stability < 30)
        if game.stability < 30 {
            if let crisis = generateCrisisProposal(member: member, game: game) {
                return crisis
            }
        }

        // 2. Faction protection (if faction losing)
        if let factionProposal = generateFactionProtectionProposal(member: member, game: game) {
            return factionProposal
        }

        // 3. Goal advancement (active NPC goals)
        if let goalProposal = generateGoalDrivenProposal(member: member, game: game) {
            return goalProposal
        }

        // 4. Opportunistic (random beneficial proposal)
        return generateOpportunisticProposal(member: member, game: game)
    }

    // MARK: - Crisis Proposals

    private static func generateCrisisProposal(member: GameCharacter, game: Game) -> ProposalContent? {
        let crisisTypes: [(condition: Bool, generator: () -> ProposalContent?)] = [
            // Economic crisis
            (game.industrialOutput < 40, {
                ProposalContent(
                    title: "Emergency Economic Measures",
                    description: "\(member.name) proposes emergency measures to address the economic crisis, including resource reallocation and production quotas adjustment.",
                    category: .economic,
                    priority: .urgent,
                    proposalType: .economicReform,
                    effects: ["industrialOutput": 5, "popularSupport": -3]
                )
            }),
            // Security crisis
            (game.stability < 25, {
                ProposalContent(
                    title: "Stability Restoration Initiative",
                    description: "\(member.name) proposes enhanced security measures and political education campaigns to restore order.",
                    category: .security,
                    priority: .critical,
                    proposalType: .securityCrackdown,
                    effects: ["stability": 8, "popularSupport": -5, "eliteLoyalty": 3]
                )
            }),
            // Elite loyalty crisis
            (game.eliteLoyalty < 30, {
                ProposalContent(
                    title: "Party Unity Campaign",
                    description: "\(member.name) proposes a campaign to strengthen Party discipline and loyalty among cadres.",
                    category: .ideological,
                    priority: .urgent,
                    proposalType: .ideologicalCampaign,
                    effects: ["eliteLoyalty": 10, "stability": -3]
                )
            }),
            // Popular support crisis
            (game.popularSupport < 25, {
                ProposalContent(
                    title: "People's Welfare Initiative",
                    description: "\(member.name) proposes increased investment in public services and living standards.",
                    category: .economic,
                    priority: .urgent,
                    proposalType: .welfareProgram,
                    effects: ["popularSupport": 12, "industrialOutput": -5]
                )
            })
        ]

        // Find applicable crisis and generate proposal
        let applicable = crisisTypes.filter { $0.condition }
        return applicable.randomElement()?.generator()
    }

    // MARK: - Faction Protection Proposals

    private static func generateFactionProtectionProposal(member: GameCharacter, game: Game) -> ProposalContent? {
        guard let factionId = member.factionId,
              let faction = game.factions.first(where: { $0.factionId == factionId }),
              faction.power < 45 else {
            return nil
        }

        // Generate faction-specific protective proposals
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

        return proposals.randomElement()
    }

    // MARK: - Goal-Driven Proposals

    private static func generateGoalDrivenProposal(member: GameCharacter, game: Game) -> ProposalContent? {
        // Check member's active goals
        let goals = member.npcGoals.filter { $0.isActive }

        for goal in goals {
            switch goal.goalType {
            case .seekPromotion:
                // Propose personnel changes that could benefit them
                if let rivalId = findRivalInPath(member: member, game: game) {
                    return ProposalContent(
                        title: "Personnel Review Initiative",
                        description: "\(member.name) proposes a comprehensive review of leadership positions to ensure the most capable cadres are in key roles.",
                        category: .personnel,
                        priority: .important,
                        proposalType: .personnelChange,
                        targetCharacterId: rivalId,
                        effects: [:]
                    )
                }

            case .destroyRival:
                if let targetId = goal.targetCharacterId {
                    return ProposalContent(
                        title: "Anti-Corruption Investigation",
                        description: "\(member.name) proposes investigating irregularities in certain administrative units.",
                        category: .security,
                        priority: .urgent,
                        proposalType: .investigation,
                        targetCharacterId: targetId,
                        effects: ["stability": -2]
                    )
                }

            case .expandInfluence:
                return ProposalContent(
                    title: "Organizational Restructuring",
                    description: "\(member.name) proposes reorganizing certain departments to improve efficiency.",
                    category: .personnel,
                    priority: .routine,
                    proposalType: .personnelChange,
                    effects: [:]
                )

            case .protectPosition:
                return ProposalContent(
                    title: "Strengthen Institutional Safeguards",
                    description: "\(member.name) proposes measures to protect institutional stability and continuity.",
                    category: .policy,
                    priority: .important,
                    proposalType: .institutionalReform,
                    effects: ["stability": 3]
                )

            case .implementReform:
                return ProposalContent(
                    title: "Reform Implementation Acceleration",
                    description: "\(member.name) proposes accelerating ongoing reform initiatives.",
                    category: .policy,
                    priority: .important,
                    proposalType: .economicReform,
                    effects: ["industrialOutput": 3, "eliteLoyalty": -3]
                )

            case .purgeEnemies:
                return ProposalContent(
                    title: "Party Discipline Enforcement",
                    description: "\(member.name) proposes strengthening discipline inspection and accountability mechanisms.",
                    category: .security,
                    priority: .urgent,
                    proposalType: .purge,
                    effects: ["eliteLoyalty": -5, "stability": 5]
                )

            default:
                continue
            }
        }

        return nil
    }

    // MARK: - Opportunistic Proposals

    private static func generateOpportunisticProposal(member: GameCharacter, game: Game) -> ProposalContent? {
        // Generate based on current game state opportunities
        var opportunities: [ProposalContent] = []

        // If economy is doing well, propose expansion
        if game.industrialOutput > 60 {
            opportunities.append(ProposalContent(
                title: "Economic Expansion Program",
                description: "\(member.name) proposes leveraging current economic strength for strategic investments.",
                category: .economic,
                priority: .routine,
                proposalType: .economicReform,
                effects: ["industrialOutput": 5, "popularSupport": 3]
            ))
        }

        // If stability is high, propose reforms
        if game.stability > 70 {
            opportunities.append(ProposalContent(
                title: "Administrative Improvement Initiative",
                description: "\(member.name) proposes using the current stable period to implement gradual improvements.",
                category: .policy,
                priority: .routine,
                proposalType: .institutionalReform,
                effects: ["stability": -3, "industrialOutput": 5]
            ))
        }

        // If international standing is low, propose diplomatic initiative
        if game.internationalStanding < 40 {
            opportunities.append(ProposalContent(
                title: "Diplomatic Engagement Initiative",
                description: "\(member.name) proposes improving international relations through diplomatic outreach.",
                category: .foreign,
                priority: .important,
                proposalType: .foreignPolicy,
                effects: ["internationalStanding": 8]
            ))
        }

        // Random procedural proposals
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
            )
        ])

        return opportunities.randomElement()
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
    }
}

struct SCProposalResult {
    let sponsorId: String
    let sponsorName: String
    let proposal: ProposalContent
    let turnSubmitted: Int
}
