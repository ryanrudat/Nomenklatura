//
//  SCMeetingView.swift
//  Nomenklatura
//
//  Standing Committee Meeting View - Interactive phase where the player
//  navigates factional politics, proposes policies, and faces opposition.
//

import SwiftUI
import SwiftData

// MARK: - SC Meeting Colors

private enum SCColors {
    static let approvedGreen = SCColors.approvedGreen
    static let cardBackground = SCColors.cardBackground
    static let darkBackground = SCColors.darkBackground
    static let headerBackground = SCColors.headerBackground
    static let neutralGray = SCColors.neutralGray
}

// MARK: - SC Meeting View

struct SCMeetingView: View {
    @Bindable var game: Game
    let onMeetingComplete: () -> Void
    @Environment(\.theme) var theme

    // Meeting state
    @State private var agendaItems: [CommitteeAgendaItem] = []
    @State private var voteResults: [SCMeetingVoteResult] = []
    @State private var currentItemIndex: Int = 0
    @State private var meetingPhase: MeetingPhase = .opening
    @State private var playerVote: PlayerVote? = nil
    @State private var noConfidenceCheck: NoConfidenceCheck? = nil
    @State private var noConfidenceResult: NoConfidenceResult? = nil
    @State private var showContent = false

    private let meetingService = StandingCommitteeMeetingService.shared

    enum MeetingPhase {
        case opening
        case agenda
        case voting
        case voteResult
        case noConfidence
        case noConfidenceResult
        case closing
    }

    private var committee: StandingCommittee? {
        game.standingCommittee
    }

    private var currentItem: CommitteeAgendaItem? {
        guard currentItemIndex < agendaItems.count else { return nil }
        return agendaItems[currentItemIndex]
    }

    private var members: [GameCharacter] {
        guard let committee = committee else { return [] }
        return committee.memberIds.compactMap { memberId in
            game.characters.first { $0.templateId == memberId && $0.isAlive }
        }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }
    }

    var body: some View {
        ZStack {
            // Dark background with subtle red tint
            SCColors.darkBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                meetingHeader

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        switch meetingPhase {
                        case .opening:
                            openingSection
                        case .agenda:
                            agendaOverviewSection
                        case .voting:
                            if let item = currentItem {
                                votingSection(item: item)
                            }
                        case .voteResult:
                            if let lastResult = voteResults.last {
                                voteResultSection(result: lastResult)
                            }
                        case .noConfidence:
                            noConfidenceSection
                        case .noConfidenceResult:
                            if let result = noConfidenceResult {
                                noConfidenceResultSection(result: result)
                            }
                        case .closing:
                            closingSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            prepareAgenda()
            withAnimation(.easeIn(duration: 0.5)) {
                showContent = true
            }
        }
    }

    // MARK: - Header

    private var meetingHeader: some View {
        VStack(spacing: 0) {
            // Red accent line
            Rectangle()
                .fill(theme.sovietRed)
                .frame(height: 3)

            HStack(spacing: 12) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 22))
                    .foregroundColor(theme.accentGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("STANDING COMMITTEE SESSION")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(theme.accentGold)

                    Text(RevolutionaryCalendar.formatTurnWithMonth(game.turnNumber))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.schemeText.opacity(0.6))
                }

                Spacer()

                // Progress indicator
                if meetingPhase == .voting || meetingPhase == .voteResult {
                    Text("\(currentItemIndex + 1)/\(agendaItems.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.schemeText.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(SCColors.headerBackground)
        }
    }

    // MARK: - Opening

    private var openingSection: some View {
        VStack(spacing: 20) {
            // Atmosphere card
            VStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundColor(theme.accentGold)
                    .opacity(showContent ? 1 : 0)

                Text("THE COMMITTEE CONVENES")
                    .font(.system(size: 18, weight: .black))
                    .tracking(3)
                    .foregroundColor(theme.accentGold)
                    .opacity(showContent ? 1 : 0)

                Text(openingNarrative)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(theme.schemeText.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .opacity(showContent ? 1 : 0)

                // Member attendance
                VStack(alignment: .leading, spacing: 8) {
                    Text("MEMBERS PRESENT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(theme.schemeText.opacity(0.4))

                    ForEach(members, id: \.id) { member in
                        memberAttendanceRow(member: member)
                    }

                    if committee?.playerIsOnCommittee == true {
                        playerAttendanceRow
                    }
                }
                .padding(16)
                .background(SCColors.cardBackground.opacity(0.8))
                .overlay(
                    Rectangle()
                        .stroke(theme.accentGold.opacity(0.3), lineWidth: 1)
                )

                Text("\(agendaItems.count) ITEM\(agendaItems.count == 1 ? "" : "S") ON THE AGENDA")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(theme.schemeText.opacity(0.6))
            }
            .padding(.top, 20)

            proceedButton(text: "REVIEW AGENDA") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    meetingPhase = .agenda
                }
            }
        }
    }

    // MARK: - Agenda Overview

    private var agendaOverviewSection: some View {
        VStack(spacing: 16) {
            Text("AGENDA")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundColor(theme.accentGold)

            ForEach(Array(agendaItems.enumerated()), id: \.element.id) { index, item in
                agendaItemCard(item: item, index: index)
            }

            if committee?.playerIsOnCommittee == true {
                // Faction balance summary
                factionBalanceSummary
            }

            proceedButton(text: "BEGIN DELIBERATIONS") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentItemIndex = 0
                    meetingPhase = .voting
                    playerVote = nil
                }
            }
        }
    }

    // MARK: - Voting

    private func votingSection(item: CommitteeAgendaItem) -> some View {
        VStack(spacing: 16) {
            // Item header
            VStack(spacing: 8) {
                HStack {
                    priorityBadge(item.priority)
                    Spacer()
                    Text(item.category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(theme.schemeText.opacity(0.4))
                }

                Text(item.title.uppercased())
                    .font(.system(size: 16, weight: .black))
                    .tracking(1)
                    .foregroundColor(theme.schemeText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.description)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(theme.schemeText.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Sponsor info
                if let sponsorId = item.sponsorId, sponsorId != "player" {
                    if let sponsor = game.characters.first(where: { $0.templateId == sponsorId }) {
                        HStack(spacing: 6) {
                            Text("Proposed by")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(theme.schemeText.opacity(0.4))
                            Text(sponsor.name)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.sovietRed)
                        }
                    }
                } else if item.sponsorId == "player" {
                    HStack(spacing: 6) {
                        Text("Proposed by")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(theme.schemeText.opacity(0.4))
                        Text("YOU")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.accentGold)
                    }
                }

                // Expected effects
                if !item.effects.isEmpty {
                    effectsPreview(item.effects)
                }
            }
            .padding(16)
            .background(SCColors.cardBackground)
            .overlay(
                Rectangle()
                    .stroke(theme.schemeBorder, lineWidth: 1)
            )

            // Member positions preview
            memberPositionsPreview(item: item)

            // Player voting options
            if committee?.playerIsOnCommittee == true {
                VStack(spacing: 12) {
                    Text("YOUR VOTE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(theme.accentGold)

                    HStack(spacing: 12) {
                        voteButton(label: "AYE", vote: .for, color: SCColors.approvedGreen)
                        voteButton(label: "NAY", vote: .against, color: theme.sovietRed)
                        voteButton(label: "ABSTAIN", vote: .abstain, color: SCColors.neutralGray)
                    }
                }
                .padding(.top, 8)
            }

            // Confirm vote button
            if let vote = playerVote {
                proceedButton(text: "CALL THE VOTE") {
                    resolveCurrentVote(playerVote: vote)
                }
            } else if committee?.playerIsOnCommittee != true {
                // Observer mode - vote proceeds without player
                proceedButton(text: "OBSERVE THE VOTE") {
                    resolveCurrentVote(playerVote: .abstain)
                }
            }
        }
    }

    // MARK: - Vote Result

    private func voteResultSection(result: SCMeetingVoteResult) -> some View {
        VStack(spacing: 16) {
            // Result stamp
            VStack(spacing: 12) {
                Text(result.passed ? "APPROVED" : "REJECTED")
                    .font(.system(size: 28, weight: .black))
                    .tracking(4)
                    .foregroundColor(result.passed ? SCColors.approvedGreen : theme.sovietRed)
                    .rotationEffect(.degrees(result.passed ? -3 : 3))
                    .overlay(
                        Rectangle()
                            .stroke(result.passed ? SCColors.approvedGreen : theme.sovietRed, lineWidth: 3)
                            .rotationEffect(.degrees(result.passed ? -3 : 3))
                            .padding(-8)
                    )
                    .padding(16)

                Text(result.item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.schemeText)
            }

            // Vote breakdown
            VStack(spacing: 8) {
                Text("VOTE RECORD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(theme.schemeText.opacity(0.4))

                HStack(spacing: 20) {
                    voteCountColumn(count: result.votesFor.count, label: "AYE", color: SCColors.approvedGreen)
                    voteCountColumn(count: result.votesAgainst.count, label: "NAY", color: theme.sovietRed)
                    voteCountColumn(count: result.abstentions.count, label: "ABSTAIN", color: SCColors.neutralGray)
                }

                // Faction breakdown
                factionVoteBreakdown(result: result)

                if result.playerInfluenceApplied {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.accentGold)
                        Text("Your influence carried additional weight")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(theme.accentGold.opacity(0.8))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(SCColors.cardBackground)
            .overlay(
                Rectangle()
                    .stroke(theme.schemeBorder, lineWidth: 1)
            )

            // Effects applied
            if result.passed && !result.item.effects.isEmpty {
                VStack(spacing: 6) {
                    Text("EFFECTS ENACTED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(theme.schemeText.opacity(0.4))

                    effectsPreview(result.item.effects)
                }
                .padding(12)
                .background(SCColors.approvedGreen.opacity(0.15))
                .overlay(
                    Rectangle()
                        .stroke(SCColors.approvedGreen.opacity(0.3), lineWidth: 1)
                )
            }

            // Next item or close
            let nextText = currentItemIndex < agendaItems.count - 1 ? "NEXT ITEM" : "CONCLUDE SESSION"
            proceedButton(text: nextText) {
                advanceToNextItem()
            }
        }
    }

    // MARK: - No Confidence

    private var noConfidenceSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.sovietRed)

            Text("VOTE OF NO CONFIDENCE")
                .font(.system(size: 18, weight: .black))
                .tracking(3)
                .foregroundColor(theme.sovietRed)

            if let check = noConfidenceCheck {
                Text("A coalition of \(check.hostileCount) members has challenged your leadership. They demand a formal vote on your continued position.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(theme.schemeText.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // Hostile members list
                VStack(alignment: .leading, spacing: 6) {
                    Text("CHALLENGERS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(theme.sovietRed.opacity(0.7))

                    ForEach(check.hostileMembers, id: \.id) { member in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(theme.sovietRed)
                                .frame(width: 8, height: 8)
                            Text(member.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.schemeText)
                            Spacer()
                            if let factionId = member.factionId {
                                Text(factionDisplayName(factionId))
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.schemeText.opacity(0.5))
                            }
                        }
                    }
                }
                .padding(12)
                .background(theme.sovietRed.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(theme.sovietRed.opacity(0.3), lineWidth: 1)
                )
            }

            proceedButton(text: "FACE THE VOTE", color: theme.sovietRed) {
                let result = meetingService.resolveNoConfidenceVote(game: game)
                noConfidenceResult = result
                withAnimation(.easeInOut(duration: 0.3)) {
                    meetingPhase = .noConfidenceResult
                }
            }
        }
    }

    private func noConfidenceResultSection(result: NoConfidenceResult) -> some View {
        VStack(spacing: 20) {
            if result.passed {
                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundColor(theme.sovietRed)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundColor(theme.accentGold)
            }

            Text(result.passed ? "REMOVED FROM OFFICE" : "CONFIDENCE SUSTAINED")
                .font(.system(size: 18, weight: .black))
                .tracking(3)
                .foregroundColor(result.passed ? theme.sovietRed : theme.accentGold)

            Text(result.narrative)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(theme.schemeText.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            HStack(spacing: 30) {
                voteCountColumn(count: result.votesFor, label: "FOR REMOVAL", color: theme.sovietRed)
                voteCountColumn(count: result.votesAgainst, label: "AGAINST", color: SCColors.approvedGreen)
            }
            .padding(16)
            .background(SCColors.cardBackground)
            .overlay(
                Rectangle()
                    .stroke(theme.schemeBorder, lineWidth: 1)
            )

            proceedButton(text: "CONTINUE") {
                if result.passed {
                    // Game over triggered in ContentView
                    game.status = GameStatus.lost.rawValue
                    game.endReason = "The Standing Committee voted to remove you from office."
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    meetingPhase = .closing
                }
            }
        }
    }

    // MARK: - Closing

    private var closingSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.accentGold)

            Text("SESSION ADJOURNED")
                .font(.system(size: 18, weight: .black))
                .tracking(3)
                .foregroundColor(theme.accentGold)

            // Summary
            VStack(spacing: 12) {
                let passedCount = voteResults.filter { $0.passed }.count
                let rejectedCount = voteResults.filter { !$0.passed }.count

                Text("MEETING SUMMARY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(theme.schemeText.opacity(0.4))

                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(passedCount)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundColor(SCColors.approvedGreen)
                        Text("APPROVED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(theme.schemeText.opacity(0.5))
                    }

                    Rectangle()
                        .fill(theme.schemeBorder)
                        .frame(width: 1, height: 40)

                    VStack(spacing: 4) {
                        Text("\(rejectedCount)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundColor(theme.sovietRed)
                        Text("REJECTED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(theme.schemeText.opacity(0.5))
                    }
                }

                // List passed items
                ForEach(voteResults, id: \.id) { result in
                    HStack(spacing: 8) {
                        Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(result.passed ? SCColors.approvedGreen : theme.sovietRed)
                        Text(result.item.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.schemeText.opacity(0.7))
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(SCColors.cardBackground)
            .overlay(
                Rectangle()
                    .stroke(theme.schemeBorder, lineWidth: 1)
            )

            proceedButton(text: "RETURN TO DESK") {
                meetingService.completeMeeting(results: voteResults, game: game)
                onMeetingComplete()
            }
        }
    }

    // MARK: - Reusable Components

    private func memberAttendanceRow(member: GameCharacter) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(member.templateId == committee?.chairId ? theme.accentGold : theme.sovietRed.opacity(0.5))
                .frame(width: 8, height: 8)

            Text(member.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.schemeText.opacity(0.8))

            if member.templateId == committee?.chairId {
                Text("CHAIR")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(theme.accentGold)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(theme.accentGold.opacity(0.2))
            }

            Spacer()

            if let factionId = member.factionId {
                Text(factionDisplayName(factionId))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(factionColor(factionId).opacity(0.8))
            }
        }
    }

    private var playerAttendanceRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(committee?.playerIsChair == true ? theme.accentGold : theme.steelBlue)
                .frame(width: 8, height: 8)

            Text("You")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(theme.accentGold)

            if committee?.playerIsChair == true {
                Text("CHAIR")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(theme.accentGold)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(theme.accentGold.opacity(0.2))
            } else {
                Text(committee?.playerIsFullMember == true ? "MEMBER" : "CANDIDATE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(theme.schemeText.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(theme.schemeText.opacity(0.1))
            }

            Spacer()

            if let factionId = game.playerFactionId {
                Text(factionDisplayName(factionId))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(factionColor(factionId).opacity(0.8))
            }
        }
    }

    private func agendaItemCard(item: CommitteeAgendaItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(index + 1).")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(theme.accentGold)

                priorityBadge(item.priority)

                Spacer()

                Text(item.category.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(theme.schemeText.opacity(0.4))
            }

            Text(item.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(theme.schemeText)

            Text(item.description)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundColor(theme.schemeText.opacity(0.65))
                .lineLimit(3)

            if !item.effects.isEmpty {
                effectsPreview(item.effects)
            }
        }
        .padding(12)
        .background(SCColors.cardBackground)
        .overlay(
            Rectangle()
                .stroke(theme.schemeBorder, lineWidth: 1)
        )
    }

    private func memberPositionsPreview(item: CommitteeAgendaItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMMITTEE POSITIONS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.schemeText.opacity(0.4))

            ForEach(members, id: \.id) { member in
                let stance = estimateMemberStance(member: member, item: item)
                HStack(spacing: 8) {
                    Circle()
                        .fill(stanceColor(stance))
                        .frame(width: 8, height: 8)

                    Text(member.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.schemeText.opacity(0.7))

                    Spacer()

                    Text(stanceLabel(stance))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(stanceColor(stance))
                }
            }
        }
        .padding(12)
        .background(SCColors.cardBackground.opacity(0.5))
        .overlay(
            Rectangle()
                .stroke(theme.schemeBorder.opacity(0.5), lineWidth: 1)
        )
    }

    private func voteButton(label: String, vote: PlayerVote, color: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                playerVote = vote
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundColor(playerVote == vote ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(playerVote == vote ? color : color.opacity(0.15))
                .overlay(
                    Rectangle()
                        .stroke(color, lineWidth: playerVote == vote ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func proceedButton(text: String, color: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color ?? theme.sovietRed)
        }
        .buttonStyle(.plain)
    }

    private func priorityBadge(_ priority: CommitteeAgendaItem.AgendaPriority) -> some View {
        Text(priority.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.5)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor(priority))
    }

    private func effectsPreview(_ effects: [String: Int]) -> some View {
        HStack(spacing: 8) {
            ForEach(effects.sorted(by: { $0.key < $1.key }), id: \.key) { stat, change in
                HStack(spacing: 2) {
                    Text(statAbbreviation(stat))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.schemeText.opacity(0.5))
                    Text(change > 0 ? "+\(change)" : "\(change)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(change > 0 ? SCColors.approvedGreen : theme.sovietRed)
                }
            }
        }
    }

    private func voteCountColumn(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(theme.schemeText.opacity(0.5))
        }
    }

    private func factionVoteBreakdown(result: SCMeetingVoteResult) -> some View {
        let allVotes = result.votesFor.map { ($0, "for") }
            + result.votesAgainst.map { ($0, "against") }
            + result.abstentions.map { ($0, "abstain") }

        var factionSummary: [String: (forCount: Int, againstCount: Int, abstainCount: Int)] = [:]
        for (vote, voteType) in allVotes {
            let factionKey = vote.factionId ?? "Independent"
            var current = factionSummary[factionKey, default: (0, 0, 0)]
            switch voteType {
            case "for": current.forCount += 1
            case "against": current.againstCount += 1
            default: current.abstainCount += 1
            }
            factionSummary[factionKey] = current
        }

        return VStack(alignment: .leading, spacing: 4) {
            Text("BY FACTION")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(theme.schemeText.opacity(0.3))

            ForEach(factionSummary.sorted(by: { $0.key < $1.key }), id: \.key) { factionId, counts in
                HStack(spacing: 8) {
                    Circle()
                        .fill(factionColor(factionId))
                        .frame(width: 6, height: 6)
                    Text(factionDisplayName(factionId))
                        .font(.system(size: 10))
                        .foregroundColor(theme.schemeText.opacity(0.6))
                    Spacer()
                    if counts.forCount > 0 {
                        Text("\(counts.forCount) aye")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(SCColors.approvedGreen)
                    }
                    if counts.againstCount > 0 {
                        Text("\(counts.againstCount) nay")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.sovietRed)
                    }
                }
            }
        }
    }

    private var factionBalanceSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMMITTEE FACTION BALANCE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.schemeText.opacity(0.4))

            if let balance = committee?.factionBalance {
                ForEach(balance.sorted(by: { $0.value > $1.value }), id: \.key) { factionId, seats in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(factionColor(factionId))
                            .frame(width: 8, height: 8)
                        Text(factionDisplayName(factionId))
                            .font(.system(size: 11))
                            .foregroundColor(theme.schemeText.opacity(0.7))
                        Spacer()
                        Text("\(seats) seat\(seats == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.schemeText.opacity(0.5))
                    }
                }
            }
        }
        .padding(12)
        .background(SCColors.cardBackground.opacity(0.5))
        .overlay(
            Rectangle()
                .stroke(theme.schemeBorder.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Logic

    private func prepareAgenda() {
        guard let committee = committee else { return }

        // Combine existing pending agenda with state-based items
        var items = committee.pendingAgenda
        let stateItems = meetingService.generateStateBasedAgenda(game: game)

        // Add state-based items that don't duplicate existing ones
        let existingTitles = Set(items.map { $0.title })
        for item in stateItems where !existingTitles.contains(item.title) {
            items.append(item)
        }

        // Ensure at least 2 items per meeting
        if items.isEmpty {
            items.append(CommitteeAgendaItem(
                title: "Quarterly Status Report",
                description: "The Secretariat presents the regular quarterly report on Party affairs, economic indicators, and administrative matters for committee review.",
                category: .policy,
                priority: .routine,
                sponsorId: committee.secretaryId ?? committee.chairId,
                turnSubmitted: game.turnNumber,
                effects: ["stability": 2]
            ))
        }

        // Sort by priority
        agendaItems = items.sorted { priorityValue($0.priority) > priorityValue($1.priority) }
    }

    private func resolveCurrentVote(playerVote: PlayerVote) {
        guard let item = currentItem else { return }

        let result = meetingService.resolveVote(
            item: item,
            playerVote: playerVote,
            game: game
        )
        voteResults.append(result)

        self.playerVote = nil

        withAnimation(.easeInOut(duration: 0.3)) {
            meetingPhase = .voteResult
        }
    }

    private func advanceToNextItem() {
        if currentItemIndex < agendaItems.count - 1 {
            currentItemIndex += 1
            playerVote = nil
            withAnimation(.easeInOut(duration: 0.3)) {
                meetingPhase = .voting
            }
        } else {
            // All items voted on. Check for no-confidence.
            let check = meetingService.checkNoConfidenceRisk(game: game)
            if check.isTriggered {
                noConfidenceCheck = check
                withAnimation(.easeInOut(duration: 0.3)) {
                    meetingPhase = .noConfidence
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    meetingPhase = .closing
                }
            }
        }
    }

    // MARK: - Helpers

    private var openingNarrative: String {
        let atmosphere: String
        if game.stability < 30 {
            atmosphere = "The members file in with visible tension. Guards line the corridor. Someone has brought extra security."
        } else if game.stability < 50 {
            atmosphere = "The atmosphere is charged. Factions have been maneuvering since the last session. Every word will be weighed carefully."
        } else if game.stability > 70 {
            atmosphere = "The meeting room is orderly, the tea already poured. A productive session is expected."
        } else {
            atmosphere = "The members take their usual seats. The agenda has been circulated. The session begins."
        }
        return atmosphere
    }

    private enum MemberStance {
        case likely_support
        case likely_oppose
        case uncertain
    }

    private func estimateMemberStance(member: GameCharacter, item: CommitteeAgendaItem) -> MemberStance {
        var score = 50

        // Faction alignment with sponsor
        if let sponsorId = item.sponsorId,
           let sponsor = game.characters.first(where: { $0.templateId == sponsorId }),
           sponsor.factionId == member.factionId {
            score += 25
        }

        // Category personality alignment
        switch item.category {
        case .security: score += member.personalityRuthless / 5
        case .personnel: score += member.personalityAmbitious / 5
        case .economic: score += member.personalityCompetent / 5
        default: break
        }

        // Disposition toward player (if player-sponsored)
        if item.sponsorId == "player" {
            score += (member.disposition - 50) / 3
        }

        if score > 60 { return .likely_support }
        if score < 40 { return .likely_oppose }
        return .uncertain
    }

    private func stanceColor(_ stance: MemberStance) -> Color {
        switch stance {
        case .likely_support: return SCColors.approvedGreen
        case .likely_oppose: return theme.sovietRed
        case .uncertain: return Color(hex: "B8860B")
        }
    }

    private func stanceLabel(_ stance: MemberStance) -> String {
        switch stance {
        case .likely_support: return "LIKELY AYE"
        case .likely_oppose: return "LIKELY NAY"
        case .uncertain: return "UNCERTAIN"
        }
    }

    private func priorityColor(_ priority: CommitteeAgendaItem.AgendaPriority) -> Color {
        switch priority {
        case .critical: return theme.sovietRed
        case .urgent: return Color(hex: "FF9800")
        case .important: return Color(hex: "B8860B")
        case .routine: return SCColors.neutralGray
        }
    }

    private func priorityValue(_ priority: CommitteeAgendaItem.AgendaPriority) -> Int {
        switch priority {
        case .routine: return 1
        case .important: return 2
        case .urgent: return 3
        case .critical: return 4
        }
    }

    private func factionDisplayName(_ factionId: String) -> String {
        factionId.replacingOccurrences(of: "_", with: " ").capitalized
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

    private func statAbbreviation(_ stat: String) -> String {
        switch stat {
        case "stability": return "STB"
        case "popularSupport": return "POP"
        case "militaryLoyalty": return "MIL"
        case "eliteLoyalty": return "ELT"
        case "treasury": return "TRS"
        case "industrialOutput": return "IND"
        case "foodSupply": return "FOD"
        case "internationalStanding": return "INT"
        default: return stat.prefix(3).uppercased()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    container.mainContext.insert(game)

    return SCMeetingView(game: game) {
        print("Meeting complete")
    }
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
