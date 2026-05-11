//
//  GlassPillBackground.swift
//  Nomenklatura
//
//  iOS-style glass pill treatment — Material blur + subtle inset shine —
//  for ornamental nav buttons that want the premium iPhone chrome feel
//  without rolling a UIVisualEffectView. Use on back / menu / close
//  buttons in headers when the prototype reads as "iOS app chrome."
//

import SwiftUI

struct GlassPillBackground: ViewModifier {
    var height: CGFloat = 44
    var dark: Bool = false

    func body(content: Content) -> some View {
        content
            .frame(height: height)
            .padding(.horizontal, height * 0.45)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: dark
                                    ? [Color.white.opacity(0.10), Color.white.opacity(0.02)]
                                    : [Color.white.opacity(0.55), Color.white.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.overlay)
                    Capsule()
                        .strokeBorder(
                            dark
                                ? Color.white.opacity(0.12)
                                : Color.white.opacity(0.35),
                            lineWidth: 0.5
                        )
                }
            )
            .clipShape(Capsule())
    }
}

extension View {
    /// Wrap any inline content (an icon, a short label) in an iOS-style
    /// glass pill. `dark: true` for dark-mode chrome.
    func glassPill(height: CGFloat = 44, dark: Bool = false) -> some View {
        modifier(GlassPillBackground(height: height, dark: dark))
    }
}

#Preview {
    VStack(spacing: 30) {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: "141414"))
                .glassPill()
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: "141414"))
                .glassPill()
        }
        HStack(spacing: 12) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .glassPill(dark: true)
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .glassPill(dark: true)
        }
        .padding(24)
        .background(Color(hex: "1A1A1A"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding(40)
    .background(
        LinearGradient(colors: [Color(hex: "F5F0E1"), Color(hex: "E8D4A8")], startPoint: .top, endPoint: .bottom)
    )
    .environment(\.theme, ColdWarTheme())
}
