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
    @State private var cycleWidth: CGFloat = 0

    var body: some View {
        let line = items.joined(separator: "   ▸   ")
        let unit = "\(line)   ▸   "
        let repeated = unit + unit

        ZStack {
            Rectangle()
                .fill(Color(hex: "0A0907"))
            // GeometryReader kept purely so the fixedSize text overflows the
            // strip instead of widening it.
            GeometryReader { _ in
                stripText(repeated)
                    .shadow(color: Color(hex: "7AAA7A").opacity(0.7), radius: 2, x: 0, y: 0)
                    .background(alignment: .leading) {
                        // Hidden single-cycle copy measures the seamless wrap
                        // distance: offsetting by exactly one unit lines the
                        // second copy up where the first started.
                        stripText(unit)
                            .hidden()
                            .background(GeometryReader { proxy in
                                Color.clear.preference(key: TeletypeCycleWidthKey.self, value: proxy.size.width)
                            })
                    }
                    .offset(x: -phase)
            }
        }
        .frame(height: 22)
        .overlay(
            Rectangle()
                .stroke(Color(hex: "7AAA7A").opacity(0.25), lineWidth: 0.5)
        )
        .clipped()
        .onPreferenceChange(TeletypeCycleWidthKey.self) { width in
            guard width > 0, width != cycleWidth else { return }
            cycleWidth = width
            phase = 0
            // Async so the reset lands before the repeatForever keyframe.
            DispatchQueue.main.async {
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    phase = width
                }
            }
        }
    }

    private func stripText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .tracking(1.5)
            .foregroundColor(Color(hex: "7AAA7A"))
            .fixedSize()
    }
}

private struct TeletypeCycleWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
