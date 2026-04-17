//
//  SupplyChainResult.swift
//  Nomenklatura
//
//  Per-turn record of what the supply-chain engine actually did.
//  Persisted on Game so the UI (Phase 3.3 SectorDetailView) can show
//  source regions, consumption, shortfalls, and surpluses without
//  re-computing everything.
//

import Foundation

struct SupplyChainResult: Codable {
    let turn: Int

    /// Resource extracted per region this turn (filtered by region status —
    /// crisis regions extract at 50%, secession at 0%).
    let extractedByRegion: [String: [String: Int]]   // regionId → [resource.rawValue: amount]

    /// Total resource produced by sectors this turn (steel mills, etc.)
    let producedBySector: [String: [String: Int]]    // sector.rawValue → [resource.rawValue: amount]

    /// Resource consumed by sectors this turn.
    let consumedBySector: [String: [String: Int]]    // sector.rawValue → [resource.rawValue: amount]

    /// Sectors whose output was scaled down due to input shortfalls.
    /// Maps sector → satisfaction percentage (0-100). Sectors not listed
    /// were fully satisfied or had no inputs.
    let shortfallBySector: [String: Int]             // sector.rawValue → satisfaction %

    /// Resources currently in deficit across the whole economy
    /// (reserve at end of turn ≤ 0). Helps surface "we need more X" alerts.
    let deficitResources: [String]                   // [StrategicResource.rawValue]

    static func empty(turn: Int) -> SupplyChainResult {
        SupplyChainResult(
            turn: turn,
            extractedByRegion: [:],
            producedBySector: [:],
            consumedBySector: [:],
            shortfallBySector: [:],
            deficitResources: []
        )
    }
}
