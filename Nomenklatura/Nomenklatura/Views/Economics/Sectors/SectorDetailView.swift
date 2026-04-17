//
//  SectorDetailView.swift
//  Nomenklatura
//
//  Sector detail sheet showing current performance metrics, active production
//  focus, and available focus options with trade-off summaries.
//  Soviet 1950s aesthetic: monospaced labels, gold/red accents, cardstock backgrounds.
//

import SwiftUI

struct SectorDetailView: View {
    @Bindable var game: Game
    let sector: EconomicSector
    @Environment(\.theme) var theme

    @State private var pendingForecast: FocusForecast?

    private var performance: SectorPerformance {
        game.sectorPerformance(for: sector)
    }

    private var activeFocusId: String {
        game.sectorFocus(for: sector)
    }

    private var focuses: [SectorFocus] {
        SectorFocus.focuses(for: sector)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                sectorHeader

                // Performance bars
                performanceSection

                // Dependencies
                dependenciesSection

                // Focus options
                focusSection
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(theme.parchment)
        .sheet(item: $pendingForecast) { forecast in
            FocusForecastSheet(
                forecast: forecast,
                onConfirm: { commitFocus(forecast.proposedFocus) },
                onCancel: { /* dismissed; nothing to do */ }
            )
        }
    }

    // MARK: - Header

    private var sectorHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: sector.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(theme.accentGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sector.displayName.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(theme.inkBlack)

                    Text(performance.healthDescription.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(healthColor)
                }

                Spacer()

                // Output badge
                VStack(spacing: 2) {
                    Text("\(performance.actualOutput)")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(healthColor)
                    Text("OUTPUT")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)
                }
            }

            Divider()
                .background(theme.accentGold.opacity(0.5))
        }
    }

    private var healthColor: Color {
        let output = performance.actualOutput
        switch output {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }

    // MARK: - Performance Bars

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SECTOR METRICS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            SectorStatBar(label: "Production", value: performance.productionLevel, theme: theme)
            SectorStatBar(label: "Investment", value: performance.investmentLevel, theme: theme)
            SectorStatBar(label: "Morale", value: performance.workerMorale, theme: theme)
            SectorStatBar(label: "Efficiency", value: performance.efficiency, theme: theme)
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Dependencies

    private var dependenciesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPPLY DEPENDENCIES")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            HStack(spacing: 12) {
                ForEach(sector.dependencies, id: \.self) { dep in
                    let depPerf = game.sectorPerformance(for: dep)
                    HStack(spacing: 6) {
                        Image(systemName: dep.iconName)
                            .font(.system(size: 11))
                            .foregroundColor(theme.accentGold)
                        Text(dep.displayName)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(theme.inkBlack)
                        Text("\(depPerf.actualOutput)%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(depPerf.actualOutput >= 50 ? .green : .red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.parchmentDark)
                    .cornerRadius(4)
                }
            }
        }
    }

    // MARK: - Focus Options

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRODUCTION FOCUS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(focuses) { focus in
                FocusOptionCard(
                    focus: focus,
                    isActive: focus.focusId == activeFocusId,
                    theme: theme
                ) {
                    changeFocus(to: focus)
                }
            }
        }
    }

    private func changeFocus(to focus: SectorFocus) {
        guard focus.focusId != activeFocusId else { return }
        // Phase 3.4: present FocusForecastSheet instead of committing
        // immediately. The sheet's CONFIRM button calls commitFocus.
        pendingForecast = FocusForecastService.shared.forecast(
            switching: sector,
            from: activeFocusId,
            to: focus,
            in: game
        )
    }

    private func commitFocus(_ focus: SectorFocus) {
        game.setSectorFocus(focus.focusId, for: sector)

        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .personalAction,
            summary: "\(sector.displayName) refocused to \(focus.name)"
        )
        event.details = [
            "sector": sector.rawValue,
            "newFocus": focus.focusId,
            "type": "sector_focus_change"
        ]
        event.importance = 4
        event.game = game
        game.events.append(event)
    }
}

// MARK: - Sector Stat Bar

private struct SectorStatBar: View {
    let label: String
    let value: Int
    let theme: any CampaignTheme

    var body: some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.parchment)
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(value) / 100, height: 10)
                }
            }
            .frame(height: 10)

            Text("\(value)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(barColor)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var barColor: Color {
        switch value {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - Focus Option Card

private struct FocusOptionCard: View {
    let focus: SectorFocus
    let isActive: Bool
    let theme: any CampaignTheme
    let onActivate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row
            HStack {
                Image(systemName: focus.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(isActive ? theme.accentGold : theme.inkGray)
                    .frame(width: 24)

                Text(focus.name.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(isActive ? theme.accentGold : theme.inkBlack)

                Spacer()

                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(theme.parchment)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accentGold)
                        .cornerRadius(3)
                } else {
                    Button(action: onActivate) {
                        Text("ACTIVATE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(theme.stampRed)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(theme.stampRed, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Description
            Text(focus.description)
                .font(.system(size: 11))
                .foregroundColor(theme.inkGray)
                .lineSpacing(2)

            // Effects summary
            HStack(spacing: 12) {
                ForEach(Array(focus.effects.sorted(by: { $0.key < $1.key })), id: \.key) { stat, change in
                    HStack(spacing: 2) {
                        Text(formatStatName(stat))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.inkGray)
                        Text(change > 0 ? "+\(change)" : "\(change)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(change > 0 ? .green : .red)
                    }
                }
            }

            // Trade-off indicators
            HStack(spacing: 16) {
                tradeoffPill(label: "PROD", value: focus.sectorProductionModifier)
                tradeoffPill(label: "MORALE", value: focus.sectorMoraleModifier)
                tradeoffPill(label: "EFFIC", value: focus.sectorEfficiencyModifier)

                if focus.treasuryCostPerTurn != 0 {
                    HStack(spacing: 2) {
                        Text("COST")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.inkGray)
                        Text(focus.treasuryCostPerTurn > 0 ? "-\(focus.treasuryCostPerTurn)" : "+\(abs(focus.treasuryCostPerTurn))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(focus.treasuryCostPerTurn > 0 ? .red : .green)
                    }
                }
            }
        }
        .padding(12)
        .background(isActive ? theme.accentGold.opacity(0.08) : theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? theme.accentGold.opacity(0.5) : theme.borderTan, lineWidth: isActive ? 2 : 1)
        )
    }

    private func tradeoffPill(label: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(theme.inkGray)
            Text(value > 0 ? "+\(value)" : "\(value)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(value > 0 ? .green : (value < 0 ? .red : theme.inkGray))
        }
    }

    private func formatStatName(_ key: String) -> String {
        switch key {
        case "stability": return "STB"
        case "popularSupport": return "POP"
        case "militaryLoyalty": return "MIL"
        case "eliteLoyalty": return "ELT"
        case "treasury": return "TRS"
        case "industrialOutput": return "IND"
        case "foodSupply": return "FD"
        case "internationalStanding": return "INT"
        default: return key.prefix(3).uppercased()
        }
    }
}
