//
//  OrgChartView.swift
//  Nomenklatura
//
//  Top-down organizational chart showing the Party hierarchy
//  General Secretary at top, branching to bureaus, entry at bottom
//

import SwiftUI
import SwiftData

struct OrgChartView: View {
    @Bindable var game: Game
    let ladder: [LadderPosition]
    var onWorldTap: (() -> Void)? = nil
    var onCongressTap: (() -> Void)? = nil

    @Environment(\.theme) var theme
    @State private var selectedPosition: LadderPosition? = nil
    @State private var showStandingCommittee: Bool = false

    // Capital tracks (6 bureaus) - order matters for display
    private let capitalTracks: [ExpandedCareerTrack] = [
        .partyApparatus,
        .stateMinistry,
        .securityServices,
        .foreignAffairs,
        .economicPlanning,
        .militaryPolitical
    ]

    // Node spacing
    private let nodeSpacing: CGFloat = 8
    private let levelSpacing: CGFloat = 16
    private let bureauSpacing: CGFloat = 100

    var body: some View {
        ZStack {
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ScreenHeader(
                    title: "Party Hierarchy",
                    subtitle: "Organizational Structure",
                    showWorldButton: onWorldTap != nil,
                    onWorldTap: onWorldTap,
                    showCongressButton: onCongressTap != nil,
                    onCongressTap: onCongressTap
                )

                // Progress indicator
                OrgChartProgressBar(
                    currentStanding: game.standing,
                    currentPosition: currentPositionTitle,
                    playerTrack: game.playerExpandedTrack.displayName
                )

                // Scrollable org chart
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(spacing: 0) {
                        // === TOP SHARED POSITIONS (GS chairs the SC) ===
                        apexSection

                        // === BUREAU BRANCHES (Index 6 → 2) ===
                        bureauSection

                        // === BOTTOM SHARED POSITIONS ===
                        entrySection
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(item: $selectedPosition) { position in
            PositionDetailSheet(
                position: position,
                holders: getHolders(for: position),
                game: game
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showStandingCommittee) {
            StandingCommitteeLadderSheet(game: game)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Apex Section (General Secretary & Deputy + Standing Committee)

    private var apexSection: some View {
        VStack(spacing: 0) {
            // Top row: GS with Standing Committee sidebar
            HStack(alignment: .top, spacing: 20) {
                // Index 8: General Secretary (Supreme Leader)
                if let genSec = getPosition(index: 8, track: .shared) {
                    VStack(spacing: 0) {
                        SharedPositionNode(
                            position: genSec,
                            holders: getHolders(for: genSec),
                            isPlayerPosition: isPlayerPosition(genSec),
                            isAchieved: genSec.index < game.currentPositionIndex,
                            scRank: .chairman,  // GS chairs the Standing Committee
                            onTap: { selectedPosition = genSec }
                        )
                    }
                }

                // Standing Committee (collective body chaired by GS)
                standingCommitteeNode
            }

            VerticalConnector(height: 20, isHighlighted: false, isAchieved: game.currentPositionIndex > 8)

            // Index 7: Deputy General Secretary
            if let deputy = getPosition(index: 7, track: .shared) {
                SharedPositionNode(
                    position: deputy,
                    holders: getHolders(for: deputy),
                    isPlayerPosition: isPlayerPosition(deputy),
                    isAchieved: deputy.index < game.currentPositionIndex,
                    onTap: { selectedPosition = deputy }
                )
            }

            // Branch connector to 6 bureaus
            BranchConnector(
                branchCount: 6,
                spacing: bureauSpacing,
                dropHeight: 30,
                highlightedIndex: highlightedBureauIndex
            )
            .frame(width: CGFloat(6) * bureauSpacing)
        }
    }

    // Standing Committee node (clickable sidebar showing the collective body)
    private var standingCommitteeNode: some View {
        Button(action: { showStandingCommittee = true }) {
            VStack(spacing: 4) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 10))
                    Text("STANDING COMMITTEE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(theme.accentGold)

                // Member info
                if let sc = game.standingCommittee {
                    let memberCount = sc.fullMemberIds.count + sc.candidateMemberIds.count + (sc.chairId != nil ? 1 : 0)
                    Text("\(memberCount) Members")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)

                    Text("Collective Leadership")
                        .font(.system(size: 8))
                        .foregroundColor(theme.inkLight)
                        .italic()

                    // Player status
                    if sc.playerIsOnCommittee {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 5))
                            Text("MEMBER")
                                .font(.system(size: 6, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(theme.sovietRed)
                        .cornerRadius(2)
                    }
                } else {
                    Text("Tap to view")
                        .font(.system(size: 8))
                        .foregroundColor(theme.inkLight)
                }
            }
            .frame(width: 120, height: 70)
            .padding(6)
            .background(theme.parchmentDark.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.accentGold.opacity(0.6), lineWidth: 1)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bureau Section (6 columns × 5 rows)

    private var bureauSection: some View {
        VStack(spacing: levelSpacing) {
            // For each level from 6 down to 2
            ForEach((2...6).reversed(), id: \.self) { levelIndex in
                HStack(alignment: .top, spacing: nodeSpacing) {
                    ForEach(capitalTracks, id: \.self) { track in
                        VStack(spacing: 0) {
                            if let position = getPosition(index: levelIndex, track: track) {
                                OrgChartNode(
                                    position: position,
                                    holders: getHolders(for: position),
                                    isPlayerPosition: isPlayerPosition(position),
                                    isAchieved: isAchievedPosition(position),
                                    isOnPlayerTrack: isOnPlayerTrack(track),
                                    isLocked: position.index > game.currentPositionIndex + 1,
                                    onTap: { selectedPosition = position }
                                )

                                // Connector to next level (if not at bottom)
                                if levelIndex > 2 {
                                    NodeConnector(
                                        height: levelSpacing - 4,
                                        isOnPlayerPath: isOnPlayerTrack(track) && position.index >= game.currentPositionIndex,
                                        isAchieved: isAchievedPosition(position)
                                    )
                                }
                            } else {
                                // Empty placeholder for missing positions
                                Color.clear
                                    .frame(width: 90, height: 60)
                            }
                        }
                    }

                    // Regional track (separate side branch)
                    if levelIndex >= 2 && levelIndex <= 4 {
                        regionalColumn(levelIndex: levelIndex)
                    } else {
                        Color.clear.frame(width: 90)
                    }
                }
            }

            // Merge connector back to shared
            MergeConnector(
                branchCount: 6,
                spacing: bureauSpacing,
                riseHeight: 30,
                highlightedIndex: highlightedBureauIndex
            )
            .frame(width: CGFloat(6) * bureauSpacing)
        }
    }

    // MARK: - Regional Column (Side Branch)

    @ViewBuilder
    private func regionalColumn(levelIndex: Int) -> some View {
        VStack(spacing: 0) {
            // Regional positions at indices 2, 3, 4
            let regionalIndex = levelIndex  // Map to regional positions
            if let position = getPosition(index: regionalIndex, track: .regional) {
                Divider()
                    .frame(width: 20)
                    .padding(.leading, 10)

                OrgChartNode(
                    position: position,
                    holders: getHolders(for: position),
                    isPlayerPosition: isPlayerPosition(position),
                    isAchieved: isAchievedPosition(position),
                    isOnPlayerTrack: game.playerExpandedTrack == .regional,
                    isLocked: position.index > game.currentPositionIndex + 1,
                    onTap: { selectedPosition = position }
                )
            }
        }
    }

    // MARK: - Entry Section (Junior Presidium & Party Official)

    private var entrySection: some View {
        VStack(spacing: 0) {
            // Index 1: Junior Presidium Member
            if let junior = getPosition(index: 1, track: .shared) {
                SharedPositionNode(
                    position: junior,
                    holders: getHolders(for: junior),
                    isPlayerPosition: isPlayerPosition(junior),
                    isAchieved: junior.index < game.currentPositionIndex,
                    onTap: { selectedPosition = junior }
                )

                VerticalConnector(height: 20, isHighlighted: game.currentPositionIndex <= 1, isAchieved: game.currentPositionIndex > 1)
            }

            // Index 0: Party Official (Entry)
            if let entry = getPosition(index: 0, track: .shared) {
                SharedPositionNode(
                    position: entry,
                    holders: getHolders(for: entry),
                    isPlayerPosition: isPlayerPosition(entry),
                    isAchieved: entry.index < game.currentPositionIndex,
                    onTap: { selectedPosition = entry }
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func getPosition(index: Int, track: ExpandedCareerTrack) -> LadderPosition? {
        ladder.first { $0.index == index && $0.expandedTrack == track }
    }

    private func getHolders(for position: LadderPosition) -> [String] {
        // Don't show "You" in holder list - we show the badge instead
        if isPlayerPosition(position) {
            return []
        }

        return game.characters
            .filter { character in
                guard character.positionIndex == position.index && character.isAlive else {
                    return false
                }
                guard let charTrack = character.positionTrack else {
                    return position.expandedTrack == .shared
                }
                return charTrack == position.expandedTrack.rawValue
            }
            .map { $0.name }
    }

    private func isPlayerPosition(_ position: LadderPosition) -> Bool {
        position.index == game.currentPositionIndex &&
        position.expandedTrack == game.playerExpandedTrack
    }

    private func isAchievedPosition(_ position: LadderPosition) -> Bool {
        // Position is achieved if player has passed this level on their track
        if position.expandedTrack == game.playerExpandedTrack || position.expandedTrack == .shared {
            return position.index < game.currentPositionIndex
        }
        return false
    }

    private func isOnPlayerTrack(_ track: ExpandedCareerTrack) -> Bool {
        // Shared track is always on player's path
        if track == .shared { return true }

        // If player is still on shared (hasn't branched), all capital tracks are potential
        if game.playerExpandedTrack == .shared && track != .regional {
            return true
        }

        return track == game.playerExpandedTrack
    }

    private var highlightedBureauIndex: Int? {
        guard game.playerExpandedTrack != .shared && game.playerExpandedTrack != .regional else {
            return nil
        }
        return capitalTracks.firstIndex(of: game.playerExpandedTrack)
    }

    private var currentPositionTitle: String {
        ladder.first {
            $0.index == game.currentPositionIndex &&
            $0.expandedTrack == game.playerExpandedTrack
        }?.title ?? "Unknown Position"
    }
}

// MARK: - Progress Bar

struct OrgChartProgressBar: View {
    let currentStanding: Int
    let currentPosition: String
    let playerTrack: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("STANDING")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "AAAAAA"))
                Text("\(currentStanding)")
                    .font(theme.statFont)
                    .foregroundColor(theme.schemeText)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("POSITION")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "AAAAAA"))
                Text(currentPosition)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.schemeText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("TRACK")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "AAAAAA"))
                Text(playerTrack)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.accentGold)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(Color(hex: "3A3A3A"))
    }
}

// MARK: - Position Detail Sheet

struct PositionDetailSheet: View {
    let position: LadderPosition
    let holders: [String]
    let game: Game
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    private var isPlayerPosition: Bool {
        position.index == game.currentPositionIndex &&
        position.expandedTrack == game.playerExpandedTrack
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Position header
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if position.expandedTrack != .shared {
                                Image(systemName: position.expandedTrack.iconName)
                                    .foregroundColor(theme.accentGold)
                            }
                            Text(position.title.uppercased())
                                .font(theme.headerFont)
                                .tracking(1)
                        }

                        Text(position.expandedTrack.displayName)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)

                        if isPlayerPosition {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                Text("YOUR CURRENT POSITION")
                                    .font(theme.tagFont)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(theme.sovietRed)
                            .padding(.top, 4)
                        }
                    }

                    Divider()

                    // Description
                    Text(position.description)
                        .font(theme.narrativeFont)
                        .foregroundColor(theme.inkGray)

                    // Requirements
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REQUIREMENTS")
                            .font(theme.labelFont)
                            .fontWeight(.semibold)
                            .tracking(1)

                        requirementRow("Standing", value: position.requiredStanding, current: game.standing)

                        if let favor = position.requiredPatronFavor {
                            requirementRow("Patron Favor", value: favor, current: game.patronFavor)
                        }

                        if let network = position.requiredNetwork {
                            requirementRow("Network", value: network, current: game.network)
                        }
                    }
                    .padding()
                    .background(theme.parchmentDark)
                    .cornerRadius(8)

                    // Current holders
                    if !holders.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CURRENT HOLDERS")
                                .font(theme.labelFont)
                                .fontWeight(.semibold)
                                .tracking(1)

                            ForEach(holders, id: \.self) { holder in
                                HStack {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.inkLight)
                                    Text(holder)
                                        .font(theme.narrativeFont)
                                }
                            }
                        }
                        .padding()
                        .background(theme.parchmentDark)
                        .cornerRadius(8)
                    } else if !isPlayerPosition {
                        Text("Position Vacant")
                            .font(theme.narrativeFont)
                            .foregroundColor(theme.accentGold)
                            .italic()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(theme.parchmentDark)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .background(theme.parchment)
            .navigationTitle("Position Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func requirementRow(_ label: String, value: Int, current: Int) -> some View {
        HStack {
            Text(label)
                .font(theme.tagFont)
                .foregroundColor(theme.inkGray)
            Spacer()
            Text("\(value)+")
                .font(theme.tagFont)
                .fontWeight(.semibold)
                .foregroundColor(current >= value ? .statHigh : theme.inkBlack)
            if current >= value {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.statHigh)
            }
        }
    }
}

// MARK: - Standing Committee Ladder Sheet

struct StandingCommitteeLadderSheet: View {
    let game: Game
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    private var committeeMembers: [(character: GameCharacter, rank: SCRank)] {
        guard let sc = game.standingCommittee else { return [] }

        var members: [(GameCharacter, SCRank)] = []

        // Chair first
        if let chairId = sc.chairId,
           let chair = game.characters.first(where: { $0.templateId == chairId && $0.isAlive }) {
            members.append((chair, .chairman))
        }

        // Full members (excluding chair who was already added)
        for memberId in sc.fullMemberIds where memberId != sc.chairId {
            if let member = game.characters.first(where: { $0.templateId == memberId && $0.isAlive }) {
                members.append((member, .fullMember))
            }
        }

        // Candidate members
        for memberId in sc.candidateMemberIds {
            if let member = game.characters.first(where: { $0.templateId == memberId && $0.isAlive }) {
                members.append((member, .candidateMember))
            }
        }

        return members
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header description
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 20))
                                .foregroundColor(theme.accentGold)
                            Text("Standing Committee")
                                .font(theme.headerFont)
                        }

                        Text("The supreme collective leadership body. These 7-9 individuals hold ultimate power over all state and party affairs.")
                            .font(theme.narrativeFont)
                            .foregroundColor(theme.inkGray)

                        // Player status
                        if let sc = game.standingCommittee, sc.playerIsOnCommittee {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                Text("You are a \(sc.playerRank?.capitalized ?? "member") of this committee")
                                    .font(theme.tagFont)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(theme.sovietRed)
                        } else {
                            Text("Position 5+ required for eligibility")
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkLight)
                        }
                    }

                    Divider()

                    // Members list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("COMMITTEE MEMBERS")
                            .font(theme.labelFont)
                            .fontWeight(.semibold)
                            .tracking(1)

                        if committeeMembers.isEmpty {
                            Text("No committee members found")
                                .font(theme.narrativeFont)
                                .foregroundColor(theme.inkLight)
                                .italic()
                        } else {
                            ForEach(committeeMembers, id: \.character.id) { member, rank in
                                SCMemberRow(character: member, rank: rank, game: game)
                            }
                        }
                    }
                    .padding()
                    .background(theme.parchmentDark)
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(theme.parchment)
            .navigationTitle("Standing Committee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - SC Member Row

private struct SCMemberRow: View {
    let character: GameCharacter
    let rank: SCRank
    let game: Game
    @Environment(\.theme) var theme

    private var positionTitle: String {
        guard let index = character.positionIndex else { return "Unknown Position" }
        let ladder = CampaignLoader.shared.getColdWarCampaign().ladder
        if let trackName = character.positionTrack,
           let track = ExpandedCareerTrack(rawValue: trackName),
           let pos = ladder.first(where: { $0.index == index && $0.expandedTrack == track }) {
            return pos.title
        }
        if let pos = ladder.first(where: { $0.index == index && $0.expandedTrack == .shared }) {
            return pos.title
        }
        return "Position \(index)"
    }

    private var factionName: String? {
        guard let factionId = character.factionId else { return nil }
        return game.factions.first(where: { $0.factionId == factionId })?.name
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank indicator
            VStack {
                Image(systemName: rank == .chairman ? "crown.fill" : "person.fill")
                    .font(.system(size: rank == .chairman ? 16 : 14))
                    .foregroundColor(rankColor)
            }
            .frame(width: 30)

            // Character info
            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.inkBlack)

                Text(positionTitle)
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkGray)

                HStack(spacing: 8) {
                    // Rank badge
                    Text(rank.displayName.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rankColor)
                        .cornerRadius(2)

                    // Faction
                    if let faction = factionName {
                        Text(faction)
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkLight)
                    }
                }
            }

            Spacer()

            // Relationship indicator
            if character.isPatron {
                Image(systemName: "shield.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.accentGold)
            } else if character.isRival {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.sovietRed)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(theme.parchment)
        .cornerRadius(6)
    }

    private var rankColor: Color {
        switch rank {
        case .chairman: return theme.accentGold
        case .fullMember: return Color(hex: "4A4A4A")
        case .candidateMember: return Color(hex: "7A7A7A")
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.currentPositionIndex = 3
    game.standing = 47
    container.mainContext.insert(game)

    let ladder = CampaignLoader.shared.getColdWarCampaign().ladder

    return OrgChartView(game: game, ladder: ladder)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
