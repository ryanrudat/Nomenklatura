//
//  LedgerView.swift
//  Nomenklatura
//
//  The Ledger — Political Situation Room.
//  Focused on political health, threat surfacing, and bureau access.
//  Economic stats (treasury / industrial / food) live in the Economy tab.
//

import SwiftUI
import SwiftData

// Extension to make String work with .sheet(item:)
extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct LedgerView: View {
    @Bindable var game: Game
    var onWorldTap: (() -> Void)? = nil
    var onCongressTap: (() -> Void)? = nil
    var onTabSwitch: ((NavTab) -> Void)? = nil   // Threat links jump to another tab
    @Environment(\.theme) var theme
    @State private var selectedStatKey: String?
    @State private var operationsBureau: ExpandedCareerTrack?

    // Political-only overall health (no economy)
    private var overallHealth: OverallHealth {
        let criticalStats = [game.stability, game.popularSupport, game.militaryLoyalty, game.eliteLoyalty]
        let criticalCount = criticalStats.filter { $0 < 30 }.count

        if criticalCount >= 2 { return .crisis }
        if criticalCount == 1 || criticalStats.contains(where: { $0 < 20 }) { return .danger }

        let avg = (game.stability + game.popularSupport + game.militaryLoyalty +
                   game.eliteLoyalty + game.internationalStanding) / 5
        if avg >= 65 { return .stable }
        if avg >= 45 { return .uncertain }
        return .danger
    }

    private var threats: [PoliticalThreat] {
        PoliticalThreat.activeThreats(for: game)
    }

    var body: some View {
        ZStack {
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                ScreenHeader(
                    title: "The Ledger",
                    subtitle: "Political Situation Room",
                    showWorldButton: onWorldTap != nil,
                    onWorldTap: onWorldTap,
                    showCongressButton: onCongressTap != nil,
                    onCongressTap: onCongressTap
                )

                OverallStatusBanner(health: overallHealth)

                ScrollView {
                    VStack(spacing: 20) {
                        // Threats section — only visible when threats exist
                        if !threats.isEmpty {
                            ThreatsSection(
                                threats: threats,
                                onTabSwitch: onTabSwitch,
                                onBureauTap: { bureau in operationsBureau = bureau }
                            )
                        }

                        // Stability section — CRITICAL
                        StatCategoryCard(
                            icon: "shield.fill",
                            title: "STABILITY",
                            subtitle: "Order & Control",
                            accentColor: theme.sovietRed,
                            stats: [
                                StatItem(key: "stability", label: "Political Stability", value: game.stability, icon: "building.columns.fill", history: game.stabilityHistory),
                                StatItem(key: "popularSupport", label: "Popular Support", value: game.popularSupport, icon: "person.3.fill", history: game.popularSupportHistory)
                            ],
                            selectedStatKey: $selectedStatKey
                        )

                        // Power Centers section
                        StatCategoryCard(
                            icon: "star.circle.fill",
                            title: "POWER CENTERS",
                            subtitle: "Institutional Loyalty",
                            accentColor: theme.accentGold,
                            stats: [
                                StatItem(key: "militaryLoyalty", label: "Military Loyalty", value: game.militaryLoyalty, icon: "shield.checkered", history: game.militaryLoyaltyHistory),
                                StatItem(key: "eliteLoyalty", label: "Party Elite Loyalty", value: game.eliteLoyalty, icon: "person.crop.rectangle.stack.fill", history: game.eliteLoyaltyHistory)
                            ],
                            selectedStatKey: $selectedStatKey
                        )

                        // External section
                        StatCategoryCard(
                            icon: "globe.europe.africa.fill",
                            title: "EXTERNAL",
                            subtitle: "Foreign Relations",
                            accentColor: Color(hex: "4682B4"),
                            stats: [
                                StatItem(key: "internationalStanding", label: "International Standing", value: game.internationalStanding, icon: "flag.fill", history: game.internationalStandingHistory)
                            ],
                            selectedStatKey: $selectedStatKey
                        )

                        // Bureau Hub — tap a bureau to open its Operations view
                        BureauHubSection(
                            game: game,
                            onBureauTap: { bureau in
                                operationsBureau = bureau
                            }
                        )

                        Spacer(minLength: 100)
                    }
                    .padding(15)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(item: $selectedStatKey) { key in
            if let description = StatDescriptions.description(for: key) {
                StatInfoSheet(stat: description)
            } else {
                Text("Unknown stat")
                    .onAppear { selectedStatKey = nil }
            }
        }
        .sheet(item: $operationsBureau) { bureau in
            BureauOperationsView(game: game, bureau: bureau)
        }
    }
}

// Needed for .sheet(item:) on ExpandedCareerTrack
extension ExpandedCareerTrack: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Overall Health

enum OverallHealth {
    case stable, uncertain, danger, crisis

    var label: String {
        switch self {
        case .stable: return "STABLE"
        case .uncertain: return "UNCERTAIN"
        case .danger: return "DANGER"
        case .crisis: return "CRISIS"
        }
    }

    var color: Color {
        switch self {
        case .stable: return .statHigh
        case .uncertain: return .statMedium
        case .danger: return .statLow
        case .crisis: return Color(hex: "8B0000")
        }
    }

    var icon: String {
        switch self {
        case .stable: return "checkmark.shield.fill"
        case .uncertain: return "exclamationmark.triangle"
        case .danger: return "exclamationmark.triangle.fill"
        case .crisis: return "flame.fill"
        }
    }

    var message: String {
        switch self {
        case .stable: return "The political situation is under control"
        case .uncertain: return "Tensions simmer beneath the surface"
        case .danger: return "The situation demands immediate attention"
        case .crisis: return "Multiple political crises threaten your position"
        }
    }
}

// MARK: - Overall Status Banner

struct OverallStatusBanner: View {
    let health: OverallHealth
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: health.icon)
                .font(.system(size: 20))
                .foregroundColor(health.color)

            VStack(alignment: .leading, spacing: 2) {
                Text("POLITICAL STATUS: \(health.label)")
                    .font(theme.labelFont)
                    .fontWeight(.bold)
                    .tracking(1)
                    .foregroundColor(health.color)

                Text(health.message)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
            }

            Spacer()
        }
        .padding(12)
        .background(health.color.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(health.color)
                .frame(width: 4),
            alignment: .leading
        )
    }
}

// MARK: - Stat Item

struct StatItem: Identifiable {
    let id = UUID()
    let key: String
    let label: String
    let value: Int
    let icon: String
    let history: [Int]

    /// Delta vs previous recorded value; nil when no history exists yet.
    var delta: Int? {
        guard history.count >= 2 else { return nil }
        let prior = history[history.count - 2]
        return value - prior
    }
}

// MARK: - Stat Category Card

struct StatCategoryCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let stats: [StatItem]
    @Binding var selectedStatKey: String?
    @Environment(\.theme) var theme

    private var hasCritical: Bool {
        stats.contains { $0.value < 30 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(theme.headerFont)
                        .tracking(2)
                        .foregroundColor(theme.inkBlack)

                    Text(subtitle)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                if hasCritical {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("CRITICAL")
                            .font(theme.tagFont)
                            .tracking(1)
                    }
                    .foregroundColor(.statLow)
                }
            }
            .padding(12)
            .background(accentColor.opacity(0.08))

            VStack(spacing: 0) {
                ForEach(stats) { stat in
                    EnhancedStatRow(
                        stat: stat,
                        accentColor: accentColor,
                        onInfoTap: { selectedStatKey = stat.key }
                    )
                }
            }
            .background(theme.parchmentDark)
        }
        .overlay(
            Rectangle()
                .stroke(hasCritical ? Color.statLow.opacity(0.5) : theme.borderTan, lineWidth: hasCritical ? 2 : 1)
        )
    }
}

// MARK: - Enhanced Stat Row

struct EnhancedStatRow: View {
    let stat: StatItem
    let accentColor: Color
    let onInfoTap: () -> Void
    @Environment(\.theme) var theme

    private var statLevel: StatLevel {
        switch stat.value {
        case 70...: return .high
        case 40..<70: return .medium
        default: return .low
        }
    }

    private var barColor: Color {
        switch statLevel {
        case .high: return .statHigh
        case .medium: return .statMedium
        case .low: return .statLow
        }
    }

    private var statusText: String? {
        if stat.value < 20 { return "CRITICAL" }
        if stat.value < 30 { return "LOW" }
        if stat.value >= 80 { return "STRONG" }
        return nil
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: stat.icon)
                    .font(.system(size: 14))
                    .foregroundColor(accentColor.opacity(0.7))
                    .frame(width: 20)

                Text(stat.label)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkBlack)

                Spacer()

                // Trend arrow + delta badge
                if let delta = stat.delta {
                    TrendBadge(delta: delta)
                }

                if let status = statusText {
                    Text(status)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(barColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(barColor.opacity(0.15))
                }

                Text("\(stat.value)")
                    .font(theme.statFont)
                    .fontWeight(.bold)
                    .foregroundColor(barColor)
                    .frame(width: 32, alignment: .trailing)

                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(theme.inkLight)
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "E8E4D9"))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geometry.size.width * CGFloat(stat.value) / 100)

                    Rectangle()
                        .fill(Color.statLow.opacity(0.3))
                        .frame(width: 1)
                        .offset(x: geometry.size.width * 0.3)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.borderTan.opacity(0.5))
                .frame(height: 1)
        }
    }
}

// MARK: - Trend Badge

struct TrendBadge: View {
    let delta: Int

    private var color: Color {
        if delta > 0 { return .statHigh }
        if delta < 0 { return .statLow }
        return .gray
    }

    private var icon: String {
        if delta > 0 { return "arrow.up" }
        if delta < 0 { return "arrow.down" }
        return "minus"
    }

    private var display: String {
        if delta == 0 { return "±0" }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(display)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .foregroundColor(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .cornerRadius(3)
    }
}

// MARK: - Threats Section

struct PoliticalThreat: Identifiable {
    let id = UUID()
    let severity: Severity
    let headline: String
    let action: String
    let destination: Destination

    enum Severity {
        case warning, critical

        var color: Color {
            switch self {
            case .warning: return .statMedium
            case .critical: return .statLow
            }
        }

        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle"
            case .critical: return "exclamationmark.octagon.fill"
            }
        }
    }

    enum Destination {
        case tab(NavTab)
        case bureau(ExpandedCareerTrack)
    }

    static func activeThreats(for game: Game) -> [PoliticalThreat] {
        var list: [PoliticalThreat] = []

        if game.stability < 40 {
            list.append(.init(
                severity: game.stability < 25 ? .critical : .warning,
                headline: "Unstable — \(game.stability)% stability",
                action: "Review Desk decisions",
                destination: .tab(.desk)
            ))
        }

        if game.popularSupport < 30 {
            list.append(.init(
                severity: game.popularSupport < 20 ? .critical : .warning,
                headline: "Unpopular — \(game.popularSupport)% support",
                action: "Propaganda Bureau directives",
                destination: .bureau(.partyApparatus)
            ))
        }

        if game.treasury < 20 {
            list.append(.init(
                severity: .critical,
                headline: "Bankrupt — treasury \(game.treasury)",
                action: "Visit the State Bank",
                destination: .tab(.economy)
            ))
        }

        if game.militaryLoyalty < 40 {
            list.append(.init(
                severity: game.militaryLoyalty < 25 ? .critical : .warning,
                headline: "Military disloyalty — \(game.militaryLoyalty)%",
                action: "Security Bureau",
                destination: .bureau(.securityServices)
            ))
        }

        if game.eliteLoyalty < 35 {
            list.append(.init(
                severity: game.eliteLoyalty < 20 ? .critical : .warning,
                headline: "Elite discontent — \(game.eliteLoyalty)%",
                action: "Party Apparatus",
                destination: .bureau(.partyApparatus)
            ))
        }

        if game.foodSupply < 30 {
            list.append(.init(
                severity: game.foodSupply < 20 ? .critical : .warning,
                headline: "Food shortage — supply \(game.foodSupply)%",
                action: "Open Economy tab",
                destination: .tab(.economy)
            ))
        }

        if game.internationalStanding < 25 {
            list.append(.init(
                severity: .warning,
                headline: "Pariah state — standing \(game.internationalStanding)%",
                action: "Review foreign relations",
                destination: .tab(.dossier)
            ))
        }

        return list
    }
}

struct ThreatsSection: View {
    let threats: [PoliticalThreat]
    let onTabSwitch: ((NavTab) -> Void)?
    let onBureauTap: (ExpandedCareerTrack) -> Void
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.statLow)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("THREATS")
                        .font(theme.headerFont)
                        .tracking(2)
                        .foregroundColor(theme.inkBlack)

                    Text("Active danger zones")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                Text("\(threats.count)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.statLow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.statLow.opacity(0.15))
                    .cornerRadius(4)
            }
            .padding(12)
            .background(Color.statLow.opacity(0.08))

            VStack(spacing: 0) {
                ForEach(threats) { threat in
                    ThreatRow(threat: threat, onTabSwitch: onTabSwitch, onBureauTap: onBureauTap)
                }
            }
            .background(theme.parchmentDark)
        }
        .overlay(
            Rectangle()
                .stroke(Color.statLow.opacity(0.5), lineWidth: 2)
        )
    }
}

struct ThreatRow: View {
    let threat: PoliticalThreat
    let onTabSwitch: ((NavTab) -> Void)?
    let onBureauTap: (ExpandedCareerTrack) -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 10) {
                Image(systemName: threat.severity.icon)
                    .font(.system(size: 14))
                    .foregroundColor(threat.severity.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(threat.headline)
                        .font(theme.bodyFontSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.inkBlack)
                        .multilineTextAlignment(.leading)
                    Text(threat.action)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.inkLight)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.borderTan.opacity(0.5))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func handleTap() {
        switch threat.destination {
        case .tab(let tab):
            onTabSwitch?(tab)
        case .bureau(let bureau):
            onBureauTap(bureau)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.stability = 35
    game.popularSupport = 25
    game.militaryLoyalty = 70
    game.eliteLoyalty = 60
    game.treasury = 15
    game.industrialOutput = 50
    game.foodSupply = 30
    game.internationalStanding = 50
    container.mainContext.insert(game)

    return LedgerView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
