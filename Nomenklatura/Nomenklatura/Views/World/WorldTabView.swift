//
//  WorldTabView.swift
//  Nomenklatura
//
//  Main hub for World tab with sub-navigation to Map, Embassy, and Economics
//

import SwiftUI
import SwiftData

enum WorldSubTab: String, CaseIterable {
    case map
    case embassy
    case economics

    var title: String {
        switch self {
        case .map: return "Map"
        case .embassy: return "Embassy"
        case .economics: return "Economics"
        }
    }

    var icon: String {
        switch self {
        case .map: return "map.fill"
        case .embassy: return "building.columns.fill"
        case .economics: return "chart.bar.fill"
        }
    }

    var description: String {
        switch self {
        case .map: return "Strategic overview of the continent"
        case .embassy: return "Diplomatic intelligence center"
        case .economics: return "Economic command dashboard"
        }
    }
}

struct WorldTabView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedSubTab: WorldSubTab = .map
    @State private var showingBriefing: Bool = false

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        ZStack {
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                WorldHeader(game: game, onBriefingTap: { showingBriefing = true })

                // Sub-tab selector
                WorldSubTabBar(selectedTab: $selectedSubTab)
                    .padding(.horizontal, 15)
                    .padding(.top, 10)

                // Content based on selected sub-tab
                Group {
                    switch selectedSubTab {
                    case .map:
                        SpriteKitMapView(game: game)
                    case .embassy:
                        EmbassyPortalView(game: game)
                    case .economics:
                        EconomicDashboardView(game: game)
                    }
                }
            }
        }
        .sheet(isPresented: $showingBriefing) {
            WorldBriefingSheet(game: game)
        }
    }
}

// MARK: - World Header

struct WorldHeader: View {
    @Bindable var game: Game
    let onBriefingTap: () -> Void
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WORLD AFFAIRS")
                        .font(.system(size: 24, weight: .black))
                        .tracking(3)
                        .foregroundColor(theme.inkBlack)

                    Text(accessLevel.accessDescription)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                // Daily briefing button
                Button(action: onBriefingTap) {
                    VStack(spacing: 2) {
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 20))
                        Text("BRIEFING")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(theme.sovietRed)
                    .padding(8)
                    .background(theme.parchmentDark)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 15)
            .padding(.top, 15)

            // Turn indicator
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text("Turn \(game.turnNumber)")
                    .font(theme.tagFont)
                Spacer()
                Text("Year \(1950 + (game.turnNumber / 4))")
                    .font(theme.tagFont)
            }
            .foregroundColor(theme.inkLight)
            .padding(.horizontal, 15)
            .padding(.bottom, 10)

            Divider()
                .background(theme.borderTan)
        }
    }
}

// MARK: - World Sub-Tab Bar

struct WorldSubTabBar: View {
    @Binding var selectedTab: WorldSubTab
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WorldSubTab.allCases, id: \.self) { tab in
                WorldSubTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }
            }
        }
    }
}

struct WorldSubTabButton: View {
    let tab: WorldSubTab
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 28))

                Text(tab.title.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
            }
            .foregroundColor(isSelected ? .white : theme.inkGray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? theme.sovietRed : theme.parchmentDark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? theme.sovietRed : theme.borderTan, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - World Briefing Sheet

struct WorldBriefingSheet: View {
    @Bindable var game: Game
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme

    private var recentEvents: [WorldEvent] {
        game.recentWorldEvents(turns: 3)
    }

    private var publicEvents: [WorldEvent] {
        recentEvents.filter { !$0.isClassified }
    }

    private var classifiedEvents: [WorldEvent] {
        recentEvents.filter { $0.isClassified }
    }

    private var canViewClassified: Bool {
        game.currentPositionIndex >= 6
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DAILY BRIEFING")
                            .font(.system(size: 20, weight: .black))
                            .tracking(2)
                            .foregroundColor(theme.inkBlack)

                        Text("Turn \(game.turnNumber) - Classified Summary")
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)
                    }

                    Divider()
                        .background(theme.borderTan)

                    // World events section
                    worldEventsSection

                    Divider()
                        .background(theme.borderTan)

                    // Intelligence reports (gated by position)
                    if canViewClassified && !classifiedEvents.isEmpty {
                        intelligenceSection

                        Divider()
                            .background(theme.borderTan)
                    }

                    // Economic summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ECONOMIC INDICATORS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(theme.inkGray)

                        HStack(spacing: 20) {
                            BriefingStat(label: "Treasury", value: game.treasury, icon: "banknote")
                            BriefingStat(label: "Industry", value: game.industrialOutput, icon: "hammer")
                            BriefingStat(label: "Food", value: game.foodSupply, icon: "leaf")
                        }
                    }

                    Divider()
                        .background(theme.borderTan)

                    // International standing
                    VStack(alignment: .leading, spacing: 12) {
                        Text("INTERNATIONAL STANDING")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(theme.inkGray)

                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(theme.accentGold)
                            Text("\(game.internationalStanding)%")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.inkBlack)
                            Spacer()
                            Text(standingDescription)
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)
                        }
                    }
                }
                .padding(20)
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .foregroundColor(theme.sovietRed)
                }
            }
        }
    }

    // MARK: - World Events Section

    @ViewBuilder
    private var worldEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INTERNATIONAL SITUATION")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            if publicEvents.isEmpty {
                Text("No significant developments to report. All foreign stations operating normally.")
                    .font(theme.bodyFont)
                    .foregroundColor(theme.inkBlack)
            } else {
                ForEach(publicEvents.prefix(5)) { event in
                    WorldEventRow(event: event, game: game)
                }
            }
        }
    }

    // MARK: - Intelligence Section

    @ViewBuilder
    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(theme.sovietRed)
                Text("INTELLIGENCE REPORTS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)
            }

            Text("CLASSIFIED - EYES ONLY")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.sovietRed.opacity(0.8))

            ForEach(classifiedEvents.prefix(3)) { event in
                WorldEventRow(event: event, game: game, isClassified: true)
            }
        }
        .padding(12)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.sovietRed.opacity(0.3), lineWidth: 1)
        )
    }

    private var standingDescription: String {
        switch game.internationalStanding {
        case 70...: return "Respected"
        case 50..<70: return "Stable"
        case 30..<50: return "Declining"
        default: return "Isolated"
        }
    }
}

// MARK: - World Event Row

struct WorldEventRow: View {
    let event: WorldEvent
    let game: Game
    var isClassified: Bool = false
    @Environment(\.theme) var theme

    private var countryName: String {
        game.country(withId: event.countryId)?.name ?? "Unknown Nation"
    }

    private var severityColor: Color {
        switch event.severity {
        case .critical: return .red
        case .major: return .orange
        case .significant: return theme.accentGold
        case .moderate: return theme.inkGray
        case .minor: return theme.inkLight
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row with icon, headline, and turn
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: event.eventType.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(severityColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.headline)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isClassified ? theme.sovietRed : theme.inkBlack)
                        .lineLimit(2)

                    Text(countryName.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                // Turn indicator
                Text("T\(event.turnOccurred)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.inkLight)
            }

            // Description
            Text(event.description)
                .font(.system(size: 12))
                .foregroundColor(theme.inkBlack.opacity(0.85))
                .lineSpacing(2)
                .padding(.leading, 28) // Align with headline

            // Severity badge
            HStack {
                Spacer()
                Text(event.severity.displayName.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(severityColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.15))
                    .cornerRadius(3)
            }
            .padding(.leading, 28)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(theme.parchmentDark.opacity(isClassified ? 0.3 : 0.15))
        .cornerRadius(6)
    }
}

struct BriefingStat: View {
    let label: String
    let value: Int
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accentGold)

            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(theme.inkBlack)

            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Access Gated View

/// A view wrapper that gates content based on access level
struct AccessGatedView<Content: View, LockedContent: View>: View {
    let requirement: AccessRequirement
    let accessLevel: AccessLevel
    let content: () -> Content
    let lockedContent: (() -> LockedContent)?

    @Environment(\.theme) var theme

    init(
        requirement: AccessRequirement,
        accessLevel: AccessLevel,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder lockedContent: @escaping () -> LockedContent
    ) {
        self.requirement = requirement
        self.accessLevel = accessLevel
        self.content = content
        self.lockedContent = lockedContent
    }

    var body: some View {
        if requirement.isGranted(for: accessLevel) {
            content()
        } else if requirement.showWhenLocked {
            if let locked = lockedContent {
                locked()
            } else {
                defaultLockedView
            }
        }
        // If !showWhenLocked and not granted, show nothing
    }

    private var defaultLockedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundColor(theme.inkLight)

            Text(requirement.unlockMessage)
                .font(theme.tagFont)
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(8)
    }
}

// Convenience extension for when no custom locked content is needed
extension AccessGatedView where LockedContent == EmptyView {
    init(
        requirement: AccessRequirement,
        accessLevel: AccessLevel,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.requirement = requirement
        self.accessLevel = accessLevel
        self.content = content
        self.lockedContent = nil
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "cold_war")

    WorldTabView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
