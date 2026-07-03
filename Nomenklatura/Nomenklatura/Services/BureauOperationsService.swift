//
//  BureauOperationsService.swift
//  Nomenklatura
//
//  Unified service for aggregating bureau operations across all three core bureaus.
//  Maps existing action services (Security, Economic, Party) to unified operation views.
//

import Foundation
import SwiftData

// MARK: - Bureau Operations Service

/// Unified service for accessing bureau operations, activity, and tasks
final class BureauOperationsService {
    static let shared = BureauOperationsService()

    private init() {}

    // MARK: - Active Operations

    /// Get all active operations for a bureau
    func getActiveOperations(for bureau: ExpandedCareerTrack, game: Game) -> [BureauOperation] {
        switch bureau {
        case .securityServices:
            return getSecurityOperations(for: game)
        case .economicPlanning:
            return getEconomicOperations(for: game)
        case .partyApparatus:
            return getPartyOperations(for: game)
        default:
            return []
        }
    }

    /// Get all active operations across all bureaus (for top leadership view)
    func getAllActiveOperations(for game: Game) -> [BureauOperation] {
        var operations: [BureauOperation] = []
        operations.append(contentsOf: getSecurityOperations(for: game))
        operations.append(contentsOf: getEconomicOperations(for: game))
        operations.append(contentsOf: getPartyOperations(for: game))
        return operations.sorted { $0.initiatedTurn > $1.initiatedTurn }
    }

    // MARK: - Security Operations Mapping

    private func getSecurityOperations(for game: Game) -> [BureauOperation] {
        var operations: [BureauOperation] = []

        // Map pending/in-progress security actions
        let pendingActions = SecurityActionService.shared.getPendingActions(for: game)
        for record in pendingActions where record.status == .inProgress || record.status == .pending {
            let operation = mapSecurityRecord(record, for: game)
            operations.append(operation)
        }

        // Map active detentions
        let detentions = SecurityActionService.shared.getActiveDetentions(for: game)
        for detention in detentions where detention.outcome == nil {
            let operation = mapDetention(detention, for: game)
            operations.append(operation)
        }

        return operations
    }

    private func mapSecurityRecord(_ record: SecurityActionRecord, for game: Game) -> BureauOperation {
        // Get action details
        let action = SecurityAction.action(withId: record.actionId)
        let name = action?.name ?? "Security Operation"

        // Determine operation type
        let operationType: BureauOperationType
        switch record.actionId {
        case let id where id.contains("investigation"):
            operationType = .investigation
        case let id where id.contains("surveillance"):
            operationType = .surveillance
        case let id where id.contains("detention"), let id where id.contains("shuanggui"):
            operationType = .detention
        case let id where id.contains("interrogation"):
            operationType = .interrogation
        case let id where id.contains("purge"):
            operationType = .purge
        default:
            operationType = .investigation
        }

        // Calculate progress
        let totalTurns = record.completionTurn - record.initiatedTurn
        let elapsed = game.turnNumber - record.initiatedTurn
        let progress = totalTurns > 0 ? min(100, (elapsed * 100) / totalTurns) : 0

        return BureauOperation(
            id: record.id,
            bureauTrack: ExpandedCareerTrack.securityServices.rawValue,
            operationType: operationType,
            name: name,
            description: action?.description ?? "Active security operation",
            initiatedTurn: record.initiatedTurn,
            targetCompletionTurn: record.completionTurn,
            progress: progress,
            status: mapSecurityStatus(record.status),
            targetCharacterId: record.targetCharacterId,
            targetCharacterName: getCharacterName(id: record.targetCharacterId, game: game),
            targetDepartment: record.targetDepartment,
            successChance: record.successChance,
            riskLevel: mapRiskLevel(from: action?.riskLevel),
            sourceActionId: record.actionId,
            sourceRecordId: record.id
        )
    }

    private func mapDetention(_ detention: ShuangguiDetention, for game: Game) -> BureauOperation {
        // Calculate progress based on phase
        let progress: Int
        switch detention.phase {
        case .isolation: progress = 15
        case .interrogation: progress = 35
        case .confession: progress = 60
        case .documentation: progress = 80
        case .referral: progress = 95
        }

        let status: OperationStatus
        if detention.confessionObtained {
            status = .awaitingApproval  // Ready for player decision
        } else {
            status = .inProgress
        }

        return BureauOperation(
            id: detention.id,
            bureauTrack: ExpandedCareerTrack.securityServices.rawValue,
            operationType: .detention,
            name: "Detention: \(detention.targetName)",
            description: "Subject held under special measures regulations. Phase: \(detention.phase.rawValue.capitalized)",
            initiatedTurn: detention.initiatedTurn,
            targetCompletionTurn: nil,
            progress: progress,
            status: status,
            targetCharacterId: detention.targetCharacterId,
            targetCharacterName: detention.targetName,
            successChance: detention.evidenceAccumulated,
            riskLevel: detention.targetPosition >= 5 ? .critical : .high
        )
    }

    // MARK: - Economic Operations Mapping

    private func getEconomicOperations(for game: Game) -> [BureauOperation] {
        var operations: [BureauOperation] = []

        // Map active projects
        let projects = EconomicActionService.shared.getActiveProjects(for: game)
        for project in projects {
            let operation = mapEconomicProject(project, for: game)
            operations.append(operation)
        }

        return operations
    }

    private func mapEconomicProject(_ project: EconomicProject, for game: Game) -> BureauOperation {
        // Determine operation type
        let operationType: BureauOperationType
        switch project.actionId {
        case let id where id.contains("quota"):
            operationType = .productionQuota
        case let id where id.contains("allocat"):
            operationType = .resourceAllocation
        case let id where id.contains("project"), let id where id.contains("industrial"):
            operationType = .industrialProject
        case let id where id.contains("five_year"):
            operationType = .fiveYearPlanTarget
        case let id where id.contains("inspection"):
            operationType = .inspectionCampaign
        default:
            operationType = .industrialProject
        }

        // Calculate progress
        let totalTurns = project.completionTurn - project.initiatedTurn
        let progress = totalTurns > 0 ? min(100, (project.progress * 100) / totalTurns) : project.progress

        let status: OperationStatus
        switch project.phase {
        case .completed: status = .completed
        case .failed: status = .failed
        default: status = .inProgress
        }

        return BureauOperation(
            id: project.id,
            bureauTrack: ExpandedCareerTrack.economicPlanning.rawValue,
            operationType: operationType,
            name: project.name,
            description: project.description,
            initiatedTurn: project.initiatedTurn,
            targetCompletionTurn: project.completionTurn,
            progress: progress,
            status: status,
            targetRegionName: project.targetSector?.displayName,
            successChance: project.successChance,
            riskLevel: .moderate,
            sourceActionId: project.actionId,
            sourceRecordId: project.id
        )
    }

    // MARK: - Party Operations Mapping

    private func getPartyOperations(for game: Game) -> [BureauOperation] {
        var operations: [BureauOperation] = []

        // Map active campaigns
        let campaigns = PartyActionService.shared.getActiveCampaigns(for: game)
        for campaign in campaigns {
            let operation = mapPartyCampaign(campaign, for: game)
            operations.append(operation)
        }

        return operations
    }

    private func mapPartyCampaign(_ campaign: PartyCampaign, for game: Game) -> BureauOperation {
        // Determine operation type
        let operationType: BureauOperationType
        switch campaign.actionId {
        case let id where id.contains("ideological"), let id where id.contains("propaganda"):
            operationType = .ideologicalCampaign
        case let id where id.contains("personnel"), let id where id.contains("review"):
            operationType = .personnelReview
        case let id where id.contains("rectification"):
            operationType = .rectificationMovement
        case let id where id.contains("education"), let id where id.contains("study"):
            operationType = .partyEducation
        case let id where id.contains("faction"), let id where id.contains("maneuver"):
            operationType = .factionManeuver
        default:
            operationType = .ideologicalCampaign
        }

        // Calculate progress
        let totalTurns = campaign.completionTurn - campaign.initiatedTurn
        let progress = totalTurns > 0 ? min(100, (campaign.progress * 100) / totalTurns) : campaign.progress

        let status: OperationStatus
        switch campaign.phase {
        case .concluded: status = .completed
        case .failed: status = .failed
        default: status = .inProgress
        }

        return BureauOperation(
            id: campaign.id,
            bureauTrack: ExpandedCareerTrack.partyApparatus.rawValue,
            operationType: operationType,
            name: campaign.name,
            description: campaign.description,
            initiatedTurn: campaign.initiatedTurn,
            targetCompletionTurn: campaign.completionTurn,
            progress: progress,
            status: status,
            targetDepartment: campaign.targetDepartment,
            successChance: campaign.successChance,
            riskLevel: operationType == .rectificationMovement ? .critical : .moderate,
            sourceActionId: campaign.actionId,
            sourceRecordId: campaign.id
        )
    }

    // MARK: - Activity Feed

    /// Get recent activity entries for a bureau
    func getRecentActivity(for bureau: ExpandedCareerTrack, game: Game, limit: Int = 10) -> [BureauActivityEntry] {
        var entries: [BureauActivityEntry] = []

        // Generate entries from completed operations and significant events
        switch bureau {
        case .securityServices:
            entries = getSecurityActivity(for: game, limit: limit)
        case .economicPlanning:
            entries = getEconomicActivity(for: game, limit: limit)
        case .partyApparatus:
            entries = getPartyActivity(for: game, limit: limit)
        default:
            break
        }

        return entries.sorted { $0.turn > $1.turn }.prefix(limit).map { $0 }
    }

    private func getSecurityActivity(for game: Game, limit: Int) -> [BureauActivityEntry] {
        var entries: [BureauActivityEntry] = []

        // Get completed/resolved actions from pending actions
        let pendingActions = SecurityActionService.shared.getPendingActions(for: game)
        for record in pendingActions {
            let entryType: ActivityEntryType
            let title: String
            let wasSuccess: Bool?

            switch record.status {
            case .completed:
                let succeeded = record.result?.succeeded ?? true
                entryType = succeeded ? .operationCompleted : .operationFailed
                title = succeeded ? "Operation Completed" : "Operation Failed"
                wasSuccess = succeeded
            case .pending:
                entryType = .operationStarted
                title = "Operation Initiated"
                wasSuccess = nil
            case .cancelled, .blocked:
                entryType = .operationFailed
                title = record.status == .cancelled ? "Operation Cancelled" : "Operation Blocked"
                wasSuccess = false
            case .inProgress, .awaitingApproval:
                continue  // Skip in-progress items for activity feed
            }

            let action = SecurityAction.action(withId: record.actionId)
            entries.append(BureauActivityEntry(
                id: UUID(),
                bureauTrack: ExpandedCareerTrack.securityServices.rawValue,
                turn: record.initiatedTurn,
                entryType: entryType,
                title: title,
                description: action?.name ?? record.actionId,
                relatedOperationId: record.id,
                wasSuccess: wasSuccess
            ))
        }

        // Get detention events
        let detentions = SecurityActionService.shared.getActiveDetentions(for: game)
        for detention in detentions {
            if detention.confessionObtained {
                entries.append(BureauActivityEntry(
                    id: UUID(),
                    bureauTrack: ExpandedCareerTrack.securityServices.rawValue,
                    turn: detention.initiatedTurn + detention.turnsInDetention,
                    entryType: .approvalGranted,
                    title: "Confession Obtained",
                    description: "\(detention.targetName) has confessed during interrogation",
                    wasSuccess: true
                ))
            }
        }

        return entries
    }

    private func getEconomicActivity(for game: Game, limit: Int) -> [BureauActivityEntry] {
        var entries: [BureauActivityEntry] = []

        // Get project events
        let projects = EconomicActionService.shared.getActiveProjects(for: game)
        for project in projects {
            let entryType: ActivityEntryType
            let title: String

            switch project.phase {
            case .completed:
                entryType = .operationCompleted
                title = "Project Completed"
            case .failed:
                entryType = .operationFailed
                title = "Project Failed"
            case .planning:
                entryType = .operationStarted
                title = "Project Initiated"
            default:
                // Track phase transitions
                entryType = .resourceAllocated
                title = "Project Phase: \(project.phase.rawValue.capitalized)"
            }

            entries.append(BureauActivityEntry(
                id: UUID(),
                bureauTrack: ExpandedCareerTrack.economicPlanning.rawValue,
                turn: project.initiatedTurn,
                entryType: entryType,
                title: title,
                description: project.name,
                relatedOperationId: project.id,
                wasSuccess: project.phase == .completed
            ))
        }

        return entries
    }

    private func getPartyActivity(for game: Game, limit: Int) -> [BureauActivityEntry] {
        var entries: [BureauActivityEntry] = []

        // Get campaign events
        let campaigns = PartyActionService.shared.getActiveCampaigns(for: game)
        for campaign in campaigns {
            let entryType: ActivityEntryType
            let title: String

            switch campaign.phase {
            case .concluded:
                entryType = .campaignCompleted
                title = "Campaign Concluded"
            case .failed:
                entryType = .operationFailed
                title = "Campaign Failed"
            case .preparation:
                entryType = .campaignLaunched
                title = "Campaign Launched"
            default:
                entryType = .operationProgress
                title = "Campaign Phase: \(campaign.phase.rawValue.capitalized)"
            }

            entries.append(BureauActivityEntry(
                id: UUID(),
                bureauTrack: ExpandedCareerTrack.partyApparatus.rawValue,
                turn: campaign.initiatedTurn,
                entryType: entryType,
                title: title,
                description: campaign.name,
                relatedOperationId: campaign.id,
                wasSuccess: campaign.phase == .concluded
            ))
        }

        return entries
    }

    // MARK: - Available Tasks

    /// Get available tasks for a bureau based on player position and cooldowns
    func getAvailableTasks(for bureau: ExpandedCareerTrack, game: Game) -> [BureauTask] {
        let baseTasks = BureauTask.tasks(for: bureau)
        let positionIndex = game.currentPositionIndex
        let affinity = getBureauAffinity(bureau: bureau, game: game)

        return baseTasks.map { task in
            var mutableTask = task

            // Check position requirement
            if positionIndex < task.minimumPosition {
                mutableTask.isAvailable = false
                mutableTask.unavailableReason = "Requires position level \(task.minimumPosition)"
            }

            // Check affinity requirement
            else if affinity < task.requiredAffinity {
                mutableTask.isAvailable = false
                mutableTask.unavailableReason = "Requires \(task.requiredAffinity)% bureau affinity"
            }

            // Check cooldown
            else {
                let cooldownRemaining = getCooldownRemaining(
                    actionId: task.actionId,
                    bureau: bureau,
                    game: game
                )
                mutableTask.cooldownRemaining = cooldownRemaining
                if cooldownRemaining > 0 {
                    mutableTask.isAvailable = false
                    mutableTask.unavailableReason = "Available in \(cooldownRemaining) turn(s)"
                }
            }

            return mutableTask
        }
    }

    /// Get cooldown remaining for an action
    private func getCooldownRemaining(actionId: String, bureau: ExpandedCareerTrack, game: Game) -> Int {
        switch bureau {
        case .securityServices:
            let cooldowns = SecurityActionService.shared.getSecurityCooldowns(for: game)
            return cooldowns.turnsRemaining(actionId: actionId, currentTurn: game.turnNumber)
        case .economicPlanning:
            let cooldowns = EconomicActionService.shared.getEconomicCooldowns(for: game)
            return cooldowns.turnsRemaining(actionId: actionId, currentTurn: game.turnNumber)
        case .partyApparatus:
            let cooldowns = PartyActionService.shared.getPartyCooldowns(for: game)
            return cooldowns.turnsRemaining(actionId: actionId, currentTurn: game.turnNumber)
        default:
            return 0
        }
    }

    /// Get player's affinity with a bureau
    private func getBureauAffinity(bureau: ExpandedCareerTrack, game: Game) -> Int {
        let scores = game.trackAffinityScores
        switch bureau {
        case .securityServices:
            return scores.securityServices
        case .economicPlanning:
            return scores.economicPlanning
        case .partyApparatus:
            return scores.partyApparatus
        default:
            return 0
        }
    }

    // MARK: - Helper Methods

    private func mapSecurityStatus(_ status: SecurityActionRecord.SecurityActionStatus) -> OperationStatus {
        switch status {
        case .pending: return .pending
        case .inProgress: return .inProgress
        case .awaitingApproval: return .awaitingApproval
        case .completed: return .completed
        case .cancelled: return .cancelled
        case .blocked: return .failed
        }
    }

    private func mapRiskLevel(from securityRisk: SecurityRiskLevel?) -> BureauRiskLevel {
        guard let risk = securityRisk else { return .moderate }
        switch risk {
        case .minimal: return .minimal
        case .low: return .low
        case .moderate: return .moderate
        case .high: return .high
        case .extreme: return .critical
        }
    }

    private func getCharacterName(id: String?, game: Game) -> String? {
        guard let characterId = id else { return nil }
        return game.characters.first { $0.id.uuidString == characterId }?.name
    }

    // MARK: - Task Execution

    /// Unified result for bureau task execution
    struct TaskExecutionResult {
        let succeeded: Bool
        let roll: Int
        let successChance: Int
        let description: String
        let networkCostApplied: Int
        let operationInitiated: Bool
        let errorMessage: String?

        static func failure(_ message: String) -> TaskExecutionResult {
            TaskExecutionResult(
                succeeded: false,
                roll: 0,
                successChance: 0,
                description: message,
                networkCostApplied: 0,
                operationInitiated: false,
                errorMessage: message
            )
        }

        func withNetworkCostApplied(_ networkCost: Int) -> TaskExecutionResult {
            TaskExecutionResult(
                succeeded: succeeded,
                roll: roll,
                successChance: successChance,
                description: description,
                networkCostApplied: networkCost,
                operationInitiated: operationInitiated,
                errorMessage: errorMessage
            )
        }
    }

    /// Execute a bureau task by routing to the appropriate action service.
    /// Pass `targetCharacter` for security tasks where the player chose the target.
    /// Pass `viaDecree: true` for security tasks issued under Chairman's Decree —
    /// bypasses committee approval / maxTargetPosition at a steep political cost
    /// (consumes 1 of game.decreeChargesRemaining, handled inside SecurityActionService).
    func executeTask(
        _ task: BureauTask,
        for game: Game,
        modelContext: ModelContext,
        targetCharacter: GameCharacter? = nil,
        viaDecree: Bool = false
    ) -> TaskExecutionResult {
        // Verify task can be initiated
        guard task.canInitiate else {
            return .failure(task.unavailableReason ?? "Task cannot be initiated")
        }

        // Check network cost up front; only deduct after successful initiation.
        if task.networkCost > 0 {
            guard game.network >= task.networkCost else {
                return .failure("Insufficient network (need \(task.networkCost), have \(game.network))")
            }
        }

        let execution: TaskExecutionResult

        // Route to appropriate service based on action category
        switch task.actionCategory {
        case "security":
            execution = executeSecurityTask(task, for: game, modelContext: modelContext, targetCharacter: targetCharacter, viaDecree: viaDecree)
        case "economic":
            execution = executeEconomicTask(task, for: game, modelContext: modelContext)
        case "party":
            execution = executePartyTask(task, for: game, modelContext: modelContext)
        default:
            return .failure("Unknown action category: \(task.actionCategory)")
        }

        if execution.operationInitiated && task.networkCost > 0 {
            game.network -= task.networkCost
            return execution.withNetworkCostApplied(task.networkCost)
        }

        return execution.withNetworkCostApplied(0)
    }

    /// Execute a security-related task. Uses `targetCharacter` if provided, otherwise auto-picks.
    /// When `viaDecree` is true, the SecurityActionService bypasses committee approval and
    /// maxTargetPosition gates, and applies the decree political cost + charge consumption.
    private func executeSecurityTask(
        _ task: BureauTask,
        for game: Game,
        modelContext: ModelContext,
        targetCharacter providedTarget: GameCharacter? = nil,
        viaDecree: Bool = false
    ) -> TaskExecutionResult {
        // Find the security action by ID
        guard let action = SecurityAction.allActions.first(where: { $0.id == task.actionId }) else {
            return .failure("Security action not found: \(task.actionId)")
        }

        let targetCharacter: GameCharacter?
        let targetFaction: GameFaction?
        switch action.targetType {
        case .character:
            if let provided = providedTarget {
                targetCharacter = provided
            } else {
                guard let resolved = pickSecurityTarget(for: action, game: game) else {
                    return .failure("No eligible target available for \(action.name)")
                }
                targetCharacter = resolved
            }
            targetFaction = nil
        case .faction:
            guard let resolved = pickFactionTarget(game: game) else {
                return .failure("No faction target available for \(action.name)")
            }
            targetCharacter = nil
            targetFaction = resolved
        default:
            targetCharacter = nil
            targetFaction = nil
        }

        let result = SecurityActionService.shared.executeAction(
            action,
            targetCharacter: targetCharacter,
            targetFaction: targetFaction,
            for: game,
            modelContext: modelContext,
            viaDecree: viaDecree
        )

        return TaskExecutionResult(
            succeeded: result.succeeded,
            roll: result.roll,
            successChance: result.successChance,
            description: result.description,
            networkCostApplied: 0,
            operationInitiated: result.roll > 0 || result.succeeded,
            errorMessage: result.succeeded ? nil : result.description
        )
    }

    /// Execute an economic-related task
    private func executeEconomicTask(
        _ task: BureauTask,
        for game: Game,
        modelContext: ModelContext
    ) -> TaskExecutionResult {
        // Find the economic action by ID
        guard let action = EconomicAction.allActions.first(where: { $0.id == task.actionId }) else {
            return .failure("Economic action not found: \(task.actionId)")
        }

        let targetSector: EconomicSector?
        if action.targetType == .sector {
            targetSector = action.targetSector ?? pickEconomicSector(game: game)
        } else {
            targetSector = action.targetSector
        }

        let result = EconomicActionService.shared.executeAction(
            action,
            targetSector: targetSector,
            for: game,
            modelContext: modelContext
        )

        return TaskExecutionResult(
            succeeded: result.succeeded,
            roll: result.roll,
            successChance: result.successChance,
            description: result.description,
            networkCostApplied: 0,
            operationInitiated: result.roll > 0 || result.projectStarted != nil || result.succeeded,
            errorMessage: result.succeeded ? nil : result.description
        )
    }

    /// Execute a party-related task
    private func executePartyTask(
        _ task: BureauTask,
        for game: Game,
        modelContext: ModelContext
    ) -> TaskExecutionResult {
        // Find the party action by ID
        guard let action = PartyAction.allActions.first(where: { $0.id == task.actionId }) else {
            return .failure("Party action not found: \(task.actionId)")
        }

        let targetDepartment: String?
        if action.targetType == .department {
            targetDepartment = action.organ.displayName
        } else {
            targetDepartment = nil
        }

        let result = PartyActionService.shared.executeAction(
            action,
            targetCadre: nil,
            targetDepartment: targetDepartment,
            for: game,
            modelContext: modelContext
        )

        return TaskExecutionResult(
            succeeded: result.succeeded,
            roll: result.roll,
            successChance: result.successChance,
            description: result.description,
            networkCostApplied: 0,
            operationInitiated: result.roll > 0 || result.campaignStarted != nil || result.succeeded,
            errorMessage: result.succeeded ? nil : result.description
        )
    }

    private func pickSecurityTarget(for action: SecurityAction, game: Game) -> GameCharacter? {
        let maxPosition = action.maxTargetPosition ?? Int.max

        let eligible = game.characters.filter { character in
            guard character.isAlive && character.isActive else { return false }
            let position = character.positionIndex ?? 0
            if position > maxPosition { return false }
            if character.currentStatus == .detained || character.currentStatus == .underInvestigation {
                return false
            }
            return true
        }

        if let rival = game.primaryRival,
           eligible.contains(where: { $0.id == rival.id }) {
            return rival
        }

        return eligible.max {
            let lhsScore = $0.personalityCorrupt + (100 - $0.disposition)
            let rhsScore = $1.personalityCorrupt + (100 - $1.disposition)
            return lhsScore < rhsScore
        }
    }

    private func pickFactionTarget(game: Game) -> GameFaction? {
        let nonPlayerFactions = game.factions.filter { faction in
            faction.factionId != game.playerFactionId
        }
        return nonPlayerFactions.min(by: { $0.playerStanding < $1.playerStanding })
            ?? game.factions.min(by: { $0.playerStanding < $1.playerStanding })
    }

    private func pickEconomicSector(game: Game) -> EconomicSector {
        if game.foodSupply < 40 { return .agriculture }
        if game.industrialOutput < 40 { return .heavyIndustry }
        if game.treasury < 35 { return .lightIndustry }
        if game.stability < 35 { return .construction }
        return .heavyIndustry
    }

    // MARK: - Summary Statistics

    /// Get summary statistics for a bureau's operations
    func getOperationsSummary(for bureau: ExpandedCareerTrack, game: Game) -> BureauOperationsSummary {
        let operations = getActiveOperations(for: bureau, game: game)
        let activity = getRecentActivity(for: bureau, game: game, limit: 20)
        let tasks = getAvailableTasks(for: bureau, game: game)

        let activeCount = operations.filter { $0.status.isActive }.count
        let pendingApproval = operations.filter { $0.status == .awaitingApproval }.count
        let recentSuccesses = activity.filter { $0.wasSuccess == true }.count
        let recentFailures = activity.filter { $0.wasSuccess == false }.count
        let availableTasks = tasks.filter { $0.canInitiate }.count

        return BureauOperationsSummary(
            bureau: bureau,
            activeOperations: activeCount,
            pendingApproval: pendingApproval,
            recentSuccesses: recentSuccesses,
            recentFailures: recentFailures,
            availableTaskCount: availableTasks,
            totalTasks: tasks.count
        )
    }
}

// MARK: - Operations Summary

/// Summary statistics for bureau operations
struct BureauOperationsSummary {
    let bureau: ExpandedCareerTrack
    let activeOperations: Int
    let pendingApproval: Int
    let recentSuccesses: Int
    let recentFailures: Int
    let availableTaskCount: Int
    let totalTasks: Int

    var successRate: Double {
        let total = recentSuccesses + recentFailures
        guard total > 0 else { return 0 }
        return Double(recentSuccesses) / Double(total)
    }
}
