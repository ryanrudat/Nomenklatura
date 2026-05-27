//
//  SimpleLineChart.swift
//  Nomenklatura
//
//  Small sparkline chart used by the Economy hub (EconomicHubView).
//  Extracted from the retired EconomicDashboardView so it survives that
//  file's deletion.
//

import SwiftUI

// MARK: - Simple Line Chart

struct SimpleLineChart: View {
    let data: [Int]
    let baselineValue: Int
    let color: Color
    @Environment(\.theme) var theme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.parchmentDark)

                if data.count >= 2 {
                    // Baseline reference line
                    let normalizedBaseline = normalizedValue(baselineValue)
                    Path { path in
                        let y = geometry.size.height * (1 - normalizedBaseline)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(theme.inkLight.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Data line
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(data.count - 1)

                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalized = normalizedValue(value)
                            let y = geometry.size.height * (1 - normalized)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Data points
                    ForEach(data.indices, id: \.self) { index in
                        let stepX = geometry.size.width / CGFloat(data.count - 1)
                        let x = CGFloat(index) * stepX
                        let normalized = normalizedValue(data[index])
                        let y = geometry.size.height * (1 - normalized)

                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }

    private func normalizedValue(_ value: Int) -> CGFloat {
        let minVal = CGFloat(data.min() ?? 0)
        let maxVal = CGFloat(data.max() ?? 100)

        // Add padding
        let range = max(maxVal - minVal, 20)
        let paddedMin = minVal - range * 0.1
        let paddedMax = maxVal + range * 0.1
        let paddedRange = paddedMax - paddedMin

        guard paddedRange > 0 else { return 0.5 }
        return (CGFloat(value) - paddedMin) / paddedRange
    }
}
