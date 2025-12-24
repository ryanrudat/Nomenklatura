//
//  OutcomeData.swift
//  Nomenklatura
//
//  Model for passing outcome data between views
//

import Foundation

struct OutcomeData {
    let outcomeText: String
    let statChanges: [StatChange]
    let optionChosen: ScenarioOption
    let scenarioId: String

    init(
        outcomeText: String,
        statChanges: [StatChange],
        optionChosen: ScenarioOption,
        scenarioId: String
    ) {
        self.outcomeText = outcomeText
        self.statChanges = statChanges
        self.optionChosen = optionChosen
        self.scenarioId = scenarioId
    }

    /// Create outcome data by comparing game state before and after applying effects
    static func create(
        from option: ScenarioOption,
        game: Game,
        scenarioId: String
    ) -> OutcomeData {
        var changes: [StatChange] = []

        let statNames: [String: (name: String, isPersonal: Bool)] = [
            "stability": ("Stability", false),
            "popularSupport": ("Popular Support", false),
            "militaryLoyalty": ("Military Loyalty", false),
            "eliteLoyalty": ("Elite Loyalty", false),
            "treasury": ("Treasury", false),
            "industrialOutput": ("Industrial Output", false),
            "foodSupply": ("Food Supply", false),
            "internationalStanding": ("International Standing", false),
            "standing": ("Standing", true),
            "patronFavor": ("Patron Favor", true),
            "rivalThreat": ("Rival Threat", true),
            "network": ("Network", true),
            "reputationCompetent": ("Competent", true),
            "reputationLoyal": ("Loyal", true),
            "reputationCunning": ("Cunning", true),
            "reputationRuthless": ("Ruthless", true)
        ]

        // Capture current values before changes
        let oldValues: [String: Int] = [
            "stability": game.stability,
            "popularSupport": game.popularSupport,
            "militaryLoyalty": game.militaryLoyalty,
            "eliteLoyalty": game.eliteLoyalty,
            "treasury": game.treasury,
            "industrialOutput": game.industrialOutput,
            "foodSupply": game.foodSupply,
            "internationalStanding": game.internationalStanding,
            "standing": game.standing,
            "patronFavor": game.patronFavor,
            "rivalThreat": game.rivalThreat,
            "network": game.network,
            "reputationCompetent": game.reputationCompetent,
            "reputationLoyal": game.reputationLoyal,
            "reputationCunning": game.reputationCunning,
            "reputationRuthless": game.reputationRuthless
        ]

        // Process national stat effects
        for (key, delta) in option.statEffects {
            if let info = statNames[key], let oldValue = oldValues[key] {
                let newValue = max(0, min(100, oldValue + delta))
                changes.append(StatChange(
                    statKey: key,
                    statName: info.name,
                    oldValue: oldValue,
                    newValue: newValue,
                    isPersonal: info.isPersonal
                ))
            }
        }

        // Process personal stat effects
        if let personalEffects = option.personalEffects {
            for (key, delta) in personalEffects {
                if let info = statNames[key], let oldValue = oldValues[key] {
                    let newValue = max(0, min(100, oldValue + delta))
                    changes.append(StatChange(
                        statKey: key,
                        statName: info.name,
                        oldValue: oldValue,
                        newValue: newValue,
                        isPersonal: info.isPersonal
                    ))
                }
            }
        }

        // Sort: national first, then personal
        changes.sort { !$0.isPersonal && $1.isPersonal }

        return OutcomeData(
            outcomeText: option.immediateOutcome,
            statChanges: changes,
            optionChosen: option,
            scenarioId: scenarioId
        )
    }
}
