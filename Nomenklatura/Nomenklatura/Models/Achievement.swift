//
//  Achievement.swift
//  Nomenklatura
//
//  Achievement/Badge system for tracking player accomplishments
//

import Foundation
import SwiftData

// MARK: - Achievement Definition

/// Static definition of an achievement
struct AchievementDefinition: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var iconName: String             // SF Symbol name
    var category: AchievementCategory
    var isSecret: Bool               // Hidden until unlocked

    // Requirements (checked programmatically)
    var requirement: String          // Human-readable requirement
}

enum AchievementCategory: String, Codable, CaseIterable {
    case survival       // Surviving various challenges
    case power          // Reaching positions of power
    case political      // Political accomplishments
    case dark           // Morally questionable achievements
    case legacy         // Long-term accomplishments

    var displayName: String {
        switch self {
        case .survival: return "Survival"
        case .power: return "Power"
        case .political: return "Political"
        case .dark: return "Dark"
        case .legacy: return "Legacy"
        }
    }

    var iconName: String {
        switch self {
        case .survival: return "heart.fill"
        case .power: return "crown.fill"
        case .political: return "building.columns.fill"
        case .dark: return "moon.fill"
        case .legacy: return "book.closed.fill"
        }
    }
}

// MARK: - Unlocked Achievement (Persisted)

@Model
final class UnlockedAchievement {
    @Attribute(.unique) var achievementId: String
    var unlockedAt: Date
    var turnUnlocked: Int?
    var gameId: UUID?                // Which game it was unlocked in

    init(achievementId: String, turnUnlocked: Int? = nil, gameId: UUID? = nil) {
        self.achievementId = achievementId
        self.unlockedAt = Date()
        self.turnUnlocked = turnUnlocked
        self.gameId = gameId
    }
}

// MARK: - Achievement Registry

/// Contains all achievement definitions
final class AchievementRegistry {
    static let shared = AchievementRegistry()

    private(set) var achievements: [AchievementDefinition] = []

    private init() {
        loadAchievements()
    }

    private func loadAchievements() {
        achievements = [
            // SURVIVAL BADGES
            AchievementDefinition(
                id: "the_survivor",
                name: "The Survivor",
                description: "Complete 50 turns without being purged",
                iconName: "shield.checkered",
                category: .survival,
                isSecret: false,
                requirement: "Survive 50 turns"
            ),
            AchievementDefinition(
                id: "nine_lives",
                name: "Nine Lives",
                description: "Be imprisoned and subsequently rehabilitated",
                iconName: "arrow.uturn.backward.circle.fill",
                category: .survival,
                isSecret: false,
                requirement: "Be rehabilitated after imprisonment"
            ),
            AchievementDefinition(
                id: "phoenix_rising",
                name: "Phoenix Rising",
                description: "Return from imprisonment and reach a higher position than before",
                iconName: "flame.fill",
                category: .survival,
                isSecret: false,
                requirement: "Reach higher position after rehabilitation"
            ),
            AchievementDefinition(
                id: "revenge_is_sweet",
                name: "Revenge is Sweet",
                description: "Return from imprisonment AND eliminate those who imprisoned you",
                iconName: "bolt.circle.fill",
                category: .survival,
                isSecret: false,
                requirement: "Complete revenge after rehabilitation"
            ),
            AchievementDefinition(
                id: "dynasty_founder",
                name: "Dynasty Founder",
                description: "Successfully transition to an heir 3 times",
                iconName: "person.3.sequence.fill",
                category: .survival,
                isSecret: false,
                requirement: "Use heir succession 3 times"
            ),

            // POWER BADGES
            AchievementDefinition(
                id: "general_secretary",
                name: "General Secretary",
                description: "Reach the top position",
                iconName: "star.fill",
                category: .power,
                isSecret: false,
                requirement: "Reach position 6 (General Secretary)"
            ),
            AchievementDefinition(
                id: "kingmaker",
                name: "Kingmaker",
                description: "Your heir reaches General Secretary",
                iconName: "crown.fill",
                category: .power,
                isSecret: false,
                requirement: "Cultivated heir reaches top position"
            ),
            AchievementDefinition(
                id: "the_puppeteer",
                name: "The Puppeteer",
                description: "Have 3+ active heirs simultaneously",
                iconName: "figure.stand.line.dotted.figure.stand",
                category: .power,
                isSecret: false,
                requirement: "Maintain 3 active heirs"
            ),
            AchievementDefinition(
                id: "untouchable",
                name: "Untouchable",
                description: "Hold General Secretary for 20+ turns",
                iconName: "shield.fill",
                category: .power,
                isSecret: false,
                requirement: "20 turns as General Secretary"
            ),

            // POLITICAL BADGES
            AchievementDefinition(
                id: "the_purger",
                name: "The Purger",
                description: "Eliminate 5+ rivals through purges",
                iconName: "xmark.seal.fill",
                category: .political,
                isSecret: false,
                requirement: "Purge 5 rivals"
            ),
            AchievementDefinition(
                id: "survivor_of_purge",
                name: "Survivor of the Purge",
                description: "Be targeted for purge and survive",
                iconName: "person.crop.circle.badge.checkmark",
                category: .political,
                isSecret: false,
                requirement: "Survive being purge target"
            ),
            AchievementDefinition(
                id: "factional_victor",
                name: "Factional Victor",
                description: "Completely destroy an opposing faction",
                iconName: "flag.filled.and.flag.crossed",
                category: .political,
                isSecret: false,
                requirement: "Eliminate enemy faction"
            ),
            AchievementDefinition(
                id: "the_rehabilitator",
                name: "The Rehabilitator",
                description: "Rehabilitate a disappeared ally",
                iconName: "arrow.counterclockwise.circle.fill",
                category: .political,
                isSecret: false,
                requirement: "Bring back disappeared ally"
            ),

            // DARK BADGES
            AchievementDefinition(
                id: "blood_on_hands",
                name: "Blood on Your Hands",
                description: "Order an execution",
                iconName: "drop.fill",
                category: .dark,
                isSecret: true,
                requirement: "Order execution"
            ),
            AchievementDefinition(
                id: "the_disappeared",
                name: "The Disappeared",
                description: "Make 3+ characters \"disappear\"",
                iconName: "questionmark.circle.fill",
                category: .dark,
                isSecret: true,
                requirement: "Disappear 3 characters"
            ),
            AchievementDefinition(
                id: "betrayer",
                name: "Betrayer",
                description: "Turn on your patron",
                iconName: "arrow.triangle.branch",
                category: .dark,
                isSecret: true,
                requirement: "Betray your patron"
            ),
            AchievementDefinition(
                id: "two_faced",
                name: "Two-Faced",
                description: "Switch factions twice",
                iconName: "theatermasks.fill",
                category: .dark,
                isSecret: true,
                requirement: "Change factions twice"
            ),
            AchievementDefinition(
                id: "show_trial_master",
                name: "Show Trial Master",
                description: "Successfully conduct 3 show trials",
                iconName: "gavel.fill",
                category: .dark,
                isSecret: true,
                requirement: "Complete 3 show trials"
            ),

            // LEGACY BADGES
            AchievementDefinition(
                id: "the_mentor",
                name: "The Mentor",
                description: "Cultivate an heir who survives 20+ turns",
                iconName: "person.badge.clock.fill",
                category: .legacy,
                isSecret: false,
                requirement: "Heir survives 20 turns"
            ),
            AchievementDefinition(
                id: "political_dynasty",
                name: "Political Dynasty",
                description: "Play through 3 generations (heir successions)",
                iconName: "person.3.fill",
                category: .legacy,
                isSecret: false,
                requirement: "3 heir successions"
            ),
            AchievementDefinition(
                id: "history_remembers",
                name: "History Remembers",
                description: "Be rehabilitated posthumously (shown in newspaper)",
                iconName: "newspaper.fill",
                category: .legacy,
                isSecret: true,
                requirement: "Posthumous rehabilitation"
            ),
            AchievementDefinition(
                id: "collective_wisdom",
                name: "Collective Wisdom",
                description: "Survive a Politburo vote to remove you",
                iconName: "person.3.sequence.fill",
                category: .legacy,
                isSecret: false,
                requirement: "Survive removal vote"
            ),
            AchievementDefinition(
                id: "self_criticism_master",
                name: "Self-Criticism Master",
                description: "Use self-criticism 5 times to avoid punishment",
                iconName: "text.bubble.fill",
                category: .legacy,
                isSecret: false,
                requirement: "5 self-criticism sessions"
            )
        ]
    }

    func getAchievement(id: String) -> AchievementDefinition? {
        achievements.first { $0.id == id }
    }

    func getAchievements(category: AchievementCategory) -> [AchievementDefinition] {
        achievements.filter { $0.category == category }
    }

    var secretAchievements: [AchievementDefinition] {
        achievements.filter { $0.isSecret }
    }

    var visibleAchievements: [AchievementDefinition] {
        achievements.filter { !$0.isSecret }
    }
}

// MARK: - Achievement Service

/// Handles checking and unlocking achievements
final class AchievementService {
    static let shared = AchievementService()

    private init() {}

    /// Check all achievements against current game state
    func checkAchievements(game: Game, unlockedIds: Set<String>) -> [String] {
        var newlyUnlocked: [String] = []

        // The Survivor - 50 turns
        if !unlockedIds.contains("the_survivor") && game.turnNumber >= 50 {
            newlyUnlocked.append("the_survivor")
        }

        // General Secretary - top position
        if !unlockedIds.contains("general_secretary") && game.currentPositionIndex >= 6 {
            newlyUnlocked.append("general_secretary")
        }

        // The Puppeteer - 3+ active heirs
        if !unlockedIds.contains("the_puppeteer") {
            let activeHeirs = game.successorRelationships.filter { $0.isActive && !$0.becameRival }
            if activeHeirs.count >= 3 {
                newlyUnlocked.append("the_puppeteer")
            }
        }

        // Additional checks would go here based on game state...

        return newlyUnlocked
    }

    /// Check for specific event-triggered achievements
    func checkEventAchievement(event: String, game: Game, unlockedIds: Set<String>) -> String? {
        switch event {
        case "rehabilitated":
            if !unlockedIds.contains("nine_lives") {
                return "nine_lives"
            }
        case "ordered_execution":
            if !unlockedIds.contains("blood_on_hands") {
                return "blood_on_hands"
            }
        case "betrayed_patron":
            if !unlockedIds.contains("betrayer") {
                return "betrayer"
            }
        case "survived_purge_target":
            if !unlockedIds.contains("survivor_of_purge") {
                return "survivor_of_purge"
            }
        case "completed_show_trial":
            // Would need to track count
            break
        case "heir_succession":
            // Would need to track count for dynasty_founder
            break
        default:
            break
        }
        return nil
    }
}
