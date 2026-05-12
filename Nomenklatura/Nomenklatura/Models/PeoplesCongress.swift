//
//  PeoplesCongress.swift
//  Nomenklatura
//
//  People's Congress — a ceremonial state-of-the-nation broadcast.
//
//  Historical note: legislative bodies of this type were not vote engines;
//  they were propaganda spectacles. The system used to fabricate vote tallies
//  (always "passed: true" with 0-2 % symbolic opposition) which gave the
//  illusion of mechanics where none existed. That has been removed. The
//  session now produces a narrative broadcast payload only — no fake votes,
//  no player agency, no misleading "legitimacy" arithmetic.
//
//  CongressVote and the agenda-item vote fields remain as types because
//  other archived data may still decode against them, but they are no longer
//  populated. processVotes() is a no-op alias for generateCeremonialBroadcast.
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

    // Voting results (encoded as Data) — REPURPOSED.
    //
    // Originally `[CongressVote]` encoded as JSON. The rubber-stamp vote loop
    // has been removed (Congress is now ceremonial) so we no longer write
    // CongressVote arrays here. Instead, we reuse this @Model field to store
    // the UTF-8 bytes of the ceremonial broadcast text (see `broadcastText`).
    //
    // This avoids a SwiftData schema bump: the field already exists in V1.
    // Old [CongressVote] payloads from prior saves are detected and treated
    // as empty by `broadcastText`'s getter.
    var votingResultsData: Data?

    // Player involvement
    var playerAttended: Bool         // Did player attend session
    var playerSpokeAtSession: Bool   // Did player give a speech
    var playerProposedPolicy: Bool   // Did player propose agenda items

    // Political effects
    // NOTE: legitimacyGranted is no longer derived from fake unanimity counts.
    // It's kept at 0 by default; callers should not rely on it as a signal.
    var legitimacyGranted: Int       // Vestigial — left at 0 by ceremonial flow
    var stabilityEffect: Int         // Vestigial — left at 0 by ceremonial flow

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

    /// Vestigial: Congress is ceremonial — there are no votes.
    ///
    /// The underlying `votingResultsData` field has been repurposed to store
    /// `broadcastText` (UTF-8 bytes). We return an empty array here so any
    /// external caller that still reads `votingResults` gets a benign empty
    /// result instead of crashing. NO LONGER SETTABLE — see `broadcastText`.
    var votingResults: [CongressVote] { [] }

    /// Ceremonial broadcast text generated at session time.
    ///
    /// Stored as UTF-8 in the (formerly vote-tally) `votingResultsData` field
    /// so we avoid a SwiftData schema bump. Old `[CongressVote]` JSON payloads
    /// from prior saves are detected (they begin with `[{` or `[]`) and surface
    /// as empty here, ensuring the UI never shows stale fake-vote bytes as text.
    var broadcastText: String {
        get {
            guard let data = votingResultsData,
                  let s = String(data: data, encoding: .utf8) else { return "" }
            if s.hasPrefix("[{") || s.hasPrefix("[]") { return "" }
            return s
        }
        set {
            votingResultsData = newValue.data(using: .utf8)
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
            return "PEOPLE'S CONGRESS CONVENES IN THE CAPITAL"
        case .emergency:
            return "EMERGENCY SESSION OF PEOPLE'S CONGRESS CALLED"
        case .constitutional:
            return "PEOPLE'S CONGRESS TO CONSIDER CONSTITUTIONAL REFORMS"
        case .succession:
            return "PEOPLE'S CONGRESS CONVENES FOR LEADERSHIP TRANSITION"
        }
    }

    /// Headline read out at the close of the ceremonial session.
    /// No longer derived from fabricated vote tallies.
    var conclusionHeadline: String {
        switch currentType {
        case .annual:        return "PEOPLE'S CONGRESS CONCLUDES IN UNITY"
        case .emergency:     return "EMERGENCY SESSION ADJOURNS"
        case .constitutional:return "CONSTITUTIONAL SESSION ADJOURNS"
        case .succession:    return "SUCCESSION SESSION ADJOURNS"
        }
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

    /// Generate the ceremonial broadcast payload for this session.
    ///
    /// Replaces the prior `processVotes()` rubber-stamp loop. There is no vote.
    /// Output is 1-2 paragraphs of propaganda-spectacle prose, varied by a few
    /// in-game state references (turn, current Five-Year Plan number, stability
    /// bracket) so successive sessions read differently.
    ///
    /// The text is stored on `broadcastText`. No stats are mutated.
    func generateCeremonialBroadcast(game: Game) {
        let turn = game.turnNumber
        let planNumber = game.currentFiveYearPlan
        let stabilityBracket: String
        switch game.stability {
        case 70...:  stabilityBracket = "in a climate of perfect social cohesion"
        case 50..<70:stabilityBracket = "amid the steady march of socialist construction"
        case 30..<50:stabilityBracket = "against a backdrop of vigilant defense of revolutionary gains"
        default:     stabilityBracket = "during a period demanding heightened revolutionary discipline"
        }

        // Pick a varied opening line so consecutive sessions read differently.
        let openings: [String] = [
            "Comrade Chairman addresses the Assembly. The Great Hall stands. The orchestra plays the anthem.",
            "The session opens with the singing of the International. Delegates rise as one.",
            "Standing ovations greet the Chairman's entry. The People's Congress is in session.",
            "The doors of the Great Hall are closed. The Presidium takes its place. Silence falls."
        ]
        let opening = openings[turn % openings.count]

        // Pick a varied closing beat.
        let closings: [String] = [
            "No dissent is recorded. The session is filed into the archives.",
            "The vote is taken by acclamation. The minutes are sealed.",
            "The hall rises a final time. The broadcast cuts to the anthem.",
            "Delegates depart to their provinces to carry word of the session."
        ]
        let closing = closings[(turn / 2) % closings.count]

        let body =
            "\(opening) The Report of the Central Committee is read into the record. " +
            "Progress on the \(planNumber.ordinalString) Five-Year Plan is recited section by section, " +
            "each milestone punctuated by sustained applause. The state budget is presented and received. " +
            "The session unfolds \(stabilityBracket).\n\n" +
            "Foreign delegations observe from the gallery. The newsreel cameras run. " +
            "The Chairman's closing address is interrupted seventeen times by ovations. " +
            "\(closing)"

        broadcastText = body
    }

    /// Backwards-compatible shim. The vote engine has been removed; this
    /// now produces a ceremonial broadcast instead. Old callers continue to
    /// compile and trigger the right end-of-session beat.
    func processVotes() {
        // We do not have a Game reference here. Callers that still invoke
        // processVotes() without a Game (none currently) will leave the
        // broadcast text blank — callers should prefer generateCeremonialBroadcast(game:).
        if broadcastText.isEmpty {
            broadcastText = "The People's Congress is in session. The Report of the Central Committee is read into the record. Standing ovations punctuate each section. No dissent is recorded."
        }
        // Vote tallies are intentionally NOT populated. votingResultsData stays nil.
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
    var currentCongressSession: CongressSession? {
        // Return the most recent session (highest session number)
        return congressSessions.max(by: { $0.sessionNumber < $1.sessionNumber })
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

        // Vote tallies removed — Congress is now ceremonial. Surface the
        // broadcast text instead so AI prompts can reference its tone.
        if !broadcastText.isEmpty {
            context += "Broadcast: \(broadcastText.prefix(160))…\n"
        }

        return context
    }
}
