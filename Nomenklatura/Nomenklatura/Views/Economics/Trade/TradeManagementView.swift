//
//  TradeManagementView.swift
//  Nomenklatura
//
//  Trade management dashboard showing balance, agreements, and partners
//

import SwiftUI

struct TradeManagementView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedCountry: ForeignCountry?
    @State private var showProposalSheet = false

    private var totalTradeVolume: Int {
        game.foreignCountries.reduce(0) { $0 + $1.tradeVolume }
    }

    private var tradeOpenness: Int {
        game.currentEconomicSystem.tradeOpenness
    }

    private var sortedPartners: [ForeignCountry] {
        game.foreignCountries.sorted { $0.relationshipScore > $1.relationshipScore }
    }

    private var balanceTrend: String {
        if game.tradeBalance > 5 { return "SURPLUS" }
        if game.tradeBalance < -5 { return "DEFICIT" }
        return "BALANCED"
    }

    private var balanceTrendColor: Color {
        if game.tradeBalance > 5 { return FiftiesColors.approvedGreen }
        if game.tradeBalance < -5 { return FiftiesColors.stampRed }
        return FiftiesColors.brassGold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            tradePolicySection
            tradeBalanceSection
            activeAgreementsSection
            tradePartnersSection
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
        .sheet(isPresented: $showProposalSheet) {
            if let country = selectedCountry {
                TradeProposalSheet(game: game, country: country)
            }
        }
    }

    // MARK: - Trade Policy Controls

    private var tradePolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("TRADE POLICY")

            VStack(spacing: 14) {
                // Tariff Level
                VStack(alignment: .leading, spacing: 8) {
                    Text("TARIFF LEVEL")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(FiftiesColors.typewriterInk)

                    HStack(spacing: 0) {
                        ForEach(TariffLevel.allCases, id: \.rawValue) { level in
                            Button {
                                game.tariffLevel = level.rawValue
                            } label: {
                                Text(level.displayName.uppercased())
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .tracking(0.3)
                                    .foregroundColor(game.currentTariffLevel == level ? .white : FiftiesColors.typewriterInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(game.currentTariffLevel == level ? FiftiesColors.brassGold : FiftiesColors.cardstock)
                                    .overlay(
                                        Rectangle()
                                            .stroke(theme.borderTan, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(game.currentTariffLevel.description)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(FiftiesColors.carbonCopy)
                }

                Rectangle()
                    .fill(FiftiesColors.brassGold.opacity(0.3))
                    .frame(height: 1)

                // Embargo Controls
                embargoSection

                Rectangle()
                    .fill(FiftiesColors.brassGold.opacity(0.3))
                    .frame(height: 1)

                // Trade Openness
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("TRADE OPENNESS")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(0.5)
                            .foregroundColor(FiftiesColors.carbonCopy)
                        Spacer()
                        Text("\(tradeOpenness)%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.typewriterInk)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(theme.borderTan)
                                .frame(height: 6)
                            Rectangle()
                                .fill(FiftiesColors.brassGold)
                                .frame(width: geo.size.width * CGFloat(tradeOpenness) / 100, height: 6)
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 6)

                    Text(tradeOpennessDescription)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(FiftiesColors.carbonCopy)
                }
            }
            .padding(14)
            .background(FiftiesColors.cardstock)
            .overlay(
                Rectangle()
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
    }

    private var embargoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EMBARGOES")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(FiftiesColors.typewriterInk)

            let embargoable = game.foreignCountries.filter { $0.relationshipScore < 0 }
            if embargoable.isEmpty {
                Text("No hostile nations available for embargo.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(FiftiesColors.carbonCopy)
            } else {
                ForEach(embargoable.sorted(by: { $0.relationshipScore < $1.relationshipScore }), id: \.id) { country in
                    let isEmbargoed = game.isEmbargoed(country.countryId)
                    HStack(spacing: 8) {
                        Text(country.name.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(isEmbargoed ? FiftiesColors.stampRed : FiftiesColors.typewriterInk)
                            .lineLimit(1)

                        Spacer()

                        if isEmbargoed {
                            Text("EMBARGOED")
                                .font(.system(size: 7, weight: .bold))
                                .tracking(0.3)
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(FiftiesColors.stampRed)
                                .cornerRadius(2)
                        }

                        Button {
                            game.toggleEmbargo(countryId: country.countryId)
                        } label: {
                            Text(isEmbargoed ? "LIFT" : "IMPOSE")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(0.3)
                                .foregroundColor(isEmbargoed ? FiftiesColors.approvedGreen : FiftiesColors.stampRed)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .overlay(
                                    Rectangle()
                                        .stroke(isEmbargoed ? FiftiesColors.approvedGreen : FiftiesColors.stampRed, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var tradeOpennessDescription: String {
        let openness = tradeOpenness
        if openness >= 70 {
            return "Highly open economy. Foreign trade flows freely with minimal restrictions."
        } else if openness >= 40 {
            return "Moderate openness. State controls trade channels but permits substantial commerce."
        } else {
            return "Restricted trade. State monopoly limits foreign commerce to essential exchanges."
        }
    }

    // MARK: - Trade Balance Summary

    private var tradeBalanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("TRADE BALANCE SUMMARY")

            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    balanceStat(
                        label: "TRADE BALANCE",
                        value: "\(game.tradeBalance > 0 ? "+" : "")\(game.tradeBalance)",
                        color: balanceTrendColor
                    )
                    balanceStat(
                        label: "TREND",
                        value: balanceTrend,
                        color: balanceTrendColor
                    )
                    balanceStat(
                        label: "TOTAL VOLUME",
                        value: "\(totalTradeVolume)",
                        color: FiftiesColors.typewriterInk
                    )
                    balanceStat(
                        label: "TARIFF",
                        value: game.currentTariffLevel.displayName.uppercased(),
                        color: FiftiesColors.brassGold
                    )
                }

                let embargoCount = game.embargoedCountries.count
                if embargoCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.shield.fill")
                            .font(.system(size: 10))
                            .foregroundColor(FiftiesColors.stampRed)
                        Text("\(embargoCount) active embargo\(embargoCount == 1 ? "" : "es")")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(FiftiesColors.stampRed)
                    }
                }

                let netImpact = game.netTradeImpact
                if netImpact != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: netImpact > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(netImpact > 0 ? FiftiesColors.approvedGreen : FiftiesColors.stampRed)
                        Text("Net agreement impact: \(netImpact > 0 ? "+" : "")\(netImpact)/turn")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)
                    }
                }
            }
            .padding(14)
            .background(FiftiesColors.cardstock)
            .overlay(
                Rectangle()
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
    }

    // MARK: - Active Agreements

    private var activeAgreementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ACTIVE AGREEMENTS")

            let agreements = game.tradeAgreements
            if agreements.isEmpty {
                emptyAgreementsView
            } else {
                ForEach(agreements, id: \.id) { agreement in
                    agreementRow(agreement)
                }
            }
        }
    }

    private var emptyAgreementsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 24))
                .foregroundColor(FiftiesColors.carbonCopy)
            Text("No active trade agreements.")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(FiftiesColors.typewriterInk)
            Text("Approach a trading partner below to negotiate.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(FiftiesColors.carbonCopy)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(FiftiesColors.cardstock)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func agreementRow(_ agreement: TradeAgreement) -> some View {
        HStack(spacing: 12) {
            Image(systemName: agreement.type.iconName)
                .font(.system(size: 14))
                .foregroundColor(FiftiesColors.brassGold)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(agreement.agreementName)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(FiftiesColors.typewriterInk)
                    .lineLimit(1)

                Text(agreement.effectsSummary)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(FiftiesColors.carbonCopy)
                    .lineLimit(1)
            }

            Spacer()

            statusBadge(agreement.status)
        }
        .padding(12)
        .background(FiftiesColors.cardstock)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func statusBadge(_ status: AgreementStatus) -> some View {
        let (color, bgColor): (Color, Color) = {
            switch status {
            case .active:
                return (FiftiesColors.approvedGreen, FiftiesColors.approvedGreen.opacity(0.15))
            case .proposed:
                return (FiftiesColors.brassGold, FiftiesColors.brassGold.opacity(0.15))
            case .suspended:
                return (.orange, Color.orange.opacity(0.15))
            case .terminated, .expired, .violated:
                return (FiftiesColors.stampRed, FiftiesColors.stampRed.opacity(0.15))
            }
        }()

        return Text(status.displayName.uppercased())
            .font(.system(size: 7, weight: .bold))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(bgColor)
            .cornerRadius(2)
    }

    // MARK: - Trade Partners

    private var tradePartnersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("TRADE PARTNERS")

            if sortedPartners.isEmpty {
                Text("No foreign countries available.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(FiftiesColors.carbonCopy)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(FiftiesColors.cardstock)
                    .overlay(
                        Rectangle()
                            .stroke(theme.borderTan, lineWidth: 1)
                    )
            } else {
                ForEach(sortedPartners, id: \.id) { country in
                    TradePartnerCard(
                        country: country,
                        activeAgreementCount: game.agreements(with: country.countryId).filter(\.isActive).count,
                        isEmbargoed: game.isEmbargoed(country.countryId),
                        onNegotiate: {
                            selectedCountry = country
                            showProposalSheet = true
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundColor(theme.inkGray)
            Rectangle()
                .fill(FiftiesColors.brassGold)
                .frame(height: 2)
        }
    }

    private func balanceStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(FiftiesColors.carbonCopy)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}
