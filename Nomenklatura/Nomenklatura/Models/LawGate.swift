//
//  LawGate.swift
//  Nomenklatura
//
//  Identifies laws/policies that gate new economic and political mechanics.
//  Phase 3-4 mechanics check these via ActionAvailability.evaluate.
//

import Foundation

enum LawGate: String, Codable, CaseIterable {
    case liberalizedTrade
    case strengthenedCentralPlanning
    case emergencyPowers
    case privateEnterprisePermitted
    case wartime
    case priceControlsActive
    case collectivizationDecreed
    case foreignCurrencyReserves
    case stateMediaControl
    case militaryEmergencyPowers

    var displayName: String {
        switch self {
        case .liberalizedTrade:           return "Liberalized Trade Law"
        case .strengthenedCentralPlanning: return "Central Planning Reinforcement Act"
        case .emergencyPowers:            return "Emergency Powers Decree"
        case .privateEnterprisePermitted: return "Private Enterprise Authorization"
        case .wartime:                    return "Wartime Mobilization"
        case .priceControlsActive:        return "Price Controls Order"
        case .collectivizationDecreed:    return "Collectivization Decree"
        case .foreignCurrencyReserves:    return "Foreign Currency Reserve Act"
        case .stateMediaControl:          return "State Media Consolidation"
        case .militaryEmergencyPowers:    return "Military Emergency Powers"
        }
    }

    /// Whether this gate is active in the current game.
    /// Stub implementation: returns false until Phase 1 wires real law detection
    /// to game.laws / game.policySlots / game flags. Phases 3-4 mechanics that gate
    /// on a law will simply be locked until that wiring lands.
    static func isActive(_ gate: LawGate, in game: Game) -> Bool {
        return false
    }
}
