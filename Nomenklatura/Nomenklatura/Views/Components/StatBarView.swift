//
//  StatBarView.swift
//  Nomenklatura
//
//  Stat bar component with color-coded fill
//

import SwiftUI

struct StatBarView: View {
    let label: String
    let value: Int
    let showLabel: Bool
    let compact: Bool
    let statKey: String?
    let showInfoButton: Bool
    @Environment(\.theme) var theme
    @State private var showingInfo = false

    init(label: String, value: Int, showLabel: Bool = true, compact: Bool = false, statKey: String? = nil, showInfoButton: Bool = true) {
        self.label = label
        self.value = value
        self.showLabel = showLabel
        self.compact = compact
        self.statKey = statKey
        self.showInfoButton = showInfoButton
    }

    private var statLevel: StatLevel {
        switch value {
        case 70...: return .high
        case 40..<70: return .medium
        default: return .low
        }
    }

    private var barColor: Color {
        switch statLevel {
        case .high: return .statHigh
        case .medium: return .statMedium
        case .low: return .statLow
        }
    }

    private var statDescription: StatDescription? {
        guard let key = statKey else { return nil }
        return StatDescriptions.description(for: key)
    }

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            if showLabel {
                HStack(spacing: 4) {
                    Text(label)
                        .font(compact ? theme.tagFont : theme.bodyFontSmall)
                        .foregroundColor(theme.inkBlack)

                    // Info button
                    if showInfoButton && statDescription != nil {
                        Button {
                            showingInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: compact ? 10 : 12))
                                .foregroundColor(theme.inkLight)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minWidth: compact ? 70 : 110, alignment: .leading)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "E8E4D9"))

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geometry.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: compact ? 6 : 8)
            .frame(width: compact ? 80 : 120)

            Text("\(value)")
                .font(theme.statFont)
                .foregroundColor(theme.inkBlack)
                .frame(width: 30, alignment: .trailing)
        }
        .sheet(isPresented: $showingInfo) {
            if let desc = statDescription {
                StatInfoSheet(stat: desc, currentValue: value)
            }
        }
    }
}

// MARK: - Compact Stat Row for Status Bar

struct CompactStatView: View {
    let label: String
    let value: Int
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color(hex: "AAAAAA"))

            Text("\(value)")
                .font(theme.statFont)
                .foregroundColor(theme.schemeText)
        }
    }
}

// MARK: - Personal Stats Bar (appears at top of Desk)

struct PersonalStatsBar: View {
    let standing: Int
    let patronFavor: Int
    let network: Int
    let rivalThreat: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 0) {
            CompactStatView(label: "Standing", value: standing)
                .frame(maxWidth: .infinity)
            CompactStatView(label: "Favor", value: patronFavor)
                .frame(maxWidth: .infinity)
            CompactStatView(label: "Network", value: network)
                .frame(maxWidth: .infinity)
            CompactStatView(label: "Threat", value: rivalThreat)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(Color(hex: "3A3A3A"))
    }
}

#Preview("Stat Bar") {
    VStack(spacing: 20) {
        StatBarView(label: "Stability", value: 75, statKey: "stability")
        StatBarView(label: "Food Supply", value: 30, statKey: "foodSupply")
        StatBarView(label: "Treasury", value: 55, statKey: "treasury")
    }
    .padding()
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}

#Preview("Personal Stats Bar") {
    PersonalStatsBar(standing: 47, patronFavor: 62, network: 31, rivalThreat: 55)
        .environment(\.theme, ColdWarTheme())
}
