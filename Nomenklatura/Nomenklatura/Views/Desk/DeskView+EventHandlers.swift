//
//  DeskView+EventHandlers.swift
//  Nomenklatura
//
//  Document decisions, character reactions, dynamic events, journal
//

import SwiftUI

extension DeskView {

    // MARK: - Event Handlers

    func handleDocumentDecision(document: DeskDocument, option: DocumentOption) {
        // Apply the decision using Codex-aware version that schedules character reactions
        // This handles: stat effects, flags, events, character reactions, follow-up triggers, AND Codex messages
        _ = documentQueue.selectOptionWithCodexReaction(
            document: document,
            optionId: option.id,
            game: game,
            context: modelContext
        )

        // Handle immediate character reaction UI if present (for dynamic events)
        if let reaction = option.characterReaction {
            handleCharacterReaction(reaction: reaction, document: document)
        }

        // Close the detail view
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showDocumentDetail = false
            selectedDocument = nil
        }
    }

    func handleCharacterReaction(reaction: CharacterReactionInfo, document: DeskDocument) {
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

    func handleDynamicEventDismissed(_ response: EventResponse?) {
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
    func handlePositionOfferResponse(response: EventResponse, event: DynamicEvent) {
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

    func saveEventToJournal(_ event: DynamicEvent) {
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
            case .institutionalChange:
                return .factionDiscovery
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
}
