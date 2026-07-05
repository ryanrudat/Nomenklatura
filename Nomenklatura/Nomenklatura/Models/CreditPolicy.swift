//
//  CreditPolicy.swift
//  Nomenklatura
//
//  The Credit Dial — the state banking system's lending stance, and the
//  boom-bust cycle it drives. Loose credit buys growth (and keeps enterprise
//  managers flush) while the OVERHEATING gauge climbs toward a crash; tight
//  credit deflates the bubble at the cost of growth and elite goodwill
//  (their enterprises starve first). The classic growth-model dilemma as a
//  push-your-luck lever: one dial you are always tempted to leave open one
//  turn too long.
//
//  State lives in the variables dictionary (no schema change). Per-turn
//  processing is EconomyService.processCreditCycle.
//

import Foundation

enum CreditStance: String, Codable, CaseIterable {
    case tight
    case neutral
    case loose

    var displayName: String {
        switch self {
        case .tight: return "TIGHTEN"
        case .neutral: return "HOLD"
        case .loose: return "LOOSEN"
        }
    }

    /// Term added inside EconomyService.calculateGDPGrowth.
    var gdpGrowthTerm: Int {
        switch self {
        case .tight: return -1
        case .neutral: return 0
        case .loose: return 3
        }
    }

    /// Term added inside EconomyService.calculateInflationChange.
    var inflationTerm: Int {
        switch self {
        case .tight: return -1
        case .neutral: return 0
        case .loose: return 1
        }
    }

    /// Honest per-turn effect summary shown on the FISCAL card.
    var effectCaption: String {
        switch self {
        case .tight: return "Growth −1 · Inflation −1 · Overheating −6/turn · Elite loyalty −1/turn"
        case .neutral: return "Overheating −2/turn"
        case .loose: return "Growth +3 · Inflation +1 · Overheating rises with market exposure"
        }
    }
}

extension Game {
    /// Turns between allowed stance changes — credit policy is a standing
    /// directive, not a per-turn toggle.
    static let creditStanceCooldown = 3

    var creditStance: CreditStance {
        get {
            guard let raw = variables["credit_stance"],
                  let stance = CreditStance(rawValue: raw) else { return .neutral }
            return stance
        }
        set {
            variables["credit_stance"] = newValue.rawValue
        }
    }

    /// OVERHEATING gauge, 0-100. Crash risk begins above 60.
    var creditBubble: Int {
        get { intVariable("credit_bubble") }
        set { setIntVariable("credit_bubble", max(0, min(100, newValue))) }
    }

    var creditStanceCooldownRemaining: Int {
        let changed = intVariable("credit_stance_changed_turn")
        guard changed > 0 else { return 0 }
        return max(0, Game.creditStanceCooldown - (turnNumber - changed))
    }

    /// Change the lending stance (respecting the cooldown; forced = crash
    /// rectification, which bypasses it).
    func setCreditStance(_ stance: CreditStance, forced: Bool = false) {
        guard forced || creditStanceCooldownRemaining == 0 else { return }
        guard stance != creditStance else { return }
        creditStance = stance
        setIntVariable("credit_stance_changed_turn", turnNumber)
    }
}
