//
//  OvernightDigestCard.swift
//  Nomenklatura
//
//  "What happened while you slept" — the morning intelligence digest.
//  The ~32 end-of-turn systems (rival schemes, conspiracies, NPC agency,
//  economy, leaks) log GameEvents that previously surfaced nowhere except
//  the Dossier journal. This card lifts the top overnight items onto the
//  Desk so consequence is felt at the start of every turn. Renders
//  nothing when the night was quiet (zero height, like CrisisResponseBanner).
//
//  Visual language matches the other desk documents (parchment, typewriter,
//  importance-tinted markers).
//

import SwiftUI

struct OvernightDigestCard: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    /// Player-driven event types the player already witnessed directly
    /// (chose in the decision overlay / watched in OutcomeView) — the
    /// digest is for what the apparatus did on its own.
    private static let ownActionTypes: Set<String> = ["decision", "outcome", "personalAction"]

    /// Top overnight items: events logged during the previous turn's
    /// end-of-turn pipeline (they carry the pre-increment turn number),
    /// important enough to brief, most severe first.
    private var dispatches: [GameEvent] {
        game.events
            .filter {
                $0.turnNumber == game.turnNumber - 1
                    && $0.importance >= 5
                    && !Self.ownActionTypes.contains($0.eventType)
            }
            .sorted {
                $0.importance != $1.importance
                    ? $0.importance > $1.importance
                    : $0.createdAt < $1.createdAt
            }
            .prefix(5)
            .map { $0 }
    }

    private func markerColor(importance: Int) -> Color {
        switch importance {
        case 8...: return theme.stampRed
        case 6...7: return theme.warningAmber
        default: return theme.inkGray
        }
    }

    var body: some View {
        let items = dispatches
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text("OVERNIGHT DISPATCHES")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(theme.inkBlack)
                    Spacer()
                    Text("AS OF THIS MORNING")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.parchmentDark)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.id) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle()
                                .fill(markerColor(importance: event.importance))
                                .frame(width: 3)
                                .frame(maxHeight: .infinity)
                            Text(event.summary)
                                .font(.custom("AmericanTypewriter", size: 12))
                                .foregroundColor(theme.inkBlack)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .background(theme.parchment)
            }
            .overlay(Rectangle().stroke(theme.inkGray.opacity(0.35), lineWidth: 1))
        }
    }
}
