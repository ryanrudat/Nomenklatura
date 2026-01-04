//
//  DynastyLegacy.swift
//  Nomenklatura
//
//  Tracks the multi-generational legacy of the player's dynasty.
//  In Communist systems, dynasty succession is officially forbidden but practically common:
//  - No formal inheritance, but "red prince" children of officials get advantages
//  - Revolutionary lineage matters - family backgrounds are scrutinized
//  - Tainted blood follows families - children of purged officials are marked
//  - Posthumous rehabilitation can restore fallen families
//

import Foundation
import SwiftData

// MARK: - Cause of Succession

/// How the previous generation's reign ended
enum CauseOfSuccession: String, Codable, CaseIterable {
    case naturalDeath          // "Passed after illness"
    case executedEnemy         // "Convicted of crimes against the state"
    case executedMartyr        // Later rehabilitated as hero
    case purgedDisgraced       // Removed, family tainted
    case assassinated          // "Accident" or enemy action
    case retired               // Rare peaceful exit
    case coupVictim            // Regime change
    case imprisoned            // Sent to labor camp

    var displayName: String {
        switch self {
        case .naturalDeath: return "Natural Causes"
        case .executedEnemy: return "Executed as Enemy"
        case .executedMartyr: return "Executed (Later Rehabilitated)"
        case .purgedDisgraced: return "Purged and Disgraced"
        case .assassinated: return "Assassinated"
        case .retired: return "Retired"
        case .coupVictim: return "Regime Change Victim"
        case .imprisoned: return "Imprisoned"
        }
    }

    var officialEuphemism: String {
        switch self {
        case .naturalDeath: return "passed after prolonged illness"
        case .executedEnemy: return "received appropriate punishment for crimes against the people"
        case .executedMartyr: return "fell victim to false accusations, later vindicated"
        case .purgedDisgraced: return "was removed for ideological deviations"
        case .assassinated: return "died in a tragic accident"
        case .retired: return "stepped down for health reasons"
        case .coupVictim: return "was swept aside by historical forces"
        case .imprisoned: return "is undergoing reform through labor"
        }
    }

    /// How this end affects the next generation
    var inheritancePenalty: Double {
        switch self {
        case .naturalDeath: return 1.0         // Full inheritance
        case .retired: return 0.9              // Graceful exit
        case .executedMartyr: return 1.2       // Bonus if rehabilitated
        case .purgedDisgraced: return 0.4      // Severe penalty
        case .executedEnemy: return 0.2        // Nearly destroyed
        case .assassinated: return 0.7         // Uncertain circumstances
        case .coupVictim: return 0.5           // Regime change hurt
        case .imprisoned: return 0.3           // Family under suspicion
        }
    }

    /// Position modifier for heir
    var positionModifier: Int {
        switch self {
        case .naturalDeath, .retired: return 0
        case .executedMartyr: return 1         // Restoration bonus
        case .assassinated: return -1
        case .coupVictim, .purgedDisgraced: return -2
        case .executedEnemy, .imprisoned: return -3
        }
    }
}

// MARK: - Dynasty Reputation

/// The family's overall standing in the Party
enum DynastyReputation: String, Codable, CaseIterable {
    case revered         // Revolutionary heroes
    case respected       // Reliable servants of the Party
    case neutral         // Average standing
    case questionable    // Under some suspicion
    case tainted         // Marked by fallen ancestors
    case rehabilitated   // Restored after falling

    var displayName: String {
        switch self {
        case .revered: return "Revered Lineage"
        case .respected: return "Respected Family"
        case .neutral: return "Ordinary Standing"
        case .questionable: return "Questionable Background"
        case .tainted: return "Tainted Bloodline"
        case .rehabilitated: return "Rehabilitated Family"
        }
    }

    var description: String {
        switch self {
        case .revered:
            return "Your family's revolutionary credentials are beyond reproach."
        case .respected:
            return "Your family has served the Party faithfully across generations."
        case .neutral:
            return "Your family background neither helps nor hinders you."
        case .questionable:
            return "Questions about your family's history occasionally arise."
        case .tainted:
            return "The sins of your ancestors cast a long shadow over your career."
        case .rehabilitated:
            return "Your family has been officially restored to good standing."
        }
    }

    var startingStandingModifier: Int {
        switch self {
        case .revered: return 20
        case .respected: return 10
        case .neutral: return 0
        case .questionable: return -10
        case .tainted: return -20
        case .rehabilitated: return 5
        }
    }
}

// MARK: - Major Decision Record

/// A significant decision made during a generation's reign
struct MajorDecision: Codable, Identifiable {
    var id: UUID = UUID()
    var turnMade: Int
    var title: String
    var description: String
    var outcome: String                    // What happened
    var historicalJudgment: String?        // How history views it
    var affectedLawId: String?
    var affectedCharacterName: String?
}

// MARK: - Generation Record

/// Record of one generation's time in power
struct GenerationRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var characterName: String
    var startTurn: Int
    var endTurn: Int?
    var causeOfEnd: CauseOfSuccession?

    // Career summary
    var highestPositionTitle: String
    var highestPositionIndex: Int
    var majorDecisions: [MajorDecision]

    // Legacy
    var epitaph: String?                   // Brief summary
    var officialNarrative: String?         // What the Party says
    var actualLegacy: String?              // What really happened

    // Stats at end
    var finalStanding: Int?
    var finalNetwork: Int?
    var turnsInPower: Int {
        guard let end = endTurn else { return 0 }
        return end - startTurn
    }

    // Family at end
    var heirName: String?
    var heirRelationship: String?

    /// Generate an epitaph based on career
    mutating func generateEpitaph() {
        let years = turnsInPower / 6 + 1

        if let cause = causeOfEnd {
            switch cause {
            case .naturalDeath:
                epitaph = "Served the Party for \(years) years before passing peacefully."
            case .retired:
                epitaph = "Stepped down after \(years) years, a rare peaceful exit."
            case .executedEnemy:
                epitaph = "Served \(years) years before conviction for crimes against the state."
            case .executedMartyr:
                epitaph = "Executed after \(years) years, later rehabilitated as a martyr."
            case .purgedDisgraced:
                epitaph = "Rose high before falling—\(years) years of service ended in disgrace."
            case .assassinated:
                epitaph = "Struck down after \(years) years. The truth remains unclear."
            case .coupVictim:
                epitaph = "Swept aside after \(years) years when the political winds changed."
            case .imprisoned:
                epitaph = "After \(years) years, sent for reform through labor."
            }
        } else {
            epitaph = "Served faithfully for \(years) years."
        }
    }

    /// Generate the official Party narrative
    mutating func generateOfficialNarrative() {
        if let cause = causeOfEnd {
            officialNarrative = "Comrade \(characterName) \(cause.officialEuphemism). The Party continues forward."
        } else {
            officialNarrative = "Comrade \(characterName) continues to serve the revolution."
        }
    }
}

// MARK: - Dynasty Legacy Model

@Model
final class DynastyLegacy {
    @Attribute(.unique) var id: UUID
    var dynastyId: UUID
    var dynastyName: String                // Family name
    var dynastyMotto: String?              // Optional family motto

    // Generation tracking
    var generationsData: Data?             // Encoded [GenerationRecord]
    var currentGeneration: Int             // 1 = first, 2 = second, etc.

    // Aggregate stats
    var totalTurnsPlayed: Int
    var totalPositionsHeld: Int

    // Reputation
    var reputationRaw: String              // DynastyReputation.rawValue
    var revolutionaryCredentials: Int      // 0-100, family's Party history

    // Ancestors
    var rehabilitatedAncestorsData: Data?  // Names of posthumously rehabilitated
    var purgedAncestorsData: Data?         // Names of ancestors who fell

    // Relationship
    var game: Game?

    init(dynastyName: String) {
        self.id = UUID()
        self.dynastyId = UUID()
        self.dynastyName = dynastyName
        self.currentGeneration = 1
        self.totalTurnsPlayed = 0
        self.totalPositionsHeld = 0
        self.reputationRaw = DynastyReputation.neutral.rawValue
        self.revolutionaryCredentials = 50
    }

    // MARK: - Computed Properties

    var reputation: DynastyReputation {
        get { DynastyReputation(rawValue: reputationRaw) ?? .neutral }
        set { reputationRaw = newValue.rawValue }
    }

    var generations: [GenerationRecord] {
        get {
            guard let data = generationsData else { return [] }
            return (try? JSONDecoder().decode([GenerationRecord].self, from: data)) ?? []
        }
        set {
            generationsData = try? JSONEncoder().encode(newValue)
        }
    }

    var rehabilitatedAncestors: [String] {
        get {
            guard let data = rehabilitatedAncestorsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            rehabilitatedAncestorsData = try? JSONEncoder().encode(newValue)
        }
    }

    var purgedAncestors: [String] {
        get {
            guard let data = purgedAncestorsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            purgedAncestorsData = try? JSONEncoder().encode(newValue)
        }
    }

    var currentGenerationRecord: GenerationRecord? {
        generations.last
    }

    var previousGenerations: [GenerationRecord] {
        Array(generations.dropLast())
    }

    /// Whether the dynasty has any stain from purged ancestors
    var hasTaintedHistory: Bool {
        !purgedAncestors.isEmpty
    }

    /// Whether any ancestors have been rehabilitated
    var hasRehabilitatedAncestors: Bool {
        !rehabilitatedAncestors.isEmpty
    }

    // MARK: - Methods

    /// Start a new generation
    func startGeneration(
        characterName: String,
        startingPosition: String,
        positionIndex: Int,
        turn: Int
    ) {
        let newRecord = GenerationRecord(
            characterName: characterName,
            startTurn: turn,
            highestPositionTitle: startingPosition,
            highestPositionIndex: positionIndex,
            majorDecisions: []
        )

        var currentGenerations = generations
        currentGenerations.append(newRecord)
        generations = currentGenerations
        currentGeneration = currentGenerations.count
    }

    /// End the current generation
    func endGeneration(
        cause: CauseOfSuccession,
        turn: Int,
        finalStanding: Int,
        finalNetwork: Int,
        heirName: String?,
        heirRelationship: String?
    ) {
        var currentGenerations = generations
        guard !currentGenerations.isEmpty else { return }

        var lastGen = currentGenerations.removeLast()
        lastGen.endTurn = turn
        lastGen.causeOfEnd = cause
        lastGen.finalStanding = finalStanding
        lastGen.finalNetwork = finalNetwork
        lastGen.heirName = heirName
        lastGen.heirRelationship = heirRelationship

        lastGen.generateEpitaph()
        lastGen.generateOfficialNarrative()

        currentGenerations.append(lastGen)
        generations = currentGenerations

        // Update aggregate stats
        totalTurnsPlayed += lastGen.turnsInPower

        // Update reputation based on cause of end
        updateReputation(cause: cause, name: lastGen.characterName)
    }

    /// Record a major decision
    func recordDecision(
        turn: Int,
        title: String,
        description: String,
        outcome: String,
        affectedLawId: String? = nil,
        affectedCharacter: String? = nil
    ) {
        var currentGenerations = generations
        guard !currentGenerations.isEmpty else { return }

        var lastGen = currentGenerations.removeLast()

        let decision = MajorDecision(
            turnMade: turn,
            title: title,
            description: description,
            outcome: outcome,
            affectedLawId: affectedLawId,
            affectedCharacterName: affectedCharacter
        )

        lastGen.majorDecisions.append(decision)
        currentGenerations.append(lastGen)
        generations = currentGenerations
    }

    /// Update highest position if current is higher
    func updateHighestPosition(title: String, index: Int) {
        var currentGenerations = generations
        guard !currentGenerations.isEmpty else { return }

        var lastGen = currentGenerations.removeLast()
        if index > lastGen.highestPositionIndex {
            lastGen.highestPositionTitle = title
            lastGen.highestPositionIndex = index
            totalPositionsHeld += 1
        }
        currentGenerations.append(lastGen)
        generations = currentGenerations
    }

    private func updateReputation(cause: CauseOfSuccession, name: String) {
        switch cause {
        case .executedEnemy, .purgedDisgraced:
            // Add to purged list
            var purged = purgedAncestors
            purged.append(name)
            purgedAncestors = purged

            // Lower reputation
            if reputation == .respected || reputation == .revered {
                reputation = .questionable
            } else if reputation == .neutral {
                reputation = .tainted
            }

        case .executedMartyr:
            // Add to rehabilitated list
            var rehabilitated = rehabilitatedAncestors
            rehabilitated.append(name)
            rehabilitatedAncestors = rehabilitated

            // Improve reputation
            if reputation == .tainted || reputation == .questionable {
                reputation = .rehabilitated
            }

        case .naturalDeath, .retired:
            // Improve credentials
            revolutionaryCredentials = min(100, revolutionaryCredentials + 5)
            if reputation == .neutral && revolutionaryCredentials >= 70 {
                reputation = .respected
            }

        default:
            break
        }
    }

    /// Calculate inheritance for next generation based on dynasty history
    func calculateInheritanceModifier() -> Double {
        var modifier = reputation.startingStandingModifier > 0 ? 1.0 : 0.9

        // Last generation's end matters most
        if let lastGen = generations.last,
           let cause = lastGen.causeOfEnd {
            modifier *= cause.inheritancePenalty
        }

        // Long dynasties get bonus
        if currentGeneration >= 3 {
            modifier *= 1.1
        }

        // Purged ancestors hurt
        modifier -= Double(purgedAncestors.count) * 0.05

        // Rehabilitated ancestors help
        modifier += Double(rehabilitatedAncestors.count) * 0.05

        return max(0.1, min(1.5, modifier))
    }
}

// MARK: - Legacy Summary

/// Summary for display during transition
struct LegacySummary: Codable {
    var dynastyName: String
    var generationsCount: Int
    var totalTurns: Int
    var reputation: DynastyReputation
    var lastLeaderName: String
    var lastLeaderEpitaph: String
    var lastLeaderCause: CauseOfSuccession
    var heirName: String?
    var heirInheritancePercent: Int
    var positionModifier: Int
    var warnings: [String]

    /// Memberwise initializer for direct construction
    init(
        dynastyName: String,
        generationsCount: Int,
        totalTurns: Int,
        reputation: DynastyReputation,
        lastLeaderName: String,
        lastLeaderEpitaph: String,
        lastLeaderCause: CauseOfSuccession,
        heirName: String?,
        heirInheritancePercent: Int,
        positionModifier: Int,
        warnings: [String]
    ) {
        self.dynastyName = dynastyName
        self.generationsCount = generationsCount
        self.totalTurns = totalTurns
        self.reputation = reputation
        self.lastLeaderName = lastLeaderName
        self.lastLeaderEpitaph = lastLeaderEpitaph
        self.lastLeaderCause = lastLeaderCause
        self.heirName = heirName
        self.heirInheritancePercent = heirInheritancePercent
        self.positionModifier = positionModifier
        self.warnings = warnings
    }

    /// Convenience initializer from DynastyLegacy
    init(legacy: DynastyLegacy, heirName: String?, inheritanceResult: InheritanceResult?) {
        self.dynastyName = legacy.dynastyName
        self.generationsCount = legacy.currentGeneration
        self.totalTurns = legacy.totalTurnsPlayed
        self.reputation = legacy.reputation

        let lastGen = legacy.generations.last
        self.lastLeaderName = lastGen?.characterName ?? "Unknown"
        self.lastLeaderEpitaph = lastGen?.epitaph ?? ""
        self.lastLeaderCause = lastGen?.causeOfEnd ?? .naturalDeath

        self.heirName = heirName
        self.heirInheritancePercent = inheritanceResult?.finalPercent ?? 50
        self.positionModifier = lastLeaderCause.positionModifier

        // Generate warnings
        var w: [String] = []
        if legacy.hasTaintedHistory {
            w.append("Your family bears the stain of fallen ancestors.")
        }
        if lastLeaderCause.inheritancePenalty < 0.5 {
            w.append("Your predecessor's end casts a long shadow.")
        }
        self.warnings = w
    }
}
