//
//  OutcomeView.swift
//  Nomenklatura
//
//  Outcome Phase - Shows results of player's decision
//

import SwiftUI
import SwiftData

struct OutcomeView: View {
    @Bindable var game: Game
    let outcomeText: String
    let statChanges: [StatChange]
    var optionArchetype: OptionArchetype? = nil  // Optional: for character reactions
    let onContinue: () -> Void
    @Environment(\.theme) var theme

    @State private var showOutcome = false
    @State private var showReactions = false
    @State private var showStats = false
    @State private var showButton = false

    /// State mood based on current conditions
    private var stateMood: String? {
        NarrativeGenerator.shared.getStateMoodDescription(game: game)
    }

    var body: some View {
        ZStack {
            // Background - parchment
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ScreenHeader(
                    title: "Outcome",
                    subtitle: "Turn \(game.turnNumber)"
                )

                ScrollView {
                    VStack(spacing: 20) {
                        // Outcome narrative
                        if showOutcome {
                            OutcomeNarrativeCard(text: outcomeText, game: game)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Multi-character reactions section
                        if showReactions {
                            ReactionsSection(
                                game: game,
                                statChanges: statChanges,
                                optionArchetype: optionArchetype
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        // Stat changes with narrative mood
                        if showStats && !statChanges.isEmpty {
                            StatChangesCard(changes: statChanges, stateMood: stateMood)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        // Continue button
                        if showButton {
                            ContinueButton {
                                onContinue()
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.top, 10)
                        }
                    }
                    .padding(15)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 40)
                }
            }
        }
        .onAppear {
            animateIn()
        }
        .modifier(CharacterSheetOverlayModifier(game: game))
    }

    private func animateIn() {
        // Stagger the animations
        withAnimation(.easeOut(duration: 0.5)) {
            showOutcome = true
        }

        // Show reactions section after outcome (if archetype provided)
        if optionArchetype != nil {
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showReactions = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.1)) {
                showStats = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(1.6)) {
                showButton = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showStats = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(1.2)) {
                showButton = true
            }
        }
    }
}

// MARK: - Outcome Narrative Card

struct OutcomeNarrativeCard: View {
    let text: String
    let game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack {
                Text("CONSEQUENCES")
                    .font(theme.labelFont)
                    .tracking(2)
                    .foregroundColor(theme.stampRed)

                Spacer()
            }

            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            // Narrative text with clickable character names
            ClickableNarrativeText(
                text: text,
                game: game,
                font: theme.narrativeFontLarge,
                color: theme.inkBlack,
                lineSpacing: 8
            )
        }
        .padding(20)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 2, y: 2)
    }
}

// MARK: - Character Reaction Card

struct CharacterReactionCard: View {
    let characterName: String
    let characterTitle: String?
    let reaction: String
    let disposition: Int
    let game: Game
    @Environment(\.theme) var theme

    /// Color based on character's disposition toward player
    private var dispositionColor: Color {
        if disposition >= 60 {
            return .statHigh.opacity(0.8)
        } else if disposition <= 40 {
            return .statLow.opacity(0.8)
        } else {
            return theme.inkGray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Character attribution
            HStack(spacing: 8) {
                // Disposition indicator dot
                Circle()
                    .fill(dispositionColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    TappableName(name: characterName, game: game)
                        .font(theme.labelFont)
                        .tracking(1)

                    if let title = characterTitle {
                        Text(title)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkLight)
                    }
                }

                Spacer()
            }

            Rectangle()
                .fill(theme.borderTan.opacity(0.5))
                .frame(height: 1)

            // Reaction text with clickable character names
            ClickableNarrativeText(
                text: reaction,
                game: game,
                font: theme.narrativeFont,
                color: theme.inkGray,
                lineSpacing: 6
            )
        }
        .padding(16)
        .background(theme.parchment.opacity(0.7))
        .overlay(
            Rectangle()
                .stroke(theme.borderTan.opacity(0.7), lineWidth: 1)
        )
    }
}

// MARK: - Stat Changes Card

struct StatChangesCard: View {
    let changes: [StatChange]
    var stateMood: String? = nil
    @Environment(\.theme) var theme

    private var nationalChanges: [StatChange] {
        changes.filter { !$0.isPersonal }
    }

    private var personalChanges: [StatChange] {
        changes.filter { $0.isPersonal }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack {
                Text("EFFECTS")
                    .font(theme.labelFont)
                    .tracking(2)
                    .foregroundColor(theme.inkGray)

                Spacer()
            }

            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            // State mood narrative (if critical)
            if let mood = stateMood {
                Text(mood)
                    .font(theme.tagFont)
                    .italic()
                    .foregroundColor(moodColor(mood))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(moodColor(mood).opacity(0.1))
                    .overlay(
                        Rectangle()
                            .stroke(moodColor(mood).opacity(0.3), lineWidth: 1)
                    )
            }

            // National stats
            if !nationalChanges.isEmpty {
                Text("STATE")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(theme.inkLight)
                    .padding(.top, 5)

                ForEach(nationalChanges) { change in
                    StatChangeRow(change: change)
                }
            }

            // Personal stats
            if !personalChanges.isEmpty {
                Text("PERSONAL")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(theme.inkLight)
                    .padding(.top, 10)

                ForEach(personalChanges) { change in
                    StatChangeRow(change: change)
                }
            }
        }
        .padding(20)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func moodColor(_ mood: String) -> Color {
        if mood.contains("teeters") || mood.contains("patience") || mood.contains("Hunger") ||
           mood.contains("restless") || mood.contains("coffers") {
            return .statLow
        } else if mood.contains("smoothly") || mood.contains("content") || mood.contains("influence") {
            return .statHigh
        }
        return theme.inkGray
    }
}

// MARK: - Stat Change Row

struct StatChangeRow: View {
    let change: StatChange
    @Environment(\.theme) var theme

    @State private var animatedValue: Int = 0
    @State private var showChange = false

    var body: some View {
        HStack {
            Text(change.statName)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkBlack)

            Spacer()

            // Before value
            Text("\(change.oldValue)")
                .font(theme.statFont)
                .foregroundColor(theme.inkLight)

            // Arrow
            Image(systemName: change.delta >= 0 ? "arrow.right" : "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(theme.inkLight)

            // After value with color
            Text("\(change.newValue)")
                .font(theme.statFont)
                .foregroundColor(changeColor)

            // Delta badge
            if showChange {
                Text(change.deltaString)
                    .font(theme.tagFont)
                    .fontWeight(.bold)
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(changeColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                showChange = true
            }
        }
    }

    private var changeColor: Color {
        if change.isPersonal {
            return Color(hex: "C9A227") // Gold for personal
        } else if change.delta >= 0 {
            return .statHigh // Green for positive
        } else {
            return .statLow // Red for negative
        }
    }
}

// MARK: - Continue Button

struct ContinueButton: View {
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            HStack {
                Text("CONTINUE TO PERSONAL ACTION")
                    .font(theme.labelFont)
                    .tracking(1)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(theme.schemeText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.schemeCard)
            .overlay(
                Rectangle()
                    .stroke(theme.accentGold, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Change Model

struct StatChange: Identifiable {
    let id = UUID()
    let statKey: String
    let statName: String
    let oldValue: Int
    let newValue: Int
    let isPersonal: Bool

    var delta: Int {
        newValue - oldValue
    }

    var deltaString: String {
        delta >= 0 ? "+\(delta)" : "\(delta)"
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    container.mainContext.insert(game)

    let changes = [
        StatChange(statKey: "stability", statName: "Stability", oldValue: 50, newValue: 65, isPersonal: false),
        StatChange(statKey: "popularSupport", statName: "Popular Support", oldValue: 50, newValue: 30, isPersonal: false),
        StatChange(statKey: "patronFavor", statName: "Patron Favor", oldValue: 50, newValue: 55, isPersonal: true),
        StatChange(statKey: "standing", statName: "Standing", oldValue: 20, newValue: 28, isPersonal: true)
    ]

    return OutcomeView(
        game: game,
        outcomeText: "The military moves in swiftly. Order is restored within hours, but the images of soldiers dragging workers from the factory gates spread through whispered conversations. Minister Wallace nods approvingly at your decisiveness. \"You understand what must be done, Comrade.\"",
        statChanges: changes
    ) {
        print("Continue tapped")
    }
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
