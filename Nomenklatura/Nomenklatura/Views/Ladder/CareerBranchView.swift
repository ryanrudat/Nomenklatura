//
//  CareerBranchView.swift
//  Nomenklatura
//
//  Career path branching choice screen
//

import SwiftUI
import SwiftData

struct CareerBranchView: View {
    let currentPosition: LadderPosition
    let capitalPath: LadderPosition
    let regionalPath: LadderPosition
    let onSelect: (CareerTrack) -> Void
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTrack: CareerTrack?
    @State private var showingConfirmation = false

    var body: some View {
        ZStack {
            // Background
            theme.schemeDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(theme.sovietRed)
                        .frame(height: 3)

                    VStack(spacing: 10) {
                        Text("YOUR PATH DIVIDES")
                            .font(theme.heroFont)
                            .tracking(4)
                            .foregroundColor(theme.schemeText)

                        Text("Choose your route to power")
                            .font(theme.labelFont)
                            .tracking(2)
                            .foregroundColor(theme.accentGold)

                        Rectangle()
                            .fill(theme.accentGold)
                            .frame(width: 80, height: 2)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                }
                .background(theme.schemeCard)

                ScrollView {
                    VStack(spacing: 25) {
                        // Current position reminder
                        CurrentPositionCard(position: currentPosition)
                            .padding(.top, 20)

                        // The two paths
                        HStack(alignment: .top, spacing: 15) {
                            PathCard(
                                track: .capital,
                                position: capitalPath,
                                isSelected: selectedTrack == .capital,
                                onSelect: { selectedTrack = .capital }
                            )

                            PathCard(
                                track: .regional,
                                position: regionalPath,
                                isSelected: selectedTrack == .regional,
                                onSelect: { selectedTrack = .regional }
                            )
                        }
                        .padding(.horizontal, 15)

                        // Flavor text
                        VStack(spacing: 8) {
                            Text("This choice will shape your career")
                                .font(theme.bodyFontSmall)
                                .italic()
                                .foregroundColor(Color(hex: "888888"))

                            Text("Both paths lead to the top, but the journey differs")
                                .font(theme.tagFont)
                                .foregroundColor(Color(hex: "666666"))
                        }
                        .padding(.vertical, 10)

                        // Confirm button
                        if let track = selectedTrack {
                            ConfirmPathButton(track: track) {
                                showingConfirmation = true
                            }
                            .padding(.horizontal, 15)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer(minLength: 100)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .alert("Confirm Your Path", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                if let track = selectedTrack {
                    onSelect(track)
                    dismiss()
                }
            }
        } message: {
            if let track = selectedTrack {
                Text("You will join the \(track.displayName) track. This choice shapes your journey but all paths can lead to the top.")
            }
        }
    }
}

// MARK: - Current Position Card

private struct CurrentPositionCard: View {
    let position: LadderPosition
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 8) {
            Text("YOUR CURRENT POSITION")
                .font(theme.tagFont)
                .tracking(1)
                .foregroundColor(theme.inkLight)

            Text(position.title.uppercased())
                .font(theme.headerFont)
                .tracking(2)
                .foregroundColor(theme.accentGold)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(theme.schemeCard.opacity(0.5))
        .overlay(
            Rectangle()
                .stroke(theme.schemeBorder, lineWidth: 1)
        )
        .padding(.horizontal, 15)
    }
}

// MARK: - Path Card

private struct PathCard: View {
    let track: CareerTrack
    let position: LadderPosition
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    private var trackIcon: String {
        switch track {
        case .capital: return "building.columns.fill"
        case .regional: return "map.fill"
        case .shared: return "person.fill"
        }
    }

    private var trackColor: Color {
        switch track {
        case .capital: return theme.sovietRed
        case .regional: return theme.accentGold
        case .shared: return theme.inkGray
        }
    }

    private var flavorText: String {
        switch track {
        case .capital:
            return "Return to the center. Navigate the intrigues of Washington. Power is close, but so are your enemies."
        case .regional:
            return "Take a distant posting. Build your own power base far from prying eyes. Prove yourself worthy of recall."
        case .shared:
            return "The common path."
        }
    }

    private var advantages: [String] {
        switch track {
        case .capital:
            return [
                "Direct access to power",
                "Influence over policy",
                "Network with top officials",
                "Faster promotion (if you survive)"
            ]
        case .regional:
            return [
                "Build independent power base",
                "Control real resources",
                "Less scrutiny from above",
                "Prove competence through results"
            ]
        case .shared:
            return []
        }
    }

    private var dangers: [String] {
        switch track {
        case .capital:
            return [
                "Constant intrigue",
                "Powerful rivals",
                "One mistake can be fatal"
            ]
        case .regional:
            return [
                "Quota failures blamed on you",
                "Distance from patronage",
                "May be forgotten"
            ]
        case .shared:
            return []
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: trackIcon)
                        .font(.system(size: 24))
                        .foregroundColor(trackColor)

                    Text(track.displayName.uppercased())
                        .font(theme.headerFont)
                        .tracking(2)
                        .foregroundColor(theme.schemeText)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.accentGold)
                    }
                }

                Rectangle()
                    .fill(trackColor.opacity(0.5))
                    .frame(height: 2)

                // Position title
                Text(position.title)
                    .font(theme.labelFont)
                    .fontWeight(.bold)
                    .foregroundColor(trackColor)

                // Flavor text
                Text(flavorText)
                    .font(theme.bodyFontSmall)
                    .italic()
                    .foregroundColor(Color(hex: "AAAAAA"))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // Advantages
                VStack(alignment: .leading, spacing: 6) {
                    Text("ADVANTAGES")
                        .font(theme.tagFont)
                        .tracking(1)
                        .foregroundColor(.statHigh)

                    ForEach(advantages, id: \.self) { advantage in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 8))
                                .foregroundColor(.statHigh)
                                .padding(.top, 4)
                            Text(advantage)
                                .font(theme.tagFont)
                                .foregroundColor(Color(hex: "BBBBBB"))
                        }
                    }
                }
                .padding(.top, 5)

                // Dangers
                VStack(alignment: .leading, spacing: 6) {
                    Text("DANGERS")
                        .font(theme.tagFont)
                        .tracking(1)
                        .foregroundColor(.statLow)

                    ForEach(dangers, id: \.self) { danger in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.statLow)
                                .padding(.top, 4)
                            Text(danger)
                                .font(theme.tagFont)
                                .foregroundColor(Color(hex: "BBBBBB"))
                        }
                    }
                }
                .padding(.top, 5)
            }
            .padding(15)
            .background(isSelected ? trackColor.opacity(0.15) : theme.schemeCard)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? trackColor : theme.schemeBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Confirm Path Button

private struct ConfirmPathButton: View {
    let track: CareerTrack
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))

                Text("TAKE THE \(track.displayName.uppercased()) PATH")
                    .font(theme.labelFont)
                    .tracking(2)
            }
            .foregroundColor(theme.sovietRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.accentGold)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let campaign = CampaignLoader.shared.getColdWarCampaign()
    let current = campaign.ladder.first { $0.index == 1 && $0.track == .shared }!
    let capitalPath = campaign.ladder.first { $0.index == 2 && $0.track == .capital }!
    let regional = campaign.ladder.first { $0.index == 2 && $0.track == .regional }!

    return CareerBranchView(
        currentPosition: current,
        capitalPath: capitalPath,
        regionalPath: regional
    ) { track in
        print("Selected: \(track)")
    }
    .environment(\.theme, ColdWarTheme())
}
