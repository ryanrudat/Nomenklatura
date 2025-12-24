//
//  BureauCard.swift
//  Nomenklatura
//
//  Soviet-style bureau badge card for the Ladder view
//  Shows player's position/status in each career track
//

import SwiftUI
import SwiftData

struct BureauCard: View {
    let track: ExpandedCareerTrack
    let game: Game
    let ladder: [LadderPosition]
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.theme) var theme

    // Check if player is on this track
    private var isPlayerTrack: Bool {
        game.currentCommittedTrack == track
    }

    // Check if player has held positions in this track
    private var hasHeldPosition: Bool {
        game.trackApexPositionsHeld.contains(track.rawValue)
    }

    // Get player's affinity score for this track
    private var affinityScore: Int {
        game.trackAffinityScores.score(for: track)
    }

    // Get player's status text in this track
    private var playerStatusText: String {
        if isPlayerTrack {
            // Find current position title in this track
            if let position = ladder.first(where: {
                $0.expandedTrack == track && $0.index == game.currentPositionIndex
            }) {
                return position.title.uppercased()
            }
            return "ASSIGNED"
        } else if hasHeldPosition {
            return "PREVIOUS"
        } else if affinityScore >= 15 {
            return "EMERGING"
        } else {
            return "UNASSIGNED"
        }
    }

    private var statusColor: Color {
        if isPlayerTrack {
            return theme.accentGold
        } else if hasHeldPosition {
            return theme.inkGray
        } else if affinityScore >= 15 {
            return Color(hex: "4A90A4")  // Teal for emerging
        } else {
            return theme.inkLight
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Bureau icon - Soviet badge style
                ZStack {
                    // Badge background
                    Circle()
                        .fill(isSelected ? theme.sovietRed : theme.schemeCard)
                        .frame(width: 50, height: 50)

                    // Gold border if player's track
                    if isPlayerTrack {
                        Circle()
                            .stroke(theme.accentGold, lineWidth: 2)
                            .frame(width: 54, height: 54)
                    }

                    Image(systemName: track.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .white : (isPlayerTrack ? theme.accentGold : theme.inkGray))
                }

                // Bureau short name
                Text(track.shortName)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(isSelected ? theme.sovietRed : theme.inkBlack)

                // Status text
                Text(playerStatusText)
                    .font(.system(size: 8, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(statusColor)
                    .lineLimit(1)

                // Affinity score (if > 0)
                if affinityScore > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 8))
                        Text("\(affinityScore)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(theme.inkGray)
                }

                // Previous indicator star
                if hasHeldPosition && !isPlayerTrack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(theme.bronzeGold)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? theme.sovietRed.opacity(0.1) : theme.parchmentDark)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? theme.sovietRed :
                            (isPlayerTrack ? theme.accentGold : theme.borderTan),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.currentPositionIndex = 3
    container.mainContext.insert(game)

    let ladder = CampaignLoader.shared.getColdWarCampaign().ladder

    return VStack(spacing: 20) {
        // Normal state
        HStack {
            BureauCard(
                track: .partyApparatus,
                game: game,
                ladder: ladder,
                isSelected: false,
                onTap: {}
            )
            BureauCard(
                track: .securityServices,
                game: game,
                ladder: ladder,
                isSelected: true,
                onTap: {}
            )
            BureauCard(
                track: .foreignAffairs,
                game: game,
                ladder: ladder,
                isSelected: false,
                onTap: {}
            )
        }
        .padding()
    }
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
