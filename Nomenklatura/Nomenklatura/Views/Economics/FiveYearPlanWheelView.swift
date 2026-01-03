//
//  FiveYearPlanWheelView.swift
//  Nomenklatura
//
//  Radial chart showing Five-Year Plan progress across sectors
//  Central visualization for the Economic Command Center
//

import SwiftUI
import SwiftData

// MARK: - Five Year Plan Wheel View

struct FiveYearPlanWheelView: View {
    @Bindable var game: Game
    let showPropaganda: Bool
    @Environment(\.theme) var theme

    private var sectors: [PlanSectorData] {
        generateSectorData()
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection

            // Wheel chart
            ZStack {
                // Background ring
                Circle()
                    .stroke(theme.parchmentDark, lineWidth: 30)

                // Sector arcs
                ForEach(sectors.indices, id: \.self) { index in
                    sectorArc(for: sectors[index], at: index, total: sectors.count)
                }

                // Center content
                centerContent
            }
            .frame(width: 220, height: 220)
            .padding(.vertical, 10)

            // Legend
            legendSection
        }
        .padding()
        .background(theme.parchment)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("FIVE-YEAR PLAN \(game.currentFiveYearPlan)")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundColor(theme.sovietRed)

            Text("Year \(game.fiveYearPlanYear) of 5")
                .font(.system(size: 11))
                .foregroundColor(theme.inkGray)
        }
    }

    // MARK: - Sector Arc

    private func sectorArc(for sector: PlanSectorData, at index: Int, total: Int) -> some View {
        let startAngle = Angle(degrees: Double(index) / Double(total) * 360 - 90)
        let endAngle = Angle(degrees: Double(index + 1) / Double(total) * 360 - 90)
        let progress = showPropaganda ? sector.propagandaProgress : sector.realProgress

        return ZStack {
            // Track (background)
            Circle()
                .trim(from: CGFloat(index) / CGFloat(total), to: CGFloat(index + 1) / CGFloat(total) - 0.01)
                .stroke(theme.parchmentDark, lineWidth: 28)
                .rotationEffect(.degrees(-90))

            // Progress arc
            Circle()
                .trim(
                    from: CGFloat(index) / CGFloat(total),
                    to: CGFloat(index) / CGFloat(total) + (CGFloat(index + 1) / CGFloat(total) - CGFloat(index) / CGFloat(total) - 0.01) * (CGFloat(progress) / 100)
                )
                .stroke(
                    progressColor(for: progress),
                    style: StrokeStyle(lineWidth: 28, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))

            // Sector icon
            sectorIcon(for: sector, startAngle: startAngle, endAngle: endAngle)
        }
    }

    private func sectorIcon(for sector: PlanSectorData, startAngle: Angle, endAngle: Angle) -> some View {
        let midAngle = Angle(degrees: (startAngle.degrees + endAngle.degrees) / 2)
        let radius: CGFloat = 140  // Distance from center for icons

        return Image(systemName: sector.icon)
            .font(.system(size: 14))
            .foregroundColor(theme.inkGray)
            .offset(
                x: cos(midAngle.radians) * radius,
                y: sin(midAngle.radians) * radius
            )
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 4) {
            Text("\(overallProgress)%")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(progressColor(for: overallProgress))

            Text(statusLabel)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)

            if !showPropaganda && hasDivergence {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                    Text("DIVERGENT")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.orange)
                .padding(.top, 2)
            }
        }
    }

    private var overallProgress: Int {
        let source = showPropaganda ? sectors.map(\.propagandaProgress) : sectors.map(\.realProgress)
        guard !source.isEmpty else { return 0 }
        return source.reduce(0, +) / source.count
    }

    private var statusLabel: String {
        let progress = overallProgress
        let expected = game.fiveYearPlanYear * 20  // 20% per year

        if progress >= expected + 10 {
            return "AHEAD OF\nSCHEDULE"
        } else if progress >= expected - 10 {
            return "ON\nTRACK"
        } else {
            return showPropaganda ? "INTENSIFYING\nEFFORTS" : "BEHIND\nSCHEDULE"
        }
    }

    private var hasDivergence: Bool {
        let propagandaAvg = sectors.map(\.propagandaProgress).reduce(0, +) / max(1, sectors.count)
        let realAvg = sectors.map(\.realProgress).reduce(0, +) / max(1, sectors.count)
        return abs(propagandaAvg - realAvg) > 10
    }

    // MARK: - Legend

    private var legendSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(sectors) { sector in
                legendItem(for: sector)
            }
        }
    }

    private func legendItem(for sector: PlanSectorData) -> some View {
        let progress = showPropaganda ? sector.propagandaProgress : sector.realProgress

        return HStack(spacing: 6) {
            Circle()
                .fill(progressColor(for: progress))
                .frame(width: 8, height: 8)

            Text(sector.name)
                .font(.system(size: 9))
                .foregroundColor(theme.inkBlack)
                .lineLimit(1)

            Spacer()

            Text("\(progress)%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(progressColor(for: progress))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(4)
    }

    // MARK: - Helpers

    private func progressColor(for progress: Int) -> Color {
        switch progress {
        case 80...: return .green
        case 60..<80: return theme.accentGold
        case 40..<60: return .orange
        default: return .red
        }
    }

    private func generateSectorData() -> [PlanSectorData] {
        let propaganda = EconomicPropagandaService.shared.generatePropagandaReport(for: game)

        return [
            PlanSectorData(
                id: "industry",
                name: "Heavy Industry",
                icon: "gearshape.fill",
                realProgress: min(100, game.industrialOutput),
                propagandaProgress: min(100, propaganda.industrialOutput)
            ),
            PlanSectorData(
                id: "agriculture",
                name: "Agriculture",
                icon: "leaf.fill",
                realProgress: min(100, game.foodSupply),
                propagandaProgress: min(100, propaganda.foodSupply)
            ),
            PlanSectorData(
                id: "energy",
                name: "Energy",
                icon: "bolt.fill",
                realProgress: min(100, (game.industrialOutput + game.treasury) / 2),
                propagandaProgress: min(100, (propaganda.industrialOutput + 60) / 2)
            ),
            PlanSectorData(
                id: "infrastructure",
                name: "Infrastructure",
                icon: "road.lanes",
                realProgress: min(100, game.stability),
                propagandaProgress: min(100, max(60, game.stability + 15))
            ),
            PlanSectorData(
                id: "defense",
                name: "Defense",
                icon: "shield.fill",
                realProgress: min(100, game.militaryLoyalty),
                propagandaProgress: min(100, max(70, game.militaryLoyalty + 10))
            ),
            PlanSectorData(
                id: "welfare",
                name: "People's Welfare",
                icon: "person.3.fill",
                realProgress: min(100, game.popularSupport),
                propagandaProgress: min(100, max(65, game.popularSupport + 20))
            )
        ]
    }
}

// MARK: - Plan Sector Data

struct PlanSectorData: Identifiable {
    let id: String
    let name: String
    let icon: String
    let realProgress: Int
    let propagandaProgress: Int
}

// MARK: - Compact Plan Summary

/// Smaller version for overview tabs
struct CompactPlanSummary: View {
    @Bindable var game: Game
    let showPropaganda: Bool
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            // Mini wheel
            ZStack {
                Circle()
                    .stroke(theme.parchmentDark, lineWidth: 8)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: CGFloat(progress) / 100)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(progress)%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(progressColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("FIVE-YEAR PLAN \(game.currentFiveYearPlan)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.sovietRed)

                Text("Year \(game.fiveYearPlanYear) of 5")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkGray)

                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(progressColor)
            }

            Spacer()
        }
        .padding()
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private var progress: Int {
        if showPropaganda {
            return EconomicPropagandaService.shared.generatePropagandaReport(for: game).fiveYearPlanProgress
        }
        return game.planPerformanceScore
    }

    private var statusText: String {
        let expected = game.fiveYearPlanYear * 20
        if progress >= expected + 10 {
            return "Ahead of Schedule"
        } else if progress >= expected - 10 {
            return "On Track"
        } else {
            return showPropaganda ? "Intensifying Efforts" : "Behind Schedule"
        }
    }

    private var progressColor: Color {
        switch progress {
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

    VStack(spacing: 20) {
        FiveYearPlanWheelView(game: game, showPropaganda: true)
        FiveYearPlanWheelView(game: game, showPropaganda: false)
    }
    .padding()
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
