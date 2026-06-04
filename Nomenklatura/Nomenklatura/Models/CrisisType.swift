//
//  CrisisType.swift
//  Nomenklatura
//
//  Unified taxonomy of acute crises the Chairman can respond to from a
//  single Crisis Response Panel. Each case maps to a detection rule in
//  CrisisResponseService.activeCrises(in:) and a curated option library.
//
//  See: Models/CrisisResponseOption.swift, Services/CrisisResponseService.swift
//

import Foundation

enum CrisisType: String, CaseIterable, Identifiable {
    case stabilityCollapse
    case treasuryCrisis
    case resourceCatastrophe
    case coupRisk
    case diplomaticCrisis
    case rivalDeadline
    case secessionCrisis

    var id: String { rawValue }

    /// Headline label shown in the Crisis Response Panel. Tracked uppercase
    /// to match the brutalist bureaucratic aesthetic used elsewhere.
    var displayName: String {
        switch self {
        case .stabilityCollapse:    return "STABILITY COLLAPSE"
        case .treasuryCrisis:       return "TREASURY CRISIS"
        case .resourceCatastrophe:  return "RESOURCE CATASTROPHE"
        case .coupRisk:             return "COUP RISK"
        case .diplomaticCrisis:     return "DIPLOMATIC CRISIS"
        case .rivalDeadline:        return "RIVAL DEADLINE"
        case .secessionCrisis:      return "SECESSION CRISIS"
        }
    }

    /// SF Symbol used by the panel header and inline list rows.
    var icon: String {
        switch self {
        case .stabilityCollapse:    return "flame.fill"
        case .treasuryCrisis:       return "banknote.fill"
        case .resourceCatastrophe:  return "exclamationmark.octagon.fill"
        case .coupRisk:             return "shield.lefthalf.filled.slash"
        case .diplomaticCrisis:     return "globe.badge.chevron.backward"
        case .rivalDeadline:        return "hourglass.bottomhalf.filled"
        case .secessionCrisis:      return "flag.slash.fill"
        }
    }

    /// One-line flavour text under the headline. Game-internal language only.
    var shortDescription: String {
        switch self {
        case .stabilityCollapse:    return "Mass unrest in the streets."
        case .treasuryCrisis:       return "Coffers nearly empty; debt service mounting."
        case .resourceCatastrophe:  return "Multiple sectors starved of strategic inputs."
        case .coupRisk:             return "Military loyalty has cratered."
        case .diplomaticCrisis:     return "Foreign tensions approaching the brink."
        case .rivalDeadline:        return "A rival's move resolves imminently."
        case .secessionCrisis:      return "A region is breaking away from the union."
        }
    }
}
