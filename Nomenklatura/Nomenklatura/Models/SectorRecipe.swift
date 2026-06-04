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

        // MARK: Heavy Industry — the STEEL feeder
        SectorRecipe(focusId: "tanks", sector: .heavyIndustry,
                     inputs: [.steel: 4, .energy: 2]),
        SectorRecipe(focusId: "tractors", sector: .heavyIndustry,
                     inputs: [.steel: 3]),
        SectorRecipe(focusId: "steel", sector: .heavyIndustry,
                     inputs: [.energy: 3],
                     outputs: [.steel: 8]),
        SectorRecipe(focusId: "machinery", sector: .heavyIndustry,
                     inputs: [.steel: 2, .energy: 1]),

        // MARK: Agriculture — the GRAIN feeder
        SectorRecipe(focusId: "collectives", sector: .agriculture,
                     inputs: [.energy: 1],
                     outputs: [.grain: 12]),
        SectorRecipe(focusId: "private_plots", sector: .agriculture,
                     outputs: [.grain: 8]),
        SectorRecipe(focusId: "export_crops", sector: .agriculture,
                     outputs: [.grain: 7]),
        SectorRecipe(focusId: "mixed_farming", sector: .agriculture,
                     outputs: [.grain: 9]),

        // MARK: Light Industry — consumes energy
        SectorRecipe(focusId: "consumer_goods", sector: .lightIndustry,
                     inputs: [.energy: 2]),
        SectorRecipe(focusId: "textiles_export", sector: .lightIndustry,
                     inputs: [.energy: 1]),
        SectorRecipe(focusId: "military_uniforms", sector: .lightIndustry,
                     inputs: [.steel: 1]),
        SectorRecipe(focusId: "housing_materials", sector: .lightIndustry,
                     inputs: [.steel: 2]),

        // MARK: Energy — the ENERGY feeder
        SectorRecipe(focusId: "coal", sector: .energy,
                     outputs: [.energy: 9]),
        SectorRecipe(focusId: "oil", sector: .energy,
                     outputs: [.energy: 8]),
        SectorRecipe(focusId: "hydroelectric", sector: .energy,
                     outputs: [.energy: 6]),
        SectorRecipe(focusId: "nuclear", sector: .energy,
                     outputs: [.energy: 12]),

        // MARK: Mining — secondary STEEL feeder
        SectorRecipe(focusId: "iron_ore", sector: .mining,
                     outputs: [.steel: 6]),
        SectorRecipe(focusId: "precious_metals", sector: .mining,
                     outputs: [.steel: 2]),
        SectorRecipe(focusId: "construction_materials", sector: .mining,
                     outputs: [.steel: 4]),
        SectorRecipe(focusId: "strategic_minerals", sector: .mining,
                     outputs: [.steel: 3, .energy: 2]),

        // MARK: Construction — consumes steel
        SectorRecipe(focusId: "housing", sector: .construction,
                     inputs: [.steel: 3]),
        SectorRecipe(focusId: "factories", sector: .construction,
                     inputs: [.steel: 4]),
        SectorRecipe(focusId: "infrastructure", sector: .construction,
                     inputs: [.steel: 2, .energy: 1]),
        SectorRecipe(focusId: "military_bases", sector: .construction,
                     inputs: [.steel: 3]),

        // MARK: Transport — consumes energy + steel
        SectorRecipe(focusId: "rail_network", sector: .transport,
                     inputs: [.steel: 2, .energy: 2]),
        SectorRecipe(focusId: "roads", sector: .transport,
                     inputs: [.energy: 1]),
        SectorRecipe(focusId: "ports", sector: .transport,
                     inputs: [.steel: 1]),
        SectorRecipe(focusId: "military_logistics", sector: .transport,
                     inputs: [.energy: 2, .steel: 1]),

        // MARK: Defense — consumes steel + energy
        SectorRecipe(focusId: "conventional_arms", sector: .defense,
                     inputs: [.steel: 3]),
        SectorRecipe(focusId: "nuclear_weapons", sector: .defense,
                     inputs: [.steel: 2, .energy: 2]),
        SectorRecipe(focusId: "intelligence_tech", sector: .defense,
                     inputs: [.energy: 1]),
        SectorRecipe(focusId: "civil_defense", sector: .defense,
                     inputs: [.steel: 1])
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
            // Administrative — modest grain baseline
            return [.grain: 3]
        case .industrial:
            // Industrial heartland — energy (coal) + some steel deposits
            return [.energy: 6, .steel: 2]
        case .agricultural:
            // Farming region — grain
            return [.grain: 9]
        case .border:
            // Frontier — modest energy + steel
            return [.energy: 3, .steel: 1]
        case .autonomous:
            // Often holds energy deposits the center wants
            return [.energy: 4]
        case .coastal:
            // Ports + offshore energy
            return [.energy: 6]
        case .extractive:
            // Mining-heavy — energy + steel
            return [.energy: 7, .steel: 3]
        }
    }
}
