//
//  MilitaryActionService.swift
//  Nomenklatura
//
//  Service for executing military-political actions following PLA/CCP structure.
//  Handles commissar duties, loyalty evaluations, purges, and NPC military behavior.
//

import Foundation
import SwiftData

// MARK: - Military Action Service

/// Main service for military-political operations following PLA commissar structure
final class MilitaryActionService {
    static let shared = MilitaryActionService()

    private init() {}

    // MARK: - Validation

    /// Result of action validation
    struct ValidationResult {
        let canExecute: Bool
        let reason: String?
        let successChance: Int
        let requiresApproval: Bool
    }

    /// Validate whether a military action can be executed
    func validateAction(
        _ action: MilitaryAction,
        targetOfficer: GameCharacter?,
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

        // Check track requirement - must be in Military-Political track (or top leadership 7+)
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInMilitaryTrack = playerTrack == .militaryPolitical
        let isTopLeadership = positionIndex >= 7  // Top leadership transcends tracks

        if !isInMilitaryTrack && !isTopLeadership {
            return ValidationResult(
                canExecute: false,
                reason: "Requires Military-Political career track",
                successChance: 0,
                requiresApproval: false
            )
        }

        // Check cooldown
        let cooldowns = getMilitaryCooldowns(for: game)
        if cooldowns.isOnCooldown(actionId: action.id, currentTurn: game.turnNumber) {
            let remaining = cooldowns.turnsRemaining(actionId: action.id, currentTurn: game.turnNumber)
            return ValidationResult(
                canExecute: false,
                reason: "On cooldown (\(remaining) turns remaining)",
                successChance: 0,
                requiresApproval: false
            )
        }

        // Check for active campaign limit (max 1 concurrent campaign)
        if action.successEffects.startsCampaign {
            let campaigns = getActiveCampaigns(for: game)
            if !campaigns.isEmpty {
                return ValidationResult(
                    canExecute: false,
                    reason: "A campaign is already in progress",
                    successChance: 0,
                    requiresApproval: action.requiresCommitteeApproval
                )
            }
        }

        // Target position restrictions (can't purge superiors without approval)
        if let target = targetOfficer, action.successEffects.initiatesPurge {
            let targetPosition = target.positionIndex ?? 0
            if targetPosition >= positionIndex && !action.requiresCommitteeApproval {
                return ValidationResult(
                    canExecute: false,
                    reason: "Cannot target officers at or above your position without CMC approval",
                    successChance: 0,
                    requiresApproval: true
                )
            }
        }

        // Calculate success chance
        let successChance = calculateSuccessChance(action, targetOfficer: targetOfficer, for: game)

        return ValidationResult(
            canExecute: true,
            reason: nil,
            successChance: successChance,
            requiresApproval: action.requiresCommitteeApproval
        )
    }

    // MARK: - Success Chance Calculation

    /// Calculate success chance for a military action
    func calculateSuccessChance(
        _ action: MilitaryAction,
        targetOfficer: GameCharacter?,
        for game: Game
    ) -> Int {
        var chance = action.baseSuccessChance
        let positionIndex = game.currentPositionIndex

        // Position bonus: +5% per level above minimum
        let positionBonus = (positionIndex - action.minimumPositionIndex) * 5
        chance += positionBonus

        // Network bonus: Up to +8% based on network stat (party connections)
        let networkBonus = min(8, game.network / 12)
        chance += networkBonus

        // Standing bonus: Up to +7% based on standing (political capital)
        let standingBonus = min(7, game.standing / 15)
        chance += standingBonus

        // Military loyalty affects military actions
        if game.militaryLoyalty > 60 {
            chance += 5
        } else if game.militaryLoyalty < 30 {
            chance -= 10
        }

        // Stability affects purge/discipline actions
        if action.successEffects.initiatesPurge || action.category == .divisionCommand {
            if game.stability > 60 {
                chance += 5  // Easier to enforce discipline in stable times
            } else if game.stability < 30 {
                chance += 10  // Crisis makes purges more acceptable
            }
        }

        // Risk level modifier
        chance += action.riskLevel.successModifier

        // Target-specific modifiers
        if let target = targetOfficer {
            chance += targetDifficultyModifier(target: target, for: action)
        }

        // Clamp to reasonable range
        return max(5, min(95, chance))
    }

    /// Get difficulty modifier for targeting specific officer
    private func targetDifficultyModifier(target: GameCharacter, for action: MilitaryAction) -> Int {
        let targetPosition = target.positionIndex ?? 0
        var modifier = 0

        // Higher position targets are harder
        modifier -= targetPosition * 3

        // Loyal targets are harder to turn/purge (personalityLoyal is 0-100)
        if target.personalityLoyal >= 70 {
            modifier -= 10
        } else if target.personalityLoyal <= 30 {
            modifier += 15  // Easier to purge those with weak loyalty
        }

        // Well-connected targets have higher fear level (protection)
        if target.fearLevel > 60 {
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
        let effects: MilitaryEffects
        let campaignStarted: MilitaryCampaign?
        let purgeInitiated: Bool
    }

    /// Execute a military action
    func executeAction(
        _ action: MilitaryAction,
        targetOfficer: GameCharacter?,
        targetUnit: String?,
        targetTheater: TheaterCommand?,
        for game: Game,
        modelContext: ModelContext
    ) -> ExecutionResult {
        // Validate first
        let validation = validateAction(action, targetOfficer: targetOfficer, for: game)

        guard validation.canExecute else {
            return ExecutionResult(
                succeeded: false,
                roll: 0,
                successChance: 0,
                description: validation.reason ?? "Action cannot be executed",
                effects: MilitaryEffects(),
                campaignStarted: nil,
                purgeInitiated: false
            )
        }

        // Check if this is a multi-turn campaign
        if action.executionTurns > 1 && action.successEffects.startsCampaign {
            return initiateCampaign(action, targetTheater: targetTheater, successChance: validation.successChance, for: game)
        }

        // Immediate resolution
        return resolveAction(
            action,
            targetOfficer: targetOfficer,
            targetTheater: targetTheater,
            successChance: validation.successChance,
            for: game,
            modelContext: modelContext
        )
    }

    /// Initiate a multi-turn campaign
    private func initiateCampaign(
        _ action: MilitaryAction,
        targetTheater: TheaterCommand?,
        successChance: Int,
        for game: Game
    ) -> ExecutionResult {
        // Create campaign record
        let campaign = MilitaryCampaign(
            id: UUID(),
            actionId: action.id,
            name: action.name,
            description: action.detailedDescription,
            targetTheater: targetTheater,
            initiatedTurn: game.turnNumber,
            completionTurn: game.turnNumber + action.executionTurns,
            successChance: successChance,
            phase: .mobilization,
            progress: 0
        )

        // Store campaign
        var campaigns = getActiveCampaigns(for: game)
        campaigns.append(campaign)
        saveActiveCampaigns(campaigns, for: game)

        // Set cooldown
        var cooldowns = getMilitaryCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        saveMilitaryCooldowns(cooldowns, for: game)

        return ExecutionResult(
            succeeded: true,
            roll: 0,
            successChance: successChance,
            description: "\(action.name) campaign initiated. Will complete in \(action.executionTurns) turn(s).",
            effects: MilitaryEffects(),
            campaignStarted: campaign,
            purgeInitiated: false
        )
    }

    /// Resolve an action immediately
    private func resolveAction(
        _ action: MilitaryAction,
        targetOfficer: GameCharacter?,
        targetTheater: TheaterCommand?,
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
        applyEffects(effects, targetOfficer: targetOfficer, for: game, modelContext: modelContext)

        // Set cooldown
        var cooldowns = getMilitaryCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        saveMilitaryCooldowns(cooldowns, for: game)

        // Generate description
        let description = generateResultDescription(
            action: action,
            succeeded: succeeded,
            targetOfficer: targetOfficer,
            targetTheater: targetTheater,
            effects: effects
        )

        return ExecutionResult(
            succeeded: succeeded,
            roll: roll,
            successChance: successChance,
            description: description,
            effects: effects,
            campaignStarted: nil,
            purgeInitiated: succeeded && effects.initiatesPurge
        )
    }

    // MARK: - Effect Application

    /// Apply military effects to game state
    private func applyEffects(
        _ effects: MilitaryEffects,
        targetOfficer: GameCharacter?,
        for game: Game,
        modelContext: ModelContext
    ) {
        // National military effects
        if effects.militaryLoyaltyChange != 0 {
            game.applyStat("militaryLoyalty", change: effects.militaryLoyaltyChange)
        }
        if effects.militaryReadinessChange != 0 {
            game.applyStat("militaryReadiness", change: effects.militaryReadinessChange)
        }
        if effects.stabilityChange != 0 {
            game.applyStat("stability", change: effects.stabilityChange)
        }

        // Support effects
        if effects.eliteLoyaltyChange != 0 {
            game.applyStat("eliteLoyalty", change: effects.eliteLoyaltyChange)
        }
        if effects.popularSupportChange != 0 {
            game.applyStat("popularSupport", change: effects.popularSupportChange)
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

        // International effects
        if effects.internationalStandingChange != 0 {
            game.applyStat("internationalStanding", change: effects.internationalStandingChange)
        }

        // Target effects
        if let target = targetOfficer {
            if effects.targetDispositionChange != 0 {
                target.disposition = max(-100, min(100, target.disposition + effects.targetDispositionChange))
            }

            // Handle purge initiation
            if effects.initiatesPurge {
                initiatePurge(target: target, game: game, modelContext: modelContext)
            }

            // Handle promotion
            if effects.initiatesPromotion {
                initiatePromotion(target: target, game: game, modelContext: modelContext)
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

    /// Initiate purge of a target officer
    private func initiatePurge(target: GameCharacter, game: Game, modelContext: ModelContext) {
        // Mark target as under investigation/purge
        let purgeFlag = "purge_\(target.id.uuidString)"
        if !game.flags.contains(purgeFlag) {
            game.flags.append(purgeFlag)
        }

        // Reduce target's disposition and trust
        target.disposition = max(-100, target.disposition - 30)
        target.trustLevel = max(0, target.trustLevel - 20)

        // Target becomes more resentful (grudge increases)
        target.grudgeLevel = min(100, target.grudgeLevel + 30)

        // Reduce their loyalty trait
        target.personalityLoyal = max(0, target.personalityLoyal - 20)
    }

    /// Initiate promotion of a target officer
    private func initiatePromotion(target: GameCharacter, game: Game, modelContext: ModelContext) {
        // Increase target position if possible
        if let currentPosition = target.positionIndex, currentPosition < 6 {
            target.positionIndex = currentPosition + 1
        }

        // Increase target's disposition and gratitude
        target.disposition = min(100, target.disposition + 20)
        target.gratitudeLevel = min(100, target.gratitudeLevel + 20)

        // Target becomes more loyal
        target.personalityLoyal = min(100, target.personalityLoyal + 15)
        target.trustLevel = min(100, target.trustLevel + 10)
    }

    // MARK: - Campaign Management

    /// Advance all active campaigns by one turn
    func advanceCampaigns(for game: Game, modelContext: ModelContext) -> [CampaignCompletionEvent] {
        var campaigns = getActiveCampaigns(for: game)
        var completionEvents: [CampaignCompletionEvent] = []

        for i in campaigns.indices {
            campaigns[i].progress += 1

            // Update phase based on progress
            let totalTurns = campaigns[i].completionTurn - campaigns[i].initiatedTurn
            let progressPercent = Double(campaigns[i].progress) / Double(totalTurns)

            if progressPercent >= 0.75 {
                campaigns[i].phase = .consolidation
            } else if progressPercent >= 0.5 {
                campaigns[i].phase = .operations
            } else if progressPercent >= 0.25 {
                campaigns[i].phase = .investigation
            }

            // Check for completion
            if game.turnNumber >= campaigns[i].completionTurn {
                let event = completeCampaign(&campaigns[i], for: game, modelContext: modelContext)
                completionEvents.append(event)
            }
        }

        // Remove completed campaigns
        campaigns.removeAll { game.turnNumber >= $0.completionTurn }
        saveActiveCampaigns(campaigns, for: game)

        return completionEvents
    }

    /// Complete a campaign and determine outcome
    private func completeCampaign(
        _ campaign: inout MilitaryCampaign,
        for game: Game,
        modelContext: ModelContext
    ) -> CampaignCompletionEvent {
        // Roll for success
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= campaign.successChance

        // Get the original action
        guard let action = MilitaryAction.allActions.first(where: { $0.id == campaign.actionId }) else {
            return CampaignCompletionEvent(
                campaignId: campaign.id,
                campaignName: campaign.name,
                succeeded: false,
                description: "Campaign data corrupted",
                effects: MilitaryEffects()
            )
        }

        let effects = succeeded ? action.successEffects : action.failureEffects
        applyEffects(effects, targetOfficer: nil, for: game, modelContext: modelContext)

        campaign.phase = succeeded ? .completed : .failed

        let description = succeeded
            ? "\(campaign.name) campaign completed successfully! Military discipline strengthened."
            : "\(campaign.name) campaign failed to achieve objectives. Political work undermined."

        return CampaignCompletionEvent(
            campaignId: campaign.id,
            campaignName: campaign.name,
            succeeded: succeeded,
            description: description,
            effects: effects
        )
    }

    // MARK: - NPC Autonomous Military Behavior

    /// Process autonomous military NPC actions each turn
    func processNPCMilitaryActions(game: Game, modelContext: ModelContext) -> [NPCMilitaryEvent] {
        var events: [NPCMilitaryEvent] = []

        // Get military-political officials (Position 2+)
        let militaryOfficials = game.characters.filter { character in
            character.isAlive &&
            (character.positionTrack == "militaryPolitical" ||
             character.positionTrack == "securityServices") &&
            (character.positionIndex ?? 0) >= 2
        }

        for official in militaryOfficials {
            // 20% chance to take action each turn
            guard Int.random(in: 1...100) <= 20 else { continue }

            if let actionPlan = evaluateNPCMilitaryAction(for: official, game: game) {
                let event = executeNPCMilitaryAction(actionPlan, by: official, game: game, modelContext: modelContext)
                events.append(event)
            }
        }

        return events
    }

    /// Evaluate what military action an NPC should take
    private func evaluateNPCMilitaryAction(
        for character: GameCharacter,
        game: Game
    ) -> NPCMilitaryActionPlan? {
        let position = character.positionIndex ?? 0

        // Priority actions based on military state
        if game.militaryLoyalty < 40 && position >= 3 {
            return NPCMilitaryActionPlan(
                actionId: "launch_ideological_campaign",
                targetOfficerId: nil,
                priority: 70
            )
        }

        // If stability is very low, push for purges
        if game.stability < 30 && position >= 4 {
            // Find a disloyal officer to purge (low personalityLoyal score)
            let disloyalOfficer = game.characters.first { char in
                char.isAlive &&
                char.personalityLoyal <= 30 &&
                (char.positionIndex ?? 0) < position
            }
            if let target = disloyalOfficer {
                return NPCMilitaryActionPlan(
                    actionId: "purge_officer",
                    targetOfficerId: target.id.uuidString,
                    priority: 80
                )
            }
        }

        // Routine discipline at lower levels
        if position >= 2 {
            return NPCMilitaryActionPlan(
                actionId: "enforce_discipline",
                targetOfficerId: nil,
                priority: 40
            )
        }

        // Political education at lowest levels
        if position >= 1 {
            return NPCMilitaryActionPlan(
                actionId: "conduct_study_session",
                targetOfficerId: nil,
                priority: 30
            )
        }

        return nil
    }

    /// Execute an NPC military action
    private func executeNPCMilitaryAction(
        _ plan: NPCMilitaryActionPlan,
        by character: GameCharacter,
        game: Game,
        modelContext: ModelContext
    ) -> NPCMilitaryEvent {
        guard let action = MilitaryAction.allActions.first(where: { $0.id == plan.actionId }) else {
            return NPCMilitaryEvent(
                id: UUID().uuidString,
                turn: game.turnNumber,
                characterId: character.id.uuidString,
                characterName: character.name,
                actionId: plan.actionId,
                targetOfficerId: plan.targetOfficerId,
                success: false,
                description: "Action not found"
            )
        }

        // Find target if specified
        var targetOfficer: GameCharacter?
        if let targetId = plan.targetOfficerId {
            targetOfficer = game.characters.first { $0.id.uuidString == targetId }
        }

        // Calculate success
        let successChance = calculateSuccessChance(action, targetOfficer: targetOfficer, for: game)
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= successChance

        // Apply effects if succeeded
        if succeeded {
            applyEffects(action.successEffects, targetOfficer: targetOfficer, for: game, modelContext: modelContext)
        } else {
            applyEffects(action.failureEffects, targetOfficer: targetOfficer, for: game, modelContext: modelContext)
        }

        let description = generateNPCActionDescription(
            action: action,
            character: character,
            targetOfficer: targetOfficer,
            succeeded: succeeded
        )

        return NPCMilitaryEvent(
            id: UUID().uuidString,
            turn: game.turnNumber,
            characterId: character.id.uuidString,
            characterName: character.name,
            actionId: action.id,
            targetOfficerId: plan.targetOfficerId,
            success: succeeded,
            description: description
        )
    }

    /// Generate description for NPC action
    private func generateNPCActionDescription(
        action: MilitaryAction,
        character: GameCharacter,
        targetOfficer: GameCharacter?,
        succeeded: Bool
    ) -> String {
        let title = character.title ?? "Political Commissar"
        let targetName = targetOfficer?.name ?? "subordinate units"

        if succeeded {
            switch action.id {
            case "conduct_study_session":
                return "\(title) \(character.name) conducted political education session."
            case "enforce_discipline":
                return "\(title) \(character.name) enforced Party discipline in the ranks."
            case "launch_ideological_campaign":
                return "\(character.name) launched ideological education campaign across their command."
            case "purge_officer":
                return "\(character.name) initiated purge proceedings against \(targetName)."
            case "evaluate_officer_loyalty":
                return "\(character.name) completed loyalty assessment of \(targetName)."
            default:
                return "\(character.name) executed military-political action: \(action.name)"
            }
        } else {
            return "\(character.name) attempted \(action.name.lowercased()) but failed to achieve objectives."
        }
    }

    // MARK: - Helper: Result Description

    private func generateResultDescription(
        action: MilitaryAction,
        succeeded: Bool,
        targetOfficer: GameCharacter?,
        targetTheater: TheaterCommand?,
        effects: MilitaryEffects
    ) -> String {
        let targetName = targetOfficer?.name ?? targetTheater?.displayName ?? "the command"

        if succeeded {
            switch action.id {
            case "conduct_study_session":
                return "Political study session completed. Party doctrine has been reinforced."
            case "report_political_attitude":
                return "Political attitudes report filed. Your diligence is noted by superiors."
            case "flag_suspicious_behavior":
                return "Suspicious behavior flagged. Investigation file opened on the subject."
            case "enforce_discipline":
                return "Discipline enforced. The unit's political reliability is strengthened."
            case "evaluate_officer_loyalty":
                return "Loyalty evaluation complete. Assessment added to political dossier."
            case "recommend_promotion":
                return "Promotion recommendation accepted. Your protégé advances in rank."
            case "purge_officer":
                return "Purge proceedings initiated against \(targetName). Party discipline prevails."
            case "launch_ideological_campaign":
                return "Ideological campaign launched. Political consciousness is being raised."
            case "nationwide_military_purge":
                return "Nationwide purge initiated. The PLA will be cleansed of disloyal elements."
            case "military_political_reform":
                return "Historic reform! The military-political structure has been transformed."
            case "cmc_personnel_directive":
                return "CMC directive issued. The entire PLA reorganizes according to your will."
            default:
                return "\(action.name) completed successfully."
            }
        } else {
            switch action.id {
            case "flag_suspicious_behavior":
                return "Report dismissed as unfounded. You face scrutiny for false accusations."
            case "purge_officer":
                return "Purge attempt failed. \(targetName) retains their position and seeks revenge."
            case "recommend_promotion":
                return "Promotion blocked by the Party committee. Your influence is questioned."
            case "nationwide_military_purge":
                return "Purge met with resistance. Your authority is undermined."
            default:
                return "\(action.name) failed. Political work suffers a setback."
            }
        }
    }

    // MARK: - Storage Helpers

    func getMilitaryCooldowns(for game: Game) -> MilitaryCooldownTracker {
        guard let data = game.variables["military_cooldowns"],
              let jsonData = data.data(using: .utf8),
              let tracker = try? JSONDecoder().decode(MilitaryCooldownTracker.self, from: jsonData) else {
            return MilitaryCooldownTracker()
        }
        return tracker
    }

    private func saveMilitaryCooldowns(_ tracker: MilitaryCooldownTracker, for game: Game) {
        if let data = try? JSONEncoder().encode(tracker),
           let string = String(data: data, encoding: .utf8) {
            game.variables["military_cooldowns"] = string
        }
    }

    func getActiveCampaigns(for game: Game) -> [MilitaryCampaign] {
        guard let data = game.variables["military_campaigns"],
              let jsonData = data.data(using: .utf8),
              let campaigns = try? JSONDecoder().decode([MilitaryCampaign].self, from: jsonData) else {
            return []
        }
        return campaigns
    }

    private func saveActiveCampaigns(_ campaigns: [MilitaryCampaign], for game: Game) {
        if let data = try? JSONEncoder().encode(campaigns),
           let string = String(data: data, encoding: .utf8) {
            game.variables["military_campaigns"] = string
        }
    }
}

// MARK: - Supporting Types

/// Cooldown tracking for military actions
struct MilitaryCooldownTracker: Codable {
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

/// An active military campaign
struct MilitaryCampaign: Identifiable, Codable {
    let id: UUID
    let actionId: String
    let name: String
    let description: String
    let targetTheater: TheaterCommand?
    let initiatedTurn: Int
    let completionTurn: Int
    let successChance: Int
    var phase: CampaignPhase
    var progress: Int
}

/// Phases of a military campaign
enum CampaignPhase: String, Codable {
    case mobilization           // Initial preparation
    case investigation          // Gathering intelligence/evidence
    case operations             // Active operations
    case consolidation          // Securing gains
    case completed              // Successfully completed
    case failed                 // Failed to complete
}

/// Event when campaign completes
struct CampaignCompletionEvent: Identifiable, Codable {
    var id: UUID { campaignId }
    let campaignId: UUID
    let campaignName: String
    let succeeded: Bool
    let description: String
    let effects: MilitaryEffects
}

/// Plan for NPC military action
struct NPCMilitaryActionPlan {
    let actionId: String
    let targetOfficerId: String?
    let priority: Int
}

/// Event generated by NPC military action
struct NPCMilitaryEvent: Identifiable, Codable {
    let id: String
    let turn: Int
    let characterId: String
    let characterName: String
    let actionId: String
    let targetOfficerId: String?
    let success: Bool
    let description: String
}

