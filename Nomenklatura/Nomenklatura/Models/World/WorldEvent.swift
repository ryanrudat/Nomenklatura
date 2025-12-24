//
//  WorldEvent.swift
//  Nomenklatura
//
//  Dynamic world events for the living world simulation
//

import Foundation
import SwiftData

// MARK: - World Event Type

/// Types of autonomous world events
enum WorldEventType: String, Codable, CaseIterable, Sendable {
    // Political events
    case leadershipChange       // New leader in foreign nation
    case coup                   // Violent government change
    case revolution             // Mass uprising
    case purge                  // Internal party purge
    case electionResult         // Democratic election outcome

    // Economic events
    case economicCrisis         // Market crash, depression
    case industrialAccident     // Factory explosion, etc.
    case harvestFailure         // Agricultural disaster
    case tradeDispute           // Trade war escalation
    case resourceDiscovery      // New oil/mineral find

    // Military events
    case borderIncident         // Shots fired at border
    case armsBuildUp            // Military expansion
    case defection              // High-profile defector
    case militaryExercise       // Show of force
    case proxyConflict          // Third-party war involvement

    // Diplomatic events
    case treatyProposal         // Offer of agreement
    case treatyViolation        // Breaking existing agreement
    case ambassadorRecall       // Diplomatic crisis
    case summitAnnouncement     // High-level meeting
    case secretNegotiations     // Hidden talks revealed

    var displayName: String {
        switch self {
        case .leadershipChange: return "Leadership Change"
        case .coup: return "Coup d'Etat"
        case .revolution: return "Revolution"
        case .purge: return "Political Purge"
        case .electionResult: return "Election Result"
        case .economicCrisis: return "Economic Crisis"
        case .industrialAccident: return "Industrial Accident"
        case .harvestFailure: return "Harvest Failure"
        case .tradeDispute: return "Trade Dispute"
        case .resourceDiscovery: return "Resource Discovery"
        case .borderIncident: return "Border Incident"
        case .armsBuildUp: return "Arms Build-Up"
        case .defection: return "Defection"
        case .militaryExercise: return "Military Exercise"
        case .proxyConflict: return "Proxy Conflict"
        case .treatyProposal: return "Treaty Proposal"
        case .treatyViolation: return "Treaty Violation"
        case .ambassadorRecall: return "Ambassador Recall"
        case .summitAnnouncement: return "Summit Announcement"
        case .secretNegotiations: return "Secret Negotiations Revealed"
        }
    }

    var iconName: String {
        switch self {
        case .leadershipChange, .electionResult: return "person.badge.shield.checkmark"
        case .coup, .revolution: return "flame.fill"
        case .purge: return "xmark.seal.fill"
        case .economicCrisis, .tradeDispute: return "chart.line.downtrend.xyaxis"
        case .industrialAccident: return "exclamationmark.triangle.fill"
        case .harvestFailure: return "leaf.fill"
        case .resourceDiscovery: return "diamond.fill"
        case .borderIncident, .militaryExercise: return "shield.fill"
        case .armsBuildUp, .proxyConflict: return "airplane.departure"
        case .defection: return "figure.walk.departure"
        case .treatyProposal, .treatyViolation: return "doc.text.fill"
        case .ambassadorRecall: return "arrow.uturn.left"
        case .summitAnnouncement, .secretNegotiations: return "person.2.fill"
        }
    }

    var severity: EventSeverity {
        switch self {
        case .revolution, .coup: return .critical
        case .borderIncident, .economicCrisis, .treatyViolation, .proxyConflict: return .major
        case .leadershipChange, .purge, .armsBuildUp, .ambassadorRecall: return .significant
        case .electionResult, .harvestFailure, .industrialAccident, .militaryExercise: return .moderate
        case .defection, .treatyProposal, .tradeDispute, .summitAnnouncement, .secretNegotiations, .resourceDiscovery: return .minor
        }
    }
}

// MARK: - Event Severity

enum EventSeverity: Int, Codable, Comparable, Sendable {
    case minor = 1
    case moderate = 2
    case significant = 3
    case major = 4
    case critical = 5

    nonisolated static func < (lhs: EventSeverity, rhs: EventSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .minor: return "Minor"
        case .moderate: return "Moderate"
        case .significant: return "Significant"
        case .major: return "Major"
        case .critical: return "Critical"
        }
    }
}

// MARK: - World Event

/// A single world event in the simulation
struct WorldEvent: Codable, Identifiable, Sendable {
    var id: String = UUID().uuidString
    var eventType: WorldEventType
    var turnOccurred: Int
    var countryId: String
    var headline: String
    var description: String
    var isClassified: Bool         // Requires intelligence clearance to see
    var wasPlayerInvolved: Bool    // Did player action cause this
    var consequences: [WorldEventConsequence]

    // Optional follow-up
    var requiresResponse: Bool     // Player must respond
    var responseDeadline: Int?     // Turn by which response needed
    var hasBeenRead: Bool = false

    init(
        eventType: WorldEventType,
        turnOccurred: Int,
        countryId: String,
        headline: String,
        description: String,
        isClassified: Bool = false,
        wasPlayerInvolved: Bool = false,
        requiresResponse: Bool = false
    ) {
        self.eventType = eventType
        self.turnOccurred = turnOccurred
        self.countryId = countryId
        self.headline = headline
        self.description = description
        self.isClassified = isClassified
        self.wasPlayerInvolved = wasPlayerInvolved
        self.requiresResponse = requiresResponse
        self.consequences = []
    }

    var severity: EventSeverity {
        eventType.severity
    }
}

// MARK: - World Event Consequence

/// Consequences of a world event
struct WorldEventConsequence: Codable, Sendable {
    var type: ConsequenceType
    var targetId: String?          // Country or region ID
    var amount: Int
    var description: String

    enum ConsequenceType: String, Codable, Sendable {
        case relationshipChange     // Change relationship with country
        case economicImpact         // Affect treasury/trade
        case stabilityImpact        // Affect national stability
        case militaryTension        // Increase/decrease tensions
        case triggerFollowUp        // Causes another event
    }
}

// MARK: - World Event History (SwiftData Model)

// Helper functions for JSON encoding/decoding outside of MainActor isolation
private func encodeWorldEvent(_ event: WorldEvent) -> Data {
    (try? JSONEncoder().encode(event)) ?? Data()
}

private func decodeWorldEvent(from data: Data) -> WorldEvent? {
    try? JSONDecoder().decode(WorldEvent.self, from: data)
}

@Model
final class WorldEventRecord {
    @Attribute(.unique) var id: UUID
    var eventData: Data           // Encoded WorldEvent
    var turnOccurred: Int
    var countryId: String
    var eventTypeRaw: String
    var headline: String
    var severityRaw: Int
    var hasBeenRead: Bool
    var wasPlayerInvolved: Bool
    var isClassified: Bool

    @Relationship(inverse: \Game.worldEventHistory) var game: Game?

    init(event: WorldEvent) {
        self.id = UUID()
        self.eventData = encodeWorldEvent(event)
        self.turnOccurred = event.turnOccurred
        self.countryId = event.countryId
        self.eventTypeRaw = event.eventType.rawValue
        self.headline = event.headline
        self.severityRaw = event.severity.rawValue
        self.hasBeenRead = event.hasBeenRead
        self.wasPlayerInvolved = event.wasPlayerInvolved
        self.isClassified = event.isClassified
    }

    var event: WorldEvent? {
        decodeWorldEvent(from: eventData)
    }

    var eventType: WorldEventType? {
        WorldEventType(rawValue: eventTypeRaw)
    }

    var severity: EventSeverity? {
        EventSeverity(rawValue: severityRaw)
    }
}

// MARK: - News Briefing

/// A collection of world events formatted as a daily briefing
struct NewsBriefing: Codable, Identifiable {
    var id: String = UUID().uuidString
    var turn: Int
    var events: [WorldEvent]
    var summaryHeadline: String
    var isUrgent: Bool

    var unreadCount: Int {
        events.filter { !$0.hasBeenRead }.count
    }

    var highestSeverity: EventSeverity {
        events.map { $0.severity }.max() ?? .minor
    }

    /// Generate summary headline from events
    static func generateHeadline(from events: [WorldEvent]) -> String {
        guard let topEvent = events.max(by: { $0.severity < $1.severity }) else {
            return "QUIET DAY IN WORLD AFFAIRS"
        }
        return topEvent.headline.uppercased()
    }
}

// MARK: - Intelligence Report

/// Classified analysis of world events for high-level players
struct IntelligenceReport: Codable, Identifiable {
    var id: String = UUID().uuidString
    var turn: Int
    var classification: ClassificationLevel
    var source: String              // e.g., "BPS Station Chief, London"
    var subject: String
    var analysis: String
    var recommendedActions: [String]
    var relatedEventIds: [String]
    var hasBeenRead: Bool = false

    enum ClassificationLevel: String, Codable {
        case confidential   // Position 6+
        case secret         // Position 7+
        case topSecret      // Position 8 only

        var displayName: String {
            switch self {
            case .confidential: return "CONFIDENTIAL"
            case .secret: return "SECRET"
            case .topSecret: return "TOP SECRET"
            }
        }

        var requiredLevel: Int {
            switch self {
            case .confidential: return 6
            case .secret: return 7
            case .topSecret: return 8
            }
        }
    }
}
