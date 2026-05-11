//
//  BureauCard.swift
//  Nomenklatura
//
//  Soviet propaganda-style bureau selection cards for the Ladder view.
//  Bold, visual cards that invite players to join a bureau.
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

    // Bureau-specific colors
    private var primaryColor: Color {
        ColdWarTheme.shared.bureauPrimary(for: track)
    }

    private var accentColor: Color {
        ColdWarTheme.shared.bureauAccent(for: track)
    }

    // Propaganda-style call to action
    private var ctaText: String {
        if isPlayerTrack {
            return "YOUR BUREAU"
        } else if affinityScore >= 25 {
            return "JOIN NOW"
        } else if affinityScore > 0 {
            return "BUILD AFFINITY"
        } else {
            return "EXPLORE"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Top color block with emblem
                ZStack {
                    // Background gradient
                    LinearGradient(
                        colors: [
                            primaryColor,
                            primaryColor.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Decorative rays (propaganda poster style)
                    if isPlayerTrack || isSelected {
                        propagandaRays
                    }

                    // Bureau emblem
                    VStack(spacing: 4) {
                        BureauEmblem(bureau: track, size: .medium)
                            .brightness(0.1)

                        // Bureau code
                        Text(ColdWarTheme.shared.bureauCode(for: track))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }

                    // "Your Bureau" badge
                    if isPlayerTrack {
                        VStack {
                            HStack {
                                Spacer()
                                Text("ACTIVE")
                                    .font(.system(size: 7, weight: .black, design: .monospaced))
                                    .foregroundColor(primaryColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(accentColor)
                                    .cornerRadius(2)
                                    .padding(4)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 90)
                .clipped()

                // Bottom info section
                VStack(spacing: 4) {
                    // Bureau name
                    Text(track.shortName)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkBlack)
                        .lineLimit(1)

                    // Affinity progress
                    if !isPlayerTrack {
                        affinityProgress
                    }

                    // CTA or status
                    Text(ctaText)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(isPlayerTrack ? accentColor : primaryColor)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    isPlayerTrack
                        ? primaryColor.opacity(0.1)
                        : (isSelected ? primaryColor.opacity(0.05) : theme.parchmentDark)
                )
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isPlayerTrack ? accentColor :
                            (isSelected ? primaryColor : theme.borderTan),
                        lineWidth: isPlayerTrack ? 2 : (isSelected ? 2 : 1)
                    )
            )
            .shadow(
                color: isSelected ? primaryColor.opacity(0.3) : .black.opacity(0.1),
                radius: isSelected ? 6 : 2,
                x: 0,
                y: isSelected ? 3 : 1
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Propaganda Rays

    private var propagandaRays: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 3, height: geo.size.height * 1.5)
                        .rotationEffect(.degrees(Double(i) * 22.5))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    // MARK: - Affinity Progress

    private var affinityProgress: some View {
        VStack(spacing: 2) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.borderTan)

                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(primaryColor)
                        .frame(width: geo.size.width * CGFloat(min(affinityScore, 25)) / 25.0)
                }
            }
            .frame(height: 4)

            // Score text
            HStack {
                Text("\(affinityScore)/25")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(theme.inkLight)
                Spacer()
            }
        }
    }
}

// MARK: - Large Bureau Poster Card (for selection screen)

/// Larger, more dramatic bureau card for dedicated selection views
struct BureauPosterCard: View {
    let track: ExpandedCareerTrack
    let game: Game
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    private var isCommitted: Bool {
        game.currentCommittedTrack == track
    }

    private var primaryColor: Color {
        ColdWarTheme.shared.bureauPrimary(for: track)
    }

    private var affinityScore: Int {
        game.trackAffinityScores.score(for: track)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Large header section
                ZStack {
                    // Background
                    LinearGradient(
                        colors: [primaryColor, primaryColor.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Propaganda rays
                    GeometryReader { geo in
                        ZStack {
                            ForEach(0..<12, id: \.self) { i in
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 4, height: geo.size.height * 2)
                                    .rotationEffect(.degrees(Double(i) * 15))
                            }
                        }
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.7)
                    }

                    // Content
                    VStack(spacing: 12) {
                        // Large emblem
                        BureauEmblem(bureau: track, size: .large)

                        // Bureau title
                        Text(ColdWarTheme.shared.bureauHeaderTitle(for: track))
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                        // Subtitle
                        Text(ColdWarTheme.shared.bureauSubtitle(for: track).uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.vertical, 20)
                }
                .frame(height: 180)

                // Bottom section
                VStack(spacing: 12) {
                    // Status
                    if isCommitted {
                        HStack {
                            StatusLight(.active, size: 10)
                            Text("YOUR BUREAU")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(primaryColor)
                        }
                    } else {
                        // Affinity
                        VStack(spacing: 4) {
                            Text("AFFINITY")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.inkLight)

                            CircularGauge(
                                value: Double(min(affinityScore, 25)) * 4,
                                label: "",
                                color: primaryColor,
                                size: 50
                            )
                        }
                    }

                    // CTA Button
                    Text(isCommitted ? "OPEN PORTAL" : (affinityScore >= 25 ? "COMMIT NOW" : "BUILD AFFINITY"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(primaryColor)
                        .cornerRadius(4)
                }
                .padding(16)
                .background(theme.parchment)
            }
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(primaryColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.currentPositionIndex = 3
    game.committedTrack = ExpandedCareerTrack.securityServices.rawValue
    container.mainContext.insert(game)

    let ladder = CampaignLoader.shared.getColdWarCampaign().ladder

    return ScrollView {
        VStack(spacing: 20) {
            // Small cards
            HStack(spacing: 12) {
                BureauCard(
                    track: .securityServices,
                    game: game,
                    ladder: ladder,
                    isSelected: false,
                    onTap: {}
                )
                BureauCard(
                    track: .economicPlanning,
                    game: game,
                    ladder: ladder,
                    isSelected: true,
                    onTap: {}
                )
                BureauCard(
                    track: .partyApparatus,
                    game: game,
                    ladder: ladder,
                    isSelected: false,
                    onTap: {}
                )
            }
            .padding(.horizontal)

            // Large poster card
            BureauPosterCard(
                track: .securityServices,
                game: game,
                onSelect: {}
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    .background(Color(hex: "E8E4D9"))
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
