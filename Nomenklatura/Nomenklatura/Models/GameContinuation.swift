//
//  GameContinuation.swift
//  Nomenklatura
//
//  Models for game continuation: death->heir succession,
//  imprisonment->rehabilitation mechanics
//

import Foundation

// MARK: - Game Continuation State

enum GameContinuationState: String, Codable {
    case active                // Normal play
    case imprisoned            // Waiting for rehabilitation
    case transitionToHeir      // Selecting heir to become
    case gameOver              // True ending - no continuation possible
}

// MARK: - Imprisonment State

/// Tracks the player's imprisonment status
struct ImprisonmentState: Codable {
    var isImprisoned: Bool
    var turnImprisoned: Int?
    var sentenceLength: Int?          // In turns
    var turnsServed: Int
    var imprisonmentReason: String?
    var imprisonedBy: String?         // Who ordered imprisonment

    // Rehabilitation factors
    var rehabilitationChance: Int     // 0-100, increases over time
    var enemiesStillInPower: Int      // Count of enemies who imprisoned you
    var alliesRemaining: Int          // Count of allies who might help

    // Grudge tracking for revenge
    var grudgeList: [GrudgeEntry]

    init() {
        self.isImprisoned = false
        self.turnsServed = 0
        self.rehabilitationChance = 0
        self.enemiesStillInPower = 0
        self.alliesRemaining = 0
        self.grudgeList = []
    }

    mutating func imprison(turn: Int, sentence: Int, reason: String, by: String) {
        isImprisoned = true
        turnImprisoned = turn
        sentenceLength = sentence
        turnsServed = 0
        imprisonmentReason = reason
        imprisonedBy = by
    }

    mutating func processTurn() {
        guard isImprisoned else { return }
        turnsServed += 1

        // Base rehabilitation chance increases over time
        rehabilitationChance = min(90, rehabilitationChance + 3)

        // Chance increases faster if sentence is almost complete
        if let sentence = sentenceLength, turnsServed >= sentence - 2 {
            rehabilitationChance = min(90, rehabilitationChance + 10)
        }

        // Enemies falling from power increases chance
        // (Would be updated by game events)
    }

    mutating func enemyFell() {
        enemiesStillInPower = max(0, enemiesStillInPower - 1)
        rehabilitationChance = min(95, rehabilitationChance + 15)
    }

    mutating func release() {
        isImprisoned = false
    }
}

/// Entry tracking who wronged the player (for revenge)
struct GrudgeEntry: Codable, Identifiable {
    var id: UUID
    var characterId: UUID
    var characterName: String
    var wrongType: String          // "imprisoned", "betrayed", "testified"
    var turnOccurred: Int
    var revengeCompleted: Bool
    var revengeTurn: Int?

    init(
        characterId: UUID,
        characterName: String,
        wrongType: String,
        turnOccurred: Int
    ) {
        self.id = UUID()
        self.characterId = characterId
        self.characterName = characterName
        self.wrongType = wrongType
        self.turnOccurred = turnOccurred
        self.revengeCompleted = false
    }

    mutating func completeRevenge(turn: Int) {
        revengeCompleted = true
        revengeTurn = turn
    }
}

// MARK: - Heir Selection

/// Data needed to display heir selection screen
struct HeirSelectionData: Codable {
    var availableHeirs: [HeirCandidate]
    var reason: DeathReason
    var deathTurn: Int
    var deathNarrative: String

    var hasViableHeir: Bool {
        !availableHeirs.isEmpty
    }
}

struct HeirCandidate: Codable, Identifiable {
    var id: UUID
    var characterId: UUID
    var name: String
    var currentTitle: String?
    var currentPosition: Int

    // From SuccessionRelationship
    var relationshipStrength: Int
    var loyalty: Int
    var competence: Int
    var ambition: Int

    // Inheritance
    var networkInheritance: Int       // How much network you keep
    var relationshipInheritance: Int  // How many relationships transfer

    /// Score for sorting (higher = better heir)
    var heirScore: Int {
        var score = 0
        score += relationshipStrength / 2
        score += loyalty / 3
        score += competence / 3
        score += currentPosition * 10
        score -= ambition / 4  // Too ambitious = risky
        return score
    }

    /// Narrative description of heir's readiness
    var readinessDescription: String {
        if relationshipStrength >= 80 && loyalty >= 70 {
            return "Devoted protege, well-prepared to continue your legacy"
        } else if relationshipStrength >= 60 {
            return "Capable successor with strong ties to your network"
        } else if relationshipStrength >= 40 {
            return "Promising but still developing heir"
        } else {
            return "Uncertain choice - relationship needs strengthening"
        }
    }
}

enum DeathReason: String, Codable {
    case naturalCauses       // Old age, illness
    case assassination       // Murdered
    case execution           // Killed by regime
    case suspicious          // "Natural" causes (likely murder)
    case accident            // "Accident"
    case suicide             // "Suicide"

    var displayText: String {
        switch self {
        case .naturalCauses: return "Natural Causes"
        case .assassination: return "Assassination"
        case .execution: return "Execution"
        case .suspicious: return "Sudden Illness"
        case .accident: return "Tragic Accident"
        case .suicide: return "Took Their Own Life"
        }
    }

    var narrativePrefix: String {
        switch self {
        case .naturalCauses:
            return "After a prolonged illness,"
        case .assassination:
            return "In a violent attack,"
        case .execution:
            return "Following conviction by the People's Court,"
        case .suspicious:
            return "After a sudden illness that took everyone by surprise,"
        case .accident:
            return "In a tragic accident that shocked the nation,"
        case .suicide:
            return "In what officials describe as a suicide,"
        }
    }

    /// Whether this death type allows for revenge motivation
    var allowsRevengeMotive: Bool {
        switch self {
        case .assassination, .execution, .suspicious, .accident:
            return true
        default:
            return false
        }
    }
}

// MARK: - Rehabilitation Event

struct RehabilitationEvent: Codable {
    var turnRehabilitated: Int
    var returningPosition: Int        // Position to return at (usually lower)
    var turnsImprisoned: Int
    var narrative: String

    // Bonuses for the returning player
    var revengeTargetsKnown: [UUID]   // IDs of characters who imprisoned you
    var sympathyBonus: Int            // Some people feel bad for you
    var grudgesAgainst: [String]      // Names for display

    /// Generate narrative for rehabilitation
    static func generateNarrative(turnsImprisoned: Int, reason: String) -> String {
        let years = turnsImprisoned / 6 + 1
        let narratives = [
            "After \(years) years, the errors in your case have been acknowledged. You return to Washington, older and wiser, with scores to settle.",
            "The regime has changed. Those who imprisoned you are themselves now under suspicion. You have been quietly rehabilitated.",
            "\"Mistakes were made.\" With these words, your suffering is dismissed - but your return to power begins.",
            "The Party, in its wisdom, has determined that the charges against you were fabricated. Your name is cleared, though the years cannot be returned."
        ]
        return narratives.randomElement() ?? narratives[0]
    }
}

// MARK: - Game Over Reasons

enum GameOverReason: String, Codable {
    case deathNoHeir           // Died with no heir
    case executed              // Killed by regime
    case factionDestroyed      // Your entire faction eliminated
    case coupFailed            // Failed coup attempt
    case overthrown            // Removed from power completely
    case exiledPermanently     // Sent away with no return
    case resigned              // Player chose to quit

    var displayText: String {
        switch self {
        case .deathNoHeir: return "Death Without Heir"
        case .executed: return "Executed"
        case .factionDestroyed: return "Faction Destroyed"
        case .coupFailed: return "Failed Coup"
        case .overthrown: return "Overthrown"
        case .exiledPermanently: return "Permanent Exile"
        case .resigned: return "Resigned"
        }
    }

    var narrative: String {
        switch self {
        case .deathNoHeir:
            return "With no heir to continue your work, your legacy fades into the footnotes of history. The apparatus moves on without you."
        case .executed:
            return "Your story ends before a firing squad. History will judge whether you were guilty or merely inconvenient."
        case .factionDestroyed:
            return "Your faction has been completely eliminated. With no allies remaining, there is no path forward."
        case .coupFailed:
            return "Your attempt to seize power has failed catastrophically. There will be no second chance."
        case .overthrown:
            return "The Politburo has voted. You are stripped of all positions and expelled from the Party. Your political life is over."
        case .exiledPermanently:
            return "You are sent far from Washington, to a place from which there is no return. The capital forgets you."
        case .resigned:
            return "You have chosen to step away from the game of power. Perhaps this is the wisest move of all."
        }
    }

    /// Whether this allows any kind of continuation
    var isTrulyFinal: Bool {
        switch self {
        case .deathNoHeir, .executed, .factionDestroyed, .coupFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Helper Extensions

extension Game {
    /// Check if player can continue through heir succession
    func canContinueWithHeir() -> Bool {
        let activeHeirs = successorRelationships.filter { $0.isActive && !$0.becameRival }
        return !activeHeirs.isEmpty
    }

    /// Get available heirs for succession
    func getAvailableHeirs() -> [HeirCandidate] {
        return successorRelationships
            .filter { $0.isActive && !$0.becameRival }
            .map { relationship in
                HeirCandidate(
                    id: relationship.id,
                    characterId: relationship.protegeId,
                    name: relationship.protegeName,
                    currentTitle: relationship.protegeTitle,
                    currentPosition: 2, // Would need to look up actual position
                    relationshipStrength: relationship.strength,
                    loyalty: relationship.protegeLoyalty,
                    competence: relationship.protegeCompetence,
                    ambition: relationship.protegeAmbition,
                    networkInheritance: calculateNetworkInheritance(strength: relationship.strength),
                    relationshipInheritance: calculateRelationshipInheritance(strength: relationship.strength)
                )
            }
            .sorted { $0.heirScore > $1.heirScore }
    }

    private func calculateNetworkInheritance(strength: Int) -> Int {
        // Stronger relationship = more network transfer
        return min(80, strength / 2 + 20)
    }

    private func calculateRelationshipInheritance(strength: Int) -> Int {
        return min(70, strength / 2 + 10)
    }
}
