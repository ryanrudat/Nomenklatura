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

            ForEach(game.regions.sorted(by: { $0.treasuryContribution > $1.treasuryContribution })) { region in
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
                label: "REGIONAL +$",
                value: "+\(totalTreasuryContribution)"
            )

            Divider()
                .frame(height: 36)
                .background(theme.borderTan)

            summaryCell(
                label: "CRISIS ZONES",
                value: "\(crisisCount)",
                valueColor: crisisCount > 0 ? FiftiesColors.stampRed : FiftiesColors.approvedGreen
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
        .background(FiftiesColors.cardstock)
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

    private var totalTreasuryContribution: Int {
        game.regions.reduce(0) { $0 + $1.treasuryContribution }
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

    @State private var detailsExpanded: Bool = false

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

            treasuryContributionBanner

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
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.accentGold)
                }

                Spacer()

                statusBadge
            }

            HStack(spacing: 8) {
                investButton
                boostQuotaButton
            }

            HStack(spacing: 8) {
                deployCadresButton
                federalAidButton
            }

            establishSEZButton

            detailsDisclosure
        }
        .padding(12)
        .background(FiftiesColors.cardstock)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private var treasuryContributionBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "banknote.fill")
                .font(.system(size: 10))
                .foregroundColor(FiftiesColors.approvedGreen)

            Text("TREASURY / TURN")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(theme.inkGray)

            Spacer()

            Text("+\(region.treasuryContribution)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(FiftiesColors.approvedGreen)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(FiftiesColors.approvedGreen.opacity(0.08))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(FiftiesColors.approvedGreen.opacity(0.3), lineWidth: 1)
        )
    }

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
        actionButton(
            label: "INVEST (-3)",
            icon: "wrench.and.screwdriver.fill",
            color: FiftiesColors.approvedGreen,
            isEnabled: game.treasury >= 3
        ) {
            guard game.treasury >= 3 else { return }
            game.applyStat("treasury", change: -3)
            region.infrastructureQuality = min(100, region.infrastructureQuality + 5)
        }
    }

    private var boostQuotaButton: some View {
        actionButton(
            label: "BOOST (-5)",
            icon: "bolt.fill",
            color: FiftiesColors.stampRed,
            isEnabled: game.treasury >= 5
        ) {
            guard game.treasury >= 5 else { return }
            game.applyStat("treasury", change: -5)
            region.industrialCapacity = min(100, region.industrialCapacity + 3)
            region.popularLoyalty = max(0, region.popularLoyalty - 2)
        }
    }

    private var deployCadresButton: some View {
        actionButton(
            label: "CADRES (-4)",
            icon: "person.3.fill",
            color: FiftiesColors.brassGold,
            isEnabled: game.treasury >= 4
        ) {
            guard game.treasury >= 4 else { return }
            game.applyStat("treasury", change: -4)
            region.partyControl = min(100, region.partyControl + 5)
            region.popularLoyalty = max(0, region.popularLoyalty - 2)
        }
    }

    private var federalAidButton: some View {
        let cdId = "request_federal_aid"
        let remaining = region.cooldownRemaining(cdId, currentTurn: game.turnNumber)
        let isAvailable = remaining == 0

        return actionButton(
            label: isAvailable ? "FED. AID" : "AID (\(remaining)t)",
            icon: "building.columns.fill",
            color: Color(hex: "4682B4"),
            isEnabled: isAvailable
        ) {
            guard isAvailable else { return }
            region.infrastructureQuality = min(100, region.infrastructureQuality + 3)
            region.autonomyDesire = max(0, region.autonomyDesire - 2)
            region.setActionCooldown(cdId, turns: 8, currentTurn: game.turnNumber)
        }
    }

    private var establishSEZButton: some View {
        let typeEligible = region.type == .coastal || region.type == .industrial
        let canAfford = game.treasury >= 8
        let isEnabled = !region.hasEstablishedSEZ && typeEligible && canAfford

        return Button {
            guard isEnabled else { return }
            game.applyStat("treasury", change: -8)
            region.industrialCapacity = min(100, region.industrialCapacity + 8)
            game.applyStat("internationalStanding", change: 3)
            region.partyControl = max(0, region.partyControl - 3)
            region.hasEstablishedSEZ = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: region.hasEstablishedSEZ ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 9))
                Text(sezLabel(typeEligible: typeEligible, canAfford: canAfford))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.3)
            }
            .foregroundColor(isEnabled ? .white : theme.inkLight)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isEnabled ? Color.purple : theme.parchmentDark)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func sezLabel(typeEligible: Bool, canAfford: Bool) -> String {
        if region.hasEstablishedSEZ { return "SEZ ESTABLISHED" }
        if !typeEligible { return "SEZ (coastal/industrial only)" }
        return "ESTABLISH SEZ (-8)"
    }

    @ViewBuilder
    private func actionButton(
        label: String,
        icon: String,
        color: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.3)
            }
            .foregroundColor(isEnabled ? .white : theme.inkLight)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isEnabled ? color : theme.parchmentDark)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var detailsDisclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    detailsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: detailsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("DETAILS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.4)
                    Spacer()
                }
                .foregroundColor(theme.inkGray)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if detailsExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let governor = region.governor {
                        governorRow(governor)
                    }

                    metaRow(label: "Years in Union", value: "\(region.yearsInUnion)")
                    metaRow(label: "Party Control", value: "\(region.partyControl)")
                    metaRow(label: "Popular Loyalty", value: "\(region.popularLoyalty)")
                    metaRow(label: "Autonomy Desire", value: "\(region.autonomyDesire)")

                    if region.hasDistinctCulture || region.hasDistinctLanguage {
                        let traits = [
                            region.hasDistinctCulture ? "Distinct culture" : nil,
                            region.hasDistinctLanguage ? "Distinct language" : nil
                        ].compactMap { $0 }.joined(separator: " · ")
                        metaRow(label: "Cultural Traits", value: traits)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func governorRow(_ governor: RegionGovernor) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkGray)
                Text("Gov. \(governorName(for: governor))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.inkBlack)
            }
            HStack(spacing: 8) {
                miniStat(label: "Loy", value: governor.loyaltyToPlayer)
                miniStat(label: "Comp", value: governor.competence)
                miniStat(label: "Corr", value: governor.corruption)
            }
        }
    }

    private func miniStat(label: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(theme.inkGray)
            Text("\(value)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(theme.inkBlack)
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(theme.inkGray)
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(theme.inkBlack)
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
        case 70...: return FiftiesColors.approvedGreen
        case 40..<70: return FiftiesColors.brassGold
        case 20..<40: return .orange
        default: return FiftiesColors.stampRed
        }
    }

    private var typeBadgeColor: Color {
        switch region.type {
        case .capital: return FiftiesColors.brassGold
        case .industrial: return FiftiesColors.steelGray
        case .agricultural: return FiftiesColors.approvedGreen
        case .extractive: return FiftiesColors.leatherBrown
        case .coastal: return Color(hex: "4682B4")
        case .border: return FiftiesColors.stampRed
        case .autonomous: return .purple
        }
    }

    private var statusColor: Color {
        switch region.status {
        case .stable: return FiftiesColors.approvedGreen
        case .unrest: return .orange
        case .crisis: return FiftiesColors.stampRed
        case .rebellion: return .red
        case .seceding: return .purple
        case .seceded: return FiftiesColors.steelGray
        case .martial: return .black
        }
    }

    private var statusBorderColor: Color {
        region.isDangerous ? FiftiesColors.stampRed.opacity(0.5) : theme.borderTan
    }
}
