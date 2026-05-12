//
//  CrisisResponseOption.swift
//  Nomenklatura
//
//  A single action the Chairman can take from the Crisis Response Panel.
//  Options have stable string IDs (so the UI can key off them) plus all
//  the data CrisisResponseService.executeOption(_:in:) needs to apply
//  costs, roll for success, and emit a result + GameEvent.
//

import Foundation

struct CrisisResponseOption: Identifiable, Equatable {
    /// Stable key, e.g. "crackdown" or "emergency_welfare". Used by UI
    /// to look up icons/styling and by the log to record what was tried.
    let id: String
    let crisisType: CrisisType

    /// Bracketed tracked-mono label, e.g. "[CRACKDOWN]".
    let label: String

    /// One-to-two sentence flavour preview shown before the player commits.
    let shortDescription: String

    /// Action point cost (0/1/2). Validated against `game.actionPoints`.
    let costAP: Int

    /// Treasury cost. Always positive here — applied as a negative delta
    /// internally so option authors don't need to remember signs.
    let costTreasury: Int

    /// If `true`, consumes one `game.decreeChargesRemaining` and requires
    /// at least one to be available.
    let requiresDecreeCharge: Bool

    /// Minimum stat thresholds gating availability, e.g. ["militaryLoyalty": 50].
    /// Keys match `Game.applyStat(_:change:)` switch.
    let minStatRequirements: [String: Int]

    /// Probability of success in [0, 1].
    let baseSuccessChance: Double

    /// Stat deltas applied on success. Keys match `Game.applyStat(_:change:)`.
    let onSuccess: [String: Int]

    /// Stat deltas applied on failure (after costs already paid).
    let onFailure: [String: Int]

    /// Flag strings appended to `game.flags` on success. Strings containing
    /// `"\\(turn)"` will be substituted at execution time with the current
    /// turn number; everything else is passed through verbatim.
    let setsFlags: [String]

    /// Outcome narratives — the panel can show whichever branch fired.
    let narrativeSuccess: String
    let narrativeFailure: String

    /// Whether the Chairman can pick this right now: AP, treasury, decree
    /// charges, and stat-threshold gates all pass.
    func isAvailable(in game: Game) -> Bool {
        if game.actionPoints < costAP { return false }
        if costTreasury > 0 && game.treasury < costTreasury { return false }
        if requiresDecreeCharge && game.decreeChargesRemaining <= 0 { return false }

        for (key, required) in minStatRequirements {
            if currentStatValue(key, in: game) < required { return false }
        }
        return true
    }

    /// Resolve a stat key against the live `Game` instance. Mirrors the
    /// switch in `Game.applyStat(_:change:)` so threshold gates use the
    /// same source of truth as the writer. Unknown keys default to a
    /// permissive `Int.max` so a typo in a requirement doesn't silently
    /// lock the option out (the option will still apply via applyStat,
    /// which is the canonical filter).
    private func currentStatValue(_ key: String, in game: Game) -> Int {
        switch key {
        case "stability":               return game.stability
        case "popularSupport":          return game.popularSupport
        case "militaryLoyalty":         return game.militaryLoyalty
        case "eliteLoyalty":            return game.eliteLoyalty
        case "treasury":                return game.treasury
        case "industrialOutput":        return game.industrialOutput
        case "foodSupply":              return game.foodSupply
        case "internationalStanding":   return game.internationalStanding
        case "standing":                return game.standing
        case "patronFavor":             return game.patronFavor
        case "rivalThreat":             return game.rivalThreat
        case "network":                 return game.network
        case "worldTension":            return game.worldTension
        case "militaryReadiness":       return game.militaryReadiness
        default:                        return .max
        }
    }
}
