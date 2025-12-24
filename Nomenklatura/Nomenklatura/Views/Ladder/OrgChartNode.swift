//
//  OrgChartNode.swift
//  Nomenklatura
//
//  Individual position box for the organizational chart
//  Shows position title, holder(s), and player status
//

import SwiftUI

struct OrgChartNode: View {
    let position: LadderPosition
    let holders: [String]
    let isPlayerPosition: Bool
    let isAchieved: Bool
    let isOnPlayerTrack: Bool
    let isLocked: Bool
    var onTap: (() -> Void)? = nil

    @Environment(\.theme) var theme

    // Compact sizing for org chart grid
    private let nodeWidth: CGFloat = 90
    private let nodeHeight: CGFloat = 60

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 2) {
                // Track icon for specialized positions
                if position.expandedTrack != .shared && position.expandedTrack != .regional {
                    Image(systemName: position.expandedTrack.iconName)
                        .font(.system(size: 10))
                        .foregroundColor(trackColor)
                }

                // Position title (abbreviated for space)
                Text(abbreviatedTitle)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)

                // Holder info
                if isPlayerPosition {
                    PlayerBadge()
                } else if !holders.isEmpty {
                    Text(holders.first ?? "")
                        .font(.system(size: 8))
                        .foregroundColor(theme.inkGray)
                        .lineLimit(1)
                    if holders.count > 1 {
                        Text("+\(holders.count - 1) more")
                            .font(.system(size: 7))
                            .foregroundColor(theme.inkLight)
                    }
                } else {
                    Text("Vacant")
                        .font(.system(size: 8))
                        .foregroundColor(theme.accentGold)
                        .italic()
                }
            }
            .frame(width: nodeWidth, height: nodeHeight)
            .padding(4)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor, lineWidth: isPlayerPosition ? 2 : 1)
            )
            .cornerRadius(4)
            .opacity(isLocked && !isOnPlayerTrack ? 0.4 : (isOnPlayerTrack ? 1.0 : 0.7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var abbreviatedTitle: String {
        // Abbreviate long titles for compact display
        let title = position.title
        if title.count > 20 {
            // Common abbreviations
            return title
                .replacingOccurrences(of: "Department", with: "Dept.")
                .replacingOccurrences(of: "Secretary", with: "Sec.")
                .replacingOccurrences(of: "Director", with: "Dir.")
                .replacingOccurrences(of: "Minister", with: "Min.")
                .replacingOccurrences(of: "Deputy", with: "Dpty.")
                .replacingOccurrences(of: "Chairman", with: "Chair.")
        }
        return title
    }

    private var trackColor: Color {
        switch position.expandedTrack {
        case .partyApparatus: return Color(hex: "8B0000")  // Dark red
        case .stateMinistry: return Color(hex: "1B5E20")   // Dark green
        case .securityServices: return Color(hex: "1A237E") // Dark blue
        case .foreignAffairs: return Color(hex: "4A148C")  // Purple
        case .economicPlanning: return Color(hex: "E65100") // Orange
        case .militaryPolitical: return Color(hex: "3E2723") // Brown
        case .regional: return Color(hex: "37474F")        // Blue-gray
        case .shared: return theme.accentGold
        }
    }

    private var titleColor: Color {
        if isLocked && !isOnPlayerTrack {
            return theme.inkLight
        }
        return isOnPlayerTrack ? theme.inkBlack : theme.inkGray
    }

    private var backgroundColor: Color {
        if isPlayerPosition {
            return Color(hex: "FFF8F0")  // Warm highlight
        } else if isAchieved {
            return Color(hex: "FFFDF0")  // Gold tint
        } else if isOnPlayerTrack {
            return theme.parchment
        } else {
            return theme.parchmentDark.opacity(0.5)
        }
    }

    private var borderColor: Color {
        if isPlayerPosition {
            return theme.sovietRed
        } else if isAchieved {
            return theme.accentGold
        } else if isOnPlayerTrack {
            return trackColor.opacity(0.6)
        } else {
            return theme.borderTan.opacity(0.5)
        }
    }
}

// MARK: - Player Badge (compact version)

private struct PlayerBadge: View {
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 6))
            Text("YOU")
                .font(.system(size: 7, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(theme.sovietRed)
        .cornerRadius(2)
    }
}

// MARK: - Shared Position Node (wider for apex/entry positions)

struct SharedPositionNode: View {
    let position: LadderPosition
    let holders: [String]
    let isPlayerPosition: Bool
    let isAchieved: Bool
    var scRank: SCRank? = nil  // Standing Committee rank indicator
    var onTap: (() -> Void)? = nil

    @Environment(\.theme) var theme

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 4) {
                // Standing Committee rank badge (if applicable)
                if let rank = scRank {
                    SCRankBadge(rank: rank)
                }

                // Position title
                Text(position.title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(isPlayerPosition ? theme.sovietRed : theme.inkBlack)
                    .multilineTextAlignment(.center)

                // Holder info
                if isPlayerPosition {
                    LargePlayerBadge()
                } else if !holders.isEmpty {
                    Text(holders.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkGray)
                        .lineLimit(1)
                } else {
                    Text("Vacant")
                        .font(.system(size: 10))
                        .foregroundColor(theme.accentGold)
                        .italic()
                }
            }
            .frame(width: 180, height: scRank != nil ? 70 : 50)
            .padding(8)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: isPlayerPosition ? 3 : 2)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isPlayerPosition {
            return Color(hex: "FFF0E8")
        } else if isAchieved {
            return Color(hex: "FFFDF0")
        } else {
            return theme.parchment
        }
    }

    private var borderColor: Color {
        if isPlayerPosition {
            return theme.sovietRed
        } else if isAchieved {
            return theme.accentGold
        } else {
            return theme.borderTan
        }
    }
}

// MARK: - SC Rank Badge

private struct SCRankBadge: View {
    let rank: SCRank
    @Environment(\.theme) var theme

    var body: some View {
        Text(rank.displayName.uppercased())
            .font(.system(size: 7, weight: .bold))
            .tracking(0.5)
            .foregroundColor(badgeTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeBackgroundColor)
            .cornerRadius(2)
    }

    private var badgeBackgroundColor: Color {
        switch rank {
        case .chairman:
            return theme.accentGold
        case .fullMember:
            return Color(hex: "4A4A4A")
        case .candidateMember:
            return Color(hex: "6A6A6A")
        }
    }

    private var badgeTextColor: Color {
        switch rank {
        case .chairman:
            return theme.inkBlack
        default:
            return .white
        }
    }
}

private struct LargePlayerBadge: View {
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 8))
            Text("YOU ARE HERE")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.sovietRed)
        .cornerRadius(3)
    }
}

// MARK: - Preview

#Preview {
    let position = LadderPosition(
        index: 4,
        track: .capital,
        expandedTrack: .securityServices,
        title: "Deputy Director",
        description: "Second in command",
        requiredStanding: 50,
        requiredPatronFavor: nil,
        requiredNetwork: 30,
        requiredFactionSupport: nil,
        maxHolders: 1,
        unlockedActions: []
    )

    return VStack(spacing: 20) {
        // Regular node
        OrgChartNode(
            position: position,
            holders: ["Director Wallace"],
            isPlayerPosition: false,
            isAchieved: false,
            isOnPlayerTrack: true,
            isLocked: false
        )

        // Player position
        OrgChartNode(
            position: position,
            holders: [],
            isPlayerPosition: true,
            isAchieved: false,
            isOnPlayerTrack: true,
            isLocked: false
        )

        // Off-track position
        OrgChartNode(
            position: position,
            holders: ["Someone Else"],
            isPlayerPosition: false,
            isAchieved: false,
            isOnPlayerTrack: false,
            isLocked: true
        )

        // Shared position
        let sharedPos = LadderPosition(
            index: 8,
            track: .shared,
            expandedTrack: .shared,
            title: "General Secretary",
            description: "Supreme leader",
            requiredStanding: 100,
            requiredPatronFavor: nil,
            requiredNetwork: nil,
            requiredFactionSupport: nil,
            maxHolders: 1,
            unlockedActions: []
        )
        SharedPositionNode(
            position: sharedPos,
            holders: ["Premier Kowalski"],
            isPlayerPosition: false,
            isAchieved: false
        )
    }
    .padding()
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}
