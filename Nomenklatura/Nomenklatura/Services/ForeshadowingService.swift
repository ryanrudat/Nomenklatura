//
//  ForeshadowingService.swift
//  Nomenklatura
//
//  Generates dramatic irony - intelligence about future events.
//  Those with connections know about purges before they happen,
//  show trial outcomes are predetermined, and whisper networks
//  carry critical information.
//

import Foundation
import os.log

private let foreshadowLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "Foreshadowing")

// MARK: - Foreshadowing Service

@MainActor
class ForeshadowingService {
    static let shared = ForeshadowingService()

    private init() {}

    // MARK: - Generate Foreshadowing

    /// Generate foreshadowing alerts for this turn based on game state
    func generateForeshadowing(game: Game) -> [ForeshadowingAlert] {
        var alerts: [ForeshadowingAlert] = []

        // Check various conditions that could generate foreshadowing

        // 1. Check for impending purges
        if let purgeAlert = checkForImpendingPurge(game: game) {
            alerts.append(purgeAlert)
        }

        // 2. Check for potential betrayals
        if let betrayalAlert = checkForBetrayalSigns(game: game) {
            alerts.append(betrayalAlert)
        }

        // 3. Check for rival moves
        if let rivalAlert = checkForRivalMoves(game: game) {
            alerts.append(rivalAlert)
        }

        // 4. Check for faction schemes
        if let factionAlert = checkForFactionSchemes(game: game) {
            alerts.append(factionAlert)
        }

        // 5. Check for patron wavering
        if let patronAlert = checkForPatronWavering(game: game) {
            alerts.append(patronAlert)
        }

        // 6. Check for rehabilitation possibilities
        if let rehabAlert = checkForRehabilitationPossible(game: game) {
            alerts.append(rehabAlert)
        }

        // 7. Check for investigation openings
        if let investigationAlert = checkForInvestigation(game: game) {
            alerts.append(investigationAlert)
        }

        // Log generated alerts
        for alert in alerts {
            foreshadowLogger.info("Generated foreshadowing: \(alert.type.rawValue) - \(alert.urgency.rawValue)")
        }

        return alerts
    }

    // MARK: - Purge Detection

    private func checkForImpendingPurge(game: Game) -> ForeshadowingAlert? {
        // Find characters who might be purged soon
        let vulnerableCharacters = game.characters.filter { char in
            guard char.isActive,
                  char.currentStatus == .active || char.currentStatus == .underInvestigation else { return false }

            // Under investigation
            if char.currentStatus == .underInvestigation { return true }

            // Low disposition to power holders
            if char.disposition < 30 { return true }

            // Faction losing power
            if let factionId = char.factionId,
               let faction = game.factions.first(where: { $0.factionId == factionId }),
               faction.power < 25 { return true }

            return false
        }

        guard let target = vulnerableCharacters.randomElement() else { return nil }

        // Only trigger with some probability
        guard Int.random(in: 1...100) <= 20 else { return nil }

        let urgency = determineUrgency(for: target, game: game)
        let source = determineSourceQuality(network: game.network)

        let content: String
        if target.currentStatus == .underInvestigation {
            content = "\(target.name) is under increasing scrutiny. The investigation seems to be reaching a conclusion, and it does not look favorable."
        } else if target.disposition < 20 {
            content = "There are whispers that \(target.name) has fallen out of favor with the leadership. Their position appears increasingly precarious."
        } else {
            content = "\(target.name)'s situation appears unstable. Sources suggest their name has come up in discussions about \"personnel adjustments.\""
        }

        return ForeshadowingAlert(
            type: .impendingPurge,
            urgency: urgency,
            content: content,
            sourceDescription: source.sourcePrefix,
            relatedCharacterId: target.templateId,
            relatedCharacterName: target.name,
            turnReceived: game.turnNumber,
            estimatedTurnToOccur: game.turnNumber + urgency.turnsAway.randomElement()!,
            confidenceLevel: source.confidenceRange.randomElement()!
        )
    }

    // MARK: - Betrayal Detection

    private func checkForBetrayalSigns(game: Game) -> ForeshadowingAlert? {
        // Look for allies who might betray
        let potentialTraitors = game.characters.filter { char in
            guard char.isActive else { return false }

            // Check if they're an ally who might turn
            let isAlly = char.disposition >= 60

            // But has reasons to betray
            let hasAmbition = char.personalityAmbitious > 70
            let isUnderPressure = char.currentStatus == .underInvestigation
            let hasLowLoyalty = char.personalityLoyal < 40

            return isAlly && (hasAmbition || isUnderPressure || hasLowLoyalty)
        }

        guard let traitor = potentialTraitors.randomElement() else { return nil }

        // Low probability
        guard Int.random(in: 1...100) <= 10 else { return nil }

        let urgency: ForeshadowingUrgency = traitor.currentStatus == .underInvestigation ? .imminent : .approaching
        let source = IntelligenceSourceQuality.rumor

        let content: String
        if traitor.currentStatus == .underInvestigation {
            content = "Sources suggest that \(traitor.name), under pressure from investigators, may be providing information about colleagues. Your name has reportedly been mentioned."
        } else {
            content = "\(traitor.name) has been seen in private meetings with individuals who are not your friends. The nature of these discussions is unknown, but the pattern is concerning."
        }

        return ForeshadowingAlert(
            type: .betrayalComing,
            urgency: urgency,
            content: content,
            sourceDescription: source.sourcePrefix,
            relatedCharacterId: traitor.templateId,
            relatedCharacterName: traitor.name,
            turnReceived: game.turnNumber,
            estimatedTurnToOccur: game.turnNumber + urgency.turnsAway.randomElement()!,
            confidenceLevel: source.confidenceRange.randomElement()!
        )
    }

    // MARK: - Rival Moves Detection

    private func checkForRivalMoves(game: Game) -> ForeshadowingAlert? {
        let activeRivals = game.characters.filter { $0.isRival && $0.isActive }

        guard let rival = activeRivals.randomElement() else { return nil }

        // Check if rival is actively plotting
        let isPlotting = rival.personalityAmbitious > 60 ||
                        rival.disposition < 30 ||
                        game.coalitionStrength > 50

        guard isPlotting, Int.random(in: 1...100) <= 25 else { return nil }

        let urgency = game.rivalThreat > 70 ? ForeshadowingUrgency.imminent : .approaching
        let source = determineSourceQuality(network: game.network)

        let plots = [
            "\(rival.name) is gathering allies against you. Their meetings have become more frequent, and the participants more influential.",
            "Intelligence suggests \(rival.name) is preparing a political move. The details are unclear, but your name features prominently.",
            "\(rival.name) has been soliciting support from members of the Standing Committee. The agenda appears to involve your portfolio.",
            "Sources report unusual activity around \(rival.name)'s office. Documents are being prepared, meetings held behind closed doors."
        ]

        return ForeshadowingAlert(
            type: .rivalMoves,
            urgency: urgency,
            content: plots.randomElement()!,
            sourceDescription: source.sourcePrefix,
            relatedCharacterId: rival.templateId,
            relatedCharacterName: rival.name,
            turnReceived: game.turnNumber,
            estimatedTurnToOccur: game.turnNumber + urgency.turnsAway.randomElement()!,
            confidenceLevel: source.confidenceRange.randomElement()!
        )
    }

    // MARK: - Faction Schemes Detection

    private func checkForFactionSchemes(game: Game) -> ForeshadowingAlert? {
        // Find factions that might be scheming
        let activeFactions = game.factions.filter { $0.power >= 30 }

        guard let faction = activeFactions.randomElement(),
              faction.factionId != game.playerFactionId,
              Int.random(in: 1...100) <= 15 else {
            return nil
        }

        let urgency = ForeshadowingUrgency.approaching
        let source = IntelligenceSourceQuality.credible

        let schemes = [
            "The \(faction.name) appears to be coordinating action on an upcoming matter. Their members have been meeting separately before committee sessions.",
            "Unusual cohesion has been observed among \(faction.name) members. They seem to be building consensus on something significant.",
            "Sources within \(faction.name) circles suggest a major initiative is being planned. Details are scarce, but it may affect the balance of power."
        ]

        return ForeshadowingAlert(
            type: .factionScheme,
            urgency: urgency,
            content: schemes.randomElement()!,
            sourceDescription: source.sourcePrefix,
            relatedFactionId: faction.factionId,
            relatedFactionName: faction.name,
            turnReceived: game.turnNumber,
            estimatedTurnToOccur: game.turnNumber + urgency.turnsAway.randomElement()!,
            confidenceLevel: source.confidenceRange.randomElement()!
        )
    }

    // MARK: - Patron Wavering Detection

    private func checkForPatronWavering(game: Game) -> ForeshadowingAlert? {
        guard let patron = game.patron,
              patron.isActive,
              game.patronFavor < 50 else {
            return nil
        }

        // Only alert if patron favor is declining
        guard Int.random(in: 1...100) <= 20 else { return nil }

        let urgency: ForeshadowingUrgency = game.patronFavor < 30 ? .imminent : .approaching
        let source = IntelligenceSourceQuality.trusted

        let warnings = [
            "Your patron \(patron.name)'s support appears to be weakening. They have been notably less vocal in your defense recently.",
            "Sources close to \(patron.name) suggest they are reconsidering their circle of proteges. Your position may not be as secure as you believed.",
            "\(patron.name) has been seen cultivating relationships with others who might replace you. The signals are subtle but concerning."
        ]

        return ForeshadowingAlert(
            type: .patronWavering,
            urgency: urgency,
            content: warnings.randomElement()!,
            sourceDescription: source.sourcePrefix,
            relatedCharacterId: patron.templateId,
            relatedCharacterName: patron.name,
            turnReceived: game.turnNumber,
            estimatedTurnToOccur: game.turnNumber + urgency.turnsAway.randomElement()!,
            confidenceLevel: source.confidenceRange.randomElement()!
        )
    }

    // MARK: - Rehabilitation Detection

    private func checkForRehabilitationPossible(game: Game) -> ForeshadowingAlert? {
        // Find characters who might be rehabilitated
        let fallenCharacters = game.characters.filter { char in
            let status = CharacterStatus(rawValue: char.status)
            return status == .exiled || status == .imprisoned
        }

        guard let fallen = fallenCharacters.randomElement() else { return nil }

        // Check if conditions favor rehabilitation
        let turnsSinceFall = game.turnNumber - (fallen.statusChangedTurn ?? 0)
        guard turnsSinceFall >= 10, Int.random(in: 1...100) <= 10 else { return nil }

        let urgency = ForeshadowingUrgency.distant
        let source = IntelligenceSourceQuality.rumor

        let hints = [
            "There are whispers about \(fallen.name). Some suggest the time may be right for a review of their case.",
            "The political winds are shifting, and names long forgotten are being mentioned again. \(fallen.name) is among them.",
            "Sources suggest that \(fallen.name)'s case is being reconsidered. Old enemies have fallen, and new patrons may be willing to sponsor their return."
        ]

        return ForeshadowingAlert(
            type: .rehabilitationPossible,
            urgency: urgency,
            content: hints.randomElement()!,
            sourceDescription: source.sourcePrefix,
            relatedCharacterId: fallen.templateId,
            relatedCharacterName: fallen.name,
            turnReceived: game.turnNumber,
            estimatedTurnToOccur: game.turnNumber + urgency.turnsAway.randomElement()!,
            confidenceLevel: source.confidenceRange.randomElement()!
        )
    }

    // MARK: - Investigation Detection

    private func checkForInvestigation(game: Game) -> ForeshadowingAlert? {
        // Check if player might be investigated
        guard game.network < 60,  // Vulnerable
              game.rivalThreat > 50,
              Int.random(in: 1...100) <= 15 else {
            return nil
        }

        // Find hostile characters who might initiate
        let hostiles = game.characters.filter {
            $0.isActive && $0.disposition < 30 && ($0.positionIndex ?? 0) >= 5
        }

        guard let instigator = hostiles.randomElement() else { return nil }

        let urgency = ForeshadowingUrgency.approaching
        let source = IntelligenceSourceQuality.credible

        let warnings = [
            "The discipline inspection commission has been asking questions. Your name has come up in connection with \"irregularities\" in your department.",
            "\(instigator.name) has reportedly requested a review of certain matters under your supervision. The formal investigation may not be far behind.",
            "Documents related to your portfolio have been requested by the anti-corruption bureau. This may be routine, or it may be the beginning of something more serious."
        ]

        return ForeshadowingAlert(
            type: .investigationOpening,
            urgency: urgency,
            content: warnings.randomElement()!,
            sourceDescription: source.sourcePrefix,
            relatedCharacterId: instigator.templateId,
            relatedCharacterName: instigator.name,
            turnReceived: game.turnNumber,
            estimatedTurnToOccur: game.turnNumber + urgency.turnsAway.randomElement()!,
            confidenceLevel: source.confidenceRange.randomElement()!
        )
    }

    // MARK: - Helpers

    private func determineUrgency(for character: GameCharacter, game: Game) -> ForeshadowingUrgency {
        if character.currentStatus == .underInvestigation {
            return .imminent
        }
        if character.disposition < 20 {
            return .approaching
        }
        return .distant
    }

    private func determineSourceQuality(network: Int) -> IntelligenceSourceQuality {
        if network >= 80 {
            return .trusted
        } else if network >= 60 {
            return .credible
        } else if network >= 40 {
            return .rumor
        } else {
            return .speculation
        }
    }

    // MARK: - Verify Predictions

    /// Check if any foreshadowing alerts should be resolved this turn
    func checkAlertResolutions(alerts: [ForeshadowingAlert], game: Game) -> [(ForeshadowingAlert, Bool, String)] {
        var resolutions: [(ForeshadowingAlert, Bool, String)] = []

        for alert in alerts where !alert.hasOccurred {
            if let (occurred, accurate, outcome) = checkAlertOutcome(alert: alert, game: game) {
                if occurred {
                    resolutions.append((alert, accurate, outcome))
                }
            }
        }

        return resolutions
    }

    private func checkAlertOutcome(alert: ForeshadowingAlert, game: Game) -> (Bool, Bool, String)? {
        guard game.turnNumber >= alert.estimatedTurnToOccur else { return nil }

        // Check if the predicted event occurred
        switch alert.type {
        case .impendingPurge:
            if let charId = alert.relatedCharacterId,
               let char = game.characters.first(where: { $0.templateId == charId }) {
                let status = char.currentStatus
                // Check if character was removed (exiled, imprisoned, executed, etc.)
                if status == .exiled || status == .imprisoned || status == .executed ||
                   status == .detained || status == .disappeared {
                    return (true, true, "\(char.name) was indeed removed from their position.")
                } else if game.turnNumber > alert.estimatedTurnToOccur + 3 && status == .active {
                    return (true, false, "\(char.name) has survived, contrary to expectations.")
                }
            }

        case .rivalMoves:
            // Check if rival took action
            if game.turnNumber >= alert.estimatedTurnToOccur,
               game.rivalThreat > 70 || game.coalitionStrength > 60 {
                return (true, true, "The rival's maneuvering has become apparent.")
            } else if game.turnNumber > alert.estimatedTurnToOccur + 2 {
                return (true, false, "The anticipated rival action did not materialize.")
            }

        case .patronWavering:
            if game.patronFavor < 30 {
                return (true, true, "Your patron's support has indeed weakened significantly.")
            } else if game.turnNumber > alert.estimatedTurnToOccur + 2 && game.patronFavor > 60 {
                return (true, false, "Your patron's support has remained strong.")
            }

        default:
            // For other types, resolve after estimated turn passes
            if game.turnNumber > alert.estimatedTurnToOccur + 2 {
                let accurate = Int.random(in: 1...100) <= alert.confidenceLevel
                let outcome = accurate ? "The prediction proved accurate." : "Events unfolded differently than expected."
                return (true, accurate, outcome)
            }
        }

        return nil
    }
}
