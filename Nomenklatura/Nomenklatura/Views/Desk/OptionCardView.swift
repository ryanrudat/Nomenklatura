//
//  OptionCardView.swift
//  Nomenklatura
//
//  Option card component for decision choices
//

import SwiftUI

struct OptionCardView: View {
    let option: ScenarioOption
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 0) {
                // Letter badge
                OptionLetterBadge(letter: option.id, isSelected: isSelected)
                    .offset(x: -12)

                VStack(alignment: .leading, spacing: 8) {
                    // Option description
                    Text(option.shortDescription)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkBlack)
                        .multilineTextAlignment(.leading)

                    // Effect tags
                    FlowLayout(spacing: 6) {
                        ForEach(option.getDisplayEffects()) { effect in
                            EffectTagView(effect: effect)
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color(hex: "FFFDF0") : theme.parchmentDark)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? theme.stampRed : theme.borderTan,
                           lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Option Letter Badge

struct OptionLetterBadge: View {
    let letter: String
    let isSelected: Bool
    @Environment(\.theme) var theme

    var body: some View {
        Text(letter)
            .font(theme.labelFont)
            .fontWeight(.bold)
            .foregroundColor(isSelected ? theme.parchmentDark : theme.schemeText)
            .frame(width: 24, height: 24)
            .background(isSelected ? theme.stampRed : theme.schemeCard)
            .clipShape(Circle())
    }
}

// MARK: - Locked Option Card

struct LockedOptionCardView: View {
    let option: ScenarioOption
    @Environment(\.theme) var theme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(theme.inkLight)
                .frame(width: 24, height: 24)
                .offset(x: -12)

            VStack(alignment: .leading, spacing: 4) {
                Text(option.shortDescription)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkLight)

                if let reason = option.lockReason {
                    Text(reason)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkLight)
                        .italic()
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.parchment.opacity(0.5))
        .overlay(
            Rectangle()
                .stroke(theme.borderTan.opacity(0.5), lineWidth: 1)
        )
        .opacity(0.6)
    }
}

#Preview {
    let options = [
        ScenarioOption(
            id: "A",
            archetype: .repress,
            shortDescription: "Support Wallace's crackdown. Authorize arrests of \"agitators.\"",
            immediateOutcome: "The military moves in swiftly.",
            statEffects: ["stability": 15, "popularSupport": -20],
            personalEffects: ["patronFavor": 5],
            followUpHook: nil,
            isLocked: false,
            lockReason: nil
        ),
        ScenarioOption(
            id: "B",
            archetype: .reform,
            shortDescription: "Propose revising the quotas. The targets were unrealistic.",
            immediateOutcome: "Workers return, but production targets slip.",
            statEffects: ["popularSupport": 10, "industrialOutput": -10],
            personalEffects: ["standing": 8],
            followUpHook: nil,
            isLocked: false,
            lockReason: nil
        ),
        ScenarioOption(
            id: "C",
            archetype: .deflect,
            shortDescription: "Quietly suggest to the General Secretary that Wallace's department set these quotas...",
            immediateOutcome: "Seeds of doubt are planted.",
            statEffects: [:],
            personalEffects: ["rivalThreat": -10, "patronFavor": -3, "reputationCunning": 10],
            followUpHook: nil,
            isLocked: false,
            lockReason: nil
        )
    ]

    return VStack(spacing: 10) {
        OptionCardView(option: options[0], isSelected: false) {}
        OptionCardView(option: options[1], isSelected: true) {}
        OptionCardView(option: options[2], isSelected: false) {}
    }
    .padding()
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}
