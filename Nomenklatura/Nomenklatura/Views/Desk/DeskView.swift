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

    @State var selectedOptionId: String?
    @State var currentScenario: Scenario?
    @State var currentNewspaper: NewspaperEdition?
    @State var currentSamizdat: NewspaperEdition?
    @State var currentDynamicEvent: DynamicEvent?
    @State var isAIGenerated = false
    @Environment(\.theme) var theme
    @Environment(\.modelContext) var modelContext

    // View state
    @State var showContent = false
    @State var showDynamicEvent = false
    @State var isTransitioning = false
    @State var previousTurn = 0
    @State var hasDisplayedContentForTurn = false
    @State var showMemoPanel = false
    @State var showFullNewspaper = false  // Expand newspaper from preview
    @State var showFullScenario = false   // Expand scenario from card
    @State var scenarioOverlayOffset: CGFloat = 0  // For pull-to-dismiss
    @State var lastDisplayedScenarioId: String? = nil  // Track to prevent consecutive duplicates
    @State var lastDisplayedScenarioFingerprint: String? = nil
    @State var duplicateScenarioRetryCount = 0

    // Document queue system
    @State var selectedDocument: DeskDocument?
    @State var showDocumentDetail = false
    @ObservedObject var documentQueue = DocumentQueueService.shared

    // End turn confirmation
    @State var showEndTurnConfirmation = false

    // Loading snapshot cycling
    @State var currentSnapshotIndex = 0
    @State var snapshotOpacity: Double = 1.0
    let snapshotImages = ["snapshot_1", "snapshot_2", "snapshot_3", "snapshot_4", "snapshot_5", "snapshot_6", "snapshot_7", "snapshot_8", "snapshot_9", "snapshot_10"]
    let snapshotTimer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    // Observe the shared loading state
    @ObservedObject var loadingState = ScenarioManager.shared.loadingState

    var campaignConfig: CampaignConfig {
        CampaignLoader.shared.getColdWarCampaign()
    }

    let dynamicEventOnboardingStartTurn = 4

    /// Computed property to check if loading section should be visible
    /// Used by both the view display and the snapshot timer
    var isLoadingSectionVisible: Bool {
        // Loading section shows when transitioning or loading
        if isTransitioning || loadingState.isLoading {
            return true
        }
        // Also shows as fallback when no content and no documents
        let visibleDocuments = documentQueue.getVisibleDocuments(for: game)
        if currentNewspaper == nil && currentScenario == nil && visibleDocuments.isEmpty {
            return true
        }
        return false
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
                            // Bureau Credential Badge (shown when committed to a core bureau)
                            BureauCredentialBadge(game: game)
                                .padding(.horizontal, 4)

                            // Player ID Card
                            PlayerIDCard(
                                playerName: playerTitle,
                                title: positionTitle,
                                clearanceLevel: clearanceLevel
                            )
                            .id("idCard")

                            // Personal Stats Widget with Sparklines - each stat navigates to relevant screen
                            SparklinePersonalStatsRow(
                                standing: game.standing,
                                network: game.network,
                                patronFavor: game.patronFavor,
                                rivalThreat: game.rivalThreat,
                                standingHistory: game.standingHistory,
                                networkHistory: game.networkHistory,
                                patronFavorHistory: game.patronFavorHistory,
                                rivalThreatHistory: game.rivalThreatHistory,
                                onStandingTap: onLadderTap,
                                onNetworkTap: onDossierTap,
                                onPatronTap: openPatronSheet,
                                onRivalTap: openRivalSheet
                            )

                            // Threat Assessment Dashboard
                            ThreatDashboardView(game: game)

                            if let report = latestEconomicReport {
                                treasuryBriefingSection(report: report)
                            }

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

    var formattedDate: String {
        RevolutionaryCalendar.formatTurnWithMonth(game.turnNumber)
    }

    var playerTitle: String {
        "Comrade Director"
    }

    var positionTitle: String {
        let config = CampaignLoader.shared.getColdWarCampaign()
        return config.ladder.first(where: { $0.index == game.currentPositionIndex })?.title ?? "Party Official"
    }

    var clearanceLevel: Int {
        min(game.currentPositionIndex + 1, 8)
    }

    var hasNotifications: Bool {
        game.unreadJournalCount > 0 || currentDynamicEvent != nil
    }

    var latestEconomicReport: EconomyService.EconomicReport? {
        guard let data = game.lastEconomicReport else { return nil }
        return EconomyService.shared.decodeReport(data)
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
