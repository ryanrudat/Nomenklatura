//
//  BureauIdentityBadge.swift
//  Nomenklatura
//
//  Prominent header badge showing the player's committed bureau identity.
//  Displayed on the Desk view when the player has committed to a core bureau.
//

import SwiftUI
import SwiftData

// MARK: - Bureau Identity Badge

/// A prominent badge showing the player's bureau identity, rank, and department
/// Tapping navigates to the bureau's portal with available actions
struct BureauIdentityBadge: View {
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

    private var bureauPrimaryColor: Color {
        guard let bureau = committedBureau else { return FiftiesColors.leatherBrown }
        return BureauColors.primary(for: bureau)
    }

    private var bureauAccentColor: Color {
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

    private var bureauIcon: String {
        guard let bureau = committedBureau else { return "building.columns" }
        return BureauColors.icon(for: bureau)
    }

    private var playerRankTitle: String {
        // Use position index to determine generic rank
        let positionIndex = game.currentPositionIndex

        switch positionIndex {
        case 0...1: return "JUNIOR OFFICIAL"
        case 2...3: return "SENIOR OFFICIAL"
        case 4...5: return "DEPARTMENT HEAD"
        case 6: return "DEPUTY DIRECTOR"
        case 7: return "DIRECTOR"
        case 8: return "BUREAU CHIEF"
        default: return "OFFICIAL"
        }
    }

    private var clearanceLevel: Int {
        min(game.currentPositionIndex + 1, 8)
    }

    // MARK: - Body

    var body: some View {
        if isCorebureau {
            Button(action: { showingBureauPortal = true }) {
                VStack(spacing: 0) {
                    // Top color stripe
                    Rectangle()
                        .fill(bureauPrimaryColor)
                        .frame(height: 4)

                    // Main badge content
                    HStack(spacing: 12) {
                        // Bureau icon in circle
                        bureauIconView

                        // Bureau info
                        VStack(alignment: .leading, spacing: 2) {
                            // Bureau title
                            Text(bureauTitle)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(bureauPrimaryColor)

                            // Bureau subtitle
                            Text(bureauSubtitle)
                                .font(.system(size: 9, design: .serif))
                                .foregroundColor(FiftiesColors.fadedInk)

                            // Player rank
                            Text(playerRankTitle)
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundColor(FiftiesColors.typewriterInk)
                        }

                        Spacer()

                        // Department code badge with chevron
                        HStack(spacing: 8) {
                            departmentCodeBadge

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(bureauPrimaryColor.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(FiftiesColors.manillaFolder)

                    // Bottom accent stripe (thinner)
                    Rectangle()
                        .fill(bureauPrimaryColor.opacity(0.3))
                        .frame(height: 2)
                }
                .background(FiftiesColors.manillaFolder)
                .cornerRadius(4)
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(bureauPrimaryColor.opacity(0.2), lineWidth: 1)
                )
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
                                    .foregroundColor(bureauPrimaryColor)
                                }
                            }
                        }
                }
            }
        }
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

    // MARK: - Subviews

    private var bureauIconView: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(bureauPrimaryColor.opacity(0.3), lineWidth: 2)
                .frame(width: 46, height: 46)

            // Inner circle
            Circle()
                .fill(bureauPrimaryColor.opacity(0.1))
                .frame(width: 40, height: 40)

            // Icon
            Image(systemName: bureauIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(bureauPrimaryColor)
        }
    }

    private var departmentCodeBadge: some View {
        VStack(spacing: 2) {
            // Bureau code
            Text(bureauCode)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(bureauPrimaryColor)

            // "OFFICIAL" label
            Text("OFFICIAL")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(FiftiesColors.fadedInk)

            // Clearance level
            HStack(spacing: 2) {
                Text("LVL")
                    .font(.system(size: 5, weight: .medium, design: .monospaced))
                Text("\(clearanceLevel)")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
            }
            .foregroundColor(FiftiesColors.carbonCopy)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .stroke(bureauPrimaryColor, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(bureauPrimaryColor.opacity(0.05))
        )
    }
}

// MARK: - Compact Version (for tighter spaces)

/// A more compact version of the bureau badge for constrained layouts
struct BureauIdentityBadgeCompact: View {
    let game: Game

    private var committedBureau: ExpandedCareerTrack? {
        game.currentCommittedTrack
    }

    private var isCorebureau: Bool {
        guard let bureau = committedBureau else { return false }
        return bureau == .securityServices ||
               bureau == .economicPlanning ||
               bureau == .partyApparatus
    }

    var body: some View {
        if isCorebureau, let bureau = committedBureau {
            HStack(spacing: 8) {
                // Icon
                Image(systemName: BureauColors.icon(for: bureau))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BureauColors.primary(for: bureau))

                // Code
                Text(BureauColors.code(for: bureau))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(BureauColors.primary(for: bureau))

                // Separator
                Rectangle()
                    .fill(BureauColors.primary(for: bureau).opacity(0.3))
                    .frame(width: 1, height: 14)

                // Subtitle
                Text(BureauColors.subtitle(for: bureau))
                    .font(.system(size: 9, design: .serif))
                    .foregroundColor(FiftiesColors.fadedInk)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(FiftiesColors.manillaFolder)
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(BureauColors.primary(for: bureau).opacity(0.2), lineWidth: 1)
            )
        }
    }
}
