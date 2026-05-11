//
//  TechEra.swift
//  Nomenklatura
//
//  Five technology eras that gate which strategic resources can be
//  extracted, which sector focuses are available, and which trade
//  agreements can be signed. Eras unlock as the player completes
//  Five-Year Plans with high ratings — fitting the Chairman role
//  (the player invests in research budget, doesn't pick individual
//  technologies).
//

import Foundation

enum TechEra: Int, Codable, Comparable, CaseIterable {
    case industrial   = 0   // Game start
    case mechanized   = 1   // 1 successful Five-Year Plan
    case atomic       = 2   // 1 Stakhanovite plan + research investment
    case computerized = 3   // 2 Stakhanovite plans + Western trade access
    case modern       = 4   // 3 Stakhanovite plans + sustained research

    var displayName: String {
        switch self {
        case .industrial:   return "Industrial"
        case .mechanized:   return "Mechanized"
        case .atomic:       return "Atomic"
        case .computerized: return "Computerized"
        case .modern:       return "Modern"
        }
    }

    var description: String {
        switch self {
        case .industrial:
            return "Coal, oil, basic steel. The state runs on furnaces and railroads."
        case .mechanized:
            return "Aluminum production, refined oil, mechanized agriculture."
        case .atomic:
            return "Nuclear power, uranium enrichment, advanced metallurgy."
        case .computerized:
            return "Electronics, rare earth processing, automated planning."
        case .modern:
            return "Solar, advanced clean energy, full-spectrum strategic capability."
        }
    }

    nonisolated static func < (lhs: TechEra, rhs: TechEra) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Compute the tech era a player should be in given their plan history.
    /// Mechanized requires 1 completed plan (any rating ≥ partial).
    /// Atomic requires 1 Stakhanovite (4/4) plan.
    /// Computerized requires 2 Stakhanovite plans.
    /// Modern requires 3 Stakhanovite plans.
    static func era(forCompletedPlans completedPlans: Int, stakhanovitePlans: Int) -> TechEra {
        if stakhanovitePlans >= 3 { return .modern }
        if stakhanovitePlans >= 2 { return .computerized }
        if stakhanovitePlans >= 1 { return .atomic }
        if completedPlans >= 1 { return .mechanized }
        return .industrial
    }

    /// Player-facing announcement when an era unlocks (for notifications and Codex events).
    var unlockHeadline: String {
        switch self {
        case .industrial:   return "Industrial Foundation"
        case .mechanized:   return "Mechanization Achieved"
        case .atomic:       return "Atomic Era Begins"
        case .computerized: return "Computerized Apparatus Online"
        case .modern:       return "Modern State Capability Unlocked"
        }
    }
}
