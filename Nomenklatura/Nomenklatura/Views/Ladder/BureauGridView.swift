//
//  BureauGridView.swift
//  Nomenklatura
//
//  Grid of bureau cards showing the 3 core playable career tracks
//

import SwiftUI
import SwiftData

struct BureauGridView: View {
    @Bindable var game: Game
    let ladder: [LadderPosition]
    @Binding var selectedTrack: ExpandedCareerTrack?
    @Environment(\.theme) var theme

    // The 3 core playable bureaus
    private let coreBureaus: [ExpandedCareerTrack] = [
        .securityServices,
        .economicPlanning,
        .partyApparatus
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Text("CHOOSE YOUR BUREAU")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(theme.inkGray)

                Spacer()
            }
            .padding(.horizontal, 4)

            // Grid of bureau cards - 3 cards in a row
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(coreBureaus, id: \.rawValue) { bureau in
                    BureauCard(
                        track: bureau,
                        game: game,
                        ladder: ladder,
                        isSelected: selectedTrack == bureau,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedTrack == bureau {
                                    selectedTrack = nil  // Collapse if already selected
                                } else {
                                    selectedTrack = bureau  // Expand this track
                                }
                            }
                        }
                    )
                }
            }

            // Track affinity summary bar (Reigns-inspired) - only for 3 core bureaus
            if showAffinitySummary {
                CoreAffinitySummaryBar(game: game)
            }
        }
    }

    // Only show affinity summary if player has some affinity built up
    private var showAffinitySummary: Bool {
        let scores = game.trackAffinityScores
        let total = scores.securityServices + scores.economicPlanning + scores.partyApparatus
        return total > 0
    }
}

// MARK: - Core Affinity Summary Bar (3 playable bureaus only)

struct CoreAffinitySummaryBar: View {
    let game: Game
    @Environment(\.theme) var theme

    private var scores: TrackAffinityScores {
        game.trackAffinityScores
    }

    // Find the dominant track among core bureaus
    private var dominantCoreTrack: ExpandedCareerTrack? {
        let coreScores: [(ExpandedCareerTrack, Int)] = [
            (.securityServices, scores.securityServices),
            (.economicPlanning, scores.economicPlanning),
            (.partyApparatus, scores.partyApparatus)
        ]
        return coreScores.max(by: { $0.1 < $1.1 })?.0
    }

    var body: some View {
        VStack(spacing: 4) {
            // Divider label
            HStack {
                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 1)

                Text("BUREAU AFFINITY")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1)
                    .foregroundColor(theme.inkLight)
                    .fixedSize()

                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 1)
            }

            // Compact affinity bars for 3 core bureaus
            HStack(spacing: 16) {
                CoreAffinityMiniBar(
                    track: .securityServices,
                    score: scores.securityServices,
                    isDominant: dominantCoreTrack == .securityServices
                )
                CoreAffinityMiniBar(
                    track: .economicPlanning,
                    score: scores.economicPlanning,
                    isDominant: dominantCoreTrack == .economicPlanning
                )
                CoreAffinityMiniBar(
                    track: .partyApparatus,
                    score: scores.partyApparatus,
                    isDominant: dominantCoreTrack == .partyApparatus
                )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(theme.parchmentDark)
        .cornerRadius(6)
    }
}

struct CoreAffinityMiniBar: View {
    let track: ExpandedCareerTrack
    let score: Int
    let isDominant: Bool
    @Environment(\.theme) var theme

    // Normalized score (0-100, capped at 50 for display)
    private var normalizedHeight: CGFloat {
        CGFloat(min(score, 50)) / 50.0 * 24  // Max height 24pt
    }

    private var trackColor: Color {
        BureauColors.primary(for: track)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Bar
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.borderTan.opacity(0.5))
                    .frame(width: 20, height: 24)

                // Fill
                if score > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isDominant ? trackColor : trackColor.opacity(0.7))
                        .frame(width: 20, height: max(4, normalizedHeight))
                }
            }

            // Bureau code
            Text(BureauColors.code(for: track))
                .font(.system(size: 8, weight: isDominant ? .bold : .medium, design: .monospaced))
                .foregroundColor(isDominant ? trackColor : theme.inkLight)

            // Score
            Text("\(score)")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(theme.inkGray)
        }
    }
}

// MARK: - Legacy Affinity Summary Bar (all 6 bureaus - kept for compatibility)

struct AffinitySummaryBar: View {
    let game: Game
    @Environment(\.theme) var theme

    private var scores: TrackAffinityScores {
        game.trackAffinityScores
    }

    // Find the dominant track
    private var dominantTrack: ExpandedCareerTrack? {
        scores.dominantTrack
    }

    var body: some View {
        VStack(spacing: 4) {
            // Divider label
            HStack {
                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 1)

                Text("TRACK AFFINITY")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1)
                    .foregroundColor(theme.inkLight)
                    .fixedSize()

                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 1)
            }

            // Compact affinity bars
            HStack(spacing: 6) {
                AffinityMiniBar(track: .partyApparatus, score: scores.partyApparatus, isDominant: dominantTrack == .partyApparatus)
                AffinityMiniBar(track: .stateMinistry, score: scores.stateMinistry, isDominant: dominantTrack == .stateMinistry)
                AffinityMiniBar(track: .securityServices, score: scores.securityServices, isDominant: dominantTrack == .securityServices)
                AffinityMiniBar(track: .foreignAffairs, score: scores.foreignAffairs, isDominant: dominantTrack == .foreignAffairs)
                AffinityMiniBar(track: .economicPlanning, score: scores.economicPlanning, isDominant: dominantTrack == .economicPlanning)
                AffinityMiniBar(track: .militaryPolitical, score: scores.militaryPolitical, isDominant: dominantTrack == .militaryPolitical)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(theme.parchmentDark)
        .cornerRadius(6)
    }
}

struct AffinityMiniBar: View {
    let track: ExpandedCareerTrack
    let score: Int
    let isDominant: Bool
    @Environment(\.theme) var theme

    // Normalized score (0-100, capped at 50 for display)
    private var normalizedHeight: CGFloat {
        CGFloat(min(score, 50)) / 50.0 * 20  // Max height 20pt
    }

    var body: some View {
        VStack(spacing: 2) {
            // Bar
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.borderTan.opacity(0.5))
                    .frame(width: 12, height: 20)

                // Fill
                if score > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isDominant ? theme.accentGold : theme.sovietRed.opacity(0.7))
                        .frame(width: 12, height: max(4, normalizedHeight))
                }
            }

            // Short code
            Text(track.shortName.prefix(2))
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(isDominant ? theme.accentGold : theme.inkLight)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.currentPositionIndex = 2
    container.mainContext.insert(game)

    let ladder = CampaignLoader.shared.getColdWarCampaign().ladder

    return VStack {
        BureauGridView(
            game: game,
            ladder: ladder,
            selectedTrack: .constant(.securityServices)
        )
        .padding()
    }
    .background(Color(hex: "F4F1E8"))
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
