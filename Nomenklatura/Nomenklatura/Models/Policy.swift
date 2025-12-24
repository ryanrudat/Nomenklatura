//
//  Policy.swift
//  Nomenklatura
//
//  Policy system for Politburo-level legislative gameplay
//

import Foundation
import SwiftData

// MARK: - Policy Category

enum PolicyCategory: String, Codable, CaseIterable, Sendable {
    case economic       // Production, trade, labor, resource allocation
    case military       // Defense spending, foreign intervention, army control
    case ideological    // Party doctrine, propaganda, censorship, education
    case administrative // Appointments, restructuring, purges, promotions

    var displayName: String {
        switch self {
        case .economic: return "Economic"
        case .military: return "Military"
        case .ideological: return "Ideological"
        case .administrative: return "Administrative"
        }
    }

    var icon: String {
        switch self {
        case .economic: return "gearshape.2.fill"
        case .military: return "shield.fill"
        case .ideological: return "book.fill"
        case .administrative: return "person.3.fill"
        }
    }
}

// MARK: - Policy Status

enum PolicyStatus: String, Codable, Sendable {
    case proposed       // Awaiting sponsor to bring to floor
    case debating       // Currently on the Politburo floor
    case voting         // Vote in progress
    case passed         // Approved by majority
    case rejected       // Failed to pass
    case decreed        // Forced through by General Secretary
    case tabled         // Blocked/delayed indefinitely

    var displayName: String {
        switch self {
        case .proposed: return "Proposed"
        case .debating: return "Under Debate"
        case .voting: return "Voting"
        case .passed: return "Enacted"
        case .rejected: return "Rejected"
        case .decreed: return "Decreed"
        case .tabled: return "Tabled"
        }
    }

    var isActive: Bool {
        switch self {
        case .proposed, .debating, .voting:
            return true
        default:
            return false
        }
    }

    var isResolved: Bool {
        switch self {
        case .passed, .rejected, .decreed, .tabled:
            return true
        default:
            return false
        }
    }
}

// MARK: - Policy Model

@Model
final class Policy {
    @Attribute(.unique) var id: UUID
    var templateId: String      // Reference to policy template
    var title: String
    var policyDescription: String
    var category: String        // PolicyCategory.rawValue

    // Authorship
    var proposerId: String?     // Character who proposed
    var sponsorId: String?      // Character who sponsored (gave floor time)

    // Effects if passed
    var statEffects: [String: Int]         // National stat changes
    var factionEffects: [String: Int]?     // Faction power/standing changes
    var personalEffects: [String: Int]?    // Player stat changes for supporting

    // Voting state
    var status: String          // PolicyStatus.rawValue
    var votesFor: Int
    var votesAgainst: Int
    var votesNeeded: Int        // Usually simple majority of Politburo

    // Resistance tracking
    var forcedThrough: Bool     // Was this decreed over objections?
    var resistanceGenerated: Int // How much resistance this caused

    // Timing
    var proposedTurn: Int
    var resolvedTurn: Int?

    var createdAt: Date
    var updatedAt: Date

    init(
        templateId: String,
        title: String,
        description: String,
        category: PolicyCategory,
        statEffects: [String: Int],
        factionEffects: [String: Int]? = nil,
        personalEffects: [String: Int]? = nil,
        proposerId: String? = nil,
        currentTurn: Int
    ) {
        self.id = UUID()
        self.templateId = templateId
        self.title = title
        self.policyDescription = description
        self.category = category.rawValue
        self.proposerId = proposerId
        self.statEffects = statEffects
        self.factionEffects = factionEffects
        self.personalEffects = personalEffects
        self.status = PolicyStatus.proposed.rawValue
        self.votesFor = 0
        self.votesAgainst = 0
        self.votesNeeded = 4  // Majority of ~7 Politburo members
        self.forcedThrough = false
        self.resistanceGenerated = 0
        self.proposedTurn = currentTurn
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Policy Computed Properties

extension Policy {
    var currentCategory: PolicyCategory {
        PolicyCategory(rawValue: category) ?? .administrative
    }

    var currentStatus: PolicyStatus {
        PolicyStatus(rawValue: status) ?? .proposed
    }

    var votingProgress: Double {
        guard votesNeeded > 0 else { return 0 }
        return Double(votesFor) / Double(votesNeeded)
    }

    var isPassable: Bool {
        votesFor >= votesNeeded
    }

    var isRejectable: Bool {
        votesAgainst >= votesNeeded
    }
}

// MARK: - Policy Ability (What players can do with policies)

enum PolicyAbility: String, CaseIterable, Sendable {
    case vote           // Vote on current policy
    case lobby          // Build support for/against
    case propose        // Submit new policy
    case sponsor        // Guarantee floor time
    case controlAgenda  // Block or expedite policies
    case decree         // Force through as decree

    var displayName: String {
        switch self {
        case .vote: return "Vote"
        case .lobby: return "Lobby"
        case .propose: return "Propose"
        case .sponsor: return "Sponsor"
        case .controlAgenda: return "Control Agenda"
        case .decree: return "Decree"
        }
    }

    var description: String {
        switch self {
        case .vote:
            return "Cast your vote on policies before the Politburo"
        case .lobby:
            return "Build support among delegates for or against a policy"
        case .propose:
            return "Submit a new policy for consideration"
        case .sponsor:
            return "Use your influence to guarantee a policy gets floor time"
        case .controlAgenda:
            return "Block policies from reaching a vote, or expedite favored ones"
        case .decree:
            return "Force a policy through as a decree, bypassing normal voting"
        }
    }

    /// Minimum ladder position index required for this ability
    var requiredPositionIndex: Int {
        switch self {
        case .vote: return 1           // Junior Politburo
        case .lobby: return 2          // Deputy Dept Head
        case .propose: return 3        // Department Head
        case .sponsor: return 4        // Senior Politburo
        case .controlAgenda: return 5  // Deputy General Secretary
        case .decree: return 6         // General Secretary
        }
    }

    /// Check if player has this ability at given position
    static func availableAbilities(forPositionIndex index: Int) -> [PolicyAbility] {
        PolicyAbility.allCases.filter { $0.requiredPositionIndex <= index }
    }
}

// MARK: - Policy Vote

struct PolicyVote: Codable, Sendable {
    let characterId: String
    let characterName: String
    let vote: VoteChoice
    let influence: Int  // Weight of their vote

    enum VoteChoice: String, Codable, Sendable {
        case forPolicy = "for"
        case against = "against"
        case abstain = "abstain"
    }
}

// MARK: - Policy Template

/// Template for generating policies
struct PolicyTemplate: Codable, Identifiable, Sendable {
    var id: String
    var title: String
    var description: String
    var category: String
    var statEffects: [String: Int]
    var factionEffects: [String: Int]?
    var personalEffects: [String: Int]?
    var isControversial: Bool  // Whether this will generate strong reactions
    var requiredConditions: [String]?  // Game flags that must be present
}

// MARK: - Sample Policy Templates

extension PolicyTemplate {
    static let sampleTemplates: [PolicyTemplate] = [
        // Economic Policies
        PolicyTemplate(
            id: "increase_quotas",
            title: "Increase Industrial Quotas",
            description: "Raise production targets for all factories by 15%. Workers will be expected to exceed previous output.",
            category: PolicyCategory.economic.rawValue,
            statEffects: ["industrialOutput": 10, "popularSupport": -8],
            factionEffects: ["reformists": 5],  // Economic pragmatists benefit
            isControversial: true
        ),
        PolicyTemplate(
            id: "agricultural_reform",
            title: "Agricultural Reform Initiative",
            description: "Restructure collective farms to improve efficiency. Some local officials will lose their positions.",
            category: PolicyCategory.economic.rawValue,
            statEffects: ["foodSupply": 12, "eliteLoyalty": -5],
            factionEffects: ["regional": -3],  // Regional officials lose positions
            isControversial: true
        ),

        // Military Policies
        PolicyTemplate(
            id: "military_expansion",
            title: "Military Modernization Program",
            description: "Invest heavily in new weapons systems and expand the standing army.",
            category: PolicyCategory.military.rawValue,
            statEffects: ["militaryLoyalty": 15, "treasury": -20, "internationalStanding": -5],
            factionEffects: ["princelings": 10],  // Red aristocracy with military ties benefits
            isControversial: false
        ),
        PolicyTemplate(
            id: "reduce_military_budget",
            title: "Military Budget Reduction",
            description: "Redirect military spending to civilian projects. The generals will not be pleased.",
            category: PolicyCategory.military.rawValue,
            statEffects: ["treasury": 15, "militaryLoyalty": -20, "popularSupport": 5],
            factionEffects: ["princelings": -15],  // Red aristocracy with military ties loses
            isControversial: true
        ),

        // Ideological Policies
        PolicyTemplate(
            id: "ideological_campaign",
            title: "Ideological Purity Campaign",
            description: "Launch a campaign to root out revisionist thinking in the Party and universities.",
            category: PolicyCategory.ideological.rawValue,
            statEffects: ["stability": 5, "eliteLoyalty": -10],
            factionEffects: ["old_guard": 8],  // Ideological guardians lead campaigns
            personalEffects: ["reputationRuthless": 10],
            isControversial: true
        ),
        PolicyTemplate(
            id: "cultural_liberalization",
            title: "Cultural Liberalization",
            description: "Relax censorship and allow more artistic freedom. A risky but potentially popular move.",
            category: PolicyCategory.ideological.rawValue,
            statEffects: ["popularSupport": 10, "internationalStanding": 8, "stability": -5],
            factionEffects: ["old_guard": -5],  // Ideological guardians oppose liberalization
            isControversial: true
        ),

        // Administrative Policies
        PolicyTemplate(
            id: "anti_corruption",
            title: "Anti-Corruption Initiative",
            description: "Crack down on corruption in the Party apparatus. Many comfortable positions will be threatened.",
            category: PolicyCategory.administrative.rawValue,
            statEffects: ["eliteLoyalty": -15, "popularSupport": 10, "treasury": 8],
            factionEffects: ["princelings": -8],  // Privileged elite targeted by corruption campaigns
            personalEffects: ["reputationCompetent": 10],
            isControversial: true
        ),
        PolicyTemplate(
            id: "bureaucratic_expansion",
            title: "Bureaucratic Expansion",
            description: "Create new departments and positions. More jobs for loyal Party members.",
            category: PolicyCategory.administrative.rawValue,
            statEffects: ["eliteLoyalty": 10, "treasury": -8, "industrialOutput": -3],
            factionEffects: ["youth_league": 10],  // Meritocrats benefit from new positions
            isControversial: false
        )
    ]
}
