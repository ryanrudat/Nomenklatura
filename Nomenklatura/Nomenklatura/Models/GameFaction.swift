//
//  GameFaction.swift
//  Nomenklatura
//
//  Faction model for power groups in the game
//

import Foundation
import SwiftData

@Model
final class GameFaction {
    @Attribute(.unique) var id: UUID
    var factionId: String
    var name: String
    var factionDescription: String?

    // Faction power (0-100) - their influence in the state
    var power: Int

    // Player's standing with this faction (0-100)
    var playerStanding: Int

    // Leader of faction (character reference)
    var leaderCharacterId: UUID?

    var game: Game?

    init(factionId: String, name: String, description: String? = nil) {
        self.id = UUID()
        self.factionId = factionId
        self.name = name
        self.factionDescription = description
        self.power = 50
        self.playerStanding = 50
    }
}

// MARK: - Computed Properties

extension GameFaction {
    var powerLevel: StatLevel {
        switch power {
        case 70...: return .high
        case 40..<70: return .medium
        default: return .low
        }
    }

    var standingLevel: StatLevel {
        switch playerStanding {
        case 70...: return .high
        case 40..<70: return .medium
        default: return .low
        }
    }

    /// Icon for faction display
    var displayIcon: String {
        switch factionId {
        case "youth_league": return "⭐"
        case "princelings": return "👑"
        case "reformists": return "🔄"
        case "old_guard": return "🛡️"    // Proletariat Union
        case "regional": return "🗺️"     // People's Provincial Administration
        default: return "🏛️"
        }
    }
}
