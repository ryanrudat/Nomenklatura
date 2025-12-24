//
//  PartyAction.swift
//  Nomenklatura
//
//  Model for Party Apparatus Bureau actions following CCP Central Committee structure.
//  Based on real CCP organs: Organization Dept, Propaganda Dept, United Front Work Dept,
//  Central Party School, and the Secretariat/General Office.
//
//  Key CCP concepts:
//  - Nomenklatura system: Hierarchical lists of positions under party control
//  - "Party nature education" (党性教育): Ideological training
//  - United Front: Influence over non-Party groups ("magic weapon")
//  - Democratic centralism: Discussion then obedience
//  - Self-criticism sessions (自我批评)
//

import Foundation

// MARK: - Party Action Category

/// Categories of party apparatus actions following CCP organizational hierarchy
enum PartyActionCategory: String, Codable, CaseIterable {
    case partyWorker       // Position 1-2: Grassroots party work
    case partySecretary    // Position 2-3: Party cell/branch leadership
    case departmentCadre   // Position 3-4: Department-level party work
    case bureauDirector    // Position 4-5: Bureau-level authority
    case provincialLevel   // Position 5-6: Provincial party leadership
    case centralLevel      // Position 7+: Central Committee authority

    var displayName: String {
        switch self {
        case .partyWorker: return "Party Worker"
        case .partySecretary: return "Party Secretary"
        case .departmentCadre: return "Department Cadre"
        case .bureauDirector: return "Bureau Director"
        case .provincialLevel: return "Provincial Level"
        case .centralLevel: return "Central Level"
        }
    }

    var minimumPositionIndex: Int {
        switch self {
        case .partyWorker: return 1
        case .partySecretary: return 2
        case .departmentCadre: return 3
        case .bureauDirector: return 4
        case .provincialLevel: return 5
        case .centralLevel: return 7
        }
    }

    /// CCP equivalent position
    var ccpEquivalent: String {
        switch self {
        case .partyWorker: return "Grassroots Party Member"
        case .partySecretary: return "Party Branch Secretary"
        case .departmentCadre: return "Department-Level Cadre"
        case .bureauDirector: return "Bureau Director-General"
        case .provincialLevel: return "Provincial Standing Committee"
        case .centralLevel: return "Central Committee Member"
        }
    }

    /// Color for UI display
    var color: String {
        switch self {
        case .partyWorker: return "#6B7280"      // Gray
        case .partySecretary: return "#3B82F6"   // Blue
        case .departmentCadre: return "#8B5CF6"  // Purple
        case .bureauDirector: return "#F59E0B"   // Amber
        case .provincialLevel: return "#EF4444"  // Red
        case .centralLevel: return "#FFD700"     // Gold
        }
    }
}

// MARK: - Party Action Target Type

/// What can be targeted by party actions
enum PartyTargetType: String, Codable {
    case character      // Target a specific cadre/member
    case faction        // Target an entire faction
    case department     // Target a bureau/department
    case mediaOutlet    // Propaganda target
    case unitedFront    // External group influence
    case none           // No target required
}

// MARK: - Party Risk Level

/// Risk level for party actions
enum PartyRiskLevel: String, Codable {
    case routine        // Standard party work
    case moderate       // Some political exposure
    case significant    // Could attract attention
    case major          // High-stakes party politics
    case extreme        // Career-defining risk

    var displayName: String {
        switch self {
        case .routine: return "Routine"
        case .moderate: return "Moderate"
        case .significant: return "Significant"
        case .major: return "Major"
        case .extreme: return "Extreme"
        }
    }

    var successModifier: Int {
        switch self {
        case .routine: return 10
        case .moderate: return 0
        case .significant: return -5
        case .major: return -10
        case .extreme: return -15
        }
    }
}

// MARK: - Party Effects

/// Effects of party actions on game state
struct PartyEffects: Codable {
    // National/Party effects
    var eliteLoyaltyChange: Int = 0         // Party elite loyalty
    var stabilityChange: Int = 0            // Political stability
    var popularSupportChange: Int = 0       // Popular support
    var ideologicalPurityChange: Int = 0    // Party orthodoxy (simulated)

    // Personal effects
    var standingChange: Int = 0             // Player's political capital
    var networkChange: Int = 0              // Player's connections
    var patronFavorChange: Int = 0          // Patron relationship

    // Target effects
    var targetDispositionChange: Int = 0    // Target's feeling toward player
    var targetStandingChange: Int = 0       // Target's political standing
    var targetLoyaltyChange: Int = 0        // Target's party loyalty

    // Triggers
    var initiatesPromotion: Bool = false    // Promotes target
    var initiatesDemotion: Bool = false     // Demotes target
    var initiatesExpulsion: Bool = false    // Expels from party
    var initiatesCampaign: Bool = false     // Starts ideological campaign
    var createsFlag: String? = nil
    var removesFlag: String? = nil
    var triggersEvent: String? = nil
}

// MARK: - Party Organ Type

/// CCP organs that execute party actions
enum PartyOrgan: String, Codable, CaseIterable {
    case organizationDept       // Personnel/cadre management
    case propagandaDept         // Ideology and media
    case unitedFrontDept        // Non-party influence
    case centralPartySchool     // Cadre training
    case secretariat            // Daily operations
    case generalOffice          // Administrative support
    case disciplineInspection   // Internal discipline (overlaps with BPS)

    var displayName: String {
        switch self {
        case .organizationDept: return "Organization Department"
        case .propagandaDept: return "Propaganda Department"
        case .unitedFrontDept: return "United Front Work Dept"
        case .centralPartySchool: return "Central Party School"
        case .secretariat: return "Secretariat"
        case .generalOffice: return "General Office"
        case .disciplineInspection: return "Discipline Inspection"
        }
    }

    var iconName: String {
        switch self {
        case .organizationDept: return "person.crop.rectangle.stack"
        case .propagandaDept: return "megaphone.fill"
        case .unitedFrontDept: return "person.3.sequence.fill"
        case .centralPartySchool: return "graduationcap.fill"
        case .secretariat: return "doc.text.fill"
        case .generalOffice: return "building.2.fill"
        case .disciplineInspection: return "checkmark.shield.fill"
        }
    }
}

// MARK: - Party Action Model

/// A single party apparatus action
struct PartyAction: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let detailedDescription: String
    let iconName: String
    let actionVerb: String              // "EXECUTE", "CONVENE", "DIRECT"

    let category: PartyActionCategory
    var minimumPositionIndex: Int
    let organ: PartyOrgan               // Which CCP organ handles this
    let targetType: PartyTargetType
    let requiredTrack: String?          // Optional track requirement

    let cooldownTurns: Int
    let executionTurns: Int             // For multi-turn campaigns
    let baseSuccessChance: Int
    let riskLevel: PartyRiskLevel

    let requiresCommitteeApproval: Bool
    let canBeDecree: Bool               // Can be issued as party directive

    let successEffects: PartyEffects
    let failureEffects: PartyEffects
}

// MARK: - Static Party Actions

extension PartyAction {
    /// All party apparatus actions
    static let allActions: [PartyAction] = [
        // TIER 1-2: Party Worker (Grassroots)
        PartyAction(
            id: "attend_study_session",
            name: "Attend Study Session",
            description: "Participate in mandatory party theory study",
            detailedDescription: "Attend party study sessions on Xi Jinping Thought and party history. Shows ideological commitment and builds connections with fellow party members. Essential for advancement.",
            iconName: "book.fill",
            actionVerb: "ATTEND",
            category: .partyWorker,
            minimumPositionIndex: 1,
            organ: .centralPartySchool,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 1,
            executionTurns: 1,
            baseSuccessChance: 95,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(standingChange: 2, networkChange: 1),
            failureEffects: PartyEffects(standingChange: -1)
        ),

        PartyAction(
            id: "submit_self_criticism",
            name: "Submit Self-Criticism",
            description: "Write self-criticism for party review",
            detailedDescription: "Compose and submit a self-criticism (自我批评) acknowledging personal shortcomings and ideological weaknesses. A ritual of party discipline that demonstrates humility and loyalty.",
            iconName: "pencil.and.scribble",
            actionVerb: "SUBMIT",
            category: .partyWorker,
            minimumPositionIndex: 1,
            organ: .disciplineInspection,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 90,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(eliteLoyaltyChange: 2, standingChange: 3),
            failureEffects: PartyEffects(standingChange: -2)
        ),

        PartyAction(
            id: "report_ideological_attitudes",
            name: "Report on Attitudes",
            description: "Report colleagues' ideological attitudes to superiors",
            detailedDescription: "Compile and submit reports on the political attitudes and ideological reliability of colleagues. Information flows upward through party channels, building your reputation as vigilant.",
            iconName: "doc.badge.ellipsis",
            actionVerb: "REPORT",
            category: .partyWorker,
            minimumPositionIndex: 1,
            organ: .organizationDept,
            targetType: .character,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(standingChange: 4, networkChange: 2, targetDispositionChange: -10),
            failureEffects: PartyEffects(standingChange: -3, targetDispositionChange: -5)
        ),

        PartyAction(
            id: "distribute_propaganda",
            name: "Distribute Propaganda",
            description: "Distribute party materials in your unit",
            detailedDescription: "Organize the distribution of official party publications, posters, and study materials. Ensure proper display and discussion of current party directives.",
            iconName: "newspaper.fill",
            actionVerb: "DISTRIBUTE",
            category: .partyWorker,
            minimumPositionIndex: 1,
            organ: .propagandaDept,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 90,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(popularSupportChange: 1, standingChange: 2),
            failureEffects: PartyEffects(standingChange: -1)
        ),

        // TIER 2-3: Party Secretary (Branch Level)
        PartyAction(
            id: "organize_party_meeting",
            name: "Organize Party Meeting",
            description: "Convene and lead a party branch meeting",
            detailedDescription: "Organize a meeting of your party branch to study central documents, discuss implementation of party directives, and conduct democratic evaluation of members.",
            iconName: "person.3.fill",
            actionVerb: "CONVENE",
            category: .partySecretary,
            minimumPositionIndex: 2,
            organ: .secretariat,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(eliteLoyaltyChange: 2, standingChange: 4, networkChange: 3),
            failureEffects: PartyEffects(standingChange: -2)
        ),

        PartyAction(
            id: "evaluate_member_attitudes",
            name: "Evaluate Member Attitudes",
            description: "Conduct political evaluation of party members",
            detailedDescription: "As party secretary, conduct formal evaluation of members' political attitudes, ideological reliability, and work performance. Results go into their personnel files.",
            iconName: "person.badge.clock.fill",
            actionVerb: "EVALUATE",
            category: .partySecretary,
            minimumPositionIndex: 2,
            organ: .organizationDept,
            targetType: .character,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(standingChange: 5, networkChange: 3, targetLoyaltyChange: 5),
            failureEffects: PartyEffects(standingChange: -3, targetDispositionChange: -15)
        ),

        PartyAction(
            id: "recommend_party_membership",
            name: "Recommend Membership",
            description: "Recommend someone for party membership",
            detailedDescription: "Formally recommend a candidate for Communist Party membership. Your recommendation carries weight and creates a bond of obligation with the new member.",
            iconName: "person.badge.plus",
            actionVerb: "RECOMMEND",
            category: .partySecretary,
            minimumPositionIndex: 2,
            organ: .organizationDept,
            targetType: .character,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 1,
            baseSuccessChance: 75,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(networkChange: 5, patronFavorChange: 3, targetDispositionChange: 25),
            failureEffects: PartyEffects(standingChange: -3, targetDispositionChange: -10)
        ),

        PartyAction(
            id: "democratic_evaluation",
            name: "Democratic Evaluation",
            description: "Conduct democratic evaluation session",
            detailedDescription: "Lead a democratic evaluation (民主评议) session where party members critique each other's work and attitudes. A ritual of collective discipline and mutual surveillance.",
            iconName: "bubble.left.and.bubble.right.fill",
            actionVerb: "CONDUCT",
            category: .partySecretary,
            minimumPositionIndex: 2,
            organ: .disciplineInspection,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(eliteLoyaltyChange: 3, stabilityChange: 2, standingChange: 5),
            failureEffects: PartyEffects(eliteLoyaltyChange: -2, standingChange: -4)
        ),

        // TIER 3-4: Department Cadre
        PartyAction(
            id: "submit_personnel_recommendation",
            name: "Personnel Recommendation",
            description: "Submit recommendation for cadre appointment",
            detailedDescription: "Submit a formal recommendation for cadre appointment or promotion to the Organization Department. Your endorsement becomes part of their nomenklatura file.",
            iconName: "person.crop.rectangle.stack.fill",
            actionVerb: "SUBMIT",
            category: .departmentCadre,
            minimumPositionIndex: 3,
            organ: .organizationDept,
            targetType: .character,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 70,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(networkChange: 5, patronFavorChange: 5, targetDispositionChange: 20, initiatesPromotion: true),
            failureEffects: PartyEffects(standingChange: -5, patronFavorChange: -3)
        ),

        PartyAction(
            id: "draft_policy_proposal",
            name: "Draft Policy Proposal",
            description: "Draft proposal for party committee consideration",
            detailedDescription: "Prepare a formal policy proposal for consideration by the party committee. Requires careful political calibration to align with current party line.",
            iconName: "doc.text.magnifyingglass",
            actionVerb: "DRAFT",
            category: .departmentCadre,
            minimumPositionIndex: 3,
            organ: .generalOffice,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 65,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(stabilityChange: 2, standingChange: 8, networkChange: 3),
            failureEffects: PartyEffects(standingChange: -6)
        ),

        PartyAction(
            id: "coordinate_united_front",
            name: "Coordinate United Front",
            description: "Coordinate united front work locally",
            detailedDescription: "Manage relationships with non-party groups: minor parties, religious organizations, private entrepreneurs, and professionals. Expand party influence through co-optation.",
            iconName: "person.3.sequence.fill",
            actionVerb: "COORDINATE",
            category: .departmentCadre,
            minimumPositionIndex: 3,
            organ: .unitedFrontDept,
            targetType: .unitedFront,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 75,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(popularSupportChange: 3, standingChange: 4, networkChange: 5),
            failureEffects: PartyEffects(standingChange: -3)
        ),

        PartyAction(
            id: "manage_local_propaganda",
            name: "Direct Local Propaganda",
            description: "Direct propaganda operations in your area",
            detailedDescription: "Oversee local propaganda work: approve media content, coordinate study campaigns, ensure correct messaging. Control the narrative in your jurisdiction.",
            iconName: "megaphone.fill",
            actionVerb: "DIRECT",
            category: .departmentCadre,
            minimumPositionIndex: 3,
            organ: .propagandaDept,
            targetType: .mediaOutlet,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(stabilityChange: 2, popularSupportChange: 4, standingChange: 5),
            failureEffects: PartyEffects(popularSupportChange: -2, standingChange: -4)
        ),

        // TIER 4-5: Bureau Director
        PartyAction(
            id: "approve_cadre_transfer",
            name: "Approve Cadre Transfer",
            description: "Approve transfer of cadres under your authority",
            detailedDescription: "Exercise nomenklatura authority to approve cadre transfers and appointments within your jurisdiction. Shape the bureaucracy through personnel decisions.",
            iconName: "arrow.left.arrow.right.circle.fill",
            actionVerb: "APPROVE",
            category: .bureauDirector,
            minimumPositionIndex: 4,
            organ: .organizationDept,
            targetType: .character,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(standingChange: 6, networkChange: 8, targetDispositionChange: 15),
            failureEffects: PartyEffects(standingChange: -4, targetDispositionChange: -10)
        ),

        PartyAction(
            id: "launch_study_campaign",
            name: "Launch Study Campaign",
            description: "Launch ideological study campaign",
            detailedDescription: "Initiate a campaign of intensive party study and ideological education in your jurisdiction. Mobilize the party apparatus for collective learning of central directives.",
            iconName: "books.vertical.fill",
            actionVerb: "LAUNCH",
            category: .bureauDirector,
            minimumPositionIndex: 4,
            organ: .propagandaDept,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 6,
            executionTurns: 3,
            baseSuccessChance: 75,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(eliteLoyaltyChange: 5, stabilityChange: 3, standingChange: 10, initiatesCampaign: true),
            failureEffects: PartyEffects(eliteLoyaltyChange: -3, standingChange: -8)
        ),

        PartyAction(
            id: "direct_propaganda_operations",
            name: "Direct Propaganda Operations",
            description: "Direct major propaganda initiatives",
            detailedDescription: "Take command of propaganda operations: issue instructions to media outlets, approve content, coordinate messaging across platforms. Shape public discourse.",
            iconName: "antenna.radiowaves.left.and.right",
            actionVerb: "DIRECT",
            category: .bureauDirector,
            minimumPositionIndex: 4,
            organ: .propagandaDept,
            targetType: .mediaOutlet,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(stabilityChange: 3, popularSupportChange: 6, standingChange: 8),
            failureEffects: PartyEffects(popularSupportChange: -4, standingChange: -6)
        ),

        PartyAction(
            id: "discipline_inspection",
            name: "Discipline Inspection",
            description: "Conduct party discipline inspection",
            detailedDescription: "Initiate inspection of party discipline in a department or locality. Examine compliance with party rules, identify problems, recommend corrective measures.",
            iconName: "checkmark.shield.fill",
            actionVerb: "INSPECT",
            category: .bureauDirector,
            minimumPositionIndex: 4,
            organ: .disciplineInspection,
            targetType: .department,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 70,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(eliteLoyaltyChange: -3, stabilityChange: 4, standingChange: 10),
            failureEffects: PartyEffects(eliteLoyaltyChange: 3, standingChange: -8)
        ),

        // TIER 5-6: Provincial Level
        PartyAction(
            id: "convene_party_plenum",
            name: "Convene Party Plenum",
            description: "Convene provincial party committee plenum",
            detailedDescription: "Call a full plenum of the provincial party committee to discuss major decisions, approve personnel changes, and transmit central directives. A display of authority.",
            iconName: "building.columns.fill",
            actionVerb: "CONVENE",
            category: .provincialLevel,
            minimumPositionIndex: 5,
            organ: .secretariat,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 2,
            baseSuccessChance: 80,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: PartyEffects(eliteLoyaltyChange: 5, stabilityChange: 5, standingChange: 15, networkChange: 8),
            failureEffects: PartyEffects(eliteLoyaltyChange: -5, standingChange: -12)
        ),

        PartyAction(
            id: "manage_provincial_nomenklatura",
            name: "Manage Nomenklatura",
            description: "Exercise provincial nomenklatura authority",
            detailedDescription: "Control appointments to all positions on the provincial nomenklatura list. Approve or block cadre appointments at prefectural level and below.",
            iconName: "list.clipboard.fill",
            actionVerb: "MANAGE",
            category: .provincialLevel,
            minimumPositionIndex: 5,
            organ: .organizationDept,
            targetType: .department,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(eliteLoyaltyChange: 3, standingChange: 10, networkChange: 10),
            failureEffects: PartyEffects(eliteLoyaltyChange: -5, standingChange: -8)
        ),

        PartyAction(
            id: "direct_provincial_united_front",
            name: "Direct Provincial United Front",
            description: "Direct united front work across the province",
            detailedDescription: "Command provincial united front operations: manage relations with all non-party groups, coordinate influence activities, expand the party's reach into civil society.",
            iconName: "globe.asia.australia.fill",
            actionVerb: "DIRECT",
            category: .provincialLevel,
            minimumPositionIndex: 5,
            organ: .unitedFrontDept,
            targetType: .unitedFront,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 75,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: PartyEffects(popularSupportChange: 5, standingChange: 8, networkChange: 8),
            failureEffects: PartyEffects(popularSupportChange: -3, standingChange: -6)
        ),

        PartyAction(
            id: "approve_senior_appointments",
            name: "Approve Senior Appointments",
            description: "Approve senior cadre appointments",
            detailedDescription: "Exercise authority to approve appointments of department-level and above cadres. Shape the provincial leadership through careful personnel selection.",
            iconName: "person.crop.rectangle.badge.checkmark",
            actionVerb: "APPROVE",
            category: .provincialLevel,
            minimumPositionIndex: 5,
            organ: .organizationDept,
            targetType: .character,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: PartyEffects(standingChange: 12, networkChange: 10, patronFavorChange: 5, targetDispositionChange: 25, initiatesPromotion: true),
            failureEffects: PartyEffects(standingChange: -10, patronFavorChange: -5)
        ),

        // TIER 7+: Central Level
        PartyAction(
            id: "control_central_nomenklatura",
            name: "Control Central Nomenklatura",
            description: "Exercise central nomenklatura authority",
            detailedDescription: "Manage the ~5,000 senior positions on the central nomenklatura list. Control who rises to provincial leadership and ministerial rank across the nation.",
            iconName: "crown.fill",
            actionVerb: "CONTROL",
            category: .centralLevel,
            minimumPositionIndex: 7,
            organ: .organizationDept,
            targetType: .department,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 90,
            riskLevel: .major,
            requiresCommitteeApproval: false,
            canBeDecree: true,
            successEffects: PartyEffects(eliteLoyaltyChange: 8, standingChange: 15, networkChange: 15),
            failureEffects: PartyEffects(eliteLoyaltyChange: -8, standingChange: -12)
        ),

        PartyAction(
            id: "issue_party_directive",
            name: "Issue Party Directive",
            description: "Issue Central Committee directive",
            detailedDescription: "Draft and issue a directive in the name of the Central Committee. Your words become party law, transmitted to every level of the apparatus for implementation.",
            iconName: "scroll.fill",
            actionVerb: "ISSUE",
            category: .centralLevel,
            minimumPositionIndex: 7,
            organ: .generalOffice,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 6,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: PartyEffects(eliteLoyaltyChange: 5, stabilityChange: 5, popularSupportChange: 3, standingChange: 20),
            failureEffects: PartyEffects(eliteLoyaltyChange: -5, stabilityChange: -5, standingChange: -15)
        ),

        PartyAction(
            id: "direct_national_propaganda",
            name: "Direct National Propaganda",
            description: "Direct nationwide propaganda operations",
            detailedDescription: "Command the entire propaganda apparatus: issue instructions to all media, define the official narrative, coordinate nationwide messaging campaigns. The 'red telephone' to CCTV is yours.",
            iconName: "tv.and.mediabox",
            actionVerb: "DIRECT",
            category: .centralLevel,
            minimumPositionIndex: 7,
            organ: .propagandaDept,
            targetType: .mediaOutlet,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 2,
            baseSuccessChance: 85,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: true,
            successEffects: PartyEffects(stabilityChange: 5, popularSupportChange: 10, standingChange: 15),
            failureEffects: PartyEffects(popularSupportChange: -8, standingChange: -10)
        ),

        PartyAction(
            id: "launch_nationwide_campaign",
            name: "Launch Nationwide Campaign",
            description: "Launch nationwide ideological campaign",
            detailedDescription: "Initiate a major nationwide campaign of political study, ideological rectification, or party building. Mobilize the entire apparatus for a campaign that will define an era.",
            iconName: "flag.2.crossed.fill",
            actionVerb: "LAUNCH",
            category: .centralLevel,
            minimumPositionIndex: 7,
            organ: .propagandaDept,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 10,
            executionTurns: 5,
            baseSuccessChance: 70,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: PartyEffects(eliteLoyaltyChange: 10, stabilityChange: -5, popularSupportChange: 5, standingChange: 25, initiatesCampaign: true),
            failureEffects: PartyEffects(eliteLoyaltyChange: -10, stabilityChange: -10, standingChange: -20)
        ),

        PartyAction(
            id: "purge_faction",
            name: "Purge Faction",
            description: "Orchestrate purge of opposing faction",
            detailedDescription: "Use the full power of the party apparatus to systematically remove an opposing faction. Coordinate Organization, Discipline Inspection, and Propaganda departments for total political destruction.",
            iconName: "person.3.fill",
            actionVerb: "PURGE",
            category: .centralLevel,
            minimumPositionIndex: 7,
            organ: .organizationDept,
            targetType: .faction,
            requiredTrack: nil,
            cooldownTurns: 12,
            executionTurns: 4,
            baseSuccessChance: 60,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: PartyEffects(eliteLoyaltyChange: -15, stabilityChange: -10, standingChange: 30, initiatesCampaign: true),
            failureEffects: PartyEffects(eliteLoyaltyChange: 10, stabilityChange: -15, standingChange: -30)
        )
    ]

    /// Get actions available at a given position
    static func actions(forPosition position: Int) -> [PartyAction] {
        allActions.filter { $0.minimumPositionIndex <= position }
    }

    /// Get actions for a specific organ
    static func actions(forOrgan organ: PartyOrgan) -> [PartyAction] {
        allActions.filter { $0.organ == organ }
    }
}
