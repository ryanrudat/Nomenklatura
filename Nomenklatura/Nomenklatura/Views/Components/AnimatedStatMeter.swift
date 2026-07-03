//
//  AnimatedStatMeter.swift
//  Nomenklatura
//
//  0–100 stat bar with animated delta arrow for the OutcomeView reveal.
//  Animates from `value - delta` up to `value` over 900ms on appear so
//  the player sees the change happen, not just the final number. Tick
//  marks at 25/50/75 keep the bar readable at a glance.
//

import SwiftUI

struct AnimatedStatMeter: View {
    let label: String
    let icon: String
    let value: Int
    let delta: Int
    var animateOnAppear: Bool = true
    @Environment(\.theme) var theme
    @State private var display: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(label.uppercased())
                }
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(theme.inkGray)
                Spacer()
                HStack(spacing: 6) {
                    Text("\(Int(display))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.inkBlack)
                        .monospacedDigit()
                    if delta != 0 {
                        Text("\(delta > 0 ? "+" : "")\(delta)")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(delta > 0 ? theme.successGreen : theme.sovietRed)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(theme.borderTan.opacity(0.35))
                        .overlay(
                            Rectangle()
                                .stroke(theme.inkGray.opacity(0.28), lineWidth: 0.5)
                        )
                    Rectangle()
                        .fill(theme.inkBlack)
                        .frame(width: geo.size.width * CGFloat(clamp(display) / 100))
                    HStack(spacing: 0) {
                        ForEach([0.25, 0.50, 0.75], id: \.self) { p in
                            Spacer()
                                .frame(width: geo.size.width * p - (p == 0.25 ? 0 : geo.size.width * (p - 0.25)))
                            Rectangle()
                                .fill(theme.parchment.opacity(0.8))
                                .frame(width: 0.5)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 6)
        }
        .onAppear {
            let start = animateOnAppear ? Double(value - delta) : Double(value)
            display = start
            withAnimation(.easeOut(duration: 0.9)) {
                display = Double(value)
            }
        }
    }

    private func clamp(_ v: Double) -> Double {
        max(0, min(100, v))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        AnimatedStatMeter(label: "Treasury",       icon: "dollarsign.circle.fill", value: 56, delta: +8)
        AnimatedStatMeter(label: "Food Supply",    icon: "leaf.fill",             value: 64, delta: +12)
        AnimatedStatMeter(label: "Stability",      icon: "shield.fill",           value: 51, delta: -9)
        AnimatedStatMeter(label: "Popular Support",icon: "person.3.fill",         value: 30, delta: -14)
        AnimatedStatMeter(label: "Elite Loyalty",  icon: "crown.fill",            value: 57, delta: +6)
    }
    .padding(20)
    .background(Color(hex: "FDFBF7"))
    .environment(\.theme, ColdWarTheme())
}
