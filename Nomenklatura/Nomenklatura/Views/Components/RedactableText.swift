//
//  RedactableText.swift
//  Nomenklatura
//
//  A text view that appears redacted by default and reveals its underlying
//  content when tapped. The Chairman has clearance over their own state;
//  redaction is theatrical bureaucratic styling, not a real access gate.
//

import SwiftUI

struct RedactableText: View {
    let text: String
    var font: Font? = nil
    var color: Color? = nil

    @State private var revealed: Bool = false
    @State private var showStamp: Bool = false

    @Environment(\.theme) var theme

    init(_ text: String, font: Font? = nil, color: Color? = nil) {
        self.text = text
        self.font = font
        self.color = color
    }

    var body: some View {
        ZStack {
            Text(text)
                .font(font ?? theme.bodyFont)
                .foregroundColor(color ?? theme.inkBlack)
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
        .accessibilityLabel(revealed ? text : "Redacted text. Tap to reveal.")
    }
}

#Preview("RedactableText — states") {
    VStack(alignment: .leading, spacing: 24) {
        Text("Short text (unrevealed)").font(.caption).foregroundColor(.secondary)
        RedactableText("Marshal Volkov is disloyal.")

        Text("Long text (unrevealed)").font(.caption).foregroundColor(.secondary)
        RedactableText("The Minister of Defense reports unusual troop concentrations near the Polish border, with three divisions moving eastward under cover of a scheduled exercise.")
            .frame(maxWidth: 360, alignment: .leading)

        Text("Custom font + color").font(.caption).foregroundColor(.secondary)
        RedactableText(
            "Operation Nightfall is compromised.",
            font: .system(size: 16, weight: .bold, design: .monospaced),
            color: Color(hex: "B82E2E")
        )

        Text("In a card context").font(.caption).foregroundColor(.secondary)
        VStack(alignment: .leading, spacing: 6) {
            Text("TOP SECRET INTELLIGENCE")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(Color(hex: "B82E2E"))
            RedactableText("Subject: General Petrov has been meeting with foreign attaches at the Metropol since March 3rd.")
        }
        .padding(14)
        .background(Color(hex: "FDFBF7"))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
        )
    }
    .padding()
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}

#Preview("RedactableText — multiple lines") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Tap to reveal each line").font(.caption).foregroundColor(.secondary)
        RedactableText("Line one: routine border sighting.")
        RedactableText("Line two: intercepted cipher from Warsaw.")
        RedactableText("Line three: troop concentration confirmed.")
    }
    .padding()
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}
