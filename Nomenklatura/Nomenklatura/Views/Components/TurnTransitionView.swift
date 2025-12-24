//
//  TurnTransitionView.swift
//  Nomenklatura
//
//  Animated PSRA flag transition between turns
//

import SwiftUI
import Combine

// MARK: - Turn Transition View

struct TurnTransitionView: View {
    let turnNumber: Int
    let loadingMessage: String
    let onComplete: () -> Void

    @Environment(\.theme) var theme

    @State private var gearRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var hasCompleted: Bool = false
    @State private var showContent: Bool = false
    @State private var dotCount: Int = 0

    // Timer for animated dots
    let dotTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Gradient background - more depth than flat color
            LinearGradient(
                colors: [
                    Color(hex: "1a0a0a"),
                    Color(hex: "4a0000"),
                    Color(hex: "6a0000"),
                    Color(hex: "4a0000"),
                    Color(hex: "1a0a0a")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle radial glow behind emblem
            RadialGradient(
                colors: [
                    Color(hex: "FFD700").opacity(glowOpacity * 0.3),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 250
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Main emblem container
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            Color(hex: "FFD700").opacity(0.2),
                            lineWidth: 2
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale * 1.1)

                    // The PSRA Emblem
                    PSRAEmblem(gearRotation: gearRotation)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.7)

                Spacer()

                // Loading message area
                VStack(spacing: 16) {
                    // Turn number with decorative lines
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color(hex: "FFD700").opacity(0.5))
                            .frame(width: 40, height: 1)

                        Text("TURN \(turnNumber)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(Color(hex: "FFD700"))

                        Rectangle()
                            .fill(Color(hex: "FFD700").opacity(0.5))
                            .frame(width: 40, height: 1)
                    }

                    // Loading message with animated dots
                    Text(loadingMessage + String(repeating: ".", count: dotCount))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(minWidth: 200)
                }
                .opacity(showContent ? 1 : 0)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onReceive(dotTimer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }

    private func startAnimations() {
        // Fade in content
        withAnimation(.easeOut(duration: 0.5)) {
            showContent = true
        }

        // Continuous gear rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            gearRotation = 360
        }

        // Pulsing effect
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }

        // Glow pulsing
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowOpacity = 0.6
        }

        // Complete transition after loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard !hasCompleted else { return }
            hasCompleted = true
            onComplete()
        }
    }
}

// MARK: - PSRA Emblem (Redesigned)

struct PSRAEmblem: View {
    let gearRotation: Double

    private let gold = Color(hex: "FFD700")
    private let darkGold = Color(hex: "B8860B")
    private let red = Color(hex: "CC0000")

    var body: some View {
        ZStack {
            // Gear (rotating)
            GearView()
                .rotationEffect(.degrees(gearRotation))

            // Central disc (red background for emblem)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [red, Color(hex: "8B0000")],
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(gold, lineWidth: 2)
                )

            // Hammer and Sickle (simplified, cleaner version)
            HammerAndSickle()
                .fill(gold)
                .frame(width: 50, height: 50)

            // Stars arranged around (fictional blend - 3 stars)
            ForEach(0..<3, id: \.self) { index in
                FivePointedStar()
                    .fill(gold)
                    .frame(width: starSize(for: index), height: starSize(for: index))
                    .offset(starOffset(for: index))
            }
        }
    }

    private func starSize(for index: Int) -> CGFloat {
        switch index {
        case 0: return 18  // Top star - largest
        case 1: return 14  // Left star
        case 2: return 14  // Right star
        default: return 12
        }
    }

    private func starOffset(for index: Int) -> CGSize {
        switch index {
        case 0: return CGSize(width: 0, height: -65)    // Top
        case 1: return CGSize(width: -55, height: -35)  // Upper left
        case 2: return CGSize(width: 55, height: -35)   // Upper right
        default: return .zero
        }
    }
}

// MARK: - Gear View (Cleaner Design)

struct GearView: View {
    private let gold = Color(hex: "FFD700")
    private let darkGold = Color(hex: "B8860B")

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // Main gear shape
                GearShape()
                    .fill(
                        LinearGradient(
                            colors: [gold, darkGold, gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Inner shadow/depth
                GearShape()
                    .stroke(darkGold.opacity(0.5), lineWidth: 1)

                // Center hole
                Circle()
                    .fill(Color.clear)
                    .frame(width: size * 0.5, height: size * 0.5)
            }
        }
    }
}

// MARK: - Simplified Hammer and Sickle

struct HammerAndSickle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let cy = rect.midY

        // === SICKLE ===
        // Curved blade (crescent shape)
        path.move(to: CGPoint(x: cx - w * 0.32, y: cy + h * 0.15))

        // Outer curve of blade (going up and right)
        path.addCurve(
            to: CGPoint(x: cx + w * 0.12, y: cy - h * 0.35),
            control1: CGPoint(x: cx - w * 0.38, y: cy - h * 0.15),
            control2: CGPoint(x: cx - w * 0.1, y: cy - h * 0.42)
        )

        // Inner curve back (thinner at tip)
        path.addCurve(
            to: CGPoint(x: cx - w * 0.22, y: cy + h * 0.08),
            control1: CGPoint(x: cx - w * 0.02, y: cy - h * 0.28),
            control2: CGPoint(x: cx - w * 0.18, y: cy - h * 0.05)
        )
        path.closeSubpath()

        // Sickle handle (vertical rectangle)
        path.addRect(CGRect(
            x: cx - w * 0.38,
            y: cy + h * 0.08,
            width: w * 0.1,
            height: h * 0.32
        ))

        // === HAMMER ===
        // Handle (diagonal from bottom-right to upper-left)
        let handleThickness = w * 0.08

        path.move(to: CGPoint(x: cx + w * 0.32, y: cy + h * 0.38))
        path.addLine(to: CGPoint(x: cx + w * 0.32 + handleThickness * 0.7, y: cy + h * 0.38 - handleThickness * 0.7))
        path.addLine(to: CGPoint(x: cx + handleThickness * 0.7, y: cy - h * 0.08))
        path.addLine(to: CGPoint(x: cx, y: cy - h * 0.08 + handleThickness * 0.7))
        path.closeSubpath()

        // Hammer head (rotated rectangle at 45 degrees)
        // Create points for rotated rectangle
        let headCX = cx + w * 0.02
        let headCY = cy - h * 0.15
        let headW = w * 0.32
        let headH = h * 0.1
        let angle = -CGFloat.pi / 4  // 45 degrees

        // Calculate corners of rotated rectangle
        let cos45 = cos(angle)
        let sin45 = sin(angle)

        let hw = headW / 2
        let hh = headH / 2

        // Four corners before rotation
        let corners = [
            CGPoint(x: -hw, y: -hh),
            CGPoint(x: hw, y: -hh),
            CGPoint(x: hw, y: hh),
            CGPoint(x: -hw, y: hh)
        ]

        // Rotate and translate each corner
        let rotatedCorners = corners.map { corner -> CGPoint in
            let rx = corner.x * cos45 - corner.y * sin45
            let ry = corner.x * sin45 + corner.y * cos45
            return CGPoint(x: headCX + rx, y: headCY + ry)
        }

        path.move(to: rotatedCorners[0])
        path.addLine(to: rotatedCorners[1])
        path.addLine(to: rotatedCorners[2])
        path.addLine(to: rotatedCorners[3])
        path.closeSubpath()

        return path
    }
}

// MARK: - Five Pointed Star

struct FivePointedStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4

        var path = Path()
        let points = 5
        let angleOffset = -CGFloat.pi / 2 // Start from top

        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = angleOffset + CGFloat(i) * .pi / CGFloat(points)
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - Gear Shape

struct GearShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.78
        let holeRadius = outerRadius * 0.5

        var path = Path()
        let teeth = 16
        let toothAngle = CGFloat.pi * 2 / CGFloat(teeth)
        let halfTooth = toothAngle / 4

        for i in 0..<teeth {
            let baseAngle = CGFloat(i) * toothAngle

            let p1 = CGPoint(
                x: center.x + innerRadius * cos(baseAngle - halfTooth),
                y: center.y + innerRadius * sin(baseAngle - halfTooth)
            )
            let p2 = CGPoint(
                x: center.x + outerRadius * cos(baseAngle - halfTooth * 0.6),
                y: center.y + outerRadius * sin(baseAngle - halfTooth * 0.6)
            )
            let p3 = CGPoint(
                x: center.x + outerRadius * cos(baseAngle + halfTooth * 0.6),
                y: center.y + outerRadius * sin(baseAngle + halfTooth * 0.6)
            )
            let p4 = CGPoint(
                x: center.x + innerRadius * cos(baseAngle + halfTooth),
                y: center.y + innerRadius * sin(baseAngle + halfTooth)
            )

            if i == 0 {
                path.move(to: p1)
            }
            path.addLine(to: p2)
            path.addLine(to: p3)
            path.addLine(to: p4)
        }
        path.closeSubpath()

        // Cut out center hole
        path.addEllipse(in: CGRect(
            x: center.x - holeRadius,
            y: center.y - holeRadius,
            width: holeRadius * 2,
            height: holeRadius * 2
        ))

        return path
    }
}

// MARK: - Color Extension (if not already defined elsewhere)

extension Color {
    func interpolate(to other: Color, progress: CGFloat) -> Color {
        let uiColor1 = UIColor(self)
        let uiColor2 = UIColor(other)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let r = r1 + (r2 - r1) * progress
        let g = g1 + (g2 - g1) * progress
        let b = b1 + (b2 - b1) * progress
        let a = a1 + (a2 - a1) * progress

        return Color(UIColor(red: r, green: g, blue: b, alpha: a))
    }
}

// MARK: - Preview

#Preview {
    TurnTransitionView(
        turnNumber: 3,
        loadingMessage: "Generating scenario"
    ) {
        print("Transition complete")
    }
    .environment(\.theme, ColdWarTheme())
}
