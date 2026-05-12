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

    @State private var remainingAP: Int = BalanceConfig.actionPointsPerTurn
    @State private var lastActionResult: ActionResult?
    @State private var showingResult = false
    @State private var showNextTurnButton = false

    // Appoint-successor target picker
    @State private var pendingAppointAction: PersonalAction? = nil
    @State private var showingAppointSheet: Bool = false

    private var groupedActions: [PersonalActionCategory: [PersonalAction]] {
        Dictionary(grouping: actions) { $0.category }
    }

    private var activeCrises: [Crisis] {
        UrgencyAdvisor.detectCrises(game: game)
    }

    private var sortedCategories: [PersonalActionCategory] {
        let base = PersonalActionCategory.allCases.sorted { $0.order < $1.order }
        let crises = activeCrises
        if crises.isEmpty { return base }
        return UrgencyAdvisor.sortedCategories(base, crises: crises)
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
                    subtitle: "Personal Action Phase",
                    phase: .personalAction
                )

                // AP indicator
                ActionPointsIndicator(points: remainingAP)

                // Scrollable content
                ScrollView {
                    VStack(spacing: 0) {
                        // Crisis alert banner if crises active
                        if !activeCrises.isEmpty {
                            CrisisAlertBanner(crises: activeCrises)
                                .padding(.horizontal, 15)
                                .padding(.top, 10)
                        }

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
                                            game: game,
                                            urgentCrisis: UrgencyAdvisor.isUrgent(action: action, crises: activeCrises)
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
        .sheet(isPresented: $showingAppointSheet) {
            AppointSuccessorSheet(
                game: game,
                ladder: ladder,
                onSelect: { candidate, vacancySlot in
                    showingAppointSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        applyAppointSuccessor(candidate: candidate, vacancySlot: vacancySlot)
                    }
                },
                onCancel: {
                    showingAppointSheet = false
                    pendingAppointAction = nil
                }
            )
        }
    }

    private func performAction(_ action: PersonalAction) {
        guard remainingAP >= action.costAP else { return }

        // Special-case: appoint_successor needs a target selection sheet
        // BEFORE we commit to AP / effects. Intercept here.
        if action.id == "appoint_successor" {
            pendingAppointAction = action
            showingAppointSheet = true
            return
        }

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

    /// Apply the result of a confirmed appointment selection.
    private func applyAppointSuccessor(candidate: GameCharacter, vacancySlot: Int) {
        guard let action = pendingAppointAction else { return }
        let result = GameEngine.shared.executeAppointSuccessor(
            action: action,
            candidate: candidate,
            vacancySlot: vacancySlot,
            game: game,
            ladder: ladder
        )
        remainingAP = game.actionPoints
        withAnimation(.easeOut(duration: 0.3)) {
            lastActionResult = result
            showingResult = true
        }
        if remainingAP <= 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                showNextTurnButton = true
            }
        }
        pendingAppointAction = nil
    }
}

// MARK: - Crisis Alert Banner

struct CrisisAlertBanner: View {
    let crises: [Crisis]
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.statLow)

                Text("ACTIVE CRISES")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.statLow)

                Spacer()

                Text("PRIORITIZE ACTIONS BELOW")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.schemeText.opacity(0.5))
            }

            HStack(spacing: 6) {
                ForEach(crises) { crisis in
                    Text(crisis.label)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.statLow.opacity(0.8))
                        .cornerRadius(2)
                }
            }
        }
        .padding(10)
        .background(Color.statLow.opacity(0.08))
        .overlay(
            Rectangle()
                .stroke(Color.statLow.opacity(0.3), lineWidth: 1)
        )
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
        StatDisplayNames.map[key] ?? key
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

// MARK: - Appoint Successor Sheet

/// Target-selection sheet for the `appoint_successor` action. Lists vacant
/// slots and, per slot, the top-5 viable candidates (active characters with
/// `positionIndex` either nil or up to 2 below the vacant slot). Candidates
/// are scored by faction alignment + disposition + competence + loyalty.
struct AppointSuccessorSheet: View {
    let game: Game
    let ladder: [LadderPosition]
    let onSelect: (GameCharacter, Int) -> Void
    let onCancel: () -> Void
    @Environment(\.theme) var theme

    @State private var selectedSlot: Int?

    /// All currently vacant slots (1-8) that the player can fill.
    private var vacantSlots: [Int] {
        PersonalActionGenerator.detectVacantSlots(game: game, ladder: ladder)
    }

    /// Default the selected slot to the first vacancy on appear.
    private var resolvedSelectedSlot: Int? {
        selectedSlot ?? vacantSlots.first
    }

    /// Compute candidates for a given vacancy. A candidate is any active
    /// character whose `positionIndex` is nil (unranked) or within 2 of the
    /// vacant slot (promotion only, never demotion). Returns up to 5,
    /// sorted by faction alignment + disposition + competence + loyalty.
    private func candidates(for slot: Int) -> [GameCharacter] {
        let playerFaction = game.playerFactionId

        let pool: [GameCharacter] = game.characters.filter { c in
            guard c.isActive else { return false }
            // Promotion-only: nil position (unranked) OR 1-2 below the vacancy
            if let pi = c.positionIndex {
                return pi < slot && pi >= slot - 2
            }
            return true
        }

        let scored: [(GameCharacter, Int)] = pool.map { c in
            var score = 0
            if let pf = playerFaction, c.factionId == pf {
                score += 30
            }
            // disposition above 50 boosts (5 per 10 above 50)
            if c.disposition > 50 {
                score += ((c.disposition - 50) / 10) * 5
            } else {
                // mild penalty for hostile candidates
                score += (c.disposition - 50) / 10
            }
            score += c.personalityCompetent
            score += c.personalityLoyal
            return (c, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0.0 }
    }

    private func title(for slot: Int) -> String {
        ladder.first(where: { $0.index == slot })?.title ?? "Position \(slot)"
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.schemeDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 4) {
                        Text("APPOINT SUCCESSOR")
                            .font(theme.labelFont)
                            .tracking(2)
                            .foregroundColor(theme.accentGold)
                        Text("Select a candidate to fill a vacant seat.")
                            .font(theme.tagFont)
                            .foregroundColor(theme.schemeText.opacity(0.7))
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(theme.schemeCard)

                    if vacantSlots.isEmpty {
                        // Defensive empty state (shouldn't usually appear since
                        // the action is gated on having vacancies, but state
                        // could shift mid-turn).
                        VStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 36))
                                .foregroundColor(theme.schemeText.opacity(0.4))
                            Text("No vacant seats")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.schemeText)
                            Text("The hierarchy is currently full.")
                                .font(theme.tagFont)
                                .foregroundColor(theme.schemeText.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Vacancy picker (if more than one) + candidate list
                        ScrollView {
                            VStack(spacing: 12) {
                                if vacantSlots.count > 1 {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("VACANT SEATS")
                                            .font(theme.tagFont)
                                            .tracking(1)
                                            .foregroundColor(theme.schemeText.opacity(0.6))
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(vacantSlots, id: \.self) { slot in
                                                    Button {
                                                        selectedSlot = slot
                                                    } label: {
                                                        Text(title(for: slot))
                                                            .font(theme.tagFont)
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 6)
                                                            .background(
                                                                (resolvedSelectedSlot == slot)
                                                                    ? theme.accentGold.opacity(0.25)
                                                                    : theme.schemeCard
                                                            )
                                                            .foregroundColor(
                                                                (resolvedSelectedSlot == slot)
                                                                    ? theme.accentGold
                                                                    : theme.schemeText
                                                            )
                                                            .overlay(
                                                                Rectangle().stroke(
                                                                    (resolvedSelectedSlot == slot)
                                                                        ? theme.accentGold
                                                                        : theme.schemeBorder,
                                                                    lineWidth: 1
                                                                )
                                                            )
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                        }
                                    }
                                    .padding(.top, 10)
                                }

                                if let slot = resolvedSelectedSlot {
                                    candidateList(for: slot)
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle(resolvedSelectedSlot.map { "Fill: \(title(for: $0))" } ?? "Appoint Successor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(theme.schemeText)
                }
            }
        }
    }

    @ViewBuilder
    private func candidateList(for slot: Int) -> some View {
        let cands = candidates(for: slot)
        VStack(alignment: .leading, spacing: 8) {
            Text("CANDIDATES")
                .font(theme.tagFont)
                .tracking(1)
                .foregroundColor(theme.schemeText.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if cands.isEmpty {
                Text("No eligible candidates. Cultivate junior officials first.")
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.schemeText.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(cands, id: \.id) { c in
                    AppointSuccessorCandidateRow(
                        candidate: c,
                        sameFactionAsPlayer: (game.playerFactionId != nil
                            && c.factionId == game.playerFactionId),
                        onSelect: { onSelect(c, slot) }
                    )
                    .padding(.horizontal, 12)
                }
            }
        }
    }
}

private struct AppointSuccessorCandidateRow: View {
    let candidate: GameCharacter
    let sameFactionAsPlayer: Bool
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    private var dispositionColor: Color {
        if candidate.disposition >= 60 { return .statHigh }
        if candidate.disposition <= 30 { return .statLow }
        return .statMedium
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(candidate.name)
                        .font(theme.bodyFontSmall)
                        .fontWeight(.medium)
                        .foregroundColor(theme.schemeText)
                    if sameFactionAsPlayer {
                        Text("ALIGNED")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(theme.accentGold.opacity(0.2))
                            .foregroundColor(theme.accentGold)
                    }
                    Spacer()
                    Text("DISP \(candidate.disposition)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(dispositionColor)
                }

                if let factionId = candidate.factionId {
                    Text("Faction: \(factionId)")
                        .font(theme.tagFont)
                        .foregroundColor(theme.schemeText.opacity(0.6))
                }

                HStack(spacing: 10) {
                    Text("CMP \(candidate.personalityCompetent)")
                    Text("LOY \(candidate.personalityLoyal)")
                    Text("AMB \(candidate.personalityAmbitious)")
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(theme.schemeText.opacity(0.7))

                if let pi = candidate.positionIndex {
                    Text("Currently: Position \(pi)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(theme.schemeText.opacity(0.5))
                } else {
                    Text("Unranked candidate")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(theme.schemeText.opacity(0.5))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.schemeCard)
            .overlay(
                Rectangle().stroke(theme.schemeBorder, lineWidth: 1)
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
