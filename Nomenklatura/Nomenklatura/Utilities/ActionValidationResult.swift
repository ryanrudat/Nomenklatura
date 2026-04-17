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

    init(
        canExecute: Bool,
        reason: String? = nil,
        successChance: Int = 0,
        requiresApproval: Bool = false,
        treasuryCost: Int = 0,
        targetTooSenior: Bool = false
    ) {
        self.canExecute = canExecute
        self.reason = reason
        self.successChance = successChance
        self.requiresApproval = requiresApproval
        self.treasuryCost = treasuryCost
        self.targetTooSenior = targetTooSenior
    }

    static func success(chance: Int) -> ActionValidationResult {
        ActionValidationResult(canExecute: true, successChance: chance)
    }

    static func failure(_ reason: String) -> ActionValidationResult {
        ActionValidationResult(canExecute: false, reason: reason)
    }
}
