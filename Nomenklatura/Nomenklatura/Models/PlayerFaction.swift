//
//  PlayerFaction.swift
//  Nomenklatura
//
//  Player-selectable faction configuration with trade-offs
//

import Foundation

// MARK: - Player Faction Configuration

/// Configuration for a player-selectable faction
struct PlayerFactionConfig: Codable, Identifiable {
    var id: String
    var name: String
    var subtitle: String                    // "The Meritocrats" / "Red Aristocracy"
    var description: String
    var historicalBasis: String             // Brief historical context

    // Trade-offs
    var statBonuses: [String: Int]          // Stat key -> bonus amount
    var statPenalties: [String: Int]        // Stat key -> penalty amount
    var specialAbility: FactionAbility?
    var vulnerability: FactionVulnerability?

    // Starting modifiers for NPC factions
    var factionRelationshipModifiers: [FactionRelationshipModifier]

    // Starting character bonuses (e.g., extra allies)
    var startingCharacterBonuses: [CharacterBonus]?

    // Gameplay modifiers
    var promotionThresholdModifier: Int     // +/- to required standing for promotion
    var eventTargetingTags: [String]        // Tags for faction-specific events
}

// MARK: - Faction Ability

/// A special ability granted by the player's faction
struct FactionAbility: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var effectType: FactionEffectType
    var effectMagnitude: Int                // How strong the effect is (0-100)

    enum FactionEffectType: String, Codable {
        case corruptionShield               // Reduces effectiveness of corruption accusations
        case ideologicalShield              // Reduces effectiveness of ideological accusations
        case promotionBoost                 // Easier promotions
        case economicBonus                  // Better economic outcomes
        case networkBonus                   // Faster network building
        case patronProtection               // Better patron relationships
    }
}

// MARK: - Faction Vulnerability

/// A weakness that comes with the player's faction choice
struct FactionVulnerability: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var triggerType: VulnerabilityTrigger
    var penaltyMagnitude: Int               // How severe the penalty (0-100)

    enum VulnerabilityTrigger: String, Codable {
        case antiCorruptionCampaign         // Triggered during anti-corruption events
        case ideologicalCampaign            // Triggered during ideological purity events
        case economicCrisis                 // Triggered when economy fails
        case patronFall                     // Triggered when patron loses power
        case regionalFailure                // Triggered when your region underperforms
        case eliteBacklash                  // Triggered by elite faction opposition
    }
}

// MARK: - Faction Relationship Modifier

/// Modifies starting relationship with an NPC faction
struct FactionRelationshipModifier: Codable {
    var targetFactionId: String             // Which NPC faction
    var standingModifier: Int               // +/- to starting standing with that faction
}

// MARK: - Character Bonus

/// Bonus starting character relationship
struct CharacterBonus: Codable {
    var characterRole: String               // "ally", "subordinate", etc.
    var dispositionBonus: Int               // Starting disposition bonus
    var count: Int                          // How many characters get this bonus
}

// MARK: - Default Faction Definitions

extension PlayerFactionConfig {
    /// Returns all available player factions for the game
    static var allFactions: [PlayerFactionConfig] {
        [
            youthLeague,
            princelings,
            reformists,
            oldGuard,
            regional
        ]
    }

    // MARK: Youth League

    static var youthLeague: PlayerFactionConfig {
        PlayerFactionConfig(
            id: "youth_league",
            name: "Youth League",
            subtitle: "The Meritocrats",
            description: "You rose through the Communist Youth League, proving yourself through competence and dedication. The Party machinery respects your abilities, but you lack the elite connections that open doors in the upper echelons.",
            historicalBasis: "Based on the Communist Youth League faction - a path to power through merit rather than birth.",
            statBonuses: [
                "standing": 15,
                "reputationCompetent": 10
            ],
            statPenalties: [
                "network": -20,
                "patronFavor": -10
            ],
            specialAbility: FactionAbility(
                id: "merit_shield",
                name: "Merit Shield",
                description: "Your record of competence makes corruption accusations less credible. Reduced damage from anti-corruption campaigns.",
                effectType: .corruptionShield,
                effectMagnitude: 30
            ),
            vulnerability: FactionVulnerability(
                id: "elite_suspicion",
                name: "Elite Suspicion",
                description: "Princeling factions view you as an upstart threatening the natural order. They may unite against you.",
                triggerType: .eliteBacklash,
                penaltyMagnitude: 25
            ),
            factionRelationshipModifiers: [
                FactionRelationshipModifier(targetFactionId: "reformists", standingModifier: 10),
                FactionRelationshipModifier(targetFactionId: "princelings", standingModifier: -5)
            ],
            startingCharacterBonuses: nil,
            promotionThresholdModifier: -5,
            eventTargetingTags: ["meritocrat", "youth_league", "outsider"]
        )
    }

    // MARK: Princelings

    static var princelings: PlayerFactionConfig {
        PlayerFactionConfig(
            id: "princelings",
            name: "Princelings",
            subtitle: "Red Aristocracy",
            description: "Your family fought in the revolution. Their sacrifice earned your birthright - connections that span the highest levels of power. But privilege breeds envy, and anti-corruption campaigns often target families like yours.",
            historicalBasis: "Based on the 'Red Aristocracy' - descendants of revolutionary heroes who inherited political capital.",
            statBonuses: [
                "network": 25,
                "patronFavor": 15
            ],
            statPenalties: [
                "popularSupport": -10,
                "rivalThreat": 15
            ],
            specialAbility: FactionAbility(
                id: "revolutionary_bloodline",
                name: "Revolutionary Bloodline",
                description: "Your family's revolutionary credentials provide some immunity to ideological attacks. 'Question my loyalty? My father died for the revolution.'",
                effectType: .ideologicalShield,
                effectMagnitude: 35
            ),
            vulnerability: FactionVulnerability(
                id: "corruption_scrutiny",
                name: "Corruption Scrutiny",
                description: "Anti-corruption campaigns target elite families. When they come, your privilege becomes a liability.",
                triggerType: .antiCorruptionCampaign,
                penaltyMagnitude: 40
            ),
            factionRelationshipModifiers: [
                FactionRelationshipModifier(targetFactionId: "old_guard", standingModifier: 10),
                FactionRelationshipModifier(targetFactionId: "regional", standingModifier: 5)
            ],
            startingCharacterBonuses: [
                CharacterBonus(characterRole: "ally", dispositionBonus: 15, count: 2)
            ],
            promotionThresholdModifier: 0,
            eventTargetingTags: ["princeling", "elite", "privileged", "red_aristocracy"]
        )
    }

    // MARK: Reformists

    static var reformists: PlayerFactionConfig {
        PlayerFactionConfig(
            id: "reformists",
            name: "Reformists",
            subtitle: "The Pragmatists",
            description: "You believe in practical results over ideological purity. Economic development, modernization, opening to the world - these are the paths to strength. But reformers walk a dangerous line when winds shift toward orthodoxy.",
            historicalBasis: "Based on reform-minded leaders who prioritized economic development over ideological rigidity.",
            statBonuses: [
                "industrialOutput": 10,
                "internationalStanding": 10
            ],
            statPenalties: [
                "standing": -5  // Old guard suspicion
            ],
            specialAbility: FactionAbility(
                id: "economic_pragmatism",
                name: "Economic Pragmatism",
                description: "Your economic policies tend to produce results. Bonus to industrial and treasury outcomes.",
                effectType: .economicBonus,
                effectMagnitude: 25
            ),
            vulnerability: FactionVulnerability(
                id: "capitalist_roader",
                name: "Capitalist Roader",
                description: "When ideological winds shift, you're vulnerable to accusations of abandoning socialist principles.",
                triggerType: .ideologicalCampaign,
                penaltyMagnitude: 35
            ),
            factionRelationshipModifiers: [
                FactionRelationshipModifier(targetFactionId: "regional", standingModifier: 15),
                FactionRelationshipModifier(targetFactionId: "old_guard", standingModifier: -10)
            ],
            startingCharacterBonuses: nil,
            promotionThresholdModifier: 0,
            eventTargetingTags: ["reformist", "pragmatist", "modernizer"]
        )
    }

    // MARK: Proletariat Union

    static var oldGuard: PlayerFactionConfig {
        PlayerFactionConfig(
            id: "old_guard",
            name: "Proletariat Union",
            subtitle: "Ideological Guardians",
            description: "You rose through the labor unions that sparked the Revolution. While others chase economic miracles, you remember why we marched on Washington. The workers trust you, but progress may pass you by.",
            historicalBasis: "Based on the industrial unions that organized the Second Revolution and maintain ideological purity.",
            statBonuses: [
                "reputationLoyal": 10
            ],
            statPenalties: [
                "industrialOutput": -10,
                "internationalStanding": -10
            ],
            specialAbility: FactionAbility(
                id: "ideological_guardian",
                name: "Ideological Guardian",
                description: "Your orthodox credentials make you immune to accusations of revisionism. Purges you initiate face less resistance.",
                effectType: .ideologicalShield,
                effectMagnitude: 40
            ),
            vulnerability: FactionVulnerability(
                id: "economic_liability",
                name: "Economic Liability",
                description: "When economic crises hit, your resistance to reform makes you a convenient scapegoat.",
                triggerType: .economicCrisis,
                penaltyMagnitude: 30
            ),
            factionRelationshipModifiers: [
                FactionRelationshipModifier(targetFactionId: "youth_league", standingModifier: 20),
                FactionRelationshipModifier(targetFactionId: "princelings", standingModifier: 10),
                FactionRelationshipModifier(targetFactionId: "reformists", standingModifier: -10)
            ],
            startingCharacterBonuses: nil,
            promotionThresholdModifier: 0,
            eventTargetingTags: ["hardliner", "orthodox", "conservative", "old_guard"]
        )
    }

    // MARK: People's Provincial Administration

    static var regional: PlayerFactionConfig {
        PlayerFactionConfig(
            id: "regional",
            name: "People's Provincial Administration",
            subtitle: "State Governors' Network",
            description: "You built your career far from Washington, cultivating a loyal network through the Zone administrations. When you arrived in the corridors of power, you brought an army of supporters. But capital elites view you as an outsider with 'provincial thinking.'",
            historicalBasis: "Based on the Labour Councils that governed sympathetic states during the Revolution and now control the Zones.",
            statBonuses: [
                "network": 30,
                "popularSupport": 15
            ],
            statPenalties: [
                "standing": -15
            ],
            specialAbility: FactionAbility(
                id: "provincial_loyalty",
                name: "Provincial Loyalty",
                description: "Your regional network provides a base of loyal supporters. Can call on regional resources in crisis.",
                effectType: .networkBonus,
                effectMagnitude: 30
            ),
            vulnerability: FactionVulnerability(
                id: "localism_accusations",
                name: "Localism Accusations",
                description: "Your regional focus makes you vulnerable to accusations of 'localism' and putting provincial interests above the state.",
                triggerType: .regionalFailure,
                penaltyMagnitude: 35
            ),
            factionRelationshipModifiers: [
                FactionRelationshipModifier(targetFactionId: "youth_league", standingModifier: -10),
                FactionRelationshipModifier(targetFactionId: "princelings", standingModifier: 5)
            ],
            startingCharacterBonuses: [
                CharacterBonus(characterRole: "subordinate", dispositionBonus: 20, count: 1)
            ],
            promotionThresholdModifier: 5,  // Harder to promote (outsider disadvantage)
            eventTargetingTags: ["regional", "provincial", "outsider"]
        )
    }
}

// MARK: - Helper Extensions

extension PlayerFactionConfig {
    /// Get faction by ID
    static func faction(withId id: String) -> PlayerFactionConfig? {
        allFactions.first { $0.id == id }
    }

    /// All stat changes (bonuses and penalties combined)
    var allStatChanges: [String: Int] {
        var changes = statBonuses
        for (key, value) in statPenalties {
            changes[key] = (changes[key] ?? 0) + value
        }
        return changes
    }

    /// Benefits as displayable strings
    var benefitStrings: [String] {
        var benefits: [String] = []

        for (stat, value) in statBonuses where value > 0 {
            benefits.append("+\(value) \(formatStatName(stat))")
        }

        if promotionThresholdModifier < 0 {
            benefits.append("Faster promotions")
        }

        if let ability = specialAbility {
            benefits.append(ability.name)
        }

        return benefits
    }

    /// Drawbacks as displayable strings
    var drawbackStrings: [String] {
        var drawbacks: [String] = []

        for (stat, value) in statPenalties where value < 0 {
            drawbacks.append("\(value) \(formatStatName(stat))")
        }

        if promotionThresholdModifier > 0 {
            drawbacks.append("Harder promotions")
        }

        if let vuln = vulnerability {
            drawbacks.append(vuln.name)
        }

        return drawbacks
    }

    private func formatStatName(_ key: String) -> String {
        switch key {
        case "standing": return "Standing"
        case "patronFavor": return "Patron Favor"
        case "rivalThreat": return "Rival Threat"
        case "network": return "Network"
        case "reputationCompetent": return "Reputation (Competent)"
        case "reputationLoyal": return "Reputation (Loyal)"
        case "reputationCunning": return "Reputation (Cunning)"
        case "reputationRuthless": return "Reputation (Ruthless)"
        case "stability": return "Stability"
        case "popularSupport": return "Popular Support"
        case "militaryLoyalty": return "Military Loyalty"
        case "eliteLoyalty": return "Elite Loyalty"
        case "treasury": return "Treasury"
        case "industrialOutput": return "Industrial Output"
        case "foodSupply": return "Food Supply"
        case "internationalStanding": return "International Standing"
        default: return key.capitalized
        }
    }
}
