//
//  AmbientActivityService.swift
//  Nomenklatura
//
//  Tracks NPC ambient activities to create a "living world" feel.
//  NPCs continue to exist and act even when the player isn't directly interacting with them.
//

import Foundation
import os.log

private let ambientLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "AmbientActivity")

// MARK: - Ambient Activity Service

/// Service that tracks and generates ambient NPC activities
final class AmbientActivityService {
    static let shared = AmbientActivityService()

    private init() {}

    // MARK: - Turn Processing

    /// Generate ambient activities for all NPCs
    func processAmbientActivities(game: Game) {
        for character in game.characters where character.isActive {
            // Only process some characters each turn
            guard Double.random(in: 0...1) < GameplayConstants.AmbientActivity.baseAmbientActionChance else {
                continue
            }

            // Generate ambient activity based on character state
            if let activity = generateAmbientActivity(character: character, game: game) {
                character.addAmbientActivity(activity)
                ambientLogger.debug("\(character.name): \(activity.description)")
            }
        }

        // Prune old activities
        pruneOldActivities(game: game)
    }

    /// Generate an ambient activity for a character
    private func generateAmbientActivity(character: GameCharacter, game: Game) -> AmbientActivity? {
        // Activity influenced by goals, needs, and role
        let activityType = selectActivityType(character: character, game: game)

        guard let type = activityType else { return nil }

        return AmbientActivity(
            type: type,
            turn: game.turnNumber,
            description: generateActivityDescription(type: type, character: character, game: game),
            targetCharacterId: selectActivityTarget(type: type, character: character, game: game),
            location: selectActivityLocation(type: type, character: character),
            visibility: determineVisibility(type: type, character: character)
        )
    }

    /// Select an activity type based on character state
    private func selectActivityType(character: GameCharacter, game: Game) -> AmbientActivityType? {
        var weights: [(AmbientActivityType, Int)] = []

        // Goal-driven activities
        if let primaryGoal = character.primaryGoal {
            switch primaryGoal.goalType {
            case .seekPromotion, .becomeTrackHead, .joinPolitburo:
                weights.append((.networking, 30))
                weights.append((.meeting, 20))
                weights.append((.politicalManeuvering, 25))

            case .destroyRival:
                weights.append((.gatheringIntelligence, 25))
                weights.append((.secretMeeting, 20))
                weights.append((.politicalManeuvering, 15))

            case .buildFaction:
                weights.append((.networking, 30))
                weights.append((.meeting, 25))
                weights.append((.factionMeeting, 30))

            case .implementReform, .maintainOrthodoxy:
                weights.append((.writing, 20))
                weights.append((.meeting, 20))
                weights.append((.ideologicalStudy, 25))

            case .serveTheParty, .defendPartyOrthodoxy:
                weights.append((.working, 30))
                weights.append((.ideologicalStudy, 25))
                weights.append((.meeting, 15))

            case .avoidPurge, .clearName, .findProtector:
                weights.append((.networking, 25))
                weights.append((.secretMeeting, 20))
                weights.append((.traveling, 15))

            case .spyForForeignPower, .sabotageFromWithin:
                weights.append((.gatheringIntelligence, 30))
                weights.append((.secretMeeting, 25))
                weights.append((.traveling, 20))

            default:
                break
            }
        }

        // Need-driven activities
        let needs = character.npcNeeds
        if needs.securityCritical {
            weights.append((.networking, 20))
            weights.append((.secretMeeting, 15))
        }
        if needs.power < 40 {
            weights.append((.politicalManeuvering, 20))
            weights.append((.meeting, 15))
        }
        if needs.recognition < 40 {
            weights.append((.socializing, 20))
            weights.append((.working, 15))
        }

        // Role-based activities
        switch character.currentRole {
        case .patron, .leader:
            weights.append((.meeting, 20))
            weights.append((.issuingDirectives, 15))

        case .rival:
            weights.append((.gatheringIntelligence, 20))
            weights.append((.politicalManeuvering, 20))

        case .contact, .informant:
            weights.append((.gatheringIntelligence, 25))
            weights.append((.socializing, 20))

        case .ally:
            weights.append((.working, 20))
            weights.append((.ideologicalStudy, 15))

        default:
            // Generic activities for all
            weights.append((.working, 30))
            weights.append((.socializing, 15))
            weights.append((.traveling, 10))
        }

        // Add some randomness
        weights.append((.dining, 10))
        weights.append((.resting, 10))

        // Weight-based random selection
        let totalWeight = weights.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return .working }

        var roll = Int.random(in: 0..<totalWeight)
        for (type, weight) in weights {
            roll -= weight
            if roll < 0 {
                return type
            }
        }

        return .working
    }

    /// Generate a description for the activity
    private func generateActivityDescription(type: AmbientActivityType, character: GameCharacter, game: Game) -> String {
        switch type {
        case .working:
            return [
                "at their desk reviewing documents",
                "in a meeting with subordinates",
                "working on department reports",
                "attending to official duties",
                "preparing briefings for superiors"
            ].randomElement()!

        case .meeting:
            let others = game.characters.filter { $0.isActive && $0.id != character.id }
            if let other = others.randomElement() {
                return "in a meeting with \(other.name)"
            }
            return "in an official meeting"

        case .socializing:
            return [
                "at the ministry canteen",
                "chatting with colleagues in the corridor",
                "attending an official reception",
                "at a Party social function"
            ].randomElement()!

        case .traveling:
            return [
                "traveling to a regional inspection",
                "en route to an official function",
                "on assignment outside the capital",
                "visiting a state enterprise"
            ].randomElement()!

        case .networking:
            return [
                "cultivating contacts in other departments",
                "attending an informal gathering of officials",
                "building relationships with useful people",
                "consolidating their network of supporters"
            ].randomElement()!

        case .gatheringIntelligence:
            return [
                "discreetly gathering information",
                "listening to rumors and whispers",
                "meeting with informants",
                "piecing together useful intelligence"
            ].randomElement()!

        case .secretMeeting:
            return [
                "meeting privately with unknown parties",
                "conducting confidential discussions",
                "in a discreet rendezvous",
                "engaged in clandestine consultations"
            ].randomElement()!

        case .politicalManeuvering:
            return [
                "positioning themselves for advancement",
                "building coalitions behind the scenes",
                "working to undermine opponents",
                "engaging in political calculation"
            ].randomElement()!

        case .factionMeeting:
            if let factionId = character.factionId,
               let faction = game.factions.first(where: { $0.factionId == factionId }) {
                return "at a gathering of \(faction.name) members"
            }
            return "at a factional meeting"

        case .ideologicalStudy:
            return [
                "studying Party doctrine",
                "attending ideological training",
                "reviewing Marxist-Leninist texts",
                "participating in political education"
            ].randomElement()!

        case .writing:
            return [
                "drafting a policy proposal",
                "composing a report for the Presidium",
                "writing a position paper",
                "preparing a speech"
            ].randomElement()!

        case .dining:
            return [
                "having lunch at the ministry",
                "dining with colleagues",
                "at a working dinner",
                "eating in the executive dining room"
            ].randomElement()!

        case .resting:
            return [
                "taking a rare moment of respite",
                "at home with family",
                "recovering from official duties",
                "on approved leave"
            ].randomElement()!

        case .issuingDirectives:
            return [
                "issuing orders to subordinates",
                "directing operations in their domain",
                "supervising department activities",
                "exercising their authority"
            ].randomElement()!
        }
    }

    /// Select a target for relationship-based activities
    private func selectActivityTarget(type: AmbientActivityType, character: GameCharacter, game: Game) -> String? {
        switch type {
        case .meeting, .networking, .secretMeeting:
            let candidates = game.characters.filter {
                $0.isActive && $0.id != character.id
            }
            return candidates.randomElement()?.id.uuidString

        case .factionMeeting:
            if let factionId = character.factionId {
                let factionMembers = game.characters.filter {
                    $0.isActive && $0.id != character.id && $0.factionId == factionId
                }
                return factionMembers.randomElement()?.id.uuidString
            }
            return nil

        default:
            return nil
        }
    }

    /// Select a location for the activity
    private func selectActivityLocation(type: AmbientActivityType, character: GameCharacter) -> String? {
        switch type {
        case .working, .writing, .issuingDirectives:
            return "Ministry offices"
        case .meeting:
            return ["Ministry conference room", "Committee chambers", "Official office"].randomElement()
        case .socializing, .dining:
            return ["Ministry canteen", "Reception hall", "Official function"].randomElement()
        case .traveling:
            return "In transit"
        case .secretMeeting:
            return ["Private location", "Undisclosed venue", "Secure room"].randomElement()
        case .factionMeeting:
            return "Private gathering"
        case .ideologicalStudy:
            return ["Party school", "Study group", "Library"].randomElement()
        case .resting:
            return "Personal quarters"
        default:
            return nil
        }
    }

    /// Determine how visible the activity is to the player
    private func determineVisibility(type: AmbientActivityType, character: GameCharacter) -> AmbientActivityVisibility {
        switch type {
        case .secretMeeting, .gatheringIntelligence:
            return .hidden

        case .politicalManeuvering:
            return character.disposition >= 40 ? .hinted : .hidden

        case .working, .meeting, .socializing, .ideologicalStudy, .factionMeeting:
            return .visible

        case .networking:
            return .hinted

        default:
            return .visible
        }
    }

    /// Prune old activities to keep memory usage in check
    private func pruneOldActivities(game: Game) {
        let cutoffTurn = game.turnNumber - GameplayConstants.AmbientActivity.ambientActionRetentionTurns

        for character in game.characters {
            var activities = character.ambientActivities
            activities.removeAll { $0.turn < cutoffTurn }

            // Keep only most recent activities
            if activities.count > GameplayConstants.AmbientActivity.maxTrackedActionsPerNPC {
                activities = Array(activities.suffix(GameplayConstants.AmbientActivity.maxTrackedActionsPerNPC))
            }

            character.ambientActivities = activities
        }
    }

    // MARK: - Activity Query Methods

    /// Get recent visible activities for a character
    func getVisibleActivities(for character: GameCharacter, observerDisposition: Int, limit: Int = 3) -> [AmbientActivity] {
        let activities = character.ambientActivities.filter { activity in
            switch activity.visibility {
            case .visible:
                return true
            case .hinted:
                return observerDisposition >= 50
            case .hidden:
                return observerDisposition >= 80
            }
        }

        return Array(activities.suffix(limit))
    }

    /// Get a summary of what a character has been doing
    func getActivitySummary(for character: GameCharacter, game: Game) -> String {
        let recentActivities = character.ambientActivities.suffix(5)

        guard !recentActivities.isEmpty else {
            return "\(character.name) has been attending to their duties."
        }

        let activityTypes = Set(recentActivities.map { $0.type })

        if activityTypes.contains(.secretMeeting) || activityTypes.contains(.gatheringIntelligence) {
            return "\(character.name) has been unusually active, with several unexplained absences."
        } else if activityTypes.contains(.networking) || activityTypes.contains(.politicalManeuvering) {
            return "\(character.name) has been busy cultivating relationships and building alliances."
        } else if activityTypes.contains(.factionMeeting) {
            if let factionId = character.factionId,
               let faction = game.factions.first(where: { $0.factionId == factionId }) {
                return "\(character.name) has been actively involved with \(faction.name) activities."
            }
        }

        return "\(character.name) has been going about their usual business."
    }
}

// MARK: - Ambient Activity Types

/// Types of ambient activities NPCs can engage in
enum AmbientActivityType: String, Codable {
    case working              // Normal job duties
    case meeting              // Official meetings
    case socializing          // Casual social interaction
    case traveling            // Moving between locations
    case networking           // Building relationships
    case gatheringIntelligence // Collecting information
    case secretMeeting        // Clandestine meetings
    case politicalManeuvering // Political scheming
    case factionMeeting       // Faction-related gatherings
    case ideologicalStudy     // Party education
    case writing              // Drafting documents
    case dining               // Eating meals
    case resting              // Time off
    case issuingDirectives    // Giving orders (for senior officials)

    var displayName: String {
        switch self {
        case .working: return "Working"
        case .meeting: return "In Meeting"
        case .socializing: return "Socializing"
        case .traveling: return "Traveling"
        case .networking: return "Networking"
        case .gatheringIntelligence: return "Gathering Information"
        case .secretMeeting: return "Secret Meeting"
        case .politicalManeuvering: return "Political Maneuvering"
        case .factionMeeting: return "Faction Meeting"
        case .ideologicalStudy: return "Studying"
        case .writing: return "Writing"
        case .dining: return "Dining"
        case .resting: return "Resting"
        case .issuingDirectives: return "Directing"
        }
    }
}

/// Visibility level of an activity to the player
enum AmbientActivityVisibility: String, Codable {
    case visible   // Player can see this activity
    case hinted    // Player gets hints about this activity
    case hidden    // Activity is completely hidden
}

// MARK: - Ambient Activity Structure

/// Represents a single ambient activity
struct AmbientActivity: Codable {
    var type: AmbientActivityType
    var turn: Int
    var description: String
    var targetCharacterId: String?
    var location: String?
    var visibility: AmbientActivityVisibility

    init(
        type: AmbientActivityType,
        turn: Int,
        description: String,
        targetCharacterId: String? = nil,
        location: String? = nil,
        visibility: AmbientActivityVisibility = .visible
    ) {
        self.type = type
        self.turn = turn
        self.description = description
        self.targetCharacterId = targetCharacterId
        self.location = location
        self.visibility = visibility
    }
}

// MARK: - GameCharacter Extensions

extension GameCharacter {
    /// All tracked ambient activities
    var ambientActivities: [AmbientActivity] {
        get {
            guard let data = ambientActivitiesData else { return [] }
            return (try? JSONDecoder().decode([AmbientActivity].self, from: data)) ?? []
        }
        set {
            ambientActivitiesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Add an ambient activity
    func addAmbientActivity(_ activity: AmbientActivity) {
        var activities = ambientActivities
        activities.append(activity)

        // Keep only the most recent activities
        if activities.count > GameplayConstants.AmbientActivity.maxTrackedActionsPerNPC {
            activities = Array(activities.suffix(GameplayConstants.AmbientActivity.maxTrackedActionsPerNPC))
        }

        ambientActivities = activities
    }

    /// Most recent activity
    var mostRecentActivity: AmbientActivity? {
        return ambientActivities.last
    }

    /// Activity summary for display
    var activityStatusDescription: String {
        guard let recent = mostRecentActivity else {
            return "Attending to duties"
        }
        return recent.description.capitalized
    }
}
