//
//  StandingCommitteeView.swift
//  Nomenklatura
//
//  Standing Committee sub-tab for viewing committee members and agenda
//

import SwiftUI
import SwiftData

struct StandingCommitteeView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var committee: StandingCommittee? {
        game.standingCommittee
    }

    private var isPlayerOnCommittee: Bool {
        game.currentPositionIndex >= 7
    }

    private var isPlayerChair: Bool {
        game.currentPositionIndex >= 8
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Committee Status Header
                CommitteeStatusHeader(
                    game: game,
                    isPlayerOnCommittee: isPlayerOnCommittee,
                    isPlayerChair: isPlayerChair
                )
                .padding(.horizontal, 15)
                .padding(.top, 10)

                // Committee Members
                CommitteeMembersSection(game: game)
                    .padding(.horizontal, 15)

                // Faction Balance
                if let committee = committee, !committee.factionBalance.isEmpty {
                    FactionBalanceCard(factionBalance: committee.factionBalance)
                        .padding(.horizontal, 15)
                }

                // Pending Agenda
                PendingAgendaSection(game: game, canSubmit: isPlayerOnCommittee)
                    .padding(.horizontal, 15)

                // Next Meeting Info
                NextMeetingCard(game: game)
                    .padding(.horizontal, 15)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Committee Status Header

struct CommitteeStatusHeader: View {
    @Bindable var game: Game
    let isPlayerOnCommittee: Bool
    let isPlayerChair: Bool
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 28))
                    .foregroundColor(theme.sovietRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text("POLITBURO STANDING COMMITTEE")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    Text("The inner circle of power")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                }

                Spacer()
            }

            // Player status
            HStack(spacing: 8) {
                if isPlayerChair {
                    Label("COMMITTEE CHAIR", systemImage: "crown.fill")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.accentGold)
                        .cornerRadius(4)
                } else if isPlayerOnCommittee {
                    Label("MEMBER", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.sovietRed)
                        .cornerRadius(4)
                } else {
                    Label("OBSERVER", systemImage: "eye.fill")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkGray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.parchmentDark)
                        .cornerRadius(4)

                    Text("Reach Senior Politburo for membership")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }

                Spacer()
            }
        }
        .padding(15)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Committee Members Section

struct CommitteeMembersSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var members: [GameCharacter] {
        guard let committee = game.standingCommittee else { return [] }
        return committee.memberIds.compactMap { memberId in
            game.characters.first { $0.templateId == memberId && $0.isAlive }
        }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }
    }

    private var chairId: String? {
        game.standingCommittee?.chairId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("COMMITTEE MEMBERS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text("\(members.count) seats")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkLight)
            }

            if members.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 30))
                        .foregroundColor(theme.inkLight)
                    Text("Committee not yet formed")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(theme.parchmentDark)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(members, id: \.id) { member in
                        CommitteeMemberRow(
                            member: member,
                            isChair: member.templateId == chairId,
                            game: game
                        )
                    }
                }
            }
        }
    }
}

struct CommitteeMemberRow: View {
    let member: GameCharacter
    let isChair: Bool
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var faction: GameFaction? {
        guard let factionId = member.factionId else { return nil }
        return game.factions.first { $0.factionId == factionId }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Rank indicator
            ZStack {
                Circle()
                    .fill(isChair ? theme.accentGold : theme.sovietRed.opacity(0.2))
                    .frame(width: 36, height: 36)

                if isChair {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                } else {
                    Text("\(member.positionIndex ?? 0)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.sovietRed)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(theme.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(theme.inkBlack)

                    if isChair {
                        Text("CHAIR")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(theme.accentGold)
                            .cornerRadius(2)
                    }
                }

                HStack(spacing: 8) {
                    Text(member.title ?? "Unknown Position")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)

                    if let faction = faction {
                        Text("•")
                            .foregroundColor(theme.inkLight)
                        Text(faction.name)
                            .font(theme.tagFont)
                            .foregroundColor(theme.sovietRed.opacity(0.7))
                    }
                }
            }

            Spacer()

            // Loyalty indicator (for player's allies/rivals)
            if member.isPatron {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.statHigh)
            } else if member.isRival {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.statLow)
            }
        }
        .padding(10)
        .background(theme.parchment)
        .overlay(
            Rectangle()
                .stroke(isChair ? theme.accentGold : theme.borderTan, lineWidth: isChair ? 2 : 1)
        )
    }
}

// MARK: - Faction Balance Card

struct FactionBalanceCard: View {
    let factionBalance: [String: Int]
    @Environment(\.theme) var theme

    private var sortedFactions: [(String, Int)] {
        factionBalance.sorted { $0.value > $1.value }
    }

    private var totalSeats: Int {
        factionBalance.values.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FACTION BALANCE")
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            // Balance bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(sortedFactions, id: \.0) { factionId, seats in
                        Rectangle()
                            .fill(factionColor(factionId))
                            .frame(width: max(20, geometry.size.width * CGFloat(seats) / CGFloat(totalSeats) - 2))
                    }
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(sortedFactions, id: \.0) { factionId, seats in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(factionColor(factionId))
                            .frame(width: 10, height: 10)
                        Text(factionDisplayName(factionId))
                            .font(.system(size: 11))
                            .foregroundColor(theme.inkGray)
                        Spacer()
                        Text("\(seats)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(theme.inkBlack)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func factionColor(_ factionId: String) -> Color {
        switch factionId {
        case "youth_league": return Color(hex: "1E88E5")
        case "princelings": return Color(hex: "8E24AA")
        case "reformists": return Color(hex: "43A047")
        case "old_guard": return Color(hex: "C62828")
        case "regional": return Color(hex: "FB8C00")
        default: return Color.gray
        }
    }

    private func factionDisplayName(_ factionId: String) -> String {
        switch factionId {
        case "youth_league": return "Youth League"
        case "princelings": return "Princelings"
        case "reformists": return "Reformists"
        case "old_guard": return "Proletariat Union"
        case "regional": return "Provincial Admin"
        default: return factionId.capitalized
        }
    }
}

// MARK: - Pending Agenda Section

struct PendingAgendaSection: View {
    @Bindable var game: Game
    let canSubmit: Bool
    @Environment(\.theme) var theme

    private var pendingItems: [CommitteeAgendaItem] {
        game.standingCommittee?.pendingAgenda ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PENDING AGENDA")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text("\(pendingItems.count) items")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkLight)
            }

            if pendingItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                        .foregroundColor(theme.inkLight)
                    Text("No pending agenda items")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                    if canSubmit {
                        Text("Submit a law proposal to add items")
                            .font(.system(size: 10))
                            .foregroundColor(theme.inkLight)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(theme.parchmentDark)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(pendingItems) { item in
                        AgendaItemRow(item: item, game: game)
                    }
                }
            }
        }
    }
}

struct AgendaItemRow: View {
    let item: CommitteeAgendaItem
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var sponsor: GameCharacter? {
        guard let sponsorId = item.sponsorId else { return nil }
        return game.characters.first { $0.templateId == sponsorId }
    }

    private var priorityColor: Color {
        switch item.priority {
        case .critical: return .statLow
        case .urgent: return Color(hex: "FF9800")
        case .important: return .statMedium
        case .routine: return theme.inkGray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Priority indicator
                Text(item.priority.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor)
                    .cornerRadius(2)

                // Category
                Text(item.category.rawValue.capitalized)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)

                Spacer()

                // Turn submitted
                Text("Turn \(item.turnSubmitted)")
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)
            }

            Text(item.title)
                .font(theme.bodyFont)
                .fontWeight(.medium)
                .foregroundColor(theme.inkBlack)

            Text(item.description)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
                .lineLimit(2)

            if let sponsor = sponsor {
                HStack(spacing: 4) {
                    Text("Sponsored by")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                    Text(sponsor.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.sovietRed)
                }
            }
        }
        .padding(12)
        .background(theme.parchment)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Next Meeting Card

struct NextMeetingCard: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var lastMeetingTurn: Int {
        game.standingCommittee?.lastMeetingTurn ?? 0
    }

    private var turnsUntilNextMeeting: Int {
        // Meetings every 4 turns (quarterly)
        let meetingInterval = 4
        let turnsSinceLast = game.turnNumber - lastMeetingTurn
        return max(0, meetingInterval - turnsSinceLast)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 24))
                .foregroundColor(theme.accentGold)

            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT SESSION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(theme.inkLight)

                if turnsUntilNextMeeting == 0 {
                    Text("Meeting this turn")
                        .font(theme.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(theme.sovietRed)
                } else {
                    Text("In \(turnsUntilNextMeeting) turn\(turnsUntilNextMeeting == 1 ? "" : "s")")
                        .font(theme.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(theme.inkBlack)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Last met")
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)
                Text("Turn \(lastMeetingTurn)")
                    .font(theme.labelFont)
                    .foregroundColor(theme.inkGray)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}
