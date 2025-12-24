//
//  Game.swift
//  Nomenklatura
//
//  Core game state model
//

import Foundation
import SwiftData

@Model
final class Game {
    // MARK: - Shared Encoders (Performance Optimization)
    // JSONDecoder/JSONEncoder are Sendable, safe to use across actor boundaries
    private static let sharedDecoder = JSONDecoder()
    private static let sharedEncoder = JSONEncoder()

    // MARK: - Transient Caches (Not Persisted)
    @Transient private var _pendingDynamicEventsCache: [DynamicEvent]?
    @Transient private var _dynamicEventCooldownsCache: [String: Int]?
    @Transient private var _pendingProjectsCache: [PendingProject]?
    @Transient private var _activeShowTrialsCache: [ShowTrial]?
    @Transient private var _earnedBadgesCache: [EarnedBadge]?
    @Transient private var _trackAffinityCache: TrackAffinityScores?
    @Transient private var _activePlotThreadsCache: [PlotThread]?
    @Transient private var _resolvedPlotThreadsCache: [PlotThread]?
    @Transient private var _aggregatedPolicyEffectsCache: PolicyEffects?
    @Transient private var _patronCache: GameCharacter?
    @Transient private var _rivalCache: GameCharacter?
    @Attribute(.unique) var id: UUID
    var campaignId: String
    var turnNumber: Int
    var phase: String  // briefing, decision, outcome, personalAction

    // National Stats (0-100)
    var stability: Int
    var popularSupport: Int
    var militaryLoyalty: Int
    var eliteLoyalty: Int
    var treasury: Int
    var industrialOutput: Int
    var foodSupply: Int
    var internationalStanding: Int

    // Personal Stats (0-100)
    var standing: Int
    var patronFavor: Int
    var rivalThreat: Int
    var network: Int

    // Reputation traits (0-100)
    var reputationCompetent: Int
    var reputationLoyal: Int
    var reputationCunning: Int
    var reputationRuthless: Int

    // Personal Wealth/Corruption (0-100)
    var personalWealth: Int         // Accumulated wealth from corruption
    var wealthVisibility: Int       // How noticed your wealth is
    var corruptionEvidence: Int     // Documented proof against you

    // Position on ladder (index, 0 = bottom)
    var currentPositionIndex: Int
    var currentTrack: String  // CareerTrack.rawValue - "shared", "capital", "regional"
    var currentExpandedTrack: String = "shared"  // ExpandedCareerTrack.rawValue - specific bureau path
    var actionPoints: Int

    // Policy/Resistance system
    var resistanceAccumulation: Int  // 0-100, danger of backlash from forced policies
    var policiesForced: Int          // Count of decrees issued
    var coalitionStrength: Int       // Opposition power building against player

    // Flags and variables (flexible state)
    var flags: [String]
    var variables: [String: String]
    var usedFallbacks: [String]
    var usedActionsThisTurn: [String]  // Track actions used this turn to prevent repeats
    var characterInteractionsThisTurn: Int  // Limit interactions per turn (max 2)
    var lastInteractionTurn: Int  // Track last turn with character interaction

    // Scenario pacing (persisted for proper variety)
    var consecutiveDecisionEvents: Int  // Tracks how many decisions in a row
    var lastNewspaperTurn: Int          // Last turn newspaper appeared
    var recentScenarioCategories: [String]  // Recent categories for variety

    // Dynamic events system
    var pendingDynamicEventsData: Data?  // Encoded [DynamicEvent]
    var lastDynamicEventTurn: Int        // Last turn a dynamic event fired
    var consecutiveEventTurns: Int       // For pacing - quiet turns after events
    var dynamicEventCooldownsData: Data? // Encoded [String: Int] for type cooldowns

    // Narrative Memory system
    var storySummary: String             // AI-maintained narrative summary (~1500 chars max)
    var activePlotThreadsData: Data?     // Encoded [PlotThread] - ongoing story threads
    var resolvedPlotThreadsData: Data?   // Encoded [PlotThread] - completed threads (for reference)
    var keyNarrativeMoments: [String]    // Most important story beats (max 10, oldest pruned)

    // Game status
    var status: String  // active, won, lost, abandoned
    var endReason: String?

    // Player faction selection
    var playerFactionId: String?  // ID of chosen player faction

    // Track Affinity System (6-track career branching)
    var trackAffinityData: Data?          // Encoded TrackAffinityScores
    var trackCommitmentStatus: String     // TrackCommitmentStatus.rawValue
    var committedTrack: String?           // ExpandedCareerTrack.rawValue if committed
    var trackApexPositionsHeld: [String]  // Track IDs where player held apex position

    // Badge/Achievement System
    var earnedBadgesData: Data?           // Encoded [EarnedBadge]
    var badgeProgressData: Data?          // Encoded badge progress tracking

    // Dynasty/Heir System
    var designatedHeirId: String?         // Character ID of designated heir
    var heirRelationship: String?         // HeirRelationship.rawValue
    var dynastySuccessions: Int           // Number of times dynasty has passed to heir
    var dynastyStartTurn: Int             // Turn the current dynasty started (for tracking)

    // Power Consolidation (for law changes)
    var powerConsolidationScore: Int      // 0-100, accumulated power for institutional changes
    var lawsModifiedCount: Int            // Number of laws player has changed
    var termLimitsAbolished: Bool         // Has player abolished term limits

    // Show Trials System
    var activeShowTrialsData: Data?       // Encoded [ShowTrial] - ongoing show trials

    // Anti-Corruption Campaign System
    var activeAntiCorruptionCampaignData: Data?  // Encoded AntiCorruptionCampaign

    // Journal System (auto-added noteworthy information)
    var journalEntriesData: Data?  // Encoded [JournalEntry]

    // Multi-turn Projects System (construction, reforms, etc.)
    var pendingProjectsData: Data?  // Encoded [PendingProject]

    // Economy System
    var lastEconomicReport: Data?  // Encoded EconomicReport from EconomyService

    // Economic Macro Indicators (1940s-60s era)
    var gdpIndex: Int = 100                    // National Product index (base 100)
    var inflationRate: Int = 5                 // Annual percentage (0-100+)
    var unemploymentRate: Int = 5              // Percentage (0-50)
    var giniCoefficient: Int = 28              // Inequality measure (0-100)
    var tradeBalance: Int = 0                  // Positive = surplus

    // Sector breakdown (percentage of National Product)
    var agricultureShare: Int = 20             // Collective farms, state farms
    var industryShare: Int = 50                // Heavy industry, manufacturing
    var servicesShare: Int = 30                // Retail, services

    // Economic system type (derived from policies)
    var economicSystemType: String = "marketSocialism"  // EconomicSystemType.rawValue

    // Five-Year Plan tracking
    var currentFiveYearPlan: Int = 1           // Which plan we're on (1st, 2nd, etc.)
    var fiveYearPlanYear: Int = 1              // Year within current plan (1-5)
    var planTargetsMet: Int = 0                // Cumulative targets met this plan

    // Economic history (for trends)
    var gdpHistoryData: Data?                  // Encoded [Int] - last 20 turns of GDP
    var inflationHistoryData: Data?            // Encoded [Int] - last 20 turns of inflation rate
    var unemploymentHistoryData: Data?         // Encoded [Int] - last 20 turns of unemployment rate

    // Term/Tenure tracking
    var termsServed: Int                  // Number of complete terms as General Secretary
    var turnsInCurrentPosition: Int       // Turns in current position
    var turnsAsGeneralSecretary: Int      // Total turns as General Secretary

    // Pending position offers (encoded)
    var pendingPositionOffersData: Data?

    // Relationships
    @Relationship(deleteRule: .cascade) var characters: [GameCharacter]
    @Relationship(deleteRule: .cascade) var factions: [GameFaction]
    @Relationship(deleteRule: .cascade) var events: [GameEvent]
    @Relationship(deleteRule: .cascade) var positionHistory: [PositionHolder]
    @Relationship(deleteRule: .cascade) var deskDocuments: [DeskDocument]
    @Relationship(deleteRule: .cascade) var successorRelationships: [SuccessionRelationship]
    @Relationship(deleteRule: .cascade) var purgeCampaigns: [PurgeCampaign]

    // New Relationships - Regions, Countries, Laws
    @Relationship(deleteRule: .cascade) var regions: [Region]
    @Relationship(deleteRule: .cascade) var foreignCountries: [ForeignCountry]
    @Relationship(deleteRule: .cascade) var laws: [Law]
    @Relationship(deleteRule: .cascade) var positionOffers: [PositionOffer]
    @Relationship(deleteRule: .cascade) var tradeAgreements: [TradeAgreement]

    // World Event History (persistent record of international events)
    @Relationship(deleteRule: .cascade) var worldEventHistory: [WorldEventRecord]

    // NPC-to-NPC Relationships (for autonomous political dynamics)
    @Relationship(deleteRule: .cascade) var npcRelationships: [NPCRelationship]

    // Policy Slots (institutional policies across 8 institutions)
    @Relationship(deleteRule: .cascade) var policySlots: [PolicySlot]

    // People's Congress sessions (rubber-stamp legislature)
    @Relationship(deleteRule: .cascade) var congressSessions: [CongressSession]

    // Standing Committee (inner circle of power)
    @Relationship(deleteRule: .cascade) var standingCommittee: StandingCommittee?

    // Historical Sessions (pre-game history Year 1-43)
    @Relationship(deleteRule: .cascade) var historicalSessions: [HistoricalSession]

    var createdAt: Date
    var updatedAt: Date

    init(campaignId: String) {
        self.id = UUID()
        self.campaignId = campaignId
        self.turnNumber = 1
        self.phase = GamePhase.briefing.rawValue

        // Default national stats (will be overridden by campaign config)
        self.stability = 50
        self.popularSupport = 50
        self.militaryLoyalty = 60
        self.eliteLoyalty = 55
        self.treasury = 45
        self.industrialOutput = 50
        self.foodSupply = 40
        self.internationalStanding = 50

        // Default personal stats
        self.standing = 20
        self.patronFavor = 50
        self.rivalThreat = 30
        self.network = 10

        // Default reputation
        self.reputationCompetent = 50
        self.reputationLoyal = 50
        self.reputationCunning = 20
        self.reputationRuthless = 20

        // Default wealth/corruption (start clean)
        self.personalWealth = 0
        self.wealthVisibility = 0
        self.corruptionEvidence = 0

        self.currentPositionIndex = 1  // Junior Politburo Member
        self.currentTrack = CareerTrack.shared.rawValue
        self.currentExpandedTrack = ExpandedCareerTrack.shared.rawValue  // No specific bureau yet
        self.actionPoints = 2

        // Policy/Resistance system
        self.resistanceAccumulation = 0
        self.policiesForced = 0
        self.coalitionStrength = 0

        // Economic macro indicators (Market Socialism starting state)
        self.gdpIndex = 100
        self.inflationRate = 8        // Moderate inflation typical of socialist transition
        self.unemploymentRate = 4     // Low official unemployment
        self.giniCoefficient = 28     // Moderate inequality
        self.tradeBalance = 5         // Slight surplus

        // Sector breakdown (heavy industry emphasis)
        self.agricultureShare = 20
        self.industryShare = 50
        self.servicesShare = 30

        // Economic system
        self.economicSystemType = EconomicSystemType.marketSocialism.rawValue

        // Five-Year Plan (game starts early in first plan)
        self.currentFiveYearPlan = 1
        self.fiveYearPlanYear = 3     // Year 3 of first plan
        self.planTargetsMet = 0

        self.flags = []
        self.variables = [:]
        self.usedFallbacks = []
        self.usedActionsThisTurn = []
        self.characterInteractionsThisTurn = 0
        self.lastInteractionTurn = 0

        // Scenario pacing
        self.consecutiveDecisionEvents = 0
        self.lastNewspaperTurn = 0
        self.recentScenarioCategories = []

        // Dynamic events system
        self.pendingDynamicEventsData = nil
        self.lastDynamicEventTurn = 0
        self.consecutiveEventTurns = 0
        self.dynamicEventCooldownsData = nil

        // Narrative Memory system
        self.storySummary = "A new official begins their career in the Party apparatus."
        self.activePlotThreadsData = nil
        self.resolvedPlotThreadsData = nil
        self.keyNarrativeMoments = []

        self.status = GameStatus.active.rawValue

        // Track Affinity System
        self.trackAffinityData = nil
        self.trackCommitmentStatus = TrackCommitmentStatus.uncommitted.rawValue
        self.committedTrack = nil
        self.trackApexPositionsHeld = []

        // Badge/Achievement System
        self.earnedBadgesData = nil
        self.badgeProgressData = nil

        // Dynasty/Heir System
        self.designatedHeirId = nil
        self.heirRelationship = nil
        self.dynastySuccessions = 0
        self.dynastyStartTurn = 1

        // Power Consolidation
        self.powerConsolidationScore = 0
        self.lawsModifiedCount = 0
        self.termLimitsAbolished = false

        // Term/Tenure tracking
        self.termsServed = 0
        self.turnsInCurrentPosition = 0
        self.turnsAsGeneralSecretary = 0

        // Position offers
        self.pendingPositionOffersData = nil

        self.characters = []
        self.factions = []
        self.events = []
        self.positionHistory = []
        self.successorRelationships = []
        self.purgeCampaigns = []
        self.deskDocuments = []

        // New relationships
        self.regions = []
        self.foreignCountries = []
        self.laws = []
        self.positionOffers = []
        self.tradeAgreements = []

        // World event history
        self.worldEventHistory = []

        // NPC-to-NPC relationships
        self.npcRelationships = []

        // Policy slots (will be populated by PolicyService.initializePolicies)
        self.policySlots = []

        // People's Congress sessions
        self.congressSessions = []

        // Historical sessions (generated on game start)
        self.historicalSessions = []

        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Game Phase

enum GamePhase: String, Codable, CaseIterable {
    case briefing
    case decision
    case outcome
    case personalAction
}

// MARK: - Game Status

enum GameStatus: String, Codable, CaseIterable {
    case active
    case won
    case lost
    case abandoned
}

// MARK: - Career Track

enum CareerTrack: String, Codable, CaseIterable, Sendable {
    case shared     // Positions before branching (Party Official, Junior Politburo) and after merging (Deputy Gen Sec, Gen Sec)
    case capital    // Central apparatus in Washington - ministries, Politburo politics
    case regional   // Provincial/Republic governance - regional first secretaries

    var displayName: String {
        switch self {
        case .shared: return "Party"
        case .capital: return "Washington"
        case .regional: return "Provincial"
        }
    }

    var description: String {
        switch self {
        case .shared:
            return "The common path all Party members travel"
        case .capital:
            return "The halls of power in Washington - ministries, committees, and Politburo intrigue"
        case .regional:
            return "The distant zones and territories - where you build your own power base"
        }
    }
}

// MARK: - Computed Properties

extension Game {
    var currentPhase: GamePhase {
        GamePhase(rawValue: phase) ?? .briefing
    }

    var currentStatus: GameStatus {
        GameStatus(rawValue: status) ?? .active
    }

    var currentCareerTrack: CareerTrack {
        CareerTrack(rawValue: currentTrack) ?? .shared
    }

    /// The player's current specialized bureau/track (e.g., securityServices, foreignAffairs)
    var playerExpandedTrack: ExpandedCareerTrack {
        ExpandedCareerTrack(rawValue: currentExpandedTrack) ?? .shared
    }

    /// Policy abilities available at current position
    var availablePolicyAbilities: [PolicyAbility] {
        PolicyAbility.availableAbilities(forPositionIndex: currentPositionIndex)
    }

    /// Whether player can participate in policy system at all
    var canParticipateInPolicies: Bool {
        currentPositionIndex >= 1  // Junior Politburo or higher
    }

    var nationalStats: [(name: String, value: Int, key: String)] {
        [
            ("Stability", stability, "stability"),
            ("Popular Support", popularSupport, "popularSupport"),
            ("Military Loyalty", militaryLoyalty, "militaryLoyalty"),
            ("Elite Loyalty", eliteLoyalty, "eliteLoyalty"),
            ("Treasury", treasury, "treasury"),
            ("Industrial Output", industrialOutput, "industrialOutput"),
            ("Food Supply", foodSupply, "foodSupply"),
            ("International Standing", internationalStanding, "internationalStanding")
        ]
    }

    var personalStats: [(name: String, value: Int, key: String)] {
        [
            ("Standing", standing, "standing"),
            ("Patron Favor", patronFavor, "patronFavor"),
            ("Rival Threat", rivalThreat, "rivalThreat"),
            ("Network", network, "network")
        ]
    }

    func statLevel(for value: Int) -> StatLevel {
        switch value {
        case 70...: return .high
        case 40..<70: return .medium
        default: return .low
        }
    }

    var patron: GameCharacter? {
        if let cached = _patronCache, cached.isPatron && cached.status == CharacterStatus.active.rawValue {
            return cached
        }
        let found = characters.first { $0.isPatron && $0.status == CharacterStatus.active.rawValue }
        _patronCache = found
        return found
    }

    var primaryRival: GameCharacter? {
        if let cached = _rivalCache, cached.isRival && cached.status == CharacterStatus.active.rawValue {
            return cached
        }
        let found = characters.first { $0.isRival && $0.status == CharacterStatus.active.rawValue }
        _rivalCache = found
        return found
    }

    /// Invalidate character role caches (call when patron/rival changes)
    func invalidateCharacterRoleCaches() {
        _patronCache = nil
        _rivalCache = nil
    }

    /// The player's selected faction configuration
    var playerFaction: PlayerFactionConfig? {
        guard let factionId = playerFactionId else { return nil }
        return PlayerFactionConfig.faction(withId: factionId)
    }

    // MARK: - Policy Slots

    /// Get policy slots for a specific institution
    func policySlots(for institution: Institution) -> [PolicySlot] {
        policySlots.filter { $0.institution == institution }
            .sorted { $0.name < $1.name }
    }

    /// Get a specific policy slot by ID
    func policySlot(withId slotId: String) -> PolicySlot? {
        policySlots.first { $0.slotId == slotId }
    }

    /// Get all current policy effects aggregated (cached)
    var aggregatedPolicyEffects: PolicyEffects {
        if let cached = _aggregatedPolicyEffectsCache { return cached }

        var effects = PolicyEffects()
        for slot in policySlots {
            if let currentOpt = slot.currentOption {
                effects.stabilityModifier += currentOpt.effects.stabilityModifier
                effects.popularSupportModifier += currentOpt.effects.popularSupportModifier
                effects.eliteLoyaltyModifier += currentOpt.effects.eliteLoyaltyModifier
                effects.economicOutputModifier += currentOpt.effects.economicOutputModifier
                effects.militaryLoyaltyModifier += currentOpt.effects.militaryLoyaltyModifier
                effects.internationalStandingModifier += currentOpt.effects.internationalStandingModifier
                effects.securityEffectiveness += currentOpt.effects.securityEffectiveness
                effects.regionalControlModifier += currentOpt.effects.regionalControlModifier

                // Aggregate faction modifiers
                for (factionId, modifier) in currentOpt.effects.factionModifiers {
                    effects.factionModifiers[factionId, default: 0] += modifier
                }

                // Aggregate special flags (any policy enabling counts)
                if currentOpt.effects.enablesDecrees { effects.enablesDecrees = true }
                if currentOpt.effects.enablesPurges { effects.enablesPurges = true }
                if currentOpt.effects.enablesReforms { effects.enablesReforms = true }
                if currentOpt.effects.enablesAutonomy { effects.enablesAutonomy = true }
                if currentOpt.effects.preventsSuccession { effects.preventsSuccession = true }
                if currentOpt.effects.triggersUnrest { effects.triggersUnrest = true }
            }
        }
        _aggregatedPolicyEffectsCache = effects
        return effects
    }

    /// Invalidate policy effects cache (call when policies change)
    func invalidatePolicyCache() {
        _aggregatedPolicyEffectsCache = nil
    }

    /// Invalidate all transient caches (call at turn start or major state change)
    func invalidateAllCaches() {
        _pendingDynamicEventsCache = nil
        _dynamicEventCooldownsCache = nil
        _pendingProjectsCache = nil
        _activeShowTrialsCache = nil
        _earnedBadgesCache = nil
        _trackAffinityCache = nil
        _activePlotThreadsCache = nil
        _resolvedPlotThreadsCache = nil
        _aggregatedPolicyEffectsCache = nil
        _patronCache = nil
        _rivalCache = nil
    }

    /// Count of policies that have been changed from default
    var modifiedPoliciesCount: Int {
        policySlots.filter { $0.hasBeenModified }.count
    }

    /// Whether decrees are currently enabled (by any active policy)
    var decreesEnabled: Bool {
        aggregatedPolicyEffects.enablesDecrees
    }

    /// Whether purges are currently enabled (by any active policy)
    var purgesEnabled: Bool {
        aggregatedPolicyEffects.enablesPurges
    }

    // MARK: - Dynamic Events

    /// Pending dynamic events waiting to be shown (cached)
    var pendingDynamicEvents: [DynamicEvent] {
        get {
            if let cached = _pendingDynamicEventsCache { return cached }
            guard let data = pendingDynamicEventsData else { return [] }
            let decoded = (try? Self.sharedDecoder.decode([DynamicEvent].self, from: data)) ?? []
            _pendingDynamicEventsCache = decoded
            return decoded
        }
        set {
            _pendingDynamicEventsCache = newValue
            pendingDynamicEventsData = try? Self.sharedEncoder.encode(newValue)
        }
    }

    /// Cooldowns by event type (persisted across sessions, cached)
    var dynamicEventCooldowns: [String: Int] {
        get {
            if let cached = _dynamicEventCooldownsCache { return cached }
            guard let data = dynamicEventCooldownsData else { return [:] }
            let decoded = (try? Self.sharedDecoder.decode([String: Int].self, from: data)) ?? [:]
            _dynamicEventCooldownsCache = decoded
            return decoded
        }
        set {
            _dynamicEventCooldownsCache = newValue
            dynamicEventCooldownsData = try? Self.sharedEncoder.encode(newValue)
        }
    }

    /// Add a dynamic event to the pending queue
    func queueDynamicEvent(_ event: DynamicEvent) {
        var current = pendingDynamicEvents
        current.append(event)
        pendingDynamicEvents = current
    }

    /// Get and remove the next pending dynamic event
    func popNextDynamicEvent() -> DynamicEvent? {
        var current = pendingDynamicEvents
        guard !current.isEmpty else { return nil }

        // Sort by priority and return highest
        current.sort { $0.priority > $1.priority }
        let event = current.removeFirst()
        pendingDynamicEvents = current

        // Update tracking
        lastDynamicEventTurn = turnNumber
        consecutiveEventTurns += 1

        // Update type-specific cooldown
        var cooldowns = dynamicEventCooldowns
        cooldowns[event.eventType.rawValue] = turnNumber
        dynamicEventCooldowns = cooldowns

        return event
    }

    /// Check if an event type is on cooldown
    func isEventTypeOnCooldown(_ type: DynamicEventType) -> Bool {
        guard let lastTurn = dynamicEventCooldowns[type.rawValue] else { return false }
        let cooldown = getCooldownForEventType(type)
        return turnNumber - lastTurn < cooldown
    }

    private func getCooldownForEventType(_ type: DynamicEventType) -> Int {
        switch type {
        case .patronDirective: return 3
        case .characterSummons: return 4
        case .rivalAction: return 5      // Increased to prevent frequent rival harassment
        case .consequenceCallback: return 2
        case .characterMessage: return 3  // Increased from 2 to space out character interactions
        case .ambientTension: return 3
        case .urgentInterruption: return 2
        case .networkIntel: return 3
        case .allyRequest: return 3
        case .worldNews: return 2
        }
    }

    /// Reset consecutive event counter (call on quiet turn)
    func resetEventPacing() {
        consecutiveEventTurns = 0
    }

    /// Whether we should force a quiet turn based on pacing
    var shouldForceQuietTurn: Bool {
        consecutiveEventTurns >= 2
    }

    // MARK: - Pending Projects (Multi-turn events)

    /// Active projects that span multiple turns (cached)
    var pendingProjects: [PendingProject] {
        get {
            if let cached = _pendingProjectsCache { return cached }
            guard let data = pendingProjectsData else { return [] }
            let decoded = (try? Self.sharedDecoder.decode([PendingProject].self, from: data)) ?? []
            _pendingProjectsCache = decoded
            return decoded
        }
        set {
            _pendingProjectsCache = newValue
            pendingProjectsData = try? Self.sharedEncoder.encode(newValue)
        }
    }

    /// Add a new project
    func addProject(_ project: PendingProject) {
        var current = pendingProjects
        current.append(project)
        pendingProjects = current
    }

    /// Update a project by ID
    func updateProject(_ project: PendingProject) {
        var current = pendingProjects
        if let index = current.firstIndex(where: { $0.id == project.id }) {
            current[index] = project
            pendingProjects = current
        }
    }

    /// Remove a project by ID
    func removeProject(withId projectId: UUID) {
        var current = pendingProjects
        current.removeAll { $0.id == projectId }
        pendingProjects = current
    }

    /// Get projects that are completing this turn
    func projectsCompletingThisTurn() -> [PendingProject] {
        pendingProjects.filter { $0.shouldComplete(currentTurn: turnNumber) }
    }

    /// Get active (in-progress) projects
    var activeProjects: [PendingProject] {
        pendingProjects.filter { $0.status == .inProgress }
    }

    /// Check if there's a project with matching keywords
    func hasActiveProject(withKeyword keyword: String) -> Bool {
        activeProjects.contains { $0.keywords.contains(keyword.lowercased()) }
    }

    // MARK: - Character Interaction Limits

    /// Maximum character interactions allowed per turn
    static let maxInteractionsPerTurn = 2

    /// Whether player can still interact with characters this turn
    var canInteractWithCharacters: Bool {
        // Reset counter if turn changed
        if lastInteractionTurn != turnNumber {
            return true
        }
        return characterInteractionsThisTurn < Game.maxInteractionsPerTurn
    }

    /// Remaining interactions this turn
    var remainingInteractionsThisTurn: Int {
        if lastInteractionTurn != turnNumber {
            return Game.maxInteractionsPerTurn
        }
        return max(0, Game.maxInteractionsPerTurn - characterInteractionsThisTurn)
    }

    /// Record that an interaction was used this turn
    func useCharacterInteraction() {
        if lastInteractionTurn != turnNumber {
            // New turn, reset counter
            characterInteractionsThisTurn = 1
            lastInteractionTurn = turnNumber
        } else {
            characterInteractionsThisTurn += 1
        }
        updatedAt = Date()
    }

    /// Reset interaction counter for new turn (called in GameEngine)
    func resetInteractionsForNewTurn() {
        characterInteractionsThisTurn = 0
        lastInteractionTurn = turnNumber
    }

    // MARK: - Show Trials System

    /// Active show trials in progress (cached)
    var activeShowTrials: [ShowTrial] {
        get {
            if let cached = _activeShowTrialsCache { return cached }
            guard let data = activeShowTrialsData else { return [] }
            let decoded = (try? Self.sharedDecoder.decode([ShowTrial].self, from: data)) ?? []
            _activeShowTrialsCache = decoded
            return decoded
        }
        set {
            _activeShowTrialsCache = newValue
            activeShowTrialsData = try? Self.sharedEncoder.encode(newValue)
        }
    }

    /// Add a new show trial
    func initiateShowTrial(_ trial: ShowTrial) {
        var trials = activeShowTrials
        trials.append(trial)
        activeShowTrials = trials
    }

    /// Update an existing show trial
    func updateShowTrial(_ trial: ShowTrial) {
        var trials = activeShowTrials
        if let index = trials.firstIndex(where: { $0.id == trial.id }) {
            trials[index] = trial
            activeShowTrials = trials
        }
    }

    /// Remove a completed show trial
    func completeShowTrial(id: UUID) {
        var trials = activeShowTrials
        trials.removeAll { $0.id == id }
        activeShowTrials = trials
    }

    /// Get trial for a specific defendant
    func getTrialForDefendant(_ characterId: UUID) -> ShowTrial? {
        activeShowTrials.first { $0.defendantId == characterId }
    }

    // MARK: - Anti-Corruption Campaign System

    /// Active anti-corruption campaign (if any)
    var activeAntiCorruptionCampaign: AntiCorruptionCampaign? {
        get {
            guard let data = activeAntiCorruptionCampaignData else { return nil }
            return try? JSONDecoder().decode(AntiCorruptionCampaign.self, from: data)
        }
        set {
            if let campaign = newValue {
                activeAntiCorruptionCampaignData = try? JSONEncoder().encode(campaign)
            } else {
                activeAntiCorruptionCampaignData = nil
            }
        }
    }

    /// Launch a new anti-corruption campaign
    func launchAntiCorruptionCampaign(_ campaign: AntiCorruptionCampaign) {
        activeAntiCorruptionCampaign = campaign
    }

    /// End the current campaign
    func endAntiCorruptionCampaign() {
        activeAntiCorruptionCampaign = nil
    }
}

// MARK: - Stat Level

enum StatLevel {
    case high, medium, low

    var color: String {
        switch self {
        case .high: return "statHigh"
        case .medium: return "statMedium"
        case .low: return "statLow"
        }
    }
}

// MARK: - Stat Modifications

extension Game {
    func applyStat(_ key: String, change: Int) {
        let oldValue: Int
        let newValue: Int

        switch key {
        case "stability":
            oldValue = stability
            stability = clampStat(stability + change)
            newValue = stability
        case "popularSupport":
            oldValue = popularSupport
            popularSupport = clampStat(popularSupport + change)
            newValue = popularSupport
        case "militaryLoyalty":
            oldValue = militaryLoyalty
            militaryLoyalty = clampStat(militaryLoyalty + change)
            newValue = militaryLoyalty
        case "eliteLoyalty":
            oldValue = eliteLoyalty
            eliteLoyalty = clampStat(eliteLoyalty + change)
            newValue = eliteLoyalty
        case "treasury":
            oldValue = treasury
            treasury = clampStat(treasury + change)
            newValue = treasury
        case "industrialOutput":
            oldValue = industrialOutput
            industrialOutput = clampStat(industrialOutput + change)
            newValue = industrialOutput
        case "foodSupply":
            oldValue = foodSupply
            foodSupply = clampStat(foodSupply + change)
            newValue = foodSupply
        case "internationalStanding":
            oldValue = internationalStanding
            internationalStanding = clampStat(internationalStanding + change)
            newValue = internationalStanding
        case "standing":
            oldValue = standing
            standing = clampStat(standing + change)
            newValue = standing
        case "patronFavor":
            oldValue = patronFavor
            patronFavor = clampStat(patronFavor + change)
            newValue = patronFavor
        case "rivalThreat":
            oldValue = rivalThreat
            rivalThreat = clampStat(rivalThreat + change)
            newValue = rivalThreat
        case "network":
            oldValue = network
            network = clampStat(network + change)
            newValue = network
        case "reputationCompetent":
            oldValue = reputationCompetent
            reputationCompetent = clampStat(reputationCompetent + change)
            newValue = reputationCompetent
        case "reputationLoyal":
            oldValue = reputationLoyal
            reputationLoyal = clampStat(reputationLoyal + change)
            newValue = reputationLoyal
        case "reputationCunning":
            oldValue = reputationCunning
            reputationCunning = clampStat(reputationCunning + change)
            newValue = reputationCunning
        case "reputationRuthless":
            oldValue = reputationRuthless
            reputationRuthless = clampStat(reputationRuthless + change)
            newValue = reputationRuthless
        case "personalWealth":
            oldValue = personalWealth
            personalWealth = clampStat(personalWealth + change)
            newValue = personalWealth
        case "wealthVisibility":
            oldValue = wealthVisibility
            wealthVisibility = clampStat(wealthVisibility + change)
            newValue = wealthVisibility
        case "corruptionEvidence":
            oldValue = corruptionEvidence
            corruptionEvidence = clampStat(corruptionEvidence + change)
            newValue = corruptionEvidence
        default:
            oldValue = 0
            newValue = 0
        }

        // Check for critical stat levels and notify
        checkStatCritical(key: key, oldValue: oldValue, newValue: newValue)

        updatedAt = Date()
    }

    /// Check if a stat has reached a critical threshold and notify
    private func checkStatCritical(key: String, oldValue: Int, newValue: Int) {
        let statName = formatStatName(key)

        // Critical low threshold (crossed into danger zone)
        let lowThreshold = 25
        // Critical high threshold for negative stats like rivalThreat
        let highThreshold = 75

        // Stats where HIGH is bad
        let negativeStats = ["rivalThreat", "wealthVisibility", "corruptionEvidence"]

        if negativeStats.contains(key) {
            // For negative stats, crossing above highThreshold is critical
            if oldValue < highThreshold && newValue >= highThreshold {
                NotificationService.shared.notifyStatCritical(
                    statName: statName,
                    value: newValue,
                    isLow: false,
                    turn: turnNumber
                )
            }
        } else {
            // For positive stats, crossing below lowThreshold is critical
            if oldValue > lowThreshold && newValue <= lowThreshold {
                NotificationService.shared.notifyStatCritical(
                    statName: statName,
                    value: newValue,
                    isLow: true,
                    turn: turnNumber
                )
            }
        }
    }

    /// Format stat key to display name
    private func formatStatName(_ key: String) -> String {
        switch key {
        case "stability": return "Stability"
        case "popularSupport": return "Popular Support"
        case "militaryLoyalty": return "Military Loyalty"
        case "eliteLoyalty": return "Elite Loyalty"
        case "treasury": return "Treasury"
        case "industrialOutput": return "Industrial Output"
        case "foodSupply": return "Food Supply"
        case "internationalStanding": return "International Standing"
        case "standing": return "Standing"
        case "patronFavor": return "Patron Favor"
        case "rivalThreat": return "Rival Threat"
        case "network": return "Network"
        case "reputationCompetent": return "Competence"
        case "reputationLoyal": return "Loyalty"
        case "reputationCunning": return "Cunning"
        case "reputationRuthless": return "Ruthlessness"
        case "personalWealth": return "Personal Wealth"
        case "wealthVisibility": return "Wealth Visibility"
        case "corruptionEvidence": return "Corruption Evidence"
        default: return key
        }
    }

    private func clampStat(_ value: Int) -> Int {
        max(0, min(100, value))
    }

    // MARK: - Narrative Memory Helpers

    /// Get active plot threads (cached)
    func getActivePlotThreads() -> [PlotThread] {
        if let cached = _activePlotThreadsCache { return cached }
        guard let data = activePlotThreadsData else { return [] }
        let decoded = (try? Self.sharedDecoder.decode([PlotThread].self, from: data)) ?? []
        _activePlotThreadsCache = decoded
        return decoded
    }

    /// Set active plot threads
    func setActivePlotThreads(_ threads: [PlotThread]) {
        _activePlotThreadsCache = threads
        activePlotThreadsData = try? Self.sharedEncoder.encode(threads)
    }

    /// Get resolved plot threads (cached)
    func getResolvedPlotThreads() -> [PlotThread] {
        if let cached = _resolvedPlotThreadsCache { return cached }
        guard let data = resolvedPlotThreadsData else { return [] }
        let decoded = (try? Self.sharedDecoder.decode([PlotThread].self, from: data)) ?? []
        _resolvedPlotThreadsCache = decoded
        return decoded
    }

    /// Add or update a plot thread
    func updatePlotThread(_ thread: PlotThread) {
        var threads = getActivePlotThreads()
        if let index = threads.firstIndex(where: { $0.id == thread.id }) {
            threads[index] = thread
        } else {
            threads.append(thread)
        }
        setActivePlotThreads(threads)
    }

    /// Resolve a plot thread (move to resolved list)
    func resolvePlotThread(id: String, resolution: String) {
        var active = getActivePlotThreads()
        guard let index = active.firstIndex(where: { $0.id == id }) else { return }

        var thread = active.remove(at: index)
        thread.status = .resolved
        thread.resolution = resolution
        thread.turnResolved = turnNumber

        var resolved = getResolvedPlotThreads()
        resolved.append(thread)

        setActivePlotThreads(active)
        _resolvedPlotThreadsCache = resolved
        resolvedPlotThreadsData = try? Self.sharedEncoder.encode(resolved)
    }

    /// Add a key narrative moment (maintains max 10, removes oldest)
    func addKeyMoment(_ moment: String) {
        keyNarrativeMoments.append(moment)
        if keyNarrativeMoments.count > 10 {
            keyNarrativeMoments.removeFirst()
        }
    }

    /// Update story summary (called after significant events)
    func appendToStorySummary(_ addition: String) {
        // Keep summary under ~1500 chars by trimming oldest content
        let newSummary = storySummary + " " + addition
        if newSummary.count > 1500 {
            // Find first sentence boundary after first 300 chars and trim
            let trimPoint = newSummary.index(newSummary.startIndex, offsetBy: 300)
            if let periodIndex = newSummary[trimPoint...].firstIndex(of: ".") {
                storySummary = String(newSummary[newSummary.index(after: periodIndex)...]).trimmingCharacters(in: .whitespaces)
            } else {
                storySummary = String(newSummary.suffix(1200))
            }
        } else {
            storySummary = newSummary
        }
    }
}

// MARK: - Plot Thread Model

struct PlotThread: Codable, Identifiable {
    var id: String                    // Unique identifier (e.g., "grain_crisis_t5")
    var title: String                 // "The Northern Grain Crisis"
    var summary: String               // Brief description
    var status: PlotStatus
    var turnIntroduced: Int
    var turnResolved: Int?
    var resolution: String?           // How it ended
    var keyCharacters: [String]       // Character names involved
    var relatedEventIds: [String]     // GameEvent IDs

    init(id: String, title: String, summary: String, turnIntroduced: Int, keyCharacters: [String] = []) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = .active
        self.turnIntroduced = turnIntroduced
        self.keyCharacters = keyCharacters
        self.relatedEventIds = []
    }
}

enum PlotStatus: String, Codable {
    case active       // Ongoing, can be continued
    case dormant      // Temporarily quiet, may resurface
    case resolved     // Concluded
    case abandoned    // Player ignored it, faded away
}

// MARK: - Track Affinity Helpers

extension Game {
    /// Current track affinity scores (cached)
    var trackAffinityScores: TrackAffinityScores {
        get {
            if let cached = _trackAffinityCache { return cached }
            guard let data = trackAffinityData else { return TrackAffinityScores() }
            let decoded = (try? Self.sharedDecoder.decode(TrackAffinityScores.self, from: data)) ?? TrackAffinityScores()
            _trackAffinityCache = decoded
            return decoded
        }
        set {
            _trackAffinityCache = newValue
            trackAffinityData = try? Self.sharedEncoder.encode(newValue)
        }
    }

    /// Current track commitment status
    var currentTrackCommitment: TrackCommitmentStatus {
        TrackCommitmentStatus(rawValue: trackCommitmentStatus) ?? .uncommitted
    }

    /// The track the player has committed to (if any)
    var currentCommittedTrack: ExpandedCareerTrack? {
        guard let track = committedTrack else { return nil }
        return ExpandedCareerTrack(rawValue: track)
    }

    /// Update affinity for a track
    func addTrackAffinity(track: ExpandedCareerTrack, amount: Int, source: AffinitySignal.AffinitySource, description: String) {
        var scores = trackAffinityScores
        scores.addScore(for: track, amount: amount)
        trackAffinityScores = scores

        // Check if a dominant track has emerged
        updateTrackCommitmentStatus()
    }

    /// Update commitment status based on current affinities
    private func updateTrackCommitmentStatus() {
        let scores = trackAffinityScores

        if currentTrackCommitment == .uncommitted {
            if scores.dominantTrack != nil {
                // Emerging preference detected
                trackCommitmentStatus = TrackCommitmentStatus.emerging.rawValue
            }
        }
    }

    /// Commit to a specific track
    func commitToTrack(_ track: ExpandedCareerTrack) {
        committedTrack = track.rawValue
        trackCommitmentStatus = TrackCommitmentStatus.committed.rawValue
        updatedAt = Date()
    }

    /// Record that player held an apex position in a track
    func recordApexPosition(track: ExpandedCareerTrack) {
        if !trackApexPositionsHeld.contains(track.rawValue) {
            trackApexPositionsHeld.append(track.rawValue)
            updatedAt = Date()
        }
    }

    /// Number of unique tracks where player held apex position
    var uniqueApexTracksHeld: Int {
        trackApexPositionsHeld.count
    }
}

// MARK: - Badge System Helpers

extension Game {
    /// Earned badges list (cached)
    var earnedBadges: [EarnedBadge] {
        get {
            if let cached = _earnedBadgesCache { return cached }
            guard let data = earnedBadgesData else { return [] }
            let decoded = (try? Self.sharedDecoder.decode([EarnedBadge].self, from: data)) ?? []
            _earnedBadgesCache = decoded
            return decoded
        }
        set {
            _earnedBadgesCache = newValue
            earnedBadgesData = try? Self.sharedEncoder.encode(newValue)
        }
    }

    /// Award a badge to the player
    func awardBadge(_ badgeId: String, circumstance: String? = nil) {
        // Check if already earned
        guard !earnedBadges.contains(where: { $0.badgeId == badgeId }) else { return }

        let config = CampaignLoader.shared.getColdWarCampaign()
        let currentPosition = config.ladder.first(where: { $0.index == currentPositionIndex })

        let badge = EarnedBadge(
            badgeId: badgeId,
            turnEarned: turnNumber,
            positionWhenEarned: currentPosition?.title,
            circumstance: circumstance
        )

        var badges = earnedBadges
        badges.append(badge)
        earnedBadges = badges

        // Notify player
        if let definition = BadgeRegistry.badge(withId: badgeId) {
            NotificationService.shared.notifyBadgeEarned(
                name: definition.name,
                tier: definition.tier.displayName,
                turn: turnNumber
            )
        }

        updatedAt = Date()
    }

    /// Check if player has earned a specific badge
    func hasBadge(_ badgeId: String) -> Bool {
        earnedBadges.contains { $0.badgeId == badgeId }
    }

    /// Get all earned badges of a specific tier
    func badges(ofTier tier: BadgeTier) -> [EarnedBadge] {
        earnedBadges.filter { badge in
            BadgeRegistry.badge(withId: badge.badgeId)?.tier == tier
        }
    }

    /// Check and award any newly earned badges
    func checkAndAwardNewBadges() {
        let newBadges = BadgeChecker.checkNewBadges(game: self, earnedBadges: earnedBadges)
        for badge in newBadges {
            awardBadge(badge.id)
        }
    }
}

// MARK: - Dynasty/Heir System Helpers

extension Game {
    /// Whether player has a designated heir
    var hasDesignatedHeir: Bool {
        designatedHeirId != nil
    }

    /// Get the designated heir character
    var designatedHeir: GameCharacter? {
        guard let heirId = designatedHeirId else { return nil }
        return characters.first { $0.id.uuidString == heirId }
    }

    /// Current heir relationship type
    var currentHeirRelationship: HeirRelationship? {
        guard let rel = heirRelationship else { return nil }
        return HeirRelationship(rawValue: rel)
    }

    /// Designate a character as heir
    func designateHeir(_ character: GameCharacter, relationship: HeirRelationship) {
        designatedHeirId = character.id.uuidString
        heirRelationship = relationship.rawValue

        // Store in variables for game over check compatibility
        variables["designated_heir_id"] = character.id.uuidString

        updatedAt = Date()
    }

    /// Remove heir designation
    func removeHeirDesignation() {
        designatedHeirId = nil
        heirRelationship = nil
        variables.removeValue(forKey: "designated_heir_id")
        updatedAt = Date()
    }

    /// Process succession to heir (called when player dies but has heir)
    func processSuccessionToHeir() -> Bool {
        guard let heir = designatedHeir,
              heir.status == CharacterStatus.active.rawValue,
              let relationship = currentHeirRelationship else {
            return false
        }

        // Calculate inheritance
        let inheritMultiplier = relationship.inheritanceMultiplier

        // Apply succession penalty
        let newStanding = Int(Double(standing) * inheritMultiplier)
        let newNetwork = Int(Double(network) * inheritMultiplier)

        standing = max(15, newStanding)  // Minimum standing to not immediately fail
        network = max(5, newNetwork)

        // Patron favor resets (new person, new relationships)
        patronFavor = 40

        // Rival threat reduced (new target)
        rivalThreat = max(20, rivalThreat - 30)

        // Record succession
        dynastySuccessions += 1
        flags.append("succession_\(dynastySuccessions)")

        // Award dynasty badge if first succession
        if dynastySuccessions == 1 {
            awardBadge("dynasty_founder", circumstance: "Your heir \(heir.name) continues your legacy")
        }

        // Clear heir (need to designate new one)
        designatedHeirId = nil
        heirRelationship = nil
        variables.removeValue(forKey: "designated_heir_id")

        // Update story
        appendToStorySummary("Following the death of their predecessor, \(heir.name) has taken control of the political dynasty.")

        updatedAt = Date()
        return true
    }
}

// MARK: - Power Consolidation Helpers

extension Game {
    /// Calculate current power consolidation score based on game state
    func calculatePowerConsolidation() -> Int {
        var score = 0

        // Base from stats
        score += standing / 4           // Max 25
        score += eliteLoyalty / 5       // Max 20
        score += network / 5            // Max 20

        // Position power
        if currentPositionIndex >= 7 {  // General Secretary
            score += 20
        } else if currentPositionIndex >= 6 {  // Deputy General Secretary
            score += 10
        } else if currentPositionIndex >= 4 {
            score += 5
        }

        // Laws already modified (each shows willingness to use power)
        score += lawsModifiedCount * 3  // Max varies

        // Patron support
        if patronFavor > 70 {
            score += 5
        }

        // Military backing
        if militaryLoyalty > 70 {
            score += 10
        }

        // Reduce for opposition
        score -= coalitionStrength / 4

        return max(0, min(100, score))
    }

    /// Whether player has enough power to modify a law
    func canModifyLaw(_ law: Law, to newState: LawState) -> Bool {
        let requirements = LawChangeRequirement.requirements(for: law, toState: newState)
        let currentPower = calculatePowerConsolidation()
        return currentPower >= requirements.powerRequired
    }

    /// Whether player can force a law change (decree vs vote)
    func canForceLawChange(_ law: Law, to newState: LawState) -> Bool {
        let requirements = LawChangeRequirement.requirements(for: law, toState: newState)
        guard requirements.canBeForced else { return false }
        let currentPower = calculatePowerConsolidation()
        return currentPower >= requirements.forcePowerRequired
    }

    /// Update power consolidation score
    func updatePowerConsolidation() {
        powerConsolidationScore = calculatePowerConsolidation()
        updatedAt = Date()
    }
}

// MARK: - Region Helpers

extension Game {
    /// Get region by ID
    func region(withId id: String) -> Region? {
        regions.first { $0.regionId == id }
    }

    /// Get capital region
    var capitalRegion: Region? {
        regions.first { $0.type == .capital }
    }

    /// Get all regions in crisis or worse
    var regionsInCrisis: [Region] {
        regions.filter { $0.status.severity >= 2 }
    }

    /// Get all regions actively seceding
    var secedingRegions: [Region] {
        regions.filter { $0.status == .seceding || $0.status == .seceded }
    }

    /// Overall national stability based on regions
    var nationalStabilityFromRegions: Int {
        guard !regions.isEmpty else { return 50 }
        let avgStability = regions.reduce(0) { $0 + $1.stabilityScore } / regions.count
        return avgStability
    }

    /// Check if territorial collapse condition is met
    var hasTerritorialCollapse: Bool {
        let secededCount = regions.filter { $0.status == .seceded }.count
        return secededCount >= 3 // 3+ regions seceded = game over
    }

    /// Process all regions for turn
    func processRegionTurns() {
        let nationalStability = stability
        for region in regions {
            region.updateSecessionProgress(nationalStability: nationalStability, currentTurn: turnNumber)
            region.applyGovernorEffects()
            region.turnsInCurrentStatus += 1
        }
        updatedAt = Date()
    }
}

// MARK: - Foreign Country Helpers

extension Game {
    /// Get country by ID
    func country(withId id: String) -> ForeignCountry? {
        foreignCountries.first { $0.countryId == id }
    }

    /// Get all countries in a bloc
    func countries(inBloc bloc: PoliticalBloc) -> [ForeignCountry] {
        foreignCountries.filter { $0.politicalBloc == bloc }
    }

    /// Get all allied countries
    var alliedCountries: [ForeignCountry] {
        foreignCountries.filter { $0.isAlly }
    }

    /// Get all hostile countries
    var hostileCountries: [ForeignCountry] {
        foreignCountries.filter { $0.isEnemy }
    }

    /// Get countries bordering our regions
    var borderingCountries: [ForeignCountry] {
        foreignCountries.filter { $0.borderingRegionId != nil }
    }

    /// Overall international standing based on relationships
    var internationalStandingFromRelations: Int {
        guard !foreignCountries.isEmpty else { return 50 }
        let avgRelation = foreignCountries.reduce(0) { $0 + $1.relationshipScore } / foreignCountries.count
        return max(0, min(100, 50 + avgRelation / 2))
    }
}

// MARK: - World Event Helpers

extension Game {
    /// Record a new world event to history
    func recordWorldEvent(_ event: WorldEvent) {
        let record = WorldEventRecord(event: event)
        record.game = self
        worldEventHistory.append(record)
    }

    /// Get recent world events (decoded from records)
    func recentWorldEvents(turns: Int = 3) -> [WorldEvent] {
        let minTurn = max(1, turnNumber - turns + 1)
        return worldEventHistory
            .filter { $0.turnOccurred >= minTurn }
            .sorted { $0.turnOccurred > $1.turnOccurred }
            .compactMap { $0.event }
    }

    /// Get world events for a specific turn
    func worldEventsForTurn(_ turn: Int) -> [WorldEvent] {
        worldEventHistory
            .filter { $0.turnOccurred == turn }
            .compactMap { $0.event }
    }

    /// Get world events for a specific country
    func worldEventsForCountry(_ countryId: String) -> [WorldEvent] {
        worldEventHistory
            .filter { $0.countryId == countryId }
            .sorted { $0.turnOccurred > $1.turnOccurred }
            .compactMap { $0.event }
    }

    /// Get unread world events
    func unreadWorldEvents() -> [WorldEvent] {
        worldEventHistory
            .filter { !$0.hasBeenRead }
            .compactMap { $0.event }
    }

    /// Mark a world event as read
    func markWorldEventRead(id: String) {
        if let record = worldEventHistory.first(where: { $0.id.uuidString == id }) {
            record.hasBeenRead = true
        }
    }

    /// Get the most severe recent events (for newspaper headlines)
    func majorWorldEvents(turns: Int = 1) -> [WorldEvent] {
        recentWorldEvents(turns: turns)
            .filter { $0.severity >= .significant }
            .sorted { $0.severity > $1.severity }
    }

    /// Get unclassified events suitable for state press
    func publicWorldEvents(turns: Int = 1) -> [WorldEvent] {
        recentWorldEvents(turns: turns)
            .filter { !$0.isClassified }
    }
}

// MARK: - Law Helpers

extension Game {
    /// Get law by ID
    func law(withId id: String) -> Law? {
        laws.first { $0.lawId == id }
    }

    /// Get all modified laws
    var modifiedLaws: [Law] {
        laws.filter { $0.hasBeenModified }
    }

    /// Get laws by category
    func laws(inCategory category: LawCategory) -> [Law] {
        laws.filter { $0.lawCategory == category }
    }

    /// Get the term limits law specifically
    var termLimitsLaw: Law? {
        law(withId: "term_limits")
    }

    /// Check if term limits are still in effect
    var hasTermLimits: Bool {
        guard let law = termLimitsLaw else { return true }
        return law.lawCurrentState != .abolished
    }

    /// Check if player has exceeded term limits
    var hasExceededTermLimits: Bool {
        guard hasTermLimits else { return false }
        // 2 terms * 4 years * 4 turns per year = 32 turns
        let maxTurns = 32
        return turnsAsGeneralSecretary > maxTurns
    }

    /// Get all pending consequences across all laws
    var allPendingConsequences: [(law: Law, consequence: ScheduledConsequence)] {
        var result: [(Law, ScheduledConsequence)] = []
        for law in laws {
            for consequence in law.pendingConsequences {
                result.append((law, consequence))
            }
        }
        return result.sorted { $0.1.triggerTurn < $1.1.triggerTurn }
    }

    /// Get consequences due this turn
    func consequencesDueThisTurn() -> [(law: Law, consequence: ScheduledConsequence)] {
        allPendingConsequences.filter { $0.consequence.triggerTurn <= turnNumber }
    }
}

// MARK: - Position Offer Helpers

extension Game {
    /// Get all pending position offers
    var pendingOffers: [PositionOffer] {
        positionOffers.filter { $0.isPending }
    }

    /// Whether player has any pending offers
    var hasPendingOffers: Bool {
        !pendingOffers.isEmpty
    }

    /// Get offers expiring soon (1 turn left)
    var urgentOffers: [PositionOffer] {
        positionOffers.filter { $0.isPending && $0.isUrgent }
    }

    /// Process offer expirations
    func processOfferExpirations() {
        for offer in positionOffers where offer.isPending {
            offer.checkExpiration(currentTurn: turnNumber)
        }
        updatedAt = Date()
    }

    /// Add a new position offer
    func addPositionOffer(_ offer: PositionOffer) {
        positionOffers.append(offer)
        offer.game = self
        updatedAt = Date()
    }
}

// MARK: - Trade Agreement Helpers

extension Game {
    /// Get all active trade agreements
    var activeTradeAgreements: [TradeAgreement] {
        tradeAgreements.filter { $0.isActive }
    }

    /// Get agreements with a specific country
    func agreements(with countryId: String) -> [TradeAgreement] {
        tradeAgreements.filter { $0.partnerCountryId == countryId }
    }

    /// Net economic impact from all trade agreements
    var netTradeImpact: Int {
        activeTradeAgreements.reduce(0) { $0 + $1.netEconomicImpact }
    }

    /// Process trade agreements for turn
    func processTradeAgreements() {
        for agreement in tradeAgreements {
            if agreement.isActive {
                agreement.processTurn()
                agreement.checkExpiration(currentTurn: turnNumber)

                // Apply effects
                applyStat("treasury", change: agreement.treasuryEffect)
                applyStat("industrialOutput", change: agreement.industrialEffect)
                applyStat("foodSupply", change: agreement.foodEffect)
            }
        }
        updatedAt = Date()
    }
}

// MARK: - Save Repair

extension Game {
    /// Repair inconsistent state where player is at a specialized position but currentExpandedTrack wasn't updated
    /// This can happen due to a bug in earlier versions where promotions didn't set the expanded track
    func repairExpandedTrackIfNeeded(ladder: [LadderPosition]) {
        // Only need to repair if position index is in the specialized range (2-6)
        // and current expanded track is still "shared"
        guard currentPositionIndex >= 2 && currentPositionIndex <= 6,
              currentExpandedTrack == ExpandedCareerTrack.shared.rawValue else {
            return
        }

        // Find what position the player should be at
        // First, check if there's any position that matches index and has a specialized track
        let possiblePositions = ladder.filter {
            $0.index == currentPositionIndex && $0.expandedTrack != .shared
        }

        // If there's only one possible specialized track at this index, use it
        // If multiple, we need to infer from game state (track affinity, events, etc.)
        if possiblePositions.count == 1 {
            let correctTrack = possiblePositions[0].expandedTrack
            currentExpandedTrack = correctTrack.rawValue
            currentTrack = possiblePositions[0].track.rawValue
            if currentTrackCommitment != .committed {
                commitToTrack(correctTrack)
            }
            #if DEBUG
            print("[SaveRepair] Fixed expanded track to \(correctTrack.rawValue)")
            #endif
            updatedAt = Date()
            return
        }

        // Multiple possibilities - check track affinity to infer the most likely track
        let scores = trackAffinityScores
        if let dominantTrack = scores.dominantTrack {
            // Check if there's a position at this index in the dominant track
            if let matchingPosition = possiblePositions.first(where: { $0.expandedTrack == dominantTrack }) {
                currentExpandedTrack = matchingPosition.expandedTrack.rawValue
                currentTrack = matchingPosition.track.rawValue
                if currentTrackCommitment != .committed {
                    commitToTrack(matchingPosition.expandedTrack)
                }
                #if DEBUG
                print("[SaveRepair] Fixed expanded track to \(dominantTrack.rawValue) based on affinity")
                #endif
                updatedAt = Date()
                return
            }
        }

        // If we still can't determine, check if there's a committed track
        if let committed = currentCommittedTrack {
            if let matchingPosition = possiblePositions.first(where: { $0.expandedTrack == committed }) {
                currentExpandedTrack = matchingPosition.expandedTrack.rawValue
                currentTrack = matchingPosition.track.rawValue
                #if DEBUG
                print("[SaveRepair] Fixed expanded track to \(committed.rawValue) based on commitment")
                #endif
                updatedAt = Date()
                return
            }
        }

        // Last resort: pick the first one (usually partyApparatus which is the first specialized track)
        if let firstPosition = possiblePositions.first {
            currentExpandedTrack = firstPosition.expandedTrack.rawValue
            currentTrack = firstPosition.track.rawValue
            if currentTrackCommitment != .committed {
                commitToTrack(firstPosition.expandedTrack)
            }
            #if DEBUG
            print("[SaveRepair] Fixed expanded track to \(firstPosition.expandedTrack.rawValue) (fallback)")
            #endif
            updatedAt = Date()
        }
    }
}

// MARK: - Economic System Helpers

extension Game {
    /// Current economic system type
    var currentEconomicSystem: EconomicSystemType {
        EconomicSystemType(rawValue: economicSystemType) ?? .marketSocialism
    }

    /// GDP history for trend display (last 20 turns)
    var gdpHistory: [Int] {
        get {
            guard let data = gdpHistoryData else { return [] }
            return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
        }
        set {
            // Keep only last 20 entries
            let trimmed = Array(newValue.suffix(20))
            gdpHistoryData = try? JSONEncoder().encode(trimmed)
        }
    }

    /// Record current GDP to history
    func recordGDPToHistory() {
        var history = gdpHistory
        history.append(gdpIndex)
        gdpHistory = history
    }

    /// GDP growth rate (percentage change from previous turn)
    var gdpGrowthRate: Double {
        let history = gdpHistory
        guard history.count >= 2 else { return 0.0 }
        let previous = Double(history[history.count - 2])
        let current = Double(history.last ?? 100)
        guard previous > 0 else { return 0.0 }
        return ((current - previous) / previous) * 100.0
    }

    /// Whether economy is in recession (3+ turns of negative growth)
    var isInRecession: Bool {
        let history = gdpHistory
        guard history.count >= 4 else { return false }
        let recent = Array(history.suffix(4))
        var declines = 0
        for i in 1..<recent.count {
            if recent[i] < recent[i-1] { declines += 1 }
        }
        return declines >= 3
    }

    /// Inflation history for trend display (last 20 turns)
    var inflationHistory: [Int] {
        get {
            guard let data = inflationHistoryData else { return [] }
            return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
        }
        set {
            let trimmed = Array(newValue.suffix(20))
            inflationHistoryData = try? JSONEncoder().encode(trimmed)
        }
    }

    /// Unemployment history for trend display (last 20 turns)
    var unemploymentHistory: [Int] {
        get {
            guard let data = unemploymentHistoryData else { return [] }
            return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
        }
        set {
            let trimmed = Array(newValue.suffix(20))
            unemploymentHistoryData = try? JSONEncoder().encode(trimmed)
        }
    }

    /// Record all economic indicators to history (call once per turn)
    func recordEconomicHistory() {
        recordGDPToHistory()

        var inflation = inflationHistory
        inflation.append(inflationRate)
        inflationHistory = inflation

        var unemployment = unemploymentHistory
        unemployment.append(unemploymentRate)
        unemploymentHistory = unemployment
    }

    /// Economic health score (0-100, composite of all indicators)
    var economicHealthScore: Int {
        var score = 50

        // GDP contribution (base 100 = neutral)
        if gdpIndex > 110 { score += 10 }
        else if gdpIndex > 100 { score += 5 }
        else if gdpIndex < 90 { score -= 10 }
        else if gdpIndex < 100 { score -= 5 }

        // Inflation penalty
        if inflationRate > 30 { score -= 20 }
        else if inflationRate > 15 { score -= 10 }
        else if inflationRate < 5 { score += 5 }

        // Unemployment penalty
        if unemploymentRate > 15 { score -= 15 }
        else if unemploymentRate > 8 { score -= 5 }
        else if unemploymentRate < 3 { score += 5 }

        // Trade balance
        if tradeBalance > 10 { score += 10 }
        else if tradeBalance < -10 { score -= 10 }

        return max(0, min(100, score))
    }

    /// Era-appropriate economic status description
    var economicStatusDescription: String {
        let health = economicHealthScore
        switch health {
        case 80...:
            return "The national economy is thriving. Industrial output exceeds plan targets, and the workers' standard of living improves steadily."
        case 60..<80:
            return "Economic development proceeds satisfactorily. Some sectors face challenges, but overall production remains strong."
        case 40..<60:
            return "The economy shows mixed results. While core industries maintain output, inefficiencies and shortages cause concern."
        case 20..<40:
            return "Economic difficulties mount. Industrial bottlenecks, supply disruptions, and declining productivity threaten stability."
        default:
            return "The national economy is in crisis. Production has collapsed, shortages are widespread, and urgent intervention is required."
        }
    }

    /// Five-Year Plan status
    var fiveYearPlanStatus: String {
        let year = fiveYearPlanYear
        let plan = currentFiveYearPlan
        return "Year \(year) of the \(ordinal(plan)) Five-Year Plan"
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "First"
        case 2: return "Second"
        case 3: return "Third"
        case 4: return "Fourth"
        case 5: return "Fifth"
        default: return "\(n)th"
        }
    }

    /// Advance Five-Year Plan year (call every 4 turns = 1 year)
    func advanceFiveYearPlanYear() {
        fiveYearPlanYear += 1
        if fiveYearPlanYear > 5 {
            // New plan begins
            currentFiveYearPlan += 1
            fiveYearPlanYear = 1
            planTargetsMet = 0
        }
        updatedAt = Date()
    }

    /// Current Five-Year Plan phase (based on year)
    var fiveYearPlanPhase: String {
        switch fiveYearPlanYear {
        case 1: return FiveYearPlanPhase.launching.rawValue
        case 2, 3: return FiveYearPlanPhase.accelerating.rawValue
        case 4: return FiveYearPlanPhase.consolidating.rawValue
        case 5: return FiveYearPlanPhase.completing.rawValue
        default: return FiveYearPlanPhase.launching.rawValue
        }
    }

    /// Apply GDP change
    func applyGDPChange(_ change: Int) {
        gdpIndex = max(50, min(200, gdpIndex + change))
        updatedAt = Date()
    }

    /// Apply inflation change
    func applyInflationChange(_ change: Int) {
        inflationRate = max(0, min(100, inflationRate + change))
        updatedAt = Date()
    }

    /// Apply unemployment change
    func applyUnemploymentChange(_ change: Int) {
        unemploymentRate = max(0, min(50, unemploymentRate + change))
        updatedAt = Date()
    }

    /// Economic stats for display
    var economicStats: [(name: String, value: Int, key: String)] {
        [
            ("National Product", gdpIndex, "gdpIndex"),
            ("Inflation", inflationRate, "inflationRate"),
            ("Unemployment", unemploymentRate, "unemploymentRate"),
            ("Trade Balance", tradeBalance, "tradeBalance")
        ]
    }

    /// Check for economic crisis conditions
    var hasEconomicCrisis: Bool {
        inflationRate >= 50 ||      // Hyperinflation
        unemploymentRate >= 20 ||   // Mass unemployment
        gdpIndex <= 70 ||           // Economic collapse
        (isInRecession && gdpIndex <= 85)  // Prolonged recession
    }

    /// Type of current economic crisis (if any)
    var currentEconomicCrisisType: EconomicCrisisType? {
        if inflationRate >= 50 {
            return .hyperinflation
        } else if unemploymentRate >= 20 {
            return .laborUnrest
        } else if gdpIndex <= 70 {
            return .industrialCollapse
        } else if tradeBalance <= -20 {
            return .tradeBlockade
        }
        return nil
    }
}
