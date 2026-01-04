//
//  IntelligenceAlert.swift
//  Nomenklatura
//
//  Pending intelligence alerts awaiting player decision.
//  Players can choose to SAVE or DISMISS each alert.
//  Only saved alerts appear in the journal/notes.
//

import Foundation
import CryptoKit

// MARK: - Intelligence Alert

/// A pending intelligence alert awaiting player decision
nonisolated struct IntelligenceAlert: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var turnDiscovered: Int
    var category: JournalCategory
    var title: String
    var content: String
    var relatedCharacterId: String?
    var relatedCharacterName: String?
    var relatedFactionId: String?
    var relatedLawId: String?
    var importance: Int              // 1-10, higher = more significant
    var createdAt: Date = Date()
    var contentHash: String          // Hash for deduplication

    init(
        turnDiscovered: Int,
        category: JournalCategory,
        title: String,
        content: String,
        relatedCharacterId: String? = nil,
        relatedCharacterName: String? = nil,
        relatedFactionId: String? = nil,
        relatedLawId: String? = nil,
        importance: Int = 5
    ) {
        self.id = UUID()
        self.turnDiscovered = turnDiscovered
        self.category = category
        self.title = title
        self.content = content
        self.relatedCharacterId = relatedCharacterId
        self.relatedCharacterName = relatedCharacterName
        self.relatedFactionId = relatedFactionId
        self.relatedLawId = relatedLawId
        self.importance = importance
        self.createdAt = Date()

        // Generate content hash for deduplication
        self.contentHash = IntelligenceAlert.generateHash(
            title: title,
            content: content,
            characterId: relatedCharacterId
        )
    }

    /// Generate a hash from alert content for deduplication
    static func generateHash(title: String, content: String, characterId: String?) -> String {
        let combined = "\(title)|\(content)|\(characterId ?? "")"
        let data = Data(combined.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    /// Convert to a JournalEntry when saved
    func toJournalEntry() -> JournalEntry {
        var entry = JournalEntry(
            turnDiscovered: turnDiscovered,
            category: category,
            title: title,
            content: content,
            relatedCharacterId: relatedCharacterId,
            relatedFactionId: relatedFactionId,
            relatedLawId: relatedLawId,
            importance: importance
        )
        entry.isRead = false
        return entry
    }
}

// MARK: - Game Extension for Intelligence Alerts

extension Game {

    // MARK: - Pending Alerts

    /// Pending intelligence alerts awaiting player decision
    var pendingAlerts: [IntelligenceAlert] {
        get {
            guard let data = pendingAlertsData else { return [] }
            return (try? JSONDecoder().decode([IntelligenceAlert].self, from: data)) ?? []
        }
        set {
            pendingAlertsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Number of pending alerts
    var pendingAlertCount: Int {
        pendingAlerts.count
    }

    /// Get the next alert to show (oldest first)
    var nextPendingAlert: IntelligenceAlert? {
        pendingAlerts.last // Last = oldest since we insert at front
    }

    // MARK: - Dismissed Alert Hashes

    /// Hashes of alerts that were dismissed (to prevent re-showing)
    var dismissedAlertHashes: Set<String> {
        get {
            guard let data = dismissedAlertHashesData else { return [] }
            return (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
        }
        set {
            dismissedAlertHashesData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Saved Alert Hashes (from Journal)

    /// Hashes of alerts that were saved to journal
    var savedAlertHashes: Set<String> {
        // Compute from journal entries
        // We store the hash in the content hash field when converting
        // For now, generate from existing entries
        let entries = journalEntries
        var hashes = Set<String>()
        for entry in entries {
            let hash = IntelligenceAlert.generateHash(
                title: entry.title,
                content: entry.content,
                characterId: entry.relatedCharacterId
            )
            hashes.insert(hash)
        }
        return hashes
    }

    // MARK: - Alert Management

    /// Check if an alert with this hash already exists (saved, pending, or dismissed)
    func isAlertDuplicate(hash: String) -> Bool {
        // Check pending alerts
        if pendingAlerts.contains(where: { $0.contentHash == hash }) {
            return true
        }

        // Check dismissed hashes
        if dismissedAlertHashes.contains(hash) {
            return true
        }

        // Check saved journal entries
        if savedAlertHashes.contains(hash) {
            return true
        }

        return false
    }

    /// Add a new pending alert (only if not a duplicate)
    /// Returns true if added, false if duplicate
    @discardableResult
    func addPendingAlert(_ alert: IntelligenceAlert) -> Bool {
        // Check for duplicates
        if isAlertDuplicate(hash: alert.contentHash) {
            return false
        }

        var alerts = pendingAlerts
        alerts.insert(alert, at: 0) // Newest first
        pendingAlerts = alerts
        return true
    }

    /// Save an alert to journal and remove from pending
    func saveAlertToNotes(alertId: UUID) {
        guard let index = pendingAlerts.firstIndex(where: { $0.id == alertId }) else {
            return
        }

        let alert = pendingAlerts[index]

        // Convert to journal entry and save
        let entry = alert.toJournalEntry()
        addJournalEntry(entry)

        // Remove from pending
        var alerts = pendingAlerts
        alerts.remove(at: index)
        pendingAlerts = alerts
    }

    /// Dismiss an alert (remove from pending, add to dismissed hashes)
    func dismissAlert(alertId: UUID) {
        guard let index = pendingAlerts.firstIndex(where: { $0.id == alertId }) else {
            return
        }

        let alert = pendingAlerts[index]

        // Add hash to dismissed set
        var dismissed = dismissedAlertHashes
        dismissed.insert(alert.contentHash)
        dismissedAlertHashes = dismissed

        // Remove from pending
        var alerts = pendingAlerts
        alerts.remove(at: index)
        pendingAlerts = alerts
    }

    /// Clear all pending alerts (save all or dismiss all)
    func clearAllPendingAlerts(saveToNotes: Bool) {
        if saveToNotes {
            for alert in pendingAlerts {
                let entry = alert.toJournalEntry()
                addJournalEntry(entry)
            }
        } else {
            var dismissed = dismissedAlertHashes
            for alert in pendingAlerts {
                dismissed.insert(alert.contentHash)
            }
            dismissedAlertHashes = dismissed
        }
        pendingAlerts = []
    }
}
