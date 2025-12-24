//
//  StateMinistryAction.swift
//  Nomenklatura
//
//  State Ministry Bureau action definitions following State Council structure.
//  Models the machinery of state governance: ministries, commissions, and administration.
//
//  Based on China's State Council (国务院) structure:
//  - Premier leads the State Council
//  - Vice Premiers oversee policy areas
//  - State Councilors manage coordination
//  - Ministers run individual ministries
//  - Commissions outrank ministries and coordinate across sectors
//

import Foundation

// MARK: - State Ministry Action Category

/// Position-gated categories for state ministry actions following State Council hierarchy
enum StateMinistryActionCategory: String, Codable, CaseIterable {
    case clerk           // Position 1-2: Ministry clerk, junior bureaucrat
    case officer         // Position 2-3: Section officer, department staff
    case director        // Position 3-4: Division director, department head
    case minister        // Position 4-5: Vice minister, bureau chief
    case stateCouncilor  // Position 5-6: Minister, commission director
    case premier         // Position 7+: Vice premier, premier authority

    var displayName: String {
        switch self {
        case .clerk: return "Ministry Clerk"
        case .officer: return "Section Officer"
        case .director: return "Division Director"
        case .minister: return "Vice Minister"
        case .stateCouncilor: return "State Councilor"
        case .premier: return "Premier Level"
        }
    }

    var minimumPositionIndex: Int {
        switch self {
        case .clerk: return 1
        case .officer: return 2
        case .director: return 3
        case .minister: return 4
        case .stateCouncilor: return 5
        case .premier: return 7
        }
    }

    var stateCouncilEquivalent: String {
        switch self {
        case .clerk: return "Ministry Staff"
        case .officer: return "Division Staff"
        case .director: return "Bureau Director"
        case .minister: return "Vice Minister/Director-General"
        case .stateCouncilor: return "Minister/State Councilor"
        case .premier: return "Vice Premier/Premier"
        }
    }

    var color: String {
        switch self {
        case .clerk: return "#6B7280"       // Gray
        case .officer: return "#059669"     // Green
        case .director: return "#2563EB"    // Blue
        case .minister: return "#7C3AED"    // Purple
        case .stateCouncilor: return "#DC2626" // Red
        case .premier: return "#B91C1C"     // Dark red
        }
    }
}

// MARK: - Ministry Department

/// Government departments and commissions under the State Council
enum MinistryDepartment: String, Codable, CaseIterable {
    case generalOffice          // State Council General Office - coordination
    case developmentReform      // National Development and Reform Commission
    case finance                // Ministry of Finance
    case industry               // Ministry of Industry and Information Technology
    case civilAffairs           // Ministry of Civil Affairs
    case justice                // Ministry of Justice
    case humanResources         // Ministry of Human Resources and Social Security
    case naturalResources       // Ministry of Natural Resources
    case housing                // Ministry of Housing and Urban-Rural Development
    case transport              // Ministry of Transport
    case agriculture            // Ministry of Agriculture and Rural Affairs
    case commerce               // Ministry of Commerce
    case culture                // Ministry of Culture and Tourism
    case health                 // National Health Commission
    case audit                  // National Audit Office

    var displayName: String {
        switch self {
        case .generalOffice: return "General Office"
        case .developmentReform: return "Development & Reform Commission"
        case .finance: return "Ministry of Finance"
        case .industry: return "Ministry of Industry"
        case .civilAffairs: return "Ministry of Civil Affairs"
        case .justice: return "Ministry of Justice"
        case .humanResources: return "Ministry of Human Resources"
        case .naturalResources: return "Ministry of Natural Resources"
        case .housing: return "Ministry of Housing"
        case .transport: return "Ministry of Transport"
        case .agriculture: return "Ministry of Agriculture"
        case .commerce: return "Ministry of Commerce"
        case .culture: return "Ministry of Culture"
        case .health: return "National Health Commission"
        case .audit: return "National Audit Office"
        }
    }

    var iconName: String {
        switch self {
        case .generalOffice: return "building.columns.fill"
        case .developmentReform: return "chart.line.uptrend.xyaxis"
        case .finance: return "banknote.fill"
        case .industry: return "gearshape.2.fill"
        case .civilAffairs: return "person.3.fill"
        case .justice: return "scalemass.fill"
        case .humanResources: return "person.crop.rectangle.stack.fill"
        case .naturalResources: return "leaf.fill"
        case .housing: return "house.fill"
        case .transport: return "car.fill"
        case .agriculture: return "carrot.fill"
        case .commerce: return "cart.fill"
        case .culture: return "theatermasks.fill"
        case .health: return "cross.case.fill"
        case .audit: return "doc.text.magnifyingglass"
        }
    }

    /// Whether this is a commission (outranks ministries)
    var isCommission: Bool {
        switch self {
        case .developmentReform, .health:
            return true
        default:
            return false
        }
    }
}

// MARK: - Target Type

/// Types of targets for state ministry actions
enum MinistryTargetType: String, Codable {
    case ministry       // Target a specific ministry/department
    case official       // Target a specific official
    case policy         // Target a policy area
    case region         // Target a region/province
    case sector         // Target an economic sector
    case none           // No target required
}

// MARK: - Risk Level

/// Risk levels for state ministry actions
enum MinistryRiskLevel: String, Codable {
    case routine        // Normal administrative work
    case moderate       // May create friction
    case significant    // Could backfire politically
    case major          // High stakes, visible consequences
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
        case .significant: return -10
        case .major: return -20
        case .extreme: return -30
        }
    }
}

// MARK: - Ministry Effects

/// Effects of state ministry actions
struct MinistryEffects: Codable {
    // Government/state effects
    var stabilityChange: Int = 0
    var popularSupportChange: Int = 0
    var treasuryChange: Int = 0
    var industrialOutputChange: Int = 0

    // Personal effects
    var standingChange: Int = 0
    var networkChange: Int = 0
    var patronFavorChange: Int = 0

    // Target effects
    var targetDispositionChange: Int = 0
    var targetStandingChange: Int = 0

    // Special triggers
    var initiatesReform: Bool = false
    var initiatesAudit: Bool = false
    var initiatesProject: Bool = false
    var createsFlag: String? = nil
    var removesFlag: String? = nil
    var triggersEvent: String? = nil
}

// MARK: - State Ministry Action

/// An action available in the State Ministry Bureau
struct StateMinistryAction: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let detailedDescription: String
    let iconName: String
    let actionVerb: String

    let category: StateMinistryActionCategory
    var minimumPositionIndex: Int
    let targetType: MinistryTargetType
    let department: MinistryDepartment?
    let requiredTrack: String?

    let cooldownTurns: Int
    let executionTurns: Int
    let baseSuccessChance: Int
    let riskLevel: MinistryRiskLevel

    let requiresCommitteeApproval: Bool
    let canBeDecree: Bool

    let successEffects: MinistryEffects
    let failureEffects: MinistryEffects

    // MARK: - All Actions

    static let allActions: [StateMinistryAction] = [
        // TIER 1-2: Clerk Actions (Ministry Staff Level)
        StateMinistryAction(
            id: "process_documents",
            name: "Process Official Documents",
            description: "Handle routine administrative paperwork",
            detailedDescription: "Process the daily flow of official documents, memoranda, and correspondence that keeps the state machinery running. Build familiarity with bureaucratic procedures.",
            iconName: "doc.text.fill",
            actionVerb: "Process",
            category: .clerk,
            minimumPositionIndex: 1,
            targetType: .none,
            department: .generalOffice,
            requiredTrack: nil,
            cooldownTurns: 1,
            executionTurns: 1,
            baseSuccessChance: 95,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(standingChange: 1, networkChange: 1),
            failureEffects: MinistryEffects(standingChange: -1)
        ),

        StateMinistryAction(
            id: "compile_statistics",
            name: "Compile Ministry Statistics",
            description: "Gather and organize departmental data",
            detailedDescription: "Collect statistical data from various departments and compile reports for senior officials. This work gives insight into ministry operations and can reveal useful information.",
            iconName: "chart.bar.doc.horizontal.fill",
            actionVerb: "Compile",
            category: .clerk,
            minimumPositionIndex: 1,
            targetType: .ministry,
            department: nil,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(standingChange: 2, networkChange: 2),
            failureEffects: MinistryEffects(standingChange: -1)
        ),

        StateMinistryAction(
            id: "assist_inspection",
            name: "Assist Ministry Inspection",
            description: "Support official inspection teams",
            detailedDescription: "Provide administrative support to inspection teams reviewing ministry operations. A good opportunity to demonstrate competence and make connections.",
            iconName: "magnifyingglass",
            actionVerb: "Assist",
            category: .clerk,
            minimumPositionIndex: 1,
            targetType: .ministry,
            department: .audit,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(standingChange: 3, networkChange: 3),
            failureEffects: MinistryEffects(standingChange: -2)
        ),

        // TIER 2-3: Section Officer Actions
        StateMinistryAction(
            id: "draft_regulations",
            name: "Draft Administrative Regulations",
            description: "Prepare regulatory documents",
            detailedDescription: "Draft administrative regulations and implementation guidelines for ministry policies. Well-crafted regulations can shape how policies are actually implemented.",
            iconName: "doc.badge.gearshape.fill",
            actionVerb: "Draft",
            category: .officer,
            minimumPositionIndex: 2,
            targetType: .policy,
            department: nil,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 75,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(stabilityChange: 1, standingChange: 3, networkChange: 2),
            failureEffects: MinistryEffects(standingChange: -2)
        ),

        StateMinistryAction(
            id: "coordinate_departments",
            name: "Coordinate Between Departments",
            description: "Facilitate inter-departmental cooperation",
            detailedDescription: "Serve as liaison between different ministry departments, resolving conflicts and ensuring smooth cooperation. This builds a broad network across the bureaucracy.",
            iconName: "arrow.triangle.branch",
            actionVerb: "Coordinate",
            category: .officer,
            minimumPositionIndex: 2,
            targetType: .ministry,
            department: .generalOffice,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 70,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(standingChange: 4, networkChange: 5),
            failureEffects: MinistryEffects(standingChange: -3, networkChange: -2)
        ),

        StateMinistryAction(
            id: "prepare_budget_proposal",
            name: "Prepare Budget Proposal",
            description: "Draft departmental budget requests",
            detailedDescription: "Prepare budget proposals and funding requests for your department. Successful budgeting demonstrates competence and secures resources for your ministry.",
            iconName: "dollarsign.circle.fill",
            actionVerb: "Prepare",
            category: .officer,
            minimumPositionIndex: 2,
            targetType: .ministry,
            department: .finance,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 65,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(treasuryChange: 2, standingChange: 5, patronFavorChange: 2),
            failureEffects: MinistryEffects(standingChange: -4, patronFavorChange: -2)
        ),

        // TIER 3-4: Division Director Actions
        StateMinistryAction(
            id: "implement_policy",
            name: "Implement State Council Policy",
            description: "Execute policies in your jurisdiction",
            detailedDescription: "Take charge of implementing State Council policies within your area of responsibility. Success demonstrates administrative capability and loyalty to central directives.",
            iconName: "checkmark.seal.fill",
            actionVerb: "Implement",
            category: .director,
            minimumPositionIndex: 3,
            targetType: .policy,
            department: nil,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 2,
            baseSuccessChance: 65,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(stabilityChange: 3, popularSupportChange: 2, standingChange: 6),
            failureEffects: MinistryEffects(stabilityChange: -2, standingChange: -5)
        ),

        StateMinistryAction(
            id: "conduct_inspection",
            name: "Conduct Ministry Inspection",
            description: "Lead inspection of subordinate units",
            detailedDescription: "Lead an official inspection of subordinate departments or local implementation. Inspections can reveal problems—or create opportunities to gain leverage over others.",
            iconName: "doc.text.magnifyingglass",
            actionVerb: "Inspect",
            category: .director,
            minimumPositionIndex: 3,
            targetType: .ministry,
            department: .audit,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 70,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(stabilityChange: 2, standingChange: 5, networkChange: 4),
            failureEffects: MinistryEffects(standingChange: -4)
        ),

        StateMinistryAction(
            id: "propose_administrative_reform",
            name: "Propose Administrative Reform",
            description: "Suggest improvements to ministry operations",
            detailedDescription: "Develop and propose reforms to administrative procedures or organizational structure. Reform proposals are risky but can demonstrate vision and capability.",
            iconName: "arrow.triangle.2.circlepath",
            actionVerb: "Propose",
            category: .director,
            minimumPositionIndex: 3,
            targetType: .ministry,
            department: nil,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 1,
            baseSuccessChance: 55,
            riskLevel: .major,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(stabilityChange: 2, standingChange: 8, networkChange: 3, initiatesReform: true),
            failureEffects: MinistryEffects(standingChange: -6, patronFavorChange: -3)
        ),

        StateMinistryAction(
            id: "allocate_resources",
            name: "Allocate Ministry Resources",
            description: "Distribute resources among departments",
            detailedDescription: "Exercise authority over resource allocation within your jurisdiction. Fair allocation builds goodwill; strategic allocation builds power.",
            iconName: "square.grid.3x3.fill",
            actionVerb: "Allocate",
            category: .director,
            minimumPositionIndex: 3,
            targetType: .ministry,
            department: .finance,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 75,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(treasuryChange: 1, standingChange: 5, networkChange: 5),
            failureEffects: MinistryEffects(standingChange: -3, networkChange: -3)
        ),

        // TIER 4-5: Vice Minister Actions
        StateMinistryAction(
            id: "direct_major_project",
            name: "Direct Major State Project",
            description: "Oversee implementation of major initiative",
            detailedDescription: "Take command of a major state project involving significant resources and multiple departments. High visibility means high stakes—success brings recognition, failure brings blame.",
            iconName: "building.2.fill",
            actionVerb: "Direct",
            category: .minister,
            minimumPositionIndex: 4,
            targetType: .sector,
            department: .developmentReform,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 3,
            baseSuccessChance: 55,
            riskLevel: .major,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(stabilityChange: 3, industrialOutputChange: 5, standingChange: 10, initiatesProject: true),
            failureEffects: MinistryEffects(stabilityChange: -3, standingChange: -8)
        ),

        StateMinistryAction(
            id: "negotiate_budget",
            name: "Negotiate Ministry Budget",
            description: "Secure funding in budget negotiations",
            detailedDescription: "Represent your ministry in budget negotiations with the Ministry of Finance. Securing adequate funding is essential for ministry effectiveness and your own reputation.",
            iconName: "banknote.fill",
            actionVerb: "Negotiate",
            category: .minister,
            minimumPositionIndex: 4,
            targetType: .ministry,
            department: .finance,
            requiredTrack: nil,
            cooldownTurns: 6,
            executionTurns: 1,
            baseSuccessChance: 60,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(treasuryChange: 5, standingChange: 8, patronFavorChange: 3),
            failureEffects: MinistryEffects(treasuryChange: -3, standingChange: -5)
        ),

        StateMinistryAction(
            id: "recommend_appointments",
            name: "Recommend Personnel Appointments",
            description: "Influence staffing decisions",
            detailedDescription: "Use your position to recommend appointments to key positions in your ministry. Building a team of loyal subordinates strengthens your institutional base.",
            iconName: "person.badge.plus",
            actionVerb: "Recommend",
            category: .minister,
            minimumPositionIndex: 4,
            targetType: .official,
            department: .humanResources,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 65,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(standingChange: 6, networkChange: 8, targetDispositionChange: 20),
            failureEffects: MinistryEffects(standingChange: -4, networkChange: -3)
        ),

        StateMinistryAction(
            id: "initiate_audit",
            name: "Initiate Department Audit",
            description: "Order formal audit of subordinate units",
            detailedDescription: "Exercise your authority to initiate a formal audit of departments under your jurisdiction. Audits can expose problems—or be used strategically against rivals.",
            iconName: "doc.text.magnifyingglass",
            actionVerb: "Audit",
            category: .minister,
            minimumPositionIndex: 4,
            targetType: .ministry,
            department: .audit,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 70,
            riskLevel: .major,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(stabilityChange: 2, standingChange: 7, initiatesAudit: true),
            failureEffects: MinistryEffects(standingChange: -5, patronFavorChange: -2)
        ),

        // TIER 5-6: State Councilor/Minister Actions
        StateMinistryAction(
            id: "propose_state_council_policy",
            name: "Propose State Council Policy",
            description: "Submit major policy proposal",
            detailedDescription: "Develop and submit a major policy proposal for State Council consideration. Successfully adopted policies can reshape governance and cement your reputation.",
            iconName: "doc.badge.plus",
            actionVerb: "Propose",
            category: .stateCouncilor,
            minimumPositionIndex: 5,
            targetType: .policy,
            department: nil,
            requiredTrack: nil,
            cooldownTurns: 6,
            executionTurns: 2,
            baseSuccessChance: 50,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: MinistryEffects(stabilityChange: 5, popularSupportChange: 3, standingChange: 12),
            failureEffects: MinistryEffects(standingChange: -8, patronFavorChange: -5)
        ),

        StateMinistryAction(
            id: "coordinate_commission_work",
            name: "Coordinate Commission Work",
            description: "Lead cross-ministry coordination",
            detailedDescription: "As a commission leader, coordinate policies and activities across multiple ministries. Commissions outrank ministries and can direct their activities.",
            iconName: "arrow.triangle.merge",
            actionVerb: "Coordinate",
            category: .stateCouncilor,
            minimumPositionIndex: 5,
            targetType: .sector,
            department: .developmentReform,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 65,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(stabilityChange: 3, standingChange: 10, networkChange: 8),
            failureEffects: MinistryEffects(stabilityChange: -2, standingChange: -6)
        ),

        StateMinistryAction(
            id: "issue_ministry_directive",
            name: "Issue Ministry Directive",
            description: "Issue binding orders to subordinate units",
            detailedDescription: "Exercise your authority to issue binding directives to all units under your ministry's jurisdiction. Effective use of directive power demonstrates command capability.",
            iconName: "doc.fill.badge.ellipsis",
            actionVerb: "Issue",
            category: .stateCouncilor,
            minimumPositionIndex: 5,
            targetType: .ministry,
            department: nil,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: true,
            successEffects: MinistryEffects(stabilityChange: 2, standingChange: 8),
            failureEffects: MinistryEffects(stabilityChange: -2, standingChange: -4)
        ),

        StateMinistryAction(
            id: "present_state_council_report",
            name: "Present to State Council",
            description: "Report directly to State Council meeting",
            detailedDescription: "Present your ministry's work and proposals directly to a State Council meeting. This high-visibility opportunity can significantly enhance your standing if successful.",
            iconName: "person.wave.2.fill",
            actionVerb: "Present",
            category: .stateCouncilor,
            minimumPositionIndex: 5,
            targetType: .none,
            department: .generalOffice,
            requiredTrack: nil,
            cooldownTurns: 6,
            executionTurns: 1,
            baseSuccessChance: 60,
            riskLevel: .major,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: MinistryEffects(standingChange: 12, patronFavorChange: 5),
            failureEffects: MinistryEffects(standingChange: -8, patronFavorChange: -4)
        ),

        // TIER 7+: Premier Level Actions
        StateMinistryAction(
            id: "chair_executive_meeting",
            name: "Chair State Council Executive Meeting",
            description: "Lead State Council executive session",
            detailedDescription: "Chair the State Council Executive Meeting that guides government work between plenary sessions. This is the heart of executive power in the state apparatus.",
            iconName: "person.3.sequence.fill",
            actionVerb: "Chair",
            category: .premier,
            minimumPositionIndex: 7,
            targetType: .none,
            department: .generalOffice,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: true,
            successEffects: MinistryEffects(stabilityChange: 5, standingChange: 15),
            failureEffects: MinistryEffects(stabilityChange: -3, standingChange: -5)
        ),

        StateMinistryAction(
            id: "issue_state_council_decree",
            name: "Issue State Council Decree",
            description: "Promulgate binding administrative decree",
            detailedDescription: "Issue a State Council decree with the force of law throughout the state apparatus. Decrees can reshape policy and demonstrate the full weight of your authority.",
            iconName: "scroll.fill",
            actionVerb: "Decree",
            category: .premier,
            minimumPositionIndex: 7,
            targetType: .policy,
            department: nil,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: MinistryEffects(stabilityChange: 5, popularSupportChange: 5, standingChange: 15),
            failureEffects: MinistryEffects(stabilityChange: -5, standingChange: -10)
        ),

        StateMinistryAction(
            id: "reorganize_ministry",
            name: "Reorganize Ministry Structure",
            description: "Restructure ministry organization",
            detailedDescription: "Exercise premier-level authority to reorganize ministry structures, merge departments, or create new administrative units. Organizational changes reshape the bureaucratic landscape.",
            iconName: "rectangle.3.group.fill",
            actionVerb: "Reorganize",
            category: .premier,
            minimumPositionIndex: 7,
            targetType: .ministry,
            department: nil,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 3,
            baseSuccessChance: 65,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: MinistryEffects(stabilityChange: -5, standingChange: 20, networkChange: 10, initiatesReform: true),
            failureEffects: MinistryEffects(stabilityChange: -8, standingChange: -15)
        ),

        StateMinistryAction(
            id: "launch_national_campaign",
            name: "Launch National Administrative Campaign",
            description: "Initiate nationwide government campaign",
            detailedDescription: "Launch a national campaign mobilizing the entire state apparatus toward a specific goal. Campaigns demonstrate the reach of your authority and can achieve dramatic results.",
            iconName: "flag.fill",
            actionVerb: "Launch",
            category: .premier,
            minimumPositionIndex: 7,
            targetType: .sector,
            department: nil,
            requiredTrack: nil,
            cooldownTurns: 10,
            executionTurns: 4,
            baseSuccessChance: 55,
            riskLevel: .extreme,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: MinistryEffects(stabilityChange: 8, popularSupportChange: 10, industrialOutputChange: 8, standingChange: 20),
            failureEffects: MinistryEffects(stabilityChange: -10, popularSupportChange: -8, standingChange: -15)
        )
    ]
}
