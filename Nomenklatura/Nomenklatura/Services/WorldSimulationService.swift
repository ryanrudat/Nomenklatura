//
//  WorldSimulationService.swift
//  Nomenklatura
//
//  Dynamic world simulation - RDR2-style living world where events happen independently
//

import Foundation

// MARK: - World Simulation Service

/// Service for simulating world events and relationship changes
final class WorldSimulationService {
    static let shared = WorldSimulationService()

    private init() {}

    // MARK: - Event Probabilities

    /// Base probability for each event type per nation per turn
    private let eventProbabilities: [WorldEventType: Double] = [
        .leadershipChange: 0.02,      // 2% per nation per turn
        .coup: 0.005,                  // 0.5% - rare
        .revolution: 0.008,            // 0.8% - rare but impactful
        .purge: 0.03,                  // 3% in socialist nations
        .electionResult: 0.02,         // 2% in democracies
        .economicCrisis: 0.025,        // 2.5%
        .industrialAccident: 0.02,     // 2%
        .harvestFailure: 0.015,        // 1.5%
        .tradeDispute: 0.03,           // 3%
        .resourceDiscovery: 0.01,      // 1% - rare positive
        .borderIncident: 0.04,         // 4% - more common for hostile nations
        .armsBuildUp: 0.03,            // 3%
        .defection: 0.015,             // 1.5%
        .militaryExercise: 0.04,       // 4%
        .proxyConflict: 0.02,          // 2%
        .treatyProposal: 0.025,        // 2.5%
        .treatyViolation: 0.01,        // 1%
        .ambassadorRecall: 0.015,      // 1.5%
        .summitAnnouncement: 0.02,     // 2%
        .secretNegotiations: 0.015     // 1.5%
    ]

    // MARK: - Turn Simulation

    /// Simulate world events for a turn
    /// Returns list of events that occurred
    func simulateTurn(game: Game) -> [WorldEvent] {
        var events: [WorldEvent] = []

        // 1. Simulate relationship drift for each nation
        simulateRelationshipDrift(game: game)

        // 2. Generate random world events
        events.append(contentsOf: generateWorldEvents(game: game))

        // 3. Process NPC diplomatic actions and add to events
        let npcDiplomaticEvents = processNPCDiplomacy(game: game)
        events.append(contentsOf: npcDiplomaticEvents)

        // 4. Check for economic reforms in foreign countries
        events.append(contentsOf: checkForEconomicReforms(game: game))

        // 5. Check for cascading consequences
        events.append(contentsOf: processCascadingConsequences(events: events, game: game))

        // 6. Update game state based on events
        applyEventEffects(events: events, game: game)

        return events
    }

    // MARK: - NPC Diplomatic Processing

    /// Process NPC diplomatic actions and convert to world events
    private func processNPCDiplomacy(game: Game) -> [WorldEvent] {
        // Get NPC diplomatic events from InternationalEventService
        let npcEvents = InternationalEventService.shared.processNPCDiplomaticActions(game: game)

        // Convert to WorldEvents for consistent handling
        return npcEvents.compactMap { event in
            convertNPCEventToWorldEvent(event, game: game)
        }
    }

    /// Convert an NPC diplomatic event to a WorldEvent
    private func convertNPCEventToWorldEvent(_ event: NPCDiplomaticEvent, game: Game) -> WorldEvent? {
        guard let countryId = event.targetCountryId else { return nil }

        // Map action type to world event type
        let worldEventType: WorldEventType
        switch event.actionType {
        case .proposedTreaty:
            worldEventType = .treatyProposal
        case .conductedNegotiations, .strengthenedAlliance:
            worldEventType = .summitAnnouncement
        case .expandedTrade:
            worldEventType = .tradeDispute  // Positive trade news
        case .defusedCrisis, .respondedToCrisis:
            worldEventType = .secretNegotiations
        case .counteredWesternInfluence:
            worldEventType = .secretNegotiations
        case .proposedPolicyChange:
            return nil  // Policy changes don't map to world events
        case .conductedEspionage:
            return nil  // Espionage is classified
        }

        let countryName = event.targetCountryName ?? "foreign nation"

        return WorldEvent(
            eventType: worldEventType,
            turnOccurred: event.turn,
            countryId: countryId,
            headline: generateNPCEventHeadline(event, countryName: countryName),
            description: generateNPCEventDescription(event, countryName: countryName),
            isClassified: event.actionType == .conductedEspionage
        )
    }

    /// Generate headline for NPC-initiated world event
    private func generateNPCEventHeadline(_ event: NPCDiplomaticEvent, countryName: String) -> String {
        switch event.actionType {
        case .proposedTreaty:
            return "\(countryName.uppercased()): TREATY TALKS BEGIN"
        case .conductedNegotiations:
            return "DIPLOMATIC PROGRESS WITH \(countryName.uppercased())"
        case .strengthenedAlliance:
            return "ALLIANCE WITH \(countryName.uppercased()) STRENGTHENED"
        case .counteredWesternInfluence:
            return "WESTERN INFLUENCE IN \(countryName.uppercased()) COUNTERED"
        case .expandedTrade:
            return "TRADE AGREEMENT WITH \(countryName.uppercased())"
        case .defusedCrisis:
            return "CRISIS WITH \(countryName.uppercased()) RESOLVED"
        case .respondedToCrisis:
            return "\(countryName.uppercased()) SITUATION ADDRESSED"
        case .proposedPolicyChange, .conductedEspionage:
            return "DIPLOMATIC ACTIVITY"
        }
    }

    /// Generate description for NPC-initiated world event
    private func generateNPCEventDescription(_ event: NPCDiplomaticEvent, countryName: String) -> String {
        let officialName = event.characterName

        switch event.actionType {
        case .proposedTreaty:
            return "\(officialName) has initiated formal treaty negotiations with \(countryName). The discussions are expected to address matters of mutual interest."
        case .conductedNegotiations:
            return "Diplomatic talks with \(countryName) continue under the direction of \(officialName). Progress is reported on key issues."
        case .strengthenedAlliance:
            return "Consultations led by \(officialName) have resulted in strengthened ties with \(countryName), reinforcing socialist bloc unity."
        case .counteredWesternInfluence:
            return "Through diplomatic efforts directed by \(officialName), Western attempts to extend influence over \(countryName) have been successfully countered."
        case .expandedTrade:
            return "New trade arrangements with \(countryName), negotiated by \(officialName), will increase economic cooperation between our nations."
        case .defusedCrisis:
            return "A diplomatic crisis with \(countryName) has been successfully de-escalated through the intervention of \(officialName)."
        case .respondedToCrisis:
            return "The Foreign Ministry, under \(officialName)'s direction, has addressed the recent international incident involving \(countryName)."
        default:
            return "Diplomatic activities continue as the Foreign Ministry maintains relations with \(countryName)."
        }
    }

    // MARK: - Relationship Drift

    /// Natural drift of relationships based on ideology and history
    private func simulateRelationshipDrift(game: Game) {
        for country in game.foreignCountries {
            var drift: Int = 0

            // Ideological pull
            drift += calculateIdeologicalPull(country: country)

            // Economic pressure
            drift += calculateEconomicPressure(country: country, game: game)

            // Random factor (-2 to +2)
            drift += Int.random(in: -2...2)

            // Apply drift (small amounts)
            country.modifyRelationship(by: drift)
        }
    }

    /// Calculate ideological drift based on bloc alignment
    private func calculateIdeologicalPull(country: ForeignCountry) -> Int {
        switch country.politicalBloc {
        case .socialist:
            // Allied nations drift slightly toward closer relations
            return country.relationshipScore < 80 ? 1 : 0
        case .capitalist:
            // Capitalist nations drift slightly hostile
            return country.relationshipScore > -80 ? -1 : 0
        case .nonAligned:
            // Non-aligned drift toward neutral (0)
            if country.relationshipScore > 10 { return -1 }
            if country.relationshipScore < -10 { return 1 }
            return 0
        case .rival:
            // Rivals drift hostile unless very negative already
            return country.relationshipScore > -60 ? -1 : 0
        }
    }

    /// Calculate economic pressure on relations
    private func calculateEconomicPressure(country: ForeignCountry, game: Game) -> Int {
        // High trade volume improves relations slightly
        if country.tradeVolume > 50 { return 1 }
        // Very low trade with capitalists increases tension
        if country.politicalBloc == .capitalist && country.tradeVolume < 10 { return -1 }
        return 0
    }

    // MARK: - World Event Generation

    /// Generate random world events for the turn
    private func generateWorldEvents(game: Game) -> [WorldEvent] {
        var events: [WorldEvent] = []

        // Limit events per turn (max 2-3 to avoid overwhelming)
        let maxEvents = Int.random(in: 1...3)
        var eventCount = 0

        for country in game.foreignCountries {
            guard eventCount < maxEvents else { break }

            // Determine eligible event types based on country characteristics
            let eligibleTypes = getEligibleEventTypes(for: country)

            for eventType in eligibleTypes {
                guard eventCount < maxEvents else { break }

                // Check probability with modifiers
                let baseProbability = eventProbabilities[eventType] ?? 0.01
                let modifiedProbability = baseProbability * probabilityModifier(for: eventType, country: country, game: game)

                if Double.random(in: 0...1) < modifiedProbability {
                    if let event = createEvent(type: eventType, country: country, game: game) {
                        events.append(event)
                        eventCount += 1
                    }
                }
            }
        }

        return events
    }

    /// Get event types eligible for a specific country
    private func getEligibleEventTypes(for country: ForeignCountry) -> [WorldEventType] {
        var types: [WorldEventType] = [
            .borderIncident, .tradeDispute, .treatyProposal,
            .summitAnnouncement, .secretNegotiations
        ]

        // Political events based on government type
        switch country.governmentType {
        case .communistState, .socialistRepublic:
            types.append(contentsOf: [.purge, .leadershipChange])
        case .liberalDemocracy, .constitutionalMonarchy:
            types.append(contentsOf: [.electionResult, .leadershipChange])
        case .authoritarianRepublic, .militaryJunta:
            types.append(contentsOf: [.coup, .leadershipChange, .purge])
        case .absoluteMonarchy, .theocracy:
            types.append(contentsOf: [.revolution, .leadershipChange])
        }

        // Economic events
        types.append(contentsOf: [.economicCrisis, .harvestFailure, .resourceDiscovery])

        // Military events for hostile nations
        if country.relationshipScore < -20 {
            types.append(contentsOf: [.armsBuildUp, .militaryExercise, .proxyConflict])
        }

        // Defection for socialist bloc
        if country.politicalBloc == .socialist || country.politicalBloc == .rival {
            types.append(.defection)
        }

        return types
    }

    /// Modify probability based on context
    private func probabilityModifier(for eventType: WorldEventType, country: ForeignCountry, game: Game) -> Double {
        var modifier: Double = 1.0

        // Border incidents more likely with hostile nations
        if eventType == .borderIncident && country.relationshipScore < -30 {
            modifier *= 2.0
        }

        // Revolutions more likely in unstable situations
        if eventType == .revolution || eventType == .coup {
            if game.stability < 40 { modifier *= 1.5 }
        }

        // Economic crises more likely with poor treasury
        if eventType == .economicCrisis {
            if game.treasury < 30 { modifier *= 1.3 }
        }

        // Treaty proposals more likely with neutral/friendly nations
        if eventType == .treatyProposal && country.relationshipScore > 0 {
            modifier *= 1.5
        }

        // EVENT CHAIN MODIFIERS: Check past events for this country
        let recentCountryEvents = game.worldEventsForCountry(country.countryId)
            .filter { $0.turnOccurred >= game.turnNumber - 3 }

        for pastEvent in recentCountryEvents {
            modifier *= eventChainModifier(newEvent: eventType, pastEvent: pastEvent)
        }

        return modifier
    }

    /// Calculate probability modifier based on event chains
    /// Returns > 1.0 if past event makes new event more likely
    private func eventChainModifier(newEvent: WorldEventType, pastEvent: WorldEvent) -> Double {
        _ = max(1, pastEvent.turnOccurred) // Reserved for future time-decay calculations

        switch (pastEvent.eventType, newEvent) {
        // Border incident chains
        case (.borderIncident, .armsBuildUp):
            return 1.5  // 50% more likely after border incident
        case (.borderIncident, .militaryExercise):
            return 1.4  // 40% more likely
        case (.borderIncident, .ambassadorRecall):
            return 1.3  // 30% more likely

        // Military buildup chains
        case (.armsBuildUp, .borderIncident):
            return 1.4
        case (.armsBuildUp, .proxyConflict):
            return 1.5
        case (.armsBuildUp, .treatyViolation):
            return 1.3

        // Revolution/coup chains
        case (.revolution, .purge):
            return 2.0  // Purges very likely after revolution
        case (.coup, .purge):
            return 2.0
        case (.revolution, .economicCrisis):
            return 1.5  // Economic disruption likely
        case (.coup, .economicCrisis):
            return 1.5

        // Economic crisis chains
        case (.economicCrisis, .tradeDispute):
            return 1.5
        case (.economicCrisis, .revolution):
            return 1.4  // Economic crisis can spark unrest
        case (.economicCrisis, .harvestFailure):
            return 1.3

        // Leadership change chains
        case (.leadershipChange, .purge):
            return 1.5  // New leaders often purge
        case (.leadershipChange, .treatyProposal):
            return 1.3  // New leaders may seek new alliances

        // Treaty chains
        case (.treatyProposal, .summitAnnouncement):
            return 1.6  // Proposals lead to summits
        case (.treatyViolation, .ambassadorRecall):
            return 1.8  // Violations cause diplomatic crises
        case (.treatyViolation, .borderIncident):
            return 1.4

        // Defection chains
        case (.defection, .secretNegotiations):
            return 1.3
        case (.defection, .ambassadorRecall):
            return 1.3

        default:
            return 1.0  // No modifier
        }
    }

    /// Create a specific event
    private func createEvent(type: WorldEventType, country: ForeignCountry, game: Game) -> WorldEvent? {
        let headline = generateHeadline(type: type, country: country)
        let description = generateDescription(type: type, country: country, game: game)

        var event = WorldEvent(
            eventType: type,
            turnOccurred: game.turnNumber,
            countryId: country.countryId,
            headline: headline,
            description: description,
            isClassified: type.severity >= .significant
        )

        // Add consequences
        event.consequences = generateConsequences(type: type, country: country, game: game)

        return event
    }

    // MARK: - Headline Generation

    private func generateHeadline(type: WorldEventType, country: ForeignCountry) -> String {
        let name = country.name.uppercased()

        switch type {
        case .leadershipChange:
            return "\(name): NEW LEADER EMERGES"
        case .coup:
            return "MILITARY COUP IN \(name)"
        case .revolution:
            return "REVOLUTION SWEEPS \(name)"
        case .purge:
            return "\(name) PARTY PURGE REPORTED"
        case .electionResult:
            return "\(name) ELECTION RESULTS"
        case .economicCrisis:
            return "ECONOMIC TURMOIL IN \(name)"
        case .industrialAccident:
            return "\(name) INDUSTRIAL DISASTER"
        case .harvestFailure:
            return "HARVEST FAILURE IN \(name)"
        case .tradeDispute:
            return "TRADE TENSIONS WITH \(name)"
        case .resourceDiscovery:
            return "RESOURCE DISCOVERY IN \(name)"
        case .borderIncident:
            return "BORDER INCIDENT WITH \(name)"
        case .armsBuildUp:
            return "\(name) MILITARY EXPANSION"
        case .defection:
            return "HIGH-PROFILE DEFECTION FROM \(name)"
        case .militaryExercise:
            return "\(name) MILITARY EXERCISES"
        case .proxyConflict:
            return "\(name) INVOLVEMENT IN CONFLICT"
        case .treatyProposal:
            return "\(name) PROPOSES AGREEMENT"
        case .treatyViolation:
            return "\(name) TREATY VIOLATION"
        case .ambassadorRecall:
            return "AMBASSADOR RECALLED FROM \(name)"
        case .summitAnnouncement:
            return "SUMMIT ANNOUNCED WITH \(name)"
        case .secretNegotiations:
            return "SECRET TALKS WITH \(name) REVEALED"
        }
    }

    private func generateDescription(type: WorldEventType, country: ForeignCountry, game: Game) -> String {
        // Generate contextual description based on event type and country
        switch type {
        case .borderIncident:
            return "Reports indicate shots were exchanged at the \(country.name) border. Casualties are unconfirmed. Both sides have lodged formal protests."
        case .economicCrisis:
            return "\(country.name) is experiencing significant economic difficulties. Production has fallen and popular discontent is rising."
        case .treatyProposal:
            return "The \(country.name) government has indicated interest in improving bilateral relations through formal agreement."
        case .leadershipChange:
            return "Political changes in \(country.name) have resulted in new leadership. The implications for our relations remain to be seen."
        default:
            return "Our intelligence services are monitoring the situation in \(country.name) closely."
        }
    }

    // MARK: - Consequences

    private func generateConsequences(type: WorldEventType, country: ForeignCountry, game: Game) -> [WorldEventConsequence] {
        var consequences: [WorldEventConsequence] = []

        switch type {
        case .borderIncident:
            consequences.append(WorldEventConsequence(
                type: .relationshipChange,
                targetId: country.countryId,
                amount: -10,
                description: "Relations strained by border incident"
            ))
            consequences.append(WorldEventConsequence(
                type: .militaryTension,
                targetId: country.countryId,
                amount: 15,
                description: "Military tensions increased"
            ))

        case .economicCrisis:
            if country.politicalBloc == .socialist {
                consequences.append(WorldEventConsequence(
                    type: .economicImpact,
                    targetId: nil,
                    amount: -3,
                    description: "Trade disruption affects our economy"
                ))
            }

        case .treatyProposal:
            consequences.append(WorldEventConsequence(
                type: .relationshipChange,
                targetId: country.countryId,
                amount: 5,
                description: "Diplomatic overture improves relations"
            ))

        case .revolution, .coup:
            consequences.append(WorldEventConsequence(
                type: .stabilityImpact,
                targetId: nil,
                amount: -5,
                description: "Regional instability affects stability"
            ))
            consequences.append(WorldEventConsequence(
                type: .relationshipChange,
                targetId: country.countryId,
                amount: Int.random(in: -20...20),
                description: "New government's alignment uncertain"
            ))

        default:
            break
        }

        return consequences
    }

    // MARK: - Cascading Consequences

    /// Process events that might trigger additional events
    private func processCascadingConsequences(events: [WorldEvent], game: Game) -> [WorldEvent] {
        // Placeholder for cascading event logic - not yet implemented
        let cascadedEvents: [WorldEvent] = []

        for event in events {
            // Revolution might trigger Atlantic Union response
            if event.eventType == .revolution {
                if let country = game.country(withId: event.countryId),
                   country.politicalBloc == .capitalist {
                    // TODO: Could trigger Atlantic Union intervention
                }
            }

            // Border incident might escalate
            if event.eventType == .borderIncident {
                // 20% chance of escalation
                if Double.random(in: 0...1) < 0.2 {
                    // TODO: Generate escalation event
                }
            }
        }

        return cascadedEvents
    }

    // MARK: - Apply Effects

    /// Apply event effects to game state
    private func applyEventEffects(events: [WorldEvent], game: Game) {
        for event in events {
            for consequence in event.consequences {
                switch consequence.type {
                case .relationshipChange:
                    if let countryId = consequence.targetId,
                       let country = game.country(withId: countryId) {
                        country.modifyRelationship(by: consequence.amount)
                    }

                case .economicImpact:
                    game.applyStat("treasury", change: consequence.amount)

                case .stabilityImpact:
                    game.applyStat("stability", change: consequence.amount)

                case .militaryTension:
                    if let countryId = consequence.targetId,
                       let country = game.country(withId: countryId) {
                        country.diplomaticTension = min(100, country.diplomaticTension + consequence.amount)
                    }

                case .triggerFollowUp:
                    // Queue follow-up event for next turn
                    break
                }
            }
        }
    }

    // MARK: - News Briefing Generation

    /// Generate a news briefing from recent events
    func generateBriefing(events: [WorldEvent], turn: Int) -> NewsBriefing {
        let isUrgent = events.contains { $0.severity >= .major }
        let headline = NewsBriefing.generateHeadline(from: events)

        return NewsBriefing(
            turn: turn,
            events: events,
            summaryHeadline: headline,
            isUrgent: isUrgent
        )
    }

    // MARK: - Intelligence Report Generation

    /// Generate intelligence reports for high-level players
    func generateIntelligenceReports(events: [WorldEvent], game: Game) -> [IntelligenceReport] {
        var reports: [IntelligenceReport] = []

        // Only generate reports for significant events
        let significantEvents = events.filter { $0.severity >= .significant }

        for event in significantEvents {
            if let country = game.country(withId: event.countryId) {
                let classification: IntelligenceReport.ClassificationLevel
                switch event.severity {
                case .critical: classification = .topSecret
                case .major: classification = .secret
                default: classification = .confidential
                }

                let report = IntelligenceReport(
                    turn: game.turnNumber,
                    classification: classification,
                    source: "Station Chief, \(country.name)",
                    subject: event.headline,
                    analysis: "Analysis of the situation indicates potential impacts on our strategic interests in the region.",
                    recommendedActions: generateRecommendedActions(for: event, country: country),
                    relatedEventIds: [event.id]
                )
                reports.append(report)
            }
        }

        return reports
    }

    private func generateRecommendedActions(for event: WorldEvent, country: ForeignCountry) -> [String] {
        switch event.eventType {
        case .borderIncident:
            return [
                "Increase military readiness in border regions",
                "Lodge formal diplomatic protest",
                "Prepare public statement"
            ]
        case .economicCrisis:
            return [
                "Consider emergency aid package to maintain influence",
                "Adjust trade projections",
                "Monitor for signs of political instability"
            ]
        case .revolution, .coup:
            return [
                "Establish contact with new leadership",
                "Assess impact on existing treaties",
                "Prepare contingency plans"
            ]
        default:
            return ["Continue monitoring situation"]
        }
    }

    // MARK: - Economic Reform Events

    /// Check for economic reforms in foreign countries based on their economic conditions
    func checkForEconomicReforms(game: Game) -> [WorldEvent] {
        var events: [WorldEvent] = []

        for country in game.foreignCountries {
            // Skip if no reform pressure
            guard country.hasReformPressure else { continue }

            // Calculate reform chance
            let reformChance = Double(country.economicReformTendency) / 100.0

            // Random check
            guard Double.random(in: 0...1) < reformChance * 0.1 else { continue }  // 10% of tendency

            // Determine reform direction
            let newSystem = determineReformDirection(for: country)
            guard newSystem != country.currentEconomicSystem else { continue }

            // Apply the reform
            let oldSystem = country.currentEconomicSystem
            country.changeEconomicSystem(to: newSystem)

            // Create world event
            let event = createEconomicReformEvent(
                country: country,
                from: oldSystem,
                to: newSystem,
                turn: game.turnNumber
            )
            events.append(event)
        }

        return events
    }

    /// Determine what economic system a country might reform toward
    private func determineReformDirection(for country: ForeignCountry) -> EconomicSystemType {
        let current = country.currentEconomicSystem

        // Reform paths depend on current system and crisis type
        switch current {
        case .commandEconomy:
            // Command economies can liberalize toward market socialism
            if country.hasEconomicCrisis {
                return .marketSocialism
            }
            return .commandEconomy

        case .marketSocialism:
            // Market socialism can go either direction
            if country.gdpGrowth < -3 {
                // Crisis might push toward more control OR more market
                return Bool.random() ? .commandEconomy : .mixedEconomy
            }
            return .marketSocialism

        case .mixedEconomy:
            // Mixed can go toward free market or market socialism
            if country.countryUnemploymentRate > 15 {
                return .marketSocialism  // Nationalization response
            }
            if country.countryInflationRate > 30 {
                return .freeMarket  // Austerity response
            }
            return .mixedEconomy

        case .freeMarket:
            // Free market can adopt more intervention
            if country.countryUnemploymentRate > 20 || country.hasEconomicCrisis {
                return .mixedEconomy
            }
            return .freeMarket

        case .cronyCapitalism:
            // Crony capitalism might reform after crisis
            if country.hasEconomicCrisis {
                return Bool.random() ? .mixedEconomy : .marketSocialism
            }
            return .cronyCapitalism
        }
    }

    /// Create a world event for an economic reform
    private func createEconomicReformEvent(
        country: ForeignCountry,
        from oldSystem: EconomicSystemType,
        to newSystem: EconomicSystemType,
        turn: Int
    ) -> WorldEvent {
        let headline = generateReformHeadline(country: country, from: oldSystem, to: newSystem)
        let description = generateReformDescription(country: country, from: oldSystem, to: newSystem)

        var event = WorldEvent(
            eventType: .economicCrisis,  // Reusing economic crisis type
            turnOccurred: turn,
            countryId: country.countryId,
            headline: headline,
            description: description,
            isClassified: false
        )

        // Add consequences
        event.consequences = [
            WorldEventConsequence(
                type: .economicImpact,
                targetId: country.countryId,
                amount: -2,  // Short-term disruption
                description: "Economic transition causes temporary disruption"
            )
        ]

        // If reforming toward socialism, improve relations
        if newSystem == .marketSocialism || newSystem == .commandEconomy {
            event.consequences.append(WorldEventConsequence(
                type: .relationshipChange,
                targetId: country.countryId,
                amount: 10,
                description: "Socialist reforms improve relations"
            ))
        }

        return event
    }

    /// Generate headline for economic reform
    private func generateReformHeadline(
        country: ForeignCountry,
        from oldSystem: EconomicSystemType,
        to newSystem: EconomicSystemType
    ) -> String {
        let name = country.name.uppercased()

        switch (oldSystem, newSystem) {
        case (_, .commandEconomy):
            return "\(name) NATIONALIZES INDUSTRY"
        case (_, .marketSocialism):
            return "\(name) ADOPTS MARKET REFORMS"
        case (_, .mixedEconomy):
            return "\(name) EXPANDS STATE ROLE"
        case (_, .freeMarket):
            return "\(name) LIBERALIZES ECONOMY"
        case (_, .cronyCapitalism):
            return "\(name) ECONOMIC RESTRUCTURING"
        }
    }

    /// Generate description for economic reform
    private func generateReformDescription(
        country: ForeignCountry,
        from oldSystem: EconomicSystemType,
        to newSystem: EconomicSystemType
    ) -> String {
        let name = country.name

        switch (oldSystem, newSystem) {
        case (.commandEconomy, .marketSocialism):
            return """
            The \(name) government has announced significant economic reforms, \
            allowing greater enterprise autonomy while maintaining state ownership \
            of strategic industries. The changes aim to boost productivity and \
            address chronic shortages.
            """

        case (.marketSocialism, .commandEconomy):
            return """
            Facing economic difficulties, \(name) has reversed previous reforms, \
            returning to strict central planning. Private enterprise has been \
            abolished and production quotas reimposed. The move signals a \
            hardline turn in economic policy.
            """

        case (.freeMarket, .mixedEconomy):
            return """
            The \(name) government has expanded state intervention in the economy, \
            nationalizing key industries and implementing new social programs. \
            The reforms come in response to growing public discontent with \
            economic inequality.
            """

        case (.mixedEconomy, .freeMarket):
            return """
            \(name) has embarked on an ambitious liberalization program, \
            privatizing state enterprises and reducing government intervention. \
            Supporters promise growth; critics warn of social costs.
            """

        case (_, .marketSocialism):
            return """
            \(name) has adopted market socialist policies, combining state \
            ownership with market mechanisms. The reforms aim to balance \
            efficiency with social goals.
            """

        default:
            return """
            The \(name) economy is undergoing significant restructuring. \
            New policies will reshape the relationship between state and market \
            in the coming years.
            """
        }
    }
}
