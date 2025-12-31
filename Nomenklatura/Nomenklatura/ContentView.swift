//
//  ContentView.swift
//  Nomenklatura
//
//  Main content view with navigation
//

import SwiftUI
import SwiftData

// MARK: - Game Setup State

enum GameSetupState {
    case campaignSelect
    case factionSelect(campaignId: String)
    case preparing(campaignId: String, factionId: String)  // Pre-generation phase
    case playing
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var games: [Game]
    @StateObject private var themeManager = ThemeManager.shared

    @State private var setupState: GameSetupState = .campaignSelect
    @State private var selectedTab: NavTab = .desk

    private var activeGame: Game? {
        games.first { $0.currentStatus == .active }
    }

    var body: some View {
        Group {
            switch setupState {
            case .campaignSelect:
                CampaignSelectView { campaignId in
                    // Set theme for campaign
                    themeManager.setTheme(for: campaignId)
                    // Move to faction selection
                    withAnimation {
                        setupState = .factionSelect(campaignId: campaignId)
                    }
                }

            case .factionSelect(let campaignId):
                let config = CampaignLoader.shared.getColdWarCampaign()
                let factions = config.playerFactions ?? PlayerFactionConfig.allFactions
                FactionSelectView(
                    factions: factions,
                    onFactionSelected: { factionId in
                        // Move to preparing state instead of directly starting game
                        withAnimation {
                            setupState = .preparing(campaignId: campaignId, factionId: factionId)
                        }
                    },
                    onBack: {
                        withAnimation {
                            setupState = .campaignSelect
                        }
                    }
                )

            case .preparing(let campaignId, let factionId):
                GamePreparationView(
                    campaignId: campaignId,
                    factionId: factionId,
                    onGameReady: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            setupState = .playing
                        }
                    },
                    onCreateGame: { campaignId, factionId in
                        startNewGame(campaignId: campaignId, factionId: factionId)
                    }
                )

            case .playing:
                if let game = activeGame {
                    GameView(
                        game: game,
                        selectedTab: $selectedTab,
                        onReturnToMenu: {
                            setupState = .campaignSelect
                        },
                        onRestartWithSameFaction: {
                            // Capture current game's campaign and faction before restarting
                            let campaignId = game.campaignId
                            let factionId = game.playerFactionId ?? "youth_league"
                            startNewGame(campaignId: campaignId, factionId: factionId)
                        },
                        onDeleteAllData: {
                            deleteAllGameData()
                            setupState = .campaignSelect
                        }
                    )
                } else {
                    // Fallback if no active game (shouldn't happen)
                    CampaignSelectView { campaignId in
                        themeManager.setTheme(for: campaignId)
                        withAnimation {
                            setupState = .factionSelect(campaignId: campaignId)
                        }
                    }
                }
            }
        }
        .environment(\.theme, themeManager.currentTheme)
        .onAppear {
            // TEMPORARY: Force delete all existing games to test faction selection flow
            // Remove this block after confirming faction selection works
            if !games.isEmpty {
                for oldGame in games {
                    modelContext.delete(oldGame)
                }
                try? modelContext.save()
                setupState = .campaignSelect
                return
            }

            // Check if there's an active game with proper faction
            if let game = activeGame {
                // Repair any save state inconsistencies from older versions
                let config = CampaignLoader.shared.getColdWarCampaign()
                game.repairExpandedTrackIfNeeded(ladder: config.ladder)

                // Set theme for the campaign
                themeManager.setTheme(for: game.campaignId)

                setupState = .playing
            }
        }
    }

    /// Delete all existing games and related data for a fresh start
    private func deleteAllGameData() {
        // Delete all games (cascades to characters, factions, events via SwiftData relationships)
        for game in games {
            modelContext.delete(game)
        }

        // Clear scenario manager cache
        ScenarioManager.shared.loadingState.clearCache()

        // Clear AI scenario cache
        Task {
            await AIScenarioGenerator.shared.clearCache()
        }

        // Save changes
        try? modelContext.save()

        #if DEBUG
        print("[ContentView] All game data deleted for fresh start")
        #endif
    }

    private func startNewGame(campaignId: String, factionId: String) {
        // Clear all existing data before creating new game
        deleteAllGameData()

        // Create new game
        let newGame = Game(campaignId: campaignId)
        newGame.playerFactionId = factionId

        // Load campaign config and initialize game state
        let config = CampaignLoader.shared.getColdWarCampaign()

        // Set starting stats (base values)
        newGame.stability = config.startingStats.stability
        newGame.popularSupport = config.startingStats.popularSupport
        newGame.militaryLoyalty = config.startingStats.militaryLoyalty
        newGame.eliteLoyalty = config.startingStats.eliteLoyalty
        newGame.treasury = config.startingStats.treasury
        newGame.industrialOutput = config.startingStats.industrialOutput
        newGame.foodSupply = config.startingStats.foodSupply
        newGame.internationalStanding = config.startingStats.internationalStanding

        newGame.standing = config.startingPersonalStats.standing
        newGame.patronFavor = config.startingPersonalStats.patronFavor
        newGame.rivalThreat = config.startingPersonalStats.rivalThreat
        newGame.network = config.startingPersonalStats.network

        newGame.currentPositionIndex = config.startingPosition

        // Apply player faction bonuses/penalties
        if let playerFaction = PlayerFactionConfig.faction(withId: factionId) {
            applyFactionModifiers(to: newGame, faction: playerFaction)
        }

        // Randomize General Secretary faction at start of each new game
        let possibleGSFactions = ["youth_league", "princelings", "reformists", "old_guard", "regional"]
        let randomGSFaction = possibleGSFactions.randomElement()!

        // Create starting characters - explicitly insert each to ensure SwiftData persistence
        for template in config.startingCharacters {
            let character = GameCharacter(
                templateId: template.id,
                name: template.name,
                title: template.title,
                role: CharacterRole(rawValue: template.role) ?? .neutral
            )
            character.positionIndex = template.positionIndex
            character.positionTrack = template.positionTrack
            character.isPatron = template.isPatron
            character.isRival = template.isRival
            character.disposition = template.startingDisposition
            character.speechPattern = template.speechPattern

            // Randomize General Secretary's faction each new game
            if template.id == "brenner" {
                character.factionId = randomGSFaction
            } else {
                character.factionId = template.factionId
            }

            character.personalityAmbitious = template.personality.ambitious
            character.personalityParanoid = template.personality.paranoid
            character.personalityRuthless = template.personality.ruthless
            character.personalityCompetent = template.personality.competent
            character.personalityLoyal = template.personality.loyal
            character.personalityCorrupt = template.personality.corrupt

            // Copy biographical data from template
            character.backstory = template.backstory
            character.ageCategory = template.ageCategory
            character.originLocation = template.originLocation
            character.familyBackground = template.familyBackground

            // Copy historical connections
            character.historicalConnections = template.historicalConnections ?? []

            // Explicitly insert character into context to ensure persistence
            modelContext.insert(character)
            character.game = newGame
            newGame.characters.append(character)
        }

        // Create factions and apply player faction relationship modifiers
        let playerFaction = PlayerFactionConfig.faction(withId: factionId)
        for factionConfig in config.factions {
            let faction = GameFaction(
                factionId: factionConfig.id,
                name: factionConfig.name,
                description: factionConfig.description
            )
            faction.power = factionConfig.startingPower

            // Base standing + any modifier from player's faction choice
            var standing = factionConfig.startingPlayerStanding
            if let pf = playerFaction {
                if let modifier = pf.factionRelationshipModifiers.first(where: { $0.targetFactionId == factionConfig.id }) {
                    standing += modifier.standingModifier
                }
            }
            faction.playerStanding = max(0, min(100, standing))

            // Explicitly insert faction into context to ensure persistence
            modelContext.insert(faction)
            faction.game = newGame
            newGame.factions.append(faction)
        }

        // Add start event with faction flavor
        let factionName = playerFaction?.name ?? "the Party"
        let startEvent = GameEvent(
            turnNumber: 1,
            eventType: .gameStart,
            summary: "You begin your political career as a member of the \(factionName)."
        )
        startEvent.importance = 10
        modelContext.insert(startEvent)
        startEvent.game = newGame
        newGame.events.append(startEvent)

        // Insert into context
        modelContext.insert(newGame)

        // Initialize position history tracking
        PositionHistoryService.shared.initializePositionHistory(
            game: newGame,
            ladder: config.ladder
        )

        // Initialize NPC-to-NPC relationships for autonomous actions
        CharacterAgencyService.shared.initializeNPCRelationships(game: newGame)

        // Initialize NPC behavior system (goals, needs)
        CharacterAgencyService.shared.initializeBehaviorSystem(game: newGame)

        // Initialize laws
        let defaultLaws = Law.createDefaultLaws()
        for law in defaultLaws {
            modelContext.insert(law)
            law.game = newGame
            newGame.laws.append(law)
        }

        // Initialize regions (domestic zones)
        let defaultRegions = Region.createDefaultRegions()
        for region in defaultRegions {
            modelContext.insert(region)
            region.game = newGame
            newGame.regions.append(region)
        }

        // Initialize foreign countries (international relations)
        let defaultCountries = ForeignCountry.createDefaultCountries()
        for country in defaultCountries {
            modelContext.insert(country)
            country.game = newGame
            newGame.foreignCountries.append(country)
        }

        // Initialize policies for all bureaus/institutions
        PolicyService.shared.initializePolicies(for: newGame)
        for slot in newGame.policySlots {
            modelContext.insert(slot)
        }

        // Initialize Standing Committee
        let committee = StandingCommitteeService.shared.initializeCommittee(for: newGame)
        modelContext.insert(committee)
        newGame.standingCommittee = committee

        // Generate initial pending agenda items
        InitialAgendaGenerator.shared.generateInitialAgenda(for: committee, game: newGame)

        // Generate 43 years of historical sessions
        HistoricalSessionGenerator.shared.generateAllHistoricalSessions(for: newGame, context: modelContext)

        // Record initial stats for sparkline history (so graphs have a starting point)
        newGame.recordAllStatHistory()

        // Generate initial Codex messages (welcome message from patron)
        Task {
            await CodexService.shared.generateMessagesForTurn(game: newGame, context: modelContext)
        }

        // Note: setupState is managed by GamePreparationView now - don't set .playing here
    }

    /// Apply faction stat modifiers to the new game
    private func applyFactionModifiers(to game: Game, faction: PlayerFactionConfig) {
        // Apply bonuses
        for (stat, bonus) in faction.statBonuses {
            game.applyStat(stat, change: bonus)
        }

        // Apply penalties
        for (stat, penalty) in faction.statPenalties {
            game.applyStat(stat, change: penalty)
        }

        // Add faction-specific event targeting tags as flags
        for tag in faction.eventTargetingTags {
            if !game.flags.contains(tag) {
                game.flags.append(tag)
            }
        }

        // Store ability and vulnerability IDs for later reference
        if let ability = faction.specialAbility {
            game.flags.append("ability_\(ability.id)")
        }
        if let vulnerability = faction.vulnerability {
            game.flags.append("vulnerability_\(vulnerability.id)")
        }
    }
}

// MARK: - Game View (with tab navigation)

struct GameView: View {
    @Bindable var game: Game
    @Binding var selectedTab: NavTab
    let onReturnToMenu: () -> Void
    let onRestartWithSameFaction: () -> Void
    var onDeleteAllData: (() -> Void)?
    @Environment(\.theme) var theme
    @Environment(\.modelContext) private var modelContext

    // Outcome data stored between phases
    @State private var currentOutcome: OutcomeData?

    // Game over state
    @State private var showGameOver = false
    @State private var gameOverReason: String = ""

    // Menu sheet state
    @State private var showingMenuSheet = false

    // World sheet state
    @State private var showingWorldSheet = false

    // Congress sheet state
    @State private var showingCongressSheet = false

    // Security sheet state
    @State private var showingSecuritySheet = false

    // Economic sheet state
    @State private var showingEconomicSheet = false

    // Military sheet state
    @State private var showingMilitarySheet = false

    // Party sheet state
    @State private var showingPartySheet = false

    // Ministry sheet state
    @State private var showingMinistrySheet = false

    // Promotion notification state
    @State private var showPromotionNotification = false
    @State private var promotionPosition: LadderPosition?

    private var campaignConfig: CampaignConfig {
        CampaignLoader.shared.getColdWarCampaign()
    }

    var body: some View {
        ZStack {
            // Check for game over first
            if showGameOver || game.currentStatus != .active {
                GameOverView(
                    game: game,
                    endReason: gameOverReason.isEmpty ? (game.endReason ?? "Your journey has ended.") : gameOverReason,
                    onNewGame: {
                        startNewGame()
                    },
                    onMainMenu: {
                        onReturnToMenu()
                    }
                )
            } else {
                // Main content based on selected tab and phase
                Group {
                    switch selectedTab {
                    case .desk:
                        deskTabContent
                    case .ledger:
                        LedgerView(
                            game: game,
                            onWorldTap: { showingWorldSheet = true },
                            onCongressTap: { showingCongressSheet = true },
                            onSecurityTap: { showingSecuritySheet = true },
                            onEconomicTap: { showingEconomicSheet = true },
                            onMilitaryTap: { showingMilitarySheet = true },
                            onPartyTap: { showingPartySheet = true },
                            onMinistryTap: { showingMinistrySheet = true }
                        )
                    case .dossier:
                        DossierView(game: game, onWorldTap: { showingWorldSheet = true }, onCongressTap: { showingCongressSheet = true })
                    case .codex:
                        CodexTerminalView(game: game)
                    case .ladder:
                        OrgChartView(game: game, ladder: campaignConfig.ladder, onWorldTap: { showingWorldSheet = true }, onCongressTap: { showingCongressSheet = true })
                    }
                }

                // Bottom navigation (hidden during outcome phase for focus)
                if game.currentPhase != .outcome {
                    VStack {
                        Spacer()
                        BottomNavBar(selectedTab: $selectedTab) {
                            showingMenuSheet = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingMenuSheet) {
            GameMenuSheet(
                onRestart: { startNewGame() },
                onMainMenu: { onReturnToMenu() },
                onDeleteAllData: onDeleteAllData
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingWorldSheet) {
            WorldTabView(game: game)
        }
        .sheet(isPresented: $showingCongressSheet) {
            CongressTabView(game: game)
        }
        .sheet(isPresented: $showingSecuritySheet) {
            SecurityPortalView(game: game)
        }
        .sheet(isPresented: $showingEconomicSheet) {
            EconomicPortalView(game: game)
        }
        .sheet(isPresented: $showingMilitarySheet) {
            MilitaryPortalView(game: game)
        }
        .sheet(isPresented: $showingPartySheet) {
            PartyPortalView(game: game)
        }
        .sheet(isPresented: $showingMinistrySheet) {
            StateMinistryPortalView(game: game)
        }
        .overlay {
            // Promotion notification overlay
            if showPromotionNotification, let position = promotionPosition {
                PromotionNotificationView(
                    position: position,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showPromotionNotification = false
                            promotionPosition = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .journalToastOverlay()
        .onAppear {
            // Check if game already ended
            if game.currentStatus != .active {
                showGameOver = true
                gameOverReason = game.endReason ?? "Your journey has ended."
            }
        }
    }

    @ViewBuilder
    private var deskTabContent: some View {
        switch game.currentPhase {
        case .briefing, .decision:
            // Show the desk with briefing
            DeskView(
                game: game,
                onDecisionMade: { outcomeData in
                    currentOutcome = outcomeData
                },
                onWorldTap: { showingWorldSheet = true },
                onCongressTap: { showingCongressSheet = true },
                onDossierTap: { selectedTab = .dossier },  // Navigate to Dossier from memo tray
                onLedgerTap: { selectedTab = .ledger },    // Navigate to Ledger from stats
                onLadderTap: { selectedTab = .ladder },    // Navigate to Ladder from standing
                onEndTurn: { transitionToPersonalAction() }  // Proper turn ending through game phases
            )

        case .outcome:
            // Show outcome screen
            if let outcome = currentOutcome {
                OutcomeView(
                    game: game,
                    outcomeText: outcome.outcomeText,
                    statChanges: outcome.statChanges,
                    optionArchetype: outcome.optionChosen.archetype
                ) {
                    transitionToPersonalAction()
                }
            } else {
                // Fallback if no outcome data (shouldn't happen)
                OutcomeView(
                    game: game,
                    outcomeText: "The consequences of your decision unfold...",
                    statChanges: []
                ) {
                    transitionToPersonalAction()
                }
            }

        case .personalAction:
            // Show personal action phase with dynamically generated actions
            PersonalActionView(
                game: game,
                actions: PersonalActionGenerator.shared.generateActions(for: game, ladder: campaignConfig.ladder),
                ladder: campaignConfig.ladder
            ) {
                completePersonalAction()
            }
        }
    }

    private func transitionToPersonalAction() {
        // Check for game end conditions after outcome
        let endCheck = GameEngine.shared.checkGameEndConditions(game: game, ladder: campaignConfig.ladder)
        if endCheck.gameOver {
            endGame(result: endCheck.result ?? .lost, reason: endCheck.reason ?? "Your journey has ended.")
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            game.phase = GamePhase.personalAction.rawValue
        }
    }

    private func completePersonalAction() {
        // Apply end-of-turn updates with Codex and Consequence integration
        Task {
            await GameEngine.shared.endTurnUpdatesWithContext(game: game, ladder: campaignConfig.ladder, context: modelContext)

            // Check for game end conditions (on main actor)
            await MainActor.run {
                let endCheck = GameEngine.shared.checkGameEndConditions(game: game, ladder: campaignConfig.ladder)
                if endCheck.gameOver {
                    endGame(result: endCheck.result ?? .lost, reason: endCheck.reason ?? "Your journey has ended.")
                    return
                }

                // Check for promotion eligibility
                let promotionCheck = GameEngine.shared.checkPromotionEligibility(game: game, ladder: campaignConfig.ladder)
                if promotionCheck.canPromote, let nextPosition = promotionCheck.nextPosition {
                    // Execute promotion and show notification
                    GameEngine.shared.executePromotion(game: game, to: nextPosition)
                    promotionPosition = nextPosition
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showPromotionNotification = true
                    }
                }

                // Clear outcome data
                currentOutcome = nil

                // Advance turn
                game.phase = GamePhase.briefing.rawValue
                game.turnNumber += 1
                game.turnsInCurrentPosition += 1  // Track time in current position
                game.actionPoints = 2  // Reset AP for next turn
                game.usedActionsThisTurn = []  // Clear used actions for new turn
            }
        }

        // Log turn event
        let turnEvent = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .crisis,
            summary: "Turn \(game.turnNumber) begins."
        )
        turnEvent.importance = 3
        turnEvent.game = game
        game.events.append(turnEvent)
    }

    private func endGame(result: GameStatus, reason: String) {
        game.status = result.rawValue
        game.endReason = reason
        gameOverReason = reason

        // Log end event
        let endEvent = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .gameEnd,
            summary: result == .won ? "Victory achieved." : "Career ended."
        )
        endEvent.importance = 10
        endEvent.game = game
        game.events.append(endEvent)

        withAnimation(.easeInOut(duration: 0.5)) {
            showGameOver = true
        }
    }

    private func startNewGame() {
        // Mark current game as abandoned if it's somehow still active
        if game.currentStatus == .active {
            game.status = GameStatus.abandoned.rawValue
        }

        // Restart with the same faction
        onRestartWithSameFaction()
    }
}

// MARK: - Promotion Notification View

struct PromotionNotificationView: View {
    let position: LadderPosition
    let onDismiss: () -> Void
    @Environment(\.theme) var theme
    @State private var showContent = false

    private var promotionTitle: String {
        switch position.index {
        case 6: return "SUPREME POWER"
        case 5: return "THE INNER CIRCLE"
        case 4: return "RISING STAR"
        case 3: return "A SEAT AT THE TABLE"
        case 2: return "ADVANCEMENT"
        default: return "PROMOTION"
        }
    }

    private var flavorText: String {
        switch position.index {
        case 6: return "The Party, the State, the Nation—all answer to you now. But remember: the higher you climb, the further you can fall."
        case 5: return "You stand at the threshold of ultimate power. One step remains. But many have fallen at this final hurdle."
        case 4: return "The General Secretary himself acknowledges your importance. Your enemies grow more desperate."
        case 3: return "Real power flows through your hands now. With it comes real danger."
        case 2: return "You have proven your worth. The Party rewards loyalty—and punishes failure."
        default: return "Your rise continues. The Politburo has noticed."
        }
    }

    var body: some View {
        ZStack {
            // Darkened background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Notification card
            VStack(spacing: 0) {
                // Gold header bar
                Rectangle()
                    .fill(theme.accentGold)
                    .frame(height: 4)

                VStack(spacing: 20) {
                    // Star icon
                    Image(systemName: "star.fill")
                        .font(.system(size: 50))
                        .foregroundColor(theme.accentGold)
                        .shadow(color: theme.accentGold.opacity(0.5), radius: 10)
                        .scaleEffect(showContent ? 1.0 : 0.5)
                        .opacity(showContent ? 1.0 : 0)

                    // Title
                    Text(promotionTitle)
                        .font(.system(size: 24, weight: .black))
                        .tracking(4)
                        .foregroundColor(theme.accentGold)
                        .opacity(showContent ? 1.0 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Position name
                    Text(position.title.uppercased())
                        .font(theme.headerFont)
                        .tracking(2)
                        .foregroundColor(theme.inkBlack)
                        .opacity(showContent ? 1.0 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Divider
                    Rectangle()
                        .fill(theme.borderTan)
                        .frame(width: 100, height: 1)
                        .opacity(showContent ? 1.0 : 0)

                    // Description
                    Text(position.description)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .opacity(showContent ? 1.0 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Flavor text
                    Text(flavorText)
                        .font(theme.bodyFontSmall)
                        .italic()
                        .foregroundColor(theme.inkLight)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .opacity(showContent ? 1.0 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Continue button
                    Button {
                        onDismiss()
                    } label: {
                        Text("ACCEPT POSITION")
                            .font(theme.labelFont)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(theme.sovietRed)
                    }
                    .opacity(showContent ? 1.0 : 0)
                    .scaleEffect(showContent ? 1.0 : 0.9)
                    .padding(.top, 10)
                }
                .padding(30)
                .background(theme.parchment)

                // Gold footer bar
                Rectangle()
                    .fill(theme.accentGold)
                    .frame(height: 4)
            }
            .frame(maxWidth: 340)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                showContent = true
            }
        }
    }
}

// MARK: - Game Preparation View

struct GamePreparationView: View {
    let campaignId: String
    let factionId: String
    let onGameReady: () -> Void
    let onCreateGame: (String, String) -> Void
    @Environment(\.theme) var theme
    @Environment(\.modelContext) private var modelContext
    @Query private var games: [Game]

    @State private var preparationPhase: PreparationPhase = .creatingGame
    @State private var progress: Double = 0
    @State private var statusMessage: String = "Preparing your first day in office..."
    @State private var isComplete = false

    @ObservedObject private var loadingState = ScenarioManager.shared.loadingState

    private var activeGame: Game? {
        games.first { $0.currentStatus == .active }
    }

    enum PreparationPhase: Int {
        case creatingGame = 0
        case generatingDocuments = 1
        case generatingBriefing = 2
        case finalizing = 3
        case complete = 4

        var message: String {
            switch self {
            case .creatingGame: return "Creating your political dossier..."
            case .generatingDocuments: return "Preparing government documents..."
            case .generatingBriefing: return "Briefing the General Secretary..."
            case .finalizing: return "Setting up your office..."
            case .complete: return "Your first day begins."
            }
        }
    }

    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Hammer and sickle or state seal icon
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(theme.accentGold)
                    .shadow(color: theme.accentGold.opacity(0.3), radius: 10)

                // Title
                VStack(spacing: 8) {
                    Text("PREPARING YOUR APPOINTMENT")
                        .font(theme.headerFont)
                        .tracking(3)
                        .foregroundColor(theme.accentGold)

                    Text(statusMessage)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.schemeText.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // Progress bar
                VStack(spacing: 12) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "333333"))

                            // Progress fill
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.sovietRed)
                                .frame(width: geometry.size.width * progress)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 60)

                    Text("\(Int(progress * 100))%")
                        .font(theme.tagFont)
                        .foregroundColor(theme.schemeText.opacity(0.6))
                }

                // Phase indicators
                HStack(spacing: 20) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index <= preparationPhase.rawValue ? theme.accentGold : Color(hex: "444444"))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                // Flavor text
                Text("The apparatus awaits your orders.")
                    .font(theme.bodyFontSmall)
                    .italic()
                    .foregroundColor(theme.schemeText.opacity(0.4))
                    .padding(.bottom, 40)
            }
        }
        .task {
            await prepareGame()
        }
        .onChange(of: loadingState.isLoading) { wasLoading, isLoading in
            if wasLoading && !isLoading {
                // Loading complete
                completePreparation()
            }
        }
    }

    private func prepareGame() async {
        // Phase 1: Create the game
        await MainActor.run {
            statusMessage = PreparationPhase.creatingGame.message
            progress = 0.1
        }

        // Small delay for visual feedback
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Create the game (this is synchronous)
        await MainActor.run {
            onCreateGame(campaignId, factionId)
            progress = 0.3
            preparationPhase = .generatingDocuments
            statusMessage = PreparationPhase.generatingDocuments.message
        }

        // Phase 2: Generate documents
        try? await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            if let game = activeGame {
                DocumentQueueService.shared.generateDocumentsForTurn(game: game)
            }
            progress = 0.5
            preparationPhase = .generatingBriefing
            statusMessage = PreparationPhase.generatingBriefing.message
        }

        // Phase 3: Start briefing/scenario generation
        try? await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            if let game = activeGame {
                let config = CampaignLoader.shared.getColdWarCampaign()
                ScenarioManager.shared.startBackgroundLoading(
                    for: game,
                    config: config,
                    checkDynamicEvents: { nil }  // No dynamic events on first turn
                )
            }
            progress = 0.7
            preparationPhase = .finalizing
            statusMessage = PreparationPhase.finalizing.message
        }

        // Wait for scenario generation with timeout
        let startTime = Date()
        let maxWait: TimeInterval = 15.0  // Maximum 15 seconds wait

        while loadingState.isLoading && Date().timeIntervalSince(startTime) < maxWait {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                // Update progress while waiting
                let elapsed = Date().timeIntervalSince(startTime)
                let waitProgress = min(elapsed / maxWait, 1.0)
                progress = 0.7 + (0.25 * waitProgress)
            }
        }

        // Complete
        completePreparation()
    }

    private func completePreparation() {
        guard !isComplete else { return }
        isComplete = true

        preparationPhase = .complete
        statusMessage = PreparationPhase.complete.message
        progress = 1.0

        // Brief pause to show completion, then transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onGameReady()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Game.self, GameCharacter.self, GameFaction.self, GameEvent.self], inMemory: true)
}
