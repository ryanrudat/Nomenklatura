//
//  WaxSealView.swift
//  Nomenklatura
//
//  Red wax seal for authentication moments — the "this is signed by
//  the Chairman" beat. Radial gradient does the heavy lifting; the
//  inset shadow sells the impression that the wax was pressed into
//  the paper, not painted on top of it.
//

import SwiftUI

struct WaxSealView: View {
    var size: CGFloat = 52
    var color: Color? = nil
    @Environment(\.theme) var theme

    var body: some View {
        let seal = color ?? theme.stampRedDark

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            seal.opacity(0.95),
                            seal.opacity(0.80),
                            Color(hex: "5A0A0A")
                        ],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.30), lineWidth: 1)
                        .blur(radius: 1)
                        .offset(y: -2)
                        .mask(Circle().fill(LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )))
                )

            Image(systemName: "star.fill")
                .font(.system(size: size * 0.45, weight: .black))
                .foregroundColor(Color(hex: "FFDCC8").opacity(0.75))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.40), radius: 2, x: 0, y: 2)
    }
}

#Preview {
    HStack(spacing: 20) {
        WaxSealView(size: 40)
        WaxSealView(size: 52)
        WaxSealView(size: 72)
    }
    .padding(40)
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}
