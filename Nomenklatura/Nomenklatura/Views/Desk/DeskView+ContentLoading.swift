//
//  DeskView+ContentLoading.swift
//  Nomenklatura
//
//  Background loading, cached content, dynamic event checks, dedup
//

import SwiftUI

extension DeskView {

    // MARK: - Background Loading

    func startBackgroundLoading() {
        guard currentScenario == nil && currentNewspaper == nil && currentDynamicEvent == nil else { return }

        ScenarioManager.shared.startBackgroundLoading(
            for: game,
            config: campaignConfig,
            checkDynamicEvents: { [self] in
                return self.checkForDynamicEventsSync()
            }
        )
    }

    func applyCachedContent() {
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
            let fingerprint = scenarioDeduplicationKey(for: scenario)
            let isDuplicate = scenario.templateId == lastDisplayedScenarioId ||
                fingerprint == lastDisplayedScenarioFingerprint

            // DEDUPLICATION: Retry generation once before accepting a duplicate.
            if isDuplicate && duplicateScenarioRetryCount < 1 {
                #if DEBUG
                print("[DeskView] Skipping duplicate scenario: \(scenario.templateId)")
                #endif

                duplicateScenarioRetryCount += 1
                loadingState.cachedScenario = nil
                isTransitioning = true
                startBackgroundLoading()
                return
            }

            duplicateScenarioRetryCount = 0
            lastDisplayedScenarioId = scenario.templateId
            lastDisplayedScenarioFingerprint = fingerprint
            hasDisplayedContentForTurn = true
            handleScenarioLoaded(scenario)
            return
        }

        // No content was cached - clear transitioning state so END TURN button can appear
        // This happens when content generation fails or produces nothing
        isTransitioning = false
        hasDisplayedContentForTurn = true
    }

    func checkForDynamicEventsSync() -> DynamicEvent? {
        guard game.turnNumber > 1 else { return nil }

        // Onboarding window: keep early turns focused on desk/scenario fundamentals.
        if game.turnNumber < dynamicEventOnboardingStartTurn {
            game.pendingDynamicEvents = []
            game.resetEventPacing()
            return nil
        }

        // Hard cap: at most one dynamic interruption per turn.
        if game.lastDynamicEventTurn == game.turnNumber {
            return nil
        }

        if game.shouldForceQuietTurn {
            game.resetEventPacing()
            return nil
        }

        // Always surface queued events first (project completions, reactions, crises).
        if let queuedEvent = game.popNextDynamicEvent() {
            return queuedEvent
        }

        if let event = DynamicEventTriggerService.shared.evaluateTriggers(game: game, phase: .briefing) {
            game.queueDynamicEvent(event)
            return game.popNextDynamicEvent()
        }

        if let characterEvent = CharacterAgencyService.shared.evaluateCharacterActions(game: game) {
            game.queueDynamicEvent(characterEvent)
            return game.popNextDynamicEvent()
        }

        let goalEvents = GoalDrivenAgencyService.shared.evaluateGoalDrivenActions(game: game)
        if let firstGoalEvent = goalEvents.first {
            game.queueDynamicEvent(firstGoalEvent)
            return game.popNextDynamicEvent()
        }

        let memoryEvents = MemoryIntegrationService.shared.evaluateMemoryDrivenActions(game: game)
        if let memoryEvent = memoryEvents.first {
            game.queueDynamicEvent(memoryEvent)
            return game.popNextDynamicEvent()
        }

        // Quiet turn: clear streak so "consecutive events" stays true to name.
        game.resetEventPacing()
        return nil
    }

    func scenarioDeduplicationKey(for scenario: Scenario) -> String {
        let normalizedBriefing = scenario.briefing
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(28)
            .joined(separator: " ")
        return "\(scenario.category.rawValue)|\(scenario.presenterName.lowercased())|\(normalizedBriefing)"
    }
}
