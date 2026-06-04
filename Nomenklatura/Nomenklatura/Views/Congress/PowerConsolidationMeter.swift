//
//  PowerConsolidationMeter.swift
//  Nomenklatura
//
//  Horizontal meter visualizing the player's power consolidation score
//  across social / economic / political / institutional thresholds.
//  Extracted from the legacy LawsView during the Wave 2 dead-code cleanup
//  so the live PolicySlotsView (which is the only consumer) can keep
//  rendering it.
//

import SwiftUI

struct PowerConsolidationMeter: View {
    let score: Int
    @Environment(\.theme) var theme

    private var tier: ChairmanshipTier {
        ChairmanshipTier.from(score: score)
    }

    private var meterColor: Color {
        switch tier {
        case .supremeChairman: return theme.sovietRed
        case .theCore: return theme.accentGold
        case .paramountChairman: return .statMedium
        case .firstAmongEquals: return theme.bronzeGold
        case .compromiseChairman: return theme.inkGray
        }
    }

    private var powerLevel: String {
        tier.displayName.uppercased()
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("POWER CONSOLIDATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text(powerLevel)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(meterColor)

                Text("\(score)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(meterColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.parchmentDark)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(meterColor)
                        .frame(width: geometry.size.width * CGFloat(score) / 100)

                    // Threshold markers at the chairmanship-tier band edges
                    ForEach([25, 45, 65, 85], id: \.self) { threshold in
                        Rectangle()
                            .fill(theme.inkLight.opacity(0.5))
                            .frame(width: 1)
                            .offset(x: geometry.size.width * CGFloat(threshold) / 100)
                    }
                }
            }
            .frame(height: 8)

            // Threshold labels
            HStack {
                Text("Social")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)

                Spacer()

                Text("Economic")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)

                Spacer()

                Text("Political")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)

                Spacer()

                Text("Institutional")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)
            }
        }
        .padding(12)
        .background(theme.parchment)
        .overlay(
            Rectangle()
                .stroke(meterColor.opacity(0.3), lineWidth: 1)
        )
    }
}
