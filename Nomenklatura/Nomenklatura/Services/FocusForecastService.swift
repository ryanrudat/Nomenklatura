//
//  FocusForecastService.swift
//  Nomenklatura
//
//  Phase 3.4: computes a FocusForecast for a proposed sector focus
//  switch. Reads the current game state, looks up recipes, simulates
//  one turn ahead, and returns the projected delta.
//

import Foundation

@MainActor
final class FocusForecastService {
    static let shared = FocusForecastService()

    private init() {}

    /// Build a forecast for switching a sector to a proposed focus.
    /// Always returns a forecast (never throws); locked focuses get
    /// their lock reason set so the UI can render a "REQUIRES X" stamp.
    func forecast(
        switching sector: EconomicSector,
        from currentFocusId: String,
        to proposedFocus: SectorFocus,
        in game: Game
    ) -> FocusForecast {
        let currentFocus = SectorFocus.focuses(for: sector)
            .first { $0.focusId == currentFocusId }

        let currentRecipe = SectorRecipe.recipe(for: currentFocusId)
        let proposedRecipe = SectorRecipe.recipe(for: proposedFocus)

        // Lock check
        var isLocked = false
        var lockReason: String? = nil
        if let recipe = proposedRecipe, game.currentTechEra < recipe.requiredTechEra {
            isLocked = true
            lockReason = "Requires \(recipe.requiredTechEra.displayName) Era"
        }

        // Input/output deltas (proposed - current)
        let inputDelta = subtract(
            proposedRecipe?.inputs ?? [:],
            currentRecipe?.inputs ?? [:]
        )
        let outputDelta = subtract(
            proposedRecipe?.outputs ?? [:],
            currentRecipe?.outputs ?? [:]
        )

        // Reserve projection: take current reserves, add expected
        // extraction (sum of all region endowments), apply proposed
        // recipe's net effect (outputs - inputs). Holds other sectors
        // constant; that's a UI simplification (otherwise the math
        // explodes for a single-sector preview).
        var projection = game.strategicReserves
        for region in game.regions {
            for (resource, amount) in region.endowments where game.canUse(resource) {
                projection[resource, default: 0] += amount
            }
        }
        for (resource, amount) in proposedRecipe?.inputs ?? [:] {
            projection[resource, default: 0] -= amount
        }
        for (resource, amount) in proposedRecipe?.outputs ?? [:] where game.canUse(resource) {
            projection[resource, default: 0] += amount
        }
        for (resource, amount) in currentRecipe?.inputs ?? [:] {
            projection[resource, default: 0] += amount   // Refund current consumption
        }
        for (resource, amount) in currentRecipe?.outputs ?? [:] {
            projection[resource, default: 0] -= amount   // Remove current production
        }

        // Cross-sector impact: walk other sectors, see whose recipe will
        // strain after this change. A sector strains if its required
        // input is now negative in projection.
        var crossSectorImpacts: [EconomicSector: Int] = [:]
        for otherSector in EconomicSector.allCases where otherSector != sector {
            let otherFocusId = game.sectorFocus(for: otherSector)
            guard let otherRecipe = SectorRecipe.recipe(for: otherFocusId) else { continue }

            var worstFraction = 1.0
            for (resource, required) in otherRecipe.inputs where required > 0 {
                let available = max(0, projection[resource] ?? 0)
                let frac = min(1.0, Double(available) / Double(required))
                worstFraction = min(worstFraction, frac)
            }
            if worstFraction < 1.0 {
                crossSectorImpacts[otherSector] = Int((worstFraction * 100).rounded())
            }
        }

        // Stat effect deltas
        var statEffectChanges: [String: Int] = [:]
        for (key, value) in proposedFocus.effects {
            statEffectChanges[key, default: 0] += value
        }
        for (key, value) in currentFocus?.effects ?? [:] {
            statEffectChanges[key, default: 0] -= value
        }
        statEffectChanges = statEffectChanges.filter { $0.value != 0 }

        let treasuryCostDelta = proposedFocus.treasuryCostPerTurn
            - (currentFocus?.treasuryCostPerTurn ?? 0)

        return FocusForecast(
            sector: sector,
            currentFocus: currentFocus,
            proposedFocus: proposedFocus,
            isLocked: isLocked,
            lockReason: lockReason,
            inputDelta: inputDelta.filter { $0.value != 0 },
            outputDelta: outputDelta.filter { $0.value != 0 },
            reserveProjection: projection,
            crossSectorImpacts: crossSectorImpacts,
            statEffectChanges: statEffectChanges,
            treasuryCostDelta: treasuryCostDelta
        )
    }

    /// Returns left - right for matching keys, with missing keys treated as 0.
    private func subtract(
        _ left: [StrategicResource: Int],
        _ right: [StrategicResource: Int]
    ) -> [StrategicResource: Int] {
        var result = left
        for (key, value) in right {
            result[key, default: 0] -= value
        }
        return result
    }
}
