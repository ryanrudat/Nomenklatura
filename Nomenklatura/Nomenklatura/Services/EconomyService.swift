//
//  EconomyService.swift
//  Nomenklatura
//
//  Dynamic economy simulation tied to regions, foreign trade, and world events.
//  Treasury is calculated each turn based on production, trade, and expenses.
//

import Foundation

// MARK: - Economy Service

@MainActor
class EconomyService {

    static let shared = EconomyService()

    // MARK: - Economic Report

    struct EconomicReport {
        // Income sources
        var domesticProduction: Int = 0
        var foreignTrade: Int = 0
        var foreignAid: Int = 0
        var resourceExtraction: Int = 0

        // Expense categories
        var militarySpending: Int = 0
        var socialPrograms: Int = 0
        var infrastructureCosts: Int = 0
        var debtPayments: Int = 0
        var crisisResponse: Int = 0
        var corruption: Int = 0

        // Modifiers
        var embargoEffects: Int = 0  // Negative from hostile nations
        var tradeAgreementBonus: Int = 0
        var warCosts: Int = 0

        var totalIncome: Int {
            domesticProduction + foreignTrade + foreignAid + resourceExtraction + tradeAgreementBonus
        }

        var totalExpenses: Int {
            militarySpending + socialPrograms + infrastructureCosts +
            debtPayments + crisisResponse + corruption + abs(embargoEffects) + warCosts
        }

        var netChange: Int {
            totalIncome - totalExpenses
        }

        var breakdown: [(String, Int, Bool)] {
            // (label, value, isIncome)
            var items: [(String, Int, Bool)] = []

            // Income
            if domesticProduction > 0 { items.append(("Domestic Production", domesticProduction, true)) }
            if foreignTrade > 0 { items.append(("Foreign Trade", foreignTrade, true)) }
            if foreignAid > 0 { items.append(("Foreign Aid", foreignAid, true)) }
            if resourceExtraction > 0 { items.append(("Resource Extraction", resourceExtraction, true)) }
            if tradeAgreementBonus > 0 { items.append(("Trade Agreements", tradeAgreementBonus, true)) }

            // Expenses
            if militarySpending > 0 { items.append(("Military Spending", -militarySpending, false)) }
            if socialPrograms > 0 { items.append(("Social Programs", -socialPrograms, false)) }
            if infrastructureCosts > 0 { items.append(("Infrastructure", -infrastructureCosts, false)) }
            if debtPayments > 0 { items.append(("Debt Payments", -debtPayments, false)) }
            if crisisResponse > 0 { items.append(("Crisis Response", -crisisResponse, false)) }
            if corruption > 0 { items.append(("Inefficiency", -corruption, false)) }
            if embargoEffects > 0 { items.append(("Trade Embargoes", -embargoEffects, false)) }
            if warCosts > 0 { items.append(("War Costs", -warCosts, false)) }

            return items
        }
    }

    // MARK: - Calculate Turn Economy

    /// Calculate economic changes for the current turn
    func calculateTurnEconomy(game: Game) -> EconomicReport {
        var report = EconomicReport()

        // === INCOME ===

        // 1. Domestic Production (from regions)
        report.domesticProduction = calculateDomesticProduction(game: game)

        // 2. Foreign Trade (from friendly/neutral nations)
        report.foreignTrade = calculateForeignTrade(game: game)

        // 3. Foreign Aid (from socialist allies)
        report.foreignAid = calculateForeignAid(game: game)

        // 4. Resource Extraction (mining, oil, etc.)
        report.resourceExtraction = calculateResourceExtraction(game: game)

        // === EXPENSES ===

        // 5. Military Spending
        report.militarySpending = calculateMilitarySpending(game: game)

        // 6. Social Programs (healthcare, education, housing)
        report.socialPrograms = calculateSocialPrograms(game: game)

        // 7. Infrastructure Maintenance
        report.infrastructureCosts = calculateInfrastructureCosts(game: game)

        // 8. Debt Payments (if applicable)
        report.debtPayments = calculateDebtPayments(game: game)

        // 9. Crisis Response (ongoing emergencies)
        report.crisisResponse = calculateCrisisResponse(game: game)

        // 10. Corruption/Inefficiency (inverse of stability)
        report.corruption = calculateCorruption(game: game)

        // === MODIFIERS ===

        // 11. Embargo Effects (from hostile nations)
        report.embargoEffects = calculateEmbargoEffects(game: game)

        // 12. Trade Agreement Bonuses
        report.tradeAgreementBonus = calculateTradeAgreementBonus(game: game)

        // 13. War Costs (if in conflict)
        report.warCosts = calculateWarCosts(game: game)

        return report
    }

    /// Apply the economic report to the game
    func applyEconomicReport(_ report: EconomicReport, to game: Game) {
        let change = report.netChange

        // Apply treasury change (clamped to prevent going too negative)
        let newTreasury = max(-100, game.treasury + change)
        let actualChange = newTreasury - game.treasury

        if actualChange != 0 {
            game.applyStat("treasury", change: actualChange)
        }

        // Store the report for display
        game.lastEconomicReport = encodeReport(report)
    }

    /// Store a fresh report snapshot without mutating game stats.
    func snapshotEconomicReport(game: Game) {
        let report = calculateTurnEconomy(game: game)
        game.lastEconomicReport = encodeReport(report)
    }

    // MARK: - Income Calculations

    private func calculateDomesticProduction(game: Game) -> Int {
        // Sum industrial + agricultural output from all regions
        // Each point of capacity/output = roughly $0.5M per turn

        var totalProduction = 0

        for region in game.regions {
            let industrialValue = region.industrialCapacity / 4  // 0-25 per region (boosted)
            let agriculturalValue = region.agriculturalOutput / 8  // 0-12 per region (boosted)

            // Modify by regional loyalty/stability (popularLoyalty is 0-100)
            let loyaltyModifier = Double(region.popularLoyalty) / 100.0  // Normalize to 0-1
            let effectiveProduction = Double(industrialValue + agriculturalValue) * (0.6 + loyaltyModifier * 0.4)

            totalProduction += Int(effectiveProduction)
        }

        // Base production even with minimal regions (boosted baseline)
        return max(15, totalProduction)
    }

    private func calculateForeignTrade(game: Game) -> Int {
        // Sum trade volumes with non-hostile nations
        var totalTrade = 0

        for country in game.foreignCountries {
            // Only count trade from countries that aren't actively hostile
            guard country.relationshipScore > -60 else { continue }  // Not hostile

            // Trade volume modified by relationship
            let relationshipMultiplier: Double = {
                if country.relationshipScore > 60 { return 1.2 }       // Strong Ally
                else if country.relationshipScore > 30 { return 1.0 }  // Friendly
                else if country.relationshipScore > -30 { return 0.7 } // Neutral
                else { return 0.4 }                                     // Unfriendly
            }()

            let effectiveTrade = Double(country.tradeVolume) * relationshipMultiplier
            totalTrade += Int(effectiveTrade / 5)  // Scale down for game balance
        }

        return totalTrade
    }

    private func calculateForeignAid(game: Game) -> Int {
        // Aid from socialist allies (USSR, Germany)
        var aid = 0

        for country in game.foreignCountries {
            // Only allied socialist nations provide aid
            let govType = country.governmentType
            guard govType == .socialistRepublic || govType == .communistState else { continue }
            guard country.relationshipScore > 30 else { continue }  // At least friendly

            // Aid based on their economic power and relationship
            let baseAid = country.economicPower / 20
            let relationshipBonus = country.relationshipScore > 60 ? 2 : 1  // Strong ally bonus
            aid += baseAid * relationshipBonus
        }

        return aid
    }

    private func calculateResourceExtraction(game: Game) -> Int {
        // Based on resource-rich regions
        var resources = 0

        for region in game.regions {
            let regionType = RegionType(rawValue: region.regionType) ?? .industrial
            switch regionType {
            case .extractive:
                resources += 15  // Mining regions are valuable
            case .industrial:
                resources += 5   // Some raw materials processing
            case .border:
                resources += 3   // Limited resources, strategic value
            case .coastal:
                resources += 4   // Port trade value
            default:
                resources += 1
            }
        }

        return resources
    }

    // MARK: - Expense Calculations

    private func calculateMilitarySpending(game: Game) -> Int {
        // Military spending based on:
        // - Number of hostile neighbors
        // - Current military loyalty needs
        // - Any ongoing conflicts

        var baseMilitary = 8  // Baseline military cost (reduced from 15)

        // Add for each hostile neighbor (relationshipScore < -60)
        let hostileCount = game.foreignCountries.filter { $0.relationshipScore < -60 }.count
        baseMilitary += hostileCount * 2

        // Add for low military loyalty (need to pay more to keep them loyal)
        if game.militaryLoyalty < 40 {
            baseMilitary += (40 - game.militaryLoyalty) / 8
        }

        // Check for war flag
        if game.flags.contains("at_war") {
            baseMilitary += 15
        }

        return baseMilitary
    }

    private func calculateSocialPrograms(game: Game) -> Int {
        // Social spending affects popular support
        // Higher spending = more stability but less treasury

        var baseSocial = 6  // Baseline social costs (reduced from 10)

        // If popular support is low, pressure to spend more
        if game.popularSupport < 40 {
            baseSocial += (40 - game.popularSupport) / 10
        }

        // If stability is low, emergency social spending
        if game.stability < 30 {
            baseSocial += 3
        }

        return baseSocial
    }

    private func calculateInfrastructureCosts(game: Game) -> Int {
        // Based on number of regions and their development
        let regionCount = game.regions.count
        var infraCost = regionCount  // Reduced from regionCount * 2

        // Additional costs for developed industrial regions
        let industrialRegions = game.regions.filter {
            RegionType(rawValue: $0.regionType) == .industrial
        }
        infraCost += industrialRegions.count * 2

        return infraCost
    }

    private func calculateDebtPayments(game: Game) -> Int {
        var debt = 0

        // Legacy debt flags
        if game.flags.contains("soviet_debt") {
            debt += 5  // Paying back USSR for revolution support
        }

        // Foreign loan payments
        debt += game.totalDebtService

        return debt
    }

    private func calculateCrisisResponse(game: Game) -> Int {
        // Ongoing crisis costs
        var crisisCost = 0

        if game.flags.contains("famine_ongoing") {
            crisisCost += 15
        }
        if game.flags.contains("industrial_accident") {
            crisisCost += 10
        }
        if game.flags.contains("natural_disaster") {
            crisisCost += 12
        }
        if game.flags.contains("epidemic") {
            crisisCost += 8
        }

        return crisisCost
    }

    private func calculateCorruption(game: Game) -> Int {
        // Corruption/inefficiency is inverse of stability
        // Lower stability = more waste
        let inefficiency = max(0, (100 - game.stability) / 10)
        return inefficiency
    }

    // MARK: - Modifier Calculations

    private func calculateEmbargoEffects(game: Game) -> Int {
        // Trade losses from hostile nations
        var embargoLoss = 0

        for country in game.foreignCountries {
            if country.relationshipScore < -60 {  // Hostile
                // Lost trade potential based on their economic power
                embargoLoss += country.economicPower / 20

                // Extra penalty if they control key shipping lanes
                if country.countryId == "uk" || country.countryId == "japan" {
                    embargoLoss += 5  // Naval powers hurt trade more
                }
            }
        }

        return embargoLoss
    }

    private func calculateTradeAgreementBonus(game: Game) -> Int {
        var bonus = 0

        for country in game.foreignCountries {
            // Check for active trade agreements via treaties
            if country.hasTreaty(of: .tradeAgreement) {
                bonus += country.economicPower / 25
            }
        }

        return bonus
    }

    private func calculateWarCosts(game: Game) -> Int {
        var warCost = 0

        // Check for active conflicts
        if game.flags.contains("war_with_canada") {
            warCost += 25
        }
        if game.flags.contains("war_with_uk") {
            warCost += 30
        }
        if game.flags.contains("war_with_japan") {
            warCost += 20
        }
        if game.flags.contains("intervention_abroad") {
            warCost += 15
        }

        return warCost
    }

    // MARK: - Helper Methods

    private func encodeReport(_ report: EconomicReport) -> Data? {
        // Encode report for storage
        let dict: [String: Int] = [
            "domesticProduction": report.domesticProduction,
            "foreignTrade": report.foreignTrade,
            "foreignAid": report.foreignAid,
            "resourceExtraction": report.resourceExtraction,
            "militarySpending": report.militarySpending,
            "socialPrograms": report.socialPrograms,
            "infrastructureCosts": report.infrastructureCosts,
            "debtPayments": report.debtPayments,
            "crisisResponse": report.crisisResponse,
            "corruption": report.corruption,
            "embargoEffects": report.embargoEffects,
            "tradeAgreementBonus": report.tradeAgreementBonus,
            "warCosts": report.warCosts
        ]
        return try? JSONEncoder().encode(dict)
    }

    func decodeReport(_ data: Data) -> EconomicReport? {
        guard let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return nil
        }

        var report = EconomicReport()
        report.domesticProduction = dict["domesticProduction"] ?? 0
        report.foreignTrade = dict["foreignTrade"] ?? 0
        report.foreignAid = dict["foreignAid"] ?? 0
        report.resourceExtraction = dict["resourceExtraction"] ?? 0
        report.militarySpending = dict["militarySpending"] ?? 0
        report.socialPrograms = dict["socialPrograms"] ?? 0
        report.infrastructureCosts = dict["infrastructureCosts"] ?? 0
        report.debtPayments = dict["debtPayments"] ?? 0
        report.crisisResponse = dict["crisisResponse"] ?? 0
        report.corruption = dict["corruption"] ?? 0
        report.embargoEffects = dict["embargoEffects"] ?? 0
        report.tradeAgreementBonus = dict["tradeAgreementBonus"] ?? 0
        report.warCosts = dict["warCosts"] ?? 0
        return report
    }

    // MARK: - Economic Projections

    /// Project treasury 3 turns ahead based on current conditions
    func projectTreasury(game: Game, turns: Int = 3) -> [Int] {
        let report = calculateTurnEconomy(game: game)
        var projections: [Int] = [game.treasury]

        for i in 1...turns {
            // Simple projection assuming conditions stay same
            let projected = game.treasury + (report.netChange * i)
            projections.append(max(-100, projected))
        }

        return projections
    }

    /// Get economic health status
    func getEconomicHealth(game: Game) -> EconomicHealth {
        let report = calculateTurnEconomy(game: game)

        if game.treasury < 0 {
            return .crisis
        } else if report.netChange < -10 {
            return .declining
        } else if report.netChange < 0 {
            return .stagnant
        } else if report.netChange < 10 {
            return .stable
        } else {
            return .growing
        }
    }

    enum EconomicHealth: String {
        case crisis = "Economic Crisis"
        case declining = "Declining"
        case stagnant = "Stagnant"
        case stable = "Stable"
        case growing = "Growing"

        var color: String {
            switch self {
            case .crisis: return "C41E3A"   // Red
            case .declining: return "CC7000" // Orange
            case .stagnant: return "808080"  // Gray
            case .stable: return "2D5A27"    // Green
            case .growing: return "28A745"   // Bright green
            }
        }
    }

    // MARK: - Macro Economic Processing (1940s-60s Era)

    /// Process all macro economic changes for the turn
    /// Updates GDP, inflation, unemployment, and sector shares based on policies
    func processEconomy(game: Game) {
        #if DEBUG
        print("[Economy] Processing macro economy for turn \(game.turnNumber)")
        #endif

        // Record all economic indicators to history before changes
        game.recordEconomicHistory()

        // 1. Calculate GDP growth based on policies, treasury, and economic system
        let gdpChange = calculateGDPGrowth(game: game)
        game.applyGDPChange(gdpChange)

        // 2. GDP affects Treasury - higher GDP = more tax revenue
        applyGDPToTreasury(game: game)


        // 3. Calculate inflation based on policies and economic conditions
        let inflationChange = calculateInflationChange(game: game)
        game.applyInflationChange(inflationChange)

        // 4. Calculate unemployment based on economic performance
        let unemploymentChange = calculateUnemploymentChange(game: game)
        game.applyUnemploymentChange(unemploymentChange)

        // 5. Update trade balance based on foreign relations
        game.tradeBalance = calculateTradeBalance(game: game)

        // 6. Update sector shares based on policy focus and performance
        updateSectorShares(game: game)

        // 7. Apply sector production effects to national stats
        applySectorEffects(game: game)

        // 7a. Apply per-sector budget allocation effects
        applySectorBudgetEffects(game: game)

        // 7b. Process foreign loan payments
        processLoanPayments(game: game)

        // 8. Process regional economies (interoperability with national economy)
        processRegionalEconomies(game: game)

        // 9. Advance Five-Year Plan (every 4 turns = 1 year)
        if game.turnNumber % 4 == 0 {
            game.advanceFiveYearPlanYear()
        }

        // 10. Check for economic crises and create events if needed
        checkForEconomicCrisis(game: game)

        #if DEBUG
        print("[Economy] GDP: \(game.gdpIndex), Inflation: \(game.inflationRate)%, Unemployment: \(game.unemploymentRate)%, Treasury: \(game.treasury)")
        #endif
    }

    /// Apply GDP effects to Treasury (the interoperability between GDP and Treasury)
    private func applyGDPToTreasury(game: Game) {
        // GDP growth affects tax revenue
        let growthRate = game.gdpGrowthRate

        // Calculate treasury change based on GDP performance
        var treasuryChange = 0

        // Strong GDP growth generates revenue surplus
        if growthRate > 5.0 {
            treasuryChange = 3
        } else if growthRate > 2.0 {
            treasuryChange = 1
        } else if growthRate < -3.0 {
            treasuryChange = -3  // Recession costs money
        } else if growthRate < 0.0 {
            treasuryChange = -1  // Stagnation drains reserves
        }

        // High GDP base provides more revenue even with slow growth
        if game.gdpIndex >= 120 {
            treasuryChange += 2
        } else if game.gdpIndex >= 110 {
            treasuryChange += 1
        } else if game.gdpIndex <= 80 {
            treasuryChange -= 2  // Collapsed economy drains treasury
        } else if game.gdpIndex <= 90 {
            treasuryChange -= 1
        }

        // Inflation erodes treasury value
        if game.inflationRate >= 30 {
            treasuryChange -= 3
        } else if game.inflationRate >= 20 {
            treasuryChange -= 1
        }

        // Apply the change
        if treasuryChange != 0 {
            game.applyStat("treasury", change: treasuryChange)
        }
    }

    /// Apply sector production effects to national stats
    private func applySectorEffects(game: Game) {
        // Agriculture sector affects food supply
        let agricultureEffect = (game.agricultureShare - 20) / 10  // Baseline is 20%
        if agricultureEffect != 0 {
            game.applyStat("foodSupply", change: agricultureEffect)
        }

        // Industry sector affects industrial output and GDP
        let industryEffect = (game.industryShare - 45) / 15  // Baseline is 45%
        if industryEffect != 0 {
            game.applyStat("industrialOutput", change: industryEffect)
        }

        // Services sector affects popular support (consumer goods availability)
        let servicesEffect = (game.servicesShare - 35) / 20  // Baseline is 35%
        if servicesEffect != 0 {
            game.applyStat("popularSupport", change: servicesEffect)
        }
    }

    /// Calculate GDP growth based on economic system and policies
    private func calculateGDPGrowth(game: Game) -> Int {
        let system = game.currentEconomicSystem
        var growth = Int(system.baseGrowthRate)

        // Modify based on active policies
        // Enterprise management policy
        if let slot = game.policySlot(withId: "enterprise_management") {
            switch slot.currentOptionId {
            case "central_quotas":
                growth -= 2  // Less flexible, less growth
            case "regional_flexibility":
                growth += 1  // Moderate flexibility
            case "manager_autonomy":
                growth += 3  // High growth but more inequality
            default:
                break
            }
        }

        // Private enterprise policy
        if let slot = game.policySlot(withId: "private_enterprise") {
            switch slot.currentOptionId {
            case "private_prohibited":
                growth -= 3  // Pure socialism, less growth
            case "small_plots":
                growth += 1  // Some private activity
            case "licensed_businesses":
                growth += 4  // Significant private sector
            default:
                break
            }
        }

        // Foreign trade policy
        if let slot = game.policySlot(withId: "foreign_trade") {
            switch slot.currentOptionId {
            case "state_monopoly":
                growth -= 1  // Limited trade
            case "licensed_companies":
                growth += 2  // Some openness
            case "joint_ventures":
                growth += 3  // Foreign investment boost
            default:
                break
            }
        }

        // Price controls policy
        if let slot = game.policySlot(withId: "price_controls") {
            switch slot.currentOptionId {
            case "full_control":
                growth -= 2  // Shortages reduce efficiency
            case "strategic_only":
                growth += 0  // Neutral
            case "market_signals":
                growth += 2  // More efficient but more inequality
            default:
                break
            }
        }

        // Economic health affects growth
        if game.stability < 40 {
            growth -= 2  // Instability hurts growth
        }
        if game.popularSupport < 30 {
            growth -= 1  // Low morale hurts productivity
        }

        // Treasury affects state investment capacity (GDP <-> Treasury interoperability)
        if game.treasury >= 80 {
            growth += 3  // Ample state resources fuel investment
        } else if game.treasury >= 60 {
            growth += 1  // Healthy finances support growth
        } else if game.treasury <= 20 {
            growth -= 3  // Empty treasury cripples state investment
        } else if game.treasury <= 35 {
            growth -= 1  // Low resources limit growth
        }

        // Industrial output affects economic productivity
        if game.industrialOutput >= 70 {
            growth += 2  // Strong industrial base
        } else if game.industrialOutput <= 35 {
            growth -= 2  // Weak industrial capacity limits growth
        }

        // Trade agreements boost growth (capped to prevent runaway bonus)
        let tradeAgreementCount = game.foreignCountries.filter { $0.hasTreaty(of: .tradeAgreement) }.count
        growth += min(3, tradeAgreementCount)  // Cap at +3 from trade

        // Five-Year Plan phase affects growth
        let planPhase = FiveYearPlanPhase(rawValue: game.fiveYearPlanPhase) ?? .launching
        let phaseModifier = planPhase.growthModifier
        growth = Int(Double(growth) * phaseModifier)

        // Cap growth at reasonable bounds
        return max(-10, min(10, growth))
    }

    /// Calculate inflation change based on policies and conditions
    private func calculateInflationChange(game: Game) -> Int {
        let system = game.currentEconomicSystem
        let targetInflation = system.inflationTendency

        // Move toward system's natural inflation level
        var change = (targetInflation - game.inflationRate) / 20

        // Price controls reduce inflation
        if let slot = game.policySlot(withId: "price_controls") {
            switch slot.currentOptionId {
            case "full_control":
                change -= 3  // Strong anti-inflation
            case "strategic_only":
                change -= 1  // Moderate control
            case "market_signals":
                change += 2  // Market-driven prices rise
            default:
                break
            }
        }

        // Treasury deficit causes inflation
        if game.treasury < 0 {
            change += abs(game.treasury) / 20  // Deficit spending inflationary
        }

        // War is inflationary
        if game.flags.contains("at_war") {
            change += 3
        }

        // Random economic shocks
        change += Int.random(in: -1...1)

        return max(-5, min(5, change))
    }

    /// Calculate unemployment change based on economic conditions
    private func calculateUnemploymentChange(game: Game) -> Int {
        var change = 0

        // GDP growth reduces unemployment
        if game.gdpGrowthRate > 3 {
            change -= 1
        } else if game.gdpGrowthRate < 0 {
            change += 2
        }

        // Private enterprise affects employment
        if let slot = game.policySlot(withId: "private_enterprise") {
            switch slot.currentOptionId {
            case "private_prohibited":
                change += 1  // State jobs only
            case "licensed_businesses":
                change -= 2  // Private sector creates jobs
            default:
                break
            }
        }

        // Industrial regions affect employment
        let industrialOutput = game.regions.reduce(0) { $0 + $1.industrialCapacity }
        if industrialOutput > 50 {
            change -= 1
        }

        // Random fluctuation
        change += Int.random(in: -1...1)

        return max(-3, min(3, change))
    }

    /// Calculate trade balance with foreign countries
    private func calculateTradeBalance(game: Game) -> Int {
        var balance = 0

        for country in game.foreignCountries {
            // Only count actual trading partners
            guard country.relationshipScore > -30 else { continue }

            // Trade agreements add to surplus
            if country.hasTreaty(of: .tradeAgreement) {
                balance += 3
            }

            // Friendly socialist countries favorable
            if country.politicalBloc == .socialist && country.relationshipScore > 30 {
                balance += 2
            }

            // Hostile countries create deficit (lost markets)
            if country.relationshipScore < -60 {
                balance -= country.economicPower / 30
            }
        }

        // Foreign trade policy affects balance
        if let slot = game.policySlot(withId: "foreign_trade") {
            switch slot.currentOptionId {
            case "state_monopoly":
                balance -= 3  // Less competitive
            case "joint_ventures":
                balance += 5  // More exports
            default:
                break
            }
        }

        return max(-30, min(30, balance))
    }

    /// Update sector shares based on economic policies
    private func updateSectorShares(game: Game) {
        // Sector shares should add to 100
        var agriculture = game.agricultureShare
        var industry = game.industryShare
        var services = game.servicesShare

        // Heavy industry emphasis in command economy
        if game.currentEconomicSystem == .commandEconomy {
            industry += 1
            agriculture -= 1
        }

        // Private enterprise grows services
        if let slot = game.policySlot(withId: "private_enterprise") {
            if slot.currentOptionId == "licensed_businesses" {
                services += 2
                industry -= 1
                agriculture -= 1
            }
        }

        // Normalize to 100
        let total = agriculture + industry + services

        // Guard against divide-by-zero - use balanced defaults if total is 0
        guard total > 0 else {
            game.agricultureShare = 20
            game.industryShare = 45
            game.servicesShare = 35
            return
        }

        game.agricultureShare = max(10, min(40, agriculture * 100 / total))
        game.industryShare = max(30, min(60, industry * 100 / total))
        game.servicesShare = 100 - game.agricultureShare - game.industryShare

        // Process detailed sector performance
        processSectorPerformance(game: game)
    }

    /// Process each sector's performance, applying dependencies and natural drift
    private func processSectorPerformance(game: Game) {
        // Process each sector
        for sector in EconomicSector.allCases {
            var productionChange = 0
            var moraleChange = 0
            var efficiencyChange = 0

            let currentPerf = game.sectorPerformance(for: sector)

            // 1. Check dependency health - weak dependencies hurt production
            for depSector in sector.dependencies {
                let depPerf = game.sectorPerformance(for: depSector)
                if depPerf.actualOutput < 40 {
                    productionChange -= 3  // Dependent sector struggling
                } else if depPerf.actualOutput < 60 {
                    productionChange -= 1
                } else if depPerf.actualOutput >= 80 {
                    productionChange += 1  // Strong dependencies boost output
                }
            }

            // 2. Investment effects - investment drives production growth
            if currentPerf.investmentLevel >= 70 {
                productionChange += 2
                efficiencyChange += 1
            } else if currentPerf.investmentLevel <= 30 {
                productionChange -= 2  // Underinvestment causes decay
                efficiencyChange -= 1
            }

            // Investment naturally decays (needs constant allocation)
            game.applySectorChange(sector, investmentChange: -3)

            // 3. Morale effects from national conditions
            if game.popularSupport >= 70 {
                moraleChange += 1
            } else if game.popularSupport <= 30 {
                moraleChange -= 2
            }

            // Stability affects worker morale
            if game.stability <= 40 {
                moraleChange -= 1
            }

            // 4. Policy effects on specific sectors
            applySectorPolicyEffects(game: game, sector: sector, productionChange: &productionChange, efficiencyChange: &efficiencyChange)

            // 5. Apply changes
            game.applySectorChange(sector, productionChange: productionChange, moraleChange: moraleChange, efficiencyChange: efficiencyChange)

            // 6. Sector output affects national economy
            let newPerf = game.sectorPerformance(for: sector)
            applySectorToNationalEconomy(game: game, sector: sector, performance: newPerf)
        }
    }

    /// Apply policy effects to specific sectors
    private func applySectorPolicyEffects(game: Game, sector: EconomicSector, productionChange: inout Int, efficiencyChange: inout Int) {
        switch sector {
        case .agriculture:
            // Collectivization policy affects agriculture
            if let slot = game.policySlot(withId: "private_enterprise") {
                if slot.currentOptionId == "private_prohibited" {
                    efficiencyChange -= 2  // Collectivized agriculture less efficient
                } else if slot.currentOptionId == "small_plots" {
                    efficiencyChange += 2  // Private plots boost agriculture
                    productionChange += 1
                }
            }

        case .heavyIndustry:
            // Central planning favors heavy industry
            if game.currentEconomicSystem == .commandEconomy {
                productionChange += 2  // State priority
            }

        case .lightIndustry:
            // Market mechanisms help consumer goods
            if let slot = game.policySlot(withId: "price_controls") {
                if slot.currentOptionId == "market_signals" {
                    efficiencyChange += 2
                    productionChange += 1
                } else if slot.currentOptionId == "full_control" {
                    productionChange -= 2  // Shortages from price controls
                }
            }

        case .defense:
            // Military loyalty affects defense production
            if game.militaryLoyalty >= 70 {
                efficiencyChange += 1
            }

        case .energy, .mining:
            // Regional industrial capacity affects extraction industries
            let totalRegionalIndustry = game.regions.reduce(0) { $0 + $1.industrialCapacity }
            if totalRegionalIndustry >= 60 {
                productionChange += 1
            } else if totalRegionalIndustry <= 30 {
                productionChange -= 1
            }

        case .construction:
            // Treasury affects state construction projects
            if game.treasury >= 70 {
                productionChange += 2
            } else if game.treasury <= 30 {
                productionChange -= 2
            }

        case .transport:
            // Foreign trade policy affects transport
            if let slot = game.policySlot(withId: "foreign_trade") {
                if slot.currentOptionId == "joint_ventures" {
                    productionChange += 1  // More goods to move
                }
            }
        }
    }

    /// Apply sector output to national economic indicators
    private func applySectorToNationalEconomy(game: Game, sector: EconomicSector, performance: SectorPerformance) {
        let output = performance.actualOutput

        // Strong sectors boost their primary stat
        if output >= 70 {
            game.applyStat(sector.primaryEffect, change: 1)
        } else if output <= 30 {
            game.applyStat(sector.primaryEffect, change: -1)
        }

        // Very strong/weak sectors affect secondary stat
        if output >= 85 {
            game.applyStat(sector.secondaryEffect, change: 1)
        } else if output <= 20 {
            game.applyStat(sector.secondaryEffect, change: -1)
        }

        // Sector collapse triggers crisis flag
        if output <= 15 {
            let crisisFlag = "sector_crisis_\(sector.rawValue)"
            if !game.flags.contains(crisisFlag) {
                game.flags.append(crisisFlag)
            }
        }
    }

    // MARK: - Regional Economic Processing

    /// Process all regional economies and their impact on national indicators
    private func processRegionalEconomies(game: Game) {
        #if DEBUG
        print("[Economy] Processing regional economies for \(game.regions.count) regions")
        #endif

        for region in game.regions {
            // 1. Process this region's economy
            processRegionEconomy(region: region, game: game)

            // 2. Apply regional contribution to national economy
            applyRegionToNational(region: region, game: game)

            // 3. Apply national conditions to region
            applyNationalToRegion(region: region, game: game)
        }

        // 4. Calculate aggregate regional effects
        calculateAggregateRegionalEffects(game: game)
    }

    /// Process individual region's economic performance
    private func processRegionEconomy(region: Region, game: Game) {
        // Regional economic drift based on type and conditions
        var industryChange = 0
        var agricultureChange = 0
        var infrastructureChange = 0

        // 1. Regional type affects base performance
        switch region.type {
        case .industrial:
            industryChange += 1
            agricultureChange -= 1
        case .agricultural:
            agricultureChange += 1
            industryChange -= 1
        case .extractive:
            industryChange += 1
            // Natural resource regions support industry
        case .border:
            // Border regions maintain military focus
            industryChange -= 1
        case .capital:
            industryChange += 1
            infrastructureChange += 1
        case .autonomous:
            // Autonomous regions have their own dynamics
            break
        case .coastal:
            industryChange += 1
            // Trade access boosts industry
        }

        // 2. Party control affects economic efficiency
        if region.partyControl >= 80 {
            industryChange += 1  // Strong organization helps
        } else if region.partyControl <= 30 {
            industryChange -= 2  // Weak control hurts productivity
            agricultureChange -= 1
        }

        // 3. Popular loyalty affects output
        if region.popularLoyalty >= 70 {
            industryChange += 1
            agricultureChange += 1
        } else if region.popularLoyalty <= 30 {
            industryChange -= 2  // Workers resist
            agricultureChange -= 2
        }

        // 4. Infrastructure affects everything
        if region.infrastructureQuality >= 70 {
            industryChange += 1
            agricultureChange += 1
        } else if region.infrastructureQuality <= 30 {
            industryChange -= 2
            agricultureChange -= 1
        }

        // 5. National policies affect regions
        if game.currentEconomicSystem == .commandEconomy {
            industryChange += 1  // Central direction helps industry
            agricultureChange -= 1  // But hurts agriculture
        } else if game.currentEconomicSystem == .marketSocialism {
            agricultureChange += 1  // Market incentives help farming
        }

        // 6. Apply changes with dampening to prevent wild swings
        region.industrialCapacity = max(10, min(100, region.industrialCapacity + industryChange / 2))
        region.agriculturalOutput = max(10, min(100, region.agriculturalOutput + agricultureChange / 2))

        // Infrastructure decays slowly without investment
        if region.infrastructureQuality > 50 {
            infrastructureChange -= 1
        }
        region.infrastructureQuality = max(10, min(100, region.infrastructureQuality + infrastructureChange / 2))
    }

    /// Apply region's economic output to national indicators
    private func applyRegionToNational(region: Region, game: Game) {
        let contribution = region.economicContribution
        let scaleFactor = Double(contribution) / 100.0

        // Large/important regions have more impact
        if contribution >= 15 {
            // Major economic region
            if region.industrialCapacity >= 70 {
                game.applyStat("industrialOutput", change: 1)
            } else if region.industrialCapacity <= 30 {
                game.applyStat("industrialOutput", change: -1)
            }

            if region.agriculturalOutput >= 70 {
                game.applyStat("foodSupply", change: 1)
            } else if region.agriculturalOutput <= 30 {
                game.applyStat("foodSupply", change: -1)
            }
        }

        // Regional instability affects national stability
        if region.status.severity >= 2 {
            let stabilityPenalty = Int(Double(region.status.severity) * scaleFactor * 2)
            game.applyStat("stability", change: -stabilityPenalty)
        }

        // Regional resource output affects treasury
        if region.naturalResources >= 70 {
            let resourceBonus = Int(scaleFactor * 2)
            game.applyStat("treasury", change: resourceBonus)
        }
    }

    /// Apply national economic conditions to a region
    private func applyNationalToRegion(region: Region, game: Game) {
        // National prosperity lifts all regions
        if game.gdpIndex >= 110 {
            region.industrialCapacity = min(100, region.industrialCapacity + 1)
            region.infrastructureQuality = min(100, region.infrastructureQuality + 1)
        } else if game.gdpIndex <= 80 {
            region.industrialCapacity = max(10, region.industrialCapacity - 1)
        }

        // National food situation affects regional loyalty
        if game.foodSupply >= 70 {
            region.popularLoyalty = min(100, region.popularLoyalty + 1)
        } else if game.foodSupply <= 30 {
            region.popularLoyalty = max(0, region.popularLoyalty - 2)
            region.autonomyDesire = min(100, region.autonomyDesire + 1)
        }

        // High inflation hurts all regions
        if game.inflationRate >= 30 {
            region.popularLoyalty = max(0, region.popularLoyalty - 1)
        }

        // National stability affects regions
        if game.stability >= 70 {
            region.partyControl = min(100, region.partyControl + 1)
        } else if game.stability <= 30 {
            region.partyControl = max(0, region.partyControl - 2)
            region.autonomyDesire = min(100, region.autonomyDesire + 2)
        }
    }

    /// Calculate aggregate effects of all regions on national economy
    private func calculateAggregateRegionalEffects(game: Game) {
        guard !game.regions.isEmpty else { return }

        // Calculate average regional health
        let totalIndustrial = game.regions.reduce(0) { $0 + $1.industrialCapacity }
        let totalAgricultural = game.regions.reduce(0) { $0 + $1.agriculturalOutput }
        let totalInfrastructure = game.regions.reduce(0) { $0 + $1.infrastructureQuality }
        let regionCount = game.regions.count

        let avgIndustrial = totalIndustrial / regionCount
        let avgAgricultural = totalAgricultural / regionCount
        let avgInfrastructure = totalInfrastructure / regionCount

        // Strong regional infrastructure boosts GDP
        if avgInfrastructure >= 70 {
            game.applyStat("gdpIndex", change: 1)
        } else if avgInfrastructure <= 30 {
            game.applyStat("gdpIndex", change: -1)
        }

        // Count crisis regions
        let crisisRegions = game.regions.filter { $0.status.severity >= 2 }.count
        if crisisRegions >= 3 {
            // NOTE: Stability penalty for widespread regional crisis is handled by
            // RegionSecessionService.processCascadeEffects() to avoid double-penalizing.
            // EconomyService only applies the elite loyalty and flag effects here.
            game.applyStat("eliteLoyalty", change: -2)
            if !game.flags.contains("regional_crisis_widespread") {
                game.flags.append("regional_crisis_widespread")
            }
        }

        // Count highly productive regions
        let productiveRegions = game.regions.filter { $0.industrialCapacity >= 70 || $0.agriculturalOutput >= 70 }.count
        if productiveRegions >= game.regions.count / 2 {
            game.applyStat("treasury", change: 2)
        }

        #if DEBUG
        print("[Economy] Regional averages - Industry: \(avgIndustrial), Agriculture: \(avgAgricultural), Infrastructure: \(avgInfrastructure)")
        #endif
    }

    /// Check for and create economic crisis events
    private func checkForEconomicCrisis(game: Game) {
        guard game.hasEconomicCrisis else { return }

        if let crisisType = game.currentEconomicCrisisType {
            #if DEBUG
            print("[Economy] CRISIS DETECTED: \(crisisType.displayName)")
            #endif

            // Apply crisis effects based on type and severity
            switch crisisType {
            case .shortage:
                // Consumer goods unavailable
                game.applyStat("popularSupport", change: -10)
                game.applyStat("stability", change: -3)
            case .hyperinflation:
                // Currency collapse - most severe
                game.applyStat("stability", change: -12)
                game.applyStat("popularSupport", change: -15)
                game.applyStat("treasury", change: -10)
            case .bankRun:
                // Financial panic
                game.applyStat("treasury", change: -20)
                game.applyStat("eliteLoyalty", change: -10)
                game.applyStat("stability", change: -5)
            case .harvestFailure:
                // Agricultural crisis
                game.applyStat("popularSupport", change: -15)
                game.applyStat("stability", change: -8)
                game.applyStat("foodSupply", change: -15)
            case .industrialCollapse:
                // Factory closures
                game.applyStat("treasury", change: -15)
                game.applyStat("industrialOutput", change: -10)
                game.applyStat("stability", change: -5)
            case .tradeBlockade:
                // External trade cut off
                game.applyStat("treasury", change: -12)
                game.applyStat("industrialOutput", change: -5)
            case .laborUnrest:
                // Strikes and work stoppages
                game.applyStat("stability", change: -10)
                game.applyStat("industrialOutput", change: -8)
                game.applyStat("popularSupport", change: 3)  // Workers feel empowered
            case .blackMarket:
                // Underground economy
                game.applyStat("stability", change: -5)
                game.applyStat("treasury", change: -8)  // Lost tax revenue
            }
        }
    }

    /// Process foreign country economies each turn with full interoperability
    func processForeignEconomies(game: Game) {
        #if DEBUG
        print("[Economy] Processing foreign economies for \(game.foreignCountries.count) countries")
        #endif

        for country in game.foreignCountries {
            // 1. Process the country's internal economy
            country.processEconomicTurn()

            // 2. Apply player's economy effects on this country
            applyPlayerEconomyEffects(from: game, to: country)

            // 3. Apply this country's economy effects on player
            applyForeignEconomyEffects(from: country, to: game)

            // 4. Check for economic reform triggers
            checkForeignEconomicReforms(country: country, game: game)

            // 5. Check for crisis contagion
            checkEconomicContagion(from: country, to: game)
        }

        // 6. Calculate global economic trend
        updateGlobalEconomicTrend(game: game)
    }

    /// Player's economic performance affects trading partners
    private func applyPlayerEconomyEffects(from game: Game, to country: ForeignCountry) {
        // Only allies and neutral countries are affected
        guard country.relationshipScore > -30 else { return }

        // Strong player economy helps trading partners
        if game.gdpIndex >= 110 && country.hasTreaty(of: .tradeAgreement) {
            country.applyGDPGrowthChange(1)
        }

        // Player recession hurts trade partners
        if game.isInRecession && country.hasTreaty(of: .tradeAgreement) {
            country.applyGDPGrowthChange(-1)
        }

        // Aid packages boost receiving country
        if country.hasTreaty(of: .aidPackage) {
            country.applyGDPGrowthChange(2)
            country.applyUnemploymentChange(-1)
        }
    }

    /// Foreign country's economy affects player
    private func applyForeignEconomyEffects(from country: ForeignCountry, to game: Game) {
        // Socialist bloc allies' performance affects our economy
        if country.politicalBloc == .socialist && country.relationshipScore > 30 {
            // Strong ally economies help us
            if country.gdpGrowth >= 5 {
                game.applyStat("gdpIndex", change: 1)
            }

            // Ally in crisis hurts us
            if country.hasEconomicCrisis {
                game.applyStat("gdpIndex", change: -1)
                game.applyStat("treasury", change: -2)  // Aid obligations
            }
        }

        // Major trading partner's economic health affects trade balance
        if country.hasTreaty(of: .tradeAgreement) {
            if country.gdpGrowth <= -3 {
                // Partner in recession = reduced exports
                game.tradeBalance = max(-30, game.tradeBalance - 2)
            } else if country.gdpGrowth >= 5 {
                // Thriving partner = increased exports
                game.tradeBalance = min(30, game.tradeBalance + 1)
            }
        }

        // Economic powerhouse countries affect global conditions
        if country.economicPower >= 80 {
            // Soviet Union or major power economic shifts affect us
            if country.hasEconomicCrisis {
                game.applyStat("stability", change: -2)  // Global uncertainty
            }
        }
    }

    /// Check if foreign country triggers economic reform
    private func checkForeignEconomicReforms(country: ForeignCountry, game: Game) {
        // Countries in crisis may reform
        guard country.hasReformPressure else { return }

        // Roll for reform (higher tendency = higher chance)
        let reformChance = country.economicReformTendency + (country.consecutiveGDPDeclines * 10)
        let roll = Int.random(in: 0...100)

        if roll < reformChance {
            let currentSystem = country.currentEconomicSystem
            let newSystem = determineEconomicReform(from: currentSystem, for: country)

            if newSystem != currentSystem {
                country.changeEconomicSystem(to: newSystem)

                #if DEBUG
                print("[Economy] \(country.name) reformed from \(currentSystem.displayName) to \(newSystem.displayName)")
                #endif
            }
        }
    }

    /// Determine what economic system a country reforms to
    private func determineEconomicReform(from current: EconomicSystemType, for country: ForeignCountry) -> EconomicSystemType {
        switch current {
        case .commandEconomy:
            // Command economies can liberalize
            return .marketSocialism

        case .cronyCapitalism:
            // Crony capitalism can reform toward free market or mixed
            return Bool.random() ? .mixedEconomy : .freeMarket

        case .freeMarket:
            // Free market in crisis may adopt more state control
            return .mixedEconomy

        case .mixedEconomy:
            // Mixed can go either direction based on government type
            if country.governmentType == .communistState || country.governmentType == .socialistRepublic {
                return .marketSocialism
            } else {
                return Bool.random() ? .freeMarket : .mixedEconomy
            }

        case .marketSocialism:
            // Market socialism can revert to command or liberalize further
            return Bool.random() ? .commandEconomy : .mixedEconomy
        }
    }

    /// Economic crisis contagion - crisis in one country can spread
    private func checkEconomicContagion(from country: ForeignCountry, to game: Game) {
        guard country.hasEconomicCrisis else { return }
        guard country.relationshipScore > -50 else { return }  // Must have some connection

        // Calculate contagion risk
        var contagionRisk = 0

        // Geographic proximity increases risk
        if country.borderingRegionId != nil {
            contagionRisk += 15
        }

        // Trade ties increase risk
        if country.hasTreaty(of: .tradeAgreement) {
            contagionRisk += 20
        }

        // Same political bloc increases risk
        if country.politicalBloc == .socialist {
            contagionRisk += 10
        }

        // Large economy = more impact
        contagionRisk += country.economicPower / 10

        // Roll for contagion
        let roll = Int.random(in: 0...100)
        if roll < contagionRisk {
            // Contagion effect - minor economic impact
            game.applyStat("stability", change: -1)

            // Specific crisis types have specific contagion effects
            if country.gdpGrowth <= -5 {
                game.applyStat("gdpIndex", change: -1)
            }
            if country.countryInflationRate >= 30 {
                game.applyInflationChange(1)
            }

            #if DEBUG
            print("[Economy] Economic contagion from \(country.name) affecting PSR")
            #endif
        }
    }

    /// Update global economic trend based on all foreign economies
    private func updateGlobalEconomicTrend(game: Game) {
        var totalGrowth = 0
        var crisisCount = 0
        var boomCount = 0

        for country in game.foreignCountries {
            totalGrowth += country.gdpGrowth

            if country.hasEconomicCrisis { crisisCount += 1 }
            if country.gdpGrowth >= 5 { boomCount += 1 }
        }

        let countryCount = max(1, game.foreignCountries.count)
        let averageGrowth = totalGrowth / countryCount

        // Global recession affects everyone
        if averageGrowth < 0 && crisisCount >= 3 {
            if !game.flags.contains("global_recession") {
                game.flags.append("global_recession")
                game.applyStat("gdpIndex", change: -3)
                game.applyStat("treasury", change: -5)

                #if DEBUG
                print("[Economy] Global recession triggered")
                #endif
            }
        } else if game.flags.contains("global_recession") && averageGrowth > 2 {
            // Recovery from global recession
            game.flags.removeAll { $0 == "global_recession" }

            #if DEBUG
            print("[Economy] Global recession ended")
            #endif
        }

        // Global boom benefits everyone
        if averageGrowth >= 4 && boomCount >= 4 {
            if !game.flags.contains("global_boom") {
                game.flags.append("global_boom")
                game.applyStat("gdpIndex", change: 2)

                #if DEBUG
                print("[Economy] Global economic boom")
                #endif
            }
        } else if game.flags.contains("global_boom") && averageGrowth < 2 {
            game.flags.removeAll { $0 == "global_boom" }
        }
    }

    // MARK: - Per-Sector Budget Effects

    /// Apply investment and production changes based on sector budget allocations
    private func applySectorBudgetEffects(game: Game) {
        let budget = game.sectorBudget

        for sector in EconomicSector.allCases {
            let allocation = budget[sector.rawValue] ?? Game.defaultAllocation(for: sector)
            let defaultAlloc = Game.defaultAllocation(for: sector)
            let deviation = allocation - defaultAlloc

            var investmentChange = 0
            var productionChange = 0

            // Sectors above default get +2 investment per turn
            if deviation > 0 {
                investmentChange += 2
            }
            // Sectors below default get -2 investment per turn
            if deviation < 0 {
                investmentChange -= 2
            }
            // Large deviation (10%+) also affects production
            if deviation >= 10 {
                productionChange += 1
            }
            if deviation <= -10 {
                productionChange -= 1
            }

            if investmentChange != 0 || productionChange != 0 {
                game.applySectorChange(sector, productionChange: productionChange, investmentChange: investmentChange)
            }
        }
    }

    // MARK: - Foreign Loan Processing

    /// Process loan payments, reducing principal and handling defaults
    private func processLoanPayments(game: Game) {
        var loans = game.foreignLoans
        var defaulted = false

        for i in loans.indices {
            guard !loans[i].isFullyPaid else { continue }

            let payment = loans[i].paymentPerTurn
            let principalPortion = loans[i].principalPaymentPerTurn
            let interestPortion = loans[i].interestPaymentPerTurn

            if game.treasury >= payment / 5 {
                // Can afford payment - deduct from treasury
                game.applyStat("treasury", change: -payment)
                loans[i].remainingPrincipal = max(0, loans[i].remainingPrincipal - principalPortion)
                loans[i].totalInterestPaid += interestPortion
            } else {
                // Cannot afford - default on this loan
                defaulted = true

                #if DEBUG
                print("[Economy] Defaulted on loan from \(loans[i].lenderName)")
                #endif
            }
        }

        // Remove fully paid loans
        loans.removeAll { $0.isFullyPaid }
        game.foreignLoans = loans

        // Apply default penalties
        if defaulted {
            game.applyStat("stability", change: -3)

            // Damage relationships with all lender countries (use local array, already saved above)
            for loan in loans where !loan.isFullyPaid {
                for country in game.foreignCountries where country.countryId == loan.lenderId {
                    country.relationshipScore = max(-100, country.relationshipScore - 5)
                }
            }

            if !game.flags.contains("debt_default") {
                game.flags.append("debt_default")
            }
        } else {
            // Clear default flag if no defaults this turn
            game.flags.removeAll { $0 == "debt_default" }
        }
    }

    /// Look up the effective relationship score for a loan source
    private func lenderRelationship(game: Game, source: LoanSource) -> Int {
        if let country = game.foreignCountries.first(where: { $0.countryId == source.lenderId }) {
            return country.relationshipScore
        }
        // International institutions - use average western relationship
        let western = game.foreignCountries.filter { $0.politicalBloc == .capitalist }
        return western.isEmpty ? 0 : western.reduce(0) { $0 + $1.relationshipScore } / western.count
    }

    /// Take a new foreign loan, adding principal to treasury
    func takeLoan(game: Game, source: LoanSource, amount: Int) {
        let relationship = lenderRelationship(game: game, source: source)
        let rate = source.interestRate(forRelationship: relationship)
        let clampedAmount = max(5, min(amount, source.maxAmount))

        let loan = ForeignLoan(
            lenderId: source.lenderId,
            lenderName: source.lenderName,
            principalAmount: clampedAmount,
            interestRate: rate,
            turnTaken: game.turnNumber,
            durationTurns: source.durationTurns
        )

        var loans = game.foreignLoans
        loans.append(loan)
        game.foreignLoans = loans

        // Immediately add principal to treasury
        game.applyStat("treasury", change: clampedAmount)

        #if DEBUG
        print("[Economy] Took loan of \(clampedAmount) from \(source.lenderName) at \(rate)% interest")
        #endif
    }

    /// Get available loan sources for the player based on current relationships
    func availableLoanSources(game: Game) -> [(source: LoanSource, relationship: Int, available: Bool)] {
        let hasCapacity = game.canTakeNewLoan
        return LoanSource.allSources.map { source in
            let relationship = lenderRelationship(game: game, source: source)
            let meetsRelationship = relationship >= source.requiredRelationship
            return (source, relationship, meetsRelationship && hasCapacity)
        }
    }
}
