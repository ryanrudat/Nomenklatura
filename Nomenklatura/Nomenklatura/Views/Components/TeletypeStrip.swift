//
//  TeletypeStrip.swift
//  Nomenklatura
//
//  Scrolling green-phosphor header for classified/surveillance contexts.
//  The illusion is that a teleprinter is piping intel live; in reality
//  it's a looping HStack offset animation. Use sparingly — a strip on
//  every screen kills the "this one is special" beat.
//

import SwiftUI

struct TeletypeStrip: View {
    let items: [String]
    var speed: Double = 42    // seconds per full cycle, matches prototype
    @Environment(\.theme) var theme
    @State private var phase: CGFloat = 0

    var body: some View {
        let line = items.joined(separator: "   ▸   ")
        let repeated = "\(line)   ▸   \(line)   ▸   "

        ZStack {
            Rectangle()
                .fill(Color(hex: "0A0907"))
            GeometryReader { geo in
                Text(repeated)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: "7AAA7A"))
                    .shadow(color: Color(hex: "7AAA7A").opacity(0.7), radius: 2, x: 0, y: 0)
                    .fixedSize()
                    .offset(x: -phase)
                    .onAppear {
                        withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                            phase = geo.size.width
                        }
                    }
            }
        }
        .frame(height: 22)
        .overlay(
            Rectangle()
                .stroke(Color(hex: "7AAA7A").opacity(0.25), lineWidth: 0.5)
        )
        .clipped()
    }
}

#Preview {
    VStack(spacing: 12) {
        TeletypeStrip(items: [
            "PSRA SECURE WIRE",
            "DOC BSS-1952-0211",
            "CLASSIFICATION: SECRET",
            "BUREAU OF STATE SECURITY",
            "ORIGIN: PETRENKO/K"
        ])
    }
    .padding(40)
    .background(Color(hex: "14120F"))
    .environment(\.theme, ColdWarTheme())
}
