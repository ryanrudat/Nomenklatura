//
//  SectorRecipe.swift
//  Nomenklatura
//
//  Phase 3.2: input/output recipes for every sector focus. Each recipe
//  declares what strategic resources the focus consumes per turn and
//  what it produces. The supply-chain engine reads these to extract
//  raw materials from regions, route them to sectors, scale outputs by
//  available inputs, and surface shortfalls to the UI.
//

import Foundation

struct SectorRecipe: Codable, Hashable {
    let focusId: String
    let sector: EconomicSector
    let inputs: [StrategicResource: Int]
    let outputs: [StrategicResource: Int]
    let requiredTechEra: TechEra

    init(
        focusId: String,
        sector: EconomicSector,
        inputs: [StrategicResource: Int] = [:],
        outputs: [StrategicResource: Int] = [:],
        requiredTechEra: TechEra = .industrial
    ) {
        self.focusId = focusId
        self.sector = sector
        self.inputs = inputs
        self.outputs = outputs
        self.requiredTechEra = requiredTechEra
    }
}

// MARK: - Recipe Catalog

extension SectorRecipe {

    /// All 32 sector-focus recipes. Inputs/outputs are abstract per-turn
    /// units; tuning happens after first playtests. Sectors with empty
    /// inputs/outputs still apply their existing stat effects via
    /// SectorFocus — recipes are additive, not a replacement.
    static let allRecipes: [SectorRecipe] = [

        // MARK: Heavy Industry
        SectorRecipe(focusId: "tanks", sector: .heavyIndustry,
                     inputs: [.steel: 4, .aluminum: 2, .oil: 2]),
        SectorRecipe(focusId: "tractors", sector: .heavyIndustry,
                     inputs: [.steel: 3, .oil: 1]),
        SectorRecipe(focusId: "steel", sector: .heavyIndustry,
                     inputs: [.iron: 8, .coal: 4],
                     outputs: [.steel: 6]),
        SectorRecipe(focusId: "machinery", sector: .heavyIndustry,
                     inputs: [.steel: 2, .aluminum: 1]),

        // MARK: Agriculture
        SectorRecipe(focusId: "collectives", sector: .agriculture,
                     inputs: [.oil: 2],
                     outputs: [.grain: 10]),
        SectorRecipe(focusId: "private_plots", sector: .agriculture,
                     outputs: [.grain: 6, .meat: 3]),
        SectorRecipe(focusId: "export_crops", sector: .agriculture,
                     inputs: [.oil: 2],
                     outputs: [.cotton: 6, .grain: 4]),
        SectorRecipe(focusId: "mixed_farming", sector: .agriculture,
                     outputs: [.grain: 7, .meat: 2]),

        // MARK: Light Industry
        SectorRecipe(focusId: "consumer_goods", sector: .lightIndustry,
                     inputs: [.cotton: 3, .timber: 2]),
        SectorRecipe(focusId: "textiles_export", sector: .lightIndustry,
                     inputs: [.cotton: 5]),
        SectorRecipe(focusId: "military_uniforms", sector: .lightIndustry,
                     inputs: [.cotton: 4]),
        SectorRecipe(focusId: "housing_materials", sector: .lightIndustry,
                     inputs: [.timber: 4, .steel: 1]),

        // MARK: Energy
        SectorRecipe(focusId: "coal", sector: .energy,
                     outputs: [.coal: 8]),
        SectorRecipe(focusId: "oil", sector: .energy,
                     outputs: [.oil: 6]),
        SectorRecipe(focusId: "hydroelectric", sector: .energy),
        SectorRecipe(focusId: "nuclear", sector: .energy,
                     inputs: [.uranium: 2],
                     requiredTechEra: .atomic),

        // MARK: Mining
        SectorRecipe(focusId: "iron_ore", sector: .mining,
                     outputs: [.iron: 8]),
        SectorRecipe(focusId: "precious_metals", sector: .mining),
        SectorRecipe(focusId: "construction_materials", sector: .mining,
                     outputs: [.timber: 4]),
        SectorRecipe(focusId: "strategic_minerals", sector: .mining,
                     outputs: [.uranium: 1, .rareEarths: 1],
                     requiredTechEra: .atomic),

        // MARK: Construction
        SectorRecipe(focusId: "housing", sector: .construction,
                     inputs: [.timber: 3, .steel: 2]),
        SectorRecipe(focusId: "factories", sector: .construction,
                     inputs: [.steel: 4, .aluminum: 1]),
        SectorRecipe(focusId: "infrastructure", sector: .construction,
                     inputs: [.steel: 2, .timber: 2]),
        SectorRecipe(focusId: "military_bases", sector: .construction,
                     inputs: [.steel: 3, .timber: 2]),

        // MARK: Transport
        SectorRecipe(focusId: "rail_network", sector: .transport,
                     inputs: [.steel: 2, .oil: 2]),
        SectorRecipe(focusId: "roads", sector: .transport,
                     inputs: [.oil: 1]),
        SectorRecipe(focusId: "ports", sector: .transport,
                     inputs: [.steel: 1, .timber: 1]),
        SectorRecipe(focusId: "military_logistics", sector: .transport,
                     inputs: [.oil: 2, .steel: 1]),

        // MARK: Defense
        SectorRecipe(focusId: "conventional_arms", sector: .defense,
                     inputs: [.steel: 3, .aluminum: 1]),
        SectorRecipe(focusId: "nuclear_weapons", sector: .defense,
                     inputs: [.uranium: 2, .steel: 2],
                     requiredTechEra: .atomic),
        SectorRecipe(focusId: "intelligence_tech", sector: .defense,
                     inputs: [.rareEarths: 1],
                     requiredTechEra: .computerized),
        SectorRecipe(focusId: "civil_defense", sector: .defense,
                     inputs: [.steel: 1, .timber: 2])
    ]

    /// Lookup recipe by focus id.
    static func recipe(for focusId: String) -> SectorRecipe? {
        allRecipes.first { $0.focusId == focusId }
    }

    /// Lookup recipe for a SectorFocus (more strict: matches focusId AND sector).
    static func recipe(for focus: SectorFocus) -> SectorRecipe? {
        allRecipes.first { $0.focusId == focus.focusId && $0.sector == focus.sector }
    }
}

// MARK: - Region Endowment Templates

extension RegionType {
    /// Default per-turn extraction capacity for a fresh region of this
    /// type. Phase 3.2 seeding uses these; campaign editors and
    /// scenario tools can override per-region.
    var defaultEndowments: [StrategicResource: Int] {
        switch self {
        case .capital:
            // Capital is administrative — modest baseline of consumables
            return [.grain: 2, .timber: 2]
        case .industrial:
            // Industrial heartland — coal + iron + steel (processed) deposits
            return [.coal: 6, .iron: 4, .timber: 1]
        case .agricultural:
            // Farming region — grain, meat, cotton
            return [.grain: 8, .meat: 4, .cotton: 3]
        case .border:
            // Frontier — modest extraction, defensive priority
            return [.timber: 4, .iron: 2, .coal: 2]
        case .autonomous:
            // Ethnic regions often hold rare deposits the center wants
            return [.oil: 3, .rareEarths: 1, .timber: 2]
        case .coastal:
            // Ports + offshore — oil, cotton (textile trade), aluminum (bauxite)
            return [.oil: 5, .cotton: 3, .aluminum: 2]
        case .extractive:
            // Mining-heavy — coal, iron, uranium, rare earths
            return [.coal: 8, .iron: 6, .uranium: 1, .rareEarths: 1]
        }
    }
}
