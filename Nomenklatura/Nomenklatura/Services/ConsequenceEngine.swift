//
//  ConsequenceEngine.swift
//  Nomenklatura
//
//  Engine for processing delayed consequences from law changes and other actions
//

import Foundation

// MARK: - Consequence Engine

class ConsequenceEngine {

    static let shared = ConsequenceEngine()

    private init() {}

    // MARK: - Consequence Generation

    /// Generate consequences when a law is modified
    func generateConsequences(for law: Law, newState: LawState, game: Game, wasForced: Bool) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []
        let currentTurn = game.turnNumber

        // Base delay for consequences (2-8 turns in the future)
        let baseDelay = Int.random(in: 2...5)

        // Forced changes generate more severe consequences
        let severityMultiplier = wasForced ? 1.5 : 1.0

        // Generate consequences based on law category
        switch law.lawCategory {
        case .institutional:
            consequences.append(contentsOf: generateInstitutionalConsequences(
                law: law, newState: newState, currentTurn: currentTurn,
                baseDelay: baseDelay, severity: severityMultiplier
            ))

        case .political:
            consequences.append(contentsOf: generatePoliticalConsequences(
                law: law, newState: newState, currentTurn: currentTurn,
                baseDelay: baseDelay, severity: severityMultiplier
            ))

        case .economic:
            consequences.append(contentsOf: generateEconomicConsequences(
                law: law, newState: newState, currentTurn: currentTurn,
                baseDelay: baseDelay, severity: severityMultiplier
            ))

        case .social:
            consequences.append(contentsOf: generateSocialConsequences(
                law: law, newState: newState, currentTurn: currentTurn,
                baseDelay: baseDelay, severity: severityMultiplier
            ))
        }

        // Add faction-specific consequences based on beneficiaries/losers
        consequences.append(contentsOf: generateFactionConsequences(
            law: law, newState: newState, currentTurn: currentTurn,
            baseDelay: baseDelay, game: game
        ))

        // Special case: abolishing term limits
        if law.lawId == "term_limits" && newState == .abolished {
            consequences.append(contentsOf: generateTermLimitConsequences(
                currentTurn: currentTurn, game: game
            ))
        }

        return consequences
    }

    // MARK: - Category-Specific Consequences

    private func generateInstitutionalConsequences(
        law: Law,
        newState: LawState,
        currentTurn: Int,
        baseDelay: Int,
        severity: Double
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Institutional changes always trigger elite backlash
        consequences.append(ScheduledConsequence(
            triggerTurn: currentTurn + baseDelay,
            type: .eliteBacklash,
            magnitude: Int(Double(30) * severity),
            description: "Senior Party members express concern about changes to \(law.name). Whispered conversations in the corridors of power.",
            relatedLawId: law.lawId,
            statEffects: ["eliteLoyalty": -5, "coalitionStrength": 10]
        ))

        // May trigger coalition formation
        if severity > 1.0 || newState == .abolished {
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay + 2,
                type: .coalitionForms,
                magnitude: Int(Double(40) * severity),
                description: "A group of concerned officials begins meeting privately to discuss the direction of Party policy.",
                relatedLawId: law.lawId,
                statEffects: ["coalitionStrength": 15, "network": -5]
            ))
        }

        return consequences
    }

    private func generatePoliticalConsequences(
        law: Law,
        newState: LawState,
        currentTurn: Int,
        baseDelay: Int,
        severity: Double
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Political changes may trigger popular unrest
        if newState == .strengthened || newState == .abolished {
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay + 1,
                type: .popularUnrest,
                magnitude: Int(Double(25) * severity),
                description: "Discontent simmers among the population regarding changes to \(law.name).",
                relatedLawId: law.lawId,
                statEffects: ["popularSupport": -8, "stability": -3]
            ))
        }

        // International observers take note
        consequences.append(ScheduledConsequence(
            triggerTurn: currentTurn + baseDelay,
            type: .internationalPressure,
            magnitude: Int(Double(20) * severity),
            description: "Foreign newspapers report on policy changes. The capitalist press finds new material for criticism.",
            relatedLawId: law.lawId,
            statEffects: ["internationalStanding": -5]
        ))

        return consequences
    }

    private func generateEconomicConsequences(
        law: Law,
        newState: LawState,
        currentTurn: Int,
        baseDelay: Int,
        severity: Double
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Economic changes have delayed economic effects
        let economicDelay = baseDelay + Int.random(in: 2...4) // Longer delay for economic effects

        consequences.append(ScheduledConsequence(
            triggerTurn: currentTurn + economicDelay,
            type: .economicEffect,
            magnitude: Int(Double(35) * severity),
            description: "The effects of changes to \(law.name) begin to ripple through the economy.",
            relatedLawId: law.lawId,
            statEffects: newState == .abolished ?
                ["industrialOutput": -10, "treasury": -5] :
                ["industrialOutput": -3, "treasury": -2]
        ))

        // Industrial ministries react
        consequences.append(ScheduledConsequence(
            triggerTurn: currentTurn + baseDelay,
            type: .factionRebellion,
            magnitude: Int(Double(20) * severity),
            description: "Industrial managers express concern about the new policies. Production targets may be affected.",
            relatedLawId: law.lawId,
            relatedCharacterId: nil,
            statEffects: nil
        ))

        return consequences
    }

    private func generateSocialConsequences(
        law: Law,
        newState: LawState,
        currentTurn: Int,
        baseDelay: Int,
        severity: Double
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Social changes affect regional stability
        consequences.append(ScheduledConsequence(
            triggerTurn: currentTurn + baseDelay + 1,
            type: .regionalTension,
            magnitude: Int(Double(25) * severity),
            description: "Changes to \(law.name) create tension in the republics and autonomous regions.",
            relatedLawId: law.lawId,
            statEffects: ["stability": -5]
        ))

        // May trigger popular reaction
        if law.lawId == "religious_tolerance" || law.lawId == "internal_passport" {
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay,
                type: .popularUnrest,
                magnitude: Int(Double(30) * severity),
                description: "The people react to changes in their daily lives. Not everyone welcomes the new order.",
                relatedLawId: law.lawId,
                statEffects: ["popularSupport": -10, "stability": -5]
            ))
        }

        return consequences
    }

    private func generateFactionConsequences(
        law: Law,
        newState: LawState,
        currentTurn: Int,
        baseDelay: Int,
        game: Game
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Losers from the law change react
        for factionId in law.losers {
            if let faction = game.factions.first(where: { $0.factionId == factionId }) {
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay,
                    type: .factionRebellion,
                    magnitude: 25,
                    description: "The \(faction.name) expresses displeasure with changes to \(law.name). Their support becomes less reliable.",
                    relatedLawId: law.lawId,
                    statEffects: nil
                ))
            }
        }

        return consequences
    }

    private func generateTermLimitConsequences(currentTurn: Int, game: Game) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Immediate elite concern
        consequences.append(ScheduledConsequence(
            triggerTurn: currentTurn + 1,
            type: .eliteBacklash,
            magnitude: 50,
            description: "The abolition of term limits sends shockwaves through the Party. Those who dreamed of succession find their hopes dashed.",
            relatedLawId: "term_limits",
            statEffects: ["eliteLoyalty": -15, "coalitionStrength": 20]
        ))

        // Coalition will definitely form
        consequences.append(ScheduledConsequence(
            triggerTurn: currentTurn + 3,
            type: .coalitionForms,
            magnitude: 60,
            description: "A shadow coalition of concerned Party members begins to take shape. They meet in private, speak in code, and wait.",
            relatedLawId: "term_limits",
            statEffects: ["coalitionStrength": 25, "rivalThreat": 15]
        ))

        // Military takes notice
        consequences.append(ScheduledConsequence(
            triggerTurn: currentTurn + 4,
            type: .militaryUnrest,
            magnitude: 40,
            description: "Senior military officers discuss the implications among themselves. The army has historically been the arbiter of succession.",
            relatedLawId: "term_limits",
            statEffects: ["militaryLoyalty": -10]
        ))

        // International condemnation
        consequences.append(ScheduledConsequence(
            triggerTurn: currentTurn + 2,
            type: .internationalPressure,
            magnitude: 45,
            description: "The capitalist press denounces the 'descent into dictatorship.' Even socialist allies express private concern.",
            relatedLawId: "term_limits",
            statEffects: ["internationalStanding": -15]
        ))

        // Character reactions - rivals become more dangerous
        for rival in game.characters.filter({ $0.isRival && $0.status == CharacterStatus.active.rawValue }) {
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + Int.random(in: 2...5),
                type: .characterAction,
                magnitude: 35,
                description: "\(rival.name) begins making quiet overtures to potential allies. Your consolidation of power has made enemies.",
                relatedLawId: "term_limits",
                relatedCharacterId: rival.id.uuidString,
                statEffects: ["rivalThreat": 10]
            ))
        }

        return consequences
    }

    // MARK: - Consequence Processing

    /// Process all due consequences for a turn
    func processConsequences(game: Game) -> [ProcessedConsequence] {
        var processed: [ProcessedConsequence] = []

        let dueConsequences = game.consequencesDueThisTurn()

        for (law, consequence) in dueConsequences {
            // Apply the consequence
            let result = applyConsequence(consequence, law: law, game: game)
            processed.append(result)

            // Mark as triggered
            law.markConsequenceTriggered(id: consequence.id)
        }

        game.updatedAt = Date()
        return processed
    }

    /// Apply a single consequence to the game
    private func applyConsequence(_ consequence: ScheduledConsequence, law: Law, game: Game) -> ProcessedConsequence {
        // Apply stat effects if any
        if let effects = consequence.statEffects {
            for (stat, change) in effects {
                game.applyStat(stat, change: change)
            }
        }

        // Generate narrative event based on type
        let narrative = generateConsequenceNarrative(consequence, law: law, game: game)

        // Track resistance
        law.resistanceGenerated += consequence.magnitude / 4

        return ProcessedConsequence(
            consequence: consequence,
            law: law,
            narrative: narrative,
            turn: game.turnNumber
        )
    }

    /// Generate narrative text for a consequence
    private func generateConsequenceNarrative(_ consequence: ScheduledConsequence, law: Law, game: Game) -> String {
        switch consequence.type {
        case .coalitionForms:
            return """
                COALITION ACTIVITY DETECTED

                \(consequence.description)

                Intelligence reports suggest that dissatisfied elements within the Party are coordinating their opposition. \
                Their numbers and intentions remain unclear, but their existence cannot be ignored.
                """

        case .eliteBacklash:
            return """
                ELITE CONCERNS

                \(consequence.description)

                The inner circle of power grows more cautious. Support that once seemed solid now comes with conditions. \
                Every smile hides calculation; every pledge of loyalty sounds hollow.
                """

        case .popularUnrest:
            return """
                POPULAR DISCONTENT

                \(consequence.description)

                Reports from the regions indicate growing unease among the masses. The Party's grip remains firm, \
                but the people's enthusiasm wanes. Whispered complaints grow louder.
                """

        case .factionRebellion:
            return """
                FACTION DISPLEASURE

                \(consequence.description)

                Those who lose from policy changes do not forget. They may accept their fate—or they may bide their time, \
                waiting for an opportunity to reverse their fortunes.
                """

        case .internationalPressure:
            return """
                INTERNATIONAL REACTION

                \(consequence.description)

                The eyes of the world observe our internal affairs with varying degrees of interest and concern. \
                Our enemies find ammunition; our friends grow silent.
                """

        case .economicEffect:
            return """
                ECONOMIC CONSEQUENCES

                \(consequence.description)

                The planned economy responds to policy changes—sometimes in unexpected ways. \
                Numbers on reports begin to tell a story that planners did not anticipate.
                """

        case .characterAction:
            if let characterId = consequence.relatedCharacterId,
               let character = game.characters.first(where: { $0.id.uuidString == characterId }) {
                return """
                    \(character.name.uppercased()) ACTS

                    \(consequence.description)

                    Your actions have not gone unnoticed by \(character.name). They are making moves of their own.
                    """
            }
            return consequence.description

        case .militaryUnrest:
            return """
                MILITARY CONCERNS

                \(consequence.description)

                The army watches politics with the careful attention of those who know they may be called upon \
                to enforce—or overturn—the current order.
                """

        case .regionalTension:
            return """
                REGIONAL INSTABILITY

                \(consequence.description)

                The distant zones and territories feel the effects of decisions made in Washington. \
                Not all of them appreciate the attention.
                """
        }
    }

    // MARK: - Consequence Events

    /// Create a DynamicEvent for a processed consequence
    func createConsequenceEvent(_ processed: ProcessedConsequence) -> DynamicEvent {
        let iconName: String
        let priority: Int

        switch processed.consequence.type {
        case .coalitionForms:
            iconName = "person.3.fill"
            priority = 8
        case .eliteBacklash:
            iconName = "exclamationmark.triangle.fill"
            priority = 7
        case .popularUnrest:
            iconName = "figure.wave"
            priority = 7
        case .factionRebellion:
            iconName = "flag.fill"
            priority = 6
        case .internationalPressure:
            iconName = "globe"
            priority = 5
        case .economicEffect:
            iconName = "chart.line.downtrend.xyaxis"
            priority = 6
        case .characterAction:
            iconName = "person.fill.questionmark"
            priority = 7
        case .militaryUnrest:
            iconName = "shield.fill"
            priority = 8
        case .regionalTension:
            iconName = "map.fill"
            priority = 6
        }

        // Convert priority Int to EventPriority
        let eventPriority: EventPriority
        switch priority {
        case 0...1: eventPriority = .background
        case 2...3: eventPriority = .normal
        case 4...5: eventPriority = .elevated
        case 6...7: eventPriority = .urgent
        default: eventPriority = .critical
        }

        // Build response options
        let responses = [
            EventResponse(
                id: "acknowledge_\(processed.consequence.id)",
                text: "Acknowledge the situation",
                shortText: "Noted",
                effects: [:]
            )
        ]

        // Convert character ID if present
        let relatedIds: [UUID]?
        if let charIdString = processed.consequence.relatedCharacterId,
           let uuid = UUID(uuidString: charIdString) {
            relatedIds = [uuid]
        } else {
            relatedIds = nil
        }

        return DynamicEvent(
            eventType: .consequenceCallback,
            priority: eventPriority,
            title: processed.consequence.type.displayName,
            briefText: processed.narrative,
            detailedText: nil,
            relatedCharacterIds: relatedIds,
            turnGenerated: processed.turn,
            isUrgent: eventPriority >= .urgent,
            responseOptions: responses,
            linkedDecisionId: processed.law.lawId,
            callbackFlag: "consequence_\(processed.consequence.id)_resolved",
            iconName: iconName
        )
    }
}

// MARK: - Processed Consequence

struct ProcessedConsequence {
    let consequence: ScheduledConsequence
    let law: Law
    let narrative: String
    let turn: Int
}

// MARK: - Law Modification Service

extension ConsequenceEngine {

    /// Process a law modification request
    func modifyLaw(
        _ law: Law,
        to newState: LawState,
        by characterName: String,
        forced: Bool,
        game: Game
    ) -> LawModificationResult {

        // Check if player has enough power
        let requirements = LawChangeRequirement.requirements(for: law, toState: newState)
        let currentPower = game.calculatePowerConsolidation()

        if forced {
            guard game.canForceLawChange(law, to: newState) else {
                return LawModificationResult(
                    success: false,
                    message: "Insufficient power to force this change. Required: \(requirements.forcePowerRequired), Current: \(currentPower)",
                    consequences: []
                )
            }
        } else {
            guard game.canModifyLaw(law, to: newState) else {
                return LawModificationResult(
                    success: false,
                    message: "Insufficient power to modify this law. Required: \(requirements.powerRequired), Current: \(currentPower)",
                    consequences: []
                )
            }
        }

        // Apply the change
        law.modify(to: newState, by: characterName, forced: forced, turn: game.turnNumber)

        // Generate consequences
        let consequences = generateConsequences(for: law, newState: newState, game: game, wasForced: forced)

        // Add consequences to the law
        for consequence in consequences {
            law.addConsequence(consequence)
        }

        // Update game state
        game.lawsModifiedCount += 1
        if law.lawId == "term_limits" && newState == .abolished {
            game.termLimitsAbolished = true
        }

        // Immediate effects of forcing
        if forced {
            game.applyStat("resistanceAccumulation", change: 15)
            game.applyStat("eliteLoyalty", change: -10)
            game.policiesForced += 1
        }

        game.updatedAt = Date()

        return LawModificationResult(
            success: true,
            message: "Law successfully \(forced ? "decreed" : "modified"). \(consequences.count) delayed consequences scheduled.",
            consequences: consequences
        )
    }
}

// MARK: - Law Modification Result

struct LawModificationResult {
    let success: Bool
    let message: String
    let consequences: [ScheduledConsequence]
}
