//
//  HistoricalSession.swift
//  Nomenklatura
//
//  Historical sessions of Party Congress, People's Congress, and Standing Committee
//  Dating from Year 1 of the Revolution to the present
//

import Foundation
import SwiftData

// MARK: - Historical Session Type

enum HistoricalSessionType: String, Codable, CaseIterable {
    case partyCongress         // Major Party Congress (every 5 years)
    case peoplesCongress       // Annual People's Congress (rubber-stamp)
    case standingCommittee     // Standing Committee meetings (2-3 per year)
    case centralCommittee      // Central Committee plenums
    case emergencySession      // Crisis meetings

    var displayName: String {
        switch self {
        case .partyCongress: return "Party Congress"
        case .peoplesCongress: return "People's Congress"
        case .standingCommittee: return "Standing Committee"
        case .centralCommittee: return "Central Committee Plenum"
        case .emergencySession: return "Emergency Session"
        }
    }

    var iconName: String {
        switch self {
        case .partyCongress: return "star.fill"
        case .peoplesCongress: return "building.columns.fill"
        case .standingCommittee: return "person.3.fill"
        case .centralCommittee: return "person.2.fill"
        case .emergencySession: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Historical Session Model

@Model
final class HistoricalSession {
    @Attribute(.unique) var id: UUID

    var sessionType: String              // HistoricalSessionType.rawValue
    var sessionNumber: Int               // e.g., "8th Party Congress"
    var revolutionaryYear: Int           // Year 1, Year 5, etc.

    var title: String                    // "8th Party Congress"
    var summary: String                  // Official summary
    var secretSummary: String?           // Hidden details (redacted)

    var keyDecisionsData: Data?          // Encoded [String]
    var memberChangesData: Data?         // Encoded [String]
    var secretDecisionsData: Data?       // Encoded [String] - redacted content

    var accessLevel: Int                 // 0=public, 5=restricted, 7=secret
    var attendeeIdsData: Data?           // Encoded [String] - character template IDs

    var atmosphere: String               // "harmonious", "tense", "confrontational"
    var era: String                      // HistoricalEra.rawValue

    var game: Game?

    init(
        sessionType: HistoricalSessionType,
        sessionNumber: Int,
        revolutionaryYear: Int,
        title: String,
        summary: String
    ) {
        self.id = UUID()
        self.sessionType = sessionType.rawValue
        self.sessionNumber = sessionNumber
        self.revolutionaryYear = revolutionaryYear
        self.title = title
        self.summary = summary
        self.accessLevel = 0
        self.atmosphere = "harmonious"
        self.era = RevolutionaryCalendar.era(for: revolutionaryYear).rawValue
    }

    // MARK: - Computed Properties

    var historicalSessionType: HistoricalSessionType {
        HistoricalSessionType(rawValue: sessionType) ?? .partyCongress
    }

    var historicalEra: RevolutionaryCalendar.HistoricalEra {
        RevolutionaryCalendar.HistoricalEra(rawValue: era) ?? .thawPeriod
    }

    var keyDecisions: [String] {
        get {
            guard let data = keyDecisionsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            keyDecisionsData = try? JSONEncoder().encode(newValue)
        }
    }

    var memberChanges: [String] {
        get {
            guard let data = memberChangesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            memberChangesData = try? JSONEncoder().encode(newValue)
        }
    }

    var secretDecisions: [String] {
        get {
            guard let data = secretDecisionsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            secretDecisionsData = try? JSONEncoder().encode(newValue)
        }
    }

    var attendeeIds: [String] {
        get {
            guard let data = attendeeIdsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            attendeeIdsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Formatted date string
    var formattedDate: String {
        RevolutionaryCalendar.format(revolutionaryYear)
    }

    /// Long formatted date string
    var formattedDateLong: String {
        RevolutionaryCalendar.formatLong(revolutionaryYear)
    }

    // MARK: - Access Control

    /// Check if content should be redacted for a given player position
    func shouldRedact(forPosition position: Int, isOnCommittee: Bool) -> Bool {
        if accessLevel == 0 { return false }
        if accessLevel <= 5 && position >= 5 { return false }
        if accessLevel <= 7 && (position >= 7 || isOnCommittee) { return false }
        return true
    }

    /// Get display summary (redacted if necessary)
    func displaySummary(forPosition position: Int, isOnCommittee: Bool) -> String {
        if shouldRedact(forPosition: position, isOnCommittee: isOnCommittee) {
            return "[REDACTED - INSUFFICIENT CLEARANCE]"
        }
        return summary
    }

    /// Get secret summary if player has access
    func displaySecretSummary(forPosition position: Int, isOnCommittee: Bool) -> String? {
        if shouldRedact(forPosition: position, isOnCommittee: isOnCommittee) {
            return nil
        }
        return secretSummary
    }

    /// Get key decisions (redacted if necessary)
    func displayKeyDecisions(forPosition position: Int, isOnCommittee: Bool) -> [String] {
        if shouldRedact(forPosition: position, isOnCommittee: isOnCommittee) {
            return ["[REDACTED]"]
        }
        return keyDecisions
    }
}

// MARK: - Game Extension for Historical Sessions

extension Game {
    /// Get historical sessions sorted by year (most recent first)
    var sortedHistoricalSessions: [HistoricalSession] {
        historicalSessions.sorted { $0.revolutionaryYear > $1.revolutionaryYear }
    }

    /// Get historical sessions by type
    func historicalSessions(ofType type: HistoricalSessionType) -> [HistoricalSession] {
        historicalSessions.filter { $0.sessionType == type.rawValue }
            .sorted { $0.revolutionaryYear > $1.revolutionaryYear }
    }

    /// Get historical sessions by era
    func historicalSessions(inEra era: RevolutionaryCalendar.HistoricalEra) -> [HistoricalSession] {
        historicalSessions.filter { $0.era == era.rawValue }
            .sorted { $0.revolutionaryYear > $1.revolutionaryYear }
    }

    /// Get historical sessions by year range
    func historicalSessions(fromYear start: Int, toYear end: Int) -> [HistoricalSession] {
        historicalSessions.filter { $0.revolutionaryYear >= start && $0.revolutionaryYear <= end }
            .sorted { $0.revolutionaryYear > $1.revolutionaryYear }
    }
}
