//
//  PartyActionService.swift
//  Nomenklatura
//
//  Service for executing party apparatus actions following CCP structure.
//  Handles Organization Dept, Propaganda Dept, United Front, and Party School operations.
//

import Foundation
import SwiftData

// MARK: - Party Action Service

/// Main service for party apparatus operations following CCP structure
final class PartyActionService {
    static let shared = PartyActionService()

    private init() {}

    // MARK: - Validation

    /// Result of action validation
    struct ValidationResult {
        let canExecute: Bool
        let reason: String?
        let successChance: Int
        let requiresApproval: Bool
    }

    /// Validate whether a party action can be executed
    func validateAction(
        _ action: PartyAction,
        targetCadre: GameCharacter?,
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

        // Check track requirement - must be in Party Apparatus track (or top leadership 7+)
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInPartyTrack = playerTrack == .partyApparatus
        let isTopLeadership = positionIndex >= 7  // Top leadership transcends tracks

        if !isInPartyTrack && !isTopLeadership {
            return ValidationResult(
                canExecute: false,
                reason: "Requires Party Apparatus career track",
                successChance: 0,
                requiresApproval: false
            )
        }

        // Check cooldown
        let cooldowns = getPartyCooldowns(for: game)
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
        if action.successEffects.initiatesCampaign {
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

        // Nomenklatura restrictions (can't appoint/expel superiors without approval)
        if let target = targetCadre, (action.successEffects.initiatesPromotion || action.successEffects.initiatesExpulsion) {
            let targetPosition = target.positionIndex ?? 0
            if targetPosition >= positionIndex && !action.requiresCommitteeApproval {
                return ValidationResult(
                    canExecute: false,
                    reason: "Cannot affect cadres at or above your position without Central Committee approval",
                    successChance: 0,
                    requiresApproval: true
                )
            }
        }

        // Calculate success chance
        let successChance = calculateSuccessChance(action, targetCadre: targetCadre, for: game)

        return ValidationResult(
            canExecute: true,
            reason: nil,
            successChance: successChance,
            requiresApproval: action.requiresCommitteeApproval
        )
    }

    // MARK: - Success Chance Calculation

    /// Calculate success chance for a party action
    func calculateSuccessChance(
        _ action: PartyAction,
        targetCadre: GameCharacter?,
        for game: Game
    ) -> Int {
        var chance = action.baseSuccessChance
        let positionIndex = game.currentPositionIndex

        // Position bonus: +5% per level above minimum
        let positionBonus = (positionIndex - action.minimumPositionIndex) * 5
        chance += positionBonus

        // Network bonus: Up to +10% based on network stat (party connections are critical)
        let networkBonus = min(10, game.network / 10)
        chance += networkBonus

        // Standing bonus: Up to +8% based on standing (political capital)
        let standingBonus = min(8, game.standing / 12)
        chance += standingBonus

        // Elite loyalty affects party actions
        if game.eliteLoyalty > 60 {
            chance += 5
        } else if game.eliteLoyalty < 30 {
            chance -= 10
        }

        // Stability affects major actions (purges, campaigns)
        if action.successEffects.initiatesCampaign || action.successEffects.initiatesExpulsion {
            if game.stability > 60 {
                chance += 5  // Easier to maintain discipline in stable times
            } else if game.stability < 30 {
                chance += 10  // Crisis makes radical measures more acceptable
            }
        }

        // Risk level modifier
        chance += action.riskLevel.successModifier

        // Organ-specific modifiers
        chance += organSpecificModifier(action.organ, for: game)

        // Target-specific modifiers
        if let target = targetCadre {
            chance += targetDifficultyModifier(target: target, for: action)
        }

        // Clamp to reasonable range
        return max(5, min(95, chance))
    }

    /// Get modifier based on party organ and game state
    private func organSpecificModifier(_ organ: PartyOrgan, for game: Game) -> Int {
        switch organ {
        case .propagandaDept:
            // Propaganda is more effective with high popular support
            return game.popularSupport > 50 ? 5 : 0
        case .organizationDept:
            // Organization work benefits from network
            return game.network > 50 ? 5 : 0
        case .unitedFrontDept:
            // United Front work benefits from international standing
            return game.internationalStanding > 50 ? 5 : 0
        case .disciplineInspection:
            // Discipline inspection is easier when elite loyalty is low (people want change)
            return game.eliteLoyalty < 40 ? 5 : 0
        default:
            return 0
        }
    }

    /// Get difficulty modifier for targeting specific cadre
    private func targetDifficultyModifier(target: GameCharacter, for action: PartyAction) -> Int {
        let targetPosition = target.positionIndex ?? 0
        var modifier = 0

        // Higher position targets are harder
        modifier -= targetPosition * 3

        // Loyal targets are harder to expel (personalityLoyal is 0-100)
        if target.personalityLoyal >= 70 {
            modifier -= 10
        } else if target.personalityLoyal <= 30 {
            modifier += 15  // Easier to expel those with weak party loyalty
        }

        // Well-connected targets have protection
        if target.fearLevel > 60 {
            modifier -= 10
        }

        // Targets with high disposition toward player are easier to promote
        if action.successEffects.initiatesPromotion && target.disposition > 30 {
            modifier += 10
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
        let effects: PartyEffects
        let campaignStarted: PartyCampaign?
        let expulsionInitiated: Bool
        let promotionInitiated: Bool
    }

    /// Execute a party action
    func executeAction(
        _ action: PartyAction,
        targetCadre: GameCharacter?,
        targetDepartment: String?,
        for game: Game,
        modelContext: ModelContext
    ) -> ExecutionResult {
        // Validate first
        let validation = validateAction(action, targetCadre: targetCadre, for: game)

        guard validation.canExecute else {
            return ExecutionResult(
                succeeded: false,
                roll: 0,
                successChance: 0,
                description: validation.reason ?? "Action cannot be executed",
                effects: PartyEffects(),
                campaignStarted: nil,
                expulsionInitiated: false,
                promotionInitiated: false
            )
        }

        // Check if this is a multi-turn campaign
        if action.executionTurns > 1 && action.successEffects.initiatesCampaign {
            return initiateCampaign(action, targetDepartment: targetDepartment, successChance: validation.successChance, for: game)
        }

        // Immediate resolution
        return resolveAction(
            action,
            targetCadre: targetCadre,
            targetDepartment: targetDepartment,
            successChance: validation.successChance,
            for: game,
            modelContext: modelContext
        )
    }

    /// Initiate a multi-turn campaign
    private func initiateCampaign(
        _ action: PartyAction,
        targetDepartment: String?,
        successChance: Int,
        for game: Game
    ) -> ExecutionResult {
        // Create campaign record
        let campaign = PartyCampaign(
            id: UUID(),
            actionId: action.id,
            name: action.name,
            description: action.detailedDescription,
            organ: action.organ,
            targetDepartment: targetDepartment,
            initiatedTurn: game.turnNumber,
            completionTurn: game.turnNumber + action.executionTurns,
            successChance: successChance,
            phase: .preparation,
            progress: 0
        )

        // Store campaign
        var campaigns = getActiveCampaigns(for: game)
        campaigns.append(campaign)
        saveActiveCampaigns(campaigns, for: game)

        // Set cooldown
        var cooldowns = getPartyCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        savePartyCooldowns(cooldowns, for: game)

        return ExecutionResult(
            succeeded: true,
            roll: 0,
            successChance: successChance,
            description: "\(action.name) campaign initiated. Will complete in \(action.executionTurns) turn(s).",
            effects: PartyEffects(),
            campaignStarted: campaign,
            expulsionInitiated: false,
            promotionInitiated: false
        )
    }

    /// Resolve an action immediately
    private func resolveAction(
        _ action: PartyAction,
        targetCadre: GameCharacter?,
        targetDepartment: String?,
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
        applyEffects(effects, targetCadre: targetCadre, for: game, modelContext: modelContext)

        // Set cooldown
        var cooldowns = getPartyCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        savePartyCooldowns(cooldowns, for: game)

        // Generate description
        let description = generateResultDescription(
            action: action,
            succeeded: succeeded,
            targetCadre: targetCadre,
            targetDepartment: targetDepartment,
            effects: effects
        )

        return ExecutionResult(
            succeeded: succeeded,
            roll: roll,
            successChance: successChance,
            description: description,
            effects: effects,
            campaignStarted: nil,
            expulsionInitiated: succeeded && effects.initiatesExpulsion,
            promotionInitiated: succeeded && effects.initiatesPromotion
        )
    }

    // MARK: - Effect Application

    /// Apply party effects to game state
    private func applyEffects(
        _ effects: PartyEffects,
        targetCadre: GameCharacter?,
        for game: Game,
        modelContext: ModelContext
    ) {
        // Party/national effects
        if effects.eliteLoyaltyChange != 0 {
            game.applyStat("eliteLoyalty", change: effects.eliteLoyaltyChange)
        }
        if effects.stabilityChange != 0 {
            game.applyStat("stability", change: effects.stabilityChange)
        }
        if effects.popularSupportChange != 0 {
            game.applyStat("popularSupport", change: effects.popularSupportChange)
        }
        // Note: ideologicalPurityChange would need a new stat or could affect eliteLoyalty

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
        if let target = targetCadre {
            if effects.targetDispositionChange != 0 {
                target.disposition = max(-100, min(100, target.disposition + effects.targetDispositionChange))
            }
            if effects.targetStandingChange != 0 {
                // Simulate effect on target's standing - affects their fear/power level
                target.fearLevel = max(0, min(100, target.fearLevel + effects.targetStandingChange))
            }
            if effects.targetLoyaltyChange != 0 {
                target.personalityLoyal = max(0, min(100, target.personalityLoyal + effects.targetLoyaltyChange))
            }

            // Handle promotion
            if effects.initiatesPromotion {
                initiatePromotion(target: target, game: game, modelContext: modelContext)
            }

            // Handle demotion
            if effects.initiatesDemotion {
                initiateDemotion(target: target, game: game, modelContext: modelContext)
            }

            // Handle expulsion
            if effects.initiatesExpulsion {
                initiateExpulsion(target: target, game: game, modelContext: modelContext)
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

    /// Initiate promotion of a target cadre
    private func initiatePromotion(target: GameCharacter, game: Game, modelContext: ModelContext) {
        // Increase target position if possible
        if let currentPosition = target.positionIndex, currentPosition < 6 {
            target.positionIndex = currentPosition + 1
        }

        // Increase target's disposition and gratitude
        target.disposition = min(100, target.disposition + 25)
        target.gratitudeLevel = min(100, target.gratitudeLevel + 25)

        // Target becomes more loyal
        target.personalityLoyal = min(100, target.personalityLoyal + 15)
        target.trustLevel = min(100, target.trustLevel + 15)

        // Set promotion flag
        let promotionFlag = "promoted_\(target.id.uuidString)"
        if !game.flags.contains(promotionFlag) {
            game.flags.append(promotionFlag)
        }
    }

    /// Initiate demotion of a target cadre
    private func initiateDemotion(target: GameCharacter, game: Game, modelContext: ModelContext) {
        // Decrease target position if possible
        if let currentPosition = target.positionIndex, currentPosition > 1 {
            target.positionIndex = currentPosition - 1
        }

        // Decrease target's disposition, increase grudge
        target.disposition = max(-100, target.disposition - 25)
        target.grudgeLevel = min(100, target.grudgeLevel + 30)

        // Target becomes less loyal
        target.personalityLoyal = max(0, target.personalityLoyal - 20)
        target.trustLevel = max(0, target.trustLevel - 20)
    }

    /// Initiate expulsion of a target cadre from the party
    private func initiateExpulsion(target: GameCharacter, game: Game, modelContext: ModelContext) {
        // Mark target as expelled
        let expulsionFlag = "expelled_\(target.id.uuidString)"
        if !game.flags.contains(expulsionFlag) {
            game.flags.append(expulsionFlag)
        }

        // Devastate target's disposition and loyalty
        target.disposition = max(-100, target.disposition - 50)
        target.grudgeLevel = min(100, target.grudgeLevel + 50)
        target.personalityLoyal = max(0, target.personalityLoyal - 40)
        target.fearLevel = max(0, target.fearLevel - 40)
        target.trustLevel = 0

        // Remove from position track
        target.positionIndex = 0
    }

    // MARK: - Result Description

    /// Generate description of action result
    private func generateResultDescription(
        action: PartyAction,
        succeeded: Bool,
        targetCadre: GameCharacter?,
        targetDepartment: String?,
        effects: PartyEffects
    ) -> String {
        let organName = action.organ.displayName

        if succeeded {
            var desc = "\(action.name) completed successfully through the \(organName)."

            if let target = targetCadre {
                if effects.initiatesPromotion {
                    desc += " \(target.name) has been promoted."
                } else if effects.initiatesDemotion {
                    desc += " \(target.name) has been demoted."
                } else if effects.initiatesExpulsion {
                    desc += " \(target.name) has been expelled from the Party."
                }
            }

            if effects.initiatesCampaign {
                desc += " An ideological campaign has begun."
            }

            if effects.standingChange > 0 {
                desc += " Your political standing has improved."
            }

            return desc
        } else {
            var desc = "\(action.name) failed."

            if action.organ == .organizationDept {
                desc += " The Organization Department could not process your request."
            } else if action.organ == .propagandaDept {
                desc += " The propaganda effort did not achieve desired results."
            } else if action.organ == .disciplineInspection {
                desc += " The discipline inspection found insufficient evidence."
            }

            if effects.standingChange < 0 {
                desc += " Your political standing has suffered."
            }

            return desc
        }
    }

    // MARK: - Campaign Management

    /// Advance all active campaigns by one turn
    func advanceCampaigns(for game: Game, modelContext: ModelContext) -> [PartyCampaignCompletionEvent] {
        var campaigns = getActiveCampaigns(for: game)
        var completionEvents: [PartyCampaignCompletionEvent] = []

        for i in campaigns.indices {
            campaigns[i].progress += 1

            // Update phase based on progress
            let totalTurns = campaigns[i].completionTurn - campaigns[i].initiatedTurn
            let progressPercent = Double(campaigns[i].progress) / Double(totalTurns)

            if progressPercent >= 0.75 {
                campaigns[i].phase = .implementation
            } else if progressPercent >= 0.5 {
                campaigns[i].phase = .mobilization
            } else if progressPercent >= 0.25 {
                campaigns[i].phase = .preparation
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
        _ campaign: inout PartyCampaign,
        for game: Game,
        modelContext: ModelContext
    ) -> PartyCampaignCompletionEvent {
        // Roll for success
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= campaign.successChance

        // Get the original action
        guard let action = PartyAction.allActions.first(where: { $0.id == campaign.actionId }) else {
            return PartyCampaignCompletionEvent(
                campaignId: campaign.id,
                campaignName: campaign.name,
                succeeded: false,
                description: "Campaign data corrupted",
                effects: PartyEffects()
            )
        }

        let effects = succeeded ? action.successEffects : action.failureEffects
        applyEffects(effects, targetCadre: nil, for: game, modelContext: modelContext)

        campaign.phase = succeeded ? .concluded : .failed

        let description = succeeded
            ? "\(campaign.name) campaign completed successfully! Party discipline strengthened across \(campaign.organ.displayName)."
            : "\(campaign.name) campaign failed to achieve objectives. Political work has been undermined."

        return PartyCampaignCompletionEvent(
            campaignId: campaign.id,
            campaignName: campaign.name,
            succeeded: succeeded,
            description: description,
            effects: effects
        )
    }

    // MARK: - NPC Autonomous Party Behavior

    /// Process autonomous party NPC actions each turn
    func processNPCPartyActions(game: Game, modelContext: ModelContext) -> [NPCPartyEvent] {
        var events: [NPCPartyEvent] = []

        // Get party officials (Position 2+)
        let partyOfficials = game.characters.filter { character in
            character.isAlive &&
            (character.positionTrack == "partyApparatus" ||
             character.positionTrack == "centralParty") &&
            (character.positionIndex ?? 0) >= 2
        }

        for official in partyOfficials {
            // 20% chance to take action each turn
            guard Int.random(in: 1...100) <= 20 else { continue }

            if let actionPlan = evaluateNPCPartyAction(for: official, game: game) {
                let event = executeNPCPartyAction(actionPlan, by: official, game: game, modelContext: modelContext)
                events.append(event)
            }
        }

        return events
    }

    /// Evaluate what party action an NPC should take
    private func evaluateNPCPartyAction(
        for character: GameCharacter,
        game: Game
    ) -> NPCPartyActionPlan? {
        let position = character.positionIndex ?? 0

        // Priority actions based on party/national state
        if game.eliteLoyalty < 40 && position >= 4 {
            return NPCPartyActionPlan(
                actionId: "launch_study_campaign",
                targetCadreId: nil,
                priority: 70
            )
        }

        // If stability is very low, push for discipline
        if game.stability < 30 && position >= 4 {
            return NPCPartyActionPlan(
                actionId: "discipline_inspection",
                targetCadreId: nil,
                priority: 80
            )
        }

        // Propaganda when popular support is low
        if game.popularSupport < 40 && position >= 3 {
            return NPCPartyActionPlan(
                actionId: "manage_local_propaganda",
                targetCadreId: nil,
                priority: 60
            )
        }

        // Standard party work
        if position >= 2 {
            return NPCPartyActionPlan(
                actionId: "conduct_united_front",
                targetCadreId: nil,
                priority: 30
            )
        }

        return nil
    }

    /// Execute an NPC's planned party action
    private func executeNPCPartyAction(
        _ plan: NPCPartyActionPlan,
        by character: GameCharacter,
        game: Game,
        modelContext: ModelContext
    ) -> NPCPartyEvent {
        guard let action = PartyAction.allActions.first(where: { $0.id == plan.actionId }) else {
            return NPCPartyEvent(
                characterId: character.id,
                characterName: character.name,
                actionId: plan.actionId,
                actionName: "Unknown Action",
                succeeded: false,
                description: "Action not found"
            )
        }

        // Find target if needed
        var targetCadre: GameCharacter? = nil
        if let targetId = plan.targetCadreId {
            targetCadre = game.characters.first { $0.id == targetId }
        }

        // Simple success check for NPC actions
        let successChance = action.baseSuccessChance + (character.positionIndex ?? 0) * 5
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= successChance

        // Apply effects if succeeded
        if succeeded {
            let effects = action.successEffects
            applyEffects(effects, targetCadre: targetCadre, for: game, modelContext: modelContext)
        }

        let description = succeeded
            ? "\(character.name) successfully executed \(action.name)"
            : "\(character.name) attempted \(action.name) but failed"

        return NPCPartyEvent(
            characterId: character.id,
            characterName: character.name,
            actionId: action.id,
            actionName: action.name,
            succeeded: succeeded,
            description: description
        )
    }

    // MARK: - Persistence Helpers

    /// Get party action cooldowns from game state
    func getPartyCooldowns(for game: Game) -> PartyCooldowns {
        guard let data = game.variables["party_cooldowns"],
              let jsonData = data.data(using: .utf8),
              let cooldowns = try? JSONDecoder().decode(PartyCooldowns.self, from: jsonData) else {
            return PartyCooldowns()
        }
        return cooldowns
    }

    /// Save party action cooldowns to game state
    func savePartyCooldowns(_ cooldowns: PartyCooldowns, for game: Game) {
        if let data = try? JSONEncoder().encode(cooldowns),
           let string = String(data: data, encoding: .utf8) {
            game.variables["party_cooldowns"] = string
        }
    }

    /// Get active party campaigns from game state
    func getActiveCampaigns(for game: Game) -> [PartyCampaign] {
        guard let data = game.variables["party_campaigns"],
              let jsonData = data.data(using: .utf8),
              let campaigns = try? JSONDecoder().decode([PartyCampaign].self, from: jsonData) else {
            return []
        }
        return campaigns
    }

    /// Save active party campaigns to game state
    func saveActiveCampaigns(_ campaigns: [PartyCampaign], for game: Game) {
        if let data = try? JSONEncoder().encode(campaigns),
           let string = String(data: data, encoding: .utf8) {
            game.variables["party_campaigns"] = string
        }
    }
}

// MARK: - Supporting Types

/// Cooldown tracking for party actions
struct PartyCooldowns: Codable {
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

/// Active party campaign state
struct PartyCampaign: Codable, Identifiable {
    let id: UUID
    let actionId: String
    let name: String
    let description: String
    let organ: PartyOrgan
    let targetDepartment: String?
    let initiatedTurn: Int
    let completionTurn: Int
    let successChance: Int
    var phase: PartyCampaignPhase
    var progress: Int
}

/// Phase of a party campaign
enum PartyCampaignPhase: String, Codable {
    case preparation        // Initial mobilization
    case mobilization       // Study sessions begin
    case implementation     // Active enforcement
    case concluded          // Successfully completed
    case failed             // Campaign failed
}

/// Event from completing a party campaign
struct PartyCampaignCompletionEvent {
    let campaignId: UUID
    let campaignName: String
    let succeeded: Bool
    let description: String
    let effects: PartyEffects
}

/// Plan for NPC party action
struct NPCPartyActionPlan {
    let actionId: String
    let targetCadreId: UUID?
    let priority: Int
}

/// Event from NPC party action
struct NPCPartyEvent {
    let characterId: UUID
    let characterName: String
    let actionId: String
    let actionName: String
    let succeeded: Bool
    let description: String
}
