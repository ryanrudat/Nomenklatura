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

    /// Generate a guaranteed proposal when no NPC proposed this turn
    private static func generateGuaranteedProposal(committee: StandingCommittee, game: Game, excludeTitles: Set<String>) -> SCProposalResult? {
        // Pick a random SC member to generate a routine proposal
        let eligibleMembers = committee.memberIds.compactMap { memberId in
            game.characters.first(where: { $0.templateId == memberId && $0.isAlive })
        }

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

        // 3. Goal advancement (active NPC goals)
        if let goalProposal = generateGoalDrivenProposal(member: member, game: game, excludeTitles: excludeTitles) {
            return goalProposal
        }

        // 4. Opportunistic (random beneficial proposal)
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
