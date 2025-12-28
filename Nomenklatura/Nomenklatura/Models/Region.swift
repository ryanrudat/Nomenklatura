//
//  Region.swift
//  Nomenklatura
//
//  Domestic zones of the United States of the People's Socialist Republic with secession mechanics
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

        // ZONE 7: CAPITAL DISTRICT (Washington D.C.)
        let capitalDistrict = Region(
            regionId: "capital_district",
            name: "Zone 7: Capital District",
            description: """
            The beating heart of the United States of the People's Socialist Republic. Where \
            once the Capitol dome stood as a symbol of bourgeois democracy, now the People's \
            Congress meets in the renamed Hall of the Revolution. The White House serves as \
            the General Secretary's residence, its rooms echoing with decisions that shape \
            a continent.

            Washington was transformed after the Second Revolution. The old monuments remain \
            but serve new purposes—the Lincoln Memorial hosts Party rallies, the Mall fills \
            with workers' parades on Revolution Day. New construction surrounds the old: \
            massive housing blocks for government workers, Party headquarters with modernist \
            angles, the imposing Bureau of People's Security watching from every corner.

            Here the watchers are also watched. Every phone may be tapped, every conversation \
            noted. The privileged few shop in special Party stores while the masses wait in \
            lines. And yet, for all its contradictions, the Capital remains the prize everyone \
            seeks. To rise in the Party is to dream of these streets.
            """,
            type: .capital
        )
        capitalDistrict.population = 4
        capitalDistrict.areaSize = 1
        capitalDistrict.climate = "Humid subtropical with hot summers and mild winters"
        capitalDistrict.terrain = "Potomac River valley, heavily urbanized"
        capitalDistrict.industrialCapacity = 40
        capitalDistrict.agriculturalOutput = 5
        capitalDistrict.naturalResources = 10
        capitalDistrict.infrastructureQuality = 90
        capitalDistrict.economicContribution = 15
        capitalDistrict.partyControl = 95
        capitalDistrict.popularLoyalty = 70
        capitalDistrict.militaryPresence = 80
        capitalDistrict.autonomyDesire = 5
        capitalDistrict.yearsInUnion = 20
        capitalDistrict.hasDistinctCulture = false
        capitalDistrict.hasDistinctLanguage = false
        regions.append(capitalDistrict)

        // ZONE 1: NORTHEAST INDUSTRIAL ZONE
        let northeast = Region(
            regionId: "northeast",
            name: "Zone 1: Northeast Industrial Zone",
            description: """
            The cradle of the Second American Revolution. From Boston to Philadelphia, from \
            the textile mills of New England to the shipyards of New York Harbor, this is \
            where the workers first marched, where the unions first organized, where Hoover's \
            troops first fired on American citizens—and where the Revolution fired back.

            The great cities here still bear the scars of the civil war. Bullet holes pock \
            the facades of Wall Street, now home to the Central Planning Commission. The \
            factories that once made capitalists rich now fulfill the People's quotas. Union \
            halls that organized secret strikes are now official Party meeting places, their \
            histories carefully curated.

            The people here remember everything. They remember the Triangle Shirtwaist fire, \
            the Bread and Roses strike, the March on Washington. They remember which side \
            they chose and what it cost. The Party's hold is strong here, but it rests on \
            genuine revolutionary history—and the workers remember that history includes \
            holding leaders accountable.
            """,
            type: .industrial
        )
        northeast.population = 45
        northeast.areaSize = 6
        northeast.climate = "Humid continental with cold winters and warm summers"
        northeast.terrain = "Coastal cities, river valleys, rolling hills"
        northeast.industrialCapacity = 90
        northeast.agriculturalOutput = 25
        northeast.naturalResources = 40
        northeast.infrastructureQuality = 80
        northeast.economicContribution = 28
        northeast.partyControl = 80
        northeast.popularLoyalty = 65
        northeast.militaryPresence = 45
        northeast.autonomyDesire = 15
        northeast.yearsInUnion = 20
        northeast.hasDistinctCulture = false
        northeast.hasDistinctLanguage = false
        northeast.historicalGrievances = ["Factory closures during reorganization", "Purge of Trotskyist elements after the Purges"]
        regions.append(northeast)

        // ZONE 2: GREAT LAKES INDUSTRIAL ZONE
        let greatLakes = Region(
            regionId: "great_lakes",
            name: "Zone 2: Great Lakes Zone",
            description: """
            The Arsenal of the Revolution. Detroit, Cleveland, Chicago, Milwaukee—these \
            cities forged the weapons that won the civil war and now build the machines \
            that power the socialist economy. The auto plants of Detroit were converted \
            to tank production in '38; they never fully converted back.

            The United Auto Workers were the shock troops of the Revolution here. When \
            the call came, assembly line workers became soldiers, foremen became officers, \
            and the factories became fortresses. The Battle of Chicago decided the war's \
            outcome—three weeks of street fighting that left the city scarred but firmly \
            in revolutionary hands.

            Today the steel mills of Gary paint the sky orange, the foundries of Cleveland \
            never stop pouring, and the assembly lines of Detroit roll out tractors for \
            collective farms. The workers here are proud, organized, and know their worth. \
            They also know that the Party needs them more than they need the Party—a fact \
            that makes Zone leadership perpetually nervous.
            """,
            type: .industrial
        )
        greatLakes.population = 35
        greatLakes.areaSize = 7
        greatLakes.climate = "Humid continental with cold winters, lake-effect snow"
        greatLakes.terrain = "Lakeshores, industrial cities, farmland"
        greatLakes.industrialCapacity = 95
        greatLakes.agriculturalOutput = 35
        greatLakes.naturalResources = 70
        greatLakes.infrastructureQuality = 75
        greatLakes.economicContribution = 25
        greatLakes.partyControl = 75
        greatLakes.popularLoyalty = 60
        greatLakes.militaryPresence = 40
        greatLakes.autonomyDesire = 20
        greatLakes.yearsInUnion = 20
        greatLakes.hasDistinctCulture = false
        greatLakes.hasDistinctLanguage = false
        greatLakes.historicalGrievances = ["Battle of Chicago casualties", "post-war quota strikes suppressed"]
        regions.append(greatLakes)

        // ZONE 3: PACIFIC ZONE
        let pacific = Region(
            regionId: "pacific",
            name: "Zone 3: Pacific Zone",
            description: """
            America's window to Asia and gateway to the Pacific. The ports of Seattle, \
            Portland, San Francisco, and Los Angeles handle the Republic's trade with \
            Asian allies and neutral nations. The shipyards here build the vessels that \
            project socialist power across the ocean.

            California came late to the Revolution—Hollywood moguls and agricultural \
            barons resisted until the bitter end. The siege of Los Angeles lasted two \
            months; San Francisco's waterfront workers rose from within. Now the studios \
            produce socialist realism, the orange groves are collective farms, and the \
            tech workshops of the Bay Area serve the Planning Commission's needs.

            The Pacific Zone has always attracted dreamers and misfits, and that hasn't \
            changed. Artists, writers, and dissidents cluster here, testing the boundaries \
            of acceptable expression. The Party watches but sometimes looks away—creativity \
            serves the Revolution too, even when it makes the censors uncomfortable.
            """,
            type: .coastal
        )
        pacific.population = 30
        pacific.areaSize = 8
        pacific.climate = "Mediterranean to marine, mild year-round"
        pacific.terrain = "Coastal mountains, valleys, port cities"
        pacific.industrialCapacity = 70
        pacific.agriculturalOutput = 65
        pacific.naturalResources = 50
        pacific.infrastructureQuality = 75
        pacific.economicContribution = 18
        pacific.partyControl = 65
        pacific.popularLoyalty = 55
        pacific.militaryPresence = 55
        pacific.autonomyDesire = 30
        pacific.yearsInUnion = 20
        pacific.hasDistinctCulture = true
        pacific.hasDistinctLanguage = false
        pacific.historicalGrievances = [
            "Siege of Los Angeles",
            "Internment of 'reactionary elements'",
            "Suppression of Japanese-American communities",
            "Hollywood purges"
        ]
        regions.append(pacific)

        // ZONE 4: SOUTHERN ZONE
        let southern = Region(
            regionId: "southern",
            name: "Zone 4: Southern Zone",
            description: """
            The most complicated zone in the Republic. The old Confederacy—already defeated \
            once in American history—found itself on the wrong side again. Southern governors \
            who called out the National Guard against workers' marches discovered that many \
            of those guardsmen were workers too.

            The Revolution here was as much about race as class. Black sharecroppers and \
            white factory workers found common cause against the planter aristocracy. The \
            old order fell, but its ghosts remain. Jim Crow is officially dead, but suspicion \
            and resentment linger in both directions. The Party struggles to build a truly \
            interracial socialism while managing generations of mistrust.

            The South's economy has been transformed—collective farms replace plantations, \
            new industries rise in the Sunbelt, and the old wealth has been redistributed \
            (or fled to exile). But culture changes slower than economics. The accents, \
            the food, the music, the religion—all persist despite official pressure. The \
            South bends but does not break.
            """,
            type: .autonomous
        )
        southern.population = 40
        southern.areaSize = 9
        southern.climate = "Humid subtropical, hot summers, mild winters"
        southern.terrain = "Coastal plains, piedmont, river deltas"
        southern.industrialCapacity = 50
        southern.agriculturalOutput = 80
        southern.naturalResources = 55
        southern.infrastructureQuality = 55
        southern.economicContribution = 12
        southern.partyControl = 60
        southern.popularLoyalty = 45
        southern.militaryPresence = 50
        southern.autonomyDesire = 55
        southern.yearsInUnion = 20
        southern.hasDistinctCulture = true
        southern.hasDistinctLanguage = false
        southern.historicalGrievances = [
            "Civil war destruction",
            "Forced collectivization of farms",
            "Suppression of religious institutions",
            "Execution of 'counter-revolutionary' landowners"
        ]
        regions.append(southern)

        // ZONE 5: PLAINS AGRICULTURAL ZONE
        let plains = Region(
            regionId: "plains",
            name: "Zone 5: Plains Zone",
            description: """
            The breadbasket of the Republic. From the wheat fields of the Dakotas to the \
            corn belt of Kansas and Nebraska, the Plains Zone feeds the nation. What were \
            once family farms and corporate agribusiness operations are now collective \
            farms and state agricultural combines stretching to every horizon.

            The Plains came to the Revolution reluctantly. Farmers here valued independence \
            above all—they mistrusted corporations but also mistrusted government. The \
            promise of debt relief and land redistribution eventually won most over, but \
            collectivization remained bitter medicine. Many old farmers still mutter about \
            the way things were.

            Distance defines life here. Towns are sparse, neighbors are far, and Washington \
            feels like another planet. The Party presence is thin—there simply aren't enough \
            cadres to watch these endless fields. People mind their own business and expect \
            the state to do the same. When it doesn't, resentment grows like wheat in summer.
            """,
            type: .agricultural
        )
        plains.population = 15
        plains.areaSize = 10
        plains.climate = "Continental, extreme temperature swings, tornadoes"
        plains.terrain = "Vast prairies, river valleys, few cities"
        plains.industrialCapacity = 25
        plains.agriculturalOutput = 95
        plains.naturalResources = 40
        plains.infrastructureQuality = 50
        plains.economicContribution = 10
        plains.partyControl = 55
        plains.popularLoyalty = 50
        plains.militaryPresence = 25
        plains.autonomyDesire = 45
        plains.yearsInUnion = 20
        plains.hasDistinctCulture = true
        plains.hasDistinctLanguage = false
        plains.historicalGrievances = [
            "Forced collectivization",
            "Destruction of family farms",
            "during the Purges grain requisitions",
            "Suppression of farm cooperatives"
        ]
        regions.append(plains)

        // ZONE 6: MOUNTAIN ZONE
        let mountain = Region(
            regionId: "mountain",
            name: "Zone 6: Mountain Zone",
            description: """
            The Republic's frontier. From the Rockies to the Sierra Nevada, from the copper \
            mines of Montana to the uranium deposits of New Mexico, the Mountain Zone \
            supplies the raw materials that keep the socialist economy running. It also \
            provides a convenient place to send those who need to disappear.

            The Zone is vast and sparsely populated. Miners work the earth for coal, copper, \
            gold, and uranium. Ranchers run collective cattle operations on ranges too dry \
            for farming. Military bases dot the desert, testing weapons that will never be \
            officially acknowledged. Prison labor camps—"rehabilitation centers"—occupy the \
            most remote valleys.

            The people here are tough, independent, and suspicious. Many fled here to escape \
            the old order; others fled here to escape the new one. The Party's reach is \
            limited by geography—there aren't enough roads, enough radios, enough eyes to \
            watch these mountains. What happens in the high country often stays there.
            """,
            type: .extractive
        )
        mountain.population = 12
        mountain.areaSize = 10
        mountain.climate = "High altitude continental, cold winters, mild summers"
        mountain.terrain = "Mountains, high desert, canyons"
        mountain.industrialCapacity = 45
        mountain.agriculturalOutput = 20
        mountain.naturalResources = 90
        mountain.infrastructureQuality = 40
        mountain.economicContribution = 10
        mountain.partyControl = 55
        mountain.popularLoyalty = 45
        mountain.militaryPresence = 60
        mountain.autonomyDesire = 50
        mountain.yearsInUnion = 20
        mountain.hasDistinctCulture = true
        mountain.hasDistinctLanguage = false
        mountain.historicalGrievances = [
            "Labor camp system",
            "Displacement of ranchers",
            "Nuclear testing on native lands",
            "Water rights seizures"
        ]
        regions.append(mountain)

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
        lore["capital_district"] = createCapitalLore()
        lore["northeast"] = createNortheastLore()
        lore["great_lakes"] = createGreatLakesLore()
        lore["pacific"] = createPacificLore()
        lore["southern"] = createSouthernLore()
        lore["plains"] = createPlainsLore()
        lore["mountain"] = createMountainLore()
    }

    // MARK: - Capital District Lore

    private func createCapitalLore() -> RegionLore {
        return RegionLore(
            regionId: "capital_district",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "fall_washington",
                    name: "The Fall of Washington",
                    era: "at the Revolution's end",
                    description: "Revolutionary forces entered the capital after Hoover fled aboard USS Yorktown to Cuba.",
                    officialNarrative: "The workers of America claimed their rightful seat of power. President Hoover, representative of the bourgeois class, fled rather than face the justice of the people.",
                    hiddenTruth: "The 'orderly transition' involved three days of looting and score-settling. Wallace's operatives secured government files before burning the rest. Several hundred federal employees who didn't flee in time were 'processed.'",
                    casualties: 2000,
                    keyFigures: ["wallace", "fitzgerald"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "peoples_congress",
                    name: "First People's Congress",
                    era: "at the Revolution's end",
                    description: "The People's Congress convened in the former Capitol Building, now the Hall of Revolution.",
                    officialNarrative: "A new dawn for American democracy. The representatives of workers, farmers, and soldiers gathered to build a new society.",
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
                    description: "Father of Socialist America. His portrait hangs in every government building. His death remains officially unexplained.",
                    isRemembered: true
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "hoover_capital",
                    name: "President Herbert Hoover",
                    role: "Last Capitalist President",
                    fate: "Exiled to Cuba, died in exile",
                    description: "Symbol of the old order's failure. His name is used to frighten children: 'Behave, or Hoover will come back.'",
                    isRemembered: true
                ),
                LocalFigure(
                    id: "blackwood_capital",
                    name: "Director Samuel Blackwood",
                    role: "First BPS Director",
                    fate: "Died in car accident after the Purges",
                    description: "Built the security apparatus. His methods were 'excessive' even by Party standards. His death was 'fortunate timing.'",
                    isRemembered: false
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "blackwood_files",
                    title: "Blackwood's Hidden Archive",
                    content: "Before his death, Blackwood hid copies of his most sensitive files. They contain evidence of fabricated confessions, including details of the Trial of the Thirty-Six. The files are somewhere in the capital—in a dead drop, a safety deposit box, or a trusted friend's keeping. If found, they would expose the Purges as manufactured terror.",
                    discoveryMethod: "Investigation of Blackwood's former associates, tracking pre-after the Purges BPS procedures",
                    consequences: "Could delegitimize the entire security apparatus. Wallace would do anything to prevent their discovery."
                ),
                ZoneSecret(
                    id: "fitzgerald_medical",
                    title: "Fitzgerald's Medical Records",
                    content: "Chairman Fitzgerald's medical records from March years later were sealed by order of the new General Secretary. They would show that Fitzgerald was ill but recovering—not dying—when he 'had a heart attack' on March 14. The attending physician, Dr. Petrov, was transferred to the Mountain Zone shortly after and has not been heard from since.",
                    discoveryMethod: "Access to sealed medical archives, locating Dr. Petrov",
                    consequences: "Would prove Fitzgerald was murdered. Would implicate Mitchell and Wallace."
                )
            ],
            culturalNotes: [
                "Revolution Day parades on the Mall draw millions. Attendance is 'voluntary' but noted.",
                "The Smithsonian now houses the Museum of Capitalist Crimes alongside traditional exhibits.",
                "The old Georgetown mansions are Party housing for senior officials. Proximity to the center equals power.",
                "The Potomac still floods occasionally. The Party claims to have 'tamed nature.' Nature disagrees."
            ],
            undergroundActivity: [
                "Small circles of ex-academics meet privately to discuss 'forbidden' philosophy.",
                "Some old families maintain hidden shrines to the pre-Revolutionary order.",
                "Diplomatic staff from foreign embassies are constantly watched—and sometimes recruited.",
                "The black market for Western goods runs through diplomatic channels."
            ]
        )
    }

    // MARK: - Northeast Lore

    private func createNortheastLore() -> RegionLore {
        return RegionLore(
            regionId: "northeast",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "boston_strike",
                    name: "The Boston General Strike",
                    era: "during the Revolution",
                    description: "Elizabeth 'Red Betty' Warren led 200,000 workers in a three-week general strike that shut down the city.",
                    officialNarrative: "The workers of Boston showed the nation the path forward. United, the proletariat is unstoppable.",
                    hiddenTruth: "Red Betty Warren was later purged as a 'Trotskyist.' Her name has been erased from official histories. The Boston General Strike is now attributed to 'the workers' with no individual credit.",
                    casualties: 47,
                    keyFigures: ["sheridan"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "march_washington",
                    name: "The March on Washington",
                    era: "during the Revolution",
                    description: "200,000 workers marched from industrial cities to Washington. The National Guard fired on marchers. 'Bloody Sunday' started the war.",
                    officialNarrative: "The capitalist state revealed its true nature when it murdered peaceful workers. The Revolution was born in their blood.",
                    hiddenTruth: "Some marchers were armed. The first shots may have come from either side—no one is certain. Fitzgerald led the Philadelphia column; his courage under fire became legend.",
                    casualties: 200,
                    keyFigures: ["fitzgerald", "mitchell"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "triangle_occupation",
                    name: "The Triangle Factory Occupation",
                    era: "during the Revolution",
                    description: "Workers at the Triangle Shirtwaist Factory (rebuilt after the infamous fire) seized and held the plant for three weeks.",
                    officialNarrative: "The workers reclaimed the site of capitalism's greatest crime and made it a fortress of revolution.",
                    hiddenTruth: "The occupation was a media stunt. The real fighting was at the docks, where Sheridan's longshoremen held the harbor.",
                    casualties: 12,
                    keyFigures: ["sheridan"],
                    isDiscoverable: false
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "warren_northeast",
                    name: "Elizabeth 'Red Betty' Warren",
                    role: "Revolutionary Orator, Boston Strike Leader",
                    fate: "Exiled to Mountain Zone during the Purges, status unknown",
                    description: "The firebrand who shut down Boston. Her speeches still circulate as samizdat. Possessing them is dangerous.",
                    isRemembered: false
                ),
                LocalFigure(
                    id: "brennan_northeast",
                    name: "Father Michael Brennan",
                    role: "Revolutionary Priest",
                    fate: "Executed during the Purges",
                    description: "Catholic priest who joined the Revolution. Recruited young Eleanor Patterson. Denounced as a 'Vatican spy' during the Religious Roundup.",
                    isRemembered: false
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "morgan_northeast",
                    name: "J.P. Morgan III",
                    role: "Wall Street Financier",
                    fate: "Fled to London during the Revolution",
                    description: "Symbol of the old financial aristocracy. His townhouse is now a workers' cultural center.",
                    isRemembered: true
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "warren_alive",
                    title: "Red Betty Lives",
                    content: "Elizabeth Warren was not executed. She was exiled to a mining town in the Mountain Zone under an assumed name. She is now in her fifties, working as a schoolteacher. Some Party members know. They visit occasionally, seeking her blessing for their plans. Her speeches still circulate underground.",
                    discoveryMethod: "Following the underground network of old Boston revolutionaries, questioning Mountain Zone miners",
                    consequences: "Finding Warren alive would be a political earthquake. Her testimony about the original Revolution's ideals vs. current reality could inspire reform—or rebellion."
                ),
                ZoneSecret(
                    id: "brennan_children",
                    title: "The Brennan Orphans",
                    content: "Father Brennan's three children—Margaret, Michael Jr., and Thomas—were sent to state orphanages after his execution. Patterson has never learned what happened to them. Margaret is now a factory worker in the Great Lakes Zone. Michael Jr. died of illness in the orphanage. Thomas was adopted by a Party family and has risen to a mid-level position—he doesn't know his real father's identity.",
                    discoveryMethod: "Orphanage records, Patterson's investigation if she ever has the courage",
                    consequences: "If Patterson discovered Thomas Brennan's survival and current position, it could be used as leverage—or as an opportunity for redemption."
                )
            ],
            culturalNotes: [
                "Boston's Irish community maintains underground Catholic practice. The Party knows and tolerates it—within limits.",
                "New York's old ethnic neighborhoods—Little Italy, Chinatown, Harlem—retain their character despite official 'integration' policies.",
                "Philadelphia's revolutionary history makes it almost as politically sensitive as the capital.",
                "The old Ivy League universities are now Party training academies. Harvard yard still has its charm, but the curriculum is different."
            ],
            undergroundActivity: [
                "Samizdat copies of Red Betty Warren's speeches circulate among old revolutionaries.",
                "Irish and Italian communities maintain unofficial Catholic networks.",
                "Jewish cultural organizations operate semi-legally, carefully avoiding religious content.",
                "Old union veterans remember different stories than the official histories tell."
            ]
        )
    }

    // MARK: - Great Lakes Lore

    private func createGreatLakesLore() -> RegionLore {
        return RegionLore(
            regionId: "great_lakes",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "battle_chicago",
                    name: "The Battle of Chicago",
                    era: "during the Revolution",
                    description: "The most intense urban warfare of the Civil War. Three months of block-by-block fighting. 40,000+ dead on both sides.",
                    officialNarrative: "The workers of Chicago, led by General Steele and the People's Army, liberated the city in a heroic struggle. The federal forces were broken; the Midwest was won.",
                    hiddenTruth: "The fighting was brutal beyond official accounts. Both sides committed atrocities. General Steele refused to execute prisoners; his subordinates often did anyway. The Black workers' militias and white ethnic union forces fought side by side—a unity that terrified the old order and sometimes surprised both groups.",
                    casualties: 40000,
                    keyFigures: ["carter", "fletcher", "thompson", "bodine", "strickland"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "siege_detroit",
                    name: "The Siege of Detroit",
                    era: "during the Revolution",
                    description: "90-day winter siege. Auto workers held the city against National Guard encirclement until Soviet weapons arrived.",
                    officialNarrative: "The workers of Detroit, birthplace of the auto industry, proved that the means of production belong to those who operate them.",
                    hiddenTruth: "The siege was won with Soviet help—weapons, advisors, and supplies smuggled through Mexico. The official history minimizes this foreign assistance. Bodine saw the crates with Cyrillic writing. He's never told anyone.",
                    casualties: 15000,
                    keyFigures: ["bodine"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "gary_mutiny",
                    name: "The Gary Steel Mutiny",
                    era: "during the Revolution",
                    description: "Workers at Gary Steel Works refused orders to execute captured federal prisoners.",
                    officialNarrative: "Not officially remembered.",
                    hiddenTruth: "The workers' refusal to commit atrocities is quietly celebrated in local memory. The Party doesn't discuss it because it raises uncomfortable questions about what happened elsewhere.",
                    casualties: 0,
                    keyFigures: [],
                    isDiscoverable: true
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "steele_greatlakes",
                    name: "General Marcus Steele",
                    role: "Commander of Revolutionary Forces, Hero of Chicago",
                    fate: "Executed during the Purges (Trial of the Thirty-Six)",
                    description: "The greatest military leader of the Revolution. Too popular, too independent. His execution haunts everyone who knew him.",
                    isRemembered: false
                ),
                LocalFigure(
                    id: "reuther_greatlakes",
                    name: "Walter Reuther",
                    role: "UAW Leader",
                    fate: "Died years later (plane crash, suspicious circumstances)",
                    description: "Organized the Detroit auto plants. His death cleared the path for more 'reliable' union leadership.",
                    isRemembered: true
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "ford_greatlakes",
                    name: "Henry Ford II",
                    role: "Auto Baron",
                    fate: "Fled to Brazil at the Revolution's end",
                    description: "His grandfather's anti-Semitism and anti-union violence made the Ford name synonymous with capitalist evil.",
                    isRemembered: true
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "steele_confession",
                    title: "Steele Never Confessed",
                    content: "At the Trial of the Thirty-Six, General Steele was the only defendant who never signed a confession. Despite weeks of 'enhanced interrogation' supervised by Wallace and Edwards, he maintained his innocence until execution. The official transcripts were falsified to suggest otherwise. Steele's final words—'I die a socialist, not a traitor'—were never recorded.",
                    discoveryMethod: "Original trial transcripts (if they exist), testimony from Edwards or Wallace",
                    consequences: "Would prove the Trial was a sham. Would implicate Carter and Fletcher, who testified against Steele."
                ),
                ZoneSecret(
                    id: "soviet_weapons",
                    title: "The Soviet Arsenal",
                    content: "The Revolution was won with significant Soviet military aid—weapons, ammunition, advisors. This assistance was channeled through Mexico to maintain the fiction of a purely American revolution. The Soviets expected payment in influence. That bill is still being collected.",
                    discoveryMethod: "Bodine's memory, surviving weapons caches with Cyrillic markings, diplomatic archives",
                    consequences: "Would undermine the narrative of American revolutionary independence. Would embarrass the Party's claims of self-reliance."
                )
            ],
            culturalNotes: [
                "Chicago's jazz and blues scene survived the Revolution. The Party considers it 'proletarian music.'",
                "Polish, Irish, and Black communities in the industrial cities maintain distinct identities despite official melting-pot rhetoric.",
                "The old ethnic union halls are now official Party buildings, but the same families often run them.",
                "Detroit's auto plants still produce, but for tractors and trucks rather than consumer cars."
            ],
            undergroundActivity: [
                "Veterans of the Chicago battle maintain informal networks. They remember Steele differently than the official history.",
                "Some union locals preserve pre-Revolution traditions that don't align with Party orthodoxy.",
                "The Black churches that sustained workers during the Depression continue, carefully avoiding political sermons.",
                "Old UAW members remember Reuther and whisper about his 'accident.'"
            ]
        )
    }

    // MARK: - Pacific Lore (abbreviated)

    private func createPacificLore() -> RegionLore {
        return RegionLore(
            regionId: "pacific",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "siege_la",
                    name: "The Siege of Los Angeles",
                    era: "during the Revolution",
                    description: "Two-month siege before Hollywood and the agricultural barons surrendered.",
                    officialNarrative: "The workers of California broke the last bastion of bourgeois culture.",
                    hiddenTruth: "The siege included significant naval bombardment. Civilian casualties were higher than admitted. Many 'war criminals' were executed without trial.",
                    casualties: 8000,
                    keyFigures: [],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "sf_rising",
                    name: "The San Francisco Rising",
                    era: "during the Revolution",
                    description: "Waterfront workers seized the city from within while federal forces focused on Los Angeles.",
                    officialNarrative: "The longshoremen of San Francisco opened the door to liberation.",
                    hiddenTruth: nil,
                    casualties: 3000,
                    keyFigures: [],
                    isDiscoverable: false
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "bridges_pacific",
                    name: "Harry Bridges",
                    role: "Longshoremen's Union Leader",
                    fate: "Died later (natural causes)",
                    description: "Organized the Pacific Coast ports. A genuine hero remembered fondly.",
                    isRemembered: true
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "hearst_pacific",
                    name: "William Randolph Hearst",
                    role: "Media Baron",
                    fate: "Died in exile",
                    description: "His newspapers opposed the Revolution. His castle at San Simeon is now a 'Museum of Capitalist Excess.'",
                    isRemembered: true
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "japanese_internment",
                    title: "The Second Internment",
                    content: "During the Intervention War, Japanese-Americans were again interned—this time by the socialist government—as potential fifth columnists for Japan. The camps were in the Mountain Zone. Some never returned. This history is not taught.",
                    discoveryMethod: "Mountain Zone records, surviving internees",
                    consequences: "Would expose the Party's hypocrisy on racial equality."
                )
            ],
            culturalNotes: [
                "Hollywood now produces socialist realism. Some films are genuinely artistic; most are propaganda.",
                "The Bay Area's counterculture has transformed into approved 'revolutionary creativity.'",
                "California wine country produces for Party elites. Ordinary citizens drink domestic beer.",
                "Asian-American communities maintain cultural traditions while carefully avoiding political connections to foreign powers."
            ],
            undergroundActivity: [
                "Artists and writers push boundaries of acceptable expression.",
                "Some Hollywood veterans maintain contacts with exile communities in Mexico.",
                "The tech workshops in the Bay Area occasionally produce unauthorized innovations.",
                "Japanese-American families quietly remember the Second Internment."
            ]
        )
    }

    // MARK: - Southern Lore

    private func createSouthernLore() -> RegionLore {
        return RegionLore(
            regionId: "southern",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "atlanta_liberation",
                    name: "Liberation Day (Atlanta)",
                    era: "during the Revolution",
                    description: "Revolutionary forces entered Atlanta as the old order collapsed.",
                    officialNarrative: "The South was liberated from the twin oppressions of capitalism and racism.",
                    hiddenTruth: "The 'liberation' included significant score-settling. Both Black and white communities had old grievances. Some lynchings went the other direction for a few terrible weeks.",
                    casualties: 5000,
                    keyFigures: [],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "birmingham_trial",
                    name: "The Birmingham Confession",
                    era: "at the Revolution's end",
                    description: "Bull Connor, infamous sheriff, was put on public trial for crimes against Black citizens.",
                    officialNarrative: "Revolutionary justice punished the oppressors and showed that a new day had come.",
                    hiddenTruth: "The trial was a show. The verdict was predetermined. Some who testified against Connor were later purged themselves. Justice was selective.",
                    casualties: nil,
                    keyFigures: [],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "sharecropper_uprising",
                    name: "The Sharecropper Uprising",
                    era: "during the Revolution",
                    description: "Black and white sharecroppers united against the planter class across Alabama, Mississippi, and Georgia.",
                    officialNarrative: "Class consciousness overcame racial division as workers recognized their common enemy.",
                    hiddenTruth: "The unity was real but fragile. Old hatreds surfaced repeatedly. The Party exploited both groups' resentments. The planters were defeated, but racial healing was superficial.",
                    casualties: 3000,
                    keyFigures: [],
                    isDiscoverable: true
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "parks_southern",
                    name: "Rosa Parks",
                    role: "Labor and Civil Rights Organizer",
                    fate: "Alive, low-profile position in Alabama",
                    description: "Organized before the Revolution. Supported integration. Later questioned some Party policies. Now carefully apolitical.",
                    isRemembered: true
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "talmadge_southern",
                    name: "Eugene Talmadge",
                    role: "Georgia Governor",
                    fate: "Executed at the Revolution's end",
                    description: "Symbol of Jim Crow resistance. His execution was broadcast on radio.",
                    isRemembered: true
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "black_church_deal",
                    title: "The Black Church Compromise",
                    content: "During the Religious Roundup, Black churches were largely spared while white churches were aggressively suppressed. This was a deliberate Party decision—the Black church was too central to community organizing to destroy. The compromise was never acknowledged; officially, all religion was treated equally.",
                    discoveryMethod: "Comparing arrest records, interviewing elderly ministers",
                    consequences: "Would expose the Party's pragmatic hypocrisy on religion. Could be used by both religious advocates and anti-religious hardliners."
                ),
                ZoneSecret(
                    id: "integration_limits",
                    title: "The Segregation Continues",
                    content: "Despite official integration, Southern housing, schooling, and social life remain largely segregated by 'voluntary choice' and economic factors the Party has never seriously addressed. The racial revolution was economic, not social. Most Black and white Southerners still live in separate worlds.",
                    discoveryMethod: "Any honest observation of Southern life",
                    consequences: "Would embarrass the Party's claims of racial progress. Could fuel both reformist and radical movements."
                )
            ],
            culturalNotes: [
                "Southern cooking, music, and hospitality survive despite official disapproval of 'regional sentiment.'",
                "Black culture—blues, gospel, literature—flourishes as approved 'proletarian expression.'",
                "White Southern culture is more suppressed, associated with the old order's racism.",
                "The accent, the pace of life, the manners—the South remains the South."
            ],
            undergroundActivity: [
                "White evangelical churches operate underground, remembering the Religious Roundup.",
                "Old Confederate families maintain private memories of the Lost Cause (now twice-lost).",
                "Some Black communities remember that the Revolution's promises remain unfulfilled.",
                "The Klan is dead, but its children remember. Some have channeled resentment into the system; others wait."
            ]
        )
    }

    // MARK: - Plains Lore

    private func createPlainsLore() -> RegionLore {
        return RegionLore(
            regionId: "plains",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "great_collectivization",
                    name: "The Great Collectivization",
                    era: "during the early Purges",
                    description: "Family farms were consolidated into collective agricultural operations across the Plains.",
                    officialNarrative: "Scientific socialism came to American agriculture. The chaos of individual farming gave way to planned abundance.",
                    hiddenTruth: "Collectivization was brutal. Farmers who resisted were labeled 'kulaks'—class enemies—and sent to camps. Families who had worked the land for generations lost everything. Some fought back; they lost. Armstrong survived by denouncing his neighbors.",
                    casualties: nil,
                    keyFigures: ["armstrong", "erickson"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "kansas_famine",
                    name: "The Kansas Famine",
                    era: "during the Purges",
                    description: "Thousands died when impossible quotas and forced collectivization collided with drought.",
                    officialNarrative: "Does not exist in official history.",
                    hiddenTruth: "The famine killed thousands—Laura Erickson's brother among them. Kowalski's office produced statistics showing bumper crops while people starved. The dead were buried in unmarked graves. Their names are not remembered. The official population figures for during the Purges don't match the during the Purges numbers—but no one is allowed to notice.",
                    casualties: 15000,
                    keyFigures: ["erickson", "kowalski"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "dust_bowl_redemption",
                    name: "The Dust Bowl Redemption",
                    era: "after the Purges",
                    description: "Party-directed conservation efforts began healing the land destroyed by capitalist farming.",
                    officialNarrative: "Socialist science succeeded where capitalist greed had failed. The Plains were redeemed.",
                    hiddenTruth: "The conservation programs were real and sometimes effective. But the same Party that caused the during the Purges famine claimed credit for healing the land. The farmers know both stories.",
                    casualties: nil,
                    keyFigures: [],
                    isDiscoverable: false
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "woody_plains",
                    name: "Woody Guthrie",
                    role: "Folk Singer",
                    fate: "Alive, official cultural figure",
                    description: "His songs celebrated workers and criticized the old order. He's now an approved artist, but some of his earlier, angrier songs are no longer performed.",
                    isRemembered: true
                )
            ],
            localVillains: [
                LocalFigure(
                    id: "kulaks_plains",
                    name: "The Kulak Class",
                    role: "Wealthy Farmers",
                    fate: "Exiled or executed",
                    description: "Not individuals but a class enemy. Anyone who resisted collectivization could be labeled a kulak. The definition was flexible—dangerously so.",
                    isRemembered: true
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "famine_records",
                    title: "The Real Numbers",
                    content: "Somewhere in the State Planning Commission, original data from the during the Purges harvest survives—the numbers Kowalski suppressed, showing crop failures, starvation, and death. Laura Erickson has spent years trying to find them. Anthony Carpenter knows they exist. If they surfaced, they would prove the Party caused a famine and covered it up.",
                    discoveryMethod: "Access to Planning Commission archives, cooperation from Carpenter or Erickson",
                    consequences: "Would be politically devastating. Would implicate Kowalski directly. Could fuel demands for reform—or rebellion."
                ),
                ZoneSecret(
                    id: "hidden_harvests_plains",
                    title: "The Underground Grain",
                    content: "Governor Armstrong runs a systematic underreporting scheme. Farmers hide portion of their harvests from the official count. The 'hidden' grain is distributed locally to prevent the starvation that official quotas would cause. It's technically theft from the state. It's also why people don't starve.",
                    discoveryMethod: "Spending time with Plains farmers, gaining Armstrong's trust",
                    consequences: "Could be used to destroy Armstrong—or to build an alliance. The farmers would protect him fiercely."
                )
            ],
            culturalNotes: [
                "The farming communities remember their family land with grief. The collectives bear numbers, not names.",
                "Church attendance is officially discouraged but quietly maintained—especially among older farmers.",
                "The vast distances create de facto autonomy. Party cadres are sparse; neighbors watch out for each other.",
                "Folk music traditions continue, carefully avoiding political content."
            ],
            undergroundActivity: [
                "Farmers maintain informal networks to protect each other from quota enforcers.",
                "Some families still visit the unmarked graves of the during the Purges dead.",
                "Underground church services happen in farmhouses far from any road.",
                "The hidden harvest system operates with tacit local BPS approval—they live here too."
            ]
        )
    }

    // MARK: - Mountain Lore

    private func createMountainLore() -> RegionLore {
        return RegionLore(
            regionId: "mountain",
            revolutionaryHistory: [
                ZoneHistoricalEvent(
                    id: "camp_system",
                    name: "Establishment of the Camp System",
                    era: "shortly after the Revolution",
                    description: "Political prisoners and 'class enemies' were sent to labor camps throughout the Mountain Zone.",
                    officialNarrative: "Rehabilitation through labor. Enemies of the people contribute to socialist construction.",
                    hiddenTruth: "The camps are death sentences for many. Uranium mining, hard labor, brutal conditions. Some survive; many don't. The exact numbers are classified. Estimates range from 50,000 to 200,000 currently incarcerated.",
                    casualties: nil,
                    keyFigures: ["wallace"],
                    isDiscoverable: true
                ),
                ZoneHistoricalEvent(
                    id: "uranium_project",
                    name: "The Manhattan Project (Socialist Version)",
                    era: "after the Purges",
                    description: "The Republic developed its own atomic weapons using Mountain Zone uranium and captured German scientists.",
                    officialNarrative: "Socialist science achieved what capitalism could not—an atomic deterrent to protect the Revolution.",
                    hiddenTruth: "The project used prison labor for the most dangerous mining. Thousands died of radiation exposure. Their sacrifice is not acknowledged.",
                    casualties: 5000,
                    keyFigures: [],
                    isDiscoverable: true
                )
            ],
            localHeroes: [
                LocalFigure(
                    id: "warren_mountain",
                    name: "Elizabeth 'Red Betty' Warren",
                    role: "Exiled Revolutionary",
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
                    description: "Anonymous by design. Their faces are not recorded. Their names are classified. They do what the system requires.",
                    isRemembered: false
                )
            ],
            hiddenTruths: [
                ZoneSecret(
                    id: "camp_deaths",
                    title: "The Real Body Count",
                    content: "The labor camps have killed tens of thousands. The official records list 'transfers' and 'releases' that never happened. Mass graves dot the remote valleys. The uranium mines are especially deadly—radiation sickness kills slowly. Some camps have mortality rates above 30% annually.",
                    discoveryMethod: "Testimony from released prisoners, accessing classified camp records",
                    consequences: "Would expose the camp system as mass murder. Would fuel international condemnation. Would force the Party to either reform or double down."
                ),
                ZoneSecret(
                    id: "dr_petrov",
                    title: "Dr. Petrov's Location",
                    content: "Dr. Petrov, the physician who treated Chairman Fitzgerald in his final days, was 'transferred' to a Mountain Zone medical facility in years later. He is alive, working in Camp 17's infirmary. He knows what really happened to Fitzgerald. He has been waiting for someone to ask.",
                    discoveryMethod: "Tracing medical personnel transfers, locating Camp 17",
                    consequences: "Petrov's testimony could prove Fitzgerald was murdered. Wallace knows where he is—and that he's still alive."
                )
            ],
            culturalNotes: [
                "The mining towns are rough, isolated, self-reliant. Party authority ends at the town limits.",
                "Native American communities exist in uneasy relationship with the state. Some reservations have semi-autonomous status.",
                "The vast distances create spaces where people can disappear—willingly or not.",
                "Mormon communities in Utah maintain their faith more openly than most religious groups, through careful negotiation with authorities."
            ],
            undergroundActivity: [
                "Released prisoners form informal networks, sharing information about who didn't come out.",
                "Some camps have internal resistance—work slowdowns, information smuggling.",
                "Red Betty Warren maintains contact with old comrades through careful channels.",
                "Native American communities preserve traditions the Party has tried to eliminate.",
                "Mormon networks extend across zone boundaries, providing mutual aid."
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
