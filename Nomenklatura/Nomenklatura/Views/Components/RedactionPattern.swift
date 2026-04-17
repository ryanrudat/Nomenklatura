//
//  RedactionPattern.swift
//  Nomenklatura
//
//  Shared redaction primitives used by RedactableText and RedactableSection.
//  The player is the General Secretary; tapping always reveals the underlying
//  content because the Chairman has clearance over their own state apparatus.
//

import SwiftUI

struct RedactionOverlayModifier: ViewModifier {
    let revealed: Bool
    @Environment(\.theme) var theme

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .overlay(alignment: .topLeading) {
                if !revealed {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(theme.inkBlack)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .allowsHitTesting(false)
                    }
                    .transition(.opacity)
                }
            }
    }
}

extension View {
    func redactionOverlay(revealed: Bool) -> some View {
        modifier(RedactionOverlayModifier(revealed: revealed))
    }
}

struct AccessAuthorizedStamp: View {
    @Environment(\.theme) var theme

    var body: some View {
        Text("ACCESS AUTHORIZED")
            .font(.system(size: 18, weight: .black, design: .default))
            .tracking(3)
            .foregroundColor(theme.sovietRed.opacity(0.75))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .overlay(
                Rectangle()
                    .stroke(theme.sovietRed.opacity(0.75), lineWidth: 2.5)
            )
            .rotationEffect(.degrees(-12))
            .shadow(color: theme.sovietRed.opacity(0.2), radius: 0.5, x: 0.5, y: 0.5)
    }
}

/// Drives the shared reveal animation for RedactableText and RedactableSection.
/// Flashes the ACCESS AUTHORIZED stamp, fades in the underlying content,
/// then dismisses the stamp. Keeping the timing in one place prevents the
/// two components from drifting out of sync.
enum RedactionReveal {
    static func animate(revealed: Binding<Bool>, showStamp: Binding<Bool>) {
        withAnimation(.easeInOut(duration: 0.25)) {
            showStamp.wrappedValue = true
        }
        withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
            revealed.wrappedValue = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showStamp.wrappedValue = false
            }
        }
    }
}

#Preview("Redaction Primitives") {
    VStack(spacing: 24) {
        Text("Overlay unrevealed").font(.headline)
        Text("The Minister of Defense reports unusual troop concentrations near the Polish border.")
            .redactionOverlay(revealed: false)
            .frame(maxWidth: 320)

        Text("Overlay revealed").font(.headline)
        Text("The Minister of Defense reports unusual troop concentrations near the Polish border.")
            .redactionOverlay(revealed: true)
            .frame(maxWidth: 320)

        Divider()

        Text("ACCESS AUTHORIZED stamp").font(.headline)
        AccessAuthorizedStamp()
    }
    .padding()
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}
