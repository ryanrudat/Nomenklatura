//
//  PeoplesCongress.swift
//  Nomenklatura
//
//  People's Congress rubber-stamp mechanic
//  Represents the nominal "highest organ of state power" that affirms Party policies
//

import Foundation
import SwiftData

/// Represents a session of the People's Congress
/// Occurs every 4-5 turns to legitimize policy changes
@Model
final class CongressSession {
    @Attribute(.unique) var id: UUID

    var sessionNumber: Int           // Sequential session number
    var turnConvened: Int            // Turn when Congress was called
    var turnConcluded: Int?          // Turn when session ended

    var sessionType: String          // CongressSessionType.rawValue
    var status: String               // CongressStatus.rawValue

    // Delegates and representation
    var totalDelegates: Int          // Number of delegates (usually 2000-3000)
    var delegatesPresent: Int        // Actual attendance

    // Agenda items (encoded as Data)
    var agendaItemsData: Data?       // [CongressAgendaItem]

    // Voting results (encoded as Data)
    var votingResultsData: Data?     // [CongressVote]

    // Player involvement
    var playerAttended: Bool         // Did player attend session
    var playerSpokeAtSession: Bool   // Did player give a speech
    var playerProposedPolicy: Bool   // Did player propose agenda items

    // Political effects
    var legitimacyGranted: Int       // Legitimacy points awarded to policies
    var stabilityEffect: Int         // Effect on national stability

    // Game reference
    var game: Game?

    init(sessionNumber: Int, turn: Int, type: CongressSessionType) {
        self.id = UUID()
        self.sessionNumber = sessionNumber
        self.turnConvened = turn
        self.sessionType = type.rawValue
        self.status = CongressStatus.convening.rawValue

        // Default delegate count
        self.totalDelegates = 2800
        self.delegatesPresent = 2650

        self.playerAttended = false
        self.playerSpokeAtSession = false
        self.playerProposedPolicy = false

        self.legitimacyGranted = 0
        self.stabilityEffect = 0
    }
}

// MARK: - Congress Types and Status

enum CongressSessionType: String, Codable {
    case annual          // Regular annual session
    case emergency       // Special emergency session
    case constitutional  // Constitutional amendment session
    case succession      // Leadership succession session

    var displayName: String {
        switch self {
        case .annual: return "Annual Session"
        case .emergency: return "Emergency Session"
        case .constitutional: return "Constitutional Session"
        case .succession: return "Succession Session"
        }
    }

    /// Turns between annual sessions
    static var sessionInterval: Int { 4 }
}

enum CongressStatus: String, Codable {
    case scheduled       // Upcoming session
    case convening       // Session opening
    case deliberating    // In session
    case voting          // Final votes
    case concluded       // Session ended
    case cancelled       // Session cancelled (rare)

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .convening: return "Convening"
        case .deliberating: return "In Session"
        case .voting: return "Voting"
        case .concluded: return "Concluded"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Congress Agenda

struct CongressAgendaItem: Codable, Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var description: String
    var category: AgendaCategory
    var proposedBy: String?          // Character ID who proposed
    var requiresVote: Bool
    var passedUnanimously: Bool?     // Result (almost always true)
    var votesFor: Int?
    var votesAgainst: Int?
    var abstentions: Int?

    enum AgendaCategory: String, Codable {
        case fiveYearPlan      // Economic plan approval
        case budgetApproval    // State budget
        case leadershipReport  // General Secretary's report
        case legislativeChange // New laws
        case internationalAffair // Foreign policy
        case ceremonial        // Awards, honors

        var displayName: String {
            switch self {
            case .fiveYearPlan: return "Five-Year Plan"
            case .budgetApproval: return "Budget Approval"
            case .leadershipReport: return "Leadership Report"
            case .legislativeChange: return "Legislative Change"
            case .internationalAffair: return "International Affairs"
            case .ceremonial: return "Ceremonial"
            }
        }
    }
}

struct CongressVote: Codable, Identifiable {
    var id: String = UUID().uuidString
    var agendaItemId: String
    var votesFor: Int
    var votesAgainst: Int
    var abstentions: Int
    var passed: Bool
    var wasUnanimous: Bool

    /// Percentage approval (for display)
    var approvalPercentage: Double {
        let total = Double(votesFor + votesAgainst + abstentions)
        guard total > 0 else { return 100.0 }
        return (Double(votesFor) / total) * 100.0
    }
}

// MARK: - Computed Properties

extension CongressSession {

    var currentType: CongressSessionType {
        CongressSessionType(rawValue: sessionType) ?? .annual
    }

    var currentStatus: CongressStatus {
        CongressStatus(rawValue: status) ?? .scheduled
    }

    var agendaItems: [CongressAgendaItem] {
        get {
            guard let data = agendaItemsData else { return [] }
            return (try? JSONDecoder().decode([CongressAgendaItem].self, from: data)) ?? []
        }
        set {
            agendaItemsData = try? JSONEncoder().encode(newValue)
        }
    }

    var votingResults: [CongressVote] {
        get {
            guard let data = votingResultsData else { return [] }
            return (try? JSONDecoder().decode([CongressVote].self, from: data)) ?? []
        }
        set {
            votingResultsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether Congress session is active
    var isInSession: Bool {
        currentStatus == .convening || currentStatus == .deliberating || currentStatus == .voting
    }

    /// Session description for newspapers
    var newspaperHeadline: String {
        switch currentType {
        case .annual:
            return "PEOPLE'S CONGRESS CONVENES IN WASHINGTON"
        case .emergency:
            return "EMERGENCY SESSION OF PEOPLE'S CONGRESS CALLED"
        case .constitutional:
            return "PEOPLE'S CONGRESS TO CONSIDER CONSTITUTIONAL REFORMS"
        case .succession:
            return "PEOPLE'S CONGRESS CONVENES FOR LEADERSHIP TRANSITION"
        }
    }

    var conclusionHeadline: String {
        let unanimousCount = votingResults.filter { $0.wasUnanimous }.count
        if unanimousCount == votingResults.count && !votingResults.isEmpty {
            return "PEOPLE'S CONGRESS UNANIMOUSLY APPROVES ALL MEASURES"
        }
        return "PEOPLE'S CONGRESS CONCLUDES HISTORIC SESSION"
    }
}

// MARK: - Session Actions

extension CongressSession {

    /// Add an agenda item to the session
    func addAgendaItem(_ item: CongressAgendaItem) {
        var items = agendaItems
        items.append(item)
        agendaItems = items
    }

    /// Create default annual session agenda
    func createStandardAgenda(game: Game) {
        var items: [CongressAgendaItem] = []

        // Leadership report always first
        items.append(CongressAgendaItem(
            title: "Report of the Central Committee",
            description: "The General Secretary presents the Party's achievements and guidance for the coming period.",
            category: .leadershipReport,
            requiresVote: true
        ))

        // Economic plan if applicable
        if game.turnNumber % 20 == 0 || sessionNumber == 1 {
            items.append(CongressAgendaItem(
                title: "Approval of the Five-Year Plan",
                description: "The Congress considers and approves the economic development plan for the next planning period.",
                category: .fiveYearPlan,
                requiresVote: true
            ))
        }

        // Budget always included
        items.append(CongressAgendaItem(
            title: "State Budget Approval",
            description: "The annual budget of the People's Socialist Republic is submitted for approval.",
            category: .budgetApproval,
            requiresVote: true
        ))

        // Ceremonial matters
        items.append(CongressAgendaItem(
            title: "Awards and Commendations",
            description: "Heroes of Socialist Labor and other distinguished citizens are honored.",
            category: .ceremonial,
            requiresVote: false
        ))

        agendaItems = items
    }

    /// Process votes (rubber-stamp all items)
    func processVotes() {
        var results: [CongressVote] = []

        for item in agendaItems where item.requiresVote {
            // Almost always unanimous with tiny symbolic opposition
            let against = Int.random(in: 0...5)
            let abstentions = Int.random(in: 0...15)
            let forVotes = delegatesPresent - against - abstentions

            results.append(CongressVote(
                agendaItemId: item.id,
                votesFor: forVotes,
                votesAgainst: against,
                abstentions: abstentions,
                passed: true,
                wasUnanimous: against == 0 && abstentions == 0
            ))
        }

        votingResults = results

        // Calculate legitimacy granted
        let unanimousCount = results.filter { $0.wasUnanimous }.count
        legitimacyGranted = 10 + (unanimousCount * 5)

        // Stability effect (Congress sessions reinforce system legitimacy)
        stabilityEffect = 3
    }

    /// Conclude the session
    func conclude(turn: Int) {
        turnConcluded = turn
        status = CongressStatus.concluded.rawValue
    }
}

// MARK: - Game Extension

extension Game {

    /// Check if it's time for a Congress session
    var shouldConveneCongress: Bool {
        let interval = CongressSessionType.sessionInterval
        return turnNumber % interval == 0
    }

    /// Get the current or most recent Congress session
    /// Note: Would need to add congressSessions relationship to Game
    var currentCongressSession: CongressSession? {
        // TODO: Implement once relationship is added
        return nil
    }

    /// Convene a new Congress session
    func conveneCongressSession(type: CongressSessionType = .annual) -> CongressSession {
        // Determine session number based on turn
        let sessionNumber = (turnNumber / CongressSessionType.sessionInterval) + 1

        let session = CongressSession(
            sessionNumber: sessionNumber,
            turn: turnNumber,
            type: type
        )

        // Create standard agenda for annual sessions
        if type == .annual {
            session.createStandardAgenda(game: self)
        }

        return session
    }
}

// MARK: - AI Context

extension CongressSession {

    /// Context for AI prompt generation
    var aiContext: String {
        var context = "People's Congress Session \(sessionNumber) (\(currentType.displayName))\n"
        context += "Status: \(currentStatus.displayName)\n"
        context += "Delegates: \(delegatesPresent) of \(totalDelegates) present\n"

        if !agendaItems.isEmpty {
            context += "Agenda Items:\n"
            for item in agendaItems {
                context += "  - \(item.title) [\(item.category.displayName)]\n"
            }
        }

        if !votingResults.isEmpty {
            let unanimous = votingResults.filter { $0.wasUnanimous }.count
            context += "Votes: \(unanimous) of \(votingResults.count) passed unanimously\n"
        }

        return context
    }
}
