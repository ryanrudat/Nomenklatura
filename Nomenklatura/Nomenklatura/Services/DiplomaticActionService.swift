//
//  DiplomaticActionService.swift
//  Nomenklatura
//
//  Handles execution of position-gated diplomatic actions following CCP-style
//  hierarchy. Validates permissions, calculates success, applies effects,
//  and manages cooldowns.
//

import Foundation
import SwiftData

// MARK: - Action Validation Result

/// Result of validating whether an action can be executed
struct ActionValidationResult {
    let canExecute: Bool
    let reason: String?
    let successChance: Int

    static func success(chance: Int) -> ActionValidationResult {
        ActionValidationResult(canExecute: true, reason: nil, successChance: chance)
    }

    static func failure(_ reason: String) -> ActionValidationResult {
        ActionValidationResult(canExecute: false, reason: reason, successChance: 0)
    }
}

// MARK: - Action Execution Result

/// Result of executing a diplomatic action
struct ActionExecutionResult {
    let succeeded: Bool
    let description: String
    let effectsApplied: DiplomaticEffects
    let triggeredEvents: [String]
    let pendingRecord: DiplomaticActionRecord?

    var isPending: Bool {
        pendingRecord != nil && !succeeded
    }
}

// MARK: - Diplomatic Action Service

@MainActor
class DiplomaticActionService {

    static let shared = DiplomaticActionService()

    // MARK: - Available Actions

    /// Get all actions available to the player at their current position
    func availableActions(for game: Game) -> [DiplomaticAction] {
        let positionIndex = game.currentPositionIndex
        let track = game.currentExpandedTrack

        return DiplomaticAction.allActions.filter { action in
            // Check position requirement
            guard positionIndex >= action.minimumPositionIndex else { return false }

            // Check track requirement if specified
            if let requiredTrack = action.requiredTrack {
                guard track == requiredTrack else { return false }
            }

            return true
        }
    }

    /// Get actions that are locked (not yet available) for preview
    func lockedActions(for game: Game) -> [DiplomaticAction] {
        let positionIndex = game.currentPositionIndex

        return DiplomaticAction.allActions.filter { action in
            action.minimumPositionIndex > positionIndex
        }
    }

    /// Get actions on cooldown
    func actionsOnCooldown(for game: Game) -> [String: Int] {
        let tracker = getCooldownTracker(for: game)
        var onCooldown: [String: Int] = [:]

        for action in DiplomaticAction.allActions {
            let remaining = tracker.turnsRemaining(actionId: action.id, currentTurn: game.turnNumber)
            if remaining > 0 {
                onCooldown[action.id] = remaining
            }
        }

        return onCooldown
    }

    // MARK: - Validation

    /// Validate whether an action can be executed
    func validateAction(
        _ action: DiplomaticAction,
        targetCountry: ForeignCountry?,
        for game: Game
    ) -> ActionValidationResult {
        // Check position requirement
        guard game.currentPositionIndex >= action.minimumPositionIndex else {
            return .failure("Requires Position \(action.minimumPositionIndex) or higher")
        }

        // Check track requirement
        if let requiredTrack = action.requiredTrack {
            guard game.currentExpandedTrack == requiredTrack else {
                return .failure("Requires \(requiredTrack) track")
            }
        }

        // Check cooldown
        let tracker = getCooldownTracker(for: game)
        if tracker.isOnCooldown(actionId: action.id, currentTurn: game.turnNumber) {
            let remaining = tracker.turnsRemaining(actionId: action.id, currentTurn: game.turnNumber)
            return .failure("On cooldown for \(remaining) more turn(s)")
        }

        // Check target requirement
        if action.targetType == .country && targetCountry == nil {
            return .failure("Must select a target country")
        }

        // Check treasury cost
        if action.successEffects.treasuryCost > 0 {
            guard game.treasury >= action.successEffects.treasuryCost else {
                return .failure("Insufficient treasury (need \(action.successEffects.treasuryCost))")
            }
        }

        // Calculate success chance
        let successChance = calculateSuccessChance(action, targetCountry: targetCountry, game: game)

        return .success(chance: successChance)
    }

    // MARK: - Success Calculation

    /// Calculate the success chance for an action
    func calculateSuccessChance(
        _ action: DiplomaticAction,
        targetCountry: ForeignCountry?,
        game: Game
    ) -> Int {
        var chance = action.baseSuccessChance

        // Bonus for higher position (each level above minimum = +5%)
        let positionBonus = (game.currentPositionIndex - action.minimumPositionIndex) * 5
        chance += positionBonus

        // Network bonus (connections help diplomacy)
        let networkBonus = min(10, game.network / 10)
        chance += networkBonus

        // Standing bonus (reputation matters)
        let standingBonus = min(5, game.standing / 20)
        chance += standingBonus

        // Target country relationship modifier
        if let country = targetCountry {
            // Better relations = easier positive actions
            if action.successEffects.relationshipChange > 0 {
                let relationshipBonus = country.relationshipScore / 10
                chance += relationshipBonus
            }
            // Better relations = harder negative actions
            else if action.successEffects.relationshipChange < 0 {
                let relationshipPenalty = country.relationshipScore / 15
                chance -= relationshipPenalty
            }

            // Ally bonus for friendly actions
            if country.politicalBloc == .socialist && action.successEffects.relationshipChange > 0 {
                chance += 10
            }

            // Penalty against powerful nations
            if country.militaryStrength > 70 {
                chance -= 5
            }

            // Intelligence level affects covert actions
            if action.id.contains("espionage") || action.id.contains("intel") {
                let intelBonus = country.ourIntelligenceAssets / 10
                chance += intelBonus
            }
        }

        // Risk level affects chance
        switch action.riskLevel {
        case .minimal: chance += 5
        case .low: chance += 0
        case .moderate: chance -= 5
        case .high: chance -= 10
        case .extreme: chance -= 15
        }

        return max(5, min(95, chance))
    }

    // MARK: - Execution

    /// Execute a diplomatic action
    func executeAction(
        _ action: DiplomaticAction,
        targetCountry: ForeignCountry?,
        for game: Game,
        modelContext: ModelContext
    ) -> ActionExecutionResult {
        // Final validation
        let validation = validateAction(action, targetCountry: targetCountry, for: game)
        guard validation.canExecute else {
            return ActionExecutionResult(
                succeeded: false,
                description: validation.reason ?? "Cannot execute action",
                effectsApplied: DiplomaticEffects(),
                triggeredEvents: [],
                pendingRecord: nil
            )
        }

        // Check if this is a multi-turn action
        if action.executionTurns > 0 {
            return initiateMultiTurnAction(action, targetCountry: targetCountry, game: game, modelContext: modelContext)
        }

        // Immediate execution
        return resolveAction(action, targetCountry: targetCountry, game: game, modelContext: modelContext, successChance: validation.successChance)
    }

    /// Initiate a multi-turn action (creates pending record)
    private func initiateMultiTurnAction(
        _ action: DiplomaticAction,
        targetCountry: ForeignCountry?,
        game: Game,
        modelContext: ModelContext
    ) -> ActionExecutionResult {
        // Create pending action record
        let record = DiplomaticActionRecord(
            actionId: action.id,
            actionName: action.name,
            targetCountryId: targetCountry?.countryId,
            targetBlocId: nil,
            initiatedTurn: game.turnNumber,
            completionTurn: game.turnNumber + action.executionTurns,
            initiatedBy: "player"
        )

        // Store pending action
        addPendingAction(record, for: game)

        // Set cooldown
        setCooldown(actionId: action.id, cooldownTurns: action.cooldownTurns, for: game)

        let description = "\(action.name) initiated. Will complete in \(action.executionTurns) turn(s)."

        return ActionExecutionResult(
            succeeded: false,
            description: description,
            effectsApplied: DiplomaticEffects(),
            triggeredEvents: [],
            pendingRecord: record
        )
    }

    /// Resolve an action (roll for success and apply effects)
    private func resolveAction(
        _ action: DiplomaticAction,
        targetCountry: ForeignCountry?,
        game: Game,
        modelContext: ModelContext,
        successChance: Int
    ) -> ActionExecutionResult {
        // Roll for success
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= successChance

        // Determine effects to apply
        let effects = succeeded ? action.successEffects : action.failureEffects

        // Apply effects
        var triggeredEvents: [String] = []

        applyEffects(effects, targetCountry: targetCountry, game: game)

        // Handle treaty creation
        if succeeded, let treatyType = effects.triggersTreaty, let country = targetCountry {
            createTreaty(type: treatyType, with: country, game: game)
            triggeredEvents.append("treaty_created_\(treatyType.rawValue)")
        }

        // Handle event triggering
        if let eventId = effects.triggersEvent {
            triggeredEvents.append(eventId)
        }

        // Set cooldown
        setCooldown(actionId: action.id, cooldownTurns: action.cooldownTurns, for: game)

        // Generate description
        let description = generateResultDescription(
            action: action,
            succeeded: succeeded,
            targetCountry: targetCountry,
            roll: roll,
            chance: successChance
        )

        return ActionExecutionResult(
            succeeded: succeeded,
            description: description,
            effectsApplied: effects,
            triggeredEvents: triggeredEvents,
            pendingRecord: nil
        )
    }

    // MARK: - Effect Application

    /// Apply diplomatic effects to the game state
    private func applyEffects(
        _ effects: DiplomaticEffects,
        targetCountry: ForeignCountry?,
        game: Game
    ) {
        // Apply relationship changes to target country
        if let country = targetCountry {
            country.modifyRelationship(by: effects.relationshipChange)
            country.diplomaticTension += effects.tensionChange
            country.diplomaticTension = max(0, min(100, country.diplomaticTension))

            // Intelligence changes
            country.ourIntelligenceAssets += effects.intelligenceChange
            country.ourIntelligenceAssets = max(0, min(100, country.ourIntelligenceAssets))
            country.espionageActivity += effects.counterIntelChange
            country.espionageActivity = max(0, min(100, country.espionageActivity))
        }

        // Apply bloc-wide relationship changes
        if effects.blocRelationshipChange != 0, let targetCountry = targetCountry {
            let bloc = targetCountry.politicalBloc
            for country in game.foreignCountries where country.politicalBloc == bloc && country.countryId != targetCountry.countryId {
                country.modifyRelationship(by: effects.blocRelationshipChange)
            }
        }

        // Apply treasury cost/gain
        game.treasury -= effects.treasuryCost

        // Apply player stat changes
        game.standing += effects.standingChange
        game.standing = max(0, min(100, game.standing))
        game.network += effects.networkChange
        game.network = max(0, min(100, game.network))

        // Handle game flags
        if let flag = effects.createsFlag {
            if !game.flags.contains(flag) {
                game.flags.append(flag)
            }
        }
        if let flag = effects.removesFlag {
            game.flags.removeAll { $0 == flag }
        }
    }

    /// Create a treaty with a foreign country
    private func createTreaty(type: TreatyType, with country: ForeignCountry, game: Game) {
        let treaty = ActiveTreaty(
            type: type,
            signedTurn: game.turnNumber,
            expirationTurn: nil,
            terms: "\(type.displayName) with \(country.name)",
            isSecret: false
        )
        country.addTreaty(treaty)
    }

    // MARK: - Result Description

    /// Generate a human-readable description of the action result
    private func generateResultDescription(
        action: DiplomaticAction,
        succeeded: Bool,
        targetCountry: ForeignCountry?,
        roll: Int,
        chance: Int
    ) -> String {
        let countryName = targetCountry?.name ?? "target"

        if succeeded {
            switch action.category {
            case .observer:
                return "Successfully completed \(action.name)."
            case .analyst:
                return "Your \(action.name.lowercased()) was well-received."
            case .departmental:
                return "Your proposal for \(action.name.lowercased()) has been approved."
            case .senior:
                return "Successfully negotiated \(action.name.lowercased()) with \(countryName)."
            case .executive:
                return "\(action.name) with \(countryName) executed successfully."
            case .supreme:
                return "Historic \(action.name.lowercased()) with \(countryName) achieved."
            }
        } else {
            let effects = action.failureEffects
            var description = "\(action.name) with \(countryName) failed."

            if effects.relationshipChange < 0 {
                description += " Relations have deteriorated."
            }
            if effects.tensionChange > 0 {
                description += " Tensions have increased."
            }
            if effects.standingChange < 0 {
                description += " Your standing has suffered."
            }

            return description
        }
    }

    // MARK: - Pending Actions

    /// Process pending actions at the start of a turn
    func processPendingActions(for game: Game, modelContext: ModelContext) -> [ActionExecutionResult] {
        var results: [ActionExecutionResult] = []
        var pendingActions = getPendingActions(for: game)

        for i in pendingActions.indices {
            if pendingActions[i].completionTurn <= game.turnNumber && !pendingActions[i].isComplete {
                // This action is ready to resolve
                guard let action = DiplomaticAction.action(withId: pendingActions[i].actionId) else { continue }

                let targetCountry: ForeignCountry? = pendingActions[i].targetCountryId.flatMap { targetId in
                    game.foreignCountries.first { $0.countryId == targetId }
                }

                let successChance = calculateSuccessChance(action, targetCountry: targetCountry, game: game)
                let result = resolveAction(action, targetCountry: targetCountry, game: game, modelContext: modelContext, successChance: successChance)

                // Update the pending record
                pendingActions[i].succeeded = result.succeeded
                pendingActions[i].resultDescription = result.description
                pendingActions[i].effectsApplied = result.effectsApplied

                results.append(result)
            }
        }

        // Save updated pending actions
        savePendingActions(pendingActions, for: game)

        return results
    }

    // MARK: - Cooldown Management

    private func getCooldownTracker(for game: Game) -> ActionCooldownTracker {
        guard let data = game.diplomaticCooldownsData else {
            return ActionCooldownTracker()
        }
        return (try? JSONDecoder().decode(ActionCooldownTracker.self, from: data)) ?? ActionCooldownTracker()
    }

    private func setCooldown(actionId: String, cooldownTurns: Int, for game: Game) {
        var tracker = getCooldownTracker(for: game)
        tracker.setCooldown(actionId: actionId, availableTurn: game.turnNumber + cooldownTurns)
        game.diplomaticCooldownsData = try? JSONEncoder().encode(tracker)
    }

    // MARK: - Pending Action Storage

    private func getPendingActions(for game: Game) -> [DiplomaticActionRecord] {
        guard let data = game.pendingDiplomaticActionsData else {
            return []
        }
        return (try? JSONDecoder().decode([DiplomaticActionRecord].self, from: data)) ?? []
    }

    private func addPendingAction(_ record: DiplomaticActionRecord, for game: Game) {
        var pending = getPendingActions(for: game)
        pending.append(record)
        game.pendingDiplomaticActionsData = try? JSONEncoder().encode(pending)
    }

    private func savePendingActions(_ actions: [DiplomaticActionRecord], for game: Game) {
        game.pendingDiplomaticActionsData = try? JSONEncoder().encode(actions)
    }

    // MARK: - Committee Approval

    /// Check if an action requires Standing Committee approval
    func requiresCommitteeApproval(_ action: DiplomaticAction, for game: Game) -> Bool {
        guard action.requiresCommitteeApproval else { return false }

        // General Secretary can decree if allowed
        if action.canBeDecree {
            if game.currentPositionIndex >= 7 {
                // Check if emergency powers or similar law allows bypass
                if game.hasFlag("emergency_powers_active") {
                    return false
                }
            }
        }

        return true
    }

    /// Submit an action for Standing Committee approval
    func submitForApproval(
        _ action: DiplomaticAction,
        targetCountry: ForeignCountry?,
        for game: Game
    ) {
        // This would integrate with the Standing Committee service
        // For now, we create a record that gets processed in committee
        let proposal = DiplomaticActionRecord(
            actionId: action.id,
            actionName: action.name,
            targetCountryId: targetCountry?.countryId,
            targetBlocId: nil,
            initiatedTurn: game.turnNumber,
            completionTurn: game.turnNumber + 1, // Committee votes next turn
            initiatedBy: "player"
        )

        addPendingAction(proposal, for: game)
    }
}

// MARK: - Game Extension for Diplomatic Action Storage

extension Game {
    /// Data storage for action cooldowns (uses variables dictionary)
    var diplomaticCooldownsData: Data? {
        get {
            guard let string = variables["_diplomatic_cooldowns"] else { return nil }
            return string.data(using: .utf8)
        }
        set {
            if let data = newValue, let string = String(data: data, encoding: .utf8) {
                variables["_diplomatic_cooldowns"] = string
            } else {
                variables.removeValue(forKey: "_diplomatic_cooldowns")
            }
        }
    }

    /// Data storage for pending diplomatic actions (uses variables dictionary)
    var pendingDiplomaticActionsData: Data? {
        get {
            guard let string = variables["_pending_diplomatic_actions"] else { return nil }
            return string.data(using: .utf8)
        }
        set {
            if let data = newValue, let string = String(data: data, encoding: .utf8) {
                variables["_pending_diplomatic_actions"] = string
            } else {
                variables.removeValue(forKey: "_pending_diplomatic_actions")
            }
        }
    }

    /// Check if a game flag is set
    func hasFlag(_ flag: String) -> Bool {
        flags.contains(flag)
    }
}
