//
//  GameEngine.swift
//  Nomenklatura
//
//  Core game logic: actions, promotions, win/lose conditions
//

import Foundation
import os.log

private let gameLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "GameEngine")

// MARK: - Game Engine

@MainActor
class GameEngine {
    static let shared = GameEngine()

    // MARK: - Personal Action Execution

    /// Execute a personal action and return the result
    func executeAction(_ action: PersonalAction, game: Game, ladder: [LadderPosition]) -> ActionResult {
        // Check if action is available
        let availability = action.isAvailable(game: game)
        guard availability.available else {
            return ActionResult(
                success: false,
                outcomeText: availability.reason ?? "This action is not available."
            )
        }

        // Check AP cost
        guard game.actionPoints >= action.costAP else {
            return ActionResult(
                success: false,
                outcomeText: "Not enough action points."
            )
        }

        // Check if action already used this turn
        guard !game.usedActionsThisTurn.contains(action.id) else {
            return ActionResult(
                success: false,
                outcomeText: "You have already performed this action this turn."
            )
        }

        // Deduct AP and track action as used
        game.actionPoints -= action.costAP
        game.usedActionsThisTurn.append(action.id)

        // Calculate risk of discovery
        let discoveryResult = calculateDiscovery(action: action, game: game)

        // Base effects (always apply)
        var statChanges = action.effects

        // If discovered, there are consequences
        var outcomeText = ""
        var newFlags: [String] = []
        let removedFlags: [String] = []

        if discoveryResult.wasDiscovered {
            // Discovery consequences based on action type
            let discoveryOutcome = handleDiscovery(action: action, game: game, discoveredBy: discoveryResult.discoveredBy)
            outcomeText = discoveryOutcome.text
            statChanges.merge(discoveryOutcome.additionalEffects) { _, new in new }
            newFlags = discoveryOutcome.newFlags
        } else {
            // Success - generate appropriate outcome text
            outcomeText = generateSuccessOutcome(action: action, game: game)

            // Some actions grant flags on success
            newFlags = getSuccessFlags(action: action)
        }

        // Apply stat changes
        for (key, value) in statChanges {
            game.applyStat(key, change: value)
        }

        // Try to spawn a network contact for network-building actions
        if !discoveryResult.wasDiscovered && action.category == .buildNetwork {
            if let newContact = NetworkContactSystem.shared.trySpawnContact(actionId: action.id, game: game) {
                game.characters.append(newContact)
            }
        }

        // Apply flags
        for flag in newFlags {
            if !game.flags.contains(flag) {
                game.flags.append(flag)
            }
        }
        for flag in removedFlags {
            game.flags.removeAll { $0 == flag }
        }

        // Log the event
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .personalAction,
            summary: discoveryResult.wasDiscovered ?
                "[DISCOVERED] \(action.title)" : action.title
        )
        event.importance = discoveryResult.wasDiscovered ? 8 : 5
        event.game = game
        game.events.append(event)

        return ActionResult(
            success: !discoveryResult.wasDiscovered,
            outcomeText: outcomeText,
            statChanges: statChanges,
            wasDiscovered: discoveryResult.wasDiscovered,
            discoveredBy: discoveryResult.discoveredBy,
            newFlags: newFlags,
            removedFlags: removedFlags
        )
    }

    private func calculateDiscovery(action: PersonalAction, game: Game) -> (wasDiscovered: Bool, discoveredBy: String?) {
        // Base discovery chance based on risk level
        var discoveryChance: Int
        switch action.riskLevel {
        case .low: discoveryChance = 5
        case .medium: discoveryChance = 15
        case .high: discoveryChance = 30
        }

        // Modifiers
        // High network reduces discovery chance
        if game.network >= 50 {
            discoveryChance -= 10
        } else if game.network < 20 {
            discoveryChance += 10
        }

        // High rival threat increases discovery (they're watching)
        if game.rivalThreat >= 70 {
            discoveryChance += 15
        } else if game.rivalThreat >= 50 {
            discoveryChance += 5
        }

        // Low patron favor means less protection
        if game.patronFavor < 30 {
            discoveryChance += 10
        }

        // Clamp
        discoveryChance = max(0, min(80, discoveryChance))

        // Roll
        let roll = Int.random(in: 1...100)
        let wasDiscovered = roll <= discoveryChance

        // Who discovered?
        var discoveredBy: String? = nil
        if wasDiscovered {
            // Usually the rival or security apparatus
            if let rival = game.primaryRival {
                discoveredBy = rival.name
            } else if let patron = game.patron, Int.random(in: 1...100) <= 30 {
                discoveredBy = patron.name
            } else {
                discoveredBy = "State Security"
            }
        }

        return (wasDiscovered, discoveredBy)
    }

    private func handleDiscovery(action: PersonalAction, game: Game, discoveredBy: String?) -> (text: String, additionalEffects: [String: Int], newFlags: [String]) {
        var text = ""
        var effects: [String: Int] = [:]
        var flags: [String] = []

        let discoverer = discoveredBy ?? "unknown parties"

        switch action.category {
        case .buildNetwork:
            text = "Your attempt to expand your network has been noticed by \(discoverer). They watch you more closely now."
            effects["rivalThreat"] = 10
            effects["patronFavor"] = -5

        case .undermineRivals:
            text = "\(discoverer) has uncovered your scheme. Your reputation for loyalty takes a significant hit, and your rivals know you're a threat."
            effects["rivalThreat"] = 20
            effects["patronFavor"] = -15
            effects["reputationLoyal"] = -15
            effects["reputationCunning"] = 5 // They know you play the game

        case .securePosition:
            text = "Your defensive maneuvers were noticed by \(discoverer). It raises questions about why you feel the need to protect yourself."
            effects["patronFavor"] = -10
            effects["rivalThreat"] = 5

        case .makeYourPlay:
            text = "\(discoverer) has exposed your power grab. This is a serious blow to your position. The Politburo questions your loyalty."
            effects["standing"] = -20
            effects["patronFavor"] = -25
            effects["rivalThreat"] = 25
            effects["reputationLoyal"] = -20
            flags.append("exposed_ambition")

        case .cultivateSuccessor:
            text = "\(discoverer) has noticed your succession preparations. They question whether you are planning to leave your position - or worse."
            effects["patronFavor"] = -15
            effects["rivalThreat"] = 15
            effects["reputationCunning"] = 5
        }

        return (text, effects, flags)
    }

    private func generateSuccessOutcome(action: PersonalAction, game: Game) -> String {
        // Generate contextual success text based on action
        switch action.id {
        case "plant_ally_security":
            return "A junior clerk in State Security now reports to you. The information may prove invaluable."
        case "cultivate_military":
            return "You've made friends among the officer corps. They appreciate someone who understands their concerns."
        case "gather_intel_rival":
            return "Your sources have uncovered interesting details about Sullivan's activities. His position may not be as strong as it appears."
        case "leak_failures":
            return "The press office received an anonymous tip about production shortfalls. Questions are being asked. Sullivan scrambles to explain."
        case "frame_conspiracy":
            return "Certain documents have found their way to the appropriate authorities. Sullivan will have difficult questions to answer."
        case "private_meeting_secretary":
            return "The General Secretary received you warmly. 'It's good to know who our reliable comrades are,' he said."
        case "public_praise_patron":
            return "Your speech praising Wallace was well-received. He nods approvingly when your eyes meet. Some colleagues whisper about sycophancy."
        case "prepare_dossier":
            return "You've compiled records of your achievements and loyalty. Should accusations come, you'll be prepared."
        case "propose_promotion":
            return "Your candidacy for the vacant position has been formally submitted. Now the waiting begins."
        case "challenge_rival":
            return "Your accusations ring through the chamber. Sullivan's face drains of color. The evidence is damning."
        case "begin_coup":
            return "Certain conversations have been had. Certain assurances given. The pieces are moving into position."
        default:
            return "Your political maneuvering proceeds according to plan."
        }
    }

    private func getSuccessFlags(action: PersonalAction) -> [String] {
        switch action.id {
        case "gather_intel_rival":
            return ["sullivan_weakness_known"]
        case "begin_coup":
            return ["coup_preparations_begun"]
        case "frame_conspiracy":
            return ["sullivan_under_investigation"]
        default:
            return []
        }
    }

    // MARK: - Promotion Logic

    /// Default minimum turns in a position before promotion (if not specified in config)
    /// With 2 weeks per turn, 6 turns = ~3 months minimum in each position
    private let defaultMinimumTurnsInPosition = 6

    /// Check if player can be promoted and return available positions
    func checkPromotionEligibility(game: Game, ladder: [LadderPosition]) -> PromotionCheck {
        let currentPosition = game.currentPositionIndex
        let nextPositionIndex = currentPosition + 1

        // Already at top
        guard nextPositionIndex < ladder.count else {
            return PromotionCheck(
                canPromote: false,
                nextPosition: nil,
                reason: "You have reached the pinnacle of power."
            )
        }

        let nextPosition = ladder[nextPositionIndex]
        let currentLadderPosition = ladder[safe: currentPosition]

        // Check minimum turns in current position
        let minimumTurns = currentLadderPosition?.minimumTurnsInPosition ?? defaultMinimumTurnsInPosition
        let turnsInPosition = game.turnsInCurrentPosition

        if turnsInPosition < minimumTurns {
            let turnsRemaining = minimumTurns - turnsInPosition
            let weeksRemaining = turnsRemaining * 2
            return PromotionCheck(
                canPromote: false,
                nextPosition: nextPosition,
                reason: "You must prove yourself in your current role. \(turnsRemaining) more turns (~\(weeksRemaining) weeks) required."
            )
        }

        // Check standing requirement
        if game.standing < nextPosition.requiredStanding {
            return PromotionCheck(
                canPromote: false,
                nextPosition: nextPosition,
                reason: "Your standing is too low. You need \(nextPosition.requiredStanding) standing."
            )
        }

        // Check patron favor if required
        if let requiredFavor = nextPosition.requiredPatronFavor, game.patronFavor < requiredFavor {
            return PromotionCheck(
                canPromote: false,
                nextPosition: nextPosition,
                reason: "Your patron does not favor you enough. You need \(requiredFavor) patron favor."
            )
        }

        // Check network if required
        if let requiredNetwork = nextPosition.requiredNetwork, game.network < requiredNetwork {
            return PromotionCheck(
                canPromote: false,
                nextPosition: nextPosition,
                reason: "Your network is insufficient. You need \(requiredNetwork) network."
            )
        }

        // Check faction support if required
        if let factionRequirements = nextPosition.requiredFactionSupport {
            for (factionId, requiredStanding) in factionRequirements {
                if let faction = game.factions.first(where: { $0.factionId == factionId }) {
                    if faction.playerStanding < requiredStanding {
                        return PromotionCheck(
                            canPromote: false,
                            nextPosition: nextPosition,
                            reason: "The \(faction.name) does not support you. You need \(requiredStanding) standing with them."
                        )
                    }
                }
            }
        }

        // Check for vacancy (simplified: check if max holders not exceeded)
        let holdersAtPosition = game.characters.filter {
            $0.positionIndex == nextPositionIndex && $0.isAlive
        }.count + (currentPosition == nextPositionIndex - 1 ? 1 : 0)

        if holdersAtPosition >= nextPosition.maxHolders {
            return PromotionCheck(
                canPromote: false,
                nextPosition: nextPosition,
                reason: "There is no vacancy at this level. Someone must fall for you to rise."
            )
        }

        // Check rival threat - if too high, rival blocks promotion
        if game.rivalThreat >= 80 {
            return PromotionCheck(
                canPromote: false,
                nextPosition: nextPosition,
                reason: "Your rival's influence blocks your advancement. Deal with them first."
            )
        }

        // All requirements met!
        return PromotionCheck(
            canPromote: true,
            nextPosition: nextPosition,
            reason: "You are eligible for promotion to \(nextPosition.title)."
        )
    }

    /// Execute a promotion
    func executePromotion(game: Game, to position: LadderPosition) {
        // Track position history - record the promotion
        PositionHistoryService.shared.recordPlayerPromotion(
            game: game,
            toPositionIndex: position.index,
            positionTitle: position.title,
            track: position.track
        )

        game.currentPositionIndex = position.index
        game.currentTrack = position.track.rawValue  // Update career track when branching
        game.currentExpandedTrack = position.expandedTrack.rawValue  // Update specialized bureau track
        game.turnsInCurrentPosition = 0

        // If moving to a specialized track, add affinity and commit
        if position.expandedTrack != .shared {
            game.addTrackAffinity(
                track: position.expandedTrack,
                amount: 10,
                source: .positionHeld,
                description: "Promoted to \(position.title)"
            )

            // Commit to track when accepting a specialized position
            if game.currentTrackCommitment != .committed {
                game.commitToTrack(position.expandedTrack)
            }
        }

        // Check for apex position
        if position.isApexPosition {
            game.recordApexPosition(track: position.expandedTrack)
        }

        // Log event
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .promotion,
            summary: "Promoted to \(position.title)"
        )
        event.importance = 10
        event.game = game
        game.events.append(event)

        // Promotion affects stats
        game.applyStat("standing", change: 10)
        game.applyStat("rivalThreat", change: 15) // More visible = more enemies

        // If promoted to top position (General Secretary), game mode changes
        if position.index == 8 {
            game.flags.append("reached_general_secretary")
            game.turnsAsGeneralSecretary = 0
            game.variables["turns_as_leader"] = "0"
        }
    }

    // MARK: - Win/Lose Condition Checks

    /// Check all end-game conditions and return result
    func checkGameEndConditions(game: Game, ladder: [LadderPosition]) -> GameEndCheck {
        // Check loss conditions first
        if let lossResult = checkLossConditions(game: game) {
            return lossResult
        }

        // Check win conditions
        if let winResult = checkWinConditions(game: game, ladder: ladder) {
            return winResult
        }

        // Game continues
        return GameEndCheck(gameOver: false, result: nil, reason: nil)
    }

    private func checkLossConditions(game: Game) -> GameEndCheck? {
        // LOSS: Patron turns on you (purge)
        if game.patronFavor < 15 {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "Your patron has turned against you. Wallace's men arrive at dawn. Your political career—and perhaps your life—is over."
            )
        }

        // LOSS: Standing collapses (dismissed)
        if game.standing < 5 {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "Your standing has collapsed. You are quietly removed from all positions and reassigned to a minor posting in the Eastern Territories. Your political career is finished."
            )
        }

        // LOSS: Rival threat maxed (rival coup)
        if game.rivalThreat >= 95 {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "Your rivals have outmaneuvered you completely. At the next Politburo meeting, you find yourself facing accusations of counter-revolutionary activity. The vote is unanimous."
            )
        }

        // LOSS: Multiple critical stats (state collapse)
        let criticalStats = [
            game.stability,
            game.popularSupport,
            game.foodSupply
        ]
        let criticalCount = criticalStats.filter { $0 < 15 }.count
        if criticalCount >= 2 {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "The state crumbles around you. Riots in the streets, empty shelves in the stores, and the army grows restless. In the chaos, you are swept away with the old regime."
            )
        }

        // LOSS: Military coup (if player at top and military loyalty too low)
        if game.flags.contains("reached_general_secretary") && game.militaryLoyalty < 20 {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "Tanks roll through the capital at dawn. Marshal Anderson appears on state television. 'The people's patience has limits,' he announces. Your reign is over."
            )
        }

        // LOSS: Popular revolution (if player at top and popular support too low)
        if game.flags.contains("reached_general_secretary") && game.popularSupport < 15 {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "The crowds fill the streets. 'Bread! Freedom! Down with the tyrant!' they chant. The security forces refuse to fire on their own people. The palace falls."
            )
        }

        return nil
    }

    private func checkWinConditions(game: Game, ladder: [LadderPosition]) -> GameEndCheck? {
        // WIN: Survival Victory - reach top and survive 20 turns
        if game.flags.contains("reached_general_secretary") {
            let turnsAsLeader = Int(game.variables["turns_as_leader"] ?? "0") ?? 0
            if turnsAsLeader >= 20 {
                return GameEndCheck(
                    gameOver: true,
                    result: .won,
                    reason: "Twenty years of power. Your portrait hangs in every office. Your name is spoken with reverence—and fear. You have outlasted them all. History will remember you as... well, that depends on who writes it."
                )
            }
        }

        // WIN: Legacy Victory - high stats while at top
        if game.flags.contains("reached_general_secretary") {
            if game.stability >= 80 &&
               game.popularSupport >= 70 &&
               game.industrialOutput >= 70 &&
               game.internationalStanding >= 70 {
                return GameEndCheck(
                    gameOver: true,
                    result: .won,
                    reason: "Against all odds, you have built something that endures. The factories hum, the people have bread, and the world respects your nation. History may call this a golden age—and you its architect."
                )
            }
        }

        return nil
    }

    /// Call this at end of each turn to update game state
    func endTurnUpdates(game: Game, ladder: [LadderPosition]) {
        // Increment turns as leader if applicable
        if game.flags.contains("reached_general_secretary") {
            let current = Int(game.variables["turns_as_leader"] ?? "0") ?? 0
            game.variables["turns_as_leader"] = "\(current + 1)"
        }

        // Natural stat drift
        applyStatDrift(game: game)

        // Character actions (rivals plotting, etc.)
        simulateNPCActions(game: game)

        // Random events that affect stats
        applyRandomEvents(game: game)

        // World simulation - dynamic world events (RDR2-style living world)
        simulateWorldEvents(game: game)

        // NPC Behavior System - process decay, detection, and updates
        processNPCBehaviorSystem(game: game)

        // Political AI - NPC policy proposals and voting
        processPoliticalAI(game: game)

        // Position offers - check expirations and generate new offers
        processPositionOffers(game: game)

        // International dynamics - foreign relations, treaties, espionage, world tension
        processInternationalDynamics(game: game)

        // Regional dynamics - stability, secession progress, territorial integrity
        processRegionalDynamics(game: game)

        // Macro economic processing - GDP, inflation, unemployment, trade balance
        processEconomicSystem(game: game)

        // Intelligence leaks - generate secret intel based on Network stat
        processIntelligenceLeaks(game: game)

        // Record stat history for sparklines (at end of turn after all processing)
        game.recordAllStatHistory()
    }

    /// Process intelligence leaks based on player's Network stat
    private func processIntelligenceLeaks(game: Game) {
        // Only check every other turn to avoid spam
        guard game.turnNumber % 2 == 0 else { return }

        if let leak = IntelligenceLeakService.shared.tryGenerateLeakEvent(for: game) {
            gameLogger.info("Generated intelligence leak: \(leak.title)")
            IntelligenceLeakService.shared.processLeakToJournal(leak: leak, game: game)
        }
    }

    /// Process macro economic indicators each turn
    private func processEconomicSystem(game: Game) {
        gameLogger.info("Processing macro economy for turn \(game.turnNumber)")

        // Process PSRA's macro economy (GDP, inflation, unemployment)
        EconomyService.shared.processEconomy(game: game)

        // Process foreign country economies
        EconomyService.shared.processForeignEconomies(game: game)

        gameLogger.info("Economic indicators - GDP: \(game.gdpIndex), Inflation: \(game.inflationRate)%, Unemployment: \(game.unemploymentRate)%")
    }

    /// Process international dynamics - foreign relations, treaties, espionage
    private func processInternationalDynamics(game: Game) {
        gameLogger.info("Processing international dynamics for turn \(game.turnNumber)")

        // Process relationship drift, treaty effects, espionage, world tension
        InternationalEventService.shared.processTurn(game: game)

        // Generate and queue international crisis events
        let crisisEvents = InternationalEventService.shared.generateInternationalEvents(for: game)
        for crisis in crisisEvents {
            if let country = game.foreignCountries.first(where: { $0.countryId == crisis.countryId }) {
                let event = InternationalEventService.shared.createDynamicEvent(
                    from: crisis,
                    country: country,
                    currentTurn: game.turnNumber
                )
                game.queueDynamicEvent(event)
                gameLogger.info("Queued international crisis: \(crisis.headline)")
            }
        }

        // Log current world state
        let hostileCount = game.foreignCountries.filter { $0.diplomaticTension > 60 }.count
        gameLogger.info("International state - Hostile countries: \(hostileCount)")
    }

    /// Process regional dynamics - stability, secession, territorial integrity
    private func processRegionalDynamics(game: Game) {
        gameLogger.info("Processing regional dynamics for turn \(game.turnNumber)")

        // Process regional stability, secession progress, cascade effects
        RegionSecessionService.shared.processTurn(game: game)

        // Generate and queue regional crisis events
        let regionalEvents = RegionSecessionService.shared.generateRegionalEvents(for: game)
        for crisis in regionalEvents {
            if let region = game.regions.first(where: { $0.regionId == crisis.regionId }) {
                let event = RegionSecessionService.shared.createDynamicEvent(
                    from: crisis,
                    region: region,
                    currentTurn: game.turnNumber
                )
                game.queueDynamicEvent(event)
                gameLogger.info("Queued regional crisis: \(crisis.eventType.rawValue) in \(region.name)")
            }
        }

        // Log regional state
        let crisisRegions = game.regions.filter { $0.status.severity >= 2 }.count
        let secedingRegions = game.regions.filter { $0.status == .seceding || $0.status == .seceded }.count
        gameLogger.info("Regional state - Crisis regions: \(crisisRegions), Seceding: \(secedingRegions)")
    }

    /// Process position offers - expiration and generation
    private func processPositionOffers(game: Game) {
        gameLogger.info("Processing position offers for turn \(game.turnNumber)")
        PositionOfferService.shared.processTurn(game: game)

        // Check for pending offers that need to be presented as events
        let pendingOffers = game.positionOffers.filter { $0.status == .pending && !$0.hasBeenPresented }
        for offer in pendingOffers {
            // Create and queue the offer event
            let event = PositionOfferService.shared.createOfferEvent(for: offer, currentTurn: game.turnNumber)
            game.queueDynamicEvent(event)
            offer.hasBeenPresented = true
            gameLogger.info("Queued position offer event: \(offer.positionName)")
        }
    }

    /// Process NPC political activity - policy proposals, votes, decrees
    private func processPoliticalAI(game: Game) {
        gameLogger.info("Processing political AI for turn \(game.turnNumber)")

        // Initialize policy slots if not done
        if game.policySlots.isEmpty {
            PolicyService.shared.initializePolicies(for: game)
        }

        // Run political AI to process NPC political behavior
        let politicalEvents = PoliticalAIService.shared.processPoliticalActivity(game: game)

        // Convert to game events and add to game log
        for event in politicalEvents {
            let gameEvent = GameEvent(
                turnNumber: event.turn,
                eventType: .decision,
                summary: event.narrative
            )
            gameEvent.importance = event.eventType == .gsDecree ? 9 : 6
            gameEvent.game = game
            game.events.append(gameEvent)

            gameLogger.info("Political event: \(event.eventType.rawValue) - \(event.narrative)")
        }
    }

    /// Process NPC behavior system updates each turn
    private func processNPCBehaviorSystem(game: Game) {
        gameLogger.info("Processing NPC behavior system for turn \(game.turnNumber)")
        let agencyService = CharacterAgencyService.shared

        // Initialize NPC relationships if they don't exist (handles existing saves)
        if game.npcRelationships.isEmpty {
            agencyService.initializeNPCRelationships(game: game)
        }

        // Initialize behavior system for any new characters
        agencyService.initializeBehaviorSystem(game: game)

        // Process need decay for all active characters
        for character in game.characters where character.isActive {
            agencyService.processNeedDecay(character: character, game: game)
        }

        // Process memory system effects (decay, disposition updates, goal generation)
        MemoryIntegrationService.shared.processTurnMemoryEffects(game: game)

        // Process ambient activities for living world feel
        AmbientActivityService.shared.processAmbientActivities(game: game)

        // Process NPC relationship decay
        agencyService.processNPCRelationshipDecay(game: game)

        // Process spy detection (checks if any spies get caught)
        agencyService.processSpyDetection(game: game)
    }

    /// Simulate world events for the living world system
    private func simulateWorldEvents(game: Game) {
        // Run world simulation
        let worldEvents = WorldSimulationService.shared.simulateTurn(game: game)

        // Persist world events to game history for narrative coherence
        for event in worldEvents {
            game.recordWorldEvent(event)
        }

        // Generate briefing if events occurred
        if !worldEvents.isEmpty {
            _ = WorldSimulationService.shared.generateBriefing(
                events: worldEvents,
                turn: game.turnNumber
            )

            // Generate intelligence reports for high-level players
            if game.currentPositionIndex >= 6 {
                _ = WorldSimulationService.shared.generateIntelligenceReports(
                    events: worldEvents,
                    game: game
                )
            }
        }
    }

    private func applyStatDrift(game: Game) {
        // Stats naturally drift based on current conditions
        // Low stats tend to get worse (instability breeds instability)
        // High stats tend to decay (hard to maintain excellence)
        // Note: Treasury is NOT included here - it has its own economy system

        let driftStats = [
            ("stability", game.stability),
            ("popularSupport", game.popularSupport)
        ]

        for (key, value) in driftStats {
            var drift = 0
            if value < 25 {
                drift = -2 // Crisis situations spiral
            } else if value > 75 {
                drift = -1 // Hard to maintain excellence
            } else if value < 35 {
                drift = -1 // Moderate concern
            }

            if drift != 0 {
                game.applyStat(key, change: drift)
            }
        }
    }

    private func simulateNPCActions(game: Game) {
        // Rivals always scheming
        if let rival = game.primaryRival, rival.isAlive {
            // Rival threat naturally increases if not addressed
            let threatIncrease = Int.random(in: 1...3)
            game.applyStat("rivalThreat", change: threatIncrease)
        }

        // Patron favor decays only when neglected (no interaction in 3+ turns)
        // This removes the "maintenance treadmill" while still requiring engagement
        if game.isPatronNeglected && game.patronFavor > 30 {
            let favorDecay = BalanceConfig.patronFavorDecayPerTurn
            game.applyStat("patronFavor", change: -favorDecay)
        }

        // Check for character fate events
        checkCharacterFates(game: game)
    }

    private func applyRandomEvents(game: Game) {
        // Small random fluctuations to keep things dynamic
        let roll = Int.random(in: 1...100)

        if roll <= 10 {
            // Minor economic fluctuation
            let change = Int.random(in: -5...5)
            game.applyStat("treasury", change: change)
        } else if roll <= 20 {
            // International event
            let change = Int.random(in: -3...3)
            game.applyStat("internationalStanding", change: change)
        }
    }

    // MARK: - Character Fate System

    private func checkCharacterFates(game: Game) {
        // Check every turn after turn 5, with lower probabilities to maintain balance
        // This makes fates feel more responsive to player actions
        guard game.turnNumber > 5 else { return }

        let activeCharacters = game.characters.filter { $0.isAlive && !$0.isPatron }

        for character in activeCharacters {
            let fateRoll = Int.random(in: 1...100)

            // Rivals can be eliminated if rival threat is very low (you've won)
            // ~5% per turn (was 15% every 3 turns = same overall rate)
            if character.isRival && game.rivalThreat < 20 {
                if fateRoll <= 5 {
                    let fates: [CharacterStatus] = [.executed, .imprisoned, .exiled]
                    applyFate(to: character, fate: fates.randomElement()!, game: game)
                    continue
                }
            }

            // Low disposition characters are at risk during purges
            // ~3% per turn (was 10% every 3 turns)
            if character.disposition < 30 && game.stability < 40 {
                if fateRoll <= 3 {
                    let fates: [CharacterStatus] = [.detained, .disappeared, .imprisoned]
                    applyFate(to: character, fate: fates.randomElement()!, game: game)
                    continue
                }
            }

            // Random deaths/accidents (very rare, ~1% per turn)
            if fateRoll <= 1 {
                let fates: [CharacterStatus] = [.dead, .disappeared, .retired]
                let weights = [1, 2, 3] // Retirement most common, death least
                let fate = weightedRandom(fates, weights: weights)
                applyFate(to: character, fate: fate, game: game)
                continue
            }

            // Corrupt characters can get caught (~2% per turn)
            if character.personalityCorrupt > 70 && fateRoll <= 2 {
                applyFate(to: character, fate: .underInvestigation, game: game)
                continue
            }

            // Very old patrons can die naturally (~3% per turn after turn 20)
            if character.currentRole == .leader && game.turnNumber > 20 && fateRoll <= 3 {
                applyFate(to: character, fate: .dead, game: game)
            }
        }

        // Check if patron needs to die (very rare, destabilizing event)
        if let patron = game.patron, game.turnNumber > 15 {
            let patronDeathRoll = Int.random(in: 1...100)
            if patronDeathRoll <= 3 { // 3% chance after turn 15
                applyFate(to: patron, fate: .dead, game: game)
                // Losing patron is significant but not campaign-ending
                // Player must find a new patron but shouldn't be instantly doomed
                game.applyStat("patronFavor", change: -30)
                game.applyStat("standing", change: -15)
            }
        }
    }

    private func applyFate(to character: GameCharacter, fate: CharacterStatus, game: Game) {
        character.status = fate.rawValue
        character.statusChangedTurn = game.turnNumber

        // Invalidate patron/rival cache since status affects cache validity
        if character.isPatron || character.isRival {
            game.invalidateCharacterRoleCaches()
        }

        // Generate narrative using the death system
        let cause = fateToDeathCause(fate)
        let notification = CharacterDeathSystem.shared.generateDeathNotification(
            character: character,
            cause: cause,
            game: game
        )

        // Store the narrative on the character
        character.fateNarrative = notification.details
        character.statusDetails = notification.headline

        // Set return possibility for non-permanent fates
        switch fate {
        case .disappeared:
            character.canReturnFlag = true
            character.returnProbability = Int.random(in: 10...40)
            character.remainingInfluence = Int.random(in: 20...50)
        case .imprisoned, .exiled:
            character.canReturnFlag = true
            character.returnProbability = Int.random(in: 5...20)
            character.remainingInfluence = Int.random(in: 10...30)
        case .underInvestigation, .detained:
            character.canReturnFlag = true
            character.returnProbability = Int.random(in: 30...60)
        default:
            character.canReturnFlag = false
            character.returnProbability = 0
        }

        // Log the event
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .death,
            summary: "\(character.name): \(notification.headline)"
        )
        event.importance = notification.isSignificant ? 8 : 5
        event.game = game
        game.events.append(event)

        // Notify player of character fate change
        NotificationService.shared.notifyCharacterFate(
            name: character.name,
            fate: fate.displayText,
            turn: game.turnNumber
        )
    }

    private func fateToDeathCause(_ fate: CharacterStatus) -> DeathCause {
        switch fate {
        case .dead: return .naturalCauses
        case .executed: return .executed
        case .disappeared: return .disappeared
        case .imprisoned, .detained: return .arrested
        case .exiled: return .exiled
        case .underInvestigation: return .arrested
        case .retired: return .naturalCauses
        case .active, .rehabilitated: return .naturalCauses
        }
    }

    private func weightedRandom<T>(_ items: [T], weights: [Int]) -> T {
        // Guard against empty arrays or zero total weight to prevent crash
        guard !items.isEmpty else {
            fatalError("weightedRandom called with empty items array")
        }

        let totalWeight = weights.reduce(0, +)

        // If all weights are zero, return first item as fallback
        guard totalWeight > 0 else {
            return items[0]
        }

        var random = Int.random(in: 0..<totalWeight)

        for (index, weight) in weights.enumerated() {
            random -= weight
            if random < 0 {
                return items[index]
            }
        }
        return items[0]
    }
}

// MARK: - Supporting Types

struct PromotionCheck {
    var canPromote: Bool
    var nextPosition: LadderPosition?
    var reason: String
}

struct GameEndCheck {
    var gameOver: Bool
    var result: GameStatus?
    var reason: String?
}

// MARK: - Assassination Risk System

extension GameEngine {

    /// Check for assassination attempts against player and NPCs
    func checkAssassinationRisks(game: Game) -> DynamicEvent? {
        // Check player assassination risk first
        if let playerEvent = checkPlayerAssassinationRisk(game: game) {
            return playerEvent
        }

        // Check NPC-to-NPC assassinations (rare)
        if let npcEvent = checkNPCAssassinationRisk(game: game) {
            return npcEvent
        }

        return nil
    }

    /// Calculate player's assassination risk
    private func checkPlayerAssassinationRisk(game: Game) -> DynamicEvent? {
        // Only check occasionally
        guard game.turnNumber > 5 && game.turnNumber % 3 == 0 else { return nil }

        let riskScore = calculateAssassinationRisk(game: game)

        // Threshold: if risk > 60, assassination attempt possible (10% per check)
        guard riskScore > 60 else { return nil }

        let attemptChance = Double(riskScore - 50) / 500.0 // 2-10% chance
        guard Double.random(in: 0...1) < attemptChance else { return nil }

        // Assassination attempt!
        return generateAssassinationAttempt(game: game, riskScore: riskScore)
    }

    /// Calculate assassination risk score for player
    func calculateAssassinationRisk(game: Game) -> Int {
        var riskScore = 0

        // Enemies contribute to risk
        if let rival = game.primaryRival, rival.isActive {
            // Rival grudge and ruthlessness
            riskScore += rival.grudgeLevel / 2
            riskScore += rival.personalityRuthless / 4
        }

        // Count other hostile NPCs
        let hostileCount = game.characters.filter {
            $0.isActive && $0.disposition < -50 && $0.personalityRuthless > 50
        }.count
        riskScore += hostileCount * 10

        // Protection factors (reduce risk)
        riskScore -= game.network / 2  // Network provides protection
        riskScore -= game.patronFavor / 3  // Patron protection

        // Position affects risk
        if game.currentPositionIndex >= 6 {
            riskScore += 20  // High value target
        }

        // Old Guard faction standing reduces risk (they control security services)
        if let oldGuardFaction = game.factions.first(where: { $0.factionId == "old_guard" }) {
            riskScore -= oldGuardFaction.playerStanding / 3
        }

        // Low stability = chaotic environment = more risk
        if game.stability < 40 {
            riskScore += (40 - game.stability) / 2
        }

        return max(0, min(100, riskScore))
    }

    /// Generate assassination attempt event
    private func generateAssassinationAttempt(game: Game, riskScore: Int) -> DynamicEvent {
        // Determine method
        let method = AssassinationMethod.allCases.randomElement()!

        // Calculate survival
        let survivalChance = calculateSurvivalChance(game: game, method: method)
        let survived = Double.random(in: 0...1) < survivalChance

        let (title, text, responses) = generateAssassinationText(
            method: method,
            survived: survived,
            game: game
        )

        return DynamicEvent(
            eventType: .urgentInterruption,
            priority: .urgent,
            title: title,
            briefText: text,
            initiatingCharacterId: game.primaryRival?.id,
            initiatingCharacterName: survived ? nil : "Unknown Assailant",
            turnGenerated: game.turnNumber,
            isUrgent: true,
            responseOptions: responses,
            iconName: method.iconName,
            accentColor: "stampRed"
        )
    }

    /// Calculate survival chance
    private func calculateSurvivalChance(game: Game, method: AssassinationMethod) -> Double {
        var chance = 0.5  // Base 50% survival

        // Network provides protection
        if game.network > 50 { chance += 0.15 }
        if game.network > 75 { chance += 0.10 }

        // Old Guard faction alliance (they control security services)
        if let oldGuardFaction = game.factions.first(where: { $0.factionId == "old_guard" }) {
            if oldGuardFaction.playerStanding > 60 { chance += 0.15 }
        }

        // Method-specific modifiers
        switch method {
        case .poison:
            chance -= 0.10  // Hard to detect, often too late when symptoms appear
        case .accident:
            chance += 0.05  // More variables, witnesses, things that can go wrong
        case .directAttack:
            chance += 0.10  // More defensive options, bodyguards can intervene
        case .medicatedSleep:
            chance -= 0.15  // Very hard to survive - victim is unconscious and defenseless
        case .windowFall:
            chance += 0.08  // Can grab ledges, awnings, or survive the fall with injuries
        case .foodPoisoning:
            chance -= 0.05  // Similar to poison but slightly easier to detect (shared meals, tasters)
        }

        // Paranoid players are more vigilant (simulate via rival threat awareness)
        if game.rivalThreat > 70 { chance += 0.10 }

        return min(0.90, max(0.20, chance))
    }

    /// Generate assassination attempt text
    private func generateAssassinationText(method: AssassinationMethod, survived: Bool, game: Game) -> (title: String, text: String, responses: [EventResponse]) {
        if survived {
            let (title, text) = method.survivedText
            let responses = [
                EventResponse(
                    id: "investigate",
                    text: "Launch investigation into the attempt",
                    shortText: "Investigate",
                    effects: ["rivalThreat": -10, "network": -5]
                ),
                EventResponse(
                    id: "retaliate",
                    text: "Retaliate against suspected enemies",
                    shortText: "Retaliate",
                    effects: ["reputationRuthless": 10, "rivalThreat": -20],
                    riskLevel: .high
                ),
                EventResponse(
                    id: "quietly",
                    text: "Handle this quietly - show no weakness",
                    shortText: "Stay Quiet",
                    effects: [:]
                )
            ]
            return (title, text, responses)
        } else {
            // Player dies - this will trigger game over
            let (title, text) = method.deathText
            let responses = [
                EventResponse(
                    id: "dead",
                    text: "Your story ends here",
                    shortText: "Accept Fate",
                    effects: ["standing": -100]  // Triggers game over
                )
            ]
            return (title, text, responses)
        }
    }

    /// Check for NPC-to-NPC assassinations
    private func checkNPCAssassinationRisk(game: Game) -> DynamicEvent? {
        // Very rare event
        guard Double.random(in: 0...1) < 0.02 else { return nil }

        // Find ruthless NPCs with enemies
        let ruthlessNPCs = game.characters.filter {
            $0.isActive && $0.personalityRuthless > 70 && !$0.isPatron
        }

        guard let assassin = ruthlessNPCs.randomElement() else { return nil }

        // Find potential victims (NPCs the assassin hates)
        let potentialVictims = game.characters.filter { target in
            guard target.id != assassin.id && target.isActive else { return false }
            // Check if assassin has grudge against target
            if let relationship = game.npcRelationships.first(where: {
                $0.sourceCharacterId == assassin.templateId && $0.targetCharacterId == target.templateId
            }) {
                return relationship.grudgeLevel > 50 || relationship.isRival
            }
            return false
        }

        guard let victim = potentialVictims.randomElement() else { return nil }

        // 60% chance the attempt succeeds
        let succeeded = Double.random(in: 0...1) < 0.6

        if succeeded {
            // Victim dies
            applyFate(to: victim, fate: .dead, game: game)
            victim.fateNarrative = "Died under mysterious circumstances. Foul play suspected."
        }

        // Generate event for player awareness
        let title = succeeded ? "Death in the Apparatus" : "Rumors of an Attempt"
        let text = succeeded
            ? "\(victim.name) has died under mysterious circumstances. Official cause: \"heart failure.\" Your sources suggest otherwise.\n\n\(assassin.name)'s name is whispered in connection, though nothing can be proven."
            : "Whispers reach you of an attempt on \(victim.name)'s life. They survived, but are shaken. \(assassin.name) is rumored to be involved."

        return DynamicEvent(
            eventType: .networkIntel,
            priority: .elevated,
            title: title,
            briefText: text,
            initiatingCharacterId: assassin.id,
            initiatingCharacterName: assassin.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "note", text: "Note this information", shortText: "Note", effects: [:]),
                EventResponse(id: "investigate", text: "Have your network investigate", shortText: "Investigate", effects: ["network": -3])
            ],
            iconName: "exclamationmark.triangle.fill",
            accentColor: "stampRed"
        )
    }
}

// MARK: - Assassination Types

enum AssassinationMethod: String, CaseIterable {
    case poison           // Subtle, 60% success - classic method
    case accident         // "Car accident", plausible deniability, 50% success
    case directAttack     // Bold, 40% success
    case medicatedSleep   // "Heart attack in sleep" - very subtle
    case windowFall       // "Defenestration" - sends a message
    case foodPoisoning    // Canteen/banquet, more deniable than poison

    var iconName: String {
        switch self {
        case .poison: return "drop.fill"
        case .accident: return "car.fill"
        case .directAttack: return "bolt.fill"
        case .medicatedSleep: return "bed.double.fill"
        case .windowFall: return "arrow.down.square.fill"
        case .foodPoisoning: return "fork.knife"
        }
    }

    var baseSurvivalChance: Double {
        switch self {
        case .poison: return 0.40
        case .accident: return 0.50
        case .directAttack: return 0.60
        case .medicatedSleep: return 0.30
        case .windowFall: return 0.25
        case .foodPoisoning: return 0.55
        }
    }

    var survivedText: (title: String, text: String) {
        switch self {
        case .poison:
            let variants = [
                (
                    "Poisoning Attempt",
                    "You notice something wrong with your tea - a faint bitterness, an unusual film. Training from your early security days saves your life.\n\nSomeone in your household has been turned. But who? And by whom?"
                ),
                (
                    "The Tainted Glass",
                    "The vodka has an aftertaste. You've drunk enough of it over the years to know. Your stomach heaves as you force yourself to vomit.\n\nThe doctors say you ingested a lethal dose - but not quite enough. Your enemies miscalculated."
                )
            ]
            return variants.randomElement()!

        case .accident:
            let variants = [
                (
                    "\"Accident\" Averted",
                    "Your driver's reflexes save you as the truck runs a red light. Later inspection reveals the brakes on your official car had been tampered with.\n\nThis was no accident. Someone wants you dead."
                ),
                (
                    "The Failed Collision",
                    "The ZiL swerves at the last moment as the military truck bears down on you. Your chauffeur - a man you've trusted for years - is pale and shaking.\n\n\"They tried to box us in, Comrade. It was deliberate.\""
                )
            ]
            return variants.randomElement()!

        case .directAttack:
            let variants = [
                (
                    "Attack Survived",
                    "The shot misses by inches. Your security detail tackles the assailant, but he takes a cyanide pill before he can be questioned.\n\nProfessional work. State-trained, by the look of it. This attack has official fingerprints."
                ),
                (
                    "The Missed Shot",
                    "Glass shatters. Your bodyguard throws himself in front of you as you're bundled into the car. He'll live - barely.\n\nThe shooter had a clear line of sight. Someone told them where you'd be."
                )
            ]
            return variants.randomElement()!

        case .medicatedSleep:
            return (
                "A Night Terror",
                "You wake gasping, heart racing, drenched in sweat. The doctor you summoned finds elevated traces of cardiac medication in your system - far above any therapeutic dose.\n\nSomeone has access to your bedroom. The thought keeps you awake for weeks."
            )

        case .windowFall:
            return (
                "The Ledge",
                "Strong hands seize you from behind. For one terrible moment you teeter on the balcony edge, five floors above the courtyard.\n\nYour own training saves you - an elbow strike, a twist. The would-be killer falls instead. His body makes no sound that reaches your ears."
            )

        case .foodPoisoning:
            return (
                "The Banquet",
                "Halfway through the ministry reception, your stomach cramps violently. You excuse yourself just in time.\n\nLater, you learn three others were taken ill. But only your portion had the concentrated dose. The chef has disappeared."
            )
        }
    }

    var deathText: (title: String, text: String) {
        switch self {
        case .poison:
            let variants = [
                (
                    "The Final Toast",
                    "The tea tastes bitter. By the time you realize something is wrong, it's too late. The room spins.\n\n\"Heart failure,\" the official report will say. History will remember a different story - if anyone dares write it."
                ),
                (
                    "The Last Drink",
                    "Your hand trembles as you set down the glass. The numbness starts in your fingers, spreads to your arms, your chest.\n\nThe last face you see is your aide's - expressionless, watching. Waiting. He's been one of them all along."
                )
            ]
            return variants.randomElement()!

        case .accident:
            let variants = [
                (
                    "A Fatal \"Accident\"",
                    "The truck comes out of nowhere. The last thing you see is the driver's cold, professional eyes.\n\n\"Tragic accident,\" the newspapers will report. Your family will never know the truth."
                ),
                (
                    "The Crash",
                    "The ZiL's brakes fail on the mountain road. Time slows as the car breaks through the barrier.\n\nThe People's Voice will report a tragic accident. Your successor has already been chosen."
                )
            ]
            return variants.randomElement()!

        case .directAttack:
            let variants = [
                (
                    "End of the Line",
                    "The shot rings out across the plaza. You never hear the second one.\n\nThey'll say it was a lone madman. But you know - knew - that in this world, there are no lone madmen."
                ),
                (
                    "The Palace Steps",
                    "You see the gun barrel rising. You see the flash. Then nothing.\n\nThe assassin will be killed 'resisting arrest'. The investigation will conclude quickly. The truth will be buried with you."
                )
            ]
            return variants.randomElement()!

        case .medicatedSleep:
            return (
                "The Endless Sleep",
                "You drift off in your study, tired from another long session. The injected sedative ensures you don't feel the cardiac medication stopping your heart.\n\n\"Died peacefully in his sleep,\" they will say. \"The strain of office.\""
            )

        case .windowFall:
            return (
                "Defenestration",
                "Strong hands grip your shoulders. A moment of weightlessness. The cobblestones rush up.\n\n\"Suicide,\" the report will read. \"The pressures of investigation.\" Your enemies have sent a very clear message to anyone else who might oppose them."
            )

        case .foodPoisoning:
            return (
                "The Last Supper",
                "The banquet seems endless. By the time the cramping starts, it's too late. You slump forward into your soup while conversations continue around you.\n\n\"Food poisoning,\" the official verdict. \"Unfortunate contamination.\" The kitchens will be blamed. The real culprit will be promoted."
            )
        }
    }
}

// MARK: - Assassination Warning Signs

extension GameEngine {
    /// Generate warning events that foreshadow potential assassination attempts
    func checkForAssassinationWarnings(game: Game) -> DynamicEvent? {
        let riskScore = calculateAssassinationRisk(game: game)

        // Only generate warnings at moderate-high risk
        guard riskScore > 40, riskScore < 70 else { return nil }

        // Small chance per turn at this risk level
        guard Double.random(in: 0...1) < 0.05 else { return nil }

        let warningTypes: [(title: String, text: String, effects: [String: Int])] = [
            (
                "Suspicious Behavior",
                "Your security chief reports that a member of your household staff has been observed meeting with unknown individuals. The meetings appear clandestine in nature.\n\nIt could be nothing - a romantic affair, perhaps. Or something far more sinister.",
                ["network": -3]
            ),
            (
                "The Missing Dossier",
                "A classified file on your daily movements has disappeared from the archives. Your chief of security cannot explain how it was accessed.\n\nSomeone is studying your routine.",
                ["rivalThreat": 5]
            ),
            (
                "Whispers in the Corridor",
                "Your informants report hushed conversations that stop when you approach. Meaningful glances exchanged between colleagues.\n\nIt may be nothing. Or it may be everything.",
                [:]
            ),
            (
                "The Reluctant Taster",
                "Your food taster has requested transfer to another position. When pressed, he refuses to explain.\n\n\"Some things, Comrade, it is better not to know,\" he says, and will say no more.",
                ["network": -5]
            ),
            (
                "Change in the Guard",
                "Several members of your security detail have been suddenly reassigned without your approval. The replacements are unknown to you.\n\nYour patron claims it's routine rotation. His eyes suggest otherwise.",
                ["patronFavor": -5]
            )
        ]

        let warning = warningTypes.randomElement()!

        return DynamicEvent(
            eventType: .ambientTension,
            priority: .normal,
            title: warning.title,
            briefText: warning.text,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "investigate_warning",
                    text: "Launch a discreet investigation",
                    shortText: "Investigate",
                    effects: ["network": -5, "rivalThreat": -10],
                    riskLevel: .medium,
                    followUpHint: "Knowledge is protection."
                ),
                EventResponse(
                    id: "increase_security",
                    text: "Increase personal security measures",
                    shortText: "More Guards",
                    effects: ["treasury": -3],
                    riskLevel: .low,
                    followUpHint: "Better safe than dead."
                ),
                EventResponse(
                    id: "ignore_warning",
                    text: "You cannot show fear",
                    shortText: "Ignore",
                    effects: [:],
                    riskLevel: .high,
                    followUpHint: "Courage - or foolishness?"
                )
            ],
            iconName: "exclamationmark.shield.fill"
        )
    }
}
