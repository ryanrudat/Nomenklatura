//
//  EconomicPropagandaService.swift
//  Nomenklatura
//
//  Generates propaganda versions of economic data that diverge from reality
//  Junior officials see propaganda; senior officials see the truth
//

import Foundation

// MARK: - Economic Propaganda Service

/// Generates propaganda versions of economic statistics
/// The Party always reports success, even when the reality is grim
@MainActor
final class EconomicPropagandaService {
    static let shared = EconomicPropagandaService()

    private init() {}

    // MARK: - Propaganda Generation

    /// Generate propaganda report for a game state
    func generatePropagandaReport(for game: Game) -> PropagandaReport {
        PropagandaReport(
            // GDP is always growing in propaganda
            gdpIndex: propagandaGDP(real: game.gdpIndex),
            gdpTrend: .growing,
            gdpHeadline: gdpHeadline(real: game.gdpIndex),

            // Inflation is always "stable" or "declining"
            inflationRate: propagandaInflation(real: game.inflationRate),
            inflationTrend: .stable,
            inflationHeadline: inflationHeadline(real: game.inflationRate),

            // Unemployment is always low
            unemploymentRate: propagandaUnemployment(real: game.unemploymentRate),
            unemploymentTrend: .declining,
            unemploymentHeadline: unemploymentHeadline(real: game.unemploymentRate),

            // Industrial output always exceeds targets
            industrialOutput: propagandaIndustrial(real: game.industrialOutput),
            industrialHeadline: industrialHeadline(real: game.industrialOutput),

            // Food supply is adequate
            foodSupply: propagandaFood(real: game.foodSupply),
            foodHeadline: foodHeadline(real: game.foodSupply),

            // Five-Year Plan always on track
            fiveYearPlanProgress: propagandaPlanProgress(game: game),
            fiveYearPlanHeadline: planHeadline(game: game),

            // Overall economic status
            economicHealth: propagandaHealth(real: game.economicHealthScore),
            overallHeadline: overallHeadline(game: game)
        )
    }

    // MARK: - Individual Stat Propaganda

    private func propagandaGDP(real: Int) -> Int {
        // Propaganda GDP is always at least 100 (baseline) and inflated
        if real >= 100 {
            return real + Int.random(in: 5...15)  // Exaggerate gains
        } else {
            // Never admit decline - show modest growth instead
            return max(100, 100 + Int.random(in: 3...8))
        }
    }

    private func propagandaInflation(real: Int) -> Int {
        // Propaganda inflation is always low
        if real <= 10 {
            return real  // Already good, report truthfully
        } else if real <= 25 {
            return Int.random(in: 5...10)  // Moderate inflation hidden
        } else {
            return Int.random(in: 8...12)  // Severe inflation deeply hidden
        }
    }

    private func propagandaUnemployment(real: Int) -> Int {
        // Socialist state has "no unemployment" - just "job reallocation"
        if real <= 5 {
            return real
        } else if real <= 15 {
            return Int.random(in: 3...5)
        } else {
            return Int.random(in: 4...6)  // Even mass unemployment reported as low
        }
    }

    private func propagandaIndustrial(real: Int) -> Int {
        // Industrial output always meets or exceeds quota
        if real >= 50 {
            return min(100, real + Int.random(in: 5...15))
        } else {
            return Int.random(in: 55...65)  // Never admit failure
        }
    }

    private func propagandaFood(real: Int) -> Int {
        // Food supply is always "adequate"
        if real >= 50 {
            return min(100, real + Int.random(in: 3...10))
        } else {
            return Int.random(in: 50...60)  // Hide shortages
        }
    }

    private func propagandaPlanProgress(game: Game) -> Int {
        // Five-Year Plan is always "on track" or "ahead of schedule"
        let realProgress = game.planPerformanceScore
        if realProgress >= 80 {
            return min(100, realProgress + 10)
        } else if realProgress >= 50 {
            return realProgress + 20
        } else {
            return Int.random(in: 70...85)  // Never admit plan is failing
        }
    }

    private func propagandaHealth(real: Int) -> Int {
        // Economic health is always "satisfactory" or better
        if real >= 60 {
            return real + 10
        } else {
            return Int.random(in: 65...75)
        }
    }

    // MARK: - Propaganda Headlines

    private func gdpHeadline(real: Int) -> String {
        if real >= 110 {
            return "RECORD GROWTH! National Product Surpasses All Projections!"
        } else if real >= 100 {
            return "Steady Progress: National Product Meets Revolutionary Targets"
        } else if real >= 90 {
            return "Temporary Adjustments as Economy Consolidates Gains"
        } else {
            return "Socialist Economy Demonstrates Resilience Against Imperialist Sabotage"
        }
    }

    private func inflationHeadline(real: Int) -> String {
        if real <= 10 {
            return "Price Stability: Central Planning Delivers for Workers"
        } else if real <= 25 {
            return "Minor Price Adjustments Reflect Growing Consumer Prosperity"
        } else if real <= 50 {
            return "Temporary Price Measures Combat Speculator Hoarding"
        } else {
            return "Emergency Anti-Hoarding Campaign Defeats Capitalist Price Manipulation"
        }
    }

    private func unemploymentHeadline(real: Int) -> String {
        if real <= 5 {
            return "Full Employment: Every Worker Contributes to Socialist Construction"
        } else if real <= 15 {
            return "Labor Reallocation Program Optimizes Workforce Distribution"
        } else {
            return "Voluntary Labor Reassignment Strengthens Key Sectors"
        }
    }

    private func industrialHeadline(real: Int) -> String {
        if real >= 70 {
            return "QUOTA EXCEEDED! Workers Demonstrate Revolutionary Spirit!"
        } else if real >= 50 {
            return "Industrial Targets Met Through Collective Effort"
        } else if real >= 30 {
            return "Production Reorganization Underway to Optimize Output"
        } else {
            return "Counter-Revolutionary Sabotage Detected and Eliminated in Factories"
        }
    }

    private func foodHeadline(real: Int) -> String {
        if real >= 70 {
            return "BUMPER HARVEST! Collective Farms Surpass All Quotas!"
        } else if real >= 50 {
            return "Agricultural Sector Meets Nutritional Needs of the People"
        } else if real >= 30 {
            return "Strategic Grain Reserves Ensure Food Security"
        } else {
            return "Kulak Sabotage Campaign Defeated; Distribution Normalized"
        }
    }

    private func planHeadline(game: Game) -> String {
        let year = game.fiveYearPlanYear
        let plan = game.currentFiveYearPlan
        let progress = game.planPerformanceScore

        if progress >= 90 {
            return "AHEAD OF SCHEDULE! Plan \(plan) Year \(year) Exceeds All Targets!"
        } else if progress >= 70 {
            return "Plan \(plan) Year \(year): Socialist Competition Drives Success"
        } else if progress >= 50 {
            return "Plan \(plan) Year \(year): Foundation Laid for Future Achievements"
        } else {
            return "Plan \(plan) Year \(year): Intensified Efforts to Meet Revolutionary Goals"
        }
    }

    private func overallHeadline(game: Game) -> String {
        let health = game.economicHealthScore

        if health >= 80 {
            return "SOCIALIST TRIUMPH: People's Economy Demonstrates Superiority Over Capitalism!"
        } else if health >= 60 {
            return "STEADY PROGRESS: Revolutionary Economic Principles Vindicated"
        } else if health >= 40 {
            return "RESILIENT: Economy Withstands Imperialist Economic Warfare"
        } else {
            return "VIGILANCE: Party Leadership Defeats Saboteurs and Wreckers"
        }
    }
}

// MARK: - Propaganda Report Model

struct PropagandaReport {
    // GDP
    let gdpIndex: Int
    let gdpTrend: PropagandaTrend
    let gdpHeadline: String

    // Inflation
    let inflationRate: Int
    let inflationTrend: PropagandaTrend
    let inflationHeadline: String

    // Unemployment
    let unemploymentRate: Int
    let unemploymentTrend: PropagandaTrend
    let unemploymentHeadline: String

    // Industrial
    let industrialOutput: Int
    let industrialHeadline: String

    // Food
    let foodSupply: Int
    let foodHeadline: String

    // Five-Year Plan
    let fiveYearPlanProgress: Int
    let fiveYearPlanHeadline: String

    // Overall
    let economicHealth: Int
    let overallHeadline: String
}

enum PropagandaTrend: String {
    case growing = "Growing"
    case stable = "Stable"
    case declining = "Adjusting"  // Never say "declining" in propaganda

    var icon: String {
        switch self {
        case .growing: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.turn.up.right"  // Euphemistic icon
        }
    }
}

// MARK: - Dual Report Data

/// Wrapper that holds both propaganda and reality values
/// Used for position-gated display
struct DualEconomicData<T> {
    let propaganda: T
    let reality: T

    /// Returns appropriate value based on position
    /// Position 3+ sees reality; below sees propaganda
    func value(forPosition position: Int) -> T {
        position >= 3 ? reality : propaganda
    }

}

// Extension for Int-specific functionality
extension DualEconomicData where T == Int {
    /// Check if there's a significant divergence between propaganda and reality
    var hasDivergence: Bool {
        abs(propaganda - reality) > 5
    }
}

// MARK: - Complete Economic Report

/// Full economic report with both propaganda and reality versions
struct EconomicIntelligenceReport {
    let turnNumber: Int
    let reportDate: String
    let classification: String  // "PUBLIC", "RESTRICTED", "CONFIDENTIAL", etc.

    // Dual data for each metric
    let gdpData: DualEconomicData<Int>
    let inflationData: DualEconomicData<Int>
    let unemploymentData: DualEconomicData<Int>
    let industrialData: DualEconomicData<Int>
    let foodData: DualEconomicData<Int>
    let planProgressData: DualEconomicData<Int>
    let healthData: DualEconomicData<Int>

    // Headlines
    let propagandaHeadline: String
    let realityAssessment: String

    /// Generate report for a game state
    static func generate(for game: Game) -> EconomicIntelligenceReport {
        let propaganda = EconomicPropagandaService.shared.generatePropagandaReport(for: game)

        return EconomicIntelligenceReport(
            turnNumber: game.turnNumber,
            reportDate: RevolutionaryCalendar.formatTurnFull(game.turnNumber),
            classification: classificationLevel(for: game.currentPositionIndex),

            gdpData: DualEconomicData(propaganda: propaganda.gdpIndex, reality: game.gdpIndex),
            inflationData: DualEconomicData(propaganda: propaganda.inflationRate, reality: game.inflationRate),
            unemploymentData: DualEconomicData(propaganda: propaganda.unemploymentRate, reality: game.unemploymentRate),
            industrialData: DualEconomicData(propaganda: propaganda.industrialOutput, reality: game.industrialOutput),
            foodData: DualEconomicData(propaganda: propaganda.foodSupply, reality: game.foodSupply),
            planProgressData: DualEconomicData(propaganda: propaganda.fiveYearPlanProgress, reality: game.planPerformanceScore),
            healthData: DualEconomicData(propaganda: propaganda.economicHealth, reality: game.economicHealthScore),

            propagandaHeadline: propaganda.overallHeadline,
            realityAssessment: generateRealityAssessment(game: game)
        )
    }

    private static func classificationLevel(for position: Int) -> String {
        switch position {
        case 0...2: return "PUBLIC"
        case 3...4: return "RESTRICTED"
        case 5...6: return "CONFIDENTIAL"
        default: return "SECRET"
        }
    }

    private static func generateRealityAssessment(game: Game) -> String {
        let health = game.economicHealthScore
        var issues: [String] = []

        if game.gdpIndex < 95 {
            issues.append("GDP contraction")
        }
        if game.inflationRate > 20 {
            issues.append("concerning inflation")
        }
        if game.unemploymentRate > 10 {
            issues.append("elevated unemployment")
        }
        if game.industrialOutput < 40 {
            issues.append("industrial underperformance")
        }
        if game.foodSupply < 40 {
            issues.append("food supply concerns")
        }

        if issues.isEmpty && health >= 60 {
            return "Economic indicators are genuinely satisfactory. No significant divergence from public reporting."
        } else if issues.isEmpty {
            return "Economy stable but vulnerable. Public reports slightly optimistic."
        } else {
            return "INTERNAL ASSESSMENT: Actual conditions diverge from public reporting. Issues: \(issues.joined(separator: ", "))."
        }
    }
}
