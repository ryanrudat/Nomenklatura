//
//  CareerEvent.swift
//  Nomenklatura
//
//  Career milestone events for the interactive timeline
//

import Foundation

/// Types of career events for the timeline
enum CareerEventType: String, Codable, CaseIterable {
    case joined          // Initial joining of Party
    case promotion       // Moved up in position
    case demotion        // Moved down in position
    case crisis          // Major crisis occurred
    case purge           // Involved in or survived a purge
    case achievement     // Badge earned or milestone reached
    case patronChange    // Patron gained/lost/changed
    case rivalChange     // Rival appeared/eliminated
    case characterDeath  // Important character died
    case policyChange    // Major policy enacted
    case internationalEvent  // Significant world event

    /// Icon for timeline display
    var icon: String {
        switch self {
        case .joined: return "star.fill"
        case .promotion: return "arrow.up.circle.fill"
        case .demotion: return "arrow.down.circle.fill"
        case .crisis: return "exclamationmark.triangle.fill"
        case .purge: return "xmark.seal.fill"
        case .achievement: return "medal.fill"
        case .patronChange: return "person.crop.circle.badge.checkmark"
        case .rivalChange: return "person.crop.circle.badge.xmark"
        case .characterDeath: return "cross.fill"
        case .policyChange: return "doc.text.fill"
        case .internationalEvent: return "globe"
        }
    }

    /// Marker shape for timeline (for vintage aesthetic)
    var markerShape: MarkerShape {
        switch self {
        case .joined, .promotion, .achievement:
            return .circle
        case .demotion, .crisis, .purge:
            return .diamond
        case .patronChange, .rivalChange:
            return .square
        case .characterDeath:
            return .cross
        case .policyChange, .internationalEvent:
            return .star
        }
    }

    /// Color for the event marker
    var color: String {
        switch self {
        case .joined, .promotion, .achievement:
            return "statHigh"  // Green
        case .demotion, .crisis, .purge, .characterDeath:
            return "statLow"   // Red
        case .patronChange, .rivalChange:
            return "accentGold"
        case .policyChange, .internationalEvent:
            return "primaryText"
        }
    }

    /// Display name for the event type
    var displayName: String {
        switch self {
        case .joined: return "JOINED"
        case .promotion: return "PROMOTED"
        case .demotion: return "DEMOTED"
        case .crisis: return "CRISIS"
        case .purge: return "PURGE"
        case .achievement: return "ACHIEVEMENT"
        case .patronChange: return "PATRON"
        case .rivalChange: return "RIVAL"
        case .characterDeath: return "DEATH"
        case .policyChange: return "POLICY"
        case .internationalEvent: return "WORLD"
        }
    }

    enum MarkerShape {
        case circle
        case diamond
        case square
        case cross
        case star
    }
}

/// A career milestone event for the timeline
struct CareerEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let turn: Int
    let type: CareerEventType
    let title: String
    let description: String
    let statSnapshot: [String: Int]  // Key stats at the moment of the event

    // Optional associated data
    let characterName: String?       // For character-related events
    let positionName: String?        // For promotion/demotion events
    let positionIndex: Int?          // Position level at time of event

    init(
        id: UUID = UUID(),
        turn: Int,
        type: CareerEventType,
        title: String,
        description: String,
        statSnapshot: [String: Int] = [:],
        characterName: String? = nil,
        positionName: String? = nil,
        positionIndex: Int? = nil
    ) {
        self.id = id
        self.turn = turn
        self.type = type
        self.title = title
        self.description = description
        self.statSnapshot = statSnapshot
        self.characterName = characterName
        self.positionName = positionName
        self.positionIndex = positionIndex
    }

    /// Create a career event from current game state
    static func from(
        game: Game,
        type: CareerEventType,
        title: String,
        description: String,
        characterName: String? = nil
    ) -> CareerEvent {
        CareerEvent(
            turn: game.turnNumber,
            type: type,
            title: title,
            description: description,
            statSnapshot: [
                "standing": game.standing,
                "network": game.network,
                "patronFavor": game.patronFavor,
                "rivalThreat": game.rivalThreat,
                "stability": game.stability
            ],
            characterName: characterName,
            positionName: game.currentPositionName,
            positionIndex: game.currentPositionIndex
        )
    }

    /// Formatted turn label for display
    var turnLabel: String {
        "Turn \(turn)"
    }

    /// Short date-like display (e.g., "T-12" for turn 12)
    var shortTurnLabel: String {
        "T-\(turn)"
    }
}

// MARK: - Career Event Factory Methods

extension CareerEvent {
    /// Create a "joined Party" event for game start
    static func gameStartEvent(game: Game) -> CareerEvent {
        CareerEvent.from(
            game: game,
            type: .joined,
            title: "Joined the Party",
            description: "Your career in the Party apparatus begins."
        )
    }

    /// Create a promotion event
    static func promotionEvent(game: Game, newPosition: String, oldPosition: String) -> CareerEvent {
        CareerEvent.from(
            game: game,
            type: .promotion,
            title: "Promoted to \(newPosition)",
            description: "Advanced from \(oldPosition) to \(newPosition)."
        )
    }

    /// Create a demotion event
    static func demotionEvent(game: Game, newPosition: String, oldPosition: String) -> CareerEvent {
        CareerEvent.from(
            game: game,
            type: .demotion,
            title: "Demoted to \(newPosition)",
            description: "Reduced from \(oldPosition) to \(newPosition)."
        )
    }

    /// Create a crisis event
    static func crisisEvent(game: Game, crisisName: String, description: String) -> CareerEvent {
        CareerEvent.from(
            game: game,
            type: .crisis,
            title: crisisName,
            description: description
        )
    }

    /// Create a patron change event
    static func patronEvent(game: Game, patronName: String, gained: Bool) -> CareerEvent {
        CareerEvent.from(
            game: game,
            type: .patronChange,
            title: gained ? "Gained Patron" : "Lost Patron",
            description: gained ?
                "\(patronName) has taken you under their protection." :
                "\(patronName) is no longer your patron.",
            characterName: patronName
        )
    }

    /// Create a rival change event
    static func rivalEvent(game: Game, rivalName: String, appeared: Bool) -> CareerEvent {
        CareerEvent.from(
            game: game,
            type: .rivalChange,
            title: appeared ? "New Rival" : "Rival Eliminated",
            description: appeared ?
                "\(rivalName) has emerged as your rival." :
                "\(rivalName) is no longer a threat.",
            characterName: rivalName
        )
    }

    /// Create a character death event
    static func deathEvent(game: Game, characterName: String, relationship: String) -> CareerEvent {
        CareerEvent.from(
            game: game,
            type: .characterDeath,
            title: "\(characterName) Died",
            description: "Your \(relationship) has passed.",
            characterName: characterName
        )
    }

    /// Create a purge event
    static func purgeEvent(game: Game, description: String, survived: Bool) -> CareerEvent {
        CareerEvent.from(
            game: game,
            type: .purge,
            title: survived ? "Survived Purge" : "Purge Initiated",
            description: description
        )
    }

    /// Create an achievement event
    static func achievementEvent(game: Game, achievementName: String, description: String) -> CareerEvent {
        CareerEvent.from(
            game: game,
            type: .achievement,
            title: achievementName,
            description: description
        )
    }
}
