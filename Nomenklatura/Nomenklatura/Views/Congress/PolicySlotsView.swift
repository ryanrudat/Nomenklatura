//
//  PolicySlotsView.swift
//  Nomenklatura
//
//  Displays policy slots organized by institution.
//  Shows competing policy options for each slot and allows changes.
//

import SwiftUI
import SwiftData

struct PolicySlotsView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedInstitution: Institution = .presidium
    @State private var selectedSlot: PolicySlot?
    @State private var showingChangeSheet = false

    private var slotsForInstitution: [PolicySlot] {
        game.policySlots(for: selectedInstitution)
            .sorted { $0.name < $1.name }
    }

    private var playerCanProposePolicies: Bool {
        // Must be on Standing Committee to propose policy changes
        game.currentPositionIndex >= 7
    }

    var body: some View {
        VStack(spacing: 0) {
            // Institution selector tabs
            InstitutionTabBar(selectedInstitution: $selectedInstitution)
                .padding(.horizontal, 15)
                .padding(.top, 10)

            // Policy slots list
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Institution header
                    InstitutionHeaderCard(institution: selectedInstitution)
                        .padding(.horizontal, 15)
                        .padding(.top, 10)

                    // Policy slots
                    ForEach(slotsForInstitution, id: \.id) { slot in
                        PolicySlotCard(
                            slot: slot,
                            game: game,
                            canChange: playerCanProposePolicies
                        ) {
                            selectedSlot = slot
                            showingChangeSheet = true
                        }
                        .padding(.horizontal, 15)
                    }

                    // Empty state
                    if slotsForInstitution.isEmpty {
                        VStack(spacing: 10) {
                            Text("No policies for this institution")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkGray)
                        }
                        .padding(30)
                    }

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)

            // Power consolidation meter
            PowerConsolidationMeter(score: game.powerConsolidationScore)
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
        }
        .sheet(isPresented: $showingChangeSheet) {
            if let slot = selectedSlot {
                PolicyChangeSheet(slot: slot, game: game)
            }
        }
    }
}

// MARK: - Institution Tab Bar

struct InstitutionTabBar: View {
    @Binding var selectedInstitution: Institution
    @Environment(\.theme) var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Institution.allCases, id: \.self) { institution in
                    InstitutionTabButton(
                        institution: institution,
                        isSelected: selectedInstitution == institution
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedInstitution = institution
                        }
                    }
                }
            }
        }
    }
}

struct InstitutionTabButton: View {
    let institution: Institution
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: institution.icon)
                    .font(.system(size: 16))
                Text(institution.shortName)
                    .font(.system(size: 8, weight: .semibold))
            }
            .frame(width: 55, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? institution.accentColor.opacity(0.15) : Color.clear)
            )
            .foregroundColor(isSelected ? institution.accentColor : theme.inkGray)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? institution.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Institution Header Card

struct InstitutionHeaderCard: View {
    let institution: Institution
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: institution.icon)
                .font(.system(size: 28))
                .foregroundColor(institution.accentColor)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(institution.displayName.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkBlack)

                Text(institution.description)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkGray)
                    .lineLimit(3)
            }

            Spacer()

            // Base difficulty indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text("Difficulty")
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)
                Text("\(institution.baseDifficulty)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(difficultyColor)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(institution.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var difficultyColor: Color {
        switch institution.baseDifficulty {
        case 70...: return .statLow
        case 50..<70: return .statMedium
        default: return .statHigh
        }
    }
}

// MARK: - Policy Slot Card

struct PolicySlotCard: View {
    @Bindable var slot: PolicySlot
    @Bindable var game: Game
    let canChange: Bool
    let onChangeRequest: () -> Void
    @Environment(\.theme) var theme

    private var currentOption: PolicyOption? {
        slot.currentOption
    }

    private var hasBeenModified: Bool {
        slot.hasBeenModified
    }

    private var hasPending: Bool {
        slot.hasPendingProposal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(slot.name.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(theme.inkBlack)

                Spacer()

                // Status badges
                HStack(spacing: 6) {
                    if hasBeenModified {
                        StatusBadge(text: "MODIFIED", color: theme.accentGold)
                    }
                    if hasPending {
                        StatusBadge(text: "PENDING", color: theme.sovietRed)
                    }
                    if slot.wasCurrentPolicyDecreed {
                        StatusBadge(text: "DECREED", color: theme.stampRed)
                    }
                }
            }

            // Description
            Text(slot.slotDescription)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
                .lineLimit(2)

            // Current policy
            if let option = currentOption {
                CurrentPolicyView(option: option)
            }

            // Other options (collapsed)
            OtherOptionsPreview(slot: slot)

            // Change button
            if canChange && !hasPending {
                HStack {
                    Spacer()

                    Button(action: onChangeRequest) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12))
                            Text("CHANGE POLICY")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.sovietRed.opacity(0.1))
                        .foregroundColor(theme.sovietRed)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.sovietRed.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else if hasPending {
                HStack {
                    Spacer()
                    Text("Vote pending next turn")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.inkGray)
                        .italic()
                }
            }
        }
        .padding(14)
        .background(theme.parchment)
        .overlay(
            Rectangle()
                .stroke(hasBeenModified ? theme.accentGold.opacity(0.4) : theme.borderTan, lineWidth: 1)
        )
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
    }
}

struct CurrentPolicyView: View {
    let option: PolicyOption
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.statHigh)

                Text("Current: \(option.name)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.inkBlack)

                if option.isExtreme {
                    Text("EXTREME")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.statLow.opacity(0.2))
                        .foregroundColor(.statLow)
                }

                Spacer()
            }

            Text(option.description)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
                .lineLimit(2)

            // Effects summary
            EffectsSummaryView(effects: option.effects)
        }
        .padding(10)
        .background(theme.parchmentDark.opacity(0.5))
    }
}

struct EffectsSummaryView: View {
    let effects: PolicyEffects
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 8) {
            if effects.stabilityModifier != 0 {
                EffectBadge(label: "Stability", value: effects.stabilityModifier)
            }
            if effects.popularSupportModifier != 0 {
                EffectBadge(label: "Popular", value: effects.popularSupportModifier)
            }
            if effects.eliteLoyaltyModifier != 0 {
                EffectBadge(label: "Elite", value: effects.eliteLoyaltyModifier)
            }
            if effects.economicOutputModifier != 0 {
                EffectBadge(label: "Economy", value: effects.economicOutputModifier)
            }
            if effects.militaryLoyaltyModifier != 0 {
                EffectBadge(label: "Military", value: effects.militaryLoyaltyModifier)
            }
            if effects.enablesDecrees {
                SpecialEffectBadge(label: "Decrees", isEnabled: true)
            }
            if effects.enablesPurges {
                SpecialEffectBadge(label: "Purges", isEnabled: true)
            }
        }
        .font(.system(size: 9))
    }
}

struct EffectBadge: View {
    let label: String
    let value: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundColor(theme.inkLight)
            Text(value > 0 ? "+\(value)" : "\(value)")
                .fontWeight(.bold)
                .foregroundColor(value > 0 ? .statHigh : .statLow)
        }
    }
}

struct SpecialEffectBadge: View {
    let label: String
    let isEnabled: Bool
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isEnabled ? "checkmark" : "xmark")
                .font(.system(size: 8))
            Text(label)
        }
        .foregroundColor(isEnabled ? theme.sovietRed : theme.inkLight)
    }
}

struct OtherOptionsPreview: View {
    let slot: PolicySlot
    @Environment(\.theme) var theme

    private var otherOptions: [PolicyOption] {
        slot.options.filter { $0.id != slot.currentOptionId }
    }

    var body: some View {
        if !otherOptions.isEmpty {
            HStack(spacing: 4) {
                Text("Alternatives:")
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)

                ForEach(otherOptions.prefix(3), id: \.id) { option in
                    Text(option.name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.inkGray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.parchmentDark)
                }

                if otherOptions.count > 3 {
                    Text("+\(otherOptions.count - 3) more")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkLight)
                }
            }
        }
    }
}

// MARK: - Policy Change Sheet

struct PolicyChangeSheet: View {
    @Bindable var slot: PolicySlot
    @Bindable var game: Game
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme
    @State private var selectedOptionId: String?
    @State private var showingConfirmation = false
    @State private var changeResult: PolicyChangeResult?

    private var options: [PolicyOption] {
        slot.options.filter { $0.id != slot.currentOptionId }
    }

    private var selectedOption: PolicyOption? {
        guard let id = selectedOptionId else { return nil }
        return slot.option(withId: id)
    }

    private var canChange: Bool {
        guard let optionId = selectedOptionId else { return false }
        let validation = PolicyService.shared.canChangePolicy(
            game: game,
            slotId: slot.slotId,
            toOptionId: optionId,
            byPlayer: true
        )
        return validation.canChange
    }

    private var changeValidation: PolicyChangeValidation? {
        guard let optionId = selectedOptionId else { return nil }
        return PolicyService.shared.canChangePolicy(
            game: game,
            slotId: slot.slotId,
            toOptionId: optionId,
            byPlayer: true
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Current policy header
                    CurrentPolicyHeader(slot: slot)
                        .padding(.horizontal, 15)

                    // Available options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ALTERNATIVE POLICIES")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(theme.inkGray)
                            .padding(.horizontal, 15)

                        ForEach(options, id: \.id) { option in
                            PolicyOptionCard(
                                option: option,
                                isSelected: selectedOptionId == option.id,
                                canSelect: canSelectOption(option)
                            ) {
                                selectedOptionId = option.id
                            }
                            .padding(.horizontal, 15)
                        }
                    }

                    // Validation info
                    if let validation = changeValidation, !validation.canChange {
                        ValidationWarning(reason: validation.reason ?? "Cannot make this change")
                            .padding(.horizontal, 15)
                    }

                    // Requirements
                    if let validation = changeValidation, validation.canChange {
                        RequirementsView(validation: validation)
                            .padding(.horizontal, 15)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 15)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                ChangeActionBar(
                    canChange: canChange,
                    onPropose: {
                        executeChange(asDecree: false)
                    },
                    onDecree: game.decreesEnabled && slot.category != .institutional ? {
                        executeChange(asDecree: true)
                    } : nil
                )
            }
            .navigationTitle("Change \(slot.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Policy Changed", isPresented: $showingConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let result = changeResult {
                    Text(result.message)
                }
            }
        }
    }

    private func canSelectOption(_ option: PolicyOption) -> Bool {
        // Validate but allow selection even if can't change, to show requirements
        _ = PolicyService.shared.canChangePolicy(
            game: game,
            slotId: slot.slotId,
            toOptionId: option.id,
            byPlayer: true
        )
        return true
    }

    private func executeChange(asDecree: Bool) {
        guard let optionId = selectedOptionId else { return }

        changeResult = PolicyService.shared.changePolicy(
            game: game,
            slotId: slot.slotId,
            toOptionId: optionId,
            byCharacterId: nil,
            byPlayer: true,
            asDecree: asDecree
        )

        showingConfirmation = true
    }
}

struct CurrentPolicyHeader: View {
    let slot: PolicySlot
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CURRENT POLICY")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            if let current = slot.currentOption {
                VStack(alignment: .leading, spacing: 6) {
                    Text(current.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.inkBlack)

                    Text(current.description)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkGray)

                    EffectsSummaryView(effects: current.effects)
                }
                .padding(12)
                .background(theme.parchmentDark)
                .overlay(
                    Rectangle()
                        .stroke(theme.borderTan, lineWidth: 1)
                )
            }
        }
    }
}

struct PolicyOptionCard: View {
    let option: PolicyOption
    let isSelected: Bool
    let canSelect: Bool
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? theme.sovietRed : theme.inkLight)

                    Text(option.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.inkBlack)

                    if option.isExtreme {
                        Text("EXTREME")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.statLow.opacity(0.2))
                            .foregroundColor(.statLow)
                    }

                    Spacer()

                    // Power required
                    Text("Power: \(option.minimumPowerRequired)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }

                Text(option.description)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkGray)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                EffectsSummaryView(effects: option.effects)

                // Beneficiaries/Losers
                if !option.beneficiaries.isEmpty || !option.losers.isEmpty {
                    FactionImpactView(beneficiaries: option.beneficiaries, losers: option.losers)
                }
            }
            .padding(12)
            .background(isSelected ? theme.sovietRed.opacity(0.05) : theme.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? theme.sovietRed : theme.borderTan, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSelect)
        .opacity(canSelect ? 1.0 : 0.6)
    }
}

struct FactionImpactView: View {
    let beneficiaries: [String]
    let losers: [String]
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            if !beneficiaries.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.statHigh)
                    Text(beneficiaries.map { formatFaction($0) }.joined(separator: ", "))
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                }
            }

            if !losers.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.statLow)
                    Text(losers.map { formatFaction($0) }.joined(separator: ", "))
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                }
            }
        }
    }

    private func formatFaction(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct ValidationWarning: View {
    let reason: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(.statLow)

            Text(reason)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)

            Spacer()
        }
        .padding(12)
        .background(Color.statLow.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(Color.statLow.opacity(0.3), lineWidth: 1)
        )
    }
}

struct RequirementsView: View {
    let validation: PolicyChangeValidation
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REQUIREMENTS MET")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.statHigh)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.statHigh)
                    Text("Power: \(validation.powerRequired)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkGray)
                }

                if validation.canDecree {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accentGold)
                        Text("Decree: \(validation.decreePowerRequired)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.inkGray)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.statHigh.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(Color.statHigh.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ChangeActionBar: View {
    let canChange: Bool
    let onPropose: () -> Void
    let onDecree: (() -> Void)?
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 12) {
                // Propose button (normal route)
                Button(action: onPropose) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                        Text("SUBMIT PROPOSAL")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canChange ? theme.sovietRed : theme.inkLight)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canChange)

                // Decree button (if available)
                if let onDecree = onDecree {
                    Button(action: onDecree) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                            Text("DECREE")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canChange ? theme.accentGold : theme.inkLight)
                        .foregroundColor(theme.inkBlack)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canChange)
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 15)
        }
        .background(theme.parchment)
    }
}
