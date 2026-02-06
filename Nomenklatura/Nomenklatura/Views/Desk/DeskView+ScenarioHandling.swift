//
//  DeskView+ScenarioHandling.swift
//  Nomenklatura
//
//  Scenario loaded, confirmDecision, continue from narrative/newspaper
//

import SwiftUI

extension DeskView {

    // MARK: - Scenario Handling

    func handleScenarioLoaded(_ scenario: Scenario) {
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

    func confirmDecision() {
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

    func continueFromNarrativeEvent() {
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

    func continueFromNewspaper() {
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
}
