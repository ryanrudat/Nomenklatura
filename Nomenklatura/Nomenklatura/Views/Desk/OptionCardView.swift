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
    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 0) {
                // Stance-colored stripe — full-height, replaces the old
                // floating letter badge. The color signals which career
                // track the option advances.
                Rectangle()
                    .fill(stanceColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    // Stance header: letter + archetype name. Mono + tracked
                    // reads like the prototype's document-form affordance.
                    HStack(spacing: 8) {
                        Text(option.id)
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(stanceColor)
                        Rectangle()
                            .fill(stanceColor.opacity(0.35))
                            .frame(width: 1, height: 10)
                        Text(option.archetype.displayName.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(stanceColor)
                        Spacer()
                    }

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

                        // Archetype indicator - shows bureau direction
                        if let track = option.archetype.associatedTrack {
                            ArchetypeIndicator(
                                archetype: option.archetype,
                                track: track
                            )
                        }
                    }
                }
                .padding(.leading, 12)
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
            // Press feedback: 1px down + inset shadow reads as "pressing
            // a physical key on a bureaucratic form."
            .offset(y: isPressed ? 1 : 0)
            .overlay(
                Rectangle()
                    .stroke(Color.black.opacity(isPressed ? 0.15 : 0), lineWidth: 2)
                    .blur(radius: 2)
                    .mask(Rectangle())
            )
            .animation(.easeOut(duration: 0.08), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    /// Color mapping for the stance stripe. Tracks the prototype's
    /// archetype → color palette (red orthodox, gold reform, teal cunning,
    /// dark red iron fist).
    private var stanceColor: Color {
        switch option.archetype.associatedTrack {
        case .securityServices: return Color(hex: "7A1818")  // Iron Fist red
        case .militaryPolitical: return Color(hex: "7A1818")
        case .partyApparatus:    return Color(hex: "A03030")  // Orthodox red
        case .economicPlanning:  return Color(hex: "C89030")  // Reformist gold
        case .foreignAffairs:    return Color(hex: "3A6A7A")  // Diplomat teal
        case .stateMinistry:     return Color(hex: "5A5040")  // Administrator sepia
        case .regional:          return Color(hex: "4A5A3A")  // Regional olive
        case .shared, .none:     return theme.concreteGray
        }
    }
}

// MARK: - Archetype Indicator

struct ArchetypeIndicator: View {
    let archetype: OptionArchetype
    let track: ExpandedCareerTrack
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: track.iconName)
                .font(.system(size: 8))
            Text(track.shortName)
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundColor(theme.accentGold)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(theme.accentGold.opacity(0.12))
        .cornerRadius(3)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(theme.accentGold.opacity(0.3), lineWidth: 0.5)
        )
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
