//
//  ActionCardView.swift
//  Nomenklatura
//
//  Action card component for personal actions phase
//

import SwiftUI

struct ActionCardView: View {
    let action: PersonalAction
    let isAvailable: Bool
    var lockReason: String? = nil
    var game: Game? = nil  // Optional game context for dynamic flavor text
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    /// The reason to display (prioritizes passed-in reason, then action's own reason)
    private var displayLockReason: String? {
        lockReason ?? action.lockReason
    }

    /// Whether to show as locked (either explicitly locked or not available)
    private var showAsLocked: Bool {
        action.isLocked || !isAvailable
    }

    /// Get flavor text - from action or generated dynamically
    private var flavorText: String? {
        if let staticFlavor = action.flavorText {
            return staticFlavor
        }
        if let game = game {
            return NarrativeGenerator.shared.getActionFlavorText(for: action.id, game: game)
        }
        return nil
    }

    var body: some View {
        Button(action: {
            if isAvailable && !action.isLocked {
                onSelect()
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Title row
                HStack {
                    if showAsLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "666666"))
                    }

                    Text(action.title)
                        .font(theme.bodyFontSmall)
                        .fontWeight(.medium)
                        .foregroundColor(showAsLocked ? Color(hex: "666666") : theme.schemeText)
                }

                // Flavor text - atmospheric description
                if !showAsLocked, let flavor = flavorText {
                    Text(flavor)
                        .font(theme.tagFont)
                        .italic()
                        .foregroundColor(Color(hex: "999999"))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Cost and effects row
                HStack(spacing: 8) {
                    // AP cost with icon
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                        Text("\(action.costAP)")
                            .font(theme.tagFont)
                    }
                    .foregroundColor(Color(hex: "888888"))

                    // Primary effect
                    if let primaryEffect = getPrimaryEffect() {
                        Text("•")
                            .foregroundColor(Color(hex: "555555"))
                        Text(primaryEffect)
                            .font(theme.tagFont)
                            .foregroundColor(theme.accentGold)
                    }

                    // Risk indicator
                    Text("•")
                        .foregroundColor(Color(hex: "555555"))
                    HStack(spacing: 3) {
                        Circle()
                            .fill(riskColor)
                            .frame(width: 6, height: 6)
                        Text(action.riskLevel.displayName)
                            .font(theme.tagFont)
                            .foregroundColor(riskColor)
                    }
                }

                // Lock reason if locked or unavailable
                if showAsLocked, let reason = displayLockReason {
                    Text(reason)
                        .font(theme.tagFont)
                        .foregroundColor(Color(hex: "666666"))
                        .italic()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(theme.schemeCard)
            .overlay(
                Rectangle()
                    .stroke(showAsLocked ? theme.schemeBorder.opacity(0.5) : theme.schemeBorder, lineWidth: 1)
            )
            .opacity(showAsLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(showAsLocked)
    }

    private var riskColor: Color {
        switch action.riskLevel {
        case .low: return .statHigh
        case .medium: return .statMedium
        case .high: return .statLow
        }
    }

    private func getPrimaryEffect() -> String? {
        guard let (key, value) = action.effects.first else { return nil }

        let statNames: [String: String] = [
            "network": "Network",
            "patronFavor": "Favor",
            "rivalThreat": "Rival",
            "standing": "Standing",
            "reputationCunning": "Cunning",
            "reputationRuthless": "Ruthless",
            "reputationLoyal": "Loyal"
        ]

        if let name = statNames[key] {
            let sign = value >= 0 ? "+" : ""
            return "\(name) \(sign)\(value)"
        }

        return nil
    }
}

#Preview {
    let actions = [
        PersonalAction(
            id: "plant_ally",
            category: .buildNetwork,
            title: "Plant ally in Wallace's department",
            description: "Cultivate an informant.",
            costAP: 1,
            riskLevel: .low,
            requirements: nil,
            effects: ["network": 5],
            isLocked: false,
            lockReason: nil
        ),
        PersonalAction(
            id: "propose_promotion",
            category: .makeYourPlay,
            title: "Propose yourself for Department Head",
            description: "Request promotion.",
            costAP: 2,
            riskLevel: .medium,
            requirements: ActionRequirements(minStanding: 65),
            effects: ["standing": 10],
            isLocked: true,
            lockReason: "Requires Standing 65+"
        )
    ]

    return VStack(spacing: 10) {
        ActionCardView(action: actions[0], isAvailable: true) {}
        ActionCardView(action: actions[1], isAvailable: false) {}
    }
    .padding()
    .background(Color(hex: "1A1A1A"))
    .environment(\.theme, ColdWarTheme())
}
