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
//    2.5 Feed — the civilian population consumes grain each turn, scaled
//       by the number of regions still under state control. Unmet demand
//       is recorded as a grain deficit like any recipe shortfall.
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
        var shortResources: Set<StrategicResource> = []
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
                shortResources: &shortResources,
                game: game
            )
            if satisfaction < 100 {
                shortfalls[sector.rawValue] = satisfaction
            }
        }

        // STEP 2.5: Civilian grain consumption. The population eats every turn —
        // without this sink no recipe consumes grain and every grain-crisis
        // mechanic is dead. Tuning intent: demand sits slightly BELOW the starting
        // economy's net grain production (~24 produced − ~6 exported vs 16
        // consumed with 7 regions), so the opening runs a THIN surplus and any
        // disruption (region unrest, lost farmland, new export obligations) can
        // push grain into genuine deficit. Scales with regions still under state
        // control — a seceded region no longer draws on state granaries.
        let grainDemand = civilianGrainDemand(for: game)
        if grainDemand > 0 {
            let available = max(0, reserves[.grain] ?? 0)
            let eaten = min(available, grainDemand)
            reserves[.grain, default: 0] -= eaten
            if eaten < grainDemand {
                // Unmet civilian demand is a grain deficit exactly like a recipe
                // shortfall — the auto-import/constituency-bleed feedback picks it up.
                shortResources.insert(.grain)
            }
        }

        // STEP 3: Persist updated reserves + result. A resource counts as a
        // deficit only if it actually fell short somewhere — landing at exactly 0
        // after fully satisfying every consumer is NOT a deficit.
        var deficitSet = shortResources
        for (resource, value) in reserves where value < 0 {
            deficitSet.insert(resource)
        }
        let deficits = deficitSet.map { $0.rawValue }.sorted()
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

    // MARK: - Civilian Grain Demand

    /// Per-turn civilian grain consumption — single source of truth shared by
    /// STEP 2.5 above and GameEngine's emergency-import credit. Grain is eaten
    /// by the population, not by any sector recipe, so an import credit that
    /// only sums recipe demand covers ~1 unit against ~16/turn of civilian
    /// draw and the deficit (plus its per-turn treasury charge) never clears.
    /// Scales with regions still under state control — a seceded region no
    /// longer draws on state granaries.
    func civilianGrainDemand(for game: Game) -> Int {
        let feedingRegions = game.regions.filter { extractionMultiplier(for: $0) > 0 }.count
        return 2 + feedingRegions * 2
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
        shortResources: inout Set<StrategicResource>,
        game: Game
    ) -> Int {
        // Determine the bottleneck input. Only the input(s) at the recipe's
        // limiting (minimum) fraction are recorded as short: a non-binding
        // input (e.g. grain 0.9 when energy is 0.5) is consumed at the lower
        // ratio, ends the turn with positive stock, and must NOT be flagged —
        // flagging it triggers a phantom -6/turn auto-import charge plus
        // constituency bleed for a resource that never actually ran out.
        var fraction: Double = 1.0
        var inputFractions: [StrategicResource: Double] = [:]
        for (resource, required) in recipe.inputs where required > 0 {
            let available = max(0, reserves[resource] ?? 0)
            let resourceFraction = min(1.0, Double(available) / Double(required))
            inputFractions[resource] = resourceFraction
            fraction = min(fraction, resourceFraction)
        }
        if fraction < 1.0 {
            for (resource, resourceFraction) in inputFractions where resourceFraction == fraction {
                shortResources.insert(resource)
            }
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
