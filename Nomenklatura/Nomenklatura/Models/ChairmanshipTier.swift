//
//  ChairmanshipTier.swift
//  Nomenklatura
//
//  The weak→strong "chairmanship spectrum" from CHAIRMANSHIP_TIERS_DESIGN.md — a
//  legible, named identity layer over the otherwise-invisible
//  powerConsolidationScore. Five tiers, each with real mechanical consequences
//  (Standing Committee deference, decree authority) and, at the top, a
//  control-vs-stability tradeoff (elite resentment). Game-internal fictional
//  names per the project's no-real-figure-names rule. (Built 2026-06.)
//

import Foundation

enum ChairmanshipTier: Int, CaseIterable, Comparable {
    case compromiseChairman    // 0–24  — anointed figurehead the Committee can override
    case firstAmongEquals      // 25–44 — consensus broker; must build coalitions
    case paramountChairman     // 45–64 — paramount reformer; committee usually defers
    case theCore               // 65–84 — faction-building core; committee rubber-stamps
    case supremeChairman       // 85–100 — personalist strongman; committee ceremonial

    static func from(score: Int) -> ChairmanshipTier {
        switch score {
        case 85...: return .supremeChairman
        case 65..<85: return .theCore
        case 45..<65: return .paramountChairman
        case 25..<45: return .firstAmongEquals
        default: return .compromiseChairman
        }
    }

    /// Lower edge of this tier's score band (used for hysteresis deadbands).
    var lowerBound: Int {
        switch self {
        case .compromiseChairman: return 0
        case .firstAmongEquals: return 25
        case .paramountChairman: return 45
        case .theCore: return 65
        case .supremeChairman: return 85
        }
    }

    /// Full in-world tier name.
    var displayName: String {
        switch self {
        case .compromiseChairman: return "Compromise Chairman"
        case .firstAmongEquals: return "First Among Equals"
        case .paramountChairman: return "Paramount Chairman"
        case .theCore: return "The Core"
        case .supremeChairman: return "Supreme Chairman"
        }
    }

    /// Short all-caps label for compact UI (e.g. the Desk header).
    var label: String {
        switch self {
        case .compromiseChairman: return "COMPROMISE"
        case .firstAmongEquals: return "FIRST AMONG EQUALS"
        case .paramountChairman: return "PARAMOUNT"
        case .theCore: return "THE CORE"
        case .supremeChairman: return "SUPREME"
        }
    }

    /// Player's effective Standing-Committee vote weight at this tier — the
    /// mechanical expression of "the committee defers more the stronger you are."
    var voteWeight: Int {
        switch self {
        case .compromiseChairman: return 1
        case .firstAmongEquals: return 2
        case .paramountChairman: return 3
        case .theCore: return 5
        case .supremeChairman: return 10
        }
    }

    /// Maximum stockpiled Chairman's Decree charges at this tier. NOTE: kept at a
    /// baseline of 3 at the bottom (the game has always granted 3 from the start;
    /// dropping to 0 would regress the shipped decree feature) and scales UP, so
    /// consolidating grants more decree authority — the doc's intent — without
    /// nerfing the opening.
    var decreeMax: Int {
        switch self {
        case .compromiseChairman: return 3
        case .firstAmongEquals: return 3
        case .paramountChairman: return 4
        case .theCore: return 5
        case .supremeChairman: return 8
        }
    }

    /// Turns between Chairman's Decree charge regenerations at this tier
    /// (50 → 18 across tiers). Single source of truth — read by both the
    /// GameEngine regen step and the last-charge warning copy.
    var decreeRegenInterval: Int {
        max(10, 50 - rawValue * 8)
    }

    /// How the Standing Committee treats the player at this tier (for prompts/UI).
    var committeeBehavior: String {
        switch self {
        case .compromiseChairman: return "can override you and force its own votes through"
        case .firstAmongEquals: return "blocks roughly half your initiatives unless you've built the coalition"
        case .paramountChairman: return "usually defers to you, and rarely overrides"
        case .theCore: return "rubber-stamps your proposals"
        case .supremeChairman: return "is ceremonial — it ratifies whatever you decide"
        }
    }

    /// One-line regime descriptor used in tier-change announcements.
    var regimeDescriptor: String {
        switch self {
        case .compromiseChairman: return "a compromise chairman the Standing Committee can still override"
        case .firstAmongEquals: return "first among equals — your peers bargain, they do not yet obey"
        case .paramountChairman: return "the paramount chairman; the Committee defers and the apparatus follows"
        case .theCore: return "the Core of the Party — your word is rubber-stamped, but elite resentment is building"
        case .supremeChairman: return "the Supreme Chairman, unchallenged master of the state — and exposed to the fragility that brings"
        }
    }

    /// Compact descriptor fed to the AI prompt instead of the raw number.
    var promptDescriptor: String {
        "a \(displayName) — the Standing Committee \(committeeBehavior)"
    }

    static func < (lhs: ChairmanshipTier, rhs: ChairmanshipTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
