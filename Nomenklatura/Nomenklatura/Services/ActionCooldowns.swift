//
//  ActionCooldowns.swift
//  Nomenklatura
//
//  Shared cooldown tracking for all action services.
//

import Foundation

struct ActionCooldowns: Codable {
    var cooldowns: [String: Int] = [:]  // actionId -> availableTurn

    func isOnCooldown(actionId: String, currentTurn: Int) -> Bool {
        guard let availableTurn = cooldowns[actionId] else { return false }
        return currentTurn < availableTurn
    }

    func turnsRemaining(actionId: String, currentTurn: Int) -> Int {
        guard let availableTurn = cooldowns[actionId] else { return 0 }
        return max(0, availableTurn - currentTurn)
    }

    mutating func setCooldown(actionId: String, availableTurn: Int) {
        cooldowns[actionId] = availableTurn
    }

    mutating func clearExpired(currentTurn: Int) {
        cooldowns = cooldowns.filter { $0.value > currentTurn }
    }
}

// Type aliases for backward compatibility
typealias PartyCooldowns = ActionCooldowns
typealias MinistryCooldowns = ActionCooldowns
typealias MilitaryCooldownTracker = ActionCooldowns
typealias EconomicCooldownTracker = ActionCooldowns
typealias SecurityCooldownTracker = ActionCooldowns
