//
//  GameEngine.swift
//  Nomenklatura
//
//  Core game logic: actions, promotions, win/lose conditions
//

import Foundation
import SwiftData
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

        // Handle special action side effects (only on success)
        if !discoveryResult.wasDiscovered {
            switch action.id {
            case "abolish_term_limits":
                game.termLimitsAbolished = true
            default:
                break
            }

            // Apply track affinity for personal action category
            let actionTrack: ExpandedCareerTrack? = {
                switch action.category {
                case .purgeEnemies: return .securityServices
                case .undermineRivals: return .securityServices
                case .controlInformation: return .partyApparatus
                case .securePosition: return .partyApparatus
                case .cultivateSuccessor: return .partyApparatus
                case .consolidatePower: return .stateMinistry
                case .buildNetwork, .makeYourPlay: return nil
                }
            }()
            if let actionTrack = actionTrack {
                game.addTrackAffinity(
                    track: actionTrack,
                    amount: 2,
                    source: .personalAction,
                    description: "Personal action: \(action.title)"
                )
            }
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

        case .purgeEnemies:
            text = "\(discoverer) has learned of your purge preparations. Potential targets are now on high alert and building counter-alliances."
            effects["rivalThreat"] = 20
            effects["eliteLoyalty"] = -15
            effects["reputationRuthless"] = 10

        case .controlInformation:
            text = "\(discoverer) has exposed your propaganda manipulation. Your credibility with the press and public takes a severe hit."
            effects["popularSupport"] = -10
            effects["reputationCunning"] = 5
            effects["internationalStanding"] = -5

        case .consolidatePower:
            text = "\(discoverer) has uncovered your power consolidation schemes. The Standing Committee questions your intentions."
            effects["eliteLoyalty"] = -20
            effects["rivalThreat"] = 15
            effects["standing"] = -10
            flags.append("exposed_consolidation")
        }

        return (text, effects, flags)
    }

    private func generateSuccessOutcome(action: PersonalAction, game: Game) -> String {
        // Generate contextual success text based on action
        switch action.id {
        case "plant_ally_security":
            return "A trusted operative within State Security now reports directly to your office. The intelligence may prove invaluable."
        case "cultivate_military":
            return "The officer corps appreciates a General Secretary who understands their concerns. Loyalty deepens."
        case "gather_intel_rival":
            return "Your intelligence network has uncovered details about your rival's activities. Their position may not be as strong as it appears."
        case "leak_failures":
            return "The press office received materials about certain production shortfalls. Questions are being asked. Your rival scrambles to explain."
        case "frame_conspiracy":
            return "Certain documents have found their way to the appropriate authorities. Difficult questions will follow."
        case "private_meeting_secretary":
            return "Your private audience with your key ally went well. The alliance remains strong."
        case "public_praise_patron":
            return "Your speech acknowledging your ally's contributions was well-received. Their faction rallies behind you."
        case "prepare_dossier":
            return "You've compiled intelligence on potential threats to your leadership. Should a challenge come, you'll be prepared."
        case "propose_promotion":
            return "Your chosen loyalist has been installed in the key position. The apparatus responds to your will."
        case "challenge_rival":
            return "Your accusations ring through the Standing Committee chamber. Your rival's face drains of color. The evidence is damning."
        case "begin_coup":
            return "The plotters have been identified and neutralized before they could act. Your decisiveness sends a clear message."
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
        case "order_show_trial":
            return ["show_trial_conducted"]
        case "launch_anticorruption":
            return ["anticorruption_campaign_active"]
        case "create_security_agency":
            return ["parallel_security_created"]
        case "abolish_term_limits":
            return ["term_limits_abolished_via_action"]
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
        let highestPositionIndex = ladder.map(\.index).max() ?? currentPosition

        // Already at top tier
        guard nextPositionIndex <= highestPositionIndex else {
            return PromotionCheck(
                canPromote: false,
                nextPosition: nil,
                reason: "You have reached the pinnacle of power."
            )
        }

        guard let nextPosition = resolveLadderPosition(for: game, at: nextPositionIndex, ladder: ladder) else {
            return PromotionCheck(
                canPromote: false,
                nextPosition: nil,
                reason: "No valid promotion path is available from your current track."
            )
        }

        let currentLadderPosition = resolveLadderPosition(for: game, at: currentPosition, ladder: ladder)

        // Check minimum turns in current position
        let minimumTurns = currentLadderPosition?.minimumTurnsInPosition ?? defaultMinimumTurnsInPosition
        let turnsInPosition = game.turnsInCurrentPosition

        if turnsInPosition < minimumTurns {
            let turnsRemaining = minimumTurns - turnsInPosition
            let weeksRemaining = turnsRemaining * 2
            return PromotionCheck(
                canPromote: false,
                nextPosition: nextPosition,
                reason: "Consolidation requires time. \(turnsRemaining) more turns (~\(weeksRemaining) weeks) in current role."
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
            $0.positionIndex == nextPosition.index && $0.isAlive
        }.count

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
                reason: "Your rival's faction holds enough Standing Committee votes to block your proposals. Weaken their position first."
            )
        }

        // All requirements met!
        return PromotionCheck(
            canPromote: true,
            nextPosition: nextPosition,
            reason: "You are eligible for promotion to \(nextPosition.title)."
        )
    }

    private func resolveLadderPosition(for game: Game, at index: Int, ladder: [LadderPosition]) -> LadderPosition? {
        let positionsAtIndex = ladder.filter { $0.index == index }
        guard !positionsAtIndex.isEmpty else { return nil }
        if positionsAtIndex.count == 1 { return positionsAtIndex.first }

        // Top leadership converges to shared positions.
        if index >= 7,
           let sharedPosition = positionsAtIndex.first(where: { $0.expandedTrack == .shared }) {
            return sharedPosition
        }

        if let committedTrack = game.currentCommittedTrack,
           let committedPosition = positionsAtIndex.first(where: { $0.expandedTrack == committedTrack }) {
            return committedPosition
        }

        let currentTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        if currentTrack != .shared,
           let currentTrackPosition = positionsAtIndex.first(where: { $0.expandedTrack == currentTrack }) {
            return currentTrackPosition
        }

        if let dominantTrack = game.trackAffinityScores.dominantTrack,
           let dominantPosition = positionsAtIndex.first(where: { $0.expandedTrack == dominantTrack }) {
            return dominantPosition
        }

        if let factionTrack = preferredTrackForFaction(game.playerFactionId),
           let factionPosition = positionsAtIndex.first(where: { $0.expandedTrack == factionTrack }) {
            return factionPosition
        }

        return positionsAtIndex.first(where: { $0.expandedTrack == .shared }) ?? positionsAtIndex.first
    }

    private func preferredTrackForFaction(_ factionId: String?) -> ExpandedCareerTrack? {
        switch factionId {
        case "old_guard":
            return .securityServices
        case "princelings":
            return .militaryPolitical
        case "reformists":
            return .economicPlanning
        case "youth_league":
            return .partyApparatus
        case "regional":
            return .regional
        default:
            return nil
        }
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
        // Structured system-collapse failures from the richer game-over model
        // should end the run immediately, regardless of the simpler balance checks below.
        if let structuredSystemLoss = checkStructuredSystemLossConditions(game: game) {
            return structuredSystemLoss
        }

        // Explicit personal-failure flags that were previously dormant in the active flow.
        if let flaggedPersonalLoss = checkFlaggedPersonalLossConditions(game: game) {
            return flaggedPersonalLoss
        }

        // EARLY GAME PROTECTION: Don't trigger loss conditions in first 5 turns
        // This gives players time to understand the game and recover from initial events
        // Exception: Catastrophic failures (state collapse) can still end the game
        let earlyGameProtection = game.turnNumber <= 5
        let canUseImmediateHeirSuccession = hasImmediateHeirSuccessionPath(game: game)

        // LOSS: Patron turns on you (purge)
        // Threshold lowered to 10 (from 15) to give more margin
        // Early game protection applies - patron wouldn't act this fast
        if !earlyGameProtection && game.patronFavor < 10 {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "Your patron has turned against you. Wallace's men arrive at dawn. Your political career—and perhaps your life—is over.",
                allowsHeirSuccession: canUseImmediateHeirSuccession
            )
        }

        // LOSS: Standing collapses (dismissed)
        // Early game protection applies - takes time to be fully dismissed
        if !earlyGameProtection && game.standing < 5 {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "Your standing has collapsed. You are quietly removed from all positions and reassigned to a minor posting in the Eastern Territories. Your political career is finished.",
                allowsHeirSuccession: canUseImmediateHeirSuccession
            )
        }

        // LOSS: Rival threat maxed (rival coup)
        // Use BalanceConfig threshold - requires extreme rival threat
        if game.rivalThreat >= BalanceConfig.assassinationRivalThreat {
            // Also require low network (no protection) as per BalanceConfig
            if game.network <= BalanceConfig.assassinationNetworkThreshold {
                return GameEndCheck(
                    gameOver: true,
                    result: .lost,
                    reason: "Your rivals have outmaneuvered you completely. At the next Politburo meeting, you find yourself facing accusations of counter-revolutionary activity. The vote is unanimous.",
                    allowsHeirSuccession: canUseImmediateHeirSuccession
                )
            }
        }

        // LOSS: Multiple critical stats (state collapse)
        // This is a catastrophic failure - NO early game protection
        // Use stricter threshold (< 10 instead of < 15) for state collapse
        let criticalStats = [
            game.stability,
            game.popularSupport,
            game.foodSupply
        ]
        let criticalCount = criticalStats.filter { $0 < 10 }.count
        if criticalCount >= 2 {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "The state crumbles around you. Riots in the streets, empty shelves in the stores, and the army grows restless. In the chaos, you are swept away with the old regime."
            )
        }

        // LOSS: Military coup (if player at top and military loyalty too low)
        // Use BalanceConfig thresholds
        if game.flags.contains("reached_general_secretary") &&
           game.militaryLoyalty <= BalanceConfig.coupMilitaryLoyaltyThreshold &&
           game.stability <= BalanceConfig.coupStabilityThreshold {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "Tanks roll through the capital at dawn. Marshal Anderson appears on state television. 'The people's patience has limits,' he announces. Your reign is over."
            )
        }

        // LOSS: Popular revolution (if player at top and popular support too low)
        // Use BalanceConfig thresholds - requires both low stability AND low support
        if game.flags.contains("reached_general_secretary") &&
           game.popularSupport <= BalanceConfig.revolutionPopularSupportThreshold &&
           game.stability <= BalanceConfig.revolutionStabilityThreshold {
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: "The crowds fill the streets. 'Bread! Freedom! Down with the tyrant!' they chant. The security forces refuse to fire on their own people. The palace falls."
            )
        }

        return nil
    }

    private func checkStructuredSystemLossConditions(game: Game) -> GameEndCheck? {
        guard let condition = GameOverChecker.checkGameOver(game: game) else {
            return nil
        }

        switch condition.type {
        case .nuclearWar, .territorialDisintegration, .capitalFalls, .foreignInvasion:
            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: systemLossReason(for: condition)
            )
        default:
            return nil
        }
    }

    private func checkFlaggedPersonalLossConditions(game: Game) -> GameEndCheck? {
        let canUseImmediateHeirSuccession = hasImmediateHeirSuccessionPath(game: game)

        if game.flags.contains("player_death_imminent") {
            let cause = game.variables["death_cause"] ?? "Natural causes"
            let reason = canUseImmediateHeirSuccession
                ? "Your predecessor has died. Official reports cite \(cause.lowercased())."
                : "Time claims all comrades eventually. Without a successor to continue your work, your influence dies with you."

            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: reason,
                allowsHeirSuccession: canUseImmediateHeirSuccession
            )
        }

        let protectionLevel = game.patronFavor + game.standing
        if game.flags.contains("corruption_exposed"),
           game.corruptionEvidence >= 70,
           protectionLevel < 50 {
            let reason = canUseImmediateHeirSuccession
                ? "The evidence against your predecessor is undeniable. Security forces move before the scandal can be contained."
                : "The evidence was undeniable. Your corruption was laid bare for all to see. The Party makes examples of such betrayals."

            return GameEndCheck(
                gameOver: true,
                result: .lost,
                reason: reason,
                allowsHeirSuccession: canUseImmediateHeirSuccession
            )
        }

        return nil
    }

    private func hasImmediateHeirSuccessionPath(game: Game) -> Bool {
        game.resolveHeirForContinuation() != nil
    }

    private func systemLossReason(for condition: GameOverCondition) -> String {
        let cause = condition.cause.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cause.isEmpty else {
            return condition.type.epitaph
        }

        if cause.hasSuffix(".") || cause.hasSuffix("!") || cause.hasSuffix("?") {
            return "\(cause) \(condition.type.epitaph)"
        }

        return "\(cause). \(condition.type.epitaph)"
    }

    private func checkWinConditions(game: Game, ladder: [LadderPosition]) -> GameEndCheck? {
        // Survival: survive 40 turns as leader
        if game.intVariable("turns_as_leader") >= 40 {
            return GameEndCheck(
                gameOver: true,
                result: .won,
                reason: VictoryType.survival.epitaph,
                victoryType: .survival
            )
        }

        // Legacy: all national stats above 70 for 5 consecutive turns
        if game.intVariable("consecutive_high_stat_turns") >= 5 {
            return GameEndCheck(
                gameOver: true,
                result: .won,
                reason: VictoryType.legacy.epitaph,
                victoryType: .legacy
            )
        }

        // Absolute Power: power consolidation >= 90 for 10 consecutive turns
        if game.intVariable("consecutive_supreme_leader_turns") >= 10 {
            return GameEndCheck(
                gameOver: true,
                result: .won,
                reason: VictoryType.absolutePower.epitaph,
                victoryType: .absolutePower
            )
        }

        // Reformer: high popular support and international standing with stability (snapshot)
        if game.popularSupport >= 80 &&
           game.internationalStanding >= 80 &&
           game.stability >= 60 {
            return GameEndCheck(
                gameOver: true,
                result: .won,
                reason: VictoryType.reformer.epitaph,
                victoryType: .reformer
            )
        }

        return nil
    }

    /// Call this at end of each turn to update game state
    func endTurnUpdates(game: Game, ladder: [LadderPosition], recordHistory: Bool = true) {
        // Snapshot critical pre-turn invariants so we can detect a half-applied turn.
        let preTurnNumber = game.turnNumber
        let preTreasury = game.treasury
        let preStability = game.stability
        defer {
            // Sanity check: turn number must have stayed the same during processing
            // (the caller increments it AFTER endTurnUpdates returns).
            if game.turnNumber != preTurnNumber {
                print("[GameEngine] WARNING: turnNumber mutated inside endTurnUpdates: \(preTurnNumber) -> \(game.turnNumber)")
            }
            // Touch the pre-snapshot variables to ensure they are retained for future
            // half-applied-turn detection (suppressing unused-let warnings).
            _ = preTreasury
            _ = preStability
        }

        // Increment turns as leader if at General Secretary position
        do {
            try runStep("trackTurnsAsLeader") {
                if game.currentPositionIndex >= 7 || game.flags.contains("reached_general_secretary") {
                    game.setIntVariable("turns_as_leader", game.intVariable("turns_as_leader") + 1)
                }
            }
        } catch {
            logTurnStepFailure(step: "trackTurnsAsLeader", error: error, turnNumber: game.turnNumber)
        }

        // Track consecutive high-stat turns for Legacy Victory
        do {
            try runStep("trackHighStatStreak") {
                let allStatsHigh = game.stability > 70 &&
                                   game.popularSupport > 70 &&
                                   game.industrialOutput > 70 &&
                                   game.internationalStanding > 70
                if allStatsHigh {
                    game.setIntVariable("consecutive_high_stat_turns", game.intVariable("consecutive_high_stat_turns") + 1)
                } else {
                    game.setIntVariable("consecutive_high_stat_turns", 0)
                }
            }
        } catch {
            logTurnStepFailure(step: "trackHighStatStreak", error: error, turnNumber: game.turnNumber)
        }

        // Track consecutive supreme leader turns for Absolute Power Victory
        do {
            try runStep("trackPowerConsolidation") {
                game.updatePowerConsolidation()
                if game.powerConsolidationScore >= 90 {
                    game.setIntVariable("consecutive_supreme_leader_turns", game.intVariable("consecutive_supreme_leader_turns") + 1)
                } else {
                    game.setIntVariable("consecutive_supreme_leader_turns", 0)
                }
            }
        } catch {
            logTurnStepFailure(step: "trackPowerConsolidation", error: error, turnNumber: game.turnNumber)
        }

        // Natural stat drift
        do {
            try runStep("applyStatDrift") {
                applyStatDrift(game: game)
            }
        } catch {
            logTurnStepFailure(step: "applyStatDrift", error: error, turnNumber: game.turnNumber)
        }

        // Character actions (rivals plotting, etc.)
        do {
            try runStep("simulateNPCActions") {
                simulateNPCActions(game: game)
            }
        } catch {
            logTurnStepFailure(step: "simulateNPCActions", error: error, turnNumber: game.turnNumber)
        }

        // Random events that affect stats
        do {
            try runStep("applyRandomEvents") {
                applyRandomEvents(game: game)
            }
        } catch {
            logTurnStepFailure(step: "applyRandomEvents", error: error, turnNumber: game.turnNumber)
        }

        // International dynamics - foreign relations, treaties, espionage, world tension
        // (Runs early so diplomatic actions are reflected before world events generate)
        do {
            try runStep("processInternationalDynamics") {
                processInternationalDynamics(game: game)
            }
        } catch {
            logTurnStepFailure(step: "processInternationalDynamics", error: error, turnNumber: game.turnNumber)
        }

        // NPC Behavior System - process decay, detection, and updates
        do {
            try runStep("processNPCBehaviorSystem") {
                processNPCBehaviorSystem(game: game)
            }
        } catch {
            logTurnStepFailure(step: "processNPCBehaviorSystem", error: error, turnNumber: game.turnNumber)
        }

        // Macro economic processing - GDP, inflation, unemployment, trade balance
        // (runs before political AI so NPCs react to current economic conditions)
        do {
            try runStep("processEconomicSystem") {
                processEconomicSystem(game: game)
            }
        } catch {
            logTurnStepFailure(step: "processEconomicSystem", error: error, turnNumber: game.turnNumber)
        }

        // Economic conditions affect political stability
        do {
            try runStep("applyEconomicPoliticalFeedback") {
                applyEconomicPoliticalFeedback(game: game)
            }
        } catch {
            logTurnStepFailure(step: "applyEconomicPoliticalFeedback", error: error, turnNumber: game.turnNumber)
        }

        // Political AI - NPC policy proposals and voting
        do {
            try runStep("processPoliticalAI") {
                processPoliticalAI(game: game)
            }
        } catch {
            logTurnStepFailure(step: "processPoliticalAI", error: error, turnNumber: game.turnNumber)
        }

        // Standing Committee meetings - convene periodically and process decisions
        do {
            try runStep("processStandingCommitteeCycle") {
                processStandingCommitteeCycle(game: game)
            }
        } catch {
            logTurnStepFailure(step: "processStandingCommitteeCycle", error: error, turnNumber: game.turnNumber)
        }

        // Position offers - check expirations and generate new offers
        do {
            try runStep("processPositionOffers") {
                processPositionOffers(game: game)
            }
        } catch {
            logTurnStepFailure(step: "processPositionOffers", error: error, turnNumber: game.turnNumber)
        }

        // World simulation - dynamic world events (RDR2-style living world)
        // (Runs after diplomatic state is updated so events reflect current relations)
        do {
            try runStep("simulateWorldEvents") {
                simulateWorldEvents(game: game)
            }
        } catch {
            logTurnStepFailure(step: "simulateWorldEvents", error: error, turnNumber: game.turnNumber)
        }

        // Regional dynamics - stability, secession progress, territorial integrity
        do {
            try runStep("processRegionalDynamics") {
                processRegionalDynamics(game: game)
            }
        } catch {
            logTurnStepFailure(step: "processRegionalDynamics", error: error, turnNumber: game.turnNumber)
        }

        // Intelligence leaks - generate secret intel based on Network stat
        do {
            try runStep("processIntelligenceLeaks") {
                processIntelligenceLeaks(game: game)
            }
        } catch {
            logTurnStepFailure(step: "processIntelligenceLeaks", error: error, turnNumber: game.turnNumber)
        }

        // Threat pre-warnings - alert player when threats approach critical
        do {
            try runStep("generateThreatWarnings") {
                generateThreatWarnings(game: game)
            }
        } catch {
            logTurnStepFailure(step: "generateThreatWarnings", error: error, turnNumber: game.turnNumber)
        }

        if recordHistory {
            // Record stat history for sparklines (at end of turn after all processing)
            do {
                try runStep("recordAllStatHistory") {
                    game.recordAllStatHistory()
                }
            } catch {
                logTurnStepFailure(step: "recordAllStatHistory", error: error, turnNumber: game.turnNumber)
            }
        }
    }

    // MARK: - Turn pipeline scaffolding

    /// Invoke a single turn-step closure, tagging any thrown error with the step name.
    /// Most existing step methods don't throw — wrapping them in try/catch catches
    /// nothing today. That's intentional: this is structural scaffolding so future
    /// throwing refactors of individual steps don't require touching the pipeline.
    private func runStep(_ name: String, _ body: () throws -> Void) rethrows {
        _ = name
        try body()
    }

    /// Log a turn-step failure both to the OS logger and as a `GameEvent` so the
    /// failure is visible in-game/journal rather than silently lost.
    private func logTurnStepFailure(step: String, error: Error, turnNumber: Int) {
        gameLogger.error("Turn step '\(step)' failed at turn \(turnNumber): \(String(describing: error))")
        #if DEBUG
        print("[GameEngine] turn step '\(step)' failed at turn \(turnNumber): \(error)")
        #endif
        let event = GameEvent(
            turnNumber: turnNumber,
            eventType: .systemError,
            summary: "Turn step '\(step)' failed: \(error.localizedDescription)"
        )
        event.details["step"] = step
        event.details["error"] = String(describing: error)
        event.importance = 8
        // Do not insert into a ModelContext here — endTurnUpdates is intentionally
        // context-agnostic. Callers that have a context can persist these via
        // their normal event-logging path; the print() above ensures the failure
        // is observable in DEBUG even without persistence.
        _ = event
    }

    /// Extended end-of-turn processing that includes Codex and Consequence integration
    /// Call this instead of endTurnUpdates when you have a ModelContext available
    func endTurnUpdatesWithContext(game: Game, ladder: [LadderPosition], context: ModelContext) async {
        // Resolve multi-turn bureau operations first so diplomatic action
        // results are visible to turn processing (e.g. world event generation).
        processBureauOperations(game: game, context: context)

        // Run standard end-of-turn updates
        endTurnUpdates(game: game, ladder: ladder, recordHistory: false)

        // Process consequences and generate Codex reactions
        let firedConsequences = ConsequenceEngine.shared.processConsequences(game: game)
        await processConsequenceCodexReactions(consequences: firedConsequences, game: game, context: context)

        // Process event-driven Codex messages (relationship triggers, state thresholds, check-ins)
        await CodexService.shared.processEventDrivenMessages(game: game, context: context)

        // Record stat history once after all turn effects are applied.
        game.recordAllStatHistory()

        gameLogger.info("End-of-turn Codex processing complete. \(firedConsequences.count) consequences fired.")
    }

    private func processBureauOperations(game: Game, context: ModelContext) {
        _ = SecurityActionService.shared.processPendingActions(for: game, modelContext: context)
        _ = SecurityActionService.shared.processActiveDetentions(for: game, modelContext: context)
        _ = EconomicActionService.shared.advanceProjects(for: game, modelContext: context)
        _ = PartyActionService.shared.advanceCampaigns(for: game, modelContext: context)
        _ = MilitaryActionService.shared.advanceCampaigns(for: game, modelContext: context)
        _ = StateMinistryActionService.shared.advanceProjects(for: game, modelContext: context)
        _ = DiplomaticActionService.shared.processPendingActions(for: game, modelContext: context)
    }

    /// Generate Codex messages for characters affected by fired consequences
    private func processConsequenceCodexReactions(consequences: [ProcessedConsequence], game: Game, context: ModelContext) async {
        for processed in consequences {
            // Check if consequence has a related character
            if let characterId = processed.consequence.relatedCharacterId {
                CodexService.shared.queueConsequenceReaction(
                    consequenceType: processed.consequence.type.rawValue,
                    consequenceDescription: processed.consequence.description,
                    characterId: characterId,
                    game: game,
                    context: context
                )
            }

            // For elite backlash, have patron comment if patron exists and favor is low
            if processed.consequence.type == .eliteBacklash, let patron = game.patron {
                if game.patronFavor < 50 {
                    CodexService.shared.queueConsequenceReaction(
                        consequenceType: "eliteBacklash",
                        consequenceDescription: processed.consequence.description,
                        characterId: patron.templateId,
                        game: game,
                        context: context
                    )
                }
            }

            // For coalition forming, have rival gloat if rival exists
            if processed.consequence.type == .coalitionForms, let rival = game.primaryRival {
                CodexService.shared.queueConsequenceReaction(
                    consequenceType: "coalitionForms",
                    consequenceDescription: processed.consequence.description,
                    characterId: rival.templateId,
                    game: game,
                    context: context
                )
            }
        }
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

        // Process PSR's macro economy (GDP, inflation, unemployment)
        EconomyService.shared.processEconomy(game: game)

        // Process foreign country economies
        EconomyService.shared.processForeignEconomies(game: game)

        // Keep desk/report UI in sync without applying a second treasury model.
        EconomyService.shared.snapshotEconomicReport(game: game)

        gameLogger.info("Economic indicators - GDP: \(game.gdpIndex), Inflation: \(game.inflationRate)%, Unemployment: \(game.unemploymentRate)%")
    }

    /// Apply political consequences of economic conditions
    private func applyEconomicPoliticalFeedback(game: Game) {
        // Treasury crisis erodes elite confidence
        if game.treasury < 20 {
            game.applyStat("eliteLoyalty", change: -2)
        } else if game.treasury < 35 {
            game.applyStat("eliteLoyalty", change: -1)
        }

        // Food shortages destroy popular support
        if game.foodSupply < 25 {
            game.applyStat("popularSupport", change: -3)
        } else if game.foodSupply < 40 {
            game.applyStat("popularSupport", change: -1)
        }

        // High unemployment breeds unrest
        if game.unemploymentRate > 30 {
            game.applyStat("stability", change: -2)
            game.applyStat("popularSupport", change: -1)
        } else if game.unemploymentRate > 20 {
            game.applyStat("stability", change: -1)
        }

        // Hyperinflation destabilizes everything
        if game.inflationRate > 40 {
            game.applyStat("stability", change: -2)
            game.applyStat("popularSupport", change: -2)
        } else if game.inflationRate > 25 {
            game.applyStat("stability", change: -1)
        }

        // Strong economy boosts support (positive feedback)
        if game.gdpGrowthRate > 5 && game.treasury > 60 {
            game.applyStat("popularSupport", change: 1)
            game.applyStat("eliteLoyalty", change: 1)
        }

        // Phase 3.7: Strategic resource feedback into political stats
        applyStrategicResourceFeedback(game: game)
    }

    /// Phase 3.7: After the supply chain runs, translate resource deficits and
    /// starved sectors into political stat changes so the new economy actually
    /// matters politically. Healthy supply chain → no penalties; crisis →
    /// compounding penalties across loyalty/support/output.
    private func applyStrategicResourceFeedback(game: Game) {
        let reserves = game.strategicReserves

        // Resource deficits — each hits the constituency that depends on that resource
        var deficitCount = 0

        if (reserves[.grain] ?? 0) <= 0 {
            game.applyStat("popularSupport", change: -2)
            deficitCount += 1
        }
        if (reserves[.meat] ?? 0) <= 0 {
            game.applyStat("popularSupport", change: -1)
            deficitCount += 1
        }
        if (reserves[.coal] ?? 0) <= 0 || (reserves[.oil] ?? 0) <= 0 {
            game.applyStat("industrialOutput", change: -2)
            game.applyStat("militaryLoyalty", change: -1)
            deficitCount += 1
        }
        if (reserves[.steel] ?? 0) <= 0 {
            game.applyStat("militaryLoyalty", change: -2)
            game.applyStat("eliteLoyalty", change: -1)
            deficitCount += 1
        }
        if (reserves[.aluminum] ?? 0) <= 0 {
            game.applyStat("militaryLoyalty", change: -1)
            deficitCount += 1
        }
        if (reserves[.iron] ?? 0) <= 0 {
            game.applyStat("industrialOutput", change: -1)
            deficitCount += 1
        }
        if (reserves[.uranium] ?? 0) <= 0 && game.canUse(.uranium) {
            game.applyStat("internationalStanding", change: -1)
            deficitCount += 1
        }
        if (reserves[.rareEarths] ?? 0) <= 0 && game.canUse(.rareEarths) {
            game.applyStat("internationalStanding", change: -1)
            game.applyStat("eliteLoyalty", change: -1)
            deficitCount += 1
        }

        // Sector capacity feedback — sectors running below half capacity have
        // political consequences proportional to their constituency.
        if let result = game.lastSupplyChainResult {
            for (sectorRaw, satisfaction) in result.shortfallBySector where satisfaction < 50 {
                guard let sector = EconomicSector(rawValue: sectorRaw) else { continue }
                switch sector {
                case .agriculture:
                    game.applyStat("popularSupport", change: -2)
                case .defense:
                    game.applyStat("militaryLoyalty", change: -2)
                case .lightIndustry:
                    game.applyStat("popularSupport", change: -1)
                case .heavyIndustry:
                    game.applyStat("eliteLoyalty", change: -1)
                case .energy:
                    game.applyStat("industrialOutput", change: -2)
                    game.applyStat("stability", change: -1)
                case .mining, .construction, .transport:
                    game.applyStat("eliteLoyalty", change: -1)
                }
            }
        }

        // Multi-deficit crisis: if 3+ resources are in deficit, fire a
        // notification + log a high-importance event so the player sees the
        // cascade clearly.
        if deficitCount >= 3 {
            let event = GameEvent(
                turnNumber: game.turnNumber,
                eventType: .crisis,
                summary: "Strategic resource crisis: \(deficitCount) commodities exhausted. Apparatus strained across multiple sectors."
            )
            event.importance = 9
            event.details = ["type": "strategic_resource_crisis", "deficitCount": String(deficitCount)]
            event.game = game
            game.events.append(event)

            NotificationService.shared.notify(
                .statCriticalLow,
                title: "STRATEGIC RESERVES EXHAUSTED",
                detail: "\(deficitCount) key commodities are depleted. Open trade or shift sector focus immediately.",
                turn: game.turnNumber
            )
        }
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

    /// Process Standing Committee meeting cycle
    /// Convenes meetings based on LeadershipConfig settings
    private func processStandingCommitteeCycle(game: Game) {
        guard let committee = game.standingCommittee else { return }

        // Get leadership config (with defaults)
        let config = CampaignLoader.shared.loadCampaign(id: game.campaignId)?.leadershipConfig
        let meetingInterval = config?.meetingFrequency ?? 5
        let minAgenda = config?.minimumAgendaItems ?? 1

        let turnsSinceMeeting = game.turnNumber - committee.lastMeetingTurn

        // Check if it's time for a meeting
        guard turnsSinceMeeting >= meetingInterval else {
            gameLogger.debug("SC meeting not due. Turns since last: \(turnsSinceMeeting)/\(meetingInterval)")
            return
        }

        // Need agenda items to meet (unless crisis)
        guard committee.pendingAgenda.count >= minAgenda || game.stability < 30 else {
            gameLogger.debug("SC meeting skipped - insufficient agenda items (\(committee.pendingAgenda.count)/\(minAgenda))")
            return
        }

        gameLogger.info("Convening Standing Committee meeting (turn \(game.turnNumber))")

        // Convene the meeting
        let result = StandingCommitteeService.shared.conveneMeeting(
            committee: committee,
            game: game
        )

        // Process decisions and generate downstream effects
        processMeetingDecisions(result: result, game: game)

        // Log the meeting as a game event
        let gameEvent = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .standingCommitteeMeeting,
            summary: result.narrative
        )
        gameEvent.importance = 8
        gameEvent.game = game
        game.events.append(gameEvent)

        gameLogger.info("SC meeting concluded. \(result.itemResults.count) decisions made.")
    }

    /// Process the results of a Standing Committee meeting
    /// Generates trickle-down effects like documents, events, and world state changes
    private func processMeetingDecisions(result: CommitteeMeetingResult, game: Game) {
        for decision in result.itemResults {
            // Process passed decisions
            if decision.outcome == .approved || decision.outcome == .amendedAndApproved {
                // Apply any stat effects from the decision
                applyDecisionEffects(decision: decision, game: game)

                // Queue documents for players based on position level
                queueDecisionDocuments(decision: decision, game: game)

                // Queue events for players if decision is significant
                if decision.item.priority == .urgent || decision.item.priority == .critical {
                    queueDecisionEvent(decision: decision, game: game)
                }

                gameLogger.info("SC decision passed: \(decision.item.title)")
            } else if decision.outcome == .rejected {
                // Failed proposals may have political consequences
                if let sponsorId = decision.item.sponsorId,
                   let sponsor = game.characters.first(where: { $0.templateId == sponsorId }) {
                    // Sponsor loses disposition (their reputation suffers)
                    sponsor.disposition = max(0, sponsor.disposition - 5)
                    gameLogger.info("SC decision rejected: \(decision.item.title) - \(sponsor.name) loses standing")
                }
            }
        }
    }

    /// Apply effects of a passed SC decision to game state
    private func applyDecisionEffects(decision: CommitteeDecisionResult, game: Game) {
        let item = decision.item

        // Use proposal-specific effects if defined, otherwise fall back to category-based
        if !item.effects.isEmpty {
            // Apply custom effects from the proposal
            for (key, value) in item.effects {
                switch key {
                case "stability", "popularSupport", "eliteLoyalty", "industrialOutput", "internationalStanding":
                    game.applyStat(key, change: value)
                case "militaryLoyalty":
                    // Find military faction and adjust power
                    if let militaryFaction = game.factions.first(where: { $0.factionId == "military" }) {
                        militaryFaction.power = max(0, min(100, militaryFaction.power + value))
                    }
                default:
                    gameLogger.warning("Unknown effect key: \(key)")
                }
            }
            gameLogger.info("SC decision '\(item.title)' applied custom effects: \(item.effects)")
        } else {
            // Fall back to category-based effects for legacy/routine proposals
            switch item.category {
            case .economic:
                // Economic decisions affect industrial output and treasury
                let impact = item.priority == .critical ? 5 : (item.priority == .urgent ? 3 : 1)
                game.applyStat("industrialOutput", change: impact)

            case .security:
                // Security decisions affect stability but may hurt popular support
                let impact = item.priority == .critical ? 8 : (item.priority == .urgent ? 5 : 2)
                game.applyStat("stability", change: impact)
                game.applyStat("popularSupport", change: -(impact / 2))

            case .personnel:
                // Personnel changes affect elite loyalty
                let impact = item.priority == .critical ? 6 : (item.priority == .urgent ? 4 : 2)
                game.applyStat("eliteLoyalty", change: impact)

            case .foreign:
                // Foreign policy affects international standing
                let impact = item.priority == .critical ? 5 : (item.priority == .urgent ? 3 : 1)
                game.applyStat("internationalStanding", change: impact)

            case .ideological:
                // Ideological decisions affect elite loyalty but may hurt popular support
                let impact = item.priority == .critical ? 5 : 3
                game.applyStat("eliteLoyalty", change: impact)
                game.applyStat("popularSupport", change: -2)

            case .crisis:
                // Crisis responses have mixed effects
                game.applyStat("stability", change: 5)

            case .policy:
                // General policy has modest stability effect
                game.applyStat("stability", change: 2)

            case .succession:
                // Succession decisions affect elite loyalty and stability
                game.applyStat("eliteLoyalty", change: 5)
                game.applyStat("stability", change: 3)
            }
        }
    }

    /// Queue documents for players based on SC decisions
    private func queueDecisionDocuments(decision: CommitteeDecisionResult, game: Game) {
        // Only queue documents for significant decisions
        guard decision.item.priority != .routine else { return }

        // Generate appropriate document based on player's position level
        let clearanceLevel = game.currentPositionIndex
        var document: DeskDocument?

        switch decision.item.category {
        case .economic:
            if clearanceLevel <= 3 {
                document = DeskDocument.builder()
                    .withTemplateId("sc_economic_directive_\(game.turnNumber)")
                    .ofType(.directive)
                    .titled("Production Quota Adjustment Notice")
                    .from("Standing Committee Secretariat", title: "Economic Affairs Division")
                    .receivedOnTurn(game.turnNumber)
                    .withUrgency(.routine)
                    .inCategory(.economic)
                    .withBody("""
                        NOTICE TO ALL BUREAUS

                        Following the Standing Committee's directive on \(decision.item.title), your bureau's quotas have been updated.

                        All personnel must review and acknowledge compliance requirements within the specified timeframe.

                        Failure to meet adjusted targets will be noted in performance evaluations.

                        By order of the Standing Committee
                        """)
                    .requiresDecision(true)
                    .addOption(id: "acknowledge", text: "Acknowledge and comply", shortDescription: "Acknowledged directive", effects: [:])
                    .addOption(id: "request_extension", text: "Request implementation extension", shortDescription: "Requested extension", effects: ["stability": -1])
                    .build()
            } else {
                document = DeskDocument.builder()
                    .withTemplateId("sc_economic_policy_\(game.turnNumber)")
                    .ofType(.directive)
                    .titled("Economic Policy Implementation Directive")
                    .from("Standing Committee", title: "Central Government")
                    .receivedOnTurn(game.turnNumber)
                    .withUrgency(.priority)
                    .inCategory(.economic)
                    .withBody("""
                        DIRECTIVE TO SENIOR OFFICIALS

                        The Standing Committee has approved: \(decision.item.title)

                        As a senior official, you are responsible for ensuring your department implements these measures promptly and completely.

                        Implementation progress will be monitored. Report any obstacles through proper channels.

                        By authority of the Standing Committee
                        """)
                    .requiresDecision(true)
                    .addOption(id: "implement", text: "Begin immediate implementation", shortDescription: "Ordered implementation", effects: ["eliteLoyalty": 2])
                    .addOption(id: "delay", text: "Request clarification before acting", shortDescription: "Delayed for clarification", effects: ["eliteLoyalty": -2])
                    .build()
            }

        case .security:
            document = DeskDocument.builder()
                .withTemplateId("sc_security_directive_\(game.turnNumber)")
                .ofType(.directive)
                .titled("Security Vigilance Notice")
                .from("State Security Directorate", title: "Standing Committee Authority")
                .receivedOnTurn(game.turnNumber)
                .withUrgency(.priority)
                .inCategory(.security)
                .withBody("""
                    SECURITY DIRECTIVE - ALL PERSONNEL

                    The Standing Committee has issued new security directives regarding \(decision.item.title).

                    All personnel are expected to maintain heightened vigilance. Report any suspicious activities or behaviors through established channels.

                    Remember: Security is everyone's responsibility.

                    State Security Directorate
                    """)
                .requiresDecision(true)
                .addOption(id: "acknowledge", text: "Acknowledge and increase vigilance", shortDescription: "Acknowledged security notice", effects: [:])
                .addOption(id: "report", text: "Report observed concerns", shortDescription: "Submitted security report", effects: ["network": -3, "stability": 1])
                .build()

        case .personnel:
            if clearanceLevel >= 4 {
                document = DeskDocument.builder()
                    .withTemplateId("sc_personnel_notice_\(game.turnNumber)")
                    .ofType(.directive)
                    .titled("Personnel Changes Notification")
                    .from("Central Personnel Department", title: "Standing Committee")
                    .receivedOnTurn(game.turnNumber)
                    .withUrgency(.priority)
                    .inCategory(.political)
                    .withBody("""
                        LEADERSHIP CHANGES ANNOUNCEMENT

                        The Standing Committee has approved changes to leadership positions: \(decision.item.title)

                        These changes take effect immediately. All affected departments should ensure smooth transitions.

                        Cooperation with incoming leadership is expected from all personnel.

                        Central Personnel Department
                        """)
                    .requiresDecision(true)
                    .addOption(id: "acknowledge", text: "Acknowledge personnel changes", shortDescription: "Acknowledged changes", effects: [:])
                    .addOption(id: "contact", text: "Reach out to affected parties", shortDescription: "Made contacts", effects: ["network": 2])
                    .build()
            }

        case .ideological:
            document = DeskDocument.builder()
                .withTemplateId("sc_ideological_directive_\(game.turnNumber)")
                .ofType(.directive)
                .titled("Political Education Directive")
                .from("Propaganda Department", title: "Central Committee")
                .receivedOnTurn(game.turnNumber)
                .withUrgency(.routine)
                .inCategory(.political)
                .withBody("""
                    POLITICAL EDUCATION NOTICE

                    Following the Committee's guidance on \(decision.item.title), all units must conduct political study sessions.

                    Attendance is mandatory. Study materials will be distributed through party channels.

                    Strengthen your ideological foundation. Build socialist consciousness.

                    Propaganda Department
                    """)
                .requiresDecision(true)
                .addOption(id: "attend", text: "Schedule attendance", shortDescription: "Scheduled study session", effects: ["eliteLoyalty": 1])
                .addOption(id: "organize", text: "Organize unit study session", shortDescription: "Organized study session", effects: ["eliteLoyalty": 2, "network": -1])
                .build()

        default:
            break
        }

        // Queue the document if we generated one
        if let doc = document {
            game.deskDocuments.append(doc)
            gameLogger.info("Queued SC directive document: \(doc.title)")
        }
    }

    /// Queue a dynamic event for the player about an SC decision
    private func queueDecisionEvent(decision: CommitteeDecisionResult, game: Game) {
        let title: String
        let briefText: String
        let priority: EventPriority

        switch decision.item.category {
        case .crisis:
            title = "Standing Committee Crisis Response"
            briefText = "The Standing Committee has convened to address: \(decision.item.title)"
            priority = .urgent
        case .security:
            title = "Security Policy Update"
            briefText = "New security measures approved: \(decision.item.title)"
            priority = .elevated
        case .personnel:
            title = "Leadership Changes Announced"
            briefText = "The Standing Committee has decided: \(decision.item.title)"
            priority = .elevated
        default:
            title = "Standing Committee Decision"
            briefText = "The Committee has approved: \(decision.item.title)"
            priority = .normal
        }

        // Look up sponsor name from sponsorId
        let sponsorName: String
        if let sponsorId = decision.item.sponsorId,
           let sponsor = game.characters.first(where: { $0.templateId == sponsorId }) {
            sponsorName = sponsor.name
        } else {
            sponsorName = "Standing Committee"
        }

        // Player is General Secretary — always receive institutional change notifications
        let event = DynamicEvent(
            eventType: .institutionalChange,
            priority: priority,
            title: title,
            briefText: briefText,
            initiatingCharacterName: sponsorName,
            turnGenerated: game.turnNumber,
            isUrgent: priority == .urgent,
            responseOptions: [
                EventResponse(
                    id: "acknowledge",
                    text: "Acknowledge and prepare",
                    shortText: "Acknowledge",
                    effects: [:]
                )
            ],
            iconName: "building.columns.fill"
        )
        game.queueDynamicEvent(event)
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

        // Process organic NPC life events (personality-driven deaths, scandals, breakdowns, etc.)
        // These create visible world events based on player's Network stat (layered visibility)
        let lifeEvents = NPCLifeEventsService.shared.processLifeEvents(game: game)
        if !lifeEvents.isEmpty {
            gameLogger.info("Generated \(lifeEvents.count) NPC life events this turn")
        }
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

            // Player is General Secretary — always generate intelligence reports
            _ = WorldSimulationService.shared.generateIntelligenceReports(
                events: worldEvents,
                game: game
            )
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

        // Autonomous NPC actions - NPCs should ALWAYS be doing something for immersive gameplay
        // (Skip only the very first turn to let player read the intro)
        guard game.turnNumber > 1 else { return }

        // IMMERSIVE DESIGN: The world is alive. NPCs are always scheming, maneuvering, and acting.
        // We evaluate ALL three action systems each turn to ensure the player feels the political
        // ecosystem is dynamic and responsive. Each system has its own internal probability gates.

        var npcActionsThisTurn: [DynamicEvent] = []

        // 1. Character agency - patron/rival/ally direct actions (high priority relationships)
        if let characterEvent = CharacterAgencyService.shared.evaluateCharacterActions(game: game) {
            npcActionsThisTurn.append(characterEvent)
        }

        // 2. Goal-driven agency - NPCs pursuing their ambitions (career advancement, rivalry, etc.)
        let goalEvents = GoalDrivenAgencyService.shared.evaluateGoalDrivenActions(game: game)
        npcActionsThisTurn.append(contentsOf: goalEvents.prefix(2)) // Up to 2 goal events

        // 3. Memory-driven agency - grudges, gratitude, and past interactions surfacing
        let memoryEvents = MemoryIntegrationService.shared.evaluateMemoryDrivenActions(game: game)
        npcActionsThisTurn.append(contentsOf: memoryEvents.prefix(1)) // Up to 1 memory event

        // 4. NPC-to-NPC world actions - visible events of NPCs interacting with each other
        // These use layered visibility based on player's Network stat
        let worldActions = NPCWorldActionService.shared.processWorldActions(game: game)
        if !worldActions.isEmpty {
            gameLogger.info("Generated \(worldActions.count) NPC world action events")
        }

        // Queue up to 3 NPC events per turn (prevents overwhelming but ensures activity)
        for event in npcActionsThisTurn.prefix(3) {
            game.queueDynamicEvent(event)
        }

        // Log NPC activities to the Journal for player visibility
        logNPCActivitiesToJournal(events: npcActionsThisTurn, game: game)
    }

    /// Log significant NPC autonomous actions to the player's journal
    private func logNPCActivitiesToJournal(events: [DynamicEvent], game: Game) {
        // Only log if there were meaningful NPC actions this turn
        guard !events.isEmpty else { return }

        // Create a summary of NPC activity for the journal
        for event in events.prefix(2) { // Log up to 2 entries per turn
            // Try to find the initiating character by name (since ID is UUID, not templateId)
            if let characterName = event.initiatingCharacterName,
               let character = game.characters.first(where: { $0.name == characterName }) {
                JournalService.shared.onNPCActivity(
                    character: character,
                    activitySummary: event.title,
                    details: event.briefText,
                    game: game
                )
            }
        }
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
                let fate = weightedRandom(fates, weights: weights) ?? .retired
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

    private func weightedRandom<T>(_ items: [T], weights: [Int]) -> T? {
        // Guard against empty arrays - return nil instead of crashing
        guard !items.isEmpty else {
            assertionFailure("weightedRandom called with empty items array")
            return nil
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
    var allowsHeirSuccession: Bool = false
    var victoryType: VictoryType?
}

// MARK: - Threat Pre-Warning System

extension GameEngine {

    /// Generate intelligence alerts when threat vectors approach dangerous levels.
    /// Uses ThreatCalculator to evaluate all five threat vectors and fires
    /// alerts at the "elevated" (0.5) and "high" (0.75) severity thresholds.
    /// Deduplication is handled by flag-based cooldowns: each threat/severity
    /// combo fires at most once per 5 turns.
    func generateThreatWarnings(game: Game) {
        guard game.turnNumber > 5 else { return }

        let threats = ThreatCalculator.getThreatLevels(game: game)

        for threat in threats {
            if threat.severity >= 0.75 {
                emitThreatAlert(game: game, threat: threat, tier: .high)
            } else if threat.severity >= 0.50 {
                emitThreatAlert(game: game, threat: threat, tier: .elevated)
            } else if threat.severity < 0.25 {
                // Clear flags when threat subsides so warnings can re-fire later
                let highFlag = "threat_warning_high_\(threat.id)"
                let elevatedFlag = "threat_warning_elevated_\(threat.id)"
                game.flags.removeAll { $0 == highFlag || $0 == elevatedFlag }
            }
        }
    }

    private func emitThreatAlert(game: Game, threat: ThreatLevel, tier: WarningSeverity) {
        let tierKey = tier == .high ? "high" : "elevated"
        let flag = "threat_warning_\(tierKey)_\(threat.id)"
        let cooldownKey = "threat_cooldown_\(threat.id)_\(tierKey)"
        let lastWarningTurn = Int(game.variables[cooldownKey] ?? "0") ?? 0

        guard game.turnNumber - lastWarningTurn >= 5, !game.flags.contains(flag) else { return }

        IntelligenceAlertService.shared.createAlert(
            for: game,
            category: .secretIntelligence,
            title: tier == .high ? "URGENT INTELLIGENCE BRIEF" : "INTELLIGENCE BRIEF",
            content: threatWarningMessage(threat: threat, severity: tier),
            importance: tier == .high ? 9 : 7
        )
        game.variables[cooldownKey] = "\(game.turnNumber)"
        game.flags.append(flag)
    }

    private enum WarningSeverity {
        case elevated, high
    }

    private func threatWarningMessage(threat: ThreatLevel, severity: WarningSeverity) -> String {
        switch (threat.id, severity) {
        // Military Coup
        case ("military_coup", .elevated):
            return "Military officers are expressing discontent with civilian leadership. Loyalty among the General Staff is eroding. Consider strengthening military ties before the situation deteriorates further."
        case ("military_coup", .high):
            return "CRITICAL: Senior military commanders are holding unauthorized meetings. Sources report discussions of 'restoring order.' A coup attempt is a real possibility. Immediate action required."

        // Popular Revolution
        case ("revolution", .elevated):
            return "Underground opposition networks are growing in major cities. Worker dissatisfaction is spreading. The security apparatus reports increasing difficulty containing unrest."
        case ("revolution", .high):
            return "CRITICAL: Mass demonstrations are being planned. Opposition leaders are coordinating across regions. The popular mood is dangerously volatile. The regime's grip is slipping."

        // Assassination
        case ("assassination", .elevated):
            return "Your rival is consolidating support among disaffected elements. Intelligence suggests they may be exploring 'direct action' against your person. Strengthen your protective network."
        case ("assassination", .high):
            return "CRITICAL: Credible intelligence indicates an assassination plot is being organized. Your rival's network has penetrated close to your inner circle. Your personal security is gravely compromised."

        // State Collapse
        case ("state_collapse", .elevated):
            return "Multiple national indicators are approaching critical thresholds simultaneously. The state's capacity to maintain basic functions is under severe strain."
        case ("state_collapse", .high):
            return "CRITICAL: The state is on the verge of systemic failure. Essential services are collapsing in multiple sectors. Without immediate intervention, total state dissolution is imminent."

        // SC Revolt / Party Purge
        case ("sc_revolt", .elevated):
            return "Establishment figures are expressing dissatisfaction with your leadership. Whispered conversations in the corridors of power suggest a loss of confidence. Shore up your political alliances."
        case ("sc_revolt", .high):
            return "CRITICAL: Party elites are actively discussing your removal. A vote of no confidence within the Standing Committee is being organized. Your position is in immediate danger."

        default:
            return "Threat conditions are developing in the \(threat.name.lowercased()) sector. Monitoring continues."
        }
    }
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
