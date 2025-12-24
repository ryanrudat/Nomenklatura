//
//  LedgerView.swift
//  Nomenklatura
//
//  The Ledger - National stats dashboard
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
    var onSecurityTap: (() -> Void)? = nil
    var onEconomicTap: (() -> Void)? = nil
    var onMilitaryTap: (() -> Void)? = nil
    var onPartyTap: (() -> Void)? = nil
    var onMinistryTap: (() -> Void)? = nil
    @Environment(\.theme) var theme
    @State private var selectedStatKey: String?

    // Calculate overall state health
    private var overallHealth: OverallHealth {
        let criticalStats = [game.stability, game.popularSupport, game.foodSupply]
        let criticalCount = criticalStats.filter { $0 < 30 }.count

        if criticalCount >= 2 { return .crisis }
        if criticalCount == 1 || criticalStats.contains(where: { $0 < 20 }) { return .danger }

        let avg = (game.stability + game.popularSupport + game.militaryLoyalty +
                   game.eliteLoyalty + game.treasury + game.industrialOutput +
                   game.foodSupply + game.internationalStanding) / 8
        if avg >= 65 { return .stable }
        if avg >= 45 { return .uncertain }
        return .danger
    }

    var body: some View {
        ZStack {
            // Background
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with optional world and congress buttons
                ScreenHeader(
                    title: "The Ledger",
                    subtitle: "State of the Nation",
                    showWorldButton: onWorldTap != nil,
                    onWorldTap: onWorldTap,
                    showCongressButton: onCongressTap != nil,
                    onCongressTap: onCongressTap
                )

                // Overall status banner
                OverallStatusBanner(health: overallHealth)

                // Scrollable stats
                ScrollView {
                    VStack(spacing: 20) {
                        // Stability section - CRITICAL
                        StatCategoryCard(
                            icon: "shield.fill",
                            title: "STABILITY",
                            subtitle: "Order & Control",
                            accentColor: theme.sovietRed,
                            stats: [
                                StatItem(key: "stability", label: "Political Stability", value: game.stability, icon: "building.columns.fill"),
                                StatItem(key: "popularSupport", label: "Popular Support", value: game.popularSupport, icon: "person.3.fill")
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
                                StatItem(key: "militaryLoyalty", label: "Military Loyalty", value: game.militaryLoyalty, icon: "shield.checkered"),
                                StatItem(key: "eliteLoyalty", label: "Party Elite Loyalty", value: game.eliteLoyalty, icon: "person.crop.rectangle.stack.fill")
                            ],
                            selectedStatKey: $selectedStatKey
                        )

                        // Resources section
                        StatCategoryCard(
                            icon: "cube.box.fill",
                            title: "RESOURCES",
                            subtitle: "Economic Foundation",
                            accentColor: Color(hex: "4A7C59"),
                            stats: [
                                StatItem(key: "treasury", label: "Treasury", value: game.treasury, icon: "rublesign.circle.fill"),
                                StatItem(key: "industrialOutput", label: "Industrial Output", value: game.industrialOutput, icon: "gearshape.2.fill"),
                                StatItem(key: "foodSupply", label: "Food Supply", value: game.foodSupply, icon: "leaf.fill")
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
                                StatItem(key: "internationalStanding", label: "International Standing", value: game.internationalStanding, icon: "flag.fill")
                            ],
                            selectedStatKey: $selectedStatKey
                        )

                        // Security Services quick access
                        if let onSecurityTap = onSecurityTap {
                            SecurityQuickAccessCard(game: game, onTap: onSecurityTap)
                        }

                        // Economic Planning quick access
                        if let onEconomicTap = onEconomicTap {
                            EconomicQuickAccessCard(game: game, onTap: onEconomicTap)
                        }

                        // Military-Political quick access
                        if let onMilitaryTap = onMilitaryTap {
                            MilitaryQuickAccessCard(game: game, onTap: onMilitaryTap)
                        }

                        // Party Apparatus quick access
                        if let onPartyTap = onPartyTap {
                            PartyQuickAccessCard(game: game, onTap: onPartyTap)
                        }

                        // State Ministry quick access
                        if let onMinistryTap = onMinistryTap {
                            MinistryQuickAccessCard(game: game, onTap: onMinistryTap)
                        }

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
                // Fallback for unknown stat keys - dismiss immediately
                Text("Unknown stat")
                    .onAppear { selectedStatKey = nil }
            }
        }
    }
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
        case .stable: return "The state apparatus functions smoothly"
        case .uncertain: return "Tensions simmer beneath the surface"
        case .danger: return "The situation demands immediate attention"
        case .crisis: return "Multiple crises threaten state collapse"
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
                Text("STATE STATUS: \(health.label)")
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

    private var categoryHealth: StatLevel {
        let avg = stats.map(\.value).reduce(0, +) / max(stats.count, 1)
        switch avg {
        case 70...: return .high
        case 40..<70: return .medium
        default: return .low
        }
    }

    private var hasCritical: Bool {
        stats.contains { $0.value < 30 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header
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

                // Category health indicator
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

            // Stats
            VStack(spacing: 0) {
                ForEach(stats) { stat in
                    EnhancedStatRow(
                        stat: stat,
                        accentColor: accentColor,
                        onInfoTap: {
                            selectedStatKey = stat.key
                        }
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
                // Icon
                Image(systemName: stat.icon)
                    .font(.system(size: 14))
                    .foregroundColor(accentColor.opacity(0.7))
                    .frame(width: 20)

                // Label
                Text(stat.label)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkBlack)

                Spacer()

                // Status badge
                if let status = statusText {
                    Text(status)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(barColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(barColor.opacity(0.15))
                }

                // Value
                Text("\(stat.value)")
                    .font(theme.statFont)
                    .fontWeight(.bold)
                    .foregroundColor(barColor)
                    .frame(width: 32, alignment: .trailing)

                // Info button
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(theme.inkLight)
                }
                .buttonStyle(.plain)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "E8E4D9"))

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geometry.size.width * CGFloat(stat.value) / 100)

                    // Danger zone marker at 30
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

// MARK: - Stat Section Container

struct StatSection<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 15)
    }
}

// MARK: - Stat Row View

struct StatRowView: View {
    let label: String
    let value: Int
    @Environment(\.theme) var theme

    private var statLevel: StatLevel {
        switch value {
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

    private var warningIcon: String? {
        if value < 30 { return "⚠️" }
        if value >= 70 { return "✓" }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkBlack)
                .frame(minWidth: 140, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "E8E4D9"))

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geometry.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 8)

            HStack(spacing: 4) {
                Text("\(value)")
                    .font(theme.statFont)
                    .foregroundColor(theme.inkBlack)
                    .frame(width: 30, alignment: .trailing)

                if let icon = warningIcon {
                    Text(icon)
                        .font(.system(size: 12))
                }
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: "E8E4D9"))
                .frame(height: 1)
        }
    }
}

// MARK: - Security Quick Access Card

struct SecurityQuickAccessCard: View {
    let game: Game
    let onTap: () -> Void
    @Environment(\.theme) var theme

    private var summary: SecuritySituationSummary {
        SecurityBriefingService.shared.generateSituationSummary(for: game)
    }

    private var isPlayerBureau: Bool {
        game.playerExpandedTrack == .securityServices
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 20))
                        .foregroundColor(theme.sovietRed)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SECURITY SERVICES")
                            .font(theme.labelFont)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(theme.schemeText)

                        Text("State Protection Bureau")
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkLight)
                    }

                    Spacer()

                    // Security status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(summary.overallSecurityRating.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)

                Divider()
                    .background(theme.borderTan)

                // Quick stats row
                HStack(spacing: 0) {
                    SecurityStatBox(
                        label: "INVESTIGATIONS",
                        value: "\(summary.activeInvestigations)",
                        icon: "magnifyingglass"
                    )

                    Divider()
                        .frame(height: 40)

                    SecurityStatBox(
                        label: "DETENTIONS",
                        value: "\(summary.activeDetentions)",
                        icon: "lock.fill"
                    )

                    Divider()
                        .frame(height: 40)

                    SecurityStatBox(
                        label: "PENDING TRIALS",
                        value: "\(summary.pendingTrials)",
                        icon: "building.columns.fill"
                    )
                }
                .padding(.vertical, 8)
            }
            .background(theme.schemeCard)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPlayerBureau ? theme.accentGold : theme.sovietRed.opacity(0.3),
                            lineWidth: isPlayerBureau ? 2 : 1)
            )
            .cornerRadius(8)
            .overlay(alignment: .topLeading) {
                if isPlayerBureau {
                    Text("YOUR BUREAU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.accentGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.parchmentDark)
                        .cornerRadius(4)
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isPlayerBureau ? 1.0 : 0.7)
    }

    private var statusColor: Color {
        switch summary.overallSecurityRating {
        case .stable: return .statHigh
        case .watchful: return Color(hex: "689F38")
        case .concerned: return .statMedium
        case .alert: return Color(hex: "F57C00")
        case .critical: return .statLow
        }
    }
}

struct SecurityStatBox: View {
    let label: String
    let value: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.schemeText)
            }
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkLight)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Economic Quick Access Card

struct EconomicQuickAccessCard: View {
    let game: Game
    let onTap: () -> Void
    @Environment(\.theme) var theme

    private var activeProjects: Int {
        EconomicActionService.shared.getActiveProjects(for: game).count
    }

    private var economicRating: String {
        let avgScore = (game.industrialOutput + game.foodSupply + min(100, max(0, game.treasury))) / 3
        switch avgScore {
        case 70...: return "EXCELLENT"
        case 50..<70: return "STABLE"
        case 30..<50: return "CONCERNING"
        default: return "CRITICAL"
        }
    }

    private var isPlayerBureau: Bool {
        game.playerExpandedTrack == .economicPlanning
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.accentGold)

                    Text("GOSPLAN")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.schemeText)

                    Spacer()

                    Text(economicRating)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ratingColor)
                        .cornerRadius(4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)

                Divider()
                    .background(theme.borderTan)

                // Quick stats row
                HStack(spacing: 0) {
                    EconomicStatBox(
                        label: "INDUSTRIAL",
                        value: "\(game.industrialOutput)%",
                        icon: "building.2.fill"
                    )

                    Divider()
                        .frame(height: 40)

                    EconomicStatBox(
                        label: "FOOD SUPPLY",
                        value: "\(game.foodSupply)%",
                        icon: "leaf.fill"
                    )

                    Divider()
                        .frame(height: 40)

                    EconomicStatBox(
                        label: "PROJECTS",
                        value: "\(activeProjects)/3",
                        icon: "hammer.fill"
                    )
                }
                .padding(.vertical, 8)
            }
            .background(theme.schemeCard)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPlayerBureau ? theme.accentGold : theme.accentGold.opacity(0.3),
                            lineWidth: isPlayerBureau ? 2 : 1)
            )
            .cornerRadius(8)
            .overlay(alignment: .topLeading) {
                if isPlayerBureau {
                    Text("YOUR BUREAU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.accentGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.parchmentDark)
                        .cornerRadius(4)
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isPlayerBureau ? 1.0 : 0.7)
    }

    private var ratingColor: Color {
        let avgScore = (game.industrialOutput + game.foodSupply + min(100, max(0, game.treasury))) / 3
        switch avgScore {
        case 70...: return .statHigh
        case 50..<70: return .blue
        case 30..<50: return .statMedium
        default: return .statLow
        }
    }
}

struct EconomicStatBox: View {
    let label: String
    let value: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.schemeText)
            }
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkLight)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Military Quick Access Card

struct MilitaryQuickAccessCard: View {
    let game: Game
    let onTap: () -> Void
    @Environment(\.theme) var theme

    private var activeCampaigns: Int {
        MilitaryActionService.shared.getActiveCampaigns(for: game).count
    }

    private var militaryRating: String {
        let avgScore = (game.militaryLoyalty + game.stability) / 2
        switch avgScore {
        case 70...: return "LOYAL"
        case 50..<70: return "STABLE"
        case 30..<50: return "WAVERING"
        default: return "UNRELIABLE"
        }
    }

    private var isPlayerBureau: Bool {
        game.playerExpandedTrack == .militaryPolitical
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#8B0000"))

                    Text("POLITICAL WORK")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.schemeText)

                    Spacer()

                    Text(militaryRating)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(ratingColor)
                        .cornerRadius(4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)

                Divider()
                    .background(theme.borderTan)

                // Quick stats row
                HStack(spacing: 0) {
                    MilitaryStatBox(
                        label: "LOYALTY",
                        value: "\(game.militaryLoyalty)%",
                        icon: "shield.checkered"
                    )

                    Divider()
                        .frame(height: 40)

                    MilitaryStatBox(
                        label: "STABILITY",
                        value: "\(game.stability)%",
                        icon: "building.columns.fill"
                    )

                    Divider()
                        .frame(height: 40)

                    MilitaryStatBox(
                        label: "CAMPAIGNS",
                        value: "\(activeCampaigns)/1",
                        icon: "flag.fill"
                    )
                }
                .padding(.vertical, 8)
            }
            .background(theme.schemeCard)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPlayerBureau ? theme.accentGold : Color(hex: "#8B0000").opacity(0.3),
                            lineWidth: isPlayerBureau ? 2 : 1)
            )
            .cornerRadius(8)
            .overlay(alignment: .topLeading) {
                if isPlayerBureau {
                    Text("YOUR BUREAU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.accentGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.parchmentDark)
                        .cornerRadius(4)
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isPlayerBureau ? 1.0 : 0.7)
    }

    private var ratingColor: Color {
        let avgScore = (game.militaryLoyalty + game.stability) / 2
        switch avgScore {
        case 70...: return .statHigh
        case 50..<70: return .blue
        case 30..<50: return .statMedium
        default: return .statLow
        }
    }
}

struct MilitaryStatBox: View {
    let label: String
    let value: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.schemeText)
            }
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkLight)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Party Quick Access Card

struct PartyQuickAccessCard: View {
    let game: Game
    let onTap: () -> Void
    @Environment(\.theme) var theme

    private var activeCampaigns: Int {
        PartyActionService.shared.getActiveCampaigns(for: game).count
    }

    private var partyRating: String {
        let avgScore = (game.eliteLoyalty + game.stability + game.popularSupport) / 3
        switch avgScore {
        case 70...: return "STRONG"
        case 50..<70: return "STABLE"
        case 30..<50: return "WAVERING"
        default: return "CRISIS"
        }
    }

    private var isPlayerBureau: Bool {
        game.playerExpandedTrack == .partyApparatus
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#CC0000"))

                    Text("PARTY APPARATUS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.schemeText)

                    Spacer()

                    Text(partyRating)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(partyRatingColor)
                        .cornerRadius(4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)

                Divider()
                    .background(theme.borderTan)

                // Quick stats row
                HStack(spacing: 0) {
                    LedgerPartyStatBox(
                        label: "ELITE LOYALTY",
                        value: "\(game.eliteLoyalty)%",
                        icon: "person.crop.rectangle.stack"
                    )

                    Divider()
                        .frame(height: 40)

                    LedgerPartyStatBox(
                        label: "CAMPAIGNS",
                        value: "\(activeCampaigns)",
                        icon: "flag.fill"
                    )

                    Divider()
                        .frame(height: 40)

                    LedgerPartyStatBox(
                        label: "NETWORK",
                        value: "\(game.network)",
                        icon: "person.3.fill"
                    )
                }
                .padding(.vertical, 8)
            }
            .background(theme.schemeCard)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPlayerBureau ? theme.accentGold : Color(hex: "#CC0000").opacity(0.3),
                            lineWidth: isPlayerBureau ? 2 : 1)
            )
            .cornerRadius(8)
            .overlay(alignment: .topLeading) {
                if isPlayerBureau {
                    Text("YOUR BUREAU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.accentGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.parchmentDark)
                        .cornerRadius(4)
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isPlayerBureau ? 1.0 : 0.7)
    }

    private var partyRatingColor: Color {
        let avgScore = (game.eliteLoyalty + game.stability + game.popularSupport) / 3
        switch avgScore {
        case 70...: return .statHigh
        case 50..<70: return .blue
        case 30..<50: return .statMedium
        default: return .statLow
        }
    }
}

struct LedgerPartyStatBox: View {
    let label: String
    let value: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.schemeText)
            }
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkLight)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ministry Quick Access Card

struct MinistryQuickAccessCard: View {
    let game: Game
    let onTap: () -> Void
    @Environment(\.theme) var theme

    private var activeProjects: Int {
        StateMinistryActionService.shared.getActiveProjects(for: game).count
    }

    private var stateRating: String {
        let avgScore = (game.stability + game.treasury + game.industrialOutput) / 3
        switch avgScore {
        case 70...: return "PROSPEROUS"
        case 50..<70: return "STABLE"
        case 30..<50: return "STRAINED"
        default: return "CRISIS"
        }
    }

    private var isPlayerBureau: Bool {
        game.playerExpandedTrack == .stateMinistry
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#2563EB"))

                    Text("STATE MINISTRY")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.schemeText)

                    Spacer()

                    Text(stateRating)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(stateRatingColor)
                        .cornerRadius(4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)

                Divider()
                    .background(theme.borderTan)

                // Stats row
                HStack(spacing: 0) {
                    LedgerMinistryStatBox(
                        label: "TREASURY",
                        value: "\(game.treasury)%",
                        icon: "banknote.fill"
                    )

                    Divider()
                        .frame(height: 40)

                    LedgerMinistryStatBox(
                        label: "PROJECTS",
                        value: "\(activeProjects)",
                        icon: "building.2.fill"
                    )

                    Divider()
                        .frame(height: 40)

                    LedgerMinistryStatBox(
                        label: "INDUSTRY",
                        value: "\(game.industrialOutput)",
                        icon: "gearshape.2.fill"
                    )
                }
                .padding(.vertical, 8)
            }
            .background(theme.schemeCard)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPlayerBureau ? theme.accentGold : Color(hex: "#2563EB").opacity(0.3),
                            lineWidth: isPlayerBureau ? 2 : 1)
            )
            .cornerRadius(8)
            .overlay(alignment: .topLeading) {
                if isPlayerBureau {
                    Text("YOUR BUREAU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.accentGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.parchmentDark)
                        .cornerRadius(4)
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(isPlayerBureau ? 1.0 : 0.7)
    }

    private var stateRatingColor: Color {
        let avgScore = (game.stability + game.treasury + game.industrialOutput) / 3
        switch avgScore {
        case 70...: return .statHigh
        case 50..<70: return .blue
        case 30..<50: return .statMedium
        default: return .statLow
        }
    }
}

struct LedgerMinistryStatBox: View {
    let label: String
    let value: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.schemeText)
            }
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkLight)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.stability = 55
    game.popularSupport = 35
    game.militaryLoyalty = 70
    game.eliteLoyalty = 60
    game.treasury = 45
    game.industrialOutput = 50
    game.foodSupply = 30
    game.internationalStanding = 50
    container.mainContext.insert(game)

    return LedgerView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
