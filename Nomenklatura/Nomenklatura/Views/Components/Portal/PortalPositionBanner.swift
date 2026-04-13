//
//  PortalPositionBanner.swift
//  Nomenklatura
//
//  Shared position banner for Economic, Military, Party, and Ministry portals
//  Security and Embassy keep their own (different layout)
//

import SwiftUI

struct PortalPositionBannerConfig {
    let track: ExpandedCareerTrack
    let accentColor: Color
    let authorityLabel: String
    let positionTitle: (Int) -> String
    let equivalentTitle: (Int) -> String
    let noAuthorityEquivalent: String
}

struct PortalPositionBanner: View {
    let game: Game
    let config: PortalPositionBannerConfig
    @Environment(\.theme) var theme

    private var isInTrack: Bool {
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        return playerTrack == config.track
    }

    private var isTopLeadership: Bool {
        game.currentPositionIndex >= 7
    }

    private var hasAuthority: Bool {
        isInTrack || isTopLeadership
    }

    private var categoryTitle: String {
        guard hasAuthority else { return "Observer Only" }
        return config.positionTitle(game.currentPositionIndex)
    }

    private var equivalentTitle: String {
        guard hasAuthority else { return config.noAuthorityEquivalent }
        return config.equivalentTitle(game.currentPositionIndex)
    }

    private var headerText: String {
        hasAuthority ? config.authorityLabel : "ACCESS STATUS"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerText)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Text(categoryTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(hasAuthority ? theme.inkBlack : theme.inkLight)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if hasAuthority {
                    Text("POSITION \(game.currentPositionIndex)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(config.accentColor)
                } else {
                    Text("VIEW ONLY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.inkLight)
                }

                Text(equivalentTitle)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkGray)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasAuthority ? config.accentColor.opacity(0.3) : theme.inkLight.opacity(0.3), lineWidth: 1)
        )
    }
}
