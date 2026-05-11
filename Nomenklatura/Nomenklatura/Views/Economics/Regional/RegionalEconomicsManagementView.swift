//
//  RegionalEconomicsManagementView.swift
//  Nomenklatura
//
//  Interactive regional economic planning view with invest/boost controls
//

import SwiftUI

struct RegionalEconomicsManagementView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            regionHeader
            summarySection

            ForEach(game.regions.sorted(by: { $0.economicContribution > $1.economicContribution })) { region in
                RegionEconomicCard(game: game, region: region)
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }

    // MARK: - Header

    private var regionHeader: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(theme.accentGold)
                .frame(height: 2)

            Text("REGIONAL ECONOMIC PLANNING")
                .font(.system(size: 13, weight: .bold))
                .tracking(2)
                .foregroundColor(theme.inkBlack)

            Rectangle()
                .fill(theme.accentGold)
                .frame(height: 2)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(spacing: 0) {
            summaryCell(
                label: "GDP COVERAGE",
                value: "\(totalContribution)%"
            )

            Divider()
                .frame(height: 36)
                .background(theme.borderTan)

            summaryCell(
                label: "CRISIS ZONES",
                value: "\(crisisCount)",
                valueColor: crisisCount > 0 ? theme.sovietRed : theme.approvedGreen
            )

            Divider()
                .frame(height: 36)
                .background(theme.borderTan)

            summaryCell(
                label: "AVG INFRA",
                value: "\(averageInfrastructure)"
            )
        }
        .padding(.vertical, 10)
        .background(theme.cardstock)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func summaryCell(
        label: String,
        value: String,
        valueColor: Color? = nil
    ) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor ?? theme.accentGold)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed

    private var totalContribution: Int {
        game.regions.reduce(0) { $0 + $1.economicContribution }
    }

    private var crisisCount: Int {
        game.regions.filter { $0.isDangerous }.count
    }

    private var averageInfrastructure: Int {
        guard !game.regions.isEmpty else { return 0 }
        return game.regions.reduce(0) { $0 + $1.infrastructureQuality } / game.regions.count
    }
}

// MARK: - Region Economic Card

private struct RegionEconomicCard: View {
    @Bindable var game: Game
    let region: Region
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(region.name.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(theme.inkBlack)

                Spacer()

                typeBadge
            }

            if let governor = region.governor {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                    Text("Gov. \(governorName(for: governor))")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkGray)
                }
            }

            VStack(spacing: 6) {
                statBar(label: "INDUSTRIAL", value: region.industrialCapacity, icon: "gearshape.2.fill")
                statBar(label: "AGRICULTURE", value: region.agriculturalOutput, icon: "leaf.fill")
                statBar(label: "RESOURCES", value: region.naturalResources, icon: "mountain.2.fill")
                statBar(label: "INFRASTRUCTURE", value: region.infrastructureQuality, icon: "road.lanes")
            }

            HStack {
                HStack(spacing: 4) {
                    Text("GDP:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.inkGray)
                    Text("\(region.economicContribution)%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.accentGold)
                }

                Spacer()

                statusBadge
            }

            HStack(spacing: 10) {
                investButton
                boostQuotaButton
            }
        }
        .padding(12)
        .background(theme.cardstock)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private var typeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: region.type.iconName)
                .font(.system(size: 8))
            Text(region.type.displayName.uppercased())
                .font(.system(size: 7, weight: .bold))
                .tracking(0.3)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(typeBadgeColor)
        .cornerRadius(3)
    }

    private var statusBadge: some View {
        Text(region.status.displayName.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(0.5)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(statusColor)
            .cornerRadius(3)
    }

    private func statBar(label: String, value: Int, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(theme.inkGray)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(0.3)
                .foregroundColor(theme.inkGray)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(theme.parchmentDark)
                        .frame(height: 6)

                    Rectangle()
                        .fill(barColor(for: value))
                        .frame(width: geometry.size.width * CGFloat(min(value, 100)) / 100, height: 6)
                }
                .cornerRadius(3)
            }
            .frame(height: 6)

            Text("\(value)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(theme.inkBlack)
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - Action Buttons

    private var investButton: some View {
        Button {
            guard game.treasury >= 3 else { return }
            game.applyStat("treasury", change: -3)
            region.infrastructureQuality = min(100, region.infrastructureQuality + 5)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 9))
                Text("INVEST (-3)")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.3)
            }
            .foregroundColor(game.treasury >= 3 ? .white : theme.inkLight)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(game.treasury >= 3 ? theme.approvedGreen : theme.parchmentDark)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(game.treasury < 3)
    }

    @ViewBuilder
    private var boostQuotaButton: some View {
        if game.treasury >= 5 {
            Button {
                region.industrialCapacity = min(100, region.industrialCapacity + 3)
                region.popularLoyalty = max(0, region.popularLoyalty - 2)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                    Text("BOOST QUOTA")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.3)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(theme.sovietRed)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func governorName(for governor: RegionGovernor) -> String {
        if let character = game.characters.first(where: { $0.templateId == governor.characterId }) {
            return character.name
        }
        return "Unknown"
    }

    private func barColor(for value: Int) -> Color {
        switch value {
        case 70...: return theme.approvedGreen
        case 40..<70: return theme.bronzeGold
        case 20..<40: return .orange
        default: return theme.sovietRed
        }
    }

    private var typeBadgeColor: Color {
        switch region.type {
        case .capital: return theme.bronzeGold
        case .industrial: return theme.steelGray
        case .agricultural: return theme.approvedGreen
        case .extractive: return theme.leatherBrown
        case .coastal: return Color(hex: "4682B4")
        case .border: return theme.sovietRed
        case .autonomous: return .purple
        }
    }

    private var statusColor: Color {
        switch region.status {
        case .stable: return theme.approvedGreen
        case .unrest: return .orange
        case .crisis: return theme.sovietRed
        case .rebellion: return .red
        case .seceding: return .purple
        case .seceded: return theme.steelGray
        case .martial: return .black
        }
    }

    private var statusBorderColor: Color {
        region.isDangerous ? theme.sovietRed.opacity(0.5) : theme.borderTan
    }
}
