//
//  FactionService.swift
//  Nomenklatura
//
//  Service for handling player faction mechanics during gameplay
//

import Foundation
import os.log

private let factionLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "FactionService")

/// Service for applying faction abilities and vulnerabilities during gameplay
final class FactionService {
    static let shared = FactionService()

    /// Flag set on `Game.flags` once starting disposition bias has been applied.
    /// Used to make `applyFactionStartingDisposition(game:)` idempotent.
    static let startingDispositionSeededFlag = "faction_disposition_seeded"

    private init() {}

    // MARK: - Ability Checks

    /// Check if player has a specific faction ability
    func hasAbility(_ abilityId: String, game: Game) -> Bool {
        game.flags.contains("ability_\(abilityId)")
    }

    /// Get the player's faction ability if any
    func getPlayerAbility(game: Game) -> FactionAbility? {
        game.playerFaction?.specialAbility
    }

    /// Get the player's faction vulnerability if any
    func getPlayerVulnerability(game: Game) -> FactionVulnerability? {
        game.playerFaction?.vulnerability
    }

    // MARK: - Corruption Shield

    /// Calculate damage reduction from corruption accusations
    /// Returns multiplier (0.0-1.0) to apply to accusation damage
    func getCorruptionDamageMultiplier(game: Game) -> Double {
        guard let ability = getPlayerAbility(game: game),
              ability.effectType == .corruptionShield else {
            return 1.0  // No reduction
        }

        // Merit shield reduces corruption damage
        let reduction = Double(ability.effectMagnitude) / 100.0
        return max(0.1, 1.0 - reduction)  // Always take at least 10% damage
    }

    // MARK: - Ideological Shield

    /// Calculate damage reduction from ideological accusations
    /// Returns multiplier (0.0-1.0) to apply to accusation damage
    func getIdeologicalDamageMultiplier(game: Game) -> Double {
        guard let ability = getPlayerAbility(game: game),
              ability.effectType == .ideologicalShield else {
            return 1.0  // No reduction
        }

        let reduction = Double(ability.effectMagnitude) / 100.0
        return max(0.1, 1.0 - reduction)
    }

    // MARK: - Economic Bonus

    /// Get bonus to economic policy outcomes
    func getEconomicPolicyBonus(game: Game) -> Int {
        guard let ability = getPlayerAbility(game: game),
              ability.effectType == .economicBonus else {
            return 0
        }

        // Return percentage bonus
        return ability.effectMagnitude / 4  // 25% of magnitude as direct bonus
    }

    // MARK: - Network Bonus

    /// Get bonus to network building actions
    func getNetworkBuildingBonus(game: Game) -> Int {
        guard let ability = getPlayerAbility(game: game),
              ability.effectType == .networkBonus else {
            return 0
        }

        return ability.effectMagnitude / 5  // e.g., +6 from 30 magnitude
    }

    // MARK: - Promotion Modifier

    /// Get promotion threshold modifier from faction
    func getPromotionThresholdModifier(game: Game) -> Int {
        game.playerFaction?.promotionThresholdModifier ?? 0
    }

    // MARK: - Vulnerability Triggers

    /// Check if a vulnerability should trigger based on event type
    func shouldTriggerVulnerability(game: Game, eventType: FactionVulnerability.VulnerabilityTrigger) -> Bool {
        guard let vulnerability = getPlayerVulnerability(game: game) else {
            return false
        }

        return vulnerability.triggerType == eventType
    }

    /// Calculate extra damage when vulnerability is triggered
    func getVulnerabilityDamage(game: Game) -> Int {
        guard let vulnerability = getPlayerVulnerability(game: game) else {
            return 0
        }

        return vulnerability.penaltyMagnitude / 4  // Convert to reasonable stat damage
    }

    // MARK: - Event Targeting

    /// Check if player's faction should be targeted by a specific event
    func shouldTargetPlayerFaction(game: Game, requiredTag: String) -> Bool {
        game.flags.contains(requiredTag)
    }

    /// Check if player's faction should be excluded from an event
    func shouldExcludePlayerFaction(game: Game, excludedTag: String) -> Bool {
        game.flags.contains(excludedTag)
    }

    // MARK: - Faction Display Helpers

    /// Get a description of the player's current faction bonuses for display
    func getFactionStatusDescription(game: Game) -> String? {
        guard let faction = game.playerFaction else { return nil }

        var description = "\(faction.name)"
        if let ability = faction.specialAbility {
            description += " - \(ability.name) active"
        }
        return description
    }

    /// Check if player has any faction (for backward compatibility)
    func hasPlayerFaction(game: Game) -> Bool {
        game.playerFactionId != nil
    }

    // MARK: - Starting Disposition Bias

    /// One-time pass applied at game start. Biases every NPC's starting `disposition`
    /// based on whether their faction is the same as, opposing to, or unrelated to
    /// the player's faction.
    ///
    /// Faction relationships come from `PlayerFactionConfig.factionRelationshipModifiers`:
    ///   - `standingModifier > 0` → ally faction (same-side ish, but we ONLY apply
    ///     the +15 bonus to characters whose `factionId` literally matches the player's,
    ///     not to ally factions; allies stay neutral per the design)
    ///   - `standingModifier < 0` → explicitly opposing faction → characters there take -10
    ///
    /// Idempotent via `Game.flags` (see `startingDispositionSeededFlag`).
    /// Safe to call multiple times — second call is a no-op.
    func applyFactionStartingDisposition(game: Game) {
        // Idempotency guard — never apply twice for a given Game
        if game.flags.contains(Self.startingDispositionSeededFlag) {
            return
        }

        guard let playerFactionId = game.playerFactionId else {
            factionLogger.notice("applyFactionStartingDisposition skipped: no playerFactionId set")
            return
        }

        // Build the set of explicitly opposing faction ids from the player's config.
        // If the player chose a faction without a config entry (shouldn't happen in
        // production but defensively guarded), we proceed with an empty opposing set
        // — same-faction bonus still applies.
        var opposingFactionIds: Set<String> = []
        if let playerFactionConfig = PlayerFactionConfig.faction(withId: playerFactionId) {
            for modifier in playerFactionConfig.factionRelationshipModifiers where modifier.standingModifier < 0 {
                opposingFactionIds.insert(modifier.targetFactionId)
            }
        }

        var sameFactionCount = 0
        var opposingFactionCount = 0
        var neutralCount = 0

        for character in game.characters {
            guard let charFactionId = character.factionId, !charFactionId.isEmpty else {
                // Independent / unaffiliated — leave alone
                neutralCount += 1
                continue
            }

            if charFactionId == playerFactionId {
                character.disposition = min(100, character.disposition + 15)
                sameFactionCount += 1
            } else if opposingFactionIds.contains(charFactionId) {
                character.disposition = max(0, character.disposition - 10)
                opposingFactionCount += 1
            } else {
                neutralCount += 1
            }
        }

        // Mark seeded so the pass can't run twice
        game.flags.append(Self.startingDispositionSeededFlag)

        factionLogger.notice(
            "Seeded faction disposition: \(sameFactionCount) +15, \(opposingFactionCount) -10, \(neutralCount) unchanged"
        )
    }
}

