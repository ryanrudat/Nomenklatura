//
//  SecurityAction.swift
//  Nomenklatura
//
//  Position-gated security actions modeled on the Chinese Communist Party's
//  Central Commission for Discipline Inspection (CCDI) structure.
//
//  Key CCP concepts implemented:
//  - Rank-gated targets (can't investigate seniors without approval)
//  - Shuanggui/Liuzhi detention (designated location, no lawyers, 6 months)
//  - Vertical management (central teams inspect lower levels)
//  - Chain investigations (confessions implicate others)
//

import Foundation

// MARK: - Security Action Category

/// Security action tiers following CCP CCDI hierarchy
enum SecurityActionCategory: String, Codable, CaseIterable {
    case operative      // Position 1-2: Local Discipline Inspector
    case investigator   // Position 2-3: Case Handler
    case caseOfficer    // Position 3-4: Section Chief
    case directorate    // Position 4-5: Department Director
    case command        // Position 5-6: CCDI Standing Committee
    case director       // Position 7-8: CCDI/CPLAC Secretary

    var displayName: String {
        switch self {
        case .operative: return "Operative"
        case .investigator: return "Investigator"
        case .caseOfficer: return "Case Officer"
        case .directorate: return "Directorate"
        case .command: return "Command"
        case .director: return "Director"
        }
    }

    var ccpEquivalent: String {
        switch self {
        case .operative: return "Local Discipline Inspector"
        case .investigator: return "Case Handler"
        case .caseOfficer: return "Section Chief"
        case .directorate: return "Department Director"
        case .command: return "CCDI Standing Committee"
        case .director: return "CCDI Secretary"
        }
    }

    var minimumPositionIndex: Int {
        switch self {
        case .operative: return 1
        case .investigator: return 2
        case .caseOfficer: return 3
        case .directorate: return 4
        case .command: return 5
        case .director: return 7
        }
    }

    var color: String {
        switch self {
        case .operative: return "808080"      // Gray
        case .investigator: return "607D8B"   // Blue-gray
        case .caseOfficer: return "1976D2"    // Blue
        case .directorate: return "7B1FA2"    // Purple
        case .command: return "C62828"        // Red
        case .director: return "FFD700"       // Gold
        }
    }
}

// MARK: - Security Target Type

/// What can be targeted by a security action
enum SecurityTargetType: String, Codable {
    case character      // Target a specific NPC
    case faction        // Target entire faction
    case department     // Target bureau/track members
    case sector         // Target purge sector (partyApparatus, military, etc.)
    case country        // Counter-intel against foreign power
    case none           // No target required
}

// MARK: - Security Risk Level

/// Risk level affecting success chance and blowback
enum SecurityRiskLevel: String, Codable, CaseIterable {
    case minimal        // +5% success, low blowback
    case low            // No modifier
    case moderate       // -5% success
    case high           // -10% success, significant blowback if failed
    case extreme        // -15% success, severe consequences

    var successModifier: Int {
        switch self {
        case .minimal: return 5
        case .low: return 0
        case .moderate: return -5
        case .high: return -10
        case .extreme: return -15
        }
    }

    var displayName: String {
        switch self {
        case .minimal: return "Minimal Risk"
        case .low: return "Low Risk"
        case .moderate: return "Moderate Risk"
        case .high: return "High Risk"
        case .extreme: return "Extreme Risk"
        }
    }
}

// MARK: - Security Effects

/// Effects applied when a security action succeeds or fails
struct SecurityEffects: Codable {
    // Target effects
    var suspicionIncrease: Int = 0          // Target's suspicion level (+)
    var evidenceGathered: Int = 0           // Evidence against target (0-100)
    var loyaltyRevealed: Bool = false       // Learn target's true loyalty
    var targetDemoted: Bool = false         // Target loses position
    var targetDetained: Bool = false        // Target enters shuanggui
    var targetExecuted: Bool = false        // Target dies (extreme)
    var targetDismissed: Bool = false       // Target removed from position

    // Player effects
    var standingChange: Int = 0
    var networkChange: Int = 0
    var patronFavorChange: Int = 0
    var corruptionRisk: Int = 0             // Risk of becoming target yourself

    // Game state effects
    var stabilityChange: Int = 0
    var eliteLoyaltyChange: Int = 0         // Fear/intimidation
    var popularSupportChange: Int = 0
    var internationalStandingChange: Int = 0

    // Triggers
    var initiatesShuanggui: Bool = false    // Begin CCP-style detention
    var initiatesTrial: Bool = false        // Begin show trial
    var createsFlag: String? = nil
    var removesFlag: String? = nil
    var triggersEvent: String? = nil
    var implicatesOthers: Bool = false      // Confession chains to new targets

    init(
        suspicionIncrease: Int = 0,
        evidenceGathered: Int = 0,
        loyaltyRevealed: Bool = false,
        targetDemoted: Bool = false,
        targetDetained: Bool = false,
        targetExecuted: Bool = false,
        targetDismissed: Bool = false,
        standingChange: Int = 0,
        networkChange: Int = 0,
        patronFavorChange: Int = 0,
        corruptionRisk: Int = 0,
        stabilityChange: Int = 0,
        eliteLoyaltyChange: Int = 0,
        popularSupportChange: Int = 0,
        internationalStandingChange: Int = 0,
        initiatesShuanggui: Bool = false,
        initiatesTrial: Bool = false,
        createsFlag: String? = nil,
        removesFlag: String? = nil,
        triggersEvent: String? = nil,
        implicatesOthers: Bool = false
    ) {
        self.suspicionIncrease = suspicionIncrease
        self.evidenceGathered = evidenceGathered
        self.loyaltyRevealed = loyaltyRevealed
        self.targetDemoted = targetDemoted
        self.targetDetained = targetDetained
        self.targetExecuted = targetExecuted
        self.targetDismissed = targetDismissed
        self.standingChange = standingChange
        self.networkChange = networkChange
        self.patronFavorChange = patronFavorChange
        self.corruptionRisk = corruptionRisk
        self.stabilityChange = stabilityChange
        self.eliteLoyaltyChange = eliteLoyaltyChange
        self.popularSupportChange = popularSupportChange
        self.internationalStandingChange = internationalStandingChange
        self.initiatesShuanggui = initiatesShuanggui
        self.initiatesTrial = initiatesTrial
        self.createsFlag = createsFlag
        self.removesFlag = removesFlag
        self.triggersEvent = triggersEvent
        self.implicatesOthers = implicatesOthers
    }
}

// MARK: - Security Action

/// A position-gated security action following CCP CCDI structure
struct SecurityAction: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let detailedDescription: String
    let iconName: String
    let actionVerb: String

    let category: SecurityActionCategory
    var minimumPositionIndex: Int
    let targetType: SecurityTargetType
    let requiredTrack: String?              // "securityServices" for some actions

    // CCP rank-gating: Maximum target position without approval
    let maxTargetPosition: Int?             // Highest position you can target freely
    let requiresApprovalAbove: Int?         // Targets above this need Standing Committee

    let cooldownTurns: Int
    let executionTurns: Int                 // Multi-turn operations (shuanggui lasts weeks)
    let baseSuccessChance: Int
    let riskLevel: SecurityRiskLevel

    let requiresCommitteeApproval: Bool
    let canBeDecree: Bool                   // General Secretary can bypass committee

    let successEffects: SecurityEffects
    let failureEffects: SecurityEffects

    // Computed properties
    var effectiveMinimumPosition: Int {
        return max(minimumPositionIndex, category.minimumPositionIndex)
    }

    init(
        id: String,
        name: String,
        description: String,
        detailedDescription: String,
        iconName: String,
        actionVerb: String,
        category: SecurityActionCategory,
        minimumPositionIndex: Int? = nil,
        targetType: SecurityTargetType,
        requiredTrack: String? = nil,
        maxTargetPosition: Int? = nil,
        requiresApprovalAbove: Int? = nil,
        cooldownTurns: Int = 1,
        executionTurns: Int = 0,
        baseSuccessChance: Int = 80,
        riskLevel: SecurityRiskLevel = .low,
        requiresCommitteeApproval: Bool = false,
        canBeDecree: Bool = false,
        successEffects: SecurityEffects = SecurityEffects(),
        failureEffects: SecurityEffects = SecurityEffects()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.detailedDescription = detailedDescription
        self.iconName = iconName
        self.actionVerb = actionVerb
        self.category = category
        self.minimumPositionIndex = minimumPositionIndex ?? category.minimumPositionIndex
        self.targetType = targetType
        self.requiredTrack = requiredTrack
        self.maxTargetPosition = maxTargetPosition
        self.requiresApprovalAbove = requiresApprovalAbove
        self.cooldownTurns = cooldownTurns
        self.executionTurns = executionTurns
        self.baseSuccessChance = baseSuccessChance
        self.riskLevel = riskLevel
        self.requiresCommitteeApproval = requiresCommitteeApproval
        self.canBeDecree = canBeDecree
        self.successEffects = successEffects
        self.failureEffects = failureEffects
    }
}

// MARK: - Security Action Record

/// Tracks pending and completed security actions
struct SecurityActionRecord: Identifiable, Codable {
    let id: UUID
    let actionId: String
    let initiatedTurn: Int
    let completionTurn: Int
    let initiatedBy: String                 // "player" or character ID
    let targetCharacterId: String?
    let targetFactionId: String?
    let targetDepartment: String?

    var status: SecurityActionStatus
    var successChance: Int
    var result: SecurityActionResult?

    enum SecurityActionStatus: String, Codable {
        case pending
        case inProgress
        case awaitingApproval
        case completed
        case cancelled
        case blocked                        // Patron intervened
    }

    struct SecurityActionResult: Codable {
        let succeeded: Bool
        let roll: Int
        let description: String
        let implicatedCharacterIds: [String]
    }
}

// MARK: - Shuanggui Detention (CCP-Accurate)

/// CCP-style "double designation" detention following CCDI practices
struct ShuangguiDetention: Codable, Identifiable {
    let id: UUID
    let targetCharacterId: String
    let targetName: String
    let targetPosition: Int
    let initiatedByCharacterId: String
    let initiatedByName: String
    let initiatedTurn: Int

    var phase: ShuangguiPhase
    var turnsInDetention: Int               // Each turn ≈ 2 weeks
    var evidenceAccumulated: Int            // 0-100
    var confessionObtained: Bool
    var confessionType: ConfessionType?
    var implicatedCharacterIds: [String]    // Chain investigations

    // CCP-accurate details
    var location: ShuangguiLocation
    var accompanyingProtectors: Int         // 6-9 guards on 8-hour rotations
    var suicideWatchActive: Bool            // Always true in real CCDI
    var lawyerAccessDenied: Bool            // Always true
    var familyNotified: Bool                // Usually false until conclusion

    // Outcome
    var outcome: ShuangguiOutcome?
    var referredToTrial: Bool

    init(
        targetCharacterId: String,
        targetName: String,
        targetPosition: Int,
        initiatedByCharacterId: String,
        initiatedByName: String,
        turn: Int
    ) {
        self.id = UUID()
        self.targetCharacterId = targetCharacterId
        self.targetName = targetName
        self.targetPosition = targetPosition
        self.initiatedByCharacterId = initiatedByCharacterId
        self.initiatedByName = initiatedByName
        self.initiatedTurn = turn

        self.phase = .isolation
        self.turnsInDetention = 0
        self.evidenceAccumulated = 0
        self.confessionObtained = false
        self.confessionType = nil
        self.implicatedCharacterIds = []

        // CCP-accurate defaults
        self.location = ShuangguiLocation.allCases.randomElement() ?? .guestHouse
        self.accompanyingProtectors = Int.random(in: 6...9)
        self.suicideWatchActive = true
        self.lawyerAccessDenied = true
        self.familyNotified = false

        self.outcome = nil
        self.referredToTrial = false
    }

    /// Maximum turns before resolution required (CCP: ~6 months = ~12 turns)
    var maxDetentionTurns: Int { 12 }

    /// Whether detention has exceeded normal limits
    var isOverdue: Bool { turnsInDetention > maxDetentionTurns }
}

enum ShuangguiPhase: String, Codable, CaseIterable {
    case isolation          // Initial detention, psychological pressure (1-2 turns)
    case interrogation      // Active questioning (2-4 turns)
    case confession         // Seeking admission (1-3 turns)
    case documentation      // Recording evidence (1-2 turns)
    case referral           // Preparing for trial or release (1 turn)

    var displayName: String {
        switch self {
        case .isolation: return "Isolation"
        case .interrogation: return "Interrogation"
        case .confession: return "Confession Extraction"
        case .documentation: return "Documentation"
        case .referral: return "Case Referral"
        }
    }

    var description: String {
        switch self {
        case .isolation:
            return "Subject is isolated from outside contact. Psychological pressure applied."
        case .interrogation:
            return "Active questioning by discipline inspectors. Evidence presented."
        case .confession:
            return "Subject is encouraged to confess and implicate others."
        case .documentation:
            return "Statements recorded. Evidence compiled for prosecution."
        case .referral:
            return "Case prepared for show trial or administrative disposition."
        }
    }
}

enum ShuangguiLocation: String, Codable, CaseIterable {
    case guestHouse         // "Provincial Guest House" - common euphemism
    case trainingCenter     // "Party School Training Center"
    case sanitarium         // "Rest and Recovery Facility"
    case hotelAnnex         // "Conference Center Annex"
    case undisclosed        // Location not specified

    var displayName: String {
        switch self {
        case .guestHouse: return "Provincial Guest House"
        case .trainingCenter: return "Party School Training Center"
        case .sanitarium: return "Rest and Recovery Facility"
        case .hotelAnnex: return "Conference Center Annex"
        case .undisclosed: return "Undisclosed Location"
        }
    }
}

// Note: ConfessionType is defined in HistoricalMechanics.swift
// Using that existing enum for shuanggui confessions

enum ShuangguiOutcome: String, Codable {
    case cleared            // Released, no findings (rare)
    case warned             // Released with warning, career damaged
    case demoted            // Loses position levels
    case expelled           // Expelled from Party
    case referredToTrial    // Goes to show trial
    case diedInDetention    // "Suicide" or "accident" (extreme)
    case imprisoned         // Administrative detention without trial
}

// MARK: - All Security Actions

extension SecurityAction {

    /// All 29 position-gated security actions following CCP CCDI structure
    static let allActions: [SecurityAction] = [
        // TIER 1-2: Operative Actions (Local Discipline Inspector)
        SecurityAction(
            id: "read_security_briefing",
            name: "Read Security Briefing",
            description: "Review filtered intelligence reports",
            detailedDescription: "Access intelligence briefings filtered for your security clearance level. Junior operatives receive only sanitized summaries.",
            iconName: "doc.text.magnifyingglass",
            actionVerb: "Read",
            category: .operative,
            targetType: .none,
            cooldownTurns: 0,
            baseSuccessChance: 100,
            riskLevel: .minimal,
            successEffects: SecurityEffects(networkChange: 1)
        ),

        SecurityAction(
            id: "conduct_surveillance",
            name: "Conduct Surveillance",
            description: "Watch a target for suspicious activity",
            detailedDescription: "Assign operatives to monitor a target's movements, contacts, and behavior. Results reported to superiors.",
            iconName: "eye.fill",
            actionVerb: "Surveil",
            category: .operative,
            targetType: .character,
            maxTargetPosition: 3,
            cooldownTurns: 1,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .low,
            successEffects: SecurityEffects(suspicionIncrease: 5, evidenceGathered: 10, networkChange: 2),
            failureEffects: SecurityEffects(standingChange: -3)
        ),

        SecurityAction(
            id: "gather_informant_tips",
            name: "Gather Informant Tips",
            description: "Collect rumors and gossip from network",
            detailedDescription: "Activate your network of informants to gather intelligence on suspicious activities within the Party.",
            iconName: "person.wave.2.fill",
            actionVerb: "Gather",
            category: .operative,
            targetType: .none,
            cooldownTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .minimal,
            successEffects: SecurityEffects(networkChange: 3)
        ),

        SecurityAction(
            id: "file_suspicious_activity",
            name: "File Suspicious Activity Report",
            description: "Report concerns to superiors",
            detailedDescription: "Submit a formal report on observed irregularities. May trigger investigation by senior officers.",
            iconName: "exclamationmark.triangle.fill",
            actionVerb: "File",
            category: .operative,
            targetType: .character,
            maxTargetPosition: 4,
            cooldownTurns: 0,
            baseSuccessChance: 100,
            riskLevel: .low,
            successEffects: SecurityEffects(suspicionIncrease: 10, standingChange: 2),
            failureEffects: SecurityEffects()
        ),

        // TIER 2-3: Investigator Actions (Case Handler)
        SecurityAction(
            id: "open_case_file",
            name: "Open Case File",
            description: "Start formal investigation on target",
            detailedDescription: "Begin a formal discipline inspection case. Creates official record and authorizes preliminary evidence gathering.",
            iconName: "folder.badge.plus",
            actionVerb: "Open",
            category: .investigator,
            targetType: .character,
            maxTargetPosition: 4,
            cooldownTurns: 2,
            baseSuccessChance: 75,
            riskLevel: .low,
            successEffects: SecurityEffects(suspicionIncrease: 15, evidenceGathered: 15, standingChange: 3),
            failureEffects: SecurityEffects(standingChange: -5)
        ),

        SecurityAction(
            id: "request_surveillance_warrant",
            name: "Request Surveillance Warrant",
            description: "Get approval for extended monitoring",
            detailedDescription: "Submit request to superiors for authorized surveillance. Enables long-term monitoring and communication intercepts.",
            iconName: "checkmark.seal.fill",
            actionVerb: "Request",
            category: .investigator,
            targetType: .character,
            maxTargetPosition: 4,
            cooldownTurns: 2,
            baseSuccessChance: 70,
            riskLevel: .low,
            successEffects: SecurityEffects(suspicionIncrease: 5, networkChange: 3),
            failureEffects: SecurityEffects(standingChange: -3)
        ),

        SecurityAction(
            id: "interview_associates",
            name: "Interview Associates",
            description: "Question target's colleagues",
            detailedDescription: "Conduct interviews with the target's known associates. May reveal incriminating information or additional suspects.",
            iconName: "person.2.fill",
            actionVerb: "Interview",
            category: .investigator,
            targetType: .character,
            maxTargetPosition: 4,
            cooldownTurns: 1,
            baseSuccessChance: 65,
            riskLevel: .moderate,
            successEffects: SecurityEffects(evidenceGathered: 20, loyaltyRevealed: true),
            failureEffects: SecurityEffects(standingChange: -5, corruptionRisk: 5)
        ),

        SecurityAction(
            id: "search_personnel_records",
            name: "Search Personnel Records",
            description: "Check archives for irregularities",
            detailedDescription: "Review official personnel files, travel records, and financial declarations for inconsistencies.",
            iconName: "doc.text.below.ecg",
            actionVerb: "Search",
            category: .investigator,
            targetType: .character,
            maxTargetPosition: 5,
            cooldownTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .low,
            successEffects: SecurityEffects(evidenceGathered: 15),
            failureEffects: SecurityEffects()
        ),

        // TIER 3-4: Case Officer Actions (Section Chief)
        SecurityAction(
            id: "launch_formal_investigation",
            name: "Launch Formal Investigation",
            description: "Full evidence gathering operation",
            detailedDescription: "Initiate a comprehensive discipline inspection with full investigative powers. Target is now formally under investigation.",
            iconName: "magnifyingglass.circle.fill",
            actionVerb: "Launch",
            category: .caseOfficer,
            targetType: .character,
            maxTargetPosition: 4,
            requiresApprovalAbove: 4,
            cooldownTurns: 3,
            executionTurns: 2,
            baseSuccessChance: 60,
            riskLevel: .moderate,
            successEffects: SecurityEffects(suspicionIncrease: 25, evidenceGathered: 30, standingChange: 5),
            failureEffects: SecurityEffects(standingChange: -10, corruptionRisk: 10)
        ),

        SecurityAction(
            id: "authorize_communications_intercept",
            name: "Authorize Communications Intercept",
            description: "Tap phones, read mail",
            detailedDescription: "Order the interception of target's communications including phone calls, mail, and electronic messages.",
            iconName: "phone.arrow.down.left.fill",
            actionVerb: "Authorize",
            category: .caseOfficer,
            targetType: .character,
            maxTargetPosition: 4,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 70,
            riskLevel: .moderate,
            successEffects: SecurityEffects(evidenceGathered: 25, networkChange: 5),
            failureEffects: SecurityEffects(standingChange: -5)
        ),

        SecurityAction(
            id: "recruit_informant",
            name: "Recruit Informant",
            description: "Turn someone into an asset",
            detailedDescription: "Attempt to recruit a target as an informant using leverage, ideological appeal, or coercion.",
            iconName: "person.badge.key.fill",
            actionVerb: "Recruit",
            category: .caseOfficer,
            targetType: .character,
            maxTargetPosition: 4,
            cooldownTurns: 3,
            baseSuccessChance: 50,
            riskLevel: .high,
            successEffects: SecurityEffects(standingChange: 5, networkChange: 10),
            failureEffects: SecurityEffects(standingChange: -10, corruptionRisk: 15)
        ),

        SecurityAction(
            id: "request_shuanggui",
            name: "Request Shuanggui Detention",
            description: "Submit detention request to superiors",
            detailedDescription: "Request authorization to detain target under shuanggui ('double designation') - designated place at designated time.",
            iconName: "lock.rectangle.fill",
            actionVerb: "Request",
            category: .caseOfficer,
            targetType: .character,
            maxTargetPosition: 4,
            requiresApprovalAbove: 4,
            cooldownTurns: 3,
            baseSuccessChance: 65,
            riskLevel: .high,
            successEffects: SecurityEffects(standingChange: 5, eliteLoyaltyChange: 5, initiatesShuanggui: true),
            failureEffects: SecurityEffects(standingChange: -15)
        ),

        SecurityAction(
            id: "conduct_interrogation",
            name: "Conduct Interrogation",
            description: "Question detained subject",
            detailedDescription: "Personally conduct interrogation of a detained subject. Results depend on subject's resistance and your methods.",
            iconName: "person.crop.circle.badge.questionmark.fill",
            actionVerb: "Interrogate",
            category: .caseOfficer,
            targetType: .character,
            requiredTrack: "securityServices",
            cooldownTurns: 1,
            baseSuccessChance: 60,
            riskLevel: .moderate,
            successEffects: SecurityEffects(evidenceGathered: 25, implicatesOthers: true),
            failureEffects: SecurityEffects(standingChange: -5, internationalStandingChange: -2)
        ),

        // TIER 4-5: Directorate Actions (Department Director)
        SecurityAction(
            id: "approve_mass_surveillance",
            name: "Approve Mass Surveillance",
            description: "Monitor entire faction or department",
            detailedDescription: "Authorize comprehensive surveillance of all members of a faction or bureau. Generates broad intelligence.",
            iconName: "eye.trianglebadge.exclamationmark.fill",
            actionVerb: "Approve",
            category: .directorate,
            targetType: .faction,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 80,
            riskLevel: .moderate,
            successEffects: SecurityEffects(networkChange: 15, stabilityChange: -3),
            failureEffects: SecurityEffects(standingChange: -10, popularSupportChange: -5)
        ),

        SecurityAction(
            id: "order_shuanggui",
            name: "Order Shuanggui Detention",
            description: "Detain without further approval",
            detailedDescription: "Exercise authority to detain targets up to Position 4 under shuanggui without seeking additional approval.",
            iconName: "lock.shield.fill",
            actionVerb: "Order",
            category: .directorate,
            targetType: .character,
            maxTargetPosition: 4,
            cooldownTurns: 2,
            baseSuccessChance: 100,
            riskLevel: .moderate,
            successEffects: SecurityEffects(targetDetained: true, eliteLoyaltyChange: 10, initiatesShuanggui: true),
            failureEffects: SecurityEffects()
        ),

        SecurityAction(
            id: "authorize_enhanced_interrogation",
            name: "Authorize Enhanced Interrogation",
            description: "Approve 'special measures'",
            detailedDescription: "Authorize use of enhanced interrogation techniques on detained subjects. Effective but carries international risk.",
            iconName: "bolt.shield.fill",
            actionVerb: "Authorize",
            category: .directorate,
            targetType: .character,
            requiredTrack: "securityServices",
            cooldownTurns: 2,
            baseSuccessChance: 90,
            riskLevel: .high,
            successEffects: SecurityEffects(evidenceGathered: 40, eliteLoyaltyChange: 5, implicatesOthers: true),
            failureEffects: SecurityEffects(popularSupportChange: -5, internationalStandingChange: -10)
        ),

        SecurityAction(
            id: "recommend_prosecution",
            name: "Recommend Prosecution",
            description: "Refer case to show trial",
            detailedDescription: "Submit formal recommendation that detained subject be referred to show trial. Requires sufficient evidence.",
            iconName: "building.columns.fill",
            actionVerb: "Recommend",
            category: .directorate,
            targetType: .character,
            cooldownTurns: 3,
            baseSuccessChance: 75,
            riskLevel: .moderate,
            successEffects: SecurityEffects(standingChange: 10, initiatesTrial: true),
            failureEffects: SecurityEffects(standingChange: -10)
        ),

        SecurityAction(
            id: "dispatch_supervision_team",
            name: "Dispatch Supervision Team",
            description: "Send inspectors to lower levels",
            detailedDescription: "Deploy central discipline inspection team to provincial/municipal level. CCP 'vertical management' in action.",
            iconName: "arrow.down.circle.fill",
            actionVerb: "Dispatch",
            category: .directorate,
            targetType: .department,
            cooldownTurns: 4,
            executionTurns: 2,
            baseSuccessChance: 85,
            riskLevel: .low,
            successEffects: SecurityEffects(evidenceGathered: 20, networkChange: 10, stabilityChange: 3),
            failureEffects: SecurityEffects(standingChange: -5)
        ),

        SecurityAction(
            id: "plant_evidence",
            name: "Plant Evidence",
            description: "Frame a target",
            detailedDescription: "Fabricate or plant incriminating evidence against a target. High risk if discovered.",
            iconName: "exclamationmark.shield.fill",
            actionVerb: "Plant",
            category: .directorate,
            targetType: .character,
            maxTargetPosition: 5,
            cooldownTurns: 5,
            baseSuccessChance: 40,
            riskLevel: .extreme,
            successEffects: SecurityEffects(evidenceGathered: 50, standingChange: 5),
            failureEffects: SecurityEffects(standingChange: -30, corruptionRisk: 30)
        ),

        SecurityAction(
            id: "dismiss_subordinate",
            name: "Dismiss Subordinate",
            description: "Remove an official from position",
            detailedDescription: "Exercise authority to remove a subordinate official from their position for disciplinary reasons.",
            iconName: "person.crop.circle.badge.minus",
            actionVerb: "Dismiss",
            category: .directorate,
            targetType: .character,
            maxTargetPosition: 3,
            cooldownTurns: 2,
            baseSuccessChance: 90,
            riskLevel: .moderate,
            successEffects: SecurityEffects(targetDismissed: true, standingChange: 3, eliteLoyaltyChange: 5),
            failureEffects: SecurityEffects(standingChange: -10)
        ),

        // TIER 5-6: Command Actions (CCDI Standing Committee Level)
        SecurityAction(
            id: "initiate_senior_investigation",
            name: "Initiate Senior Investigation",
            description: "Investigate Position 5-6 officials",
            detailedDescription: "Launch formal investigation against senior officials. Requires Standing Committee approval for targets at Position 5+.",
            iconName: "person.badge.shield.checkmark.fill",
            actionVerb: "Initiate",
            category: .command,
            targetType: .character,
            maxTargetPosition: 6,
            requiresApprovalAbove: 4,
            cooldownTurns: 5,
            executionTurns: 3,
            baseSuccessChance: 55,
            riskLevel: .high,
            requiresCommitteeApproval: true,
            successEffects: SecurityEffects(suspicionIncrease: 30, evidenceGathered: 35, standingChange: 15, eliteLoyaltyChange: 15),
            failureEffects: SecurityEffects(standingChange: -20, corruptionRisk: 20)
        ),

        SecurityAction(
            id: "prepare_show_trial",
            name: "Prepare Show Trial",
            description: "Begin formal trial proceedings",
            detailedDescription: "Initiate preparations for a public show trial. Requires sufficient evidence and political approval.",
            iconName: "building.columns.circle.fill",
            actionVerb: "Prepare",
            category: .command,
            targetType: .character,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 70,
            riskLevel: .high,
            requiresCommitteeApproval: true,
            successEffects: SecurityEffects(standingChange: 10, eliteLoyaltyChange: 20, initiatesTrial: true),
            failureEffects: SecurityEffects(standingChange: -15, internationalStandingChange: -5)
        ),

        SecurityAction(
            id: "issue_arrest_warrant",
            name: "Issue Arrest Warrant",
            description: "Immediate detention authority",
            detailedDescription: "Issue warrant for immediate arrest and detention. Target is taken into custody without warning.",
            iconName: "hand.raised.fill",
            actionVerb: "Issue",
            category: .command,
            targetType: .character,
            maxTargetPosition: 5,
            cooldownTurns: 2,
            baseSuccessChance: 100,
            riskLevel: .moderate,
            successEffects: SecurityEffects(targetDetained: true, eliteLoyaltyChange: 10, initiatesShuanggui: true),
            failureEffects: SecurityEffects()
        ),

        SecurityAction(
            id: "launch_anti_corruption_campaign",
            name: "Launch Anti-Corruption Campaign",
            description: "Target sector or faction",
            detailedDescription: "Initiate a comprehensive anti-corruption campaign against a sector or faction. 'Tigers and Flies' approach.",
            iconName: "flame.fill",
            actionVerb: "Launch",
            category: .command,
            targetType: .faction,
            cooldownTurns: 10,
            executionTurns: 5,
            baseSuccessChance: 75,
            riskLevel: .high,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: SecurityEffects(standingChange: 20, stabilityChange: -10, eliteLoyaltyChange: 25, popularSupportChange: 10),
            failureEffects: SecurityEffects(standingChange: -25, stabilityChange: -15)
        ),

        SecurityAction(
            id: "order_vertical_inspection",
            name: "Order Vertical Inspection",
            description: "Central team to provinces",
            detailedDescription: "Deploy central inspection team with full authority over provincial apparatus. 'Vertical management' enforcement.",
            iconName: "arrow.up.arrow.down.circle.fill",
            actionVerb: "Order",
            category: .command,
            targetType: .sector,
            cooldownTurns: 6,
            executionTurns: 3,
            baseSuccessChance: 85,
            riskLevel: .moderate,
            canBeDecree: true,
            successEffects: SecurityEffects(evidenceGathered: 30, networkChange: 15, stabilityChange: 5),
            failureEffects: SecurityEffects(standingChange: -10)
        ),

        // TIER 7-8: Director Actions (CCDI/CPLAC Secretary Level)
        SecurityAction(
            id: "investigate_politburo_member",
            name: "Investigate Politburo Member",
            description: "Target highest officials",
            detailedDescription: "Launch investigation against Politburo-level officials. Requires full Standing Committee approval.",
            iconName: "star.circle.fill",
            actionVerb: "Investigate",
            category: .director,
            targetType: .character,
            maxTargetPosition: 8,
            cooldownTurns: 10,
            executionTurns: 5,
            baseSuccessChance: 50,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            successEffects: SecurityEffects(suspicionIncrease: 50, evidenceGathered: 40, standingChange: 30, eliteLoyaltyChange: 30),
            failureEffects: SecurityEffects(standingChange: -40, corruptionRisk: 40)
        ),

        SecurityAction(
            id: "order_mass_detention",
            name: "Order Mass Detention",
            description: "Sweep arrests across sector",
            detailedDescription: "Order mass arrests across an entire sector or faction. Creates fear but destabilizes the apparatus.",
            iconName: "person.3.fill",
            actionVerb: "Order",
            category: .director,
            targetType: .sector,
            cooldownTurns: 15,
            executionTurns: 2,
            baseSuccessChance: 90,
            riskLevel: .extreme,
            canBeDecree: true,
            successEffects: SecurityEffects(stabilityChange: -20, eliteLoyaltyChange: 40, popularSupportChange: -15, internationalStandingChange: -15),
            failureEffects: SecurityEffects(standingChange: -30, stabilityChange: -25)
        ),

        SecurityAction(
            id: "execute_without_trial",
            name: "Order Extrajudicial Elimination",
            description: "Target dies in 'accident'",
            detailedDescription: "Order the elimination of a target without trial. Officially recorded as 'suicide during detention' or 'accident'.",
            iconName: "xmark.seal.fill",
            actionVerb: "Eliminate",
            category: .director,
            targetType: .character,
            maxTargetPosition: 6,
            cooldownTurns: 10,
            baseSuccessChance: 85,
            riskLevel: .extreme,
            canBeDecree: true,
            successEffects: SecurityEffects(targetExecuted: true, stabilityChange: -5, eliteLoyaltyChange: 30, internationalStandingChange: -10),
            failureEffects: SecurityEffects(standingChange: -40, popularSupportChange: -20, internationalStandingChange: -20)
        ),

        SecurityAction(
            id: "control_security_apparatus",
            name: "Control Security Apparatus",
            description: "Direct all BPS operations",
            detailedDescription: "Exercise absolute control over the State Protection Bureau. All operations require your approval.",
            iconName: "shield.lefthalf.filled.badge.checkmark",
            actionVerb: "Control",
            category: .director,
            targetType: .none,
            cooldownTurns: 0,
            baseSuccessChance: 100,
            riskLevel: .minimal,
            successEffects: SecurityEffects(standingChange: 10, networkChange: 20, createsFlag: "controls_bps"),
            failureEffects: SecurityEffects()
        ),

        SecurityAction(
            id: "fabricate_conspiracy",
            name: "Fabricate Conspiracy",
            description: "Manufacture case against faction",
            detailedDescription: "Create an elaborate fabricated conspiracy case against an entire faction. Extremely risky but can eliminate rivals.",
            iconName: "theatermask.and.paintbrush.fill",
            actionVerb: "Fabricate",
            category: .director,
            targetType: .faction,
            cooldownTurns: 15,
            executionTurns: 5,
            baseSuccessChance: 45,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: SecurityEffects(standingChange: 25, stabilityChange: -15, eliteLoyaltyChange: 35),
            failureEffects: SecurityEffects(standingChange: -50, corruptionRisk: 50, stabilityChange: -20)
        )
    ]

    /// Get actions available for a given position level
    static func actionsForPosition(_ positionIndex: Int) -> [SecurityAction] {
        return allActions.filter { $0.effectiveMinimumPosition <= positionIndex }
    }

    /// Get actions by category
    static func actionsForCategory(_ category: SecurityActionCategory) -> [SecurityAction] {
        return allActions.filter { $0.category == category }
    }

    /// Get a specific action by ID
    static func action(withId id: String) -> SecurityAction? {
        return allActions.first { $0.id == id }
    }
}

// MARK: - Cooldown Tracker

/// Tracks cooldowns for security actions
struct SecurityCooldownTracker: Codable {
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
