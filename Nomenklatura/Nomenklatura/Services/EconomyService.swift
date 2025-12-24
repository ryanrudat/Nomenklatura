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

    // MARK: - Income Calculations

    private func calculateDomesticProduction(game: Game) -> Int {
        // Sum industrial + agricultural output from all regions
        // Each point of capacity/output = roughly $0.5M per turn

        var totalProduction = 0

        for region in game.regions {
            let industrialValue = region.industrialCapacity / 5  // 0-20 per region
            let agriculturalValue = region.agriculturalOutput / 10  // 0-10 per region

            // Modify by regional loyalty/stability (popularLoyalty is 0-100)
            let loyaltyModifier = Double(region.popularLoyalty) / 100.0  // Normalize to 0-1
            let effectiveProduction = Double(industrialValue + agriculturalValue) * (0.5 + loyaltyModifier * 0.5)

            totalProduction += Int(effectiveProduction)
        }

        // Base production even with minimal regions
        return max(10, totalProduction)
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

        var baseMilitary = 15  // Baseline military cost

        // Add for each hostile neighbor (relationshipScore < -60)
        let hostileCount = game.foreignCountries.filter { $0.relationshipScore < -60 }.count
        baseMilitary += hostileCount * 3

        // Add for low military loyalty (need to pay more to keep them loyal)
        if game.militaryLoyalty < 40 {
            baseMilitary += (40 - game.militaryLoyalty) / 5
        }

        // Check for war flag
        if game.flags.contains("at_war") {
            baseMilitary += 20
        }

        return baseMilitary
    }

    private func calculateSocialPrograms(game: Game) -> Int {
        // Social spending affects popular support
        // Higher spending = more stability but less treasury

        var baseSocial = 10  // Baseline social costs

        // If popular support is low, pressure to spend more
        if game.popularSupport < 50 {
            baseSocial += (50 - game.popularSupport) / 10
        }

        // If stability is low, emergency social spending
        if game.stability < 40 {
            baseSocial += 5
        }

        return baseSocial
    }

    private func calculateInfrastructureCosts(game: Game) -> Int {
        // Based on number of regions and their development
        let regionCount = game.regions.count
        var infraCost = regionCount * 2

        // Additional costs for developed industrial regions
        let industrialRegions = game.regions.filter {
            RegionType(rawValue: $0.regionType) == .industrial
        }
        infraCost += industrialRegions.count * 3

        return infraCost
    }

    private func calculateDebtPayments(game: Game) -> Int {
        // Check for debt flags
        if game.flags.contains("soviet_debt") {
            return 5  // Paying back USSR for revolution support
        }
        return 0
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

        // 1. Calculate GDP growth based on policies and economic system
        let gdpChange = calculateGDPGrowth(game: game)
        game.applyGDPChange(gdpChange)

        // 2. Calculate inflation based on policies and economic conditions
        let inflationChange = calculateInflationChange(game: game)
        game.applyInflationChange(inflationChange)

        // 3. Calculate unemployment based on economic performance
        let unemploymentChange = calculateUnemploymentChange(game: game)
        game.applyUnemploymentChange(unemploymentChange)

        // 4. Update trade balance based on foreign relations
        game.tradeBalance = calculateTradeBalance(game: game)

        // 5. Update sector shares based on policy focus
        updateSectorShares(game: game)

        // 6. Advance Five-Year Plan (every 4 turns = 1 year)
        if game.turnNumber % 4 == 0 {
            game.advanceFiveYearPlanYear()
        }

        // 7. Check for economic crises and create events if needed
        checkForEconomicCrisis(game: game)

        #if DEBUG
        print("[Economy] GDP: \(game.gdpIndex), Inflation: \(game.inflationRate)%, Unemployment: \(game.unemploymentRate)%")
        #endif
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

    /// Process foreign country economies each turn
    func processForeignEconomies(game: Game) {
        for country in game.foreignCountries {
            country.processEconomicTurn()
        }
    }
}
