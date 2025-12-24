//
//  EffectTagView.swift
//  Nomenklatura
//
//  Effect tag component for displaying stat changes
//

import SwiftUI

struct EffectTagView: View {
    let effect: StatEffect
    @Environment(\.theme) var theme

    private var backgroundColor: Color {
        switch effect.effectType {
        case .positive: return .effectPositiveBg
        case .negative: return .effectNegativeBg
        case .personal: return .effectPersonalBg
        }
    }

    private var textColor: Color {
        switch effect.effectType {
        case .positive: return .effectPositiveText
        case .negative: return .effectNegativeText
        case .personal: return .effectPersonalText
        }
    }

    var body: some View {
        Text(effect.displayString)
            .font(theme.tagFont)
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Simple Effect Tag (for predefined strings)

struct SimpleEffectTag: View {
    let text: String
    let type: EffectType
    @Environment(\.theme) var theme

    private var backgroundColor: Color {
        switch type {
        case .positive: return .effectPositiveBg
        case .negative: return .effectNegativeBg
        case .personal: return .effectPersonalBg
        }
    }

    private var textColor: Color {
        switch type {
        case .positive: return .effectPositiveText
        case .negative: return .effectNegativeText
        case .personal: return .effectPersonalText
        }
    }

    var body: some View {
        Text(text)
            .font(theme.tagFont)
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Effect Tags Row

struct EffectTagsRow: View {
    let effects: [StatEffect]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(effects) { effect in
                EffectTagView(effect: effect)
            }
        }
    }
}

// MARK: - Flow Layout for wrapping tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        HStack(spacing: 6) {
            SimpleEffectTag(text: "+15 Stability", type: .positive)
            SimpleEffectTag(text: "-20 Popular", type: .negative)
            SimpleEffectTag(text: "+5 Favor", type: .personal)
        }

        HStack(spacing: 6) {
            SimpleEffectTag(text: "Reputation: Cunning", type: .personal)
            SimpleEffectTag(text: "-10 Rival", type: .positive)
        }
    }
    .padding()
    .background(Color(hex: "FFFEF7"))
    .environment(\.theme, ColdWarTheme())
}
