//
//  DiplomaticAction.swift
//  Nomenklatura
//
//  Position-gated diplomatic actions following CCP-style hierarchy.
//  ~25 actions across 5 tiers from observer to supreme authority.
//

import Foundation

// MARK: - Action Category

/// Tier of diplomatic action based on authority level
enum DiplomaticActionCategory: String, Codable, CaseIterable {
    case observer       // Position 1-2: Read briefings, attend events
    case analyst        // Position 2-3: Draft cables, recommend responses
    case departmental   // Position 3-4: Propose exchanges, lobby policies
    case senior         // Position 4-5: Negotiate, sponsor treaties
    case executive      // Position 5-6: Direct authority, manage operations
    case supreme        // Position 7-8: War, sanctions, nuclear decisions

    var displayName: String {
        switch self {
        case .observer: return "Observer"
        case .analyst: return "Analyst"
        case .departmental: return "Departmental"
        case .senior: return "Senior Official"
        case .executive: return "Executive"
        case .supreme: return "Supreme Authority"
        }
    }

    var minimumPositionIndex: Int {
        switch self {
        case .observer: return 1
        case .analyst: return 2
        case .departmental: return 3
        case .senior: return 4
        case .executive: return 5
        case .supreme: return 7
        }
    }

    var color: String {
        switch self {
        case .observer: return "808080"     // Gray
        case .analyst: return "607D8B"      // Blue-gray
        case .departmental: return "1976D2" // Blue
        case .senior: return "7B1FA2"       // Purple
        case .executive: return "C62828"    // Red
        case .supreme: return "FFD700"      // Gold
        }
    }
}

// MARK: - Target Type

/// What the diplomatic action targets
enum DiplomaticTargetType: String, Codable {
    case country        // Specific foreign nation
    case bloc           // Political bloc (socialist, capitalist, etc.)
    case treaty         // Existing or proposed treaty
    case organization   // International organization
    case none           // No specific target (e.g., request briefing)
}

// MARK: - Risk Level

/// How risky the action is
enum DiplomaticRiskLevel: String, Codable {
    case minimal        // Safe, routine action
    case low            // Minor consequences possible
    case moderate       // Noticeable consequences likely
    case high           // Significant consequences expected
    case extreme        // Major international incident possible

    var failureConsequenceMultiplier: Double {
        switch self {
        case .minimal: return 0.5
        case .low: return 1.0
        case .moderate: return 1.5
        case .high: return 2.0
        case .extreme: return 3.0
        }
    }
}

// MARK: - Diplomatic Effects

/// Effects of a diplomatic action
struct DiplomaticEffects: Codable {
    // Relationship changes
    var relationshipChange: Int = 0         // Target country relationship
    var blocRelationshipChange: Int = 0     // Entire bloc relationship
    var tensionChange: Int = 0              // Diplomatic tension

    // Resource costs/gains
    var treasuryCost: Int = 0               // Immediate cost
    var standingChange: Int = 0             // Player standing
    var networkChange: Int = 0              // Player network

    // Special flags
    var createsFlag: String? = nil          // Game flag to set
    var removesFlag: String? = nil          // Game flag to remove
    var triggersTreaty: TreatyType? = nil   // Treaty to propose
    var triggersEvent: String? = nil        // Event to generate

    // Espionage effects
    var intelligenceChange: Int = 0         // Our assets in target
    var counterIntelChange: Int = 0         // Their activity against us
}

// MARK: - Diplomatic Action

/// A diplomatic action the player can take
struct DiplomaticAction: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let detailedDescription: String

    // Requirements
    let category: DiplomaticActionCategory
    let minimumPositionIndex: Int
    let targetType: DiplomaticTargetType

    // Timing
    let cooldownTurns: Int                  // Turns before can use again
    let executionTurns: Int                 // Turns to complete (0 = immediate)

    // Success/Failure
    let baseSuccessChance: Int              // 0-100 base chance
    let riskLevel: DiplomaticRiskLevel

    // Approval requirements
    let requiresCommitteeApproval: Bool     // Needs Standing Committee vote
    let canBeDecree: Bool                   // GS can bypass committee
    let canBeOverridden: Bool               // Higher authority can cancel

    // Effects
    let successEffects: DiplomaticEffects
    let failureEffects: DiplomaticEffects

    // UI
    let iconName: String
    let actionVerb: String                  // "Request", "Propose", "Declare"

    // Track requirement (nil = any track can use)
    let requiredTrack: String?

    init(
        id: String,
        name: String,
        description: String,
        detailedDescription: String = "",
        category: DiplomaticActionCategory,
        minimumPositionIndex: Int? = nil,
        targetType: DiplomaticTargetType,
        cooldownTurns: Int = 1,
        executionTurns: Int = 0,
        baseSuccessChance: Int = 80,
        riskLevel: DiplomaticRiskLevel = .low,
        requiresCommitteeApproval: Bool = false,
        canBeDecree: Bool = false,
        canBeOverridden: Bool = true,
        successEffects: DiplomaticEffects = DiplomaticEffects(),
        failureEffects: DiplomaticEffects = DiplomaticEffects(),
        iconName: String = "globe",
        actionVerb: String = "Execute",
        requiredTrack: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.detailedDescription = detailedDescription.isEmpty ? description : detailedDescription
        self.category = category
        self.minimumPositionIndex = minimumPositionIndex ?? category.minimumPositionIndex
        self.targetType = targetType
        self.cooldownTurns = cooldownTurns
        self.executionTurns = executionTurns
        self.baseSuccessChance = baseSuccessChance
        self.riskLevel = riskLevel
        self.requiresCommitteeApproval = requiresCommitteeApproval
        self.canBeDecree = canBeDecree
        self.canBeOverridden = canBeOverridden
        self.successEffects = successEffects
        self.failureEffects = failureEffects
        self.iconName = iconName
        self.actionVerb = actionVerb
        self.requiredTrack = requiredTrack
    }
}

// MARK: - Action Execution Record

/// Record of a diplomatic action being executed
struct DiplomaticActionRecord: Codable, Identifiable {
    let id: String
    let actionId: String
    let actionName: String
    let targetCountryId: String?
    let targetBlocId: String?
    let initiatedTurn: Int
    let completionTurn: Int
    let initiatedBy: String                 // Character ID or "player"

    var succeeded: Bool?
    var resultDescription: String?
    var effectsApplied: DiplomaticEffects?

    var isComplete: Bool {
        succeeded != nil
    }

    var isPending: Bool {
        !isComplete
    }

    init(
        actionId: String,
        actionName: String,
        targetCountryId: String? = nil,
        targetBlocId: String? = nil,
        initiatedTurn: Int,
        completionTurn: Int,
        initiatedBy: String
    ) {
        self.id = UUID().uuidString
        self.actionId = actionId
        self.actionName = actionName
        self.targetCountryId = targetCountryId
        self.targetBlocId = targetBlocId
        self.initiatedTurn = initiatedTurn
        self.completionTurn = completionTurn
        self.initiatedBy = initiatedBy
    }
}

// MARK: - Action Cooldown Tracker

/// Tracks cooldowns for diplomatic actions
struct ActionCooldownTracker: Codable {
    var cooldowns: [String: Int] = [:]      // actionId -> turn available

    mutating func setCooldown(actionId: String, availableTurn: Int) {
        cooldowns[actionId] = availableTurn
    }

    func isOnCooldown(actionId: String, currentTurn: Int) -> Bool {
        guard let availableTurn = cooldowns[actionId] else { return false }
        return currentTurn < availableTurn
    }

    func turnsRemaining(actionId: String, currentTurn: Int) -> Int {
        guard let availableTurn = cooldowns[actionId] else { return 0 }
        return max(0, availableTurn - currentTurn)
    }

    mutating func clearExpired(currentTurn: Int) {
        cooldowns = cooldowns.filter { $0.value > currentTurn }
    }
}

// MARK: - Default Actions

extension DiplomaticAction {

    /// All available diplomatic actions organized by tier
    static let allActions: [DiplomaticAction] = [
        // === TIER 1-2: OBSERVER/ANALYST ===

        DiplomaticAction(
            id: "request_briefing",
            name: "Request Country Briefing",
            description: "Request a detailed briefing on a specific country's situation.",
            category: .observer,
            targetType: .country,
            cooldownTurns: 0,
            baseSuccessChance: 100,
            riskLevel: .minimal,
            successEffects: DiplomaticEffects(standingChange: 1),
            iconName: "doc.text.magnifyingglass",
            actionVerb: "Request"
        ),

        DiplomaticAction(
            id: "attend_reception",
            name: "Attend Embassy Reception",
            description: "Attend a diplomatic reception to gather information and make contacts.",
            category: .observer,
            targetType: .country,
            cooldownTurns: 2,
            baseSuccessChance: 90,
            riskLevel: .minimal,
            successEffects: DiplomaticEffects(relationshipChange: 1, networkChange: 1),
            iconName: "person.3.fill",
            actionVerb: "Attend"
        ),

        DiplomaticAction(
            id: "draft_cable",
            name: "Draft Diplomatic Cable",
            description: "Draft a diplomatic cable recommending a course of action to superiors.",
            category: .analyst,
            minimumPositionIndex: 2,
            targetType: .country,
            cooldownTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .low,
            successEffects: DiplomaticEffects(standingChange: 2),
            iconName: "envelope.fill",
            actionVerb: "Draft"
        ),

        DiplomaticAction(
            id: "request_intel",
            name: "Request Intelligence Assessment",
            description: "Request an intelligence assessment on a foreign power's intentions.",
            category: .analyst,
            minimumPositionIndex: 2,
            targetType: .country,
            cooldownTurns: 2,
            baseSuccessChance: 80,
            riskLevel: .low,
            successEffects: DiplomaticEffects(intelligenceChange: 5),
            iconName: "eye.fill",
            actionVerb: "Request"
        ),

        // === TIER 3: DEPARTMENTAL ===

        DiplomaticAction(
            id: "propose_cultural_exchange",
            name: "Propose Cultural Exchange",
            description: "Propose a cultural exchange program with a foreign nation.",
            detailedDescription: "Submit a proposal for cultural exchange including student programs, artistic delegations, and scientific cooperation. Requires Standing Committee approval.",
            category: .departmental,
            targetType: .country,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 70,
            riskLevel: .low,
            requiresCommitteeApproval: true,
            successEffects: DiplomaticEffects(relationshipChange: 8, treasuryCost: 5, standingChange: 3),
            failureEffects: DiplomaticEffects(standingChange: -2),
            iconName: "theatermasks.fill",
            actionVerb: "Propose"
        ),

        DiplomaticAction(
            id: "lobby_trade_policy",
            name: "Lobby for Trade Policy",
            description: "Lobby the Standing Committee for a specific trade policy with a nation.",
            category: .departmental,
            targetType: .country,
            cooldownTurns: 3,
            baseSuccessChance: 60,
            riskLevel: .moderate,
            successEffects: DiplomaticEffects(standingChange: 5),
            failureEffects: DiplomaticEffects(standingChange: -3),
            iconName: "chart.bar.fill",
            actionVerb: "Lobby"
        ),

        DiplomaticAction(
            id: "meet_foreign_official",
            name: "Meet Foreign Official",
            description: "Arrange a meeting with a foreign diplomatic official.",
            category: .departmental,
            targetType: .country,
            cooldownTurns: 2,
            baseSuccessChance: 75,
            riskLevel: .low,
            successEffects: DiplomaticEffects(relationshipChange: 3, networkChange: 2),
            iconName: "person.2.fill",
            actionVerb: "Arrange"
        ),

        DiplomaticAction(
            id: "recommend_protest",
            name: "Recommend Diplomatic Protest",
            description: "Recommend that the Foreign Ministry issue a diplomatic protest.",
            category: .departmental,
            targetType: .country,
            cooldownTurns: 2,
            baseSuccessChance: 80,
            riskLevel: .moderate,
            successEffects: DiplomaticEffects(tensionChange: 5, standingChange: 2),
            iconName: "exclamationmark.bubble.fill",
            actionVerb: "Recommend"
        ),

        // === TIER 4: SENIOR ===

        DiplomaticAction(
            id: "negotiate_trade",
            name: "Negotiate Trade Agreement",
            description: "Directly negotiate trade terms with a foreign nation.",
            detailedDescription: "Lead negotiations for a trade agreement. Success improves economic ties and treasury income. Failure may strain relations.",
            category: .senior,
            targetType: .country,
            cooldownTurns: 5,
            executionTurns: 3,
            baseSuccessChance: 65,
            riskLevel: .moderate,
            requiresCommitteeApproval: true,
            successEffects: DiplomaticEffects(
                relationshipChange: 10,
                treasuryCost: -15,
                standingChange: 5,
                triggersTreaty: .tradeAgreement
            ),
            failureEffects: DiplomaticEffects(relationshipChange: -5, standingChange: -3),
            iconName: "dollarsign.circle.fill",
            actionVerb: "Negotiate"
        ),

        DiplomaticAction(
            id: "sponsor_treaty",
            name: "Sponsor Treaty Proposal",
            description: "Sponsor a treaty proposal in the Standing Committee.",
            category: .senior,
            targetType: .country,
            cooldownTurns: 8,
            executionTurns: 2,
            baseSuccessChance: 55,
            riskLevel: .high,
            requiresCommitteeApproval: true,
            successEffects: DiplomaticEffects(relationshipChange: 15, standingChange: 8),
            failureEffects: DiplomaticEffects(standingChange: -5),
            iconName: "doc.text.fill",
            actionVerb: "Sponsor"
        ),

        DiplomaticAction(
            id: "expand_embassy",
            name: "Approve Embassy Expansion",
            description: "Approve expansion of embassy staff and facilities in a country.",
            category: .senior,
            targetType: .country,
            cooldownTurns: 10,
            baseSuccessChance: 85,
            riskLevel: .low,
            successEffects: DiplomaticEffects(
                relationshipChange: 5,
                treasuryCost: 10,
                intelligenceChange: 10
            ),
            iconName: "building.columns.fill",
            actionVerb: "Approve"
        ),

        DiplomaticAction(
            id: "authorize_backchannel",
            name: "Authorize Back-Channel",
            description: "Authorize secret back-channel communications with foreign officials.",
            category: .senior,
            targetType: .country,
            cooldownTurns: 5,
            baseSuccessChance: 70,
            riskLevel: .high,
            successEffects: DiplomaticEffects(relationshipChange: 5, intelligenceChange: 8),
            failureEffects: DiplomaticEffects(relationshipChange: -10, tensionChange: 10),
            iconName: "lock.fill",
            actionVerb: "Authorize"
        ),

        // === TIER 5-6: EXECUTIVE ===

        DiplomaticAction(
            id: "propose_defense_pact",
            name: "Propose Mutual Defense Pact",
            description: "Propose a mutual defense treaty with an allied nation.",
            detailedDescription: "Initiate negotiations for a mutual defense pact. This is a major commitment that binds the nation to military cooperation.",
            category: .executive,
            targetType: .country,
            cooldownTurns: 15,
            executionTurns: 5,
            baseSuccessChance: 50,
            riskLevel: .high,
            requiresCommitteeApproval: true,
            successEffects: DiplomaticEffects(
                relationshipChange: 25,
                blocRelationshipChange: -10,
                tensionChange: 15,
                standingChange: 10,
                triggersTreaty: .mutualDefense
            ),
            failureEffects: DiplomaticEffects(relationshipChange: -10, standingChange: -5),
            iconName: "shield.fill",
            actionVerb: "Propose"
        ),

        DiplomaticAction(
            id: "direct_espionage",
            name: "Direct Espionage Operations",
            description: "Direct intelligence operations against a foreign target.",
            category: .executive,
            targetType: .country,
            cooldownTurns: 3,
            baseSuccessChance: 60,
            riskLevel: .high,
            successEffects: DiplomaticEffects(intelligenceChange: 15),
            failureEffects: DiplomaticEffects(
                relationshipChange: -15,
                tensionChange: 20,
                counterIntelChange: 10
            ),
            iconName: "eye.trianglebadge.exclamationmark.fill",
            actionVerb: "Direct",
            requiredTrack: "security"
        ),

        DiplomaticAction(
            id: "issue_ultimatum",
            name: "Issue Diplomatic Ultimatum",
            description: "Issue an ultimatum demanding specific concessions from a nation.",
            category: .executive,
            targetType: .country,
            cooldownTurns: 10,
            executionTurns: 1,
            baseSuccessChance: 40,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: DiplomaticEffects(
                relationshipChange: -20,
                tensionChange: 30,
                standingChange: 10
            ),
            failureEffects: DiplomaticEffects(
                relationshipChange: -30,
                tensionChange: 40,
                standingChange: -10
            ),
            iconName: "exclamationmark.triangle.fill",
            actionVerb: "Issue"
        ),

        DiplomaticAction(
            id: "negotiate_aid",
            name: "Negotiate Aid Package",
            description: "Negotiate foreign aid to give or receive from another nation.",
            category: .executive,
            targetType: .country,
            cooldownTurns: 8,
            executionTurns: 2,
            baseSuccessChance: 70,
            riskLevel: .moderate,
            requiresCommitteeApproval: true,
            successEffects: DiplomaticEffects(
                relationshipChange: 15,
                blocRelationshipChange: 5,
                treasuryCost: 20,
                triggersTreaty: .aidPackage
            ),
            iconName: "gift.fill",
            actionVerb: "Negotiate"
        ),

        DiplomaticAction(
            id: "recall_ambassador",
            name: "Recall Ambassador",
            description: "Recall the ambassador from a foreign nation as a diplomatic signal.",
            category: .executive,
            targetType: .country,
            cooldownTurns: 5,
            baseSuccessChance: 100,
            riskLevel: .high,
            successEffects: DiplomaticEffects(
                relationshipChange: -20,
                tensionChange: 15,
                intelligenceChange: -10
            ),
            iconName: "airplane.departure",
            actionVerb: "Recall"
        ),

        DiplomaticAction(
            id: "expel_diplomats",
            name: "Expel Foreign Diplomats",
            description: "Expel diplomats from a foreign nation, often as counterintelligence measure.",
            category: .executive,
            targetType: .country,
            cooldownTurns: 8,
            baseSuccessChance: 100,
            riskLevel: .high,
            successEffects: DiplomaticEffects(
                relationshipChange: -25,
                tensionChange: 20,
                counterIntelChange: -20
            ),
            iconName: "person.fill.xmark",
            actionVerb: "Expel"
        ),

        // === TIER 7-8: SUPREME AUTHORITY ===

        DiplomaticAction(
            id: "summit_diplomacy",
            name: "Summit Diplomacy",
            description: "Conduct direct leader-to-leader summit negotiations.",
            detailedDescription: "As General Secretary, personally negotiate with foreign leaders. High stakes but potential for breakthrough agreements.",
            category: .supreme,
            targetType: .country,
            cooldownTurns: 20,
            executionTurns: 3,
            baseSuccessChance: 60,
            riskLevel: .extreme,
            canBeDecree: true,
            successEffects: DiplomaticEffects(
                relationshipChange: 30,
                tensionChange: -20,
                standingChange: 15
            ),
            failureEffects: DiplomaticEffects(
                relationshipChange: -15,
                tensionChange: 10,
                standingChange: -10
            ),
            iconName: "person.2.wave.2.fill",
            actionVerb: "Conduct"
        ),

        DiplomaticAction(
            id: "declare_sanctions",
            name: "Declare Economic Sanctions",
            description: "Impose comprehensive economic sanctions on a nation.",
            category: .supreme,
            targetType: .country,
            cooldownTurns: 15,
            baseSuccessChance: 100,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: DiplomaticEffects(
                relationshipChange: -40,
                blocRelationshipChange: 5,
                tensionChange: 35,
                createsFlag: "sanctions_active"
            ),
            iconName: "xmark.seal.fill",
            actionVerb: "Declare"
        ),

        DiplomaticAction(
            id: "authorize_intervention",
            name: "Authorize Military Intervention",
            description: "Authorize military intervention in a foreign conflict.",
            detailedDescription: "Commit military forces to a proxy war or direct intervention. Extremely high stakes with potential for escalation.",
            category: .supreme,
            targetType: .country,
            cooldownTurns: 25,
            executionTurns: 5,
            baseSuccessChance: 50,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: DiplomaticEffects(
                relationshipChange: -50,
                tensionChange: 50,
                treasuryCost: 50,
                standingChange: 15,
                createsFlag: "military_intervention"
            ),
            failureEffects: DiplomaticEffects(
                relationshipChange: -60,
                tensionChange: 60,
                treasuryCost: 75,
                standingChange: -20
            ),
            iconName: "airplane.circle.fill",
            actionVerb: "Authorize"
        ),

        DiplomaticAction(
            id: "nuclear_posturing",
            name: "Nuclear Posturing",
            description: "Signal nuclear readiness as a diplomatic threat.",
            detailedDescription: "Order increased nuclear readiness or make public statements about nuclear capability. Extreme escalation risk.",
            category: .supreme,
            targetType: .country,
            cooldownTurns: 30,
            baseSuccessChance: 80,
            riskLevel: .extreme,
            canBeDecree: true,
            successEffects: DiplomaticEffects(
                relationshipChange: -30,
                tensionChange: 50,
                standingChange: -5,
                createsFlag: "nuclear_alert"
            ),
            iconName: "bolt.trianglebadge.exclamationmark.fill",
            actionVerb: "Order"
        ),

        DiplomaticAction(
            id: "recognize_government",
            name: "Recognize New Government",
            description: "Formally recognize a new or rival government in a country.",
            category: .supreme,
            targetType: .country,
            cooldownTurns: 20,
            baseSuccessChance: 100,
            riskLevel: .high,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: DiplomaticEffects(
                relationshipChange: 40,
                blocRelationshipChange: -15,
                tensionChange: 20
            ),
            iconName: "flag.fill",
            actionVerb: "Recognize"
        ),

        DiplomaticAction(
            id: "abrogate_treaty",
            name: "Abrogate Treaty",
            description: "Unilaterally withdraw from an existing treaty.",
            category: .supreme,
            targetType: .treaty,
            cooldownTurns: 15,
            baseSuccessChance: 100,
            riskLevel: .high,
            canBeDecree: true,
            successEffects: DiplomaticEffects(
                relationshipChange: -35,
                blocRelationshipChange: -10,
                tensionChange: 25
            ),
            iconName: "doc.text.fill.viewfinder",
            actionVerb: "Abrogate"
        )
    ]

    /// Get actions available at a specific position level
    static func availableActions(forPositionIndex positionIndex: Int) -> [DiplomaticAction] {
        allActions.filter { $0.minimumPositionIndex <= positionIndex }
    }

    /// Get actions by category
    static func actions(inCategory category: DiplomaticActionCategory) -> [DiplomaticAction] {
        allActions.filter { $0.category == category }
    }

    /// Get a specific action by ID
    static func action(withId id: String) -> DiplomaticAction? {
        allActions.first { $0.id == id }
    }
}
