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
enum EconomicSector: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

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

    /// Primary stat this sector affects
    var primaryEffect: String {
        switch self {
        case .heavyIndustry: return "industrialOutput"
        case .lightIndustry: return "popularSupport"
        case .agriculture: return "foodSupply"
        case .energy: return "industrialOutput"
        case .mining: return "treasury"
        case .construction: return "stability"
        case .transport: return "gdpIndex"
        case .defense: return "militaryLoyalty"
        }
    }

    /// Secondary stat this sector affects
    var secondaryEffect: String {
        switch self {
        case .heavyIndustry: return "gdpIndex"
        case .lightIndustry: return "treasury"
        case .agriculture: return "stability"
        case .energy: return "gdpIndex"
        case .mining: return "industrialOutput"
        case .construction: return "popularSupport"
        case .transport: return "industrialOutput"
        case .defense: return "stability"
        }
    }

    /// How investment-heavy this sector is (affects treasury drain)
    var investmentCost: Int {
        switch self {
        case .heavyIndustry: return 4
        case .lightIndustry: return 2
        case .agriculture: return 2
        case .energy: return 5
        case .mining: return 3
        case .construction: return 4
        case .transport: return 5
        case .defense: return 6
        }
    }

    /// How many workers this sector employs (affects unemployment)
    var laborIntensity: Int {
        switch self {
        case .heavyIndustry: return 4
        case .lightIndustry: return 5
        case .agriculture: return 4
        case .energy: return 2
        case .mining: return 3
        case .construction: return 5
        case .transport: return 3
        case .defense: return 3
        }
    }

    /// Which sectors support this sector's production
    var dependencies: [EconomicSector] {
        switch self {
        case .heavyIndustry: return [.energy, .mining]
        case .lightIndustry: return [.heavyIndustry, .agriculture]
        case .agriculture: return [.energy, .transport]
        case .energy: return [.mining, .transport]
        case .mining: return [.energy, .transport]
        case .construction: return [.heavyIndustry, .transport]
        case .transport: return [.energy, .heavyIndustry]
        case .defense: return [.heavyIndustry, .energy]
        }
    }
}

// MARK: - Sector Performance Tracking

/// Tracks individual sector performance
struct SectorPerformance: Codable {
    var sectorId: String
    var productionLevel: Int = 50       // 0-100, current output
    var investmentLevel: Int = 50       // 0-100, recent investment
    var workerMorale: Int = 50          // 0-100, affects productivity
    var efficiency: Int = 50            // 0-100, tech/management level

    /// Calculate actual output based on all factors
    var actualOutput: Int {
        let base = productionLevel
        let moraleModifier = (workerMorale - 50) / 10  // -5 to +5
        let efficiencyModifier = (efficiency - 50) / 10  // -5 to +5
        return max(0, min(100, base + moraleModifier + efficiencyModifier))
    }

    /// Sector health description
    var healthDescription: String {
        let output = actualOutput
        if output >= 80 { return "Exceeding quotas" }
        if output >= 60 { return "Meeting targets" }
        if output >= 40 { return "Underperforming" }
        if output >= 20 { return "Crisis conditions" }
        return "Collapsed"
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
    /// Player is General Secretary — all actions are available regardless of position
    func isAvailable(forPosition position: Int, track: String?) -> Bool {
        // Position gate removed: player always has access as General Secretary
        if let required = requiredTrack {
            return track == required || position >= 6  // High positions transcend track limits
        }
        return true
    }

    /// Plan sectors this action contributes progress toward when executed
    /// successfully. Each entry carries the contribution amount. Used by
    /// `EconomicActionService` to update `Game.planTargets`.
    ///
    /// The mapping is intentionally generous: players should see visible
    /// progress on the wheel after executing 2-3 actions in a cycle.
    func planSectorContributions(targetSector: EconomicSector?) -> [(sector: PlanSector, amount: Int)] {
        var contributions: [(PlanSector, Int)] = []
        switch id {
        case "meet_quota":
            contributions.append((.heavyIndustry, 2))
        case "exceed_quota":
            contributions.append((.heavyIndustry, 5))
            contributions.append((.welfare, 1))
        case "set_regional_quota":
            contributions.append((.heavyIndustry, 2))
            contributions.append((.agriculture, 1))
        case "allocate_labor":
            contributions.append((.heavyIndustry, 3))
            contributions.append((.infrastructure, 2))
        case "prioritize_sector":
            if let ts = targetSector {
                contributions.append((planSector(for: ts), 5))
            } else {
                contributions.append((.heavyIndustry, 4))
            }
        case "emergency_requisition":
            if let ts = targetSector {
                contributions.append((planSector(for: ts), 6))
            } else {
                contributions.append((.heavyIndustry, 5))
            }
        case "propose_modernization":
            contributions.append((.heavyIndustry, 6))
            contributions.append((.energy, 3))
        case "agricultural_reform":
            contributions.append((.agriculture, 8))
            contributions.append((.welfare, 2))
        case "trade_agreement":
            contributions.append((.infrastructure, 3))
            contributions.append((.welfare, 3))
        case "crisis_mobilization":
            contributions.append((.heavyIndustry, 6))
            contributions.append((.defense, 4))
        case "economic_decree":
            contributions.append((.heavyIndustry, 4))
            contributions.append((.infrastructure, 3))
        case "nationalize_sector":
            if let ts = targetSector {
                contributions.append((planSector(for: ts), 5))
            } else {
                contributions.append((.heavyIndustry, 3))
            }
        case "request_resources":
            contributions.append((.heavyIndustry, 2))
        case "reallocate_budget":
            contributions.append((.heavyIndustry, 2))
            contributions.append((.welfare, 1))
        default:
            switch category {
            case .production: contributions.append((.heavyIndustry, 2))
            case .planning: contributions.append((.heavyIndustry, 1))
            case .allocation: contributions.append((.welfare, 1))
            case .reform: contributions.append((.heavyIndustry, 2))
            case .strategic: contributions.append((.infrastructure, 2))
            case .supreme: contributions.append((.defense, 2))
            }
        }
        return contributions
    }

    /// Map an `EconomicSector` (raw economic engine sector) to the six-sector
    /// plan view used by Five-Year Plan targets.
    private func planSector(for sector: EconomicSector) -> PlanSector {
        switch sector {
        case .heavyIndustry: return .heavyIndustry
        case .lightIndustry: return .welfare
        case .agriculture: return .agriculture
        case .energy: return .energy
        case .mining: return .heavyIndustry
        case .construction: return .infrastructure
        case .transport: return .infrastructure
        case .defense: return .defense
        }
    }
}

// MARK: - Economic Action Definitions

extension EconomicAction {

    /// Slim, focused economic-action lineup.
    ///
    /// Reduced from 25 to 12 core actions (plus 2 compatibility actions used
    /// by bureau directives). Each action contributes progress toward the
    /// player's Five-Year Plan sector targets via
    /// `planSectorContributions(targetSector:)`.
    static let allActions: [EconomicAction] = [
        // MARK: Production

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

        // MARK: Planning

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
            requiredTrack: nil,
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

        // MARK: Allocation

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
            requiredTrack: nil,
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

        // MARK: Reform

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
            requiredTrack: nil,
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

        // MARK: Strategic

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

        // MARK: Supreme

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

        // MARK: Bureau-directive compatibility
        // These actions are still referenced by bureau directives
        // (BureauTask.swift). They remain available as economic actions but
        // are kept terse — the bureau directive UI is the primary surface.

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

// MARK: - Foreign Loan

/// A foreign loan taken from another country or international institution
struct ForeignLoan: Codable, Identifiable {
    let id: UUID
    let lenderId: String        // Country ID or "imf"/"world_bank"
    let lenderName: String
    let principalAmount: Int    // Original loan amount (treasury boost)
    let interestRate: Int       // % per turn (2-8%)
    let turnTaken: Int
    let durationTurns: Int      // Repayment period
    var remainingPrincipal: Int // Decreases as you pay
    var totalInterestPaid: Int  // Running total

    var paymentPerTurn: Int {
        let interest = remainingPrincipal * interestRate / 100
        let principalPayment = principalAmount / durationTurns
        return interest + principalPayment
    }

    var principalPaymentPerTurn: Int {
        principalAmount / durationTurns
    }

    var interestPaymentPerTurn: Int {
        remainingPrincipal * interestRate / 100
    }

    var isFullyPaid: Bool { remainingPrincipal <= 0 }

    var turnsRemaining: Int {
        guard principalPaymentPerTurn > 0 else { return 0 }
        return max(0, (remainingPrincipal + principalPaymentPerTurn - 1) / principalPaymentPerTurn)
    }

    init(lenderId: String, lenderName: String, principalAmount: Int, interestRate: Int, turnTaken: Int, durationTurns: Int) {
        self.id = UUID()
        self.lenderId = lenderId
        self.lenderName = lenderName
        self.principalAmount = principalAmount
        self.interestRate = interestRate
        self.turnTaken = turnTaken
        self.durationTurns = durationTurns
        self.remainingPrincipal = principalAmount
        self.totalInterestPaid = 0
    }
}

// MARK: - Loan Source

/// Available loan sources with their terms and conditions
struct LoanSource: Identifiable {
    let id: String
    let lenderId: String
    let lenderName: String
    let category: LoanCategory
    let minInterestRate: Int
    let maxInterestRate: Int
    let maxAmount: Int
    let durationTurns: Int
    let requiredRelationship: Int    // Minimum relationship score needed
    let conditions: [String]         // Human-readable conditions

    enum LoanCategory: String {
        case socialist      // Low interest, few conditions
        case western        // Medium interest, economic conditions
        case institutional  // Higher interest, strict conditions
    }

    /// Calculate actual interest rate based on relationship
    func interestRate(forRelationship relationship: Int) -> Int {
        let range = maxInterestRate - minInterestRate
        let relationshipFactor = max(0, min(100, relationship + 100)) // Normalize -100..100 to 0..200
        let reduction = range * relationshipFactor / 200
        return max(minInterestRate, maxInterestRate - reduction)
    }

    /// All available loan sources
    static let allSources: [LoanSource] = [
        // Socialist bloc
        LoanSource(
            id: "ussr_loan",
            lenderId: "soviet_union",
            lenderName: "Soviet Union",
            category: .socialist,
            minInterestRate: 2,
            maxInterestRate: 3,
            maxAmount: 30,
            durationTurns: 20,
            requiredRelationship: 20,
            conditions: ["Maintain socialist economic system"]
        ),
        LoanSource(
            id: "china_loan",
            lenderId: "china",
            lenderName: "People's Republic of China",
            category: .socialist,
            minInterestRate: 2,
            maxInterestRate: 4,
            maxAmount: 20,
            durationTurns: 16,
            requiredRelationship: 20,
            conditions: ["Fraternal socialist solidarity"]
        ),
        // Western countries
        LoanSource(
            id: "usa_loan",
            lenderId: "usa",
            lenderName: "United States",
            category: .western,
            minInterestRate: 4,
            maxInterestRate: 5,
            maxAmount: 40,
            durationTurns: 12,
            requiredRelationship: 0,
            conditions: ["Permit licensed businesses", "Open foreign trade"]
        ),
        LoanSource(
            id: "uk_loan",
            lenderId: "uk",
            lenderName: "United Kingdom",
            category: .western,
            minInterestRate: 4,
            maxInterestRate: 5,
            maxAmount: 25,
            durationTurns: 12,
            requiredRelationship: 0,
            conditions: ["Permit licensed businesses"]
        ),
        // International institutions
        LoanSource(
            id: "imf_loan",
            lenderId: "imf",
            lenderName: "International Monetary Fund",
            category: .institutional,
            minInterestRate: 5,
            maxInterestRate: 8,
            maxAmount: 50,
            durationTurns: 16,
            requiredRelationship: -50,
            conditions: ["Market reforms required", "Austerity measures", "Quarterly reporting"]
        ),
        LoanSource(
            id: "world_bank_loan",
            lenderId: "world_bank",
            lenderName: "World Bank",
            category: .institutional,
            minInterestRate: 5,
            maxInterestRate: 7,
            maxAmount: 35,
            durationTurns: 20,
            requiredRelationship: -30,
            conditions: ["Infrastructure investment mandate", "Transparency requirements"]
        )
    ]
}
