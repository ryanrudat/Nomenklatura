//
//  PaperclipDecoration.swift
//  Nomenklatura
//
//  Metal paperclip shape for attaching to document cards. The briefing
//  in the prototype reads as "a file folder" partly because a single
//  paperclip sits at the top-right — a physical affordance, not just
//  a card with rounded corners. Draw it procedurally so it scales and
//  re-tints with the theme.
//

import SwiftUI

struct PaperclipDecoration: View {
    var color: Color? = nil
    var height: CGFloat = 70
    @Environment(\.theme) var theme

    var body: some View {
        PaperclipShape()
            .stroke(
                color ?? theme.concreteGray,
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )
            .opacity(0.85)
            .frame(width: height * 0.4, height: height)
            .shadow(color: .black.opacity(0.25), radius: 1.5, x: 1, y: 1)
    }
}

private struct PaperclipShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x: (CGFloat) -> CGFloat = { $0 * w / 28 }
        let y: (CGFloat) -> CGFloat = { $0 * h / 70 }

        var path = Path()
        path.move(to: CGPoint(x: x(14), y: y(4)))
        path.addCurve(
            to: CGPoint(x: x(24), y: y(14)),
            control1: CGPoint(x: x(20), y: y(4)),
            control2: CGPoint(x: x(24), y: y(8))
        )
        path.addLine(to: CGPoint(x: x(24), y: y(52)))
        path.addCurve(
            to: CGPoint(x: x(14), y: y(62)),
            control1: CGPoint(x: x(24), y: y(58)),
            control2: CGPoint(x: x(20), y: y(62))
        )
        path.addCurve(
            to: CGPoint(x: x(4), y: y(52)),
            control1: CGPoint(x: x(8), y: y(62)),
            control2: CGPoint(x: x(4), y: y(58))
        )
        path.addLine(to: CGPoint(x: x(4), y: y(18)))
        path.addCurve(
            to: CGPoint(x: x(10), y: y(12)),
            control1: CGPoint(x: x(4), y: y(14)),
            control2: CGPoint(x: x(6), y: y(12))
        )
        path.addCurve(
            to: CGPoint(x: x(16), y: y(18)),
            control1: CGPoint(x: x(14), y: y(12)),
            control2: CGPoint(x: x(16), y: y(14))
        )
        path.addLine(to: CGPoint(x: x(16), y: y(48)))
        return path
    }
}

#Preview {
    ZStack(alignment: .topTrailing) {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(hex: "FDFBF7"))
            .frame(width: 320, height: 420)
            .shadow(radius: 6)
        PaperclipDecoration()
            .offset(x: -30, y: -14)
    }
    .padding(40)
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}
