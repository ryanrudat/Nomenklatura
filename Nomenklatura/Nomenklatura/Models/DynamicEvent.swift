//
//  DynamicEvent.swift
//  Nomenklatura
//
//  Dynamic events that make NPCs feel alive and consequences visible
//

import Foundation

// MARK: - Dynamic Event Model

struct DynamicEvent: Codable, Identifiable {
    var id: UUID = UUID()
    var eventType: DynamicEventType
    var priority: EventPriority

    // Content
    var title: String
    var briefText: String
    var detailedText: String?
    var flavorText: String?

    // Source character (if character-initiated)
    var initiatingCharacterId: UUID?
    var initiatingCharacterName: String?
    var relatedCharacterIds: [UUID]?

    // Timing
    var turnGenerated: Int
    var expiresOnTurn: Int?
    var isUrgent: Bool

    // Response options (nil = simple acknowledge)
    var responseOptions: [EventResponse]?

    // For consequence callbacks - links to original decision
    var linkedDecisionId: String?
    var linkedTurnNumber: Int?
    var callbackFlag: String?  // Flag to mark this callback as resolved

    // Visual styling hints
    var iconName: String?
    var accentColor: String?
}

// MARK: - Event Types

enum DynamicEventType: String, Codable {
    case characterMessage      // NPC reaches out informally
    case characterSummons      // NPC demands a meeting
    case consequenceCallback   // Past decision resurfaces
    case urgentInterruption    // Crisis breaks routine
    case ambientTension        // Foreshadowing, no action needed
    case rivalAction           // Rival makes a move against you
    case patronDirective       // Patron gives orders or warnings
    case networkIntel          // Contacts share information
    case allyRequest           // Ally asks for help
    case worldNews             // External events affecting player

    var displayName: String {
        switch self {
        case .characterMessage: return "Message"
        case .characterSummons: return "Summons"
        case .consequenceCallback: return "Consequences"
        case .urgentInterruption: return "Urgent"
        case .ambientTension: return "Whispers"
        case .rivalAction: return "Rival Move"
        case .patronDirective: return "From Your Patron"
        case .networkIntel: return "Intelligence"
        case .allyRequest: return "Request"
        case .worldNews: return "News"
        }
    }

    var defaultIcon: String {
        switch self {
        case .characterMessage: return "envelope.fill"
        case .characterSummons: return "bell.fill"
        case .consequenceCallback: return "arrow.uturn.backward.circle.fill"
        case .urgentInterruption: return "exclamationmark.triangle.fill"
        case .ambientTension: return "eye.fill"
        case .rivalAction: return "bolt.fill"
        case .patronDirective: return "hand.raised.fill"
        case .networkIntel: return "antenna.radiowaves.left.and.right"
        case .allyRequest: return "person.fill.questionmark"
        case .worldNews: return "newspaper.fill"
        }
    }

    var requiresResponse: Bool {
        switch self {
        case .ambientTension, .worldNews:
            return false
        default:
            return true
        }
    }

    /// Minimum position index for this event type
    /// Ensures events are appropriate for player's rank
    var minimumPositionIndex: Int {
        switch self {
        case .ambientTension, .worldNews:
            return 0  // Anyone can hear whispers and news
        case .characterMessage:
            return 1  // Basic NPC contact from Junior level
        case .networkIntel:
            return 2  // Need some network to receive intel
        case .allyRequest:
            return 2  // Need to be established enough to have real allies
        case .rivalAction:
            return 2  // Rivals only target those with something to lose
        case .patronDirective:
            return 1  // Patrons guide even junior members
        case .characterSummons:
            return 2  // Formal summons for those with some standing
        case .consequenceCallback:
            return 0  // Consequences can hit anyone
        case .urgentInterruption:
            return 3  // Major crises only reach those with authority
        }
    }

    /// Maximum position index (nil = no max)
    /// Prevents trivial events for senior officials
    var maximumPositionIndex: Int? {
        switch self {
        case .ambientTension:
            return 5  // Senior officials get direct reports, not whispers
        default:
            return nil
        }
    }

    /// Check if this event type is appropriate for given position
    func isAppropriate(forPositionIndex index: Int) -> Bool {
        if index < minimumPositionIndex {
            return false
        }
        if let max = maximumPositionIndex, index > max {
            return false
        }
        return true
    }
}

// MARK: - Event Priority

enum EventPriority: Int, Codable, Comparable, Sendable {
    case background = 0       // Can be missed, lowest priority
    case normal = 1           // Shows when there's room
    case elevated = 2         // Shows soon
    case urgent = 3           // Shows this turn
    case critical = 4         // Interrupts current flow immediately

    nonisolated static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var cooldownTurns: Int {
        switch self {
        case .background: return 3
        case .normal: return 2
        case .elevated: return 2
        case .urgent: return 1
        case .critical: return 0
        }
    }
}

// MARK: - Event Response

struct EventResponse: Codable, Identifiable {
    var id: String
    var text: String
    var shortText: String?  // For button label
    var effects: [String: Int]
    var riskLevel: RiskLevel?
    var followUpHint: String?
    var setsFlag: String?
    var removesFlag: String?

    enum RiskLevel: String, Codable {
        case low
        case medium
        case high

        var color: String {
            switch self {
            case .low: return "statHigh"
            case .medium: return "statMedium"
            case .high: return "statLow"
            }
        }
    }
}

// MARK: - Event Trigger Conditions

enum EventTriggerCondition: Codable {
    case statBelow(stat: String, threshold: Int)
    case statAbove(stat: String, threshold: Int)
    case patronFavorBelow(threshold: Int)
    case patronFavorAbove(threshold: Int)
    case rivalThreatAbove(threshold: Int)
    case characterDispositionAbove(characterId: UUID, threshold: Int)
    case characterDispositionBelow(characterId: UUID, threshold: Int)
    case turnsSinceDecision(decisionId: String, minTurns: Int, maxTurns: Int)
    case hasFlag(flag: String)
    case lacksFlag(flag: String)
    case positionAtLeast(index: Int)
    case randomChance(probability: Double)

    func isMet(game: Game) -> Bool {
        switch self {
        case .statBelow(let stat, let threshold):
            return getStatValue(stat, game: game) < threshold
        case .statAbove(let stat, let threshold):
            return getStatValue(stat, game: game) > threshold
        case .patronFavorBelow(let threshold):
            return game.patronFavor < threshold
        case .patronFavorAbove(let threshold):
            return game.patronFavor > threshold
        case .rivalThreatAbove(let threshold):
            return game.rivalThreat > threshold
        case .characterDispositionAbove(let characterId, let threshold):
            return game.characters.first(where: { $0.id == characterId })?.disposition ?? 0 > threshold
        case .characterDispositionBelow(let characterId, let threshold):
            return game.characters.first(where: { $0.id == characterId })?.disposition ?? 100 < threshold
        case .turnsSinceDecision(let decisionId, let minTurns, let maxTurns):
            guard let event = game.events.first(where: { $0.details["decisionId"] == decisionId }) else {
                return false
            }
            let turnsSince = game.turnNumber - event.turnNumber
            return turnsSince >= minTurns && turnsSince <= maxTurns
        case .hasFlag(let flag):
            return game.flags.contains(flag)
        case .lacksFlag(let flag):
            return !game.flags.contains(flag)
        case .positionAtLeast(let index):
            return game.currentPositionIndex >= index
        case .randomChance(let probability):
            return Double.random(in: 0...1) < probability
        }
    }

    private func getStatValue(_ stat: String, game: Game) -> Int {
        switch stat {
        case "stability": return game.stability
        case "popularSupport": return game.popularSupport
        case "militaryLoyalty": return game.militaryLoyalty
        case "eliteLoyalty": return game.eliteLoyalty
        case "treasury": return game.treasury
        case "industrialOutput": return game.industrialOutput
        case "foodSupply": return game.foodSupply
        case "internationalStanding": return game.internationalStanding
        case "standing": return game.standing
        case "network": return game.network
        default: return 50
        }
    }
}

// MARK: - Character Action Types (for agency system)

enum CharacterActionType: String, Codable {
    // Patron actions
    case patronWarning
    case patronOpportunity
    case patronDirective
    case patronSummons

    // Rival actions
    case rivalProbe
    case rivalAttack
    case rivalThreat
    case rivalScheme

    // Ally actions
    case allyIntel
    case allyRequest
    case allyWarning

    // Network actions
    case contactIntel
    case contactRequest
}

// MARK: - Event Templates

struct DynamicEventTemplate {
    let eventType: DynamicEventType
    let priority: EventPriority
    let titleTemplates: [String]
    let briefTextTemplates: [String]
    let detailedTextTemplates: [String]?
    let responseTemplates: [[String: Any]]?
    let conditions: [EventTriggerCondition]

    func generate(game: Game, character: GameCharacter?) -> DynamicEvent {
        let title = titleTemplates.randomElement() ?? "Event"
        var briefText = briefTextTemplates.randomElement() ?? ""
        var detailedText = detailedTextTemplates?.randomElement()

        // Replace placeholders
        if let char = character {
            briefText = briefText.replacingOccurrences(of: "{CHARACTER}", with: char.name)
            briefText = briefText.replacingOccurrences(of: "{TITLE}", with: char.title ?? "Official")
            detailedText = detailedText?.replacingOccurrences(of: "{CHARACTER}", with: char.name)
            detailedText = detailedText?.replacingOccurrences(of: "{TITLE}", with: char.title ?? "Official")
        }

        // Generate responses if templates exist
        var responses: [EventResponse]? = nil
        if let templates = responseTemplates {
            responses = templates.compactMap { template -> EventResponse? in
                guard let id = template["id"] as? String,
                      let text = template["text"] as? String else { return nil }
                return EventResponse(
                    id: id,
                    text: text,
                    shortText: template["shortText"] as? String,
                    effects: template["effects"] as? [String: Int] ?? [:],
                    riskLevel: (template["risk"] as? String).flatMap { EventResponse.RiskLevel(rawValue: $0) },
                    followUpHint: template["followUp"] as? String,
                    setsFlag: template["setsFlag"] as? String,
                    removesFlag: template["removesFlag"] as? String
                )
            }
        }

        return DynamicEvent(
            eventType: eventType,
            priority: priority,
            title: title,
            briefText: briefText,
            detailedText: detailedText,
            initiatingCharacterId: character?.id,
            initiatingCharacterName: character?.name,
            turnGenerated: game.turnNumber,
            isUrgent: priority >= .urgent,
            responseOptions: responses,
            iconName: eventType.defaultIcon
        )
    }
}
