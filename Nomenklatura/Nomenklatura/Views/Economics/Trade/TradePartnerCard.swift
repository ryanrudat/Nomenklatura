//
//  TradePartnerCard.swift
//  Nomenklatura
//
//  Trade partner card showing country details and negotiation status
//

import SwiftUI

struct TradePartnerCard: View {
    let country: ForeignCountry
    let activeAgreementCount: Int
    var isEmbargoed: Bool = false
    let onNegotiate: () -> Void
    @Environment(\.theme) var theme

    private var canNegotiate: Bool {
        country.relationshipScore > -30 && !isEmbargoed
    }

    private var blocColor: Color {
        switch country.politicalBloc {
        case .socialist: return theme.sovietRed
        case .capitalist: return Color(hex: "1565C0")
        case .nonAligned: return theme.steelGray
        case .rival: return .orange
        }
    }

    private var relationshipColor: Color {
        if country.relationshipScore > 30 { return theme.approvedGreen }
        if country.relationshipScore > -30 { return theme.bronzeGold }
        return theme.sovietRed
    }

    private var compatibility: (label: String, color: Color) {
        switch country.currentEconomicSystem {
        case .commandEconomy, .marketSocialism:
            return ("COMPATIBLE", theme.approvedGreen)
        case .mixedEconomy:
            return ("NEUTRAL", theme.bronzeGold)
        case .freeMarket, .cronyCapitalism:
            return ("INCOMPATIBLE", theme.sovietRed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(country.name.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.inkBlack)

                    Text(country.leaderName.isEmpty ? country.officialName : "\(country.leaderTitle) \(country.leaderName)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(theme.carbonCopy)
                }

                Spacer()

                Text(country.politicalBloc.displayName.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(blocColor)
                    .cornerRadius(2)
            }

            Rectangle()
                .fill(theme.bronzeGold.opacity(0.4))
                .frame(height: 1)
                .padding(.vertical, 8)

            HStack(spacing: 16) {
                statColumn(
                    label: "RELATIONS",
                    value: "\(country.relationshipScore > 0 ? "+" : "")\(country.relationshipScore)",
                    color: relationshipColor
                )
                statColumn(
                    label: "TRADE VOL.",
                    value: "\(country.tradeVolume)",
                    color: theme.inkBlack
                )
                statColumn(
                    label: "ECON. POWER",
                    value: "\(country.economicPower)",
                    color: theme.inkBlack
                )
                statColumn(
                    label: "COMPAT.",
                    value: compatibility.label,
                    color: compatibility.color
                )
            }

            if isEmbargoed {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 9))
                        .foregroundColor(theme.sovietRed)
                    Text("TRADE EMBARGO IN EFFECT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.3)
                        .foregroundColor(theme.sovietRed)
                }
                .padding(.top, 8)
            } else if activeAgreementCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 9))
                        .foregroundColor(theme.bronzeGold)
                    Text("\(activeAgreementCount) active agreement\(activeAgreementCount == 1 ? "" : "s")")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(theme.carbonCopy)
                }
                .padding(.top, 8)
            }

            if canNegotiate {
                Button(action: onNegotiate) {
                    Text("NEGOTIATE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(theme.approvedGreen)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            } else {
                Text(isEmbargoed ? "EMBARGO BLOCKS NEGOTIATION" : "RELATIONS TOO HOSTILE FOR TRADE")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(theme.sovietRed)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
        }
        .padding(14)
        .background(theme.cardstock)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func statColumn(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(theme.carbonCopy)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}
