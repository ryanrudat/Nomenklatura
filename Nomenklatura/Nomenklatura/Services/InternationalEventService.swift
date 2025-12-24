//
//  InternationalEventService.swift
//  Nomenklatura
//
//  Service for managing international relations, diplomatic events, and world crises
//

import Foundation

// MARK: - International Event Service

@MainActor
class InternationalEventService {

    static let shared = InternationalEventService()

    private init() {}

    // MARK: - Turn Processing

    /// Process all international dynamics at end of turn
    func processTurn(game: Game) {
        // Update relationship dynamics
        processRelationshipChanges(game: game)

        // Process treaty effects
        processTreatyEffects(game: game)

        // Check for triggered events
        processTriggeredEvents(game: game)

        // Update world tension
        updateWorldTension(game: game)

        // Process espionage activities
        processEspionage(game: game)
    }

    // MARK: - Relationship Management

    /// Process natural relationship drift based on conditions
    private func processRelationshipChanges(game: Game) {
        for country in game.foreignCountries {
            var change = 0

            // Bloc alignment naturally affects relations
            switch country.politicalBloc {
            case .socialist:
                // Socialist allies drift toward friendship
                if country.relationshipScore < 60 {
                    change += 1
                }
            case .capitalist:
                // Capitalist bloc drifts toward hostility
                if country.relationshipScore > -40 {
                    change -= 1
                }
            case .nonAligned:
                // Non-aligned drift toward neutral
                if country.relationshipScore > 20 {
                    change -= 1
                } else if country.relationshipScore < -20 {
                    change += 1
                }
            case .rival:
                // Rivals drift toward hostility
                if country.relationshipScore > -20 {
                    change -= 1
                }
            }

            // National stability affects bloc relations
            if game.stability < 40 {
                // Weakness attracts predators, worries allies
                if country.politicalBloc == .capitalist || country.politicalBloc == .rival {
                    country.diplomaticTension = min(100, country.diplomaticTension + 2)
                } else if country.politicalBloc == .socialist {
                    change -= 2 // Allies worry about our stability
                }
            }

            // Apply change
            if change != 0 {
                country.modifyRelationship(by: change)
            }
        }
    }

    /// Process active treaty effects
    private func processTreatyEffects(game: Game) {
        for country in game.foreignCountries {
            for treaty in country.treaties {
                switch treaty.type {
                case .tradeAgreement:
                    game.applyStat("treasury", change: 2)

                case .aidPackage:
                    if country.politicalBloc == .socialist {
                        game.applyStat("treasury", change: -5)
                        country.modifyRelationship(by: 1)
                    }

                case .mutualDefense:
                    // Keeps tension with enemies higher
                    if country.politicalBloc == .socialist {
                        for enemy in game.foreignCountries where enemy.politicalBloc == .capitalist {
                            enemy.diplomaticTension = min(100, enemy.diplomaticTension + 1)
                        }
                    }

                case .culturalExchange:
                    country.modifyRelationship(by: 1)

                case .espionageAgreement:
                    country.ourIntelligenceAssets = min(100, country.ourIntelligenceAssets + 1)

                default:
                    break
                }

                // Check for treaty expiration
                if let expiration = treaty.expirationTurn, expiration <= game.turnNumber {
                    country.removeTreaty(id: treaty.id)
                    game.flags.append("treaty_expired_\(country.countryId)_\(treaty.type.rawValue)")
                }
            }
        }
    }

    /// Check for and process triggered international events
    private func processTriggeredEvents(game: Game) {
        // Check for proxy war opportunities
        checkProxyWarOpportunities(game: game)

        // Check for diplomatic crises
        checkDiplomaticCrises(game: game)

        // Check for alliance strains
        checkAllianceStrains(game: game)
    }

    // MARK: - World Tension

    /// Update global tension levels
    private func updateWorldTension(game: Game) {
        var tensionChange = 0

        // Count hostile relationships
        let hostileCountries = game.foreignCountries.filter { $0.diplomaticTension > 60 }
        tensionChange += hostileCountries.count

        // Nuclear tensions
        let nuclearTensions = game.foreignCountries.filter { $0.hasNuclearWeapons && $0.diplomaticTension > 70 }
        tensionChange += nuclearTensions.count * 3

        // Stability affects tension
        if game.stability < 30 {
            tensionChange += 5 // Our weakness emboldens enemies
        }

        // Apply change (capped)
        if tensionChange > 0 {
            game.applyStat("worldTension", change: tensionChange / 2)
        }

        // Natural de-escalation when nothing dramatic happening
        if hostileCountries.count < 3 && game.stability > 60 {
            game.applyStat("worldTension", change: -1)
        }
    }

    // MARK: - Espionage

    /// Process espionage activities
    private func processEspionage(game: Game) {
        for country in game.foreignCountries {
            // Their spying on us
            if country.espionageActivity > 50 {
                let discoveryRoll = Int.random(in: 1...100)
                if discoveryRoll <= country.espionageActivity / 3 {
                    // They discovered something
                    let effect = processEspionageDiscovery(country: country, game: game)
                    if effect {
                        game.flags.append("espionage_incident_\(country.countryId)_\(game.turnNumber)")
                    }
                }
            }

            // Our spying on them
            if country.ourIntelligenceAssets > 30 {
                let counterIntelRoll = Int.random(in: 1...100)
                if counterIntelRoll <= country.espionageActivity / 4 {
                    // Our agents discovered/compromised
                    country.ourIntelligenceAssets = max(0, country.ourIntelligenceAssets - 10)
                    country.modifyRelationship(by: -5)
                    game.flags.append("agents_compromised_\(country.countryId)_\(game.turnNumber)")
                }
            }
        }
    }

    private func processEspionageDiscovery(country: ForeignCountry, game: Game) -> Bool {
        // Random type of intelligence loss
        let discoveryType = Int.random(in: 1...4)
        switch discoveryType {
        case 1:
            // Military secrets
            game.applyStat("militaryReadiness", change: -3)
            return true
        case 2:
            // Economic information
            game.applyStat("treasury", change: -5)
            return true
        case 3:
            // Political intelligence
            game.applyStat("reputation", change: -3)
            return true
        default:
            return false
        }
    }

    // MARK: - Event Triggers

    private func checkProxyWarOpportunities(game: Game) {
        // Check for countries where we could get involved
        for country in game.foreignCountries {
            if country.politicalBloc == .nonAligned && country.diplomaticTension > 50 {
                // Opportunity to support one side in a developing conflict
                if Int.random(in: 1...20) == 1 {
                    game.variables["proxy_opportunity_\(country.countryId)"] = String(game.turnNumber)
                }
            }
        }
    }

    private func checkDiplomaticCrises(game: Game) {
        for country in game.foreignCountries {
            // High tension can trigger crises
            if country.diplomaticTension > 80 {
                let crisisRoll = Int.random(in: 1...100)
                if crisisRoll <= country.diplomaticTension / 4 {
                    // Diplomatic crisis triggered
                    game.variables["diplomatic_crisis_\(country.countryId)"] = String(game.turnNumber)
                    game.applyStat("worldTension", change: 10)
                }
            }

            // Border tensions with neighboring regions
            if let borderingRegionId = country.borderingRegionId {
                if country.diplomaticTension > 60 {
                    // Find the region and increase military alert
                    if let region = game.regions.first(where: { $0.regionId == borderingRegionId }) {
                        region.militaryPresence = min(100, region.militaryPresence + 5)
                    }
                }
            }
        }
    }

    private func checkAllianceStrains(game: Game) {
        // Check socialist bloc for strains
        let socialistAllies = game.foreignCountries.filter { $0.politicalBloc == .socialist }
        for ally in socialistAllies {
            let strainKey = "alliance_strain_\(ally.countryId)"
            if ally.relationshipScore < 40 {
                // Alliance strain warning
                game.variables[strainKey] = String(game.turnNumber)
            } else if ally.relationshipScore >= 50 {
                // Clear strain flag when relationship has recovered
                game.variables.removeValue(forKey: strainKey)
            }
        }
    }

    // MARK: - Diplomatic Actions

    /// Execute a diplomatic action against a country
    func executeDiplomaticAction(_ action: DiplomaticActionType, target: ForeignCountry, game: Game) -> DiplomaticActionResult {
        var result = DiplomaticActionResult(
            success: true,
            actionType: action,
            targetCountry: target.countryId,
            turn: game.turnNumber
        )

        switch action {
        case .sendAid:
            game.applyStat("treasury", change: -20)
            target.modifyRelationship(by: action.relationshipEffect)
            result.narrativeOutcome = "Aid package delivered to \(target.name). Relations improve."

        case .culturalExchange:
            game.applyStat("treasury", change: -5)
            target.modifyRelationship(by: action.relationshipEffect)
            result.narrativeOutcome = "Cultural delegation exchanges strengthen ties with \(target.name)."

        case .tradeNegotiation:
            let successRoll = Int.random(in: 1...100)
            if successRoll <= 60 + target.relationshipScore / 2 {
                target.tradeVolume = min(100, target.tradeVolume + 10)
                target.modifyRelationship(by: action.relationshipEffect)
                result.narrativeOutcome = "Trade negotiations with \(target.name) succeed."
            } else {
                result.success = false
                result.narrativeOutcome = "Trade negotiations with \(target.name) fail to reach agreement."
            }

        case .militaryCooperation:
            if target.politicalBloc == .socialist || target.relationshipScore > 20 {
                target.modifyRelationship(by: action.relationshipEffect)
                target.militaryStrength = min(100, target.militaryStrength + 5)
                // Enemies react
                for enemy in game.foreignCountries where enemy.politicalBloc == .capitalist {
                    enemy.diplomaticTension = min(100, enemy.diplomaticTension + 3)
                }
                result.narrativeOutcome = "Military cooperation agreement with \(target.name) concluded."
            } else {
                result.success = false
                result.narrativeOutcome = "\(target.name) declines military cooperation."
            }

        case .economicSanctions:
            target.tradeVolume = max(0, target.tradeVolume - 20)
            target.modifyRelationship(by: action.relationshipEffect)
            target.diplomaticTension = min(100, target.diplomaticTension + 15)
            game.applyStat("worldTension", change: 5)
            result.narrativeOutcome = "Economic sanctions imposed on \(target.name)."

        case .diplomaticProtest:
            target.modifyRelationship(by: action.relationshipEffect)
            result.narrativeOutcome = "Formal diplomatic protest delivered to \(target.name)."

        case .recallAmbassador:
            target.modifyRelationship(by: action.relationshipEffect)
            target.diplomaticTension = min(100, target.diplomaticTension + 10)
            game.applyStat("worldTension", change: 3)
            result.narrativeOutcome = "Ambassador recalled from \(target.name). Relations deteriorate sharply."

        case .militaryThreat:
            target.modifyRelationship(by: action.relationshipEffect)
            target.diplomaticTension = min(100, target.diplomaticTension + 25)
            game.applyStat("worldTension", change: 10)
            // Risk of escalation
            if target.hasNuclearWeapons {
                game.applyStat("worldTension", change: 15)
            }
            result.narrativeOutcome = "Military threats issued against \(target.name). Tension rises dangerously."

        case .plantAssets:
            let successRoll = Int.random(in: 1...100)
            let counterIntel = target.espionageActivity
            if successRoll > counterIntel / 2 {
                target.ourIntelligenceAssets = min(100, target.ourIntelligenceAssets + 15)
                result.narrativeOutcome = "Intelligence assets successfully planted in \(target.name)."
            } else {
                result.success = false
                result.discovered = true
                target.modifyRelationship(by: -20)
                target.diplomaticTension = min(100, target.diplomaticTension + 15)
                game.applyStat("reputation", change: -10)
                result.narrativeOutcome = "Intelligence operation in \(target.name) discovered. Diplomatic incident."
            }

        case .supportDissidents:
            let successRoll = Int.random(in: 1...100)
            if successRoll > 40 {
                // Internal pressure on target
                game.variables["dissidents_supported_\(target.countryId)"] = String(game.turnNumber)
                result.narrativeOutcome = "Dissident groups in \(target.name) receive covert support."
            } else {
                result.success = false
                result.discovered = true
                target.modifyRelationship(by: action.relationshipEffect)
                target.diplomaticTension = min(100, target.diplomaticTension + 20)
                game.applyStat("reputation", change: -15)
                game.applyStat("worldTension", change: 5)
                result.narrativeOutcome = "Our support for dissidents in \(target.name) is exposed publicly."
            }

        case .propaganda:
            let effectiveness = Int.random(in: 1...100)
            if effectiveness > 50 {
                target.modifyRelationship(by: -5)
                result.narrativeOutcome = "Propaganda campaign targeting \(target.name) shows some effect."
            } else {
                result.narrativeOutcome = "Propaganda campaign targeting \(target.name) has limited impact."
            }

        case .sabotage:
            let successRoll = Int.random(in: 1...100)
            if successRoll > 60 {
                target.economicPower = max(0, target.economicPower - 5)
                if target.hasOurMilitaryBases {
                    // Can't sabotage allies easily
                    result.success = false
                    result.narrativeOutcome = "Sabotage operation against \(target.name) aborted—too many friendly forces present."
                } else {
                    result.narrativeOutcome = "Sabotage operation damages infrastructure in \(target.name)."
                }
            } else {
                result.success = false
                result.discovered = true
                target.modifyRelationship(by: action.relationshipEffect)
                target.diplomaticTension = min(100, target.diplomaticTension + 30)
                game.applyStat("worldTension", change: 10)
                game.applyStat("reputation", change: -20)
                result.narrativeOutcome = "Sabotage operation in \(target.name) catastrophically exposed. International incident."
            }
        }

        // Record the action
        game.flags.append("diplomatic_action_\(action.rawValue)_\(target.countryId)_\(game.turnNumber)")
        game.updatedAt = Date()

        return result
    }

    // MARK: - Treaty Management

    /// Propose a treaty to a foreign country
    func proposeTreaty(_ type: TreatyType, to country: ForeignCountry, game: Game, terms: String = "") -> TreatyProposalResult {
        var result = TreatyProposalResult(accepted: false, treatyType: type, countryId: country.countryId)

        // Calculate acceptance chance
        var acceptanceChance = 50

        // Relationship affects acceptance
        acceptanceChance += country.relationshipScore / 2

        // Bloc affects willingness
        switch country.politicalBloc {
        case .socialist:
            acceptanceChance += 30 // Allies more willing
        case .capitalist:
            acceptanceChance -= 40 // Enemies unlikely
        case .nonAligned:
            acceptanceChance += 10 // Open to offers
        case .rival:
            acceptanceChance -= 20 // Rivals suspicious
        }

        // Treaty type affects acceptance
        switch type {
        case .mutualDefense:
            if country.politicalBloc != .socialist {
                acceptanceChance -= 30 // Only allies accept defense pacts
            }
        case .tradeAgreement:
            acceptanceChance += 15 // Everyone likes trade
        case .aidPackage:
            if country.economicPower < 40 {
                acceptanceChance += 20 // Poor countries want aid
            }
        case .culturalExchange:
            acceptanceChance += 10 // Low stakes
        case .nonAggression:
            if country.diplomaticTension > 50 {
                acceptanceChance += 15 // Tense situations want peace
            }
        case .nuclearSharing:
            if !country.hasNuclearWeapons && country.politicalBloc == .socialist {
                acceptanceChance += 10
            } else {
                acceptanceChance = 5 // Very unlikely otherwise
            }
        case .espionageAgreement:
            if country.politicalBloc == .socialist {
                acceptanceChance += 20
            } else {
                acceptanceChance = 10
            }
        }

        // Roll for acceptance
        let roll = Int.random(in: 1...100)
        if roll <= acceptanceChance {
            result.accepted = true

            // Create the treaty
            let treaty = ActiveTreaty(
                type: type,
                signedTurn: game.turnNumber,
                expirationTurn: type == .mutualDefense ? nil : game.turnNumber + 40, // 10 years
                terms: terms.isEmpty ? type.displayName : terms,
                isSecret: type == .espionageAgreement || type == .nuclearSharing
            )
            country.addTreaty(treaty)

            // Relationship improvement
            country.modifyRelationship(by: 10)

            result.narrativeOutcome = "\(country.name) accepts the \(type.displayName)."

            // Other effects
            switch type {
            case .mutualDefense:
                game.applyStat("militaryReadiness", change: 5)
            case .tradeAgreement:
                country.tradeVolume = min(100, country.tradeVolume + 15)
            case .aidPackage:
                game.applyStat("treasury", change: -30) // Initial cost
            default:
                break
            }
        } else {
            result.narrativeOutcome = "\(country.name) declines the proposed \(type.displayName)."
            country.modifyRelationship(by: -3) // Slight insult from rejection
        }

        game.flags.append("treaty_proposal_\(type.rawValue)_\(country.countryId)_\(result.accepted ? "accepted" : "rejected")_\(game.turnNumber)")

        return result
    }

    /// Terminate an existing treaty
    func terminateTreaty(id: String, with country: ForeignCountry, game: Game) {
        guard let treaty = country.treaties.first(where: { $0.id == id }) else { return }

        country.removeTreaty(id: id)

        // Relationship damage
        country.modifyRelationship(by: -15)

        // Specific effects
        switch treaty.type {
        case .mutualDefense:
            country.modifyRelationship(by: -20) // Breaking defense pact is serious
            game.applyStat("reputation", change: -10)
        case .tradeAgreement:
            country.tradeVolume = max(0, country.tradeVolume - 15)
        case .aidPackage:
            country.modifyRelationship(by: -10)
        default:
            break
        }

        game.flags.append("treaty_terminated_\(treaty.type.rawValue)_\(country.countryId)_\(game.turnNumber)")
    }

    // MARK: - Crisis Generation

    /// Generate international crisis events for the turn
    func generateInternationalEvents(for game: Game) -> [InternationalCrisisEvent] {
        var events: [InternationalCrisisEvent] = []

        for country in game.foreignCountries {
            // Check if crisis conditions exist
            if country.diplomaticTension > 70 {
                let crisisChance = country.diplomaticTension / 3
                if Int.random(in: 1...100) <= crisisChance {
                    if let crisis = generateCrisis(with: country, game: game) {
                        events.append(crisis)
                    }
                }
            }

            // Check for bloc-specific events
            if country.politicalBloc == .socialist && country.relationshipScore < 30 {
                let defectionRisk = 30 - country.relationshipScore
                if Int.random(in: 1...100) <= defectionRisk / 3 {
                    events.append(InternationalCrisisEvent(
                        id: UUID().uuidString,
                        countryId: country.countryId,
                        crisisType: .allianceStrain,
                        severity: 3,
                        turn: game.turnNumber,
                        headline: "Alliance Strain: \(country.name)",
                        description: "\(country.name)'s loyalty to the bloc is wavering. Western diplomats are making overtures."
                    ))
                }
            }
        }

        // Check for superpower confrontation
        if let atlanticUnion = game.foreignCountries.first(where: { $0.countryId == "atlantic_union" }) {
            if atlanticUnion.diplomaticTension > 80 && game.variables["world_tension"] ?? "0" != "0" {
                let confrontationRisk = Int.random(in: 1...100)
                if confrontationRisk <= 10 {
                    events.append(InternationalCrisisEvent(
                        id: UUID().uuidString,
                        countryId: "atlantic_union",
                        crisisType: .superpowerConfrontation,
                        severity: 5,
                        turn: game.turnNumber,
                        headline: "SUPERPOWER CRISIS",
                        description: "A serious incident threatens to escalate into direct confrontation with the Atlantic Union. The world holds its breath."
                    ))
                }
            }
        }

        return events
    }

    private func generateCrisis(with country: ForeignCountry, game: Game) -> InternationalCrisisEvent? {
        let crisisTypes: [InternationalCrisisType]

        switch country.politicalBloc {
        case .socialist:
            crisisTypes = [.allianceStrain, .ideologicalChallenge, .economicCrisis]
        case .capitalist:
            crisisTypes = [.spyScandal, .borderIncident, .tradeWar, .militaryProvocation]
        case .nonAligned:
            crisisTypes = [.proxyWarOpportunity, .coupAttempt, .economicCrisis]
        case .rival:
            crisisTypes = [.borderIncident, .ideologicalChallenge, .militaryProvocation]
        }

        guard let crisisType = crisisTypes.randomElement() else { return nil }

        return InternationalCrisisEvent(
            id: UUID().uuidString,
            countryId: country.countryId,
            crisisType: crisisType,
            severity: crisisType.baseSeverity,
            turn: game.turnNumber,
            headline: crisisType.generateHeadline(for: country.name),
            description: crisisType.generateDescription(for: country.name)
        )
    }

    // MARK: - Assessment

    /// Get overall international situation assessment
    func internationalAssessment(game: Game) -> InternationalAssessment {
        let totalCountries = game.foreignCountries.count
        let allies = game.foreignCountries.filter { $0.isAlly }
        let enemies = game.foreignCountries.filter { $0.isEnemy }
        let threats = game.foreignCountries.filter { $0.isThreat }

        let avgRelationship = game.foreignCountries.reduce(0) { $0 + $1.relationshipScore } / max(1, totalCountries)
        let maxTension = game.foreignCountries.max(by: { $0.diplomaticTension < $1.diplomaticTension })?.diplomaticTension ?? 0

        return InternationalAssessment(
            allyCount: allies.count,
            enemyCount: enemies.count,
            threatCount: threats.count,
            averageRelationship: avgRelationship,
            maximumTension: maxTension,
            mostDangerousCountry: threats.first,
            weakestAlliance: allies.min(by: { $0.relationshipScore < $1.relationshipScore }),
            recommendations: generateDiplomaticRecommendations(game: game)
        )
    }

    private func generateDiplomaticRecommendations(game: Game) -> [String] {
        var recommendations: [String] = []

        // Check for immediate threats
        for country in game.foreignCountries where country.diplomaticTension > 80 {
            recommendations.append("URGENT: Diplomatic crisis imminent with \(country.name). Consider de-escalation.")
        }

        // Check for weak alliances
        for country in game.foreignCountries where country.politicalBloc == .socialist && country.relationshipScore < 30 {
            recommendations.append("WARNING: \(country.name) alliance unstable. Risk of defection.")
        }

        // Opportunities
        for country in game.foreignCountries where country.politicalBloc == .nonAligned && country.relationshipScore > 20 {
            if !country.hasTreaty(of: .tradeAgreement) {
                recommendations.append("Opportunity: \(country.name) receptive to closer relations. Consider trade agreement.")
            }
        }

        if recommendations.isEmpty {
            recommendations.append("International situation stable. Continue monitoring.")
        }

        return recommendations
    }
}

// MARK: - Supporting Types

struct DiplomaticActionResult {
    var success: Bool
    var actionType: DiplomaticActionType
    var targetCountry: String
    var turn: Int
    var narrativeOutcome: String = ""
    var discovered: Bool = false
}

struct TreatyProposalResult {
    var accepted: Bool
    var treatyType: TreatyType
    var countryId: String
    var narrativeOutcome: String = ""
}

enum InternationalCrisisType: String, Codable, CaseIterable {
    case borderIncident             // Military clash at border
    case spyScandal                 // Espionage discovered
    case tradeWar                   // Economic conflict
    case militaryProvocation        // Naval/air incident
    case allianceStrain             // Ally wavering
    case proxyWarOpportunity        // Chance to intervene
    case coupAttempt                // Regime change opportunity
    case economicCrisis             // Financial collapse
    case ideologicalChallenge       // Challenge to our doctrine
    case superpowerConfrontation    // Direct crisis with main rival

    var baseSeverity: Int {
        switch self {
        case .tradeWar, .economicCrisis: return 2
        case .spyScandal, .allianceStrain, .proxyWarOpportunity: return 3
        case .borderIncident, .coupAttempt, .ideologicalChallenge: return 4
        case .militaryProvocation: return 4
        case .superpowerConfrontation: return 5
        }
    }

    func generateHeadline(for countryName: String) -> String {
        switch self {
        case .borderIncident:
            return "Border Incident with \(countryName)"
        case .spyScandal:
            return "Espionage Scandal: \(countryName)"
        case .tradeWar:
            return "Trade Dispute Escalates with \(countryName)"
        case .militaryProvocation:
            return "Military Provocation by \(countryName)"
        case .allianceStrain:
            return "Alliance Under Strain: \(countryName)"
        case .proxyWarOpportunity:
            return "Civil Conflict in \(countryName)"
        case .coupAttempt:
            return "Political Crisis in \(countryName)"
        case .economicCrisis:
            return "Economic Turmoil in \(countryName)"
        case .ideologicalChallenge:
            return "Ideological Challenge from \(countryName)"
        case .superpowerConfrontation:
            return "SUPERPOWER CRISIS"
        }
    }

    func generateDescription(for countryName: String) -> String {
        switch self {
        case .borderIncident:
            return "Armed clashes have occurred along the border with \(countryName). Casualties reported on both sides. The situation remains tense."

        case .spyScandal:
            return "An espionage operation involving \(countryName) has been exposed. Diplomatic fallout is expected. The intelligence community awaits direction."

        case .tradeWar:
            return "\(countryName) has imposed new trade restrictions against our exports. Economic planners report potential impact on key sectors."

        case .militaryProvocation:
            return "Military forces from \(countryName) have engaged in provocative maneuvers near our territory. The General Staff requests guidance on response."

        case .allianceStrain:
            return "Reports indicate that \(countryName)'s commitment to our alliance is weakening. Western diplomats have increased their presence in their capital."

        case .proxyWarOpportunity:
            return "Internal conflict in \(countryName) presents an opportunity for intervention. Revolutionary forces seek our support against the current regime."

        case .coupAttempt:
            return "A coup attempt is underway in \(countryName). The outcome is uncertain. Our allies in the country request immediate assistance."

        case .economicCrisis:
            return "Economic collapse threatens \(countryName). They may request emergency aid, or their instability could spread to neighboring states."

        case .ideologicalChallenge:
            return "\(countryName) has issued statements challenging our interpretation of socialist doctrine. The international communist movement awaits our response."

        case .superpowerConfrontation:
            return "A serious incident has brought us to the brink of direct military confrontation. The world watches as both sides weigh their options. Nuclear forces are on alert."
        }
    }
}

struct InternationalCrisisEvent: Identifiable, Codable {
    var id: String
    var countryId: String
    var crisisType: InternationalCrisisType
    var severity: Int
    var turn: Int
    var headline: String
    var description: String
    var resolved: Bool = false
    var resolution: String?
}

struct InternationalAssessment {
    var allyCount: Int
    var enemyCount: Int
    var threatCount: Int
    var averageRelationship: Int
    var maximumTension: Int
    var mostDangerousCountry: ForeignCountry?
    var weakestAlliance: ForeignCountry?
    var recommendations: [String]

    var overallStatusDescription: String {
        if threatCount >= 3 || maximumTension > 85 {
            return "Critical - Multiple serious threats"
        } else if threatCount >= 2 || maximumTension > 70 {
            return "Dangerous - Active tensions with adversaries"
        } else if averageRelationship < -20 {
            return "Strained - International isolation growing"
        } else if averageRelationship > 20 && threatCount == 0 {
            return "Favorable - Strong diplomatic position"
        } else {
            return "Stable - Normal Cold War tensions"
        }
    }
}

// MARK: - NPC Diplomatic Action Integration

extension InternationalEventService {

    /// Process autonomous NPC diplomatic decisions and generate events
    func processNPCDiplomaticActions(game: Game) -> [NPCDiplomaticEvent] {
        var diplomaticEvents: [NPCDiplomaticEvent] = []

        // Get Foreign Affairs track officials (Position 5+)
        let foreignAffairsOfficials = game.characters.filter { character in
            character.isAlive &&
            character.positionTrack == "foreign" &&
            (character.positionIndex ?? 0) >= 5
        }

        for official in foreignAffairsOfficials {
            // Check for diplomatic goal pursuit
            if let action = evaluateDiplomaticAction(for: official, game: game) {
                let event = executeDiplomaticAction(action, by: official, game: game)
                diplomaticEvents.append(event)
            }
        }

        return diplomaticEvents
    }

    /// Evaluate what diplomatic action an NPC should take
    private func evaluateDiplomaticAction(
        for character: GameCharacter,
        game: Game
    ) -> NPCDiplomaticActionPlan? {
        // Only act occasionally (30% chance per turn)
        guard Int.random(in: 1...100) <= 30 else { return nil }

        // Get character's diplomatic goals
        let allGoals = character.goals ?? []
        let diplomaticGoals = allGoals.filter { $0.goalType.isDiplomaticGoal && $0.isActive }
        guard let primaryGoal = diplomaticGoals.max(by: { $0.effectivePriority(currentTurn: game.turnNumber) < $1.effectivePriority(currentTurn: game.turnNumber) }) else {
            return nil
        }

        // Select action based on goal
        switch primaryGoal.goalType {
        case .improveAllyRelations:
            // Find socialist ally with lowest relationship
            if let weakestAlly = game.foreignCountries
                .filter({ $0.politicalBloc == .socialist && $0.relationshipScore < 70 })
                .min(by: { $0.relationshipScore < $1.relationshipScore }) {
                return NPCDiplomaticActionPlan(
                    actionType: .strengthenedAlliance,
                    targetCountryId: weakestAlly.countryId,
                    priority: primaryGoal.priority
                )
            }

        case .containCapitalistThreat:
            // Counter most active capitalist power
            if let threat = game.foreignCountries
                .filter({ $0.politicalBloc == .capitalist && $0.diplomaticTension > 50 })
                .max(by: { $0.diplomaticTension < $1.diplomaticTension }) {
                return NPCDiplomaticActionPlan(
                    actionType: .counteredWesternInfluence,
                    targetCountryId: threat.countryId,
                    priority: primaryGoal.priority
                )
            }

        case .expandTradeNetwork:
            // Expand trade with non-aligned nations
            if let tradePartner = game.foreignCountries
                .filter({ $0.politicalBloc == .nonAligned && $0.relationshipScore > 0 && $0.tradeVolume < 50 })
                .randomElement() {
                return NPCDiplomaticActionPlan(
                    actionType: .expandedTrade,
                    targetCountryId: tradePartner.countryId,
                    priority: primaryGoal.priority
                )
            }

        case .defuseInternationalCrisis:
            // Handle highest tension country
            if let crisis = game.foreignCountries
                .filter({ $0.diplomaticTension > 70 })
                .max(by: { $0.diplomaticTension < $1.diplomaticTension }) {
                return NPCDiplomaticActionPlan(
                    actionType: .defusedCrisis,
                    targetCountryId: crisis.countryId,
                    priority: max(primaryGoal.priority, 70)  // Crises are urgent
                )
            }

        case .negotiateTreaty:
            // Negotiate with countries we don't have major treaties with
            if let potential = game.foreignCountries
                .filter({ $0.relationshipScore > 20 && $0.treaties.count < 2 })
                .randomElement() {
                return NPCDiplomaticActionPlan(
                    actionType: .proposedTreaty,
                    targetCountryId: potential.countryId,
                    priority: primaryGoal.priority
                )
            }

        case .proposeForeignPolicy:
            // Propose policy change (no specific country target)
            return NPCDiplomaticActionPlan(
                actionType: .proposedPolicyChange,
                targetCountryId: nil,
                priority: primaryGoal.priority
            )

        case .advanceIdeologicalGoals:
            // Strengthen relations with socialist bloc
            if let ally = game.foreignCountries
                .filter({ $0.politicalBloc == .socialist })
                .randomElement() {
                return NPCDiplomaticActionPlan(
                    actionType: .conductedNegotiations,
                    targetCountryId: ally.countryId,
                    priority: primaryGoal.priority
                )
            }

        default:
            return nil
        }

        return nil
    }

    /// Execute a diplomatic action and return the resulting event
    private func executeDiplomaticAction(
        _ plan: NPCDiplomaticActionPlan,
        by character: GameCharacter,
        game: Game
    ) -> NPCDiplomaticEvent {
        var success = true
        var effects: [String: Int] = [:]

        // Get target country if applicable
        let targetCountry = plan.targetCountryId.flatMap { game.country(withId: $0) }

        // Apply effects based on action type
        switch plan.actionType {
        case .strengthenedAlliance:
            if let country = targetCountry {
                country.modifyRelationship(by: 5)
                effects["relationship"] = 5
            }

        case .counteredWesternInfluence:
            if let country = targetCountry {
                // Reduce capitalist influence, slight tension increase
                country.diplomaticTension = max(0, country.diplomaticTension - 5)
                effects["tension"] = -5
            }

        case .expandedTrade:
            if let country = targetCountry {
                country.tradeVolume = min(100, country.tradeVolume + 10)
                effects["trade"] = 10
            }

        case .defusedCrisis:
            if let country = targetCountry {
                let reduction = min(20, country.diplomaticTension / 2)
                country.diplomaticTension = max(0, country.diplomaticTension - reduction)
                effects["tension"] = -reduction
                // Crisis defusion affects world tension
                game.applyStat("worldTension", change: -3)
            }

        case .proposedTreaty:
            if let country = targetCountry {
                // Small relationship boost for opening negotiations
                country.modifyRelationship(by: 3)
                effects["relationship"] = 3
                // Mark negotiation in progress
                game.variables["treaty_negotiation_\(country.countryId)"] = String(game.turnNumber)
            }

        case .conductedNegotiations:
            if let country = targetCountry {
                country.modifyRelationship(by: 2)
                effects["relationship"] = 2
            }

        case .proposedPolicyChange:
            // Policy change handled by PoliticalAIService
            break

        case .conductedEspionage:
            // Espionage operations - chance of discovery
            if let country = targetCountry {
                let discoveryRoll = Int.random(in: 1...100)
                if discoveryRoll <= 20 {
                    success = false
                    country.diplomaticTension = min(100, country.diplomaticTension + 10)
                    effects["tension"] = 10
                } else {
                    country.ourIntelligenceAssets = min(100, country.ourIntelligenceAssets + 5)
                    effects["intelligence"] = 5
                }
            }

        case .respondedToCrisis:
            if let country = targetCountry {
                // Appropriate response to crisis
                let change = Int.random(in: 3...8)
                country.diplomaticTension = max(0, country.diplomaticTension - change)
                effects["tension"] = -change
            }
        }

        return NPCDiplomaticEvent(
            id: UUID().uuidString,
            turn: game.turnNumber,
            characterId: character.id.uuidString,
            characterName: character.name,
            actionType: plan.actionType,
            targetCountryId: plan.targetCountryId,
            targetCountryName: targetCountry?.name,
            success: success,
            effects: effects
        )
    }

    /// Generate a briefing item from NPC diplomatic action
    func createBriefingFromNPCAction(
        event: NPCDiplomaticEvent,
        positionIndex: Int,
        game: Game
    ) -> DiplomaticBriefingItem? {
        // Lower positions get sanitized briefings
        let classification: BriefingClassification
        let showDetails: Bool

        if positionIndex >= 6 {
            classification = .secret
            showDetails = true
        } else if positionIndex >= 4 {
            classification = .confidential
            showDetails = true
        } else {
            classification = .publicNews
            showDetails = false
        }

        // Espionage actions are only in classified briefings
        if event.actionType == .conductedEspionage && positionIndex < 5 {
            return nil
        }

        let summary: String?
        let fullDetails: String?

        if showDetails {
            summary = generateSanitizedBriefing(for: event, game: game)
            fullDetails = generateDetailedBriefing(for: event, game: game)
        } else {
            summary = generateSanitizedBriefing(for: event, game: game)
            fullDetails = nil
        }

        // Map action type to briefing category
        let category: BriefingCategory
        switch event.actionType {
        case .proposedTreaty, .conductedNegotiations:
            category = .treaty
        case .strengthenedAlliance:
            category = .bilateral
        case .expandedTrade:
            category = .trade
        case .defusedCrisis, .respondedToCrisis:
            category = .crisis
        case .conductedEspionage:
            category = .intelligence
        case .counteredWesternInfluence:
            category = .bilateral
        case .proposedPolicyChange:
            category = .summit
        }

        return DiplomaticBriefingItem(
            turnNumber: game.turnNumber,
            category: category,
            classification: classification,
            countryId: event.targetCountryId,
            headline: "\(event.actionType.displayName) Report",
            summary: summary,
            fullDetails: fullDetails,
            isUrgent: event.actionType == .defusedCrisis || event.actionType == .respondedToCrisis
        )
    }

    private func generateDetailedBriefing(for event: NPCDiplomaticEvent, game: Game) -> String {
        let countryName = event.targetCountryName ?? "multiple nations"
        let effects = event.effects.map { "\($0.key): \($0.value > 0 ? "+" : "")\($0.value)" }.joined(separator: ", ")

        switch event.actionType {
        case .strengthenedAlliance:
            return "\(event.characterName) conducted consultations with \(countryName) leadership. Relations improved. Effects: \(effects)."
        case .counteredWesternInfluence:
            return "Diplomatic counter-operations directed by \(event.characterName) have reduced Western influence in \(countryName). Effects: \(effects)."
        case .expandedTrade:
            return "Trade negotiations led by \(event.characterName) with \(countryName) concluded successfully. Trade volume increased. Effects: \(effects)."
        case .defusedCrisis:
            return "Crisis with \(countryName) successfully de-escalated through intervention by \(event.characterName). Effects: \(effects)."
        case .proposedTreaty:
            return "\(event.characterName) has initiated treaty negotiations with \(countryName). Initial response positive. Effects: \(effects)."
        case .conductedNegotiations:
            return "Ongoing diplomatic talks with \(countryName) under \(event.characterName)'s direction. Progress reported. Effects: \(effects)."
        case .conductedEspionage:
            if event.success {
                return "CLASSIFIED: Intelligence operation in \(countryName) successful. Asset network strengthened. Effects: \(effects)."
            } else {
                return "CLASSIFIED: Intelligence operation in \(countryName) compromised. Damage assessment ongoing. Effects: \(effects)."
            }
        case .proposedPolicyChange:
            return "\(event.characterName) has submitted foreign policy recommendations to the Standing Committee for consideration."
        case .respondedToCrisis:
            return "Response to international incident coordinated by \(event.characterName). Situation stabilizing. Effects: \(effects)."
        }
    }

    private func generateSanitizedBriefing(for event: NPCDiplomaticEvent, game: Game) -> String {
        let countryName = event.targetCountryName ?? "foreign nations"

        switch event.actionType {
        case .strengthenedAlliance:
            return "The Foreign Ministry reports improved relations with \(countryName) following diplomatic consultations."
        case .counteredWesternInfluence:
            return "Foreign Ministry activities continue to protect national interests in the international arena."
        case .expandedTrade:
            return "Trade discussions with \(countryName) have produced positive results."
        case .defusedCrisis:
            return "Diplomatic efforts have successfully addressed recent tensions with \(countryName)."
        case .proposedTreaty:
            return "The Foreign Ministry is engaged in treaty discussions with \(countryName)."
        case .conductedNegotiations:
            return "Diplomatic talks with \(countryName) continue on schedule."
        case .conductedEspionage:
            return nil as String? ?? ""  // Should not reach here
        case .proposedPolicyChange:
            return "The Foreign Ministry has submitted recommendations for Party leadership consideration."
        case .respondedToCrisis:
            return "The Foreign Ministry has addressed recent international developments."
        }
    }
}

/// Plan for an NPC diplomatic action
struct NPCDiplomaticActionPlan {
    let actionType: NPCDiplomaticActionType
    let targetCountryId: String?
    let priority: Int
}

/// Event generated by NPC diplomatic action
struct NPCDiplomaticEvent: Identifiable, Codable {
    let id: String
    let turn: Int
    let characterId: String
    let characterName: String
    let actionType: NPCDiplomaticActionType
    let targetCountryId: String?
    let targetCountryName: String?
    let success: Bool
    let effects: [String: Int]
}

// MARK: - DynamicEvent Integration

extension InternationalEventService {

    /// Convert an international crisis to a DynamicEvent for presentation
    func createDynamicEvent(from crisis: InternationalCrisisEvent, country: ForeignCountry, currentTurn: Int) -> DynamicEvent {
        let responses = generateCrisisResponses(for: crisis, country: country)

        // Convert severity to EventPriority
        let eventPriority: EventPriority
        switch crisis.severity {
        case 0...2: eventPriority = .normal
        case 3: eventPriority = .elevated
        case 4: eventPriority = .urgent
        default: eventPriority = .critical
        }

        return DynamicEvent(
            eventType: crisis.crisisType == .superpowerConfrontation ? .urgentInterruption : .worldNews,
            priority: eventPriority,
            title: crisis.headline,
            briefText: crisis.description,
            detailedText: "Country: \(country.name)\nCrisis Type: \(crisis.crisisType.rawValue)",
            turnGenerated: currentTurn,
            expiresOnTurn: crisis.severity >= 4 ? currentTurn + 1 : currentTurn + 2,
            isUrgent: crisis.severity >= 4,
            responseOptions: responses,
            linkedDecisionId: "crisis_\(crisis.id)",
            callbackFlag: "crisis_\(crisis.id)_resolved",
            iconName: "globe"
        )
    }

    private func generateCrisisResponses(for crisis: InternationalCrisisEvent, country: ForeignCountry) -> [EventResponse] {
        var responses: [EventResponse] = []

        switch crisis.crisisType {
        case .borderIncident:
            responses = [
                EventResponse(
                    id: "escalate_\(crisis.id)",
                    text: "Reinforce the border and demand apology",
                    shortText: "Escalate",
                    effects: ["worldTension": 10, "militaryReadiness": 5],
                    riskLevel: .high
                ),
                EventResponse(
                    id: "negotiate_\(crisis.id)",
                    text: "Propose joint investigation",
                    shortText: "Negotiate",
                    effects: ["worldTension": -5, "reputation": -3],
                    riskLevel: .low
                ),
                EventResponse(
                    id: "protest_\(crisis.id)",
                    text: "Issue formal diplomatic protest",
                    shortText: "Protest",
                    effects: ["worldTension": 3],
                    riskLevel: .medium
                )
            ]

        case .allianceStrain:
            responses = [
                EventResponse(
                    id: "pressure_\(crisis.id)",
                    text: "Remind them of their obligations",
                    shortText: "Pressure",
                    effects: ["patronFavor": 3, "worldTension": 5],
                    riskLevel: .medium
                ),
                EventResponse(
                    id: "conciliate_\(crisis.id)",
                    text: "Offer economic concessions",
                    shortText: "Conciliate",
                    effects: ["treasury": -15],
                    riskLevel: .low
                ),
                EventResponse(
                    id: "ignore_\(crisis.id)",
                    text: "Monitor the situation",
                    shortText: "Monitor",
                    effects: ["standing": -3],
                    riskLevel: .medium
                )
            ]

        case .superpowerConfrontation:
            responses = [
                EventResponse(
                    id: "standFirm_\(crisis.id)",
                    text: "Stand firm - we will not back down",
                    shortText: "Stand Firm",
                    effects: ["worldTension": 25, "patronFavor": 10],
                    riskLevel: .high
                ),
                EventResponse(
                    id: "backChannel_\(crisis.id)",
                    text: "Open back-channel negotiations",
                    shortText: "Negotiate",
                    effects: ["worldTension": -10, "standing": -5],
                    riskLevel: .medium
                ),
                EventResponse(
                    id: "partialRetreat_\(crisis.id)",
                    text: "Make limited concessions to de-escalate",
                    shortText: "Concede",
                    effects: ["worldTension": -20, "reputation": -15, "patronFavor": -10],
                    riskLevel: .low
                )
            ]

        case .proxyWarOpportunity:
            responses = [
                EventResponse(
                    id: "intervene_\(crisis.id)",
                    text: "Provide military support to revolutionary forces",
                    shortText: "Intervene",
                    effects: ["treasury": -25, "worldTension": 15],
                    riskLevel: .high
                ),
                EventResponse(
                    id: "covert_\(crisis.id)",
                    text: "Provide covert assistance only",
                    shortText: "Covert Aid",
                    effects: ["treasury": -10, "worldTension": 5],
                    riskLevel: .medium
                ),
                EventResponse(
                    id: "abstain_\(crisis.id)",
                    text: "Stay out of this conflict",
                    shortText: "Abstain",
                    effects: ["standing": -5],
                    riskLevel: .low
                )
            ]

        default:
            responses = [
                EventResponse(
                    id: "respond_\(crisis.id)",
                    text: "Respond firmly through diplomatic channels",
                    shortText: "Respond",
                    effects: ["worldTension": 5],
                    riskLevel: .medium
                ),
                EventResponse(
                    id: "measured_\(crisis.id)",
                    text: "Take measured, proportional action",
                    shortText: "Measured",
                    effects: ["worldTension": 2],
                    riskLevel: .low
                ),
                EventResponse(
                    id: "wait_\(crisis.id)",
                    text: "Wait and assess the situation",
                    shortText: "Wait",
                    effects: ["patronFavor": -3],
                    riskLevel: .low
                )
            ]
        }

        return responses
    }
}
