//
//  DramaticIrony.swift
//  Nomenklatura
//
//  Models for dramatic irony - letting the player know things that NPCs don't.
//  In Communist systems, intelligence networks, whisper networks, and show trials
//  mean that those with connections know about purges before they happen.
//
//  Foreshadowing visibility is gated by the player's Network stat:
//  - Distant events: Network >= 70
//  - Approaching: Network >= 50
//  - Imminent: Network >= 30
//

import Foundation

// MARK: - Foreshadowing Type

/// The type of future event being foreshadowed
enum ForeshadowingType: String, Codable, CaseIterable {
    case impendingPurge          // Someone is about to be purged
    case betrayalComing          // An ally is planning betrayal
    case promotionPending        // Someone is being considered for promotion
    case allianceShifting        // Coalition/alliance is changing
    case rehabilitationPossible  // Fallen character may return
    case rivalMoves              // Rival is planning action against player
    case factionScheme           // Faction is coordinating something
    case scProposal              // SC proposal being prepared
    case investigationOpening    // Investigation about to begin
    case patronWavering          // Patron's support is weakening

    var displayName: String {
        switch self {
        case .impendingPurge: return "Impending Purge"
        case .betrayalComing: return "Betrayal Warning"
        case .promotionPending: return "Promotion Pending"
        case .allianceShifting: return "Alliance Shifting"
        case .rehabilitationPossible: return "Rehabilitation Possible"
        case .rivalMoves: return "Rival Moves"
        case .factionScheme: return "Faction Activity"
        case .scProposal: return "Committee Activity"
        case .investigationOpening: return "Investigation Opening"
        case .patronWavering: return "Patron Wavering"
        }
    }

    var iconName: String {
        switch self {
        case .impendingPurge: return "exclamationmark.triangle.fill"
        case .betrayalComing: return "person.crop.circle.badge.xmark"
        case .promotionPending: return "arrow.up.circle.fill"
        case .allianceShifting: return "arrow.left.arrow.right.circle"
        case .rehabilitationPossible: return "arrow.uturn.backward.circle"
        case .rivalMoves: return "figure.fencing"
        case .factionScheme: return "person.3.fill"
        case .scProposal: return "doc.text.fill"
        case .investigationOpening: return "magnifyingglass.circle.fill"
        case .patronWavering: return "hand.raised.slash.fill"
        }
    }

    /// How threatening is this type to the player
    var threatLevel: Int {
        switch self {
        case .impendingPurge: return 30      // Depends on target
        case .betrayalComing: return 80      // Direct threat
        case .promotionPending: return 10    // Usually neutral
        case .allianceShifting: return 40    // Context dependent
        case .rehabilitationPossible: return 20  // Could be good or bad
        case .rivalMoves: return 70          // Direct threat
        case .factionScheme: return 50       // Depends on faction
        case .scProposal: return 30          // Could affect player
        case .investigationOpening: return 60 // Potentially dangerous
        case .patronWavering: return 65      // Loss of protection
        }
    }
}

// MARK: - Foreshadowing Urgency

/// How soon the foreshadowed event will occur
enum ForeshadowingUrgency: String, Codable, CaseIterable {
    case distant       // 5+ turns away
    case approaching   // 2-4 turns away
    case imminent      // 1 turn away

    var displayName: String {
        switch self {
        case .distant: return "Distant Rumors"
        case .approaching: return "Growing Concern"
        case .imminent: return "Imminent"
        }
    }

    /// Network stat required to detect this level of foreshadowing
    var networkRequired: Int {
        switch self {
        case .distant: return 70
        case .approaching: return 50
        case .imminent: return 30
        }
    }

    var turnsAway: ClosedRange<Int> {
        switch self {
        case .distant: return 5...10
        case .approaching: return 2...4
        case .imminent: return 1...1
        }
    }
}

// MARK: - Foreshadowing Alert

/// A hint about a future event
struct ForeshadowingAlert: Codable, Identifiable {
    var id: UUID = UUID()
    var type: ForeshadowingType
    var urgency: ForeshadowingUrgency
    var content: String                    // The actual intelligence/hint
    var sourceDescription: String          // "A trusted source reveals..."

    // Related entities
    var relatedCharacterId: String?
    var relatedCharacterName: String?
    var relatedFactionId: String?
    var relatedFactionName: String?

    // Metadata
    var turnReceived: Int
    var estimatedTurnToOccur: Int          // When the event will likely happen
    var confidenceLevel: Int               // 0-100, how reliable is this intel

    // Resolution tracking
    var hasOccurred: Bool = false
    var wasAccurate: Bool?                 // Was the prediction correct?
    var actualOutcome: String?             // What really happened

    /// How dangerous this alert is to the player
    var threatToPlayer: Int {
        var threat = type.threatLevel

        // Imminent is more threatening
        if urgency == .imminent {
            threat += 20
        } else if urgency == .approaching {
            threat += 10
        }

        return min(100, threat)
    }

    /// Time remaining until estimated event
    func turnsRemaining(currentTurn: Int) -> Int {
        return max(0, estimatedTurnToOccur - currentTurn)
    }

    /// Whether this alert is still relevant
    func isStillRelevant(currentTurn: Int) -> Bool {
        if hasOccurred { return false }
        // Alert is relevant if event hasn't happened yet or just happened
        return currentTurn <= estimatedTurnToOccur + 2
    }
}

// MARK: - Intelligence Source Quality

/// Quality of the intelligence source
enum IntelligenceSourceQuality: String, Codable {
    case trusted       // Very reliable source
    case credible      // Generally reliable
    case rumor         // Unconfirmed, could be wrong
    case speculation   // Low confidence

    var confidenceRange: ClosedRange<Int> {
        switch self {
        case .trusted: return 75...95
        case .credible: return 55...75
        case .rumor: return 35...55
        case .speculation: return 15...35
        }
    }

    var sourcePrefix: String {
        switch self {
        case .trusted: return "A trusted source within the apparatus confirms"
        case .credible: return "Credible reports suggest"
        case .rumor: return "Whispers in the corridors indicate"
        case .speculation: return "Unconfirmed speculation suggests"
        }
    }
}

// MARK: - Dramatic Irony State

/// Tracks all active foreshadowing for the current game
struct DramaticIronyState: Codable {
    var activeAlerts: [ForeshadowingAlert] = []
    var resolvedAlerts: [ForeshadowingAlert] = []
    var totalAccurateAlerts: Int = 0
    var totalInaccurateAlerts: Int = 0

    /// Add a new foreshadowing alert
    mutating func addAlert(_ alert: ForeshadowingAlert) {
        activeAlerts.append(alert)
    }

    /// Mark an alert as resolved
    mutating func resolveAlert(id: UUID, wasAccurate: Bool, outcome: String) {
        if let index = activeAlerts.firstIndex(where: { $0.id == id }) {
            var alert = activeAlerts.remove(at: index)
            alert.hasOccurred = true
            alert.wasAccurate = wasAccurate
            alert.actualOutcome = outcome
            resolvedAlerts.append(alert)

            if wasAccurate {
                totalAccurateAlerts += 1
            } else {
                totalInaccurateAlerts += 1
            }
        }
    }

    /// Get alerts visible to player based on Network stat
    func visibleAlerts(networkStat: Int) -> [ForeshadowingAlert] {
        return activeAlerts.filter { alert in
            networkStat >= alert.urgency.networkRequired
        }
    }

    /// Clean up old, irrelevant alerts
    mutating func cleanupAlerts(currentTurn: Int) {
        activeAlerts.removeAll { !$0.isStillRelevant(currentTurn: currentTurn) }
    }

    /// Accuracy rate of intelligence
    var intelligenceAccuracy: Double {
        let total = totalAccurateAlerts + totalInaccurateAlerts
        guard total > 0 else { return 0.5 }
        return Double(totalAccurateAlerts) / Double(total)
    }
}

// MARK: - Surprising Reversal Types

/// Types of surprising reversals that can occur
enum ReversalType: String, Codable, CaseIterable {
    case rehabilitation          // Purged character returns
    case betrayal               // Loyal ally turns traitor
    case unexpectedAlly         // Enemy becomes ally
    case secretRevealed         // Hidden information comes to light
    case powerShift             // Sudden change in power dynamics
    case patronFall             // Patron loses power
    case rivalDownfall          // Rival unexpectedly falls

    var displayName: String {
        switch self {
        case .rehabilitation: return "Rehabilitation"
        case .betrayal: return "Betrayal"
        case .unexpectedAlly: return "Unexpected Alliance"
        case .secretRevealed: return "Secret Revealed"
        case .powerShift: return "Power Shift"
        case .patronFall: return "Patron's Fall"
        case .rivalDownfall: return "Rival's Downfall"
        }
    }

    var dramaticWeight: Int {
        switch self {
        case .rehabilitation: return 70
        case .betrayal: return 90
        case .unexpectedAlly: return 60
        case .secretRevealed: return 75
        case .powerShift: return 80
        case .patronFall: return 85
        case .rivalDownfall: return 65
        }
    }
}

/// Record of a surprising reversal that occurred
struct SurprisingReversal: Codable, Identifiable {
    var id: UUID = UUID()
    var type: ReversalType
    var turnOccurred: Int
    var headline: String
    var narrative: String

    var involvedCharacterId: String?
    var involvedCharacterName: String?

    // Whether player had warning
    var wasForeshadowed: Bool
    var foreshadowingAlertId: UUID?

    // Impact
    var playerImpact: String   // How this affects the player
}
