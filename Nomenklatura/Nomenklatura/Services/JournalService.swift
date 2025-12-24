//
//  JournalService.swift
//  Nomenklatura
//
//  Service for managing journal entries with toast notifications
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

    /// Add a journal entry and show toast notification
    func addEntry(
        to game: Game,
        category: JournalCategory,
        title: String,
        content: String,
        relatedCharacterId: String? = nil,
        relatedFactionId: String? = nil,
        relatedLawId: String? = nil,
        importance: Int = 5
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

        // Show toast notification
        showToast(for: entry)
    }

    // MARK: - Specific Event Hooks

    /// Called when a character's personality is revealed
    func onPersonalityRevealed(character: GameCharacter, game: Game) {
        let dominantTrait = getDominantTrait(character)
        addEntry(
            to: game,
            category: .personalityReveal,
            title: "Character Insight: \(character.name)",
            content: "You have come to understand \(character.name)'s true nature. They appear to be primarily \(dominantTrait.lowercased()) in character. This knowledge may prove useful in future dealings.",
            relatedCharacterId: character.templateId,
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

        addEntry(
            to: game,
            category: .fateChange,
            title: title,
            content: content,
            relatedCharacterId: character.templateId,
            importance: importance
        )
    }

    /// Called when a plot thread develops significantly
    func onPlotDevelopment(title: String, description: String, game: Game) {
        addEntry(
            to: game,
            category: .plotDevelopment,
            title: title,
            content: description,
            importance: 7
        )
    }

    /// Called when a significant relationship change occurs
    func onRelationshipChange(character: GameCharacter, change: String, game: Game) {
        addEntry(
            to: game,
            category: .relationshipChange,
            title: "Relationship Update: \(character.name)",
            content: change,
            relatedCharacterId: character.templateId,
            importance: 5
        )
    }

    /// Called when secret intelligence is received (from Network stat)
    func onSecretIntelligence(title: String, content: String, relatedCharacterId: String? = nil, game: Game) {
        addEntry(
            to: game,
            category: .secretIntelligence,
            title: title,
            content: content,
            relatedCharacterId: relatedCharacterId,
            importance: 7
        )
    }

    /// Called when a law is changed or proposed
    func onLawChange(law: Law, change: String, game: Game) {
        addEntry(
            to: game,
            category: .lawChange,
            title: "Legislative Change: \(law.name)",
            content: change,
            relatedLawId: law.lawId,
            importance: 6
        )
    }

    /// Called when historical information is declassified
    func onHistoricalRecordDeclassified(title: String, content: String, game: Game) {
        addEntry(
            to: game,
            category: .historicalRecord,
            title: title,
            content: content,
            importance: 5
        )
    }

    /// Called when faction information is discovered
    func onFactionDiscovery(faction: GameFaction, discovery: String, game: Game) {
        addEntry(
            to: game,
            category: .factionDiscovery,
            title: "Faction Intelligence: \(faction.name)",
            content: discovery,
            relatedFactionId: faction.factionId,
            importance: 6
        )
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
