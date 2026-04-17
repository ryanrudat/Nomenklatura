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

    static func < (lhs: TechEra, rhs: TechEra) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
