//
//  RegionSecessionService.swift
//  Nomenklatura
//
//  Service for managing regional stability, secession mechanics, and territorial integrity
//

import Foundation

// MARK: - Region Secession Service

@MainActor
class RegionSecessionService {

    static let shared = RegionSecessionService()

    private init() {}

    // MARK: - Turn Processing

    /// Process all regional dynamics at end of turn
    func processTurn(game: Game) {
        let nationalStability = game.stability

        for region in game.regions {
            // Update secession progress based on conditions
            region.updateSecessionProgress(nationalStability: nationalStability, currentTurn: game.turnNumber)

            // Apply governor effects
            region.applyGovernorEffects()

            // Check for status transitions
            updateRegionStatus(region: region, game: game)

            // Increment time in current status
            region.turnsInCurrentStatus += 1
        }

        // Check for cascade effects
        processCascadeEffects(game: game)

        // Check for game-over conditions
        checkTerritorialIntegrity(game: game)
    }

    // MARK: - Status Management

    /// Update region status based on current conditions
    private func updateRegionStatus(region: Region, game: Game) {
        let previousStatus = region.status

        // Don't update if seceded or martial
        guard region.status != .seceded && region.status != .martial else { return }

        // Calculate instability factors
        let instabilityScore = calculateInstabilityScore(region: region, game: game)

        // Determine appropriate status
        let newStatus: RegionStatus
        if instabilityScore >= 80 {
            newStatus = .rebellion
        } else if instabilityScore >= 60 {
            newStatus = .crisis
        } else if instabilityScore >= 40 {
            newStatus = .unrest
        } else {
            newStatus = .stable
        }

        // Status can only change one step at a time (except for dramatic events)
        if newStatus.severity > previousStatus.severity {
            region.status = RegionStatus(rawValue: RegionStatus.allCases.first {
                $0.severity == previousStatus.severity + 1
            }?.rawValue ?? newStatus.rawValue) ?? newStatus
        } else if newStatus.severity < previousStatus.severity - 1 {
            // Slow recovery
            region.status = RegionStatus(rawValue: RegionStatus.allCases.first {
                $0.severity == previousStatus.severity - 1
            }?.rawValue ?? newStatus.rawValue) ?? newStatus
        }

        // Reset counter if status changed
        if region.status != previousStatus {
            region.turnsInCurrentStatus = 0
        }
    }

    /// Calculate overall instability score for a region
    private func calculateInstabilityScore(region: Region, game: Game) -> Int {
        var score = 0

        // Base from autonomy desire
        score += region.autonomyDesire / 2

        // Party control (inverted - low control = high instability)
        score += (100 - region.partyControl) / 3

        // Popular loyalty (inverted)
        score += (100 - region.popularLoyalty) / 3

        // Military presence stabilizes
        score -= region.militaryPresence / 4

        // National factors
        if game.stability < 30 {
            score += 20
        } else if game.stability < 50 {
            score += 10
        }

        // Cultural factors
        if region.hasDistinctCulture {
            score += 10
        }
        if region.hasDistinctLanguage {
            score += 10
        }

        // Historical grievances
        score += region.historicalGrievances.count * 3

        // Governor effects
        if let governor = region.governor {
            if governor.loyaltyToPlayer < 30 {
                score += 10
            }
            if governor.corruption > 70 {
                score += 5
            }
        }

        return max(0, min(100, score))
    }

    // MARK: - Cascade Effects

    /// Process how instability in one region affects others
    private func processCascadeEffects(game: Game) {
        // Count regions in crisis or worse
        let crisisRegions = game.regions.filter { $0.status.severity >= 2 }
        let rebellingRegions = game.regions.filter { $0.status.severity >= 3 }

        // Widespread crisis affects national stability
        if crisisRegions.count >= 3 {
            game.applyStat("stability", change: -5)
        }

        // Multiple rebellions inspire others
        if rebellingRegions.count >= 2 {
            for region in game.regions where region.status.severity < 3 {
                if region.hasDistinctCulture || region.autonomyDesire > 50 {
                    region.autonomyDesire = min(100, region.autonomyDesire + 5)
                }
            }
        }

        // Successful secession dramatically increases risk elsewhere (one-time cascade per secession)
        let secededRegions = game.regions.filter { $0.status == .seceded }
        for seceded in secededRegions {
            let cascadeKey = "secession_cascade_\(seceded.regionId)"
            // Only apply cascade once per seceded region
            guard game.variables[cascadeKey] == nil else { continue }
            game.variables[cascadeKey] = String(game.turnNumber)

            for region in game.regions where region.canSecede && region.status != .seceded {
                // Cascade effect is proportional to cultural similarity
                let cascadeMultiplier = region.hasDistinctCulture ? 1.5 : 1.0
                region.secessionProgress = min(100, region.secessionProgress + Int(5.0 * cascadeMultiplier))
                region.autonomyDesire = min(100, region.autonomyDesire + Int(8.0 * cascadeMultiplier))
            }
        }
    }

    // MARK: - Interventions

    /// Send troops to stabilize a region
    func deployTroops(to region: Region, game: Game, level: DeploymentLevel) {
        switch level {
        case .minimal:
            region.militaryPresence = min(100, region.militaryPresence + 10)
            region.partyControl = min(100, region.partyControl + 5)
            region.popularLoyalty = max(0, region.popularLoyalty - 3)
            game.applyStat("treasury", change: -5)

        case .moderate:
            region.militaryPresence = min(100, region.militaryPresence + 25)
            region.partyControl = min(100, region.partyControl + 15)
            region.popularLoyalty = max(0, region.popularLoyalty - 8)
            game.applyStat("treasury", change: -15)
            game.applyStat("worldTension", change: 5)

        case .overwhelming:
            region.militaryPresence = min(100, region.militaryPresence + 50)
            region.partyControl = min(100, region.partyControl + 30)
            region.popularLoyalty = max(0, region.popularLoyalty - 20)
            // Heavy occupation suppresses autonomy expression through fear
            // Long-term resentment is modeled by the loyalty penalty
            region.autonomyDesire = max(0, region.autonomyDesire - 5)
            game.applyStat("treasury", change: -30)
            game.applyStat("worldTension", change: 15)
            game.applyStat("reputation", change: -10)
        }

        game.flags.append("deployed_troops_\(region.regionId)_\(game.turnNumber)")
    }

    /// Impose martial law on a region
    func imposeMartialLaw(on region: Region, game: Game) {
        region.imposeMartialLaw()

        // Consequences
        game.applyStat("stability", change: -5)
        game.applyStat("worldTension", change: 10)
        game.applyStat("reputation", change: -15)
        game.applyStat("treasury", change: -20)

        // Record
        game.flags.append("martial_law_\(region.regionId)_\(game.turnNumber)")

        // International reaction
        if region.hasDistinctCulture {
            game.applyStat("worldTension", change: 10)
        }
    }

    /// Lift martial law from a region
    func liftMartialLaw(from region: Region, game: Game) {
        region.liftMartialLaw()
        game.flags.append("lifted_martial_law_\(region.regionId)_\(game.turnNumber)")
    }

    /// Offer concessions to a restless region
    func offerConcessions(to region: Region, game: Game, type: ConcessionType) {
        switch type {
        case .economicInvestment:
            region.infrastructureQuality = min(100, region.infrastructureQuality + 15)
            region.popularLoyalty = min(100, region.popularLoyalty + 10)
            region.autonomyDesire = max(0, region.autonomyDesire - 5)
            game.applyStat("treasury", change: -25)

        case .culturalAutonomy:
            region.popularLoyalty = min(100, region.popularLoyalty + 15)
            region.autonomyDesire = max(0, region.autonomyDesire - 10)
            region.partyControl = max(0, region.partyControl - 5)
            // May inspire other regions
            for other in game.regions where other.hasDistinctCulture && other.regionId != region.regionId {
                other.autonomyDesire = min(100, other.autonomyDesire + 3)
            }

        case .politicalRepresentation:
            region.popularLoyalty = min(100, region.popularLoyalty + 20)
            region.autonomyDesire = max(0, region.autonomyDesire - 15)
            region.partyControl = max(0, region.partyControl - 10)
            game.applyStat("ideology", change: -5) // Seen as deviation

        case .amnesty:
            region.popularLoyalty = min(100, region.popularLoyalty + 25)
            region.partyControl = max(0, region.partyControl - 15)
            game.applyStat("standing", change: -5) // Seen as weakness

        case .economicExploitation:
            // Harsh extraction to punish/profit from region
            region.popularLoyalty = max(0, region.popularLoyalty - 20)
            region.autonomyDesire = min(100, region.autonomyDesire + 15)
            game.applyStat("treasury", change: 20)
            game.applyStat("reputation", change: -5)
        }

        game.flags.append("concession_\(type.rawValue)_\(region.regionId)_\(game.turnNumber)")
    }

    /// Replace regional governor
    func replaceGovernor(in region: Region, game: Game, newGovernorId: String, isLoyalist: Bool) {
        let loyaltyToPlayer = isLoyalist ? Int.random(in: 70...90) : Int.random(in: 30...60)
        let competence = isLoyalist ? Int.random(in: 40...70) : Int.random(in: 50...80)

        region.governor = RegionGovernor(
            characterId: newGovernorId,
            turn: game.turnNumber,
            loyaltyToPlayer: loyaltyToPlayer,
            competence: competence,
            isPlayerAppointed: true
        )

        // Loyalist appointments may anger locals
        if isLoyalist && region.hasDistinctCulture {
            region.popularLoyalty = max(0, region.popularLoyalty - 10)
            region.autonomyDesire = min(100, region.autonomyDesire + 5)
        }

        game.flags.append("governor_replaced_\(region.regionId)_\(game.turnNumber)")
    }

    // MARK: - Game Over Checks

    /// Check if territorial disintegration has triggered game over
    private func checkTerritorialIntegrity(game: Game) {
        let secededRegions = game.regions.filter { $0.status == .seceded }

        // Calculate population and economic loss
        _ = secededRegions.reduce(0) { $0 + $1.population }
        let lostEconomy = secededRegions.reduce(0) { $0 + $1.economicContribution }

        // Game over if capital falls or too much territory lost
        if secededRegions.contains(where: { $0.type == .capital }) {
            game.variables["game_over_reason"] = "capital_seceded"
            game.variables["game_over_turn"] = String(game.turnNumber)
        } else if secededRegions.count >= 3 {
            game.variables["game_over_reason"] = "territorial_disintegration"
            game.variables["game_over_turn"] = String(game.turnNumber)
        } else if lostEconomy >= 40 {
            game.variables["game_over_reason"] = "economic_collapse_secession"
            game.variables["game_over_turn"] = String(game.turnNumber)
        }

        // Severe instability even without game over
        if secededRegions.count >= 2 {
            game.applyStat("stability", change: -20)
            game.applyStat("patronFavor", change: -30)
            game.applyStat("worldTension", change: 25)
        }
    }

    // MARK: - Event Generation

    /// Generate regional events based on conditions
    func generateRegionalEvents(for game: Game) -> [RegionalCrisisEvent] {
        var events: [RegionalCrisisEvent] = []

        for region in game.regions {
            // Skip stable regions usually
            if region.status == .stable && Int.random(in: 1...10) > 2 {
                continue
            }

            // Determine if event should occur
            let eventChance = calculateEventChance(region: region, game: game)
            guard Int.random(in: 1...100) <= eventChance else { continue }

            // Generate appropriate event type
            if let event = generateEvent(for: region, game: game) {
                events.append(event)
            }
        }

        return events
    }

    private func calculateEventChance(region: Region, game: Game) -> Int {
        var chance = 10 // Base chance

        // Status-based
        switch region.status {
        case .stable: chance += 5
        case .unrest: chance += 20
        case .crisis: chance += 35
        case .rebellion: chance += 50
        case .seceding: chance += 40
        case .seceded: chance = 0 // No longer part of nation
        case .martial: chance += 15
        }

        // Instability factors
        chance += (100 - region.partyControl) / 5
        chance += region.autonomyDesire / 5

        // National crisis increases regional events
        if game.stability < 40 {
            chance += 15
        }

        return min(80, chance)
    }

    private func generateEvent(for region: Region, game: Game) -> RegionalCrisisEvent? {
        // Weight event types based on region characteristics
        var weights: [RegionEventType: Int] = [:]

        // Industrial regions more prone to strikes
        if region.type == .industrial {
            weights[.laborStrike] = 30
            weights[.sabotage] = 20
            weights[.infrastructureFailure] = 15
        }

        // Autonomous/distinct culture regions prone to ethnic tension
        if region.hasDistinctCulture {
            weights[.ethnicTension] = 25
            weights[.religiousRevival] = 20
            weights[.secessionMovement] = region.autonomyDesire / 3
        }

        // Border regions
        if region.type == .border {
            weights[.borderIncident] = 30
            weights[.smugglingRing] = 20
        }

        // Universal possibilities
        weights[.partyCorruption] = 15
        weights[.demonstration] = region.status.severity >= 2 ? 25 : 10
        weights[.militaryMutiny] = region.militaryPresence > 60 && region.popularLoyalty < 40 ? 10 : 2

        // Select event type based on weights
        let totalWeight = weights.values.reduce(0, +)
        guard totalWeight > 0 else { return nil }

        var roll = Int.random(in: 1...totalWeight)
        var selectedType: RegionEventType = .demonstration

        for (type, weight) in weights {
            roll -= weight
            if roll <= 0 {
                selectedType = type
                break
            }
        }

        return RegionalCrisisEvent(
            id: UUID().uuidString,
            regionId: region.regionId,
            eventType: selectedType,
            severity: selectedType.severity,
            turn: game.turnNumber
        )
    }

    // MARK: - Information

    /// Get regions at risk of secession
    func regionsAtRisk(game: Game) -> [Region] {
        game.regions
            .filter { $0.canSecede && $0.secessionProgress > 25 }
            .sorted { $0.secessionProgress > $1.secessionProgress }
    }

    /// Get overall territorial stability assessment
    func territorialStabilityAssessment(game: Game) -> TerritorialAssessment {
        let totalRegions = game.regions.count
        let stableRegions = game.regions.filter { $0.status == .stable }.count
        let crisisRegions = game.regions.filter { $0.status.severity >= 2 }.count
        _ = game.regions.filter { $0.status == .seceding || $0.status == .seceded }.count

        let avgLoyalty = game.regions.reduce(0) { $0 + $1.popularLoyalty } / max(1, totalRegions)
        let avgPartyControl = game.regions.reduce(0) { $0 + $1.partyControl } / max(1, totalRegions)

        return TerritorialAssessment(
            overallStability: calculateOverallTerritorialStability(game: game),
            stableRegionCount: stableRegions,
            crisisRegionCount: crisisRegions,
            secessionRiskCount: regionsAtRisk(game: game).count,
            averageLoyalty: avgLoyalty,
            averagePartyControl: avgPartyControl,
            mostAtRisk: regionsAtRisk(game: game).first,
            recommendations: generateRecommendations(game: game)
        )
    }

    private func calculateOverallTerritorialStability(game: Game) -> Int {
        guard !game.regions.isEmpty else { return 100 }

        let stabilityScores = game.regions.map { $0.stabilityScore }
        let avgStability = stabilityScores.reduce(0, +) / game.regions.count

        // Penalty for regions in crisis
        let crisisPenalty = game.regions.filter { $0.status.severity >= 2 }.count * 5
        let secessionPenalty = game.regions.filter { $0.status == .seceding }.count * 15

        return max(0, min(100, avgStability - crisisPenalty - secessionPenalty))
    }

    private func generateRecommendations(game: Game) -> [String] {
        var recommendations: [String] = []

        for region in game.regions {
            if region.status == .rebellion {
                recommendations.append("URGENT: \(region.name) is in open rebellion. Decisive action required.")
            } else if region.status == .crisis && region.secessionProgress > 50 {
                recommendations.append("WARNING: \(region.name) approaching secession threshold. Consider intervention.")
            } else if region.partyControl < 40 {
                recommendations.append("Strengthen Party presence in \(region.name) - control dangerously low.")
            } else if region.popularLoyalty < 30 && region.hasDistinctCulture {
                recommendations.append("Consider concessions to \(region.name) - loyalty critically low.")
            }
        }

        if recommendations.isEmpty {
            recommendations.append("Territorial integrity stable. Continue monitoring.")
        }

        return recommendations
    }
}

// MARK: - Supporting Types

enum DeploymentLevel: String, Codable, CaseIterable {
    case minimal        // Show of force
    case moderate       // Serious reinforcement
    case overwhelming   // Full military occupation

    var displayName: String {
        switch self {
        case .minimal: return "Show of Force"
        case .moderate: return "Reinforcement"
        case .overwhelming: return "Military Occupation"
        }
    }
}

enum ConcessionType: String, Codable, CaseIterable {
    case economicInvestment         // Build infrastructure, create jobs
    case culturalAutonomy           // Allow local language, customs
    case politicalRepresentation    // More local voices in government
    case amnesty                    // Forgive past "crimes"
    case economicExploitation       // Opposite - extract more from region

    var displayName: String {
        switch self {
        case .economicInvestment: return "Economic Investment"
        case .culturalAutonomy: return "Cultural Autonomy"
        case .politicalRepresentation: return "Political Representation"
        case .amnesty: return "General Amnesty"
        case .economicExploitation: return "Increased Extraction"
        }
    }
}

struct RegionalCrisisEvent: Identifiable, Codable {
    var id: String
    var regionId: String
    var eventType: RegionEventType
    var severity: Int
    var turn: Int
    var resolved: Bool = false
    var resolutionMethod: String?

    var headline: String {
        "\(eventType.displayName) in Region"
    }
}

struct TerritorialAssessment {
    var overallStability: Int
    var stableRegionCount: Int
    var crisisRegionCount: Int
    var secessionRiskCount: Int
    var averageLoyalty: Int
    var averagePartyControl: Int
    var mostAtRisk: Region?
    var recommendations: [String]

    var statusDescription: String {
        if overallStability >= 80 {
            return "Excellent - Union is strong"
        } else if overallStability >= 60 {
            return "Good - Minor concerns in some regions"
        } else if overallStability >= 40 {
            return "Concerning - Multiple regions require attention"
        } else if overallStability >= 20 {
            return "Critical - Territorial integrity at serious risk"
        } else {
            return "Catastrophic - Union is disintegrating"
        }
    }
}

// MARK: - DynamicEvent Integration

extension RegionSecessionService {

    /// Convert a regional crisis to a DynamicEvent for presentation
    func createDynamicEvent(from crisis: RegionalCrisisEvent, region: Region, currentTurn: Int) -> DynamicEvent {
        let responses = generateEventResponses(for: crisis, region: region)

        // Determine priority based on severity
        let eventPriority: EventPriority
        switch crisis.severity {
        case 0...2: eventPriority = .normal
        case 3: eventPriority = .elevated
        case 4: eventPriority = .urgent
        default: eventPriority = .critical
        }

        return DynamicEvent(
            eventType: .urgentInterruption,
            priority: eventPriority,
            title: "\(crisis.eventType.displayName): \(region.name)",
            briefText: generateEventSummary(crisis: crisis, region: region),
            turnGenerated: currentTurn,
            expiresOnTurn: crisis.severity >= 4 ? currentTurn + 1 : currentTurn + 2,
            isUrgent: crisis.severity >= 4,
            responseOptions: responses,
            iconName: RegionType(rawValue: region.regionType)?.iconName ?? "map.fill"
        )
    }

    private func generateEventSummary(crisis: RegionalCrisisEvent, region: Region) -> String {
        switch crisis.eventType {
        case .laborStrike:
            return "Workers in \(region.name) have stopped production, demanding better conditions. Factories stand idle as the strike spreads."

        case .ethnicTension:
            return "Ethnic clashes have erupted in \(region.name). The local population and settlers are at odds, with violence threatening to spiral."

        case .religiousRevival:
            return "Underground religious meetings in \(region.name) have grown into a mass movement. The faithful gather in defiance of official atheism."

        case .demonstration:
            return "Crowds have gathered in the streets of \(region.name), demanding change. The militia awaits orders."

        case .secessionMovement:
            return "Independence activists in \(region.name) have declared their intention to leave the union. This is no longer underground—it is open defiance."

        case .borderIncident:
            return "Armed clashes on the \(region.name) border have left casualties on both sides. Tensions with our neighbors are at a breaking point."

        case .militaryMutiny:
            return "Troops stationed in \(region.name) have refused orders. Their commanders report loss of control over key units."

        case .partyCorruption:
            return "Reports from \(region.name) reveal systematic corruption among local Party officials. Public trust in the Party is collapsing."

        case .infrastructureFailure:
            return "A major industrial accident in \(region.name) has caused widespread damage. Casualties are mounting and production has halted."

        case .sabotage:
            return "Key facilities in \(region.name) have been sabotaged. Counter-revolutionary elements are suspected."

        case .naturalDisaster:
            return "Natural disaster has struck \(region.name). Emergency response is required immediately."

        case .smugglingRing:
            return "A major smuggling operation has been uncovered in \(region.name), undermining state control of the economy."
        }
    }

    private func generateEventResponses(for crisis: RegionalCrisisEvent, region: Region) -> [EventResponse] {
        switch crisis.eventType {
        case .laborStrike:
            return [
                EventResponse(
                    id: "negotiate_\(crisis.id)",
                    text: "Negotiate with strike leaders",
                    shortText: "Negotiate",
                    effects: ["treasury": -10, "stability": -5],
                    riskLevel: .medium
                ),
                EventResponse(
                    id: "suppress_\(crisis.id)",
                    text: "Send security forces to end the strike",
                    shortText: "Suppress",
                    effects: ["stability": -5, "standing": -5],
                    riskLevel: .high
                ),
                EventResponse(
                    id: "concede_\(crisis.id)",
                    text: "Meet worker demands",
                    shortText: "Concede",
                    effects: ["treasury": -20, "standing": -5],
                    riskLevel: .low
                )
            ]

        case .demonstration:
            return [
                EventResponse(
                    id: "disperse_\(crisis.id)",
                    text: "Order militia to disperse the crowds",
                    shortText: "Disperse",
                    effects: ["stability": -8, "internationalStanding": -5],
                    riskLevel: .high
                ),
                EventResponse(
                    id: "dialog_\(crisis.id)",
                    text: "Send Party representatives to dialogue",
                    shortText: "Dialogue",
                    effects: ["standing": -3],
                    riskLevel: .medium
                ),
                EventResponse(
                    id: "ignore_\(crisis.id)",
                    text: "Wait and observe",
                    shortText: "Wait",
                    effects: ["patronFavor": -5],
                    riskLevel: .low
                )
            ]

        case .secessionMovement:
            return [
                EventResponse(
                    id: "martial_\(crisis.id)",
                    text: "Declare martial law immediately",
                    shortText: "Martial Law",
                    effects: ["stability": -10, "internationalStanding": -15],
                    riskLevel: .high
                ),
                EventResponse(
                    id: "negotiate_\(crisis.id)",
                    text: "Open negotiations on autonomy",
                    shortText: "Negotiate",
                    effects: ["eliteLoyalty": -10, "standing": -10],
                    riskLevel: .medium
                ),
                EventResponse(
                    id: "infiltrate_\(crisis.id)",
                    text: "Infiltrate and arrest leadership",
                    shortText: "Infiltrate",
                    effects: ["patronFavor": 5, "stability": -5],
                    riskLevel: .high
                )
            ]

        default:
            return [
                EventResponse(
                    id: "investigate_\(crisis.id)",
                    text: "Order full investigation",
                    shortText: "Investigate",
                    effects: ["treasury": -5],
                    riskLevel: .low
                ),
                EventResponse(
                    id: "crackdown_\(crisis.id)",
                    text: "Launch security crackdown",
                    shortText: "Crackdown",
                    effects: ["stability": -5, "patronFavor": 3],
                    riskLevel: .high
                ),
                EventResponse(
                    id: "contain_\(crisis.id)",
                    text: "Contain and manage quietly",
                    shortText: "Contain",
                    effects: ["standing": -3],
                    riskLevel: .medium
                )
            ]
        }
    }
}
