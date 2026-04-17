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
    func apply(_ decree: EmergencyDecree, to game: Game) {
        guard decree.isAvailable(in: game) else { return }

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
    }
}
