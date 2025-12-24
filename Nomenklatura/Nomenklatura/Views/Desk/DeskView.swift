//
//  DeskView.swift
//  Nomenklatura
//
//  The Desk - Main game screen (Stitch-inspired redesign)
//

import SwiftUI
import SwiftData
import Combine

struct DeskView: View {
    @Bindable var game: Game
    let onDecisionMade: (OutcomeData) -> Void
    var onWorldTap: (() -> Void)? = nil
    var onCongressTap: (() -> Void)? = nil
    var onDossierTap: (() -> Void)? = nil
    var onLedgerTap: (() -> Void)? = nil
    var onLadderTap: (() -> Void)? = nil
    var onEndTurn: (() -> Void)? = nil  // Callback to properly end turn through game phases

    @State private var selectedOptionId: String?
    @State private var currentScenario: Scenario?
    @State private var currentNewspaper: NewspaperEdition?
    @State private var currentSamizdat: NewspaperEdition?
    @State private var currentDynamicEvent: DynamicEvent?
    @State private var isAIGenerated = false
    @Environment(\.theme) var theme

    // View state
    @State private var showContent = false
    @State private var showDynamicEvent = false
    @State private var isTransitioning = false
    @State private var previousTurn = 0
    @State private var hasDisplayedContentForTurn = false
    @State private var showMemoPanel = false
    @State private var showFullNewspaper = false  // Expand newspaper from preview
    @State private var showFullScenario = false   // Expand scenario from card
    @State private var scenarioOverlayOffset: CGFloat = 0  // For pull-to-dismiss

    // Document queue system
    @State private var selectedDocument: DeskDocument?
    @State private var showDocumentDetail = false
    @ObservedObject private var documentQueue = DocumentQueueService.shared

    // End turn confirmation
    @State private var showEndTurnConfirmation = false

    // Loading snapshot cycling
    @State private var currentSnapshotIndex = 0
    @State private var snapshotOpacity: Double = 1.0
    private let snapshotImages = ["snapshot_1", "snapshot_2", "snapshot_3", "snapshot_4", "snapshot_5", "snapshot_6", "snapshot_7"]
    private let snapshotTimer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    // Observe the shared loading state
    @ObservedObject private var loadingState = ScenarioManager.shared.loadingState

    private var campaignConfig: CampaignConfig {
        CampaignLoader.shared.getColdWarCampaign()
    }

    var body: some View {
        ZStack {
            // Wood desk background
            WoodDeskBackground()
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Stitch Status Bar
                StitchStatusBar(
                    date: formattedDate,
                    turnNumber: game.turnNumber,
                    hasNotifications: hasNotifications,
                    onCongressTap: onCongressTap,
                    onWorldTap: onWorldTap,
                    onTurnTap: { showEndTurnConfirmation = true }
                )

                // Scrollable desk content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Player ID Card
                            PlayerIDCard(
                                playerName: playerTitle,
                                title: positionTitle,
                                clearanceLevel: clearanceLevel
                            )
                            .id("idCard")

                            // Personal Stats Widget - each stat navigates to relevant screen
                            PersonalStatsWidgetRow(
                                standing: game.standing,
                                network: game.network,
                                patronFavor: game.patronFavor,
                                rivalThreat: game.rivalThreat,
                                onStandingTap: onLadderTap,
                                onNetworkTap: onDossierTap,
                                onPatronTap: openPatronSheet,
                                onRivalTap: openRivalSheet
                            )

                            // Content area - newspaper preview or scenario cards
                            contentSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                    .onChange(of: game.turnNumber) { _, _ in
                        // Scroll to top when turn changes to ensure ID card is visible
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("idCard", anchor: .top)
                        }
                    }
                }
            }

            // Sticky Notes FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MemoTrayButton(game: game) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showMemoPanel = true
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }

            // Full-screen overlays
            if showFullNewspaper, let newspaper = currentNewspaper {
                fullNewspaperOverlay(newspaper: newspaper)
            }

            if showFullScenario, let scenario = currentScenario {
                fullScenarioOverlay(scenario: scenario)
            }

            // Dynamic event overlay
            if showDynamicEvent, let event = currentDynamicEvent {
                dynamicEventOverlay(event: event)
            }

            // Memo slide-out panel
            if showMemoPanel {
                memoSlideOutOverlay
            }

            // Document detail overlay
            if showDocumentDetail, let document = selectedDocument {
                DocumentDetailView(
                    document: document,
                    game: game,
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showDocumentDetail = false
                            selectedDocument = nil
                        }
                    },
                    onOptionSelected: { option in
                        handleDocumentDecision(document: document, option: option)
                    }
                )
            }
        }
        .task {
            if game.turnNumber > 1 && currentScenario == nil && currentNewspaper == nil {
                isTransitioning = true
            }
            startBackgroundLoading()
            // Generate documents for this turn if needed
            documentQueue.generateDocumentsForTurn(game: game)
        }
        .onChange(of: game.turnNumber) { _, newValue in handleTurnChange(newValue) }
        .onChange(of: loadingState.isLoading) { wasLoading, isLoading in
            if wasLoading && !isLoading && !hasDisplayedContentForTurn {
                applyCachedContent()
            }
        }
        .onAppear { handleOnAppear() }
        .modifier(CharacterSheetOverlayModifier(game: game))
        .sheet(isPresented: $showEndTurnConfirmation) {
            EndTurnConfirmationSheet(
                game: game,
                pendingDocuments: documentQueue.getActiveDocuments(for: game).filter { $0.requiresDecision },
                onConfirm: {
                    showEndTurnConfirmation = false
                    processEndTurnWithConsequences()
                },
                onCancel: {
                    showEndTurnConfirmation = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Computed Properties

    private var formattedDate: String {
        RevolutionaryCalendar.formatTurnWithMonth(game.turnNumber)
    }

    private var playerTitle: String {
        "Comrade Director"
    }

    private var positionTitle: String {
        let config = CampaignLoader.shared.getColdWarCampaign()
        return config.ladder.first(where: { $0.index == game.currentPositionIndex })?.title ?? "Party Official"
    }

    private var clearanceLevel: Int {
        min(game.currentPositionIndex + 1, 8)
    }

    private var hasNotifications: Bool {
        game.unreadJournalCount > 0 || currentDynamicEvent != nil
    }

    // MARK: - Turn Advancement

    /// Process end of turn with consequences for unhandled documents
    private func processEndTurnWithConsequences() {
        // Apply consequences for pending documents
        let pendingDocs = documentQueue.getActiveDocuments(for: game).filter { $0.requiresDecision }
        for doc in pendingDocs {
            applyDocumentConsequence(doc)
        }

        // Clear current scenario/newspaper state
        currentScenario = nil
        currentNewspaper = nil
        currentSamizdat = nil

        // Use the proper end turn flow through game phases
        if let onEndTurn = onEndTurn {
            onEndTurn()
        } else {
            // Fallback: direct turn advancement (shouldn't normally happen)
            advanceTurnFromDesk()
        }
    }

    /// Apply negative consequence for not acting on a document
    private func applyDocumentConsequence(_ document: DeskDocument) {
        // Mark document as expired/ignored
        document.status = DocumentStatus.expired.rawValue

        // Apply stat penalties based on document urgency and type
        let penalty: Int
        switch document.urgencyEnum {
        case .critical:
            penalty = -8
            game.standing = max(0, game.standing - 5)  // Standing hit for ignoring critical items
        case .urgent:
            penalty = -5
            game.standing = max(0, game.standing - 2)
        case .priority:
            penalty = -3
        case .routine:
            penalty = -1
        }

        // Apply the penalty to relevant stats based on document category
        switch document.categoryEnum {
        case .political:
            game.eliteLoyalty = max(0, game.eliteLoyalty + penalty)
        case .economic:
            game.treasury = max(0, game.treasury + penalty * 10)
        case .security:
            game.stability = max(0, game.stability + penalty)
        case .diplomatic:
            game.internationalStanding = max(0, game.internationalStanding + penalty)
        case .military:
            game.militaryLoyalty = max(0, game.militaryLoyalty + penalty)
        case .personnel:
            game.network = max(0, game.network + penalty / 2)
        case .crisis:
            game.stability = max(0, game.stability + penalty)
            game.standing = max(0, game.standing - 3)  // Crisis neglect hurts standing
        case .personal:
            game.patronFavor = max(0, game.patronFavor + penalty)
        }

        // Log the consequence
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .decision,
            summary: "Failed to act on: \(document.title)"
        )
        event.game = game
        game.events.append(event)
    }

    // MARK: - Navigation Actions

    private func openPatronSheet() {
        if let patron = game.patron {
            NotificationCenter.default.post(
                name: .showCharacterSheet,
                object: patron.name
            )
        }
    }

    private func openRivalSheet() {
        // Find active rival character
        if let rival = game.characters.first(where: { $0.isRival && $0.isActive }) {
            NotificationCenter.default.post(
                name: .showCharacterSheet,
                object: rival.name
            )
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 16) {
            // Document stack section (always show if documents exist)
            let visibleDocuments = documentQueue.getVisibleDocuments(for: game)
            if !visibleDocuments.isEmpty {
                documentStackSection(documents: visibleDocuments)
            }

            // Loading/Scenario/Newspaper section
            if isTransitioning || loadingState.isLoading {
                // Immersive loading with manila folder, photos, and CLASSIFIED stamp
                immersiveLoadingSection
            } else if let newspaper = currentNewspaper {
                physicalNewspaperCard(newspaper: newspaper)
            } else if let scenario = currentScenario {
                physicalScenarioCards(scenario: scenario)
            } else if visibleDocuments.isEmpty {
                // Only show loading if no documents either
                immersiveLoadingSection
            } else {
                // Documents exist but no scenario/newspaper - show End Turn option
                endTurnSection
            }
        }
    }

    // MARK: - End Turn Section

    @ViewBuilder
    private var endTurnSection: some View {
        VStack(spacing: 12) {
            // Explanation
            Text("All documents processed for this turn.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(FiftiesColors.leatherBrown.opacity(0.7))
                .multilineTextAlignment(.center)

            // End Turn button styled like 1950s office
            Button {
                advanceTurnFromDesk()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                    Text("END TURN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(FiftiesColors.leatherBrown)
                )
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(FiftiesColors.agedPaper.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(FiftiesColors.leatherBrown.opacity(0.2), lineWidth: 1)
                )
        )
    }

    /// Advance turn when player clicks End Turn from desk
    private func advanceTurnFromDesk() {
        // Log turn end event
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .narrative,
            summary: "Completed administrative duties"
        )
        event.game = game
        game.events.append(event)

        // Pre-generate content for next turn
        ScenarioManager.shared.preGenerateForNextTurn(game: game, config: campaignConfig)

        // Advance turn
        game.turnNumber += 1
        game.turnsInCurrentPosition += 1

        // Reset state for new turn
        currentScenario = nil
        currentNewspaper = nil
        hasDisplayedContentForTurn = false
        isTransitioning = true

        // Generate new documents for the new turn
        documentQueue.generateDocumentsForTurn(game: game)
    }

    // MARK: - Document Stack Section

    @ViewBuilder
    private func documentStackSection(documents: [DeskDocument]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Rectangle()
                    .fill(FiftiesColors.urgentRed)
                    .frame(width: 3, height: 14)

                Text("DOCUMENTS AWAITING ACTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(FiftiesColors.leatherBrown)

                Spacer()

                // Document count badge
                Text("\(documents.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(documents.contains { $0.urgencyEnum >= .urgent } ? FiftiesColors.urgentRed : FiftiesColors.leatherBrown)
                    )
            }

            // Document grid
            DocumentStackView(documents: documents) { document in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDocument = document
                    showDocumentDetail = true
                    document.markAsRead()
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                // Desk blotter area
                RoundedRectangle(cornerRadius: 4)
                    .fill(FiftiesColors.leatherBrown.opacity(0.08))

                // Subtle border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(FiftiesColors.leatherBrown.opacity(0.15), lineWidth: 1)
            }
        )
    }

    // MARK: - Immersive Loading (1950s Dossier Style)

    @ViewBuilder
    private var immersiveLoadingSection: some View {
        VStack(spacing: 0) {
            // Manila folder with cycling photographs
            ZStack {
                // Manila folder background
                RoundedRectangle(cornerRadius: 4)
                    .fill(FiftiesColors.manillaFolder)
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)

                // Paper texture overlay (using deterministic pattern to avoid re-rendering)
                Canvas { context, size in
                    var rng = SeededRandomNumberGenerator(seed: 12345)
                    for _ in 0..<60 {
                        let x = CGFloat.random(in: 0...size.width, using: &rng)
                        let y = CGFloat.random(in: 0...size.height, using: &rng)
                        let length = CGFloat.random(in: 8...25, using: &rng)
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + length, y: y))
                        context.stroke(path, with: .color(FiftiesColors.leatherBrown.opacity(0.1)), lineWidth: 0.5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .drawingGroup() // Cache the rendered texture

                // Content: Photo + Info
                HStack(alignment: .top, spacing: 16) {
                    // Cycling photograph with dossier styling
                    ZStack(alignment: .topTrailing) {
                        // Photo stack shadow
                        Rectangle()
                            .fill(Color.black.opacity(0.15))
                            .frame(width: 105, height: 130)
                            .offset(x: 3, y: 4)

                        // Photo with photo corners
                        ZStack {
                            Rectangle()
                                .fill(Color(hex: "2A2A2A"))

                            Image(snapshotImages[currentSnapshotIndex])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 94, height: 119)
                                .clipped()
                                .grayscale(0.6)
                                .opacity(snapshotOpacity)
                        }
                        .frame(width: 100, height: 125)
                        .overlay {
                            // Photo corner mounts - as overlay to stay within bounds
                            ZStack {
                                // Top-left
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 12))
                                    path.addLine(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: 12, y: 0))
                                }
                                .stroke(Color(hex: "4A4A4A"), lineWidth: 2)
                                .offset(x: 4, y: 4)

                                // Top-right
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: 12, y: 0))
                                    path.addLine(to: CGPoint(x: 12, y: 12))
                                }
                                .stroke(Color(hex: "4A4A4A"), lineWidth: 2)
                                .offset(x: 84, y: 4)

                                // Bottom-left
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: 0, y: 12))
                                    path.addLine(to: CGPoint(x: 12, y: 12))
                                }
                                .stroke(Color(hex: "4A4A4A"), lineWidth: 2)
                                .offset(x: 4, y: 109)

                                // Bottom-right
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 12))
                                    path.addLine(to: CGPoint(x: 12, y: 12))
                                    path.addLine(to: CGPoint(x: 12, y: 0))
                                }
                                .stroke(Color(hex: "4A4A4A"), lineWidth: 2)
                                .offset(x: 84, y: 109)
                            }
                        }
                        .rotationEffect(.degrees(-1.5))

                        // Paper clip - overlaps top-right corner of photo
                        Image(systemName: "paperclip")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(Color(hex: "A0A0A0"))
                            .rotationEffect(.degrees(45))
                            .offset(x: 8, y: 0)
                    }

                    // Right side: Status + stamp
                    VStack(alignment: .leading, spacing: 10) {
                        // DOSSIER header - typewriter style
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(FiftiesColors.stampRed)
                                .frame(width: 3, height: 12)

                            Text("DOSSIER")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(FiftiesColors.leatherBrown)
                        }

                        // Loading status - typewriter style
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(FiftiesColors.leatherBrown)

                                Text(loadingState.loadingMessage.uppercased())
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundColor(FiftiesColors.leatherBrown)
                                    .lineLimit(2)
                            }

                            if Secrets.isAIEnabled && loadingState.isLoading {
                                Text("AI-POWERED GENERATION")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(FiftiesColors.fadedInk)
                            }
                        }

                        Spacer()

                        // CLASSIFIED rubber stamp
                        RubberStamp(text: "CLASSIFIED", stampType: .classified, rotation: -5, size: .medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(maxWidth: .infinity)
            .frame(height: 175)
            .onReceive(snapshotTimer) { _ in
                // Only cycle images when loading screen is actually visible
                guard loadingState.isLoading else { return }

                // Slow fade out
                withAnimation(.easeOut(duration: 1.2)) {
                    snapshotOpacity = 0.0
                }
                // Change image after fade out, then fade back in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    currentSnapshotIndex = (currentSnapshotIndex + 1) % snapshotImages.count
                    withAnimation(.easeIn(duration: 1.5)) {
                        snapshotOpacity = 1.0
                    }
                }
            }
        }
    }

    // MARK: - Physical Newspaper Card (1950s Newsprint Style)

    @ViewBuilder
    private func physicalNewspaperCard(newspaper: NewspaperEdition) -> some View {
        // Newspaper styled as physical folded paper on desk
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showFullNewspaper = true
            }
        } label: {
            ZStack {
                // Paper shadow
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .offset(x: 3, y: 4)

                // Newspaper paper
                VStack(alignment: .leading, spacing: 0) {
                    // Masthead - period newspaper style
                    HStack {
                        Text(newspaper.publicationName.uppercased())
                            .font(.system(size: 18, weight: .black, design: .serif))
                            .tracking(1)
                            .foregroundColor(FiftiesColors.typewriterInk)

                        Spacer()

                        Text(formattedDate.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.fadedInk)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                    // Decorative double line under masthead
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(FiftiesColors.typewriterInk)
                            .frame(height: 2)
                        Rectangle()
                            .fill(FiftiesColors.typewriterInk)
                            .frame(height: 0.5)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    // Headline
                    Text(newspaper.headline.headline.uppercased())
                        .font(.system(size: 18, weight: .black, design: .serif))
                        .foregroundColor(FiftiesColors.typewriterInk)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)

                    // Brief text
                    Text(String(newspaper.headline.body.prefix(100)) + "...")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(FiftiesColors.fadedInk)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                        .padding(.bottom, 12)

                    // Fold line indicator
                    Rectangle()
                        .fill(FiftiesColors.typewriterInk.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 6)

                    // Bottom padding
                    Spacer()
                        .frame(height: 8)
                }
                .background(
                    ZStack {
                        // Newsprint color - slightly yellowed
                        FiftiesColors.agedPaper

                        // Aged paper texture (using deterministic pattern to avoid re-rendering)
                        Canvas { context, size in
                            var rng = SeededRandomNumberGenerator(seed: 67890)
                            // Paper fibers
                            for _ in 0..<40 {
                                let x = CGFloat.random(in: 0...size.width, using: &rng)
                                let y = CGFloat.random(in: 0...size.height, using: &rng)
                                let length = CGFloat.random(in: 4...12, using: &rng)
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: y))
                                path.addLine(to: CGPoint(x: x + length, y: y))
                                context.stroke(path, with: .color(FiftiesColors.typewriterInk.opacity(0.03)), lineWidth: 0.5)
                            }
                        }
                        .drawingGroup() // Cache the rendered texture

                        // Edge aging
                        LinearGradient(
                            colors: [FiftiesColors.leatherBrown.opacity(0.08), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    }
                )
                .clipShape(Rectangle())
            }
            .rotationEffect(.degrees(-0.8))
        }
        .buttonStyle(.plain)

        // Samizdat as hidden note tucked underneath
        if let samizdat = currentSamizdat {
            ZStack {
                // Shadow
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .offset(x: 2, y: 3)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 9))
                        Text("SAMIZDAT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                    }
                    .foregroundColor(FiftiesColors.fadedInk)

                    Text(samizdat.headline.headline)
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(FiftiesColors.typewriterInk)
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    // Cheaper onionskin paper
                    Color(hex: "E8E4D8")
                )
                .clipShape(Rectangle())
            }
            .rotationEffect(.degrees(1.2))
            .offset(y: -8)
        }

        // Action buttons for newspaper
        HStack(spacing: 12) {
            // Read button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showFullNewspaper = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                    Text("READ")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FiftiesColors.leatherBrown)
                )
            }
            .buttonStyle(.plain)

            // Skip/Put Aside button
            Button {
                continueFromNewspaper()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 12))
                    Text("PUT ASIDE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(FiftiesColors.leatherBrown)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(FiftiesColors.leatherBrown, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Physical Scenario Cards (1950s Official Memo Style)

    @ViewBuilder
    private func physicalScenarioCards(scenario: Scenario) -> some View {
        // Briefing document styled as official memo on desk
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showFullScenario = true
            }
        } label: {
            ZStack {
                // Document shadow
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .offset(x: 3, y: 4)

                // Main document
                VStack(alignment: .leading, spacing: 0) {
                    // Official header with red stripe
                    HStack(alignment: .top) {
                        Rectangle()
                            .fill(scenario.requiresDecision ? FiftiesColors.urgentRed : FiftiesColors.leatherBrown)
                            .frame(width: 4)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(scenario.requiresDecision ? "ACTION REQUIRED" : "FOR YOUR INFORMATION")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(scenario.requiresDecision ? FiftiesColors.urgentRed : FiftiesColors.leatherBrown)

                            Text(scenario.category.rawValue.uppercased())
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(FiftiesColors.fadedInk)
                        }

                        Spacer()

                        // Rubber stamp
                        if scenario.requiresDecision {
                            RubberStamp(text: "URGENT", stampType: .urgent, rotation: -8, size: .small)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                    // Divider line - typewriter style
                    Text(String(repeating: "-", count: 50))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk.opacity(0.4))
                        .padding(.horizontal, 12)
                        .padding(.top, 6)

                    // Presenter info - memo format
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("FROM:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(FiftiesColors.fadedInk)
                                .frame(width: 40, alignment: .leading)

                            Text(scenario.presenterName.uppercased())
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(FiftiesColors.typewriterInk)
                        }

                        if let title = scenario.presenterTitle {
                            HStack(spacing: 6) {
                                Text("")
                                    .frame(width: 40)
                                Text("(\(title))")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(FiftiesColors.fadedInk)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    // Briefing content preview
                    Text(String(scenario.briefing.prefix(120)) + "...")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(FiftiesColors.typewriterInk)
                        .lineLimit(3)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    // Footer with action hint
                    HStack {
                        if scenario.requiresDecision {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                Text("\(scenario.options.count) OPTIONS REQUIRE DECISION")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                            }
                            .foregroundColor(FiftiesColors.urgentRed.opacity(0.8))
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("REVIEW")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(FiftiesColors.fadedInk)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                }
                .background(
                    ZStack {
                        // Government memo paper
                        FiftiesColors.agedPaper

                        // Paper texture
                        Canvas { context, size in
                            var rng = SeededRandomNumberGenerator(seed: 11111)
                            for _ in 0..<25 {
                                let x = CGFloat.random(in: 0...size.width, using: &rng)
                                let y = CGFloat.random(in: 0...size.height, using: &rng)
                                let length = CGFloat.random(in: 3...10, using: &rng)
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: y))
                                path.addLine(to: CGPoint(x: x + length, y: y))
                                context.stroke(path, with: .color(FiftiesColors.typewriterInk.opacity(0.02)), lineWidth: 0.5)
                            }
                        }
                        .drawingGroup()

                        // Coffee ring stain (subtle authenticity)
                        Circle()
                            .stroke(Color(hex: "8B6914").opacity(0.04), lineWidth: 2)
                            .frame(width: 35, height: 35)
                            .blur(radius: 1)
                            .offset(x: 90, y: -50)
                    }
                )
                .clipShape(Rectangle())
            }
            .rotationEffect(.degrees(0.5))
        }
        .buttonStyle(.plain)

        // Paper clip decoration (optional - suggests multiple pages)
        if scenario.requiresDecision && scenario.options.count > 2 {
            HStack {
                Spacer()
                Image(systemName: "paperclip")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "6A6A6A").opacity(0.6))
                    .rotationEffect(.degrees(25))
                    .offset(x: 25, y: -18)
            }
        }
    }

    // MARK: - Full Newspaper Overlay

    @ViewBuilder
    private func fullNewspaperOverlay(newspaper: NewspaperEdition) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showFullNewspaper = false
                    }
                }

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        withAnimation {
                            showFullNewspaper = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }

                MultiNewspaperView(
                    stateEdition: newspaper,
                    samizdatEdition: currentSamizdat
                ) {
                    showFullNewspaper = false
                    continueFromNewspaper()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
                .padding(.bottom, 20)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Full Scenario Overlay

    @ViewBuilder
    private func fullScenarioOverlay(scenario: Scenario) -> some View {
        let dismissThreshold: CGFloat = 150

        ZStack {
            // Background - dims as you pull down
            Color.black.opacity(0.5 * (1 - min(scenarioOverlayOffset / 300, 0.5)))
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow tap to dismiss for non-decision scenarios
                    if !scenario.requiresDecision {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showFullScenario = false
                        }
                    }
                }

            VStack(spacing: 0) {
                // Pull indicator at top
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Close button (only for non-decision scenarios)
                if !scenario.requiresDecision {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showFullScenario = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal)
                    }
                }

                ScrollView {
                    VStack(spacing: 15) {
                        if scenario.requiresDecision {
                            decisionContent(scenario: scenario)
                        } else {
                            NarrativeEventView(
                                scenario: scenario,
                                turnNumber: game.turnNumber,
                                game: game
                            ) {
                                showFullScenario = false
                                continueFromNarrativeEvent()
                            }
                        }
                    }
                    .padding(15)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 100) // Space for tab bar
                }
                .background(theme.parchment)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
                .padding(.bottom, 80)
            }
            .offset(y: scenarioOverlayOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow downward dragging
                        if value.translation.height > 0 {
                            scenarioOverlayOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > dismissThreshold {
                            // Dismiss
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showFullScenario = false
                                scenarioOverlayOffset = 0
                            }
                            // If it was a non-decision scenario, continue the game
                            if !scenario.requiresDecision {
                                continueFromNarrativeEvent()
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scenarioOverlayOffset = 0
                            }
                        }
                    }
            )
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func decisionContent(scenario: Scenario) -> some View {
        BriefingPaperView(
            scenario: scenario,
            turnNumber: game.turnNumber,
            game: game
        )

        VStack(spacing: 10) {
            ForEach(Array(scenario.options.enumerated()), id: \.element.id) { index, option in
                if option.isLocked {
                    LockedOptionCardView(option: option)
                } else {
                    OptionCardView(
                        option: option,
                        isSelected: selectedOptionId == option.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedOptionId = option.id
                        }
                    }
                }
            }
        }

        if selectedOptionId != nil {
            Button {
                confirmDecision()
                showFullScenario = false
            } label: {
                Text("CONFIRM DECISION")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(StitchColors.stampRed)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .padding(.top, 15)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Dynamic Event Overlay

    @ViewBuilder
    private func dynamicEventOverlay(event: DynamicEvent) -> some View {
        if event.eventType == .ambientTension {
            VStack {
                AmbientTensionView(event: event, game: game) {
                    handleDynamicEventDismissed(nil)
                }
                .padding(.top, 100)
                Spacer()
            }
        } else if event.eventType == .characterSummons || event.priority >= .urgent {
            SummonsOverlayView(event: event, game: game) {
                handleDynamicEventDismissed(event.responseOptions?.first)
            }
        } else {
            DynamicEventView(
                event: event,
                game: game,
                onDismiss: { response in
                    handleDynamicEventDismissed(response)
                }
            )
        }
    }

    // MARK: - Memo Panel

    @ViewBuilder
    private var memoSlideOutOverlay: some View {
        MemoSlideOutPanel(
            game: game,
            isOpen: showMemoPanel,
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showMemoPanel = false
                }
            },
            onViewAll: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showMemoPanel = false
                }
                onDossierTap?()
            }
        )
    }

    // MARK: - Background Loading

    private func startBackgroundLoading() {
        guard currentScenario == nil && currentNewspaper == nil && currentDynamicEvent == nil else { return }

        ScenarioManager.shared.startBackgroundLoading(
            for: game,
            config: campaignConfig,
            checkDynamicEvents: { [self] in
                return self.checkForDynamicEventsSync()
            }
        )
    }

    private func applyCachedContent() {
        guard !hasDisplayedContentForTurn else { return }

        if let event = loadingState.cachedDynamicEvent {
            currentDynamicEvent = event
            showDynamicEvent = true
            hasDisplayedContentForTurn = true
            if event.eventType == .characterMessage, let charName = event.initiatingCharacterName {
                NotificationService.shared.notifyCharacterMessage(name: charName, turn: game.turnNumber)
            }
            // Pre-generate next turn while user reads dynamic event
            ScenarioManager.shared.preGenerateForNextTurn(game: game, config: campaignConfig)
            return
        }

        if let newspaper = loadingState.cachedNewspaper {
            currentNewspaper = newspaper
            currentSamizdat = loadingState.cachedSamizdat
            isAIGenerated = loadingState.isAIGenerated
            isTransitioning = false
            hasDisplayedContentForTurn = true

            // Pre-generate next turn while user reads newspaper
            ScenarioManager.shared.preGenerateForNextTurn(game: game, config: campaignConfig)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    showContent = true
                }
            }
            return
        }

        if let scenario = loadingState.cachedScenario {
            hasDisplayedContentForTurn = true
            handleScenarioLoaded(scenario)
            return
        }

        // No content was cached - clear transitioning state so END TURN button can appear
        // This happens when content generation fails or produces nothing
        isTransitioning = false
        hasDisplayedContentForTurn = true
    }

    private func checkForDynamicEventsSync() -> DynamicEvent? {
        guard game.turnNumber > 1 else { return nil }

        if game.shouldForceQuietTurn {
            game.resetEventPacing()
            return nil
        }

        if let event = DynamicEventTriggerService.shared.evaluateTriggers(game: game, phase: .briefing) {
            return event
        }

        if let characterEvent = CharacterAgencyService.shared.evaluateCharacterActions(game: game) {
            return characterEvent
        }

        let goalEvents = GoalDrivenAgencyService.shared.evaluateGoalDrivenActions(game: game)
        if let firstGoalEvent = goalEvents.first {
            return firstGoalEvent
        }

        let memoryEvents = MemoryIntegrationService.shared.evaluateMemoryDrivenActions(game: game)
        if let memoryEvent = memoryEvents.first {
            return memoryEvent
        }

        return nil
    }

    // MARK: - View Lifecycle

    private func handleTurnChange(_ newValue: Int) {
        showContent = false
        showDynamicEvent = false
        showFullNewspaper = false
        showFullScenario = false
        showDocumentDetail = false
        selectedDocument = nil
        currentScenario = nil
        currentNewspaper = nil
        currentSamizdat = nil
        currentDynamicEvent = nil
        hasDisplayedContentForTurn = false

        ProjectService.shared.updateProjectsForTurn(game: game)
        let completions = ProjectService.shared.checkProjectCompletions(game: game)

        for completion in completions {
            ProjectService.shared.applyCompletionEffects(completion: completion, game: game)
            if let event = ProjectService.shared.generateCompletionEvent(completion: completion, game: game) {
                game.queueDynamicEvent(event)
            }
        }

        // Document queue: check expirations and generate new documents
        documentQueue.checkExpiredDocuments(game: game)
        documentQueue.generateDocumentsForTurn(game: game)

        // Economy: calculate and apply turn economy (skip turn 1 - player hasn't ended turn yet)
        if newValue > 1 {
            let economicReport = EconomyService.shared.calculateTurnEconomy(game: game)
            EconomyService.shared.applyEconomicReport(economicReport, to: game)
        }

        if newValue != previousTurn && newValue > 1 {
            previousTurn = newValue
            isTransitioning = true
        }

        startBackgroundLoading()
    }

    private func handleOnAppear() {
        previousTurn = game.turnNumber

        if hasDisplayedContentForTurn {
            return
        }

        if loadingState.hasCachedContent(for: game.turnNumber) {
            applyCachedContent()
        } else if !loadingState.isLoading {
            if game.turnNumber > 1 {
                isTransitioning = true
            }
            startBackgroundLoading()
        } else if loadingState.isLoading && game.turnNumber > 1 {
            isTransitioning = true
        }
    }

    // MARK: - Event Handlers

    private func handleDocumentDecision(document: DeskDocument, option: DocumentOption) {
        // Apply the decision to the document
        _ = documentQueue.selectOption(document: document, optionId: option.id, game: game)

        // Apply stat effects
        for (key, value) in option.effects {
            game.applyStat(key, change: value)
        }

        // Handle flags
        if let flag = option.setsFlag, !game.flags.contains(flag) {
            game.flags.append(flag)
        }
        if let flag = option.removesFlag {
            game.flags.removeAll { $0 == flag }
        }

        // Record in game events
        let gameEvent = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .decision,
            summary: "Document: \(option.shortDescription)"
        )
        gameEvent.decisionContext = document.bodyText
        gameEvent.optionChosen = option.shortDescription
        gameEvent.presenterName = document.sender
        gameEvent.presenterTitle = document.senderTitle
        gameEvent.game = game
        game.events.append(gameEvent)

        // Handle character reaction if present
        if let reaction = option.characterReaction {
            handleCharacterReaction(reaction: reaction, document: document)
        }

        // Trigger follow-up document if specified
        if let triggerId = option.triggersDocument {
            // Queue a follow-up document for next turn
            if !game.flags.contains("pending_doc_\(triggerId)") {
                game.flags.append("pending_doc_\(triggerId)")
            }
        }

        // Close the detail view
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showDocumentDetail = false
            selectedDocument = nil
        }
    }

    private func handleCharacterReaction(reaction: CharacterReactionInfo, document: DeskDocument) {
        // Find the character
        if let character = game.characters.first(where: { $0.name == reaction.characterName }) {
            // Apply disposition change
            character.disposition = max(-100, min(100, character.disposition + reaction.dispositionChange))

            // Record the interaction
            character.recordInteraction(
                turn: game.turnNumber,
                scenario: document.bodyText,
                choice: document.chosenOptionId ?? "unknown",
                outcome: reaction.dispositionChange > 0 ? "positive" : (reaction.dispositionChange < 0 ? "negative" : "neutral"),
                dispositionChange: reaction.dispositionChange
            )

            // Show reaction text if immediate
            if !reaction.delayed, let reactionText = reaction.reactionText {
                // Create a dynamic event for the reaction
                let reactionEvent = DynamicEvent(
                    eventType: .characterMessage,
                    priority: .normal,
                    title: "\(reaction.characterName) Responds",
                    briefText: reactionText,
                    initiatingCharacterName: reaction.characterName,
                    turnGenerated: game.turnNumber,
                    isUrgent: false
                )
                game.queueDynamicEvent(reactionEvent)
            }
        }
    }

    private func handleDynamicEventDismissed(_ response: EventResponse?) {
        guard let event = currentDynamicEvent else { return }

        if let response = response {
            // Handle position offer responses specially
            if event.eventType == .patronDirective {
                handlePositionOfferResponse(response: response, event: event)
            }

            for (key, value) in response.effects {
                game.applyStat(key, change: value)
            }

            if let flag = response.setsFlag {
                if !game.flags.contains(flag) {
                    game.flags.append(flag)
                }
            }
            if let flag = response.removesFlag {
                game.flags.removeAll { $0 == flag }
            }

            if response.id == "note" || response.id == "acknowledge" ||
               response.text.lowercased().contains("note") ||
               response.text.lowercased().contains("file") {
                saveEventToJournal(event)
            }
        }

        if let callbackFlag = event.callbackFlag, !game.flags.contains(callbackFlag) {
            game.flags.append(callbackFlag)
        }

        let gameEvent = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .narrative,
            summary: "Event: \(event.title)"
        )
        gameEvent.game = game
        game.events.append(gameEvent)

        game.lastDynamicEventTurn = game.turnNumber

        var cooldowns = game.dynamicEventCooldowns
        cooldowns[event.eventType.rawValue] = game.turnNumber
        game.dynamicEventCooldowns = cooldowns

        showDynamicEvent = false
        currentDynamicEvent = nil
        loadingState.cachedDynamicEvent = nil

        Task {
            startBackgroundLoading()
        }
    }

    /// Handle position offer event responses (accept/decline/consider)
    private func handlePositionOfferResponse(response: EventResponse, event: DynamicEvent) {
        // Extract offer ID from response ID (format: "accept_OFFERID", "decline_OFFERID", "consider_OFFERID")
        let responseId = response.id

        // Find the matching offer
        guard let offer = game.positionOffers.first(where: { offer in
            responseId == "accept_\(offer.offerId)" ||
            responseId == "decline_\(offer.offerId)" ||
            responseId == "consider_\(offer.offerId)"
        }) else {
            return
        }

        let config = CampaignLoader.shared.getColdWarCampaign()

        if responseId.hasPrefix("accept_") {
            // Accept the position offer
            PositionOfferService.shared.acceptOffer(offer, game: game, config: config)

            // Log the promotion
            let gameEvent = GameEvent(
                turnNumber: game.turnNumber,
                eventType: .promotion,
                summary: "Accepted position as \(offer.positionName)"
            )
            gameEvent.importance = 8
            gameEvent.game = game
            game.events.append(gameEvent)

            // Notify
            NotificationService.shared.notifyPromotionAvailable(
                positionName: offer.positionName,
                turn: game.turnNumber
            )

        } else if responseId.hasPrefix("decline_") {
            // Decline the position offer
            PositionOfferService.shared.declineOffer(offer, game: game)

            // Log the decline
            let gameEvent = GameEvent(
                turnNumber: game.turnNumber,
                eventType: .narrative,
                summary: "Declined position as \(offer.positionName)"
            )
            gameEvent.importance = 5
            gameEvent.game = game
            game.events.append(gameEvent)

        } else if responseId.hasPrefix("consider_") {
            // Request more time
            PositionOfferService.shared.requestTimeForOffer(offer, game: game)
        }
    }

    private func saveEventToJournal(_ event: DynamicEvent) {
        let category: JournalCategory = {
            switch event.eventType {
            case .characterMessage, .characterSummons:
                return .personalityReveal
            case .allyRequest, .rivalAction:
                return .relationshipChange
            case .patronDirective:
                return .plotDevelopment
            case .networkIntel:
                return .secretIntelligence
            case .worldNews, .ambientTension:
                return .factionDiscovery
            case .consequenceCallback:
                return .plotDevelopment
            case .urgentInterruption:
                return .plotDevelopment
            }
        }()

        let importance: Int = {
            switch event.priority {
            case .background: return 3
            case .normal: return 5
            case .elevated: return 6
            case .urgent: return 7
            case .critical: return 9
            }
        }()

        JournalService.shared.addEntry(
            to: game,
            category: category,
            title: event.title,
            content: event.briefText + (event.detailedText.map { "\n\n\($0)" } ?? ""),
            relatedCharacterId: event.initiatingCharacterId?.uuidString,
            importance: importance
        )

        NotificationService.shared.notify(
            .newJournalEntry,
            title: "Note Saved",
            detail: event.title,
            turn: game.turnNumber
        )
    }

    private func handleScenarioLoaded(_ scenario: Scenario) {
        if scenario.format == .newspaper {
            let newspaper = NewspaperGenerator.shared.generateNewspaper(for: game)
            currentNewspaper = newspaper

            if SamizdatGenerator.shared.isSamizdatAvailable(for: game) {
                currentSamizdat = SamizdatGenerator.shared.generateSamizdat(for: game)
            } else {
                currentSamizdat = nil
            }

            currentScenario = nil
        } else {
            currentScenario = scenario
            currentNewspaper = nil
            currentSamizdat = nil
        }
        isAIGenerated = loadingState.isAIGenerated
        isTransitioning = false

        // Start pre-generating next turn's scenario while user reads current content
        // This runs silently in background so next turn loads instantly
        ScenarioManager.shared.preGenerateForNextTurn(game: game, config: campaignConfig)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showContent = true
            }
        }
    }

    private func confirmDecision() {
        guard let optionId = selectedOptionId,
              let scenario = currentScenario,
              let option = scenario.options.first(where: { $0.id == optionId }) else {
            return
        }

        let outcomeData = OutcomeData.create(
            from: option,
            game: game,
            scenarioId: scenario.templateId
        )

        for (key, value) in option.statEffects {
            game.applyStat(key, change: value)
        }

        if let personalEffects = option.personalEffects {
            for (key, value) in personalEffects {
                game.applyStat(key, change: value)
            }
        }

        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .decision,
            summary: "Chose: \(option.shortDescription)"
        )
        event.decisionContext = scenario.briefing
        event.optionChosen = option.shortDescription
        event.optionArchetype = option.archetype.displayName
        event.fullBriefing = scenario.briefing
        event.presenterName = scenario.presenterName
        event.presenterTitle = scenario.presenterTitle
        event.wasAIGenerated = isAIGenerated

        let optionSummaries = scenario.options.map { opt in
            OptionSummary(
                id: opt.id,
                shortDescription: opt.shortDescription,
                archetype: opt.archetype.rawValue,
                wasChosen: opt.id == optionId
            )
        }
        event.setAllOptions(optionSummaries)

        if let metadata = ScenarioManager.shared.lastNarrativeMetadata {
            event.narrativeSummary = metadata.narrativeSummary
            event.charactersInvolved = metadata.charactersInvolved
            event.narrativeWeight = metadata.suggestedCallbackTurn != nil ? 7 : 5

            let newCharacters = CharacterDiscoveryService.shared.processCharactersFromScenario(
                metadata: metadata,
                presenterName: scenario.presenterName,
                presenterTitle: scenario.presenterTitle,
                briefingText: scenario.briefing,
                game: game,
                turnNumber: game.turnNumber
            )

            for character in newCharacters {
                character.game = game
                game.characters.append(character)

                NotificationService.shared.notifyNewCharacter(
                    name: character.name,
                    title: character.title,
                    turn: game.turnNumber
                )
            }

            CharacterDiscoveryService.shared.updateCharacterAppearances(
                characterNames: metadata.charactersInvolved,
                game: game,
                turnNumber: game.turnNumber
            )

            processCharacterInteractions(
                metadata: metadata,
                option: option,
                scenario: scenario
            )

            if let newThread = metadata.newThread {
                let thread = PlotThread(
                    id: newThread.id,
                    title: newThread.title,
                    summary: newThread.summary,
                    turnIntroduced: game.turnNumber,
                    keyCharacters: metadata.charactersInvolved
                )
                game.updatePlotThread(thread)
                event.plotThreadIds = [newThread.id]

                NotificationService.shared.notifyNewPlotThread(
                    title: newThread.title,
                    turn: game.turnNumber
                )
            }

            if !metadata.continuesThreadIds.isEmpty {
                event.plotThreadIds = metadata.continuesThreadIds
            }

            if let summary = metadata.narrativeSummary {
                game.appendToStorySummary(summary)
            }

            if event.narrativeWeight >= 7 {
                game.addKeyMoment("Turn \(game.turnNumber): \(option.shortDescription)")
            }
        } else if !scenario.isFallback {
            event.narrativeWeight = scenario.category == .crisis ? 7 : 5
        }

        event.game = game
        game.events.append(event)

        game.phase = GamePhase.outcome.rawValue
        selectedOptionId = nil

        ScenarioManager.shared.preGenerateForNextTurn(game: game, config: campaignConfig)
        onDecisionMade(outcomeData)
    }

    private func continueFromNarrativeEvent() {
        guard let scenario = currentScenario else { return }

        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .narrative,
            summary: "Experienced: \(scenario.category.rawValue.capitalized)"
        )
        event.game = game
        game.events.append(event)

        ScenarioManager.shared.preGenerateForNextTurn(game: game, config: campaignConfig)

        game.turnNumber += 1
        game.turnsInCurrentPosition += 1

        currentScenario = nil
        selectedOptionId = nil
    }

    private func continueFromNewspaper() {
        guard let newspaper = currentNewspaper else { return }

        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .newspaper,
            summary: "Read \(newspaper.publicationName): \(newspaper.headline.headline)"
        )
        event.game = game
        game.events.append(event)

        ScenarioManager.shared.preGenerateForNextTurn(game: game, config: campaignConfig)

        game.turnNumber += 1
        game.turnsInCurrentPosition += 1

        currentNewspaper = nil
        currentSamizdat = nil
        currentScenario = nil
        selectedOptionId = nil
    }

    // MARK: - Character Interactions

    private func processCharacterInteractions(
        metadata: ScenarioNarrativeMetadata,
        option: ScenarioOption,
        scenario: Scenario
    ) {
        for name in metadata.charactersInvolved {
            guard let character = CharacterDiscoveryService.shared.findExistingCharacter(
                name: name,
                in: game.characters
            ) else { continue }

            let outcomeEffect = determineOutcomeEffect(option: option, character: character)
            let dispChange = calculateDispositionChange(option: option, character: character)

            character.recordInteraction(
                turn: game.turnNumber,
                scenario: scenario.briefing,
                choice: option.shortDescription,
                outcome: outcomeEffect,
                dispositionChange: dispChange
            )

            character.disposition = max(-100, min(100, character.disposition + dispChange))

            if let statusChange = character.updateRelationshipStatus(currentTurn: game.turnNumber) {
                let relationEvent = GameEvent(
                    turnNumber: game.turnNumber,
                    eventType: .narrative,
                    summary: statusChange
                )
                relationEvent.importance = 6
                relationEvent.game = game
                game.events.append(relationEvent)
            }

            if character.checkPersonalityReveal(networkStat: game.network, currentTurn: game.turnNumber) {
                let revealEvent = GameEvent(
                    turnNumber: game.turnNumber,
                    eventType: .narrative,
                    summary: "You now understand \(character.name)'s true nature"
                )
                revealEvent.importance = 4
                revealEvent.game = game
                game.events.append(revealEvent)
            }
        }
    }

    private func determineOutcomeEffect(option: ScenarioOption, character: GameCharacter) -> String {
        switch option.archetype {
        case .repress, .attack, .investigate, .surveil, .military, .mobilize:
            return character.isRival ? "positive" : "negative"
        case .reform, .appease, .production, .allocate:
            return "positive"
        case .negotiate, .international, .trade:
            return character.disposition > 50 ? "positive" : "neutral"
        case .deflect, .delay, .administrative, .governance, .regulate:
            return "neutral"
        case .sacrifice, .loyalty, .ideological, .personnel, .orthodox:
            return "negative"
        }
    }

    private func calculateDispositionChange(option: ScenarioOption, character: GameCharacter) -> Int {
        var change = 0

        switch option.archetype {
        case .repress, .attack, .investigate, .surveil, .military, .mobilize:
            change = character.isRival ? 0 : -8
        case .reform, .appease, .production, .allocate:
            change = 5
        case .negotiate, .international, .trade:
            change = 3
        case .deflect, .administrative, .governance:
            change = -2
        case .delay, .regulate:
            change = -1
        case .sacrifice, .loyalty, .ideological, .personnel, .orthodox:
            change = -5
        }

        if character.isPatron, let effects = option.personalEffects {
            if let favorChange = effects["patronFavor"] {
                change = favorChange / 2
            }
        }
        if character.isRival, let effects = option.personalEffects {
            if let threatChange = effects["rivalThreat"] {
                change = -threatChange / 3
            }
        }

        return change
    }
}

// MARK: - Confirm Decision Button (kept for compatibility)

struct ConfirmDecisionButton: View {
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            Text("CONFIRM DECISION")
                .font(theme.labelFont)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundColor(theme.parchmentDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.stampRed)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    container.mainContext.insert(game)

    return DeskView(game: game) { outcome in
        print("Decision made: \(outcome.outcomeText)")
    }
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}

// MARK: - Seeded Random Number Generator

/// A deterministic random number generator for consistent Canvas rendering
/// Prevents texture flickering by producing the same sequence for a given seed
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64 algorithm - fast and produces good distribution
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
