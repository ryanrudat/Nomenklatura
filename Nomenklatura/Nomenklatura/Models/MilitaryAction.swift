//
//  MilitaryAction.swift
//  Nomenklatura
//
//  Military-Political Bureau action model following CCP/PLA structure.
//  Based on the "Party commands the gun" principle with dual command system.
//
//  Key concepts:
//  - Central Military Commission (CMC) as supreme body
//  - Political commissar system (dual command at every level)
//  - Political Work Department for ideology, discipline, personnel
//  - Three pillars: Party committee, commissar, political organ systems
//

import Foundation

// MARK: - Military Action

/// A position-gated military-political action in the PLA-style system
struct MilitaryAction: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let detailedDescription: String
    let iconName: String
    let actionVerb: String

    let category: MilitaryActionCategory
    var minimumPositionIndex: Int
    let targetType: MilitaryTargetType
    let requiredTrack: String?          // "militaryPolitical" for some actions

    let cooldownTurns: Int
    let executionTurns: Int             // Some operations take multiple turns
    let baseSuccessChance: Int
    let riskLevel: MilitaryRiskLevel

    let requiresCommitteeApproval: Bool
    let canBeDecree: Bool               // Position 7+ direct orders

    let successEffects: MilitaryEffects
    let failureEffects: MilitaryEffects
}

// MARK: - Action Categories (PLA Political Work Hierarchy)

/// Categories of military-political actions based on PLA structure
enum MilitaryActionCategory: String, Codable, CaseIterable {
    case politicalEducation     // Position 1-2: Basic political work
    case unitCommissar          // Position 2-3: Company/battalion level
    case regimentCommand        // Position 3-4: Regiment/brigade commissar
    case divisionCommand        // Position 4-5: Division/corps level
    case theaterCommand         // Position 5-6: Theater/department level
    case cmcAuthority           // Position 7+: Central Military Commission

    var displayName: String {
        switch self {
        case .politicalEducation: return "Political Education"
        case .unitCommissar: return "Unit Commissar"
        case .regimentCommand: return "Regiment Command"
        case .divisionCommand: return "Division Command"
        case .theaterCommand: return "Theater Command"
        case .cmcAuthority: return "CMC Authority"
        }
    }

    var minimumPositionIndex: Int {
        switch self {
        case .politicalEducation: return 1
        case .unitCommissar: return 2
        case .regimentCommand: return 3
        case .divisionCommand: return 4
        case .theaterCommand: return 5
        case .cmcAuthority: return 7
        }
    }

    /// PLA equivalent rank/role
    var plaEquivalent: String {
        switch self {
        case .politicalEducation: return "Political Instructor"
        case .unitCommissar: return "Battalion Commissar"
        case .regimentCommand: return "Regiment Political Commissar"
        case .divisionCommand: return "Division Political Commissar"
        case .theaterCommand: return "Theater Political Work Dept"
        case .cmcAuthority: return "CMC Political Work Department"
        }
    }

    var color: String {
        switch self {
        case .politicalEducation: return "#4CAF50"  // Green
        case .unitCommissar: return "#2196F3"       // Blue
        case .regimentCommand: return "#9C27B0"     // Purple
        case .divisionCommand: return "#FF9800"     // Orange
        case .theaterCommand: return "#F44336"      // Red
        case .cmcAuthority: return "#FFD700"        // Gold
        }
    }
}

// MARK: - Target Types

/// What the military action targets
enum MilitaryTargetType: String, Codable {
    case officer        // Target specific military character
    case unit           // Target military unit/formation
    case theater        // Target theater command area
    case serviceArm     // Target Army/Navy/Air Force/Rocket Force
    case none           // No target required
}

// MARK: - Risk Levels

/// Risk level for military-political actions
enum MilitaryRiskLevel: String, Codable, CaseIterable {
    case routine        // Normal political work
    case moderate       // Some career risk
    case significant    // Could backfire
    case major          // High stakes operation
    case extreme        // Could end career or worse

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

// MARK: - Military Effects

/// Effects of military-political actions
struct MilitaryEffects: Codable {
    // National military effects
    var militaryLoyaltyChange: Int = 0
    var militaryReadinessChange: Int = 0
    var stabilityChange: Int = 0

    // Support effects
    var eliteLoyaltyChange: Int = 0
    var popularSupportChange: Int = 0

    // Personal effects
    var standingChange: Int = 0
    var networkChange: Int = 0
    var patronFavorChange: Int = 0

    // International effects
    var internationalStandingChange: Int = 0

    // Target effects (when targeting officers)
    var targetLoyaltyChange: Int = 0
    var targetDispositionChange: Int = 0
    var initiatesPurge: Bool = false
    var initiatesPromotion: Bool = false

    // Flags and triggers
    var createsFlag: String? = nil
    var removesFlag: String? = nil
    var triggersEvent: String? = nil
    var startsCampaign: Bool = false
}

// MARK: - Service Arm

/// PLA service branches
enum ServiceArm: String, Codable, CaseIterable {
    case groundForce        // PLAGF - Army
    case navy               // PLAN - Navy
    case airForce           // PLAAF - Air Force
    case rocketForce        // PLARF - Strategic missiles
    case strategicSupport   // PLASSF - Cyber, space, EW
    case armedPolice        // PAP - People's Armed Police

    var displayName: String {
        switch self {
        case .groundForce: return "Ground Force (Army)"
        case .navy: return "Navy"
        case .airForce: return "Air Force"
        case .rocketForce: return "Rocket Force"
        case .strategicSupport: return "Strategic Support Force"
        case .armedPolice: return "Armed Police"
        }
    }

    var iconName: String {
        switch self {
        case .groundForce: return "figure.walk"
        case .navy: return "ferry.fill"
        case .airForce: return "airplane"
        case .rocketForce: return "scope"
        case .strategicSupport: return "antenna.radiowaves.left.and.right"
        case .armedPolice: return "shield.fill"
        }
    }
}

// MARK: - Theater Command

/// PLA Theater Commands (战区)
enum TheaterCommand: String, Codable, CaseIterable {
    case eastern    // Taiwan/East China Sea focus
    case southern   // South China Sea focus
    case western    // India/Central Asia focus
    case northern   // Russia/Korea focus
    case central    // Capital/strategic reserve

    var displayName: String {
        switch self {
        case .eastern: return "Eastern Theater"
        case .southern: return "Southern Theater"
        case .western: return "Western Theater"
        case .northern: return "Northern Theater"
        case .central: return "Central Theater"
        }
    }

    var strategicFocus: String {
        switch self {
        case .eastern: return "Taiwan Strait operations"
        case .southern: return "South China Sea defense"
        case .western: return "Border security (India/Central Asia)"
        case .northern: return "Korean Peninsula/Russia relations"
        case .central: return "Capital defense/Strategic reserve"
        }
    }
}

// MARK: - Action Definitions

extension MilitaryAction {

    /// All available military-political actions
    static let allActions: [MilitaryAction] = [

        // MARK: - Tier 1-2: Political Education (Position 1-2)

        MilitaryAction(
            id: "conduct_study_session",
            name: "Conduct Study Session",
            description: "Lead political education session",
            detailedDescription: "Organize and lead a study session on Xi Jinping Thought on Socialism with Chinese Characteristics or other Party doctrine. Essential political work for maintaining ideological purity in the ranks.",
            iconName: "book.fill",
            actionVerb: "Conduct",
            category: .politicalEducation,
            minimumPositionIndex: 1,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 1,
            executionTurns: 1,
            baseSuccessChance: 90,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 2, standingChange: 2),
            failureEffects: MilitaryEffects(standingChange: -3)
        ),

        MilitaryAction(
            id: "report_political_attitude",
            name: "Report Political Attitudes",
            description: "File report on unit's political reliability",
            detailedDescription: "Submit a report to superiors on the political attitudes and ideological soundness of personnel in your unit. These reports form the basis of political dossiers used in promotion decisions.",
            iconName: "doc.text.fill",
            actionVerb: "Report",
            category: .politicalEducation,
            minimumPositionIndex: 1,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(standingChange: 3, networkChange: 2),
            failureEffects: MilitaryEffects(standingChange: -2)
        ),

        MilitaryAction(
            id: "organize_morale_activity",
            name: "Organize Morale Activity",
            description: "Plan cultural/recreational activities",
            detailedDescription: "Organize approved cultural activities, revolutionary songs, or recreational programs to maintain troop morale. The Political Work Department oversees all cultural activities in the PLA.",
            iconName: "music.note.list",
            actionVerb: "Organize",
            category: .politicalEducation,
            minimumPositionIndex: 1,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 3, popularSupportChange: 2),
            failureEffects: MilitaryEffects(standingChange: -2)
        ),

        MilitaryAction(
            id: "flag_suspicious_behavior",
            name: "Flag Suspicious Behavior",
            description: "Report potential disloyalty to superiors",
            detailedDescription: "File a confidential report flagging potentially disloyal or ideologically unsound behavior by a fellow officer. This information goes into their political dossier and may trigger investigation.",
            iconName: "exclamationmark.triangle.fill",
            actionVerb: "Flag",
            category: .politicalEducation,
            minimumPositionIndex: 2,
            targetType: .officer,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 70,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(standingChange: 5, targetDispositionChange: -20),
            failureEffects: MilitaryEffects(standingChange: -8, networkChange: -5)
        ),

        // MARK: - Tier 2-3: Unit Commissar (Position 2-3)

        MilitaryAction(
            id: "enforce_discipline",
            name: "Enforce Discipline",
            description: "Implement disciplinary measures",
            detailedDescription: "As political commissar, enforce Party discipline and military regulations in your unit. This includes formal reprimands, confinement, and recommendations for more serious action. The commissar has final say on discipline matters.",
            iconName: "hand.raised.fill",
            actionVerb: "Enforce",
            category: .unitCommissar,
            minimumPositionIndex: 2,
            targetType: .officer,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 75,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 3, stabilityChange: 2, standingChange: 3, targetDispositionChange: -15),
            failureEffects: MilitaryEffects(militaryLoyaltyChange: -2, standingChange: -5)
        ),

        MilitaryAction(
            id: "evaluate_officer_loyalty",
            name: "Evaluate Officer Loyalty",
            description: "Conduct loyalty assessment",
            detailedDescription: "Conduct a formal political reliability evaluation of an officer. As commissar, you control personnel dossiers and your assessment directly impacts their career prospects. The Party committee relies on your judgment.",
            iconName: "person.badge.shield.checkmark.fill",
            actionVerb: "Evaluate",
            category: .unitCommissar,
            minimumPositionIndex: 2,
            targetType: .officer,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 70,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(standingChange: 5, networkChange: 3),
            failureEffects: MilitaryEffects(standingChange: -5)
        ),

        MilitaryAction(
            id: "recommend_promotion",
            name: "Recommend Promotion",
            description: "Submit promotion recommendation",
            detailedDescription: "Submit a formal recommendation to promote an officer. In the dual command system, the political commissar's recommendation carries significant weight - often more than the military commander's. Building allies through patronage is key.",
            iconName: "arrow.up.circle.fill",
            actionVerb: "Recommend",
            category: .unitCommissar,
            minimumPositionIndex: 3,
            targetType: .officer,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 60,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(standingChange: 5, networkChange: 8, targetDispositionChange: 30, initiatesPromotion: true),
            failureEffects: MilitaryEffects(standingChange: -5, networkChange: -3)
        ),

        MilitaryAction(
            id: "convene_party_committee",
            name: "Convene Party Committee",
            description: "Call unit Party committee meeting",
            detailedDescription: "Convene a meeting of the unit's Party committee to discuss personnel matters, discipline issues, or political work priorities. The Party committee system is the 'fundamental system' of Party leadership over the military.",
            iconName: "person.3.fill",
            actionVerb: "Convene",
            category: .unitCommissar,
            minimumPositionIndex: 3,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 3, standingChange: 5, networkChange: 3),
            failureEffects: MilitaryEffects(standingChange: -3)
        ),

        // MARK: - Tier 3-4: Regiment Command (Position 3-4)

        MilitaryAction(
            id: "launch_ideological_campaign",
            name: "Launch Ideological Campaign",
            description: "Initiate political education campaign",
            detailedDescription: "Launch a comprehensive ideological education campaign in your command. Campaigns focus on Party loyalty, Xi Jinping Thought, or specific themes like anti-corruption. These demonstrate political reliability to superiors.",
            iconName: "megaphone.fill",
            actionVerb: "Launch",
            category: .regimentCommand,
            minimumPositionIndex: 3,
            targetType: .unit,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 65,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 8, stabilityChange: 3, standingChange: 8, startsCampaign: true),
            failureEffects: MilitaryEffects(militaryLoyaltyChange: -3, standingChange: -8)
        ),

        MilitaryAction(
            id: "investigate_corruption",
            name: "Investigate Corruption",
            description: "Launch anti-corruption investigation",
            detailedDescription: "Initiate an investigation into suspected corruption - selling ranks, bribery, or misappropriation. Anti-corruption work is a priority under Xi Jinping. Success can remove rivals; failure may expose your own networks.",
            iconName: "magnifyingglass",
            actionVerb: "Investigate",
            category: .regimentCommand,
            minimumPositionIndex: 3,
            targetType: .officer,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 2,
            baseSuccessChance: 55,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(eliteLoyaltyChange: -5, standingChange: 10, targetDispositionChange: -40),
            failureEffects: MilitaryEffects(standingChange: -10, networkChange: -5)
        ),

        MilitaryAction(
            id: "block_promotion",
            name: "Block Promotion",
            description: "Veto officer's advancement",
            detailedDescription: "Use your authority as political commissar to block an officer's promotion by citing concerns about political reliability. The commissar's veto is often decisive. This is a powerful but dangerous tool.",
            iconName: "hand.raised.slash.fill",
            actionVerb: "Block",
            category: .regimentCommand,
            minimumPositionIndex: 4,
            targetType: .officer,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 1,
            baseSuccessChance: 60,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(standingChange: 5, targetDispositionChange: -50),
            failureEffects: MilitaryEffects(standingChange: -10, networkChange: -8)
        ),

        MilitaryAction(
            id: "publish_political_report",
            name: "Publish Political Report",
            description: "Write article for Liberation Army Daily",
            detailedDescription: "Author an article for the PLA Daily (解放军报) on political work or Party theory. Publication in the official military newspaper demonstrates ideological soundness and raises your profile among the leadership.",
            iconName: "newspaper.fill",
            actionVerb: "Publish",
            category: .regimentCommand,
            minimumPositionIndex: 3,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 50,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(eliteLoyaltyChange: 3, standingChange: 12, networkChange: 5),
            failureEffects: MilitaryEffects(standingChange: -5)
        ),

        // MARK: - Tier 4-5: Division Command (Position 4-5)

        MilitaryAction(
            id: "purge_officer",
            name: "Purge Officer",
            description: "Remove officer for political unreliability",
            detailedDescription: "Formally recommend removal of an officer from their position for political unreliability, corruption, or disloyalty. This requires Party committee approval and initiates expulsion proceedings. A decisive but irreversible action.",
            iconName: "person.fill.xmark",
            actionVerb: "Purge",
            category: .divisionCommand,
            minimumPositionIndex: 4,
            targetType: .officer,
            requiredTrack: nil,
            cooldownTurns: 6,
            executionTurns: 2,
            baseSuccessChance: 50,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: MilitaryEffects(stabilityChange: -5, eliteLoyaltyChange: -8, standingChange: 15, initiatesPurge: true),
            failureEffects: MilitaryEffects(stabilityChange: -3, standingChange: -15, networkChange: -10)
        ),

        MilitaryAction(
            id: "appoint_commissar",
            name: "Appoint Political Commissar",
            description: "Assign commissar to subordinate unit",
            detailedDescription: "Exercise your authority to appoint a political commissar to a subordinate unit. Placing allies in commissar positions builds your network and ensures loyal political work in subordinate commands.",
            iconName: "person.badge.plus",
            actionVerb: "Appoint",
            category: .divisionCommand,
            minimumPositionIndex: 4,
            targetType: .officer,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 1,
            baseSuccessChance: 65,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(standingChange: 8, networkChange: 10, targetDispositionChange: 40),
            failureEffects: MilitaryEffects(standingChange: -8)
        ),

        MilitaryAction(
            id: "assess_unit_readiness",
            name: "Assess Unit Readiness",
            description: "Conduct political readiness inspection",
            detailedDescription: "Lead an inspection team to assess the political readiness and ideological soundness of subordinate units. The political organ system exists to hold the PLA accountable through inspection. Your report goes to higher headquarters.",
            iconName: "checklist",
            actionVerb: "Assess",
            category: .divisionCommand,
            minimumPositionIndex: 4,
            targetType: .unit,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 2,
            baseSuccessChance: 70,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 5, militaryReadinessChange: 5, standingChange: 8),
            failureEffects: MilitaryEffects(militaryReadinessChange: -3, standingChange: -5)
        ),

        MilitaryAction(
            id: "coordinate_dual_command",
            name: "Coordinate Dual Command",
            description: "Resolve commander-commissar conflicts",
            detailedDescription: "Mediate disputes between military commanders and political commissars in the dual command system. The Party committee should provide collective leadership, but conflicts arise. Your arbitration shapes command relationships.",
            iconName: "arrow.triangle.merge",
            actionVerb: "Coordinate",
            category: .divisionCommand,
            minimumPositionIndex: 4,
            targetType: .unit,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 60,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 5, stabilityChange: 5, standingChange: 8, networkChange: 5),
            failureEffects: MilitaryEffects(stabilityChange: -5, standingChange: -5)
        ),

        // MARK: - Tier 5-6: Theater Command (Position 5-6)

        MilitaryAction(
            id: "theater_political_directive",
            name: "Issue Theater Directive",
            description: "Issue political work directive for theater",
            detailedDescription: "Issue a comprehensive political work directive for your theater command. Theater-level political departments coordinate political work across all units in the geographic area, setting priorities and standards.",
            iconName: "scroll.fill",
            actionVerb: "Issue",
            category: .theaterCommand,
            minimumPositionIndex: 5,
            targetType: .theater,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 60,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 10, stabilityChange: 5, standingChange: 12),
            failureEffects: MilitaryEffects(militaryLoyaltyChange: -5, standingChange: -10)
        ),

        MilitaryAction(
            id: "recommend_general_promotion",
            name: "Recommend General Promotion",
            description: "Nominate officer for general rank",
            detailedDescription: "Submit a recommendation to the CMC for an officer to be promoted to general rank. General promotions require CMC approval and are highly political. Your recommendation can make careers - or reveal your factional alignments.",
            iconName: "star.circle.fill",
            actionVerb: "Recommend",
            category: .theaterCommand,
            minimumPositionIndex: 5,
            targetType: .officer,
            requiredTrack: nil,
            cooldownTurns: 6,
            executionTurns: 2,
            baseSuccessChance: 45,
            riskLevel: .significant,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: MilitaryEffects(standingChange: 15, networkChange: 12, targetDispositionChange: 50, initiatesPromotion: true),
            failureEffects: MilitaryEffects(standingChange: -10, networkChange: -5)
        ),

        MilitaryAction(
            id: "anti_corruption_sweep",
            name: "Launch Anti-Corruption Sweep",
            description: "Initiate theater-wide anti-corruption campaign",
            detailedDescription: "Launch a comprehensive anti-corruption campaign across your theater command. Xi Jinping has made anti-corruption in the military a priority. This can remove entire networks of corrupt officers - including your rivals.",
            iconName: "shield.lefthalf.filled",
            actionVerb: "Launch",
            category: .theaterCommand,
            minimumPositionIndex: 5,
            targetType: .theater,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 3,
            baseSuccessChance: 50,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: -5, stabilityChange: -8, eliteLoyaltyChange: -15, standingChange: 20, startsCampaign: true),
            failureEffects: MilitaryEffects(stabilityChange: -5, standingChange: -20, networkChange: -15)
        ),

        MilitaryAction(
            id: "service_arm_inspection",
            name: "Inspect Service Arm",
            description: "Lead political inspection of service branch",
            detailedDescription: "Lead a high-level inspection team to assess political work in a service branch (Army, Navy, Air Force, etc.). Your findings will be reported to the CMC Political Work Department and may result in personnel changes.",
            iconName: "binoculars.fill",
            actionVerb: "Inspect",
            category: .theaterCommand,
            minimumPositionIndex: 5,
            targetType: .serviceArm,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 60,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 8, militaryReadinessChange: 5, standingChange: 12),
            failureEffects: MilitaryEffects(militaryReadinessChange: -3, standingChange: -8)
        ),

        // MARK: - Tier 7+: CMC Authority (Position 7+)

        MilitaryAction(
            id: "cmc_personnel_directive",
            name: "CMC Personnel Directive",
            description: "Issue CMC directive on military personnel",
            detailedDescription: "Issue a directive from the Central Military Commission on military personnel matters. As a CMC member, your directives reshape the entire PLA leadership structure. This is the highest level of military-political authority.",
            iconName: "building.columns.fill",
            actionVerb: "Issue",
            category: .cmcAuthority,
            minimumPositionIndex: 7,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 2,
            baseSuccessChance: 70,
            riskLevel: .major,
            requiresCommitteeApproval: false,
            canBeDecree: true,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 15, stabilityChange: 5, eliteLoyaltyChange: 10, standingChange: 20),
            failureEffects: MilitaryEffects(stabilityChange: -10, standingChange: -15)
        ),

        MilitaryAction(
            id: "nationwide_military_purge",
            name: "Nationwide Military Purge",
            description: "Launch PLA-wide anti-corruption purge",
            detailedDescription: "Initiate a nationwide purge of the PLA targeting corruption networks, disloyal officers, and factional enemies. Xi Jinping has dismissed nearly 1/5 of generals since 2012. This is the ultimate demonstration of power over the military.",
            iconName: "flame.fill",
            actionVerb: "Launch",
            category: .cmcAuthority,
            minimumPositionIndex: 7,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 12,
            executionTurns: 4,
            baseSuccessChance: 50,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: MilitaryEffects(militaryLoyaltyChange: -10, stabilityChange: -15, eliteLoyaltyChange: -20, standingChange: 30, startsCampaign: true),
            failureEffects: MilitaryEffects(militaryLoyaltyChange: -15, stabilityChange: -20, standingChange: -30)
        ),

        MilitaryAction(
            id: "appoint_theater_commander",
            name: "Appoint Theater Commander",
            description: "Name new theater command leadership",
            detailedDescription: "Exercise CMC authority to appoint new theater command leadership - both military commander and political commissar. The CMC directly controls all senior military appointments. This shapes the PLA's operational readiness.",
            iconName: "person.2.badge.gearshape.fill",
            actionVerb: "Appoint",
            category: .cmcAuthority,
            minimumPositionIndex: 7,
            targetType: .theater,
            requiredTrack: nil,
            cooldownTurns: 6,
            executionTurns: 1,
            baseSuccessChance: 75,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: true,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 10, standingChange: 15, networkChange: 15),
            failureEffects: MilitaryEffects(standingChange: -12, networkChange: -8)
        ),

        MilitaryAction(
            id: "military_political_reform",
            name: "Military-Political Reform",
            description: "Restructure PLA political work system",
            detailedDescription: "Initiate comprehensive reform of the PLA's political work system. Xi's 2016 reforms transformed the four headquarters into 15 CMC agencies. Such restructuring demonstrates supreme authority and reshapes power relationships throughout the military.",
            iconName: "arrow.3.trianglepath",
            actionVerb: "Reform",
            category: .cmcAuthority,
            minimumPositionIndex: 7,
            targetType: .none,
            requiredTrack: nil,
            cooldownTurns: 10,
            executionTurns: 3,
            baseSuccessChance: 45,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: MilitaryEffects(militaryLoyaltyChange: 10, militaryReadinessChange: 10, stabilityChange: -10, eliteLoyaltyChange: -10, standingChange: 25),
            failureEffects: MilitaryEffects(militaryLoyaltyChange: -10, stabilityChange: -15, standingChange: -25)
        )
    ]

    /// Get actions available for a given position
    static func actions(forPosition positionIndex: Int) -> [MilitaryAction] {
        allActions.filter { $0.minimumPositionIndex <= positionIndex }
    }

    /// Find action by ID
    static func action(withId id: String) -> MilitaryAction? {
        allActions.first { $0.id == id }
    }
}
