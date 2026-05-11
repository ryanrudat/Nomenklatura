//
//  ClassifiedWatermark.swift
//  Nomenklatura
//
//  Diagonal tiled "CLASSIFIED" wash for sensitive document backgrounds.
//  Sits under content at very low opacity — you notice it peripherally,
//  not while reading. Apply via `.classifiedWatermark()` on any card
//  that surfaces EYES ONLY / SECRET material.
//

import SwiftUI

struct ClassifiedWatermark: View {
    var text: String = "CLASSIFIED"
    var opacity: Double = 0.04
    @Environment(\.theme) var theme

    var body: some View {
        GeometryReader { geo in
            let tile: CGFloat = 180
            let cols = Int(ceil(geo.size.width / tile)) + 1
            let rows = Int(ceil(geo.size.height / tile)) + 1
            ZStack {
                ForEach(0..<rows, id: \.self) { r in
                    ForEach(0..<cols, id: \.self) { c in
                        Text(text)
                            .font(.system(size: 36, weight: .heavy, design: .default))
                            .tracking(6)
                            .foregroundColor(theme.stampRed.opacity(opacity))
                            .position(
                                x: CGFloat(c) * tile,
                                y: CGFloat(r) * tile
                            )
                    }
                }
            }
            .rotationEffect(.degrees(-32))
            .allowsHitTesting(false)
        }
        .clipped()
    }
}

struct ClassifiedWatermarkModifier: ViewModifier {
    let text: String
    let opacity: Double
    func body(content: Content) -> some View {
        content.overlay(
            ClassifiedWatermark(text: text, opacity: opacity)
        )
    }
}

extension View {
    func classifiedWatermark(text: String = "CLASSIFIED", opacity: Double = 0.04) -> some View {
        modifier(ClassifiedWatermarkModifier(text: text, opacity: opacity))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        Text("MEMO 1952-0211")
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .tracking(2)
        Text("Unauthorized broadcast detected. Four city blocks from the Tribune press building. Authorize sweep.")
            .font(.custom("AmericanTypewriter", size: 14))
        Spacer()
    }
    .frame(width: 320, height: 420, alignment: .topLeading)
    .padding(20)
    .background(Color(hex: "1E1B15"))
    .foregroundColor(Color(hex: "D4C8A8"))
    .classifiedWatermark(opacity: 0.08)
    .environment(\.theme, ColdWarTheme())
}
