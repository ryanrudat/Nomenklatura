//
//  Scenario.swift
//  Nomenklatura
//
//  Scenario and option models for crisis briefings
//

import Foundation

// MARK: - Scenario Category

/// Categories are used internally for variety but NOT exposed to the player
/// to maintain unpredictability
enum ScenarioCategory: String, Codable, CaseIterable, Sendable {
    case introduction     // Turn 1 only - orientation and onboarding
    case crisis           // Urgent problems demanding immediate attention
    case routine          // Normal governance decisions, lower stakes
    case opportunity      // Chances for advancement or gain
    case character        // NPC-driven events, relationship moments

    // NEW: Non-decision event categories for immersion
    case routineDay       // Mundane bureaucracy, no player choice needed
    case newspaper        // World events, NPC fates, propaganda
    case characterMoment  // Brief NPC interactions without decisions
    case tensionBuilder   // Warnings/foreshadowing before crises

    /// Weight for selection (higher = more common)
    /// Note: introduction is not weighted - it's only used on Turn 1
    /// Balanced to ensure crisis doesn't dominate - routine/opportunity/character
    /// should appear frequently to make crises feel more impactful
    var selectionWeight: Int {
        switch self {
        case .introduction: return 0      // Special case, not random
        case .crisis: return 15           // Reduced - crises should feel special, not constant
        case .routine: return 30          // Increased - the state keeps functioning
        case .opportunity: return 25      // Increased - advancement chances are engaging
        case .character: return 25        // Increased - relationships drive engagement
        // Non-decision events - important for pacing and immersion
        case .routineDay: return 25       // Mundane days are common in bureaucracy
        case .newspaper: return 0         // Newspaper uses random chance, not weight
        case .characterMoment: return 18  // Brief NPC encounters add texture
        case .tensionBuilder: return 12   // Foreshadowing builds anticipation
        }
    }

    /// Whether this category requires player to make a decision
    var requiresDecision: Bool {
        switch self {
        case .introduction, .crisis, .routine, .opportunity, .character:
            return true
        case .routineDay, .newspaper, .characterMoment, .tensionBuilder:
            return false
        }
    }

    /// Whether this is an urgent/crisis type event (shows URGENT badge)
    var isUrgent: Bool {
        switch self {
        case .crisis:
            return true
        default:
            return false
        }
    }

    /// Minimum position index required for this category
    /// Position 0 = Party Official (entry), 8 = General Secretary
    var minimumPositionIndex: Int {
        switch self {
        case .introduction:
            return 0  // Everyone sees introduction
        case .routineDay, .characterMoment:
            return 0  // Mundane events for all levels
        case .tensionBuilder:
            return 1  // Foreshadowing starts at Junior level
        case .routine, .newspaper:
            return 0  // Routine governance and news for all
        case .opportunity:
            return 1  // Advancement opportunities from Junior level
        case .character:
            return 1  // NPC interactions from Junior level
        case .crisis:
            return 2  // Real crises only for those with some responsibility
        }
    }

    /// Maximum position index for this category (nil = no max)
    /// Helps prevent high-level officials from getting trivial events
    var maximumPositionIndex: Int? {
        switch self {
        case .introduction:
            return 1  // Only for entry positions
        case .routineDay:
            return 4  // Senior officials don't do routine paperwork
        default:
            return nil  // No upper limit
        }
    }

    /// Check if this category is appropriate for a given position
    func isAppropriate(forPositionIndex index: Int) -> Bool {
        if index < minimumPositionIndex {
            return false
        }
        if let max = maximumPositionIndex, index > max {
            return false
        }
        return true
    }
}

// MARK: - Scenario Format

/// Different presentation formats for scenarios
enum ScenarioFormat: String, Codable, Sendable {
    case briefing      // Standard briefing paper with options (current default)
    case narrative     // Atmospheric text only, no options - just "Continue"
    case newspaper     // Newspaper layout with headlines and stories
    case interlude     // Brief moment between events, minimal UI
}

// MARK: - Scenario

struct Scenario: Codable, Identifiable, Sendable {
    var id: UUID
    var templateId: String
    var category: ScenarioCategory
    var format: ScenarioFormat
    var isFallback: Bool

    var briefing: String
    var presenterName: String
    var presenterTitle: String?

    var options: [ScenarioOption]

    // For narrative-only scenarios (no options)
    var narrativeConclusion: String?

    var aiProvider: String?
    var generatedAt: Date

    /// Whether this scenario requires player decision
    var requiresDecision: Bool {
        return category.requiresDecision && !options.isEmpty
    }

    /// Whether to show URGENT badge
    var isUrgent: Bool {
        return category.isUrgent
    }

    nonisolated init(
        templateId: String,
        category: ScenarioCategory = .crisis,
        format: ScenarioFormat = .briefing,
        briefing: String,
        presenterName: String,
        presenterTitle: String? = nil,
        options: [ScenarioOption] = [],
        narrativeConclusion: String? = nil,
        isFallback: Bool = false,
        aiProvider: String? = nil
    ) {
        self.id = UUID()
        self.templateId = templateId
        self.category = category
        self.format = format
        self.isFallback = isFallback
        self.briefing = briefing
        self.presenterName = presenterName
        self.presenterTitle = presenterTitle
        self.options = options
        self.narrativeConclusion = narrativeConclusion
        self.aiProvider = aiProvider
        self.generatedAt = Date()
    }
}

// MARK: - Scenario Option

struct ScenarioOption: Codable, Identifiable, Sendable {
    var id: String  // A, B, C, D
    var archetype: OptionArchetype
    var shortDescription: String
    var immediateOutcome: String
    var statEffects: [String: Int]
    var personalEffects: [String: Int]?
    var followUpHook: String?

    var isLocked: Bool
    var lockReason: String?
}

// MARK: - Option Archetype
// Note: OptionArchetype is now defined in TrackAffinity.swift with expanded track affinity support

// MARK: - Stat Effect Display

struct StatEffect: Identifiable {
    let id = UUID()
    let statName: String
    let statKey: String
    let value: Int
    let isPersonal: Bool

    var displayString: String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(value) \(statName)"
    }

    var effectType: EffectType {
        if isPersonal {
            return .personal
        } else if value >= 0 {
            return .positive
        } else {
            return .negative
        }
    }
}

enum EffectType {
    case positive
    case negative
    case personal

    var backgroundColor: String {
        switch self {
        case .positive: return "effectPositiveBg"
        case .negative: return "effectNegativeBg"
        case .personal: return "effectPersonalBg"
        }
    }

    var textColor: String {
        switch self {
        case .positive: return "effectPositiveText"
        case .negative: return "effectNegativeText"
        case .personal: return "effectPersonalText"
        }
    }
}

// MARK: - Scenario Option Helpers

extension ScenarioOption {
    /// Convert raw stat effects to display-ready StatEffect objects
    func getDisplayEffects() -> [StatEffect] {
        var effects: [StatEffect] = []

        let statNames: [String: String] = [
            "stability": "Stability",
            "popularSupport": "Popular",
            "militaryLoyalty": "Military",
            "eliteLoyalty": "Elite",
            "treasury": "Treasury",
            "industrialOutput": "Industry",
            "foodSupply": "Food",
            "internationalStanding": "Intl.",
            "standing": "Standing",
            "patronFavor": "Favor",
            "rivalThreat": "Rival",
            "network": "Network",
            "reputationCompetent": "Competent",
            "reputationLoyal": "Loyal",
            "reputationCunning": "Cunning",
            "reputationRuthless": "Ruthless"
        ]

        let personalStats = ["standing", "patronFavor", "rivalThreat", "network",
                           "reputationCompetent", "reputationLoyal", "reputationCunning", "reputationRuthless"]

        // National stat effects
        for (key, value) in statEffects {
            if let name = statNames[key] {
                effects.append(StatEffect(
                    statName: name,
                    statKey: key,
                    value: value,
                    isPersonal: personalStats.contains(key)
                ))
            }
        }

        // Personal stat effects
        if let personal = personalEffects {
            for (key, value) in personal {
                if let name = statNames[key] {
                    effects.append(StatEffect(
                        statName: name,
                        statKey: key,
                        value: value,
                        isPersonal: true
                    ))
                }
            }
        }

        return effects.sorted { $0.statName < $1.statName }
    }
}
