//
//  BureauCredentialBadge.swift
//  Nomenklatura
//
//  Official-looking credential/ID card showing the player's bureau identity.
//  Soviet-inspired government aesthetic with seals, stamps, and visual hierarchy.
//

import SwiftUI
import SwiftData

// MARK: - Bureau Credential Badge

/// Visual credential card showing bureau identity - tappable to access bureau portal
struct BureauCredentialBadge: View {
    let game: Game
    @State private var showingBureauPortal = false

    // MARK: - Computed Properties

    private var committedBureau: ExpandedCareerTrack? {
        game.currentCommittedTrack
    }

    private var isCorebureau: Bool {
        guard let bureau = committedBureau else { return false }
        return bureau == .securityServices ||
               bureau == .economicPlanning ||
               bureau == .partyApparatus
    }

    private var primaryColor: Color {
        guard let bureau = committedBureau else { return FiftiesColors.leatherBrown }
        return BureauColors.primary(for: bureau)
    }

    private var accentColor: Color {
        guard let bureau = committedBureau else { return FiftiesColors.brassGold }
        return BureauColors.accent(for: bureau)
    }

    private var bureauTitle: String {
        guard let bureau = committedBureau else { return "GOVERNMENT BUREAU" }
        return BureauColors.headerTitle(for: bureau)
    }

    private var bureauSubtitle: String {
        guard let bureau = committedBureau else { return "Official" }
        return BureauColors.subtitle(for: bureau)
    }

    private var bureauCode: String {
        guard let bureau = committedBureau else { return "GOV" }
        return BureauColors.code(for: bureau)
    }

    private var playerRankTitle: String {
        let positionIndex = game.currentPositionIndex
        switch positionIndex {
        case 0...1: return "Junior Official"
        case 2...3: return "Senior Official"
        case 4...5: return "Department Head"
        case 6: return "Deputy Director"
        case 7: return "Director"
        case 8: return "Bureau Chief"
        default: return "Official"
        }
    }

    private var clearanceLevel: Int {
        min(game.currentPositionIndex + 1, 8)
    }

    // MARK: - Body

    var body: some View {
        if isCorebureau, let bureau = committedBureau {
            Button(action: { showingBureauPortal = true }) {
                credentialCard(bureau: bureau)
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showingBureauPortal) {
                NavigationStack {
                    bureauPortalView
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(action: { showingBureauPortal = false }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Desk")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(primaryColor)
                                }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Credential Card

    private func credentialCard(bureau: ExpandedCareerTrack) -> some View {
        VStack(spacing: 0) {
            // Top color bar with pattern
            ZStack {
                Rectangle()
                    .fill(primaryColor)

                // Decorative pattern
                HStack(spacing: 4) {
                    ForEach(0..<20, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 2)
                    }
                }
            }
            .frame(height: 8)

            // Main card content
            HStack(spacing: 0) {
                // Left side - Emblem and classification
                VStack(spacing: 8) {
                    // Bureau emblem
                    BureauEmblem(bureau: bureau, size: .large)

                    // Bureau code
                    Text(bureauCode)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(primaryColor)

                    // Classification stamp
                    Text("CLASSIFIED")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(primaryColor)
                        .cornerRadius(2)
                }
                .frame(width: 110)
                .padding(.vertical, 12)

                // Vertical divider
                Rectangle()
                    .fill(primaryColor.opacity(0.2))
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Right side - Details
                VStack(alignment: .leading, spacing: 6) {
                    // Bureau title
                    Text(bureauTitle)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(primaryColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    // Subtitle
                    Text(bureauSubtitle)
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(FiftiesColors.fadedInk)

                    Spacer()

                    // Rank
                    HStack {
                        Text("RANK:")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)
                        Text(playerRankTitle.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.typewriterInk)
                    }

                    // Clearance level visual
                    HStack {
                        Text("CLEARANCE:")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)

                        ClearanceBadge(level: clearanceLevel, color: primaryColor)
                    }

                    Spacer()

                    // Authorized stamp and tap hint
                    HStack {
                        BureauStamp("AUTHORIZED", color: primaryColor, rotation: -8)

                        Spacer()

                        // Tap indicator
                        HStack(spacing: 4) {
                            Text("ACCESS")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(primaryColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(
                    colors: [FiftiesColors.manillaFolder, FiftiesColors.agedPaper],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Bottom bar
            HStack {
                // Serial number style
                Text("NO. \(game.id.uuidString.prefix(8).uppercased())")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(primaryColor.opacity(0.6))

                Spacer()

                // Turn/date
                Text("TURN \(game.turnNumber)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(primaryColor.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(primaryColor.opacity(0.1))
        }
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(primaryColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Bureau Portal View

    @ViewBuilder
    private var bureauPortalView: some View {
        switch committedBureau {
        case .securityServices:
            SecurityPortalView(game: game)
        case .economicPlanning:
            EconomicPortalView(game: game)
        case .partyApparatus:
            PartyPortalView(game: game)
        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.currentPositionIndex = 4
    game.committedTrack = ExpandedCareerTrack.securityServices.rawValue
    container.mainContext.insert(game)

    return VStack(spacing: 20) {
        BureauCredentialBadge(game: game)
            .padding(.horizontal)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(hex: "E8E4D9"))
    .modelContainer(container)
}
