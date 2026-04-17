//
//  StrategicResource.swift
//  Nomenklatura
//
//  The 12 strategic resources that drive supply chains, trade
//  negotiations, and sector production. Resources live in regions
//  (endowments), are produced by sectors, consumed by sectors, and
//  traded internationally.
//
//  Phase 3.1: data layer only. Phase 3.2 wires recipes; 3.3-3.7 wire
//  UI, forecasting, trade, and cross-system effects.
//

import Foundation

enum StrategicResource: String, Codable, CaseIterable, Hashable {
    // Energy
    case coal
    case oil
    case naturalGas
    case uranium

    // Heavy materials
    case iron
    case steel
    case aluminum
    case rareEarths

    // Consumables
    case grain
    case meat
    case timber
    case cotton

    var category: ResourceCategory {
        switch self {
        case .coal, .oil, .naturalGas, .uranium:
            return .energy
        case .iron, .steel, .aluminum, .rareEarths:
            return .heavyMaterial
        case .grain, .meat, .timber, .cotton:
            return .consumable
        }
    }

    var displayName: String {
        switch self {
        case .coal:        return "Coal"
        case .oil:         return "Oil"
        case .naturalGas:  return "Natural Gas"
        case .uranium:     return "Uranium"
        case .iron:        return "Iron Ore"
        case .steel:       return "Steel"
        case .aluminum:    return "Aluminum"
        case .rareEarths:  return "Rare Earths"
        case .grain:       return "Grain"
        case .meat:        return "Meat"
        case .timber:      return "Timber"
        case .cotton:      return "Cotton"
        }
    }

    /// SF Symbol for at-a-glance icon. Subsequent visual sub-batches may
    /// swap these for custom Constructivist illustrations.
    var iconName: String {
        switch self {
        case .coal:        return "circle.grid.cross.fill"
        case .oil:         return "drop.fill"
        case .naturalGas:  return "flame.fill"
        case .uranium:     return "atom"
        case .iron:        return "cube.fill"
        case .steel:       return "square.stack.3d.up.fill"
        case .aluminum:    return "rectangle.stack.fill"
        case .rareEarths:  return "sparkles"
        case .grain:       return "leaf.fill"
        case .meat:        return "fork.knife"
        case .timber:      return "tree.fill"
        case .cotton:      return "cloud.fill"
        }
    }

    /// The earliest tech era at which this resource can be extracted/used.
    /// Uranium and rare earths are atomic-era and beyond; everything else
    /// is available from game start.
    var minimumTechEra: TechEra {
        switch self {
        case .uranium:    return .atomic
        case .rareEarths: return .computerized
        default:          return .industrial
        }
    }

    /// Whether this resource is a raw input (mined/grown) or a processed
    /// good (manufactured from raw inputs). Steel and aluminum are
    /// processed; everything else is raw.
    var isRaw: Bool {
        switch self {
        case .steel, .aluminum: return false
        default:                return true
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
