//
//  EconomicSystem.swift
//  Nomenklatura
//
//  Economic system types for PSRA and foreign countries
//  Era: 1940s-1960s alternate history
//

import Foundation

// MARK: - Economic System Type

enum EconomicSystemType: String, Codable, CaseIterable {
    case commandEconomy       // Full central planning (classic Soviet model)
    case marketSocialism      // State ownership with market mechanisms (CCP-style)
    case mixedEconomy         // State intervention with private sector (European model)
    case freeMarket           // Minimal state intervention (Anglo-American capitalism)
    case cronyCapitalism      // State-favored oligarchs (authoritarian capitalism)

    var displayName: String {
        switch self {
        case .commandEconomy: return "Central Planning"
        case .marketSocialism: return "Market Socialism"
        case .mixedEconomy: return "Mixed Economy"
        case .freeMarket: return "Free Enterprise"
        case .cronyCapitalism: return "State Capitalism"
        }
    }

    /// Era-appropriate description for Codex/tooltips
    var description: String {
        switch self {
        case .commandEconomy:
            return """
            The state owns all means of production. Central planners set production \
            quotas, allocate resources, and fix prices. Five-Year Plans guide \
            industrial development. Private enterprise is prohibited.
            """
        case .marketSocialism:
            return """
            The state controls strategic industries—steel, coal, banking, railways—while \
            permitting limited private enterprise in consumer goods and services. \
            Regional industrial bureaus compete for central investment. Price controls \
            apply to essential goods only.
            """
        case .mixedEconomy:
            return """
            A blend of state enterprise and private ownership. The government \
            nationalizes key industries while allowing competitive markets elsewhere. \
            Welfare programs and labor protections balance capitalist incentives.
            """
        case .freeMarket:
            return """
            Private ownership dominates the economy. Markets set prices with minimal \
            state intervention. Business interests shape policy. Labor protections \
            and welfare programs are limited.
            """
        case .cronyCapitalism:
            return """
            Nominally capitalist but controlled by state-connected elites. Contracts \
            and licenses flow to political allies. Competition is suppressed. The \
            economy serves regime stability over efficiency.
            """
        }
    }

    // MARK: - Economic Characteristics

    /// Base annual growth potential (percentage points)
    var baseGrowthRate: Double {
        switch self {
        case .commandEconomy: return 3.0    // Stable but inefficient
        case .marketSocialism: return 5.0   // Best growth potential
        case .mixedEconomy: return 4.0      // Balanced growth
        case .freeMarket: return 4.5        // High but volatile
        case .cronyCapitalism: return 2.0   // Rent-seeking drags growth
        }
    }

    /// How prone to inflation (0-100 scale)
    var inflationTendency: Int {
        switch self {
        case .commandEconomy: return 10     // Price controls limit official inflation (shortages instead)
        case .marketSocialism: return 25    // Moderate, managed
        case .mixedEconomy: return 35       // Some market pressure
        case .freeMarket: return 45         // Market-driven, can spike
        case .cronyCapitalism: return 55    // Often printing money
        }
    }

    /// Gini coefficient tendency (0-100, higher = more inequality)
    var inequalityFactor: Int {
        switch self {
        case .commandEconomy: return 20     // Low inequality, everyone equally poor
        case .marketSocialism: return 30    // Moderate, some private wealth
        case .mixedEconomy: return 40       // Middle ground
        case .freeMarket: return 55         // High inequality
        case .cronyCapitalism: return 65    // Oligarch wealth concentration
        }
    }

    /// State control level (0-100, higher = more state involvement)
    var stateControlLevel: Int {
        switch self {
        case .commandEconomy: return 95     // Near total control
        case .marketSocialism: return 70    // Strong state, some markets
        case .mixedEconomy: return 45       // Balanced
        case .freeMarket: return 20         // Minimal state
        case .cronyCapitalism: return 60    // High but selective
        }
    }

    /// Volatility (0-100, higher = more boom/bust cycles)
    var volatility: Int {
        switch self {
        case .commandEconomy: return 15     // Stable (problems hidden)
        case .marketSocialism: return 25    // Controlled cycles
        case .mixedEconomy: return 40       // Some market fluctuation
        case .freeMarket: return 60         // Full business cycles
        case .cronyCapitalism: return 50    // Political shocks
        }
    }

    /// Trade openness (0-100, higher = more foreign trade)
    var tradeOpenness: Int {
        switch self {
        case .commandEconomy: return 20     // State monopoly limits trade
        case .marketSocialism: return 50    // Selective openness
        case .mixedEconomy: return 65       // Generally open
        case .freeMarket: return 80         // Free trade emphasis
        case .cronyCapitalism: return 35    // Controlled by elites
        }
    }

    // MARK: - Era-Appropriate Institutions

    /// Key institutions for this economic type (1940s-60s appropriate)
    var keyInstitutions: [String] {
        switch self {
        case .commandEconomy:
            return [
                "State Planning Commission",
                "People's Commissariats of Industry",
                "Central Procurement Boards",
                "State Price Committee",
                "Collective Farm Administration"
            ]
        case .marketSocialism:
            return [
                "People's Bank of America",
                "State Reconstruction Bank",
                "Regional Industrial Bureaus",
                "Foreign Trade Ministry",
                "Agricultural Credit Cooperatives"
            ]
        case .mixedEconomy:
            return [
                "National Development Bank",
                "Industrial Policy Commission",
                "Labor Relations Board",
                "Price Stabilization Authority",
                "Trade Promotion Office"
            ]
        case .freeMarket:
            return [
                "Federal Reserve System",
                "Securities Exchange Commission",
                "Chamber of Commerce",
                "International Trade Office",
                "Anti-Trust Division"
            ]
        case .cronyCapitalism:
            return [
                "State Development Corporation",
                "Presidential Economic Council",
                "Import Licensing Authority",
                "Currency Control Board",
                "Industrial Monopoly Trust"
            ]
        }
    }
}

// MARK: - Five-Year Plan Phase

enum FiveYearPlanPhase: String, Codable, CaseIterable {
    case planning             // Year 0: Setting targets
    case launching            // Year 1: Initial investment
    case accelerating         // Year 2-3: Peak production push
    case consolidating        // Year 4: Meeting targets
    case completing           // Year 5: Final assessment

    var displayName: String {
        switch self {
        case .planning: return "Planning Phase"
        case .launching: return "Launch Phase"
        case .accelerating: return "Acceleration Phase"
        case .consolidating: return "Consolidation Phase"
        case .completing: return "Completion Phase"
        }
    }

    /// Modifier to economic growth during this phase
    var growthModifier: Double {
        switch self {
        case .planning: return 0.8      // Slower during planning
        case .launching: return 1.0     // Normal
        case .accelerating: return 1.3  // Push for targets
        case .consolidating: return 1.1 // Maintaining momentum
        case .completing: return 0.9    // Winding down before next plan
        }
    }
}

// MARK: - Economic Crisis Type

enum EconomicCrisisType: String, Codable, CaseIterable {
    case shortage             // Consumer goods unavailable
    case hyperinflation       // Currency collapse
    case bankRun              // Financial panic
    case harvestFailure       // Agricultural crisis
    case industrialCollapse   // Factory closures
    case tradeBlockade        // External trade cut off
    case laborUnrest          // Strikes and work stoppages
    case blackMarket          // Underground economy dominates

    var displayName: String {
        switch self {
        case .shortage: return "Goods Shortage"
        case .hyperinflation: return "Currency Crisis"
        case .bankRun: return "Banking Panic"
        case .harvestFailure: return "Harvest Failure"
        case .industrialCollapse: return "Industrial Collapse"
        case .tradeBlockade: return "Trade Blockade"
        case .laborUnrest: return "Labor Unrest"
        case .blackMarket: return "Black Market Crisis"
        }
    }

    /// Era-appropriate description
    var description: String {
        switch self {
        case .shortage:
            return "Store shelves stand empty. Citizens queue for hours for basic necessities. The black market flourishes."
        case .hyperinflation:
            return "The currency loses value daily. Workers spend wages immediately before prices rise again. Barter replaces money."
        case .bankRun:
            return "Depositors line up to withdraw savings. Banks lack sufficient reserves. Credit freezes."
        case .harvestFailure:
            return "Drought, flood, or mismanagement devastates crops. Grain procurement fails. Rationing becomes necessary."
        case .industrialCollapse:
            return "Factories stand idle. Workers are laid off. Production quotas go unmet. Industrial output plummets."
        case .tradeBlockade:
            return "Foreign ports close to our ships. Essential imports cease. Strategic stockpiles dwindle."
        case .laborUnrest:
            return "Strikes spread across industrial centers. Workers demand better conditions. Production halts."
        case .blackMarket:
            return "Official commerce withers. Underground traders dominate distribution. State authority erodes."
        }
    }

    /// Primary stat affected
    var primaryImpact: String {
        switch self {
        case .shortage: return "popularSupport"
        case .hyperinflation: return "treasury"
        case .bankRun: return "treasury"
        case .harvestFailure: return "popularSupport"
        case .industrialCollapse: return "treasury"
        case .tradeBlockade: return "treasury"
        case .laborUnrest: return "stability"
        case .blackMarket: return "stability"
        }
    }

    /// Severity level (1-5)
    var severity: Int {
        switch self {
        case .shortage: return 2
        case .hyperinflation: return 5
        case .bankRun: return 4
        case .harvestFailure: return 4
        case .industrialCollapse: return 4
        case .tradeBlockade: return 3
        case .laborUnrest: return 3
        case .blackMarket: return 2
        }
    }
}
