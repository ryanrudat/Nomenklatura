//
//  EconomicForecastSheet.swift
//  Nomenklatura
//
//  Pre-turn forecast surfacing what will happen IF YOU DO NOTHING next
//  turn (treasury / food / stability / industrial deltas), the top
//  contributors driving the projected treasury change, and 3-5 lever
//  recommendations the Chairman could act on right now.
//
//  Read-only by design — tapping a lever card just dismisses the sheet.
//  The actual lever execution lives in the relevant tab (Sectors,
//  Trade, etc.), so this view only points at WHERE to go.
//

import SwiftUI

struct EconomicForecastSheet: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    private var forecast: EconomicForecast {
        EconomyService.shared.predictNextTurn(for: game)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ifYouDoNothingSection
                    Divider().padding(.vertical, 12)
                    whySection
                    Divider().padding(.vertical, 12)
                    ifYouActSection
                    Spacer(minLength: 30)
                    Text("PROJECTIONS ARE NOT GUARANTEES.")
                        .font(theme.tagFont)
                        .tracking(2)
                        .foregroundColor(theme.inkLight.opacity(0.5))
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(theme.parchment)
            .navigationTitle("NEXT TURN FORECAST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.stampRed)
                }
            }
        }
    }

    // MARK: - "If You Do Nothing" Section

    @ViewBuilder
    private var ifYouDoNothingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("IF YOU DO NOTHING")
            VStack(spacing: 4) {
                ForEach(forecast.stats) { stat in
                    statRow(stat)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(theme.parchmentDark)
        }
    }

    private func statRow(_ stat: ForecastStatLine) -> some View {
        HStack(spacing: 12) {
            Text(stat.label.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkBlack)
                .frame(width: 90, alignment: .leading)

            Image(systemName: deltaIcon(stat.projectedDelta))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(deltaColor(stat.projectedDelta))

            Text(deltaString(stat.projectedDelta))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(deltaColor(stat.projectedDelta))

            Spacer()

            Text("\(stat.currentValue) → \(stat.projectedValue)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.inkGray)
        }
    }

    // MARK: - "Why" Section

    @ViewBuilder
    private var whySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("WHY")
            if forecast.contributors.isEmpty {
                Text("No significant treasury movement this turn.")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkLight)
                    .italic()
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(theme.parchmentDark)
            } else {
                VStack(spacing: 4) {
                    ForEach(forecast.contributors) { c in
                        contributorRow(c)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(theme.parchmentDark)
            }
        }
    }

    private func contributorRow(_ c: ForecastContributorLine) -> some View {
        HStack(spacing: 10) {
            Text("•")
                .font(.system(size: 14))
                .foregroundColor(theme.inkGray)
            Text(c.label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(theme.inkBlack)
            Spacer()
            Text(deltaString(c.amount))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(deltaColor(c.amount))
        }
    }

    // MARK: - "If You Act" Section

    @ViewBuilder
    private var ifYouActSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("IF YOU ACT")
            if forecast.levers.isEmpty {
                Text("No urgent levers required. Economy is stable.")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkLight)
                    .italic()
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(theme.parchmentDark)
            } else {
                VStack(spacing: 8) {
                    ForEach(forecast.levers) { lever in
                        leverCard(lever)
                    }
                }
            }
        }
    }

    private func leverCard(_ lever: ForecastLeverRecommendation) -> some View {
        Button {
            // Read-only sheet — tapping just dismisses so the player can navigate.
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(urgencyColor(lever.urgency))
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(urgencyLabel(lever.urgency))
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(urgencyColor(lever.urgency))
                        Spacer()
                    }
                    Text(lever.title)
                        .font(theme.labelFont)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.inkBlack)
                        .multilineTextAlignment(.leading)
                    Text(lever.subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.inkGray)
                    Text(lever.projectedEffect)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkBlack.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)
                .padding(.trailing, 12)

                Spacer()
            }
            .background(theme.parchmentDark)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .tracking(2)
            .foregroundColor(theme.stampRed)
            .padding(.bottom, 4)
    }

    private func deltaIcon(_ delta: Int) -> String {
        if delta > 0 { return "arrow.up.right" }
        if delta < 0 { return "arrow.down.right" }
        return "minus"
    }

    private func deltaColor(_ delta: Int) -> Color {
        if delta > 0 { return theme.approvedGreen }
        if delta < 0 { return theme.stampRed }
        return theme.inkGray
    }

    private func deltaString(_ delta: Int) -> String {
        if delta > 0 { return "+\(delta)" }
        if delta < 0 { return "\(delta)" }
        return "0"
    }

    private func urgencyColor(_ urgency: ForecastLeverRecommendation.Urgency) -> Color {
        switch urgency {
        case .critical:      return theme.stampRed
        case .advised:       return theme.accentGold
        case .opportunistic: return theme.approvedGreen
        }
    }

    private func urgencyLabel(_ urgency: ForecastLeverRecommendation.Urgency) -> String {
        switch urgency {
        case .critical:      return "CRITICAL"
        case .advised:       return "ADVISED"
        case .opportunistic: return "OPPORTUNITY"
        }
    }
}
