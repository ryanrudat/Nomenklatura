//
//  GameEvent.swift
//  Nomenklatura
//
//  Event log model for tracking game history
//

import Foundation
import SwiftData

@Model
final class GameEvent {
    @Attribute(.unique) var id: UUID
    var turnNumber: Int
    var eventType: String  // crisis, decision, outcome, personalAction, promotion, death, etc.
    var summary: String
    var details: [String: String]
    var importance: Int  // 1-10, higher = more likely to include in AI prompts
    var createdAt: Date

    // Decision Journal fields
    var decisionContext: String?          // The situation/crisis description
    var optionChosen: String?             // What the player chose
    var optionArchetype: String?          // The archetype of the choice (hardline, pragmatic, etc.)
    var linkedEventIds: [String]          // IDs of consequence events
    var isConsequence: Bool               // Is this a callback/consequence event?
    var sourceDecisionId: String?         // Links to original decision event
    var consequenceNote: String?          // "Your earlier decision comes back to haunt you"

    // Narrative Memory fields (for AI context)
    var fullBriefing: String?             // Complete scenario briefing text
    var presenterName: String?            // Who delivered the briefing
    var presenterTitle: String?           // Their title
    var allOptionsData: Data?             // Encoded array of all options that were available
    var narrativeSummary: String?         // AI-generated summary for future context
    var charactersInvolved: [String]      // Names of characters in this scenario
    var plotThreadIds: [String]           // Plot threads this event relates to
    var narrativeWeight: Int              // How important for story continuity (1-10)
    var wasAIGenerated: Bool              // Whether this came from AI or fallback

    var game: Game?

    init(turnNumber: Int, eventType: EventType, summary: String) {
        self.id = UUID()
        self.turnNumber = turnNumber
        self.eventType = eventType.rawValue
        self.summary = summary
        self.details = [:]
        self.importance = 5
        self.createdAt = Date()
        self.linkedEventIds = []
        self.isConsequence = false
        self.charactersInvolved = []
        self.plotThreadIds = []
        self.narrativeWeight = 5
        self.wasAIGenerated = false
    }
}

// MARK: - Option Summary (for storing all options)

struct OptionSummary: Codable {
    var id: String
    var shortDescription: String
    var archetype: String
    var wasChosen: Bool
}

extension GameEvent {
    /// Encode options for storage
    func setAllOptions(_ options: [OptionSummary]) {
        allOptionsData = try? JSONEncoder().encode(options)
    }

    /// Decode stored options
    func getAllOptions() -> [OptionSummary] {
        guard let data = allOptionsData else { return [] }
        return (try? JSONDecoder().decode([OptionSummary].self, from: data)) ?? []
    }
}

// MARK: - Event Type

enum EventType: String, Codable, CaseIterable {
    case crisis
    case decision
    case outcome
    case personalAction
    case promotion
    case demotion
    case death
    case purge
    case coup
    case gameStart
    case gameEnd
    case narrative      // Non-decision events (routine days, character moments, tension builders)
    case newspaper      // Newspaper reading events
}

// MARK: - Computed Properties

extension GameEvent {
    var currentEventType: EventType {
        EventType(rawValue: eventType) ?? .crisis
    }

    /// Display icon for event type
    var displayIcon: String {
        switch currentEventType {
        case .crisis: return "⚠️"
        case .decision: return "📋"
        case .outcome: return "📊"
        case .personalAction: return "🎭"
        case .promotion: return "📈"
        case .demotion: return "📉"
        case .death: return "💀"
        case .purge: return "🔥"
        case .coup: return "⚔️"
        case .gameStart: return "🎬"
        case .gameEnd: return "🏁"
        case .narrative: return "📖"
        case .newspaper: return "📰"
        }
    }
}
