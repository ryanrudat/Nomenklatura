//
//  FiveYearPlanService.swift
//  Nomenklatura
//
//  End-of-cycle evaluation for the Five-Year Plan target system.
//
//  Each cycle runs for 20 turns. When the current turn passes
//  `planTargets.endTurn`, this service evaluates how many of the 6 sector
//  targets the player met and applies consequences per the Unit-5 design:
//
//      6 met  → Stakhanovite Achievement: +15 standing, +10 elite loyalty
//      4-5    → good plan: +5 standing, +3 elite loyalty
//      2-3    → mixed: -3 standing
//      0-1    → Plan Failure: -10 elite loyalty, Committee intervention risk
//
//  Call `resolveElapsedCycle(for:)` at the end of a turn (after
//  `EconomyService.processEconomicSystem`). It is idempotent — once the
//  cycle is marked `isComplete`, it will not fire again.
//

import Foundation
import SwiftData

// MARK: - Cycle Consequence

/// Result of an end-of-cycle evaluation. Returned so the UI can surface a
/// consequence event / briefing after the cycle closes.
struct FiveYearPlanCycleResult {
    enum Outcome {
        case stakhanovite    // 6/6
        case success         // 4-5
        case mixed           // 2-3
        case failure         // 0-1

        var displayName: String {
            switch self {
            case .stakhanovite: return "Stakhanovite Achievement"
            case .success: return "Plan Success"
            case .mixed: return "Mixed Results"
            case .failure: return "Plan Failure"
            }
        }
    }

    let cycleNumber: Int
    let outcome: Outcome
    let sectorsMet: Int
    let sectorsTotal: Int
    let headline: String
    let detail: String
    let flagsAdded: [String]
}

// MARK: - Service

final class FiveYearPlanService {
    static let shared = FiveYearPlanService()

    private init() {}

    /// Check whether the current cycle has ended, and if so, apply
    /// consequences and start a new cycle (unconfigured, awaiting player
    /// input). Returns a result if a cycle was resolved; nil otherwise.
    @discardableResult
    func resolveElapsedCycle(for game: Game) -> FiveYearPlanCycleResult? {
        let targets = game.planTargets
        guard targets.isConfigured else { return nil }
        guard !targets.isComplete else { return nil }
        guard game.turnNumber >= targets.endTurn else { return nil }

        return resolveCycle(for: game)
    }

    /// Force evaluation of the current cycle (used by debug / end-of-cycle
    /// tests). Applies consequences even if `endTurn` has not been reached.
    @discardableResult
    func resolveCycle(for game: Game) -> FiveYearPlanCycleResult {
        var targets = game.planTargets
        let sectorsMet = targets.sectorsMetCount
        let totalWithTargets = max(1, targets.sectorsWithTargets)

        let outcome: FiveYearPlanCycleResult.Outcome
        var flags: [String] = []

        if sectorsMet >= 6 {
            outcome = .stakhanovite
            game.applyStat("standing", change: 15)
            game.applyStat("eliteLoyalty", change: 10)
            game.applyStat("popularSupport", change: 5)
            game.applyStat("reputationCompetent", change: 10)
            flags.append("stakhanovite_achievement")
            flags.append("plan_\(targets.cycleNumber)_exceeded")
        } else if sectorsMet >= 4 {
            outcome = .success
            game.applyStat("standing", change: 5)
            game.applyStat("eliteLoyalty", change: 3)
            game.applyStat("reputationCompetent", change: 5)
            flags.append("plan_\(targets.cycleNumber)_success")
        } else if sectorsMet >= 2 {
            outcome = .mixed
            game.applyStat("standing", change: -3)
            flags.append("plan_\(targets.cycleNumber)_partial")
        } else {
            outcome = .failure
            game.applyStat("eliteLoyalty", change: -10)
            game.applyStat("standing", change: -8)
            game.applyStat("reputationCompetent", change: -10)
            flags.append("plan_failure")
            flags.append("plan_\(targets.cycleNumber)_failure")
            // Standing Committee intervention risk: set a flag the political
            // AI reads when deciding whether to schedule a challenge.
            flags.append("committee_intervention_risk")
        }

        // Dedupe into game.flags.
        for flag in flags where !game.flags.contains(flag) {
            game.flags.append(flag)
        }

        // Mark this cycle complete before rolling to the next one.
        targets.isComplete = true
        game.planTargets = targets

        let headline = headlineText(for: outcome, cycleNumber: targets.cycleNumber)
        let detail = detailText(for: outcome, sectorsMet: sectorsMet, total: totalWithTargets)

        // Start the next cycle (unconfigured — prompts the player next turn).
        startNextCycle(for: game)

        return FiveYearPlanCycleResult(
            cycleNumber: targets.cycleNumber,
            outcome: outcome,
            sectorsMet: sectorsMet,
            sectorsTotal: totalWithTargets,
            headline: headline,
            detail: detail,
            flagsAdded: flags
        )
    }

    /// Increment cycle number and prepare a fresh unconfigured cycle. The
    /// player will be prompted to set targets on their next visit to the
    /// Economy tab.
    private func startNextCycle(for game: Game) {
        game.currentFiveYearPlan += 1
        game.fiveYearPlanYear = 1
        game.initializePlanTargets()
    }

    // MARK: - Text generation

    private func headlineText(
        for outcome: FiveYearPlanCycleResult.Outcome,
        cycleNumber: Int
    ) -> String {
        switch outcome {
        case .stakhanovite:
            return "\(ordinal(cycleNumber)) Five-Year Plan: Stakhanovite Triumph"
        case .success:
            return "\(ordinal(cycleNumber)) Five-Year Plan: Successful Completion"
        case .mixed:
            return "\(ordinal(cycleNumber)) Five-Year Plan: Mixed Results"
        case .failure:
            return "\(ordinal(cycleNumber)) Five-Year Plan: Failure"
        }
    }

    private func detailText(
        for outcome: FiveYearPlanCycleResult.Outcome,
        sectorsMet: Int,
        total: Int
    ) -> String {
        switch outcome {
        case .stakhanovite:
            return "All \(sectorsMet) sector targets exceeded. The nation stands in awe of this industrial miracle. Bonus actions unlocked for the coming cycle."
        case .success:
            return "\(sectorsMet) of \(total) sector targets met. The plan delivered on its core promises."
        case .mixed:
            return "Only \(sectorsMet) of \(total) sector targets met. The Politburo registers its concern."
        case .failure:
            return "\(sectorsMet) of \(total) sector targets met. The Standing Committee has opened an inquiry. Your grip on power weakens."
        }
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "First"
        case 2: return "Second"
        case 3: return "Third"
        case 4: return "Fourth"
        case 5: return "Fifth"
        case 6: return "Sixth"
        case 7: return "Seventh"
        case 8: return "Eighth"
        default: return "\(n)th"
        }
    }
}
