//
//  MilitaryPortalView.swift
//  Nomenklatura
//
//  Military-Political Bureau Portal - PLA-style commissar operations
//  Modeled on CCP/PLA Political Work Department with dual command structure
//
//  Three sections:
//  - Overview: Military situation and theater readiness
//  - Campaigns: Active ideological/purge campaigns
//  - Actions: Execute commissar actions based on position
//

import SwiftUI
import SwiftData

struct MilitaryPortalView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedSection: MilitarySection = .overview

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            MilitaryPortalHeader()
                .padding(.horizontal, 15)
                .padding(.top, 10)

            // Section tabs
            MilitarySectionBar(selectedSection: $selectedSection, accessLevel: accessLevel)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)

            // Content
            ScrollView {
                switch selectedSection {
                case .overview:
                    MilitaryOverviewSection(game: game)
                case .campaigns:
                    MilitaryCampaignsSection(game: game)
                case .actions:
                    MilitaryActionsSection(game: game)
                }
            }
        }
    }
}

// MARK: - Military Portal Header

struct MilitaryPortalHeader: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Text("MILITARY-POLITICAL BUREAU")
                .font(.system(size: 14, weight: .bold))
                .tracking(2)
                .foregroundColor(theme.accentGold)

            Text("Central Military Commission Political Work Dept")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#8B0000").opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Military Sections

enum MilitarySection: String, CaseIterable {
    case overview
    case campaigns
    case actions

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .campaigns: return "Campaigns"
        case .actions: return "Actions"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "shield.lefthalf.filled"
        case .campaigns: return "flag.fill"
        case .actions: return "bolt.fill"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .overview: return 0
        case .campaigns: return 2
        case .actions: return 1
        }
    }
}

// MARK: - Military Section Bar

struct MilitarySectionBar: View {
    @Binding var selectedSection: MilitarySection
    let accessLevel: AccessLevel
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MilitarySection.allCases, id: \.self) { section in
                let hasAccess = accessLevel.effectiveLevel(for: .military) >= section.requiredLevel

                MilitarySectionButton(
                    section: section,
                    isSelected: selectedSection == section,
                    isLocked: !hasAccess
                ) {
                    if hasAccess {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                        }
                    }
                }
            }
        }
    }
}

struct MilitarySectionButton: View {
    let section: MilitarySection
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: section.icon)
                        .font(.system(size: 16))

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                            .offset(x: 8, y: 8)
                    }
                }

                Text(section.title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.3)
            }
            .foregroundColor(
                isLocked ? theme.inkLight :
                    (isSelected ? .white : theme.inkGray)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isLocked ? theme.parchmentDark.opacity(0.5) :
                    (isSelected ? Color(hex: "#8B0000") : theme.parchmentDark)
            )
            .cornerRadius(6)
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

// MARK: - Overview Section

struct MilitaryOverviewSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private let actionService = MilitaryActionService.shared

    private var activeCampaigns: [MilitaryCampaign] {
        actionService.getActiveCampaigns(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            MilitaryPositionBanner(game: game)

            // Military Situation Card
            MilitarySituationCard(game: game)

            // Quick Stats
            MilitaryQuickStats(game: game, campaignCount: activeCampaigns.count)

            // Theater Readiness
            TheaterReadinessCard(game: game)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct MilitaryPositionBanner: View {
    let game: Game
    @Environment(\.theme) var theme

    private var isInTrack: Bool {
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        return playerTrack == .militaryPolitical
    }

    private var isTopLeadership: Bool {
        game.currentPositionIndex >= 7
    }

    private var hasAuthority: Bool {
        isInTrack || isTopLeadership
    }

    private var categoryTitle: String {
        guard hasAuthority else { return "Observer Only" }
        let position = game.currentPositionIndex
        switch position {
        case 0...1: return "Political Instructor"
        case 2...3: return "Unit Commissar"
        case 4...5: return "Division Command"
        case 6: return "Theater Command"
        default: return "CMC Authority"
        }
    }

    private var plaEquivalent: String {
        guard hasAuthority else { return "No Military Authority" }
        return MilitaryActionCategory.allCases
            .filter { game.currentPositionIndex >= $0.minimumPositionIndex }
            .last?.plaEquivalent ?? "Political Instructor"
    }

    private var headerText: String {
        hasAuthority ? "YOUR MILITARY RANK" : "ACCESS STATUS"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerText)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Text(categoryTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(hasAuthority ? theme.inkBlack : theme.inkLight)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if hasAuthority {
                    Text("POSITION \(game.currentPositionIndex)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#8B0000"))
                } else {
                    Text("VIEW ONLY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.inkLight)
                }

                Text(plaEquivalent)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkGray)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasAuthority ? Color(hex: "#8B0000").opacity(0.3) : theme.inkLight.opacity(0.3), lineWidth: 1)
        )
    }
}

struct MilitarySituationCard: View {
    let game: Game
    @Environment(\.theme) var theme

    // Simulate readiness as combination of loyalty and stability
    private var effectiveReadiness: Int {
        (game.militaryLoyalty + game.stability) / 2
    }

    private var militaryRating: String {
        let avgScore = (game.militaryLoyalty + game.stability + effectiveReadiness) / 3
        switch avgScore {
        case 70...: return "LOYAL"
        case 50..<70: return "STABLE"
        case 30..<50: return "WAVERING"
        default: return "UNRELIABLE"
        }
    }

    private var ratingColor: String {
        let avgScore = (game.militaryLoyalty + game.stability + effectiveReadiness) / 3
        switch avgScore {
        case 70...: return "#22c55e"
        case 50..<70: return "#3b82f6"
        case 30..<50: return "#f59e0b"
        default: return "#ef4444"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MILITARY SITUATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text(militaryRating)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: ratingColor))
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                MilitaryMetric(label: "Loyalty", value: "\(game.militaryLoyalty)", color: game.militaryLoyalty >= 50 ? .green : .orange)
                MilitaryMetric(label: "Readiness", value: "\(effectiveReadiness)", color: effectiveReadiness >= 50 ? .green : .orange)
                MilitaryMetric(label: "Stability", value: "\(game.stability)", color: game.stability >= 50 ? .green : .orange)
            }

            Divider()

            HStack(spacing: 12) {
                DualCommandIndicator(label: "Party Command", isStrong: game.militaryLoyalty >= 60)
                DualCommandIndicator(label: "Elite Loyalty", isStrong: game.eliteLoyalty >= 60)
                DualCommandIndicator(label: "Discipline", isStrong: game.stability >= 60)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct MilitaryMetric: View {
    let label: String
    let value: String
    let color: Color
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(theme.inkGray)
        }
    }
}

struct DualCommandIndicator: View {
    let label: String
    let isStrong: Bool
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isStrong ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.inkGray)

                Text(isStrong ? "Strong" : "Weak")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)
            }
        }
    }
}

struct MilitaryQuickStats: View {
    let game: Game
    let campaignCount: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            MilitaryQuickStatBox(label: "Active Campaigns", value: "\(campaignCount)", icon: "flag.fill")
            MilitaryQuickStatBox(label: "Int'l Standing", value: "\(game.internationalStanding)", icon: "globe")
            MilitaryQuickStatBox(label: "Your Standing", value: "\(game.standing)", icon: "star.fill")
        }
    }
}

struct MilitaryQuickStatBox: View {
    let label: String
    let value: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#8B0000"))

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.inkBlack)

            Text(label)
                .font(.system(size: 8))
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct TheaterReadinessCard: View {
    let game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THEATER READINESS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(TheaterCommand.allCases.prefix(5), id: \.self) { theater in
                TheaterRow(theater: theater, readiness: theaterReadiness(theater))
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private func theaterReadiness(_ theater: TheaterCommand) -> Int {
        // Base readiness on military stats with some variation per theater
        let effectiveReadiness = (game.militaryLoyalty + game.stability) / 2
        let base = (game.militaryLoyalty + effectiveReadiness) / 2
        switch theater {
        case .eastern: return min(100, max(0, base + 5))  // Taiwan focus
        case .southern: return min(100, max(0, base))     // South China Sea
        case .western: return min(100, max(0, base - 10)) // Remote
        case .northern: return min(100, max(0, base - 5)) // Russia border
        case .central: return min(100, max(0, base + 10)) // Capital defense
        }
    }
}

struct TheaterRow: View {
    let theater: TheaterCommand
    let readiness: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: theaterIcon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#8B0000"))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 0) {
                Text(theater.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkBlack)

                Text(theater.strategicFocus)
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkGray)
            }

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.parchment)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(readinessColor)
                        .frame(width: geo.size.width * CGFloat(readiness) / 100, height: 8)
                }
            }
            .frame(width: 60, height: 8)

            Text("\(readiness)%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(readinessColor)
                .frame(width: 35, alignment: .trailing)
        }
    }

    private var theaterIcon: String {
        switch theater {
        case .eastern: return "ferry.fill"
        case .southern: return "water.waves"
        case .western: return "mountain.2.fill"
        case .northern: return "snowflake"
        case .central: return "building.columns.fill"
        }
    }

    private var readinessColor: Color {
        switch readiness {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - Campaigns Section

struct MilitaryCampaignsSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private let actionService = MilitaryActionService.shared

    private var activeCampaigns: [MilitaryCampaign] {
        actionService.getActiveCampaigns(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            MilitaryPositionBanner(game: game)

            // Active campaigns
            if !activeCampaigns.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#8B0000"))

                        Text("ACTIVE CAMPAIGNS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(theme.inkBlack)

                        Spacer()

                        Text("\(activeCampaigns.count)/1")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.inkGray)
                    }

                    ForEach(activeCampaigns) { campaign in
                        CampaignCard(campaign: campaign, currentTurn: game.turnNumber)
                    }
                }
            } else {
                EmptyCampaignsView()
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct CampaignCard: View {
    let campaign: MilitaryCampaign
    let currentTurn: Int
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    private var turnsRemaining: Int {
        max(0, campaign.completionTurn - currentTurn)
    }

    private var progressPercent: Double {
        let totalTurns = campaign.completionTurn - campaign.initiatedTurn
        guard totalTurns > 0 else { return 0 }
        return Double(campaign.progress) / Double(totalTurns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.name)
                        .font(theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundColor(theme.inkBlack)

                    if let theater = campaign.targetTheater {
                        Text(theater.displayName)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)
                    }
                }

                Spacer()

                // Phase badge
                Text(campaign.phase.displayName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(phaseColor)
                    .cornerRadius(4)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                    Spacer()
                    Text("\(Int(progressPercent * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.inkBlack)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.parchmentDark)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#8B0000"))
                            .frame(width: geo.size.width * progressPercent, height: 6)
                    }
                }
                .frame(height: 6)
            }

            // Expanded details
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    CampaignDetailRow(label: "Turns Remaining", value: "\(turnsRemaining)")
                    CampaignDetailRow(label: "Success Chance", value: "\(campaign.successChance)%")
                    CampaignDetailRow(label: "Current Phase", value: campaign.phase.displayName)
                }
            }

            // Tap to expand
            HStack {
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)
                Spacer()
            }
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private var phaseColor: Color {
        switch campaign.phase {
        case .mobilization: return .purple
        case .investigation: return .orange
        case .operations: return .blue
        case .consolidation: return .green
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct CampaignDetailRow: View {
    let label: String
    let value: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(theme.inkGray)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.inkBlack)
        }
    }
}

struct EmptyCampaignsView: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text("No Active Campaigns")
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            Text("Launch ideological campaigns or purges from the Actions tab to begin political operations.")
                .font(theme.tagFont)
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Actions Section

struct MilitaryActionsSection: View {
    @Bindable var game: Game
    @Environment(\.modelContext) var modelContext
    @Environment(\.theme) var theme

    private let actionService = MilitaryActionService.shared

    // Track authority check
    private var hasTrackAuthority: Bool {
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInTrack = playerTrack == .militaryPolitical
        let isTopLeadership = game.currentPositionIndex >= 7
        return isInTrack || isTopLeadership
    }

    private var availableActions: [MilitaryAction] {
        MilitaryAction.actions(forPosition: game.currentPositionIndex)
    }

    private var lockedActions: [MilitaryAction] {
        MilitaryAction.allActions.filter { $0.minimumPositionIndex > game.currentPositionIndex }
    }

    private var cooldowns: MilitaryCooldownTracker {
        actionService.getMilitaryCooldowns(for: game)
    }

    private var actionsByCategory: [(category: MilitaryActionCategory, actions: [MilitaryAction])] {
        var result: [(MilitaryActionCategory, [MilitaryAction])] = []
        for category in MilitaryActionCategory.allCases {
            let categoryActions = availableActions.filter { $0.category == category }
            if !categoryActions.isEmpty {
                result.append((category, categoryActions))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            MilitaryPositionBanner(game: game)

            // Check track authority before showing actions
            if !hasTrackAuthority {
                NoTrackAuthorityView(
                    bureauName: "Military-Political Administration",
                    requiredTrack: "Military-Political",
                    accentColor: Color(hex: "#8B0000")
                )
            } else if availableActions.isEmpty {
                NoMilitaryActionsView(nextUnlock: lockedActions.first)
            } else {
                // Available actions by category
                ForEach(actionsByCategory, id: \.category) { category, actions in
                    MilitaryActionCategorySection(
                        category: category,
                        actions: actions,
                        cooldowns: cooldowns,
                        currentTurn: game.turnNumber,
                        game: game,
                        modelContext: modelContext
                    )
                }

                // Locked actions preview
                if !lockedActions.isEmpty {
                    LockedMilitaryActionsPreview(actions: lockedActions, currentPosition: game.currentPositionIndex)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct MilitaryActionCategorySection: View {
    let category: MilitaryActionCategory
    let actions: [MilitaryAction]
    let cooldowns: MilitaryCooldownTracker
    let currentTurn: Int
    @Bindable var game: Game
    let modelContext: ModelContext
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 8) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 0) {
                    Text(category.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    Text(category.plaEquivalent)
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                Text("Pos \(category.minimumPositionIndex)+")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.inkGray)
            }

            // Actions
            ForEach(actions, id: \.id) { action in
                MilitaryActionCard(
                    action: action,
                    isOnCooldown: cooldowns.isOnCooldown(actionId: action.id, currentTurn: currentTurn),
                    cooldownRemaining: cooldowns.turnsRemaining(actionId: action.id, currentTurn: currentTurn),
                    validation: MilitaryActionService.shared.validateAction(action, targetOfficer: nil, for: game),
                    game: game,
                    modelContext: modelContext
                )
            }
        }
    }

    private var categoryColor: Color {
        Color(hex: category.color)
    }
}

struct MilitaryActionCard: View {
    let action: MilitaryAction
    let isOnCooldown: Bool
    let cooldownRemaining: Int
    let validation: MilitaryActionService.ValidationResult
    @Bindable var game: Game
    let modelContext: ModelContext
    @Environment(\.theme) var theme
    @State private var isExpanded = false
    @State private var showingConfirmation = false
    @State private var lastResult: MilitaryActionService.ExecutionResult?

    private let actionService = MilitaryActionService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: action.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(isOnCooldown ? theme.inkLight : Color(hex: "#8B0000"))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name)
                        .font(theme.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(isOnCooldown ? theme.inkLight : theme.inkBlack)

                    Text(action.description)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                        .lineLimit(1)
                }

                Spacer()

                if isOnCooldown {
                    Text("\(cooldownRemaining)T")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.inkLight)
                        .cornerRadius(4)
                } else {
                    Text("\(validation.successChance)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(successColor)
                }
            }

            if isExpanded {
                Divider()

                Text(action.detailedDescription)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)

                HStack(spacing: 12) {
                    ActionDetailTag(label: "Cooldown", value: "\(action.cooldownTurns)T")
                    ActionDetailTag(label: "Risk", value: action.riskLevel.displayName)
                    if action.requiresCommitteeApproval {
                        ActionDetailTag(label: "Approval", value: "Required", isWarning: true)
                    }
                }

                if !isOnCooldown && validation.canExecute {
                    Button(action: { showingConfirmation = true }) {
                        HStack {
                            Spacer()
                            Text(action.actionVerb.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(Color(hex: "#8B0000"))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                // Inline result display
                if let result = lastResult {
                    Text(result.description)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(result.succeeded ? .green : .red)
                        .padding(.top, 4)
                }
            }

            // Tap to expand
            HStack {
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)
                Spacer()
            }
        }
        .padding(12)
        .background(isOnCooldown ? theme.parchmentDark.opacity(0.5) : theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
        .opacity(isOnCooldown ? 0.7 : 1.0)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .sheet(isPresented: $showingConfirmation) {
            ActionConfirmationSheet(
                title: action.name,
                description: action.detailedDescription,
                successChance: validation.successChance,
                riskLevel: action.riskLevel.displayName,
                riskColor: riskColor(action.riskLevel),
                accentColor: Color(hex: "#8B0000"),
                actionVerb: action.actionVerb,
                onConfirm: {
                    executeAction()
                    showingConfirmation = false
                },
                onCancel: {
                    showingConfirmation = false
                }
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.clear)
        }
    }

    private func executeAction() {
        lastResult = actionService.executeAction(
            action,
            targetOfficer: nil,
            targetUnit: nil,
            targetTheater: nil,
            for: game,
            modelContext: modelContext
        )
    }

    private func riskColor(_ risk: MilitaryRiskLevel) -> Color {
        switch risk {
        case .routine: return .green
        case .moderate: return .blue
        case .significant: return .orange
        case .major: return .red
        case .extreme: return .purple
        }
    }

    private var successColor: Color {
        switch validation.successChance {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
}

struct ActionDetailTag: View {
    let label: String
    let value: String
    var isWarning: Bool = false
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(theme.inkGray)

            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isWarning ? .orange : theme.inkBlack)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.parchmentDark)
        .cornerRadius(4)
    }
}

struct NoMilitaryActionsView: View {
    let nextUnlock: MilitaryAction?
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text("No Actions Available")
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            if let next = nextUnlock {
                Text("Reach Position \(next.minimumPositionIndex) to unlock \"\(next.name)\"")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(12)
    }
}

struct LockedMilitaryActionsPreview: View {
    let actions: [MilitaryAction]
    let currentPosition: Int
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)

                Text("LOCKED ACTIONS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkLight)
            }

            ForEach(actions.prefix(3), id: \.id) { action in
                HStack(spacing: 12) {
                    Image(systemName: action.iconName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.name)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkLight)

                        Text("Unlocks at Position \(action.minimumPositionIndex)")
                            .font(.system(size: 8))
                            .foregroundColor(theme.inkLight.opacity(0.7))
                    }

                    Spacer()
                }
            }

            if actions.count > 3 {
                Text("+ \(actions.count - 3) more locked actions")
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight.opacity(0.7))
            }
        }
        .padding(12)
        .background(theme.parchmentDark.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Campaign Phase Extension

extension CampaignPhase {
    var displayName: String {
        switch self {
        case .mobilization: return "Mobilization"
        case .investigation: return "Investigation"
        case .operations: return "Operations"
        case .consolidation: return "Consolidation"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}
