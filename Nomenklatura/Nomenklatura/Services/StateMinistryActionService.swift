//
//  StateMinistryActionService.swift
//  Nomenklatura
//
//  Service for executing state ministry actions following State Council structure.
//  Handles administrative operations, budget management, and state project coordination.
//

import Foundation
import SwiftData

// MARK: - State Ministry Action Service

/// Main service for state ministry operations following State Council structure
final class StateMinistryActionService {
    static let shared = StateMinistryActionService()

    private init() {}

    // MARK: - Validation

    /// Result of action validation
    struct ValidationResult {
        let canExecute: Bool
        let reason: String?
        let successChance: Int
        let requiresApproval: Bool
    }

    /// Validate whether a state ministry action can be executed
    func validateAction(
        _ action: StateMinistryAction,
        targetMinistry: MinistryDepartment?,
        targetOfficial: GameCharacter?,
        for game: Game
    ) -> ValidationResult {
        let positionIndex = game.currentPositionIndex

        // Check position requirement
        guard positionIndex >= action.minimumPositionIndex else {
            return ValidationResult(
                canExecute: false,
                reason: "Requires Position \(action.minimumPositionIndex) (you are Position \(positionIndex))",
                successChance: 0,
                requiresApproval: false
            )
        }

        // Check track requirement - must be in State Ministry track (or top leadership 7+)
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInMinistryTrack = playerTrack == .stateMinistry
        let isTopLeadership = positionIndex >= 7  // Top leadership transcends tracks

        if !isInMinistryTrack && !isTopLeadership {
            return ValidationResult(
                canExecute: false,
                reason: "Requires State Ministry career track",
                successChance: 0,
                requiresApproval: false
            )
        }

        // Check cooldown
        let cooldowns = getMinistryCooldowns(for: game)
        if cooldowns.isOnCooldown(actionId: action.id, currentTurn: game.turnNumber) {
            let remaining = cooldowns.turnsRemaining(actionId: action.id, currentTurn: game.turnNumber)
            return ValidationResult(
                canExecute: false,
                reason: "On cooldown (\(remaining) turns remaining)",
                successChance: 0,
                requiresApproval: false
            )
        }

        // Check for active project limit (max 2 concurrent projects)
        if action.successEffects.initiatesProject {
            let projects = getActiveProjects(for: game)
            if projects.count >= 2 {
                return ValidationResult(
                    canExecute: false,
                    reason: "Maximum active projects reached (2)",
                    successChance: 0,
                    requiresApproval: action.requiresCommitteeApproval
                )
            }
        }

        // Target restrictions for personnel actions
        if let target = targetOfficial, action.targetType == .official {
            let targetPosition = target.positionIndex ?? 0
            // Can only recommend appointments for those below your position
            if targetPosition >= positionIndex && !action.requiresCommitteeApproval {
                return ValidationResult(
                    canExecute: false,
                    reason: "Cannot affect officials at or above your position without State Council approval",
                    successChance: 0,
                    requiresApproval: true
                )
            }
        }

        // Calculate success chance
        let successChance = calculateSuccessChance(
            action,
            targetMinistry: targetMinistry,
            targetOfficial: targetOfficial,
            for: game
        )

        return ValidationResult(
            canExecute: true,
            reason: nil,
            successChance: successChance,
            requiresApproval: action.requiresCommitteeApproval
        )
    }

    // MARK: - Success Chance Calculation

    /// Calculate success chance for a state ministry action
    func calculateSuccessChance(
        _ action: StateMinistryAction,
        targetMinistry: MinistryDepartment?,
        targetOfficial: GameCharacter?,
        for game: Game
    ) -> Int {
        var chance = action.baseSuccessChance
        let positionIndex = game.currentPositionIndex

        // Position bonus: +5% per level above minimum
        let positionBonus = (positionIndex - action.minimumPositionIndex) * 5
        chance += positionBonus

        // Network bonus: Up to +10% based on network stat (bureaucratic connections)
        let networkBonus = min(10, game.network / 10)
        chance += networkBonus

        // Standing bonus: Up to +8% based on standing (political capital)
        let standingBonus = min(8, game.standing / 12)
        chance += standingBonus

        // Stability affects administrative actions
        if game.stability > 60 {
            chance += 8  // Stable environment aids administration
        } else if game.stability < 30 {
            chance -= 10  // Chaos hampers bureaucracy
        }

        // Treasury affects budget-related actions
        if action.department == .finance || action.successEffects.treasuryChange != 0 {
            if game.treasury > 70 {
                chance += 5  // Plenty of resources
            } else if game.treasury < 30 {
                chance -= 10  // Budget constraints
            }
        }

        // Risk level modifier
        chance += action.riskLevel.successModifier

        // Department-specific modifiers
        chance += departmentSpecificModifier(action.department, for: game)

        // Target-specific modifiers
        if let target = targetOfficial {
            chance += targetDifficultyModifier(target: target, for: action)
        }

        // Commission actions are more authoritative
        if let dept = action.department, dept.isCommission {
            chance += 5
        }

        // Clamp to reasonable range
        return max(5, min(95, chance))
    }

    /// Get modifier based on department and game state
    private func departmentSpecificModifier(_ department: MinistryDepartment?, for game: Game) -> Int {
        guard let dept = department else { return 0 }

        switch dept {
        case .finance:
            // Finance work benefits from strong treasury
            return game.treasury > 50 ? 5 : (game.treasury < 30 ? -5 : 0)
        case .developmentReform:
            // Development commission benefits from industrial output
            return game.industrialOutput > 50 ? 5 : 0
        case .audit:
            // Audit work is easier when there's corruption to find
            return game.stability < 40 ? 5 : 0
        case .generalOffice:
            // General Office benefits from network (coordination role)
            return game.network > 50 ? 5 : 0
        case .humanResources:
            // HR work benefits from standing (influence over appointments)
            return game.standing > 50 ? 5 : 0
        case .commerce:
            // Commerce benefits from international standing
            return game.internationalStanding > 50 ? 5 : 0
        case .industry:
            // Industry benefits from industrial output
            return game.industrialOutput > 60 ? 5 : 0
        default:
            return 0
        }
    }

    /// Get difficulty modifier for targeting specific official
    private func targetDifficultyModifier(target: GameCharacter, for action: StateMinistryAction) -> Int {
        let targetPosition = target.positionIndex ?? 0
        var modifier = 0

        // Higher position targets are harder to affect
        modifier -= targetPosition * 3

        // Well-connected targets have more protection
        if target.fearLevel > 60 {
            modifier -= 10
        }

        // Targets with high disposition toward player are easier to work with
        if target.disposition > 30 {
            modifier += 10
        } else if target.disposition < -30 {
            modifier -= 10
        }

        return modifier
    }

    // MARK: - Action Execution

    /// Result of executing an action
    struct ExecutionResult {
        let succeeded: Bool
        let roll: Int
        let successChance: Int
        let description: String
        let effects: MinistryEffects
        let projectStarted: MinistryProject?
        let auditInitiated: Bool
        let reformInitiated: Bool
    }

    /// Execute a state ministry action
    func executeAction(
        _ action: StateMinistryAction,
        targetMinistry: MinistryDepartment?,
        targetOfficial: GameCharacter?,
        for game: Game,
        modelContext: ModelContext
    ) -> ExecutionResult {
        // Validate first
        let validation = validateAction(
            action,
            targetMinistry: targetMinistry,
            targetOfficial: targetOfficial,
            for: game
        )

        guard validation.canExecute else {
            return ExecutionResult(
                succeeded: false,
                roll: 0,
                successChance: 0,
                description: validation.reason ?? "Action cannot be executed",
                effects: MinistryEffects(),
                projectStarted: nil,
                auditInitiated: false,
                reformInitiated: false
            )
        }

        // Check if this is a multi-turn project
        if action.executionTurns > 1 && action.successEffects.initiatesProject {
            return initiateProject(
                action,
                targetMinistry: targetMinistry,
                successChance: validation.successChance,
                for: game
            )
        }

        // Immediate resolution
        return resolveAction(
            action,
            targetMinistry: targetMinistry,
            targetOfficial: targetOfficial,
            successChance: validation.successChance,
            for: game,
            modelContext: modelContext
        )
    }

    /// Initiate a multi-turn project
    private func initiateProject(
        _ action: StateMinistryAction,
        targetMinistry: MinistryDepartment?,
        successChance: Int,
        for game: Game
    ) -> ExecutionResult {
        // Create project record
        let project = MinistryProject(
            id: UUID(),
            actionId: action.id,
            name: action.name,
            description: action.detailedDescription,
            department: action.department ?? .generalOffice,
            targetMinistry: targetMinistry,
            initiatedTurn: game.turnNumber,
            completionTurn: game.turnNumber + action.executionTurns,
            successChance: successChance,
            phase: .planning,
            progress: 0
        )

        // Store project
        var projects = getActiveProjects(for: game)
        projects.append(project)
        saveActiveProjects(projects, for: game)

        // Set cooldown
        var cooldowns = getMinistryCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        saveMinistryCooldowns(cooldowns, for: game)

        return ExecutionResult(
            succeeded: true,
            roll: 0,
            successChance: successChance,
            description: "\(action.name) project initiated. Will complete in \(action.executionTurns) turn(s).",
            effects: MinistryEffects(),
            projectStarted: project,
            auditInitiated: false,
            reformInitiated: false
        )
    }

    /// Resolve an action immediately
    private func resolveAction(
        _ action: StateMinistryAction,
        targetMinistry: MinistryDepartment?,
        targetOfficial: GameCharacter?,
        successChance: Int,
        for game: Game,
        modelContext: ModelContext
    ) -> ExecutionResult {
        // Roll for success
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= successChance

        // Determine effects
        let effects = succeeded ? action.successEffects : action.failureEffects

        // Apply effects
        applyEffects(effects, targetOfficial: targetOfficial, for: game, modelContext: modelContext)

        // Set cooldown
        var cooldowns = getMinistryCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        saveMinistryCooldowns(cooldowns, for: game)

        // Generate description
        let description = generateResultDescription(
            action: action,
            succeeded: succeeded,
            targetMinistry: targetMinistry,
            targetOfficial: targetOfficial,
            effects: effects
        )

        return ExecutionResult(
            succeeded: succeeded,
            roll: roll,
            successChance: successChance,
            description: description,
            effects: effects,
            projectStarted: nil,
            auditInitiated: succeeded && effects.initiatesAudit,
            reformInitiated: succeeded && effects.initiatesReform
        )
    }

    // MARK: - Effect Application

    /// Apply ministry effects to game state
    private func applyEffects(
        _ effects: MinistryEffects,
        targetOfficial: GameCharacter?,
        for game: Game,
        modelContext: ModelContext
    ) {
        // State/national effects
        if effects.stabilityChange != 0 {
            game.applyStat("stability", change: effects.stabilityChange)
        }
        if effects.popularSupportChange != 0 {
            game.applyStat("popularSupport", change: effects.popularSupportChange)
        }
        if effects.treasuryChange != 0 {
            game.applyStat("treasury", change: effects.treasuryChange)
        }
        if effects.industrialOutputChange != 0 {
            game.applyStat("industrialOutput", change: effects.industrialOutputChange)
        }

        // Personal effects
        if effects.standingChange != 0 {
            game.applyStat("standing", change: effects.standingChange)
        }
        if effects.networkChange != 0 {
            game.applyStat("network", change: effects.networkChange)
        }
        if effects.patronFavorChange != 0 {
            game.applyStat("patronFavor", change: effects.patronFavorChange)
        }

        // Target effects
        if let target = targetOfficial {
            if effects.targetDispositionChange != 0 {
                target.disposition = max(-100, min(100, target.disposition + effects.targetDispositionChange))
            }
            if effects.targetStandingChange != 0 {
                // Simulate effect on target's standing - affects their fear/power level
                target.fearLevel = max(0, min(100, target.fearLevel + effects.targetStandingChange))
            }
        }

        // Flags
        if let flag = effects.createsFlag, !game.flags.contains(flag) {
            game.flags.append(flag)
        }
        if let flag = effects.removesFlag, let index = game.flags.firstIndex(of: flag) {
            game.flags.remove(at: index)
        }
    }

    // MARK: - Result Description

    /// Generate description of action result
    private func generateResultDescription(
        action: StateMinistryAction,
        succeeded: Bool,
        targetMinistry: MinistryDepartment?,
        targetOfficial: GameCharacter?,
        effects: MinistryEffects
    ) -> String {
        let categoryName = action.category.displayName

        if succeeded {
            var desc = "\(action.name) completed successfully at the \(categoryName) level."

            if let ministry = targetMinistry {
                desc += " The \(ministry.displayName) has been affected."
            }

            if let target = targetOfficial {
                if effects.targetDispositionChange > 0 {
                    desc += " \(target.name) is grateful for your support."
                }
            }

            if effects.initiatesReform {
                desc += " Administrative reforms have been initiated."
            }

            if effects.initiatesAudit {
                desc += " A formal audit has been launched."
            }

            if effects.initiatesProject {
                desc += " A major state project has begun."
            }

            if effects.treasuryChange > 0 {
                desc += " The ministry's budget has been secured."
            }

            if effects.standingChange > 0 {
                desc += " Your reputation in the bureaucracy has improved."
            }

            return desc
        } else {
            var desc = "\(action.name) failed."

            if action.department == .finance {
                desc += " Budget negotiations did not achieve desired results."
            } else if action.department == .audit {
                desc += " The audit encountered resistance or found insufficient evidence."
            } else if action.department == .developmentReform {
                desc += " The Development and Reform Commission could not advance the proposal."
            } else {
                desc += " Administrative obstacles blocked progress."
            }

            if effects.standingChange < 0 {
                desc += " Your bureaucratic standing has suffered."
            }

            return desc
        }
    }

    // MARK: - Project Management

    /// Advance all active projects by one turn
    func advanceProjects(for game: Game, modelContext: ModelContext) -> [MinistryProjectCompletionEvent] {
        var projects = getActiveProjects(for: game)
        var completionEvents: [MinistryProjectCompletionEvent] = []

        for i in projects.indices {
            projects[i].progress += 1

            // Update phase based on progress
            let totalTurns = projects[i].completionTurn - projects[i].initiatedTurn
            let progressPercent = Double(projects[i].progress) / Double(totalTurns)

            if progressPercent >= 0.75 {
                projects[i].phase = .completion
            } else if progressPercent >= 0.5 {
                projects[i].phase = .execution
            } else if progressPercent >= 0.25 {
                projects[i].phase = .implementation
            }

            // Check for completion
            if game.turnNumber >= projects[i].completionTurn {
                let event = completeProject(&projects[i], for: game, modelContext: modelContext)
                completionEvents.append(event)
            }
        }

        // Remove completed projects
        projects.removeAll { game.turnNumber >= $0.completionTurn }
        saveActiveProjects(projects, for: game)

        return completionEvents
    }

    /// Complete a project and determine outcome
    private func completeProject(
        _ project: inout MinistryProject,
        for game: Game,
        modelContext: ModelContext
    ) -> MinistryProjectCompletionEvent {
        // Roll for success
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= project.successChance

        // Get the original action
        guard let action = StateMinistryAction.allActions.first(where: { $0.id == project.actionId }) else {
            return MinistryProjectCompletionEvent(
                projectId: project.id,
                projectName: project.name,
                succeeded: false,
                description: "Project data corrupted",
                effects: MinistryEffects()
            )
        }

        let effects = succeeded ? action.successEffects : action.failureEffects
        applyEffects(effects, targetOfficial: nil, for: game, modelContext: modelContext)

        project.phase = succeeded ? .completed : .failed

        let description = succeeded
            ? "\(project.name) project completed successfully! The \(project.department.displayName) has achieved its objectives."
            : "\(project.name) project failed to meet targets. Administrative resources have been wasted."

        return MinistryProjectCompletionEvent(
            projectId: project.id,
            projectName: project.name,
            succeeded: succeeded,
            description: description,
            effects: effects
        )
    }

    // MARK: - NPC Autonomous Ministry Behavior

    /// Process autonomous state ministry NPC actions each turn
    func processNPCMinistryActions(game: Game, modelContext: ModelContext) -> [NPCMinistryEvent] {
        var events: [NPCMinistryEvent] = []

        // Get ministry officials (Position 2+)
        let ministryOfficials = game.characters.filter { character in
            character.isAlive &&
            (character.positionTrack == "stateMinistry" ||
             character.positionTrack == "government" ||
             character.positionTrack == "administrative") &&
            (character.positionIndex ?? 0) >= 2
        }

        for official in ministryOfficials {
            // 15% chance to take action each turn (government is methodical)
            guard Int.random(in: 1...100) <= 15 else { continue }

            if let actionPlan = evaluateNPCMinistryAction(for: official, game: game) {
                let event = executeNPCMinistryAction(actionPlan, by: official, game: game, modelContext: modelContext)
                events.append(event)
            }
        }

        return events
    }

    /// Evaluate what ministry action an NPC should take
    private func evaluateNPCMinistryAction(
        for character: GameCharacter,
        game: Game
    ) -> NPCMinistryActionPlan? {
        let position = character.positionIndex ?? 0

        // Priority actions based on state conditions

        // Low stability: push for administrative order
        if game.stability < 40 && position >= 3 {
            return NPCMinistryActionPlan(
                actionId: "implement_policy",
                targetMinistry: nil,
                targetOfficialId: nil,
                priority: 80
            )
        }

        // Low treasury: try to manage resources
        if game.treasury < 40 && position >= 4 {
            return NPCMinistryActionPlan(
                actionId: "negotiate_budget",
                targetMinistry: .finance,
                targetOfficialId: nil,
                priority: 75
            )
        }

        // Low industrial output: coordinate development
        if game.industrialOutput < 40 && position >= 5 {
            return NPCMinistryActionPlan(
                actionId: "coordinate_commission_work",
                targetMinistry: nil,
                targetOfficialId: nil,
                priority: 70
            )
        }

        // Standard administrative work
        if position >= 3 {
            return NPCMinistryActionPlan(
                actionId: "conduct_inspection",
                targetMinistry: MinistryDepartment.allCases.randomElement(),
                targetOfficialId: nil,
                priority: 40
            )
        }

        if position >= 2 {
            return NPCMinistryActionPlan(
                actionId: "coordinate_departments",
                targetMinistry: nil,
                targetOfficialId: nil,
                priority: 30
            )
        }

        return nil
    }

    /// Execute an NPC's planned ministry action
    private func executeNPCMinistryAction(
        _ plan: NPCMinistryActionPlan,
        by character: GameCharacter,
        game: Game,
        modelContext: ModelContext
    ) -> NPCMinistryEvent {
        guard let action = StateMinistryAction.allActions.first(where: { $0.id == plan.actionId }) else {
            return NPCMinistryEvent(
                characterId: character.id,
                characterName: character.name,
                actionId: plan.actionId,
                actionName: "Unknown Action",
                succeeded: false,
                description: "Action not found"
            )
        }

        // Find target if needed
        var targetOfficial: GameCharacter? = nil
        if let targetId = plan.targetOfficialId {
            targetOfficial = game.characters.first { $0.id == targetId }
        }

        // Simple success check for NPC actions
        let successChance = action.baseSuccessChance + (character.positionIndex ?? 0) * 5
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= successChance

        // Apply effects if succeeded
        if succeeded {
            let effects = action.successEffects
            applyEffects(effects, targetOfficial: targetOfficial, for: game, modelContext: modelContext)
        }

        let description = succeeded
            ? "\(character.name) successfully executed \(action.name)"
            : "\(character.name) attempted \(action.name) but failed"

        return NPCMinistryEvent(
            characterId: character.id,
            characterName: character.name,
            actionId: action.id,
            actionName: action.name,
            succeeded: succeeded,
            description: description
        )
    }

    // MARK: - Persistence Helpers

    /// Get ministry action cooldowns from game state
    func getMinistryCooldowns(for game: Game) -> MinistryCooldowns {
        guard let data = game.variables["ministry_cooldowns"],
              let jsonData = data.data(using: .utf8),
              let cooldowns = try? JSONDecoder().decode(MinistryCooldowns.self, from: jsonData) else {
            return MinistryCooldowns()
        }
        return cooldowns
    }

    /// Save ministry action cooldowns to game state
    func saveMinistryCooldowns(_ cooldowns: MinistryCooldowns, for game: Game) {
        if let data = try? JSONEncoder().encode(cooldowns),
           let string = String(data: data, encoding: .utf8) {
            game.variables["ministry_cooldowns"] = string
        }
    }

    /// Get active ministry projects from game state
    func getActiveProjects(for game: Game) -> [MinistryProject] {
        guard let data = game.variables["ministry_projects"],
              let jsonData = data.data(using: .utf8),
              let projects = try? JSONDecoder().decode([MinistryProject].self, from: jsonData) else {
            return []
        }
        return projects
    }

    /// Save active ministry projects to game state
    func saveActiveProjects(_ projects: [MinistryProject], for game: Game) {
        if let data = try? JSONEncoder().encode(projects),
           let string = String(data: data, encoding: .utf8) {
            game.variables["ministry_projects"] = string
        }
    }
}

// MARK: - Supporting Types

/// Cooldown tracking for ministry actions
struct MinistryCooldowns: Codable {
    var cooldowns: [String: Int] = [:]  // actionId: availableTurn

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
}

/// Active ministry project state
struct MinistryProject: Codable, Identifiable {
    let id: UUID
    let actionId: String
    let name: String
    let description: String
    let department: MinistryDepartment
    let targetMinistry: MinistryDepartment?
    let initiatedTurn: Int
    let completionTurn: Int
    let successChance: Int
    var phase: MinistryProjectPhase
    var progress: Int
}

/// Phase of a ministry project
enum MinistryProjectPhase: String, Codable {
    case planning           // Initial planning phase
    case implementation     // Beginning implementation
    case execution          // Active execution
    case completion         // Finalizing work
    case completed          // Successfully completed
    case failed             // Project failed

    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .implementation: return "Implementation"
        case .execution: return "Execution"
        case .completion: return "Completion"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

/// Event generated when a project completes
struct MinistryProjectCompletionEvent {
    let projectId: UUID
    let projectName: String
    let succeeded: Bool
    let description: String
    let effects: MinistryEffects
}

/// NPC ministry action plan
struct NPCMinistryActionPlan {
    let actionId: String
    let targetMinistry: MinistryDepartment?
    let targetOfficialId: UUID?
    let priority: Int
}

/// Event generated when NPC takes ministry action
struct NPCMinistryEvent {
    let characterId: UUID
    let characterName: String
    let actionId: String
    let actionName: String
    let succeeded: Bool
    let description: String
}
