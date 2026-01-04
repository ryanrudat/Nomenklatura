//
//  IntelligenceAlertService.swift
//  Nomenklatura
//
//  Service for managing intelligence alerts with deduplication.
//  Alerts await player decision (save or dismiss) before appearing in notes.
//

import Foundation
import Combine

// MARK: - Intelligence Alert Service

@MainActor
final class IntelligenceAlertService: ObservableObject {
    static let shared = IntelligenceAlertService()

    /// Whether there are pending alerts to show
    @Published var hasPendingAlerts = false

    /// Current alert being displayed (modal presentation)
    @Published var currentAlert: IntelligenceAlert?

    /// Whether alert modal is showing
    @Published var isShowingAlert = false

    private init() {}

    // MARK: - Alert Creation (with deduplication)

    /// Create an alert if not a duplicate. Returns true if created.
    @discardableResult
    func createAlert(
        for game: Game,
        category: JournalCategory,
        title: String,
        content: String,
        relatedCharacterId: String? = nil,
        relatedCharacterName: String? = nil,
        relatedFactionId: String? = nil,
        relatedLawId: String? = nil,
        importance: Int = 5
    ) -> Bool {
        let alert = IntelligenceAlert(
            turnDiscovered: game.turnNumber,
            category: category,
            title: title,
            content: content,
            relatedCharacterId: relatedCharacterId,
            relatedCharacterName: relatedCharacterName,
            relatedFactionId: relatedFactionId,
            relatedLawId: relatedLawId,
            importance: importance
        )

        let added = game.addPendingAlert(alert)

        if added {
            hasPendingAlerts = true
            // Show immediately if no current alert
            if currentAlert == nil {
                showNextAlert(for: game)
            }
        }

        return added
    }

    // MARK: - Alert Display

    /// Show the next pending alert
    func showNextAlert(for game: Game) {
        if let next = game.nextPendingAlert {
            currentAlert = next
            isShowingAlert = true
        } else {
            currentAlert = nil
            isShowingAlert = false
            hasPendingAlerts = false
        }
    }

    /// Check if there are pending alerts
    func updatePendingStatus(for game: Game) {
        hasPendingAlerts = game.pendingAlertCount > 0
    }

    // MARK: - Player Actions

    /// Save the current alert to notes
    func saveCurrentAlert(for game: Game) {
        guard let alert = currentAlert else { return }

        game.saveAlertToNotes(alertId: alert.id)
        showNextAlert(for: game)
    }

    /// Dismiss the current alert
    func dismissCurrentAlert(for game: Game) {
        guard let alert = currentAlert else { return }

        game.dismissAlert(alertId: alert.id)
        showNextAlert(for: game)
    }

    /// Save all pending alerts
    func saveAllAlerts(for game: Game) {
        game.clearAllPendingAlerts(saveToNotes: true)
        currentAlert = nil
        isShowingAlert = false
        hasPendingAlerts = false
    }

    /// Dismiss all pending alerts
    func dismissAllAlerts(for game: Game) {
        game.clearAllPendingAlerts(saveToNotes: false)
        currentAlert = nil
        isShowingAlert = false
        hasPendingAlerts = false
    }

    // MARK: - Event Hooks (replacing JournalService auto-save)

    /// Called when a character's personality is revealed
    func onPersonalityRevealed(character: GameCharacter, game: Game) {
        let dominantTrait = getDominantTrait(character)
        createAlert(
            for: game,
            category: .personalityReveal,
            title: "Character Insight: \(character.name)",
            content: "You have come to understand \(character.name)'s true nature. They appear to be primarily \(dominantTrait.lowercased()) in character. This knowledge may prove useful in future dealings.",
            relatedCharacterId: character.templateId,
            relatedCharacterName: character.name,
            importance: 6
        )
    }

    /// Called when a character's fate changes
    func onFateChange(character: GameCharacter, newStatus: CharacterStatus, narrative: String?, game: Game) {
        let title: String
        let importance: Int

        switch newStatus {
        case .executed:
            title = "Execution: \(character.name)"
            importance = 9
        case .imprisoned:
            title = "Imprisonment: \(character.name)"
            importance = 8
        case .exiled:
            title = "Exile: \(character.name)"
            importance = 7
        case .disappeared:
            title = "Disappearance: \(character.name)"
            importance = 8
        case .rehabilitated:
            title = "Rehabilitation: \(character.name)"
            importance = 7
        case .retired:
            title = "Retirement: \(character.name)"
            importance = 5
        case .dead:
            title = "Death: \(character.name)"
            importance = 7
        case .underInvestigation:
            title = "Investigation: \(character.name)"
            importance = 6
        case .detained:
            title = "Detention: \(character.name)"
            importance = 6
        case .active:
            title = "Return to Service: \(character.name)"
            importance = 5
        }

        let content = narrative ?? "\(character.name) has been \(newStatus.displayText.lowercased()). The Party's justice is final."

        createAlert(
            for: game,
            category: .fateChange,
            title: title,
            content: content,
            relatedCharacterId: character.templateId,
            relatedCharacterName: character.name,
            importance: importance
        )
    }

    /// Called when a plot thread develops significantly
    func onPlotDevelopment(title: String, description: String, game: Game) {
        createAlert(
            for: game,
            category: .plotDevelopment,
            title: title,
            content: description,
            importance: 7
        )
    }

    /// Called when a significant relationship change occurs
    func onRelationshipChange(character: GameCharacter, change: String, game: Game) {
        createAlert(
            for: game,
            category: .relationshipChange,
            title: "Relationship Update: \(character.name)",
            content: change,
            relatedCharacterId: character.templateId,
            relatedCharacterName: character.name,
            importance: 5
        )
    }

    /// Called when secret intelligence is received
    func onSecretIntelligence(title: String, content: String, relatedCharacterId: String? = nil, relatedCharacterName: String? = nil, game: Game) {
        createAlert(
            for: game,
            category: .secretIntelligence,
            title: title,
            content: content,
            relatedCharacterId: relatedCharacterId,
            relatedCharacterName: relatedCharacterName,
            importance: 7
        )
    }

    /// Called when a law is changed or proposed
    func onLawChange(law: Law, change: String, game: Game) {
        createAlert(
            for: game,
            category: .lawChange,
            title: "Legislative Change: \(law.name)",
            content: change,
            relatedLawId: law.lawId,
            importance: 6
        )
    }

    /// Called when historical information is declassified
    func onHistoricalRecordDeclassified(title: String, content: String, game: Game) {
        createAlert(
            for: game,
            category: .historicalRecord,
            title: title,
            content: content,
            importance: 5
        )
    }

    /// Called when faction information is discovered
    func onFactionDiscovery(faction: GameFaction, discovery: String, game: Game) {
        createAlert(
            for: game,
            category: .factionDiscovery,
            title: "Faction Intelligence: \(faction.name)",
            content: discovery,
            relatedFactionId: faction.factionId,
            importance: 6
        )
    }

    /// Called when an NPC takes autonomous action
    func onNPCActivity(character: GameCharacter, activitySummary: String, details: String, game: Game) {
        guard !activitySummary.isEmpty else { return }

        var importance = 4
        if character.isPatron { importance = 7 }
        else if character.isRival { importance = 6 }
        else if character.disposition >= 60 { importance = 5 }

        createAlert(
            for: game,
            category: .npcActivity,
            title: "\(character.name) Makes a Move",
            content: details.isEmpty ? "Reports indicate \(character.name) has been active in political circles." : details,
            relatedCharacterId: character.templateId,
            relatedCharacterName: character.name,
            importance: importance
        )
    }

    /// Called when a Standing Committee proposal is submitted
    func onCommitteeProposal(sponsor: GameCharacter, proposalTitle: String, description: String, isPlayerOverlap: Bool, game: Game) {
        var content = "\(sponsor.name) has submitted a proposal to the Standing Committee: \"\(proposalTitle)\""

        if isPlayerOverlap {
            content += "\n\nNOTE: This proposal may affect or conflict with your own agenda items."
        }

        if !description.isEmpty {
            content += "\n\nDetails: \(description)"
        }

        createAlert(
            for: game,
            category: .committeeActivity,
            title: "Committee Proposal: \(proposalTitle)",
            content: content,
            relatedCharacterId: sponsor.templateId,
            relatedCharacterName: sponsor.name,
            importance: isPlayerOverlap ? 8 : 6
        )
    }

    /// Called when a Standing Committee decision is made
    func onCommitteeDecision(itemTitle: String, outcome: String, playerInvolved: Bool, game: Game) {
        createAlert(
            for: game,
            category: .committeeActivity,
            title: "Committee Decision: \(itemTitle)",
            content: "The Standing Committee has reached a decision on \"\(itemTitle)\": \(outcome)",
            importance: playerInvolved ? 8 : 5
        )
    }

    // MARK: - Helper Methods

    private func getDominantTrait(_ character: GameCharacter) -> String {
        let traits: [(String, Int)] = [
            ("Ambitious", character.personalityAmbitious),
            ("Paranoid", character.personalityParanoid),
            ("Ruthless", character.personalityRuthless),
            ("Competent", character.personalityCompetent),
            ("Loyal", character.personalityLoyal),
            ("Corrupt", character.personalityCorrupt)
        ]

        if let highest = traits.max(by: { $0.1 < $1.1 }), highest.1 >= 60 {
            return highest.0
        }
        return "Unremarkable"
    }
}
