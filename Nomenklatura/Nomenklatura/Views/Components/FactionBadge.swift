//
//  FactionBadge.swift
//  Nomenklatura
//
//  Small faction indicator badge for position holders (CK3-style)
//

import SwiftUI

struct FactionBadge: View {
    let factionId: String
    @Environment(\.theme) var theme

    /// Returns the appropriate color for each faction
    private var factionColor: Color {
        switch factionId.lowercased() {
        case "youth_league":
            return Color(hex: "1976D2")  // Blue - rising merit
        case "princelings":
            return Color(hex: "C62828")  // Deep red - aristocracy
        case "reformists":
            return Color(hex: "388E3C")  // Green - progress
        case "old_guard":
            return Color(hex: "5D4037")  // Brown - Proletariat Union (tradition)
        case "regional":
            return Color(hex: "F57C00")  // Orange - People's Provincial Administration
        default:
            return theme.inkGray
        }
    }

    /// Returns the appropriate icon for each faction
    private var factionIcon: String {
        switch factionId.lowercased() {
        case "youth_league":
            return "star.fill"  // Rising star
        case "princelings":
            return "crown.fill"  // Aristocratic crown
        case "reformists":
            return "arrow.triangle.2.circlepath"  // Change/progress
        case "old_guard":
            return "shield.fill"  // Proletariat Union - guardian shield
        case "regional":
            return "map.fill"  // People's Provincial Administration - geographic
        default:
            return "circle.fill"
        }
    }

    /// Short faction code for display
    private var factionCode: String {
        switch factionId.lowercased() {
        case "youth_league": return "YL"
        case "princelings": return "PR"
        case "reformists": return "RF"
        case "old_guard": return "PU"   // Proletariat Union
        case "regional": return "PPA"  // People's Provincial Administration
        default: return "?"
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: factionIcon)
                .font(.system(size: 8))
        }
        .foregroundColor(factionColor)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(factionColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Compact Dot Version

struct FactionDot: View {
    let factionId: String

    private var factionColor: Color {
        switch factionId.lowercased() {
        case "youth_league": return Color(hex: "1976D2")
        case "princelings": return Color(hex: "C62828")
        case "reformists": return Color(hex: "388E3C")
        case "old_guard": return Color(hex: "5D4037")   // Proletariat Union
        case "regional": return Color(hex: "F57C00")    // People's Provincial Administration
        default: return Color.gray
        }
    }

    var body: some View {
        Circle()
            .fill(factionColor)
            .frame(width: 6, height: 6)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        // All faction badges
        VStack(alignment: .leading, spacing: 8) {
            Text("Faction Badges").font(.headline)
            HStack(spacing: 10) {
                FactionBadge(factionId: "youth_league")
                FactionBadge(factionId: "princelings")
                FactionBadge(factionId: "reformists")
                FactionBadge(factionId: "old_guard")
                FactionBadge(factionId: "regional")
            }
        }

        // Usage with names
        VStack(alignment: .leading, spacing: 8) {
            Text("With Names").font(.headline)
            HStack(spacing: 6) {
                Text("Wallace")
                    .font(.system(size: 12))
                FactionBadge(factionId: "old_guard")
            }
            HStack(spacing: 6) {
                Text("Morrison")
                    .font(.system(size: 12))
                FactionBadge(factionId: "youth_league")
            }
            HStack(spacing: 6) {
                Text("Anderson")
                    .font(.system(size: 12))
                FactionBadge(factionId: "princelings")
            }
        }

        // Faction dots
        VStack(alignment: .leading, spacing: 8) {
            Text("Faction Dots").font(.headline)
            HStack(spacing: 10) {
                FactionDot(factionId: "youth_league")
                FactionDot(factionId: "princelings")
                FactionDot(factionId: "reformists")
                FactionDot(factionId: "old_guard")
                FactionDot(factionId: "regional")
            }
        }
    }
    .padding()
    .environment(\.theme, ColdWarTheme())
}
