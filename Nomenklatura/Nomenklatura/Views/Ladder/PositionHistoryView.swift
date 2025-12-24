//
//  PositionHistoryView.swift
//  Nomenklatura
//
//  Shows the historical timeline of position holders
//

import SwiftUI

struct PositionHistoryView: View {
    let positionIndex: Int
    let positionTitle: String
    let holders: [PositionHolder]
    @State private var isExpanded = false
    @Environment(\.theme) var theme

    /// Current holder (if any)
    private var currentHolder: PositionHolder? {
        holders.first { $0.isCurrent }
    }

    /// Previous holders, sorted by most recent first
    private var previousHolders: [PositionHolder] {
        holders.filter { !$0.isCurrent }
            .sorted { ($0.turnEnded ?? 0) > ($1.turnEnded ?? 0) }
    }

    /// Most recent previous holder
    private var mostRecentPrevious: PositionHolder? {
        previousHolders.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header - tap to expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("POSITION HISTORY")
                        .font(theme.tagFont)
                        .fontWeight(.semibold)
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }
            }
            .buttonStyle(.plain)

            // Current holder
            if let current = currentHolder {
                HolderRow(
                    holder: current,
                    isCurrent: true,
                    showEndReason: false
                )
            }

            // Previous holder (always shown)
            if let previous = mostRecentPrevious {
                HolderRow(
                    holder: previous,
                    isCurrent: false,
                    showEndReason: true
                )
            }

            // Expanded: show all previous holders
            if isExpanded && previousHolders.count > 1 {
                ForEach(previousHolders.dropFirst()) { holder in
                    HolderRow(
                        holder: holder,
                        isCurrent: false,
                        showEndReason: true
                    )
                }
            }

            // Show count if more history exists
            if !isExpanded && previousHolders.count > 1 {
                Text("+ \(previousHolders.count - 1) more")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkLight)
                    .italic()
                    .padding(.leading, 20)
            }
        }
        .padding(12)
        .background(theme.parchmentDark.opacity(0.5))
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Holder Row

private struct HolderRow: View {
    let holder: PositionHolder
    let isCurrent: Bool
    let showEndReason: Bool
    @Environment(\.theme) var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 10, height: 10)

                if !isCurrent {
                    Rectangle()
                        .fill(theme.borderTan)
                        .frame(width: 1)
                        .frame(minHeight: 20)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(holder.characterName)
                        .font(theme.labelFont)
                        .fontWeight(isCurrent ? .semibold : .regular)
                        .foregroundColor(isCurrent ? theme.inkBlack : theme.inkGray)

                    if holder.wasPlayer {
                        Text("(You)")
                            .font(theme.tagFont)
                            .foregroundColor(theme.stampRed)
                    }

                    if isCurrent {
                        Text("CURRENT")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "4A7C59"))
                            .foregroundColor(.white)
                    }
                }

                // Tenure
                Text(holder.tenureDisplayString)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkLight)

                // End reason (for past holders)
                if showEndReason, let reason = holder.endReason {
                    HStack(spacing: 4) {
                        Image(systemName: reason.icon)
                            .font(.system(size: 10))
                        Text(reason.displayText)
                            .font(theme.tagFont)
                    }
                    .foregroundColor(reasonColor(for: reason))
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
    }

    private var indicatorColor: Color {
        if isCurrent {
            return Color(hex: "4A7C59") // Green for current
        }
        if let reason = holder.endReason {
            switch reason.color {
            case "positiveGreen": return Color(hex: "4A7C59")
            case "warningYellow": return Color(hex: "B8860B")
            case "dangerRed": return Color(hex: "8B0000")
            default: return Color.gray
            }
        }
        return Color.gray
    }

    private func reasonColor(for reason: PositionEndReason) -> Color {
        switch reason.color {
        case "positiveGreen": return Color(hex: "4A7C59")
        case "warningYellow": return Color(hex: "B8860B")
        case "dangerRed": return Color(hex: "8B0000")
        default: return Color.gray
        }
    }
}

// MARK: - Preview

#Preview("Position History") {
    PositionHistoryView(
        positionIndex: 3,
        positionTitle: "Deputy Minister",
        holders: []
    )
    .padding()
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}
