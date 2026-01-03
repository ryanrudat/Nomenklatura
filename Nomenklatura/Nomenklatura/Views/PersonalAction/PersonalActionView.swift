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

    // NPC Visitor state
    @State private var visitors: [NPCVisitor] = []
    @State private var selectedVisitor: NPCVisitor?
    @State private var showingVisitorSheet = false
    @State private var handledVisitorIds: Set<UUID> = []
    @State private var lastVisitorResponse: (visitor: NPCVisitor, response: VisitorResponse)?
    @State private var showingVisitorResult = false

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

    /// Active visitors that haven't been handled yet
    private var activeVisitors: [NPCVisitor] {
        visitors.filter { !handledVisitorIds.contains($0.id) }
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

                        // Show visitor response result if any
                        if showingVisitorResult, let result = lastVisitorResponse {
                            VisitorResponseCard(
                                visitor: result.visitor,
                                response: result.response
                            ) {
                                withAnimation {
                                    showingVisitorResult = false
                                    lastVisitorResponse = nil
                                }
                            }
                            .padding(.horizontal, 15)
                            .padding(.bottom, 15)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

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

                        // NPC Visitors section - shows NPCs who want to interact
                        if !activeVisitors.isEmpty {
                            SectionDivider(title: "Visitors", isDark: true)
                                .padding(.horizontal, 15)

                            VStack(spacing: 8) {
                                ForEach(activeVisitors) { visitor in
                                    VisitorCardView(visitor: visitor) {
                                        selectedVisitor = visitor
                                        showingVisitorSheet = true
                                    }
                                }
                            }
                            .padding(.horizontal, 15)
                            .padding(.bottom, 10)
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
        .sheet(isPresented: $showingVisitorSheet) {
            if let visitor = selectedVisitor {
                VisitorDetailSheet(
                    visitor: visitor,
                    game: game,
                    onResponse: { response in
                        handleVisitorResponse(visitor: visitor, response: response)
                        showingVisitorSheet = false
                    },
                    onDismiss: {
                        showingVisitorSheet = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            remainingAP = game.actionPoints
            // Generate NPC visitors for this turn
            visitors = NPCVisitorService.shared.generateVisitors(for: game)
        }
    }

    private func handleVisitorResponse(visitor: NPCVisitor, response: VisitorResponse) {
        // Apply effects
        NPCVisitorService.shared.applyVisitorResponse(visitor: visitor, response: response, game: game)

        // Mark visitor as handled
        handledVisitorIds.insert(visitor.id)

        // Show result
        withAnimation(.easeOut(duration: 0.3)) {
            lastVisitorResponse = (visitor, response)
            showingVisitorResult = true
            selectedVisitor = nil
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

// MARK: - Visitor Card View

struct VisitorCardView: View {
    let visitor: NPCVisitor
    let onTap: () -> Void
    @Environment(\.theme) var theme

    private var visitorColor: Color {
        switch visitor.visitType {
        case .makingThreat: return .statLow
        case .warningOfDanger: return Color(hex: "FF9500")  // Warning orange
        case .seekingEndorsement, .askingFavor: return Color(hex: "5AC8FA")  // Request blue
        case .sharingIntel: return Color(hex: "AF52DE")  // Intel purple
        case .offeringAlliance, .expressingGratitude: return .statHigh
        case .probingIntentions: return Color(hex: "888888")
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(visitorColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: visitor.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(visitorColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(visitor.character.name)
                            .font(theme.headerFont)
                            .foregroundColor(theme.schemeText)

                        Spacer()

                        // Visit type badge
                        Text(visitor.visitType.displayName.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(visitorColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(visitorColor.opacity(0.15))
                    }

                    Text(visitor.title)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(Color(hex: "AAAAAA"))
                        .lineLimit(1)

                    if let title = visitor.character.title {
                        Text(title)
                            .font(theme.tagFont)
                            .foregroundColor(Color(hex: "777777"))
                            .lineLimit(1)
                    }
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "555555"))
            }
            .padding(12)
            .background(theme.schemeCard)
            .overlay(
                Rectangle()
                    .stroke(visitorColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visitor Response Card (shows after responding)

struct VisitorResponseCard: View {
    let visitor: NPCVisitor
    let response: VisitorResponse
    let onDismiss: () -> Void
    @Environment(\.theme) var theme

    private var isPositiveResponse: Bool {
        response.dispositionChange >= 0 && !response.isHostile
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: isPositiveResponse ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(isPositiveResponse ? .statHigh : .statLow)

                Text("\(visitor.character.name)")
                    .font(theme.labelFont)
                    .tracking(1)
                    .foregroundColor(theme.schemeText)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(theme.schemeText.opacity(0.5))
                }
            }

            Rectangle()
                .fill(theme.schemeBorder)
                .frame(height: 1)

            // Response chosen
            Text("You chose: \(response.shortText)")
                .font(theme.bodyFontSmall)
                .foregroundColor(Color(hex: "AAAAAA"))

            // Stat changes
            if !response.effects.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(response.effects.keys.sorted()), id: \.self) { key in
                        if let value = response.effects[key], value != 0 {
                            StatChangeTag(key: key, value: value)
                        }
                    }
                }
            }

            // Disposition change
            if response.dispositionChange != 0 {
                HStack(spacing: 6) {
                    Image(systemName: response.dispositionChange > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 10))
                    Text("\(visitor.character.name)'s disposition: \(response.dispositionChange > 0 ? "+" : "")\(response.dispositionChange)")
                        .font(theme.tagFont)
                }
                .foregroundColor(response.dispositionChange > 0 ? .statHigh : .statLow)
                .padding(.top, 4)
            }
        }
        .padding(15)
        .background(isPositiveResponse ? Color.statHigh.opacity(0.1) : Color.statLow.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(isPositiveResponse ? Color.statHigh.opacity(0.3) : Color.statLow.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Visitor Detail Sheet

struct VisitorDetailSheet: View {
    let visitor: NPCVisitor
    let game: Game
    let onResponse: (VisitorResponse) -> Void
    let onDismiss: () -> Void
    @Environment(\.theme) var theme

    private var visitorColor: Color {
        switch visitor.visitType {
        case .makingThreat: return .statLow
        case .warningOfDanger: return Color(hex: "FF9500")
        case .seekingEndorsement, .askingFavor: return Color(hex: "5AC8FA")
        case .sharingIntel: return Color(hex: "AF52DE")
        case .offeringAlliance, .expressingGratitude: return .statHigh
        case .probingIntentions: return Color(hex: "888888")
        }
    }

    var body: some View {
        ZStack {
            theme.schemeDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        // Character info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(visitor.visitType.displayName.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(visitorColor)

                            Text(visitor.character.name)
                                .font(theme.titleFont)
                                .foregroundColor(theme.schemeText)

                            if let title = visitor.character.title {
                                Text(title)
                                    .font(theme.bodyFontSmall)
                                    .foregroundColor(Color(hex: "888888"))
                            }
                        }

                        Spacer()

                        // Icon
                        ZStack {
                            Circle()
                                .fill(visitorColor.opacity(0.2))
                                .frame(width: 60, height: 60)

                            Image(systemName: visitor.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(visitorColor)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Divider
                    Rectangle()
                        .fill(theme.schemeBorder)
                        .frame(height: 1)
                        .padding(.horizontal, 20)

                    // Message
                    Text(visitor.message)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.schemeText)
                        .lineSpacing(6)
                        .padding(.horizontal, 20)

                    // Relationship indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(dispositionColor)
                            .frame(width: 8, height: 8)

                        Text("Disposition: \(dispositionDescription)")
                            .font(theme.tagFont)
                            .foregroundColor(Color(hex: "888888"))
                    }
                    .padding(.horizontal, 20)

                    // Divider
                    Rectangle()
                        .fill(theme.schemeBorder)
                        .frame(height: 1)
                        .padding(.horizontal, 20)

                    // Response options
                    VStack(spacing: 12) {
                        ForEach(visitor.responseOptions) { response in
                            ResponseOptionButton(response: response) {
                                onResponse(response)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var dispositionDescription: String {
        let disp = visitor.character.disposition
        if disp >= 70 { return "Friendly" }
        if disp >= 40 { return "Cordial" }
        if disp >= 10 { return "Neutral" }
        if disp >= -20 { return "Cool" }
        return "Hostile"
    }

    private var dispositionColor: Color {
        let disp = visitor.character.disposition
        if disp >= 50 { return .statHigh }
        if disp >= 0 { return .statMedium }
        return .statLow
    }
}

// MARK: - Response Option Button

struct ResponseOptionButton: View {
    let response: VisitorResponse
    let onTap: () -> Void
    @Environment(\.theme) var theme

    private var buttonColor: Color {
        if response.isHostile {
            return .statLow
        } else if response.dispositionChange > 5 {
            return .statHigh
        } else if response.dispositionChange < -5 {
            return Color(hex: "FF9500")
        }
        return Color(hex: "5AC8FA")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(response.shortText.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(buttonColor)

                    Spacer()

                    // Effect preview
                    if !response.effects.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(response.effects.keys.prefix(2).sorted()), id: \.self) { key in
                                if let value = response.effects[key], value != 0 {
                                    Text("\(value > 0 ? "+" : "")\(value)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(value > 0 ? .statHigh : .statLow)
                                }
                            }
                        }
                    }
                }

                Text(response.text)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.schemeText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.schemeCard)
            .overlay(
                Rectangle()
                    .stroke(buttonColor.opacity(0.3), lineWidth: 1)
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
