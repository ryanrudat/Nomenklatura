//
//  UrgencyAdvisor.swift
//  Nomenklatura
//
//  Analyzes game state to detect active crises and flag actions/directives
//  that address them. Helps the General Secretary triage 200+ options quickly.
//

import Foundation

// MARK: - Crisis

struct Crisis: Identifiable {
    let id: String
    let label: String           // Short display label e.g. "LOW STABILITY"
    let relevantStats: Set<String>  // Effect keys that address this crisis
    let relevantCategories: Set<PersonalActionCategory>
    let relevantBureaus: Set<String>  // ExpandedCareerTrack raw values
}

// MARK: - Urgency Advisor

enum UrgencyAdvisor {

    /// Detect all active crises from current game state
    static func detectCrises(game: Game) -> [Crisis] {
        var crises: [Crisis] = []

        // Stability crisis
        if game.stability < 30 {
            crises.append(Crisis(
                id: "low_stability",
                label: "LOW STABILITY",
                relevantStats: ["stability", "popularSupport"],
                relevantCategories: [.controlInformation, .consolidatePower, .securePosition],
                relevantBureaus: ["partyApparatus", "securityServices", "stateMinistry"]
            ))
        }

        // Rival threat crisis
        if game.rivalThreat > 65 {
            crises.append(Crisis(
                id: "high_rival",
                label: "RIVAL THREAT",
                relevantStats: ["rivalThreat", "network"],
                relevantCategories: [.undermineRivals, .purgeEnemies, .securePosition],
                relevantBureaus: ["securityServices"]
            ))
        }

        // Patron favor decay
        if game.patronFavor < 25 {
            crises.append(Crisis(
                id: "low_favor",
                label: "LOW FAVOR",
                relevantStats: ["patronFavor"],
                relevantCategories: [.buildNetwork, .securePosition],
                relevantBureaus: ["partyApparatus"]
            ))
        }

        // Military loyalty crisis
        if game.militaryLoyalty < 30 {
            crises.append(Crisis(
                id: "low_military",
                label: "MILITARY UNREST",
                relevantStats: ["militaryLoyalty"],
                relevantCategories: [.consolidatePower, .purgeEnemies],
                relevantBureaus: ["militaryPolitical"]
            ))
        }

        // Elite loyalty crisis
        if game.eliteLoyalty < 30 {
            crises.append(Crisis(
                id: "low_elite",
                label: "ELITE DISSENT",
                relevantStats: ["eliteLoyalty"],
                relevantCategories: [.buildNetwork, .consolidatePower, .purgeEnemies],
                relevantBureaus: ["partyApparatus", "securityServices"]
            ))
        }

        // Popular support crisis
        if game.popularSupport < 25 {
            crises.append(Crisis(
                id: "low_popular",
                label: "LOW SUPPORT",
                relevantStats: ["popularSupport", "stability"],
                relevantCategories: [.controlInformation, .consolidatePower],
                relevantBureaus: ["partyApparatus", "stateMinistry"]
            ))
        }

        // Standing collapse
        if game.standing < 20 {
            crises.append(Crisis(
                id: "low_standing",
                label: "POSITION AT RISK",
                relevantStats: ["standing"],
                relevantCategories: [.securePosition, .buildNetwork],
                relevantBureaus: ["partyApparatus"]
            ))
        }

        // Treasury crisis
        if game.treasury < 15 {
            crises.append(Crisis(
                id: "low_treasury",
                label: "TREASURY DEPLETED",
                relevantStats: ["treasury"],
                relevantCategories: [.consolidatePower],
                relevantBureaus: ["economicPlanning", "stateMinistry"]
            ))
        }

        // Food supply crisis
        if game.foodSupply < 20 {
            crises.append(Crisis(
                id: "low_food",
                label: "FOOD SHORTAGE",
                relevantStats: ["foodSupply"],
                relevantCategories: [.controlInformation],
                relevantBureaus: ["economicPlanning", "stateMinistry"]
            ))
        }

        return crises
    }

    /// Check if a personal action addresses any active crisis
    static func isUrgent(action: PersonalAction, crises: [Crisis]) -> Crisis? {
        for crisis in crises {
            // Check if the action's effects touch a relevant stat
            for effectKey in action.effects.keys {
                if crisis.relevantStats.contains(effectKey) {
                    return crisis
                }
            }
            // Check if the action's category is relevant
            if crisis.relevantCategories.contains(action.category) {
                return crisis
            }
        }
        return nil
    }

    /// Check if a bureau directive addresses any active crisis
    static func isUrgentDirective(bureauTrack: String, crises: [Crisis]) -> Crisis? {
        for crisis in crises {
            if crisis.relevantBureaus.contains(bureauTrack) {
                return crisis
            }
        }
        return nil
    }

    /// Sort personal action categories so crisis-relevant ones appear first
    static func sortedCategories(
        _ categories: [PersonalActionCategory],
        crises: [Crisis]
    ) -> [PersonalActionCategory] {
        let urgentCategories = Set(crises.flatMap { $0.relevantCategories })
        return categories.sorted { a, b in
            let aUrgent = urgentCategories.contains(a)
            let bUrgent = urgentCategories.contains(b)
            if aUrgent != bUrgent { return aUrgent }
            return a.order < b.order
        }
    }
}
