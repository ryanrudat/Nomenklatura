//
//  PersonalAction.swift
//  Nomenklatura
//
//  Personal action models for the "work the system" phase
//

import Foundation

// MARK: - Personal Action

struct PersonalAction: Codable, Identifiable {
    var id: String
    var category: PersonalActionCategory
    var title: String
    var description: String
    var costAP: Int
    var riskLevel: RiskLevel

    var requirements: ActionRequirements?
    var effects: [String: Int]

    var isLocked: Bool
    var lockReason: String?

    // Narrative flavor text for immersion
    var flavorText: String?           // Atmospheric description shown on card
    var actionNarrative: String?      // What happens when you perform this action
    var successNarratives: [String]?  // Pool of success outcome texts
    var failureNarratives: [String]?  // Pool of discovery/failure texts

    /// Check if this action is available given current game state
    func isAvailable(game: Game) -> (available: Bool, reason: String?) {
        guard let reqs = requirements else {
            return (true, nil)
        }

        if let minStanding = reqs.minStanding, game.standing < minStanding {
            return (false, "Requires Standing \(minStanding)+")
        }

        if let minPatronFavor = reqs.minPatronFavor, game.patronFavor < minPatronFavor {
            return (false, "Requires Patron Favor \(minPatronFavor)+")
        }

        if let minNetwork = reqs.minNetwork, game.network < minNetwork {
            return (false, "Requires Network \(minNetwork)+")
        }

        if let minPosition = reqs.minPositionIndex, game.currentPositionIndex < minPosition {
            return (false, "Requires higher position")
        }

        if let maxSuccessors = reqs.maxSuccessorCount {
            let activeSuccessors = game.successorRelationships.filter { $0.isActive }.count
            if activeSuccessors >= maxSuccessors {
                return (false, "Maximum successors reached")
            }
        }

        if reqs.requiresActiveSuccessor == true {
            let hasActiveSuccessor = game.successorRelationships.contains { $0.isActive }
            if !hasActiveSuccessor {
                return (false, "Requires an active protege")
            }
        }

        if let requiredFlags = reqs.requiredFlags {
            for flag in requiredFlags {
                if !game.flags.contains(flag) {
                    return (false, "Missing requirement")
                }
            }
        }

        if let forbiddenFlags = reqs.forbiddenFlags {
            for flag in forbiddenFlags {
                if game.flags.contains(flag) {
                    return (false, "Cannot perform this action")
                }
            }
        }

        if reqs.vacancyRequired == true {
            // Would need to check ladder positions
            // For now, return locked
            return (false, "Requires a vacancy above you")
        }

        return (true, nil)
    }
}

// MARK: - Personal Action Category

enum PersonalActionCategory: String, Codable, CaseIterable {
    case buildNetwork
    case undermineRivals
    case securePosition
    case makeYourPlay
    case cultivateSuccessor     // Heir cultivation actions

    var displayName: String {
        switch self {
        case .buildNetwork: return "BUILD NETWORK"
        case .undermineRivals: return "UNDERMINE RIVALS"
        case .securePosition: return "SECURE POSITION"
        case .makeYourPlay: return "MAKE YOUR PLAY"
        case .cultivateSuccessor: return "CULTIVATE SUCCESSOR"
        }
    }

    var order: Int {
        switch self {
        case .buildNetwork: return 0
        case .undermineRivals: return 1
        case .securePosition: return 2
        case .cultivateSuccessor: return 3
        case .makeYourPlay: return 4
        }
    }
}

// MARK: - Risk Level

enum RiskLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var color: String {
        switch self {
        case .low: return "statHigh"  // Green
        case .medium: return "statMedium"  // Yellow
        case .high: return "statLow"  // Red
        }
    }
}

// MARK: - Action Requirements

struct ActionRequirements: Codable {
    var minStanding: Int?
    var minPatronFavor: Int?
    var minNetwork: Int?
    var minPositionIndex: Int?         // Minimum position on ladder
    var maxSuccessorCount: Int?        // Maximum existing successors
    var requiresActiveSuccessor: Bool? // Must have at least one heir
    var requiredFlags: [String]?
    var forbiddenFlags: [String]?
    var vacancyRequired: Bool?
    var requiredFactionSupport: [String: Int]?
}

// MARK: - Action Result

struct ActionResult {
    var success: Bool
    var outcomeText: String
    var statChanges: [String: Int]
    var wasDiscovered: Bool
    var discoveredBy: String?
    var newFlags: [String]
    var removedFlags: [String]

    init(
        success: Bool,
        outcomeText: String,
        statChanges: [String: Int] = [:],
        wasDiscovered: Bool = false,
        discoveredBy: String? = nil,
        newFlags: [String] = [],
        removedFlags: [String] = []
    ) {
        self.success = success
        self.outcomeText = outcomeText
        self.statChanges = statChanges
        self.wasDiscovered = wasDiscovered
        self.discoveredBy = discoveredBy
        self.newFlags = newFlags
        self.removedFlags = removedFlags
    }
}
