//
//  Badge.swift
//  Nomenklatura
//
//  Badge/Achievement system - positions and accomplishments are badges, not victories
//

import Foundation

// MARK: - Badge Tier

enum BadgeTier: String, Codable, CaseIterable, Comparable, Sendable {
    case entry       // Easy - junior appointments
    case standard    // Moderate - department heads, regional positions
    case senior      // Hard - first deputy positions
    case elite       // Very hard - General Secretary, track apex positions
    case legendary   // Extraordinary - multi-track mastery, dynasty achievements

    var displayName: String {
        switch self {
        case .entry: return "Entry"
        case .standard: return "Standard"
        case .senior: return "Senior"
        case .elite: return "Elite"
        case .legendary: return "Legendary"
        }
    }

    var description: String {
        switch self {
        case .entry:
            return "First steps on the ladder of power"
        case .standard:
            return "A position of real responsibility"
        case .senior:
            return "The inner circles of power"
        case .elite:
            return "The heights of Socialist governance"
        case .legendary:
            return "Extraordinary achievements across a lifetime"
        }
    }

    var colorHex: String {
        switch self {
        case .entry: return "808080"      // Gray
        case .standard: return "228B22"   // Forest Green
        case .senior: return "4169E1"     // Royal Blue
        case .elite: return "FFD700"      // Gold
        case .legendary: return "9400D3"  // Dark Violet
        }
    }

    var iconName: String {
        switch self {
        case .entry: return "star"
        case .standard: return "star.fill"
        case .senior: return "star.circle"
        case .elite: return "star.circle.fill"
        case .legendary: return "sparkles"
        }
    }

    nonisolated static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool {
        let order: [BadgeTier] = [.entry, .standard, .senior, .elite, .legendary]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Badge Category

enum BadgeCategory: String, Codable, CaseIterable, Sendable {
    case position        // Earned by reaching a position
    case multiTrack      // Earned by mastering multiple tracks
    case regional        // Earned through regional service
    case dynasty         // Earned through heir/succession achievements
    case mastery         // Earned through comprehensive stat achievements
    case special         // Earned through unique scenario outcomes

    var displayName: String {
        switch self {
        case .position: return "Position"
        case .multiTrack: return "Multi-Track"
        case .regional: return "Regional"
        case .dynasty: return "Dynasty"
        case .mastery: return "Mastery"
        case .special: return "Special"
        }
    }
}

// MARK: - Badge Definition

struct BadgeDefinition: Codable, Identifiable, Sendable {
    var id: String                       // Unique identifier (e.g., "sword_and_shield")
    var name: String                     // Display name (e.g., "Sword and Shield")
    var description: String              // How to earn this badge
    var tier: BadgeTier
    var category: BadgeCategory
    var iconName: String
    var requirements: BadgeRequirements?

    // For position badges
    var associatedPositionId: String?    // Position that grants this badge
    var associatedTrack: String?         // Track this badge is associated with
}

struct BadgeRequirements: Codable, Sendable {
    // Position requirements
    var positionIndex: Int?
    var positionTrack: String?

    // Multi-track requirements
    var tracksRequired: Int?             // Number of track apex positions needed
    var specificTracks: [String]?        // Specific tracks required

    // Regional requirements
    var regionsServed: Int?
    var regionTypesRequired: [String]?

    // Dynasty requirements
    var successionsRequired: Int?
    var heirsDesignated: Int?
    var familyInPower: Int?              // Family members in high positions

    // Stat requirements
    var statThresholds: [String: Int]?   // e.g., ["stability": 70, "popularSupport": 70]
    var statDuration: Int?               // Turns stat must be maintained

    // Action requirements
    var actionsCompleted: [String]?
    var actionCount: Int?

    // Special flags
    var requiredFlags: [String]?
    var turnsSurvived: Int?
    var assassinationsSurvived: Int?
}

// MARK: - Earned Badge

struct EarnedBadge: Codable, Identifiable, Sendable {
    var id: String = UUID().uuidString
    var badgeId: String                  // References BadgeDefinition.id
    var turnEarned: Int
    var positionWhenEarned: String?
    var circumstance: String?            // Brief narrative of how it was earned

    // For tracking progress toward repeatable achievements
    var count: Int = 1                   // Times earned (for some badges)
}

// MARK: - Badge Registry

struct BadgeRegistry {
    /// All defined badges in the game
    static let allBadges: [BadgeDefinition] = [
        // MARK: - Elite Position Badges

        BadgeDefinition(
            id: "general_secretary",
            name: "General Secretary",
            description: "Rise to become Supreme Leader of the Party",
            tier: .elite,
            category: .position,
            iconName: "crown.fill",
            requirements: BadgeRequirements(positionIndex: 8),
            associatedPositionId: "shared_8",
            associatedTrack: "shared"
        ),

        BadgeDefinition(
            id: "sword_and_shield",
            name: "Sword and Shield",
            description: "Become Director of State Protection",
            tier: .elite,
            category: .position,
            iconName: "shield.fill",
            requirements: BadgeRequirements(positionIndex: 6, positionTrack: "securityServices"),
            associatedPositionId: "securityServices_6",
            associatedTrack: "securityServices"
        ),

        BadgeDefinition(
            id: "voice_of_nation",
            name: "Voice of the Nation",
            description: "Become Foreign Minister",
            tier: .elite,
            category: .position,
            iconName: "globe",
            requirements: BadgeRequirements(positionIndex: 6, positionTrack: "foreignAffairs"),
            associatedPositionId: "foreignAffairs_6",
            associatedTrack: "foreignAffairs"
        ),

        BadgeDefinition(
            id: "architect_socialism",
            name: "Architect of Socialism",
            description: "Become Chairman of Gosplan",
            tier: .elite,
            category: .position,
            iconName: "chart.bar.fill",
            requirements: BadgeRequirements(positionIndex: 6, positionTrack: "economicPlanning"),
            associatedPositionId: "economicPlanning_6",
            associatedTrack: "economicPlanning"
        ),

        BadgeDefinition(
            id: "guardian_army",
            name: "Guardian of the Army",
            description: "Become Chief of the Main Political Administration",
            tier: .elite,
            category: .position,
            iconName: "star.circle.fill",
            requirements: BadgeRequirements(positionIndex: 6, positionTrack: "militaryPolitical"),
            associatedPositionId: "militaryPolitical_6",
            associatedTrack: "militaryPolitical"
        ),

        BadgeDefinition(
            id: "party_conscience",
            name: "Party's Conscience",
            description: "Become CC Secretary",
            tier: .elite,
            category: .position,
            iconName: "building.columns.fill",
            requirements: BadgeRequirements(positionIndex: 6, positionTrack: "partyApparatus"),
            associatedPositionId: "partyApparatus_6",
            associatedTrack: "partyApparatus"
        ),

        BadgeDefinition(
            id: "master_state",
            name: "Master of the State",
            description: "Become Deputy Chairman of the Council of Ministers",
            tier: .elite,
            category: .position,
            iconName: "doc.text.fill",
            requirements: BadgeRequirements(positionIndex: 6, positionTrack: "stateMinistry"),
            associatedPositionId: "stateMinistry_6",
            associatedTrack: "stateMinistry"
        ),

        // MARK: - Legendary Multi-Track Badges

        BadgeDefinition(
            id: "renaissance_apparatchik",
            name: "Renaissance Apparatchik",
            description: "Hold apex positions in 2+ different tracks",
            tier: .legendary,
            category: .multiTrack,
            iconName: "person.2.circle.fill",
            requirements: BadgeRequirements(tracksRequired: 2)
        ),

        BadgeDefinition(
            id: "universal_comrade",
            name: "Universal Comrade",
            description: "Hold apex positions in 3+ different tracks",
            tier: .legendary,
            category: .multiTrack,
            iconName: "person.3.fill",
            requirements: BadgeRequirements(tracksRequired: 3)
        ),

        BadgeDefinition(
            id: "master_all_organs",
            name: "Master of All Organs",
            description: "Hold apex positions in all 6 tracks (across dynasty)",
            tier: .legendary,
            category: .multiTrack,
            iconName: "sparkles",
            requirements: BadgeRequirements(tracksRequired: 6)
        ),

        // MARK: - Legendary Regional Badges

        BadgeDefinition(
            id: "provincial_champion",
            name: "Provincial Champion",
            description: "Serve in 3+ different regional positions",
            tier: .legendary,
            category: .regional,
            iconName: "map",
            requirements: BadgeRequirements(regionsServed: 3)
        ),

        BadgeDefinition(
            id: "lord_provinces",
            name: "Lord of the Provinces",
            description: "Serve in all regional position types",
            tier: .legendary,
            category: .regional,
            iconName: "map.fill",
            requirements: BadgeRequirements(regionTypesRequired: ["gorkom", "obkom", "republic"])
        ),

        BadgeDefinition(
            id: "architect_periphery",
            name: "Architect of the Periphery",
            description: "Successfully develop 5+ regions",
            tier: .legendary,
            category: .regional,
            iconName: "building.2.fill",
            requirements: BadgeRequirements(regionsServed: 5, requiredFlags: ["region_developed_5"])
        ),

        // MARK: - Legendary Dynasty Badges

        BadgeDefinition(
            id: "dynasty_founder",
            name: "Dynasty Founder",
            description: "Your heir successfully takes power after your death",
            tier: .legendary,
            category: .dynasty,
            iconName: "person.line.dotted.person.fill",
            requirements: BadgeRequirements(successionsRequired: 1)
        ),

        BadgeDefinition(
            id: "eternal_line",
            name: "Eternal Line",
            description: "Dynasty survives 3+ successions",
            tier: .legendary,
            category: .dynasty,
            iconName: "figure.2.and.child.holdinghands",
            requirements: BadgeRequirements(successionsRequired: 3)
        ),

        BadgeDefinition(
            id: "house_power",
            name: "House of Power",
            description: "Multiple family members hold high positions simultaneously",
            tier: .legendary,
            category: .dynasty,
            iconName: "house.fill",
            requirements: BadgeRequirements(familyInPower: 3)
        ),

        // MARK: - Legendary Mastery Badges

        BadgeDefinition(
            id: "iron_grip",
            name: "Iron Grip",
            description: "Maintain General Secretary for 25+ turns",
            tier: .legendary,
            category: .mastery,
            iconName: "hand.raised.fill",
            requirements: BadgeRequirements(positionIndex: 8, statDuration: 25)
        ),

        BadgeDefinition(
            id: "golden_age",
            name: "Golden Age",
            description: "All major stats at 70+ for 10+ turns",
            tier: .legendary,
            category: .mastery,
            iconName: "sun.max.fill",
            requirements: BadgeRequirements(
                statThresholds: [
                    "stability": 70,
                    "popularSupport": 70,
                    "militaryLoyalty": 70,
                    "eliteLoyalty": 70,
                    "treasury": 70,
                    "industrialOutput": 70,
                    "foodSupply": 70,
                    "internationalStanding": 70
                ],
                statDuration: 10
            )
        ),

        BadgeDefinition(
            id: "the_survivor",
            name: "The Survivor",
            description: "Dynasty survives 100+ turns",
            tier: .legendary,
            category: .mastery,
            iconName: "clock.badge.checkmark.fill",
            requirements: BadgeRequirements(turnsSurvived: 100)
        ),

        BadgeDefinition(
            id: "untouchable",
            name: "Untouchable",
            description: "Survive 5+ assassination attempts",
            tier: .legendary,
            category: .mastery,
            iconName: "target",
            requirements: BadgeRequirements(assassinationsSurvived: 5)
        ),

        BadgeDefinition(
            id: "puppetmaster",
            name: "The Puppetmaster",
            description: "Control 10+ characters with disposition 80+",
            tier: .legendary,
            category: .mastery,
            iconName: "theatermasks.fill",
            requirements: BadgeRequirements(requiredFlags: ["puppetmaster_10"])
        ),

        // MARK: - Standard Badges

        BadgeDefinition(
            id: "spymaster",
            name: "Spymaster",
            description: "Complete 10 intelligence operations",
            tier: .standard,
            category: .special,
            iconName: "eye.fill",
            requirements: BadgeRequirements(actionsCompleted: ["intel_operation"], actionCount: 10)
        ),

        BadgeDefinition(
            id: "diplomat",
            name: "Diplomat",
            description: "Sign treaties with 3+ nations",
            tier: .standard,
            category: .special,
            iconName: "doc.on.doc.fill",
            requirements: BadgeRequirements(requiredFlags: ["treaties_signed_3"])
        ),

        BadgeDefinition(
            id: "reformer",
            name: "The Reformer",
            description: "Successfully implement major reform policies",
            tier: .standard,
            category: .special,
            iconName: "gearshape.2.fill",
            requirements: BadgeRequirements(requiredFlags: ["major_reform_complete"])
        ),

        BadgeDefinition(
            id: "industrial_titan",
            name: "Industrial Titan",
            description: "Exceed all Five-Year Plan targets",
            tier: .standard,
            category: .special,
            iconName: "hammer.fill",
            requirements: BadgeRequirements(requiredFlags: ["plan_exceeded"])
        ),

        BadgeDefinition(
            id: "peoples_champion",
            name: "People's Champion",
            description: "Maintain popular support 80+ for 20 turns",
            tier: .standard,
            category: .mastery,
            iconName: "person.3.sequence.fill",
            requirements: BadgeRequirements(
                statThresholds: ["popularSupport": 80],
                statDuration: 20
            )
        ),

        // MARK: - Entry Badges

        BadgeDefinition(
            id: "first_promotion",
            name: "First Rung",
            description: "Receive your first promotion",
            tier: .entry,
            category: .position,
            iconName: "arrow.up.circle",
            requirements: BadgeRequirements(positionIndex: 1)
        ),

        BadgeDefinition(
            id: "network_builder",
            name: "Network Builder",
            description: "Reach Network 30",
            tier: .entry,
            category: .mastery,
            iconName: "link.circle.fill",
            requirements: BadgeRequirements(statThresholds: ["network": 30])
        ),

        BadgeDefinition(
            id: "patron_trusted",
            name: "Patron's Trust",
            description: "Reach Patron Favor 75",
            tier: .entry,
            category: .mastery,
            iconName: "person.crop.circle.badge.checkmark",
            requirements: BadgeRequirements(statThresholds: ["patronFavor": 75])
        )
    ]

    /// Get badge by ID
    static func badge(withId id: String) -> BadgeDefinition? {
        allBadges.first { $0.id == id }
    }

    /// Get all badges for a tier
    static func badges(forTier tier: BadgeTier) -> [BadgeDefinition] {
        allBadges.filter { $0.tier == tier }
    }

    /// Get all badges for a category
    static func badges(forCategory category: BadgeCategory) -> [BadgeDefinition] {
        allBadges.filter { $0.category == category }
    }

    /// Get badge for a position
    static func badge(forPositionId positionId: String) -> BadgeDefinition? {
        allBadges.first { $0.associatedPositionId == positionId }
    }
}

// MARK: - Badge Checker

class BadgeChecker {

    /// Check which badges the player has newly earned
    static func checkNewBadges(game: Game, earnedBadges: [EarnedBadge]) -> [BadgeDefinition] {
        let earnedIds = Set(earnedBadges.map { $0.badgeId })
        var newBadges: [BadgeDefinition] = []

        for badge in BadgeRegistry.allBadges {
            // Skip already earned badges (unless they're repeatable)
            if earnedIds.contains(badge.id) { continue }

            if checkBadgeEarned(badge: badge, game: game) {
                newBadges.append(badge)
            }
        }

        return newBadges
    }

    /// Check if a specific badge has been earned
    static func checkBadgeEarned(badge: BadgeDefinition, game: Game) -> Bool {
        guard let requirements = badge.requirements else {
            return false
        }

        // Check position requirements
        if let posIndex = requirements.positionIndex {
            if game.currentPositionIndex < posIndex {
                return false
            }
        }

        // Check stat thresholds
        if let thresholds = requirements.statThresholds {
            for (stat, threshold) in thresholds {
                let value = getStatValue(stat, game: game)
                if value < threshold {
                    return false
                }
            }
        }

        // Check required flags
        if let flags = requirements.requiredFlags {
            for flag in flags {
                if !game.flags.contains(flag) {
                    return false
                }
            }
        }

        // Check turns survived
        if let turns = requirements.turnsSurvived {
            if game.turnNumber < turns {
                return false
            }
        }

        // Check assassination survival
        if let count = requirements.assassinationsSurvived {
            let survived = game.flags.filter { $0.hasPrefix("survived_assassination_") }.count
            if survived < count {
                return false
            }
        }

        // Check successions
        if let successions = requirements.successionsRequired {
            let count = game.flags.filter { $0.hasPrefix("succession_") }.count
            if count < successions {
                return false
            }
        }

        return true
    }

    private static func getStatValue(_ stat: String, game: Game) -> Int {
        switch stat {
        case "stability": return game.stability
        case "popularSupport": return game.popularSupport
        case "militaryLoyalty": return game.militaryLoyalty
        case "eliteLoyalty": return game.eliteLoyalty
        case "treasury": return game.treasury
        case "industrialOutput": return game.industrialOutput
        case "foodSupply": return game.foodSupply
        case "internationalStanding": return game.internationalStanding
        case "standing": return game.standing
        case "network": return game.network
        case "patronFavor": return game.patronFavor
        default: return 0
        }
    }
}
