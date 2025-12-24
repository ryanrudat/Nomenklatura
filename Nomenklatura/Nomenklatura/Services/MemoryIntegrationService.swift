//
//  MemoryIntegrationService.swift
//  Nomenklatura
//
//  Enhances memory system integration for NPC behavior.
//  Processes memories to influence disposition, generate events, and drive character actions.
//

import Foundation
import os.log

private let memoryLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "MemorySystem")

// MARK: - Memory Integration Service

/// Service that deeply integrates NPC memories into behavior and relationships
@MainActor
final class MemoryIntegrationService {
    static let shared = MemoryIntegrationService()

    private let memoryDecisionMaker = MemoryInfluencedDecisionMaker.shared

    private init() {}

    // MARK: - Turn Processing

    /// Process all memory-related updates for the turn
    func processTurnMemoryEffects(game: Game) {
        for character in game.characters where character.isActive {
            // Process memory decay
            character.processNPCMemoryDecay(currentTurn: game.turnNumber)

            // Update disposition based on memories
            updateDispositionFromMemories(character: character, game: game)

            // Check for memory-triggered goals
            checkMemoryTriggeredGoals(character: character, game: game)

            // Ensure Foreign Affairs NPCs have diplomatic goals
            assignTrackBasedGoalsIfMissing(character: character, game: game)
        }

        // Process relationship effects from memories
        processRelationshipMemoryEffects(game: game)
    }

    // MARK: - Track-Based Goal Assignment

    /// Assign default goals based on position track if character has none
    private func assignTrackBasedGoalsIfMissing(character: GameCharacter, game: Game) {
        // Only assign if character has few or no goals
        guard character.npcGoals.count < 2 else { return }

        // Check for Foreign Affairs track
        if character.positionTrack == "foreignAffairs" || character.positionTrack == "diplomatic" {
            assignDiplomaticGoals(character: character, game: game)
        }
    }

    /// Assign diplomatic goals to Foreign Affairs NPCs
    private func assignDiplomaticGoals(character: GameCharacter, game: Game) {
        let positionIndex = character.positionIndex ?? 1

        // Check existing goals to avoid duplicates
        let existingGoalTypes = Set(character.npcGoals.map { $0.goalType })

        var goalsToAdd: [NPCGoal] = []

        // Senior officials (Position 5+) get policy and treaty goals
        if positionIndex >= 5 {
            if !existingGoalTypes.contains(.proposeForeignPolicy) && Bool.random() {
                goalsToAdd.append(NPCGoal(
                    goalType: .proposeForeignPolicy,
                    priority: 60 + Int.random(in: 0...20),
                    turnCreated: game.turnNumber
                ))
            }
            if !existingGoalTypes.contains(.negotiateTreaty) && Bool.random() {
                goalsToAdd.append(NPCGoal(
                    goalType: .negotiateTreaty,
                    priority: 55 + Int.random(in: 0...20),
                    turnCreated: game.turnNumber
                ))
            }
        }

        // Mid-level officials (Position 3+) get ally relations and trade goals
        if positionIndex >= 3 {
            if !existingGoalTypes.contains(.improveAllyRelations) && goalsToAdd.count < 2 {
                goalsToAdd.append(NPCGoal(
                    goalType: .improveAllyRelations,
                    priority: 50 + Int.random(in: 0...20),
                    turnCreated: game.turnNumber
                ))
            }
            if !existingGoalTypes.contains(.expandTradeNetwork) && goalsToAdd.count < 2 && Bool.random() {
                goalsToAdd.append(NPCGoal(
                    goalType: .expandTradeNetwork,
                    priority: 45 + Int.random(in: 0...15),
                    turnCreated: game.turnNumber
                ))
            }
        }

        // All Foreign Affairs officials may get containment or crisis goals based on world state
        if !existingGoalTypes.contains(.containCapitalistThreat) && goalsToAdd.count < 2 {
            // Assign if there's tension with capitalist countries
            let hasCapitalistThreat = game.foreignCountries.contains {
                $0.politicalBloc == .capitalist && $0.diplomaticTension > 40
            }
            if hasCapitalistThreat {
                goalsToAdd.append(NPCGoal(
                    goalType: .containCapitalistThreat,
                    priority: 55 + Int.random(in: 0...20),
                    turnCreated: game.turnNumber
                ))
            }
        }

        if !existingGoalTypes.contains(.defuseInternationalCrisis) && goalsToAdd.count < 2 {
            // Assign if there's an active crisis
            let hasCrisis = game.foreignCountries.contains { $0.diplomaticTension > 60 }
            if hasCrisis {
                goalsToAdd.append(NPCGoal(
                    goalType: .defuseInternationalCrisis,
                    priority: 75 + Int.random(in: 0...15),
                    turnCreated: game.turnNumber
                ))
            }
        }

        // Add the goals
        for goal in goalsToAdd {
            character.addGoal(goal)
            memoryLogger.info("\(character.name) assigned diplomatic goal: \(goal.goalType.displayName)")
        }
    }

    // MARK: - Disposition Updates

    /// Update a character's disposition based on their memories
    private func updateDispositionFromMemories(character: GameCharacter, game: Game) {
        // Get memories involving the player (or could track per-character dispositions)
        let playerMemories = character.npcMemoriesEnhanced.filter { memory in
            memory.involvedCharacterId == "player" && memory.isSignificant
        }

        var dispositionChange = 0

        for memory in playerMemories {
            let strengthFactor = Double(memory.currentStrength) / 100.0
            let baseEffect = memory.sentiment / 10  // -10 to +10 range

            dispositionChange += Int(Double(baseEffect) * strengthFactor)
        }

        // Apply gradual disposition drift based on memories
        if dispositionChange != 0 {
            let currentDisposition = character.disposition
            let targetDisposition = max(0, min(100, currentDisposition + dispositionChange / 5))

            // Slow drift toward memory-influenced target
            if currentDisposition < targetDisposition {
                character.disposition = min(currentDisposition + 1, targetDisposition)
            } else if currentDisposition > targetDisposition {
                character.disposition = max(currentDisposition - 1, targetDisposition)
            }
        }
    }

    // MARK: - Memory-Triggered Goals

    /// Check if memories should create new goals for a character
    private func checkMemoryTriggeredGoals(character: GameCharacter, game: Game) {
        let significantMemories = character.npcMemoriesEnhanced.filter { $0.isSignificant && !$0.isProcessed }

        for memory in significantMemories {
            if let newGoal = goalFromMemory(memory, character: character, game: game) {
                // Check if character doesn't already have this goal type
                let hasExistingGoal = character.npcGoals.contains { $0.goalType == newGoal.goalType }

                if !hasExistingGoal {
                    character.addGoal(newGoal)
                    memoryLogger.info("\(character.name) gained goal \(newGoal.goalType.displayName) from memory: \(memory.description)")
                }

                // Mark memory as processed
                markMemoryProcessed(character: character, memoryId: memory.id)
            }
        }
    }

    /// Generate a goal based on a memory
    private func goalFromMemory(_ memory: NPCMemory, character: GameCharacter, game: Game) -> NPCGoal? {
        switch memory.memoryType {
        // Betrayal memories can create revenge goals
        case .betrayal, .publicHumiliation:
            guard memory.severity >= 60, let targetId = memory.involvedCharacterId else { return nil }
            return NPCGoal(
                goalType: .avengeBetrayal,
                targetCharacterId: targetId,
                priority: min(memory.severity, 80),
                turnCreated: game.turnNumber,
                turnDeadline: game.turnNumber + 30
            )

        // Being investigated can create survival goals
        case .wasInvestigated, .suspectedOfEspionage:
            guard memory.severity >= 50 else { return nil }
            return NPCGoal(
                goalType: .clearName,
                priority: memory.severity,
                turnCreated: game.turnNumber,
                turnDeadline: game.turnNumber + 15
            )

        // Protection memories can create loyalty/repayment goals
        case .protection, .favor, .crisisCollaboration:
            guard memory.severity >= 40, let targetId = memory.involvedCharacterId else { return nil }
            return NPCGoal(
                goalType: .repayDebt,
                targetCharacterId: targetId,
                priority: memory.severity / 2 + 30,
                turnCreated: game.turnNumber
            )

        // Promotion blocked creates career revenge
        case .promotionBlocked:
            guard memory.severity >= 50, let targetId = memory.involvedCharacterId else { return nil }
            // Can either seek to destroy the blocker or just seek promotion regardless
            if memory.severity >= 70 {
                return NPCGoal(
                    goalType: .destroyRival,
                    targetCharacterId: targetId,
                    priority: memory.severity,
                    turnCreated: game.turnNumber
                )
            } else {
                return NPCGoal(
                    goalType: .seekPromotion,
                    priority: memory.severity,
                    turnCreated: game.turnNumber
                )
            }

        // Demotion creates position protection or recovery
        case .demotion:
            guard memory.severity >= 40 else { return nil }
            return NPCGoal(
                goalType: .protectPosition,
                priority: memory.severity + 20,
                turnCreated: game.turnNumber
            )

        // Being detained creates survival goals
        case .wasDetained:
            guard memory.severity >= 60 else { return nil }
            return NPCGoal(
                goalType: .avoidPurge,
                priority: 80,
                turnCreated: game.turnNumber
            )

        // Party recognition can create service goals
        case .partyCommendation:
            guard memory.severity >= 50 else { return nil }
            return NPCGoal(
                goalType: .serveTheParty,
                priority: memory.severity / 2 + 40,
                turnCreated: game.turnNumber
            )

        // Alliance formation can create faction-building goals
        case .allianceFormed:
            guard memory.severity >= 40 else { return nil }
            return NPCGoal(
                goalType: .buildFaction,
                priority: memory.severity / 2 + 30,
                turnCreated: game.turnNumber
            )

        default:
            return nil
        }
    }

    /// Mark a memory as processed
    private func markMemoryProcessed(character: GameCharacter, memoryId: UUID) {
        var memories = character.npcMemoriesEnhanced
        if let index = memories.firstIndex(where: { $0.id == memoryId }) {
            memories[index].isProcessed = true
            character.npcMemoriesEnhanced = memories
        }
    }

    // MARK: - Relationship Memory Effects

    /// Process how memories affect NPC-to-NPC relationships
    private func processRelationshipMemoryEffects(game: Game) {
        for character in game.characters where character.isActive {
            // Group memories by involved character
            let memoriesByCharacter = Dictionary(grouping: character.npcMemoriesEnhanced.filter { $0.isSignificant }) {
                $0.involvedCharacterId ?? "unknown"
            }

            for (targetId, memories) in memoriesByCharacter {
                guard targetId != "unknown" else { continue }

                // Calculate net sentiment from memories about this character
                let netSentiment = memories.reduce(0) { sum, memory in
                    let strengthFactor = Double(memory.currentStrength) / 100.0
                    return sum + Int(Double(memory.sentiment) * strengthFactor)
                }

                // Update NPC relationship if one exists
                let charId = character.id.uuidString
                for relationship in game.npcRelationships {
                    let match1 = relationship.sourceCharacterId == charId && relationship.targetCharacterId == targetId
                    let match2 = relationship.targetCharacterId == charId && relationship.sourceCharacterId == targetId
                    if match1 || match2 {
                        // Gradual drift based on memories
                        let targetTrust = relationship.trust + netSentiment / 10
                        if relationship.trust < targetTrust {
                            relationship.trust = min(relationship.trust + 1, targetTrust)
                        } else if relationship.trust > targetTrust {
                            relationship.trust = max(relationship.trust - 1, targetTrust)
                        }
                        break
                    }
                }
            }
        }
    }

    // MARK: - Memory-Based Event Generation

    /// Generate events based on NPC memories
    /// Returns events triggered by strong memories (grudges, debts, etc.)
    func evaluateMemoryDrivenActions(game: Game) -> [DynamicEvent] {
        var events: [DynamicEvent] = []

        for character in game.characters where character.isActive && !character.isPatron && !character.isRival {
            // Check for strong grudge memories that might trigger action
            if let grudgeEvent = checkGrudgeAction(character: character, game: game) {
                events.append(grudgeEvent)
            }

            // Check for gratitude memories that might trigger help
            if let gratitudeEvent = checkGratitudeAction(character: character, game: game) {
                events.append(gratitudeEvent)
            }

            // Limit to 1 memory-driven event per turn
            if events.count >= 1 {
                break
            }
        }

        return events
    }

    /// Check if a character should act on a grudge
    private func checkGrudgeAction(character: GameCharacter, game: Game) -> DynamicEvent? {
        let grudgeMemories = character.npcMemoriesEnhanced.filter { memory in
            memory.involvedCharacterId == "player" &&
            memory.memoryType.isNegative &&
            memory.currentStrength >= 50 &&
            memory.severity >= 50
        }

        guard let strongestGrudge = grudgeMemories.max(by: { $0.severity < $1.severity }) else {
            return nil
        }

        // Create decision context
        let context = DecisionContext(
            decisionType: .rivalConfrontation,
            targetCharacterId: "player",
            contextData: [
                "memoryId": strongestGrudge.id.uuidString,
                "memorySeverity": strongestGrudge.severity
            ]
        )

        // Use memory-influenced decision maker
        let shouldAct = memoryDecisionMaker.shouldAct(
            character: character,
            game: game,
            context: context
        )

        guard shouldAct else { return nil }

        let grievanceText: String
        switch strongestGrudge.memoryType {
        case .betrayal:
            grievanceText = "the betrayal they suffered"
        case .publicHumiliation:
            grievanceText = "their public humiliation"
        case .promotionBlocked:
            grievanceText = "having their career blocked"
        case .wasInvestigated:
            grievanceText = "the investigation they endured"
        case .demotion:
            grievanceText = "their demotion"
        default:
            grievanceText = "past wrongs"
        }

        memoryLogger.info("\(character.name) acting on grudge memory: \(strongestGrudge.memoryType.rawValue)")

        return DynamicEvent(
            eventType: .characterMessage,
            priority: .elevated,
            title: "\(character.name) Remembers",
            briefText: "\(character.name) has not forgotten \(grievanceText). They've been waiting for the right moment, and now they confront you. Their tone is cold, measured, but unmistakably hostile.",
            detailedText: "\"Did you think I would simply forget? That I would let it pass without consequence? I remember everything, Comrade. Everything.\"",
            initiatingCharacterId: character.id,
            initiatingCharacterName: character.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "apologize",
                    text: "Apologize and try to make amends",
                    shortText: "Apologize",
                    effects: ["standing": -5]
                ),
                EventResponse(
                    id: "defend",
                    text: "Defend your past actions",
                    shortText: "Defend",
                    effects: [:]
                ),
                EventResponse(
                    id: "threaten",
                    text: "Warn them not to pursue this grudge",
                    shortText: "Warn",
                    effects: ["standing": 3]
                ),
                EventResponse(
                    id: "dismiss",
                    text: "Dismiss their concerns",
                    shortText: "Dismiss",
                    effects: [:]
                )
            ],
            iconName: "flame.fill",
            accentColor: "sovietRed"
        )
    }

    /// Check if a character should act on gratitude
    private func checkGratitudeAction(character: GameCharacter, game: Game) -> DynamicEvent? {
        let gratitudeMemories = character.npcMemoriesEnhanced.filter { memory in
            memory.involvedCharacterId == "player" &&
            memory.memoryType.isPositive &&
            memory.currentStrength >= 50 &&
            memory.severity >= 40
        }

        guard let strongestGratitude = gratitudeMemories.max(by: { $0.severity < $1.severity }) else {
            return nil
        }

        // Only trigger occasionally
        guard Int.random(in: 0...100) < 20 else { return nil }

        // Create decision context
        let context = DecisionContext(
            decisionType: .allyAssistance,
            targetCharacterId: "player",
            contextData: [
                "memoryId": strongestGratitude.id.uuidString,
                "memorySeverity": strongestGratitude.severity
            ]
        )

        // Use memory-influenced decision maker
        let shouldAct = memoryDecisionMaker.shouldAct(
            character: character,
            game: game,
            context: context
        )

        guard shouldAct else { return nil }

        let gratitudeText: String
        switch strongestGratitude.memoryType {
        case .protection:
            gratitudeText = "the protection you provided"
        case .favor:
            gratitudeText = "the favor you did them"
        case .promotion:
            gratitudeText = "helping advance their career"
        case .kindness:
            gratitudeText = "your kindness"
        default:
            gratitudeText = "your past help"
        }

        memoryLogger.info("\(character.name) acting on gratitude memory: \(strongestGratitude.memoryType.rawValue)")

        return DynamicEvent(
            eventType: .allyRequest,
            priority: .normal,
            title: "\(character.name) Returns the Favor",
            briefText: "\(character.name) approaches you with a knowing look. They haven't forgotten \(gratitudeText), and they've come to offer something in return - information, support, or perhaps a timely warning.",
            detailedText: "\"I haven't forgotten what you did for me. I've been waiting for the right time to repay that debt. I believe that time has come.\"",
            initiatingCharacterId: character.id,
            initiatingCharacterName: character.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "accept_gratefully",
                    text: "Accept their help gratefully",
                    shortText: "Accept",
                    effects: ["network": 5, "influence": 3]
                ),
                EventResponse(
                    id: "save_favor",
                    text: "Thank them but save the favor for later",
                    shortText: "Save Favor",
                    effects: [:]
                ),
                EventResponse(
                    id: "decline_graciously",
                    text: "Tell them no debt exists between you",
                    shortText: "No Debt",
                    effects: ["standing": 3]
                )
            ],
            iconName: "gift.fill",
            accentColor: "accentGold"
        )
    }

    // MARK: - Memory Influence Calculations

    /// Calculate how memories should influence a character's behavior toward another
    func calculateMemoryInfluence(from actor: GameCharacter, toward target: GameCharacter) -> MemoryInfluence {
        let memories = actor.npcMemoriesEnhanced.filter { $0.involvedCharacterId == target.id.uuidString }

        var grudgeLevel = 0
        var gratitudeLevel = 0
        var fearLevel = 0
        var respectLevel = 0

        for memory in memories where memory.isSignificant {
            let strengthFactor = Double(memory.currentStrength) / 100.0
            let severityFactor = Double(memory.severity) / 100.0
            let combinedFactor = strengthFactor * severityFactor

            switch memory.memoryType {
            case .betrayal, .publicHumiliation, .allianceBroken, .threatReceived, .promotionBlocked:
                grudgeLevel += Int(50.0 * combinedFactor)

            case .favor, .protection, .kindness, .secretShared, .allianceFormed:
                gratitudeLevel += Int(40.0 * combinedFactor)

            case .wasDetained, .wasInvestigated, .wasReportedAsTraitor:
                fearLevel += Int(30.0 * combinedFactor)

            case .promotion, .partyCommendation, .ideologicalVictory:
                respectLevel += Int(25.0 * combinedFactor)

            default:
                if memory.sentiment > 0 {
                    gratitudeLevel += Int(15.0 * combinedFactor)
                } else if memory.sentiment < 0 {
                    grudgeLevel += Int(15.0 * combinedFactor)
                }
            }
        }

        return MemoryInfluence(
            grudge: min(100, grudgeLevel),
            gratitude: min(100, gratitudeLevel),
            fear: min(100, fearLevel),
            respect: min(100, respectLevel)
        )
    }
}

// MARK: - Memory Influence Structure

/// Represents the influence of memories on an NPC's behavior
struct MemoryInfluence {
    let grudge: Int       // 0-100, how much they want revenge
    let gratitude: Int    // 0-100, how much they want to help
    let fear: Int         // 0-100, how much they fear the target
    let respect: Int      // 0-100, how much they respect the target

    /// Net disposition modifier from memories
    var dispositionModifier: Int {
        return gratitude + respect - grudge - fear / 2
    }

    /// Whether the character harbors significant negative feelings
    var hasSignificantGrudge: Bool {
        return grudge >= 50
    }

    /// Whether the character feels significant gratitude
    var hasSignificantGratitude: Bool {
        return gratitude >= 50
    }

    /// Whether the character is significantly afraid
    var hasSignificantFear: Bool {
        return fear >= 50
    }

    /// Overall relationship tone based on memories
    var relationshipTone: RelationshipTone {
        let netPositive = gratitude + respect
        let netNegative = grudge + fear

        if netPositive > netNegative + 40 {
            return .friendly
        } else if netNegative > netPositive + 40 {
            return .hostile
        } else if fear > grudge && fear > gratitude {
            return .fearful
        } else {
            return .neutral
        }
    }

    enum RelationshipTone {
        case friendly
        case hostile
        case fearful
        case neutral
    }
}

// MARK: - GameCharacter Memory Extensions

extension GameCharacter {
    /// Get memories specifically about the player
    var memoriesAboutPlayer: [NPCMemory] {
        return npcMemoriesEnhanced.filter { $0.involvedCharacterId == "player" }
    }

    /// Net sentiment toward player based on memories
    var playerSentiment: Int {
        let memories = memoriesAboutPlayer
        return memories.reduce(0) { sum, memory in
            let strengthFactor = Double(memory.currentStrength) / 100.0
            return sum + Int(Double(memory.sentiment) * strengthFactor)
        }
    }

    /// Whether this character has significant grudge against player
    var hasGrudgeAgainstPlayer: Bool {
        return memoriesAboutPlayer.contains { memory in
            memory.memoryType.isNegative &&
            memory.currentStrength >= 50 &&
            memory.severity >= 50
        }
    }

    /// Whether this character has significant gratitude toward player
    var hasGratitudeTowardPlayer: Bool {
        return memoriesAboutPlayer.contains { memory in
            memory.memoryType.isPositive &&
            memory.currentStrength >= 50 &&
            memory.severity >= 40
        }
    }
}
