//
//  PolicyService.swift
//  Nomenklatura
//
//  Service for managing policy slots, changes, and effects
//

import Foundation
import SwiftData

class PolicyService {
    static let shared = PolicyService()

    private init() {}

    // MARK: - Initialization

    /// Initialize all default policy slots for a new game
    func initializePolicies(for game: Game) {
        // Only initialize if empty
        guard game.policySlots.isEmpty else { return }

        // Create all 27 default policy slots
        let defaultSlots = PolicySlot.createDefaultPolicySlots()

        for slot in defaultSlots {
            slot.game = game
            game.policySlots.append(slot)
        }
    }

    // MARK: - Policy Change Validation

    /// Check if a policy change can be made
    func canChangePolicy(
        game: Game,
        slotId: String,
        toOptionId: String,
        byPlayer: Bool
    ) -> PolicyChangeValidation {
        guard let slot = game.policySlot(withId: slotId) else {
            return PolicyChangeValidation(canChange: false, reason: "Policy slot not found")
        }

        guard let option = slot.option(withId: toOptionId) else {
            return PolicyChangeValidation(canChange: false, reason: "Policy option not found")
        }

        if slot.currentOptionId == toOptionId {
            return PolicyChangeValidation(canChange: false, reason: "This policy is already active")
        }

        if byPlayer {
            // Player-specific checks
            let factionStandings = getFactionStandings(game: game)

            let (canChange, reason) = slot.canChange(
                to: toOptionId,
                playerPower: game.powerConsolidationScore,
                playerPosition: game.currentPositionIndex,
                factionStandings: factionStandings
            )

            if !canChange {
                return PolicyChangeValidation(canChange: false, reason: reason)
            }

            // Check if player has Standing Committee membership for institutional changes
            if slot.category == .institutional && game.currentPositionIndex < 7 {
                return PolicyChangeValidation(
                    canChange: false,
                    reason: "Must be on Standing Committee for institutional changes"
                )
            }
        }

        // Calculate requirements for the change
        let requirements = calculateChangeRequirements(slot: slot, option: option, game: game)

        return PolicyChangeValidation(
            canChange: true,
            reason: nil,
            powerRequired: requirements.powerRequired,
            canDecree: requirements.canDecree,
            decreePowerRequired: requirements.decreePowerRequired,
            factionSupportRequired: option.requiredFactionSupport
        )
    }

    // MARK: - Policy Change Execution

    /// Execute a policy change
    func changePolicy(
        game: Game,
        slotId: String,
        toOptionId: String,
        byCharacterId: String?,
        byPlayer: Bool,
        asDecree: Bool
    ) -> PolicyChangeResult {
        guard let slot = game.policySlot(withId: slotId) else {
            return PolicyChangeResult(success: false, message: "Policy slot not found")
        }

        guard let newOption = slot.option(withId: toOptionId) else {
            return PolicyChangeResult(success: false, message: "Policy option not found")
        }

        _ = slot.currentOptionId  // Track for potential future logging
        let previousOption = slot.currentOption

        // Record the change
        var voteResult: PolicyChangeRecord.VoteResult? = nil

        if !asDecree {
            // Simulate Standing Committee vote
            voteResult = simulateVote(game: game, slot: slot, newOption: newOption)

            // Check if vote passed
            if voteResult!.inFavor <= voteResult!.against {
                return PolicyChangeResult(
                    success: false,
                    message: "The Standing Committee rejected the proposal (\(voteResult!.inFavor) for, \(voteResult!.against) against)",
                    voteResult: voteResult
                )
            }
        }

        // Execute the change
        slot.changePolicy(
            to: toOptionId,
            changedByCharacterId: byCharacterId,
            changedByPlayer: byPlayer,
            turn: game.turnNumber,
            wasDecreed: asDecree,
            voteResult: voteResult
        )

        // Apply immediate effects
        applyPolicyEffects(game: game, newOption: newOption, previousOption: previousOption)

        // Update game tracking
        if byPlayer {
            game.lawsModifiedCount += 1
        }

        // Generate consequences
        let consequences = generateConsequences(
            game: game,
            slot: slot,
            newOption: newOption,
            previousOption: previousOption,
            wasDecreed: asDecree
        )

        // Track important changes
        if slot.slotId == "presidium_term_limits" && toOptionId == "term_limits_life_tenure" {
            game.termLimitsAbolished = true
        }

        let message = asDecree
            ? "The \(newOption.name) policy has been decreed."
            : "The Standing Committee approved \(newOption.name) (\(voteResult!.inFavor) for, \(voteResult!.against) against)"

        return PolicyChangeResult(
            success: true,
            message: message,
            voteResult: voteResult,
            consequences: consequences
        )
    }

    // MARK: - Voting Simulation

    /// Simulate a Standing Committee vote on a policy change
    private func simulateVote(
        game: Game,
        slot: PolicySlot,
        newOption: PolicyOption
    ) -> PolicyChangeRecord.VoteResult {
        // Get Standing Committee members
        guard let committee = game.standingCommittee else {
            // Default vote if no committee
            return PolicyChangeRecord.VoteResult(inFavor: 4, against: 3, abstained: 0, unanimous: false)
        }

        var inFavor = 0
        var against = 0
        var abstained = 0

        let memberIds = committee.memberIds
        let factionStandings = getFactionStandings(game: game)

        for memberId in memberIds {
            // Find the character
            guard let character = game.characters.first(where: { $0.templateId == memberId }) else {
                continue
            }

            // Determine vote based on faction alignment and policy effects
            let vote = determineVote(
                character: character,
                newOption: newOption,
                factionStandings: factionStandings,
                game: game
            )

            switch vote {
            case .inFavor: inFavor += 1
            case .against: against += 1
            case .abstain: abstained += 1
            }
        }

        // GS (if exists and is voting) gets extra weight or breaks ties
        let gsVote = determineGSVote(game: game, newOption: newOption)
        switch gsVote {
        case .inFavor: inFavor += 1
        case .against: against += 1
        case .abstain: abstained += 1
        }

        let unanimous = (against == 0 && abstained == 0) || (inFavor == 0 && abstained == 0)

        return PolicyChangeRecord.VoteResult(
            inFavor: inFavor,
            against: against,
            abstained: abstained,
            unanimous: unanimous
        )
    }

    private enum Vote {
        case inFavor, against, abstain
    }

    private func determineVote(
        character: GameCharacter,
        newOption: PolicyOption,
        factionStandings: [String: Int],
        game: Game
    ) -> Vote {
        var support = 0

        // Check if their faction benefits
        if let factionId = character.factionId {
            if newOption.beneficiaries.contains(factionId) {
                support += 30
            }
            if newOption.losers.contains(factionId) {
                support -= 30
            }

            // Check faction modifier in effects
            if let modifier = newOption.effects.factionModifiers[factionId] {
                support += modifier
            }
        }

        // Personality modifiers - determine dominant trait
        let traits = [
            ("loyal", character.personalityLoyal),
            ("ambitious", character.personalityAmbitious),
            ("paranoid", character.personalityParanoid),
            ("ruthless", character.personalityRuthless),
            ("corrupt", character.personalityCorrupt)
        ]
        let dominantPersonality = traits.max(by: { $0.1 < $1.1 })?.0 ?? "pragmatic"
        switch dominantPersonality {
        case "loyal":
            // Loyal characters follow the GS
            if game.currentPositionIndex == 8 {
                support += 20  // Player is GS, loyal follows
            }
        case "ambitious":
            // Ambitious characters support destabilizing changes
            if newOption.isExtreme {
                support += 10
            }
        case "paranoid":
            // Paranoid characters oppose extreme changes
            if newOption.isExtreme {
                support -= 20
            }
        case "principled":
            // Principled characters vote on ideology
            if newOption.beneficiaries.contains("old_guard") {
                support += 10
            }
        default:
            break
        }

        // Random factor
        support += Int.random(in: -10...10)

        if support > 15 {
            return .inFavor
        } else if support < -15 {
            return .against
        } else {
            return .abstain
        }
    }

    private func determineGSVote(game: Game, newOption: PolicyOption) -> Vote {
        // If player is GS and proposed this, they vote in favor
        if game.currentPositionIndex == 8 {
            return .inFavor
        }

        // Otherwise, determine GS vote based on effects
        // (In future, this would use the GeneralSecretaryAI)
        if newOption.effects.enablesDecrees || newOption.effects.preventsSuccession {
            return .inFavor  // GS tends to support power-concentrating policies
        }

        return .abstain
    }

    // MARK: - Effects Application

    /// Apply the effects of a policy change to the game state
    private func applyPolicyEffects(
        game: Game,
        newOption: PolicyOption,
        previousOption: PolicyOption?
    ) {
        // Remove previous effects (if any)
        if let prev = previousOption {
            game.stability -= prev.effects.stabilityModifier
            game.popularSupport -= prev.effects.popularSupportModifier
            game.eliteLoyalty -= prev.effects.eliteLoyaltyModifier
            game.industrialOutput -= prev.effects.economicOutputModifier
            game.militaryLoyalty -= prev.effects.militaryLoyaltyModifier
            game.internationalStanding -= prev.effects.internationalStandingModifier
        }

        // Apply new effects
        game.stability += newOption.effects.stabilityModifier
        game.popularSupport += newOption.effects.popularSupportModifier
        game.eliteLoyalty += newOption.effects.eliteLoyaltyModifier
        game.industrialOutput += newOption.effects.economicOutputModifier
        game.militaryLoyalty += newOption.effects.militaryLoyaltyModifier
        game.internationalStanding += newOption.effects.internationalStandingModifier

        // Clamp all stats to 0-100
        game.stability = max(0, min(100, game.stability))
        game.popularSupport = max(0, min(100, game.popularSupport))
        game.eliteLoyalty = max(0, min(100, game.eliteLoyalty))
        game.industrialOutput = max(0, min(100, game.industrialOutput))
        game.militaryLoyalty = max(0, min(100, game.militaryLoyalty))
        game.internationalStanding = max(0, min(100, game.internationalStanding))

        // Apply faction standing changes
        for (factionId, modifier) in newOption.effects.factionModifiers {
            if let faction = game.factions.first(where: { $0.factionId == factionId }) {
                faction.playerStanding = max(0, min(100, faction.playerStanding + modifier))
            }
        }
    }

    // MARK: - Consequence Generation

    /// Generate consequences for a policy change
    private func generateConsequences(
        game: Game,
        slot: PolicySlot,
        newOption: PolicyOption,
        previousOption: PolicyOption?,
        wasDecreed: Bool
    ) -> [PolicyConsequence] {
        var consequences: [PolicyConsequence] = []

        let baseSeverity = newOption.delayedConsequenceSeverity
        let decreedMultiplier = wasDecreed ? 1.5 : 1.0

        // Check if we should generate a consequence based on chance
        let roll = Int.random(in: 1...100)
        if roll > newOption.immediateConsequenceChance {
            return consequences  // No consequences this time
        }

        // Generate based on losers
        for loserFactionId in newOption.losers {
            let delay = Int.random(in: 2...6)
            let severity = Int(Double(baseSeverity * 20) * decreedMultiplier)

            let consequence = PolicyConsequence(
                type: .factionBacklash,
                description: "The \(loserFactionId.replacingOccurrences(of: "_", with: " ")) faction is organizing opposition.",
                triggerTurn: game.turnNumber + delay,
                severity: severity,
                relatedFactionId: loserFactionId,
                relatedSlotId: slot.slotId
            )
            consequences.append(consequence)
        }

        // Decree-specific consequences
        if wasDecreed {
            let consequence = PolicyConsequence(
                type: .eliteResentment,
                description: "Elite resentment grows over the bypassing of the Standing Committee.",
                triggerTurn: game.turnNumber + 3,
                severity: Int(30 * decreedMultiplier),
                relatedSlotId: slot.slotId
            )
            consequences.append(consequence)
        }

        // Extreme policy consequences
        if newOption.isExtreme {
            let consequence = PolicyConsequence(
                type: .internationalPressure,
                description: "International observers condemn the radical policy change.",
                triggerTurn: game.turnNumber + 2,
                severity: 25,
                relatedSlotId: slot.slotId
            )
            consequences.append(consequence)
        }

        return consequences
    }

    // MARK: - Helper Methods

    private func getFactionStandings(game: Game) -> [String: Int] {
        var standings: [String: Int] = [:]
        for faction in game.factions {
            standings[faction.factionId] = faction.playerStanding
        }
        return standings
    }

    private func calculateChangeRequirements(
        slot: PolicySlot,
        option: PolicyOption,
        game: Game
    ) -> (powerRequired: Int, canDecree: Bool, decreePowerRequired: Int) {
        let basePower = option.minimumPowerRequired
        let categoryDifficulty = slot.category.modificationDifficulty

        let powerRequired = max(basePower, categoryDifficulty)
        let canDecree = slot.category != .institutional && game.decreesEnabled
        let decreePowerRequired = powerRequired + 20

        return (powerRequired, canDecree, decreePowerRequired)
    }
}

// MARK: - Supporting Types

struct PolicyChangeValidation {
    let canChange: Bool
    let reason: String?
    var powerRequired: Int = 0
    var canDecree: Bool = false
    var decreePowerRequired: Int = 0
    var factionSupportRequired: [String: Int]? = nil
}

struct PolicyChangeResult {
    let success: Bool
    let message: String
    var voteResult: PolicyChangeRecord.VoteResult? = nil
    var consequences: [PolicyConsequence] = []
}

struct PolicyConsequence: Codable, Identifiable {
    let id: UUID
    let type: PolicyConsequenceType
    let description: String
    let triggerTurn: Int
    let severity: Int
    let relatedFactionId: String?
    let relatedSlotId: String?

    init(
        type: PolicyConsequenceType,
        description: String,
        triggerTurn: Int,
        severity: Int,
        relatedFactionId: String? = nil,
        relatedSlotId: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.triggerTurn = triggerTurn
        self.severity = severity
        self.relatedFactionId = relatedFactionId
        self.relatedSlotId = relatedSlotId
    }
}

enum PolicyConsequenceType: String, Codable {
    case factionBacklash
    case eliteResentment
    case popularUnrest
    case internationalPressure
    case economicDisruption
    case militaryUnrest
    case regionalTension
    case reformMovement
    case conservativeReaction
}
