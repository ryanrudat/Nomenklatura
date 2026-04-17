//
//  RedactableSection.swift
//  Nomenklatura
//
//  A wrapper that applies the redaction reveal behavior to any content block
//  (cards, multi-line layouts, etc.). Same tap-to-reveal semantics as
//  RedactableText, scaled up for multi-line content.
//

import SwiftUI

struct RedactableSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @State private var revealed: Bool = false
    @State private var showStamp: Bool = false

    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            content()
                .redactionOverlay(revealed: revealed)

            if showStamp {
                AccessAuthorizedStamp()
                    .transition(.opacity.combined(with: .scale(scale: 1.15)))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !revealed else { return }
            RedactionReveal.animate(revealed: $revealed, showStamp: $showStamp)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(revealed ? "Declassified section" : "Redacted section. Tap to reveal.")
    }
}

#Preview("RedactableSection — multi-line") {
    VStack(alignment: .leading, spacing: 24) {
        Text("Multi-line report (tap to reveal)").font(.caption).foregroundColor(.secondary)
        RedactableSection {
            VStack(alignment: .leading, spacing: 6) {
                Text("Top Secret Intelligence Report")
                    .font(.system(size: 14, weight: .bold))
                Text("Subject: Marshal Volkov")
                    .font(.system(size: 12))
                Text("Date: March 12, 1962")
                    .font(.system(size: 12))
                Text("Summary: Target observed in repeated clandestine contact with foreign military attaches. Pattern suggests active intelligence sharing rather than routine diplomatic interaction.")
                    .font(.system(size: 13))
                    .frame(maxWidth: 320, alignment: .leading)
            }
        }

        Text("Short section").font(.caption).foregroundColor(.secondary)
        RedactableSection {
            Text("Deny all knowledge. Burn the file.")
                .font(.system(size: 16, weight: .semibold))
        }

        Text("Card-styled section").font(.caption).foregroundColor(.secondary)
        RedactableSection {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(Color(hex: "B82E2E"))
                    Text("CLASSIFIED DOSSIER")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "B82E2E"))
                }
                Text("Operation Nightfall")
                    .font(.system(size: 15, weight: .bold))
                Text("Agent Petrov confirms: the asset has accepted payment in gold. Arrange extraction before the Politburo session next Tuesday.")
                    .font(.system(size: 13))
                    .frame(maxWidth: 320, alignment: .leading)
            }
            .padding(14)
            .background(Color(hex: "FDFBF7"))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
            )
        }
    }
    .padding()
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}
