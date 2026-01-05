//
//  TestScenarioService.swift
//  Nomenklatura
//
//  Service for applying test scenarios to create specific game states.
//
//  ============================================================================
//  DEBUG/DEVELOPMENT CODE - REMOVE BEFORE APP STORE RELEASE
//  This entire file should be removed before production release.
//  All code is wrapped in #if DEBUG to prevent accidental inclusion.
//  ============================================================================
//

import Foundation
import SwiftData
import os.log

#if DEBUG

private let scenarioLogger = Logger(subsystem: "com.nomenklatura", category: "TestScenario")

/// Service for applying test scenarios to create games at specific states.
/// DEBUG only - allows testing different bureau positions, crisis situations, etc.
@MainActor
class TestScenarioService {
    static let shared = TestScenarioService()

    private init() {}

    // MARK: - Scenario Application

    /// Apply a test scenario to create a new game in that state
    /// - Parameters:
    ///   - scenario: The test scenario to apply
    ///   - context: The SwiftData model context
    /// - Returns: The newly created game in the specified state
    func applyScenario(_ scenario: TestScenario, context: ModelContext) -> Game {
        scenarioLogger.info("Applying test scenario: \(scenario.name) [\(scenario.id)]")

        // Create base game
        let game = Game(campaignId: "coldwar")
        game.playerFactionId = "youth_league"
        game.turnNumber = scenario.turnNumber

        // Load campaign config
        let config = CampaignLoader.shared.getColdWarCampaign()

        // Apply position configuration
        applyPositionConfig(scenario.positionConfig, to: game)

        // Apply stats configuration
        applyStatsConfig(scenario.statsConfig, to: game)

        // Apply track affinity if specified
        if let affinity = scenario.trackAffinityOverride {
            game.trackAffinityScores = affinity.toTrackAffinityScores()
        }

        // Apply flags
        if let flags = scenario.flagsToSet {
            game.flags.append(contentsOf: flags)
        }

        // Apply crisis configuration
        if let crisis = scenario.crisisConfig {
            applyCrisisConfig(crisis, to: game)
        }

        // Insert game first (required before adding relationships)
        context.insert(game)

        // Create characters with relationship config
        createCharacters(for: game, scenario: scenario, config: config, context: context)

        // Apply NPC overrides after characters are created
        if let overrides = scenario.npcOverrides {
            applyNPCOverrides(overrides, to: game)
        }

        // Initialize all supporting game systems
        initializeGameSystems(game: game, config: config, context: context)

        // Record initial stat history for sparklines
        game.recordAllStatHistory()

        scenarioLogger.info("Scenario '\(scenario.name)' applied successfully - Turn \(game.turnNumber), Position \(game.currentPositionIndex)")
        return game
    }

    // MARK: - Position Configuration

    private func applyPositionConfig(_ config: TestPositionConfig, to game: Game) {
        game.currentPositionIndex = config.positionIndex
        game.currentExpandedTrack = config.expandedTrack

        // Set track for legacy compatibility
        if config.expandedTrack == "shared" {
            game.currentTrack = "shared"
        } else if config.expandedTrack == "regional" {
            game.currentTrack = "regional"
        } else {
            game.currentTrack = "capital"
        }

        // Set track commitment based on position
        if config.positionIndex >= 2 && config.expandedTrack != "shared" {
            game.trackCommitmentStatus = TrackCommitmentStatus.committed.rawValue
            game.committedTrack = config.expandedTrack
        }

        if let turns = config.turnsInPosition {
            game.turnsInCurrentPosition = turns
        } else {
            game.turnsInCurrentPosition = max(1, config.positionIndex)
        }

        if let gsturns = config.turnsAsGeneralSecretary {
            game.turnsAsGeneralSecretary = gsturns
        }
    }

    // MARK: - Stats Configuration

    private func applyStatsConfig(_ config: TestStatsConfig, to game: Game) {
        // National stats - use defaults from campaign if not specified
        let campaignConfig = CampaignLoader.shared.getColdWarCampaign()

        game.stability = config.stability ?? campaignConfig.startingStats.stability
        game.popularSupport = config.popularSupport ?? campaignConfig.startingStats.popularSupport
        game.militaryLoyalty = config.militaryLoyalty ?? campaignConfig.startingStats.militaryLoyalty
        game.eliteLoyalty = config.eliteLoyalty ?? campaignConfig.startingStats.eliteLoyalty
        game.treasury = config.treasury ?? campaignConfig.startingStats.treasury
        game.industrialOutput = config.industrialOutput ?? campaignConfig.startingStats.industrialOutput
        game.foodSupply = config.foodSupply ?? campaignConfig.startingStats.foodSupply
        game.internationalStanding = config.internationalStanding ?? campaignConfig.startingStats.internationalStanding

        // Personal stats
        game.standing = config.standing ?? campaignConfig.startingPersonalStats.standing
        game.patronFavor = config.patronFavor ?? campaignConfig.startingPersonalStats.patronFavor
        game.rivalThreat = config.rivalThreat ?? campaignConfig.startingPersonalStats.rivalThreat
        game.network = config.network ?? campaignConfig.startingPersonalStats.network

        // Reputation (defaults to 50)
        game.reputationCompetent = config.reputationCompetent ?? 50
        game.reputationLoyal = config.reputationLoyal ?? 50
        game.reputationCunning = config.reputationCunning ?? 50
        game.reputationRuthless = config.reputationRuthless ?? 50

        // Wealth/Corruption (defaults to 0)
        game.personalWealth = config.personalWealth ?? 0
        game.corruptionEvidence = config.corruptionEvidence ?? 0
    }

    // MARK: - Crisis Configuration

    private func applyCrisisConfig(_ config: TestCrisisConfig, to game: Game) {
        if let v = config.resistanceAccumulation {
            game.resistanceAccumulation = v
        }
        if let v = config.coalitionStrength {
            game.coalitionStrength = v
        }
        if let v = config.policiesForced {
            game.policiesForced = v
        }
        // Note: activeShowTrialCount and activePurgeCampaign would need
        // more complex setup - these are tracked as separate data structures
    }

    // MARK: - Character Creation

    private func createCharacters(
        for game: Game,
        scenario: TestScenario,
        config: CampaignConfig,
        context: ModelContext
    ) {
        let relationshipConfig = scenario.relationshipConfig

        // Randomize General Secretary faction
        let possibleGSFactions = ["youth_league", "princelings", "reformists", "old_guard", "regional"]
        let randomGSFaction = possibleGSFactions.randomElement()!

        for template in config.startingCharacters {
            let character = GameCharacter(
                templateId: template.id,
                name: template.name,
                title: template.title,
                role: CharacterRole(rawValue: template.role) ?? .neutral
            )

            // Set base properties
            character.positionIndex = template.positionIndex
            character.positionTrack = template.positionTrack
            character.speechPattern = template.speechPattern

            // Randomize GS faction
            if template.id == "brenner" {
                character.factionId = randomGSFaction
            } else {
                character.factionId = template.factionId
            }

            // Apply personality from template
            character.personalityAmbitious = template.personality.ambitious
            character.personalityParanoid = template.personality.paranoid
            character.personalityRuthless = template.personality.ruthless
            character.personalityCompetent = template.personality.competent
            character.personalityLoyal = template.personality.loyal
            character.personalityCorrupt = template.personality.corrupt

            // Copy biographical data
            character.backstory = template.backstory
            character.ageCategory = template.ageCategory
            character.originLocation = template.originLocation
            character.familyBackground = template.familyBackground
            character.historicalConnections = template.historicalConnections ?? []

            // Apply relationship config for patron
            if template.isPatron {
                character.isPatron = relationshipConfig.patronIsActive
                if let disp = relationshipConfig.patronDisposition {
                    character.disposition = disp
                } else {
                    character.disposition = template.startingDisposition
                }

                // Mark patron as dead if inactive
                if !relationshipConfig.patronIsActive {
                    character.status = CharacterStatus.dead.rawValue
                    character.isPatron = false
                }
            } else if template.isRival {
                character.isRival = relationshipConfig.rivalIsActive
                if let disp = relationshipConfig.rivalDisposition {
                    character.disposition = disp
                } else {
                    character.disposition = template.startingDisposition
                }
            } else {
                character.disposition = template.startingDisposition
            }

            context.insert(character)
            character.game = game
            game.characters.append(character)
        }

        // Create additional allies if requested
        if let allyCount = relationshipConfig.createAdditionalAllies, allyCount > 0 {
            for i in 0..<allyCount {
                let ally = createTestCharacter(
                    name: "Andrei Volkov \(i + 1)",  // Generic ally name
                    role: .ally,
                    disposition: 65 + Int.random(in: 0...15),
                    positionIndex: max(1, scenario.positionConfig.positionIndex - 1),
                    context: context
                )
                ally.game = game
                game.characters.append(ally)
            }
        }

        // Create additional rivals if requested
        if let rivalCount = relationshipConfig.createAdditionalRivals, rivalCount > 0 {
            for i in 0..<rivalCount {
                let rival = createTestCharacter(
                    name: "Viktor Petrov \(i + 1)",  // Generic rival name
                    role: .rival,
                    disposition: -30 - Int.random(in: 0...30),
                    positionIndex: scenario.positionConfig.positionIndex + Int.random(in: 0...1),
                    context: context
                )
                rival.isRival = true
                rival.game = game
                game.characters.append(rival)
            }
        }
    }

    private func createTestCharacter(
        name: String,
        role: CharacterRole,
        disposition: Int,
        positionIndex: Int,
        context: ModelContext
    ) -> GameCharacter {
        let character = GameCharacter(
            templateId: "test_\(UUID().uuidString.prefix(8))",
            name: name,
            title: role == .ally ? "Trusted Colleague" : "Political Competitor",
            role: role
        )
        character.disposition = disposition
        character.positionIndex = positionIndex
        character.personalityAmbitious = Int.random(in: 40...80)
        character.personalityParanoid = Int.random(in: 30...70)
        character.personalityRuthless = Int.random(in: 30...70)
        character.personalityCompetent = Int.random(in: 40...80)
        character.personalityLoyal = Int.random(in: 30...70)
        character.personalityCorrupt = Int.random(in: 20...60)
        character.factionId = ["youth_league", "reformists", "old_guard"].randomElement()

        context.insert(character)
        return character
    }

    // MARK: - NPC Overrides

    private func applyNPCOverrides(_ overrides: [TestNPCOverride], to game: Game) {
        for override in overrides {
            guard let character = game.characters.first(where: { $0.templateId == override.templateId }) else {
                scenarioLogger.warning("Could not find character with templateId: \(override.templateId)")
                continue
            }

            if let v = override.disposition { character.disposition = v }
            if let v = override.isPatron { character.isPatron = v }
            if let v = override.isRival { character.isRival = v }
            if let v = override.status { character.status = v }
            if let v = override.positionIndex { character.positionIndex = v }
            if let v = override.positionTrack { character.positionTrack = v }
            if let v = override.grudgeLevel { character.grudgeLevel = v }
            if let v = override.fearLevel { character.fearLevel = v }
            if let v = override.trustLevel { character.trustLevel = v }

            scenarioLogger.debug("Applied overrides to \(character.name)")
        }
    }

    // MARK: - Game Systems Initialization

    private func initializeGameSystems(game: Game, config: CampaignConfig, context: ModelContext) {
        // Create factions
        for factionConfig in config.factions {
            let faction = GameFaction(
                factionId: factionConfig.id,
                name: factionConfig.name,
                description: factionConfig.description
            )
            faction.power = factionConfig.startingPower
            faction.playerStanding = factionConfig.startingPlayerStanding
            context.insert(faction)
            faction.game = game
            game.factions.append(faction)
        }

        // Initialize laws
        let defaultLaws = Law.createDefaultLaws()
        for law in defaultLaws {
            context.insert(law)
            law.game = game
            game.laws.append(law)
        }

        // Initialize regions
        let defaultRegions = Region.createDefaultRegions()
        for region in defaultRegions {
            context.insert(region)
            region.game = game
            game.regions.append(region)
        }

        // Initialize foreign countries
        let defaultCountries = ForeignCountry.createDefaultCountries()
        for country in defaultCountries {
            context.insert(country)
            country.game = game
            game.foreignCountries.append(country)
        }

        // Initialize policies
        PolicyService.shared.initializePolicies(for: game)
        for slot in game.policySlots {
            context.insert(slot)
        }

        // Initialize position history
        PositionHistoryService.shared.initializePositionHistory(game: game, ladder: config.ladder)

        // Initialize NPC relationships
        CharacterAgencyService.shared.initializeNPCRelationships(game: game)

        // Initialize NPC behavior system
        CharacterAgencyService.shared.initializeBehaviorSystem(game: game)

        // Initialize Standing Committee
        let committee = StandingCommitteeService.shared.initializeCommittee(for: game)
        context.insert(committee)
        game.standingCommittee = committee

        // Generate initial agenda items
        InitialAgendaGenerator.shared.generateInitialAgenda(for: committee, game: game)

        // Add a start event
        let startEvent = GameEvent(
            turnNumber: 1,
            eventType: .gameStart,
            summary: "You began your political career. [TEST SCENARIO: \(game.turnNumber) turns simulated]"
        )
        startEvent.importance = 10
        context.insert(startEvent)
        startEvent.game = game
        game.events.append(startEvent)

        scenarioLogger.debug("Game systems initialized for test scenario")
    }
}

#endif
