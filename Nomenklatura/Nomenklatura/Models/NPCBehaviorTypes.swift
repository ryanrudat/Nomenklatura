//
//  NPCBehaviorTypes.swift
//  Nomenklatura
//
//  NPC Goals, Needs, Enhanced Memory, and Espionage types
//

import Foundation

// MARK: - NPC Goal Types

/// Goal types that drive NPC long-term behavior
enum NPCGoalType: String, Codable, CaseIterable {
    // Ambition Goals
    case seekPromotion           // Rise to next position level
    case becomeTrackHead         // Reach position 6+ in their track
    case joinPolitburo           // Reach position 7+
    case protectPosition         // Maintain current standing

    // Relationship Goals
    case destroyRival            // Remove specific enemy
    case elevateAlly             // Help specific ally rise
    case avengeBetrayal          // Punish someone who wronged them
    case repayDebt               // Help someone who helped them

    // Power Goals
    case buildFaction            // Create/strengthen power bloc
    case accumulateWealth        // Personal enrichment (corrupt)
    case expandInfluence         // Increase network of supporters

    // Ideological Goals
    case implementReform         // Push specific policy direction
    case maintainOrthodoxy       // Resist change, preserve status quo
    case purgeEnemies            // Remove ideological opponents

    // PARTY DEVOTION Goals (True Believers)
    case serveTheParty           // Party survival is everything
    case defendPartyOrthodoxy    // Protect ideological purity
    case rootOutTraitors         // Find and expose enemies of the Party
    case strengthenTheState      // Build state capacity for Party

    // ESPIONAGE Goals (Foreign Agents)
    case spyForForeignPower      // Pass secrets to foreign country
    case recruitAssets           // Turn others into foreign assets
    case sabotageFromWithin      // Weaken the state for foreign benefit
    case avoidDetection          // Stay hidden as a spy

    // Survival Goals
    case avoidPurge              // Stay safe during instability
    case clearName               // If under investigation
    case escapeDetention         // If detained
    case findProtector           // Secure patron relationship

    // SECURITY Goals (CCDI/MSS Security Services NPCs)
    case investigateCorruption   // CCDI primary mission - find corrupt officials
    case expandSurveillance      // CPLAC coordination - increase monitoring
    case conductPurge            // Recommend anti-corruption campaign
    case buildDossiers           // Gather compromising info for leverage
    case protectPatron           // Shield patron from investigation
    case protectRegime           // Defend current leadership structure
    case eliminateRivals         // Use security apparatus against personal enemies
    case huntForeignSpies        // MSS domain - find foreign agents

    // ECONOMIC Goals (Gosplan/Economic Planning NPCs)
    case meetProductionQuotas    // Primary mission - fulfill assigned targets
    case exceedException         // Go beyond quota for Stakhanovite recognition
    case expandIndustrialOutput  // Grow the industrial base
    case modernizeSector         // Push for technological improvement
    case acquireResources        // Secure resource allocations for region/sector
    case protectBudgetAllocation // Defend ministry/sector funding
    case buildEconomicNetwork    // Create planning connections and favors
    case advanceEconomicReform   // Push for structural changes (risky)

    // MILITARY-POLITICAL Goals (PLA Political Work/Commissar NPCs)
    case ensurePartyCommand      // "Party commands the gun" - maintain political control
    case conductPoliticalWork    // Run ideological education and morale activities
    case evaluateOfficerLoyalty  // Assess political reliability of military personnel
    case purgeDisloyal           // Remove politically unreliable officers
    case enforcePartyDiscipline  // Implement discipline and regulations
    case buildCommissarNetwork   // Create patronage ties among commissars
    case advanceMilitaryReform   // Push for PLA modernization/restructuring
    case preventMilitaryCoup     // Ensure military cannot threaten Party

    // DIPLOMATIC Goals (Foreign Affairs NPCs)
    case improveAllyRelations    // Strengthen socialist bloc ties
    case containCapitalistThreat // Counter Western influence
    case expandTradeNetwork      // Build international economic ties
    case defuseInternationalCrisis // Resolve diplomatic incidents
    case advanceIdeologicalGoals // Spread socialism abroad
    case proposeForeignPolicy    // Submit policy changes to Standing Committee
    case negotiateTreaty         // Work on treaty negotiations

    // PARTY APPARATUS Goals (Central Committee/Organization Department NPCs)
    case controlNomenklatura     // Manage cadre appointments and promotions
    case enforcePropagandaLine   // Ensure correct messaging and ideology
    case conductUnitedFrontWork  // Influence non-party groups and allies
    case runPartySchool          // Train and indoctrinate cadres
    case maintainPartyDiscipline // Internal discipline and self-criticism
    case expandPartyInfluence    // Grow party's reach into civil society
    case buildCadreNetwork       // Create patronage ties among party officials
    case purgeDeviationists      // Remove those who stray from party line

    // STATE MINISTRY Goals (State Council/Ministry NPCs)
    case achieveAdministrativeExcellence  // Improve efficiency and competence
    case secureBudgetAllocation           // Obtain and protect ministry funding
    case advanceMajorProject              // Push infrastructure or development initiatives
    case coordinateAcrossMinistries       // Cross-ministry coordination work
    case implementStatePolicy             // Execute State Council directives
    case auditSubordinateUnits            // Conduct oversight of lower departments
    case modernizeAdministration          // Push administrative reforms
    case buildBureaucraticNetwork         // Create connections across the bureaucracy

    /// Human-readable description
    var displayName: String {
        switch self {
        case .seekPromotion: return "Seeking Promotion"
        case .becomeTrackHead: return "Becoming Track Head"
        case .joinPolitburo: return "Joining Politburo"
        case .protectPosition: return "Protecting Position"
        case .destroyRival: return "Destroying Rival"
        case .elevateAlly: return "Elevating Ally"
        case .avengeBetrayal: return "Avenging Betrayal"
        case .repayDebt: return "Repaying Debt"
        case .buildFaction: return "Building Faction"
        case .accumulateWealth: return "Accumulating Wealth"
        case .expandInfluence: return "Expanding Influence"
        case .implementReform: return "Implementing Reform"
        case .maintainOrthodoxy: return "Maintaining Orthodoxy"
        case .purgeEnemies: return "Purging Enemies"
        case .serveTheParty: return "Serving the Party"
        case .defendPartyOrthodoxy: return "Defending Party Orthodoxy"
        case .rootOutTraitors: return "Rooting Out Traitors"
        case .strengthenTheState: return "Strengthening the State"
        case .spyForForeignPower: return "Foreign Intelligence"
        case .recruitAssets: return "Recruiting Assets"
        case .sabotageFromWithin: return "Sabotage Operations"
        case .avoidDetection: return "Maintaining Cover"
        case .avoidPurge: return "Avoiding Purge"
        case .clearName: return "Clearing Name"
        case .escapeDetention: return "Escaping Detention"
        case .findProtector: return "Finding Protector"
        case .investigateCorruption: return "Investigating Corruption"
        case .expandSurveillance: return "Expanding Surveillance"
        case .conductPurge: return "Conducting Purge"
        case .buildDossiers: return "Building Dossiers"
        case .protectPatron: return "Protecting Patron"
        case .protectRegime: return "Protecting Regime"
        case .eliminateRivals: return "Eliminating Rivals"
        case .huntForeignSpies: return "Hunting Foreign Spies"
        case .meetProductionQuotas: return "Meeting Production Quotas"
        case .exceedException: return "Exceeding Quota"
        case .expandIndustrialOutput: return "Expanding Industrial Output"
        case .modernizeSector: return "Modernizing Sector"
        case .acquireResources: return "Acquiring Resources"
        case .protectBudgetAllocation: return "Protecting Budget"
        case .buildEconomicNetwork: return "Building Economic Network"
        case .advanceEconomicReform: return "Advancing Economic Reform"
        case .ensurePartyCommand: return "Ensuring Party Command"
        case .conductPoliticalWork: return "Conducting Political Work"
        case .evaluateOfficerLoyalty: return "Evaluating Officer Loyalty"
        case .purgeDisloyal: return "Purging Disloyal Officers"
        case .enforcePartyDiscipline: return "Enforcing Party Discipline"
        case .buildCommissarNetwork: return "Building Commissar Network"
        case .advanceMilitaryReform: return "Advancing Military Reform"
        case .preventMilitaryCoup: return "Preventing Military Coup"
        case .improveAllyRelations: return "Improving Ally Relations"
        case .containCapitalistThreat: return "Containing Capitalist Threat"
        case .expandTradeNetwork: return "Expanding Trade Network"
        case .defuseInternationalCrisis: return "Defusing International Crisis"
        case .advanceIdeologicalGoals: return "Advancing Ideological Goals"
        case .proposeForeignPolicy: return "Proposing Foreign Policy"
        case .negotiateTreaty: return "Negotiating Treaty"
        case .controlNomenklatura: return "Controlling Nomenklatura"
        case .enforcePropagandaLine: return "Enforcing Propaganda Line"
        case .conductUnitedFrontWork: return "Conducting United Front Work"
        case .runPartySchool: return "Running Party School"
        case .maintainPartyDiscipline: return "Maintaining Party Discipline"
        case .expandPartyInfluence: return "Expanding Party Influence"
        case .buildCadreNetwork: return "Building Cadre Network"
        case .purgeDeviationists: return "Purging Deviationists"
        case .achieveAdministrativeExcellence: return "Achieving Administrative Excellence"
        case .secureBudgetAllocation: return "Securing Budget Allocation"
        case .advanceMajorProject: return "Advancing Major Project"
        case .coordinateAcrossMinistries: return "Coordinating Across Ministries"
        case .implementStatePolicy: return "Implementing State Policy"
        case .auditSubordinateUnits: return "Auditing Subordinate Units"
        case .modernizeAdministration: return "Modernizing Administration"
        case .buildBureaucraticNetwork: return "Building Bureaucratic Network"
        }
    }

    /// Whether this is a Party devotion goal
    var isPartyDevotionGoal: Bool {
        switch self {
        case .serveTheParty, .defendPartyOrthodoxy, .rootOutTraitors, .strengthenTheState:
            return true
        default:
            return false
        }
    }

    /// Whether this is an espionage-related goal
    var isEspionageGoal: Bool {
        switch self {
        case .spyForForeignPower, .recruitAssets, .sabotageFromWithin, .avoidDetection:
            return true
        default:
            return false
        }
    }

    /// Whether this is a diplomatic/foreign affairs goal
    var isDiplomaticGoal: Bool {
        switch self {
        case .improveAllyRelations, .containCapitalistThreat, .expandTradeNetwork,
             .defuseInternationalCrisis, .advanceIdeologicalGoals, .proposeForeignPolicy,
             .negotiateTreaty:
            return true
        default:
            return false
        }
    }

    /// Whether this is a security/CCDI/MSS goal
    var isSecurityGoal: Bool {
        switch self {
        case .investigateCorruption, .expandSurveillance, .conductPurge,
             .buildDossiers, .protectPatron, .protectRegime,
             .eliminateRivals, .huntForeignSpies:
            return true
        default:
            return false
        }
    }

    /// Whether this is an economic/Gosplan goal
    var isEconomicGoal: Bool {
        switch self {
        case .meetProductionQuotas, .exceedException, .expandIndustrialOutput,
             .modernizeSector, .acquireResources, .protectBudgetAllocation,
             .buildEconomicNetwork, .advanceEconomicReform:
            return true
        default:
            return false
        }
    }

    /// Whether this is a military-political/PLA commissar goal
    var isMilitaryGoal: Bool {
        switch self {
        case .ensurePartyCommand, .conductPoliticalWork, .evaluateOfficerLoyalty,
             .purgeDisloyal, .enforcePartyDiscipline, .buildCommissarNetwork,
             .advanceMilitaryReform, .preventMilitaryCoup:
            return true
        default:
            return false
        }
    }

    /// Whether this is a party apparatus/Organization Department goal
    var isPartyApparatusGoal: Bool {
        switch self {
        case .controlNomenklatura, .enforcePropagandaLine, .conductUnitedFrontWork,
             .runPartySchool, .maintainPartyDiscipline, .expandPartyInfluence,
             .buildCadreNetwork, .purgeDeviationists:
            return true
        default:
            return false
        }
    }

    /// Whether this is a state ministry/State Council goal
    var isStateMinistryGoal: Bool {
        switch self {
        case .achieveAdministrativeExcellence, .secureBudgetAllocation, .advanceMajorProject,
             .coordinateAcrossMinistries, .implementStatePolicy, .auditSubordinateUnits,
             .modernizeAdministration, .buildBureaucraticNetwork:
            return true
        default:
            return false
        }
    }

    /// Whether this goal requires a specific target
    var requiresTarget: Bool {
        switch self {
        case .destroyRival, .elevateAlly, .avengeBetrayal, .repayDebt,
             .eliminateRivals, .protectPatron, .buildDossiers:
            return true
        default:
            return false
        }
    }
}

// MARK: - NPC Goal

/// A specific goal an NPC is pursuing
struct NPCGoal: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var goalType: NPCGoalType
    var targetCharacterId: String?    // For relationship goals
    var priority: Int                  // 1-100, higher = more important
    var progress: Int                  // 0-100, completion progress
    var turnCreated: Int
    var turnDeadline: Int?            // Optional deadline
    var isActive: Bool = true

    // Goal state
    var attemptsCount: Int = 0
    var lastAttemptTurn: Int?
    var frustrationLevel: Int = 0     // Increases with failures

    init(
        goalType: NPCGoalType,
        targetCharacterId: String? = nil,
        priority: Int = 50,
        progress: Int = 0,
        turnCreated: Int = 1,
        turnDeadline: Int? = nil
    ) {
        self.goalType = goalType
        self.targetCharacterId = targetCharacterId
        self.priority = priority
        self.progress = progress
        self.turnCreated = turnCreated
        self.turnDeadline = turnDeadline
    }

    /// Whether this goal has reached critical frustration
    var isFrustrated: Bool {
        frustrationLevel >= 50
    }

    /// Whether this goal is overdue
    func isOverdue(currentTurn: Int) -> Bool {
        guard let deadline = turnDeadline else { return false }
        return currentTurn > deadline
    }

    /// Effective priority accounting for urgency
    func effectivePriority(currentTurn: Int) -> Int {
        var effective = priority

        // Increase priority as deadline approaches
        if let deadline = turnDeadline {
            let turnsRemaining = deadline - currentTurn
            if turnsRemaining <= 3 {
                effective += 20
            } else if turnsRemaining <= 5 {
                effective += 10
            }
        }

        // Frustration slightly increases desperation
        effective += frustrationLevel / 5

        return min(100, effective)
    }
}

// MARK: - NPC Need Types

/// Types of needs that drive NPC behavior
enum NeedType: String, Codable, CaseIterable {
    case security              // Safety from threats
    case power                 // Influence and control
    case loyalty               // Belonging to group/faction
    case recognition           // Status and respect
    case stability             // Predictability
    case ideologicalCommitment // Sense of purpose/belief in Party

    var displayName: String {
        switch self {
        case .security: return "Security"
        case .power: return "Power"
        case .loyalty: return "Loyalty"
        case .recognition: return "Recognition"
        case .stability: return "Stability"
        case .ideologicalCommitment: return "Ideological Commitment"
        }
    }
}

// MARK: - NPC Needs

/// Competing needs that drive NPC behavior
struct NPCNeeds: Sendable {
    var security: Int = 60              // 0-100, feeling of safety
    var power: Int = 50                 // 0-100, sense of influence
    var loyalty: Int = 60               // 0-100, feeling of belonging/allegiance
    var recognition: Int = 50           // 0-100, status and respect
    var stability: Int = 60             // 0-100, predictability, routine
    var ideologicalCommitment: Int = 50 // 0-100, sense of ideological purpose

    private enum CodingKeys: String, CodingKey {
        case security, power, loyalty, recognition, stability, ideologicalCommitment
    }

    init(
        security: Int = 60,
        power: Int = 50,
        loyalty: Int = 60,
        recognition: Int = 50,
        stability: Int = 60,
        ideologicalCommitment: Int = 50
    ) {
        self.security = security
        self.power = power
        self.loyalty = loyalty
        self.recognition = recognition
        self.stability = stability
        self.ideologicalCommitment = ideologicalCommitment
    }

    /// The most urgent (lowest) need
    var mostUrgentNeed: NeedType {
        let needs: [(NeedType, Int)] = [
            (.security, security),
            (.power, power),
            (.loyalty, loyalty),
            (.recognition, recognition),
            (.stability, stability),
            (.ideologicalCommitment, ideologicalCommitment)
        ]
        return needs.min(by: { $0.1 < $1.1 })?.0 ?? .stability
    }

    /// How desperate the NPC is (inverse of lowest need)
    var urgencyLevel: Int {
        return 100 - min(security, power, loyalty, recognition, stability, ideologicalCommitment)
    }

    /// True believers have high ideological commitment
    var isTrueBeliever: Bool {
        return ideologicalCommitment >= 75
    }

    /// Disillusioned characters have low commitment - vulnerable to recruitment
    var isDisillusioned: Bool {
        return ideologicalCommitment <= 25
    }

    /// Whether security need is critical
    var securityCritical: Bool {
        return security < 30
    }

    /// Whether any need is critically low
    var hasCriticalNeed: Bool {
        return min(security, power, loyalty, recognition, stability) < 25
    }

    /// Get the value for a specific need type
    func value(for needType: NeedType) -> Int {
        switch needType {
        case .security: return security
        case .power: return power
        case .loyalty: return loyalty
        case .recognition: return recognition
        case .stability: return stability
        case .ideologicalCommitment: return ideologicalCommitment
        }
    }

    /// Set the value for a specific need type
    mutating func setValue(_ value: Int, for needType: NeedType) {
        let clamped = max(0, min(100, value))
        switch needType {
        case .security: security = clamped
        case .power: power = clamped
        case .loyalty: loyalty = clamped
        case .recognition: recognition = clamped
        case .stability: stability = clamped
        case .ideologicalCommitment: ideologicalCommitment = clamped
        }
    }
}

// MARK: - NPCNeeds Codable Conformance (nonisolated for Swift 6 compatibility)

extension NPCNeeds: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        security = try container.decodeIfPresent(Int.self, forKey: .security) ?? 60
        power = try container.decodeIfPresent(Int.self, forKey: .power) ?? 50
        loyalty = try container.decodeIfPresent(Int.self, forKey: .loyalty) ?? 60
        recognition = try container.decodeIfPresent(Int.self, forKey: .recognition) ?? 50
        stability = try container.decodeIfPresent(Int.self, forKey: .stability) ?? 60
        ideologicalCommitment = try container.decodeIfPresent(Int.self, forKey: .ideologicalCommitment) ?? 50
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(security, forKey: .security)
        try container.encode(power, forKey: .power)
        try container.encode(loyalty, forKey: .loyalty)
        try container.encode(recognition, forKey: .recognition)
        try container.encode(stability, forKey: .stability)
        try container.encode(ideologicalCommitment, forKey: .ideologicalCommitment)
    }
}

// MARK: - Enhanced NPC Memory Types

/// Extended memory types for NPC-to-NPC interactions
enum NPCMemoryType: String, Codable, CaseIterable {
    // Existing player-related types (mirrors CharacterMemory.MemoryType)
    case betrayal
    case favor
    case humiliation
    case protection
    case slight
    case kindness
    case lawChange
    case promotion
    case demotion
    case familyMatter
    case factionAction

    // NEW: Specific NPC-to-NPC event memories
    case wasInvestigated        // Someone investigated me
    case investigatedOther      // I investigated someone
    case promotionBlocked       // Someone blocked my advancement
    case blockedPromotion       // I blocked someone's advancement
    case allianceFormed         // Formed alliance with someone
    case allianceBroken         // Alliance was broken
    case wasDetained            // I was detained
    case detainedOther          // I detained someone
    case receivedDirective      // Superior issued me orders
    case issuedDirective        // I issued orders to subordinate
    case crisisCollaboration    // Worked together during crisis
    case publicHumiliation      // Denounced or shamed publicly
    case secretShared           // Someone shared intel with me
    case threatReceived         // Someone threatened me
    case threatIssued           // I threatened someone

    // ESPIONAGE & LOYALTY memories
    case caughtSpy              // Caught a foreign spy
    case suspectedOfEspionage   // Was suspected of spying (even if innocent)
    case recruitedByForeign     // Was recruited as foreign asset
    case reportedTraitor        // Reported someone for treason
    case wasReportedAsTraitor   // Was reported for treason
    case ideologicalVictory     // Won ideological campaign/debate
    case ideologicalDefeat      // Lost ideological standing
    case partyCommendation      // Received Party recognition
    case partyReprimand         // Received Party criticism

    /// Whether this memory type is inherently negative
    var isNegative: Bool {
        switch self {
        case .betrayal, .humiliation, .slight, .demotion, .wasInvestigated,
             .promotionBlocked, .allianceBroken, .wasDetained, .publicHumiliation,
             .threatReceived, .suspectedOfEspionage, .wasReportedAsTraitor,
             .ideologicalDefeat, .partyReprimand:
            return true
        default:
            return false
        }
    }

    /// Whether this memory type is inherently positive
    var isPositive: Bool {
        switch self {
        case .favor, .protection, .kindness, .promotion, .allianceFormed,
             .crisisCollaboration, .secretShared, .caughtSpy, .ideologicalVictory,
             .partyCommendation:
            return true
        default:
            return false
        }
    }
}

// MARK: - Enhanced NPC Memory

/// Enhanced memory structure for NPC-to-NPC tracking
struct NPCMemory: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var memoryType: NPCMemoryType
    var turn: Int
    var involvedCharacterId: String?   // Who was involved
    var involvedCharacterName: String? // For display
    var severity: Int                   // 1-100, how significant
    var sentiment: Int                  // -100 to +100
    var description: String             // "Denounced by Wallace"
    var isProcessed: Bool = false       // Has affected behavior?
    var decayRate: Int = 5              // How fast it fades
    var currentStrength: Int = 100      // Fades over time

    init(
        memoryType: NPCMemoryType,
        turn: Int,
        involvedCharacterId: String? = nil,
        involvedCharacterName: String? = nil,
        severity: Int = 50,
        sentiment: Int = 0,
        description: String,
        decayRate: Int = 5
    ) {
        self.memoryType = memoryType
        self.turn = turn
        self.involvedCharacterId = involvedCharacterId
        self.involvedCharacterName = involvedCharacterName
        self.severity = severity
        self.sentiment = sentiment
        self.description = description
        self.decayRate = decayRate
    }

    /// Whether this memory is still significant enough to influence behavior
    var isSignificant: Bool {
        return severity >= 50 && currentStrength >= 30
    }

    /// Whether this is a positive memory
    var isPositive: Bool {
        return sentiment > 0
    }

    /// Process decay for this memory, returns true if memory should be removed
    mutating func processDecay(currentTurn: Int) -> Bool {
        let turnsElapsed = currentTurn - turn
        let decay = turnsElapsed * decayRate / 10
        currentStrength = max(0, currentStrength - decay)

        // Memory should be removed if strength drops below threshold
        return currentStrength < 10
    }
}

// MARK: - Foreign Agent Status

/// Tracks espionage status for NPCs who are foreign agents
struct ForeignAgentStatus: Sendable {
    var isForeignAgent: Bool = false
    var foreignPower: String?           // "United States", "West Germany", etc.
    var recruitedTurn: Int?
    var handler: String?                // Contact name

    // Espionage tracking
    var secretsPassed: Int = 0          // Times intel was passed
    var assetsRecruited: Int = 0        // Other NPCs turned
    var sabotageActs: Int = 0           // Sabotage operations

    // Detection risk
    var suspicionLevel: Int = 0         // 0-100, accumulates with risky actions
    var coverStrength: Int = 80         // 0-100, how solid their cover story is
    var lastActivityTurn: Int?

    // Skill
    var tradecraft: Int = 50            // 0-100, espionage skill

    private enum CodingKeys: String, CodingKey {
        case isForeignAgent, foreignPower, recruitedTurn, handler
        case secretsPassed, assetsRecruited, sabotageActs
        case suspicionLevel, coverStrength, lastActivityTurn, tradecraft
    }

    init(
        isForeignAgent: Bool = false,
        foreignPower: String? = nil,
        recruitedTurn: Int? = nil,
        handler: String? = nil,
        secretsPassed: Int = 0,
        assetsRecruited: Int = 0,
        sabotageActs: Int = 0,
        suspicionLevel: Int = 0,
        coverStrength: Int = 80,
        lastActivityTurn: Int? = nil,
        tradecraft: Int = 50
    ) {
        self.isForeignAgent = isForeignAgent
        self.foreignPower = foreignPower
        self.recruitedTurn = recruitedTurn
        self.handler = handler
        self.secretsPassed = secretsPassed
        self.assetsRecruited = assetsRecruited
        self.sabotageActs = sabotageActs
        self.suspicionLevel = suspicionLevel
        self.coverStrength = coverStrength
        self.lastActivityTurn = lastActivityTurn
        self.tradecraft = tradecraft
    }

    /// Default non-spy status
    static var notAnAgent: ForeignAgentStatus {
        return ForeignAgentStatus()
    }

    /// Create a new foreign agent
    static func newAgent(
        foreignPower: String,
        recruitedTurn: Int,
        tradecraft: Int = 50
    ) -> ForeignAgentStatus {
        return ForeignAgentStatus(
            isForeignAgent: true,
            foreignPower: foreignPower,
            recruitedTurn: recruitedTurn,
            handler: generateHandlerName(),
            tradecraft: tradecraft
        )
    }

    /// Generate a random handler codename
    private static func generateHandlerName() -> String {
        let codeNames = [
            "CARDINAL", "BISHOP", "KNIGHT", "ROOK",
            "FALCON", "EAGLE", "SPARROW", "HAWK",
            "WINTER", "FROST", "SHADOW", "GHOST",
            "PHOENIX", "MERCURY", "SATURN", "MARS"
        ]
        return codeNames.randomElement() ?? "UNKNOWN"
    }

    /// Overall detection risk combining multiple factors
    var detectionRisk: Int {
        guard isForeignAgent else { return 0 }

        // Higher suspicion + lower tradecraft + lower cover = higher risk
        let risk = suspicionLevel +
                   (100 - tradecraft) / 2 +
                   (100 - coverStrength) / 3
        return min(100, risk)
    }

    /// Whether this agent is at high risk of being caught
    var isHighRisk: Bool {
        return detectionRisk >= 60
    }

    /// Whether this agent is actively operating
    var isActivelySpying: Bool {
        return isForeignAgent && suspicionLevel < 80
    }
}

// MARK: - ForeignAgentStatus Codable Conformance (nonisolated for Swift 6 compatibility)

extension ForeignAgentStatus: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isForeignAgent = try container.decodeIfPresent(Bool.self, forKey: .isForeignAgent) ?? false
        foreignPower = try container.decodeIfPresent(String.self, forKey: .foreignPower)
        recruitedTurn = try container.decodeIfPresent(Int.self, forKey: .recruitedTurn)
        handler = try container.decodeIfPresent(String.self, forKey: .handler)
        secretsPassed = try container.decodeIfPresent(Int.self, forKey: .secretsPassed) ?? 0
        assetsRecruited = try container.decodeIfPresent(Int.self, forKey: .assetsRecruited) ?? 0
        sabotageActs = try container.decodeIfPresent(Int.self, forKey: .sabotageActs) ?? 0
        suspicionLevel = try container.decodeIfPresent(Int.self, forKey: .suspicionLevel) ?? 0
        coverStrength = try container.decodeIfPresent(Int.self, forKey: .coverStrength) ?? 80
        lastActivityTurn = try container.decodeIfPresent(Int.self, forKey: .lastActivityTurn)
        tradecraft = try container.decodeIfPresent(Int.self, forKey: .tradecraft) ?? 50
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isForeignAgent, forKey: .isForeignAgent)
        try container.encodeIfPresent(foreignPower, forKey: .foreignPower)
        try container.encodeIfPresent(recruitedTurn, forKey: .recruitedTurn)
        try container.encodeIfPresent(handler, forKey: .handler)
        try container.encode(secretsPassed, forKey: .secretsPassed)
        try container.encode(assetsRecruited, forKey: .assetsRecruited)
        try container.encode(sabotageActs, forKey: .sabotageActs)
        try container.encode(suspicionLevel, forKey: .suspicionLevel)
        try container.encode(coverStrength, forKey: .coverStrength)
        try container.encodeIfPresent(lastActivityTurn, forKey: .lastActivityTurn)
        try container.encode(tradecraft, forKey: .tradecraft)
    }
}

// MARK: - NPC Diplomatic Action Types

/// Types of diplomatic actions taken by Foreign Affairs NPCs (for newspapers/events)
enum NPCDiplomaticActionType: String, Codable, CaseIterable {
    case proposedTreaty             // NPC proposed a treaty
    case conductedNegotiations      // Ongoing diplomatic talks
    case strengthenedAlliance       // Improved relations with ally
    case counteredWesternInfluence  // Blocked capitalist influence
    case expandedTrade              // New trade agreements
    case defusedCrisis              // Resolved diplomatic incident
    case conductedEspionage         // Intelligence operation (classified)
    case proposedPolicyChange       // Submitted policy to Standing Committee
    case respondedToCrisis          // Reacted to international event

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .proposedTreaty: return "Treaty Proposal"
        case .conductedNegotiations: return "Diplomatic Negotiations"
        case .strengthenedAlliance: return "Alliance Strengthening"
        case .counteredWesternInfluence: return "Countering Western Influence"
        case .expandedTrade: return "Trade Expansion"
        case .defusedCrisis: return "Crisis Resolution"
        case .conductedEspionage: return "Intelligence Activity"
        case .proposedPolicyChange: return "Policy Proposal"
        case .respondedToCrisis: return "Crisis Response"
        }
    }

    /// Whether this action is newsworthy (should appear in newspapers)
    var isNewsworthy: Bool {
        switch self {
        case .conductedEspionage:
            return false  // Classified
        default:
            return true
        }
    }

    /// Importance level for headlines (1-5)
    var importance: Int {
        switch self {
        case .proposedTreaty, .defusedCrisis, .respondedToCrisis:
            return 4  // Major news
        case .strengthenedAlliance, .counteredWesternInfluence:
            return 3  // Significant
        case .conductedNegotiations, .expandedTrade, .proposedPolicyChange:
            return 2  // Moderate
        case .conductedEspionage:
            return 1  // Not public
        }
    }
}

// MARK: - Foreign Powers Helper

/// Helper to get recruitment intensity for foreign powers
/// Uses existing ForeignCountry system - countryIds that might recruit agents:
/// - "atlantic_union" (primary adversary, highest espionage)
/// - "commonwealth_islands" (island monarchy with strong spy services)
/// - "korvath" (primary regional adversary)
/// - "brechtland" (industrial capitalist)
/// - "zimograd" (rival socialist - might recruit against us)
/// - "marzovia" (ancient enemy)
struct EspionageHelper {
    /// Get recruitment intensity for a foreign power by countryId
    static func recruitmentIntensity(for countryId: String) -> Int {
        switch countryId {
        case "atlantic_union": return 95      // Primary superpower adversary
        case "commonwealth_islands": return 85 // Strong intelligence services
        case "korvath": return 65             // Regional adversary
        case "brechtland": return 50          // Industrial power
        case "zimograd": return 70            // Rival socialist (ideological competition)
        case "marzovia": return 45            // Ancient enemy
        case "federated_states": return 30    // Neutral traders (opportunistic)
        default: return 20
        }
    }

    /// Countries likely to recruit foreign agents (capitalist bloc + rival)
    static var hostilePowers: [String] {
        ["atlantic_union", "commonwealth_islands", "korvath", "brechtland", "zimograd", "marzovia"]
    }
}
