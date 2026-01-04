//
//  JournalService.swift
//  Nomenklatura
//
//  Service for managing journal entries with toast notifications.
//  NOTE: Most auto-generated entries now route through IntelligenceAlertService
//  for player-initiated save/dismiss. This service handles direct entries and toasts.
//

import Foundation
import Combine

// MARK: - Journal Toast

struct JournalToast: Identifiable {
    let id = UUID()
    let entry: JournalEntry
    let timestamp: Date = Date()
}

// MARK: - Journal Service

@MainActor
final class JournalService: ObservableObject {
    static let shared = JournalService()

    /// Current toast to display (auto-dismisses after 3 seconds)
    @Published var currentToast: JournalToast?

    /// Queue of pending toasts
    private var toastQueue: [JournalToast] = []

    /// Timer for auto-dismiss
    private var dismissTimer: Timer?

    private init() {}

    // MARK: - Public Methods

    /// Add a journal entry directly (bypasses alert system).
    /// Use for player-initiated saves or system-critical entries.
    func addEntry(
        to game: Game,
        category: JournalCategory,
        title: String,
        content: String,
        relatedCharacterId: String? = nil,
        relatedFactionId: String? = nil,
        relatedLawId: String? = nil,
        importance: Int = 5,
        showToast: Bool = true
    ) {
        let entry = JournalEntry(
            turnDiscovered: game.turnNumber,
            category: category,
            title: title,
            content: content,
            relatedCharacterId: relatedCharacterId,
            relatedFactionId: relatedFactionId,
            relatedLawId: relatedLawId,
            importance: importance
        )

        game.addJournalEntry(entry)

        // Show toast notification (optional)
        if showToast {
            self.showToast(for: entry)
        }
    }

    // MARK: - Event Hooks (Route to IntelligenceAlertService)
    //
    // These hooks now create alerts instead of directly adding to journal.
    // Player must explicitly save or dismiss each alert.

    /// Called when a character's personality is revealed
    func onPersonalityRevealed(character: GameCharacter, game: Game) {
        IntelligenceAlertService.shared.onPersonalityRevealed(character: character, game: game)
    }

    /// Called when a character's fate changes
    func onFateChange(character: GameCharacter, newStatus: CharacterStatus, narrative: String?, game: Game) {
        IntelligenceAlertService.shared.onFateChange(character: character, newStatus: newStatus, narrative: narrative, game: game)
    }

    /// Called when a plot thread develops significantly
    func onPlotDevelopment(title: String, description: String, game: Game) {
        IntelligenceAlertService.shared.onPlotDevelopment(title: title, description: description, game: game)
    }

    /// Called when a significant relationship change occurs
    func onRelationshipChange(character: GameCharacter, change: String, game: Game) {
        IntelligenceAlertService.shared.onRelationshipChange(character: character, change: change, game: game)
    }

    /// Called when secret intelligence is received (from Network stat)
    func onSecretIntelligence(title: String, content: String, relatedCharacterId: String? = nil, relatedCharacterName: String? = nil, game: Game) {
        IntelligenceAlertService.shared.onSecretIntelligence(title: title, content: content, relatedCharacterId: relatedCharacterId, relatedCharacterName: relatedCharacterName, game: game)
    }

    /// Called when a law is changed or proposed
    func onLawChange(law: Law, change: String, game: Game) {
        IntelligenceAlertService.shared.onLawChange(law: law, change: change, game: game)
    }

    /// Called when historical information is declassified
    func onHistoricalRecordDeclassified(title: String, content: String, game: Game) {
        IntelligenceAlertService.shared.onHistoricalRecordDeclassified(title: title, content: content, game: game)
    }

    /// Called when faction information is discovered
    func onFactionDiscovery(faction: GameFaction, discovery: String, game: Game) {
        IntelligenceAlertService.shared.onFactionDiscovery(faction: faction, discovery: discovery, game: game)
    }

    /// Called when an NPC takes autonomous action (political maneuvering)
    func onNPCActivity(character: GameCharacter, activitySummary: String, details: String, game: Game) {
        IntelligenceAlertService.shared.onNPCActivity(character: character, activitySummary: activitySummary, details: details, game: game)
    }

    /// Called when a Standing Committee proposal is submitted
    func onCommitteeProposal(sponsor: GameCharacter, proposalTitle: String, description: String, isPlayerOverlap: Bool, game: Game) {
        IntelligenceAlertService.shared.onCommitteeProposal(sponsor: sponsor, proposalTitle: proposalTitle, description: description, isPlayerOverlap: isPlayerOverlap, game: game)
    }

    /// Called when a Standing Committee decision is made
    func onCommitteeDecision(itemTitle: String, outcome: String, playerInvolved: Bool, game: Game) {
        IntelligenceAlertService.shared.onCommitteeDecision(itemTitle: itemTitle, outcome: outcome, playerInvolved: playerInvolved, game: game)
    }

    // MARK: - Toast Management

    private func showToast(for entry: JournalEntry) {
        let toast = JournalToast(entry: entry)

        if currentToast == nil {
            currentToast = toast
            scheduleAutoDismiss()
        } else {
            toastQueue.append(toast)
        }
    }

    func dismissCurrentToast() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        if !toastQueue.isEmpty {
            currentToast = toastQueue.removeFirst()
            scheduleAutoDismiss()
        } else {
            currentToast = nil
        }
    }

    private func scheduleAutoDismiss() {
        dismissTimer?.invalidate()
        // 5 seconds gives player time to read and decide to tap
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissCurrentToast()
            }
        }
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
