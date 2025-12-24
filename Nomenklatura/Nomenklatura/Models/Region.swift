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
        northeast.historicalGrievances = ["Factory closures during reorganization", "Purge of Trotskyist elements 1945"]
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
        greatLakes.historicalGrievances = ["Battle of Chicago casualties", "1947 quota strikes suppressed"]
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
            "1943 grain requisitions",
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
