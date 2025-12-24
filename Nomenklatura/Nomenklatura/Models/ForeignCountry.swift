//
//  ForeignCountry.swift
//  Nomenklatura
//
//  Foreign nations for diplomacy, trade, and international events
//  Alternate history where America became socialist after the Second Revolution (1936-1940)
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
            return "Nations aligned with the People's Socialist Republic of America through mutual defense treaties and ideological solidarity"
        case .capitalist:
            return "Capitalist powers led by the United Kingdom and the exiled US government in Cuba, united in opposition to American socialism"
        case .nonAligned:
            return "Nations refusing to join either superpower bloc, pursuing independent paths amid Cold War pressures"
        case .rival:
            return "Communist nations that reject our leadership and pursue their own path to socialism"
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
    var countryTradeBalance: Int = 0    // Positive = surplus with PSRA
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

    /// Create all 11 default foreign countries for the alternate history PSRA world
    static func createDefaultCountries() -> [ForeignCountry] {
        var countries: [ForeignCountry] = []

        // ========================================
        // SOCIALIST ALLIES (2 nations)
        // ========================================

        // 1. SOVIET UNION - Revolutionary ally who helped the Second Revolution
        let sovietUnion = ForeignCountry(
            countryId: "soviet_union",
            name: "Soviet Union",
            officialName: "Union of Soviet Socialist Republics",
            bloc: .socialist,
            government: .communistState
        )
        sovietUnion.region = "Eurasia"
        sovietUnion.population = 200
        sovietUnion.landArea = 10
        sovietUnion.leaderName = "Premier Georgy Malenkov"
        sovietUnion.leaderTitle = "Premier of the Soviet Union"
        sovietUnion.rulingParty = "Communist Party of the Soviet Union"
        sovietUnion.diplomaticStatus = DiplomaticStatus.friendly.rawValue
        sovietUnion.relationshipScore = 55
        sovietUnion.diplomaticTension = 25
        sovietUnion.economicPower = 85
        sovietUnion.tradeVolume = 70
        sovietUnion.strategicResources = ["Heavy industry", "Oil", "Minerals", "Military equipment"]
        sovietUnion.militaryStrength = 95
        sovietUnion.hasNuclearWeapons = true
        sovietUnion.hasOurMilitaryBases = false
        sovietUnion.espionageActivity = 45
        sovietUnion.ourIntelligenceAssets = 30
        sovietUnion.countryDescription = """
            The world's first socialist state and our revolutionary ally. The USSR provided crucial \
            support during the Second American Civil War, sending advisors, weapons, and economic aid \
            that helped turn the tide against the Federal Government. In exchange, we ceded part of \
            Alaska—a debt of gratitude some in the Party still resent.
            """
        sovietUnion.historySummary = """
            When Herbert Hoover's government began its final crackdown on the Labour Councils in 1938, \
            the Soviet Union saw an opportunity to spread world revolution. Stalin authorized covert \
            shipments of weapons through Mexico and sent military advisors to help organize the Red Militias.

            After the Revolutionary victory in 1940, Soviet aid accelerated—industrial machinery, technical \
            experts, grain shipments to feed the war-ravaged cities. The price was the Alaska Cession: \
            the eastern portion of the territory returned to Russia, giving the USSR a foothold in North America.

            Relations have cooled since Stalin's death. Premier Malenkov pursues a more cautious foreign \
            policy, and ideological tensions simmer over the correct path to socialism. They see themselves \
            as the senior partner; we increasingly chafe at this assumption.
            """
        sovietUnion.relationshipHistory = """
            Revolutionary allies with growing tensions. They saved our Revolution when Britain and Canada \
            threatened to crush it; we gave them Alaska in return. Some call it gratitude; others call \
            it tribute.

            Trade flows steadily—their heavy machinery for our agricultural products. But Moscow's \
            demands for ideological conformity grate on American sensibilities. We are socialists, \
            not satellites.
            """
        sovietUnion.strategicImportance = """
            Our most powerful ally and our most complicated relationship. Their military might deters \
            capitalist intervention; their ideological demands threaten our independence. The balance \
            is delicate. Relations can improve through cooperation or sour through conflict.
            """
        // Soviet Union: Command economy with strong industry
        sovietUnion.economicSystem = EconomicSystemType.commandEconomy.rawValue
        sovietUnion.gdpGrowth = 5
        sovietUnion.countryInflationRate = 3
        sovietUnion.countryUnemploymentRate = 2
        sovietUnion.economicReformTendency = 15
        countries.append(sovietUnion)

        // 2. GERMANY - Socialist republic, ally to both USSR and PSRA
        let germany = ForeignCountry(
            countryId: "germany",
            name: "Germany",
            officialName: "German Socialist Republic",
            bloc: .socialist,
            government: .socialistRepublic
        )
        germany.region = "Central Europe"
        germany.population = 70
        germany.landArea = 6
        germany.leaderName = "Chairman Ernst Thälmann"
        germany.leaderTitle = "Chairman of the State Council"
        germany.rulingParty = "Socialist Unity Party of Germany"
        germany.diplomaticStatus = DiplomaticStatus.allied.rawValue
        germany.relationshipScore = 70
        germany.diplomaticTension = 10
        germany.economicPower = 80
        germany.tradeVolume = 60
        germany.strategicResources = ["Precision machinery", "Chemicals", "Engineering", "Steel"]
        germany.militaryStrength = 65
        germany.hasNuclearWeapons = false
        germany.hasOurMilitaryBases = false
        germany.espionageActivity = 20
        germany.ourIntelligenceAssets = 35
        germany.countryDescription = """
            The industrial heart of European socialism. In this timeline, the Nazis never rose to power— \
            the Social Democrats and Communists united against them in 1932, and Germany became a \
            socialist republic through democratic transition. They are allies to both Moscow and \
            Washington, proof that socialism need not mean Soviet domination.
            """
        germany.historySummary = """
            History pivoted in 1932. As the Nazi Party surged in the polls, Ernst Thälmann and the \
            Communist leadership made a fateful decision: they would work with the Social Democrats \
            rather than against them. The "United Front Against Fascism" narrowly won the elections.

            The transition was not smooth. Street battles with Nazi paramilitaries, an attempted putsch, \
            economic crisis. But the left held together, nationalizing key industries while maintaining \
            democratic forms. By 1936, Germany was a socialist republic—one that rejected both fascism \
            and Stalinist authoritarianism.

            Today, Germany walks a careful line between Moscow and Washington, maintaining friendly \
            relations with both socialist powers while insisting on its own path. Their economy thrives; \
            their example inspires socialists worldwide.
            """
        germany.relationshipHistory = """
            Our closest ideological ally. German-American socialist solidarity predates both our \
            revolutions—German immigrants brought socialist ideas to America, and American support \
            helped the German left survive the Nazi threat.

            Trade is substantial and growing. German machinery builds our factories; American grain \
            feeds their workers. More importantly, Germany proves that socialism can succeed through \
            democratic means—a model we find more appealing than Moscow's.
            """
        germany.strategicImportance = """
            The bridge between American and Soviet socialism. Germany's success validates our system; \
            their independence from Moscow shows another path is possible. If Germany prospers, so \
            does the cause of democratic socialism worldwide.
            """
        // Germany: Market socialism with strong industrial base
        germany.economicSystem = EconomicSystemType.marketSocialism.rawValue
        germany.gdpGrowth = 6
        germany.countryInflationRate = 5
        germany.countryUnemploymentRate = 4
        germany.economicReformTendency = 25
        countries.append(germany)

        // ========================================
        // CAPITALIST ADVERSARIES (4 nations)
        // ========================================

        // 3. CUBA - Government-in-Exile of the old United States
        let cuba = ForeignCountry(
            countryId: "cuba",
            name: "Cuba",
            officialName: "Republic of Cuba (United States Government-in-Exile)",
            bloc: .capitalist,
            government: .liberalDemocracy
        )
        cuba.region = "Caribbean"
        cuba.population = 6
        cuba.landArea = 2
        cuba.leaderName = "President-in-Exile Robert Taft Jr."
        cuba.leaderTitle = "President of the United States (in Exile)"
        cuba.rulingParty = "Republican Party (Exile Government)"
        cuba.diplomaticStatus = DiplomaticStatus.hostile.rawValue
        cuba.relationshipScore = -75
        cuba.diplomaticTension = 80
        cuba.economicPower = 35
        cuba.tradeVolume = 0
        cuba.strategicResources = ["Sugar", "Tobacco", "Naval bases"]
        cuba.militaryStrength = 30
        cuba.hasNuclearWeapons = false
        cuba.hasOurMilitaryBases = false
        cuba.espionageActivity = 90
        cuba.ourIntelligenceAssets = 55
        cuba.countryDescription = """
            The last refuge of the old America. When the Federal Government collapsed in 1940, President \
            Hoover and key officials fled to Havana, where they established a government-in-exile that \
            still claims to be the "legitimate" United States. Ninety miles from our shores, they plot \
            and scheme for restoration.
            """
        cuba.historySummary = """
            In the final days of the Civil War, as Red Militia forces surrounded Washington, Herbert \
            Hoover made his escape. A Navy destroyer carried the President, the Cabinet, and the \
            Supreme Court to Cuba, where the Batista government offered sanctuary.

            The exiles established their government-in-exile in Havana, insisting they remain the \
            legitimate government of the United States. They printed money, issued passports, and \
            maintained embassies in sympathetic nations. Britain and Canada recognize them; most of \
            the world does not.

            Robert Taft Jr. now leads the exile government, having "won" elections conducted only among \
            emigres. He dreams of restoration, of leading an army back to reclaim America. The dream \
            grows more distant each year, but the hatred never fades.
            """
        cuba.relationshipHistory = """
            Our mortal enemy, ninety miles away. They claim our government is illegitimate; we claim \
            theirs is. No diplomatic relations exist. Every exile is a potential saboteur; every \
            fishing boat might carry agents.

            The British and Canadians fund them. Our intelligence services work constantly to penetrate \
            their networks. Someday, we may have to deal with Cuba directly—but that would mean \
            acknowledging what they represent.
            """
        cuba.strategicImportance = """
            The dagger pointed at our heart. Their intelligence operations, funded by London, threaten \
            our security. Their very existence is a propaganda victory for capitalism. Resolving the \
            Cuba question—one way or another—remains a strategic priority.
            """
        // Cuba: Small free market economy dependent on Britain
        cuba.economicSystem = EconomicSystemType.freeMarket.rawValue
        cuba.gdpGrowth = 2
        cuba.countryInflationRate = 8
        cuba.countryUnemploymentRate = 12
        cuba.economicReformTendency = 40
        countries.append(cuba)

        // 4. CANADA - Lost territory to PSRA, bitter enemy
        let canada = ForeignCountry(
            countryId: "canada",
            name: "Canada",
            officialName: "Dominion of Canada",
            bloc: .capitalist,
            government: .constitutionalMonarchy
        )
        canada.region = "North America"
        canada.population = 14
        canada.landArea = 9
        canada.leaderName = "Prime Minister George Drew"
        canada.leaderTitle = "Prime Minister"
        canada.rulingParty = "Progressive Conservative Party"
        canada.diplomaticStatus = DiplomaticStatus.hostile.rawValue
        canada.relationshipScore = -70
        canada.diplomaticTension = 75
        canada.economicPower = 55
        canada.tradeVolume = 5
        canada.strategicResources = ["Timber", "Minerals", "Oil", "Grain"]
        canada.militaryStrength = 45
        canada.hasNuclearWeapons = false
        canada.hasOurMilitaryBases = false
        canada.espionageActivity = 70
        canada.ourIntelligenceAssets = 40
        canada.borderingRegionId = "pacific"
        canada.countryDescription = """
            Our neighbor to the north, now bitterly hostile. When Britain and Canada intervened in \
            1941 to help the Federal Government, our forces pushed back—and kept pushing. British \
            Columbia and Alberta now fly our flag as the People's Federated Territory. Canada has \
            never forgiven us.
            """
        canada.historySummary = """
            Canada watched the American Civil War with horror. When the Labour Councils seemed likely \
            to win, Ottawa panicked. In 1941, Canadian and British forces crossed the border, hoping \
            to save the Federal Government—or at least secure a buffer zone.

            They miscalculated badly. Our forces, hardened by civil war, threw them back. When the \
            counteroffensive ended, we held British Columbia and Alberta. The "People's Federated \
            Territory" was proclaimed—revenge for their intervention, and a permanent reminder of \
            their failure.

            Prime Minister Drew leads a nation consumed by revanchism. Every election turns on the \
            "Lost Provinces." Military spending drains the treasury. The border is the most militarized \
            in the world.
            """
        canada.relationshipHistory = """
            From friendly neighbors to bitter enemies. They intervened; we conquered. Now they want \
            their territory back, and we have no intention of returning it.

            Diplomatic relations are frozen. Trade is minimal. The border bristles with fortifications. \
            Incidents occur regularly—sometimes shots are fired. Neither side wants full-scale war, \
            but neither side will back down.
            """
        canada.strategicImportance = """
            Our most dangerous neighbor. Their military is small but backed by Britain. The lost \
            provinces fester like an open wound. Resolving the Canada question—through negotiation \
            or force—may eventually become necessary.
            """
        // Canada: Mixed economy with resource dependence
        canada.economicSystem = EconomicSystemType.mixedEconomy.rawValue
        canada.gdpGrowth = 4
        canada.countryInflationRate = 6
        canada.countryUnemploymentRate = 7
        canada.economicReformTendency = 35
        countries.append(canada)

        // 5. UNITED KINGDOM - Empire intact, hostile power
        let unitedKingdom = ForeignCountry(
            countryId: "united_kingdom",
            name: "United Kingdom",
            officialName: "United Kingdom of Great Britain and Northern Ireland",
            bloc: .capitalist,
            government: .constitutionalMonarchy
        )
        unitedKingdom.region = "Western Europe"
        unitedKingdom.population = 50
        unitedKingdom.landArea = 4
        unitedKingdom.leaderName = "Prime Minister Anthony Eden"
        unitedKingdom.leaderTitle = "Prime Minister"
        unitedKingdom.rulingParty = "Conservative Party"
        unitedKingdom.diplomaticStatus = DiplomaticStatus.hostile.rawValue
        unitedKingdom.relationshipScore = -60
        unitedKingdom.diplomaticTension = 65
        unitedKingdom.economicPower = 70
        unitedKingdom.tradeVolume = 10
        unitedKingdom.strategicResources = ["Finance", "Naval power", "Intelligence", "Colonial resources"]
        unitedKingdom.militaryStrength = 70
        unitedKingdom.hasNuclearWeapons = true
        unitedKingdom.hasOurMilitaryBases = false
        unitedKingdom.espionageActivity = 85
        unitedKingdom.ourIntelligenceAssets = 40
        unitedKingdom.countryDescription = """
            The old empire, still standing. Without a World War to drain their resources, Britain \
            retains much of its colonial empire. They tried to crush our Revolution and failed; now \
            they lead the capitalist world's opposition to American socialism. Their intelligence \
            services are legendary—and focused squarely on us.
            """
        unitedKingdom.historySummary = """
            The British Empire of this timeline never faced its reckoning. No World War II bankrupted \
            their treasury; no decolonization wave swept away their possessions. India remains the \
            jewel in the crown; Africa remains carved into British colonies; the sun still never sets \
            on British dominion.

            When the American Civil War erupted, London saw both threat and opportunity. They backed \
            the Federal Government with money, weapons, and eventually troops. The intervention failed, \
            costing them Canadian territory and creating an implacable enemy.

            Prime Minister Eden leads a nation still adjusting to its new rival. America was supposed \
            to be a junior partner; now it's a revolutionary threat. British intelligence wages \
            constant shadow war against us, funding exiles and plotting subversion.
            """
        unitedKingdom.relationshipHistory = """
            They tried to strangle our Revolution in its cradle. We humiliated them in Canada. Neither \
            side forgets, neither side forgives.

            Diplomatic relations are minimal—ambassadors exchange notes, nothing more. Their spies \
            swarm through Cuba and Mexico. Our agents work to undermine their colonial rule. The \
            "special relationship" is one of mutual hostility.
            """
        unitedKingdom.strategicImportance = """
            The leader of the capitalist world, with or without their American ally. Their empire \
            provides resources; their navy controls the seas; their intelligence services threaten \
            our security. Britain is the enemy we must eventually either defeat or accommodate.
            """
        // UK: Free market with imperial resources
        unitedKingdom.economicSystem = EconomicSystemType.freeMarket.rawValue
        unitedKingdom.gdpGrowth = 3
        unitedKingdom.countryInflationRate = 4
        unitedKingdom.countryUnemploymentRate = 5
        unitedKingdom.economicReformTendency = 30
        countries.append(unitedKingdom)

        // 6. FRANCE - Unstable, swings between left and right
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
        france.leaderName = "Premier Pierre Mendès France"
        france.leaderTitle = "President of the Council"
        france.rulingParty = "Radical Party (coalition)"
        france.diplomaticStatus = DiplomaticStatus.strained.rawValue
        france.relationshipScore = -25
        france.diplomaticTension = 40
        france.economicPower = 60
        france.tradeVolume = 25
        france.strategicResources = ["Wine", "Luxury goods", "Colonial resources", "Industry"]
        france.militaryStrength = 55
        france.hasNuclearWeapons = false
        france.hasOurMilitaryBases = false
        france.espionageActivity = 50
        france.ourIntelligenceAssets = 45
        france.countryDescription = """
            The most unpredictable power in Europe. French politics swing wildly between left and \
            right, between accommodation with socialism and fierce anti-communism. Today's enemy \
            might be tomorrow's friend—or vice versa. Their large Communist Party provides both \
            opportunity and concern.
            """
        france.historySummary = """
            France emerged from the interwar period without the trauma of Nazi occupation. The Third \
            Republic limped along, governments rising and falling with dizzying speed. The French \
            Communist Party grew strong; so did the fascist leagues.

            The American Revolution split French opinion. The left celebrated; the right condemned. \
            Governments tried to navigate between, officially hostile but privately hedging. The \
            French Communist Party maintains close ties with both Moscow and Washington—a potential \
            fifth column or a bridge to better relations.

            Premier Mendès France leads the latest unstable coalition, trying to balance colonial \
            wars, domestic unrest, and international pressures. France could fall to the left \
            tomorrow—or to the right.
            """
        france.relationshipHistory = """
            Complicated. Official relations are strained but not frozen. Trade continues. French \
            intellectuals debate our system endlessly; French communists look to us for inspiration.

            The French government fears we might support their colonial subjects; we fear they might \
            join British intervention. Neither side trusts the other, but neither side wants to \
            force a choice—yet.
            """
        france.strategicImportance = """
            The swing state of Europe. If France goes socialist, the capitalist bloc fractures. If \
            France goes fascist, we face another enemy. French politics bear constant watching; \
            French communists deserve constant cultivation.
            """
        // France: Mixed economy with colonial strain
        france.economicSystem = EconomicSystemType.mixedEconomy.rawValue
        france.gdpGrowth = 3
        france.countryInflationRate = 8
        france.countryUnemploymentRate = 8
        france.economicReformTendency = 55
        countries.append(france)

        // ========================================
        // FASCIST POWERS (2 nations)
        // ========================================

        // 7. ITALY - Fascist state controlling North Africa
        let italy = ForeignCountry(
            countryId: "italy",
            name: "Italy",
            officialName: "Italian Social Republic",
            bloc: .nonAligned,
            government: .authoritarianRepublic
        )
        italy.region = "Southern Europe"
        italy.population = 47
        italy.landArea = 5
        italy.leaderName = "Duce Benito Mussolini"
        italy.leaderTitle = "Head of Government"
        italy.rulingParty = "National Fascist Party"
        italy.diplomaticStatus = DiplomaticStatus.hostile.rawValue
        italy.relationshipScore = -55
        italy.diplomaticTension = 50
        italy.economicPower = 50
        italy.tradeVolume = 5
        italy.strategicResources = ["Mediterranean access", "Colonial resources", "Industry"]
        italy.militaryStrength = 55
        italy.hasNuclearWeapons = false
        italy.hasOurMilitaryBases = false
        italy.espionageActivity = 40
        italy.ourIntelligenceAssets = 35
        italy.countryDescription = """
            Fascism's original home, still standing. Without a World War to destroy him, Mussolini \
            remains in power, his regime controlling Italy and much of North Africa. The fascist \
            state represents everything we oppose—yet they oppose the British Empire too, creating \
            strange potential alignments.
            """
        italy.historySummary = """
            Mussolini's March on Rome in 1922 brought fascism to power in Italy. Without the disasters \
            of World War II to discredit his regime, he remains Il Duce, aging but still commanding.

            Italy expanded into Africa throughout the 1930s—Ethiopia fell in 1936, and Italian forces \
            pushed into British-held territories during the chaos of the American Civil War. North \
            Africa from Libya to Ethiopia now flies the Italian tricolor.

            The regime is brutal but pragmatic. Mussolini hates communism but hates British imperialism \
            too. Italy trades with whoever pays, spies on everyone, and trusts no one. The Duce grows \
            old; succession looms; the fascist experiment's future remains uncertain.
            """
        italy.relationshipHistory = """
            Ideological enemies but not at war. Mussolini's anti-communism is genuine, but so is his \
            resentment of British dominance. Italian intelligence cooperates with British services \
            against us—but also competes with them in the Mediterranean.

            No formal relations exist. Some trade flows through intermediaries. Italian communists, \
            suppressed but not destroyed, maintain underground contact with our agents.
            """
        italy.strategicImportance = """
            A fascist power that might be turned against our enemies. Italy's Mediterranean position \
            threatens British shipping; their African colonies drain British resources. The enemy of \
            our enemy is not our friend—but might be useful.
            """
        // Italy: Fascist crony capitalism with inefficiency
        italy.economicSystem = EconomicSystemType.cronyCapitalism.rawValue
        italy.gdpGrowth = 2
        italy.countryInflationRate = 10
        italy.countryUnemploymentRate = 12
        italy.economicReformTendency = 25
        countries.append(italy)

        // 8. SPAIN - Traditional fascist state
        let spain = ForeignCountry(
            countryId: "spain",
            name: "Spain",
            officialName: "Spanish State",
            bloc: .nonAligned,
            government: .authoritarianRepublic
        )
        spain.region = "Southwestern Europe"
        spain.population = 28
        spain.landArea = 4
        spain.leaderName = "Caudillo Francisco Franco"
        spain.leaderTitle = "Head of State"
        spain.rulingParty = "Movimiento Nacional"
        spain.diplomaticStatus = DiplomaticStatus.hostile.rawValue
        spain.relationshipScore = -50
        spain.diplomaticTension = 45
        spain.economicPower = 35
        spain.tradeVolume = 5
        spain.strategicResources = ["Strategic position", "Minerals", "Agriculture"]
        spain.militaryStrength = 45
        spain.hasNuclearWeapons = false
        spain.hasOurMilitaryBases = false
        spain.espionageActivity = 35
        spain.ourIntelligenceAssets = 30
        spain.countryDescription = """
            Franco's Spain—victorious in civil war, isolated in peace. The Spanish Civil War of \
            1936-1939 ended in Nationalist victory, establishing a fascist state that survives \
            through repression and international isolation. They hate us; we supported the Republic \
            they destroyed.
            """
        spain.historySummary = """
            The Spanish Civil War was a rehearsal for greater conflicts. Franco's Nationalists, backed \
            by Italy and Germany, defeated the Republican forces we supported with volunteers and weapons. \
            The International Brigades included many American communists who would later fight in our \
            own revolution.

            Franco's victory in 1939 established a regime of terror. Republicans were shot by the \
            thousands; survivors fled or hid. The regime aligned with fascist Italy but kept its \
            distance from the British-led order.

            Today, Spain remains isolated—too fascist for the British, too anti-communist for us. \
            Franco grows old, his regime ossifying. What comes after remains unclear, but Spanish \
            exiles in our territory dream of liberation.
            """
        spain.relationshipHistory = """
            Blood enemies. We backed the Republic; they killed it. Spanish refugees, including many \
            who fought in our own Revolution, live in our territory, plotting return.

            No diplomatic relations. No trade. Spanish fascists shelter Cuban exiles; we shelter \
            Spanish republicans. The hatred runs deep.
            """
        spain.strategicImportance = """
            A secondary enemy, but one with strategic position. Spain controls access to the \
            Mediterranean; Spanish Morocco borders important shipping lanes. When Franco falls— \
            and he will—Spain could go either direction. We should be ready.
            """
        // Spain: Isolated crony capitalism, economically weak
        spain.economicSystem = EconomicSystemType.cronyCapitalism.rawValue
        spain.gdpGrowth = 1
        spain.countryInflationRate = 12
        spain.countryUnemploymentRate = 15
        spain.economicReformTendency = 35
        countries.append(spain)

        // ========================================
        // PACIFIC POWERS (2 nations)
        // ========================================

        // 9. JAPAN - Imperial power holding Hawaii
        let japan = ForeignCountry(
            countryId: "japan",
            name: "Japan",
            officialName: "Empire of Japan",
            bloc: .nonAligned,
            government: .absoluteMonarchy
        )
        japan.region = "Pacific"
        japan.population = 85
        japan.landArea = 6
        japan.leaderName = "Prime Minister Nobusuke Kishi"
        japan.leaderTitle = "Prime Minister"
        japan.rulingParty = "Imperial Rule Assistance Association"
        japan.diplomaticStatus = DiplomaticStatus.hostile.rawValue
        japan.relationshipScore = -65
        japan.diplomaticTension = 70
        japan.economicPower = 65
        japan.tradeVolume = 5
        japan.strategicResources = ["Industrial capacity", "Naval power", "Hawaii", "China resources"]
        japan.militaryStrength = 80
        japan.hasNuclearWeapons = false
        japan.hasOurMilitaryBases = false
        japan.espionageActivity = 60
        japan.ourIntelligenceAssets = 35
        japan.borderingRegionId = "pacific"
        japan.countryDescription = """
            The rising sun that never set. While America tore itself apart in civil war, Imperial \
            Japan seized Hawaii and expanded across Asia. They hold our islands hostage; their \
            empire stretches from Manchuria to the mid-Pacific. Someday, we must take back what \
            they stole.
            """
        japan.historySummary = """
            Japan watched the American Civil War with predatory interest. When it became clear the \
            Federal Government would fall, the Imperial Navy moved. In December 1941, Japanese forces \
            occupied Hawaii—presented as "protection" of Japanese-American residents, in reality a \
            strategic grab.

            The new PSRA government, exhausted from civil war and facing British-Canadian intervention, \
            could not respond. Hawaii remains under Japanese occupation, its American population \
            subjected to increasingly harsh rule.

            Japan's empire now spans East Asia. China groans under occupation; Korea and Manchuria \
            fuel Japanese industry; Southeast Asia provides resources. The Empire is vast, brutal, \
            and directly controls territory we consider ours.
            """
        japan.relationshipHistory = """
            They stole Hawaii when we were weak. We have never recognized their occupation; they \
            have never recognized our government. The state of war that never formally began has \
            never formally ended.

            Japanese-American citizens in Hawaii face persecution. Our intelligence services work \
            to support resistance; their secret police hunt our agents. Someday, there will be a \
            reckoning.
            """
        japan.strategicImportance = """
            The enemy across the Pacific. They hold Hawaii—American territory, American citizens, \
            American honor. Liberating Hawaii is a national priority that events have not yet \
            permitted. When we are strong enough, the reckoning will come.
            """
        // Japan: Militarist crony capitalism with imperial expansion
        japan.economicSystem = EconomicSystemType.cronyCapitalism.rawValue
        japan.gdpGrowth = 4
        japan.countryInflationRate = 8
        japan.countryUnemploymentRate = 6
        japan.economicReformTendency = 20
        countries.append(japan)

        // 10. CHINA - Under Japanese occupation, status uncertain
        let china = ForeignCountry(
            countryId: "china",
            name: "China",
            officialName: "Republic of China (contested)",
            bloc: .nonAligned,
            government: .authoritarianRepublic
        )
        china.region = "East Asia"
        china.population = 450
        china.landArea = 9
        china.leaderName = "Generalissimo Chiang Kai-shek"
        china.leaderTitle = "President (in resistance)"
        china.rulingParty = "Kuomintang (fragmented)"
        china.diplomaticStatus = DiplomaticStatus.neutral.rawValue
        china.relationshipScore = 15
        china.diplomaticTension = 35
        china.economicPower = 25
        china.tradeVolume = 10
        china.strategicResources = ["Population", "Resources", "Strategic position"]
        china.militaryStrength = 40
        china.hasNuclearWeapons = false
        china.hasOurMilitaryBases = false
        china.espionageActivity = 25
        china.ourIntelligenceAssets = 30
        china.countryDescription = """
            The sleeping giant, bound in chains. Japan's invasion of China continues, with the \
            Kuomintang government retreated to the interior and communist guerrillas fighting in \
            the north. China's fate remains undecided—whoever helps liberate them may shape the \
            future of Asia.
            """
        china.historySummary = """
            Japan's full invasion of China began in 1937 and has never truly ended. The Kuomintang \
            government retreated to Chongqing; the Chinese Communist Party fights guerrilla war in \
            the north; Japanese forces control the coast and major cities.

            The Chinese resistance continues, but neither the Nationalists nor the Communists can \
            expel Japan alone. Both factions have approached us for aid; both view us as potential \
            allies against Tokyo.

            Chiang Kai-shek leads what remains of the Nationalist government, corrupt and ineffective \
            but still claiming to represent China. Mao Zedong's communists grow stronger in the \
            countryside. When Japan falls, the two factions will likely turn on each other.
            """
        china.relationshipHistory = """
            Potential allies against a common enemy. Chinese Nationalists and Communists both seek \
            our support; we provide what we can without provoking Japan into wider conflict.

            Our relationship with Chinese communists is complicated by Moscow's involvement. The \
            Soviets support Mao; we maintain contacts with both factions. China's liberation \
            could create a powerful ally—or a new rival.
            """
        china.strategicImportance = """
            The key to Asia. Whoever helps free China from Japan will have enormous influence over \
            its future. Chinese communists might become allies; Chinese nationalists might become \
            enemies. The situation is fluid, the stakes enormous.
            """
        // China: Fragmented economy under occupation
        china.economicSystem = EconomicSystemType.cronyCapitalism.rawValue
        china.gdpGrowth = -2
        china.countryInflationRate = 25
        china.countryUnemploymentRate = 20
        china.economicReformTendency = 70  // High tendency due to instability
        countries.append(china)

        // ========================================
        // NEIGHBORS (1 nation)
        // ========================================

        // 11. MEXICO - Oligarchy playing both sides
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
        mexico.leaderName = "President Miguel Alemán Valdés"
        mexico.leaderTitle = "President"
        mexico.rulingParty = "Institutional Revolutionary Party"
        mexico.diplomaticStatus = DiplomaticStatus.neutral.rawValue
        mexico.relationshipScore = 10
        mexico.diplomaticTension = 30
        mexico.economicPower = 40
        mexico.tradeVolume = 45
        mexico.strategicResources = ["Oil", "Silver", "Agricultural products", "Strategic position"]
        mexico.militaryStrength = 35
        mexico.hasNuclearWeapons = false
        mexico.hasOurMilitaryBases = false
        mexico.espionageActivity = 35
        mexico.ourIntelligenceAssets = 45
        mexico.borderingRegionId = "southern"
        mexico.countryDescription = """
            Our southern neighbor walks a careful line. Mexico is neither socialist nor fully \
            capitalist—a one-party state run by an oligarchy that mouths revolutionary rhetoric \
            while maintaining capitalist structures. They helped us during the Civil War but \
            refuse to commit fully to either bloc.
            """
        mexico.historySummary = """
            Mexico's own revolution, decades before ours, created a unique system—the PRI rules as \
            a permanent revolutionary party that has made peace with capitalism while maintaining \
            socialist theater. Land reform proceeded, then stalled. Nationalization occurred, then \
            stopped.

            During our Civil War, Mexico provided crucial support—Soviet weapons flowed through Mexican \
            ports; our agents organized in Mexican cities. President Cárdenas sympathized with our \
            cause. But his successors have been more cautious.

            President Alemán leads a government focused on development and stability, not revolution. \
            Mexico trades with us and with our enemies, plays all sides, commits to none. They fear \
            both our expansion and British revenge.
            """
        mexico.relationshipHistory = """
            Helpful neighbors who refuse to become allies. They aided our Revolution but will not \
            join our bloc. We share a long border and longer history; they remember the wars of \
            the 19th century and keep their distance.

            Trade flows freely. Diplomatic relations are correct. Mexican intelligence watches us \
            carefully; our agents operate with some freedom in their territory. The relationship \
            is useful but not warm.
            """
        mexico.strategicImportance = """
            Our most important neutral neighbor. Mexico's cooperation—or opposition—shapes our \
            strategic position. If they joined the capitalist bloc, we would face enemies on \
            two land borders. Keeping Mexico neutral, or better, is essential.
            """
        // Mexico: Mixed economy with state oil sector
        mexico.economicSystem = EconomicSystemType.mixedEconomy.rawValue
        mexico.gdpGrowth = 4
        mexico.countryInflationRate = 7
        mexico.countryUnemploymentRate = 10
        mexico.economicReformTendency = 40
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
