//
//  ActionValidationResult.swift
//  Nomenklatura
//

import Foundation

struct ActionValidationResult {
    let canExecute: Bool
    let reason: String?
    let successChance: Int
    let requiresApproval: Bool
    let treasuryCost: Int
    let targetTooSenior: Bool
    let viaDecree: Bool

    init(
        canExecute: Bool,
        reason: String? = nil,
        successChance: Int = 0,
        requiresApproval: Bool = false,
        treasuryCost: Int = 0,
        targetTooSenior: Bool = false,
        viaDecree: Bool = false
    ) {
        self.canExecute = canExecute
        self.reason = reason
        self.successChance = successChance
        self.requiresApproval = requiresApproval
        self.treasuryCost = treasuryCost
        self.targetTooSenior = targetTooSenior
        self.viaDecree = viaDecree
    }

    static func success(chance: Int) -> ActionValidationResult {
        ActionValidationResult(canExecute: true, successChance: chance)
    }

    static func failure(_ reason: String) -> ActionValidationResult {
        ActionValidationResult(canExecute: false, reason: reason)
    }
}

// MARK: - Committee oversight cost

extension Game {
    /// Political price of executing a Standing-Committee-flagged action
    /// without convening the committee (and without a decree). The committee
    /// resents being bypassed — scaled by how consolidated the Chairman is.
    /// At Supreme tier the committee is ceremonial and the cost vanishes;
    /// at The Core it grumbles quietly; below that, every unilateral move
    /// feeds the resentment that drives the strongman-fragility loop.
    /// Returns the applied stat deltas for callers that surface them.
    @discardableResult
    func applyCommitteeBypassCost(actionTitle: String) -> [String: Int] {
        let eliteCost: Int
        let resentment: Int
        switch chairmanshipTier {
        case .supremeChairman:
            return [:]   // the committee ratifies whatever you decide
        case .theCore:
            eliteCost = -1
            resentment = 1
        default:
            eliteCost = -3
            resentment = 2
        }

        applyStat("eliteLoyalty", change: eliteCost)
        setIntVariable("elite_resentment", min(100, intVariable("elite_resentment") + resentment))

        let event = GameEvent(
            turnNumber: turnNumber,
            eventType: .decision,
            summary: "\(actionTitle): executed without Standing Committee approval. The committee notes it was not consulted."
        )
        event.importance = 4
        event.game = self
        events.append(event)

        return ["eliteLoyalty": eliteCost]
    }
}
