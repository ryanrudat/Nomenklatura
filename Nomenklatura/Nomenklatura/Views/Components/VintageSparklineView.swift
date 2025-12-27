//
//  VintageSparklineView.swift
//  Nomenklatura
//
//  Vintage 1950s-style sparkline chart with graph paper aesthetic,
//  hand-drawn line effects, and typewriter labels.
//

import SwiftUI

// MARK: - Vintage Sparkline View

/// A compact sparkline chart with vintage graph paper aesthetic
struct VintageSparklineView: View {
    let data: [Int]
    var dangerThreshold: Int = 40
    var safeThreshold: Int = 70
    var showLabels: Bool = false
    var height: CGFloat = 24
    var baselineValue: Int = 50

    // Visual style options
    var showBaseline: Bool = true
    var showTrendArrow: Bool = true
    var handDrawnWobble: CGFloat = 0.8

    private var normalizedData: [CGFloat] {
        guard !data.isEmpty else { return [] }
        return data.map { CGFloat($0) / 100.0 }
    }

    private var currentValue: Int {
        data.last ?? 50
    }

    private var trend: SparklineTrend {
        guard data.count >= 2 else { return .stable }
        let recent = Array(data.suffix(3))
        let first = recent.first ?? 50
        let last = recent.last ?? 50
        let diff = last - first

        if diff > 5 { return .rising }
        if diff < -5 { return .falling }
        return .stable
    }

    private var lineColor: Color {
        if currentValue < dangerThreshold {
            return Color("statLow")
        } else if currentValue > safeThreshold {
            return Color("statHigh")
        } else {
            return FiftiesColors.typewriterInk
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Graph paper background
                GraphPaperBackground(
                    cellSize: 4,
                    lineColor: Color(hex: "D4C5A9").opacity(0.4)
                )

                // Baseline dashed line at 50%
                if showBaseline {
                    BaselinePath(normalizedValue: CGFloat(baselineValue) / 100.0)
                        .stroke(
                            style: StrokeStyle(lineWidth: 0.5, dash: [2, 2])
                        )
                        .foregroundColor(FiftiesColors.fadedInk.opacity(0.5))
                }

                // Main sparkline
                if data.count >= 2 {
                    HandDrawnSparklinePath(
                        data: normalizedData,
                        wobble: handDrawnWobble
                    )
                    .stroke(lineColor, style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        lineJoin: .round
                    ))
                    // Slight ink bleed effect
                    .shadow(color: lineColor.opacity(0.3), radius: 0.5, x: 0.3, y: 0.3)
                }

                // Current value dot
                if !data.isEmpty {
                    Circle()
                        .fill(lineColor)
                        .frame(width: 4, height: 4)
                        .position(
                            x: geometry.size.width - 2,
                            y: geometry.size.height * (1 - (normalizedData.last ?? 0.5))
                        )
                }

                // Trend arrow
                if showTrendArrow {
                    TrendArrow(trend: trend, color: lineColor)
                        .position(
                            x: geometry.size.width - 8,
                            y: 6
                        )
                }

                // Labels
                if showLabels {
                    VStack {
                        Spacer()
                        HStack {
                            // Start turn label
                            if data.count > 1 {
                                Text("T-\(data.count - 1)")
                                    .font(.system(size: 6, weight: .medium, design: .monospaced))
                                    .foregroundColor(FiftiesColors.fadedInk)
                            }
                            Spacer()
                            // NOW label
                            Text("NOW")
                                .font(.system(size: 6, weight: .bold, design: .monospaced))
                                .foregroundColor(FiftiesColors.typewriterInk)
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Trend Type

enum SparklineTrend {
    case rising
    case falling
    case stable

    var arrowIcon: String {
        switch self {
        case .rising: return "arrow.up"
        case .falling: return "arrow.down"
        case .stable: return "minus"
        }
    }
}

// MARK: - Graph Paper Background

struct GraphPaperBackground: View {
    var cellSize: CGFloat = 8
    var lineColor: Color = Color(hex: "D4C5A9").opacity(0.5)
    var backgroundColor: Color = Color(hex: "F4F1E8")

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base parchment
                backgroundColor

                // Vertical grid lines
                Path { path in
                    let cols = Int(geometry.size.width / cellSize)
                    for i in 0...cols {
                        let x = CGFloat(i) * cellSize
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                }
                .stroke(lineColor, lineWidth: 0.5)

                // Horizontal grid lines
                Path { path in
                    let rows = Int(geometry.size.height / cellSize)
                    for i in 0...rows {
                        let y = CGFloat(i) * cellSize
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(lineColor, lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Baseline Path

struct BaselinePath: Shape {
    let normalizedValue: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.height * (1 - normalizedValue)
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: rect.width, y: y))
        return path
    }
}

// MARK: - Hand-Drawn Sparkline Path

struct HandDrawnSparklinePath: Shape {
    let data: [CGFloat]
    var wobble: CGFloat = 1.0

    func path(in rect: CGRect) -> Path {
        guard data.count >= 2 else { return Path() }

        var path = Path()
        let pointSpacing = rect.width / CGFloat(data.count - 1)

        // Generate consistent "random" offsets based on index
        func wobbleOffset(for index: Int, component: Int) -> CGFloat {
            // Use a simple deterministic formula for consistent rendering
            let seed = Double(index * 17 + component * 31)
            let offset = sin(seed) * Double(wobble)
            return CGFloat(offset)
        }

        // Start point
        let startY = rect.height * (1 - data[0])
        path.move(to: CGPoint(
            x: wobbleOffset(for: 0, component: 0),
            y: startY + wobbleOffset(for: 0, component: 1)
        ))

        // Draw through each point with slight wobble
        for (index, value) in data.enumerated().dropFirst() {
            let x = CGFloat(index) * pointSpacing + wobbleOffset(for: index, component: 0)
            let y = rect.height * (1 - value) + wobbleOffset(for: index, component: 1)

            // Use quad curves for smoother hand-drawn feel
            let prevIndex = index - 1
            let prevX = CGFloat(prevIndex) * pointSpacing + wobbleOffset(for: prevIndex, component: 0)
            let prevY = rect.height * (1 - data[prevIndex]) + wobbleOffset(for: prevIndex, component: 1)

            let controlX = (prevX + x) / 2 + wobbleOffset(for: index, component: 2) * 2
            let controlY = (prevY + y) / 2 + wobbleOffset(for: index, component: 3) * 2

            path.addQuadCurve(
                to: CGPoint(x: x, y: y),
                control: CGPoint(x: controlX, y: controlY)
            )
        }

        return path
    }
}

// MARK: - Trend Arrow

struct TrendArrow: View {
    let trend: SparklineTrend
    let color: Color

    var body: some View {
        Image(systemName: trend.arrowIcon)
            .font(.system(size: 6, weight: .bold))
            .foregroundColor(color)
    }
}

// MARK: - Extended Sparkline (For Detail Sheets)

/// Larger sparkline with more detail for stat sheets
struct DetailedSparklineView: View {
    let data: [Int]
    let title: String
    var dangerThreshold: Int = 40
    var safeThreshold: Int = 70
    var height: CGFloat = 120

    private var minValue: Int {
        max(0, (data.min() ?? 0) - 10)
    }

    private var maxValue: Int {
        min(100, (data.max() ?? 100) + 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .default))
                .tracking(1)
                .foregroundColor(FiftiesColors.fadedInk)

            // Chart
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Graph paper
                    GraphPaperBackground(
                        cellSize: 12,
                        lineColor: Color(hex: "D4C5A9").opacity(0.3)
                    )

                    // Danger zone fill
                    if dangerThreshold > minValue {
                        Rectangle()
                            .fill(Color("statLow").opacity(0.1))
                            .frame(
                                height: geometry.size.height * CGFloat(dangerThreshold - minValue) / CGFloat(maxValue - minValue)
                            )
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }

                    // Safe zone fill
                    if safeThreshold < maxValue {
                        Rectangle()
                            .fill(Color("statHigh").opacity(0.1))
                            .frame(
                                height: geometry.size.height * CGFloat(maxValue - safeThreshold) / CGFloat(maxValue - minValue)
                            )
                            .frame(maxHeight: .infinity, alignment: .top)
                    }

                    // Baseline at 50
                    if 50 >= minValue && 50 <= maxValue {
                        Path { path in
                            let y = geometry.size.height * (1 - CGFloat(50 - minValue) / CGFloat(maxValue - minValue))
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundColor(FiftiesColors.fadedInk.opacity(0.5))
                    }

                    // Sparkline
                    if data.count >= 2 {
                        DetailedSparklinePath(
                            data: data,
                            minValue: minValue,
                            maxValue: maxValue
                        )
                        .stroke(
                            lineColor(for: data.last ?? 50),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: lineColor(for: data.last ?? 50).opacity(0.3), radius: 1)
                    }

                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        Circle()
                            .fill(lineColor(for: value))
                            .frame(width: 6, height: 6)
                            .position(
                                x: CGFloat(index) / CGFloat(max(1, data.count - 1)) * geometry.size.width,
                                y: geometry.size.height * (1 - CGFloat(value - minValue) / CGFloat(maxValue - minValue))
                            )
                    }

                    // Y-axis labels
                    VStack {
                        Text("\(maxValue)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(FiftiesColors.fadedInk)
                        Spacer()
                        Text("\(minValue)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(FiftiesColors.fadedInk)
                    }
                    .frame(width: 20)
                }
            }
            .frame(height: height)

            // X-axis with turn labels
            HStack {
                if data.count > 1 {
                    Text("T-\(data.count - 1)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk)
                }
                Spacer()
                Text("NOW")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(FiftiesColors.typewriterInk)
            }
        }
        .padding(12)
        .background(FiftiesColors.agedPaper)
        .overlay(
            Rectangle()
                .stroke(Color(hex: "D4C9B0"), lineWidth: 1)
        )
    }

    private func lineColor(for value: Int) -> Color {
        if value < dangerThreshold {
            return Color("statLow")
        } else if value > safeThreshold {
            return Color("statHigh")
        } else {
            return FiftiesColors.typewriterInk
        }
    }
}

// MARK: - Detailed Sparkline Path

struct DetailedSparklinePath: Shape {
    let data: [Int]
    let minValue: Int
    let maxValue: Int

    func path(in rect: CGRect) -> Path {
        guard data.count >= 2 else { return Path() }

        var path = Path()
        let range = CGFloat(maxValue - minValue)
        let pointSpacing = rect.width / CGFloat(data.count - 1)

        func yPosition(for value: Int) -> CGFloat {
            rect.height * (1 - CGFloat(value - minValue) / range)
        }

        // Start
        path.move(to: CGPoint(x: 0, y: yPosition(for: data[0])))

        // Smooth curve through points
        for (index, value) in data.enumerated().dropFirst() {
            let x = CGFloat(index) * pointSpacing
            let y = yPosition(for: value)

            let prevIndex = index - 1
            let prevX = CGFloat(prevIndex) * pointSpacing
            let prevY = yPosition(for: data[prevIndex])

            // Control points for smooth curve
            let controlX1 = prevX + pointSpacing * 0.5
            let controlX2 = x - pointSpacing * 0.5

            path.addCurve(
                to: CGPoint(x: x, y: y),
                control1: CGPoint(x: controlX1, y: prevY),
                control2: CGPoint(x: controlX2, y: y)
            )
        }

        return path
    }
}

// MARK: - Previews

#Preview("Compact Sparkline") {
    VStack(spacing: 16) {
        // Rising trend (good stat)
        VintageSparklineView(
            data: [45, 48, 52, 55, 60, 65, 72],
            showLabels: true,
            height: 32
        )
        .frame(width: 80)

        // Falling trend (danger)
        VintageSparklineView(
            data: [65, 58, 52, 45, 38, 32],
            showLabels: true,
            height: 32
        )
        .frame(width: 80)

        // Stable trend
        VintageSparklineView(
            data: [50, 52, 48, 51, 49, 50],
            showLabels: true,
            height: 32
        )
        .frame(width: 80)
    }
    .padding()
    .background(FiftiesColors.agedPaper)
}

#Preview("Detailed Chart") {
    DetailedSparklineView(
        data: [45, 52, 48, 55, 62, 58, 65, 72, 68, 75],
        title: "Standing History"
    )
    .padding()
    .background(Color(hex: "E8E4DC"))
}

#Preview("Graph Paper") {
    GraphPaperBackground()
        .frame(width: 200, height: 100)
        .padding()
}
