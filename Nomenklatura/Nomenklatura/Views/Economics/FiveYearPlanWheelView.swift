//
//  FiveYearPlanWheelView.swift
//  Nomenklatura
//
//  Radial chart showing Five-Year Plan progress across sectors.
//  Central visualization for the Economic Command Center.
//
//  Post-redesign (Unit 5): the wheel visualizes **real progress toward
//  player-set sector targets**, not a cosmetic mapping of current stats.
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

    private var targets: FiveYearPlanTargets { game.planTargets }

    var body: some View {
        VStack(spacing: 16) {
            headerSection

            if !targets.isConfigured {
                unconfiguredPlaceholder
            } else {
                // Wheel chart
                ZStack {
                    Circle()
                        .stroke(theme.parchmentDark, lineWidth: 30)

                    ForEach(sectors.indices, id: \.self) { index in
                        sectorArc(for: sectors[index], at: index, total: sectors.count)
                    }

                    centerContent
                }
                .frame(width: 220, height: 220)
                .padding(.vertical, 10)

                legendSection
            }
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
            Text("FIVE-YEAR PLAN \(targets.cycleNumber)")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundColor(theme.sovietRed)

            if targets.isConfigured {
                Text("Turn \(game.turnNumber) of \(targets.endTurn) — Cycle \(targets.cycleNumber)")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkGray)
            } else {
                Text("Targets not yet set — Gosplan awaiting instructions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.sovietRed)
            }
        }
    }

    // MARK: - Unconfigured Placeholder

    private var unconfiguredPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundColor(theme.inkLight)

            Text("Set Plan Targets to Begin")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(theme.inkBlack)

            Text("Pick production goals for Heavy Industry, Agriculture, Defense, Welfare, Infrastructure and Energy. Your economic actions will build progress toward those targets over the next \(FiveYearPlanTargets.cycleLength) turns.")
                .font(.system(size: 11))
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 24)
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

            // Progress arc (cap at 100% for the visible arc length)
            let cappedProgress = min(100, progress)
            Circle()
                .trim(
                    from: CGFloat(index) / CGFloat(total),
                    to: CGFloat(index) / CGFloat(total) + (CGFloat(index + 1) / CGFloat(total) - CGFloat(index) / CGFloat(total) - 0.01) * (CGFloat(cappedProgress) / 100)
                )
                .stroke(
                    progressColor(for: progress),
                    style: StrokeStyle(lineWidth: 28, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))

            sectorIcon(for: sector, startAngle: startAngle, endAngle: endAngle)
        }
    }

    private func sectorIcon(for sector: PlanSectorData, startAngle: Angle, endAngle: Angle) -> some View {
        let midAngle = Angle(degrees: (startAngle.degrees + endAngle.degrees) / 2)
        let radius: CGFloat = 140

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

            Text("\(targets.sectorsMetCount)/\(max(1, targets.sectorsWithTargets)) met")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(theme.inkLight)

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
        guard targets.isConfigured else { return 0 }
        return targets.averageProgressPercent
    }

    private var statusLabel: String {
        guard targets.isConfigured else { return "UNSET" }
        let progress = overallProgress
        let expected = targets.expectedProgressPercent(currentTurn: game.turnNumber)

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

            VStack(alignment: .leading, spacing: 0) {
                Text(sector.name)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkBlack)
                    .lineLimit(1)

                if sector.target > 0 {
                    Text("\(sector.current)/\(sector.target)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(theme.inkLight)
                }
            }

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

    /// Color coding: green (on track/ahead), yellow (slightly behind), orange
    /// (falling behind), red (failing).
    private func progressColor(for progress: Int) -> Color {
        let expected = targets.isConfigured
            ? targets.expectedProgressPercent(currentTurn: game.turnNumber)
            : 0
        if progress >= expected + 5 {
            return .green
        } else if progress >= expected - 10 {
            return theme.accentGold
        } else if progress >= expected - 25 {
            return .orange
        } else {
            return .red
        }
    }

    /// Build the six plan-sector display rows from the live target blob.
    private func generateSectorData() -> [PlanSectorData] {
        PlanSector.allCases.map { sector in
            let tgt = targets.target(for: sector)
            let cur = targets.progress(for: sector)
            let realProgress = targets.progressPercent(for: sector)

            // Propaganda variant: puffs up real progress by ~15 points.
            let propagandaProgress = min(100, realProgress + 15)

            return PlanSectorData(
                id: sector.rawValue,
                name: sector.displayName,
                icon: sector.iconName,
                target: tgt,
                current: cur,
                realProgress: realProgress,
                propagandaProgress: propagandaProgress
            )
        }
    }
}

// MARK: - Plan Sector Data

struct PlanSectorData: Identifiable {
    let id: String
    let name: String
    let icon: String
    let target: Int           // Target delta (e.g. +15)
    let current: Int          // Accumulated progress
    let realProgress: Int     // 0-100+ percent
    let propagandaProgress: Int
}

// MARK: - Compact Plan Summary

/// Smaller version for overview tabs.
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
                    .trim(from: 0, to: CGFloat(min(100, progress)) / 100)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(progress)%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(progressColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("FIVE-YEAR PLAN \(game.planTargets.cycleNumber)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.sovietRed)

                if game.planTargets.isConfigured {
                    Text("Turn \(game.turnNumber) of \(game.planTargets.endTurn)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkGray)
                } else {
                    Text("Targets unset")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.sovietRed)
                }

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
        guard game.planTargets.isConfigured else { return 0 }
        if showPropaganda {
            return min(100, game.planTargets.averageProgressPercent + 15)
        }
        return game.planTargets.averageProgressPercent
    }

    private var statusText: String {
        guard game.planTargets.isConfigured else { return "Awaiting targets" }
        let expected = game.planTargets.expectedProgressPercent(currentTurn: game.turnNumber)
        if progress >= expected + 5 {
            return "Ahead of Schedule"
        } else if progress >= expected - 10 {
            return "On Track"
        } else {
            return showPropaganda ? "Intensifying Efforts" : "Behind Schedule"
        }
    }

    private var progressColor: Color {
        let expected = game.planTargets.isConfigured
            ? game.planTargets.expectedProgressPercent(currentTurn: game.turnNumber)
            : 0
        if progress >= expected + 5 { return .green }
        if progress >= expected - 10 { return theme.accentGold }
        if progress >= expected - 25 { return .orange }
        return .red
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
