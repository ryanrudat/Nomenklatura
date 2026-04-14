//
//  NPCLifeEventsService.swift
//  Nomenklatura
//
//  Generates organic life events for NPCs: deaths, illnesses, scandals, affairs,
//  defections, nervous breakdowns, and other natural occurrences that make the
//  world feel alive and dynamic. Events are personality-driven and use a layered
//  visibility system based on player's Network stat.
//

import Foundation
import os.log

private let lifeEventsLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "NPCLifeEvents")

// MARK: - NPC Life Events Service

@MainActor
class NPCLifeEventsService {
    static let shared = NPCLifeEventsService()

    private init() {}

    // MARK: - Visibility Thresholds

    /// Network thresholds for layered visibility
    private struct VisibilityThresholds {
        static let rumor = 30    // "Whispers suggest..."
        static let intel = 50    // "Your sources report..."
        static let secret = 70   // Hidden plots revealed
    }

    // MARK: - Main Processing

    /// Process life events for all NPCs each turn
    /// Returns events that should be shown to the player based on visibility rules
    func processLifeEvents(game: Game) -> [NPCLifeEventResult] {
        var results: [NPCLifeEventResult] = []

        // Only process after early game protection
        guard game.turnNumber > 3 else { return [] }

        // Process each active character
        for character in game.characters where character.isActive {
            // Skip player's patron initially (handled separately)
            guard !character.isPatron else { continue }

            // Check for various life events based on character personality and state
            if let event = checkForLifeEvent(character: character, game: game) {
                // Filter by visibility rules
                if shouldPlayerSeeEvent(event: event, game: game) {
                    results.append(event)
                }

                // Always apply effects regardless of visibility
                applyLifeEventEffects(event: event, character: character, game: game)

                lifeEventsLogger.info("Life event for \(character.name): \(event.eventType.rawValue) [visible: \(event.visibilityLevel.rawValue)]")
            }
        }

        // Limit to prevent spam (1-2 per turn as per plan)
        return Array(results.prefix(2))
    }

    /// Determines if the player should see this event based on Network stat
    private func shouldPlayerSeeEvent(event: NPCLifeEventResult, game: Game) -> Bool {
        switch event.visibilityLevel {
        case .public:
            return true  // Always visible
        case .rumor:
            return game.network >= VisibilityThresholds.rumor
        case .intel:
            return game.network >= VisibilityThresholds.intel
        case .secret:
            return game.network >= VisibilityThresholds.secret
        }
    }

    // MARK: - Life Event Checking (Personality-Driven)

    private func checkForLifeEvent(character: GameCharacter, game: Game) -> NPCLifeEventResult? {
        // Priority order - most impactful first

        // Health crisis (stress-induced, affects paranoid/under-pressure characters)
        if let healthEvent = checkHealthCrisis(character: character, game: game) {
            return healthEvent
        }

        // Scandal (affects corrupt characters)
        if let scandalEvent = checkScandal(character: character, game: game) {
            return scandalEvent
        }

        // Nervous breakdown (affects paranoid characters under investigation)
        if let breakdownEvent = checkNervousBreakdown(character: character, game: game) {
            return breakdownEvent
        }

        // Defection attempt (affects disillusioned characters)
        if let defectionEvent = checkDefection(character: character, game: game) {
            return defectionEvent
        }

        // Unexpected success (affects loyal, competent characters)
        if let successEvent = checkUnexpectedSuccess(character: character, game: game) {
            return successEvent
        }

        // Natural death (affects elderly)
        if let deathEvent = checkNaturalDeath(character: character, game: game) {
            return deathEvent
        }

        // Family crisis
        if let familyEvent = checkFamilyCrisis(character: character, game: game) {
            return familyEvent
        }

        // Public disgrace (affects ambitious who overreach)
        if let disgraceEvent = checkPublicDisgrace(character: character, game: game) {
            return disgraceEvent
        }

        return nil
    }

    // MARK: - Health Crisis (Paranoid/High-Stress)

    private func checkHealthCrisis(character: GameCharacter, game: Game) -> NPCLifeEventResult? {
        var chance = 0 // Base chance

        // Personality: Paranoid characters under stress
        if character.personalityParanoid > 60 {
            chance += 2
        }

        // Status: Under investigation dramatically increases risk
        if character.currentStatus == .underInvestigation {
            chance += 4
        }

        // Needs: Low security need (constant fear)
        if character.npcNeeds.security < 30 {
            chance += 3
        }

        // Position: High-level stress
        if let positionIndex = character.positionIndex, positionIndex >= 6 {
            chance += 2
        }

        // Age factor
        if character.ageCategory == "elderly" {
            chance += 3
        }

        guard chance > 0 && Int.random(in: 1...100) <= chance else { return nil }

        // Determine severity
        let severity = Int.random(in: 1...100)

        if severity <= 8 {
            // Fatal heart attack (8% of health events)
            return NPCLifeEventResult(
                character: character,
                eventType: .suddenDeath,
                headline: "\(character.name) Suffers Fatal Heart Attack",
                details: generateHeartAttackNarrative(character: character, fatal: true),
                visibilityLevel: .public,  // Deaths are always public
                severity: .fatal,
                affectsStatus: .dead
            )
        } else if severity <= 35 {
            // Serious illness, hospitalized
            return NPCLifeEventResult(
                character: character,
                eventType: .seriousIllness,
                headline: "\(character.name) Hospitalized with Undisclosed Illness",
                details: generateIllnessNarrative(character: character, serious: true),
                visibilityLevel: .public,
                severity: .major,
                temporaryEffect: "hospitalized"
            )
        } else {
            // Minor health scare - requires network to learn about
            return NPCLifeEventResult(
                character: character,
                eventType: .healthScare,
                headline: "\(character.name) Takes Medical Leave",
                details: generateIllnessNarrative(character: character, serious: false),
                visibilityLevel: .rumor,  // Requires Network >= 30
                severity: .minor
            )
        }
    }

    // MARK: - Scandal (Corrupt Characters)

    private func checkScandal(character: GameCharacter, game: Game) -> NPCLifeEventResult? {
        var chance = 0

        // Personality: Corrupt characters attract scandal
        if character.personalityCorrupt > 70 {
            chance += 4
        } else if character.personalityCorrupt > 50 {
            chance += 2
        }

        // Already under investigation increases exposure
        if character.currentStatus == .underInvestigation {
            chance += 2
        }

        // Characters with enemies are at risk (enemies expose them)
        let enemyCount = game.npcRelationships.filter {
            $0.targetCharacterId == character.templateId && $0.disposition < -30
        }.count
        chance += min(enemyCount, 3)

        guard chance > 0 && Int.random(in: 1...100) <= chance else { return nil }

        // Determine type of scandal based on personality
        let scandalType = determineScandalType(for: character)

        return NPCLifeEventResult(
            character: character,
            eventType: .scandal,
            headline: scandalType.headline(for: character),
            details: scandalType.narrative(for: character),
            visibilityLevel: scandalType.visibilityLevel,
            severity: scandalType.severity,
            affectsStatus: scandalType.resultingStatus,
            dispositionChange: scandalType.dispositionPenalty
        )
    }

    private func determineScandalType(for character: GameCharacter) -> ScandalType {
        // Weight scandal types by personality
        var weights: [(ScandalType, Int)] = []

        // Corrupt -> financial scandals
        if character.personalityCorrupt > 60 {
            weights.append((.corruption, 40))
            weights.append((.blackMarket, 30))
        }

        // Low loyalty -> foreign contacts
        if character.personalityLoyal < 40 {
            weights.append((.foreignContact, 35))
        }

        // Any character can have affairs
        weights.append((.affair, 15))

        // Ideological deviation for any
        weights.append((.ideologicalDeviation, 20))

        // If no specific weights, use default
        if weights.isEmpty {
            return ScandalType.allCases.randomElement() ?? .corruption
        }

        // Weighted random selection
        let totalWeight = weights.reduce(0) { $0 + $1.1 }
        var roll = Int.random(in: 0..<totalWeight)
        for (type, weight) in weights {
            roll -= weight
            if roll < 0 {
                return type
            }
        }
        return weights.first?.0 ?? .corruption
    }

    // MARK: - Nervous Breakdown (Paranoid Under Pressure)

    private func checkNervousBreakdown(character: GameCharacter, game: Game) -> NPCLifeEventResult? {
        var chance = 0

        // Under investigation + paranoid = high risk
        if character.currentStatus == .underInvestigation && character.personalityParanoid > 60 {
            chance += 6
        }

        // Multiple critical needs
        let needs = character.npcNeeds
        if needs.security < 25 && needs.stability < 25 {
            chance += 4
        }

        // Frustrated goals
        if let primaryGoal = character.primaryGoal, primaryGoal.frustrationLevel > 70 {
            chance += 3
        }

        // Low paranoia characters are resilient
        if character.personalityParanoid < 30 {
            chance = max(0, chance - 3)
        }

        guard chance > 0 && Int.random(in: 1...100) <= chance else { return nil }

        let outcomes: [(String, String, CharacterStatus?, EventVisibilityLevel)] = [
            ("public outburst",
             "made an incoherent speech denouncing unnamed enemies before being escorted from the hall",
             .detained,
             .public),
            ("attempted escape",
             "was apprehended at the border with falsified documents",
             .detained,
             .public),
            ("confession",
             "submitted a rambling self-criticism confessing to various ideological deviations",
             .underInvestigation,
             .intel),
            ("breakdown",
             "collapsed during a meeting and has been hospitalized for 'nervous exhaustion'",
             nil,
             .rumor)
        ]

        guard let outcome = outcomes.randomElement() else { return nil }

        return NPCLifeEventResult(
            character: character,
            eventType: .nervousBreakdown,
            headline: "\(character.name) Suffers \(outcome.0.capitalized)",
            details: "\(character.name) \(outcome.1). Colleagues express 'concern' while carefully distancing themselves.",
            visibilityLevel: outcome.3,
            severity: .major,
            affectsStatus: outcome.2,
            dispositionChange: -15
        )
    }

    // MARK: - Defection (Disillusioned Characters)

    private func checkDefection(character: GameCharacter, game: Game) -> NPCLifeEventResult? {
        // Must be disillusioned (low ideological commitment)
        guard character.isDisillusioned else { return nil }

        // Higher chance for foreign affairs personnel
        let hasForeignAccess = character.positionTrack == "foreignAffairs"

        var chance = 1

        if character.npcNeeds.ideologicalCommitment < 20 {
            chance += 3
        }

        if character.grudgeLevel < -50 {
            chance += 2
        }

        if hasForeignAccess {
            chance += 3
        }

        // Foreign agents who feel heat are more likely to flee
        if character.foreignAgentStatus.isForeignAgent && character.foreignAgentStatus.suspicionLevel > 60 {
            chance += 8
        }

        guard Int.random(in: 1...100) <= chance else { return nil }

        // Determine if defection succeeds (40% success rate)
        let success = Int.random(in: 1...100) <= 40

        if success {
            return NPCLifeEventResult(
                character: character,
                eventType: .defection,
                headline: "\(character.name) Defects to the West",
                details: "In a stunning betrayal, \(character.name) has defected to the Atlantic Union, reportedly taking sensitive documents. State media denounces them as a 'traitor and provocateur seduced by imperialist lies.'",
                visibilityLevel: .public,  // Major defections are always public
                severity: .catastrophic,
                affectsStatus: .exiled,
                gameEffects: ["internationalStanding": -5, "stability": -3]
            )
        } else {
            return NPCLifeEventResult(
                character: character,
                eventType: .defectionFailed,
                headline: "\(character.name) Arrested Attempting to Flee",
                details: "\(character.name) was apprehended at the border with classified materials. They face charges of treason and espionage. Their associates are now under scrutiny.",
                visibilityLevel: .public,
                severity: .major,
                affectsStatus: .detained
            )
        }
    }

    // MARK: - Unexpected Success (Loyal/Competent Characters)

    private func checkUnexpectedSuccess(character: GameCharacter, game: Game) -> NPCLifeEventResult? {
        // Only loyal and competent characters get windfalls
        guard character.personalityLoyal > 60 && character.personalityCompetent > 50 else { return nil }

        // Low chance (positive events are rarer)
        guard Int.random(in: 1...100) <= 2 else { return nil }

        let successes = [
            ("Receives State Commendation",
             "\(character.name) has been awarded the Order of Labor for 'outstanding contributions to socialist construction.' Their star rises within the apparatus.",
             20),  // disposition boost
            ("Published in Central Press",
             "\(character.name)'s theoretical article on Party doctrine receives prominent placement in the Central Press. They are increasingly seen as a rising ideological voice.",
             15),
            ("Project Exceeds Targets",
             "A project under \(character.name)'s supervision has exceeded all production targets. They bask in reflected glory as congratulations pour in.",
             12),
            ("Appointed to Prestigious Commission",
             "\(character.name) has been appointed to a prestigious study commission, signaling high-level confidence in their abilities.",
             10)
        ]

        guard let success = successes.randomElement() else { return nil }

        return NPCLifeEventResult(
            character: character,
            eventType: .unexpectedSuccess,
            headline: "\(character.name) \(success.0)",
            details: success.1,
            visibilityLevel: .public,
            severity: .moderate,
            dispositionChange: success.2
        )
    }

    // MARK: - Natural Death (Elderly)

    private func checkNaturalDeath(character: GameCharacter, game: Game) -> NPCLifeEventResult? {
        // Only affects elderly characters
        guard character.ageCategory == "elderly" else { return nil }

        // Very low chance (1% per turn for elderly)
        guard Int.random(in: 1...100) <= 1 else { return nil }

        let causes = [
            ("heart failure", "passed away peacefully at home after a brief illness"),
            ("stroke", "suffered a fatal stroke in their office during a late meeting"),
            ("car accident", "died in a car accident while traveling to their dacha"),
            ("illness", "succumbed to a long-hidden illness that they had concealed for years")
        ]

        guard let cause = causes.randomElement() else { return nil }

        return NPCLifeEventResult(
            character: character,
            eventType: .naturalDeath,
            headline: "\(character.name) Dies of \(cause.0.capitalized)",
            details: "\(character.name) \(cause.1). The funeral will be held with appropriate state honors at the Central Cemetery. A moment of silence was observed at the latest Politburo session.",
            visibilityLevel: .public,
            severity: .fatal,
            affectsStatus: .dead
        )
    }

    // MARK: - Family Crisis

    private func checkFamilyCrisis(character: GameCharacter, game: Game) -> NPCLifeEventResult? {
        // Low base chance
        guard Int.random(in: 1...100) <= 2 else { return nil }

        let crises: [(String, String, Int, EventVisibilityLevel)] = [
            ("Child's Disgrace",
             "\(character.name)'s son has been expelled from the Party Youth for 'bourgeois attitudes' and 'ideological immaturity.' The family's loyalty is now quietly questioned.",
             -10,
             .rumor),
            ("Spouse's Indiscretion",
             "Rumors circulate about \(character.name)'s spouse's involvement in black market activities. Whether true or not, the whispers damage their standing.",
             -8,
             .rumor),
            ("Relative's Arrest",
             "A cousin of \(character.name) has been arrested for counter-revolutionary activity. Colleagues maintain careful distance, not wishing to be associated.",
             -12,
             .intel),
            ("Family Property Dispute",
             "\(character.name) is embroiled in an embarrassing dispute with siblings over family property. Such private concerns raise eyebrows among the ideologically pure.",
             -5,
             .rumor)
        ]

        guard let crisis = crises.randomElement() else { return nil }

        return NPCLifeEventResult(
            character: character,
            eventType: .familyCrisis,
            headline: crisis.0,
            details: crisis.1,
            visibilityLevel: crisis.3,
            severity: .moderate,
            dispositionChange: crisis.2
        )
    }

    // MARK: - Public Disgrace (Ambitious Overreachers)

    private func checkPublicDisgrace(character: GameCharacter, game: Game) -> NPCLifeEventResult? {
        // Only for very ambitious characters
        guard character.personalityAmbitious > 70 else { return nil }

        // Low chance
        guard Int.random(in: 1...100) <= 2 else { return nil }

        let disgraces = [
            ("Public Criticism",
             "\(character.name) is criticized at a Party meeting for 'bureaucratic tendencies' and 'excessive personal ambition.' They scramble to perform self-criticism while rivals circle.",
             -12),
            ("Failed Initiative",
             "An initiative loudly championed by \(character.name) has failed spectacularly. Blame flows freely, and their reputation suffers as former supporters distance themselves.",
             -10),
            ("Demotion Rumors",
             "Whispers suggest \(character.name) is being sidelined from key decisions. Their phone calls go unreturned, and their office feels emptier each week.",
             -15)
        ]

        guard let disgrace = disgraces.randomElement() else { return nil }

        return NPCLifeEventResult(
            character: character,
            eventType: .unexpectedDisgrace,
            headline: disgrace.0,
            details: disgrace.1,
            visibilityLevel: .rumor,
            severity: .moderate,
            dispositionChange: disgrace.2
        )
    }

    // MARK: - Effect Application

    private func applyLifeEventEffects(event: NPCLifeEventResult, character: GameCharacter, game: Game) {
        // Apply status change if specified
        if let newStatus = event.affectsStatus {
            character.status = newStatus.rawValue
            character.statusChangedTurn = game.turnNumber
            character.fateNarrative = event.details
            character.statusDetails = event.headline

            // Handle return possibilities for non-permanent statuses
            switch newStatus {
            case .dead, .executed:
                character.canReturnFlag = false
                game.invalidateCharacterRoleCaches()
            case .detained, .imprisoned:
                character.canReturnFlag = true
                character.returnProbability = Int.random(in: 15...40)
            case .exiled:
                character.canReturnFlag = true
                character.returnProbability = Int.random(in: 5...20)
            case .underInvestigation:
                character.canReturnFlag = true
                character.returnProbability = Int.random(in: 40...70)
            default:
                break
            }
        }

        // Apply disposition change
        if let dispositionChange = event.dispositionChange {
            character.disposition = max(-100, min(100, character.disposition + dispositionChange))
        }

        // Apply game-wide effects
        if let effects = event.gameEffects {
            for (key, value) in effects {
                game.applyStat(key, change: value)
            }
        }

        // Add to journal based on visibility level
        addEventToJournal(event: event, game: game)

        // Create a GameEvent for the history log
        let gameEvent = GameEvent(
            turnNumber: game.turnNumber,
            eventType: event.severity == .fatal ? .death : .narrative,
            summary: event.headline
        )
        gameEvent.importance = event.severity.importance
        gameEvent.game = game
        game.events.append(gameEvent)
    }

    private func addEventToJournal(event: NPCLifeEventResult, game: Game) {
        // Determine category based on event type
        let category: JournalCategory = {
            switch event.eventType {
            case .suddenDeath, .naturalDeath:
                return .fateChange
            case .scandal, .defection, .defectionFailed:
                return .secretIntelligence
            case .nervousBreakdown, .healthScare, .seriousIllness:
                return .fateChange
            case .familyCrisis:
                return .npcActivity
            case .unexpectedSuccess, .unexpectedDisgrace:
                return .npcActivity
            default:
                return .npcActivity
            }
        }()

        // Prefix based on visibility level for immersion
        let prefix: String = {
            switch event.visibilityLevel {
            case .public:
                return ""
            case .rumor:
                return "Whispers suggest: "
            case .intel:
                return "Your sources report: "
            case .secret:
                return game.currentPositionIndex >= 7 ? "Eyes Only: " : "[CLASSIFIED] "
            }
        }()

        JournalService.shared.addEntry(
            to: game,
            category: category,
            title: prefix + event.headline,
            content: event.details,
            relatedCharacterId: event.character.templateId,
            importance: event.severity.importance
        )
    }

    // MARK: - Narrative Generation

    private func generateHeartAttackNarrative(character: GameCharacter, fatal: Bool) -> String {
        if fatal {
            let narratives = [
                "\(character.name) collapsed in their office during an evening meeting and could not be revived. Doctors cite 'acute myocardial infarction.' The official obituary will praise their 'tireless service to the Party and the People.'",
                "\(character.name) was found unresponsive at their desk by staff early the following morning. Despite immediate medical attention, they could not be saved. Colleagues speak of their dedication in hushed, careful tones.",
                "After complaining of chest pains during a reception at the Cultural Palace, \(character.name) was rushed to the Central Clinical Hospital where they died shortly after arrival. The funeral will be held with full state honors."
            ]
            return narratives.randomElement() ?? narratives[0]
        } else {
            return "\(character.name) suffered a minor cardiac event and is recovering in hospital. They are expected to return to duties within weeks, though some whisper that the strain of office is taking its toll."
        }
    }

    private func generateIllnessNarrative(character: GameCharacter, serious: Bool) -> String {
        if serious {
            let illnesses = [
                "The official statement cites 'exhaustion from overwork,' though insiders whisper of more serious conditions. \(character.name) remains under observation, their office curiously silent.",
                "\(character.name) has been diagnosed with a serious but treatable condition. Their duties have been temporarily reassigned as they undergo treatment at the special clinic reserved for senior cadres.",
                "Following weeks of declining health that could no longer be concealed, \(character.name) has finally been hospitalized. The prognosis remains guarded, and their position grows uncertain."
            ]
            return illnesses.randomElement() ?? illnesses[0]
        } else {
            return "\(character.name) has taken a brief medical leave to address 'minor health concerns.' They are expected to return shortly, though rivals note the opportunity with interest."
        }
    }
}

// MARK: - Supporting Types

struct NPCLifeEventResult {
    let character: GameCharacter
    let eventType: NPCLifeEventType
    let headline: String
    let details: String
    let visibilityLevel: EventVisibilityLevel
    let severity: EventSeverity
    var affectsStatus: CharacterStatus? = nil
    var temporaryEffect: String? = nil
    var dispositionChange: Int? = nil
    var gameEffects: [String: Int]? = nil

    enum EventSeverity: Int {
        case minor = 3
        case moderate = 5
        case major = 7
        case catastrophic = 9
        case fatal = 10

        var importance: Int { rawValue }
    }
}

enum EventVisibilityLevel: String, Codable {
    case `public` = "public"     // Always visible
    case rumor = "rumor"         // Network >= 30
    case intel = "intel"         // Network >= 50
    case secret = "secret"       // Network >= 70
}

enum NPCLifeEventType: String, Codable {
    case suddenDeath = "sudden_death"
    case naturalDeath = "natural_death"
    case seriousIllness = "serious_illness"
    case healthScare = "health_scare"
    case scandal = "scandal"
    case nervousBreakdown = "nervous_breakdown"
    case defection = "defection"
    case defectionFailed = "defection_failed"
    case familyCrisis = "family_crisis"
    case unexpectedSuccess = "unexpected_success"
    case unexpectedDisgrace = "unexpected_disgrace"
    case arrest = "arrest"
    case rehabilitation = "rehabilitation"
}

enum ScandalType: String, CaseIterable {
    case corruption
    case affair
    case ideologicalDeviation
    case blackMarket
    case foreignContact

    func headline(for character: GameCharacter) -> String {
        switch self {
        case .corruption:
            return "\(character.name) Implicated in Corruption Scandal"
        case .affair:
            return "Rumors Swirl Around \(character.name)'s Private Life"
        case .ideologicalDeviation:
            return "\(character.name) Criticized for Ideological Wavering"
        case .blackMarket:
            return "\(character.name) Linked to Black Market Ring"
        case .foreignContact:
            return "\(character.name) Under Scrutiny for Foreign Contacts"
        }
    }

    func narrative(for character: GameCharacter) -> String {
        switch self {
        case .corruption:
            return "An investigation has uncovered evidence of \(character.name)'s involvement in misappropriation of state funds. Their 'lavish lifestyle' is now under scrutiny. Colleagues who once sought their favor now avoid their gaze."
        case .affair:
            return "Whispered rumors about \(character.name)'s 'inappropriate personal conduct' have reached official ears. Such private scandals, in this world, often precede more serious accusations."
        case .ideologicalDeviation:
            return "\(character.name) has been criticized at a Party meeting for 'right-deviationist tendencies' in their recent statements. They have submitted a self-criticism, but doubts about their reliability linger in the corridors."
        case .blackMarket:
            return "State Security has identified \(character.name) as a person of interest in an investigation of black market activities. While not yet formally accused, their position has become precarious. Friends grow scarce."
        case .foreignContact:
            return "Security organs have noted \(character.name)'s 'excessive contacts' with foreign diplomats at recent receptions. Such scrutiny often signals the beginning of more serious investigation."
        }
    }

    var severity: NPCLifeEventResult.EventSeverity {
        switch self {
        case .corruption, .blackMarket, .foreignContact:
            return .major
        case .affair, .ideologicalDeviation:
            return .moderate
        }
    }

    var visibilityLevel: EventVisibilityLevel {
        switch self {
        case .affair:
            return .rumor  // Requires network to hear gossip
        case .ideologicalDeviation:
            return .public  // Public criticism
        case .corruption, .blackMarket, .foreignContact:
            return .intel  // Requires good sources
        }
    }

    var resultingStatus: CharacterStatus? {
        switch self {
        case .corruption, .blackMarket, .foreignContact:
            return .underInvestigation
        default:
            return nil
        }
    }

    var dispositionPenalty: Int {
        switch self {
        case .corruption:
            return -15
        case .affair:
            return -5
        case .ideologicalDeviation:
            return -10
        case .blackMarket:
            return -12
        case .foreignContact:
            return -18
        }
    }
}
