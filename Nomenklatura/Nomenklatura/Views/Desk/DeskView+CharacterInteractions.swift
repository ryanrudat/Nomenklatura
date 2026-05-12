//
//  DeskView+CharacterInteractions.swift
//  Nomenklatura
//
//  Character disposition and interaction processing
//

import SwiftUI

extension DeskView {

    // MARK: - Character Interactions

    func processCharacterInteractions(
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

            if let statusChange = character.updateRelationshipStatus(currentTurn: game.turnNumber, game: game) {
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

    func determineOutcomeEffect(option: ScenarioOption, character: GameCharacter) -> String {
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

    func calculateDispositionChange(option: ScenarioOption, character: GameCharacter) -> Int {
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
