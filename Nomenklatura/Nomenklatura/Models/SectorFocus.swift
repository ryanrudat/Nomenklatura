//
//  SectorFocus.swift
//  Nomenklatura
//
//  Production focus options for each economic sector. Each sector has 3-4
//  focus choices that determine what the sector produces and which national
//  stats benefit. Creates real trade-offs in economic planning.
//

import Foundation

// MARK: - Sector Focus

/// A production focus option for an economic sector
struct SectorFocus: Codable, Identifiable {
    var id: String { "\(sector.rawValue)_\(focusId)" }
    let sector: EconomicSector
    let focusId: String
    let name: String
    let description: String
    let iconName: String

    // Effects applied per turn when this focus is active
    let effects: [String: Int]  // stat key -> change per turn

    // Trade-offs
    let sectorProductionModifier: Int  // +/- to sector production
    let sectorMoraleModifier: Int      // +/- to worker morale
    let sectorEfficiencyModifier: Int  // +/- to efficiency
    let treasuryCostPerTurn: Int       // ongoing cost (negative = income)
}

// MARK: - Focus Catalog

extension SectorFocus {

    /// All available focuses, grouped by sector
    static let allFocuses: [EconomicSector: [SectorFocus]] = [
        .heavyIndustry: heavyIndustryFocuses,
        .lightIndustry: lightIndustryFocuses,
        .agriculture: agricultureFocuses,
        .energy: energyFocuses,
        .mining: miningFocuses,
        .construction: constructionFocuses,
        .transport: transportFocuses,
        .defense: defenseFocuses
    ]

    /// Focuses available for a given sector
    static func focuses(for sector: EconomicSector) -> [SectorFocus] {
        allFocuses[sector] ?? []
    }

    /// Default focus id for a sector (first option)
    static func defaultFocusId(for sector: EconomicSector) -> String {
        focuses(for: sector).first?.focusId ?? "default"
    }

    // MARK: - Heavy Industry

    private static let heavyIndustryFocuses: [SectorFocus] = [
        SectorFocus(
            sector: .heavyIndustry,
            focusId: "tanks",
            name: "Tank Production",
            description: "Retool factories for armored vehicle output. Strengthens the military but diverts steel from civilian use.",
            iconName: "shield.checkered",
            effects: ["militaryLoyalty": 2, "industrialOutput": -1],
            sectorProductionModifier: 5,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 3
        ),
        SectorFocus(
            sector: .heavyIndustry,
            focusId: "tractors",
            name: "Tractor Production",
            description: "Manufacture agricultural machinery. Boosts food production at the expense of military hardware.",
            iconName: "leaf.arrow.circlepath",
            effects: ["foodSupply": 2, "militaryLoyalty": -1],
            sectorProductionModifier: 3,
            sectorMoraleModifier: 5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 1
        ),
        SectorFocus(
            sector: .heavyIndustry,
            focusId: "steel",
            name: "Steel Expansion",
            description: "Maximize raw steel output to feed all downstream sectors. High investment, high industrial returns.",
            iconName: "hammer.fill",
            effects: ["industrialOutput": 3],
            sectorProductionModifier: 8,
            sectorMoraleModifier: -10,
            sectorEfficiencyModifier: 5,
            treasuryCostPerTurn: 4
        ),
        SectorFocus(
            sector: .heavyIndustry,
            focusId: "machinery",
            name: "General Machinery",
            description: "Balanced production of industrial equipment. Modest gains across all sectors, no dramatic trade-offs.",
            iconName: "gearshape.2.fill",
            effects: ["industrialOutput": 1, "stability": 1],
            sectorProductionModifier: 2,
            sectorMoraleModifier: 0,
            sectorEfficiencyModifier: 3,
            treasuryCostPerTurn: 2
        )
    ]

    // MARK: - Agriculture

    private static let agricultureFocuses: [SectorFocus] = [
        SectorFocus(
            sector: .agriculture,
            focusId: "collectives",
            name: "Collective Farms",
            description: "Large-scale collectivized agriculture. High theoretical output but poor worker morale and chronic inefficiency.",
            iconName: "person.3.fill",
            effects: ["foodSupply": 2, "popularSupport": -2],
            sectorProductionModifier: 5,
            sectorMoraleModifier: -15,
            sectorEfficiencyModifier: -5,
            treasuryCostPerTurn: 1
        ),
        SectorFocus(
            sector: .agriculture,
            focusId: "private_plots",
            name: "Private Plots",
            description: "Allow peasant smallholdings alongside state farms. Higher morale and efficiency, but lower total output and ideological risk.",
            iconName: "house.fill",
            effects: ["popularSupport": 3, "foodSupply": 1],
            sectorProductionModifier: -3,
            sectorMoraleModifier: 15,
            sectorEfficiencyModifier: 10,
            treasuryCostPerTurn: 0
        ),
        SectorFocus(
            sector: .agriculture,
            focusId: "export_crops",
            name: "Export Crops",
            description: "Prioritize cash crops for foreign currency. Treasury gains but domestic food supply suffers.",
            iconName: "dollarsign.circle.fill",
            effects: ["treasury": 3, "foodSupply": -2],
            sectorProductionModifier: 3,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: -2
        ),
        SectorFocus(
            sector: .agriculture,
            focusId: "mixed_farming",
            name: "Mixed Agriculture",
            description: "Balanced approach combining state and private output. Steady but unremarkable results.",
            iconName: "leaf.fill",
            effects: ["foodSupply": 1, "stability": 1],
            sectorProductionModifier: 0,
            sectorMoraleModifier: 0,
            sectorEfficiencyModifier: 2,
            treasuryCostPerTurn: 1
        )
    ]

    // MARK: - Light Industry

    private static let lightIndustryFocuses: [SectorFocus] = [
        SectorFocus(
            sector: .lightIndustry,
            focusId: "consumer_goods",
            name: "Consumer Goods",
            description: "Produce household items, appliances, and amenities. The people notice when shelves are full.",
            iconName: "cart.fill",
            effects: ["popularSupport": 3, "stability": 1],
            sectorProductionModifier: 3,
            sectorMoraleModifier: 10,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 2
        ),
        SectorFocus(
            sector: .lightIndustry,
            focusId: "textiles_export",
            name: "Textile Exports",
            description: "Manufacture textiles for foreign markets. Earns hard currency but leaves domestic shops empty.",
            iconName: "dollarsign.arrow.circlepath",
            effects: ["treasury": 3, "popularSupport": -2],
            sectorProductionModifier: 5,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 3,
            treasuryCostPerTurn: -1
        ),
        SectorFocus(
            sector: .lightIndustry,
            focusId: "military_uniforms",
            name: "Military Uniforms",
            description: "Dedicate textile capacity to military outfitting. Strengthens military loyalty at the cost of civilian supply.",
            iconName: "shield.fill",
            effects: ["militaryLoyalty": 2, "popularSupport": -1],
            sectorProductionModifier: 2,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 2
        ),
        SectorFocus(
            sector: .lightIndustry,
            focusId: "housing_materials",
            name: "Housing Materials",
            description: "Produce building materials and prefab components. Slow but steady improvement to living conditions.",
            iconName: "building.fill",
            effects: ["stability": 2, "popularSupport": 1],
            sectorProductionModifier: 0,
            sectorMoraleModifier: 5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 2
        )
    ]

    // MARK: - Energy

    private static let energyFocuses: [SectorFocus] = [
        SectorFocus(
            sector: .energy,
            focusId: "coal",
            name: "Coal Production",
            description: "Cheap and abundant but damages infrastructure and worker health over time. The backbone of early industrialization.",
            iconName: "flame.fill",
            effects: ["industrialOutput": 2, "stability": -1],
            sectorProductionModifier: 8,
            sectorMoraleModifier: -10,
            sectorEfficiencyModifier: -5,
            treasuryCostPerTurn: 0
        ),
        SectorFocus(
            sector: .energy,
            focusId: "oil",
            name: "Oil Extraction",
            description: "Moderate cost, exportable surplus. Provides steady energy with foreign currency potential.",
            iconName: "drop.fill",
            effects: ["treasury": 2, "industrialOutput": 1],
            sectorProductionModifier: 3,
            sectorMoraleModifier: 0,
            sectorEfficiencyModifier: 3,
            treasuryCostPerTurn: 2
        ),
        SectorFocus(
            sector: .energy,
            focusId: "hydroelectric",
            name: "Hydroelectric Power",
            description: "Expensive dam construction pays off with efficient, clean power. A long-term investment in the future.",
            iconName: "water.waves",
            effects: ["industrialOutput": 1, "stability": 1],
            sectorProductionModifier: -3,
            sectorMoraleModifier: 5,
            sectorEfficiencyModifier: 10,
            treasuryCostPerTurn: 4
        ),
        SectorFocus(
            sector: .energy,
            focusId: "nuclear",
            name: "Nuclear Program",
            description: "Extremely expensive but delivers massive output once operational. A prestige project with strategic implications.",
            iconName: "atom",
            effects: ["industrialOutput": 3, "internationalStanding": 1],
            sectorProductionModifier: -5,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 15,
            treasuryCostPerTurn: 6
        )
    ]

    // MARK: - Mining

    private static let miningFocuses: [SectorFocus] = [
        SectorFocus(
            sector: .mining,
            focusId: "iron_ore",
            name: "Iron Ore",
            description: "Feed the blast furnaces. Directly supports heavy industry at the cost of other mineral extraction.",
            iconName: "cube.fill",
            effects: ["industrialOutput": 2],
            sectorProductionModifier: 5,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 1
        ),
        SectorFocus(
            sector: .mining,
            focusId: "precious_metals",
            name: "Precious Metals",
            description: "Gold and platinum for state reserves and export. Enriches the treasury but does little for industry.",
            iconName: "star.circle.fill",
            effects: ["treasury": 4],
            sectorProductionModifier: 0,
            sectorMoraleModifier: 0,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 2
        ),
        SectorFocus(
            sector: .mining,
            focusId: "construction_materials",
            name: "Construction Materials",
            description: "Quarry stone, gravel, and cement for the building sector. Essential for housing and infrastructure programs.",
            iconName: "building.2.fill",
            effects: ["stability": 2, "popularSupport": 1],
            sectorProductionModifier: 3,
            sectorMoraleModifier: 0,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 1
        ),
        SectorFocus(
            sector: .mining,
            focusId: "strategic_minerals",
            name: "Strategic Minerals",
            description: "Rare earth and uranium extraction for defense applications. Military value at high cost.",
            iconName: "shield.lefthalf.filled",
            effects: ["militaryLoyalty": 2, "internationalStanding": 1],
            sectorProductionModifier: -3,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 3
        )
    ]

    // MARK: - Construction

    private static let constructionFocuses: [SectorFocus] = [
        SectorFocus(
            sector: .construction,
            focusId: "housing",
            name: "Housing Program",
            description: "Build apartment blocks for the masses. Slow but meaningful improvement to popular support.",
            iconName: "house.lodge.fill",
            effects: ["popularSupport": 3, "stability": 1],
            sectorProductionModifier: 3,
            sectorMoraleModifier: 10,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 3
        ),
        SectorFocus(
            sector: .construction,
            focusId: "factories",
            name: "Factory Construction",
            description: "Expand industrial capacity with new plants and workshops. Boosts output but costs heavily.",
            iconName: "wrench.and.screwdriver.fill",
            effects: ["industrialOutput": 3],
            sectorProductionModifier: 5,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 5,
            treasuryCostPerTurn: 4
        ),
        SectorFocus(
            sector: .construction,
            focusId: "infrastructure",
            name: "Infrastructure",
            description: "Roads, bridges, utilities, and public works. Benefits all sectors modestly through improved connectivity.",
            iconName: "road.lanes",
            effects: ["stability": 2, "industrialOutput": 1],
            sectorProductionModifier: 0,
            sectorMoraleModifier: 5,
            sectorEfficiencyModifier: 5,
            treasuryCostPerTurn: 3
        ),
        SectorFocus(
            sector: .construction,
            focusId: "military_bases",
            name: "Military Installations",
            description: "Construct barracks, bunkers, and defense works. Strengthens military loyalty but diverts resources from civilians.",
            iconName: "shield.checkered",
            effects: ["militaryLoyalty": 3, "popularSupport": -1],
            sectorProductionModifier: 0,
            sectorMoraleModifier: -10,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 4
        )
    ]

    // MARK: - Transport

    private static let transportFocuses: [SectorFocus] = [
        SectorFocus(
            sector: .transport,
            focusId: "rail_network",
            name: "Rail Network",
            description: "Expand and modernize railways. Boosts industrial efficiency by connecting factories to resources.",
            iconName: "train.side.front.car",
            effects: ["industrialOutput": 2, "stability": 1],
            sectorProductionModifier: 5,
            sectorMoraleModifier: 0,
            sectorEfficiencyModifier: 5,
            treasuryCostPerTurn: 3
        ),
        SectorFocus(
            sector: .transport,
            focusId: "roads",
            name: "Road Construction",
            description: "Build highways linking regional centers. Improves regional connectivity and popular satisfaction.",
            iconName: "road.lanes",
            effects: ["popularSupport": 2, "stability": 1],
            sectorProductionModifier: 3,
            sectorMoraleModifier: 5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 2
        ),
        SectorFocus(
            sector: .transport,
            focusId: "ports",
            name: "Port Development",
            description: "Invest in maritime infrastructure. Opens trade capacity and earns foreign currency.",
            iconName: "ferry.fill",
            effects: ["treasury": 2, "internationalStanding": 1],
            sectorProductionModifier: 0,
            sectorMoraleModifier: 0,
            sectorEfficiencyModifier: 3,
            treasuryCostPerTurn: 3
        ),
        SectorFocus(
            sector: .transport,
            focusId: "military_logistics",
            name: "Military Logistics",
            description: "Prioritize supply chains for the armed forces. Strengthens military readiness at civilian expense.",
            iconName: "shippingbox.fill",
            effects: ["militaryLoyalty": 2, "popularSupport": -1],
            sectorProductionModifier: -3,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 3
        )
    ]

    // MARK: - Defense

    private static let defenseFocuses: [SectorFocus] = [
        SectorFocus(
            sector: .defense,
            focusId: "conventional_arms",
            name: "Conventional Arms",
            description: "Rifles, artillery, and standard military equipment. Reliable, moderate-cost military strengthening.",
            iconName: "scope",
            effects: ["militaryLoyalty": 3],
            sectorProductionModifier: 5,
            sectorMoraleModifier: 0,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 3
        ),
        SectorFocus(
            sector: .defense,
            focusId: "nuclear_weapons",
            name: "Nuclear Weapons Program",
            description: "Pursue the ultimate deterrent. Enormous cost but unmatched international leverage and prestige.",
            iconName: "bolt.shield.fill",
            effects: ["internationalStanding": 3, "militaryLoyalty": 1],
            sectorProductionModifier: -5,
            sectorMoraleModifier: -10,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 6
        ),
        SectorFocus(
            sector: .defense,
            focusId: "intelligence_tech",
            name: "Intelligence Technology",
            description: "Develop surveillance equipment and signals intelligence. Enhances internal security apparatus.",
            iconName: "eye.fill",
            effects: ["stability": 2, "eliteLoyalty": 1],
            sectorProductionModifier: 0,
            sectorMoraleModifier: -5,
            sectorEfficiencyModifier: 5,
            treasuryCostPerTurn: 3
        ),
        SectorFocus(
            sector: .defense,
            focusId: "civil_defense",
            name: "Civil Defense",
            description: "Shelters, emergency services, and civil preparedness. Improves stability and popular confidence.",
            iconName: "person.badge.shield.checkmark.fill",
            effects: ["stability": 3, "popularSupport": 1],
            sectorProductionModifier: -3,
            sectorMoraleModifier: 5,
            sectorEfficiencyModifier: 0,
            treasuryCostPerTurn: 2
        )
    ]
}
