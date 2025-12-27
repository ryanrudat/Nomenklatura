//
//  DynamicEventTriggerService.swift
//  Nomenklatura
//
//  Evaluates game state to trigger dynamic events contextually
//

import Foundation

// MARK: - Dynamic Event Trigger Service

class DynamicEventTriggerService {
    static let shared = DynamicEventTriggerService()

    // Cooldown tracking to prevent event fatigue
    private var lastEventTurnByType: [DynamicEventType: Int] = [:]
    private var eventsThisTurn: Int = 0
    private var consecutiveEventTurns: Int = 0

    // MARK: - Main Evaluation

    /// Called at turn start to check for triggered events
    /// Returns the highest priority event that should fire, or nil for quiet turn
    func evaluateTriggers(game: Game, phase: GamePhase) -> DynamicEvent? {
        // Reset turn counter at briefing phase
        if phase == .briefing {
            eventsThisTurn = 0
        }

        // Check if we should have a quiet turn (natural pacing)
        if shouldBeQuietTurn(game: game) {
            return nil
        }

        // Prevent event fatigue - max events per turn based on situation
        let maxEvents = getMaxEventsForTurn(game: game)
        guard eventsThisTurn < maxEvents else { return nil }

        // Gather all candidate events
        var candidates: [DynamicEvent] = []

        // Check each trigger category
        candidates.append(contentsOf: checkPatronEvents(game: game))
        candidates.append(contentsOf: checkRivalEvents(game: game))
        candidates.append(contentsOf: checkAllyEvents(game: game))
        candidates.append(contentsOf: checkConsequenceCallbacks(game: game))
        candidates.append(contentsOf: checkUrgentInterruptions(game: game))
        candidates.append(contentsOf: checkAmbientTension(game: game))
        candidates.append(contentsOf: checkNetworkIntel(game: game))

        // New political systems
        candidates.append(contentsOf: checkNPCAutonomousActions(game: game))
        candidates.append(contentsOf: checkAssassinationRisks(game: game))
        candidates.append(contentsOf: checkPeoplesCongressEvents(game: game))
        candidates.append(contentsOf: checkShowTrialEvents(game: game))
        candidates.append(contentsOf: checkCorruptionEvents(game: game))

        // Filter by player position - ensure events are appropriate for their rank
        let positionFiltered = candidates.filter { event in
            event.eventType.isAppropriate(forPositionIndex: game.currentPositionIndex)
        }

        // Filter by cooldowns
        let filtered = filterByCooldowns(positionFiltered, game: game)

        // Select highest priority event
        guard let selected = selectEvent(from: filtered, game: game) else {
            return nil
        }

        // Update tracking
        eventsThisTurn += 1
        lastEventTurnByType[selected.eventType] = game.turnNumber
        consecutiveEventTurns += 1

        return selected
    }

    /// Reset tracking for new turn
    func resetForNewTurn(game: Game, hadEventLastTurn: Bool) {
        eventsThisTurn = 0
        if !hadEventLastTurn {
            consecutiveEventTurns = 0
        }
    }

    // MARK: - Patron Events

    private func checkPatronEvents(game: Game) -> [DynamicEvent] {
        guard let patron = game.patron, patron.isActive else { return [] }

        var events: [DynamicEvent] = []
        let eventService = EventGenerationService.shared

        // Use centralized EventGenerationService and GameplayConstants for consistency
        // Priority order: summons > directive > warning > opportunity (most severe first)
        // Using else-if to prevent multiple patron events in same turn
        if eventService.shouldTriggerPatronEvent(game: game, eventType: .summons) {
            // Urgent summons when favor is critically low (highest priority)
            events.append(eventService.generatePatronSummons(patron: patron, game: game))
        } else if eventService.shouldTriggerPatronEvent(game: game, eventType: .directive) {
            // Patron directive when stability is critical
            events.append(eventService.generatePatronDirective(patron: patron, game: game))
        } else if eventService.shouldTriggerPatronEvent(game: game, eventType: .warning) {
            // Patron warning when favor is low
            events.append(eventService.generatePatronWarning(patron: patron, game: game))
        } else if eventService.shouldTriggerPatronEvent(game: game, eventType: .opportunity) {
            // Patron opportunity when favor is high
            events.append(eventService.generatePatronOpportunity(patron: patron, game: game))
        }

        return events
    }

    private func generatePatronWarning(patron: GameCharacter, game: Game) -> DynamicEvent {
        let titles = [
            "A Word of Caution",
            "Private Communication",
            "A Warning",
            "Confidential Message"
        ]

        let texts = [
            "\(patron.name) sends word through back channels. The tone is concerned:\n\n\"I have heard whispers, Comrade. Questions are being asked about your recent decisions. Questions I cannot easily deflect. You would do well to demonstrate your loyalty in the coming days.\"",
            "A note arrives, written in \(patron.name)'s distinctive hand:\n\n\"Certain parties have taken notice of your... activities. I suggest you consider your position carefully. The General Secretary has a long memory.\"",
            "\(patron.name) catches your eye across the ministry corridor and gestures subtly toward an empty office.\n\n\"Be careful,\" they say quietly. \"Your rivals are circling. I may not always be able to protect you.\""
        ]

        return DynamicEvent(
            eventType: .patronDirective,
            priority: .elevated,
            title: titles.randomElement()!,
            briefText: texts.randomElement()!,
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "acknowledge", text: "Thank your patron for the warning", shortText: "Acknowledge", effects: [:]),
                EventResponse(id: "ask_advice", text: "Ask what you should do", shortText: "Seek Guidance", effects: ["patronFavor": 3]),
                EventResponse(id: "dismiss", text: "Assure them you have everything under control", shortText: "Dismiss Concerns", effects: ["patronFavor": -5])
            ],
            iconName: "hand.raised.fill",
            accentColor: "accentGold"
        )
    }

    private func generatePatronOpportunity(patron: GameCharacter, game: Game) -> DynamicEvent {
        let titles = [
            "An Opportunity Presents Itself",
            "A Gift from Your Patron",
            "Favorable News"
        ]

        let texts = [
            "\(patron.name) summons you to their office with unusual warmth.\n\n\"Your loyalty has not gone unnoticed, Comrade. A position on the Foreign Affairs Committee has opened. I have recommended you for consideration.\"",
            "A message from \(patron.name): \"The General Secretary was impressed with your handling of recent matters. I have arranged for you to present at the next Presidium meeting. Do not disappoint me.\"",
            "\(patron.name) pulls you aside after the morning briefing.\n\n\"Director Kowalski is retiring. His position could be yours, if you play your cards right. I will support your candidacy.\""
        ]

        return DynamicEvent(
            eventType: .patronDirective,
            priority: .normal,
            title: titles.randomElement()!,
            briefText: texts.randomElement()!,
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "accept_eager", text: "Accept eagerly and thank your patron", shortText: "Accept Eagerly", effects: ["standing": 5, "patronFavor": 5]),
                EventResponse(id: "accept_cautious", text: "Accept with appropriate caution", shortText: "Accept Cautiously", effects: ["standing": 3]),
                EventResponse(id: "defer", text: "Suggest you are not yet ready", shortText: "Defer", effects: ["patronFavor": -3])
            ],
            iconName: "star.fill",
            accentColor: "accentGold"
        )
    }

    private func generatePatronDirective(patron: GameCharacter, game: Game) -> DynamicEvent {
        let crisisArea = game.stability < 30 ? "stability" : (game.popularSupport < 30 ? "popular discontent" : "the current crisis")

        return DynamicEvent(
            eventType: .patronDirective,
            priority: .elevated,
            title: "Orders from Above",
            briefText: "\(patron.name) is direct:\n\n\"The situation with \(crisisArea) is unacceptable. The General Secretary expects results. I am assigning you to handle this personally. Failure is not an option.\"",
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: true,
            responseOptions: [
                EventResponse(id: "accept", text: "Accept the responsibility", shortText: "Accept", effects: ["patronFavor": 5], followUpHint: "You will be held accountable for the outcome"),
                EventResponse(id: "negotiate", text: "Request additional resources", shortText: "Request Resources", effects: ["patronFavor": -2, "network": 5]),
                EventResponse(id: "deflect", text: "Suggest someone else is better suited", shortText: "Deflect", effects: ["patronFavor": -10])
            ],
            iconName: "exclamationmark.circle.fill",
            accentColor: "sovietRed"
        )
    }

    private func generatePatronSummons(patron: GameCharacter, game: Game) -> DynamicEvent {
        return DynamicEvent(
            eventType: .characterSummons,
            priority: .urgent,
            title: "URGENT SUMMONS",
            briefText: "A secretary appears at your door, pale-faced.\n\n\"\(patron.name) demands your presence. Immediately.\"\n\nThis is not a request. Something has happened.",
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: true,
            responseOptions: [
                EventResponse(id: "go_immediately", text: "Go immediately", shortText: "Proceed", effects: [:])
            ],
            iconName: "bell.fill",
            accentColor: "stampRed"
        )
    }

    // MARK: - Rival Events

    private func checkRivalEvents(game: Game) -> [DynamicEvent] {
        guard let rival = game.primaryRival, rival.isActive else { return [] }

        var events: [DynamicEvent] = []

        // Rival acts based on threat level and player vulnerability
        let actionChance = calculateRivalActionChance(rival: rival, game: game)

        if Double.random(in: 0...1) < actionChance {
            if game.rivalThreat > 70 {
                events.append(generateRivalAttack(rival: rival, game: game))
            } else if game.rivalThreat > 50 {
                events.append(generateRivalScheme(rival: rival, game: game))
            } else {
                events.append(generateRivalProbe(rival: rival, game: game))
            }
        }

        return events
    }

    private func calculateRivalActionChance(rival: GameCharacter, game: Game) -> Double {
        var chance = BalanceConfig.rivalActionBaseChance  // Base 5% (configurable)

        // Higher threat = more aggressive
        chance += Double(game.rivalThreat) / 400.0  // Up to +25% (reduced from +50%)

        // Player vulnerability invites attack (only when severe)
        if game.standing < 30 { chance += 0.10 }  // Reduced threshold and bonus
        if game.patronFavor < 40 { chance += 0.08 }  // Reduced threshold and bonus

        // Ambitious rivals act more
        chance += Double(rival.personalityAmbitious) / 800.0  // Up to +12% (reduced)

        // Paranoid rivals act less
        chance -= Double(rival.personalityParanoid) / 500.0  // Up to -20%

        return min(BalanceConfig.rivalActionMaxChance, chance)  // Cap at 35% (configurable)
    }

    private func generateRivalAttack(rival: GameCharacter, game: Game) -> DynamicEvent {
        let titles = [
            "A Move Against You",
            "Your Rival Strikes",
            "Political Attack"
        ]

        let texts = [
            "\(rival.name) has not been idle. Word reaches you that they have been meeting privately with members of the Central Committee, spreading doubts about your competence.\n\nThree officials who once supported you have grown distant.",
            "At this morning's briefing, \(rival.name) publicly questions a decision you made last week. The General Secretary's expression is unreadable.\n\nThis was no accident.",
            "An anonymous complaint about your department has appeared on the General Secretary's desk. The handwriting looks familiar.\n\n\(rival.name) is making their move."
        ]

        return DynamicEvent(
            eventType: .rivalAction,
            priority: .elevated,
            title: titles.randomElement()!,
            briefText: texts.randomElement()!,
            initiatingCharacterId: rival.id,
            initiatingCharacterName: rival.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "confront", text: "Confront them publicly at the next meeting", shortText: "Confront", effects: ["standing": -5, "rivalThreat": -15], riskLevel: .high, followUpHint: "High risk, but could decisively weaken them"),
                EventResponse(id: "counter", text: "Begin gathering evidence against them", shortText: "Gather Evidence", effects: ["network": -3], setsFlag: "gathering_rival_evidence"),
                EventResponse(id: "patron", text: "Appeal to your patron for protection", shortText: "Seek Protection", effects: ["patronFavor": -8], followUpHint: "Uses political capital but provides cover")
            ],
            iconName: "bolt.fill",
            accentColor: "stampRed"
        )
    }

    private func generateRivalScheme(rival: GameCharacter, game: Game) -> DynamicEvent {
        return DynamicEvent(
            eventType: .rivalAction,
            priority: .normal,
            title: "Rumors Spread",
            briefText: "Whispers reach you through your network. \(rival.name) has been talking to officials in your ministry, asking questions about your methods, your loyalties.\n\n\"Just gathering information,\" they claim. But you know better.",
            initiatingCharacterId: rival.id,
            initiatingCharacterName: rival.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "ignore", text: "Ignore it—showing concern gives them power", shortText: "Ignore", effects: ["rivalThreat": 5]),
                EventResponse(id: "counter_rumors", text: "Spread your own rumors about them", shortText: "Counter-Rumors", effects: ["rivalThreat": -5, "reputationCunning": 5]),
                EventResponse(id: "confront_private", text: "Arrange a private meeting to warn them off", shortText: "Private Warning", effects: ["rivalThreat": -3])
            ],
            iconName: "ear.fill",
            accentColor: "inkGray"
        )
    }

    private func generateRivalProbe(rival: GameCharacter, game: Game) -> DynamicEvent {
        return DynamicEvent(
            eventType: .rivalAction,
            priority: .background,
            title: "Testing the Waters",
            briefText: "\(rival.name) approaches you after the morning briefing, their tone carefully neutral.\n\n\"Comrade, perhaps we have more in common than we thought. The General Secretary's latest policies are... ambitious. What do you think?\"\n\nThey are fishing for something.",
            initiatingCharacterId: rival.id,
            initiatingCharacterName: rival.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "agree", text: "Agree cautiously, see what they want", shortText: "Agree", effects: ["rivalThreat": -5, "reputationLoyal": -3]),
                EventResponse(id: "deflect", text: "Give a non-committal response", shortText: "Deflect", effects: ["reputationCunning": 3]),
                EventResponse(id: "loyal", text: "Express firm support for the General Secretary", shortText: "Show Loyalty", effects: ["reputationLoyal": 5, "rivalThreat": 3])
            ],
            iconName: "questionmark.circle.fill",
            accentColor: "inkGray"
        )
    }

    // MARK: - Ally Events

    private func checkAllyEvents(game: Game) -> [DynamicEvent] {
        var events: [DynamicEvent] = []

        // Check non-patron, non-rival characters with high disposition
        let allies = game.characters.filter { char in
            char.isActive && !char.isPatron && !char.isRival && char.disposition >= 65
        }

        for ally in allies {
            let chance = Double(ally.disposition - 60) / 200.0 + 0.05  // 5-25%
            if Double.random(in: 0...1) < chance {
                if ally.disposition > 80 {
                    events.append(generateAllyIntel(ally: ally, game: game))
                } else {
                    events.append(generateAllyRequest(ally: ally, game: game))
                }
                break  // Only one ally event per check
            }
        }

        return events
    }

    private func generateAllyIntel(ally: GameCharacter, game: Game) -> DynamicEvent {
        return DynamicEvent(
            eventType: .characterMessage,
            priority: .normal,
            title: "Friendly Intelligence",
            briefText: "\(ally.name) finds a moment to speak with you privately.\n\n\"I thought you should know—I overheard something in the canteen. Your rival has been asking about the foreign delegation visit. They may be planning something.\"",
            initiatingCharacterId: ally.id,
            initiatingCharacterName: ally.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "thank", text: "Thank them warmly", shortText: "Thank Them", effects: [:], followUpHint: "Strengthens the friendship"),
                EventResponse(id: "investigate", text: "Ask them to find out more", shortText: "Investigate", effects: ["network": 3])
            ],
            iconName: "person.fill.checkmark",
            accentColor: "statHigh"
        )
    }

    private func generateAllyRequest(ally: GameCharacter, game: Game) -> DynamicEvent {
        // Variety in request types
        let requests: [(title: String, text: String, helpEffect: [String: Int])] = [
            (
                title: "A Request from a Friend",
                text: "\(ally.name) approaches you, looking troubled.\n\n\"Comrade, I need a favor. My brother-in-law has gotten into difficulty with the local party committee. A word from you could help resolve things quietly. I would not forget such a kindness.\"",
                helpEffect: ["network": 5, "patronFavor": -3]
            ),
            (
                title: "Helping a Colleague",
                text: "\(ally.name) corners you in the canteen.\n\n\"A position is opening in the trade ministry. My cousin would be perfect for it. You know people there, don't you? I'd owe you one.\"",
                helpEffect: ["network": 4, "standing": 2]
            ),
            (
                title: "A Small Favor",
                text: "\(ally.name) slips into step beside you.\n\n\"I hear you have contacts at the printing office. There's a report that needs to be... adjusted before it reaches the Presidium. Nothing major. Just smoothing out some unfortunate statistics.\"",
                helpEffect: ["network": 6, "corruptionEvidence": 3]
            ),
            (
                title: "A Quiet Request",
                text: "\(ally.name) checks that no one is listening.\n\n\"My sister needs an exit visa. For medical treatment, you understand. The official channels have been... uncooperative. But someone with your connections...\"",
                helpEffect: ["network": 7, "patronFavor": -4]
            )
        ]

        let request = requests.randomElement()!

        return DynamicEvent(
            eventType: .allyRequest,
            priority: .normal,
            title: request.title,
            briefText: request.text,
            initiatingCharacterId: ally.id,
            initiatingCharacterName: ally.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "help", text: "Agree to help—building alliances is valuable", shortText: "Help Them", effects: request.helpEffect),
                EventResponse(id: "delay", text: "Promise to look into it (noncommittal)", shortText: "Delay", effects: [:]),
                EventResponse(id: "refuse", text: "Decline—you can't afford the risk", shortText: "Decline", effects: ["network": -3])
            ],
            iconName: "person.fill.questionmark",
            accentColor: "inkGray"
        )
    }

    // MARK: - Consequence Callbacks

    private func checkConsequenceCallbacks(game: Game) -> [DynamicEvent] {
        var events: [DynamicEvent] = []

        // Look for past decisions with followUpHooks
        for event in game.events where event.currentEventType == .decision {
            guard let followUpHook = event.details["followUpHook"],
                  !followUpHook.isEmpty else { continue }

            // Calculate turns since decision
            let turnsSince = game.turnNumber - event.turnNumber
            guard turnsSince >= 2 && turnsSince <= 10 else { continue }

            // Check if already called back
            let callbackFlag = "callback_\(event.id.uuidString.prefix(8))"
            guard !game.flags.contains(callbackFlag) else { continue }

            // Probability increases with time
            let callbackChance = Double(turnsSince - 1) * 0.08 + 0.05

            if Double.random(in: 0...1) < callbackChance {
                if let callback = generateCallback(originalEvent: event, followUpHook: followUpHook, game: game) {
                    events.append(callback)
                    break  // Only one callback per turn
                }
            }
        }

        return events
    }

    private func generateCallback(originalEvent: GameEvent, followUpHook: String, game: Game) -> DynamicEvent? {
        let callbackFlag = "callback_\(originalEvent.id.uuidString.prefix(8))"

        return DynamicEvent(
            eventType: .consequenceCallback,
            priority: .elevated,
            title: "Echoes of the Past",
            briefText: followUpHook,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "acknowledge", text: "Deal with it", shortText: "Deal With It", effects: [:], setsFlag: callbackFlag)
            ],
            linkedDecisionId: originalEvent.details["decisionId"],
            linkedTurnNumber: originalEvent.turnNumber,
            callbackFlag: callbackFlag,
            iconName: "arrow.uturn.backward.circle.fill",
            accentColor: "inkGray"
        )
    }

    // MARK: - Urgent Interruptions

    private func checkUrgentInterruptions(game: Game) -> [DynamicEvent] {
        // Skip if a crisis document was already generated this turn (avoid double-crisis)
        if DocumentQueueService.shared.didGenerateCrisisDocumentThisTurn() {
            return []
        }

        var events: [DynamicEvent] = []

        // Critical stat thresholds - only one per turn (else-if chain)
        if game.stability < 25 && Double.random(in: 0...1) < 0.35 {
            events.append(generateStatCrisis(stat: "stability", value: game.stability, game: game))
        } else if game.foodSupply < 25 && Double.random(in: 0...1) < 0.35 {
            events.append(generateStatCrisis(stat: "food", value: game.foodSupply, game: game))
        } else if game.militaryLoyalty < 25 && Double.random(in: 0...1) < 0.30 {
            events.append(generateStatCrisis(stat: "military", value: game.militaryLoyalty, game: game))
        }

        return events
    }

    private func generateStatCrisis(stat: String, value: Int, game: Game) -> DynamicEvent {
        let (title, text) = getStatCrisisContent(stat: stat, value: value)

        return DynamicEvent(
            eventType: .urgentInterruption,
            priority: .urgent,
            title: title,
            briefText: text,
            turnGenerated: game.turnNumber,
            isUrgent: true,
            responseOptions: [
                EventResponse(id: "handle", text: "This requires immediate attention", shortText: "Address It", effects: [:])
            ],
            iconName: "exclamationmark.triangle.fill",
            accentColor: "stampRed"
        )
    }

    private func getStatCrisisContent(stat: String, value: Int) -> (String, String) {
        switch stat {
        case "stability":
            return ("UNREST SPREADING", "Reports flood in from across the republic. Protests in the industrial districts. Workers refusing to meet quotas. The security services are stretched thin.\n\nThe General Secretary is watching. Action is required.")
        case "food":
            return ("FOOD CRISIS DEEPENING", "The harvest reports are grim. Bread lines grow longer by the day. There have been incidents—scuffles, even looting.\n\nThe people's patience is running out.")
        case "military":
            return ("MILITARY DISCONTENT", "Troubling reports from the barracks. Officers grumbling about civilian interference. Talk of \"restoring order.\"\n\nMarshal Anderson has requested an urgent meeting.")
        default:
            return ("CRISIS DEVELOPING", "The situation is deteriorating. Immediate action is required.")
        }
    }

    // MARK: - Ambient Tension

    private func checkAmbientTension(game: Game) -> [DynamicEvent] {
        // Only generate tension when things are building but not critical
        guard game.turnNumber > 3 else { return [] }

        var events: [DynamicEvent] = []

        // Rising rival threat
        if game.rivalThreat > 50 && game.rivalThreat < 80 && Double.random(in: 0...1) < 0.15 {
            events.append(generateTensionEvent(type: .rivalPlotting, game: game))
        }

        // Fading patron favor
        if game.patronFavor > 30 && game.patronFavor < 50 && Double.random(in: 0...1) < 0.12 {
            events.append(generateTensionEvent(type: .patronDistant, game: game))
        }

        // General unease
        if game.stability > 30 && game.stability < 50 && Double.random(in: 0...1) < 0.10 {
            events.append(generateTensionEvent(type: .generalUnease, game: game))
        }

        return events
    }

    private enum TensionType {
        case rivalPlotting
        case patronDistant
        case generalUnease
    }

    private func generateTensionEvent(type: TensionType, game: Game) -> DynamicEvent {
        let rivalName = game.primaryRival?.name ?? "Your rival"
        let patronName = game.patron?.name ?? "Your patron"

        let (title, text): (String, String)

        switch type {
        case .rivalPlotting:
            title = "Whispers in the Corridor"
            text = "You pass \(rivalName) speaking quietly with Marshal Anderson. They fall silent as you approach.\n\n\"Comrade,\" \(rivalName) nods. Their smile doesn't reach their eyes.\n\nYou continue walking, but you can feel their gaze on your back."
        case .patronDistant:
            title = "A Cooling Wind"
            text = "\(patronName) passes you in the ministry hallway without a word. Not even a nod of acknowledgment.\n\nPerhaps they were distracted. Perhaps not."
        case .generalUnease:
            title = "Something in the Air"
            text = "The ministry feels different today. Conversations stop when you enter rooms. Eyes follow you down corridors.\n\nOr perhaps you're imagining things."
        }

        return DynamicEvent(
            eventType: .ambientTension,
            priority: .background,
            title: title,
            briefText: text,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: nil,  // No response needed
            iconName: "eye.fill",
            accentColor: "inkLight"
        )
    }

    // MARK: - Network Intel (Enhanced with IntelligenceLeakService)

    private func checkNetworkIntel(game: Game) -> [DynamicEvent] {
        guard game.network >= 30 else { return [] }

        var events: [DynamicEvent] = []

        // Try to generate a leak using IntelligenceLeakService
        if let leak = IntelligenceLeakService.shared.tryGenerateLeakEvent(for: game) {
            events.append(generateNetworkIntelFromLeak(leak: leak, game: game))
        }

        return events
    }

    private func generateNetworkIntelFromLeak(leak: IntelligenceLeak, game: Game) -> DynamicEvent {
        let priority: EventPriority
        let iconName: String

        switch leak.quality {
        case .low:
            priority = .background
            iconName = "ear.fill"
        case .medium:
            priority = .normal
            iconName = "doc.text.fill"
        case .high:
            priority = .elevated
            iconName = "eye.fill"
        }

        return DynamicEvent(
            eventType: .networkIntel,
            priority: priority,
            title: leak.title,
            briefText: leak.content,
            initiatingCharacterId: leak.relatedCharacterId != nil ? UUID() : nil,
            initiatingCharacterName: nil,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "journal",
                    text: "Record this in your personal journal",
                    shortText: "Add to Journal",
                    effects: [:]
                ),
                EventResponse(
                    id: "investigate",
                    text: "Have your contacts dig deeper",
                    shortText: "Investigate",
                    effects: ["network": -2],
                    setsFlag: "investigating_\(leak.relatedCharacterId ?? "intel")"
                ),
                EventResponse(
                    id: "share",
                    text: "Share this with a trusted colleague",
                    shortText: "Share Intel",
                    effects: ["network": 1],
                    setsFlag: "shared_intelligence"
                )
            ],
            iconName: iconName,
            accentColor: leak.quality == .high ? "sovietRed" : "accentGold"
        )
    }

    // Fallback for basic network intel
    private func generateNetworkIntel(game: Game) -> DynamicEvent {
        let rivalName = game.primaryRival?.name ?? "a rival"

        let intels = [
            ("Network Report", "Your contacts have gathered intelligence:\n\n\"\(rivalName) has been meeting with foreign diplomats. The conversations appear... unofficial.\""),
            ("Whispered Warning", "Word reaches you through back channels: State Security is conducting a review of ministry expenditures. Your department is on the list."),
            ("Useful Information", "A contact in the records office sends word: someone has been requesting your personnel file. They wouldn't say who.")
        ]

        let (title, text) = intels.randomElement()!

        return DynamicEvent(
            eventType: .networkIntel,
            priority: .normal,
            title: title,
            briefText: text,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "note", text: "File this away for later", shortText: "Note It", effects: [:]),
                EventResponse(id: "investigate", text: "Have your contacts dig deeper", shortText: "Investigate", effects: ["network": -2], setsFlag: "investigating_intel")
            ],
            iconName: "antenna.radiowaves.left.and.right",
            accentColor: "accentGold"
        )
    }

    // MARK: - Pacing Logic

    private func shouldBeQuietTurn(game: Game) -> Bool {
        // Force quiet turn after too many consecutive event turns
        if consecutiveEventTurns >= BalanceConfig.forceQuietAfterEventTurns {
            consecutiveEventTurns = 0
            return true
        }

        // Early game: more quiet turns to establish rhythm
        if game.turnNumber <= 3 {
            return Double.random(in: 0...1) < (BalanceConfig.quietTurnChance + BalanceConfig.earlyGameQuietBonus)
        }

        // Base quiet probability (from BalanceConfig)
        var quietChance = BalanceConfig.quietTurnChance

        // More quiet turns after events
        quietChance += Double(consecutiveEventTurns) * 0.15

        // Less quiet when situation is tense
        if game.stability < 40 { quietChance -= BalanceConfig.crisisQuietPenalty }
        if game.rivalThreat > 60 { quietChance -= 0.10 }
        if game.patronFavor < 40 { quietChance -= 0.10 }

        return Double.random(in: 0...1) < quietChance
    }

    private func getMaxEventsForTurn(game: Game) -> Int {
        // Normally 1, critical situations allow 2
        if game.stability < 25 || game.rivalThreat > 85 || game.patronFavor < 20 {
            return 2
        }
        return 1
    }

    private func filterByCooldowns(_ events: [DynamicEvent], game: Game) -> [DynamicEvent] {
        return events.filter { event in
            // Use Game model's persisted cooldown tracking (survives app restart)
            if game.isEventTypeOnCooldown(event.eventType) {
                // Urgent events get reduced cooldown (1 turn) but don't fully bypass
                // This prevents "urgent event every turn" during crises
                if event.priority >= .urgent {
                    return game.isEventTypeOnReducedCooldown(event.eventType)
                }
                return false
            }
            return true
        }
    }

    private func selectEvent(from events: [DynamicEvent], game: Game) -> DynamicEvent? {
        guard !events.isEmpty else { return nil }

        // Sort by priority (highest first)
        let sorted = events.sorted { $0.priority > $1.priority }

        // Critical/urgent events always fire
        if let urgent = sorted.first(where: { $0.priority >= .urgent }) {
            return urgent
        }

        // Otherwise, weighted random from top priority tier
        let topPriority = sorted[0].priority
        let topCandidates = sorted.filter { $0.priority == topPriority }

        return topCandidates.randomElement()
    }

    // MARK: - NPC Autonomous Actions

    private func checkNPCAutonomousActions(game: Game) -> [DynamicEvent] {
        // Check for NPC-to-NPC political actions
        if let event = CharacterAgencyService.shared.evaluateNPCvsNPCActions(game: game) {
            return [event]
        }
        return []
    }

    // MARK: - Assassination Risk

    private func checkAssassinationRisks(game: Game) -> [DynamicEvent] {
        var events: [DynamicEvent] = []

        // Check for assassination attempts (player or NPC)
        if let attemptEvent = GameEngine.shared.checkAssassinationRisks(game: game) {
            events.append(attemptEvent)
        }

        // If no attempt this turn, check for warning signs (foreshadowing)
        if events.isEmpty {
            if let warningEvent = GameEngine.shared.checkForAssassinationWarnings(game: game) {
                events.append(warningEvent)
            }
        }

        return events
    }

    // MARK: - People's Congress Events

    private func checkPeoplesCongressEvents(game: Game) -> [DynamicEvent] {
        // Check if it's time for a Congress session
        guard game.shouldConveneCongress else { return [] }

        // Check if there's already an active or recent session
        if let lastSession = game.congressSessions.last {
            if lastSession.isInSession {
                // Progress existing session
                return [generateCongressProgressEvent(session: lastSession, game: game)]
            }
            // Don't convene again too soon
            let turnsSinceLast = game.turnNumber - lastSession.turnConvened
            if turnsSinceLast < CongressSessionType.sessionInterval {
                return []
            }
        }

        // Convene new session
        let session = game.conveneCongressSession(type: .annual)
        session.game = game
        game.congressSessions.append(session)

        return [generateCongressConveneEvent(session: session, game: game)]
    }

    private func generateCongressConveneEvent(session: CongressSession, game: Game) -> DynamicEvent {
        // Generate headline for newspaper integration
        _ = NewspaperGenerator.shared.generateCongressHeadline(session: session, game: game)

        return DynamicEvent(
            eventType: .worldNews,
            priority: .elevated,
            title: session.newspaperHeadline,
            briefText: "The People's Congress has convened in Washington. \(session.delegatesPresent) delegates have assembled from all zones to affirm Party policies and demonstrate the unity of the socialist state.\n\nAs a rising official, your attendance may be expected.",
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "attend", text: "Attend the Congress session", shortText: "Attend", effects: ["standing": 3]),
                EventResponse(id: "observe", text: "Observe from a distance", shortText: "Observe", effects: [:]),
                EventResponse(id: "excuse", text: "Find an excuse to be elsewhere", shortText: "Avoid", effects: ["standing": -2])
            ],
            iconName: "building.columns.fill",
            accentColor: "sovietRed"
        )
    }

    private func generateCongressProgressEvent(session: CongressSession, game: Game) -> DynamicEvent {
        // Progress the session
        switch session.currentStatus {
        case .convening:
            session.status = CongressStatus.deliberating.rawValue
            return DynamicEvent(
                eventType: .worldNews,
                priority: .normal,
                title: "Congress Deliberations Begin",
                briefText: "The People's Congress has begun deliberations on the national agenda. Speeches extol the wisdom of Party leadership and the achievements of socialist construction.",
                turnGenerated: game.turnNumber,
                isUrgent: false,
                responseOptions: nil,
                iconName: "building.columns.fill",
                accentColor: "sovietRed"
            )

        case .deliberating:
            session.status = CongressStatus.voting.rawValue
            session.processVotes()
            return DynamicEvent(
                eventType: .worldNews,
                priority: .normal,
                title: "Congress Voting Underway",
                briefText: "The People's Congress is voting on key measures. Early indications suggest overwhelming support for all Party-backed proposals.",
                turnGenerated: game.turnNumber,
                isUrgent: false,
                responseOptions: nil,
                iconName: "hand.raised.fill",
                accentColor: "sovietRed"
            )

        case .voting:
            session.conclude(turn: game.turnNumber)
            let unanimousCount = session.votingResults.filter { $0.wasUnanimous }.count
            return DynamicEvent(
                eventType: .worldNews,
                priority: .elevated,
                title: session.conclusionHeadline,
                briefText: "The People's Congress has concluded its session. All measures passed with overwhelming majorities. \(unanimousCount) votes were unanimous.\n\nThe session has granted \(session.legitimacyGranted) legitimacy points to state policies.",
                turnGenerated: game.turnNumber,
                isUrgent: false,
                responseOptions: nil,
                iconName: "checkmark.seal.fill",
                accentColor: "statHigh"
            )

        default:
            return DynamicEvent(
                eventType: .worldNews,
                priority: .background,
                title: "Congress News",
                briefText: "The People's Congress session continues.",
                turnGenerated: game.turnNumber,
                isUrgent: false,
                responseOptions: nil,
                iconName: "building.columns.fill",
                accentColor: "sovietRed"
            )
        }
    }

    // MARK: - Show Trial Events

    private func checkShowTrialEvents(game: Game) -> [DynamicEvent] {
        // Check for any active show trials that need phase advancement
        // Trials progress automatically through phases over multiple turns

        var events: [DynamicEvent] = []

        // Get any trials that need to advance this turn
        let trialEvents = ShowTrialService.shared.checkTrialsForAdvancement(game: game)
        events.append(contentsOf: trialEvents)

        // Also check if powerful NPCs might initiate trials against rivals (rare)
        if game.activeShowTrials.isEmpty && game.turnNumber > 10 {
            // Small chance of NPC-initiated purge event
            if Double.random(in: 0...1) < 0.03 {  // 3% per turn
                if let purgeEvent = generateNPCPurgeInitiationEvent(game: game) {
                    events.append(purgeEvent)
                }
            }
        }

        return events
    }

    /// Generate an event where a powerful NPC initiates action against a rival
    private func generateNPCPurgeInitiationEvent(game: Game) -> DynamicEvent? {
        // Find a high-ranking ambitious character who might move against a rival
        let potentialInstigators = game.characters.filter { char in
            guard char.isAlive,
                  let positionIndex = char.positionIndex,
                  positionIndex >= 5,  // High ranking
                  char.personalityAmbitious > 60,
                  char.personalityRuthless > 50 else { return false }
            return true
        }

        guard let instigator = potentialInstigators.randomElement() else { return nil }

        // Find a potential target (rival or competitor)
        let potentialTargets = game.characters.filter { char in
            guard char.isAlive,
                  char.id != instigator.id,
                  let targetIndex = char.positionIndex,
                  let instigatorIndex = instigator.positionIndex,
                  targetIndex >= instigatorIndex - 1,  // Similar or higher position
                  targetIndex <= instigatorIndex + 1 else { return false }

            // Check if there's rivalry between them
            if let relationship = game.npcRelationships.first(where: {
                ($0.sourceCharacterId == instigator.templateId && $0.targetCharacterId == char.templateId) ||
                ($0.targetCharacterId == instigator.templateId && $0.sourceCharacterId == char.templateId)
            }) {
                return relationship.isRival || relationship.disposition < -20
            }
            return false
        }

        guard let target = potentialTargets.randomElement() else { return nil }

        return DynamicEvent(
            eventType: .networkIntel,
            priority: .elevated,
            title: "Whispers of Accusation",
            briefText: "Your network reports that \(instigator.name) is gathering evidence against \(target.name).",
            detailedText: """
            Reliable sources indicate that \(instigator.name) has been making inquiries with \
            State Security about \(target.name). Documents are being collected, and former \
            associates questioned.

            The charges being assembled appear to involve \(TrialCharge.allCases.randomElement()!.displayName.lowercased()). \
            Your informants suggest the case could be brought to the Procurator within weeks.

            This may be an opportunity - or a warning. Such investigations have a way of expanding.
            """,
            flavorText: "\"In this system, everyone has a file.\"",
            initiatingCharacterId: instigator.id,
            relatedCharacterIds: [target.id],
            turnGenerated: game.turnNumber,
            expiresOnTurn: game.turnNumber + 3,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "support_investigation",
                    text: "Quietly support the investigation with your own information.",
                    shortText: "Support",
                    effects: ["network": 5, "reputationCunning": 5],
                    riskLevel: .medium,
                    followUpHint: "\(instigator.name) may remember this favor."
                ),
                EventResponse(
                    id: "warn_target",
                    text: "Discreetly warn \(target.name) of the danger.",
                    shortText: "Warn Target",
                    effects: ["reputationLoyal": 5],
                    riskLevel: .high,
                    followUpHint: "Loyalty can be repaid - or exploited."
                ),
                EventResponse(
                    id: "stay_uninvolved",
                    text: "Keep your distance from this factional struggle.",
                    shortText: "Stay Out",
                    effects: [:],
                    riskLevel: .low,
                    followUpHint: "Sometimes the best move is no move."
                ),
                EventResponse(
                    id: "report_to_patron",
                    text: "Report this maneuvering to your patron.",
                    shortText: "Report Up",
                    effects: ["patronFavor": 5, "reputationLoyal": 3],
                    riskLevel: .low,
                    followUpHint: "The leadership appreciates being informed."
                )
            ]
        )
    }

    // MARK: - Corruption Events

    private func checkCorruptionEvents(game: Game) -> [DynamicEvent] {
        var events: [DynamicEvent] = []

        // Check if player should face corruption investigation
        if CorruptionService.shared.shouldTriggerInvestigation(for: game) {
            if Double.random(in: 0...1) < 0.15 {  // 15% chance when conditions met
                events.append(generateCorruptionInvestigationEvent(game: game))
            }
        }

        return events
    }

    private func generateCorruptionInvestigationEvent(game: Game) -> DynamicEvent {
        return DynamicEvent(
            eventType: .urgentInterruption,
            priority: .elevated,
            title: "Party Discipline Commission Inquires",
            briefText: "A knock at your office door. Two men in dark suits enter without waiting for permission.\n\n\"Comrade, the Central Commission for Discipline Inspection has some questions regarding certain... irregularities in your department's accounts. This is merely routine, of course.\"\n\nTheir smiles don't reach their eyes.",
            turnGenerated: game.turnNumber,
            isUrgent: true,
            responseOptions: [
                EventResponse(
                    id: "cooperate",
                    text: "Cooperate fully - you have nothing to hide",
                    shortText: "Cooperate",
                    effects: ["standing": -5]
                ),
                EventResponse(
                    id: "lawyer",
                    text: "Request time to prepare your records",
                    shortText: "Delay",
                    effects: ["network": -3]
                ),
                EventResponse(
                    id: "patron",
                    text: "Contact your patron immediately",
                    shortText: "Call Patron",
                    effects: ["patronFavor": -10],
                    followUpHint: "Uses significant political capital"
                )
            ],
            iconName: "exclamationmark.shield.fill",
            accentColor: "stampRed"
        )
    }
}
