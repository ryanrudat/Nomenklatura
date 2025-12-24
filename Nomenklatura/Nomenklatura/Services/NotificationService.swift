//
//  NotificationService.swift
//  Nomenklatura
//
//  Tracks unread events and provides badge counts for UI tabs
//

import Foundation
import SwiftUI

// MARK: - Notification Types

enum NotificationType: String, Codable, CaseIterable {
    // Dossier notifications
    case newCharacter           // New figure discovered
    case characterFateChanged   // Someone arrested/executed/died
    case personalityRevealed    // Character personality now known
    case relationshipChanged    // Ally became rival or vice versa
    case characterMessage       // Someone reached out (proactive behavior)

    // Ledger notifications
    case statCriticalLow        // A stat dropped to dangerous levels
    case statCriticalHigh       // A negative stat (rival threat) got too high
    case statSignificantChange  // Major stat swing

    // Codex notifications
    case plotThreadUpdate       // Plot thread resolved or updated
    case newPlotThread          // New storyline began

    // Ladder notifications
    case promotionAvailable     // Player can advance
    case demotionRisk           // Player might lose position
    case badgeEarned            // Achievement/badge unlocked

    // General
    case newJournalEntry        // Decision recorded
    case newspaperAvailable     // New newspaper to read

    /// Which tab this notification belongs to
    var targetTab: GameTab {
        switch self {
        case .newCharacter, .characterFateChanged, .personalityRevealed,
             .relationshipChanged, .characterMessage, .newJournalEntry:
            return .dossier
        case .statCriticalLow, .statCriticalHigh, .statSignificantChange:
            return .ledger
        case .plotThreadUpdate, .newPlotThread:
            return .codex
        case .promotionAvailable, .demotionRisk, .badgeEarned:
            return .ladder
        case .newspaperAvailable:
            return .desk
        }
    }
}

// MARK: - Game Tab (for badge targeting)

enum GameTab: String, CaseIterable {
    case desk
    case ledger
    case dossier
    case world
    case codex
    case ladder
    case menu
}

// MARK: - Notification Item

struct NotificationItem: Codable, Identifiable {
    let id: UUID
    let type: NotificationType
    let title: String
    let detail: String?
    let turnCreated: Int
    let timestamp: Date
    var isRead: Bool

    init(type: NotificationType, title: String, detail: String? = nil, turn: Int) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.detail = detail
        self.turnCreated = turn
        self.timestamp = Date()
        self.isRead = false
    }
}

// MARK: - Notification Service

@Observable
class NotificationService {
    static let shared = NotificationService()

    /// All notifications (persisted with game)
    private(set) var notifications: [NotificationItem] = []

    /// Badge counts per tab
    var badgeCounts: [GameTab: Int] {
        var counts: [GameTab: Int] = [:]
        for tab in GameTab.allCases {
            counts[tab] = unreadCount(for: tab)
        }
        return counts
    }

    /// Total unread count
    var totalUnreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    // MARK: - Public API

    /// Add a new notification
    func notify(_ type: NotificationType, title: String, detail: String? = nil, turn: Int) {
        let notification = NotificationItem(type: type, title: title, detail: detail, turn: turn)
        notifications.append(notification)

        // Keep notifications manageable (last 50)
        if notifications.count > 50 {
            notifications = Array(notifications.suffix(50))
        }
    }

    /// Get unread count for a specific tab
    func unreadCount(for tab: GameTab) -> Int {
        notifications.filter { !$0.isRead && $0.type.targetTab == tab }.count
    }

    /// Check if a tab has unread notifications
    func hasUnread(for tab: GameTab) -> Bool {
        unreadCount(for: tab) > 0
    }

    /// Mark all notifications for a tab as read
    func markAsRead(for tab: GameTab) {
        for index in notifications.indices {
            if notifications[index].type.targetTab == tab {
                notifications[index].isRead = true
            }
        }
    }

    /// Mark a specific notification as read
    func markAsRead(_ notification: NotificationItem) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
        }
    }

    /// Get unread notifications for a tab
    func unreadNotifications(for tab: GameTab) -> [NotificationItem] {
        notifications.filter { !$0.isRead && $0.type.targetTab == tab }
    }

    /// Clear all notifications (e.g., on new game)
    func clearAll() {
        notifications.removeAll()
    }

    // MARK: - Persistence

    /// Encode notifications for storage
    func encodeNotifications() -> Data? {
        try? JSONEncoder().encode(notifications)
    }

    /// Restore notifications from storage
    func restoreNotifications(from data: Data) {
        if let decoded = try? JSONDecoder().decode([NotificationItem].self, from: data) {
            notifications = decoded
        }
    }

    // MARK: - Convenience Methods for Common Events

    /// Notify about a new character being discovered
    func notifyNewCharacter(name: String, title: String?, turn: Int) {
        let detail = title ?? "Unknown role"
        notify(.newCharacter, title: "New Figure: \(name)", detail: detail, turn: turn)
    }

    /// Notify about a character's fate changing
    func notifyCharacterFate(name: String, fate: String, turn: Int) {
        notify(.characterFateChanged, title: "\(name): \(fate)", detail: nil, turn: turn)
    }

    /// Notify about personality being revealed
    func notifyPersonalityRevealed(name: String, turn: Int) {
        notify(.personalityRevealed, title: "Intelligence Gathered", detail: "You now understand \(name)'s true nature", turn: turn)
    }

    /// Notify about relationship change
    func notifyRelationshipChanged(name: String, newRelation: String, turn: Int) {
        notify(.relationshipChanged, title: "Relationship Changed", detail: "\(name) is now \(newRelation)", turn: turn)
    }

    /// Notify about critical stat level
    func notifyStatCritical(statName: String, value: Int, isLow: Bool, turn: Int) {
        let type: NotificationType = isLow ? .statCriticalLow : .statCriticalHigh
        let direction = isLow ? "dangerously low" : "critically high"
        notify(type, title: "\(statName) \(direction)", detail: "Current value: \(value)", turn: turn)
    }

    /// Notify about promotion availability
    func notifyPromotionAvailable(positionName: String, turn: Int) {
        notify(.promotionAvailable, title: "Advancement Possible", detail: "You may be ready for: \(positionName)", turn: turn)
    }

    /// Notify about new plot thread
    func notifyNewPlotThread(title: String, turn: Int) {
        notify(.newPlotThread, title: "New Storyline", detail: title, turn: turn)
    }

    /// Notify about character message (proactive behavior)
    func notifyCharacterMessage(name: String, turn: Int) {
        notify(.characterMessage, title: "Message Received", detail: "\(name) wishes to speak with you", turn: turn)
    }

    /// Notify about badge/achievement earned
    func notifyBadgeEarned(name: String, tier: String, turn: Int) {
        notify(.badgeEarned, title: "Achievement Unlocked", detail: "\(name) (\(tier))", turn: turn)
    }
}

// MARK: - Badge View Component

struct NotificationBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 18, height: 18)

                if count < 10 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("9+")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Simple Dot Badge

struct NotificationDot: View {
    let isVisible: Bool
    var color: Color = .red

    var body: some View {
        if isVisible {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
    }
}
