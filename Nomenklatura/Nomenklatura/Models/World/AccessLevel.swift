//
//  AccessLevel.swift
//  Nomenklatura
//
//  Access control system for position-based feature gating
//

import Foundation

// MARK: - Feature Category

/// Categories of features for access control purposes
enum FeatureCategory: String, Codable, CaseIterable {
    case general        // Basic features available to all
    case diplomatic     // Embassy, foreign relations, treaties
    case economic       // Economic data, trade flows, budget
    case intelligence   // Classified info, espionage, covert ops
    case military       // Defense data, troop movements
    case administrative // Internal Party affairs, personnel

    var displayName: String {
        switch self {
        case .general: return "General"
        case .diplomatic: return "Diplomatic"
        case .economic: return "Economic"
        case .intelligence: return "Intelligence"
        case .military: return "Military"
        case .administrative: return "Administrative"
        }
    }

    var iconName: String {
        switch self {
        case .general: return "doc.text.fill"
        case .diplomatic: return "globe"
        case .economic: return "chart.bar.fill"
        case .intelligence: return "eye.fill"
        case .military: return "shield.fill"
        case .administrative: return "building.columns.fill"
        }
    }
}

// MARK: - Access Level

/// Calculates effective access level based on position and career track
struct AccessLevel {
    let basePosition: Int
    let track: ExpandedCareerTrack
    let trackAffinities: TrackAffinityScores

    /// Initialize from a Game instance
    init(game: Game) {
        self.basePosition = game.currentPositionIndex
        self.track = game.currentCommittedTrack ?? .shared
        self.trackAffinities = game.trackAffinityScores
    }

    /// Initialize with explicit values
    init(basePosition: Int, track: ExpandedCareerTrack, trackAffinities: TrackAffinityScores = TrackAffinityScores()) {
        self.basePosition = basePosition
        self.track = track
        self.trackAffinities = trackAffinities
    }

    /// Calculate effective access level for a specific feature category
    /// Career track provides bonuses to relevant categories
    func effectiveLevel(for category: FeatureCategory) -> Int {
        var level = basePosition

        switch category {
        case .diplomatic:
            // Foreign Affairs track gets +2, Security gets +1 (intelligence overlap)
            if track == .foreignAffairs { level += 2 }
            else if track == .securityServices { level += 1 }

        case .economic:
            // Economic Planning gets +2, State Ministry gets +1 (budget overlap)
            if track == .economicPlanning { level += 2 }
            else if track == .stateMinistry { level += 1 }

        case .intelligence:
            // Security Services gets +2, Foreign Affairs gets +1 (foreign intel)
            if track == .securityServices { level += 2 }
            else if track == .foreignAffairs { level += 1 }

        case .military:
            // Military-Political gets +2, Security gets +1 (internal troops)
            if track == .militaryPolitical { level += 2 }
            else if track == .securityServices { level += 1 }

        case .administrative:
            // Party Apparatus gets +2, State Ministry gets +1
            if track == .partyApparatus { level += 2 }
            else if track == .stateMinistry { level += 1 }

        case .general:
            // No track bonuses for general features
            break
        }

        // Add small bonus from track affinity if high enough
        let relevantAffinity = affinityBonus(for: category)
        level += relevantAffinity

        // Cap at 8 (Politburo Standing Committee level)
        return min(level, 8)
    }

    /// Small bonus from track affinity (representing expertise even without commitment)
    private func affinityBonus(for category: FeatureCategory) -> Int {
        let relevantTrack: ExpandedCareerTrack?

        switch category {
        case .diplomatic: relevantTrack = .foreignAffairs
        case .economic: relevantTrack = .economicPlanning
        case .intelligence: relevantTrack = .securityServices
        case .military: relevantTrack = .militaryPolitical
        case .administrative: relevantTrack = .partyApparatus
        case .general: relevantTrack = nil
        }

        guard let track = relevantTrack else { return 0 }
        let affinity = trackAffinities.score(for: track)

        // High affinity (25+) gives +1 bonus
        if affinity >= 25 { return 1 }
        return 0
    }

    /// Check if player has access to a feature requiring a specific level
    func hasAccess(requiredLevel: Int, category: FeatureCategory = .general) -> Bool {
        effectiveLevel(for: category) >= requiredLevel
    }

    /// Whether player has Politburo-level access (sees everything)
    var isPolitburoLevel: Bool {
        basePosition >= 8
    }

    /// Description of current access level
    var accessDescription: String {
        switch basePosition {
        case 8: return "Politburo Standing Committee - Full Access"
        case 7: return "General Secretary - Full Access"
        case 6: return "Deputy General Secretary - High Clearance"
        case 5: return "Politburo Member - Senior Clearance"
        case 4: return "Candidate Politburo Member - Elevated Clearance"
        case 3: return "Central Committee Secretary - Standard Clearance"
        case 2: return "Department Head - Limited Clearance"
        case 1: return "Party Official - Basic Clearance"
        default: return "Entry Level - Minimal Clearance"
        }
    }
}

// MARK: - Access Requirement

/// Defines access requirements for a specific feature or piece of information
struct AccessRequirement {
    let minLevel: Int
    let category: FeatureCategory
    let showWhenLocked: Bool  // Whether to show locked state or hide completely
    let unlockMessage: String

    init(
        minLevel: Int,
        category: FeatureCategory = .general,
        showWhenLocked: Bool = true,
        unlockMessage: String? = nil
    ) {
        self.minLevel = minLevel
        self.category = category
        self.showWhenLocked = showWhenLocked
        self.unlockMessage = unlockMessage ?? "Requires Position Level \(minLevel)"
    }

    /// Check if access is granted for the given access level
    func isGranted(for accessLevel: AccessLevel) -> Bool {
        accessLevel.effectiveLevel(for: category) >= minLevel
    }

    /// Static factory methods for common requirements

    /// Basic info available to all
    static let publicInfo = AccessRequirement(minLevel: 0)

    /// Relationship scores (Position 4+)
    static let relationshipData = AccessRequirement(
        minLevel: 4,
        category: .diplomatic,
        unlockMessage: "Relationship data requires Candidate Politburo rank"
    )

    /// Treaty details (Position 4+)
    static let treatyDetails = AccessRequirement(
        minLevel: 4,
        category: .diplomatic,
        unlockMessage: "Treaty details require Candidate Politburo rank"
    )

    /// Intelligence reports (Position 6+)
    static let intelligenceReports = AccessRequirement(
        minLevel: 6,
        category: .intelligence,
        unlockMessage: "Intelligence reports require Deputy General Secretary rank"
    )

    /// Classified cables (Position 8 only)
    static let classifiedCables = AccessRequirement(
        minLevel: 8,
        category: .intelligence,
        showWhenLocked: false,  // Hidden until Politburo level
        unlockMessage: "Classified cables require Politburo Standing Committee membership"
    )

    /// Covert operations (Position 8 only)
    static let covertOperations = AccessRequirement(
        minLevel: 8,
        category: .intelligence,
        showWhenLocked: false,
        unlockMessage: "Covert operations require Politburo Standing Committee membership"
    )

    /// Economic breakdowns (Position 4+)
    static let economicDetails = AccessRequirement(
        minLevel: 4,
        category: .economic,
        unlockMessage: "Economic details require Candidate Politburo rank"
    )

    /// Economic trends (Position 2+)
    static let economicTrends = AccessRequirement(
        minLevel: 2,
        category: .economic,
        unlockMessage: "Economic trend data requires Department Head rank"
    )

    /// Regional economics (Position 6+)
    static let regionalEconomics = AccessRequirement(
        minLevel: 6,
        category: .economic,
        unlockMessage: "Regional economic data requires Deputy General Secretary rank"
    )

    /// Budget details (Position 6+)
    static let budgetDetails = AccessRequirement(
        minLevel: 6,
        category: .economic,
        unlockMessage: "Budget details require Deputy General Secretary rank"
    )

    /// Classified projections (Position 8 only)
    static let classifiedProjections = AccessRequirement(
        minLevel: 8,
        category: .economic,
        showWhenLocked: false,
        unlockMessage: "Classified projections require Politburo Standing Committee membership"
    )
}

// MARK: - Diplomatic Action Clearance

/// Determines what diplomatic actions player can take at their access level
struct DiplomaticActionClearance {
    let accessLevel: AccessLevel

    /// Full diplomatic actions (Position 8)
    var canTakeFullActions: Bool {
        accessLevel.effectiveLevel(for: .diplomatic) >= 8
    }

    /// Limited diplomatic actions (Position 6-7)
    var canTakeLimitedActions: Bool {
        let level = accessLevel.effectiveLevel(for: .diplomatic)
        return level >= 6 && level < 8
    }

    /// View-only diplomatic info (Position 4+)
    var canViewDiplomaticDetails: Bool {
        accessLevel.effectiveLevel(for: .diplomatic) >= 4
    }

    /// Available action types based on clearance
    var availableActionTypes: [DiplomaticActionType] {
        let level = accessLevel.effectiveLevel(for: .diplomatic)

        if level >= 8 {
            // Full access - all actions
            return DiplomaticActionType.allCases
        } else if level >= 6 {
            // Limited - non-covert actions only
            return DiplomaticActionType.allCases.filter { !$0.isCovert }
        } else {
            // No actions available
            return []
        }
    }
}
