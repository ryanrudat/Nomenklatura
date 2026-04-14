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

enum EconomicHubSection: String, CaseIterable {
    case commandCenter = "COMMAND"
    case sectors = "SECTORS"
    case trade = "TRADE"
    case regions = "REGIONS"
    case budget = "BUDGET"
    case planning = "PLANNING"

    var icon: String {
        switch self {
        case .commandCenter: return "star.fill"
        case .sectors: return "gearshape.2.fill"
        case .trade: return "arrow.left.arrow.right"
        case .regions: return "map.fill"
        case .budget: return "banknote.fill"
        case .planning: return "hammer.fill"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .commandCenter: return 0
        case .sectors: return 0
        case .trade: return 4
        case .regions: return 6
        case .budget: return 6
        case .planning: return 1
        }
    }
}

// MARK: - Economic Hub View

struct EconomicHubView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    @State private var selectedSection: EconomicHubSection = .commandCenter
    @State private var showPropaganda: Bool = true
    @State private var selectedSector: EconomicSector?

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    private var canSeeReality: Bool {
        accessLevel.effectiveLevel(for: .economic) >= 3
    }

    var body: some View {
        VStack(spacing: 0) {
            hubHeader
                .padding(.horizontal, 15)
                .padding(.top, 10)

            if canSeeReality {
                propagandaToggle
                    .padding(.horizontal, 15)
                    .padding(.top, 8)
            }

            hubSectionSelector
                .padding(.horizontal, 15)
                .padding(.vertical, 10)

            ScrollView {
                sectionContent
                    .padding(.bottom, 120)
            }
        }
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

                Text("GOSPLAN")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)
            }
            .padding(.vertical, 8)

            EconomicPositionBanner(game: game)
        }
    }

    // MARK: - Propaganda Toggle

    private var propagandaToggle: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPropaganda = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 10))
                    Text("PUBLIC REPORT")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(showPropaganda ? .white : theme.inkGray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(showPropaganda ? theme.sovietRed : theme.parchmentDark)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPropaganda = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 10))
                    Text("INTERNAL DATA")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(!showPropaganda ? .white : theme.inkGray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(!showPropaganda ? theme.accentGold : theme.parchmentDark)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    /// Always show propaganda for junior officials, toggle for seniors
    private var effectiveShowPropaganda: Bool {
        canSeeReality ? showPropaganda : true
    }

    // MARK: - Section Selector

    private var hubSectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EconomicHubSection.allCases, id: \.self) { section in
                    let hasAccess = accessLevel.effectiveLevel(for: .economic) >= section.requiredLevel

                    Button {
                        if hasAccess {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSection = section
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12))

                            Text(section.rawValue)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .tracking(0.3)

                            if !hasAccess {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundColor(
                            !hasAccess ? theme.inkLight :
                                (selectedSection == section ? .white : theme.inkGray)
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            !hasAccess ? theme.parchmentDark.opacity(0.5) :
                                (selectedSection == section ? theme.sovietRed : theme.parchmentDark)
                        )
                        .cornerRadius(6)
                        .opacity(!hasAccess ? 0.6 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasAccess)
                }
            }
        }
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .commandCenter:
            commandCenterSection
        case .sectors:
            sectorsSection
        case .trade:
            tradeSectionContent
        case .regions:
            regionsSectionContent
        case .budget:
            budgetSectionContent
        case .planning:
            planningSectionContent
        }
    }

    // MARK: - Command Center

    private var commandCenterSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            EconomicSituationCard(game: game)
            keyMetricsGrid
            sparklineSection
            FiveYearPlanWheelView(game: game, showPropaganda: effectiveShowPropaganda)
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

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                HubMetricCard(
                    label: "TREASURY",
                    value: "\(game.treasury)",
                    baseline: 50,
                    actual: game.treasury,
                    icon: "banknote.fill"
                )
                HubMetricCard(
                    label: "TRADE BAL.",
                    value: game.tradeBalance >= 0 ? "+\(game.tradeBalance)" : "\(game.tradeBalance)",
                    baseline: 0,
                    actual: game.tradeBalance,
                    icon: "arrow.left.arrow.right"
                )
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

    private var sparklineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ECONOMIC TRENDS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            if !game.gdpHistory.isEmpty {
                HStack(spacing: 12) {
                    HubSparkline(label: "GDP", data: game.gdpHistory, baselineValue: 100, color: .green)
                    HubSparkline(label: "INFLATION", data: game.inflationHistory, baselineValue: 5, color: .orange)
                    HubSparkline(label: "UNEMPLOY.", data: game.unemploymentHistory, baselineValue: 5, color: .red)
                }
            } else {
                Text("Trend data will appear after Turn 1 processing.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkLight)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
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

    // MARK: - Trade

    private var tradeSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            tradeSummaryCard

            if !game.foreignCountries.isEmpty {
                tradingPartnersList
            }
        }
        .padding(.horizontal, 15)
    }

    private var tradeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRADE OVERVIEW")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            HStack(spacing: 16) {
                HubStatBox(label: "Trade Balance", value: game.tradeBalance >= 0 ? "+\(game.tradeBalance)" : "\(game.tradeBalance)", color: game.tradeBalance >= 0 ? .green : .red)
                HubStatBox(label: "Partners", value: "\(game.foreignCountries.filter { $0.tradeVolume > 0 }.count)", color: theme.accentGold)
                HubStatBox(label: "Total Volume", value: "\(game.foreignCountries.reduce(0) { $0 + $1.tradeVolume })", color: .blue)
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

    private var tradingPartnersList: some View {
        let activePartners = game.foreignCountries
            .filter { $0.tradeVolume > 0 }
            .sorted { $0.tradeVolume > $1.tradeVolume }

        return VStack(alignment: .leading, spacing: 12) {
            Text("TRADING PARTNERS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            if activePartners.isEmpty {
                Text("No active trade agreements.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkLight)
                    .padding(.vertical, 8)
            } else {
                ForEach(activePartners.prefix(8), id: \.countryId) { country in
                    HubTradePartnerRow(country: country)
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

    // MARK: - Regions

    private var regionsSectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DOMESTIC ECONOMIC ZONES")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)
                .padding(.horizontal, 15)

            ForEach(game.regions, id: \.regionId) { region in
                RegionEconomicCard(region: region)
                    .padding(.horizontal, 15)
            }

            if game.regions.isEmpty {
                Text("Regional data not yet available.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkLight)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .padding(.horizontal, 15)
            }
        }
    }

    // MARK: - Budget

    private var budgetSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            budgetOverview

            sectorSharesCard
        }
        .padding(.horizontal, 15)
    }

    private var budgetOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATE BUDGET")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            HStack(spacing: 16) {
                HubStatBox(label: "Treasury", value: "\(game.treasury)", color: game.treasury >= 50 ? .green : .orange)
                HubStatBox(label: "Industry", value: "\(game.industrialOutput)", color: game.industrialOutput >= 50 ? .green : .orange)
                HubStatBox(label: "Food Supply", value: "\(game.foodSupply)", color: game.foodSupply >= 50 ? .green : .orange)
            }

            if game.lastEconomicReport == nil {
                Text("Full economic report will be available after Turn 1 processing.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkLight)
                    .padding(.top, 4)
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

    private var sectorSharesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NATIONAL PRODUCT BREAKDOWN")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            SectorShareRow(label: "Agriculture", share: game.agricultureShare, color: .green)
            SectorShareRow(label: "Industry", share: game.industryShare, color: .blue)
            SectorShareRow(label: "Services", share: game.servicesShare, color: .orange)
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Planning

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
        sectorValue(for: sector)
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

    private func sectorValue(for sector: EconomicSector) -> Int {
        switch sector {
        case .heavyIndustry: return min(100, max(0, game.industrialOutput + 10))
        case .lightIndustry: return min(100, max(0, (game.industrialOutput + game.popularSupport) / 2))
        case .agriculture: return game.foodSupply
        case .energy: return min(100, max(0, game.industrialOutput - 5))
        case .mining: return min(100, max(0, (game.industrialOutput + game.stability) / 2))
        case .construction: return min(100, max(0, game.stability))
        case .transport: return min(100, max(0, (game.industrialOutput + game.stability) / 2))
        case .defense: return min(100, max(0, game.militaryLoyalty))
        }
    }

    private func sectorDependencies(_ sector: EconomicSector) -> String? {
        switch sector {
        case .heavyIndustry: return "Depends on: Energy, Mining"
        case .lightIndustry: return "Depends on: Heavy Industry"
        case .agriculture: return "Depends on: Transport, Energy"
        case .energy: return nil
        case .mining: return "Depends on: Energy, Transport"
        case .construction: return "Depends on: Heavy Industry, Mining"
        case .transport: return "Depends on: Energy, Construction"
        case .defense: return "Depends on: Heavy Industry, Energy"
        }
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
