//
//  GameCharacter.swift
//  Nomenklatura
//
//  Character model for NPCs in the game
//

import Foundation
import SwiftData

@Model
final class GameCharacter {
    @Attribute(.unique) var id: UUID
    var templateId: String
    var name: String
    var title: String?
    var role: String  // leader, patron, rival, ally, neutral, subordinate
    var positionIndex: Int?
    var positionTrack: String?  // Track assignment (e.g., "securityServices", "regional")

    var status: String  // CharacterStatus raw value
    var statusChangedTurn: Int?
    var statusDetails: String?       // "Under investigation for wrecking"
    var fateNarrative: String?       // Full story of what happened
    var remainingInfluence: Int      // Influence even after fall (0-100)
    var canReturnFlag: Bool          // For disappeared characters
    var returnProbability: Int       // Chance to resurface (0-100)

    // Relationship to player (-100 to 100)
    var disposition: Int
    var isPatron: Bool
    var isRival: Bool

    // Character traits
    var personalityAmbitious: Int
    var personalityParanoid: Int
    var personalityRuthless: Int
    var personalityCompetent: Int
    var personalityLoyal: Int
    var personalityCorrupt: Int

    var speechPattern: String?

    // Faction allegiance
    var factionId: String?
    var factionLoyalty: Int

    // History
    var introducedTurn: Int
    var lastAppearedTurn: Int?
    var turnsAtSeniorPosition: Int     // Turns spent at position 4+ (for SC eligibility)

    // Living Character System - Discovery state
    var isFullyRevealed: Bool            // Has player learned personality?
    var personalityRevealedTurn: Int?    // When personality was discovered
    var wasDiscoveredDynamically: Bool   // Was this character discovered from AI narratives?

    // Living Character System - Interaction history (encoded as Data for SwiftData)
    var interactionHistoryData: Data?    // Encoded [CharacterInteractionRecord]

    // Living Character System - Proactive behavior
    var lastInitiatedTurn: Int?          // Last turn this character reached out
    var aggressionLevel: Int             // Influences proactive behavior frequency (0-100)

    // Memory/Grudge System (RDR2-style naturalism)
    var grudgeLevel: Int                 // Long-term resentment (-100 to 100, negative = grudge)
    var gratitudeLevel: Int              // Appreciation for past help (0-100)
    var fearLevel: Int                   // Fear of player's power (0-100)
    var trustLevel: Int                  // Trust based on consistent behavior (0-100)
    var memoriesData: Data?              // Encoded [CharacterMemory]
    var opinionOnLawsData: Data?         // Encoded [String: Int] - lawId to opinion
    var lastBetrayalTurn: Int?           // Last time player betrayed them
    var lastFavorTurn: Int?              // Last time player helped them
    var accumulatedSlights: Int          // Count of minor offenses
    var accumulatedKindnesses: Int       // Count of minor good deeds

    // NPC Behavior System - Goals, Needs, Memory, Espionage
    var npcGoalsData: Data?              // Encoded [NPCGoal]
    var npcNeedsData: Data?              // Encoded NPCNeeds
    var npcMemoriesData: Data?           // Encoded [NPCMemory]
    var foreignAgentData: Data?          // Encoded ForeignAgentStatus
    var ambientActivitiesData: Data?     // Encoded [AmbientActivity]

    // Denouncement/Evidence System
    var evidenceLevel: Int               // 0-100: How much evidence exists against them
    var denouncementCount: Int           // How many times they've been denounced
    var lastDenouncedTurn: Int?          // When they were last denounced
    var denouncedByPlayer: Bool          // Has the player denounced them?
    var hasProtection: Bool              // Do they have high-level protection?
    var protectorId: String?             // UUID of their protector (if any)

    var game: Game?

    init(
        templateId: String,
        name: String,
        title: String? = nil,
        role: CharacterRole
    ) {
        self.id = UUID()
        self.templateId = templateId
        self.name = name
        self.title = title
        self.role = role.rawValue
        self.status = CharacterStatus.active.rawValue
        self.disposition = 50
        self.isPatron = false
        self.isRival = false

        // Default personality
        self.personalityAmbitious = 50
        self.personalityParanoid = 50
        self.personalityRuthless = 50
        self.personalityCompetent = 50
        self.personalityLoyal = 50
        self.personalityCorrupt = 50

        self.factionLoyalty = 50
        self.introducedTurn = 1
        self.turnsAtSeniorPosition = 0

        // Enhanced status fields
        self.remainingInfluence = 0
        self.canReturnFlag = false
        self.returnProbability = 0

        // Living Character System defaults
        self.isFullyRevealed = false
        self.wasDiscoveredDynamically = false
        self.aggressionLevel = 50

        // Memory/Grudge System defaults
        self.grudgeLevel = 0
        self.gratitudeLevel = 0
        self.fearLevel = 0
        self.trustLevel = 50
        self.accumulatedSlights = 0
        self.accumulatedKindnesses = 0

        // Evidence/Denouncement defaults
        self.evidenceLevel = 0
        self.denouncementCount = 0
        self.denouncedByPlayer = false
        self.hasProtection = false
    }

    /// Convenience initializer for dynamically discovered characters
    convenience init(
        name: String,
        title: String?,
        role: CharacterRole,
        introducedTurn: Int,
        disposition: Int = 50
    ) {
        self.init(
            templateId: "discovered_\(UUID().uuidString.prefix(8))",
            name: name,
            title: title,
            role: role
        )
        self.introducedTurn = introducedTurn
        self.lastAppearedTurn = introducedTurn
        self.disposition = disposition
        self.wasDiscoveredDynamically = true
        self.isFullyRevealed = false
    }
}

// MARK: - Character Role

public enum CharacterRole: String, Codable, CaseIterable {
    case leader
    case patron
    case rival
    case ally
    case neutral
    case subordinate
    case informant       // Network contact who provides information
    case contact         // General network contact
}

// MARK: - Character Status

enum CharacterStatus: String, Codable, CaseIterable {
    case active              // Currently in position
    case dead                // Deceased (natural or otherwise)
    case exiled              // Sent away from power center
    case imprisoned          // In detention/labor camp
    case retired             // Forced or voluntary retirement
    case disappeared         // Fate unknown - CAN RETURN
    case underInvestigation  // Being investigated by security organs
    case detained            // Short-term holding (shuanggui)
    case rehabilitated       // Restored after previous fall
    case executed            // Death by execution

    /// Display-friendly text
    var displayText: String {
        switch self {
        case .active: return "Active"
        case .dead: return "Deceased"
        case .exiled: return "Exiled"
        case .imprisoned: return "Imprisoned"
        case .retired: return "Retired"
        case .disappeared: return "Disappeared"
        case .underInvestigation: return "Under Investigation"
        case .detained: return "Detained"
        case .rehabilitated: return "Rehabilitated"
        case .executed: return "Executed"
        }
    }

    /// Euphemistic description
    var euphemism: String {
        switch self {
        case .active: return "serving the party"
        case .dead: return "passed after illness"
        case .exiled: return "contributing to regional development"
        case .imprisoned: return "undergoing reform through labor"
        case .retired: return "released for health reasons"
        case .disappeared: return "whereabouts unknown"
        case .underInvestigation: return "assisting with party inquiries"
        case .detained: return "cooperating with discipline inspection"
        case .rehabilitated: return "errors corrected; restored to good standing"
        case .executed: return "convicted of crimes against the state"
        }
    }

    /// Whether this status means the character is "fallen" from grace
    var isFallen: Bool {
        switch self {
        case .active, .rehabilitated:
            return false
        default:
            return true
        }
    }

    /// Whether the character can potentially return
    var canReturn: Bool {
        switch self {
        case .disappeared, .imprisoned, .exiled, .detained, .underInvestigation:
            return true
        default:
            return false
        }
    }

    /// Whether this is a permanent/final status
    var isPermanent: Bool {
        switch self {
        case .dead, .executed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Computed Properties

extension GameCharacter {
    var currentRole: CharacterRole {
        CharacterRole(rawValue: role) ?? .neutral
    }

    var currentStatus: CharacterStatus {
        CharacterStatus(rawValue: status) ?? .active
    }

    var isAlive: Bool {
        !currentStatus.isPermanent
    }

    /// Whether character is currently active in government
    var isActive: Bool {
        currentStatus == .active || currentStatus == .rehabilitated
    }

    /// Whether character has "fallen" from grace
    var isFallen: Bool {
        currentStatus.isFallen
    }

    /// Whether this character might return from their current status
    var mightReturn: Bool {
        canReturnFlag && currentStatus.canReturn
    }

    var personality: CharacterPersonality {
        CharacterPersonality(
            ambitious: personalityAmbitious,
            paranoid: personalityParanoid,
            ruthless: personalityRuthless,
            competent: personalityCompetent,
            loyal: personalityLoyal,
            corrupt: personalityCorrupt
        )
    }

    var stanceTags: [StanceTag] {
        var tags: [StanceTag] = []

        if isPatron {
            tags.append(.patron)
        }
        if isRival {
            tags.append(.rival)
        }
        if !isPatron && !isRival && disposition >= 60 {
            tags.append(.ally)
        }
        if !isPatron && !isRival && disposition < 60 && disposition > 40 {
            tags.append(.neutral)
        }

        return tags
    }

    var traitTags: [String] {
        var tags: [String] = []

        if personalityAmbitious >= 70 { tags.append("Ambitious") }
        if personalityParanoid >= 70 { tags.append("Paranoid") }
        if personalityRuthless >= 70 { tags.append("Ruthless") }
        if personalityCompetent >= 70 { tags.append("Competent") }
        if personalityLoyal >= 70 { tags.append("Loyal") }
        if personalityCorrupt >= 70 { tags.append("Corrupt") }

        if personalityAmbitious <= 30 { tags.append("Content") }
        if personalityParanoid <= 30 { tags.append("Trusting") }
        if personalityRuthless <= 30 { tags.append("Merciful") }

        return tags
    }

    /// Icon for character display
    var displayIcon: String {
        switch currentRole {
        case .leader: return "👴"
        case .patron: return "🕴️"
        case .rival: return "💰"
        case .ally: return "📝"
        case .neutral: return "🎖️"
        case .subordinate: return "👤"
        case .informant: return "🕵️"
        case .contact: return "📞"
        }
    }
}

// MARK: - Stance Tag

enum StanceTag: String, CaseIterable {
    case patron = "Your Patron"
    case rival = "Rival"
    case ally = "Ally"
    case neutral = "Neutral"

    var backgroundColor: String {
        switch self {
        case .patron: return "stancePatronBg"
        case .rival: return "stanceRivalBg"
        case .ally: return "stanceAllyBg"
        case .neutral: return "stanceNeutralBg"
        }
    }

    var textColor: String {
        switch self {
        case .patron: return "stancePatronText"
        case .rival: return "stanceRivalText"
        case .ally: return "stanceAllyText"
        case .neutral: return "stanceNeutralText"
        }
    }
}

// MARK: - Character Personality

struct CharacterPersonality: Codable {
    var ambitious: Int
    var paranoid: Int
    var ruthless: Int
    var competent: Int
    var loyal: Int
    var corrupt: Int

    init(
        ambitious: Int = 50,
        paranoid: Int = 50,
        ruthless: Int = 50,
        competent: Int = 50,
        loyal: Int = 50,
        corrupt: Int = 50
    ) {
        self.ambitious = ambitious
        self.paranoid = paranoid
        self.ruthless = ruthless
        self.competent = competent
        self.loyal = loyal
        self.corrupt = corrupt
    }

    /// Brief text description of personality
    var briefDescription: String {
        var traits: [String] = []
        if ambitious >= 70 { traits.append("Ambitious") }
        if paranoid >= 70 { traits.append("Paranoid") }
        if ruthless >= 70 { traits.append("Ruthless") }
        if competent >= 70 { traits.append("Competent") }
        if loyal >= 70 { traits.append("Loyal") }
        if corrupt >= 70 { traits.append("Corrupt") }
        return traits.isEmpty ? "Unremarkable" : traits.joined(separator: ", ")
    }
}

// MARK: - Character Interaction Record

/// Records a single interaction between the player and a character
struct CharacterInteractionRecord: Codable {
    let turnNumber: Int
    let scenarioSummary: String
    let playerChoice: String
    let outcomeEffect: String  // "positive", "negative", "neutral"
    let dispositionChange: Int
}

// MARK: - Living Character System Extensions

extension GameCharacter {

    /// Decode interaction history from stored data
    var interactionHistory: [CharacterInteractionRecord] {
        get {
            guard let data = interactionHistoryData else { return [] }
            return (try? JSONDecoder().decode([CharacterInteractionRecord].self, from: data)) ?? []
        }
        set {
            interactionHistoryData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Record an interaction with this character
    func recordInteraction(
        turn: Int,
        scenario: String,
        choice: String,
        outcome: String,
        dispositionChange: Int
    ) {
        var history = interactionHistory
        history.append(CharacterInteractionRecord(
            turnNumber: turn,
            scenarioSummary: String(scenario.prefix(150)),
            playerChoice: choice,
            outcomeEffect: outcome,
            dispositionChange: dispositionChange
        ))
        // Keep last 10 interactions
        if history.count > 10 {
            history = Array(history.suffix(10))
        }
        interactionHistory = history
    }

    /// Get personality only if revealed (for display purposes)
    var displayPersonality: CharacterPersonality? {
        isFullyRevealed ? personality : nil
    }

    /// Summary for AI prompts - includes interaction history if available
    var aiContextSummary: String {
        var summary = "**\(name)**"
        if let title = title { summary += " (\(title))" }
        summary += " - Disposition: \(disposition)/100"

        if isFullyRevealed {
            summary += ", Personality: \(personality.briefDescription)"
        }

        if !interactionHistory.isEmpty {
            let recent = interactionHistory.suffix(3)
            summary += "\n  Recent interactions: "
            summary += recent.map { "Turn \($0.turnNumber): \($0.outcomeEffect)" }.joined(separator: "; ")
        }

        return summary
    }

    /// Check if personality should be revealed based on interaction count and network
    func checkPersonalityReveal(networkStat: Int, currentTurn: Int) -> Bool {
        // Already revealed
        if isFullyRevealed { return false }

        // Conditions for revealing personality:
        // 1. 5+ interactions with this character AND high network stat (60+)
        // 2. 8+ interactions regardless of network
        let interactionCount = interactionHistory.count
        let networkThreshold = networkStat >= 60

        if (interactionCount >= 5 && networkThreshold) || interactionCount >= 8 {
            isFullyRevealed = true
            personalityRevealedTurn = currentTurn
            return true
        }

        return false
    }

    /// Update relationship status based on disposition thresholds
    func updateRelationshipStatus(currentTurn: Int) -> String? {
        // If disposition drops below -30 and character was neutral/ally, they become hostile
        if disposition <= -30 && !isRival && currentRole != .rival {
            role = CharacterRole.rival.rawValue
            return "\(name) has become openly hostile to you"
        }

        // If disposition rises above 70, character becomes potential ally
        if disposition >= 70 && currentRole == .neutral {
            role = CharacterRole.ally.rawValue
            return "\(name) has become a trusted ally"
        }

        return nil
    }
}

// MARK: - Character Memory

/// A significant memory that shapes character behavior
struct CharacterMemory: Codable, Identifiable {
    var id: String = UUID().uuidString
    var turnOccurred: Int
    var memoryType: MemoryType
    var description: String
    var emotionalImpact: Int        // -100 to 100 (negative = bad memory)
    var isProcessed: Bool = false   // Has this memory affected behavior yet?
    var decayRate: Int              // How fast memory fades (1-10, higher = faster)

    enum MemoryType: String, Codable {
        case betrayal           // Player broke promise or harmed them
        case favor              // Player helped them significantly
        case humiliation        // Player embarrassed them publicly
        case protection         // Player protected them from threat
        case slight             // Minor offense
        case kindness           // Minor good deed
        case lawChange          // Player changed a law they cared about
        case promotion          // Player helped their career
        case demotion           // Player hurt their career
        case familyMatter       // Something involving their family
        case factionAction      // Action affecting their faction
    }

    var isPositive: Bool {
        emotionalImpact > 0
    }

    var isSignificant: Bool {
        abs(emotionalImpact) >= 30
    }
}

// MARK: - Memory/Grudge System Extensions

extension GameCharacter {

    /// All memories this character has
    var memories: [CharacterMemory] {
        get {
            guard let data = memoriesData else { return [] }
            return (try? JSONDecoder().decode([CharacterMemory].self, from: data)) ?? []
        }
        set {
            memoriesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Character's opinions on specific laws
    var lawOpinions: [String: Int] {
        get {
            guard let data = opinionOnLawsData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            opinionOnLawsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Add a memory to this character
    func addMemory(_ memory: CharacterMemory) {
        var current = memories
        current.append(memory)

        // Keep only the 20 most impactful memories
        if current.count > 20 {
            current.sort { abs($0.emotionalImpact) > abs($1.emotionalImpact) }
            current = Array(current.prefix(20))
        }

        memories = current

        // Update grudge/gratitude based on memory
        updateEmotionalState(from: memory)
    }

    /// Record a betrayal by the player
    func recordBetrayal(turn: Int, description: String, severity: Int) {
        let memory = CharacterMemory(
            turnOccurred: turn,
            memoryType: .betrayal,
            description: description,
            emotionalImpact: -severity,
            decayRate: 2 // Betrayals fade slowly
        )
        addMemory(memory)
        lastBetrayalTurn = turn

        // Betrayals significantly affect trust
        trustLevel = max(0, trustLevel - (severity / 2))
    }

    /// Record a favor done by the player
    func recordFavor(turn: Int, description: String, magnitude: Int) {
        let memory = CharacterMemory(
            turnOccurred: turn,
            memoryType: .favor,
            description: description,
            emotionalImpact: magnitude,
            decayRate: 4 // Favors fade faster than betrayals
        )
        addMemory(memory)
        lastFavorTurn = turn

        // Favors build trust
        trustLevel = min(100, trustLevel + (magnitude / 3))
    }

    /// Record a minor slight
    func recordSlight(turn: Int, description: String) {
        accumulatedSlights += 1

        // After 3 slights, create a grudge memory
        if accumulatedSlights >= 3 {
            let memory = CharacterMemory(
                turnOccurred: turn,
                memoryType: .slight,
                description: "Accumulated minor offenses: \(description)",
                emotionalImpact: -20,
                decayRate: 6
            )
            addMemory(memory)
            accumulatedSlights = 0
        }
    }

    /// Record a minor kindness
    func recordKindness(turn: Int, description: String) {
        accumulatedKindnesses += 1

        // After 3 kindnesses, create a gratitude memory
        if accumulatedKindnesses >= 3 {
            let memory = CharacterMemory(
                turnOccurred: turn,
                memoryType: .kindness,
                description: "Accumulated good deeds: \(description)",
                emotionalImpact: 15,
                decayRate: 5
            )
            addMemory(memory)
            accumulatedKindnesses = 0
        }
    }

    /// Record character's reaction to a law change
    func recordLawOpinion(lawId: String, opinion: Int, turn: Int, description: String) {
        var opinions = lawOpinions
        opinions[lawId] = opinion
        lawOpinions = opinions

        // Significant opinions create memories
        if abs(opinion) >= 30 {
            let memory = CharacterMemory(
                turnOccurred: turn,
                memoryType: .lawChange,
                description: description,
                emotionalImpact: opinion,
                decayRate: 3
            )
            addMemory(memory)
        }
    }

    /// Update emotional state based on a new memory
    private func updateEmotionalState(from memory: CharacterMemory) {
        let impact = memory.emotionalImpact

        if impact < 0 {
            // Negative memory increases grudge
            grudgeLevel = max(-100, grudgeLevel + (impact / 2))
        } else {
            // Positive memory increases gratitude
            gratitudeLevel = min(100, gratitudeLevel + (impact / 2))
        }

        // Significant events affect disposition
        disposition = max(-100, min(100, disposition + (impact / 4)))
    }

    /// Update fear level based on player's power and actions
    func updateFearLevel(playerPower: Int, recentActions: [String]) {
        // Base fear from power differential
        var newFear = playerPower / 2

        // Increase fear if player has taken ruthless actions
        if recentActions.contains("purge") {
            newFear += 20
        }
        if recentActions.contains("execution") {
            newFear += 30
        }
        if recentActions.contains("forced_confession") {
            newFear += 15
        }

        // Decrease fear if player has shown mercy
        if recentActions.contains("rehabilitation") {
            newFear -= 10
        }
        if recentActions.contains("amnesty") {
            newFear -= 15
        }

        fearLevel = max(0, min(100, newFear))
    }

    /// Process memory decay over time
    func processMemoryDecay(currentTurn: Int) {
        var current = memories

        for index in current.indices {
            let turnsElapsed = currentTurn - current[index].turnOccurred
            let decayAmount = turnsElapsed * current[index].decayRate

            // Reduce emotional impact over time
            if current[index].emotionalImpact > 0 {
                current[index] = CharacterMemory(
                    id: current[index].id,
                    turnOccurred: current[index].turnOccurred,
                    memoryType: current[index].memoryType,
                    description: current[index].description,
                    emotionalImpact: max(0, current[index].emotionalImpact - decayAmount),
                    isProcessed: current[index].isProcessed,
                    decayRate: current[index].decayRate
                )
            } else {
                current[index] = CharacterMemory(
                    id: current[index].id,
                    turnOccurred: current[index].turnOccurred,
                    memoryType: current[index].memoryType,
                    description: current[index].description,
                    emotionalImpact: min(0, current[index].emotionalImpact + decayAmount),
                    isProcessed: current[index].isProcessed,
                    decayRate: current[index].decayRate
                )
            }
        }

        // Remove faded memories
        current = current.filter { abs($0.emotionalImpact) > 5 }
        memories = current

        // Decay grudge and gratitude slightly
        if grudgeLevel < 0 {
            grudgeLevel = min(0, grudgeLevel + 1)
        }
        if gratitudeLevel > 0 {
            gratitudeLevel = max(0, gratitudeLevel - 1)
        }
    }

    /// Get character's overall emotional stance toward player
    var emotionalStance: EmotionalStance {
        let netFeeling = gratitudeLevel + grudgeLevel // grudgeLevel is negative when grudging

        if fearLevel > 70 {
            return .terrified
        }
        if netFeeling < -50 {
            return .hostile
        }
        if netFeeling < -20 {
            return .resentful
        }
        if netFeeling > 50 && trustLevel > 60 {
            return .devoted
        }
        if netFeeling > 20 {
            return .grateful
        }
        if trustLevel < 30 {
            return .suspicious
        }
        return .neutral
    }

    /// Behavior modifier based on emotional state
    var behaviorModifier: BehaviorModifier {
        switch emotionalStance {
        case .terrified:
            return BehaviorModifier(
                cooperationBonus: 30,
                betrayalRisk: -20,
                initiativeReduction: 50,
                description: "Acts out of fear, not loyalty"
            )
        case .hostile:
            return BehaviorModifier(
                cooperationBonus: -40,
                betrayalRisk: 60,
                initiativeReduction: -20,
                description: "Actively working against you"
            )
        case .resentful:
            return BehaviorModifier(
                cooperationBonus: -20,
                betrayalRisk: 30,
                initiativeReduction: 0,
                description: "Harbors grudges, waits for opportunity"
            )
        case .devoted:
            return BehaviorModifier(
                cooperationBonus: 40,
                betrayalRisk: -30,
                initiativeReduction: -10,
                description: "Loyal and proactive supporter"
            )
        case .grateful:
            return BehaviorModifier(
                cooperationBonus: 20,
                betrayalRisk: -10,
                initiativeReduction: 0,
                description: "Remembers your kindness"
            )
        case .suspicious:
            return BehaviorModifier(
                cooperationBonus: -10,
                betrayalRisk: 15,
                initiativeReduction: 20,
                description: "Watchful and cautious"
            )
        case .neutral:
            return BehaviorModifier(
                cooperationBonus: 0,
                betrayalRisk: 0,
                initiativeReduction: 0,
                description: "Professional detachment"
            )
        }
    }

    /// Check if character would join a coalition against player
    func wouldJoinCoalition(coalitionStrength: Int, playerPower: Int) -> Bool {
        // Factors that increase coalition joining
        var joinChance = 0

        // Grudge increases chance
        if grudgeLevel < -30 {
            joinChance += abs(grudgeLevel) / 2
        }

        // Low fear + resentment = likely to join
        if fearLevel < 40 && emotionalStance == .resentful {
            joinChance += 30
        }

        // Coalition strength matters
        if coalitionStrength > playerPower {
            joinChance += 20
        }

        // Personal ambition matters
        if personalityAmbitious > 70 && !isPatron {
            joinChance += 15
        }

        // Factors that decrease joining
        // Gratitude
        if gratitudeLevel > 30 {
            joinChance -= gratitudeLevel / 2
        }

        // High fear prevents action
        if fearLevel > 70 {
            joinChance -= 40
        }

        // Trust
        if trustLevel > 60 {
            joinChance -= 20
        }

        return Int.random(in: 1...100) <= joinChance
    }

    /// AI context including emotional state
    var aiContextWithEmotions: String {
        var context = aiContextSummary

        context += "\n  Emotional state: \(emotionalStance.displayName)"
        context += " (Grudge: \(grudgeLevel), Gratitude: \(gratitudeLevel), Fear: \(fearLevel), Trust: \(trustLevel))"

        // Include significant memories
        let significantMemories = memories.filter { $0.isSignificant }.prefix(3)
        if !significantMemories.isEmpty {
            context += "\n  Key memories: "
            context += significantMemories.map { $0.description }.joined(separator: "; ")
        }

        return context
    }
}

// MARK: - Emotional Stance

enum EmotionalStance: String, Codable {
    case terrified      // High fear, compliant but unreliable
    case hostile        // Active enemy
    case resentful      // Nursing grudges, waiting
    case suspicious     // Doesn't trust player
    case neutral        // Professional
    case grateful       // Appreciates player
    case devoted        // Loyal supporter

    var displayName: String {
        switch self {
        case .terrified: return "Terrified"
        case .hostile: return "Hostile"
        case .resentful: return "Resentful"
        case .suspicious: return "Suspicious"
        case .neutral: return "Neutral"
        case .grateful: return "Grateful"
        case .devoted: return "Devoted"
        }
    }
}

// MARK: - Behavior Modifier

struct BehaviorModifier {
    let cooperationBonus: Int       // Added to cooperation checks
    let betrayalRisk: Int           // Chance of betrayal in crisis
    let initiativeReduction: Int    // Reduction in proactive behavior
    let description: String
}

// MARK: - NPC Behavior System Extensions

extension GameCharacter {

    // MARK: - NPC Goals

    /// All goals this NPC is pursuing
    var npcGoals: [NPCGoal] {
        get {
            guard let data = npcGoalsData else { return [] }
            return (try? JSONDecoder().decode([NPCGoal].self, from: data)) ?? []
        }
        set {
            npcGoalsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Active (non-completed) goals sorted by priority
    var activeGoals: [NPCGoal] {
        return npcGoals.filter { $0.isActive }.sorted { $0.priority > $1.priority }
    }

    /// Primary goal (highest priority active goal)
    var primaryGoal: NPCGoal? {
        return activeGoals.first
    }

    /// Add a new goal
    func addGoal(_ goal: NPCGoal) {
        var goals = npcGoals
        goals.append(goal)
        // Keep max 5 goals
        if goals.count > 5 {
            goals.sort { $0.priority > $1.priority }
            goals = Array(goals.prefix(5))
        }
        npcGoals = goals
    }

    /// Update a goal's progress
    func updateGoalProgress(goalId: UUID, progress: Int, attempt: Bool = false, currentTurn: Int) {
        var goals = npcGoals
        if let index = goals.firstIndex(where: { $0.id == goalId }) {
            goals[index].progress = min(100, max(0, progress))
            if attempt {
                goals[index].attemptsCount += 1
                goals[index].lastAttemptTurn = currentTurn
            }
            // Mark complete if progress reaches 100
            if goals[index].progress >= 100 {
                goals[index].isActive = false
            }
            npcGoals = goals
        }
    }

    /// Increase frustration for a goal
    func increaseGoalFrustration(goalId: UUID, amount: Int = 10) {
        var goals = npcGoals
        if let index = goals.firstIndex(where: { $0.id == goalId }) {
            goals[index].frustrationLevel = min(100, goals[index].frustrationLevel + amount)
            npcGoals = goals
        }
    }

    /// Remove a goal
    func removeGoal(goalId: UUID) {
        var goals = npcGoals
        goals.removeAll { $0.id == goalId }
        npcGoals = goals
    }

    // MARK: - NPC Needs

    /// Current needs state
    var npcNeeds: NPCNeeds {
        get {
            guard let data = npcNeedsData else { return NPCNeeds() }
            return (try? JSONDecoder().decode(NPCNeeds.self, from: data)) ?? NPCNeeds()
        }
        set {
            npcNeedsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this character is a true believer in the Party
    var isTrueBeliever: Bool {
        return npcNeeds.isTrueBeliever || personalityLoyal > 80
    }

    /// Whether this character is disillusioned
    var isDisillusioned: Bool {
        return npcNeeds.isDisillusioned && personalityLoyal < 40
    }

    /// Update a specific need
    func updateNeed(_ needType: NeedType, change: Int) {
        var needs = npcNeeds
        let current = needs.value(for: needType)
        needs.setValue(current + change, for: needType)
        npcNeeds = needs
    }

    // MARK: - Enhanced NPC Memory

    /// Enhanced NPC-to-NPC memories
    var npcMemoriesEnhanced: [NPCMemory] {
        get {
            guard let data = npcMemoriesData else { return [] }
            return (try? JSONDecoder().decode([NPCMemory].self, from: data)) ?? []
        }
        set {
            npcMemoriesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Get memories about a specific character
    func memoriesAbout(characterId: String) -> [NPCMemory] {
        return npcMemoriesEnhanced.filter { $0.involvedCharacterId == characterId }
    }

    /// Get significant memories about a specific character
    func significantMemoriesAbout(characterId: String) -> [NPCMemory] {
        return memoriesAbout(characterId: characterId).filter { $0.isSignificant }
    }

    /// Add an enhanced NPC memory
    func addNPCMemory(_ memory: NPCMemory) {
        var memories = npcMemoriesEnhanced
        memories.append(memory)

        // Keep only 30 most recent/significant memories
        if memories.count > 30 {
            memories.sort { $0.severity > $1.severity }
            memories = Array(memories.prefix(30))
        }

        npcMemoriesEnhanced = memories
    }

    /// Process memory decay and remove faded memories
    func processNPCMemoryDecay(currentTurn: Int) {
        var memories = npcMemoriesEnhanced
        memories = memories.compactMap { memory in
            var mutableMemory = memory
            if mutableMemory.processDecay(currentTurn: currentTurn) {
                return nil // Remove faded memory
            }
            return mutableMemory
        }
        npcMemoriesEnhanced = memories
    }

    /// Get overall sentiment toward another character based on memories
    func sentimentToward(characterId: String) -> Int {
        let relevantMemories = significantMemoriesAbout(characterId: characterId)
        guard !relevantMemories.isEmpty else { return 0 }

        let totalSentiment = relevantMemories.reduce(0) { $0 + ($1.sentiment * $1.currentStrength / 100) }
        return totalSentiment / relevantMemories.count
    }

    // MARK: - Foreign Agent Status

    /// Espionage status
    var foreignAgentStatus: ForeignAgentStatus {
        get {
            guard let data = foreignAgentData else { return ForeignAgentStatus.notAnAgent }
            return (try? JSONDecoder().decode(ForeignAgentStatus.self, from: data)) ?? ForeignAgentStatus.notAnAgent
        }
        set {
            foreignAgentData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this character is an active foreign spy
    var isActiveSpy: Bool {
        return foreignAgentStatus.isForeignAgent && currentStatus == .active
    }

    /// Whether this character is at high risk of detection
    var isHighRiskSpy: Bool {
        return isActiveSpy && foreignAgentStatus.isHighRisk
    }

    /// Current detection risk (0 if not a spy)
    var detectionRisk: Int {
        return foreignAgentStatus.detectionRisk
    }

    /// Whether this character can be recruited as a foreign agent
    var canBeRecruitedAsSpy: Bool {
        // Already a spy
        if foreignAgentStatus.isForeignAgent { return false }

        // True believers refuse
        if isTrueBeliever { return false }
        if personalityLoyal > 80 { return false }

        // Corrupt characters are vulnerable
        if personalityCorrupt > 60 { return true }

        // Disaffected characters (low loyalty, high grudge)
        if personalityLoyal < 40 && grudgeLevel < -30 { return true }

        // Ambitious characters might be turned with promises
        if personalityAmbitious > 70 && personalityLoyal < 50 { return true }

        return false
    }

    /// Record espionage activity
    func recordSpyActivity(turn: Int) {
        guard isActiveSpy else { return }
        var status = foreignAgentStatus
        status.lastActivityTurn = turn
        foreignAgentStatus = status
    }

    /// Increase suspicion level
    func increaseSuspicion(amount: Int) {
        guard foreignAgentStatus.isForeignAgent else { return }
        var status = foreignAgentStatus
        status.suspicionLevel = min(100, status.suspicionLevel + amount)
        foreignAgentStatus = status
    }

    /// Erode cover strength
    func erodeCover(amount: Int) {
        guard foreignAgentStatus.isForeignAgent else { return }
        var status = foreignAgentStatus
        status.coverStrength = max(0, status.coverStrength - amount)
        foreignAgentStatus = status
    }

    /// Record passing secrets
    func recordSecretsPassed() {
        guard isActiveSpy else { return }
        var status = foreignAgentStatus
        status.secretsPassed += 1
        foreignAgentStatus = status
    }

    // MARK: - AI Context with Behavior System

    /// Extended AI context including goals, needs, and memories
    var aiContextWithBehavior: String {
        var context = aiContextWithEmotions

        // Goals
        if let primary = primaryGoal {
            context += "\n  Primary goal: \(primary.goalType.displayName)"
            if let targetId = primary.targetCharacterId {
                context += " (target: \(targetId))"
            }
        }

        // Needs
        let needs = npcNeeds
        if needs.hasCriticalNeed {
            context += "\n  Critical need: \(needs.mostUrgentNeed.displayName) (\(needs.value(for: needs.mostUrgentNeed)))"
        }

        // True believer / Disillusioned
        if isTrueBeliever {
            context += "\n  True Party believer"
        } else if isDisillusioned {
            context += "\n  Disillusioned with the Party"
        }

        return context
    }
}
