//
//  Region.swift
//  Nomenklatura
//
//  Domestic zones of the People's Socialist Republic with secession mechanics
//

import Foundation
import SwiftData

// MARK: - Region Type

enum RegionType: String, Codable, CaseIterable {
    case capital            // Political center, government seat
    case industrial         // Heavy industry, manufacturing
    case agricultural       // Farming, food production
    case border             // Military presence, frontier defense
    case autonomous         // Ethnic minorities, special status
    case coastal            // Ports, naval, trade access
    case extractive         // Mining, resources, labor camps

    var displayName: String {
        switch self {
        case .capital: return "Capital District"
        case .industrial: return "Industrial Zone"
        case .agricultural: return "Agricultural Region"
        case .border: return "Border Territory"
        case .autonomous: return "Autonomous Region"
        case .coastal: return "Coastal Territory"
        case .extractive: return "Extractive Territory"
        }
    }

    var iconName: String {
        switch self {
        case .capital: return "building.columns.fill"
        case .industrial: return "gearshape.2.fill"
        case .agricultural: return "leaf.fill"
        case .border: return "shield.fill"
        case .autonomous: return "flag.fill"
        case .coastal: return "water.waves"
        case .extractive: return "mountain.2.fill"
        }
    }
}

// MARK: - Region Status

enum RegionStatus: String, Codable, CaseIterable {
    case stable             // Normal operation
    case unrest             // Growing discontent
    case crisis             // Active problems requiring attention
    case rebellion          // Open resistance
    case seceding           // Actively attempting to leave
    case seceded            // Has left the union (game over if too many)
    case martial            // Under martial law

    var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .unrest: return "Unrest"
        case .crisis: return "Crisis"
        case .rebellion: return "Rebellion"
        case .seceding: return "Seceding"
        case .seceded: return "Seceded"
        case .martial: return "Martial Law"
        }
    }

    var severity: Int {
        switch self {
        case .stable: return 0
        case .unrest: return 1
        case .crisis: return 2
        case .rebellion: return 3
        case .seceding: return 4
        case .seceded: return 5
        case .martial: return 2 // Imposed order
        }
    }

    var color: String {
        switch self {
        case .stable: return "green"
        case .unrest: return "yellow"
        case .crisis: return "orange"
        case .rebellion: return "red"
        case .seceding: return "purple"
        case .seceded: return "gray"
        case .martial: return "black"
        }
    }
}

// MARK: - Region Governor

struct RegionGovernor: Codable, Identifiable {
    var id: String { characterId }
    var characterId: String
    var appointedTurn: Int
    var loyaltyToPlayer: Int        // -100 to 100
    var competence: Int             // 1-100
    var corruption: Int             // 1-100
    var localPopularity: Int        // 1-100
    var isPlayerAppointed: Bool

    init(characterId: String, turn: Int, loyaltyToPlayer: Int = 50, competence: Int = 50, isPlayerAppointed: Bool = false) {
        self.characterId = characterId
        self.appointedTurn = turn
        self.loyaltyToPlayer = loyaltyToPlayer
        self.competence = competence
        self.corruption = Int.random(in: 10...40)
        self.localPopularity = Int.random(in: 30...70)
        self.isPlayerAppointed = isPlayerAppointed
    }
}

// MARK: - Region Model

// Helper functions for JSON encoding/decoding outside of MainActor isolation
private func decodeRegionGovernor(from data: Data?) -> RegionGovernor? {
    guard let data = data else { return nil }
    return try? JSONDecoder().decode(RegionGovernor.self, from: data)
}

private func encodeRegionGovernor(_ governor: RegionGovernor?) -> Data? {
    try? JSONEncoder().encode(governor)
}

@Model
final class Region {
    @Attribute(.unique) var id: UUID
    var regionId: String                    // Unique identifier like "capital_district"
    var name: String
    var regionDescription: String
    var regionType: String                  // RegionType.rawValue
    var currentStatus: String               // RegionStatus.rawValue

    // Population and geography
    var population: Int                     // In millions
    var areaSize: Int                       // Relative size (1-10)
    var climate: String                     // Description
    var terrain: String                     // Description

    // Economic indicators
    var industrialCapacity: Int             // 0-100
    var agriculturalOutput: Int             // 0-100
    var naturalResources: Int               // 0-100, raw materials
    var infrastructureQuality: Int          // 0-100
    var economicContribution: Int           // % of national GDP

    // Political indicators
    var partyControl: Int                   // 0-100, Party strength
    var popularLoyalty: Int                 // 0-100, loyalty to the state
    var militaryPresence: Int               // 0-100, troops stationed
    var autonomyDesire: Int                 // 0-100, wish for independence

    // Secession mechanics
    var secessionProgress: Int              // 0-100, progress toward leaving
    var turnsInCurrentStatus: Int           // How long at current status

    // Historical/cultural
    var yearsInUnion: Int                   // How long part of the state
    var hasDistinctCulture: Bool            // Ethnic/cultural minorities
    var hasDistinctLanguage: Bool           // Language differences
    var historicalGrievances: [String]      // Past wrongs remembered

    // Governor (encoded)
    var governorData: Data?

    // JSON-encoded because SwiftData does not store [String: Int] directly
    var actionCooldownsData: Data?

    var hasEstablishedSEZ: Bool = false

    var game: Game?

    init(regionId: String, name: String, description: String, type: RegionType) {
        self.id = UUID()
        self.regionId = regionId
        self.name = name
        self.regionDescription = description
        self.regionType = type.rawValue
        self.currentStatus = RegionStatus.stable.rawValue

        self.population = 10
        self.areaSize = 5
        self.climate = ""
        self.terrain = ""

        self.industrialCapacity = 50
        self.agriculturalOutput = 50
        self.naturalResources = 50
        self.infrastructureQuality = 50
        self.economicContribution = 10

        self.partyControl = 70
        self.popularLoyalty = 60
        self.militaryPresence = 30
        self.autonomyDesire = 20

        self.secessionProgress = 0
        self.turnsInCurrentStatus = 0

        self.yearsInUnion = 50
        self.hasDistinctCulture = false
        self.hasDistinctLanguage = false
        self.historicalGrievances = []
    }

    // MARK: - Computed Properties

    var type: RegionType {
        RegionType(rawValue: regionType) ?? .industrial
    }

    var status: RegionStatus {
        get { RegionStatus(rawValue: currentStatus) ?? .stable }
        set { currentStatus = newValue.rawValue }
    }

    var governor: RegionGovernor? {
        get {
            decodeRegionGovernor(from: governorData)
        }
        set {
            governorData = encodeRegionGovernor(newValue)
        }
    }

    /// Overall stability score (higher = more stable)
    var stabilityScore: Int {
        let partyFactor = partyControl
        let loyaltyFactor = popularLoyalty
        let militaryFactor = militaryPresence / 2
        let autonomyPenalty = autonomyDesire
        let culturePenalty = (hasDistinctCulture ? 10 : 0) + (hasDistinctLanguage ? 10 : 0)

        return max(0, min(100, (partyFactor + loyaltyFactor + militaryFactor - autonomyPenalty - culturePenalty) / 2))
    }

    /// Risk of status deterioration (higher = more risk)
    var instabilityRisk: Int {
        100 - stabilityScore + (autonomyDesire / 2) + (historicalGrievances.count * 5)
    }

    /// Whether this region is in a dangerous state
    var isDangerous: Bool {
        status.severity >= 2
    }

    /// Whether region can potentially secede
    var canSecede: Bool {
        type != .capital && autonomyDesire > 50 && hasDistinctCulture
    }

    /// Estimated treasury contribution per turn from this region.
    /// Mirrors the domestic production formula in EconomyService plus a resource bonus by region type.
    var treasuryContribution: Int {
        let baseOutput = (industrialCapacity / 4) + (agriculturalOutput / 8)
        let loyaltyModifier = 0.6 + (Double(popularLoyalty) / 100.0) * 0.4
        let resourceBonus: Int = {
            switch type {
            case .extractive: return 15
            case .industrial: return 5
            case .border: return 3
            case .coastal: return 4
            default: return 0
            }
        }()
        return Int(Double(baseOutput) * loyaltyModifier) + resourceBonus
    }

    // MARK: - Action Cooldowns

    /// Decoded cooldown map: actionId -> turn available
    var actionCooldowns: [String: Int] {
        get {
            guard let data = actionCooldownsData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            actionCooldownsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Check whether a region-scoped action is currently on cooldown.
    func isActionOnCooldown(_ actionId: String, currentTurn: Int) -> Bool {
        guard let availableTurn = actionCooldowns[actionId] else { return false }
        return currentTurn < availableTurn
    }

    /// Remaining cooldown turns for a region-scoped action.
    func cooldownRemaining(_ actionId: String, currentTurn: Int) -> Int {
        guard let availableTurn = actionCooldowns[actionId] else { return 0 }
        return max(0, availableTurn - currentTurn)
    }

    /// Record a cooldown of `turns` on an action starting from `currentTurn`.
    func setActionCooldown(_ actionId: String, turns: Int, currentTurn: Int) {
        var map = actionCooldowns
        map[actionId] = currentTurn + turns
        actionCooldowns = map
    }

    // MARK: - Methods

    func updateSecessionProgress(nationalStability: Int, currentTurn: Int) {
        // Secession accelerates when:
        // - Low national stability
        // - High autonomy desire
        // - Low party control
        // - Status is rebellion or worse

        guard canSecede else {
            secessionProgress = 0
            return
        }

        var change = 0

        // Base pressure from autonomy desire
        if autonomyDesire > 70 {
            change += 3
        } else if autonomyDesire > 50 {
            change += 1
        }

        // National weakness accelerates secession
        if nationalStability < 30 {
            change += 5
        } else if nationalStability < 50 {
            change += 2
        }

        // Local conditions
        if partyControl < 30 {
            change += 3
        }
        if popularLoyalty < 30 {
            change += 2
        }

        // Status multiplier
        switch status {
        case .rebellion:
            change *= 2
        case .seceding:
            change *= 3
        case .martial:
            change = -5 // Military suppression
        case .stable:
            change = -2 // Slow regression
        default:
            break
        }

        secessionProgress = max(0, min(100, secessionProgress + change))

        // Update status based on progress
        if secessionProgress >= 100 {
            status = .seceded
        } else if secessionProgress >= 75 && status != .seceding {
            status = .seceding
        } else if secessionProgress >= 50 && status.severity < 3 {
            status = .rebellion
        }
    }

    func applyGovernorEffects() {
        guard let gov = governor else { return }

        // Competent governors improve things
        if gov.competence > 70 {
            partyControl = min(100, partyControl + 1)
            infrastructureQuality = min(100, infrastructureQuality + 1)
        } else if gov.competence < 30 {
            partyControl = max(0, partyControl - 1)
        }

        // Corrupt governors hurt loyalty
        if gov.corruption > 70 {
            popularLoyalty = max(0, popularLoyalty - 2)
        }

        // Popular governors help stability
        if gov.localPopularity > 70 {
            popularLoyalty = min(100, popularLoyalty + 1)
        }
    }

    func imposeMartialLaw() {
        status = .martial
        militaryPresence = min(100, militaryPresence + 30)
        partyControl = min(100, partyControl + 20)
        popularLoyalty = max(0, popularLoyalty - 15)
        autonomyDesire = min(100, autonomyDesire + 10)
    }

    func liftMartialLaw() {
        if status == .martial {
            if instabilityRisk > 60 {
                status = .crisis
            } else if instabilityRisk > 40 {
                status = .unrest
            } else {
                status = .stable
            }
            militaryPresence = max(0, militaryPresence - 20)
        }
    }
}

// MARK: - Default Zones

extension Region {

    /// Create the 7 default zones for a new game
    static func createDefaultRegions() -> [Region] {
        var regions: [Region] = []

        // ZONE 1: CAPITAL DISTRICT (The Capital)
        let capitalDistrict = Region(
            regionId: "zone_1",
            name: "Zone 1: Capital District",
            description: """
            The beating heart of the People's Socialist Republic. The capital city rises \
            from the central plains—a modernist monument to revolutionary power. \
            The Hall of the People dominates the skyline, its red star visible for miles. \
            The General Secretary's residence, government ministries, and Party headquarters \
            cluster in the Government Quarter.

            The capital was transformed after the Revolution. The old colonial mansions \
            now house workers' cultural centers. Massive housing blocks for government workers \
            surround the central district. The Bureau of People's Security maintains its \
            headquarters here, watching from every corner.

            Here the watchers are also watched. Every phone may be tapped, every conversation \
            noted. The privileged few shop in special Party stores while the masses wait in \
            lines. And yet, for all its contradictions, the Capital remains the prize everyone \
            seeks. To rise in the Party is to dream of these streets.
            """,
            type: .capital
        )
        capitalDistrict.population = 4
        capitalDistrict.areaSize = 1
        capitalDistrict.climate = "Temperate continental with warm summers and cold winters"
        capitalDistrict.terrain = "River valley, heavily urbanized"
        capitalDistrict.industrialCapacity = 40
        capitalDistrict.agriculturalOutput = 5
        capitalDistrict.naturalResources = 10
        capitalDistrict.infrastructureQuality = 90
        capitalDistrict.economicContribution = 15
        capitalDistrict.partyControl = 95
        capitalDistrict.popularLoyalty = 70
        capitalDistrict.militaryPresence = 80
        capitalDistrict.autonomyDesire = 5
        capitalDistrict.yearsInUnion = 43
        capitalDistrict.hasDistinctCulture = false
        capitalDistrict.hasDistinctLanguage = false
        regions.append(capitalDistrict)

        // ZONE 2: INDUSTRIAL ZONE (Fitzgerald City)
        let industrialZone = Region(
            regionId: "zone_2",
            name: "Zone 2: Industrial Zone",
            description: """
            The furnace of the Revolution. Fitzgerald City and the surrounding industrial belt \
            produce the steel, machinery, and weapons that power the socialist economy. \
            Smokestacks paint the sky gray; the hammers never stop ringing.

            This is where the workers first organized, where the unions first struck, where \
            the revolutionary militias were armed. The great factories here still bear the \
            scars of the civil war that brought the Party to power. The workers here are \
            proud, organized, and know their worth.

            The people here remember everything. They remember the old exploitation, the \
            strikes, the uprising. They remember which side they chose and what it cost. \
            The Party's hold is strong here, but it rests on genuine revolutionary history— \
            and the workers remember that history includes holding leaders accountable.
            """,
            type: .industrial
        )
        industrialZone.population = 45
        industrialZone.areaSize = 6
        industrialZone.climate = "Continental with cold winters and mild summers"
        industrialZone.terrain = "River valleys, industrial cities, coalfields"
        industrialZone.industrialCapacity = 95
        industrialZone.agriculturalOutput = 25
        industrialZone.naturalResources = 70
        industrialZone.infrastructureQuality = 80
        industrialZone.economicContribution = 32
        industrialZone.partyControl = 80
        industrialZone.popularLoyalty = 65
        industrialZone.militaryPresence = 45
        industrialZone.autonomyDesire = 15
        industrialZone.yearsInUnion = 43
        industrialZone.hasDistinctCulture = false
        industrialZone.hasDistinctLanguage = false
        industrialZone.historicalGrievances = ["Factory closures during reorganization", "Purge of union dissidents"]
        regions.append(industrialZone)

        // ZONE 3: AGRICULTURAL ZONE (The People's Proletarian Town)
        let agriculturalZone = Region(
            regionId: "zone_3",
            name: "Zone 3: Agricultural Zone",
            description: """
            The breadbasket of the Republic. From the wheat fields of the northern plains to \
            the collective farms around The People's Proletarian Town, Zone 3 feeds the nation. What were once \
            independent farms are now collective agricultural combines stretching to every horizon.

            The plains came to the Revolution reluctantly. Farmers here valued independence \
            above all—they mistrusted landowners but also mistrusted government. The promise \
            of land redistribution eventually won most over, but collectivization remained \
            bitter medicine. Many old farmers still mutter about the way things were.

            Distance defines life here. Towns are sparse, neighbors are far, and the capital \
            feels like another planet. The Party presence is thin—there simply aren't enough \
            cadres to watch these endless fields. People mind their own business and expect \
            the state to do the same. When it doesn't, resentment grows like wheat in summer.
            """,
            type: .agricultural
        )
        agriculturalZone.population = 25
        agriculturalZone.areaSize = 10
        agriculturalZone.climate = "Continental, extreme temperature swings"
        agriculturalZone.terrain = "Vast plains, river valleys, few cities"
        agriculturalZone.industrialCapacity = 25
        agriculturalZone.agriculturalOutput = 95
        agriculturalZone.naturalResources = 40
        agriculturalZone.infrastructureQuality = 50
        agriculturalZone.economicContribution = 15
        agriculturalZone.partyControl = 55
        agriculturalZone.popularLoyalty = 50
        agriculturalZone.militaryPresence = 25
        agriculturalZone.autonomyDesire = 45
        agriculturalZone.yearsInUnion = 43
        agriculturalZone.hasDistinctCulture = true
        agriculturalZone.hasDistinctLanguage = false
        agriculturalZone.historicalGrievances = [
            "Forced collectivization",
            "Destruction of family farms",
            "Grain requisitions during the crisis years",
            "Suppression of farm cooperatives"
        ]
        regions.append(agriculturalZone)

        // ZONE 4: NORTHERN ZONE (Upton on Tye)
        let northernZone = Region(
            regionId: "zone_4",
            name: "Zone 4: Northern Zone",
            description: """
            The frozen frontier. Upton on Tye and the northern territories supply timber, minerals, \
            and serve as the Republic's strategic buffer. The climate is harsh; the population \
            sparse; the land unforgiving.

            The north was settled by pioneers, political exiles, and those seeking to escape \
            the reach of any government. The Revolution brought little change to daily life— \
            the struggle against nature overshadows political concerns. Mining towns dot the \
            taiga; labor camps occupy the most remote valleys.

            The people here are tough, independent, and suspicious. Many fled here to escape \
            the old order; others fled here to escape the new one. The Party's reach is \
            limited by geography—there aren't enough roads, enough radios, enough eyes to \
            watch these forests. What happens in the north often stays there.
            """,
            type: .extractive
        )
        northernZone.population = 8
        northernZone.areaSize = 10
        northernZone.climate = "Subarctic with long, severe winters"
        northernZone.terrain = "Taiga forests, mountains, tundra"
        northernZone.industrialCapacity = 35
        northernZone.agriculturalOutput = 10
        northernZone.naturalResources = 85
        northernZone.infrastructureQuality = 35
        northernZone.economicContribution = 8
        northernZone.partyControl = 50
        northernZone.popularLoyalty = 45
        northernZone.militaryPresence = 55
        northernZone.autonomyDesire = 50
        northernZone.yearsInUnion = 43
        northernZone.hasDistinctCulture = true
        northernZone.hasDistinctLanguage = false
        northernZone.historicalGrievances = [
            "Labor camp system",
            "Displacement of indigenous peoples",
            "Resource extraction without local benefit"
        ]
        regions.append(northernZone)

        // ZONE 5: COASTAL ZONE (Red Harbor)
        let coastalZone = Region(
            regionId: "zone_5",
            name: "Zone 5: Coastal Zone",
            description: """
            The Republic's window to the world. Red Harbor and the coastal cities handle \
            foreign trade with socialist allies and neutral nations. The shipyards here build \
            the vessels that project socialist power across the seas.

            The coast came to the Revolution through its workers—longshoremen, sailors, and \
            shipyard laborers who seized the ports from within. Now the docks bustle with \
            trade: machinery from the Soviet Union, grain exports to friendly nations, and \
            the constant movement of a planned economy.

            The Coastal Zone has always attracted dreamers and misfits. Artists, writers, and \
            dissidents cluster here, testing the boundaries of acceptable expression. The Party \
            watches but sometimes looks away—the zone's economic importance buys it some latitude.
            """,
            type: .coastal
        )
        coastalZone.population = 20
        coastalZone.areaSize = 5
        coastalZone.climate = "Maritime, mild year-round with frequent fog"
        coastalZone.terrain = "Coastal plains, port cities, fishing villages"
        coastalZone.industrialCapacity = 70
        coastalZone.agriculturalOutput = 40
        coastalZone.naturalResources = 45
        coastalZone.infrastructureQuality = 75
        coastalZone.economicContribution = 18
        coastalZone.partyControl = 65
        coastalZone.popularLoyalty = 55
        coastalZone.militaryPresence = 60
        coastalZone.autonomyDesire = 30
        coastalZone.yearsInUnion = 43
        coastalZone.hasDistinctCulture = true
        coastalZone.hasDistinctLanguage = false
        coastalZone.historicalGrievances = [
            "Post-revolution property seizures",
            "Suppression of merchant families",
            "Cultural purges"
        ]
        regions.append(coastalZone)

        // ZONE 6: MOUNTAIN ZONE (Highland)
        let mountainZone = Region(
            regionId: "zone_6",
            name: "Zone 6: Mountain Zone",
            description: """
            The Republic's spine and its secrets. The mountain ranges supply coal, copper, \
            iron, and uranium—the raw materials that keep the socialist economy running. \
            Remote valleys hide military installations and "rehabilitation centers" where \
            enemies of the people disappear.

            Highland and the mining towns are rough, isolated, self-reliant. Miners work \
            dangerous shifts deep underground. Ranchers run collective livestock operations \
            on slopes too steep for farming. The military maintains bases that test weapons \
            never officially acknowledged.

            The mountains create natural fortresses and natural prisons. Some here chose \
            isolation; others had it imposed. The Party's authority ends where the roads end— \
            and roads end quickly in the mountains.
            """,
            type: .extractive
        )
        mountainZone.population = 12
        mountainZone.areaSize = 8
        mountainZone.climate = "Highland continental, cold winters, mild summers"
        mountainZone.terrain = "Mountains, high plateaus, deep valleys"
        mountainZone.industrialCapacity = 50
        mountainZone.agriculturalOutput = 20
        mountainZone.naturalResources = 90
        mountainZone.infrastructureQuality = 40
        mountainZone.economicContribution = 10
        mountainZone.partyControl = 55
        mountainZone.popularLoyalty = 45
        mountainZone.militaryPresence = 65
        mountainZone.autonomyDesire = 50
        mountainZone.yearsInUnion = 43
        mountainZone.hasDistinctCulture = true
        mountainZone.hasDistinctLanguage = true
        mountainZone.historicalGrievances = [
            "Labor camp system",
            "Displacement of mountain communities",
            "Suppression of traditional practices",
            "Resource extraction without compensation"
        ]
        regions.append(mountainZone)

        // ZONE 7: BORDER ZONE (The Frontier)
        let borderZone = Region(
            regionId: "zone_7",
            name: "Zone 7: Border Zone",
            description: """
            The frontier where ideologies meet. The Frontier and the border territories face \
            the outside world—neutral neighbors, potential enemies, and constant tension. \
            Military installations line the frontier; border guards patrol day and night.

            The border zone is a place of contradictions. Official trade flows through customs \
            posts; unofficial trade flows through smugglers' paths. Ideological broadcasts blast \
            across the border in both directions. Refugees try to leave; agents try to enter.

            The people here live in a permanent state of alertness. Some are true believers, \
            manning the ramparts of socialism. Others are opportunists, profiting from the \
            border's peculiar economy. Many simply wish to live in peace—a wish the frontier \
            rarely grants.
            """,
            type: .border
        )
        borderZone.population = 15
        borderZone.areaSize = 7
        borderZone.climate = "Varied, temperate to continental"
        borderZone.terrain = "Plains, forests, strategic passes"
        borderZone.industrialCapacity = 40
        borderZone.agriculturalOutput = 50
        borderZone.naturalResources = 35
        borderZone.infrastructureQuality = 60
        borderZone.economicContribution = 8
        borderZone.partyControl = 70
        borderZone.popularLoyalty = 55
        borderZone.militaryPresence = 85
        borderZone.autonomyDesire = 35
        borderZone.yearsInUnion = 43
        borderZone.hasDistinctCulture = true
        borderZone.hasDistinctLanguage = false
        borderZone.historicalGrievances = [
            "Forced population relocations",
            "Military occupation of farmland",
            "Restrictions on border crossings"
        ]
        regions.append(borderZone)

        return regions
    }
}

// MARK: - Region Lore

/// Deep historical lore for each zone
struct RegionLore: Codable, Identifiable {
    var id: String { regionId }
    var regionId: String
    var revolutionaryHistory: [ZoneHistoricalEvent]
    var localHeroes: [LocalFigure]
    var localVillains: [LocalFigure]
    var hiddenTruths: [ZoneSecret]
    var culturalNotes: [String]
    var undergroundActivity: [String]
}

struct ZoneHistoricalEvent: Codable, Identifiable {
    var id: String
    var name: String
    var era: String
    var description: String
    var officialNarrative: String
    var hiddenTruth: String?
    var casualties: Int?
    var keyFigures: [String] // character ids
    var isDiscoverable: Bool
}

struct LocalFigure: Codable, Identifiable {
    var id: String
    var name: String
    var role: String
    var fate: String // alive, executed, exiled, disappeared
    var description: String
    var isRemembered: Bool // officially celebrated or erased
}

struct ZoneSecret: Codable, Identifiable {
    var id: String
    var title: String
    var content: String
    var discoveryMethod: String
    var consequences: String
}

/// Provider for zone-specific lore
class RegionLoreProvider {
    static let shared = RegionLoreProvider()

    private var lore: [String: RegionLore] = [:]

    private init() {
        loadLore()
    }

    func getLore(for regionId: String) -> RegionLore? {
        return lore[regionId]
    }

    private func loadLore() {
        lore["zone_1"] = createCapitalLore()
        lore["zone_2"] = createIndustrialLore()
        lore["zone_3"] = createAgriculturalLore()
        lore["zone_4"] = createNorthernLore()
        lore["zone_5"] = createCoastalLore()
        lore["zone_6"] = createMountainLore()
        lore["zone_7"] = createBorderLore()
    }

    // MARK: - Capital District Lore

    private func createCapitalLore() -> RegionLore {
        return RegionLore(
            regionId: "zone_1",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "fall_capital",
                    name: "The Fall of the Old Capital",
                    era: "at the Revolution's end",
                    description: "Revolutionary forces entered the capital after the old government fled.",
                    officialNarrative: "The workers claimed their rightful seat of power. The old regime fled rather than face the justice of the people.",
                    hiddenTruth: "The 'orderly transition' involved three days of score-settling. Sensitive files were secured before the rest were burned. Several hundred officials who didn't flee in time were 'processed.'",
                    casualties: 2000,
                    keyFigures: ["wallace", "fitzgerald"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "peoples_congress",
                    name: "First People's Congress",
                    era: "at the Revolution's end",
                    description: "The People's Congress convened in the former Parliament Building, now the Hall of the People.",
                    officialNarrative: "A new dawn for democracy. The representatives of workers, farmers, and soldiers gathered to build a new society.",
                    hiddenTruth: "The 'elections' were tightly controlled. Dissenting candidates were intimidated or arrested. The Congress rubber-stamped decisions already made by the Central Committee.",
                    casualties: nil,
                    keyFigures: ["fitzgerald", "mitchell"],
                    isDiscoverable: true
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "fitzgerald_capital",
                    name: "Chairman Robert Fitzgerald",
                    role: "First General Secretary",
                    fate: "Died mysteriously years later",
                    description: "Father of Socialist Republic. His portrait hangs in every government building. His death remains officially unexplained.",
                    isRemembered: true
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "old_president",
                    name: "The Last President",
                    role: "Last Leader of the Old Regime",
                    fate: "Died in exile",
                    description: "Symbol of the old order's failure. His name is used to frighten children.",
                    isRemembered: true
                ),
                LocalFigure(
                    id: "blackwood_capital",
                    name: "Director Samuel Blackwood",
                    role: "First BPS Director",
                    fate: "Died in accident after the Purges",
                    description: "Built the security apparatus. His methods were 'excessive' even by Party standards. His death was 'fortunate timing.'",
                    isRemembered: false
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "blackwood_files",
                    title: "Blackwood's Hidden Archive",
                    content: "Before his death, Blackwood hid copies of his most sensitive files. They contain evidence of fabricated confessions. If found, they would expose the Purges as manufactured terror.",
                    discoveryMethod: "Investigation of Blackwood's former associates, tracking pre-Purge BPS procedures",
                    consequences: "Could delegitimize the entire security apparatus. Wallace would do anything to prevent their discovery."
                ),
                ZoneSecret(
                    id: "fitzgerald_medical",
                    title: "Fitzgerald's Medical Records",
                    content: "Chairman Fitzgerald's medical records were sealed by order of the new General Secretary. They would show that Fitzgerald was ill but recovering—not dying—when he 'had a heart attack.' The attending physician was transferred to the Northern Zone shortly after.",
                    discoveryMethod: "Access to sealed medical archives, locating the physician",
                    consequences: "Would prove Fitzgerald was murdered. Would implicate Mitchell and Wallace."
                )
            ],
            culturalNotes: [
                "Revolution Day parades draw millions. Attendance is 'voluntary' but noted.",
                "The National Museum now houses exhibits on the crimes of the old regime.",
                "The old aristocratic quarter is now Party housing for senior officials. Proximity to the center equals power.",
                "The river still floods occasionally. The Party claims to have 'tamed nature.' Nature disagrees."
            ],
            undergroundActivity: [
                "Small circles of former intellectuals meet privately to discuss 'forbidden' philosophy.",
                "Some old families maintain hidden memories of the pre-Revolutionary order.",
                "Diplomatic staff from foreign embassies are constantly watched—and sometimes recruited.",
                "The black market for Western goods runs through diplomatic channels."
            ]
        )
    }

    // MARK: - Industrial Zone Lore

    private func createIndustrialLore() -> RegionLore {
        return RegionLore(
            regionId: "zone_2",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "stahlgrad_strike",
                    name: "The Great Strike",
                    era: "during the Revolution",
                    description: "Workers across the industrial belt walked out in a coordinated general strike that paralyzed the old regime's economy.",
                    officialNarrative: "The workers showed the path forward. United, the proletariat is unstoppable.",
                    hiddenTruth: "The strike's leaders were later purged as 'deviationists.' Their names have been erased from official histories.",
                    casualties: 47,
                    keyFigures: ["sheridan"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "battle_foundry_city",
                    name: "The Battle of Fitzgerald City",
                    era: "during the Revolution",
                    description: "The most intense urban warfare of the Civil War. Weeks of block-by-block fighting.",
                    officialNarrative: "The workers, led by the People's Army, liberated the city in a heroic struggle.",
                    hiddenTruth: "The fighting was brutal beyond official accounts. Both sides committed atrocities. The unity of the workers was real but fragile.",
                    casualties: 40000,
                    keyFigures: ["carter", "fletcher", "thompson", "bodine", "strickland"],
                    isDiscoverable: true
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "steele_industrial",
                    name: "General Marcus Steele",
                    role: "Commander of Revolutionary Forces",
                    fate: "Executed during the Purges",
                    description: "The greatest military leader of the Revolution. Too popular, too independent. His execution haunts everyone who knew him.",
                    isRemembered: false
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "industrial_baron",
                    name: "The Factory Lords",
                    role: "Industrial Magnates",
                    fate: "Fled or executed",
                    description: "The capitalist owners who exploited workers for generations. Their mansions are now workers' cultural centers.",
                    isRemembered: true
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "steele_confession",
                    title: "Steele Never Confessed",
                    content: "At the Trial of the Thirty-Six, General Steele was the only defendant who never signed a confession. Despite weeks of 'enhanced interrogation,' he maintained his innocence until execution. The official transcripts were falsified.",
                    discoveryMethod: "Original trial transcripts (if they exist), testimony from surviving officials",
                    consequences: "Would prove the Trial was a sham. Would implicate those who testified against Steele."
                )
            ],
            culturalNotes: [
                "The industrial cities maintain distinct working-class identities despite official melting-pot rhetoric.",
                "The old union halls are now official Party buildings, but the same families often run them.",
                "Factory towns still produce, but quotas drive everything."
            ],
            undergroundActivity: [
                "Veterans of the civil war maintain informal networks. They remember events differently than official history.",
                "Some union locals preserve pre-Revolution traditions that don't align with Party orthodoxy.",
                "Old workers remember the purged leaders and whisper about 'accidents.'"
            ]
        )
    }

    // MARK: - Agricultural Zone Lore

    private func createAgriculturalLore() -> RegionLore {
        return RegionLore(
            regionId: "zone_3",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "great_collectivization",
                    name: "The Great Collectivization",
                    era: "during the early years",
                    description: "Family farms were consolidated into collective agricultural operations.",
                    officialNarrative: "Scientific socialism came to agriculture. The chaos of individual farming gave way to planned abundance.",
                    hiddenTruth: "Collectivization was brutal. Farmers who resisted were labeled 'class enemies' and sent to camps. Families who had worked the land for generations lost everything.",
                    casualties: nil,
                    keyFigures: ["armstrong", "erickson"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "the_famine",
                    name: "The Crisis Years Famine",
                    era: "during the Purges",
                    description: "Thousands died when impossible quotas collided with drought.",
                    officialNarrative: "Does not exist in official history.",
                    hiddenTruth: "The famine killed thousands. Officials produced statistics showing bumper crops while people starved. The dead were buried in unmarked graves.",
                    casualties: 15000,
                    keyFigures: ["erickson", "kowalski"],
                    isDiscoverable: true
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "folk_singer",
                    name: "The People's Poet",
                    role: "Folk Singer",
                    fate: "Alive, official cultural figure",
                    description: "Songs celebrated workers and criticized the old order. Now an approved artist, but some earlier, angrier songs are no longer performed.",
                    isRemembered: true
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "kulak_class",
                    name: "The Kulak Class",
                    role: "Wealthy Farmers",
                    fate: "Exiled or executed",
                    description: "Not individuals but a class enemy. Anyone who resisted collectivization could be labeled a kulak.",
                    isRemembered: true
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "famine_records",
                    title: "The Real Numbers",
                    content: "Somewhere in the State Planning Commission, original data survives—the numbers that were suppressed, showing crop failures, starvation, and death. If they surfaced, they would prove the Party caused a famine and covered it up.",
                    discoveryMethod: "Access to Planning Commission archives, cooperation from key officials",
                    consequences: "Would be politically devastating. Could fuel demands for reform—or rebellion."
                ),
                ZoneSecret(
                    id: "hidden_harvests",
                    title: "The Underground Grain",
                    content: "Local governors run systematic underreporting schemes. Farmers hide portions of their harvests from the official count. The 'hidden' grain is distributed locally to prevent starvation. It's technically theft from the state. It's also why people don't starve.",
                    discoveryMethod: "Spending time with farmers, gaining local trust",
                    consequences: "Could be used to destroy officials—or to build alliances. The farmers would protect their protectors fiercely."
                )
            ],
            culturalNotes: [
                "The farming communities remember their family land with grief. The collectives bear numbers, not names.",
                "Religious practice is officially discouraged but quietly maintained—especially among older farmers.",
                "The vast distances create de facto autonomy. Party cadres are sparse; neighbors watch out for each other."
            ],
            undergroundActivity: [
                "Farmers maintain informal networks to protect each other from quota enforcers.",
                "Some families still visit the unmarked graves of the famine dead.",
                "Underground religious services happen in farmhouses far from any road."
            ]
        )
    }

    // MARK: - Northern Zone Lore

    private func createNorthernLore() -> RegionLore {
        return RegionLore(
            regionId: "zone_4",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "camp_system_north",
                    name: "Establishment of the Northern Camps",
                    era: "shortly after the Revolution",
                    description: "Political prisoners and 'class enemies' were sent to labor camps throughout the Northern Zone.",
                    officialNarrative: "Rehabilitation through labor. Enemies of the people contribute to socialist construction.",
                    hiddenTruth: "The camps are death sentences for many. Hard labor, brutal conditions. Some survive; many don't.",
                    casualties: nil,
                    keyFigures: ["wallace"],
                    isDiscoverable: true
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "warren_north",
                    name: "The Exiled Revolutionary",
                    role: "Former Revolutionary Leader",
                    fate: "Alive under assumed name",
                    description: "Lives in a mining town as a schoolteacher. Some know who she really is. She waits.",
                    isRemembered: false
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "camp_commanders",
                    name: "The Camp Commanders",
                    role: "Labor Camp Administration",
                    fate: "Various",
                    description: "Anonymous by design. Their faces are not recorded. Their names are classified.",
                    isRemembered: false
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "camp_deaths",
                    title: "The Real Body Count",
                    content: "The labor camps have killed tens of thousands. The official records list 'transfers' and 'releases' that never happened. Mass graves dot the remote valleys.",
                    discoveryMethod: "Testimony from released prisoners, accessing classified camp records",
                    consequences: "Would expose the camp system as mass murder. Would force the Party to either reform or double down."
                )
            ],
            culturalNotes: [
                "The mining towns are rough, isolated, self-reliant. Party authority ends at the town limits.",
                "Indigenous communities exist in uneasy relationship with the state.",
                "The vast distances create spaces where people can disappear—willingly or not."
            ],
            undergroundActivity: [
                "Released prisoners form informal networks, sharing information about who didn't come out.",
                "Some camps have internal resistance—work slowdowns, information smuggling.",
                "Indigenous communities preserve traditions the Party has tried to eliminate."
            ]
        )
    }

    // MARK: - Coastal Zone Lore

    private func createCoastalLore() -> RegionLore {
        return RegionLore(
            regionId: "zone_5",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "harbor_rising",
                    name: "The Harbor Rising",
                    era: "during the Revolution",
                    description: "Waterfront workers seized the port cities from within.",
                    officialNarrative: "The longshoremen opened the door to liberation.",
                    hiddenTruth: nil,
                    casualties: 3000,
                    keyFigures: [],
                    isDiscoverable: false
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "harbor_leader",
                    name: "The Harbor Leader",
                    role: "Longshoremen's Union Leader",
                    fate: "Died (natural causes)",
                    description: "Organized the coastal ports. A genuine hero remembered fondly.",
                    isRemembered: true
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "shipping_magnates",
                    name: "The Shipping Magnates",
                    role: "Maritime Capitalists",
                    fate: "Fled or exiled",
                    description: "The old shipping families who controlled trade. Their mansions are now workers' rest homes.",
                    isRemembered: true
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "smuggling_networks",
                    title: "The Shadow Trade",
                    content: "Despite official controls, extensive smuggling networks operate through the ports. Some Party officials take cuts. Some use the networks to move people—dissidents out, agents in.",
                    discoveryMethod: "Working with port officials, following suspicious shipments",
                    consequences: "Could expose corruption—or provide useful leverage and connections."
                )
            ],
            culturalNotes: [
                "The port cities maintain cosmopolitan traditions despite official nationalism.",
                "Sailors bring news and goods from the outside world.",
                "The arts scene pushes boundaries of acceptable expression."
            ],
            undergroundActivity: [
                "Artists and writers push boundaries.",
                "Some maintain contacts with exile communities abroad.",
                "Smuggling networks operate with varying degrees of official tolerance."
            ]
        )
    }

    // MARK: - Mountain Zone Lore

    private func createMountainLore() -> RegionLore {
        return RegionLore(
            regionId: "zone_6",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "camp_system_mountain",
                    name: "The Mountain Camps",
                    era: "shortly after the Revolution",
                    description: "The most remote camps were established in mountain valleys, far from prying eyes.",
                    officialNarrative: "Rehabilitation facilities for enemies of the people.",
                    hiddenTruth: "The mountain camps are the worst. Uranium mining, hard labor in extreme conditions. Mortality rates are highest here.",
                    casualties: 5000,
                    keyFigures: [],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "nuclear_project",
                    name: "The Special Project",
                    era: "post-Revolution",
                    description: "The Republic developed atomic capabilities using mountain zone resources.",
                    officialNarrative: "Socialist science achieved what capitalism could not—a deterrent to protect the Revolution.",
                    hiddenTruth: "The project used prison labor for the most dangerous mining. Thousands died of radiation exposure. Their sacrifice is not acknowledged.",
                    casualties: 5000,
                    keyFigures: [],
                    isDiscoverable: true
                )
            ],
            localHeroes: [],
            localVillains: [
                LocalFigure(
                    id: "mountain_commanders",
                    name: "The Mountain Camp Commanders",
                    role: "Labor Camp Administration",
                    fate: "Various",
                    description: "Anonymous by design. The worst assignments go here.",
                    isRemembered: false
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "radiation_deaths",
                    title: "The Uranium Miners",
                    content: "Prisoners forced to mine uranium without protection died by the thousands. The symptoms—hair loss, bleeding, slow death—were classified as 'industrial accidents.'",
                    discoveryMethod: "Medical records, testimony from survivors (rare)",
                    consequences: "Would expose the human cost of the nuclear program."
                ),
                ZoneSecret(
                    id: "hidden_witness",
                    title: "The Hidden Witness",
                    content: "A physician who treated Chairman Fitzgerald in his final days was 'transferred' to a mountain medical facility. He knows what really happened. He has been waiting for someone to ask.",
                    discoveryMethod: "Tracing medical personnel transfers, locating the facility",
                    consequences: "His testimony could prove Fitzgerald was murdered."
                )
            ],
            culturalNotes: [
                "The mining towns are rough, isolated, self-reliant.",
                "Mountain communities maintain traditions despite official pressure.",
                "The vast distances create spaces beyond Party control."
            ],
            undergroundActivity: [
                "Released prisoners form networks.",
                "Some camps have internal resistance.",
                "Mountain communities preserve forbidden traditions."
            ]
        )
    }

    // MARK: - Border Zone Lore

    private func createBorderLore() -> RegionLore {
        return RegionLore(
            regionId: "zone_7",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "border_war",
                    name: "The Border Consolidation",
                    era: "during the Revolution",
                    description: "Revolutionary forces secured the borders against intervention.",
                    officialNarrative: "The defenders of the Revolution held the line against capitalist aggression.",
                    hiddenTruth: "Some communities were forcibly relocated. Suspected collaborators were dealt with harshly.",
                    casualties: 2000,
                    keyFigures: [],
                    isDiscoverable: true
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "border_commander",
                    name: "The Border Hero",
                    role: "Revolutionary Commander",
                    fate: "Died in service",
                    description: "Defended the frontier during the dark days. Officially honored, genuinely respected.",
                    isRemembered: true
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "collaborators",
                    name: "The Collaborators",
                    role: "Those who aided foreign powers",
                    fate: "Executed or exiled",
                    description: "Some communities are still tainted by association with those who helped the enemy.",
                    isRemembered: true
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "border_trade",
                    title: "The Grey Economy",
                    content: "Extensive unofficial trade crosses the border. Some officials profit; some look the other way; some actively facilitate. The official economy couldn't function without it.",
                    discoveryMethod: "Working with border officials, following suspicious transactions",
                    consequences: "Could expose corruption—or provide useful economic flexibility."
                )
            ],
            culturalNotes: [
                "Border communities maintain connections across the line despite official restrictions.",
                "Military culture dominates many towns.",
                "Smuggling is an open secret."
            ],
            undergroundActivity: [
                "Cross-border family connections persist.",
                "Smuggling networks operate with varying degrees of tolerance.",
                "Some communities maintain forbidden contacts with the outside world."
            ]
        )
    }
}

// MARK: - Region Event Types

enum RegionEventType: String, Codable, CaseIterable {
    case laborStrike            // Workers demanding better conditions
    case ethnicTension          // Cultural/ethnic conflict
    case religiousRevival       // Underground religious activity
    case smugglingRing          // Black market operations
    case partyCorruption        // Local officials abusing power
    case infrastructureFailure  // Dam breaks, factory explosions
    case naturalDisaster        // Flood, earthquake, drought
    case borderIncident         // Clash with foreign power
    case sabotage               // Industrial sabotage
    case demonstration          // Public protest
    case militaryMutiny         // Troops refusing orders
    case secessionMovement      // Independence activists

    var displayName: String {
        switch self {
        case .laborStrike: return "Labor Strike"
        case .ethnicTension: return "Ethnic Tension"
        case .religiousRevival: return "Religious Revival"
        case .smugglingRing: return "Smuggling Ring"
        case .partyCorruption: return "Party Corruption"
        case .infrastructureFailure: return "Infrastructure Failure"
        case .naturalDisaster: return "Natural Disaster"
        case .borderIncident: return "Border Incident"
        case .sabotage: return "Industrial Sabotage"
        case .demonstration: return "Public Demonstration"
        case .militaryMutiny: return "Military Mutiny"
        case .secessionMovement: return "Secession Movement"
        }
    }

    var severity: Int {
        switch self {
        case .laborStrike, .smugglingRing, .partyCorruption: return 1
        case .ethnicTension, .religiousRevival, .demonstration: return 2
        case .infrastructureFailure, .naturalDisaster, .sabotage: return 3
        case .borderIncident, .militaryMutiny: return 4
        case .secessionMovement: return 5
        }
    }
}
