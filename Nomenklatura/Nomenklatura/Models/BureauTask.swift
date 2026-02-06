//
//  BureauTask.swift
//  Nomenklatura
//
//  Actionable tasks that players can initiate from the Ledger operations center.
//  Links to existing action systems (SecurityAction, EconomicAction, etc.)
//

import Foundation

// MARK: - Bureau Task

/// An actionable task available from the Ledger operations center
struct BureauTask: Identifiable, Sendable {
    let id: String
    let bureauTrack: String                    // ExpandedCareerTrack.rawValue
    let name: String
    let briefDescription: String
    let fullDescription: String
    let iconName: String

    // Link to existing action systems
    let actionId: String                       // ID in SecurityAction, EconomicAction, etc.
    let actionCategory: String                 // e.g., "security", "economic", "party"

    // Requirements
    let minimumPosition: Int                   // Required position level (0-8)
    let requiredAffinity: Int                  // Required affinity with bureau (0-100)
    let networkCost: Int                       // Network points required
    let cooldownTurns: Int                     // Turns before can use again

    // Availability state
    var isAvailable: Bool
    var unavailableReason: String?
    var cooldownRemaining: Int                 // 0 if available

    // Effects preview
    var estimatedDuration: Int?                // Turns to complete
    var riskLevel: BureauRiskLevel
    var potentialEffects: [String]             // Brief list like ["±Stability", "-Network"]

    // MARK: - Computed Properties

    var bureau: ExpandedCareerTrack? {
        ExpandedCareerTrack(rawValue: bureauTrack)
    }

    var isOnCooldown: Bool {
        cooldownRemaining > 0
    }

    var canInitiate: Bool {
        isAvailable && !isOnCooldown
    }

    // MARK: - Initialization

    init(
        id: String,
        bureauTrack: String,
        name: String,
        briefDescription: String,
        fullDescription: String = "",
        iconName: String,
        actionId: String,
        actionCategory: String,
        minimumPosition: Int = 0,
        requiredAffinity: Int = 0,
        networkCost: Int = 0,
        cooldownTurns: Int = 0,
        isAvailable: Bool = true,
        unavailableReason: String? = nil,
        cooldownRemaining: Int = 0,
        estimatedDuration: Int? = nil,
        riskLevel: BureauRiskLevel = .moderate,
        potentialEffects: [String] = []
    ) {
        self.id = id
        self.bureauTrack = bureauTrack
        self.name = name
        self.briefDescription = briefDescription
        self.fullDescription = fullDescription.isEmpty ? briefDescription : fullDescription
        self.iconName = iconName
        self.actionId = actionId
        self.actionCategory = actionCategory
        self.minimumPosition = minimumPosition
        self.requiredAffinity = requiredAffinity
        self.networkCost = networkCost
        self.cooldownTurns = cooldownTurns
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
        self.cooldownRemaining = cooldownRemaining
        self.estimatedDuration = estimatedDuration
        self.riskLevel = riskLevel
        self.potentialEffects = potentialEffects
    }
}

// MARK: - Predefined Tasks by Bureau

extension BureauTask {

    // MARK: - Security Services Tasks

    static func securityTasks() -> [BureauTask] {
        [
            BureauTask(
                id: "sec_open_investigation",
                bureauTrack: ExpandedCareerTrack.securityServices.rawValue,
                name: "Open Investigation",
                briefDescription: "Begin investigating a suspicious individual or activity",
                fullDescription: "Launch a formal investigation into potential subversive activities. Requires network resources to gather initial intelligence.",
                iconName: "magnifyingglass",
                actionId: "launch_formal_investigation",
                actionCategory: "security",
                minimumPosition: 3,
                networkCost: 10,
                cooldownTurns: 2,
                estimatedDuration: 3,
                riskLevel: .low,
                potentialEffects: ["-Network", "±Standing", "Intelligence"]
            ),
            BureauTask(
                id: "sec_request_surveillance",
                bureauTrack: ExpandedCareerTrack.securityServices.rawValue,
                name: "Request Surveillance",
                briefDescription: "Place a target under surveillance",
                fullDescription: "Submit a surveillance request through proper channels. Higher positions can approve their own requests.",
                iconName: "eye.fill",
                actionId: "request_surveillance_warrant",
                actionCategory: "security",
                minimumPosition: 2,
                networkCost: 5,
                cooldownTurns: 1,
                estimatedDuration: 2,
                riskLevel: .low,
                potentialEffects: ["-Network", "Evidence"]
            ),
            BureauTask(
                id: "sec_issue_detention",
                bureauTrack: ExpandedCareerTrack.securityServices.rawValue,
                name: "Issue Detention Order",
                briefDescription: "Authorize the detention of a suspect",
                fullDescription: "Issue an order to detain an individual for questioning. High-risk action with significant consequences.",
                iconName: "lock.fill",
                actionId: "request_shuanggui",
                actionCategory: "security",
                minimumPosition: 4,
                networkCost: 15,
                cooldownTurns: 3,
                riskLevel: .high,
                potentialEffects: ["-Network", "-Stability", "±Standing", "Evidence"]
            ),
            BureauTask(
                id: "sec_launch_purge",
                bureauTrack: ExpandedCareerTrack.securityServices.rawValue,
                name: "Launch Anti-Corruption Campaign",
                briefDescription: "Initiate a systematic campaign against corruption",
                fullDescription: "Begin a coordinated campaign to root out corruption and enemies of the state. Extremely high-risk with far-reaching consequences.",
                iconName: "flame.fill",
                actionId: "launch_anti_corruption_campaign",
                actionCategory: "security",
                minimumPosition: 6,
                networkCost: 30,
                cooldownTurns: 10,
                estimatedDuration: 5,
                riskLevel: .critical,
                potentialEffects: ["-Network", "-Stability", "±Elite Loyalty", "-Popular Support"]
            )
        ]
    }

    // MARK: - Economic Planning Tasks

    static func economicTasks() -> [BureauTask] {
        [
            BureauTask(
                id: "econ_adjust_quota",
                bureauTrack: ExpandedCareerTrack.economicPlanning.rawValue,
                name: "Set Regional Quota",
                briefDescription: "Modify production targets for a region",
                fullDescription: "Submit quota adjustments through the planning bureaucracy. Can ease pressure or demand greater output.",
                iconName: "chart.bar.fill",
                actionId: "set_regional_quota",
                actionCategory: "economic",
                minimumPosition: 3,
                networkCost: 5,
                cooldownTurns: 2,
                riskLevel: .low,
                potentialEffects: ["±Industrial Output", "±Treasury", "±Standing"]
            ),
            BureauTask(
                id: "econ_allocate_resources",
                bureauTrack: ExpandedCareerTrack.economicPlanning.rawValue,
                name: "Reallocate Budget",
                briefDescription: "Redirect resources to priority sectors",
                fullDescription: "Use your authority to reallocate scarce resources. Creates winners and losers in the system.",
                iconName: "shippingbox.fill",
                actionId: "reallocate_budget",
                actionCategory: "economic",
                minimumPosition: 4,
                networkCost: 10,
                cooldownTurns: 3,
                riskLevel: .moderate,
                potentialEffects: ["±Treasury", "±Industrial Output", "±Food Supply"]
            ),
            BureauTask(
                id: "econ_launch_project",
                bureauTrack: ExpandedCareerTrack.economicPlanning.rawValue,
                name: "Propose Modernization",
                briefDescription: "Initiate a major modernization initiative",
                fullDescription: "Begin a modernization project for industrial capacity. Long-term investment with significant resource commitment.",
                iconName: "building.2.fill",
                actionId: "propose_modernization",
                actionCategory: "economic",
                minimumPosition: 5,
                networkCost: 20,
                cooldownTurns: 5,
                estimatedDuration: 8,
                riskLevel: .moderate,
                potentialEffects: ["-Treasury", "+Industrial Output (future)", "±Standing"]
            ),
            BureauTask(
                id: "econ_inspection",
                bureauTrack: ExpandedCareerTrack.economicPlanning.rawValue,
                name: "Request Resources",
                briefDescription: "Submit resource requisition to central planning",
                fullDescription: "Request additional resources from central planning for your jurisdiction. Success depends on standing and connections.",
                iconName: "checklist",
                actionId: "request_resources",
                actionCategory: "economic",
                minimumPosition: 3,
                networkCost: 8,
                cooldownTurns: 2,
                estimatedDuration: 2,
                riskLevel: .low,
                potentialEffects: ["-Network", "+Treasury", "±Standing"]
            )
        ]
    }

    // MARK: - Party Apparatus Tasks

    static func partyTasks() -> [BureauTask] {
        [
            BureauTask(
                id: "party_personnel_review",
                bureauTrack: ExpandedCareerTrack.partyApparatus.rawValue,
                name: "Democratic Evaluation",
                briefDescription: "Review the political reliability of cadres",
                fullDescription: "Begin formal review of personnel in a department. Can identify loyal supporters or expose unreliable elements.",
                iconName: "person.text.rectangle",
                actionId: "democratic_evaluation",
                actionCategory: "party",
                minimumPosition: 3,
                networkCost: 10,
                cooldownTurns: 3,
                estimatedDuration: 3,
                riskLevel: .moderate,
                potentialEffects: ["-Network", "±Elite Loyalty", "Intelligence"]
            ),
            BureauTask(
                id: "party_launch_campaign",
                bureauTrack: ExpandedCareerTrack.partyApparatus.rawValue,
                name: "Launch Study Campaign",
                briefDescription: "Start a political education campaign",
                fullDescription: "Mobilize Party resources for mass political education. Shapes public opinion and reinforces ideological orthodoxy.",
                iconName: "megaphone.fill",
                actionId: "launch_study_campaign",
                actionCategory: "party",
                minimumPosition: 4,
                networkCost: 15,
                cooldownTurns: 4,
                estimatedDuration: 4,
                riskLevel: .low,
                potentialEffects: ["-Network", "±Popular Support", "±Standing"]
            ),
            BureauTask(
                id: "party_faction_maneuver",
                bureauTrack: ExpandedCareerTrack.partyApparatus.rawValue,
                name: "Discipline Inspection",
                briefDescription: "Conduct party discipline inspection",
                fullDescription: "Use Party discipline mechanisms to investigate and potentially sanction cadres. High-stakes political action.",
                iconName: "person.3.fill",
                actionId: "discipline_inspection",
                actionCategory: "party",
                minimumPosition: 5,
                networkCost: 20,
                cooldownTurns: 5,
                riskLevel: .high,
                potentialEffects: ["-Network", "±Rival Threat", "±Patron Favor", "±Elite Loyalty"]
            ),
            BureauTask(
                id: "party_rectification",
                bureauTrack: ExpandedCareerTrack.partyApparatus.rawValue,
                name: "Launch Nationwide Campaign",
                briefDescription: "Begin mass political campaign",
                fullDescription: "Initiate a Party-wide campaign to correct ideological deviations. Powerful but dangerous tool.",
                iconName: "arrow.triangle.2.circlepath",
                actionId: "launch_nationwide_campaign",
                actionCategory: "party",
                minimumPosition: 6,
                networkCost: 25,
                cooldownTurns: 8,
                estimatedDuration: 6,
                riskLevel: .critical,
                potentialEffects: ["-Network", "-Elite Loyalty", "±Stability", "±Standing"]
            )
        ]
    }

    // MARK: - Get All Tasks for Bureau

    static func tasks(for bureau: ExpandedCareerTrack) -> [BureauTask] {
        switch bureau {
        case .securityServices:
            return securityTasks()
        case .economicPlanning:
            return economicTasks()
        case .partyApparatus:
            return partyTasks()
        default:
            return []
        }
    }
}
