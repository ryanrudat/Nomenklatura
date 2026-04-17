//
//  Achievement.swift
//  Nomenklatura
//
//  Achievement/Badge system for tracking player accomplishments.
//
//  Phase 1 redesign (2026-04-17): Removed climbing-themed achievements
//  ("Reach the top position"). Player IS the General Secretary at game
//  start. Achievements now reward TENURE, state EXCELLENCE, power
//  CONSOLIDATION, and era-defining endgame paths.
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
    case tenure         // Holding power over time
    case excellence     // Running the state well
    case consolidation  // Domination of the apparatus
    case endgame        // Era-defining victories
    case survival       // Surviving challenges
    case dark           // Morally questionable acts
    case legacy         // Long-term accomplishments

    var displayName: String {
        switch self {
        case .tenure: return "Tenure"
        case .excellence: return "State Excellence"
        case .consolidation: return "Consolidation"
        case .endgame: return "Endgame"
        case .survival: return "Survival"
        case .dark: return "Dark"
        case .legacy: return "Legacy"
        }
    }

    var iconName: String {
        switch self {
        case .tenure: return "hourglass"
        case .excellence: return "star.fill"
        case .consolidation: return "crown.fill"
        case .endgame: return "flag.checkered"
        case .survival: return "heart.fill"
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

            // MARK: TENURE — Holding Power Over Time
            AchievementDefinition(
                id: "inaugurated",
                name: "Inaugurated",
                description: "Survive your first 5 turns as General Secretary",
                iconName: "calendar.badge.checkmark",
                category: .tenure,
                isSecret: false,
                requirement: "Reach turn 5"
            ),
            AchievementDefinition(
                id: "iron_grip",
                name: "Iron Grip",
                description: "Hold the office of General Secretary for 20 turns",
                iconName: "shield.fill",
                category: .tenure,
                isSecret: false,
                requirement: "Survive 20 turns in office"
            ),
            AchievementDefinition(
                id: "consolidated_power",
                name: "Consolidated Power",
                description: "Hold the office of General Secretary for 40 turns",
                iconName: "lock.shield.fill",
                category: .tenure,
                isSecret: false,
                requirement: "Survive 40 turns in office"
            ),
            AchievementDefinition(
                id: "the_long_reign",
                name: "The Long Reign",
                description: "Hold the office of General Secretary for 80 turns",
                iconName: "hourglass.bottomhalf.filled",
                category: .tenure,
                isSecret: false,
                requirement: "Survive 80 turns in office"
            ),
            AchievementDefinition(
                id: "the_eternal_chairman",
                name: "The Eternal Chairman",
                description: "Hold the office of General Secretary for 150 turns",
                iconName: "infinity",
                category: .tenure,
                isSecret: false,
                requirement: "Survive 150 turns in office"
            ),

            // MARK: STATE EXCELLENCE — Running the State Well
            AchievementDefinition(
                id: "champion_of_people",
                name: "Champion of the People",
                description: "Maintain Popular Support ≥ 80 for 20 consecutive turns",
                iconName: "person.3.sequence.fill",
                category: .excellence,
                isSecret: false,
                requirement: "Sustain high popular support"
            ),
            AchievementDefinition(
                id: "industrial_vanguard",
                name: "Industrial Vanguard",
                description: "Hit a major Five-Year Plan industrial target",
                iconName: "gearshape.2.fill",
                category: .excellence,
                isSecret: false,
                requirement: "Achieve a heavy industry plan target"
            ),
            AchievementDefinition(
                id: "banner_of_victory",
                name: "Banner of Victory",
                description: "Win a major show trial or military operation",
                iconName: "flag.fill",
                category: .excellence,
                isSecret: false,
                requirement: "Decisive show trial or military victory"
            ),
            AchievementDefinition(
                id: "architect_of_law",
                name: "Architect of Law",
                description: "Pass 5 major laws through the Standing Committee",
                iconName: "doc.text.fill",
                category: .excellence,
                isSecret: false,
                requirement: "Pass 5 laws"
            ),
            AchievementDefinition(
                id: "stakhanovite_standard",
                name: "Stakhanovite Standard",
                description: "Achieve a Stakhanovite (6/6) Five-Year Plan completion",
                iconName: "hammer.fill",
                category: .excellence,
                isSecret: false,
                requirement: "Complete Five-Year Plan with Stakhanovite rating"
            ),
            AchievementDefinition(
                id: "supreme_commander",
                name: "Supreme Commander",
                description: "Maintain Military Loyalty ≥ 90 for 30 consecutive turns",
                iconName: "star.circle.fill",
                category: .excellence,
                isSecret: false,
                requirement: "Sustain high military loyalty"
            ),

            // MARK: CONSOLIDATION — Domination of the Apparatus
            AchievementDefinition(
                id: "cult_of_personality",
                name: "Cult of Personality",
                description: "Reach maximum propaganda intensity",
                iconName: "megaphone.fill",
                category: .consolidation,
                isSecret: false,
                requirement: "Max propaganda level"
            ),
            AchievementDefinition(
                id: "architect_of_state",
                name: "Architect of the State",
                description: "Pass 10 major reforms",
                iconName: "building.columns.fill",
                category: .consolidation,
                isSecret: false,
                requirement: "Pass 10 reforms"
            ),
            AchievementDefinition(
                id: "master_of_politburo",
                name: "Master of the Politburo",
                description: "Personally appoint 3 or more Standing Committee members",
                iconName: "person.3.fill",
                category: .consolidation,
                isSecret: false,
                requirement: "Direct 3+ SC appointments"
            ),
            AchievementDefinition(
                id: "father_of_nation",
                name: "Father of the Nation",
                description: "Maintain Stability ≥ 90 for 50 consecutive turns",
                iconName: "house.fill",
                category: .consolidation,
                isSecret: false,
                requirement: "Sustain high stability"
            ),
            AchievementDefinition(
                id: "defender_of_revolution",
                name: "Defender of the Revolution",
                description: "Survive 3 coup or purge attempts against you",
                iconName: "shield.lefthalf.filled",
                category: .consolidation,
                isSecret: false,
                requirement: "Survive 3 coup attempts"
            ),
            AchievementDefinition(
                id: "iron_hand",
                name: "Iron Hand",
                description: "Order 10 successful show trials",
                iconName: "hand.raised.fill",
                category: .consolidation,
                isSecret: false,
                requirement: "10 successful show trials"
            ),

            // MARK: ENDGAME — Era-Defining Victories
            AchievementDefinition(
                id: "the_hardliner",
                name: "The Hardliner",
                description: "Win the game with hardline ideology dominant",
                iconName: "bolt.fill",
                category: .endgame,
                isSecret: false,
                requirement: "Victory with hardline path"
            ),
            AchievementDefinition(
                id: "the_reformer",
                name: "The Reformer",
                description: "Win the game with reformist ideology dominant",
                iconName: "leaf.fill",
                category: .endgame,
                isSecret: false,
                requirement: "Victory with reformist path"
            ),

            // MARK: SURVIVAL — Surviving Challenges
            AchievementDefinition(
                id: "the_survivor",
                name: "The Survivor",
                description: "Complete 100 turns without being purged",
                iconName: "shield.checkered",
                category: .survival,
                isSecret: false,
                requirement: "Survive 100 turns"
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
                description: "Survive a purge, return to the Politburo, and restore your authority to its former peak",
                iconName: "flame.fill",
                category: .survival,
                isSecret: false,
                requirement: "Restore power after rehabilitation"
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

            // MARK: SURVIVAL (carried from old Power category — these still fit Chairman framing)
            AchievementDefinition(
                id: "kingmaker",
                name: "Kingmaker",
                description: "Your designated heir successfully takes the chairmanship",
                iconName: "crown.fill",
                category: .legacy,
                isSecret: false,
                requirement: "Cultivated heir takes office"
            ),
            AchievementDefinition(
                id: "the_puppeteer",
                name: "The Puppeteer",
                description: "Have 3 or more active heirs simultaneously",
                iconName: "figure.stand.line.dotted.figure.stand",
                category: .consolidation,
                isSecret: false,
                requirement: "Maintain 3 active heirs"
            ),

            // MARK: POLITICAL (carried — already Chairman-appropriate)
            AchievementDefinition(
                id: "the_purger",
                name: "The Purger",
                description: "Eliminate 5 or more rivals through purges",
                iconName: "xmark.seal.fill",
                category: .consolidation,
                isSecret: false,
                requirement: "Purge 5 rivals"
            ),
            AchievementDefinition(
                id: "survivor_of_purge",
                name: "Survivor of the Purge",
                description: "Be targeted for purge and survive",
                iconName: "person.crop.circle.badge.checkmark",
                category: .survival,
                isSecret: false,
                requirement: "Survive being a purge target"
            ),
            AchievementDefinition(
                id: "factional_victor",
                name: "Factional Victor",
                description: "Completely destroy an opposing faction",
                iconName: "flag.filled.and.flag.crossed",
                category: .consolidation,
                isSecret: false,
                requirement: "Eliminate enemy faction"
            ),
            AchievementDefinition(
                id: "the_rehabilitator",
                name: "The Rehabilitator",
                description: "Rehabilitate a disappeared ally",
                iconName: "arrow.counterclockwise.circle.fill",
                category: .legacy,
                isSecret: false,
                requirement: "Bring back a disappeared ally"
            ),

            // MARK: DARK / SECRET (carried — secret unlocks)
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
                description: "Make 3 or more characters \"disappear\"",
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

            // MARK: LEGACY (carried — long-term)
            AchievementDefinition(
                id: "the_mentor",
                name: "The Mentor",
                description: "Cultivate an heir who survives 20 or more turns",
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
                requirement: "Survive a removal vote"
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

/// Handles checking and unlocking achievements.
///
/// Many achievements (Cult of Personality, Master of the Politburo, etc.) are
/// gated by Phase 3-4 mechanics that don't yet exist in the codebase. Their
/// definitions ship now so the UI can display them as "locked"; the trigger
/// hooks land alongside the relevant mechanic.
final class AchievementService {
    static let shared = AchievementService()

    private init() {}

    /// Check all achievements against current game state
    func checkAchievements(game: Game, unlockedIds: Set<String>) -> [String] {
        var newlyUnlocked: [String] = []

        // TENURE — turn-count milestones
        let tenureMilestones: [(id: String, turns: Int)] = [
            ("inaugurated", 5),
            ("iron_grip", 20),
            ("consolidated_power", 40),
            ("the_long_reign", 80),
            ("the_eternal_chairman", 150)
        ]
        for milestone in tenureMilestones where !unlockedIds.contains(milestone.id) && game.turnNumber >= milestone.turns {
            newlyUnlocked.append(milestone.id)
        }

        // SURVIVAL — long-haul
        if !unlockedIds.contains("the_survivor") && game.turnNumber >= 100 {
            newlyUnlocked.append("the_survivor")
        }

        // The Puppeteer - 3+ active heirs
        if !unlockedIds.contains("the_puppeteer") {
            let activeHeirs = game.successorRelationships.filter { $0.isActive && !$0.becameRival }
            if activeHeirs.count >= 3 {
                newlyUnlocked.append("the_puppeteer")
            }
        }

        // Additional state-based checks (Champion of the People, Father of the Nation,
        // Supreme Commander) require sustained-stat tracking — those will be added when
        // the stat-history infrastructure lands in Phase 2/3.

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
            // Tracked elsewhere; show_trial_master fires at count 3, iron_hand at 10
            break
        case "heir_succession":
            // Tracked elsewhere for dynasty_founder / political_dynasty
            break
        case "stakhanovite_plan":
            if !unlockedIds.contains("stakhanovite_standard") {
                return "stakhanovite_standard"
            }
        default:
            break
        }
        return nil
    }
}
