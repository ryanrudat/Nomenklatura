//
//  BureauHubSection.swift
//  Nomenklatura
//
//  Bureau Hub section for LedgerView - shows all 6 bureaus with access status
//  and track affinity progress. Provides natural paths to bureau access through
//  affinity building, patron connections, and position progression.
//

import SwiftUI
import SwiftData

struct BureauHubSection: View {
    @Bindable var game: Game
    let onBureauTap: (ExpandedCareerTrack) -> Void

    @Environment(\.theme) var theme

    // The 6 specialized bureaus
    private let bureaus: [ExpandedCareerTrack] = [
        .partyApparatus,
        .stateMinistry,
        .securityServices,
        .foreignAffairs,
        .economicPlanning,
        .militaryPolitical
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Text("BUREAUS")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(theme.sovietRed)

                Spacer()

                // Track commitment status
                if let track = game.currentCommittedTrack {
                    Text("Committed: \(track.shortName)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.accentGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(theme.parchmentDark)
                        .cornerRadius(4)
                }
            }

            // Bureau cards grid (2 columns for mobile)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(bureaus, id: \.rawValue) { bureau in
                    BureauAccessCard(
                        bureau: bureau,
                        game: game,
                        accessStatus: getAccessStatus(for: bureau),
                        onTap: { onBureauTap(bureau) }
                    )
                }
            }

            // Affinity explanation (if player has no affinity yet)
            if !hasAnyAffinity {
                Text("Your actions build expertise in different areas. Gain 25+ affinity to unlock bureau access.")
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(theme.inkLight)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private var hasAnyAffinity: Bool {
        let scores = game.trackAffinityScores
        return scores.partyApparatus + scores.stateMinistry + scores.securityServices +
               scores.foreignAffairs + scores.economicPlanning + scores.militaryPolitical > 0
    }

    /// Determine access status for a bureau
    private func getAccessStatus(for bureau: ExpandedCareerTrack) -> BureauAccessStatus {
        let affinity = getAffinity(for: bureau)

        // 1. Committed track - Full access
        if game.currentCommittedTrack == bureau {
            return .fullAccess(reason: "Your career track")
        }

        // 2. Current position is in this track - Full access
        let posTrack = game.currentExpandedTrack
        if let currentTrack = ExpandedCareerTrack(rawValue: posTrack),
           currentTrack == bureau {
            return .fullAccess(reason: "Current position")
        }

        // 3. Patron is associated with this bureau
        if let patron = game.patron,
           patronIsAssociatedWith(bureau: bureau, patron: patron) {
            return .limitedAccess(reason: "Patron connection", affinity: affinity)
        }

        // 4. High affinity (>= 25) - Limited access unlocked
        if affinity >= 25 {
            return .limitedAccess(reason: "Expertise recognized", affinity: affinity)
        }

        // 5. Some affinity - Locked but progressing
        if affinity > 0 {
            return .locked(affinity: affinity, neededForUnlock: 25)
        }

        // 6. No affinity - Locked
        return .locked(affinity: 0, neededForUnlock: 25)
    }

    private func getAffinity(for bureau: ExpandedCareerTrack) -> Int {
        let scores = game.trackAffinityScores
        switch bureau {
        case .partyApparatus: return scores.partyApparatus
        case .stateMinistry: return scores.stateMinistry
        case .securityServices: return scores.securityServices
        case .foreignAffairs: return scores.foreignAffairs
        case .economicPlanning: return scores.economicPlanning
        case .militaryPolitical: return scores.militaryPolitical
        case .shared, .regional: return 0
        }
    }

    private func patronIsAssociatedWith(bureau: ExpandedCareerTrack, patron: GameCharacter) -> Bool {
        // Check patron's position track
        if let patronTrack = patron.positionTrack {
            return patronTrack == bureau.rawValue
        }
        return false
    }
}

// MARK: - Bureau Access Status

enum BureauAccessStatus {
    case fullAccess(reason: String)
    case limitedAccess(reason: String, affinity: Int)
    case locked(affinity: Int, neededForUnlock: Int)

    var isAccessible: Bool {
        switch self {
        case .fullAccess, .limitedAccess:
            return true
        case .locked:
            return false
        }
    }
}

// MARK: - Bureau Access Card

struct BureauAccessCard: View {
    let bureau: ExpandedCareerTrack
    let game: Game
    let accessStatus: BureauAccessStatus
    let onTap: () -> Void

    @Environment(\.theme) var theme

    var body: some View {
        Button(action: {
            if accessStatus.isAccessible {
                onTap()
            }
        }) {
            VStack(spacing: 6) {
                // Bureau icon and name
                HStack(spacing: 8) {
                    Image(systemName: bureau.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)

                    Text(bureau.shortName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textColor)

                    Spacer()

                    // Status indicator
                    accessIndicator
                }

                // Affinity progress bar (if not full access)
                if case .locked(let affinity, let needed) = accessStatus {
                    ProgressView(value: Double(affinity), total: Double(needed))
                        .tint(theme.accentGold)
                        .scaleEffect(y: 0.5)

                    Text("\(affinity)/\(needed) affinity")
                        .font(.system(size: 8))
                        .foregroundColor(theme.inkLight)
                }

                // Access reason
                Text(statusText)
                    .font(.system(size: 9, design: .serif))
                    .foregroundColor(theme.inkLight)
                    .lineLimit(1)
            }
            .padding(10)
            .background(cardBackground)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(accessStatus.isAccessible ? 1.0 : 0.7)
    }

    private var iconColor: Color {
        switch accessStatus {
        case .fullAccess:
            return theme.accentGold
        case .limitedAccess:
            return theme.sovietRed
        case .locked:
            return theme.inkLight
        }
    }

    private var textColor: Color {
        switch accessStatus {
        case .fullAccess, .limitedAccess:
            return theme.inkBlack
        case .locked:
            return theme.inkLight
        }
    }

    private var cardBackground: Color {
        switch accessStatus {
        case .fullAccess:
            return theme.parchmentDark.opacity(0.8)
        case .limitedAccess:
            return theme.parchment.opacity(0.8)
        case .locked:
            return theme.borderTan.opacity(0.3)
        }
    }

    private var borderColor: Color {
        switch accessStatus {
        case .fullAccess:
            return theme.accentGold
        case .limitedAccess:
            return theme.sovietRed.opacity(0.5)
        case .locked:
            return theme.borderTan
        }
    }

    @ViewBuilder
    private var accessIndicator: some View {
        switch accessStatus {
        case .fullAccess:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(theme.accentGold)
                .font(.system(size: 14))
        case .limitedAccess:
            Image(systemName: "eye.fill")
                .foregroundColor(theme.sovietRed)
                .font(.system(size: 12))
        case .locked:
            Image(systemName: "lock.fill")
                .foregroundColor(theme.inkLight)
                .font(.system(size: 12))
        }
    }

    private var statusText: String {
        switch accessStatus {
        case .fullAccess(let reason):
            return reason
        case .limitedAccess(let reason, _):
            return reason
        case .locked:
            return "Build expertise to unlock"
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.currentPositionIndex = 3
    container.mainContext.insert(game)

    return ScrollView {
        BureauHubSection(
            game: game,
            onBureauTap: { bureau in
                print("Tapped: \(bureau.displayName)")
            }
        )
        .padding()
    }
    .background(Color(hex: "F4F1E8"))
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
