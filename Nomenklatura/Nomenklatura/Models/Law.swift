//
//  Law.swift
//  Nomenklatura
//
//  Laws and constitutional rules that can be modified by the General Secretary
//

import Foundation
import SwiftData

// MARK: - Law Category

enum LawCategory: String, Codable, CaseIterable {
    case institutional    // Term limits, voting rules, power structure
    case economic         // Property, labor, production systems
    case political        // Party structure, elections, censorship
    case social           // Religion, education, family, culture

    var displayName: String {
        switch self {
        case .institutional: return "Institutional"
        case .economic: return "Economic"
        case .political: return "Political"
        case .social: return "Social"
        }
    }

    var description: String {
        switch self {
        case .institutional:
            return "Fundamental rules governing state structure, succession, and power distribution"
        case .economic:
            return "Policies governing production, labor, property, and resource allocation"
        case .political:
            return "Regulations on Party organization, elections, media, and expression"
        case .social:
            return "Laws affecting culture, religion, education, and family life"
        }
    }

    /// Minimum power consolidation required to modify laws in this category
    var modificationDifficulty: Int {
        switch self {
        case .institutional: return 80  // Hardest - threatens everyone
        case .political: return 60
        case .economic: return 50
        case .social: return 40         // Easiest
        }
    }

    var iconName: String {
        switch self {
        case .institutional: return "building.columns.fill"
        case .economic: return "chart.bar.fill"
        case .political: return "person.3.fill"
        case .social: return "house.fill"
        }
    }
}

// MARK: - Law State

enum LawState: String, Codable, CaseIterable {
    case defaultState       // Original law as enacted
    case modifiedWeak       // Minor modification
    case modifiedStrong     // Major modification
    case abolished          // Completely removed
    case strengthened       // Made more restrictive

    var displayName: String {
        switch self {
        case .defaultState: return "Standard"
        case .modifiedWeak: return "Modified"
        case .modifiedStrong: return "Significantly Changed"
        case .abolished: return "Abolished"
        case .strengthened: return "Strengthened"
        }
    }
}

// MARK: - Consequence Type

enum ConsequenceType: String, Codable {
    case coalitionForms         // Opposition organizes
    case factionRebellion       // Specific faction acts
    case popularUnrest          // Mass discontent
    case eliteBacklash          // Politburo resistance
    case internationalPressure  // Foreign condemnation
    case economicEffect         // Delayed economic impact
    case characterAction        // Specific NPC responds
    case militaryUnrest         // Army concerns
    case regionalTension        // Regional instability increases

    var displayName: String {
        switch self {
        case .coalitionForms: return "Coalition Forms"
        case .factionRebellion: return "Faction Rebellion"
        case .popularUnrest: return "Popular Unrest"
        case .eliteBacklash: return "Elite Backlash"
        case .internationalPressure: return "International Pressure"
        case .economicEffect: return "Economic Effect"
        case .characterAction: return "Character Action"
        case .militaryUnrest: return "Military Unrest"
        case .regionalTension: return "Regional Tension"
        }
    }
}

// MARK: - Scheduled Consequence

struct ScheduledConsequence: Codable, Identifiable {
    var id: UUID = UUID()
    var triggerTurn: Int
    var type: ConsequenceType
    var magnitude: Int              // Severity of the consequence (1-100)
    var description: String
    var hasTriggered: Bool = false
    var relatedLawId: String?
    var relatedCharacterId: String?
    var statEffects: [String: Int]? // Stats to modify when triggered

    init(
        triggerTurn: Int,
        type: ConsequenceType,
        magnitude: Int,
        description: String,
        relatedLawId: String? = nil,
        relatedCharacterId: String? = nil,
        statEffects: [String: Int]? = nil
    ) {
        self.id = UUID()
        self.triggerTurn = triggerTurn
        self.type = type
        self.magnitude = magnitude
        self.description = description
        self.hasTriggered = false
        self.relatedLawId = relatedLawId
        self.relatedCharacterId = relatedCharacterId
        self.statEffects = statEffects
    }
}

// MARK: - Law Model

@Model
final class Law {
    @Attribute(.unique) var id: UUID
    var lawId: String                   // Unique identifier like "term_limits"
    var name: String
    var lawDescription: String
    var category: String                // LawCategory.rawValue
    var currentState: String            // LawState.rawValue
    var defaultState: String            // LawState.rawValue - original state

    var turnEnacted: Int?               // When the current state was set
    var enactedBy: String?              // Character name who changed it
    var wasForced: Bool                 // Was decreed vs voted

    // Who benefits/loses from this law
    var beneficiaries: [String]         // Faction IDs that benefit
    var losers: [String]                // Faction IDs that lose

    // Resistance tracking
    var resistanceGenerated: Int        // Cumulative resistance since enactment

    // Scheduled consequences (encoded)
    var scheduledConsequencesData: Data?

    var game: Game?

    init(lawId: String, name: String, description: String, category: LawCategory) {
        self.id = UUID()
        self.lawId = lawId
        self.name = name
        self.lawDescription = description
        self.category = category.rawValue
        self.currentState = LawState.defaultState.rawValue
        self.defaultState = LawState.defaultState.rawValue
        self.wasForced = false
        self.beneficiaries = []
        self.losers = []
        self.resistanceGenerated = 0
    }

    // MARK: - Computed Properties

    var lawCategory: LawCategory {
        LawCategory(rawValue: category) ?? .institutional
    }

    var lawCurrentState: LawState {
        LawState(rawValue: currentState) ?? .defaultState
    }

    var lawDefaultState: LawState {
        LawState(rawValue: defaultState) ?? .defaultState
    }

    var hasBeenModified: Bool {
        currentState != defaultState
    }

    var scheduledConsequences: [ScheduledConsequence] {
        get {
            guard let data = scheduledConsequencesData else { return [] }
            return (try? JSONDecoder().decode([ScheduledConsequence].self, from: data)) ?? []
        }
        set {
            scheduledConsequencesData = try? JSONEncoder().encode(newValue)
        }
    }

    var pendingConsequences: [ScheduledConsequence] {
        scheduledConsequences.filter { !$0.hasTriggered }
    }

    // MARK: - Methods

    func addConsequence(_ consequence: ScheduledConsequence) {
        var consequences = scheduledConsequences
        consequences.append(consequence)
        scheduledConsequences = consequences
    }

    func markConsequenceTriggered(id: UUID) {
        var consequences = scheduledConsequences
        if let index = consequences.firstIndex(where: { $0.id == id }) {
            consequences[index].hasTriggered = true
            scheduledConsequences = consequences
        }
    }

    func modify(to newState: LawState, by characterName: String, forced: Bool, turn: Int) {
        self.currentState = newState.rawValue
        self.turnEnacted = turn
        self.enactedBy = characterName
        self.wasForced = forced
    }

    func restore() {
        self.currentState = defaultState
        self.turnEnacted = nil
        self.enactedBy = nil
        self.wasForced = false
        self.resistanceGenerated = 0
        self.scheduledConsequences = []
    }
}

// MARK: - Default Laws

extension Law {

    /// Create default laws for a new game
    static func createDefaultLaws() -> [Law] {
        var laws: [Law] = []

        // INSTITUTIONAL LAWS
        let termLimits = Law(
            lawId: "term_limits",
            name: "Term Limits for General Secretary",
            description: "The General Secretary serves a maximum of two terms of four years each. After eight years, the leader must step down and allow for orderly succession.",
            category: .institutional
        )
        termLimits.beneficiaries = ["youth_league"]  // Meritocrats benefit from regular turnover
        laws.append(termLimits)

        let collectiveLeadership = Law(
            lawId: "collective_leadership",
            name: "Collective Leadership Principle",
            description: "Major state decisions require consensus of the Presidium. No single individual may act unilaterally on matters of war, peace, or constitutional change.",
            category: .institutional
        )
        collectiveLeadership.beneficiaries = ["youth_league", "princelings"]  // Prevents any one faction from dominating
        laws.append(collectiveLeadership)

        let appointmentApproval = Law(
            lawId: "appointment_approval",
            name: "Appointment Confirmation Process",
            description: "Senior appointments to ministerial and regional leadership positions require approval by the Standing Committee of the Presidium.",
            category: .institutional
        )
        appointmentApproval.beneficiaries = ["youth_league"]  // Merit-based appointments help meritocrats
        laws.append(appointmentApproval)

        // POLITICAL LAWS
        let partyElections = Law(
            lawId: "party_elections",
            name: "Internal Party Elections",
            description: "Local Party committees are elected by registered Party members. Regional and national leadership is selected through delegate congresses.",
            category: .political
        )
        partyElections.beneficiaries = ["youth_league"]  // Meritocrats benefit from electoral advancement
        laws.append(partyElections)

        let pressControl = Law(
            lawId: "press_control",
            name: "State Media Guidelines",
            description: "All publications, broadcasts, and public communications require editorial approval from the Propaganda Department. Counter-revolutionary content is prohibited.",
            category: .political
        )
        pressControl.beneficiaries = ["old_guard", "youth_league"]  // Ideological guardians and party apparatus control media
        laws.append(pressControl)

        let assemblyRights = Law(
            lawId: "assembly_rights",
            name: "Public Assembly Regulations",
            description: "Public gatherings require advance permission from local authorities. Unauthorized assemblies may be dispersed.",
            category: .political
        )
        assemblyRights.beneficiaries = ["old_guard"]  // Security-focused ideological guardians enforce assembly rules
        laws.append(assemblyRights)

        // ECONOMIC LAWS
        let enterpriseQuotas = Law(
            lawId: "enterprise_quotas",
            name: "Production Quota System",
            description: "State enterprises must meet centrally-set production quotas. Managers are responsible for plan fulfillment and may face consequences for failure.",
            category: .economic
        )
        enterpriseQuotas.beneficiaries = ["reformists"]  // Economic pragmatists manage quotas
        laws.append(enterpriseQuotas)

        let privatePlots = Law(
            lawId: "private_plots",
            name: "Collective Farm Private Plots",
            description: "Collective farm members may cultivate small personal plots for household consumption. Surplus may be sold at local markets.",
            category: .economic
        )
        privatePlots.losers = ["old_guard"]  // Ideological purists oppose private enterprise
        laws.append(privatePlots)

        let foreignTrade = Law(
            lawId: "foreign_trade",
            name: "State Monopoly on Foreign Trade",
            description: "All international trade must be conducted through state trading organizations. Private foreign commerce is prohibited.",
            category: .economic
        )
        foreignTrade.beneficiaries = ["reformists"]  // Economic pragmatists control trade
        laws.append(foreignTrade)

        // SOCIAL LAWS
        let religiousTolerance = Law(
            lawId: "religious_tolerance",
            name: "Religious Practice Policy",
            description: "Limited religious observance is permitted in registered places of worship. Religious education of minors and proselytizing are restricted.",
            category: .social
        )
        laws.append(religiousTolerance)

        let educationControl = Law(
            lawId: "education_control",
            name: "State Education System",
            description: "All education is provided by the state according to socialist principles. Private and religious schools are prohibited.",
            category: .social
        )
        educationControl.beneficiaries = ["old_guard"]  // Ideological guardians control education
        laws.append(educationControl)

        let internalPassport = Law(
            lawId: "internal_passport",
            name: "Internal Passport System",
            description: "Citizens must carry internal passports and register their residence. Travel between regions requires authorization.",
            category: .social
        )
        internalPassport.beneficiaries = ["old_guard"]  // Security apparatus controls movement
        laws.append(internalPassport)

        return laws
    }
}

// MARK: - Law Change Requirements

struct LawChangeRequirement {
    var powerRequired: Int
    var factionSupportRequired: [String: Int]?  // Faction ID -> minimum standing
    var canBeForced: Bool                        // Can be decreed without vote
    var forcePowerRequired: Int                  // Extra power needed to force

    static func requirements(for law: Law, toState: LawState) -> LawChangeRequirement {
        let category = law.lawCategory
        var basepower = category.modificationDifficulty

        // Abolishing is harder than modifying
        if toState == .abolished {
            basepower += 15
        }

        // Special case: term limits are the hardest
        if law.lawId == "term_limits" && toState == .abolished {
            return LawChangeRequirement(
                powerRequired: 85,
                factionSupportRequired: ["princelings": 60, "youth_league": 70],  // Need military elite and party support
                canBeForced: true,
                forcePowerRequired: 95
            )
        }

        // Determine faction support needed based on beneficiaries/losers
        var factionSupport: [String: Int]? = nil
        if !law.losers.isEmpty {
            factionSupport = [:]
            for faction in law.losers {
                factionSupport?[faction] = 40  // Need at least neutral standing
            }
        }

        return LawChangeRequirement(
            powerRequired: basepower,
            factionSupportRequired: factionSupport,
            canBeForced: category != .institutional,
            forcePowerRequired: basepower + 20
        )
    }
}
