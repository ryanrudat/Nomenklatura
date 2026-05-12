//
//  EmergencyDecreeService.swift
//  Nomenklatura
//
//  Phase 3.8: orchestrates emergency decree application — looks up
//  available decrees given current crisis state, applies the chosen
//  decree's stat + resource + treasury effects, and logs the decree
//  as a high-importance GameEvent so the Codex/journal records the
//  chairman's response.
//

import Foundation

@MainActor
final class EmergencyDecreeService {
    static let shared = EmergencyDecreeService()

    private init() {}

    /// All decrees, with a flag indicating whether each is currently
    /// reachable. Returned in catalog order so the UI list is stable
    /// regardless of which crises are active.
    func decreesWithAvailability(in game: Game) -> [(decree: EmergencyDecree, available: Bool)] {
        EmergencyDecree.allCases.map { ($0, $0.isAvailable(in: game)) }
    }

    /// Whether ANY decree is currently available — used by call sites
    /// to decide whether to show the "Emergency Decrees" entry point.
    func hasAvailableDecrees(in game: Game) -> Bool {
        EmergencyDecree.allCases.contains { $0.isAvailable(in: game) }
    }

    /// Apply a decree's full effect: treasury, stats, resources, and a
    /// logged event. Caller is responsible for verifying availability
    /// (the UI greys out unavailable decrees, but applying still
    /// no-ops if the decree isn't reachable to be safe).
    ///
    /// Pass `force: true` when the caller has already gated on a
    /// broader crisis condition (e.g. Crisis Response's
    /// `.resourceCatastrophe`, which fires on 3+ deficits but doesn't
    /// guarantee grain specifically is depleted). Forcing skips the
    /// per-decree availability check but still runs the full effect
    /// chain so both UI entry points produce identical state changes.
    ///
    /// Emergency decrees consume one charge from the Chairman's shared
    /// decree pool (`game.decreeChargesRemaining`, regen 1/50 turns) —
    /// same pool spent by Security executions and Crisis Response
    /// `requiresDecreeCharge` options. `force: true` bypasses the
    /// per-decree availability gate but does NOT bypass the charge
    /// requirement; an out-of-charges Chairman cannot decree, period.
    ///
    /// Pass `viaChargeAlreadyPaid: true` from call sites that have
    /// ALREADY deducted a charge upstream (currently: Crisis Response's
    /// `requisition_decree` option, which sets `requiresDecreeCharge: true`
    /// on the option itself and so `CrisisResponseService.executeOption`
    /// has already paid before reaching `applyOptionSideEffects`). This
    /// prevents the charge from being double-counted while still letting
    /// both surfaces converge on the same effect chain.
    ///
    /// Returns `true` when the decree was actually applied; `false`
    /// when refused (no charges, unavailable and not forced).
    @discardableResult
    func apply(_ decree: EmergencyDecree, to game: Game, force: Bool = false, viaChargeAlreadyPaid: Bool = false) -> Bool {
        // Charge gate FIRST. Even forced decrees consume a charge — the
        // only exception is when the upstream caller already paid.
        if !viaChargeAlreadyPaid {
            guard game.decreeChargesRemaining > 0 else { return false }
        }

        // Availability gate (skipped under `force`).
        if !force {
            guard decree.isAvailable(in: game) else { return false }
        }

        // Treasury
        if decree.treasuryCost != 0 {
            game.applyStat("treasury", change: decree.treasuryCost)
        }

        // Stats
        for (stat, change) in decree.statEffects {
            game.applyStat(stat, change: change)
        }

        // Resources
        var reserves = game.strategicReserves
        for (resource, delta) in decree.resourceEffects {
            reserves[resource, default: 0] += delta
        }
        game.strategicReserves = reserves.filter { $0.value > 0 }

        // Event log
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .crisis,
            summary: "Emergency Decree: \(decree.displayName) — \(decree.description)"
        )
        event.importance = 8
        event.details = [
            "type": "emergency_decree",
            "decree": decree.rawValue
        ]
        event.game = game
        game.events.append(event)

        // Deduct the charge AFTER successful application (skip when an
        // upstream caller, e.g. Crisis Response, already paid).
        if !viaChargeAlreadyPaid {
            game.decreeChargesRemaining = max(0, game.decreeChargesRemaining - 1)
        }

        return true
    }
}
