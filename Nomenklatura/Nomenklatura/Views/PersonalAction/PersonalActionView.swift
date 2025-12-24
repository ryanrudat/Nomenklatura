//
//  PersonalActionView.swift
//  Nomenklatura
//
//  Personal Action Phase - Dark mode screen for political maneuvering
//

import SwiftUI
import SwiftData

struct PersonalActionView: View {
    @Bindable var game: Game
    let actions: [PersonalAction]
    let ladder: [LadderPosition]
    let onComplete: () -> Void
    @Environment(\.theme) var theme

    @State private var remainingAP: Int = 2
    @State private var lastActionResult: ActionResult?
    @State private var showingResult = false
    @State private var showNextTurnButton = false

    private var groupedActions: [PersonalActionCategory: [PersonalAction]] {
        Dictionary(grouping: actions) { $0.category }
    }

    private var sortedCategories: [PersonalActionCategory] {
        PersonalActionCategory.allCases.sorted { $0.order < $1.order }
    }

    /// Atmospheric text based on game state
    private var atmosphereText: String {
        NarrativeGenerator.shared.generateAtmosphere(for: .personalAction, game: game)
    }

    /// Personal situation mood
    private var personalMood: String? {
        NarrativeGenerator.shared.getPersonalMoodDescription(game: game)
    }

    var body: some View {
        ZStack {
            // Dark background
            theme.schemeDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ScreenHeader(
                    title: "Your Move",
                    subtitle: "Personal Action Phase"
                )

                // AP indicator
                ActionPointsIndicator(points: remainingAP)

                // Scrollable content
                ScrollView {
                    VStack(spacing: 0) {
                        // Atmosphere card - sets the mood
                        AtmosphereCard(
                            atmosphere: atmosphereText,
                            personalMood: personalMood
                        )
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)

                        // Show last action result if any
                        if showingResult, let result = lastActionResult {
                            ActionResultCard(result: result) {
                                withAnimation {
                                    showingResult = false
                                    lastActionResult = nil
                                }
                            }
                            .padding(.horizontal, 15)
                            .padding(.bottom, 15)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        ForEach(sortedCategories, id: \.self) { category in
                            if let categoryActions = groupedActions[category], !categoryActions.isEmpty {
                                // Section header
                                SectionDivider(title: category.displayName, isDark: true)
                                    .padding(.horizontal, 15)

                                // Actions in this category
                                VStack(spacing: 8) {
                                    ForEach(categoryActions, id: \.id) { action in
                                        let availability = action.isAvailable(game: game)
                                        let canAfford = remainingAP >= action.costAP
                                        let alreadyUsed = game.usedActionsThisTurn.contains(action.id)

                                        ActionCardView(
                                            action: action,
                                            isAvailable: availability.available && canAfford && !alreadyUsed,
                                            lockReason: alreadyUsed ? "Already performed this turn" : (!availability.available ? availability.reason : (!canAfford ? "Not enough AP" : nil)),
                                            game: game
                                        ) {
                                            performAction(action)
                                        }
                                    }
                                }
                                .padding(.horizontal, 15)
                            }
                        }

                        // Next Turn button (when out of AP) or Pass button
                        if showNextTurnButton || remainingAP <= 0 {
                            NextTurnButton {
                                onComplete()
                            }
                            .padding(15)
                        } else {
                            PassTurnButton {
                                onComplete()
                            }
                            .padding(15)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 100)
                }
            }
        }
        .onAppear {
            remainingAP = game.actionPoints
        }
    }

    private func performAction(_ action: PersonalAction) {
        guard remainingAP >= action.costAP else { return }

        // Use GameEngine to execute action
        let result = GameEngine.shared.executeAction(action, game: game, ladder: ladder)

        // Update local state
        remainingAP = game.actionPoints

        // Show result
        withAnimation(.easeOut(duration: 0.3)) {
            lastActionResult = result
            showingResult = true
        }

        // If no AP left, show the Next Turn button (no auto-advance)
        if remainingAP <= 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                showNextTurnButton = true
            }
        }
    }
}

// MARK: - Action Result Card

struct ActionResultCard: View {
    let result: ActionResult
    let onDismiss: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.success ? .statHigh : .statLow)

                Text(result.success ? "SUCCESS" : "DISCOVERED")
                    .font(theme.labelFont)
                    .tracking(2)
                    .foregroundColor(result.success ? .statHigh : .statLow)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(theme.schemeText.opacity(0.5))
                }
            }

            Rectangle()
                .fill(theme.schemeBorder)
                .frame(height: 1)

            // Outcome text
            Text(result.outcomeText)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.schemeText)
                .lineSpacing(4)

            // Stat changes
            if !result.statChanges.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(result.statChanges.keys.sorted()), id: \.self) { key in
                        if let value = result.statChanges[key], value != 0 {
                            StatChangeTag(key: key, value: value)
                        }
                    }
                }
            }

            // Discovery warning
            if result.wasDiscovered, let discoverer = result.discoveredBy {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 10))
                    Text("Discovered by \(discoverer)")
                        .font(theme.tagFont)
                }
                .foregroundColor(.statLow)
                .padding(.top, 4)
            }
        }
        .padding(15)
        .background(result.success ? Color.statHigh.opacity(0.1) : Color.statLow.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(result.success ? Color.statHigh.opacity(0.3) : Color.statLow.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Stat Change Tag

struct StatChangeTag: View {
    let key: String
    let value: Int
    @Environment(\.theme) var theme

    private var displayName: String {
        let names: [String: String] = [
            "standing": "Standing",
            "patronFavor": "Favor",
            "rivalThreat": "Rival",
            "network": "Network",
            "reputationCompetent": "Competent",
            "reputationLoyal": "Loyal",
            "reputationCunning": "Cunning",
            "reputationRuthless": "Ruthless",
            "stability": "Stability",
            "popularSupport": "Popular"
        ]
        return names[key] ?? key
    }

    private var isPositive: Bool {
        // For rivalThreat, negative is good
        if key == "rivalThreat" {
            return value < 0
        }
        return value > 0
    }

    var body: some View {
        Text("\(value >= 0 ? "+" : "")\(value) \(displayName)")
            .font(theme.tagFont)
            .foregroundColor(isPositive ? .statHigh : .statLow)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isPositive ? Color.statHigh.opacity(0.15) : Color.statLow.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Action Points Indicator

struct ActionPointsIndicator: View {
    let points: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
            Text("YOU HAVE \(points) ACTION POINT\(points == 1 ? "" : "S")")
                .font(theme.labelFont)
                .tracking(1)
            Image(systemName: "star.fill")
                .font(.system(size: 12))
        }
        .foregroundColor(theme.accentGold)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(theme.schemeCard)
    }
}

// MARK: - Atmosphere Card

struct AtmosphereCard: View {
    let atmosphere: String
    let personalMood: String?
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Main atmosphere text - larger, more immersive
            Text(atmosphere)
                .font(theme.narrativeFont)
                .italic()
                .foregroundColor(Color(hex: "999999"))
                .lineSpacing(6)

            // Personal mood indicator if present
            if let mood = personalMood {
                Rectangle()
                    .fill(theme.schemeBorder.opacity(0.5))
                    .frame(height: 1)

                HStack(spacing: 8) {
                    Circle()
                        .fill(moodColor(for: mood))
                        .frame(width: 6, height: 6)

                    Text(mood)
                        .font(theme.labelFont)
                        .foregroundColor(Color(hex: "AAAAAA"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(theme.schemeCard.opacity(0.5))
        .overlay(
            Rectangle()
                .stroke(theme.schemeBorder.opacity(0.3), lineWidth: 1)
        )
    }

    private func moodColor(for mood: String) -> Color {
        if mood.contains("enemies") || mood.contains("rivals") || mood.contains("blood") || mood.contains("danger") {
            return .statLow
        } else if mood.contains("strong") || mood.contains("favor") || mood.contains("web") {
            return .statHigh
        } else if mood.contains("fading") || mood.contains("cooled") || mood.contains("withdrawal") {
            return .statMedium
        }
        return Color(hex: "888888")
    }
}

// MARK: - Next Turn Button (shown when AP exhausted)

struct NextTurnButton: View {
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("Your political capital is spent")
                    .font(theme.bodyFontSmall)
                    .foregroundColor(Color(hex: "888888"))

                HStack(spacing: 8) {
                    Text("PROCEED TO NEXT TURN")
                        .font(theme.labelFont)
                        .fontWeight(.bold)
                        .tracking(2)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(theme.schemeDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.accentGold)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pass Turn Button

struct PassTurnButton: View {
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text("Or skip and save your political capital")
                    .font(theme.labelFont)
                    .foregroundColor(Color(hex: "666666"))

                Text("PASS THIS TURN")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(Color(hex: "888888"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .overlay(
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundColor(theme.schemeBorder)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    container.mainContext.insert(game)

    let campaign = CampaignLoader.shared.getColdWarCampaign()

    return PersonalActionView(
        game: game,
        actions: campaign.personalActions,
        ladder: campaign.ladder
    ) {
        print("Completed")
    }
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
