//
//  StatInfoSheet.swift
//  Nomenklatura
//
//  Detailed stat explanation sheet
//

import SwiftUI

struct StatInfoSheet: View {
    let stat: StatDescription
    let currentValue: Int?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme

    init(stat: StatDescription, currentValue: Int? = nil) {
        self.stat = stat
        self.currentValue = currentValue
    }

    private var valueColor: Color {
        guard let value = currentValue else { return theme.inkBlack }
        if value >= 70 { return .statHigh }
        if value <= 30 { return .statLow }
        return .statMedium
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with icon and current value
                    HStack(spacing: 15) {
                        Image(systemName: stat.icon)
                            .font(.system(size: 32))
                            .foregroundColor(stat.isPersonal ? theme.accentGold : theme.sovietRed)
                            .frame(width: 50)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(stat.name.uppercased())
                                .font(theme.headerFont)
                                .tracking(2)
                                .foregroundColor(theme.inkBlack)

                            if let value = currentValue {
                                HStack(spacing: 8) {
                                    Text("Current:")
                                        .font(theme.labelFont)
                                        .foregroundColor(theme.inkGray)
                                    Text("\(value)")
                                        .font(theme.statFont)
                                        .foregroundColor(valueColor)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 10)

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHAT IT MEANS")
                            .font(theme.labelFont)
                            .tracking(1)
                            .foregroundColor(theme.sovietRed)

                        Text(stat.description)
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)
                            .lineSpacing(4)
                    }

                    // Warning section (low values)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.statLow)
                            Text("DANGER ZONE")
                                .font(theme.labelFont)
                                .tracking(1)
                                .foregroundColor(.statLow)
                        }

                        Text(stat.lowWarning)
                            .font(theme.bodyFontSmall)
                            .foregroundColor(theme.inkGray)
                            .lineSpacing(4)
                    }
                    .padding(12)
                    .background(Color.statLow.opacity(0.1))
                    .overlay(
                        Rectangle()
                            .stroke(Color.statLow.opacity(0.3), lineWidth: 1)
                    )

                    // Benefit section (high values)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.statHigh)
                            Text("STRONG POSITION")
                                .font(theme.labelFont)
                                .tracking(1)
                                .foregroundColor(.statHigh)
                        }

                        Text(stat.highBenefit)
                            .font(theme.bodyFontSmall)
                            .foregroundColor(theme.inkGray)
                            .lineSpacing(4)
                    }
                    .padding(12)
                    .background(Color.statHigh.opacity(0.1))
                    .overlay(
                        Rectangle()
                            .stroke(Color.statHigh.opacity(0.3), lineWidth: 1)
                    )

                    // Tips section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(theme.accentGold)
                            Text("HOW TO IMPROVE")
                                .font(theme.labelFont)
                                .tracking(1)
                                .foregroundColor(theme.accentGold)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(stat.tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(theme.bronzeGold)
                                        .padding(.top, 5)

                                    Text(tip)
                                        .font(theme.bodyFontSmall)
                                        .foregroundColor(theme.inkBlack)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(theme.accentGold.opacity(0.1))
                    .overlay(
                        Rectangle()
                            .stroke(theme.accentGold.opacity(0.3), lineWidth: 1)
                    )

                    Spacer()
                }
                .padding(20)
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.sovietRed)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StatInfoSheet(
        stat: StatDescriptions.nationalStats[0],
        currentValue: 45
    )
    .environment(\.theme, ColdWarTheme())
}
