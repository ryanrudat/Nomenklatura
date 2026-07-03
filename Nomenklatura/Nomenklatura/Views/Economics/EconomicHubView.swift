//
//  EconomicHubView.swift
//  Nomenklatura
//
//  Unified Economic Hub — merges Dashboard (data/intelligence) and Portal (actions/projects)
//  into a single primary tab view for the State Planning Committee (Gosplan).
//

import SwiftUI
import SwiftData

// MARK: - Hub Section Enum

// Simplified in the 2026-06 economy pass from 6 sections to 3 lever tabs. The old
// COMMAND dashboard became the always-visible summary at the top of the screen;
// TRADE / REGIONS / BUDGET were cut (dead or folded into the summary / diplomacy /
// security surfaces). PLANNING was renamed WORKS to end the "plan" name collision.
enum EconomicHubSection: String, CaseIterable {
    case sectors = "SECTORS"
    case works = "WORKS"
    case fiscal = "FISCAL"

    var icon: String {
        switch self {
        case .sectors: return "gearshape.2.fill"
        case .works: return "hammer.fill"
        case .fiscal: return "banknote.fill"
        }
    }
}

// MARK: - Economic Hub View

struct EconomicHubView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    @State private var selectedSection: EconomicHubSection = .sectors
    @State private var selectedSector: EconomicSector?
    @State private var showForecastSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            hubHeader
                .padding(.horizontal, 15)
                .padding(.top, 10)

            // Forecast button — single most-important visibility lever per
            // the economy audit. Always one tap away from "what will happen
            // next turn if I do nothing, and what should I consider doing?"
            forecastButton
                .padding(.horizontal, 15)
                .padding(.top, 8)

            // Always-visible command summary (replaces the old COMMAND tab): the
            // economic-health chip and the Five-Year-Plan clock, so the headline
            // state is on screen without digging into a sub-section.
            commandSummary
                .padding(.horizontal, 15)
                .padding(.top, 10)

            hubSectionSelector
                .padding(.horizontal, 15)
                .padding(.vertical, 10)

            ScrollView {
                sectionContent
                    .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $showForecastSheet) {
            EconomicForecastSheet(game: game)
        }
    }

    /// Compact always-on summary at the top of the Economy tab.
    private var commandSummary: some View {
        VStack(spacing: 8) {
            EconomicSituationCard(game: game)
            planClockBanner
        }
    }

    /// One-line Five-Year-Plan clock (replaces the cosmetic FiveYearPlanWheelView).
    private var planClockBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 11))
                .foregroundColor(theme.accentGold)
            Text("FIVE-YEAR PLAN — YEAR \(min(game.fiveYearPlanYear, 5))/5")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.parchmentDark)
        .cornerRadius(6)
    }

    /// Tight pill button that opens the EconomicForecastSheet. Surfaces
    /// the projected treasury delta inline so the player sees the pain
    /// before even tapping in.
    private var forecastButton: some View {
        Button {
            showForecastSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "scope")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.stampRed)
                Text("FORECAST NEXT TURN")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(theme.inkBlack)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.stampRed)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.parchmentDark)
            .overlay(
                Rectangle()
                    .stroke(theme.stampRed.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var hubHeader: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(theme.accentGold)
                .frame(height: 3)
                .cornerRadius(1.5)

            VStack(spacing: 2) {
                Text("STATE PLANNING COMMITTEE")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(theme.accentGold)

                Text("STATE PLAN")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)
            }
            .padding(.vertical, 8)

            EconomicPositionBanner(game: game)
        }
    }

    // MARK: - Section Selector

    private var hubSectionSelector: some View {
        HStack(spacing: 6) {
            ForEach(EconomicHubSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 12))
                        Text(section.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(0.3)
                    }
                    .foregroundColor(selectedSection == section ? .white : theme.inkGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedSection == section ? theme.sovietRed : theme.parchmentDark)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .sectors:
            sectorsSection
        case .works:
            planningSectionContent
        case .fiscal:
            fiscalSection
        }
    }

    // MARK: - Fiscal (read-only treasury / indicators report)

    private var fiscalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            keyMetricsGrid
            activeProjectsSummary
        }
        .padding(.horizontal, 15)
    }

    private var keyMetricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEY INDICATORS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                HubMetricCard(
                    label: "GDP INDEX",
                    value: "\(game.gdpIndex)",
                    baseline: 100,
                    actual: game.gdpIndex,
                    icon: "chart.line.uptrend.xyaxis"
                )
                HubMetricCard(
                    label: "INFLATION",
                    value: "\(game.inflationRate)%",
                    baseline: 5,
                    actual: game.inflationRate,
                    invertColor: true,
                    icon: "arrow.up.right"
                )
                HubMetricCard(
                    label: "UNEMPLOY.",
                    value: "\(game.unemploymentRate)%",
                    baseline: 5,
                    actual: game.unemploymentRate,
                    invertColor: true,
                    icon: "person.fill.xmark"
                )
            }

            HubMetricCard(
                label: "TREASURY",
                value: "\(game.treasury)",
                baseline: 50,
                actual: game.treasury,
                icon: "banknote.fill"
            )
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private var activeProjectsSummary: some View {
        let projects = EconomicActionService.shared.getActiveProjects(for: game)
        return HStack {
            Image(systemName: "building.2.fill")
                .font(.system(size: 14))
                .foregroundColor(theme.accentGold)

            Text("ACTIVE PROJECTS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            Spacer()

            Text("\(projects.count)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(projects.isEmpty ? theme.inkLight : theme.accentGold)

            Text("/ 3")
                .font(.system(size: 12))
                .foregroundColor(theme.inkGray)
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Sectors

    private var sectorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ECONOMIC SECTORS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)
                .padding(.horizontal, 15)

            ForEach(EconomicSector.allCases, id: \.self) { sector in
                SectorDetailCard(sector: sector, game: game)
                    .padding(.horizontal, 15)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedSector = sector }
            }
        }
        .sheet(item: $selectedSector) { sector in
            SectorDetailView(game: game, sector: sector)
        }
    }

    // MARK: - Works (economic projects + actions; formerly "Planning")

    private var planningSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            EconomicProjectsSection(game: game)
            EconomicActionsSection(game: game)
        }
    }
}

// MARK: - Hub Metric Card

private struct HubMetricCard: View {
    let label: String
    let value: String
    var baseline: Int = 50
    var actual: Int = 50
    var invertColor: Bool = false
    var icon: String = "chart.bar.fill"
    @Environment(\.theme) var theme

    private var statusColor: Color {
        let good: Bool
        if invertColor {
            good = actual <= baseline
        } else {
            good = actual >= baseline
        }
        return good ? .green : .orange
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(statusColor)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(statusColor)

            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.parchment)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.borderTan, lineWidth: 0.5)
        )
    }
}

// MARK: - Hub Sparkline

private struct HubSparkline: View {
    let label: String
    let data: [Int]
    let baselineValue: Int
    let color: Color
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            SimpleLineChart(data: data, baselineValue: baselineValue, color: color)
                .frame(height: 40)

            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.3)
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hub Stat Box

private struct HubStatBox: View {
    let label: String
    let value: String
    let color: Color
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sector Detail Card

private struct SectorDetailCard: View {
    let sector: EconomicSector
    let game: Game
    @Environment(\.theme) var theme

    private var production: Int {
        // Same source of truth as SectorDetailView — the card must agree with
        // the detail screen it opens.
        game.sectorPerformance(for: sector).actualOutput
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: sector.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentGold)
                    .frame(width: 24)

                Text(sector.displayName.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(theme.inkBlack)

                Spacer()

                Text("\(production)%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(barColor(production))
            }

            SectorBar(value: production)

            if let deps = sectorDependencies(sector) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkLight)
                    Text(deps)
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkLight)
                }
            }
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func sectorDependencies(_ sector: EconomicSector) -> String? {
        // Render the model's real dependency graph — the same one the
        // supply-chain sim and SectorDetailView use.
        let deps = sector.dependencies
        guard !deps.isEmpty else { return nil }
        return "Depends on: " + deps.map(\.displayName).joined(separator: ", ")
    }

    private func barColor(_ value: Int) -> Color {
        switch value {
        case 60...: return .green
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - Sector Bar

private struct SectorBar: View {
    let value: Int
    @Environment(\.theme) var theme

    private var barColor: Color {
        switch value {
        case 60...: return .green
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.parchmentDark)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: geo.size.width * CGFloat(max(0, min(100, value))) / 100, height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Trade Partner Row

private struct HubTradePartnerRow: View {
    let country: ForeignCountry
    @Environment(\.theme) var theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(country.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.inkBlack)

                Text(country.bloc.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkGray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Vol: \(country.tradeVolume)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.accentGold)

                Text("Rel: \(country.relationshipScore)")
                    .font(.system(size: 9))
                    .foregroundColor(country.relationshipScore >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Region Economic Card

private struct RegionEconomicCard: View {
    let region: Region
    @Environment(\.theme) var theme

    private var regionTypeEnum: RegionType? {
        RegionType(rawValue: region.regionType)
    }

    private var regionStatusEnum: RegionStatus? {
        RegionStatus(rawValue: region.currentStatus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: regionTypeEnum?.iconName ?? "map.fill")
                    .font(.system(size: 14))
                    .foregroundColor(theme.accentGold)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(region.name.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(theme.inkBlack)

                    Text(regionTypeEnum?.displayName ?? region.regionType)
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                if let status = regionStatusEnum {
                    Text(status.displayName.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor(status))
                        .cornerRadius(3)
                }
            }

            HStack(spacing: 12) {
                RegionStatMini(label: "Industry", value: region.industrialCapacity)
                RegionStatMini(label: "Agri.", value: region.agriculturalOutput)
                RegionStatMini(label: "Resources", value: region.naturalResources)
                RegionStatMini(label: "GDP %", value: region.economicContribution)
            }
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func statusColor(_ status: RegionStatus) -> Color {
        switch status {
        case .stable: return .green
        case .unrest: return .yellow
        case .crisis: return .orange
        case .rebellion, .seceding: return .red
        case .seceded: return .gray
        case .martial: return .purple
        }
    }
}

// MARK: - Region Stat Mini

private struct RegionStatMini: View {
    let label: String
    let value: Int
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(value >= 50 ? .green : .orange)

            Text(label)
                .font(.system(size: 8))
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sector Share Row

private struct SectorShareRow: View {
    let label: String
    let share: Int
    let color: Color
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.inkBlack)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.parchmentDark)
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(100, share))) / 100, height: 10)
                }
            }
            .frame(height: 10)

            Text("\(share)%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.inkBlack)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    EconomicHubView(game: Game(campaignId: "cold_war"))
        .environment(\.theme, ColdWarTheme())
}
