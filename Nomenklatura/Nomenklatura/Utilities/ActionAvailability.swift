//
//  ActionAvailability.swift
//  Nomenklatura
//
//  Unified availability check for new Phase 3-4 mechanics. Combines position,
//  law, stat, and cooldown gates into one result with a user-facing reason
//  string so locked actions can render a "REQUIRES X" stamp instead of a
//  silent disable.
//
//  Usage example:
//      let availability = ActionAvailability.evaluate(
//          positionRequirement: 7,
//          lawRequirements: [.liberalizedTrade],
//          statRequirements: [(stat: "Standing", value: 50, current: game.standing)],
//          in: game
//      )
//      if !availability.isAvailable {
//          showLockStamp(reason: availability.reason ?? "Locked")
//      }
//

import Foundation

struct ActionAvailability {
    let isAvailable: Bool
    let reason: String?
    let lockedBy: LockReason?

    static let available = ActionAvailability(isAvailable: true, reason: nil, lockedBy: nil)

    static func evaluate(
        positionRequirement: Int? = nil,
        lawRequirements: [LawGate] = [],
        statRequirements: [(stat: String, value: Int, current: Int)] = [],
        cooldownTurnsRemaining: Int = 0,
        in game: Game
    ) -> ActionAvailability {
        if cooldownTurnsRemaining > 0 {
            return ActionAvailability(
                isAvailable: false,
                reason: "On cooldown (\(cooldownTurnsRemaining) turns remaining)",
                lockedBy: .cooldownActive(turnsRemaining: cooldownTurnsRemaining)
            )
        }

        if let required = positionRequirement, game.currentPositionIndex < required {
            return ActionAvailability(
                isAvailable: false,
                reason: "Requires Position \(required) (you are \(game.currentPositionIndex))",
                lockedBy: .positionTooLow(required: required, current: game.currentPositionIndex)
            )
        }

        for gate in lawRequirements where !LawGate.isActive(gate, in: game) {
            return ActionAvailability(
                isAvailable: false,
                reason: "Requires: \(gate.displayName)",
                lockedBy: .lawNotPassed(gate)
            )
        }

        for requirement in statRequirements where requirement.current < requirement.value {
            return ActionAvailability(
                isAvailable: false,
                reason: "Requires \(requirement.stat) \(requirement.value) (you have \(requirement.current))",
                lockedBy: .statTooLow(stat: requirement.stat, required: requirement.value)
            )
        }

        return .available
    }
}

enum LockReason {
    case positionTooLow(required: Int, current: Int)
    case lawNotPassed(LawGate)
    case statTooLow(stat: String, required: Int)
    case cooldownActive(turnsRemaining: Int)
    case other(String)
}
