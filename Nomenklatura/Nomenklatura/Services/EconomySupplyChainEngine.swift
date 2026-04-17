//
//  EconomySupplyChainEngine.swift
//  Nomenklatura
//
//  Per-turn supply chain processing for Phase 3.2:
//
//    1. Extract — for each region, contribute its endowments to the
//       state's strategic reserves, scaled by region status (stable=100%,
//       unrest=85%, crisis=50%, rebellion=25%, secession in-progress=10%,
//       seceded=0%, martial=70%).
//
//    2. Consume + Produce — for each sector's active focus, look up its
//       SectorRecipe. Determine the largest fraction of the recipe the
//       current reserves can satisfy (worst-case input ratio). Consume
//       inputs at that ratio, produce outputs at that ratio. Track the
//       satisfaction percentage per sector for the UI.
//
//    3. Record — write a SupplyChainResult to game.lastSupplyChainResult
//       so the UI (Phase 3.3) can show "Energy strained: oil 33%
//       shortfall — sourced from Caspia which is in crisis."
//
//  Tech-era gating: recipes whose requiredTechEra exceeds the player's
//  current era are skipped entirely (no consumption, no production).
//

import Foundation
import os.log

private let supplyChainLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "SupplyChain")

@MainActor
final class EconomySupplyChainEngine {
    static let shared = EconomySupplyChainEngine()

    private init() {}

    // MARK: - Entry Point

    func processSupplyChain(game: Game) {
        var reserves = game.strategicReserves
        var extracted: [String: [String: Int]] = [:]
        var produced: [String: [String: Int]] = [:]
        var consumed: [String: [String: Int]] = [:]
        var shortfalls: [String: Int] = [:]
        var tradeImports: [String: [String: Int]] = [:]
        var tradeExports: [String: [String: Int]] = [:]

        // STEP 1: Extract from regions
        for region in game.regions {
            let multiplier = extractionMultiplier(for: region)
            guard multiplier > 0 else { continue }

            var regionExtraction: [String: Int] = [:]
            for (resource, capacity) in region.endowments {
                guard game.canUse(resource) else { continue }
                let amount = Int((Double(capacity) * multiplier).rounded())
                guard amount > 0 else { continue }
                reserves[resource, default: 0] += amount
                regionExtraction[resource.rawValue] = amount
            }
            if !regionExtraction.isEmpty {
                extracted[region.regionId] = regionExtraction
            }
        }

        // STEP 1.5: Apply commodity flows from active trade agreements (Phase 3.6).
        // Imports add to reserves; exports subtract. If we don't have enough
        // of the export commodity, ship what we can (clamped at 0) so we
        // don't go negative purely from trade obligations.
        for agreement in game.tradeAgreements where agreement.isActive && agreement.hasCommodityFlows {
            var partnerImports: [String: Int] = [:]
            for (resource, amount) in agreement.commodityImports where game.canUse(resource) && amount > 0 {
                reserves[resource, default: 0] += amount
                partnerImports[resource.rawValue, default: 0] += amount
            }
            if !partnerImports.isEmpty {
                tradeImports[agreement.partnerCountryId, default: [:]].merge(partnerImports) { $0 + $1 }
            }

            var partnerExports: [String: Int] = [:]
            for (resource, owed) in agreement.commodityExports where owed > 0 {
                let available = max(0, reserves[resource] ?? 0)
                let shipped = min(available, owed)
                guard shipped > 0 else { continue }
                reserves[resource, default: 0] -= shipped
                partnerExports[resource.rawValue, default: 0] += shipped
            }
            if !partnerExports.isEmpty {
                tradeExports[agreement.partnerCountryId, default: [:]].merge(partnerExports) { $0 + $1 }
            }
        }

        // STEP 2: Run each sector's active focus recipe
        for sector in EconomicSector.allCases {
            let focusId = game.sectorFocus(for: sector)
            guard let recipe = SectorRecipe.recipe(for: focusId), recipe.sector == sector else { continue }
            guard game.currentTechEra >= recipe.requiredTechEra else { continue }

            let satisfaction = applyRecipe(
                recipe,
                reserves: &reserves,
                consumed: &consumed,
                produced: &produced,
                game: game
            )
            if satisfaction < 100 {
                shortfalls[sector.rawValue] = satisfaction
            }
        }

        // STEP 3: Persist updated reserves + result
        let deficits = reserves.filter { $0.value <= 0 }.map { $0.key.rawValue }
        game.strategicReserves = reserves.filter { $0.value > 0 }  // Drop zeros to keep storage clean

        let result = SupplyChainResult(
            turn: game.turnNumber,
            extractedByRegion: extracted,
            producedBySector: produced,
            consumedBySector: consumed,
            shortfallBySector: shortfalls,
            deficitResources: deficits,
            tradeImportsByPartner: tradeImports,
            tradeExportsByPartner: tradeExports
        )
        game.lastSupplyChainResultData = encodeResult(result)

        #if DEBUG
        supplyChainLogger.debug("Turn \(game.turnNumber): extracted \(extracted.count) regions, \(shortfalls.count) shortfalls, \(deficits.count) deficits")
        #endif
    }

    // MARK: - Extraction Multiplier

    /// Per-region extraction efficiency. Reflects political reality: a
    /// rebellious region cannot deliver coal even if the deposit exists.
    private func extractionMultiplier(for region: Region) -> Double {
        guard let status = RegionStatus(rawValue: region.currentStatus) else { return 1.0 }
        switch status {
        case .stable:    return 1.0
        case .unrest:    return 0.85
        case .crisis:    return 0.50
        case .rebellion: return 0.25
        case .seceding:  return 0.10
        case .seceded:   return 0.0
        case .martial:   return 0.70
        }
    }

    // MARK: - Recipe Application

    /// Apply a recipe to current reserves. Returns satisfaction % (0-100):
    /// the fraction of the full recipe that ran, limited by the scarcest
    /// input. Recipes with no inputs always return 100.
    private func applyRecipe(
        _ recipe: SectorRecipe,
        reserves: inout [StrategicResource: Int],
        consumed: inout [String: [String: Int]],
        produced: inout [String: [String: Int]],
        game: Game
    ) -> Int {
        // Determine the bottleneck input
        var fraction: Double = 1.0
        for (resource, required) in recipe.inputs where required > 0 {
            let available = max(0, reserves[resource] ?? 0)
            let resourceFraction = min(1.0, Double(available) / Double(required))
            fraction = min(fraction, resourceFraction)
        }

        guard fraction > 0 else { return 0 }

        let sectorKey = recipe.sector.rawValue

        // Consume inputs at the bottleneck ratio
        var sectorConsumed: [String: Int] = consumed[sectorKey] ?? [:]
        for (resource, required) in recipe.inputs where required > 0 {
            let amount = Int((Double(required) * fraction).rounded())
            guard amount > 0 else { continue }
            reserves[resource, default: 0] -= amount
            sectorConsumed[resource.rawValue, default: 0] += amount
        }
        if !sectorConsumed.isEmpty { consumed[sectorKey] = sectorConsumed }

        // Produce outputs at the same ratio
        var sectorProduced: [String: Int] = produced[sectorKey] ?? [:]
        for (resource, yield) in recipe.outputs where yield > 0 {
            guard game.canUse(resource) else { continue }
            let amount = Int((Double(yield) * fraction).rounded())
            guard amount > 0 else { continue }
            reserves[resource, default: 0] += amount
            sectorProduced[resource.rawValue, default: 0] += amount
        }
        if !sectorProduced.isEmpty { produced[sectorKey] = sectorProduced }

        return Int((fraction * 100).rounded())
    }

    // MARK: - Result Codec

    private func encodeResult(_ result: SupplyChainResult) -> Data? {
        do {
            return try JSONEncoder().encode(result)
        } catch {
            supplyChainLogger.error("Failed to encode SupplyChainResult: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Result Decode (called by Game accessor)

func decodeSupplyChainResult(from data: Data?) -> SupplyChainResult? {
    guard let data = data else { return nil }
    do {
        return try JSONDecoder().decode(SupplyChainResult.self, from: data)
    } catch {
        supplyChainLogger.error("Failed to decode SupplyChainResult: \(error.localizedDescription)")
        return nil
    }
}
