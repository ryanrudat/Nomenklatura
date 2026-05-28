//
//  ForeignCountry.swift
//  Nomenklatura
//
//  Foreign nations for diplomacy, trade, and international events
//  The world is circa 1950/1951 with real nations; the PSR is a fictional socialist state
//

import Foundation
import SwiftData

// MARK: - Political Bloc

enum PoliticalBloc: String, Codable, CaseIterable {
    case socialist      // Allied with the player's nation
    case capitalist     // Western liberal democracies
    case nonAligned     // Independent nations
    case rival          // Socialist but opposed to player

    var displayName: String {
        switch self {
        case .socialist: return "Socialist Bloc"
        case .capitalist: return "Capitalist Bloc"
        case .nonAligned: return "Non-Aligned Movement"
        case .rival: return "Rival Socialist Power"
        }
    }

    var description: String {
        switch self {
        case .socialist:
            return "Nations aligned with the Soviet Union and friendly to the People's Socialist Republic through ideological solidarity"
        case .capitalist:
            return "Capitalist powers led by the United States and Western European nations, united in opposition to communism"
        case .nonAligned:
            return "Nations refusing to join either superpower bloc, pursuing independent paths amid Cold War pressures"
        case .rival:
            return "Communist nations that chart their own path to socialism, sometimes competing with Soviet leadership"
        }
    }

    var color: String {
        switch self {
        case .socialist: return "red"
        case .capitalist: return "blue"
        case .nonAligned: return "green"
        case .rival: return "orange"
        }
    }
}

// MARK: - Government Type

enum GovernmentType: String, Codable, CaseIterable {
    case communistState         // Single-party communist
    case socialistRepublic      // Socialist with some pluralism
    case liberalDemocracy       // Western-style democracy
    case constitutionalMonarchy // Monarch + parliament
    case authoritarianRepublic  // Nominal republic, actual dictatorship
    case militaryJunta          // Military rule
    case theocracy              // Religious rule
    case absoluteMonarchy       // Traditional monarchy

    var displayName: String {
        switch self {
        case .communistState: return "Communist State"
        case .socialistRepublic: return "Socialist Republic"
        case .liberalDemocracy: return "Liberal Democracy"
        case .constitutionalMonarchy: return "Constitutional Monarchy"
        case .authoritarianRepublic: return "Authoritarian Republic"
        case .militaryJunta: return "Military Junta"
        case .theocracy: return "Theocracy"
        case .absoluteMonarchy: return "Absolute Monarchy"
        }
    }
}

// MARK: - Diplomatic Status

enum DiplomaticStatus: String, Codable, CaseIterable {
    case allied             // Formal alliance
    case friendly           // Good relations
    case neutral            // Normal diplomatic relations
    case strained           // Tensions exist
    case hostile            // Near-conflict
    case atWar              // Active military conflict
    case noRelations        // No diplomatic recognition

    var displayName: String {
        switch self {
        case .allied: return "Allied"
        case .friendly: return "Friendly"
        case .neutral: return "Neutral"
        case .strained: return "Strained"
        case .hostile: return "Hostile"
        case .atWar: return "At War"
        case .noRelations: return "No Relations"
        }
    }

    var relationshipModifier: Int {
        switch self {
        case .allied: return 30
        case .friendly: return 15
        case .neutral: return 0
        case .strained: return -15
        case .hostile: return -30
        case .atWar: return -50
        case .noRelations: return -20
        }
    }
}

// MARK: - Treaty Type

enum TreatyType: String, Codable, CaseIterable {
    case mutualDefense      // Military alliance
    case tradeAgreement     // Economic cooperation
    case aidPackage         // One-way assistance
    case nonAggression      // Peace guarantee
    case culturalExchange   // Soft diplomacy
    case nuclearSharing     // Nuclear cooperation
    case espionageAgreement // Intelligence sharing

    var displayName: String {
        switch self {
        case .mutualDefense: return "Mutual Defense Pact"
        case .tradeAgreement: return "Trade Agreement"
        case .aidPackage: return "Aid Package"
        case .nonAggression: return "Non-Aggression Treaty"
        case .culturalExchange: return "Cultural Exchange"
        case .nuclearSharing: return "Nuclear Sharing Agreement"
        case .espionageAgreement: return "Intelligence Sharing"
        }
    }
}

// MARK: - Active Treaty

struct ActiveTreaty: Codable, Identifiable {
    var id: String = UUID().uuidString
    var type: TreatyType
    var signedTurn: Int
    var expirationTurn: Int?    // nil = permanent
    var terms: String           // Description of specific terms
    var isSecret: Bool          // Hidden from public

    var isActive: Bool {
        guard let expiration = expirationTurn else { return true }
        return expiration > 0 // Would compare to current turn
    }
}

// MARK: - Foreign Country Model

@Model
final class ForeignCountry {
    @Attribute(.unique) var id: UUID
    var countryId: String               // Unique identifier like "soviet_union"
    var name: String
    var officialName: String            // Full formal name
    var countryDescription: String
    var bloc: String                    // PoliticalBloc.rawValue
    var government: String              // GovernmentType.rawValue

    // Geography
    var region: String                  // Geographic region
    var population: Int                 // In millions
    var landArea: Int                   // Relative size
    var borderingRegionId: String?      // If borders player's region

    // Leadership
    var leaderName: String
    var leaderTitle: String
    var rulingParty: String?

    // Diplomatic relations
    var diplomaticStatus: String        // DiplomaticStatus.rawValue
    var relationshipScore: Int          // -100 to 100
    var diplomaticTension: Int          // 0-100, risk of conflict

    // Economic
    var economicPower: Int              // 1-100
    var tradeVolume: Int                // Current trade with us
    var strategicResources: [String]    // What they have that we want

    // Economic System (1940s-60s era)
    var economicSystem: String = "freeMarket"   // EconomicSystemType.rawValue
    var gdpGrowth: Int = 3              // Annual growth rate (-10 to +15)
    var countryInflationRate: Int = 5   // Annual percentage (0-100+)
    var countryUnemploymentRate: Int = 5 // Percentage (0-50)
    var countryTradeBalance: Int = 0    // Positive = surplus with PSR
    var economicReformTendency: Int = 30 // 0-100 how likely to change economic system
    var consecutiveGDPDeclines: Int = 0 // Track for reform triggers

    // Military
    var militaryStrength: Int           // 1-100
    var hasNuclearWeapons: Bool
    var hasOurMilitaryBases: Bool

    // Intelligence
    var espionageActivity: Int          // Their spying on us (0-100)
    var ourIntelligenceAssets: Int      // Our spying on them (0-100)

    // Historical
    var historySummary: String          // Detailed history for Codex
    var relationshipHistory: String     // History with us
    var strategicImportance: String     // Why they matter

    // Treaties (encoded)
    var treatiesData: Data?

    var game: Game?

    init(countryId: String, name: String, officialName: String, bloc: PoliticalBloc, government: GovernmentType) {
        self.id = UUID()
        self.countryId = countryId
        self.name = name
        self.officialName = officialName
        self.countryDescription = ""
        self.bloc = bloc.rawValue
        self.government = government.rawValue

        self.region = ""
        self.population = 10
        self.landArea = 5

        self.leaderName = ""
        self.leaderTitle = ""

        self.diplomaticStatus = DiplomaticStatus.neutral.rawValue
        self.relationshipScore = 0
        self.diplomaticTension = 20

        self.economicPower = 50
        self.tradeVolume = 0
        self.strategicResources = []

        self.militaryStrength = 50
        self.hasNuclearWeapons = false
        self.hasOurMilitaryBases = false

        self.espionageActivity = 20
        self.ourIntelligenceAssets = 20

        self.historySummary = ""
        self.relationshipHistory = ""
        self.strategicImportance = ""
    }

    // MARK: - Computed Properties

    var politicalBloc: PoliticalBloc {
        PoliticalBloc(rawValue: bloc) ?? .nonAligned
    }

    var governmentType: GovernmentType {
        GovernmentType(rawValue: government) ?? .authoritarianRepublic
    }

    var status: DiplomaticStatus {
        get { DiplomaticStatus(rawValue: diplomaticStatus) ?? .neutral }
        set { diplomaticStatus = newValue.rawValue }
    }

    var treaties: [ActiveTreaty] {
        get {
            guard let data = treatiesData else { return [] }
            return (try? JSONDecoder().decode([ActiveTreaty].self, from: data)) ?? []
        }
        set {
            treatiesData = try? JSONEncoder().encode(newValue)
        }
    }

    var isAlly: Bool {
        politicalBloc == .socialist && relationshipScore > 30
    }

    var isEnemy: Bool {
        politicalBloc == .capitalist || relationshipScore < -50
    }

    var isThreat: Bool {
        militaryStrength > 70 && relationshipScore < 0
    }

    /// Overall relationship category for display
    var relationshipCategory: String {
        if relationshipScore > 60 { return "Strong Ally" }
        if relationshipScore > 30 { return "Friendly" }
        if relationshipScore > -30 { return "Neutral" }
        if relationshipScore > -60 { return "Unfriendly" }
        return "Hostile"
    }

    // MARK: - Economic System Properties

    /// Current economic system type
    var currentEconomicSystem: EconomicSystemType {
        EconomicSystemType(rawValue: economicSystem) ?? .freeMarket
    }

    /// Default economic system based on government type
    var defaultEconomicSystem: EconomicSystemType {
        switch governmentType {
        case .communistState:
            return .commandEconomy
        case .socialistRepublic:
            return .marketSocialism
        case .liberalDemocracy, .constitutionalMonarchy:
            return .freeMarket
        case .authoritarianRepublic, .militaryJunta:
            return .cronyCapitalism
        case .absoluteMonarchy, .theocracy:
            return .cronyCapitalism
        }
    }

    /// Whether this country is in economic crisis
    var hasEconomicCrisis: Bool {
        countryInflationRate >= 40 ||
        countryUnemploymentRate >= 20 ||
        gdpGrowth <= -5 ||
        consecutiveGDPDeclines >= 3
    }

    /// Economic health score (0-100)
    var economicHealthScore: Int {
        var score = 50

        // Growth contribution
        if gdpGrowth > 5 { score += 15 }
        else if gdpGrowth > 2 { score += 10 }
        else if gdpGrowth > 0 { score += 5 }
        else if gdpGrowth < -5 { score -= 20 }
        else if gdpGrowth < 0 { score -= 10 }

        // Inflation penalty
        if countryInflationRate > 30 { score -= 20 }
        else if countryInflationRate > 15 { score -= 10 }
        else if countryInflationRate < 5 { score += 5 }

        // Unemployment penalty
        if countryUnemploymentRate > 15 { score -= 15 }
        else if countryUnemploymentRate > 8 { score -= 5 }
        else if countryUnemploymentRate < 3 { score += 5 }

        return max(0, min(100, score))
    }

    /// Era-appropriate economic status description
    var economicStatusDescription: String {
        let health = economicHealthScore
        switch health {
        case 80...:
            return "The \(name) economy is flourishing with strong industrial output and stable prices."
        case 60..<80:
            return "\(name) maintains satisfactory economic conditions despite some challenges."
        case 40..<60:
            return "The \(name) economy shows mixed results with both progress and difficulties."
        case 20..<40:
            return "\(name) faces mounting economic difficulties that threaten stability."
        default:
            return "\(name) is experiencing severe economic crisis with widespread hardship."
        }
    }

    /// Whether reform pressure is building
    var hasReformPressure: Bool {
        consecutiveGDPDeclines >= 2 || hasEconomicCrisis || economicReformTendency >= 60
    }

    // MARK: - Methods

    func addTreaty(_ treaty: ActiveTreaty) {
        var current = treaties
        current.append(treaty)
        treaties = current
    }

    func removeTreaty(id: String) {
        var current = treaties
        current.removeAll { $0.id == id }
        treaties = current
    }

    func hasTreaty(of type: TreatyType) -> Bool {
        treaties.contains { $0.type == type }
    }

    func modifyRelationship(by amount: Int) {
        relationshipScore = max(-100, min(100, relationshipScore + amount))

        // Update diplomatic status based on score
        if relationshipScore > 60 {
            status = .allied
        } else if relationshipScore > 30 {
            status = .friendly
        } else if relationshipScore > -30 {
            status = .neutral
        } else if relationshipScore > -60 {
            status = .strained
        } else {
            status = .hostile
        }
    }

    // MARK: - Economic Methods

    /// Set economic system based on government type
    func initializeEconomicSystem() {
        economicSystem = defaultEconomicSystem.rawValue

        // Set initial economic indicators based on system
        switch currentEconomicSystem {
        case .commandEconomy:
            gdpGrowth = Int.random(in: 2...5)
            countryInflationRate = Int.random(in: 3...8)
            countryUnemploymentRate = Int.random(in: 1...4) // Low official unemployment
            economicReformTendency = Int.random(in: 10...30)

        case .marketSocialism:
            gdpGrowth = Int.random(in: 4...8)
            countryInflationRate = Int.random(in: 5...12)
            countryUnemploymentRate = Int.random(in: 3...7)
            economicReformTendency = Int.random(in: 20...50)

        case .mixedEconomy:
            gdpGrowth = Int.random(in: 3...6)
            countryInflationRate = Int.random(in: 4...10)
            countryUnemploymentRate = Int.random(in: 4...8)
            economicReformTendency = Int.random(in: 30...60)

        case .freeMarket:
            gdpGrowth = Int.random(in: 2...7)
            countryInflationRate = Int.random(in: 3...12)
            countryUnemploymentRate = Int.random(in: 5...12)
            economicReformTendency = Int.random(in: 20...50)

        case .cronyCapitalism:
            gdpGrowth = Int.random(in: 1...4)
            countryInflationRate = Int.random(in: 8...20)
            countryUnemploymentRate = Int.random(in: 8...15)
            economicReformTendency = Int.random(in: 15...40)
        }
    }

    /// Apply GDP growth change
    func applyGDPGrowthChange(_ change: Int) {
        let previousGrowth = gdpGrowth
        gdpGrowth = max(-15, min(15, gdpGrowth + change))

        // Track consecutive declines
        if gdpGrowth < previousGrowth && gdpGrowth < 0 {
            consecutiveGDPDeclines += 1
        } else if gdpGrowth > 0 {
            consecutiveGDPDeclines = 0
        }
    }

    /// Apply inflation change
    func applyInflationChange(_ change: Int) {
        countryInflationRate = max(0, min(100, countryInflationRate + change))
    }

    /// Apply unemployment change
    func applyUnemploymentChange(_ change: Int) {
        countryUnemploymentRate = max(0, min(50, countryUnemploymentRate + change))
    }

    /// Change economic system (economic reform)
    func changeEconomicSystem(to newSystem: EconomicSystemType, isReform: Bool = true) {
        let oldSystem = currentEconomicSystem
        economicSystem = newSystem.rawValue

        // Reforms cause short-term instability
        if isReform {
            // Transition costs
            applyGDPGrowthChange(-2)
            applyInflationChange(5)

            // Reset reform tendency
            economicReformTendency = 20
        }

        // Log the change (would be picked up by WorldSimulationService)
        #if DEBUG
        print("[Economy] \(name) changed from \(oldSystem.displayName) to \(newSystem.displayName)")
        #endif
    }

    /// Calculate potential GDP growth based on economic system
    func calculateBaseGrowth() -> Int {
        let baseRate = currentEconomicSystem.baseGrowthRate
        let volatility = currentEconomicSystem.volatility

        // Random variation based on volatility
        let variation = Int.random(in: -(volatility / 20)...(volatility / 20))

        return Int(baseRate) + variation
    }

    /// Calculate trade compatibility based on economic system alignment
    func economicCompatibility(with playerSystem: EconomicSystemType) -> Int {
        let mySystem = currentEconomicSystem

        if mySystem == playerSystem { return 3 }

        if mySystem.isSocialist && playerSystem.isSocialist { return 2 }
        if mySystem.isMarket && playerSystem.isMarket { return 2 }

        // Opposed systems: trade friction
        if mySystem.isSocialist != playerSystem.isSocialist { return -2 }

        return 0
    }

    /// Process economic turn for this country
    func processEconomicTurn() {
        // Update GDP growth
        let newGrowth = calculateBaseGrowth()
        applyGDPGrowthChange(newGrowth - gdpGrowth)

        // Inflation tends toward system tendency
        let targetInflation = currentEconomicSystem.inflationTendency
        let inflationDrift = (targetInflation - countryInflationRate) / 10
        applyInflationChange(inflationDrift + Int.random(in: -2...2))

        // Unemployment fluctuation
        let unemploymentChange = Int.random(in: -2...2)
        applyUnemploymentChange(unemploymentChange)

        // Update reform tendency based on economic performance
        if hasEconomicCrisis {
            economicReformTendency = min(100, economicReformTendency + 5)
        } else if gdpGrowth > 3 {
            economicReformTendency = max(0, economicReformTendency - 2)
        }
    }
}

// MARK: - Default Countries

extension ForeignCountry {

    /// Create all default foreign countries for the 1950s world
    /// The People's Socialist Republic (PSR) is a fictional nation; all others are real
    static func createDefaultCountries() -> [ForeignCountry] {
        var countries: [ForeignCountry] = []

        // ========================================
        // SOVIET BLOC (3 nations)
        // ========================================

        // 1. SOVIET UNION - Our primary ally and ideological partner
        let sovietUnion = ForeignCountry(
            countryId: "soviet_union",
            name: "Soviet Union",
            officialName: "Union of Soviet Socialist Republics",
            bloc: .socialist,
            government: .communistState
        )
        sovietUnion.region = "Eurasia"
        sovietUnion.population = 180
        sovietUnion.landArea = 10
        sovietUnion.leaderName = "The General Secretary"
        sovietUnion.leaderTitle = "General Secretary"
        sovietUnion.rulingParty = "Communist Party of the Soviet Union"
        sovietUnion.diplomaticStatus = DiplomaticStatus.friendly.rawValue
        sovietUnion.relationshipScore = 55
        sovietUnion.diplomaticTension = 20
        sovietUnion.economicPower = 80
        sovietUnion.tradeVolume = 65
        sovietUnion.strategicResources = ["Heavy industry", "Oil", "Minerals", "Military equipment"]
        sovietUnion.militaryStrength = 95
        sovietUnion.hasNuclearWeapons = true
        sovietUnion.hasOurMilitaryBases = false
        sovietUnion.espionageActivity = 40
        sovietUnion.ourIntelligenceAssets = 25
        sovietUnion.countryDescription = """
            The world's first socialist state and leader of the communist world. Under the General Secretary's \
            iron grip, the USSR has industrialized rapidly and emerged victorious from the Great \
            Patriotic War. Moscow seeks to spread revolution while rebuilding from wartime \
            devastation.
            """
        sovietUnion.historySummary = """
            The Soviet Union emerged from the chaos of the Russian Revolution in 1917, transforming \
            a feudal empire into an industrial powerhouse. The Five-Year Plans forced rapid \
            industrialization at tremendous human cost. The Great Patriotic War against Nazi Germany \
            killed over 20 million Soviet citizens but left the Red Army the most powerful force in Europe.

            Now, the USSR dominates Eastern Europe through satellite states and seeks to expand its \
            influence globally. The atomic bomb, developed in 1949, has given Moscow nuclear parity \
            with Washington. The General Secretary's health is declining, but his grip on power remains absolute.

            The Soviet system offers both model and warning: rapid industrialization is possible, \
            but at what cost? The purges, the famines, the terror—these too are part of the Soviet \
            experience.
            """
        sovietUnion.relationshipHistory = """
            The People's Socialist Republic views the USSR as a senior partner in the global \
            struggle against capitalism. Soviet advisors helped establish our revolutionary \
            government, and Soviet trade sustains our economy.

            Yet tensions exist. Moscow demands ideological conformity; we seek our own path. \
            They provide weapons and machinery; we provide strategic position and agricultural \
            goods. The relationship is one of mutual benefit, but not equal partnership.
            """
        sovietUnion.strategicImportance = """
            Our most powerful ally and our most demanding one. Soviet military might deters \
            Western intervention; Soviet ideology shapes our own. The balance between gratitude \
            and independence defines our foreign policy.
            """
        sovietUnion.economicSystem = EconomicSystemType.commandEconomy.rawValue
        sovietUnion.gdpGrowth = 5
        sovietUnion.countryInflationRate = 3
        sovietUnion.countryUnemploymentRate = 2
        sovietUnion.economicReformTendency = 10
        countries.append(sovietUnion)

        // 2. POLAND - Eastern Bloc satellite
        let poland = ForeignCountry(
            countryId: "poland",
            name: "Poland",
            officialName: "Polish People's Republic",
            bloc: .socialist,
            government: .communistState
        )
        poland.region = "Eastern Europe"
        poland.population = 25
        poland.landArea = 4
        poland.leaderName = "The First Secretary"
        poland.leaderTitle = "President"
        poland.rulingParty = "Polish United Workers' Party"
        poland.diplomaticStatus = DiplomaticStatus.friendly.rawValue
        poland.relationshipScore = 45
        poland.diplomaticTension = 15
        poland.economicPower = 40
        poland.tradeVolume = 25
        poland.strategicResources = ["Coal", "Steel", "Machinery"]
        poland.militaryStrength = 40
        poland.hasNuclearWeapons = false
        poland.hasOurMilitaryBases = false
        poland.espionageActivity = 15
        poland.ourIntelligenceAssets = 30
        poland.countryDescription = """
            A key Soviet satellite in Eastern Europe. Poland suffered terribly in the war—six million \
            dead, cities destroyed, borders redrawn. Now under communist rule, the Poles rebuild \
            while chafing under Soviet domination. The Catholic Church remains a powerful force \
            despite official atheism.
            """
        poland.historySummary = """
            Poland's history is one of partition, occupation, and resistance. Erased from the map for \
            over a century, reborn after World War I, invaded by both Nazi Germany and the Soviet Union \
            in 1939. The war killed one in six Poles.

            Liberation by the Red Army came at a price: communist rule imposed from Moscow. The \
            London-based government-in-exile was brushed aside. Elections were rigged. Opposition \
            crushed. But Polish nationalism and Catholic faith persist beneath the surface.
            """
        poland.relationshipHistory = """
            Fellow socialist states with much in common. Polish workers share our revolutionary \
            aspirations; Polish culture enriches our own. Trade flows steadily between our nations.
            """
        poland.strategicImportance = """
            A window into the Eastern Bloc and a potential ally in any conflict with Moscow's \
            hegemony. Poland's geographic position makes it crucial to European politics.
            """
        poland.economicSystem = EconomicSystemType.commandEconomy.rawValue
        poland.gdpGrowth = 4
        poland.countryInflationRate = 5
        poland.countryUnemploymentRate = 3
        poland.economicReformTendency = 25
        countries.append(poland)

        // 3. CZECHOSLOVAKIA - Eastern Bloc industrial power
        let czechoslovakia = ForeignCountry(
            countryId: "czechoslovakia",
            name: "Czechoslovakia",
            officialName: "Czechoslovak Socialist Republic",
            bloc: .socialist,
            government: .communistState
        )
        czechoslovakia.region = "Central Europe"
        czechoslovakia.population = 13
        czechoslovakia.landArea = 3
        czechoslovakia.leaderName = "The President"
        czechoslovakia.leaderTitle = "President"
        czechoslovakia.rulingParty = "Communist Party of Czechoslovakia"
        czechoslovakia.diplomaticStatus = DiplomaticStatus.friendly.rawValue
        czechoslovakia.relationshipScore = 50
        czechoslovakia.diplomaticTension = 12
        czechoslovakia.economicPower = 55
        czechoslovakia.tradeVolume = 30
        czechoslovakia.strategicResources = ["Precision machinery", "Arms", "Automobiles", "Glass"]
        czechoslovakia.militaryStrength = 35
        czechoslovakia.hasNuclearWeapons = false
        czechoslovakia.hasOurMilitaryBases = false
        czechoslovakia.espionageActivity = 12
        czechoslovakia.ourIntelligenceAssets = 25
        czechoslovakia.countryDescription = """
            The most industrialized nation in Eastern Europe. Czechoslovakia's Skoda works produce \
            everything from locomotives to weapons. The 1948 communist coup ended democracy here, \
            but the population remains relatively prosperous by Eastern Bloc standards.
            """
        czechoslovakia.historySummary = """
            Czechoslovakia was created from the ruins of Austria-Hungary after World War I. A \
            functioning democracy in the interwar period, it was betrayed at Munich in 1938 and \
            dismembered by Nazi Germany.

            After liberation, Czechoslovakia briefly attempted a democratic path with communist \
            participation. The 1948 coup ended this experiment. The purges that followed were \
            particularly brutal—even communist leaders were executed on fabricated charges.
            """
        czechoslovakia.relationshipHistory = """
            A valued trading partner and fellow socialist state. Czech machinery and arms help \
            build our economy; our agricultural goods feed their workers.
            """
        czechoslovakia.strategicImportance = """
            The industrial heart of Eastern Europe. Czech arms and machinery are crucial to the \
            socialist bloc's military capacity.
            """
        czechoslovakia.economicSystem = EconomicSystemType.commandEconomy.rawValue
        czechoslovakia.gdpGrowth = 5
        czechoslovakia.countryInflationRate = 4
        czechoslovakia.countryUnemploymentRate = 2
        czechoslovakia.economicReformTendency = 20
        countries.append(czechoslovakia)

        // ========================================
        // WESTERN POWERS (4 nations)
        // ========================================

        // 4. UNITED STATES - The leading capitalist power
        let unitedStates = ForeignCountry(
            countryId: "united_states",
            name: "United States",
            officialName: "United States of America",
            bloc: .capitalist,
            government: .liberalDemocracy
        )
        unitedStates.region = "North America"
        unitedStates.population = 150
        unitedStates.landArea = 9
        unitedStates.leaderName = "The President"
        unitedStates.leaderTitle = "President"
        unitedStates.rulingParty = "Democratic Party"
        unitedStates.diplomaticStatus = DiplomaticStatus.strained.rawValue
        unitedStates.relationshipScore = -25
        unitedStates.diplomaticTension = 55
        unitedStates.economicPower = 100
        unitedStates.tradeVolume = 15
        unitedStates.strategicResources = ["Technology", "Capital", "Industrial goods", "Food"]
        unitedStates.militaryStrength = 95
        unitedStates.hasNuclearWeapons = true
        unitedStates.hasOurMilitaryBases = false
        unitedStates.espionageActivity = 75
        unitedStates.ourIntelligenceAssets = 20
        unitedStates.countryDescription = """
            The world's richest and most powerful nation. America emerged from World War II with \
            its industry intact and its military supreme. The containment doctrine commits Washington \
            to containing communism everywhere. Yet American consumers hunger for trade, and \
            some voices counsel engagement over confrontation.
            """
        unitedStates.historySummary = """
            The United States became a superpower almost by accident. Isolationist through the \
            1930s, drawn into war by Pearl Harbor, America emerged in 1945 as the only major \
            power whose homeland remained unscathed.

            The atomic bomb gave America a brief monopoly on ultimate destruction. The Marshall \
            Plan rebuilt Western Europe as a bulwark against communism. The Korean War proved \
            American willingness to fight. McCarthyism revealed American fears.

            The President's term has been defined by containment—holding the line against Soviet \
            expansion. But America is not monolithic. Business interests want trade. Liberals \
            question Cold War orthodoxy. The 1952 election may bring change.
            """
        unitedStates.relationshipHistory = """
            The Americans view us with suspicion but not outright hostility. We are not in their \
            sphere of influence; we pose no direct threat. Some American businesses see us as a \
            potential market; some politicians see us as a potential ally against Soviet dominance.

            Trade is limited but not forbidden. Diplomatic relations exist but are cool. The \
            situation could evolve in either direction.
            """
        unitedStates.strategicImportance = """
            The most powerful nation on Earth. American technology, capital, and markets could \
            accelerate our development—if we can access them without compromising our principles. \
            American hostility could be devastating; American friendship could be transformative.
            """
        unitedStates.economicSystem = EconomicSystemType.freeMarket.rawValue
        unitedStates.gdpGrowth = 4
        unitedStates.countryInflationRate = 3
        unitedStates.countryUnemploymentRate = 5
        unitedStates.economicReformTendency = 20
        countries.append(unitedStates)

        // 5. UNITED KINGDOM - Declining empire
        let unitedKingdom = ForeignCountry(
            countryId: "united_kingdom",
            name: "United Kingdom",
            officialName: "United Kingdom of Great Britain and Northern Ireland",
            bloc: .capitalist,
            government: .constitutionalMonarchy
        )
        unitedKingdom.region = "Western Europe"
        unitedKingdom.population = 50
        unitedKingdom.landArea = 3
        unitedKingdom.leaderName = "The Prime Minister"
        unitedKingdom.leaderTitle = "Prime Minister"
        unitedKingdom.rulingParty = "Labour Party"
        unitedKingdom.diplomaticStatus = DiplomaticStatus.neutral.rawValue
        unitedKingdom.relationshipScore = -10
        unitedKingdom.diplomaticTension = 35
        unitedKingdom.economicPower = 60
        unitedKingdom.tradeVolume = 20
        unitedKingdom.strategicResources = ["Finance", "Technology", "Colonial resources"]
        unitedKingdom.militaryStrength = 55
        unitedKingdom.hasNuclearWeapons = true
        unitedKingdom.hasOurMilitaryBases = false
        unitedKingdom.espionageActivity = 60
        unitedKingdom.ourIntelligenceAssets = 30
        unitedKingdom.countryDescription = """
            A declining empire struggling to redefine itself. Britain won the war but lost its \
            wealth. The Labour government has nationalized industries and created the National \
            Health Service—socialist measures that give us common ground, despite their loyalty \
            to Washington.
            """
        unitedKingdom.historySummary = """
            Britain entered World War II as the world's largest empire and emerged victorious but \
            exhausted. The costs of war bankrupted the treasury. India gained independence in 1947; \
            other colonies demanded the same.

            The Labour government implemented sweeping reforms—nationalization of \
            industries, universal healthcare, expanded social services. These democratic socialist \
            measures transformed British society while maintaining the capitalist framework.

            Britain clings to great power status but depends increasingly on American support. \
            The "special relationship" with Washington shapes British foreign policy.
            """
        unitedKingdom.relationshipHistory = """
            The British view us with pragmatic caution. Their own Labour Party has implemented \
            socialist policies; they understand our aspirations even if they oppose our methods. \
            Trade is possible; friendship might be achievable.
            """
        unitedKingdom.strategicImportance = """
            A declining but still significant power. British technology, finance, and diplomatic \
            experience could benefit us. Their social democratic experiment offers lessons—both \
            positive and negative—for our own path.
            """
        unitedKingdom.economicSystem = EconomicSystemType.mixedEconomy.rawValue
        unitedKingdom.gdpGrowth = 3
        unitedKingdom.countryInflationRate = 5
        unitedKingdom.countryUnemploymentRate = 4
        unitedKingdom.economicReformTendency = 40
        countries.append(unitedKingdom)

        // 6. FRANCE - Fourth Republic instability
        let france = ForeignCountry(
            countryId: "france",
            name: "France",
            officialName: "French Republic",
            bloc: .capitalist,
            government: .liberalDemocracy
        )
        france.region = "Western Europe"
        france.population = 42
        france.landArea = 5
        france.leaderName = "The President"
        france.leaderTitle = "President"
        france.rulingParty = "Coalition Government"
        france.diplomaticStatus = DiplomaticStatus.neutral.rawValue
        france.relationshipScore = 5
        france.diplomaticTension = 30
        france.economicPower = 55
        france.tradeVolume = 25
        france.strategicResources = ["Wine", "Luxury goods", "Colonial resources", "Industry"]
        france.militaryStrength = 50
        france.hasNuclearWeapons = false
        france.hasOurMilitaryBases = false
        france.espionageActivity = 40
        france.ourIntelligenceAssets = 35
        france.countryDescription = """
            The Fourth Republic struggles with instability. Governments rise and fall; colonial \
            wars drain resources. Yet France remains a major power, and its large Communist Party \
            provides us potential allies within a capitalist state.
            """
        france.historySummary = """
            France fell to Nazi Germany in 1940—a humiliation that still haunts the nation. \
            Liberation came in 1944, but the political system that emerged has proven unstable. \
            Governments rarely last more than months.

            The French Communist Party, strengthened by its role in the Resistance, commands a \
            quarter of the vote. Colonial wars in Indochina drain French blood and treasure. \
            The Fourth Republic lurches from crisis to crisis.

            Yet French culture, French industry, and French diplomacy remain influential. Paris \
            is still Paris. French intellectuals debate socialism with sophistication and passion.
            """
        france.relationshipHistory = """
            France is the most promising Western power for improved relations. French communists \
            maintain ties with us; French socialists share some of our goals. Trade flows more \
            freely than with most capitalist nations.
            """
        france.strategicImportance = """
            A potential bridge between East and West. France's instability creates opportunities; \
            its Communist Party provides allies. If France tilted toward socialism, European \
            politics would transform.
            """
        france.economicSystem = EconomicSystemType.mixedEconomy.rawValue
        france.gdpGrowth = 4
        france.countryInflationRate = 8
        france.countryUnemploymentRate = 6
        france.economicReformTendency = 50
        countries.append(france)

        // 7. WEST GERMANY - Divided nation under occupation
        let westGermany = ForeignCountry(
            countryId: "west_germany",
            name: "West Germany",
            officialName: "Federal Republic of Germany",
            bloc: .capitalist,
            government: .liberalDemocracy
        )
        westGermany.region = "Central Europe"
        westGermany.population = 50
        westGermany.landArea = 4
        westGermany.leaderName = "The Chancellor"
        westGermany.leaderTitle = "Chancellor"
        westGermany.rulingParty = "Christian Democratic Union"
        westGermany.diplomaticStatus = DiplomaticStatus.strained.rawValue
        westGermany.relationshipScore = -20
        westGermany.diplomaticTension = 45
        westGermany.economicPower = 50
        westGermany.tradeVolume = 10
        westGermany.strategicResources = ["Machinery", "Chemicals", "Steel", "Engineering"]
        westGermany.militaryStrength = 25
        westGermany.hasNuclearWeapons = false
        westGermany.hasOurMilitaryBases = false
        westGermany.espionageActivity = 35
        westGermany.ourIntelligenceAssets = 20
        westGermany.countryDescription = """
            The western half of divided Germany, occupied by American, British, and French forces. \
            Under the Chancellor's conservative leadership, West Germany is rebuilding rapidly—the \
            "economic miracle" has begun. Anti-communist sentiment runs deep.
            """
        westGermany.historySummary = """
            Germany's defeat in 1945 left the nation divided and occupied. The western zones, \
            combined in 1949, became the Federal Republic. The Chancellor leads a pro-Western government \
            firmly aligned with Washington.

            The economic miracle is transforming West Germany into an industrial powerhouse once \
            more. American aid and German efficiency drive growth. But the division of Germany \
            remains an open wound.
            """
        westGermany.relationshipHistory = """
            Relations are cool. West Germany is firmly in the American orbit, suspicious of all \
            communist states. Trade is minimal. Diplomatic contact is formal at best.
            """
        westGermany.strategicImportance = """
            The front line of the Cold War in Europe. West Germany's rearmament—now being \
            discussed—would transform European security. Their industry could be valuable \
            if relations ever improve.
            """
        westGermany.economicSystem = EconomicSystemType.freeMarket.rawValue
        westGermany.gdpGrowth = 8
        westGermany.countryInflationRate = 4
        westGermany.countryUnemploymentRate = 8
        westGermany.economicReformTendency = 25
        countries.append(westGermany)

        // ========================================
        // NON-ALIGNED NATIONS (4 nations)
        // ========================================

        // 8. INDIA - Newly independent, non-aligned leader
        let india = ForeignCountry(
            countryId: "india",
            name: "India",
            officialName: "Republic of India",
            bloc: .nonAligned,
            government: .liberalDemocracy
        )
        india.region = "South Asia"
        india.population = 360
        india.landArea = 7
        india.leaderName = "The Prime Minister"
        india.leaderTitle = "Prime Minister"
        india.rulingParty = "Indian National Congress"
        india.diplomaticStatus = DiplomaticStatus.friendly.rawValue
        india.relationshipScore = 35
        india.diplomaticTension = 15
        india.economicPower = 35
        india.tradeVolume = 30
        india.strategicResources = ["Tea", "Cotton", "Jute", "Minerals", "Manpower"]
        india.militaryStrength = 45
        india.hasNuclearWeapons = false
        india.hasOurMilitaryBases = false
        india.espionageActivity = 15
        india.ourIntelligenceAssets = 25
        india.countryDescription = """
            The world's largest democracy, newly independent from British rule. The Prime Minister leads a \
            nation of enormous potential and enormous challenges. India refuses to align with \
            either superpower bloc, charting its own course as a leader of the developing world.
            """
        india.historySummary = """
            India won independence through a campaign of non-violent resistance—a moral victory that \
            inspired colonized peoples everywhere. Partition in 1947 created Pakistan and caused \
            massive bloodshed, but India emerged as a democratic republic.

            The Prime Minister combines Western-educated sophistication with deep roots in Indian tradition. \
            His socialist economic policies and non-aligned foreign policy offer a third way \
            between Washington and Moscow. India's voice carries moral weight.
            """
        india.relationshipHistory = """
            India is a natural friend. The Prime Minister's socialism aligns with our principles; his \
            non-alignment protects our interests. Trade is growing. Cultural exchanges \
            flourish. India may become our most important partner outside the Soviet bloc.
            """
        india.strategicImportance = """
            The leader of the non-aligned world. India's friendship legitimizes our position; \
            their example of democratic socialism offers alternatives to Soviet orthodoxy. \
            A strong India-PSR relationship could reshape global politics.
            """
        india.economicSystem = EconomicSystemType.mixedEconomy.rawValue
        india.gdpGrowth = 3
        india.countryInflationRate = 6
        india.countryUnemploymentRate = 10
        india.economicReformTendency = 35
        countries.append(india)

        // 9. YUGOSLAVIA - Independent communist
        let yugoslavia = ForeignCountry(
            countryId: "yugoslavia",
            name: "Yugoslavia",
            officialName: "Federal People's Republic of Yugoslavia",
            bloc: .nonAligned,
            government: .communistState
        )
        yugoslavia.region = "Southern Europe"
        yugoslavia.population = 17
        yugoslavia.landArea = 4
        yugoslavia.leaderName = "The President"
        yugoslavia.leaderTitle = "President"
        yugoslavia.rulingParty = "Communist League of Yugoslavia"
        yugoslavia.diplomaticStatus = DiplomaticStatus.friendly.rawValue
        yugoslavia.relationshipScore = 40
        yugoslavia.diplomaticTension = 18
        yugoslavia.economicPower = 35
        yugoslavia.tradeVolume = 20
        yugoslavia.strategicResources = ["Minerals", "Agriculture", "Strategic position"]
        yugoslavia.militaryStrength = 45
        yugoslavia.hasNuclearWeapons = false
        yugoslavia.hasOurMilitaryBases = false
        yugoslavia.espionageActivity = 25
        yugoslavia.ourIntelligenceAssets = 30
        yugoslavia.countryDescription = """
            A communist state that defied Moscow. Its 1948 break with Moscow proved that \
            socialist nations need not follow Soviet dictates. Yugoslavia experiments with \
            worker self-management and independent foreign policy.
            """
        yugoslavia.historySummary = """
            Yugoslavia liberated itself from Nazi occupation through partisan warfare—the only \
            Eastern European nation that didn't require Soviet troops. This gave Yugoslavia the \
            independence to challenge Moscow's demands for subservience.

            The 1948 split nearly led to war. Soviet pressure failed. Yugoslavia survived as \
            an independent communist state, developing its own model of socialism with worker \
            councils and market elements. The West, eager to support any crack in the Eastern \
            Bloc, provides economic aid.
            """
        yugoslavia.relationshipHistory = """
            Yugoslavia offers a model for independent socialism. Their worker self-management \
            experiments interest our reformers; their defiance of Moscow inspires our \
            nationalists. Trade and cultural exchange flourish.
            """
        yugoslavia.strategicImportance = """
            Proof that communism need not mean Soviet control. Yugoslavia's example strengthens \
            our own independence from Moscow. Their experiments with worker management may \
            point toward socialism's future.
            """
        yugoslavia.economicSystem = EconomicSystemType.marketSocialism.rawValue
        yugoslavia.gdpGrowth = 5
        yugoslavia.countryInflationRate = 8
        yugoslavia.countryUnemploymentRate = 6
        yugoslavia.economicReformTendency = 45
        countries.append(yugoslavia)

        // 10. EGYPT - Arab nationalism rising
        let egypt = ForeignCountry(
            countryId: "egypt",
            name: "Egypt",
            officialName: "Kingdom of Egypt",
            bloc: .nonAligned,
            government: .constitutionalMonarchy
        )
        egypt.region = "North Africa"
        egypt.population = 21
        egypt.landArea = 4
        egypt.leaderName = "The King"
        egypt.leaderTitle = "King"
        egypt.rulingParty = "Wafd Party (opposition growing)"
        egypt.diplomaticStatus = DiplomaticStatus.neutral.rawValue
        egypt.relationshipScore = 15
        egypt.diplomaticTension = 25
        egypt.economicPower = 30
        egypt.tradeVolume = 15
        egypt.strategicResources = ["Cotton", "Suez Canal", "Strategic position"]
        egypt.militaryStrength = 35
        egypt.hasNuclearWeapons = false
        egypt.hasOurMilitaryBases = false
        egypt.espionageActivity = 20
        egypt.ourIntelligenceAssets = 20
        egypt.countryDescription = """
            A kingdom in ferment. The King's corruption has lost him popular support. The \
            army grows restless. Arab nationalism rises. Egypt controls the Suez Canal, making \
            it strategically vital. Change is coming—the only question is its direction.
            """
        egypt.historySummary = """
            Egypt gained nominal independence from Britain in 1922, but British troops remained \
            to protect the Suez Canal. The King's regime has proven corrupt and ineffective. \
            The 1948 war against Israel ended in humiliating defeat.

            Young army officers plot revolution. Arab nationalism demands real independence. \
            The Suez Canal—Britain's lifeline to Asia—makes Egypt too important to ignore.
            """
        egypt.relationshipHistory = """
            Egypt is ripe for change. We maintain diplomatic relations with the monarchy while \
            cultivating contacts among nationalists and leftists. When revolution comes—and it \
            will—we should be positioned to benefit.
            """
        egypt.strategicImportance = """
            The Suez Canal makes Egypt vital to world trade. Egyptian nationalism could \
            challenge Western imperialism throughout the Arab world. The right relationship \
            with Egypt's future leaders could transform our position in the Middle East.
            """
        egypt.economicSystem = EconomicSystemType.cronyCapitalism.rawValue
        egypt.gdpGrowth = 2
        egypt.countryInflationRate = 10
        egypt.countryUnemploymentRate = 15
        egypt.economicReformTendency = 60
        countries.append(egypt)

        // 11. CHINA - Revolutionary transformation
        let china = ForeignCountry(
            countryId: "china",
            name: "China",
            officialName: "People's Republic of China",
            bloc: .socialist,
            government: .communistState
        )
        china.region = "East Asia"
        china.population = 550
        china.landArea = 9
        china.leaderName = "The Chairman"
        china.leaderTitle = "Chairman"
        china.rulingParty = "Communist Party of China"
        china.diplomaticStatus = DiplomaticStatus.friendly.rawValue
        china.relationshipScore = 45
        china.diplomaticTension = 20
        china.economicPower = 30
        china.tradeVolume = 20
        china.strategicResources = ["Population", "Agricultural potential", "Strategic position"]
        china.militaryStrength = 70
        china.hasNuclearWeapons = false
        china.hasOurMilitaryBases = false
        china.espionageActivity = 25
        china.ourIntelligenceAssets = 15
        china.countryDescription = """
            A revolutionary giant awakening. The Communists won the civil war in 1949, \
            establishing the People's Republic. Now they remake the world's most populous \
            nation according to revolutionary principles. The Korean War demonstrates \
            China's willingness to fight.
            """
        china.historySummary = """
            China's "century of humiliation" ended with the Communist victory in 1949. The Communist \
            Party, forged in the Long March and tempered by war with Japan, finally defeated \
            the Nationalist forces.

            The new government faces enormous challenges: a devastated economy, illiteracy, \
            feudal social structures, and hostile encirclement. Land reform proceeds with \
            revolutionary violence. The Korean War pits Chinese "volunteers" against American \
            forces.

            China seeks to learn from Soviet experience while developing its own path. The \
            relationship with Moscow is close but not without tension. Two communist giants \
            share a long border—and potentially competing interests.
            """
        china.relationshipHistory = """
            We share revolutionary heritage and ideological commitment. Chinese experience \
            offers lessons in peasant mobilization and people's war. Trade is limited by \
            geography and development, but political solidarity is strong.
            """
        china.strategicImportance = """
            The sleeping giant has awakened. China's transformation will shape the 21st century. \
            Their revolutionary energy inspires; their enormous population and territory make \
            them a future superpower. Our relationship with China may prove as important as \
            our relationship with Moscow.
            """
        china.economicSystem = EconomicSystemType.commandEconomy.rawValue
        china.gdpGrowth = 4
        china.countryInflationRate = 15
        china.countryUnemploymentRate = 8
        china.economicReformTendency = 15
        countries.append(china)

        // ========================================
        // ADDITIONAL REGIONAL POWERS (2 nations)
        // ========================================

        // 12. JAPAN - Occupied and rebuilding
        let japan = ForeignCountry(
            countryId: "japan",
            name: "Japan",
            officialName: "Japan",
            bloc: .capitalist,
            government: .constitutionalMonarchy
        )
        japan.region = "Pacific"
        japan.population = 84
        japan.landArea = 3
        japan.leaderName = "The Prime Minister"
        japan.leaderTitle = "Prime Minister"
        japan.rulingParty = "Liberal Party"
        japan.diplomaticStatus = DiplomaticStatus.strained.rawValue
        japan.relationshipScore = -30
        japan.diplomaticTension = 40
        japan.economicPower = 35
        japan.tradeVolume = 5
        japan.strategicResources = ["Industrial capacity", "Technology potential", "Labor"]
        japan.militaryStrength = 20
        japan.hasNuclearWeapons = false
        japan.hasOurMilitaryBases = false
        japan.espionageActivity = 25
        japan.ourIntelligenceAssets = 15
        japan.countryDescription = """
            A defeated empire under American occupation. Japan's military was destroyed; its \
            cities were firebombed; two suffered atomic attack. Now, under Allied \
            guidance, Japan rebuilds as a pacifist democracy aligned with Washington.
            """
        japan.historySummary = """
            Imperial Japan's aggressive expansion ended in catastrophic defeat. The atomic \
            bombings of Hiroshima and Nagasaki brought surrender. American occupation \
            followed—demilitarization, democratization, and economic reform.

            The 1947 constitution renounces war forever. American bases dot the islands. \
            Japanese industry, redirected from weapons to consumer goods, begins its \
            remarkable recovery. The Korean War brings orders and economic stimulus.
            """
        japan.relationshipHistory = """
            Japan is firmly in the American orbit. Their wartime militarism makes many \
            in our country suspicious. Diplomatic relations are minimal. Trade is negligible.
            """
        japan.strategicImportance = """
            Japan's industrial potential is enormous. Their technological capacity could \
            benefit us if relations ever improve. For now, they serve American interests \
            in the Pacific.
            """
        japan.economicSystem = EconomicSystemType.freeMarket.rawValue
        japan.gdpGrowth = 7
        japan.countryInflationRate = 5
        japan.countryUnemploymentRate = 6
        japan.economicReformTendency = 30
        countries.append(japan)

        // 13. MEXICO - Revolutionary legacy, pragmatic present
        let mexico = ForeignCountry(
            countryId: "mexico",
            name: "Mexico",
            officialName: "United Mexican States",
            bloc: .nonAligned,
            government: .authoritarianRepublic
        )
        mexico.region = "North America"
        mexico.population = 28
        mexico.landArea = 5
        mexico.leaderName = "The President"
        mexico.leaderTitle = "President"
        mexico.rulingParty = "Institutional Revolutionary Party"
        mexico.diplomaticStatus = DiplomaticStatus.friendly.rawValue
        mexico.relationshipScore = 30
        mexico.diplomaticTension = 18
        mexico.economicPower = 40
        mexico.tradeVolume = 35
        mexico.strategicResources = ["Oil", "Silver", "Agricultural products"]
        mexico.militaryStrength = 30
        mexico.hasNuclearWeapons = false
        mexico.hasOurMilitaryBases = false
        mexico.espionageActivity = 20
        mexico.ourIntelligenceAssets = 30
        mexico.countryDescription = """
            A revolutionary nation that has made peace with pragmatism. Mexico's own revolution \
            predates the Soviet one. The PRI rules as a permanent "revolutionary" party while \
            maintaining capitalist structures. Oil nationalization in 1938 proved Mexico's \
            independence from Washington.
            """
        mexico.historySummary = """
            The Mexican Revolution (1910-1920) transformed the nation. Land reform, labor rights, \
            and nationalist economic policy emerged from a decade of bloody conflict. The \
            Institutional Revolutionary Party (PRI) has ruled since 1929, incorporating \
            revolutionary rhetoric into single-party stability.

            President Cárdenas's 1938 oil nationalization defied American and British companies, \
            establishing Mexican sovereignty over its resources. The current president has \
            tilted toward business interests and American investment, but revolutionary \
            tradition constrains complete alignment with Washington.
            """
        mexico.relationshipHistory = """
            Mexico is a natural friend—revolutionary heritage, oil nationalization, and resistance \
            to American dominance give us common ground. Trade flows freely. Cultural exchange \
            flourishes. Mexico provides us a window to Latin America.
            """
        mexico.strategicImportance = """
            Our most important partner in the Americas. Mexican oil helps fuel our economy. \
            Mexican diplomatic cover helps protect our interests. A strong Mexico-PSR relationship \
            demonstrates that socialism need not mean isolation.
            """
        mexico.economicSystem = EconomicSystemType.mixedEconomy.rawValue
        mexico.gdpGrowth = 5
        mexico.countryInflationRate = 7
        mexico.countryUnemploymentRate = 8
        mexico.economicReformTendency = 35
        countries.append(mexico)

        return countries
    }
}

// MARK: - Diplomatic Action Types

enum DiplomaticActionType: String, Codable, CaseIterable {
    // Positive actions
    case sendAid                // Economic assistance
    case culturalExchange       // Artists, students, delegations
    case tradeNegotiation       // Improve trade relations
    case militaryCooperation    // Joint exercises, arms sales

    // Pressure actions
    case economicSanctions      // Trade restrictions
    case diplomaticProtest      // Formal complaint
    case recallAmbassador       // Diplomatic crisis
    case militaryThreat         // Saber rattling

    // Covert actions
    case plantAssets            // Establish spy network
    case supportDissidents      // Fund opposition
    case propaganda             // Information warfare
    case sabotage               // Economic/military damage

    var displayName: String {
        switch self {
        case .sendAid: return "Send Economic Aid"
        case .culturalExchange: return "Cultural Exchange"
        case .tradeNegotiation: return "Trade Negotiation"
        case .militaryCooperation: return "Military Cooperation"
        case .economicSanctions: return "Economic Sanctions"
        case .diplomaticProtest: return "Diplomatic Protest"
        case .recallAmbassador: return "Recall Ambassador"
        case .militaryThreat: return "Military Threat"
        case .plantAssets: return "Plant Intelligence Assets"
        case .supportDissidents: return "Support Dissidents"
        case .propaganda: return "Propaganda Campaign"
        case .sabotage: return "Sabotage Operation"
        }
    }

    var isCovert: Bool {
        switch self {
        case .plantAssets, .supportDissidents, .propaganda, .sabotage:
            return true
        default:
            return false
        }
    }

    var relationshipEffect: Int {
        switch self {
        case .sendAid: return 10
        case .culturalExchange: return 5
        case .tradeNegotiation: return 8
        case .militaryCooperation: return 12
        case .economicSanctions: return -15
        case .diplomaticProtest: return -5
        case .recallAmbassador: return -20
        case .militaryThreat: return -25
        case .plantAssets: return 0 // Hidden unless discovered
        case .supportDissidents: return -30 // If discovered
        case .propaganda: return -10 // If discovered
        case .sabotage: return -40 // If discovered
        }
    }
}
