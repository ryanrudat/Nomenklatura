//
//  PolicyView.swift
//  Nomenklatura
//
//  Main policy interface - view and interact with Politburo policies
//

import SwiftUI
import SwiftData

struct PolicyView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @Environment(\.modelContext) private var modelContext

    @Query private var policies: [Policy]

    @State private var selectedCategory: PolicyCategory?
    @State private var showingProposalSheet = false

    private var activePolicies: [Policy] {
        policies.filter { $0.currentStatus.isActive }
    }

    private var resolvedPolicies: [Policy] {
        policies.filter { $0.currentStatus.isResolved }
    }

    private var availableAbilities: [PolicyAbility] {
        game.availablePolicyAbilities
    }

    var body: some View {
        ZStack {
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ScreenHeader(
                    title: "The Politburo",
                    subtitle: "Policy & Legislation"
                )

                // Abilities bar
                PolicyAbilitiesBar(abilities: availableAbilities)

                ScrollView {
                    VStack(spacing: 20) {
                        // Active policies section
                        if !activePolicies.isEmpty {
                            PolicySection(
                                title: "BEFORE THE POLITBURO",
                                policies: activePolicies,
                                game: game,
                                onVote: { policy, vote in
                                    castVote(on: policy, vote: vote)
                                }
                            )
                        } else {
                            EmptyPoliciesCard()
                        }

                        // Propose button (if player has ability)
                        if availableAbilities.contains(.propose) {
                            ProposeButton {
                                showingProposalSheet = true
                            }
                        }

                        // Recent decisions
                        if !resolvedPolicies.isEmpty {
                            PolicySection(
                                title: "RECENT DECISIONS",
                                policies: Array(resolvedPolicies.prefix(5)),
                                game: game,
                                isHistory: true,
                                onVote: { _, _ in }
                            )
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(15)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(isPresented: $showingProposalSheet) {
            PolicyProposalSheet(game: game) { template in
                proposePolicy(from: template)
            }
        }
    }

    private func castVote(on policy: Policy, vote: PolicyVote.VoteChoice) {
        switch vote {
        case .forPolicy:
            policy.votesFor += 1
        case .against:
            policy.votesAgainst += 1
        case .abstain:
            break
        }

        // Check if policy should resolve
        if policy.isPassable {
            policy.status = PolicyStatus.passed.rawValue
            policy.resolvedTurn = game.turnNumber
            applyPolicyEffects(policy)
        } else if policy.isRejectable {
            policy.status = PolicyStatus.rejected.rawValue
            policy.resolvedTurn = game.turnNumber
        }

        policy.updatedAt = Date()
    }

    private func proposePolicy(from template: PolicyTemplate) {
        let policy = Policy(
            templateId: template.id,
            title: template.title,
            description: template.description,
            category: PolicyCategory(rawValue: template.category) ?? .administrative,
            statEffects: template.statEffects,
            factionEffects: template.factionEffects,
            personalEffects: template.personalEffects,
            proposerId: "player",
            currentTurn: game.turnNumber
        )

        modelContext.insert(policy)
    }

    private func applyPolicyEffects(_ policy: Policy) {
        for (key, value) in policy.statEffects {
            game.applyStat(key, change: value)
        }

        // Apply personal effects for proposer
        if let effects = policy.personalEffects {
            for (key, value) in effects {
                game.applyStat(key, change: value)
            }
        }
    }
}

// MARK: - Policy Abilities Bar

struct PolicyAbilitiesBar: View {
    let abilities: [PolicyAbility]
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PolicyAbility.allCases, id: \.self) { ability in
                AbilityBadge(
                    ability: ability,
                    isUnlocked: abilities.contains(ability)
                )
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(theme.schemeCard)
    }
}

struct AbilityBadge: View {
    let ability: PolicyAbility
    let isUnlocked: Bool
    @Environment(\.theme) var theme

    var body: some View {
        Text(ability.displayName.uppercased())
            .font(theme.tagFont)
            .tracking(1)
            .foregroundColor(isUnlocked ? theme.accentGold : Color(hex: "555555"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isUnlocked ? theme.accentGold.opacity(0.15) : theme.schemeBorder.opacity(0.3))
            .overlay(
                Rectangle()
                    .stroke(isUnlocked ? theme.accentGold.opacity(0.5) : Color.clear, lineWidth: 1)
            )
    }
}

// MARK: - Policy Section

struct PolicySection: View {
    let title: String
    let policies: [Policy]
    let game: Game
    var isHistory: Bool = false
    let onVote: (Policy, PolicyVote.VoteChoice) -> Void
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionDivider(title: title)

            ForEach(policies) { policy in
                PolicyCard(
                    policy: policy,
                    game: game,
                    isHistory: isHistory,
                    onVote: { vote in
                        onVote(policy, vote)
                    }
                )
            }
        }
    }
}

// MARK: - Policy Card

struct PolicyCard: View {
    let policy: Policy
    let game: Game
    var isHistory: Bool = false
    let onVote: (PolicyVote.VoteChoice) -> Void
    @Environment(\.theme) var theme

    private var statusColor: Color {
        switch policy.currentStatus {
        case .passed, .decreed:
            return .statHigh
        case .rejected, .tabled:
            return .statLow
        default:
            return theme.accentGold
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: policy.currentCategory.icon)
                    .foregroundColor(theme.sovietRed)

                Text(policy.title)
                    .font(theme.labelFont)
                    .fontWeight(.bold)
                    .foregroundColor(theme.inkBlack)

                Spacer()

                Text(policy.currentStatus.displayName.uppercased())
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(statusColor)
            }

            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            // Description
            Text(policy.policyDescription)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
                .lineSpacing(4)

            // Effects preview
            if !policy.statEffects.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(policy.statEffects.keys.sorted().prefix(4)), id: \.self) { key in
                        if let value = policy.statEffects[key] {
                            PolicyEffectTag(key: key, value: value)
                        }
                    }
                }
            }

            // Voting progress (for active policies)
            if !isHistory && policy.currentStatus == .voting {
                VStack(spacing: 8) {
                    HStack {
                        Text("VOTES FOR: \(policy.votesFor)")
                            .font(theme.tagFont)
                            .foregroundColor(.statHigh)

                        Spacer()

                        Text("NEEDED: \(policy.votesNeeded)")
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkLight)

                        Spacer()

                        Text("AGAINST: \(policy.votesAgainst)")
                            .font(theme.tagFont)
                            .foregroundColor(.statLow)
                    }

                    // Vote buttons
                    if game.availablePolicyAbilities.contains(.vote) {
                        HStack(spacing: 10) {
                            VoteButton(label: "FOR", color: .statHigh) {
                                onVote(.forPolicy)
                            }

                            VoteButton(label: "ABSTAIN", color: theme.inkGray) {
                                onVote(.abstain)
                            }

                            VoteButton(label: "AGAINST", color: .statLow) {
                                onVote(.against)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(15)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Policy Effect Tag

struct PolicyEffectTag: View {
    let key: String
    let value: Int
    @Environment(\.theme) var theme

    private var displayName: String {
        let names: [String: String] = [
            "stability": "Stab",
            "popularSupport": "Pop",
            "militaryLoyalty": "Mil",
            "eliteLoyalty": "Elite",
            "treasury": "Treas",
            "industrialOutput": "Ind",
            "foodSupply": "Food",
            "internationalStanding": "Intl"
        ]
        return names[key] ?? key
    }

    private var isPositive: Bool { value > 0 }

    var body: some View {
        Text("\(value >= 0 ? "+" : "")\(value) \(displayName)")
            .font(theme.tagFont)
            .foregroundColor(isPositive ? .statHigh : .statLow)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isPositive ? Color.statHigh.opacity(0.15) : Color.statLow.opacity(0.15))
    }
}

// MARK: - Vote Button

struct VoteButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(theme.tagFont)
                .tracking(1)
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay(
                    Rectangle()
                        .stroke(color, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty Policies Card

struct EmptyPoliciesCard: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(theme.inkLight)

            Text("No policies before the Politburo")
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)

            Text("The apparatus awaits new directives")
                .font(theme.tagFont)
                .italic()
                .foregroundColor(theme.inkLight)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Propose Button

struct ProposeButton: View {
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))

                Text("PROPOSE NEW POLICY")
                    .font(theme.labelFont)
                    .tracking(2)
            }
            .foregroundColor(theme.parchment)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.sovietRed)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Policy Proposal Sheet

struct PolicyProposalSheet: View {
    let game: Game
    let onPropose: (PolicyTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme

    @State private var selectedTemplate: PolicyTemplate?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    Text("Select a policy to propose to the Politburo")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                        .padding(.top, 10)

                    ForEach(PolicyTemplate.sampleTemplates, id: \.id) { template in
                        ProposalTemplateCard(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id
                        ) {
                            selectedTemplate = template
                        }
                    }

                    if let template = selectedTemplate {
                        Button {
                            onPropose(template)
                            dismiss()
                        } label: {
                            Text("PROPOSE THIS POLICY")
                                .font(theme.labelFont)
                                .tracking(2)
                                .foregroundColor(theme.parchment)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(theme.sovietRed)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                    }

                    Spacer(minLength: 50)
                }
                .padding(15)
            }
            .background(theme.parchment)
            .navigationTitle("Propose Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(theme.sovietRed)
                }
            }
        }
    }
}

// MARK: - Proposal Template Card

struct ProposalTemplateCard: View {
    let template: PolicyTemplate
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(template.title)
                        .font(theme.labelFont)
                        .fontWeight(.bold)
                        .foregroundColor(theme.inkBlack)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.sovietRed)
                    }
                }

                Text(template.description)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkGray)
                    .lineSpacing(4)

                // Effects
                HStack(spacing: 8) {
                    ForEach(Array(template.statEffects.keys.sorted().prefix(3)), id: \.self) { key in
                        if let value = template.statEffects[key] {
                            PolicyEffectTag(key: key, value: value)
                        }
                    }
                }

                if template.isControversial {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("CONTROVERSIAL")
                            .font(theme.tagFont)
                            .tracking(1)
                    }
                    .foregroundColor(.statLow)
                }
            }
            .padding(15)
            .background(isSelected ? theme.sovietRed.opacity(0.1) : theme.parchmentDark)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? theme.sovietRed : theme.borderTan, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, Policy.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.currentPositionIndex = 3  // Department Head - can propose
    container.mainContext.insert(game)

    return PolicyView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
