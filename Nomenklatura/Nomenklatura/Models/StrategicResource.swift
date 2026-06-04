//
//  StrategicResource.swift
//  Nomenklatura
//
//  The strategic resources that drive sector production. Simplified in the
//  2026-06 economy pass from 12 resources to THREE — Steel, Grain, Energy — so
//  the player tracks an at-a-glance feeder economy ("Heavy Industry makes steel,
//  Agriculture makes grain, Energy makes energy; downstream sectors consume them")
//  instead of a 12-commodity ledger. Energy folds the old coal/oil/gas; Steel
//  folds the old iron/aluminum heavy materials; Grain folds the old food
//  consumables. Uranium/rare-earths/tech-era resources were cut with the tech
//  ladder.
//

import Foundation

enum StrategicResource: String, Codable, CaseIterable, Hashable {
    case steel      // heavy materials feeder (Heavy Industry / Mining)
    case grain      // food feeder (Agriculture)
    case energy     // coal + oil + power (Energy sector + regions)

    var category: ResourceCategory {
        switch self {
        case .steel:  return .heavyMaterial
        case .grain:  return .consumable
        case .energy: return .energy
        }
    }

    var displayName: String {
        switch self {
        case .steel:  return "Steel"
        case .grain:  return "Grain"
        case .energy: return "Energy"
        }
    }

    /// SF Symbol for at-a-glance icon.
    var iconName: String {
        switch self {
        case .steel:  return "square.stack.3d.up.fill"
        case .grain:  return "leaf.fill"
        case .energy: return "bolt.fill"
        }
    }

    /// All three resources are available from game start (the tech-era gate was
    /// removed in the simplification). Retained for the supply-chain engine's
    /// `canUse` check, which now always passes.
    var minimumTechEra: TechEra { .industrial }

    /// Steel is a processed/manufactured good; grain and energy are extracted.
    var isRaw: Bool {
        switch self {
        case .steel:  return false
        default:      return true
        }
    }
}

enum ResourceCategory: String, Codable, CaseIterable {
    case energy
    case heavyMaterial
    case consumable

    var displayName: String {
        switch self {
        case .energy:        return "Energy"
        case .heavyMaterial: return "Heavy Materials"
        case .consumable:    return "Consumables"
        }
    }
}
