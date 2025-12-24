//
//  OrgChartConnector.swift
//  Nomenklatura
//
//  Connection lines for the organizational chart
//  Draws vertical and horizontal lines between position nodes
//

import SwiftUI

// MARK: - Vertical Connector (Single Line Down)

struct VerticalConnector: View {
    let height: CGFloat
    let isHighlighted: Bool
    let isAchieved: Bool

    @Environment(\.theme) var theme

    var body: some View {
        Rectangle()
            .fill(lineColor)
            .frame(width: lineWidth, height: height)
    }

    private var lineColor: Color {
        if isHighlighted {
            return theme.sovietRed
        } else if isAchieved {
            return theme.accentGold
        } else {
            return theme.borderTan
        }
    }

    private var lineWidth: CGFloat {
        isHighlighted ? 3 : 2
    }
}

// MARK: - Horizontal Connector (Line Across)

struct HorizontalConnector: View {
    let width: CGFloat
    let isHighlighted: Bool

    @Environment(\.theme) var theme

    var body: some View {
        Rectangle()
            .fill(isHighlighted ? theme.sovietRed : theme.borderTan)
            .frame(width: width, height: isHighlighted ? 3 : 2)
    }
}

// MARK: - Branch Connector (One to Many)

struct BranchConnector: View {
    let branchCount: Int
    let spacing: CGFloat
    let dropHeight: CGFloat
    let highlightedIndex: Int?  // Which branch to highlight (-1 for none)

    @Environment(\.theme) var theme

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let startY: CGFloat = 0
            let midY = dropHeight / 2
            let endY = dropHeight

            // Vertical line from top to mid
            var path = Path()
            path.move(to: CGPoint(x: centerX, y: startY))
            path.addLine(to: CGPoint(x: centerX, y: midY))
            context.stroke(path, with: .color(theme.borderTan), lineWidth: 2)

            // Calculate branch positions
            let totalWidth = CGFloat(branchCount - 1) * spacing
            let startX = centerX - totalWidth / 2

            // Horizontal line across all branches
            var horizPath = Path()
            horizPath.move(to: CGPoint(x: startX, y: midY))
            horizPath.addLine(to: CGPoint(x: startX + totalWidth, y: midY))
            context.stroke(horizPath, with: .color(theme.borderTan), lineWidth: 2)

            // Vertical drops to each branch
            for i in 0..<branchCount {
                let branchX = startX + CGFloat(i) * spacing
                var branchPath = Path()
                branchPath.move(to: CGPoint(x: branchX, y: midY))
                branchPath.addLine(to: CGPoint(x: branchX, y: endY))

                let isHighlighted = highlightedIndex == i
                context.stroke(
                    branchPath,
                    with: .color(isHighlighted ? theme.sovietRed : theme.borderTan),
                    lineWidth: isHighlighted ? 3 : 2
                )
            }
        }
        .frame(height: dropHeight)
    }
}

// MARK: - Merge Connector (Many to One)

struct MergeConnector: View {
    let branchCount: Int
    let spacing: CGFloat
    let riseHeight: CGFloat
    let highlightedIndex: Int?

    @Environment(\.theme) var theme

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let startY: CGFloat = 0
            let midY = riseHeight / 2
            let endY = riseHeight

            // Calculate branch positions
            let totalWidth = CGFloat(branchCount - 1) * spacing
            let startX = centerX - totalWidth / 2

            // Vertical rises from each branch
            for i in 0..<branchCount {
                let branchX = startX + CGFloat(i) * spacing
                var branchPath = Path()
                branchPath.move(to: CGPoint(x: branchX, y: startY))
                branchPath.addLine(to: CGPoint(x: branchX, y: midY))

                let isHighlighted = highlightedIndex == i
                context.stroke(
                    branchPath,
                    with: .color(isHighlighted ? theme.sovietRed : theme.borderTan),
                    lineWidth: isHighlighted ? 3 : 2
                )
            }

            // Horizontal line across all branches
            var horizPath = Path()
            horizPath.move(to: CGPoint(x: startX, y: midY))
            horizPath.addLine(to: CGPoint(x: startX + totalWidth, y: midY))
            context.stroke(horizPath, with: .color(theme.borderTan), lineWidth: 2)

            // Vertical line from mid to bottom center
            var centerPath = Path()
            centerPath.move(to: CGPoint(x: centerX, y: midY))
            centerPath.addLine(to: CGPoint(x: centerX, y: endY))
            context.stroke(centerPath, with: .color(theme.borderTan), lineWidth: 2)
        }
        .frame(height: riseHeight)
    }
}

// MARK: - Simple Vertical Drop with Node Spacing

struct NodeConnector: View {
    let height: CGFloat
    let isOnPlayerPath: Bool
    let isAchieved: Bool

    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(lineColor)
                .frame(width: lineWidth, height: height)
        }
    }

    private var lineColor: Color {
        if isOnPlayerPath {
            return theme.sovietRed.opacity(0.8)
        } else if isAchieved {
            return theme.accentGold
        } else {
            return theme.borderTan
        }
    }

    private var lineWidth: CGFloat {
        isOnPlayerPath ? 3 : 2
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Single vertical
        VStack {
            Text("Vertical Connector")
                .font(.caption)
            VerticalConnector(height: 40, isHighlighted: false, isAchieved: false)
        }

        // Highlighted vertical
        VStack {
            Text("Highlighted Vertical")
                .font(.caption)
            VerticalConnector(height: 40, isHighlighted: true, isAchieved: false)
        }

        // Branch connector (1 to 6)
        VStack {
            Text("Branch Connector (1→6)")
                .font(.caption)
            BranchConnector(
                branchCount: 6,
                spacing: 100,
                dropHeight: 50,
                highlightedIndex: 2
            )
            .frame(width: 600)
        }

        // Merge connector (6 to 1)
        VStack {
            Text("Merge Connector (6→1)")
                .font(.caption)
            MergeConnector(
                branchCount: 6,
                spacing: 100,
                riseHeight: 50,
                highlightedIndex: 3
            )
            .frame(width: 600)
        }
    }
    .padding()
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}
