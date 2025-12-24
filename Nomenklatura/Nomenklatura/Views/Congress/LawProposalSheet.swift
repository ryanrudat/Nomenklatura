//
//  LawProposalSheet.swift
//  Nomenklatura
//
//  Sheet for proposing changes to a law
//

import SwiftUI
import SwiftData

struct LawProposalSheet: View {
    let law: Law
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @State private var selectedState: LawState?
    @State private var showingConfirmation = false

    private var availableStates: [LawState] {
        // Filter out current state and determine available transitions
        LawState.allCases.filter { state in
            state != law.lawCurrentState && state != .defaultState
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.parchment.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Current law info
                        CurrentLawInfo(law: law)

                        // State selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PROPOSED CHANGE")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1)
                                .foregroundColor(theme.inkGray)

                            ForEach(availableStates, id: \.self) { state in
                                StateOptionRow(
                                    state: state,
                                    law: law,
                                    game: game,
                                    isSelected: selectedState == state
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedState = state
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 15)

                        // Requirements info
                        if let state = selectedState {
                            RequirementsCard(law: law, toState: state, game: game)
                                .padding(.horizontal, 15)
                        }

                        // Warning about consequences
                        ConsequenceWarning(law: law)
                            .padding(.horizontal, 15)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 15)
                }
            }
            .navigationTitle("Propose Law Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        showingConfirmation = true
                    }
                    .disabled(selectedState == nil || !canSubmit)
                }
            }
            .alert("Submit Proposal", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Submit", role: .destructive) {
                    submitProposal()
                }
            } message: {
                Text("This proposal will be submitted to the Standing Committee for a vote. Are you sure?")
            }
        }
    }

    private var canSubmit: Bool {
        guard let state = selectedState else { return false }
        let requirements = LawChangeRequirement.requirements(for: law, toState: state)
        return game.powerConsolidationScore >= requirements.powerRequired
    }

    private func submitProposal() {
        guard let state = selectedState else { return }

        // Submit law change proposal to Standing Committee agenda
        // The committee will vote on it during their next meeting
        let success = StandingCommitteeService.shared.proposeLawChange(
            law: law,
            newState: state,
            sponsor: nil,  // Player sponsoring
            game: game
        )

        if success {
            // Proposal was added to agenda - will be voted on at next committee meeting
            // The actual law change happens when the vote passes
        } else {
            // Failed to add proposal (shouldn't happen if UI checks are correct)
            // Could show an error here
        }

        dismiss()
    }
}

// MARK: - Current Law Info

struct CurrentLawInfo: View {
    let law: Law
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(law.name)
                        .font(theme.headerFont)
                        .foregroundColor(theme.inkBlack)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: law.lawCategory.iconName)
                                .font(.system(size: 12))
                            Text(law.lawCategory.displayName)
                                .font(theme.tagFont)
                        }
                        .foregroundColor(theme.inkGray)

                        Text("•")
                            .foregroundColor(theme.inkLight)

                        Text("Currently: \(law.lawCurrentState.displayName)")
                            .font(theme.tagFont)
                            .foregroundColor(theme.sovietRed)
                    }
                }

                Spacer()
            }

            Text(law.lawDescription)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
        }
        .padding(15)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
        .padding(.horizontal, 15)
    }
}

// MARK: - State Option Row

struct StateOptionRow: View {
    let state: LawState
    let law: Law
    @Bindable var game: Game
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    private var requirements: LawChangeRequirement {
        LawChangeRequirement.requirements(for: law, toState: state)
    }

    private var canAfford: Bool {
        game.powerConsolidationScore >= requirements.powerRequired
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? theme.sovietRed : theme.inkLight, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(theme.sovietRed)
                            .frame(width: 14, height: 14)
                    }
                }

                // State info
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.displayName.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(canAfford ? theme.inkBlack : theme.inkLight)

                    Text(stateDescription)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                        .lineLimit(2)
                }

                Spacer()

                // Power cost
                VStack(alignment: .trailing, spacing: 2) {
                    Text("POWER")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkLight)

                    Text("\(requirements.powerRequired)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canAfford ? .statHigh : .statLow)
                }
            }
            .padding(12)
            .background(isSelected ? theme.sovietRed.opacity(0.1) : theme.parchment)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? theme.sovietRed : theme.borderTan, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canAfford)
        .opacity(canAfford ? 1.0 : 0.6)
    }

    private var stateDescription: String {
        switch state {
        case .defaultState:
            return "Restore to original state"
        case .modifiedWeak:
            return "Minor adjustments to the law's provisions"
        case .modifiedStrong:
            return "Significant changes to key provisions"
        case .abolished:
            return "Remove this law entirely"
        case .strengthened:
            return "Increase enforcement and penalties"
        }
    }
}

// MARK: - Requirements Card

struct RequirementsCard: View {
    let law: Law
    let toState: LawState
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var requirements: LawChangeRequirement {
        LawChangeRequirement.requirements(for: law, toState: toState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REQUIREMENTS")
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            // Power requirement
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(theme.accentGold)
                Text("Power Consolidation")
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text("\(game.powerConsolidationScore) / \(requirements.powerRequired)")
                    .font(theme.labelFont)
                    .fontWeight(.bold)
                    .foregroundColor(game.powerConsolidationScore >= requirements.powerRequired ? .statHigh : .statLow)
            }

            // Faction support if needed
            if let factionSupport = requirements.factionSupportRequired {
                Divider()

                Text("FACTION SUPPORT REQUIRED")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(theme.inkLight)

                ForEach(Array(factionSupport.keys), id: \.self) { factionId in
                    if let requiredStanding = factionSupport[factionId] {
                        HStack {
                            Text(factionDisplayName(factionId))
                                .font(theme.bodyFontSmall)
                                .foregroundColor(theme.inkGray)

                            Spacer()

                            let currentStanding = getFactionStanding(factionId)
                            Text("\(currentStanding) / \(requiredStanding)")
                                .font(theme.labelFont)
                                .fontWeight(.bold)
                                .foregroundColor(currentStanding >= requiredStanding ? .statHigh : .statLow)
                        }
                    }
                }
            }

            // Force option
            if requirements.canBeForced {
                Divider()

                HStack {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(theme.sovietRed)
                    Text("Can be forced (decree)")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)

                    Spacer()

                    Text("Requires \(requirements.forcePowerRequired) power")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkLight)
                }
            }
        }
        .padding(15)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func factionDisplayName(_ factionId: String) -> String {
        switch factionId {
        case "youth_league": return "Youth League"
        case "princelings": return "Princelings"
        case "reformists": return "Reformists"
        case "old_guard": return "Proletariat Union"
        case "regional": return "Provincial Administration"
        default: return factionId.capitalized
        }
    }

    private func getFactionStanding(_ factionId: String) -> Int {
        game.factions.first { $0.factionId == factionId }?.playerStanding ?? 0
    }
}

// MARK: - Consequence Warning

struct ConsequenceWarning: View {
    let law: Law
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.statLow)
                Text("POTENTIAL CONSEQUENCES")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.statLow)
            }

            Text("Changing laws can trigger delayed consequences including faction backlash, popular unrest, and coalition formation against you. The more significant the change, the greater the risk.")
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)

            if law.lawId == "term_limits" {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(theme.accentGold)
                    Text("Abolishing term limits is an irreversible step toward absolute power.")
                        .font(theme.bodyFontSmall)
                        .italic()
                        .foregroundColor(theme.accentGold)
                }
                .padding(.top, 4)
            }
        }
        .padding(15)
        .background(Color.statLow.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(Color.statLow.opacity(0.3), lineWidth: 1)
        )
    }
}
