//
//  PolicySlot.swift
//  Nomenklatura
//
//  Policy Slots represent areas of governance where competing policy options exist.
//  Each institution has multiple slots, and each slot has 3-4 competing options.
//

import Foundation
import SwiftData

// MARK: - Policy Option Effects

struct PolicyEffects: Codable, Equatable {
    // Stat modifiers (applied while policy is active)
    var stabilityModifier: Int = 0
    var popularSupportModifier: Int = 0
    var eliteLoyaltyModifier: Int = 0
    var economicOutputModifier: Int = 0
    var militaryLoyaltyModifier: Int = 0
    var internationalStandingModifier: Int = 0
    var securityEffectiveness: Int = 0
    var regionalControlModifier: Int = 0

    // Faction standing modifiers
    var factionModifiers: [String: Int] = [:]  // factionId -> standing change

    // Special flags
    var enablesDecrees: Bool = false           // GS can bypass SC
    var enablesPurges: Bool = false            // Allows mass arrests
    var enablesReforms: Bool = false           // Unlocks economic reforms
    var enablesAutonomy: Bool = false          // Regions can self-govern
    var preventsSuccession: Bool = false       // Blocks normal succession
    var triggersUnrest: Bool = false           // Causes popular discontent

    static let none = PolicyEffects()
}

// MARK: - Policy Option

struct PolicyOption: Codable, Identifiable, Equatable {
    let id: String              // Unique ID like "term_limits_life_tenure"
    let name: String            // Display name
    let description: String     // Full description
    let effects: PolicyEffects  // Stat/faction effects
    let beneficiaries: [String] // Faction IDs that benefit
    let losers: [String]        // Faction IDs that lose
    let isDefault: Bool         // Is this the starting policy?
    let isExtreme: Bool         // Requires high power to enact

    // Requirements to enact this option
    let minimumPowerRequired: Int       // Power consolidation needed
    let minimumPositionIndex: Int       // Position level needed (0-8)
    let requiredFactionSupport: [String: Int]?  // Faction -> minimum standing

    // Consequences of enacting
    let immediateConsequenceChance: Int  // 0-100, chance of immediate backlash
    let delayedConsequenceSeverity: Int  // 1-5, how severe delayed effects are

    init(
        id: String,
        name: String,
        description: String,
        effects: PolicyEffects = .none,
        beneficiaries: [String] = [],
        losers: [String] = [],
        isDefault: Bool = false,
        isExtreme: Bool = false,
        minimumPowerRequired: Int = 40,
        minimumPositionIndex: Int = 5,
        requiredFactionSupport: [String: Int]? = nil,
        immediateConsequenceChance: Int = 20,
        delayedConsequenceSeverity: Int = 2
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.effects = effects
        self.beneficiaries = beneficiaries
        self.losers = losers
        self.isDefault = isDefault
        self.isExtreme = isExtreme
        self.minimumPowerRequired = minimumPowerRequired
        self.minimumPositionIndex = minimumPositionIndex
        self.requiredFactionSupport = requiredFactionSupport
        self.immediateConsequenceChance = immediateConsequenceChance
        self.delayedConsequenceSeverity = delayedConsequenceSeverity
    }
}

// MARK: - Policy Change Record

struct PolicyChangeRecord: Codable, Identifiable {
    let id: UUID
    let slotId: String
    let previousOptionId: String
    let newOptionId: String
    let changedByCharacterId: String?
    let changedByPlayer: Bool
    let turnChanged: Int
    let wasDecreed: Bool          // Bypassed Standing Committee
    let voteResult: VoteResult?   // If voted, what was the result

    struct VoteResult: Codable {
        let inFavor: Int
        let against: Int
        let abstained: Int
        let unanimous: Bool
    }

    init(
        slotId: String,
        previousOptionId: String,
        newOptionId: String,
        changedByCharacterId: String? = nil,
        changedByPlayer: Bool = false,
        turnChanged: Int,
        wasDecreed: Bool = false,
        voteResult: VoteResult? = nil
    ) {
        self.id = UUID()
        self.slotId = slotId
        self.previousOptionId = previousOptionId
        self.newOptionId = newOptionId
        self.changedByCharacterId = changedByCharacterId
        self.changedByPlayer = changedByPlayer
        self.turnChanged = turnChanged
        self.wasDecreed = wasDecreed
        self.voteResult = voteResult
    }
}

// MARK: - Policy Slot Model

@Model
final class PolicySlot {
    @Attribute(.unique) var id: UUID
    var slotId: String                    // e.g., "presidium_term_limits"
    var name: String                      // "Term Limits"
    var slotDescription: String           // Full description of this policy area
    var institutionRaw: String            // Institution.rawValue
    var categoryRaw: String               // LawCategory.rawValue (for difficulty)

    // Current active policy
    var currentOptionId: String           // Which PolicyOption is active

    // All available options (encoded)
    var optionsData: Data?

    // History of changes
    var changeHistoryData: Data?

    // Last modified
    var lastModifiedTurn: Int?
    var lastModifiedBy: String?           // Character name
    var lastModifiedByPlayer: Bool

    // Pending proposal (if any)
    var pendingProposalOptionId: String?
    var pendingProposalCharacterId: String?
    var pendingProposalTurn: Int?

    // Relationship
    var game: Game?

    init(
        slotId: String,
        name: String,
        description: String,
        institution: Institution,
        category: LawCategory,
        options: [PolicyOption],
        defaultOptionId: String
    ) {
        self.id = UUID()
        self.slotId = slotId
        self.name = name
        self.slotDescription = description
        self.institutionRaw = institution.rawValue
        self.categoryRaw = category.rawValue
        self.currentOptionId = defaultOptionId
        self.lastModifiedByPlayer = false
        self.options = options
    }

    // MARK: - Computed Properties

    var institution: Institution {
        Institution(rawValue: institutionRaw) ?? .presidium
    }

    var category: LawCategory {
        LawCategory(rawValue: categoryRaw) ?? .institutional
    }

    var options: [PolicyOption] {
        get {
            guard let data = optionsData else { return [] }
            return (try? JSONDecoder().decode([PolicyOption].self, from: data)) ?? []
        }
        set {
            optionsData = try? JSONEncoder().encode(newValue)
        }
    }

    var changeHistory: [PolicyChangeRecord] {
        get {
            guard let data = changeHistoryData else { return [] }
            return (try? JSONDecoder().decode([PolicyChangeRecord].self, from: data)) ?? []
        }
        set {
            changeHistoryData = try? JSONEncoder().encode(newValue)
        }
    }

    var currentOption: PolicyOption? {
        options.first { $0.id == currentOptionId }
    }

    var defaultOption: PolicyOption? {
        options.first { $0.isDefault }
    }

    var hasBeenModified: Bool {
        guard let defaultOpt = defaultOption else { return false }
        return currentOptionId != defaultOpt.id
    }

    var hasPendingProposal: Bool {
        pendingProposalOptionId != nil
    }

    // MARK: - Methods

    func option(withId id: String) -> PolicyOption? {
        options.first { $0.id == id }
    }

    func canChange(
        to optionId: String,
        playerPower: Int,
        playerPosition: Int,
        factionStandings: [String: Int]
    ) -> (canChange: Bool, reason: String?) {
        guard let option = option(withId: optionId) else {
            return (false, "Invalid option")
        }

        if optionId == currentOptionId {
            return (false, "Already active policy")
        }

        if playerPower < option.minimumPowerRequired {
            return (false, "Requires \(option.minimumPowerRequired) power consolidation")
        }

        if playerPosition < option.minimumPositionIndex {
            return (false, "Requires higher position")
        }

        if let requiredSupport = option.requiredFactionSupport {
            for (factionId, minStanding) in requiredSupport {
                let currentStanding = factionStandings[factionId] ?? 0
                if currentStanding < minStanding {
                    return (false, "Insufficient support from \(factionId)")
                }
            }
        }

        return (true, nil)
    }

    func changePolicy(
        to optionId: String,
        changedByCharacterId: String?,
        changedByPlayer: Bool,
        turn: Int,
        wasDecreed: Bool,
        voteResult: PolicyChangeRecord.VoteResult?
    ) {
        let previousId = currentOptionId

        // Record the change
        let record = PolicyChangeRecord(
            slotId: slotId,
            previousOptionId: previousId,
            newOptionId: optionId,
            changedByCharacterId: changedByCharacterId,
            changedByPlayer: changedByPlayer,
            turnChanged: turn,
            wasDecreed: wasDecreed,
            voteResult: voteResult
        )

        var history = changeHistory
        history.append(record)
        changeHistory = history

        // Update current option
        currentOptionId = optionId
        lastModifiedTurn = turn
        lastModifiedBy = changedByCharacterId
        lastModifiedByPlayer = changedByPlayer

        // Clear any pending proposal
        clearPendingProposal()
    }

    func proposeChange(optionId: String, characterId: String, turn: Int) {
        pendingProposalOptionId = optionId
        pendingProposalCharacterId = characterId
        pendingProposalTurn = turn
    }

    func clearPendingProposal() {
        pendingProposalOptionId = nil
        pendingProposalCharacterId = nil
        pendingProposalTurn = nil
    }

    func restoreDefault() {
        guard let defaultOpt = defaultOption else { return }
        currentOptionId = defaultOpt.id
        lastModifiedTurn = nil
        lastModifiedBy = nil
        lastModifiedByPlayer = false
    }
}

// MARK: - Policy Slot Extensions

extension PolicySlot {

    /// Get the effects of the current active policy
    var currentEffects: PolicyEffects {
        currentOption?.effects ?? .none
    }

    /// Get factions that benefit from current policy
    var currentBeneficiaries: [String] {
        currentOption?.beneficiaries ?? []
    }

    /// Get factions that lose from current policy
    var currentLosers: [String] {
        currentOption?.losers ?? []
    }

    /// Summary of change history
    var changeCount: Int {
        changeHistory.count
    }

    /// Most recent change
    var mostRecentChange: PolicyChangeRecord? {
        changeHistory.last
    }

    /// Was the current policy decreed (not voted)?
    var wasCurrentPolicyDecreed: Bool {
        mostRecentChange?.wasDecreed ?? false
    }
}
