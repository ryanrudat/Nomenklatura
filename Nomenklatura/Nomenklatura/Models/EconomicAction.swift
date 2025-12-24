//
//  EconomicAction.swift
//  Nomenklatura
//
//  Position-gated economic planning actions following Soviet Gosplan structure.
//  Modeled on centralized economic planning with quota systems and resource allocation.
//

import Foundation

// MARK: - Economic Action Category

/// Categories of economic actions based on Gosplan organizational structure
enum EconomicActionCategory: String, Codable, CaseIterable {
    case production      // Position 1-2: Factory floor, quota implementation
    case planning        // Position 2-3: Production targets, labor allocation
    case allocation      // Position 3-4: Resource distribution, priority sectors
    case reform          // Position 4-5: Structural changes, modernization
    case strategic       // Position 5-6: Five-year plans, major initiatives
    case supreme         // Position 7+: Economic policy direction, system changes

    var displayName: String {
        switch self {
        case .production: return "Production"
        case .planning: return "Planning"
        case .allocation: return "Allocation"
        case .reform: return "Reform"
        case .strategic: return "Strategic"
        case .supreme: return "Supreme Economic Authority"
        }
    }

    var minimumPositionIndex: Int {
        switch self {
        case .production: return 1
        case .planning: return 2
        case .allocation: return 3
        case .reform: return 4
        case .strategic: return 5
        case .supreme: return 7
        }
    }

    var gosplanEquivalent: String {
        switch self {
        case .production: return "Factory Manager"
        case .planning: return "Regional Planner"
        case .allocation: return "Sector Coordinator"
        case .reform: return "Deputy Minister"
        case .strategic: return "Gosplan Deputy Chairman"
        case .supreme: return "Gosplan Chairman"
        }
    }
}

// MARK: - Economic Target Type

/// What the economic action targets
enum EconomicTargetType: String, Codable {
    case region         // Target a specific region
    case sector         // Target economic sector (industry, agriculture, etc.)
    case enterprise     // Target specific enterprise/factory
    case tradePartner   // Target foreign trade relationship
    case budget         // Target budget allocation
    case none           // No specific target
}

// MARK: - Economic Sector

/// Economic sectors for targeting
enum EconomicSector: String, Codable, CaseIterable {
    case heavyIndustry      // Steel, machinery, military production
    case lightIndustry      // Consumer goods, textiles
    case agriculture        // Farming, collective farms
    case energy             // Coal, oil, nuclear
    case mining             // Resource extraction
    case construction       // Housing, infrastructure
    case transport          // Railways, roads, shipping
    case defense            // Military-industrial complex

    var displayName: String {
        switch self {
        case .heavyIndustry: return "Heavy Industry"
        case .lightIndustry: return "Light Industry"
        case .agriculture: return "Agriculture"
        case .energy: return "Energy"
        case .mining: return "Mining"
        case .construction: return "Construction"
        case .transport: return "Transport"
        case .defense: return "Defense Industry"
        }
    }

    var iconName: String {
        switch self {
        case .heavyIndustry: return "gearshape.2.fill"
        case .lightIndustry: return "tshirt.fill"
        case .agriculture: return "leaf.fill"
        case .energy: return "bolt.fill"
        case .mining: return "cube.fill"
        case .construction: return "building.2.fill"
        case .transport: return "train.side.front.car"
        case .defense: return "shield.fill"
        }
    }
}

// MARK: - Economic Effects

/// Effects from economic actions
struct EconomicEffects: Codable {
    // National economic effects
    var treasuryChange: Int = 0
    var industrialOutputChange: Int = 0
    var foodSupplyChange: Int = 0
    var stabilityChange: Int = 0

    // Support effects
    var popularSupportChange: Int = 0
    var eliteLoyaltyChange: Int = 0
    var militaryLoyaltyChange: Int = 0

    // Personal effects
    var standingChange: Int = 0
    var networkChange: Int = 0
    var patronFavorChange: Int = 0

    // Regional effects (applied to target region)
    var regionalIndustryChange: Int = 0
    var regionalAgricultureChange: Int = 0
    var regionalLoyaltyChange: Int = 0

    // Trade effects
    var internationalStandingChange: Int = 0

    // Flags
    var createsFlag: String? = nil
    var removesFlag: String? = nil
    var triggersEvent: String? = nil

    // Special outcomes
    var startsProject: Bool = false
    var completesQuota: Bool = false
    var causesShortage: Bool = false
}

// MARK: - Economic Risk Level

enum EconomicRiskLevel: String, Codable {
    case routine        // Standard operations
    case moderate       // Some political risk
    case significant    // Notable consequences if failed
    case major          // Major political/economic fallout
    case systemic       // Could destabilize the system

    var displayName: String {
        switch self {
        case .routine: return "Routine"
        case .moderate: return "Moderate"
        case .significant: return "Significant"
        case .major: return "Major"
        case .systemic: return "Systemic"
        }
    }
}

// MARK: - Economic Action

/// A position-gated economic planning action
struct EconomicAction: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let detailedDescription: String
    let iconName: String
    let actionVerb: String              // "Set", "Allocate", "Reform", etc.

    let category: EconomicActionCategory
    let minimumPositionIndex: Int
    let targetType: EconomicTargetType
    let targetSector: EconomicSector?   // If targeting a specific sector
    let requiredTrack: String?          // "economicPlanning" for some actions

    let cooldownTurns: Int
    let executionTurns: Int             // Some actions take multiple turns
    let baseSuccessChance: Int          // 0-100
    let riskLevel: EconomicRiskLevel

    let requiresCommitteeApproval: Bool
    let canBeDecree: Bool               // Can be issued as General Secretary decree

    let successEffects: EconomicEffects
    let failureEffects: EconomicEffects

    /// Check if action is available for position
    func isAvailable(forPosition position: Int, track: String?) -> Bool {
        guard position >= minimumPositionIndex else { return false }
        if let required = requiredTrack {
            return track == required || position >= 6  // High positions transcend track limits
        }
        return true
    }
}

// MARK: - Economic Action Definitions

extension EconomicAction {

    /// All defined economic actions (25+ actions across 6 tiers)
    static let allActions: [EconomicAction] = [
        // TIER 1-2: Production Actions (Factory Manager Level)
        EconomicAction(
            id: "report_production",
            name: "Report Production Status",
            description: "File accurate production reports",
            detailedDescription: "Submit truthful reports on factory output, resource usage, and worker productivity. Honest reporting is valued but can expose shortfalls.",
            iconName: "doc.text.fill",
            actionVerb: "Report",
            category: .production,
            minimumPositionIndex: 1,
            targetType: .enterprise,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 0,
            executionTurns: 1,
            baseSuccessChance: 100,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(standingChange: 2),
            failureEffects: EconomicEffects()
        ),

        EconomicAction(
            id: "meet_quota",
            name: "Meet Production Quota",
            description: "Fulfill assigned production targets",
            detailedDescription: "Push workers and resources to meet the assigned quota. Success brings recognition; failure invites scrutiny.",
            iconName: "checkmark.circle.fill",
            actionVerb: "Meet",
            category: .production,
            minimumPositionIndex: 1,
            targetType: .enterprise,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 1,
            executionTurns: 1,
            baseSuccessChance: 70,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(industrialOutputChange: 2, standingChange: 5),
            failureEffects: EconomicEffects(stabilityChange: -1, standingChange: -5)
        ),

        EconomicAction(
            id: "exceed_quota",
            name: "Exceed Quota (Stakhanovite)",
            description: "Push for above-target production",
            detailedDescription: "Emulate Stakhanovite heroes by dramatically exceeding quotas. High risk of burnout and quality issues, but great rewards if successful.",
            iconName: "star.fill",
            actionVerb: "Exceed",
            category: .production,
            minimumPositionIndex: 2,
            targetType: .enterprise,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 45,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(industrialOutputChange: 5, popularSupportChange: 2, standingChange: 10),
            failureEffects: EconomicEffects(industrialOutputChange: -3, popularSupportChange: -3, standingChange: -8)
        ),

        EconomicAction(
            id: "falsify_reports",
            name: "Falsify Production Reports",
            description: "Inflate numbers to meet targets",
            detailedDescription: "Submit fraudulent reports showing quotas met. Common practice but risky if audited.",
            iconName: "doc.badge.ellipsis",
            actionVerb: "Falsify",
            category: .production,
            minimumPositionIndex: 1,
            targetType: .enterprise,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 75,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(standingChange: 5, createsFlag: "falsified_reports"),
            failureEffects: EconomicEffects(stabilityChange: -2, standingChange: -15)
        ),

        // TIER 2-3: Planning Actions (Regional Planner Level)
        EconomicAction(
            id: "set_regional_quota",
            name: "Set Regional Quota",
            description: "Establish production targets for region",
            detailedDescription: "Define production targets for factories and collective farms in your region. Balance ambition with achievability.",
            iconName: "chart.bar.fill",
            actionVerb: "Set",
            category: .planning,
            minimumPositionIndex: 2,
            targetType: .region,
            targetSector: nil,
            requiredTrack: "economicPlanning",
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(industrialOutputChange: 2, standingChange: 3),
            failureEffects: EconomicEffects(standingChange: -3)
        ),

        EconomicAction(
            id: "allocate_labor",
            name: "Allocate Labor Force",
            description: "Direct workers to priority sectors",
            detailedDescription: "Transfer workers between sectors based on plan priorities. May cause resentment but fulfills directives.",
            iconName: "person.3.fill",
            actionVerb: "Allocate",
            category: .planning,
            minimumPositionIndex: 2,
            targetType: .sector,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 75,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(industrialOutputChange: 3, popularSupportChange: -2),
            failureEffects: EconomicEffects(stabilityChange: -2, popularSupportChange: -5)
        ),

        EconomicAction(
            id: "request_resources",
            name: "Request Additional Resources",
            description: "Petition for more raw materials",
            detailedDescription: "Submit formal request for additional resource allocation from central planners. Success depends on relationships and priorities.",
            iconName: "shippingbox.fill",
            actionVerb: "Request",
            category: .planning,
            minimumPositionIndex: 2,
            targetType: .none,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 50,
            riskLevel: .routine,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(industrialOutputChange: 4, networkChange: 2),
            failureEffects: EconomicEffects(standingChange: -2)
        ),

        EconomicAction(
            id: "propose_efficiency",
            name: "Propose Efficiency Measures",
            description: "Suggest productivity improvements",
            detailedDescription: "Submit proposals for improving production efficiency. May be seen as criticizing current methods.",
            iconName: "gearshape.arrow.triangle.2.circlepath",
            actionVerb: "Propose",
            category: .planning,
            minimumPositionIndex: 3,
            targetType: .sector,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 2,
            executionTurns: 1,
            baseSuccessChance: 60,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(industrialOutputChange: 3, standingChange: 5),
            failureEffects: EconomicEffects(standingChange: -5)
        ),

        // TIER 3-4: Allocation Actions (Sector Coordinator Level)
        EconomicAction(
            id: "prioritize_sector",
            name: "Prioritize Sector",
            description: "Direct resources to priority sector",
            detailedDescription: "Reallocate national resources to a chosen economic sector. Benefits one area at the expense of others.",
            iconName: "arrow.up.forward.circle.fill",
            actionVerb: "Prioritize",
            category: .allocation,
            minimumPositionIndex: 3,
            targetType: .sector,
            targetSector: nil,
            requiredTrack: "economicPlanning",
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 70,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(industrialOutputChange: 5, standingChange: 5),
            failureEffects: EconomicEffects(stabilityChange: -2, standingChange: -5)
        ),

        EconomicAction(
            id: "authorize_imports",
            name: "Authorize Foreign Imports",
            description: "Approve import of foreign goods/technology",
            detailedDescription: "Grant permission to import foreign machinery or technology. May be seen as admitting domestic shortcomings.",
            iconName: "arrow.down.to.line.circle.fill",
            actionVerb: "Authorize",
            category: .allocation,
            minimumPositionIndex: 4,
            targetType: .tradePartner,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 3,
            executionTurns: 1,
            baseSuccessChance: 65,
            riskLevel: .moderate,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(treasuryChange: -3, industrialOutputChange: 4, internationalStandingChange: 2),
            failureEffects: EconomicEffects(standingChange: -3)
        ),

        EconomicAction(
            id: "reallocate_budget",
            name: "Reallocate Ministry Budget",
            description: "Shift funds between ministries",
            detailedDescription: "Transfer budget allocations between ministries. Creates winners and losers in the bureaucracy.",
            iconName: "arrow.left.arrow.right.circle.fill",
            actionVerb: "Reallocate",
            category: .allocation,
            minimumPositionIndex: 4,
            targetType: .budget,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 60,
            riskLevel: .significant,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(treasuryChange: 3, eliteLoyaltyChange: -2, standingChange: 3),
            failureEffects: EconomicEffects(eliteLoyaltyChange: -3, standingChange: -5)
        ),

        EconomicAction(
            id: "emergency_requisition",
            name: "Emergency Requisition",
            description: "Seize resources for urgent needs",
            detailedDescription: "Commandeer resources from lower-priority sectors to address urgent shortfalls. Heavy-handed but effective.",
            iconName: "exclamationmark.triangle.fill",
            actionVerb: "Requisition",
            category: .allocation,
            minimumPositionIndex: 4,
            targetType: .sector,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .major,
            requiresCommitteeApproval: false,
            canBeDecree: false,
            successEffects: EconomicEffects(industrialOutputChange: 6, stabilityChange: -2, popularSupportChange: -5),
            failureEffects: EconomicEffects(stabilityChange: -5, standingChange: -10)
        ),

        // TIER 4-5: Reform Actions (Deputy Minister Level)
        EconomicAction(
            id: "propose_modernization",
            name: "Propose Modernization Program",
            description: "Plan industrial modernization",
            detailedDescription: "Submit comprehensive plan to modernize production methods. Requires significant investment but promises long-term gains.",
            iconName: "arrow.triangle.2.circlepath.circle.fill",
            actionVerb: "Propose",
            category: .reform,
            minimumPositionIndex: 4,
            targetType: .sector,
            targetSector: nil,
            requiredTrack: "economicPlanning",
            cooldownTurns: 5,
            executionTurns: 3,
            baseSuccessChance: 55,
            riskLevel: .significant,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(treasuryChange: -5, industrialOutputChange: 8, standingChange: 10, startsProject: true),
            failureEffects: EconomicEffects(treasuryChange: -3, standingChange: -8)
        ),

        EconomicAction(
            id: "agricultural_reform",
            name: "Agricultural Reform Initiative",
            description: "Restructure collective farming",
            detailedDescription: "Propose changes to collective farm organization. Can increase output but risks political backlash from ideological purists.",
            iconName: "leaf.arrow.triangle.circlepath",
            actionVerb: "Reform",
            category: .reform,
            minimumPositionIndex: 5,
            targetType: .sector,
            targetSector: .agriculture,
            requiredTrack: nil,
            cooldownTurns: 6,
            executionTurns: 3,
            baseSuccessChance: 50,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(foodSupplyChange: 10, popularSupportChange: 5, standingChange: 8),
            failureEffects: EconomicEffects(stabilityChange: -3, standingChange: -10)
        ),

        EconomicAction(
            id: "price_adjustment",
            name: "Adjust State Prices",
            description: "Modify controlled prices",
            detailedDescription: "Propose adjustments to state-controlled prices. Can reduce shortages but may cause inflation fears.",
            iconName: "rublesign.circle.fill",
            actionVerb: "Adjust",
            category: .reform,
            minimumPositionIndex: 5,
            targetType: .none,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 4,
            executionTurns: 1,
            baseSuccessChance: 60,
            riskLevel: .significant,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(treasuryChange: 5, popularSupportChange: -3, standingChange: 5),
            failureEffects: EconomicEffects(stabilityChange: -3, popularSupportChange: -8)
        ),

        EconomicAction(
            id: "create_enterprise",
            name: "Create New State Enterprise",
            description: "Establish new production facility",
            detailedDescription: "Propose creation of new state enterprise. Requires substantial investment and labor allocation.",
            iconName: "building.fill",
            actionVerb: "Create",
            category: .reform,
            minimumPositionIndex: 5,
            targetType: .region,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 5,
            baseSuccessChance: 60,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(treasuryChange: -10, industrialOutputChange: 10, standingChange: 10, startsProject: true),
            failureEffects: EconomicEffects(treasuryChange: -5, standingChange: -10)
        ),

        // TIER 5-6: Strategic Actions (Gosplan Deputy Chairman Level)
        EconomicAction(
            id: "five_year_plan",
            name: "Draft Five-Year Plan",
            description: "Create comprehensive economic plan",
            detailedDescription: "Lead the development of the next Five-Year Plan. The defining act of economic leadership in a socialist state.",
            iconName: "calendar.badge.clock",
            actionVerb: "Draft",
            category: .strategic,
            minimumPositionIndex: 5,
            targetType: .none,
            targetSector: nil,
            requiredTrack: "economicPlanning",
            cooldownTurns: 26,  // Once per "year"
            executionTurns: 3,
            baseSuccessChance: 65,
            riskLevel: .systemic,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(industrialOutputChange: 5, foodSupplyChange: 3, stabilityChange: 5, standingChange: 15),
            failureEffects: EconomicEffects(stabilityChange: -5, standingChange: -15)
        ),

        EconomicAction(
            id: "trade_agreement",
            name: "Negotiate Trade Agreement",
            description: "Establish trade deal with foreign nation",
            detailedDescription: "Negotiate comprehensive trade agreement with a foreign country. Affects treasury and international relations.",
            iconName: "arrow.left.arrow.right",
            actionVerb: "Negotiate",
            category: .strategic,
            minimumPositionIndex: 5,
            targetType: .tradePartner,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 5,
            executionTurns: 2,
            baseSuccessChance: 55,
            riskLevel: .significant,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(treasuryChange: 8, standingChange: 8, internationalStandingChange: 5),
            failureEffects: EconomicEffects(standingChange: -5, internationalStandingChange: -3)
        ),

        EconomicAction(
            id: "crisis_mobilization",
            name: "Economic Crisis Mobilization",
            description: "Emergency economic measures",
            detailedDescription: "Declare economic emergency and mobilize resources. Grants sweeping powers but creates long-term problems.",
            iconName: "exclamationmark.shield.fill",
            actionVerb: "Mobilize",
            category: .strategic,
            minimumPositionIndex: 6,
            targetType: .none,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 10,
            executionTurns: 1,
            baseSuccessChance: 80,
            riskLevel: .systemic,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: EconomicEffects(treasuryChange: 5, industrialOutputChange: 10, stabilityChange: -3, popularSupportChange: -5, standingChange: 10),
            failureEffects: EconomicEffects(stabilityChange: -10, standingChange: -15)
        ),

        EconomicAction(
            id: "purge_ministry",
            name: "Purge Ministry for Sabotage",
            description: "Remove officials for economic crimes",
            detailedDescription: "Blame economic failures on 'wreckers' and 'saboteurs' in a ministry. Deflects blame and creates fear.",
            iconName: "person.fill.xmark",
            actionVerb: "Purge",
            category: .strategic,
            minimumPositionIndex: 6,
            targetType: .sector,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 1,
            baseSuccessChance: 85,
            riskLevel: .major,
            requiresCommitteeApproval: false,
            canBeDecree: true,
            successEffects: EconomicEffects(stabilityChange: 3, eliteLoyaltyChange: -5, standingChange: 5),
            failureEffects: EconomicEffects(eliteLoyaltyChange: -10, standingChange: -10)
        ),

        // TIER 7+: Supreme Economic Authority (Gosplan Chairman Level)
        EconomicAction(
            id: "economic_decree",
            name: "Issue Economic Decree",
            description: "Decree major economic change",
            detailedDescription: "Issue a decree fundamentally altering economic policy. Bypasses normal planning process.",
            iconName: "scroll.fill",
            actionVerb: "Decree",
            category: .supreme,
            minimumPositionIndex: 7,
            targetType: .none,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 1,
            baseSuccessChance: 90,
            riskLevel: .systemic,
            requiresCommitteeApproval: false,
            canBeDecree: true,
            successEffects: EconomicEffects(treasuryChange: 5, industrialOutputChange: 8, stabilityChange: -2, standingChange: 5),
            failureEffects: EconomicEffects(stabilityChange: -8, standingChange: -10)
        ),

        EconomicAction(
            id: "nationalize_sector",
            name: "Nationalize Sector",
            description: "Bring sector under state control",
            detailedDescription: "Complete nationalization of any remaining private or cooperative elements in a sector.",
            iconName: "building.2.crop.circle.fill",
            actionVerb: "Nationalize",
            category: .supreme,
            minimumPositionIndex: 7,
            targetType: .sector,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 15,
            executionTurns: 3,
            baseSuccessChance: 85,
            riskLevel: .systemic,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: EconomicEffects(treasuryChange: 10, industrialOutputChange: -3, stabilityChange: -5, popularSupportChange: -10, standingChange: 8),
            failureEffects: EconomicEffects(stabilityChange: -10, popularSupportChange: -15, standingChange: -15)
        ),

        EconomicAction(
            id: "abandon_sector",
            name: "Abandon Sector Investments",
            description: "Cut losses on failing sector",
            detailedDescription: "Officially recognize that a sector has failed and redirect resources. Admission of planning failure.",
            iconName: "xmark.circle.fill",
            actionVerb: "Abandon",
            category: .supreme,
            minimumPositionIndex: 7,
            targetType: .sector,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 10,
            executionTurns: 1,
            baseSuccessChance: 100,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: EconomicEffects(treasuryChange: 8, standingChange: -10),
            failureEffects: EconomicEffects()
        ),

        EconomicAction(
            id: "command_economy_reform",
            name: "Reform Command Economy",
            description: "Fundamental economic restructuring",
            detailedDescription: "Propose systemic changes to the command economy model. The most politically dangerous economic action.",
            iconName: "arrow.3.trianglepath",
            actionVerb: "Reform",
            category: .supreme,
            minimumPositionIndex: 7,
            targetType: .none,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 26,
            executionTurns: 5,
            baseSuccessChance: 40,
            riskLevel: .systemic,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(treasuryChange: 10, industrialOutputChange: 10, foodSupplyChange: 10, stabilityChange: -10, standingChange: 20),
            failureEffects: EconomicEffects(stabilityChange: -15, eliteLoyaltyChange: -10, standingChange: -25)
        ),

        // TIER 6+: Economic System Reform Actions (Era-Appropriate 1940s-60s)
        EconomicAction(
            id: "propose_economic_relaxation",
            name: "Propose Economic Relaxation",
            description: "Expand licensed private enterprise",
            detailedDescription: """
                Propose expanding licenses for small private businesses and cooperatives. \
                Following the model of 'socialism with American characteristics,' allow \
                greater economic flexibility while maintaining state control of commanding \
                heights. May boost productivity but risks ideological criticism.
                """,
            iconName: "arrow.up.right.circle.fill",
            actionVerb: "Propose",
            category: .strategic,
            minimumPositionIndex: 6,
            targetType: .none,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 2,
            baseSuccessChance: 55,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(
                treasuryChange: 5,
                industrialOutputChange: 6,
                stabilityChange: -3,
                popularSupportChange: 5,
                standingChange: 8,
                createsFlag: "economic_relaxation_policy"
            ),
            failureEffects: EconomicEffects(
                stabilityChange: -5,
                eliteLoyaltyChange: -8,
                standingChange: -12
            )
        ),

        EconomicAction(
            id: "strengthen_central_planning",
            name: "Strengthen Central Planning",
            description: "Tighten state control over production",
            detailedDescription: """
                Reassert central planning authority over production decisions. Reduce \
                regional autonomy and enterprise discretion in favor of strict quota \
                compliance. Appeals to ideological purists but may reduce economic \
                efficiency and worker initiative.
                """,
            iconName: "building.columns.fill",
            actionVerb: "Strengthen",
            category: .strategic,
            minimumPositionIndex: 6,
            targetType: .none,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 2,
            baseSuccessChance: 70,
            riskLevel: .significant,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(
                industrialOutputChange: -2,
                stabilityChange: 5,
                eliteLoyaltyChange: 5,
                standingChange: 5,
                createsFlag: "strengthened_planning"
            ),
            failureEffects: EconomicEffects(
                industrialOutputChange: -5,
                popularSupportChange: -5,
                standingChange: -8
            )
        ),

        EconomicAction(
            id: "establish_industrial_zone",
            name: "Establish Industrial Development Zone",
            description: "Create zone for foreign trade and investment",
            detailedDescription: """
                Designate a coastal or border region as an Industrial Development Zone \
                with special provisions for foreign trade and joint ventures. Attracts \
                foreign capital and technology while containing capitalist influences \
                to a defined area. A pragmatic approach that may draw ideological fire.
                """,
            iconName: "building.2.fill",
            actionVerb: "Establish",
            category: .strategic,
            minimumPositionIndex: 6,
            targetType: .region,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 12,
            executionTurns: 4,
            baseSuccessChance: 50,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(
                treasuryChange: 10,
                industrialOutputChange: 8,
                stabilityChange: -2,
                standingChange: 10,
                internationalStandingChange: 5,
                createsFlag: "industrial_development_zone",
                startsProject: true
            ),
            failureEffects: EconomicEffects(
                treasuryChange: -5,
                stabilityChange: -5,
                standingChange: -10
            )
        ),

        EconomicAction(
            id: "expand_fyp_targets",
            name: "Expand Five-Year Plan Targets",
            description: "Increase production quotas across sectors",
            detailedDescription: """
                Announce ambitious new targets for the current Five-Year Plan, calling \
                on workers and managers to exceed original goals. Stakhanovite heroism \
                expected. May boost short-term output but risks exhausting workers and \
                resources. Success brings glory; failure invites blame.
                """,
            iconName: "chart.line.uptrend.xyaxis",
            actionVerb: "Expand",
            category: .strategic,
            minimumPositionIndex: 6,
            targetType: .none,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 10,
            executionTurns: 1,
            baseSuccessChance: 45,
            riskLevel: .major,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: EconomicEffects(
                industrialOutputChange: 10,
                foodSupplyChange: 5,
                popularSupportChange: -3,
                standingChange: 12
            ),
            failureEffects: EconomicEffects(
                industrialOutputChange: -5,
                stabilityChange: -5,
                popularSupportChange: -8,
                standingChange: -15
            )
        ),

        EconomicAction(
            id: "reform_agricultural_procurement",
            name: "Reform Agricultural Procurement",
            description: "Adjust collective farm quotas and incentives",
            detailedDescription: """
                Modify the procurement system for collective farms—adjusting quotas, \
                allowing farmers to sell surplus production, or changing payment \
                structures. Proper incentives can boost food supply; poor implementation \
                can cause chaos in the countryside.
                """,
            iconName: "leaf.circle.fill",
            actionVerb: "Reform",
            category: .strategic,
            minimumPositionIndex: 6,
            targetType: .sector,
            targetSector: .agriculture,
            requiredTrack: nil,
            cooldownTurns: 8,
            executionTurns: 2,
            baseSuccessChance: 55,
            riskLevel: .significant,
            requiresCommitteeApproval: true,
            canBeDecree: false,
            successEffects: EconomicEffects(
                foodSupplyChange: 8,
                popularSupportChange: 5,
                standingChange: 8,
                regionalAgricultureChange: 10
            ),
            failureEffects: EconomicEffects(
                foodSupplyChange: -5,
                stabilityChange: -5,
                popularSupportChange: -5,
                standingChange: -10
            )
        ),

        EconomicAction(
            id: "launch_electrification_campaign",
            name: "Launch Electrification Campaign",
            description: "Major infrastructure program for rural power",
            detailedDescription: """
                Initiate a nationwide campaign to bring electrical power to rural \
                areas and expand industrial capacity. 'Communism is Soviet power plus \
                electrification of the whole country.' A massive undertaking requiring \
                sustained investment and organization.
                """,
            iconName: "bolt.circle.fill",
            actionVerb: "Launch",
            category: .supreme,
            minimumPositionIndex: 7,
            targetType: .none,
            targetSector: .energy,
            requiredTrack: nil,
            cooldownTurns: 20,
            executionTurns: 6,
            baseSuccessChance: 55,
            riskLevel: .systemic,
            requiresCommitteeApproval: true,
            canBeDecree: true,
            successEffects: EconomicEffects(
                treasuryChange: -15,
                industrialOutputChange: 15,
                foodSupplyChange: 5,
                popularSupportChange: 10,
                standingChange: 15,
                createsFlag: "electrification_campaign",
                startsProject: true
            ),
            failureEffects: EconomicEffects(
                treasuryChange: -10,
                stabilityChange: -8,
                standingChange: -15
            )
        ),

        EconomicAction(
            id: "declare_economic_emergency",
            name: "Declare Economic Emergency",
            description: "Invoke emergency powers for economic crisis",
            detailedDescription: """
                Formally declare a state of economic emergency, granting extraordinary \
                powers to redirect resources, requisition supplies, and override normal \
                planning procedures. A drastic measure that signals crisis but enables \
                rapid response. Use sparingly.
                """,
            iconName: "exclamationmark.octagon.fill",
            actionVerb: "Declare",
            category: .supreme,
            minimumPositionIndex: 7,
            targetType: .none,
            targetSector: nil,
            requiredTrack: nil,
            cooldownTurns: 15,
            executionTurns: 1,
            baseSuccessChance: 90,
            riskLevel: .systemic,
            requiresCommitteeApproval: false,
            canBeDecree: true,
            successEffects: EconomicEffects(
                treasuryChange: 8,
                industrialOutputChange: 8,
                stabilityChange: -8,
                popularSupportChange: -10,
                standingChange: 5,
                createsFlag: "economic_emergency"
            ),
            failureEffects: EconomicEffects(
                stabilityChange: -15,
                standingChange: -20
            )
        )
    ]

    /// Get actions available for a position
    static func actions(forPosition position: Int, track: String? = nil) -> [EconomicAction] {
        allActions.filter { $0.isAvailable(forPosition: position, track: track) }
    }

    /// Get actions by category
    static func actions(inCategory category: EconomicActionCategory) -> [EconomicAction] {
        allActions.filter { $0.category == category }
    }
}
