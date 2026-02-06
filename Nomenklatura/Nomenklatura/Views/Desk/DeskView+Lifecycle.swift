//
//  DeskView+Lifecycle.swift
//  Nomenklatura
//
//  View lifecycle handlers: turn changes and onAppear
//

import SwiftUI

extension DeskView {

    // MARK: - View Lifecycle

    func handleTurnChange(_ newValue: Int) {
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
        duplicateScenarioRetryCount = 0

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

        if newValue != previousTurn && newValue > 1 {
            previousTurn = newValue
            isTransitioning = true
        }

        startBackgroundLoading()
    }

    func handleOnAppear() {
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
}
