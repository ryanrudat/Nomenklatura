//
//  CodexStatChangeToast.swift
//  Nomenklatura
//
//  Brutalist parchment-stamp toast shown after sending a Codex response.
//  Surfaces the stat deltas (disposition, patron favor, rival threat) so
//  the player can *see* their choice land, instead of needing to navigate
//  to Dossier and hunt for the change.
//

import SwiftUI

/// A single stat delta line to show in the toast.
struct CodexStatDelta: Identifiable {
    let id = UUID()
    let label: String      // "PATRON FAVOR", "RIVAL THREAT", "DISPOSITION"
    let amount: Int        // signed: +3, -5, etc.
    let isPositive: Bool   // true = "good for player", false = "bad"
                           // Note: -2 RIVAL THREAT is "good" (rival respects strength)

    var displayText: String {
        let sign = amount > 0 ? "+" : ""
        return "\(sign)\(amount) \(label)"
    }
}

struct CodexStatChangeToast: View {
    let deltas: [CodexStatDelta]
    let archetypeLabel: String?    // e.g. "ASSERTIVE", "DEFIANT" — the choice that produced these
    let onDismiss: () -> Void
    @Environment(\.theme) var theme
    @State private var isVisible = false

    var body: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                // Header row: stamp + RESPONSE FILED + archetype
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.stampRed)
                        .rotationEffect(.degrees(-6))

                    Text("RESPONSE FILED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(theme.inkBlack)

                    if let archetype = archetypeLabel {
                        Text("•")
                            .foregroundColor(theme.inkLight)
                        Text(archetype.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(theme.accentGold)
                    }

                    Spacer()
                }

                // Hairline divider
                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 1)

                // Delta rows
                if deltas.isEmpty {
                    Text("NO MEASURABLE EFFECT")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundColor(theme.inkLight)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(deltas) { delta in
                            deltaRow(delta)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.parchmentDark)
                    // Faint inner border for the rubber-stamp feel
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(theme.stampRed.opacity(0.7), lineWidth: 1.5)
                }
            )
            .shadow(color: theme.inkBlack.opacity(0.25), radius: 6, x: 0, y: 3)
            .padding(.horizontal, 24)
            .padding(.bottom, 96)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                isVisible = true
            }
            // Auto-dismiss after 3.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                dismiss()
            }
        }
        .onTapGesture { dismiss() }
    }

    private func deltaRow(_ delta: CodexStatDelta) -> some View {
        HStack(spacing: 8) {
            // Direction chevron, colored by "is this good for me?"
            Image(systemName: delta.isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(delta.isPositive ? theme.accentGold : theme.stampRed)
                .frame(width: 14)

            Text(delta.displayText)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(theme.inkBlack)

            Spacer()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

#Preview("Stat Change Toast") {
    ZStack {
        Color(hex: "F5F0E1").ignoresSafeArea()

        CodexStatChangeToast(
            deltas: [
                CodexStatDelta(label: "PATRON FAVOR", amount: 3, isPositive: true),
                CodexStatDelta(label: "DISPOSITION", amount: 4, isPositive: true),
                CodexStatDelta(label: "RIVAL THREAT", amount: -2, isPositive: true)
            ],
            archetypeLabel: "ASSERTIVE",
            onDismiss: {}
        )
    }
    .environment(\.theme, ColdWarTheme())
}
