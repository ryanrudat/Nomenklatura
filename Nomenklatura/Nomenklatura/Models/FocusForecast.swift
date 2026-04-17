//
//  FocusForecast.swift
//  Nomenklatura
//
//  Phase 3.4: predicts the cascading impact of switching a sector's
//  focus before the player commits. Surfaces input/output deltas,
//  reserve projections, cross-sector strain, and stat-effect changes
//  so the Chairman can see exactly what their decision means.
//

import Foundation

struct FocusForecast: Identifiable {
    /// Identity = sector + proposed focus, so SwiftUI's .sheet(item:)
    /// re-presents when the player picks a different focus while the
    /// sheet is up.
    var id: String { "\(sector.rawValue)_\(proposedFocus.focusId)" }

    let sector: EconomicSector
    let currentFocus: SectorFocus?
    let proposedFocus: SectorFocus
    let isLocked: Bool
    let lockReason: String?

    /// Per-resource net change in inputs *required* per turn (proposed - current).
    /// Negative = less required, positive = more required.
    let inputDelta: [StrategicResource: Int]

    /// Per-resource net change in outputs *produced* per turn (proposed - current).
    let outputDelta: [StrategicResource: Int]

    /// Projected reserve count for each resource at end of next turn,
    /// holding everything else constant. Surfaces "after this switch you
    /// will run out of oil within 2 turns" effects.
    let reserveProjection: [StrategicResource: Int]

    /// Sectors whose satisfaction will drop below 100% as a side effect
    /// of this focus change (because they share a resource we're now
    /// consuming more of). Maps sector.rawValue → projected satisfaction %.
    let crossSectorImpacts: [EconomicSector: Int]

    /// Net change in per-turn stat effects (popularSupport, militaryLoyalty,
    /// etc.) from the SectorFocus.effects dictionaries.
    let statEffectChanges: [String: Int]

    /// Net change in treasury cost per turn (proposed - current).
    /// Positive = costs more; negative = costs less.
    let treasuryCostDelta: Int
}

// MARK: - Helpers

extension FocusForecast {
    /// Total resource pressure score: positive = adds load to economy,
    /// negative = relieves pressure. Used for at-a-glance "is this risky?"
    var pressureScore: Int {
        inputDelta.values.reduce(0, +) - outputDelta.values.reduce(0, +)
    }

    var hasShortfallRisk: Bool {
        reserveProjection.contains { $0.value < 0 }
    }

    var deficitResources: [StrategicResource] {
        reserveProjection.compactMap { $0.value < 0 ? $0.key : nil }
            .sorted { $0.displayName < $1.displayName }
    }
}
