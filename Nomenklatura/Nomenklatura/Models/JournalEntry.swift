//
//  JournalEntry.swift
//  Nomenklatura
//
//  Journal entry model for tracking noteworthy discoveries and events
//

import Foundation

// MARK: - Journal Category

enum JournalCategory: String, Codable, CaseIterable {
    case personalityReveal      // Character personality discovered
    case factionDiscovery       // Faction scheming/information
    case plotDevelopment        // Major plot thread advancement
    case fateChange             // Character fate change (purged, promoted, etc.)
    case relationshipChange     // Significant relationship shift
    case secretIntelligence     // Information from network/leaks
    case historicalRecord       // Declassified historical information
    case lawChange              // Law modification or proposal

    var displayName: String {
        switch self {
        case .personalityReveal: return "Character Insight"
        case .factionDiscovery: return "Faction Intelligence"
        case .plotDevelopment: return "Political Development"
        case .fateChange: return "Personnel Change"
        case .relationshipChange: return "Relationship Shift"
        case .secretIntelligence: return "Secret Intelligence"
        case .historicalRecord: return "Historical Record"
        case .lawChange: return "Legislative Matter"
        }
    }

    var iconName: String {
        switch self {
        case .personalityReveal: return "person.fill.questionmark"
        case .factionDiscovery: return "person.3.fill"
        case .plotDevelopment: return "flag.fill"
        case .fateChange: return "arrow.up.arrow.down"
        case .relationshipChange: return "heart.fill"
        case .secretIntelligence: return "eye.fill"
        case .historicalRecord: return "book.closed.fill"
        case .lawChange: return "scroll.fill"
        }
    }
}

// MARK: - Journal Entry

struct JournalEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var turnDiscovered: Int
    var category: JournalCategory
    var title: String
    var content: String
    var relatedCharacterId: String?
    var relatedFactionId: String?
    var relatedLawId: String?
    var importance: Int  // 1-10, higher = more significant
    var isRead: Bool = false
    var dateAdded: Date = Date()

    init(
        turnDiscovered: Int,
        category: JournalCategory,
        title: String,
        content: String,
        relatedCharacterId: String? = nil,
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
        self.relatedFactionId = relatedFactionId
        self.relatedLawId = relatedLawId
        self.importance = importance
        self.isRead = false
        self.dateAdded = Date()
    }
}

// MARK: - Journal Entry Extension for Game

extension Game {
    /// Computed property for accessing journal entries from stored data
    var journalEntries: [JournalEntry] {
        get {
            guard let data = journalEntriesData else { return [] }
            return (try? JSONDecoder().decode([JournalEntry].self, from: data)) ?? []
        }
        set {
            journalEntriesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Unread journal entries count
    var unreadJournalCount: Int {
        journalEntries.filter { !$0.isRead }.count
    }

    /// Add a new journal entry
    func addJournalEntry(_ entry: JournalEntry) {
        var entries = journalEntries
        entries.insert(entry, at: 0)  // Most recent first
        journalEntries = entries
    }

    /// Mark an entry as read
    func markJournalEntryRead(id: UUID) {
        var entries = journalEntries
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].isRead = true
            journalEntries = entries
        }
    }

    /// Get entries by category
    func journalEntries(for category: JournalCategory) -> [JournalEntry] {
        journalEntries.filter { $0.category == category }
    }

    /// Get entries related to a character
    func journalEntries(forCharacterId characterId: String) -> [JournalEntry] {
        journalEntries.filter { $0.relatedCharacterId == characterId }
    }
}
