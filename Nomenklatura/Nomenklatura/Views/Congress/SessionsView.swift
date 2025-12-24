//
//  SessionsView.swift
//  Nomenklatura
//
//  Sessions sub-tab showing legislative sessions and voting history
//

import SwiftUI
import SwiftData

struct SessionsView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedSegment: SessionSegment = .upcoming

    private var nextPartyCongressTurn: Int {
        let congressCycle = 20
        let currentTurn = game.turnNumber
        let turnsUntilNext = congressCycle - (currentTurn % congressCycle)
        return currentTurn + turnsUntilNext
    }

    private var nextAnnualSessionTurn: Int {
        let sessionInterval = CongressSessionType.sessionInterval  // 4 turns
        let currentTurn = game.turnNumber
        let turnsUntilNext = sessionInterval - (currentTurn % sessionInterval)
        return currentTurn + turnsUntilNext
    }

    private var committeeMeetings: [CommitteeMeeting] {
        game.standingCommittee?.meetingMinutes ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Segment control
                SessionSegmentControl(selected: $selectedSegment)
                    .padding(.horizontal, 15)
                    .padding(.top, 10)

                switch selectedSegment {
                case .upcoming:
                    UpcomingSessionsContent(
                        game: game,
                        nextPartyCongress: nextPartyCongressTurn,
                        nextAnnualSession: nextAnnualSessionTurn
                    )
                    .padding(.horizontal, 15)

                case .history:
                    SessionHistoryContent(
                        game: game,
                        committeeMeetings: committeeMeetings
                    )
                    .padding(.horizontal, 15)

                case .archives:
                    HistoricalArchivesContent(game: game)
                        .padding(.horizontal, 15)
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Session Segment

enum SessionSegment: String, CaseIterable {
    case upcoming = "Upcoming"
    case history = "History"
    case archives = "Archives"
}

struct SessionSegmentControl: View {
    @Binding var selected: SessionSegment
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SessionSegment.allCases, id: \.self) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = segment
                    }
                } label: {
                    Text(segment.rawValue.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(selected == segment ? .white : theme.inkGray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected == segment ? theme.sovietRed : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Upcoming Sessions Content

struct UpcomingSessionsContent: View {
    @Bindable var game: Game
    let nextPartyCongress: Int
    let nextAnnualSession: Int
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            // Party Congress (every 20 turns = 5 years)
            UpcomingSessionCard(
                title: "PARTY CONGRESS",
                description: "The supreme organ of the Communist Party convenes to elect the Central Committee and set major policy direction.",
                icon: "star.circle.fill",
                accentColor: theme.accentGold,
                turnsUntil: nextPartyCongress - game.turnNumber,
                turnNumber: nextPartyCongress,
                isHighPriority: (nextPartyCongress - game.turnNumber) <= 2
            )

            // People's Congress (every 4 turns = 1 year)
            UpcomingSessionCard(
                title: "PEOPLE'S CONGRESS",
                description: "The nominal highest organ of state power meets to approve budgets, plans, and legislation.",
                icon: "person.3.fill",
                accentColor: theme.sovietRed,
                turnsUntil: nextAnnualSession - game.turnNumber,
                turnNumber: nextAnnualSession,
                isHighPriority: (nextAnnualSession - game.turnNumber) <= 1
            )

            // Standing Committee meeting (every 4 turns)
            let lastMeeting = game.standingCommittee?.lastMeetingTurn ?? 0
            let turnsUntilCommittee = max(0, 4 - (game.turnNumber - lastMeeting))
            UpcomingSessionCard(
                title: "STANDING COMMITTEE",
                description: "The inner circle convenes to vote on pending agenda items and make key decisions.",
                icon: "person.2.circle.fill",
                accentColor: Color(hex: "6A1B9A"),
                turnsUntil: turnsUntilCommittee,
                turnNumber: game.turnNumber + turnsUntilCommittee,
                isHighPriority: turnsUntilCommittee == 0
            )

            // Current turn info
            CurrentTurnCard(game: game)
        }
    }
}

struct UpcomingSessionCard: View {
    let title: String
    let description: String
    let icon: String
    let accentColor: Color
    let turnsUntil: Int
    let turnNumber: Int
    let isHighPriority: Bool
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkBlack)

                    if isHighPriority {
                        Text("SOON")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.3)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(accentColor)
                            .cornerRadius(2)
                    }
                }

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkGray)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if turnsUntil == 0 {
                    Text("THIS TURN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accentColor)
                } else {
                    Text("In \(turnsUntil)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.inkBlack)
                    Text(turnsUntil == 1 ? "turn" : "turns")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkLight)
                }

                Text("Turn \(turnNumber)")
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)
            }
        }
        .padding(12)
        .background(isHighPriority ? accentColor.opacity(0.08) : theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(isHighPriority ? accentColor.opacity(0.5) : theme.borderTan, lineWidth: isHighPriority ? 2 : 1)
        )
    }
}

struct CurrentTurnCard: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var year: Int {
        1960 + (game.turnNumber / 4)  // Each turn is a quarter
    }

    private var quarter: String {
        let q = (game.turnNumber % 4) + 1
        return "Q\(q)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 20))
                .foregroundColor(theme.inkGray)

            VStack(alignment: .leading, spacing: 2) {
                Text("CURRENT PERIOD")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(theme.inkLight)

                Text("Turn \(game.turnNumber) (\(quarter) \(year))")
                    .font(theme.bodyFont)
                    .fontWeight(.medium)
                    .foregroundColor(theme.inkBlack)
            }

            Spacer()
        }
        .padding(12)
        .background(theme.parchment)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Session History Content

struct SessionHistoryContent: View {
    @Bindable var game: Game
    let committeeMeetings: [CommitteeMeeting]
    @Environment(\.theme) var theme

    private var sortedMeetings: [CommitteeMeeting] {
        committeeMeetings.sorted { $0.turnHeld > $1.turnHeld }
    }

    var body: some View {
        VStack(spacing: 12) {
            if sortedMeetings.isEmpty {
                EmptyHistoryCard()
            } else {
                ForEach(sortedMeetings) { meeting in
                    MeetingHistoryCard(meeting: meeting, game: game)
                }
            }
        }
    }
}

struct EmptyHistoryCard: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(theme.inkLight)

            Text("No Session History")
                .font(theme.headerFont)
                .foregroundColor(theme.inkGray)

            Text("Past legislative sessions and committee meetings will appear here as they occur.")
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkLight)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct MeetingHistoryCard: View {
    let meeting: CommitteeMeeting
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    private var atmosphereColor: Color {
        switch meeting.atmosphere {
        case .harmonious: return .statHigh
        case .tense: return .statMedium
        case .confrontational: return .statLow
        case .performative: return theme.inkGray
        }
    }

    private var atmosphereIcon: String {
        switch meeting.atmosphere {
        case .harmonious: return "checkmark.seal.fill"
        case .tense: return "exclamationmark.triangle"
        case .confrontational: return "bolt.fill"
        case .performative: return "doc.on.doc"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Atmosphere indicator
                    ZStack {
                        Circle()
                            .fill(atmosphereColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: atmosphereIcon)
                            .font(.system(size: 14))
                            .foregroundColor(atmosphereColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Standing Committee Meeting")
                            .font(theme.bodyFont)
                            .fontWeight(.medium)
                            .foregroundColor(theme.inkBlack)

                        HStack(spacing: 8) {
                            Text("Turn \(meeting.turnHeld)")
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)

                            Text("•")
                                .foregroundColor(theme.inkLight)

                            Text(meeting.atmosphere.rawValue.capitalized)
                                .font(theme.tagFont)
                                .foregroundColor(atmosphereColor)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(meeting.decisionsReached.count)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.inkBlack)
                        Text("decisions")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkLight)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)
                .background(theme.parchmentDark)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Decisions
                    if !meeting.decisionsReached.isEmpty {
                        Text("DECISIONS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(theme.inkLight)

                        ForEach(meeting.decisionsReached) { decision in
                            DecisionRow(decision: decision, game: game)
                        }
                    }

                    // Attendance
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(meeting.attendeeIds.count) members attended")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(theme.inkGray)
                }
                .padding(12)
                .background(theme.parchment)
            }
        }
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct DecisionRow: View {
    let decision: CommitteeDecision
    let game: Game
    @Environment(\.theme) var theme

    private var outcomeColor: Color {
        switch decision.outcome {
        case .approved, .amendedAndApproved: return .statHigh
        case .rejected: return .statLow
        case .deferred, .referredToSubcommittee: return .statMedium
        }
    }

    private var outcomeIcon: String {
        switch decision.outcome {
        case .approved, .amendedAndApproved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .deferred: return "clock.fill"
        case .referredToSubcommittee: return "arrow.right.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: outcomeIcon)
                .font(.system(size: 12))
                .foregroundColor(outcomeColor)

            ClickableNarrativeText(
                text: decision.narrativeSummary,
                game: game,
                font: .system(size: 11),
                color: theme.inkGray
            )
            .lineLimit(2)

            Spacer()

            // Voting record
            HStack(spacing: 4) {
                Text("\(decision.votingRecord.votesFor)")
                    .foregroundColor(.statHigh)
                Text("/")
                    .foregroundColor(theme.inkLight)
                Text("\(decision.votingRecord.votesAgainst)")
                    .foregroundColor(.statLow)
            }
            .font(.system(size: 10, weight: .bold))
        }
        .padding(8)
        .background(outcomeColor.opacity(0.05))
        .cornerRadius(4)
    }
}

// MARK: - Historical Archives Content

struct HistoricalArchivesContent: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedEra: RevolutionaryCalendar.HistoricalEra?
    @State private var selectedType: HistoricalSessionType?

    private var playerPosition: Int {
        game.currentPositionIndex
    }

    private var isOnCommittee: Bool {
        game.standingCommittee?.playerIsOnCommittee ?? false
    }

    private var filteredSessions: [HistoricalSession] {
        var sessions = game.historicalSessions

        if let era = selectedEra {
            sessions = sessions.filter { $0.era == era.rawValue }
        }

        if let type = selectedType {
            sessions = sessions.filter { $0.sessionType == type.rawValue }
        }

        return sessions.sorted { $0.revolutionaryYear > $1.revolutionaryYear }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            ArchivesHeaderCard()

            // Filter controls
            ArchivesFilterControls(selectedEra: $selectedEra, selectedType: $selectedType)

            // Content
            if filteredSessions.isEmpty {
                EmptyArchivesCard()
            } else {
                ForEach(filteredSessions) { session in
                    HistoricalSessionCard(
                        session: session,
                        playerPosition: playerPosition,
                        isOnCommittee: isOnCommittee
                    )
                }
            }

            // Access level legend
            AccessLevelLegend(playerPosition: playerPosition)
        }
    }
}

struct ArchivesHeaderCard: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 24))
                    .foregroundColor(theme.accentGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HISTORICAL ARCHIVES")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    Text("Records from \(RevolutionaryCalendar.formatLong(1))")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkGray)
                }

                Spacer()
            }

            Text("Access to classified materials depends on your position within the Party hierarchy.")
                .font(.system(size: 10))
                .foregroundColor(theme.inkLight)
                .italic()
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.accentGold.opacity(0.5), lineWidth: 1)
        )
    }
}

struct ArchivesFilterControls: View {
    @Binding var selectedEra: RevolutionaryCalendar.HistoricalEra?
    @Binding var selectedType: HistoricalSessionType?
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 8) {
            // Era filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(label: "All Eras", isSelected: selectedEra == nil) {
                        selectedEra = nil
                    }

                    ForEach(RevolutionaryCalendar.HistoricalEra.allCases, id: \.self) { era in
                        FilterChip(
                            label: era.displayName,
                            isSelected: selectedEra == era
                        ) {
                            selectedEra = selectedEra == era ? nil : era
                        }
                    }
                }
            }

            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(label: "All Types", isSelected: selectedType == nil) {
                        selectedType = nil
                    }

                    ForEach(HistoricalSessionType.allCases, id: \.self) { type in
                        FilterChip(
                            label: type.displayName,
                            isSelected: selectedType == type
                        ) {
                            selectedType = selectedType == type ? nil : type
                        }
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .white : theme.inkGray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? theme.sovietRed : theme.parchmentDark)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? theme.sovietRed : theme.borderTan, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct HistoricalSessionCard: View {
    let session: HistoricalSession
    let playerPosition: Int
    let isOnCommittee: Bool
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    private var isRedacted: Bool {
        session.shouldRedact(forPosition: playerPosition, isOnCommittee: isOnCommittee)
    }

    private var typeColor: Color {
        switch session.historicalSessionType {
        case .partyCongress: return theme.accentGold
        case .peoplesCongress: return theme.sovietRed
        case .standingCommittee: return Color(hex: "6A1B9A")
        case .centralCommittee: return Color(hex: "1565C0")
        case .emergencySession: return Color(hex: "E65100")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Type icon
                    ZStack {
                        Circle()
                            .fill(typeColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: session.historicalSessionType.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(typeColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(session.title)
                                .font(theme.bodyFont)
                                .fontWeight(.medium)
                                .foregroundColor(theme.inkBlack)

                            if isRedacted {
                                Text("CLASSIFIED")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(theme.sovietRed)
                                    .cornerRadius(2)
                            }
                        }

                        HStack(spacing: 6) {
                            Text(session.formattedDate)
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)

                            Text("•")
                                .foregroundColor(theme.inkLight)

                            Text(session.historicalEra.displayName)
                                .font(theme.tagFont)
                                .foregroundColor(typeColor)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)
                .background(theme.parchmentDark)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Summary
                    Text("SUMMARY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkLight)

                    Text(session.displaySummary(forPosition: playerPosition, isOnCommittee: isOnCommittee))
                        .font(.system(size: 12))
                        .foregroundColor(isRedacted ? theme.inkLight : theme.inkGray)
                        .italic(isRedacted)

                    // Key decisions (if accessible)
                    if !session.keyDecisions.isEmpty {
                        Text("KEY DECISIONS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(theme.inkLight)
                            .padding(.top, 4)

                        ForEach(session.displayKeyDecisions(forPosition: playerPosition, isOnCommittee: isOnCommittee), id: \.self) { decision in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(isRedacted ? theme.inkLight : typeColor)
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 5)

                                Text(decision)
                                    .font(.system(size: 11))
                                    .foregroundColor(isRedacted ? theme.inkLight : theme.inkGray)
                                    .italic(isRedacted)
                            }
                        }
                    }

                    // Secret summary (if accessible)
                    if let secretSummary = session.displaySecretSummary(forPosition: playerPosition, isOnCommittee: isOnCommittee) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 9))
                                Text("RESTRICTED INFORMATION")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(0.5)
                            }
                            .foregroundColor(theme.sovietRed)
                            .padding(.top, 6)

                            Text(secretSummary)
                                .font(.system(size: 11))
                                .foregroundColor(theme.inkGray)
                                .italic()
                        }
                    }

                    // Member changes (if any)
                    if !session.memberChanges.isEmpty && !isRedacted {
                        Text("PERSONNEL CHANGES")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(theme.inkLight)
                            .padding(.top, 4)

                        ForEach(session.memberChanges, id: \.self) { change in
                            Text("• \(change)")
                                .font(.system(size: 11))
                                .foregroundColor(theme.inkGray)
                        }
                    }
                }
                .padding(12)
                .background(theme.parchment)
            }
        }
        .overlay(
            Rectangle()
                .stroke(isRedacted ? theme.sovietRed.opacity(0.3) : theme.borderTan, lineWidth: 1)
        )
    }
}

struct EmptyArchivesCard: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(theme.inkLight)

            Text("No Matching Records")
                .font(theme.bodyFont)
                .foregroundColor(theme.inkGray)

            Text("Adjust filters to view historical sessions.")
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkLight)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct AccessLevelLegend: View {
    let playerPosition: Int
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACCESS CLEARANCE")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundColor(theme.inkLight)

            HStack(spacing: 12) {
                AccessLegendItem(label: "Public", level: 0, playerPosition: playerPosition)
                AccessLegendItem(label: "Restricted", level: 5, playerPosition: playerPosition)
                AccessLegendItem(label: "Secret", level: 7, playerPosition: playerPosition)
            }

            Text("Your current position: Level \(playerPosition)")
                .font(.system(size: 10))
                .foregroundColor(theme.inkGray)
                .padding(.top, 2)
        }
        .padding(12)
        .background(theme.parchment)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct AccessLegendItem: View {
    let label: String
    let level: Int
    let playerPosition: Int
    @Environment(\.theme) var theme

    private var hasAccess: Bool {
        playerPosition >= level
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(hasAccess ? Color.statHigh : theme.sovietRed)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(hasAccess ? theme.inkGray : theme.inkLight)
        }
    }
}
