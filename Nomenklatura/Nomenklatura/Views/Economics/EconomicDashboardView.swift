//
//  EconomicDashboardView.swift
//  Nomenklatura
//
//  Gosplan Command Center - comprehensive economic intelligence dashboard
//

import SwiftUI
import SwiftData

struct EconomicDashboardView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedView: EconomicView = .overview

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(spacing: 0) {
            // View selector
            EconomicViewSelector(selectedView: $selectedView, accessLevel: accessLevel)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)

            // Content
            ScrollView {
                switch selectedView {
                case .overview:
                    NationalStatsView(game: game)
                case .trends:
                    EconomicTrendsView(game: game)
                case .fiveYearPlan:
                    FiveYearPlanView(game: game)
                case .trade:
                    TradeFlowView(game: game)
                case .regional:
                    RegionalEconomicsView(game: game)
                case .budget:
                    BudgetView(game: game)
                }
            }
        }
    }
}

// MARK: - Economic View Types

enum EconomicView: String, CaseIterable {
    case overview
    case trends
    case fiveYearPlan
    case trade
    case regional
    case budget

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .trends: return "Trends"
        case .fiveYearPlan: return "Plan"
        case .trade: return "Trade"
        case .regional: return "Regions"
        case .budget: return "Budget"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .fiveYearPlan: return "target"
        case .trade: return "arrow.left.arrow.right"
        case .regional: return "map.fill"
        case .budget: return "banknote.fill"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .overview, .fiveYearPlan: return 0  // Public
        case .trends: return 2                    // Position 2+
        case .trade: return 4                     // Position 4+
        case .regional, .budget: return 6         // Position 6+
        }
    }
}

// MARK: - Economic View Selector

struct EconomicViewSelector: View {
    @Binding var selectedView: EconomicView
    let accessLevel: AccessLevel
    @Environment(\.theme) var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EconomicView.allCases, id: \.self) { view in
                    let hasAccess = accessLevel.effectiveLevel(for: .economic) >= view.requiredLevel

                    EconomicViewButton(
                        view: view,
                        isSelected: selectedView == view,
                        isLocked: !hasAccess
                    ) {
                        if hasAccess {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedView = view
                            }
                        }
                    }
                }
            }
        }
    }
}

struct EconomicViewButton: View {
    let view: EconomicView
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: view.icon)
                    .font(.system(size: 12))

                Text(view.title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                }
            }
            .foregroundColor(
                isLocked ? theme.inkLight :
                    (isSelected ? .white : theme.inkGray)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isLocked ? theme.parchmentDark.opacity(0.5) :
                    (isSelected ? theme.sovietRed : theme.parchmentDark)
            )
            .cornerRadius(6)
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

// MARK: - National Stats View

struct NationalStatsView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 20) {
            // Key indicators
            VStack(alignment: .leading, spacing: 12) {
                Text("KEY INDICATORS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(
                        title: "Treasury",
                        value: game.treasury,
                        icon: "banknote.fill",
                        trend: nil
                    )
                    StatCard(
                        title: "Industry",
                        value: game.industrialOutput,
                        icon: "hammer.fill",
                        trend: nil
                    )
                    StatCard(
                        title: "Food Supply",
                        value: game.foodSupply,
                        icon: "leaf.fill",
                        trend: nil
                    )
                    StatCard(
                        title: "Intl. Standing",
                        value: game.internationalStanding,
                        icon: "globe",
                        trend: nil
                    )
                }
            }

            Divider()
                .background(theme.borderTan)

            // Stability indicators
            VStack(alignment: .leading, spacing: 12) {
                Text("STABILITY INDICATORS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(
                        title: "Stability",
                        value: game.stability,
                        icon: "building.2.fill",
                        trend: nil
                    )
                    StatCard(
                        title: "Popular Support",
                        value: game.popularSupport,
                        icon: "person.3.fill",
                        trend: nil
                    )
                    StatCard(
                        title: "Military Loyalty",
                        value: game.militaryLoyalty,
                        icon: "shield.fill",
                        trend: nil
                    )
                    StatCard(
                        title: "Elite Loyalty",
                        value: game.eliteLoyalty,
                        icon: "star.fill",
                        trend: nil
                    )
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let trend: Int?
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 8) {
            // Icon and value
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentGold)

                Spacer()

                Text("\(value)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(valueColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(theme.parchmentDark)
                        .frame(height: 6)

                    Rectangle()
                        .fill(valueColor)
                        .frame(width: geometry.size.width * CGFloat(value) / 100, height: 6)
                }
                .cornerRadius(3)
            }
            .frame(height: 6)

            // Title and trend
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(theme.inkGray)

                Spacer()

                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                        Text("\(abs(trend))")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(trend > 0 ? .green : .red)
                }
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

    private var valueColor: Color {
        switch value {
        case 70...: return .green
        case 40..<70: return theme.accentGold
        case 20..<40: return .orange
        default: return .red
        }
    }
}

// MARK: - Five Year Plan View

struct FiveYearPlanView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Current plan status
            VStack(alignment: .leading, spacing: 12) {
                Text("FIVE-YEAR PLAN PROGRESS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                // Overall progress
                VStack(spacing: 8) {
                    HStack {
                        Text("Overall Progress")
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)

                        Spacer()

                        Text("\(planProgress)%")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.accentGold)
                    }

                    ProgressView(value: Double(planProgress) / 100)
                        .tint(theme.sovietRed)
                }
                .padding()
                .background(theme.parchmentDark)
                .cornerRadius(8)

                // Sector targets
                ForEach(sectors, id: \.name) { sector in
                    SectorProgressRow(sector: sector)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }

    private var planProgress: Int {
        // Calculate based on economic indicators
        (game.industrialOutput + game.foodSupply + game.treasury) / 3
    }

    private var sectors: [PlanSector] {
        [
            PlanSector(name: "Heavy Industry", target: 100, current: game.industrialOutput, icon: "gearshape.fill"),
            PlanSector(name: "Agriculture", target: 100, current: game.foodSupply, icon: "leaf.fill"),
            PlanSector(name: "Energy", target: 100, current: (game.industrialOutput + game.treasury) / 2, icon: "bolt.fill"),
            PlanSector(name: "Infrastructure", target: 100, current: game.stability, icon: "road.lanes")
        ]
    }
}

struct PlanSector {
    let name: String
    let target: Int
    let current: Int
    let icon: String
}

struct SectorProgressRow: View {
    let sector: PlanSector
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sector.icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accentGold)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(sector.name)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkBlack)

                    Spacer()

                    Text("\(sector.current)/\(sector.target)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.inkGray)
                }

                ProgressView(value: Double(sector.current) / Double(sector.target))
                    .tint(progressColor)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private var progressColor: Color {
        let ratio = Double(sector.current) / Double(sector.target)
        if ratio >= 0.9 { return .green }
        if ratio >= 0.7 { return theme.accentGold }
        if ratio >= 0.5 { return .orange }
        return .red
    }
}

// MARK: - Trade Flow View

struct TradeFlowView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AccessGatedView(
                requirement: .economicDetails,
                accessLevel: accessLevel
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TRADE FLOWS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    Text("Trade flow visualization would appear here showing imports, exports, and trade balance with each nation.")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkBlack)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.parchmentDark)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

// MARK: - Regional Economics View

struct RegionalEconomicsView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AccessGatedView(
                requirement: .regionalEconomics,
                accessLevel: accessLevel
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("REGIONAL ECONOMICS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    Text("Regional economic heat map would appear here showing production, resources, and labor allocation across the PSRA's 7 domestic zones.")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkBlack)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.parchmentDark)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

// MARK: - Budget View

struct BudgetView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AccessGatedView(
                requirement: .budgetDetails,
                accessLevel: accessLevel
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("BUDGET ALLOCATION")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    Text("State budget breakdown would appear here showing military vs civilian spending, ministry allocations, and emergency reserves.")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkBlack)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.parchmentDark)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

// MARK: - Economic Trends View

struct EconomicTrendsView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AccessGatedView(
                requirement: .economicTrends,
                accessLevel: accessLevel
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    // GDP Trend
                    TrendChartSection(
                        title: "NATIONAL PRODUCT INDEX",
                        data: game.gdpHistory,
                        currentValue: game.gdpIndex,
                        baselineValue: 100,
                        color: theme.accentGold,
                        format: .index,
                        turnNumber: game.turnNumber
                    )

                    Divider()
                        .background(theme.borderTan)

                    // Inflation Trend
                    TrendChartSection(
                        title: "INFLATION RATE",
                        data: game.inflationHistory,
                        currentValue: game.inflationRate,
                        baselineValue: 10,
                        color: .orange,
                        format: .percentage,
                        turnNumber: game.turnNumber
                    )

                    Divider()
                        .background(theme.borderTan)

                    // Unemployment Trend
                    TrendChartSection(
                        title: "UNEMPLOYMENT RATE",
                        data: game.unemploymentHistory,
                        currentValue: game.unemploymentRate,
                        baselineValue: 5,
                        color: theme.sovietRed,
                        format: .percentage,
                        turnNumber: game.turnNumber
                    )

                    // Economic Status Summary
                    EconomicStatusSummary(game: game)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

// MARK: - Trend Chart Section

struct TrendChartSection: View {
    let title: String
    let data: [Int]
    let currentValue: Int
    let baselineValue: Int
    let color: Color
    let format: TrendFormat
    var turnNumber: Int = 1
    @Environment(\.theme) var theme

    enum TrendFormat {
        case index
        case percentage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                // Current value and trend
                HStack(spacing: 8) {
                    if let trend = calculateTrend() {
                        HStack(spacing: 2) {
                            Image(systemName: trend > 0 ? "arrow.up" : (trend < 0 ? "arrow.down" : "minus"))
                                .font(.system(size: 10))
                            Text(format == .percentage ? "\(abs(trend))%" : "\(abs(trend))")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(trendColor(trend))
                    }

                    Text(formatValue(currentValue))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                }
            }

            // Chart
            if data.count >= 2 {
                SimpleLineChart(
                    data: data,
                    baselineValue: baselineValue,
                    color: color
                )
                .frame(height: 80)
            } else {
                // Not enough data
                HStack {
                    Spacer()
                    Text("Insufficient data for trend analysis")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkLight)
                    Spacer()
                }
                .frame(height: 80)
                .background(theme.parchmentDark)
                .cornerRadius(8)
            }

            // Turn labels
            if data.count >= 2 {
                HStack {
                    Text("Turn \(max(1, turnNumber - data.count + 1))")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkLight)
                    Spacer()
                    Text("Turn \(turnNumber)")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkLight)
                }
            }
        }
    }

    private func formatValue(_ value: Int) -> String {
        switch format {
        case .index: return "\(value)"
        case .percentage: return "\(value)%"
        }
    }

    private func calculateTrend() -> Int? {
        guard data.count >= 2 else { return nil }
        let previous = data[data.count - 2]
        return currentValue - previous
    }

    private func trendColor(_ trend: Int) -> Color {
        // For inflation/unemployment, down is good; for GDP, up is good
        if format == .percentage {
            return trend < 0 ? .green : (trend > 0 ? .red : theme.inkGray)
        } else {
            return trend > 0 ? .green : (trend < 0 ? .red : theme.inkGray)
        }
    }
}

// MARK: - Simple Line Chart

struct SimpleLineChart: View {
    let data: [Int]
    let baselineValue: Int
    let color: Color
    @Environment(\.theme) var theme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.parchmentDark)

                if data.count >= 2 {
                    // Baseline reference line
                    let normalizedBaseline = normalizedValue(baselineValue)
                    Path { path in
                        let y = geometry.size.height * (1 - normalizedBaseline)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(theme.inkLight.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Data line
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(data.count - 1)

                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalized = normalizedValue(value)
                            let y = geometry.size.height * (1 - normalized)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Data points
                    ForEach(data.indices, id: \.self) { index in
                        let stepX = geometry.size.width / CGFloat(data.count - 1)
                        let x = CGFloat(index) * stepX
                        let normalized = normalizedValue(data[index])
                        let y = geometry.size.height * (1 - normalized)

                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }

    private func normalizedValue(_ value: Int) -> CGFloat {
        let minVal = CGFloat(data.min() ?? 0)
        let maxVal = CGFloat(data.max() ?? 100)

        // Add padding
        let range = max(maxVal - minVal, 20)
        let paddedMin = minVal - range * 0.1
        let paddedMax = maxVal + range * 0.1
        let paddedRange = paddedMax - paddedMin

        guard paddedRange > 0 else { return 0.5 }
        return (CGFloat(value) - paddedMin) / paddedRange
    }
}

// MARK: - Economic Status Summary

struct EconomicStatusSummary: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ECONOMIC ASSESSMENT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            VStack(spacing: 8) {
                // Health score
                HStack {
                    Text("Economic Health")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkBlack)

                    Spacer()

                    Text(healthStatus)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(healthColor)
                }

                // Recession status
                if game.isInRecession {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("RECESSION: National Product declining for 3+ quarters")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }

                // Crisis status
                if game.hasEconomicCrisis {
                    if let crisis = game.currentEconomicCrisisType {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text("CRISIS: \(crisis.displayName)")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    }
                }

                // Economic system
                HStack {
                    Text("Economic System")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkGray)

                    Spacer()

                    Text(game.currentEconomicSystem.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.inkBlack)
                }

                // Five-Year Plan phase
                HStack {
                    Text("Five-Year Plan")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkGray)

                    Spacer()

                    Text("Plan \(game.currentFiveYearPlan), Year \(game.fiveYearPlanYear)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.inkBlack)
                }
            }
            .padding()
            .background(theme.parchmentDark)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
    }

    private var healthStatus: String {
        let score = game.economicHealthScore
        switch score {
        case 80...: return "Flourishing"
        case 60..<80: return "Satisfactory"
        case 40..<60: return "Mixed"
        case 20..<40: return "Struggling"
        default: return "Critical"
        }
    }

    private var healthColor: Color {
        let score = game.economicHealthScore
        switch score {
        case 80...: return .green
        case 60..<80: return theme.accentGold
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "cold_war")

    EconomicDashboardView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
