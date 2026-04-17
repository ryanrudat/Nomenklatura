//
//  DeskView+FullOverlays.swift
//  Nomenklatura
//
//  Full newspaper/scenario/dynamic event overlays, memo panel, decision content
//

import SwiftUI

extension DeskView {

    // MARK: - Full Newspaper Overlay

    @ViewBuilder
    func fullNewspaperOverlay(newspaper: NewspaperEdition) -> some View {
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
    func fullScenarioOverlay(scenario: Scenario) -> some View {
        let dismissThreshold: CGFloat = 150

        ZStack {
            // Background - dims as you pull down
            Color.black.opacity(0.5 * (1 - min(scenarioOverlayOffset / 300, 0.5)))
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow tap to dismiss for all scenarios
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showFullScenario = false
                    }
                }

            VStack(spacing: 0) {
                // Pull indicator at top
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Close button - always visible for dismissal
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
                            // Dismiss - allow for all scenarios (decisions will be handled at end of turn)
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

    // MARK: - Decision Content

    @ViewBuilder
    func decisionContent(scenario: Scenario) -> some View {
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
                    .background(ColdWarTheme.shared.stampRed)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .padding(.top, 15)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Dynamic Event Overlay

    @ViewBuilder
    func dynamicEventOverlay(event: DynamicEvent) -> some View {
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
    var memoSlideOutOverlay: some View {
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
}
