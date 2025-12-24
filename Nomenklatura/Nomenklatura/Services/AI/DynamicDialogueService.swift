//
//  DynamicDialogueService.swift
//  Nomenklatura
//
//  Uses Claude AI to generate dynamic, contextual dialogue for NPCs.
//  Makes characters feel alive by generating personality-appropriate speech.
//

import Foundation
import os.log

private let dialogueLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "DynamicDialogue")

// MARK: - Dynamic Dialogue Service

/// Service that generates AI-powered dialogue for NPCs
final class DynamicDialogueService {
    static let shared = DynamicDialogueService()

    private let claudeClient = ClaudeClient.shared

    private init() {}

    // MARK: - Dialogue Generation

    /// Generate dialogue for a character based on context
    func generateDialogue(
        character: GameCharacter,
        context: DialogueContext,
        game: Game
    ) async throws -> GeneratedDialogue {
        let prompt = buildDialoguePrompt(character: character, context: context, game: game)

        dialogueLogger.info("Generating dialogue for \(character.name) - \(context.situation.description)")

        let response = try await claudeClient.generateScenario(prompt: prompt)

        guard let text = response.text else {
            throw DialogueError.noContentGenerated
        }

        return parseDialogueResponse(text, character: character)
    }

    /// Generate a brief character reaction
    func generateReaction(
        character: GameCharacter,
        toEvent: String,
        game: Game
    ) async throws -> String {
        let prompt = buildReactionPrompt(character: character, event: toEvent, game: game)

        let response = try await claudeClient.generateScenario(prompt: prompt)

        guard let text = response.text else {
            throw DialogueError.noContentGenerated
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate greeting dialogue for when player encounters a character
    func generateGreeting(
        character: GameCharacter,
        game: Game
    ) async throws -> String {
        let context = DialogueContext(
            situation: .greeting,
            playerAction: nil,
            recentEvents: getRecentRelevantEvents(for: character, game: game)
        )

        let dialogue = try await generateDialogue(character: character, context: context, game: game)
        return dialogue.mainDialogue
    }

    /// Generate confrontation dialogue
    func generateConfrontation(
        character: GameCharacter,
        topic: String,
        game: Game
    ) async throws -> GeneratedDialogue {
        let context = DialogueContext(
            situation: .confrontation,
            topic: topic,
            playerAction: nil,
            recentEvents: getRecentRelevantEvents(for: character, game: game)
        )

        return try await generateDialogue(character: character, context: context, game: game)
    }

    /// Generate negotiation dialogue
    func generateNegotiation(
        character: GameCharacter,
        proposal: String,
        game: Game
    ) async throws -> GeneratedDialogue {
        let context = DialogueContext(
            situation: .negotiation,
            topic: proposal,
            playerAction: nil,
            recentEvents: getRecentRelevantEvents(for: character, game: game)
        )

        return try await generateDialogue(character: character, context: context, game: game)
    }

    // MARK: - Prompt Building

    private func buildDialoguePrompt(character: GameCharacter, context: DialogueContext, game: Game) -> String {
        var prompt = """
        You are writing dialogue for a character in a Cold War-era political simulation game set in a fictional communist state.

        CHARACTER PROFILE:
        Name: \(character.name)
        Title/Position: \(character.title ?? "Official")
        Role: \(character.currentRole.rawValue.capitalized)
        Personality Traits:
        - Ambitious: \(character.personalityAmbitious)/100
        - Paranoid: \(character.personalityParanoid)/100
        - Ruthless: \(character.personalityRuthless)/100
        - Loyal: \(character.personalityLoyal)/100
        - Corrupt: \(character.personalityCorrupt)/100
        Disposition toward player: \(character.disposition)/100 (\(dispositionDescription(character.disposition)))

        """

        // Add goal context
        if let primaryGoal = character.primaryGoal {
            prompt += """

            CURRENT GOAL: \(primaryGoal.goalType.displayName)
            Goal Priority: \(primaryGoal.priority)/100
            Goal Progress: \(primaryGoal.progress)%

            """
        }

        // Add memory context
        let significantMemories = character.npcMemoriesEnhanced.filter { $0.isSignificant }.prefix(3)
        if !significantMemories.isEmpty {
            prompt += "\nKEY MEMORIES:\n"
            for memory in significantMemories {
                prompt += "- \(memory.description) (Turn \(memory.turn))\n"
            }
        }

        // Add needs context
        let needs = character.npcNeeds
        if needs.hasCriticalNeed {
            prompt += "\nCRITICAL NEED: \(needs.mostUrgentNeed.displayName) (\(needs.value(for: needs.mostUrgentNeed))/100)\n"
        }

        // Add political context
        prompt += """

        CURRENT POLITICAL SITUATION:
        - State Stability: \(game.stability)/100
        - Your (player's) Standing: \(game.standing)/100
        - Your Patron's Favor: \(game.patronFavor)/100
        - Current Turn: \(game.turnNumber)

        """

        // Add situation context
        prompt += """

        DIALOGUE SITUATION: \(context.situation.description)
        """

        if let topic = context.topic {
            prompt += "\nTOPIC: \(topic)"
        }

        if let playerAction = context.playerAction {
            prompt += "\nPLAYER'S ACTION: \(playerAction)"
        }

        if !context.recentEvents.isEmpty {
            prompt += "\nRECENT RELEVANT EVENTS:\n"
            for event in context.recentEvents {
                prompt += "- \(event)\n"
            }
        }

        // Instructions
        prompt += """

        INSTRUCTIONS:
        Generate dialogue for \(character.name) that:
        1. Reflects their personality traits (especially \(dominantTrait(character)))
        2. Takes into account their disposition toward the player
        3. References their current goals or concerns naturally
        4. Fits the Cold War communist bureaucracy setting
        5. Sounds authentic - uses appropriate formal/informal register
        6. Is between 2-5 sentences for the main dialogue
        7. Includes subtle hints about their true feelings or intentions

        FORMAT YOUR RESPONSE AS:
        DIALOGUE: [The character's actual spoken words]
        SUBTEXT: [What they really mean or are hiding]
        TONE: [One word describing their emotional tone]

        Generate the dialogue now:
        """

        return prompt
    }

    private func buildReactionPrompt(character: GameCharacter, event: String, game: Game) -> String {
        return """
        You are writing a brief reaction for a character in a Cold War-era political simulation game.

        CHARACTER: \(character.name), \(character.title ?? "Official")
        PERSONALITY: \(dominantTrait(character)) (primarily)
        DISPOSITION TOWARD PLAYER: \(character.disposition)/100 (\(dispositionDescription(character.disposition)))

        EVENT: \(event)

        Generate a brief (1-2 sentence) reaction that this character would have to this event.
        Consider their personality and how it affects their response.
        Be concise and in-character.

        REACTION:
        """
    }

    // MARK: - Response Parsing

    private func parseDialogueResponse(_ text: String, character: GameCharacter) -> GeneratedDialogue {
        var mainDialogue = ""
        var subtext: String?
        var tone = "neutral"

        let lines = text.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.lowercased().hasPrefix("dialogue:") {
                mainDialogue = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                // Remove quotes if present
                mainDialogue = mainDialogue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            } else if trimmed.lowercased().hasPrefix("subtext:") {
                subtext = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.lowercased().hasPrefix("tone:") {
                tone = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces).lowercased()
            }
        }

        // Fallback if parsing fails
        if mainDialogue.isEmpty {
            mainDialogue = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return GeneratedDialogue(
            characterId: character.id.uuidString,
            characterName: character.name,
            mainDialogue: mainDialogue,
            subtext: subtext,
            tone: mapTone(tone)
        )
    }

    // MARK: - Helper Methods

    private func dispositionDescription(_ disposition: Int) -> String {
        switch disposition {
        case 0..<20: return "hostile"
        case 20..<40: return "unfriendly"
        case 40..<60: return "neutral"
        case 60..<80: return "friendly"
        default: return "very friendly"
        }
    }

    private func dominantTrait(_ character: GameCharacter) -> String {
        let traits = [
            ("ambitious", character.personalityAmbitious),
            ("paranoid", character.personalityParanoid),
            ("ruthless", character.personalityRuthless),
            ("loyal", character.personalityLoyal),
            ("corrupt", character.personalityCorrupt)
        ]

        return traits.max(by: { $0.1 < $1.1 })?.0 ?? "pragmatic"
    }

    private func mapTone(_ toneString: String) -> DialogueTone {
        switch toneString {
        case "friendly", "warm", "welcoming":
            return .friendly
        case "hostile", "angry", "threatening":
            return .hostile
        case "fearful", "nervous", "anxious":
            return .fearful
        case "suspicious", "wary", "guarded":
            return .suspicious
        case "respectful", "formal", "deferential":
            return .respectful
        case "conspiratorial", "secretive", "hushed":
            return .conspiratorial
        case "cold", "icy", "distant":
            return .cold
        default:
            return .neutral
        }
    }

    private func getRecentRelevantEvents(for character: GameCharacter, game: Game) -> [String] {
        // Get recent events that involved this character
        let recentTurns = max(1, game.turnNumber - 5)

        var events: [String] = []

        // Check game events
        let relevantEvents = game.events.filter { event in
            event.turnNumber >= recentTurns &&
            (event.details["characterId"] == character.id.uuidString ||
             event.summary.contains(character.name))
        }

        for event in relevantEvents.prefix(3) {
            events.append(event.summary)
        }

        // Check character memories
        let recentMemories = character.npcMemoriesEnhanced.filter { memory in
            memory.turn >= recentTurns && memory.isSignificant
        }

        for memory in recentMemories.prefix(2) {
            events.append(memory.description)
        }

        return events
    }
}

// MARK: - Dialogue Context

/// Context for dialogue generation
struct DialogueContext {
    let situation: DialogueSituation
    var topic: String?
    var playerAction: String?
    var recentEvents: [String]

    init(
        situation: DialogueSituation,
        topic: String? = nil,
        playerAction: String? = nil,
        recentEvents: [String] = []
    ) {
        self.situation = situation
        self.topic = topic
        self.playerAction = playerAction
        self.recentEvents = recentEvents
    }
}

/// Types of dialogue situations
enum DialogueSituation {
    case greeting           // Initial encounter
    case farewell           // Leaving interaction
    case request            // Character asking for something
    case offer              // Character offering something
    case warning            // Character warning player
    case threat             // Character threatening player
    case negotiation        // Discussing terms
    case confrontation      // Conflict situation
    case gossip             // Sharing information
    case politicalDiscussion // Discussing politics
    case personalMatter     // Non-political conversation

    var description: String {
        switch self {
        case .greeting:
            return "Initial greeting/encounter"
        case .farewell:
            return "Ending conversation"
        case .request:
            return "Character making a request"
        case .offer:
            return "Character offering something"
        case .warning:
            return "Character giving a warning"
        case .threat:
            return "Character making a threat"
        case .negotiation:
            return "Negotiating terms or conditions"
        case .confrontation:
            return "Confrontation or conflict"
        case .gossip:
            return "Sharing rumors or information"
        case .politicalDiscussion:
            return "Political discussion"
        case .personalMatter:
            return "Personal conversation"
        }
    }
}

// MARK: - Generated Dialogue

/// Result of dialogue generation
struct GeneratedDialogue {
    let characterId: String
    let characterName: String
    let mainDialogue: String
    let subtext: String?
    let tone: DialogueTone
}

/// Emotional tone of dialogue
enum DialogueTone: String {
    case friendly
    case hostile
    case fearful
    case suspicious
    case respectful
    case conspiratorial
    case cold
    case neutral

    var iconName: String {
        switch self {
        case .friendly: return "face.smiling"
        case .hostile: return "flame"
        case .fearful: return "exclamationmark.triangle"
        case .suspicious: return "eye"
        case .respectful: return "hand.raised"
        case .conspiratorial: return "ear"
        case .cold: return "snow"
        case .neutral: return "ellipsis.bubble"
        }
    }
}

// MARK: - Errors

enum DialogueError: LocalizedError {
    case noContentGenerated
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noContentGenerated:
            return "No dialogue content was generated"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

// MARK: - Convenience Extensions

extension DynamicDialogueService {
    /// Generate enhanced event dialogue using AI
    func enhanceEventDialogue(
        event: DynamicEvent,
        sourceCharacter: GameCharacter?,
        game: Game
    ) async throws -> String? {
        guard let character = sourceCharacter else { return nil }

        let context = DialogueContext(
            situation: mapEventTypeToSituation(event.eventType),
            topic: event.title,
            recentEvents: [event.briefText]
        )

        let dialogue = try await generateDialogue(character: character, context: context, game: game)
        return dialogue.mainDialogue
    }

    private func mapEventTypeToSituation(_ eventType: DynamicEventType) -> DialogueSituation {
        switch eventType {
        case .characterMessage:
            return .gossip
        case .characterSummons:
            return .request
        case .rivalAction:
            return .threat
        case .patronDirective:
            return .warning
        case .allyRequest:
            return .request
        case .networkIntel:
            return .gossip
        default:
            return .greeting
        }
    }
}
