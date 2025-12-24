//
//  SecurityActionService.swift
//  Nomenklatura
//
//  Service for executing security actions, managing shuanggui detentions,
//  and processing NPC autonomous security behavior following CCP CCDI patterns.
//

import Foundation
import SwiftData

// MARK: - Security Action Service

/// Main service for security operations following CCP CCDI structure
final class SecurityActionService {
    static let shared = SecurityActionService()

    private init() {}

    // MARK: - Validation

    /// Result of action validation
    struct ValidationResult {
        let canExecute: Bool
        let reason: String?
        let successChance: Int
        let requiresApproval: Bool
        let targetTooSenior: Bool
    }

    /// Validate whether an action can be executed
    func validateAction(
        _ action: SecurityAction,
        targetCharacter: GameCharacter?,
        targetFaction: GameFaction?,
        for game: Game
    ) -> ValidationResult {
        let positionIndex = game.currentPositionIndex

        // Check position requirement
        guard positionIndex >= action.effectiveMinimumPosition else {
            return ValidationResult(
                canExecute: false,
                reason: "Requires Position \(action.effectiveMinimumPosition) (you are Position \(positionIndex))",
                successChance: 0,
                requiresApproval: false,
                targetTooSenior: false
            )
        }

        // Check track requirement - must be in Security Services track (or top leadership 7+)
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInSecurityTrack = playerTrack == .securityServices
        let isTopLeadership = positionIndex >= 7  // Top leadership transcends tracks

        if !isInSecurityTrack && !isTopLeadership {
            return ValidationResult(
                canExecute: false,
                reason: "Requires Security Services career track",
                successChance: 0,
                requiresApproval: false,
                targetTooSenior: false
            )
        }

        // Check cooldown
        let cooldowns = getSecurityCooldowns(for: game)
        if cooldowns.isOnCooldown(actionId: action.id, currentTurn: game.turnNumber) {
            let remaining = cooldowns.turnsRemaining(actionId: action.id, currentTurn: game.turnNumber)
            return ValidationResult(
                canExecute: false,
                reason: "On cooldown (\(remaining) turns remaining)",
                successChance: 0,
                requiresApproval: false,
                targetTooSenior: false
            )
        }

        // Check target requirements
        var targetTooSenior = false
        var requiresApproval = action.requiresCommitteeApproval

        if action.targetType == .character, let target = targetCharacter {
            let targetPosition = target.positionIndex ?? 0

            // Check if target is too senior
            if let maxTarget = action.maxTargetPosition, targetPosition > maxTarget {
                return ValidationResult(
                    canExecute: false,
                    reason: "Target is Position \(targetPosition), maximum allowed is Position \(maxTarget)",
                    successChance: 0,
                    requiresApproval: false,
                    targetTooSenior: true
                )
            }

            // Check if approval required for this target level
            if let approvalThreshold = action.requiresApprovalAbove, targetPosition > approvalThreshold {
                requiresApproval = true
                targetTooSenior = true
            }
        }

        // Check treasury for any costs (security actions are mostly free but some have costs)
        let treasuryCost = action.successEffects.standingChange < 0 ? abs(action.successEffects.standingChange) : 0
        if treasuryCost > 0 && game.treasury < treasuryCost {
            return ValidationResult(
                canExecute: false,
                reason: "Insufficient resources",
                successChance: 0,
                requiresApproval: false,
                targetTooSenior: false
            )
        }

        // Calculate success chance
        let successChance = calculateSuccessChance(action, targetCharacter: targetCharacter, for: game)

        return ValidationResult(
            canExecute: true,
            reason: nil,
            successChance: successChance,
            requiresApproval: requiresApproval,
            targetTooSenior: targetTooSenior
        )
    }

    // MARK: - Success Chance Calculation

    /// Calculate success chance for an action
    func calculateSuccessChance(
        _ action: SecurityAction,
        targetCharacter: GameCharacter?,
        for game: Game
    ) -> Int {
        var chance = action.baseSuccessChance
        let positionIndex = game.currentPositionIndex

        // Position bonus: +5% per level above minimum
        let positionBonus = (positionIndex - action.effectiveMinimumPosition) * 5
        chance += positionBonus

        // Network bonus: Up to +10% based on network stat
        let networkBonus = min(10, game.network / 10)
        chance += networkBonus

        // Standing bonus: Up to +5% based on standing
        let standingBonus = min(5, game.standing / 20)
        chance += standingBonus

        // Risk level modifier
        chance += action.riskLevel.successModifier

        // Target-specific modifiers
        if let target = targetCharacter {
            let targetPosition = target.positionIndex ?? 0

            // Harder to investigate senior officials
            if targetPosition > positionIndex {
                chance -= (targetPosition - positionIndex) * 10
            }

            // Target's position gives them protection (higher position = more protected)
            if targetPosition >= 4 {
                chance -= (targetPosition - 3) * 5
            }

            // Target's loyalty makes them harder to break
            if target.personality.loyal > 60 {
                chance -= (target.personality.loyal - 60) / 10
            }
        }

        // Clamp to reasonable range
        return max(5, min(95, chance))
    }

    // MARK: - Action Execution

    /// Result of executing an action
    struct ExecutionResult {
        let succeeded: Bool
        let roll: Int
        let successChance: Int
        let description: String
        let effects: SecurityEffects
        let implicatedCharacters: [String]
        let detentionCreated: ShuangguiDetention?
    }

    /// Execute a security action
    func executeAction(
        _ action: SecurityAction,
        targetCharacter: GameCharacter?,
        targetFaction: GameFaction?,
        for game: Game,
        modelContext: ModelContext
    ) -> ExecutionResult {
        // Validate first
        let validation = validateAction(action, targetCharacter: targetCharacter, targetFaction: targetFaction, for: game)

        guard validation.canExecute else {
            return ExecutionResult(
                succeeded: false,
                roll: 0,
                successChance: 0,
                description: validation.reason ?? "Action cannot be executed",
                effects: SecurityEffects(),
                implicatedCharacters: [],
                detentionCreated: nil
            )
        }

        // Check if this is a multi-turn action
        if action.executionTurns > 0 {
            return initiateMultiTurnAction(action, targetCharacter: targetCharacter, targetFaction: targetFaction, for: game)
        }

        // Immediate resolution
        return resolveAction(action, targetCharacter: targetCharacter, targetFaction: targetFaction, successChance: validation.successChance, for: game, modelContext: modelContext)
    }

    /// Initiate a multi-turn action
    private func initiateMultiTurnAction(
        _ action: SecurityAction,
        targetCharacter: GameCharacter?,
        targetFaction: GameFaction?,
        for game: Game
    ) -> ExecutionResult {
        let successChance = calculateSuccessChance(action, targetCharacter: targetCharacter, for: game)

        // Create pending action record
        let record = SecurityActionRecord(
            id: UUID(),
            actionId: action.id,
            initiatedTurn: game.turnNumber,
            completionTurn: game.turnNumber + action.executionTurns,
            initiatedBy: "player",
            targetCharacterId: targetCharacter?.id.uuidString,
            targetFactionId: targetFaction?.factionId,
            targetDepartment: nil,
            status: .inProgress,
            successChance: successChance,
            result: nil
        )

        // Store pending action
        var pendingActions = getPendingActions(for: game)
        pendingActions.append(record)
        savePendingActions(pendingActions, for: game)

        // Set cooldown
        var cooldowns = getSecurityCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        saveSecurityCooldowns(cooldowns, for: game)

        return ExecutionResult(
            succeeded: true,
            roll: 0,
            successChance: successChance,
            description: "\(action.name) initiated. Will complete in \(action.executionTurns) turn(s).",
            effects: SecurityEffects(),
            implicatedCharacters: [],
            detentionCreated: nil
        )
    }

    /// Resolve an action immediately
    private func resolveAction(
        _ action: SecurityAction,
        targetCharacter: GameCharacter?,
        targetFaction: GameFaction?,
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
        var implicatedCharacters: [String] = []
        var detentionCreated: ShuangguiDetention? = nil

        if succeeded {
            // Apply success effects
            applyEffects(effects, targetCharacter: targetCharacter, targetFaction: targetFaction, for: game, modelContext: modelContext)

            // Handle special triggers
            if effects.initiatesShuanggui, let target = targetCharacter {
                detentionCreated = createShuangguiDetention(for: target, initiatedBy: "Player", game: game)
            }

            if effects.implicatesOthers, let target = targetCharacter {
                implicatedCharacters = generateImplicatedCharacters(from: target, game: game)
            }

            if effects.initiatesTrial, let target = targetCharacter {
                initiateShowTrial(for: target, game: game, modelContext: modelContext)
            }

            if effects.targetExecuted, let target = targetCharacter {
                executeCharacter(target, method: .detention, game: game, modelContext: modelContext)
            }

            if effects.targetDismissed, let target = targetCharacter {
                dismissCharacter(target, game: game, modelContext: modelContext)
            }

            if effects.targetDemoted, let target = targetCharacter {
                demoteCharacter(target, levels: 2, game: game, modelContext: modelContext)
            }
        } else {
            // Apply failure effects
            applyEffects(effects, targetCharacter: targetCharacter, targetFaction: targetFaction, for: game, modelContext: modelContext)
        }

        // Set cooldown
        var cooldowns = getSecurityCooldowns(for: game)
        cooldowns.setCooldown(actionId: action.id, availableTurn: game.turnNumber + action.cooldownTurns)
        saveSecurityCooldowns(cooldowns, for: game)

        // Generate description
        let description = generateResultDescription(action: action, succeeded: succeeded, targetCharacter: targetCharacter, effects: effects)

        return ExecutionResult(
            succeeded: succeeded,
            roll: roll,
            successChance: successChance,
            description: description,
            effects: effects,
            implicatedCharacters: implicatedCharacters,
            detentionCreated: detentionCreated
        )
    }

    // MARK: - Effect Application

    /// Apply security effects to game state
    private func applyEffects(
        _ effects: SecurityEffects,
        targetCharacter: GameCharacter?,
        targetFaction: GameFaction?,
        for game: Game,
        modelContext: ModelContext
    ) {
        // Player effects
        if effects.standingChange != 0 {
            game.applyStat("standing", change: effects.standingChange)
        }
        if effects.networkChange != 0 {
            game.applyStat("network", change: effects.networkChange)
        }

        // Game state effects
        if effects.stabilityChange != 0 {
            game.applyStat("stability", change: effects.stabilityChange)
        }
        if effects.eliteLoyaltyChange != 0 {
            game.applyStat("eliteLoyalty", change: effects.eliteLoyaltyChange)
        }
        if effects.popularSupportChange != 0 {
            game.applyStat("popularSupport", change: effects.popularSupportChange)
        }
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

        // Target suspicion (stored in character variables or separate tracking)
        if effects.suspicionIncrease > 0, let target = targetCharacter {
            increaseSuspicion(for: target, by: effects.suspicionIncrease, game: game)
        }

        // Evidence accumulation
        if effects.evidenceGathered > 0, let target = targetCharacter {
            gatherEvidence(against: target, amount: effects.evidenceGathered, game: game)
        }
    }

    // MARK: - Shuanggui Detention

    /// Create a new shuanggui detention
    func createShuangguiDetention(
        for target: GameCharacter,
        initiatedBy: String,
        game: Game
    ) -> ShuangguiDetention {
        let detention = ShuangguiDetention(
            targetCharacterId: target.id.uuidString,
            targetName: target.name,
            targetPosition: target.positionIndex ?? 0,
            initiatedByCharacterId: initiatedBy,
            initiatedByName: initiatedBy == "Player" ? "You" : initiatedBy,
            turn: game.turnNumber
        )

        // Store detention
        var detentions = getActiveDetentions(for: game)
        detentions.append(detention)
        saveActiveDetentions(detentions, for: game)

        // Mark character as detained
        target.isDetained = true

        return detention
    }

    /// Advance shuanggui detention by one turn
    func advanceDetention(_ detention: inout ShuangguiDetention, game: Game, modelContext: ModelContext) {
        detention.turnsInDetention += 1

        // Evidence accumulates each turn
        let evidenceGain = Int.random(in: 5...15)
        detention.evidenceAccumulated = min(100, detention.evidenceAccumulated + evidenceGain)

        // Phase progression based on evidence and time
        switch detention.phase {
        case .isolation:
            if detention.turnsInDetention >= 2 {
                detention.phase = .interrogation
            }
        case .interrogation:
            if detention.turnsInDetention >= 4 || detention.evidenceAccumulated >= 50 {
                detention.phase = .confession
            }
        case .confession:
            // Check for confession based on target personality
            if let target = game.character(withId: detention.targetCharacterId) {
                let confessionChance = calculateConfessionChance(target: target, detention: detention)
                if Int.random(in: 1...100) <= confessionChance {
                    detention.confessionObtained = true
                    detention.confessionType = determineConfessionType(target: target)

                    // Implicates others?
                    if detention.confessionType == .implicatedOthers {
                        detention.implicatedCharacterIds = generateImplicatedCharacters(from: target, game: game)
                    }

                    detention.phase = .documentation
                }
            }
        case .documentation:
            if detention.turnsInDetention >= detention.initiatedTurn + 8 {
                detention.phase = .referral
            }
        case .referral:
            // Ready for outcome
            break
        }

        // Check for "accidents" - rare death in detention
        if detention.turnsInDetention > 8 && detention.evidenceAccumulated >= 80 {
            if Int.random(in: 1...100) <= 5 { // 5% chance
                detention.outcome = .diedInDetention
                if let target = game.character(withId: detention.targetCharacterId) {
                    executeCharacter(target, method: .detention, game: game, modelContext: modelContext)
                }
            }
        }
    }

    /// Calculate confession chance based on target personality
    private func calculateConfessionChance(target: GameCharacter, detention: ShuangguiDetention) -> Int {
        var chance = 30 // Base 30%

        // Time pressure increases chance
        chance += detention.turnsInDetention * 5

        // Evidence pressure
        chance += detention.evidenceAccumulated / 3

        // Personality modifiers
        chance -= target.personality.loyal / 3   // High loyalty resists
        if target.personality.paranoid > 50 {
            chance -= 10                        // Paranoid characters resist
        }
        if target.personality.ambitious > 70 {
            chance += 10                        // Ambitious may confess to save themselves
        }

        return max(10, min(90, chance))
    }

    /// Determine type of confession
    /// Uses ConfessionType from HistoricalMechanics: .scripted, .resisted, .recanted, .implicatedOthers
    private func determineConfessionType(target: GameCharacter) -> ConfessionType {
        let roll = Int.random(in: 1...100)

        if target.personality.loyal > 80 {
            // Loyal characters more likely to resist
            if roll <= 50 { return .resisted }
            if roll <= 70 { return .recanted }  // May recant under pressure
            return .scripted
        } else if target.personality.ambitious > 70 {
            // Ambitious characters implicate others to save themselves
            if roll <= 60 { return .implicatedOthers }
            return .scripted
        } else {
            // Normal distribution
            if roll <= 25 { return .resisted }
            if roll <= 45 { return .recanted }
            if roll <= 75 { return .scripted }
            return .implicatedOthers
        }
    }

    /// Generate list of implicated characters from confession
    private func generateImplicatedCharacters(from target: GameCharacter, game: Game) -> [String] {
        var implicated: [String] = []

        // 40% chance to implicate each known associate
        for character in game.characters where character.id != target.id && character.isAlive {
            // Same faction = more likely to implicate
            if character.factionId == target.factionId {
                if Int.random(in: 1...100) <= 40 {
                    implicated.append(character.id.uuidString)
                }
            } else if Int.random(in: 1...100) <= 15 {
                implicated.append(character.id.uuidString)
            }

            // Limit to 3 implicated
            if implicated.count >= 3 { break }
        }

        return implicated
    }

    // MARK: - Character Fate (Death/Dismissal)

    enum ExecutionMethod: String {
        case trial          // Executed after show trial
        case detention      // "Suicide" during shuanggui
        case accident       // "Accident"
        case purge          // Mass purge execution
    }

    /// Execute a character (death)
    func executeCharacter(
        _ character: GameCharacter,
        method: ExecutionMethod,
        game: Game,
        modelContext: ModelContext
    ) {
        // Set status to executed (permanent death)
        character.status = CharacterStatus.executed.rawValue
        character.isDetained = false

        // Record death
        let deathDescription: String
        switch method {
        case .trial:
            deathDescription = "\(character.name) was executed following conviction at trial."
        case .detention:
            deathDescription = "\(character.name) died during detention. Official cause: suicide."
        case .accident:
            deathDescription = "\(character.name) died in an accident."
        case .purge:
            deathDescription = "\(character.name) was eliminated during purge operations."
        }

        // Add to game log/journal
        #if DEBUG
        print("[SECURITY] \(deathDescription)")
        #endif

        // Effects on game state
        game.applyStat("eliteLoyalty", change: 10)  // Fear increases loyalty
        game.applyStat("internationalStanding", change: -5)
        game.applyStat("stability", change: -3)

        // Vacate position
        if let positionIndex = character.positionIndex, positionIndex > 0 {
            vacatePosition(character: character, game: game)
        }
    }

    /// Dismiss a character from their position
    func dismissCharacter(
        _ character: GameCharacter,
        game: Game,
        modelContext: ModelContext
    ) {
        // Remove from current position
        if let positionIndex = character.positionIndex, positionIndex > 0 {
            vacatePosition(character: character, game: game)
            character.positionIndex = 0
            character.title = "Disgraced Former Official"
        }

        #if DEBUG
        print("[SECURITY] \(character.name) was dismissed from their position.")
        #endif
    }

    /// Demote a character by specified levels
    func demoteCharacter(
        _ character: GameCharacter,
        levels: Int,
        game: Game,
        modelContext: ModelContext
    ) {
        if let currentPosition = character.positionIndex, currentPosition > levels {
            vacatePosition(character: character, game: game)
            character.positionIndex = max(0, currentPosition - levels)
            // Title would be updated based on new position
        }

        #if DEBUG
        print("[SECURITY] \(character.name) was demoted by \(levels) position level(s).")
        #endif
    }

    /// Vacate a character's position
    private func vacatePosition(character: GameCharacter, game: Game) {
        // This would integrate with position management system
        // For now, just clear their position
        character.positionIndex = nil
    }

    // MARK: - Show Trial Integration

    /// Initiate show trial for a character
    private func initiateShowTrial(
        for character: GameCharacter,
        game: Game,
        modelContext: ModelContext
    ) {
        // This integrates with existing ShowTrialService
        // For now, set up the trial
        #if DEBUG
        print("[SECURITY] Show trial initiated for \(character.name)")
        #endif
    }

    // MARK: - NPC Autonomous Security Behavior

    /// Process autonomous security NPC actions each turn
    func processNPCSecurityActions(game: Game, modelContext: ModelContext) -> [NPCSecurityEvent] {
        var events: [NPCSecurityEvent] = []

        // Get security track officials (Position 3+)
        let securityOfficials = game.characters.filter { character in
            character.isAlive &&
            !character.isDetained &&
            character.positionTrack == "securityServices" &&
            (character.positionIndex ?? 0) >= 3
        }

        for official in securityOfficials {
            // 25% chance to take action each turn
            guard Int.random(in: 1...100) <= 25 else { continue }

            if let action = evaluateNPCSecurityAction(for: official, game: game) {
                let event = executeNPCSecurityAction(action, by: official, game: game, modelContext: modelContext)
                events.append(event)
            }
        }

        return events
    }

    /// Evaluate what security action an NPC should take
    private func evaluateNPCSecurityAction(
        for character: GameCharacter,
        game: Game
    ) -> NPCSecurityActionPlan? {
        let position = character.positionIndex ?? 0
        let goals = character.goals ?? []

        // Check for security-related goals
        // Using .rootOutTraitors as the existing goal for security NPCs who investigate
        let hasInvestigateGoal = goals.contains { $0.goalType == .rootOutTraitors || $0.goalType == .purgeEnemies }
        // Note: hasProtectGoal reserved for future defensive actions
        _ = goals.contains { $0.goalType == .protectPosition }

        // Find potential targets based on goals
        if hasInvestigateGoal {
            // Look for characters with high corruption evidence
            if let target = findCorruptTarget(for: character, game: game) {
                // Choose action based on position
                let actionId: String
                if position >= 5 {
                    actionId = "order_shuanggui"
                } else if position >= 4 {
                    actionId = "launch_formal_investigation"
                } else {
                    actionId = "open_case_file"
                }

                return NPCSecurityActionPlan(
                    actionId: actionId,
                    targetCharacterId: target.id.uuidString,
                    priority: 60
                )
            }
        }

        // Routine surveillance on random characters
        if position >= 2 {
            if let randomTarget = game.characters.filter({ $0.isAlive && $0.id != character.id }).randomElement() {
                return NPCSecurityActionPlan(
                    actionId: "conduct_surveillance",
                    targetCharacterId: randomTarget.id.uuidString,
                    priority: 30
                )
            }
        }

        return nil
    }

    /// Find a corrupt target for investigation
    private func findCorruptTarget(for investigator: GameCharacter, game: Game) -> GameCharacter? {
        let investigatorPosition = investigator.positionIndex ?? 0

        // Find characters with corruption indicators
        return game.characters
            .filter { target in
                target.isAlive &&
                target.id != investigator.id &&
                !target.isDetained &&
                (target.positionIndex ?? 0) < investigatorPosition && // Can only target juniors
                (target.factionId != investigator.factionId || investigatorPosition >= 5) // Different faction unless senior
            }
            .randomElement()
    }

    /// Execute an NPC security action
    private func executeNPCSecurityAction(
        _ plan: NPCSecurityActionPlan,
        by character: GameCharacter,
        game: Game,
        modelContext: ModelContext
    ) -> NPCSecurityEvent {
        guard let action = SecurityAction.action(withId: plan.actionId) else {
            return NPCSecurityEvent(
                id: UUID().uuidString,
                turn: game.turnNumber,
                characterId: character.id.uuidString,
                characterName: character.name,
                actionId: plan.actionId,
                targetCharacterId: plan.targetCharacterId,
                success: false,
                description: "Action not found"
            )
        }

        let target = plan.targetCharacterId.flatMap { id in
            game.characters.first { $0.id.uuidString == id }
        }

        // Calculate success
        let successChance = calculateSuccessChance(action, targetCharacter: target, for: game)
        let roll = Int.random(in: 1...100)
        let succeeded = roll <= successChance

        // Apply effects if succeeded
        if succeeded {
            applyEffects(action.successEffects, targetCharacter: target, targetFaction: nil as GameFaction?, for: game, modelContext: modelContext)

            // Special handling for detention
            if action.successEffects.initiatesShuanggui || action.successEffects.targetDetained, let target = target {
                _ = createShuangguiDetention(for: target, initiatedBy: character.name, game: game)
            }

            // Death/dismissal
            if action.successEffects.targetExecuted, let target = target {
                executeCharacter(target, method: .purge, game: game, modelContext: modelContext)
            }
            if action.successEffects.targetDismissed, let target = target {
                dismissCharacter(target, game: game, modelContext: modelContext)
            }
        }

        let description = generateNPCActionDescription(
            action: action,
            character: character,
            target: target,
            succeeded: succeeded
        )

        return NPCSecurityEvent(
            id: UUID().uuidString,
            turn: game.turnNumber,
            characterId: character.id.uuidString,
            characterName: character.name,
            actionId: action.id,
            targetCharacterId: plan.targetCharacterId,
            success: succeeded,
            description: description
        )
    }

    /// Generate description for NPC action
    private func generateNPCActionDescription(
        action: SecurityAction,
        character: GameCharacter,
        target: GameCharacter?,
        succeeded: Bool
    ) -> String {
        let targetName = target?.name ?? "unknown subject"
        let title = character.title ?? "Security Official"

        if succeeded {
            switch action.id {
            case "conduct_surveillance":
                return "\(title) \(character.name) placed \(targetName) under surveillance."
            case "open_case_file":
                return "\(title) \(character.name) opened a discipline inspection case on \(targetName)."
            case "launch_formal_investigation":
                return "The State Protection Bureau launched a formal investigation into \(targetName)."
            case "order_shuanggui":
                return "\(targetName) was detained under shuanggui by order of \(character.name)."
            default:
                return "\(character.name) executed security action: \(action.name)"
            }
        } else {
            return "\(character.name) attempted \(action.name.lowercased()) but was unsuccessful."
        }
    }

    // MARK: - Helper: Result Description

    private func generateResultDescription(
        action: SecurityAction,
        succeeded: Bool,
        targetCharacter: GameCharacter?,
        effects: SecurityEffects
    ) -> String {
        let targetName = targetCharacter?.name ?? "the target"

        if succeeded {
            switch action.id {
            case "read_security_briefing":
                return "You reviewed the latest security intelligence briefings."
            case "conduct_surveillance":
                return "Surveillance on \(targetName) yielded useful intelligence."
            case "open_case_file":
                return "A formal case file has been opened on \(targetName)."
            case "order_shuanggui":
                return "\(targetName) has been detained under shuanggui at a designated location."
            case "execute_without_trial":
                return "\(targetName) died during detention. The official report cites suicide."
            default:
                return "\(action.name) completed successfully."
            }
        } else {
            return "\(action.name) failed. \(targetName) may be aware of the attempt."
        }
    }

    // MARK: - Storage Helpers

    func getSecurityCooldowns(for game: Game) -> SecurityCooldownTracker {
        guard let data = game.variables["security_cooldowns"],
              let jsonData = data.data(using: .utf8),
              let tracker = try? JSONDecoder().decode(SecurityCooldownTracker.self, from: jsonData) else {
            return SecurityCooldownTracker()
        }
        return tracker
    }

    private func saveSecurityCooldowns(_ tracker: SecurityCooldownTracker, for game: Game) {
        if let data = try? JSONEncoder().encode(tracker),
           let string = String(data: data, encoding: .utf8) {
            game.variables["security_cooldowns"] = string
        }
    }

    func getPendingActions(for game: Game) -> [SecurityActionRecord] {
        guard let data = game.variables["security_pending_actions"],
              let jsonData = data.data(using: .utf8),
              let records = try? JSONDecoder().decode([SecurityActionRecord].self, from: jsonData) else {
            return []
        }
        return records
    }

    private func savePendingActions(_ records: [SecurityActionRecord], for game: Game) {
        if let data = try? JSONEncoder().encode(records),
           let string = String(data: data, encoding: .utf8) {
            game.variables["security_pending_actions"] = string
        }
    }

    func getActiveDetentions(for game: Game) -> [ShuangguiDetention] {
        guard let data = game.variables["active_detentions"],
              let jsonData = data.data(using: .utf8),
              let detentions = try? JSONDecoder().decode([ShuangguiDetention].self, from: jsonData) else {
            return []
        }
        return detentions
    }

    private func saveActiveDetentions(_ detentions: [ShuangguiDetention], for game: Game) {
        if let data = try? JSONEncoder().encode(detentions),
           let string = String(data: data, encoding: .utf8) {
            game.variables["active_detentions"] = string
        }
    }

    private func increaseSuspicion(for character: GameCharacter, by amount: Int, game: Game) {
        // Store suspicion levels in game variables
        let key = "suspicion_\(character.id.uuidString)"
        let current = Int(game.variables[key] ?? "0") ?? 0
        game.variables[key] = String(min(100, current + amount))
    }

    private func gatherEvidence(against character: GameCharacter, amount: Int, game: Game) {
        let key = "evidence_\(character.id.uuidString)"
        let current = Int(game.variables[key] ?? "0") ?? 0
        game.variables[key] = String(min(100, current + amount))
    }
}

// MARK: - Supporting Types

/// Plan for NPC security action
struct NPCSecurityActionPlan {
    let actionId: String
    let targetCharacterId: String?
    let priority: Int
}

/// Event generated by NPC security action
struct NPCSecurityEvent: Identifiable, Codable {
    let id: String
    let turn: Int
    let characterId: String
    let characterName: String
    let actionId: String
    let targetCharacterId: String?
    let success: Bool
    let description: String
}

// MARK: - Game Extension

extension Game {
    /// Get character by ID string
    func character(withId id: String) -> GameCharacter? {
        return characters.first { $0.id.uuidString == id }
    }
}

// MARK: - GameCharacter Extension

extension GameCharacter {
    /// Whether character is currently detained
    var isDetained: Bool {
        get { return detainedFlag ?? false }
        set { detainedFlag = newValue }
    }

    // This assumes a detainedFlag property exists or we add it
    private var detainedFlag: Bool? {
        get { return nil } // Would read from actual property
        set { } // Would write to actual property
    }
}
