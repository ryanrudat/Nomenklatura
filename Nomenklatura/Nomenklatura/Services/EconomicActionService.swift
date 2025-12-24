//
//  EconomicActionService.swift
//  Nomenklatura
//
//  Service for executing economic planning actions following Soviet Gosplan structure.
//  Handles quota setting, resource allocation, industrial projects, and NPC economic behavior.
//

import Foundation
import SwiftData

// MARK: - Economic Action Service

/// Main service for economic planning operations following Gosplan structure
final class EconomicActionService {
    static let shared = EconomicActionService()

    private init() {}

    // MARK: - Validation

    /// Result of action validation
    struct ValidationResult {
        let canExecute: Bool
        let reason: String?
        let successChance: Int
        let requiresApproval: Bool
        let treasuryCost: Int
    }

    /// Validate whether an action can be executed
    func validateAction(
        _ action: EconomicAction,
        targetSector: EconomicSector?,
        for game: Game
    ) -> ValidationResult {
        let positionIndex = game.currentPositionIndex

        // Check position requirement
        guard positionIndex >= action.minimumPositionIndex else {
            return ValidationResult(
                canExecute: false,
                reason: "Requires Position \(action.minimumPositionIndex) (you are Position \(positionIndex))",
                successChance: 0,
                requiresApproval: false,
                treasuryCost: 0
            )
        }

        // Check track requirement - must be in Economic Planning track (or top leadership 7+)
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInEconomicTrack = playerTrack == .economicPlanning
        let isTopLeadership = positionIndex >= 7  // Top leadership transcends tracks

        if !isInEconomicTrack && !isTopLeadership {
            return ValidationResult(
                canExecute: false,
                reason: "Requires Economic Planning career track",
                successChance: 0,
                requiresApproval: false,
                treasuryCost: 0
            )
        }

        // Check cooldown
        let cooldowns = getEconomicCooldowns(for: game)
        if cooldowns.isOnCooldown(actionId: action.id, currentTurn: game.turnNumber) {
            let remaining = cooldowns.turnsRemaining(actionId: action.id, currentTurn: game.turnNumber)
            return ValidationResult(
                canExecute: false,
                reason: "On cooldown (\(remaining) turns remaining)",
                successChance: 0,
                requiresApproval: false,
                treasuryCost: 0
            )
        }

        // Calculate treasury cost (negative treasuryChange means cost)
        let treasuryCost = action.successEffects.treasuryChange < 0
            ? abs(action.successEffects.treasuryChange)
            : 0

        if treasuryCost > 0 && game.treasury < treasuryCost {
            return ValidationResult(
                canExecute: false,
                reason: "Insufficient treasury (need \(treasuryCost), have \(game.treasury))",
                successChance: 0,
                requiresApproval: false,
                treasuryCost: treasuryCost
            )
        }

        // Check for active projects limit (max 3 concurrent projects)
        if action.successEffects.startsProject {
            let activeProjects = getActiveProjects(for: game)
            if activeProjects.count >= 3 {
                return ValidationResult(
                    canExecute: false,
                    reason: "Maximum concurrent projects reached (3)",
                    successChance: 0,
                    requiresApproval: action.requiresCommitteeApproval,
                    treasuryCost: treasuryCost
                )
            }
        }

        // Calculate success chance
        let successChance = calculateSuccessChance(action, targetSector: targetSector, for: game)

        return ValidationResult(
            canExecute: true,
            reason: nil,
            successChance: successChance,
            requiresApproval: action.requiresCommitteeApproval,
            treasuryCost: treasuryCost
        )
    }

    // MARK: - Success Chance Calculation

    /// Calculate success chance for an economic action
    func calculateSuccessChance(
        _ action: EconomicAction,
        targetSector: EconomicSector?,
        for game: Game
    ) -> Int {
        var chance = action.baseSuccessChance
        let positionIndex = game.currentPositionIndex

        // Position bonus: +5% per level above minimum
        let positionBonus = (positionIndex - action.minimumPositionIndex) * 5
        chance += positionBonus

        // Network bonus: Up to +8% based on network stat (planning connections)
        let networkBonus = min(8, game.network / 12)
        chance += networkBonus

        // Standing bonus: Up to +7% based on standing (political capital)
        let standingBonus = min(7, game.standing / 15)
        chance += standingBonus

        // Stability bonus/penalty: Economic actions easier in stable times
        if game.stability > 60 {
            chance += 5
        } else if game.stability < 30 {
            chance -= 10
        }

        // Industrial output affects production actions
        if action.category == .production {
            if game.industrialOutput > 60 {
                chance += 5
            } else if game.industrialOutput < 40 {
                chance -= 5
            }
        }

        // Risk level modifier
        chance += action.riskLevel.successModifier

        // Sector-specific modifiers
        if let sector = targetSector {
            chance += sectorDifficultyModifier(sector: sector, game: game)
        }

        // Clamp to reasonable range
        return max(5, min(95, chance))
    }

    /// Get difficulty modifier for targeting specific sector
    private func sectorDifficultyModifier(sector: EconomicSector, game: Game) -> Int {
        switch sector {
        case .agriculture:
            // Agriculture is harder if food supply is low
            return game.foodSupply < 40 ? -10 : 0
        case .heavyIndustry, .defense:
            // Heavy industry/defense benefits from high industrial output
            return game.industrialOutput > 60 ? 5 : -5
        case .energy, .mining:
            // Resource sectors are relatively stable
            return 0
        case .lightIndustry:
            // Consumer goods production harder during crises
            return game.stability < 40 ? -5 : 0
        case .construction, .transport:
            // Infrastructure projects need treasury
            return game.treasury < 50 ? -5 : 0
        }
    }

    // MARK: - Action Execution

    /// Result of executing an action
    struct ExecutionResult {
        let succeeded: Bool
        let roll: Int
        let successChance: Int
        let description: String
        let effects: EconomicEffects
        let projectStarted: EconomicProject?
        let quotaCompleted: Bool
    }

    /// Execute an economic action
    func executeAction(
        _ action: EconomicAction,
        targetSector: EconomicSector?,
        for game: Game,
        modelContext: ModelContext
    ) -> ExecutionResult {
        // Validate first
        let validation = validateAction(action, targetSector: targetSector, for: game)

        guard validation.canExecute else {
            return ExecutionResult(
                succeeded: false,
                roll: 0,
                successChance: 0,
                description: validation.reason ?? "Action cannot be executed",
                effects: EconomicEffects(),
                projectStarted: nil,
                quotaCompleted: false
            )
        }

        // Check if this is a multi-turn project
        if action.executionTurns > 1 && action.successEffects.startsProject {
            return initiateProject(action, targetSector: targetSector, successChance: validation.successChance, for: game)
        }

        // Immediate resolution
        return resolveAction(action, targetSector: targetSector, successChance: validation.successChance, for: game, modelContext: modelContext)
    }

    /// Initiate a multi-turn project
    private func initiateProject(
        _ action: EconomicAction,
        targetSector: EconomicSector?,
        successChance: Int,
        for game: Game
    ) -> ExecutionResult {
        // Create project record
        let project = EconomicProject(
            id: UUID(),
            actionId: action.id,
            name: action.name,
            description: action.detailedDescription,
            targetSector: targetSector,
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
        var cooldowns = getEconomicCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        saveEconomicCooldowns(cooldowns, for: game)

        // Apply immediate treasury cost if any
        if action.successEffects.treasuryChange < 0 {
            game.applyStat("treasury", change: action.successEffects.treasuryChange)
        }

        return ExecutionResult(
            succeeded: true,
            roll: 0,
            successChance: successChance,
            description: "\(action.name) project initiated. Will complete in \(action.executionTurns) turn(s).",
            effects: EconomicEffects(treasuryChange: action.successEffects.treasuryChange),
            projectStarted: project,
            quotaCompleted: false
        )
    }

    /// Resolve an action immediately
    private func resolveAction(
        _ action: EconomicAction,
        targetSector: EconomicSector?,
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
        applyEffects(effects, targetSector: targetSector, for: game, modelContext: modelContext)

        // Set cooldown
        var cooldowns = getEconomicCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        saveEconomicCooldowns(cooldowns, for: game)

        // Generate description
        let description = generateResultDescription(
            action: action,
            succeeded: succeeded,
            targetSector: targetSector,
            effects: effects
        )

        return ExecutionResult(
            succeeded: succeeded,
            roll: roll,
            successChance: successChance,
            description: description,
            effects: effects,
            projectStarted: nil,
            quotaCompleted: succeeded && effects.completesQuota
        )
    }

    // MARK: - Effect Application

    /// Apply economic effects to game state
    private func applyEffects(
        _ effects: EconomicEffects,
        targetSector: EconomicSector?,
        for game: Game,
        modelContext: ModelContext
    ) {
        // National economic effects
        if effects.treasuryChange != 0 {
            game.applyStat("treasury", change: effects.treasuryChange)
        }
        if effects.industrialOutputChange != 0 {
            game.applyStat("industrialOutput", change: effects.industrialOutputChange)
        }
        if effects.foodSupplyChange != 0 {
            game.applyStat("foodSupply", change: effects.foodSupplyChange)
        }
        if effects.stabilityChange != 0 {
            game.applyStat("stability", change: effects.stabilityChange)
        }

        // Support effects
        if effects.popularSupportChange != 0 {
            game.applyStat("popularSupport", change: effects.popularSupportChange)
        }
        if effects.eliteLoyaltyChange != 0 {
            game.applyStat("eliteLoyalty", change: effects.eliteLoyaltyChange)
        }
        if effects.militaryLoyaltyChange != 0 {
            game.applyStat("militaryLoyalty", change: effects.militaryLoyaltyChange)
        }

        // Personal effects
        if effects.standingChange != 0 {
            game.applyStat("standing", change: effects.standingChange)
        }
        if effects.networkChange != 0 {
            game.applyStat("network", change: effects.networkChange)
        }

        // International effects
        if effects.internationalStandingChange != 0 {
            game.applyStat("internationalStanding", change: effects.internationalStandingChange)
        }

        // Flags
        if let flag = effects.createsFlag, !game.flags.contains(flag) {
            game.flags.append(flag)
        }
        if let flag = effects.removesFlag, let index = game.flags.firstIndex(of: flag) {
            game.flags.remove(at: index)
        }

        // Handle shortage creation
        if effects.causesShortage, let sector = targetSector {
            createShortage(in: sector, for: game)
        }
    }

    /// Create a shortage in a sector
    private func createShortage(in sector: EconomicSector, for game: Game) {
        let shortageFlag = "shortage_\(sector.rawValue)"
        if !game.flags.contains(shortageFlag) {
            game.flags.append(shortageFlag)
        }
        // Shortages reduce popular support
        game.applyStat("popularSupport", change: -5)
    }

    // MARK: - Project Management

    /// Advance all active projects by one turn
    func advanceProjects(for game: Game, modelContext: ModelContext) -> [ProjectCompletionEvent] {
        var projects = getActiveProjects(for: game)
        var completionEvents: [ProjectCompletionEvent] = []

        for i in projects.indices {
            projects[i].progress += 1

            // Update phase based on progress
            let totalTurns = projects[i].completionTurn - projects[i].initiatedTurn
            let progressPercent = Double(projects[i].progress) / Double(totalTurns)

            if progressPercent >= 0.75 {
                projects[i].phase = .implementation
            } else if progressPercent >= 0.5 {
                projects[i].phase = .construction
            } else if progressPercent >= 0.25 {
                projects[i].phase = .resourceAllocation
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
        _ project: inout EconomicProject,
        for game: Game,
        modelContext: ModelContext
    ) -> ProjectCompletionEvent {
        // Roll for success
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= project.successChance

        // Get the original action
        guard let action = EconomicAction.allActions.first(where: { $0.id == project.actionId }) else {
            return ProjectCompletionEvent(
                projectId: project.id,
                projectName: project.name,
                succeeded: false,
                description: "Project data corrupted",
                effects: EconomicEffects()
            )
        }

        let effects = succeeded ? action.successEffects : action.failureEffects

        // Apply effects (treasury already paid at initiation)
        var adjustedEffects = effects
        adjustedEffects.treasuryChange = 0 // Already paid
        applyEffects(adjustedEffects, targetSector: project.targetSector, for: game, modelContext: modelContext)

        project.phase = succeeded ? .completed : .failed

        let description = succeeded
            ? "\(project.name) completed successfully! Production capacity increased."
            : "\(project.name) failed to meet objectives. Resources wasted."

        return ProjectCompletionEvent(
            projectId: project.id,
            projectName: project.name,
            succeeded: succeeded,
            description: description,
            effects: adjustedEffects
        )
    }

    // MARK: - NPC Autonomous Economic Behavior

    /// Process autonomous economic NPC actions each turn
    func processNPCEconomicActions(game: Game, modelContext: ModelContext) -> [NPCEconomicEvent] {
        var events: [NPCEconomicEvent] = []

        // Get economic planning officials (Position 2+)
        let economicOfficials = game.characters.filter { character in
            character.isAlive &&
            character.positionTrack == "economicPlanning" &&
            (character.positionIndex ?? 0) >= 2
        }

        for official in economicOfficials {
            // 20% chance to take action each turn
            guard Int.random(in: 1...100) <= 20 else { continue }

            if let actionPlan = evaluateNPCEconomicAction(for: official, game: game) {
                let event = executeNPCEconomicAction(actionPlan, by: official, game: game, modelContext: modelContext)
                events.append(event)
            }
        }

        return events
    }

    /// Evaluate what economic action an NPC should take
    private func evaluateNPCEconomicAction(
        for character: GameCharacter,
        game: Game
    ) -> NPCEconomicActionPlan? {
        let position = character.positionIndex ?? 0

        // Priority actions based on economic state
        if game.industrialOutput < 40 && position >= 3 {
            return NPCEconomicActionPlan(
                actionId: "prioritize_sector",
                targetSector: .heavyIndustry,
                priority: 70
            )
        }

        if game.foodSupply < 35 && position >= 3 {
            return NPCEconomicActionPlan(
                actionId: "emergency_requisition",
                targetSector: .agriculture,
                priority: 80
            )
        }

        // Routine quota setting
        if position >= 2 {
            return NPCEconomicActionPlan(
                actionId: "set_regional_quota",
                targetSector: EconomicSector.allCases.randomElement(),
                priority: 40
            )
        }

        // Production actions at lower levels
        if position >= 1 {
            return NPCEconomicActionPlan(
                actionId: "meet_quota",
                targetSector: nil,
                priority: 30
            )
        }

        return nil
    }

    /// Execute an NPC economic action
    private func executeNPCEconomicAction(
        _ plan: NPCEconomicActionPlan,
        by character: GameCharacter,
        game: Game,
        modelContext: ModelContext
    ) -> NPCEconomicEvent {
        guard let action = EconomicAction.allActions.first(where: { $0.id == plan.actionId }) else {
            return NPCEconomicEvent(
                id: UUID().uuidString,
                turn: game.turnNumber,
                characterId: character.id.uuidString,
                characterName: character.name,
                actionId: plan.actionId,
                targetSector: plan.targetSector,
                success: false,
                description: "Action not found"
            )
        }

        // Calculate success
        let successChance = calculateSuccessChance(action, targetSector: plan.targetSector, for: game)
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= successChance

        // Apply effects if succeeded
        if succeeded {
            applyEffects(action.successEffects, targetSector: plan.targetSector, for: game, modelContext: modelContext)
        } else {
            applyEffects(action.failureEffects, targetSector: plan.targetSector, for: game, modelContext: modelContext)
        }

        let description = generateNPCActionDescription(
            action: action,
            character: character,
            targetSector: plan.targetSector,
            succeeded: succeeded
        )

        return NPCEconomicEvent(
            id: UUID().uuidString,
            turn: game.turnNumber,
            characterId: character.id.uuidString,
            characterName: character.name,
            actionId: action.id,
            targetSector: plan.targetSector,
            success: succeeded,
            description: description
        )
    }

    /// Generate description for NPC action
    private func generateNPCActionDescription(
        action: EconomicAction,
        character: GameCharacter,
        targetSector: EconomicSector?,
        succeeded: Bool
    ) -> String {
        let title = character.title ?? "Planning Official"
        let sectorName = targetSector?.displayName ?? "national economy"

        if succeeded {
            switch action.id {
            case "meet_quota":
                return "\(title) \(character.name) reported quota fulfillment for \(sectorName)."
            case "set_regional_quota":
                return "\(title) \(character.name) established new production targets for \(sectorName)."
            case "prioritize_sector":
                return "Resources redirected to \(sectorName) by order of \(character.name)."
            case "emergency_requisition":
                return "Emergency requisition for \(sectorName) approved by \(character.name)."
            default:
                return "\(character.name) executed economic action: \(action.name)"
            }
        } else {
            return "\(character.name) attempted \(action.name.lowercased()) but quotas were not met."
        }
    }

    // MARK: - Helper: Result Description

    private func generateResultDescription(
        action: EconomicAction,
        succeeded: Bool,
        targetSector: EconomicSector?,
        effects: EconomicEffects
    ) -> String {
        let sectorName = targetSector?.displayName ?? "the economy"

        if succeeded {
            switch action.id {
            case "report_production":
                return "Production report filed. Your accurate reporting is noted."
            case "meet_quota":
                return "Quota fulfilled! Production targets for this period have been met."
            case "exceed_quota":
                return "Stakhanovite achievement! You have exceeded the quota by a significant margin."
            case "falsify_reports":
                return "Reports submitted showing quota fulfillment. Let us hope no audit comes."
            case "five_year_plan":
                return "The Five-Year Plan has been adopted. The nation looks to your vision."
            case "economic_decree":
                return "Your economic decree has been issued and takes immediate effect."
            case "command_economy_reform":
                return "Historic reform! The command economy enters a new phase."
            default:
                return "\(action.name) completed successfully."
            }
        } else {
            switch action.id {
            case "meet_quota":
                return "Quota not met. Shortfalls must be explained to superiors."
            case "exceed_quota":
                return "Stakhanovite targets not achieved. Production fell short of heroic goals."
            case "falsify_reports":
                return "Audit detected discrepancies. You face serious consequences."
            default:
                return "\(action.name) failed. The \(sectorName) suffers the consequences."
            }
        }
    }

    // MARK: - Storage Helpers

    func getEconomicCooldowns(for game: Game) -> EconomicCooldownTracker {
        guard let data = game.variables["economic_cooldowns"],
              let jsonData = data.data(using: .utf8),
              let tracker = try? JSONDecoder().decode(EconomicCooldownTracker.self, from: jsonData) else {
            return EconomicCooldownTracker()
        }
        return tracker
    }

    private func saveEconomicCooldowns(_ tracker: EconomicCooldownTracker, for game: Game) {
        if let data = try? JSONEncoder().encode(tracker),
           let string = String(data: data, encoding: .utf8) {
            game.variables["economic_cooldowns"] = string
        }
    }

    func getActiveProjects(for game: Game) -> [EconomicProject] {
        guard let data = game.variables["economic_projects"],
              let jsonData = data.data(using: .utf8),
              let projects = try? JSONDecoder().decode([EconomicProject].self, from: jsonData) else {
            return []
        }
        return projects
    }

    private func saveActiveProjects(_ projects: [EconomicProject], for game: Game) {
        if let data = try? JSONEncoder().encode(projects),
           let string = String(data: data, encoding: .utf8) {
            game.variables["economic_projects"] = string
        }
    }
}

// MARK: - Supporting Types

/// Cooldown tracking for economic actions
struct EconomicCooldownTracker: Codable {
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
}

/// An active economic project
struct EconomicProject: Identifiable, Codable {
    let id: UUID
    let actionId: String
    let name: String
    let description: String
    let targetSector: EconomicSector?
    let initiatedTurn: Int
    let completionTurn: Int
    let successChance: Int
    var phase: ProjectPhase
    var progress: Int
}

/// Phases of an economic project
enum ProjectPhase: String, Codable {
    case planning               // Initial planning phase
    case resourceAllocation     // Gathering resources
    case construction           // Active construction/implementation
    case implementation         // Final implementation phase
    case completed              // Successfully completed
    case failed                 // Failed to complete
}

/// Event when project completes
struct ProjectCompletionEvent: Identifiable, Codable {
    var id: UUID { projectId }
    let projectId: UUID
    let projectName: String
    let succeeded: Bool
    let description: String
    let effects: EconomicEffects
}

/// Plan for NPC economic action
struct NPCEconomicActionPlan {
    let actionId: String
    let targetSector: EconomicSector?
    let priority: Int
}

/// Event generated by NPC economic action
struct NPCEconomicEvent: Identifiable, Codable {
    let id: String
    let turn: Int
    let characterId: String
    let characterName: String
    let actionId: String
    let targetSector: EconomicSector?
    let success: Bool
    let description: String
}

// MARK: - Risk Level Extension

extension EconomicRiskLevel {
    /// Success chance modifier based on risk level
    var successModifier: Int {
        switch self {
        case .routine: return 10
        case .moderate: return 0
        case .significant: return -5
        case .major: return -10
        case .systemic: return -15
        }
    }
}
