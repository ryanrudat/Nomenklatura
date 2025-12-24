//
//  PositionHolder.swift
//  Nomenklatura
//
//  Tracks historical position holders for the Ladder timeline
//

import Foundation
import SwiftData

@Model
final class PositionHolder {
    @Attribute(.unique) var id: UUID
    var characterId: UUID?         // Reference to GameCharacter (if still tracked)
    var characterName: String
    var characterTitle: String?

    var positionIndex: Int         // Position on the ladder (0 = lowest)
    var positionTrack: String      // "main" or specific track like "military"

    var turnStarted: Int
    var turnEnded: Int?
    var howItEnded: String?        // PositionEndReason raw value

    var wasPlayer: Bool            // Whether this was a player-held position

    var game: Game?

    init(
        characterId: UUID? = nil,
        characterName: String,
        characterTitle: String? = nil,
        positionIndex: Int,
        positionTrack: String = "main",
        turnStarted: Int,
        wasPlayer: Bool = false
    ) {
        self.id = UUID()
        self.characterId = characterId
        self.characterName = characterName
        self.characterTitle = characterTitle
        self.positionIndex = positionIndex
        self.positionTrack = positionTrack
        self.turnStarted = turnStarted
        self.wasPlayer = wasPlayer
    }

    /// End this tenure with a reason
    func endTenure(turn: Int, reason: PositionEndReason) {
        self.turnEnded = turn
        self.howItEnded = reason.rawValue
    }
}

// MARK: - Position End Reason

enum PositionEndReason: String, Codable, CaseIterable, Sendable {
    case promoted           // Moved to higher position
    case demoted            // Moved to lower position
    case reassigned         // Lateral move
    case purged             // Forcibly removed
    case arrested           // Taken into custody
    case executed           // Death by execution
    case died               // Natural death or "natural" death
    case exiled             // Sent away
    case imprisoned         // Long-term detention
    case retired            // Voluntary or forced retirement
    case resigned           // Stepped down
    case disappeared        // Fate unknown
    case succeeded          // Natural succession (leader died, next took over)
    case rehabilitated      // Returned from previous fall

    /// Display-friendly description
    var displayText: String {
        switch self {
        case .promoted: return "Promoted"
        case .demoted: return "Demoted"
        case .reassigned: return "Reassigned"
        case .purged: return "Purged"
        case .arrested: return "Arrested"
        case .executed: return "Executed"
        case .died: return "Died"
        case .exiled: return "Exiled"
        case .imprisoned: return "Imprisoned"
        case .retired: return "Retired"
        case .resigned: return "Resigned"
        case .disappeared: return "Disappeared"
        case .succeeded: return "Succeeded"
        case .rehabilitated: return "Rehabilitated"
        }
    }

    /// Euphemistic Soviet/CCP-style description
    var euphemism: String {
        switch self {
        case .promoted: return "elevated to greater responsibilities"
        case .demoted: return "reassigned to other duties"
        case .reassigned: return "transferred to important work elsewhere"
        case .purged: return "removed for anti-party activities"
        case .arrested: return "assisting with inquiries"
        case .executed: return "convicted of crimes against the state"
        case .died: return "passed after illness"
        case .exiled: return "sent to contribute to regional development"
        case .imprisoned: return "undergoing reform through labor"
        case .retired: return "released for health reasons"
        case .resigned: return "stepped aside for personal reasons"
        case .disappeared: return "whereabouts currently unknown"
        case .succeeded: return "assumed responsibilities"
        case .rehabilitated: return "errors in previous judgment corrected"
        }
    }

    /// Icon for timeline display
    var icon: String {
        switch self {
        case .promoted: return "arrow.up.circle.fill"
        case .demoted: return "arrow.down.circle.fill"
        case .reassigned: return "arrow.left.arrow.right"
        case .purged: return "xmark.seal.fill"
        case .arrested: return "lock.fill"
        case .executed: return "xmark.circle.fill"
        case .died: return "heart.slash"
        case .exiled: return "airplane.departure"
        case .imprisoned: return "building.columns.fill"
        case .retired: return "bed.double.fill"
        case .resigned: return "door.left.hand.open"
        case .disappeared: return "questionmark.circle"
        case .succeeded: return "crown.fill"
        case .rehabilitated: return "arrow.uturn.backward.circle.fill"
        }
    }

    /// Color for timeline indicator
    var color: String {
        switch self {
        case .promoted, .succeeded, .rehabilitated:
            return "positiveGreen"
        case .demoted, .reassigned, .retired, .resigned:
            return "warningYellow"
        case .purged, .arrested, .executed, .imprisoned, .died, .exiled, .disappeared:
            return "dangerRed"
        }
    }

    /// Whether this ending is permanent/fatal
    var isPermanent: Bool {
        switch self {
        case .executed, .died:
            return true
        default:
            return false
        }
    }

    /// Whether the character might return from this fate
    var canReturn: Bool {
        switch self {
        case .disappeared, .imprisoned, .exiled, .arrested:
            return true
        default:
            return false
        }
    }
}

// MARK: - Computed Properties

extension PositionHolder {
    var endReason: PositionEndReason? {
        guard let raw = howItEnded else { return nil }
        return PositionEndReason(rawValue: raw)
    }

    /// Duration in turns
    var tenureDuration: Int? {
        guard let ended = turnEnded else { return nil }
        return ended - turnStarted
    }

    /// Whether this is a current (ongoing) tenure
    var isCurrent: Bool {
        turnEnded == nil
    }

    /// Display string for tenure
    var tenureDisplayString: String {
        if let ended = turnEnded {
            return "Turn \(turnStarted) - Turn \(ended)"
        } else {
            return "Turn \(turnStarted) - Present"
        }
    }
}
