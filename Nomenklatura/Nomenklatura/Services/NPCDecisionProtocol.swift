//
//  NPCDecisionProtocol.swift
//  Nomenklatura
//
//  Standardized protocol for NPC decision-making.
//  All NPC decision services should conform to this protocol for consistency.
//

import Foundation

// MARK: - NPC Decision Protocol

/// Protocol defining the standard decision-making interface for NPCs
protocol NPCDecisionMaker {
    /// Calculate motivation for a character to act
    func calculateMotivation(character: GameCharacter, game: Game, context: DecisionContext) -> Int

    /// Calculate opportunity for action
    func calculateOpportunity(character: GameCharacter, game: Game, context: DecisionContext) -> Int

    /// Calculate risk of acting
    func calculateRisk(character: GameCharacter, game: Game, context: DecisionContext) -> Int

    /// Determine if the character should act based on motivation, opportunity, and risk
    func shouldAct(character: GameCharacter, game: Game, context: DecisionContext) -> Bool
}

// MARK: - Decision Context

/// Context for NPC decision-making
struct DecisionContext {
    /// The type of decision being made
    let decisionType: NPCDecisionType

    /// Optional target character for relationship-based decisions
    let targetCharacterId: String?

    /// Optional target policy slot for political decisions
    let targetSlotId: String?

    /// Additional context data
    var contextData: [String: Any]

    init(
        decisionType: NPCDecisionType,
        targetCharacterId: String? = nil,
        targetSlotId: String? = nil,
        contextData: [String: Any] = [:]
    ) {
        self.decisionType = decisionType
        self.targetCharacterId = targetCharacterId
        self.targetSlotId = targetSlotId
        self.contextData = contextData
    }
}

/// Types of NPC decisions
enum NPCDecisionType {
    // Patron-related
    case patronWarning
    case patronOpportunity
    case patronDirective
    case patronSummons

    // Rival-related
    case rivalConfrontation
    case rivalPlot
    case rivalAttack

    // Ally-related
    case allyAssistance
    case allyRequest

    // Political
    case policyProposal
    case policyDecree
    case coalitionBuilding

    // Espionage
    case spyActivity
    case recruitment

    // Goal-driven
    case goalPursuit
    case survivalAction
}

// MARK: - Default Implementation

extension NPCDecisionMaker {
    /// Default implementation using GameplayConstants
    func shouldAct(character: GameCharacter, game: Game, context: DecisionContext) -> Bool {
        let motivation = calculateMotivation(character: character, game: game, context: context)
        let opportunity = calculateOpportunity(character: character, game: game, context: context)
        let risk = calculateRisk(character: character, game: game, context: context)

        // Calculate caution from personality
        let caution = GameplayConstants.calculateCaution(
            ambitious: character.personalityAmbitious,
            paranoid: character.personalityParanoid,
            ruthless: character.personalityRuthless
        )

        return GameplayConstants.shouldAct(
            motivation: motivation,
            opportunity: opportunity,
            risk: risk,
            caution: caution
        )
    }
}

// MARK: - Standard NPC Decision Maker

/// Standard implementation of NPC decision-making
final class StandardNPCDecisionMaker: NPCDecisionMaker {
    static let shared = StandardNPCDecisionMaker()

    private init() {}

    func calculateMotivation(character: GameCharacter, game: Game, context: DecisionContext) -> Int {
        var motivation = GameplayConstants.NPCDecision.baseMotivation

        // Goal-based motivation
        if let goals = character.goals, !goals.isEmpty {
            let highestPriority = goals.map { $0.effectivePriority(currentTurn: game.turnNumber) }.max() ?? 50
            motivation += highestPriority / 5
        }

        // Need-based motivation
        if let needs = character.needs {
            if needs.hasCriticalNeed {
                motivation += 25
            }
            motivation += needs.urgencyLevel / 5
        }

        // Personality modifiers
        motivation += character.personalityAmbitious / GameplayConstants.Personality.traitToModifierDivisor

        // Context-specific modifiers
        switch context.decisionType {
        case .rivalConfrontation, .rivalPlot, .rivalAttack:
            // Rivalries increase motivation
            if character.isRival {
                motivation += 20
            }
            motivation += game.rivalThreat / 4

        case .patronWarning, .patronDirective:
            // Patron concern increases motivation
            motivation += (GameplayConstants.Patron.lowFavorThreshold - game.patronFavor) / 2

        case .allyAssistance:
            // High disposition increases motivation to help
            motivation += (character.disposition - 50) / 3

        case .policyProposal, .policyDecree:
            // Faction interest drives political motivation
            motivation += 15

        case .goalPursuit:
            // Goal urgency drives motivation
            if let goals = character.goals {
                let urgentGoals = goals.filter { $0.effectivePriority(currentTurn: game.turnNumber) > 70 }
                motivation += urgentGoals.count * 10
            }

        case .survivalAction:
            // Survival is highly motivating
            if let needs = character.needs, needs.securityCritical {
                motivation += 40
            }

        default:
            break
        }

        return max(0, min(100, motivation))
    }

    func calculateOpportunity(character: GameCharacter, game: Game, context: DecisionContext) -> Int {
        var opportunity = 10  // Base opportunity

        // Low stability creates opportunities
        if game.stability < GameplayConstants.Stability.lowThreshold {
            opportunity += (GameplayConstants.Stability.lowThreshold - game.stability) / 2
        }

        // Position provides opportunity
        let position = character.positionIndex ?? 0
        opportunity += position * 3

        // Network strength
        opportunity += game.network / 10

        // Context-specific opportunity
        switch context.decisionType {
        case .rivalAttack:
            // Player weakness creates opportunity
            if game.standing < 40 {
                opportunity += 20
            }
            if game.patronFavor < GameplayConstants.Patron.lowFavorThreshold {
                opportunity += 15
            }

        case .patronOpportunity:
            // High favor creates opportunity
            if game.patronFavor > GameplayConstants.Patron.highFavorThreshold {
                opportunity += 25
            }

        case .policyDecree:
            // High power enables decrees
            if game.powerConsolidationScore > GameplayConstants.Power.dominantThreshold {
                opportunity += 30
            }

        case .coalitionBuilding:
            // Multiple factions provide coalition opportunities
            let activeFactions = game.factions.filter { $0.power > 30 }.count
            opportunity += activeFactions * 5

        case .recruitment:
            // Disillusioned characters are recruitment opportunities
            if let needs = character.needs, needs.isDisillusioned {
                opportunity += 25
            }

        default:
            break
        }

        return max(0, min(100, opportunity))
    }

    func calculateRisk(character: GameCharacter, game: Game, context: DecisionContext) -> Int {
        var risk = GameplayConstants.NPCDecision.baseRisk

        // High stability makes waves risky
        if game.stability > GameplayConstants.Stability.secureThreshold {
            risk += 15
        }

        // Strong player is risky to oppose
        if game.standing > 60 {
            risk += 20
        }

        // Paranoid characters perceive more risk
        risk += character.personalityParanoid / GameplayConstants.Personality.traitToModifierDivisor

        // Context-specific risk
        switch context.decisionType {
        case .rivalAttack:
            // Direct attacks are high risk
            risk += 20
            if game.patronFavor > 60 {
                risk += 15  // Protected by patron
            }

        case .policyDecree:
            // Decrees carry political risk
            risk += 25
            if game.eliteLoyalty < 50 {
                risk += 15  // Elite resentment likely
            }

        case .spyActivity:
            // Espionage is very risky
            risk += 35
            risk += game.stability / 3  // More stable states have more effective security

        case .survivalAction:
            // Survival actions have lower perceived risk
            risk -= 20

        default:
            break
        }

        return max(0, min(100, risk))
    }
}

// MARK: - Goal-Driven Decision Maker

/// Decision maker that prioritizes NPC goals
final class GoalDrivenDecisionMaker: NPCDecisionMaker {
    static let shared = GoalDrivenDecisionMaker()

    private init() {}

    func calculateMotivation(character: GameCharacter, game: Game, context: DecisionContext) -> Int {
        guard let goals = character.goals, !goals.isEmpty else {
            return StandardNPCDecisionMaker.shared.calculateMotivation(
                character: character,
                game: game,
                context: context
            )
        }

        var motivation = 0

        // Find relevant goals for this decision type
        let relevantGoals = goals.filter { isGoalRelevant($0, for: context) }

        for goal in relevantGoals {
            let effectivePriority = goal.effectivePriority(currentTurn: game.turnNumber)

            // Higher priority goals = higher motivation
            motivation += effectivePriority / 2

            // Frustrated goals increase desperation
            if goal.isFrustrated {
                motivation += 15
            }

            // Overdue goals are urgent
            if goal.isOverdue(currentTurn: game.turnNumber) {
                motivation += 20
            }
        }

        // Personality still matters
        motivation += character.personalityAmbitious / 10

        return max(0, min(100, motivation))
    }

    func calculateOpportunity(character: GameCharacter, game: Game, context: DecisionContext) -> Int {
        guard let goals = character.goals, !goals.isEmpty else {
            return StandardNPCDecisionMaker.shared.calculateOpportunity(
                character: character,
                game: game,
                context: context
            )
        }

        var opportunity = 10

        // Check if current game state aligns with goal requirements
        let relevantGoals = goals.filter { isGoalRelevant($0, for: context) }

        for goal in relevantGoals {
            // Progress toward goal indicates opportunity
            if goal.progress > 30 && goal.progress < 80 {
                opportunity += 15  // Mid-progress = good opportunity
            }

            // Check specific goal conditions
            switch goal.goalType {
            case .seekPromotion, .becomeTrackHead, .joinPolitburo:
                // Positions open up opportunity
                if game.stability < 50 {
                    opportunity += 10  // Instability creates openings
                }

            case .destroyRival:
                // Rival weakness is opportunity
                if game.rivalThreat > 50 {
                    opportunity += 15
                }

            case .buildFaction:
                // Faction power creates opportunity
                if let factionId = character.factionId,
                   let faction = game.factions.first(where: { $0.factionId == factionId }) {
                    if faction.power < 50 {
                        opportunity += 10  // Room to grow
                    }
                }

            default:
                break
            }
        }

        return max(0, min(100, opportunity))
    }

    func calculateRisk(character: GameCharacter, game: Game, context: DecisionContext) -> Int {
        guard let goals = character.goals, !goals.isEmpty else {
            return StandardNPCDecisionMaker.shared.calculateRisk(
                character: character,
                game: game,
                context: context
            )
        }

        var risk = GameplayConstants.NPCDecision.baseRisk

        // Survival goals reduce perceived risk (must act)
        let hasSurvivalGoal = goals.contains { goal in
            [.avoidPurge, .clearName, .escapeDetention, .findProtector].contains(goal.goalType)
        }
        if hasSurvivalGoal {
            risk -= 20
        }

        // Espionage goals increase risk
        let hasEspionageGoal = goals.contains { $0.goalType.isEspionageGoal }
        if hasEspionageGoal {
            risk += 25
        }

        // High stability increases risk for covert actions (better surveillance)
        risk += game.stability / 5

        // Paranoia increases perceived risk
        risk += character.personalityParanoid / 5

        return max(0, min(100, risk))
    }

    /// Check if a goal is relevant to the current decision context
    private func isGoalRelevant(_ goal: NPCGoal, for context: DecisionContext) -> Bool {
        switch context.decisionType {
        case .rivalConfrontation, .rivalPlot, .rivalAttack:
            return goal.goalType == .destroyRival || goal.goalType == .protectPosition

        case .patronWarning, .patronDirective:
            return goal.goalType == .protectPosition || goal.goalType == .findProtector

        case .policyProposal, .policyDecree:
            return goal.goalType == .implementReform || goal.goalType == .maintainOrthodoxy

        case .goalPursuit:
            return true  // All goals are relevant

        case .survivalAction:
            return [.avoidPurge, .clearName, .escapeDetention, .findProtector].contains(goal.goalType)

        case .spyActivity, .recruitment:
            return goal.goalType.isEspionageGoal

        default:
            return false
        }
    }
}

// MARK: - Memory-Influenced Decision Maker

/// Decision maker that factors in NPC memories
final class MemoryInfluencedDecisionMaker: NPCDecisionMaker {
    static let shared = MemoryInfluencedDecisionMaker()

    private init() {}

    func calculateMotivation(character: GameCharacter, game: Game, context: DecisionContext) -> Int {
        var motivation = StandardNPCDecisionMaker.shared.calculateMotivation(
            character: character,
            game: game,
            context: context
        )

        // Memories influence motivation
        let memories = character.memories

        // Grudges increase motivation for negative actions
        if context.decisionType == .rivalConfrontation ||
           context.decisionType == .rivalPlot ||
           context.decisionType == .rivalAttack {
            // Strong grudges fuel action
            let grudgeMemories = memories.filter { $0.memoryType == .betrayal || $0.memoryType == .humiliation }
            for memory in grudgeMemories {
                motivation += abs(memory.emotionalImpact) / 5
            }
        }

        // Gratitude increases motivation for helpful actions
        if context.decisionType == .allyAssistance {
            let gratitudeMemories = memories.filter { $0.memoryType == .favor || $0.memoryType == .protection }
            for memory in gratitudeMemories {
                motivation += memory.emotionalImpact / 4
            }
        }

        // Negative memories reduce motivation for risk-taking
        let negativeMemories = memories.filter { $0.emotionalImpact < -50 }
        if !negativeMemories.isEmpty && context.decisionType == .rivalAttack {
            motivation -= 15
        }

        return max(0, min(100, motivation))
    }

    func calculateOpportunity(character: GameCharacter, game: Game, context: DecisionContext) -> Int {
        // Memory doesn't strongly affect opportunity
        return StandardNPCDecisionMaker.shared.calculateOpportunity(
            character: character,
            game: game,
            context: context
        )
    }

    func calculateRisk(character: GameCharacter, game: Game, context: DecisionContext) -> Int {
        var risk = StandardNPCDecisionMaker.shared.calculateRisk(
            character: character,
            game: game,
            context: context
        )

        let memories = character.memories

        // Past failures increase perceived risk (negative impact demotions)
        let failureMemories = memories.filter { $0.memoryType == .demotion || $0.emotionalImpact < -30 }
        risk += failureMemories.count * 5

        // Past successes reduce perceived risk (promotions with positive impact)
        let successMemories = memories.filter { $0.memoryType == .promotion || $0.emotionalImpact > 50 }
        risk -= successMemories.count * 3

        // Strong negative memories increase perceived risk
        let traumaMemories = memories.filter { $0.emotionalImpact < -70 }
        risk += traumaMemories.count * 10

        return max(0, min(100, risk))
    }
}
