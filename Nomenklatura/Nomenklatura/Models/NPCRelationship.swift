//
//  NPCRelationship.swift
//  Nomenklatura
//
//  NPC-to-NPC relationship tracking for autonomous political dynamics
//  Enables coalition building, betrayals, and factional conflicts
//

import Foundation
import SwiftData

/// Tracks relationships between NPCs (separate from player-NPC relationships)
/// This enables realistic political dynamics where NPCs form alliances, betrayals, and rivalries
@Model
final class NPCRelationship {
    @Attribute(.unique) var id: UUID

    // Source and target NPCs (by template ID for stable references)
    var sourceCharacterId: String    // The NPC holding this view
    var targetCharacterId: String    // The NPC being viewed

    // Core relationship metrics
    var disposition: Int             // -100 to 100 (negative = hostile, positive = friendly)
    var trust: Int                   // 0-100 (reliability in alliances)
    var fear: Int                    // 0-100 (intimidation factor)
    var respect: Int                 // 0-100 (professional regard)

    // Formal relationship states
    var isAllied: Bool               // Formal alliance
    var isRival: Bool                // Active rivalry
    var isPatron: Bool               // Source is patron of target
    var isClient: Bool               // Source is client of target

    // History tracking
    var lastInteractionTurn: Int     // When they last interacted
    var relationshipStartTurn: Int   // When this relationship began
    var timesBetrayed: Int           // Count of betrayals by target
    var timesBenefited: Int          // Count of benefits from target

    // Grudge/Gratitude system (similar to player-NPC system)
    var grudgeLevel: Int             // 0-100 (resentment accumulated)
    var gratitudeLevel: Int          // 0-100 (appreciation accumulated)

    // Alliance specifics
    var allianceStrength: Int        // 0-100 (how solid the alliance is)
    var allianceFormedTurn: Int?     // When alliance was formed (for duration checks)
    var commonEnemies: [String]      // Character IDs of shared enemies

    // Game reference
    var game: Game?

    init(sourceId: String, targetId: String, turn: Int) {
        self.id = UUID()
        self.sourceCharacterId = sourceId
        self.targetCharacterId = targetId

        // Default neutral relationship
        self.disposition = 0
        self.trust = 50
        self.fear = 0
        self.respect = 50

        self.isAllied = false
        self.isRival = false
        self.isPatron = false
        self.isClient = false

        self.lastInteractionTurn = turn
        self.relationshipStartTurn = turn
        self.timesBetrayed = 0
        self.timesBenefited = 0

        self.grudgeLevel = 0
        self.gratitudeLevel = 0

        self.allianceStrength = 0
        self.commonEnemies = []
    }
}

// MARK: - Relationship Analysis

extension NPCRelationship {

    /// Overall relationship quality (-100 to 100)
    var overallQuality: Int {
        var quality = disposition
        quality += (trust - 50) / 2
        quality += (respect - 50) / 2
        quality += gratitudeLevel / 3
        quality -= grudgeLevel / 2
        if isAllied { quality += 20 }
        if isRival { quality -= 30 }
        return max(-100, min(100, quality))
    }

    /// Whether this NPC would help the target
    var wouldHelp: Bool {
        if isAllied && allianceStrength >= 30 {
            return true
        }
        return overallQuality >= 40 && trust >= 40
    }

    /// Whether this NPC would actively work against the target
    var wouldOppose: Bool {
        if isRival {
            return true
        }
        return overallQuality <= -40 || grudgeLevel >= 60
    }

    /// Whether this NPC would betray the target given opportunity
    var wouldBetray: Bool {
        // Consider betrayal if:
        // - Grudge is high enough
        // - Trust has been broken before
        // - Fear is low (not afraid of retaliation)
        if isAllied && allianceStrength >= 60 {
            return false  // Strong alliances resist betrayal
        }

        let betrayalIncentive = grudgeLevel + (100 - fear)
        return betrayalIncentive >= 120 || timesBetrayed > 0
    }

    /// Relationship stance for AI context
    var stance: NPCRelationshipStance {
        if isAllied && allianceStrength >= 50 {
            return .strongAlly
        }
        if isAllied {
            return .weakAlly
        }
        if isRival && grudgeLevel >= 50 {
            return .bitterEnemy
        }
        if isRival {
            return .rival
        }
        if overallQuality >= 60 {
            return .friendly
        }
        if overallQuality <= -60 {
            return .hostile
        }
        if overallQuality <= -20 {
            return .distrustful
        }
        if trust >= 60 {
            return .trusting
        }
        return .neutral
    }
}

// MARK: - Relationship Modifications

extension NPCRelationship {

    /// Record a betrayal by the target
    func recordBetrayal(turn: Int, severity: Int) {
        timesBetrayed += 1
        disposition = max(-100, disposition - severity)
        trust = max(0, trust - severity / 2)
        grudgeLevel = min(100, grudgeLevel + severity)
        lastInteractionTurn = turn

        // Betrayal ends alliances
        if isAllied {
            isAllied = false
            allianceStrength = 0
            isRival = true
        }
    }

    /// Record a benefit provided by the target
    func recordBenefit(turn: Int, magnitude: Int) {
        timesBenefited += 1
        disposition = min(100, disposition + magnitude / 2)
        trust = min(100, trust + magnitude / 4)
        gratitudeLevel = min(100, gratitudeLevel + magnitude / 2)
        lastInteractionTurn = turn
    }

    /// Form an alliance between NPCs
    func formAlliance(turn: Int, strength: Int) {
        isAllied = true
        isRival = false
        allianceStrength = strength
        allianceFormedTurn = turn
        disposition = max(disposition, 30)
        trust = min(100, trust + 10)
        lastInteractionTurn = turn
    }

    /// Break an alliance
    func breakAlliance(turn: Int, reason: AllianceBreakReason) {
        isAllied = false

        switch reason {
        case .mutualAgreement:
            allianceStrength = 0
        case .betrayal:
            allianceStrength = 0
            isRival = true
            grudgeLevel = min(100, grudgeLevel + 40)
            trust = max(0, trust - 30)
        case .externalPressure:
            allianceStrength = 0
            trust = max(0, trust - 10)
        case .divergingInterests:
            allianceStrength = 0
        }

        lastInteractionTurn = turn
    }

    /// Declare rivalry
    func declareRivalry(turn: Int) {
        isRival = true
        isAllied = false
        allianceStrength = 0
        disposition = min(0, disposition)
        lastInteractionTurn = turn
    }

    /// Increase fear of the target
    func increaseFear(amount: Int, turn: Int) {
        fear = min(100, fear + amount)
        lastInteractionTurn = turn
    }

    /// Increase respect for the target
    func increaseRespect(amount: Int, turn: Int) {
        respect = min(100, respect + amount)
        lastInteractionTurn = turn
    }

    /// Natural decay of extreme emotions over time
    func processDecay(currentTurn: Int) {
        let turnsSinceInteraction = currentTurn - lastInteractionTurn

        // Grudges decay slowly
        if grudgeLevel > 0 && turnsSinceInteraction > 3 {
            grudgeLevel = max(0, grudgeLevel - 2)
        }

        // Gratitude decays faster
        if gratitudeLevel > 0 && turnsSinceInteraction > 2 {
            gratitudeLevel = max(0, gratitudeLevel - 3)
        }

        // Fear decays over time if not reinforced
        if fear > 20 && turnsSinceInteraction > 4 {
            fear = max(20, fear - 5)
        }
    }
}

// MARK: - Supporting Types

enum NPCRelationshipStance: String, Codable {
    case strongAlly
    case weakAlly
    case trusting
    case friendly
    case neutral
    case distrustful
    case hostile
    case rival
    case bitterEnemy

    var displayName: String {
        switch self {
        case .strongAlly: return "Strong Ally"
        case .weakAlly: return "Weak Ally"
        case .trusting: return "Trusting"
        case .friendly: return "Friendly"
        case .neutral: return "Neutral"
        case .distrustful: return "Distrustful"
        case .hostile: return "Hostile"
        case .rival: return "Rival"
        case .bitterEnemy: return "Bitter Enemy"
        }
    }
}

enum AllianceBreakReason: String, Codable {
    case mutualAgreement
    case betrayal
    case externalPressure
    case divergingInterests
}

// MARK: - Game Extension for NPC Relationships

extension Game {

    /// Get relationship between two NPCs
    func npcRelationship(from sourceId: String, to targetId: String) -> NPCRelationship? {
        // Note: This requires adding npcRelationships to Game's @Relationship
        // For now, we'll need to query through characters
        return nil  // TODO: Implement once relationship is added to Game
    }

    /// Get all relationships for a specific NPC
    func npcRelationships(for characterId: String) -> [NPCRelationship] {
        return []  // TODO: Implement
    }

    /// Initialize NPC-NPC relationships at game start
    func initializeNPCRelationships() {
        // Create relationships between all active NPCs
        // Initial disposition based on:
        // - Same faction: +20 disposition, +10 trust
        // - Different faction: -10 disposition
        // - Same track: +10 (colleagues) or -15 (direct competitors at same level)
        // - Position proximity: Higher positions gain fear/respect

        // TODO: Implement initialization logic
    }
}

// MARK: - AI Context

extension NPCRelationship {

    /// Brief context for AI generation
    var aiContext: String {
        var context = "\(sourceCharacterId) → \(targetCharacterId): "
        context += "\(stance.displayName)"

        if isAllied {
            context += " (Allied, strength \(allianceStrength))"
        }
        if isRival {
            context += " (Rival)"
        }
        if grudgeLevel > 30 {
            context += " [Grudge: \(grudgeLevel)]"
        }
        if gratitudeLevel > 30 {
            context += " [Gratitude: \(gratitudeLevel)]"
        }

        return context
    }
}
