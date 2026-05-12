//
//  CrisisResponseBanner.swift
//  Nomenklatura
//
//  Slim red parchment-on-red banner that sits above the Desk content
//  whenever `CrisisResponseService.shared.activeCrises(in:)` is non-empty.
//  Brutalist-Bureaucratic aesthetic — tracked monospace, pulsing red dot,
//  chevron at the trailing edge. Entire surface is a tap target.
//
//  Phase 4 "Crisis Response Panel" — surfaces stability / treasury /
//  resource / coup / diplomatic / rival deadline crises in one place so
//  the Chairman can respond without hunting through tabs.
//

import SwiftUI
import SwiftData

struct CrisisResponseBanner: View {
    @Bindable var game: Game
    let onTap: () -> Void

    @Environment(\.theme) var theme
    @State private var pulseOpacity: Double = 1.0

    /// Recompute on every body invocation — `Game` mutations trigger a
    /// redraw via `@Bindable`, so the banner appears/disappears as
    /// crises spin up or resolve.
    private var activeCrises: [CrisisType] {
        CrisisResponseService.shared.activeCrises(in: game)
    }

    var body: some View {
        if activeCrises.isEmpty {
            EmptyView()
        } else {
            bannerContent
        }
    }

    private var bannerContent: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Pulsing red dot (small, simple opacity loop — not flashy)
                Circle()
                    .fill(theme.parchment)
                    .frame(width: 8, height: 8)
                    .opacity(pulseOpacity)
                    .overlay(
                        Circle()
                            .stroke(theme.parchment.opacity(0.5), lineWidth: 1)
                            .frame(width: 14, height: 14)
                            .opacity(pulseOpacity)
                    )

                Text(bannerText)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(theme.parchment)
                    .lineLimit(1)

                Spacer(minLength: 6)

                // Right-aligned chevron — bureaucratic "open file" affordance
                Text("\u{25B6}")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(theme.parchment.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(theme.stampRed)
            .overlay(
                Rectangle()
                    .stroke(theme.parchment.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityHint(Text("Opens crisis response panel"))
        .onAppear { startPulse() }
    }

    // MARK: - Text

    private var bannerText: String {
        let count = activeCrises.count
        if count == 1 {
            return "\u{26A0} CRISIS \u{2014} RESPOND"
        } else {
            return "\u{26A0} \(count) CRISES \u{2014} RESPOND"
        }
    }

    private var accessibilityText: String {
        let count = activeCrises.count
        return count == 1 ? "One active crisis. Respond." : "\(count) active crises. Respond."
    }

    // MARK: - Pulse Animation

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.7
        }
    }
}

#Preview("Crisis Banner") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    container.mainContext.insert(game)

    return VStack(spacing: 0) {
        CrisisResponseBanner(game: game, onTap: { print("Banner tapped") })
        Spacer()
    }
    .background(Color(hex: "F5F0E1"))
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
