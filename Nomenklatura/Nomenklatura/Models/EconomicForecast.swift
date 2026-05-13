//
//  EconomicForecast.swift
//  Nomenklatura
//
//  Pre-turn forecast: predicts where the Chairman's treasury, food,
//  stability, and industrial output are headed next turn IF NOTHING is
//  done — plus the top contributors driving the change and the most
//  relevant levers the player could pull to alter the trajectory.
//
//  Built non-mutating on top of EconomyService.calculateTurnEconomy().
//

import Foundation

// MARK: - Forecast Stat Line

/// One projected stat row in the "if you do nothing" block.
struct ForecastStatLine: Identifiable {
    var id: String { key }
    let key: String          // e.g. "treasury", "foodSupply"
    let label: String        // e.g. "Treasury"
    let projectedDelta: Int  // can be 0
    let currentValue: Int
    let projectedValue: Int  // currentValue + projectedDelta (already clamped to display range)
}

// MARK: - Contributor Line

/// One bulleted "WHY" row attributing some portion of the projected
/// treasury change to a named source.
struct ForecastContributorLine: Identifiable {
    var id: String { label }
    let label: String        // e.g. "Corruption (stability 42)"
    let amount: Int          // signed; positive = income, negative = expense
}

// MARK: - Lever Recommendation

/// One "IF YOU ACT" lever card. The sheet renders these read-only —
/// tapping any lever dismisses the sheet (no execution from the
/// preview path).
struct ForecastLeverRecommendation: Identifiable {
    var id: String { leverId }
    let leverId: String          // unique id for SwiftUI identity
    let kind: Kind
    let title: String            // "Bloc Loan", "Switch Agriculture → Export Crops"
    let subtitle: String         // one-line projected effect summary
    let projectedEffect: String  // e.g. "Treasury +30 once, −2/turn for 20 turns"
    let urgency: Urgency         // affects card accent

    enum Kind: String {
        case loan
        case sectorFocus
        case emergencyDecree
        case planAlignment
    }

    enum Urgency: String {
        case critical    // crisis level — treasury negative, deficit resource
        case advised     // worth considering
        case opportunistic // upside lever, not strictly needed
    }
}

// MARK: - Economic Forecast

/// Aggregate forecast for the next turn — what will happen if the
/// player does nothing, why, and 3–5 highest-relevance levers.
struct EconomicForecast {
    /// Stat-projection rows for "IF YOU DO NOTHING" (4–5 entries).
    let stats: [ForecastStatLine]

    /// "WHY" contributors — top 5 absolute-magnitude items pulled from
    /// the EconomicReport breakdown plus a couple of derived lines.
    let contributors: [ForecastContributorLine]

    /// 3–5 levers the player could pull right now to change the
    /// trajectory. Pre-sorted: critical first, then advised, then
    /// opportunistic.
    let levers: [ForecastLeverRecommendation]

    /// The underlying treasury-bound report used. Surfaced for debug
    /// / inline display ("Net change: -8").
    let netTreasuryChange: Int
}
