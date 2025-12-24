//
//  CharacterAgencyService.swift
//  Nomenklatura
//
//  NPC decision-making system - characters decide to act based on
//  personality, opportunity, and risk
//

import Foundation
import os.log

private let npcLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "NPCSystem")

// MARK: - Character Agency Service

@MainActor
class CharacterAgencyService {
    static let shared = CharacterAgencyService()

    // MARK: - Main Evaluation

    /// Determine if any character should act this turn
    /// Returns a DynamicEvent if a character decides to act
    func evaluateCharacterActions(game: Game) -> DynamicEvent? {
        // Check patron first (most important relationship)
        if let patron = game.patron {
            if let action = evaluatePatronAction(patron, game: game) {
                return action
            }
        }

        // Check rival next
        if let rival = game.primaryRival {
            if let action = evaluateRivalAction(rival, game: game) {
                return action
            }
        }

        // Check allies
        let allies = game.characters.filter { char in
            char.isActive && !char.isPatron && !char.isRival && char.disposition >= 60
        }
        for ally in allies {
            if let action = evaluateAllyAction(ally, game: game) {
                return action
            }
        }

        // Check network contacts
        let contacts = game.characters.filter { char in
            char.isActive && char.role == CharacterRole.contact.rawValue
        }
        for contact in contacts {
            if let action = evaluateContactAction(contact, game: game) {
                return action
            }
        }

        // LIVING CHARACTER SYSTEM: Check dynamically discovered characters
        let discoveredCharacters = game.characters.filter { char in
            char.isActive &&
            char.wasDiscoveredDynamically &&
            !char.isPatron &&
            !char.isRival &&
            char.currentRole != .contact &&
            char.currentRole != .informant
        }
        for character in discoveredCharacters {
            if let action = evaluateDiscoveredCharacterAction(character, game: game) {
                return action
            }
        }

        return nil
    }

    // MARK: - Patron Actions

    private func evaluatePatronAction(_ patron: GameCharacter, game: Game) -> DynamicEvent? {
        let motivation = calculatePatronMotivation(patron, game: game)
        let opportunity = calculatePatronOpportunity(patron, game: game)
        let risk = calculatePatronRisk(patron, game: game)

        // Patron caution based on personality
        let caution = Double(100 - patron.personalityRuthless) / 100.0 * 0.5 + 0.5
        let actionThreshold = Double(risk) * caution

        guard Double(motivation + opportunity) > actionThreshold else { return nil }

        // Determine action type based on context
        return selectPatronAction(patron, motivation: motivation, game: game)
    }

    private func calculatePatronMotivation(_ patron: GameCharacter, game: Game) -> Int {
        var motivation = 20  // Base motivation

        // Low favor = patron needs to warn player
        if game.patronFavor < 35 {
            motivation += (35 - game.patronFavor)
        }

        // High favor = patron wants to reward player
        if game.patronFavor > 75 {
            motivation += (game.patronFavor - 75) / 2
        }

        // State in crisis = patron needs action
        if game.stability < 35 {
            motivation += (35 - game.stability) / 2
        }

        // Paranoid patrons act more
        motivation += patron.personalityParanoid / 5

        return motivation
    }

    private func calculatePatronOpportunity(_ patron: GameCharacter, game: Game) -> Int {
        var opportunity = 10

        // Player is vulnerable (rivals circling)
        if game.rivalThreat > 50 {
            opportunity += 15
        }

        // Major event recently happened
        if let lastEvent = game.events.last, lastEvent.importance >= 7 {
            opportunity += 10
        }

        return opportunity
    }

    private func calculatePatronRisk(_ patron: GameCharacter, game: Game) -> Int {
        var risk = 20  // Base risk

        // High stability = risky to make waves
        if game.stability > 70 {
            risk += 20
        }

        // Patron is paranoid
        risk += patron.personalityParanoid / 4

        return risk
    }

    private func selectPatronAction(_ patron: GameCharacter, motivation: Int, game: Game) -> DynamicEvent? {
        // Random roll determines if action fires (weighted by motivation)
        let actionChance = Double(motivation) / 200.0
        guard Double.random(in: 0...1) < actionChance else { return nil }

        // Check cooldown
        guard !game.isEventTypeOnCooldown(.patronDirective) else { return nil }

        // Use centralized EventGenerationService for event creation
        let eventService = EventGenerationService.shared

        // Select action type based on game state using GameplayConstants
        if game.patronFavor < GameplayConstants.Patron.criticalFavorThreshold {
            return eventService.generatePatronSummons(patron: patron, game: game)
        } else if game.patronFavor < GameplayConstants.Patron.lowFavorThreshold {
            return eventService.generatePatronWarning(patron: patron, game: game)
        } else if game.patronFavor > GameplayConstants.Patron.highFavorThreshold && game.stability > GameplayConstants.Stability.lowThreshold {
            return eventService.generatePatronOpportunity(patron: patron, game: game)
        } else if game.stability < GameplayConstants.Stability.criticalThreshold {
            return eventService.generatePatronDirective(patron: patron, game: game)
        }

        return nil
    }

    // MARK: - Rival Actions

    private func evaluateRivalAction(_ rival: GameCharacter, game: Game) -> DynamicEvent? {
        let motivation = calculateRivalMotivation(rival, game: game)
        let opportunity = calculateRivalOpportunity(rival, game: game)
        let risk = calculateRivalRisk(rival, game: game)

        // Rival caution based on personality (ambitious = less cautious)
        let caution = Double(100 - rival.personalityAmbitious) / 100.0
        let actionThreshold = Double(risk) * caution

        guard Double(motivation + opportunity) > actionThreshold else { return nil }

        return selectRivalAction(rival, motivation: motivation, game: game)
    }

    private func calculateRivalMotivation(_ rival: GameCharacter, game: Game) -> Int {
        var motivation = 0

        // Threat level is key driver
        motivation += game.rivalThreat / 2

        // Ambitious rivals more motivated
        motivation += rival.personalityAmbitious / 4

        // Player weakness increases motivation
        if game.standing < 40 {
            motivation += 20
        }
        if game.patronFavor < 50 {
            motivation += 15
        }

        return motivation
    }

    private func calculateRivalOpportunity(_ rival: GameCharacter, game: Game) -> Int {
        var opportunity = 5

        // Low stability = chaos to exploit
        if game.stability < 50 {
            opportunity += (50 - game.stability) / 3
        }

        // Player just made mistake (low standing)
        if game.standing < 35 {
            opportunity += 20
        }

        // Patron distracted or weak
        if game.patronFavor < 40 {
            opportunity += 10
        }

        return opportunity
    }

    private func calculateRivalRisk(_ rival: GameCharacter, game: Game) -> Int {
        var risk = 30  // Base risk

        // High stability = dangerous to act
        if game.stability > 60 {
            risk += 20
        }

        // Player is strong
        if game.standing > 60 {
            risk += 25
        }

        // Paranoid rivals see more risk
        risk += rival.personalityParanoid / 3

        return risk
    }

    private func selectRivalAction(_ rival: GameCharacter, motivation: Int, game: Game) -> DynamicEvent? {
        // Action chance weighted by motivation
        let actionChance = Double(motivation) / 150.0
        guard Double.random(in: 0...1) < actionChance else { return nil }

        // Check cooldown
        guard !game.isEventTypeOnCooldown(.rivalAction) else { return nil }

        // Use centralized EventGenerationService for event creation
        let eventService = EventGenerationService.shared

        // Select action based on threat level using GameplayConstants
        if game.rivalThreat > GameplayConstants.Rival.criticalThreatThreshold {
            // Critical threat: Major attack - use plot discovery (more serious)
            return eventService.generateRivalPlot(rival: rival, game: game)
        } else if game.rivalThreat > GameplayConstants.Rival.highThreatThreshold {
            // High threat: Direct confrontation
            return eventService.generateRivalConfrontation(rival: rival, game: game)
        } else if game.rivalThreat > 30 {
            // Moderate threat: Probing actions - use confrontation with lower intensity
            return generateRivalProbe(rival, game: game)
        }

        return nil
    }

    // MARK: - Ally Actions

    private func evaluateAllyAction(_ ally: GameCharacter, game: Game) -> DynamicEvent? {
        // Allies act based on disposition and whether they have something to share
        let motivation = (ally.disposition - 50) / 2
        let hasIntel = ally.disposition > 75 && game.network > 30

        guard motivation > 10 || hasIntel else { return nil }

        let actionChance = Double(motivation) / 100.0 + (hasIntel ? 0.15 : 0)
        guard Double.random(in: 0...1) < actionChance else { return nil }

        // Use centralized EventGenerationService for event creation
        let eventService = EventGenerationService.shared

        // Check cooldowns - allyRequest and characterMessage have separate cooldowns
        if hasIntel && Double.random(in: 0...1) < 0.6 {
            // Ally intel uses characterMessage type - use assistance event
            guard !game.isEventTypeOnCooldown(.characterMessage) else { return nil }
            return eventService.generateAllyAssistance(ally: ally, game: game)
        } else if ally.disposition > 65 {
            // Ally request uses allyRequest type
            guard !game.isEventTypeOnCooldown(.allyRequest) else { return nil }
            return eventService.generateAllyRequest(ally: ally, game: game)
        }

        return nil
    }

    // MARK: - Contact Actions

    private func evaluateContactAction(_ contact: GameCharacter, game: Game) -> DynamicEvent? {
        guard game.network >= 40 else { return nil }

        // Contacts share intel based on network strength
        let intelChance = Double(game.network - 30) / 200.0
        guard Double.random(in: 0...1) < intelChance else { return nil }

        guard !game.isEventTypeOnCooldown(.networkIntel) else { return nil }

        return generateContactIntel(contact, game: game)
    }

    // MARK: - Event Generators

    private func generatePatronSummons(_ patron: GameCharacter, game: Game) -> DynamicEvent {
        DynamicEvent(
            eventType: .characterSummons,
            priority: .urgent,
            title: "URGENT SUMMONS",
            briefText: "A secretary appears at your door, pale-faced.\n\n\"\(patron.name) demands your presence. Immediately.\"\n\nThis is not a request. Something has happened.",
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: true,
            responseOptions: [
                EventResponse(id: "go", text: "Go immediately", shortText: "Proceed", effects: [:])
            ],
            iconName: "bell.fill",
            accentColor: "stampRed"
        )
    }

    private func generatePatronWarning(_ patron: GameCharacter, game: Game) -> DynamicEvent {
        let texts = [
            "\(patron.name) catches your eye across the ministry corridor and gestures subtly toward an empty office.\n\n\"Be careful,\" they say quietly. \"Your rivals are circling. I may not always be able to protect you.\"",
            "A note arrives, written in \(patron.name)'s distinctive hand:\n\n\"Certain parties have taken notice of your activities. I suggest you consider your position carefully.\"",
            "\(patron.name) sends word through back channels. The tone is concerned:\n\n\"I have heard whispers, Comrade. Questions I cannot easily deflect. Demonstrate your loyalty soon.\""
        ]

        return DynamicEvent(
            eventType: .patronDirective,
            priority: .elevated,
            title: "A Word of Caution",
            briefText: texts.randomElement()!,
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "acknowledge", text: "Thank your patron for the warning", shortText: "Acknowledge", effects: [:]),
                EventResponse(id: "ask", text: "Ask what you should do", shortText: "Seek Guidance", effects: ["patronFavor": 3]),
                EventResponse(id: "dismiss", text: "Assure them you have everything under control", shortText: "Dismiss", effects: ["patronFavor": -5])
            ],
            iconName: "hand.raised.fill",
            accentColor: "accentGold"
        )
    }

    private func generatePatronOpportunity(_ patron: GameCharacter, game: Game) -> DynamicEvent {
        let texts = [
            "\(patron.name) summons you with unusual warmth.\n\n\"Your loyalty has not gone unnoticed, Comrade. A position on the Foreign Affairs Committee has opened. I have recommended you.\"",
            "A message from \(patron.name): \"The General Secretary was impressed with your handling of recent matters. I have arranged for you to present at the next Presidium meeting.\"",
            "\(patron.name) pulls you aside after the morning briefing.\n\n\"Director Kowalski is retiring. His position could be yours, if you play your cards right. I will support your candidacy.\""
        ]

        return DynamicEvent(
            eventType: .patronDirective,
            priority: .normal,
            title: "An Opportunity",
            briefText: texts.randomElement()!,
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "accept_eager", text: "Accept eagerly", shortText: "Accept Eagerly", effects: ["standing": 5, "patronFavor": 5]),
                EventResponse(id: "accept_cautious", text: "Accept with appropriate caution", shortText: "Accept", effects: ["standing": 3]),
                EventResponse(id: "defer", text: "Suggest you are not yet ready", shortText: "Defer", effects: ["patronFavor": -3])
            ],
            iconName: "star.fill",
            accentColor: "accentGold"
        )
    }

    private func generatePatronDirective(_ patron: GameCharacter, game: Game) -> DynamicEvent {
        let crisisArea: String
        if game.stability < 30 {
            crisisArea = "the spreading unrest"
        } else if game.foodSupply < 30 {
            crisisArea = "the food situation"
        } else if game.popularSupport < 30 {
            crisisArea = "popular discontent"
        } else {
            crisisArea = "the current situation"
        }

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
                EventResponse(id: "accept", text: "Accept the responsibility", shortText: "Accept", effects: ["patronFavor": 5], followUpHint: "You will be held accountable"),
                EventResponse(id: "resources", text: "Request additional resources", shortText: "Request Resources", effects: ["patronFavor": -2, "network": 5]),
                EventResponse(id: "deflect", text: "Suggest someone else is better suited", shortText: "Deflect", effects: ["patronFavor": -10])
            ],
            iconName: "exclamationmark.circle.fill",
            accentColor: "sovietRed"
        )
    }

    private func generateRivalAttack(_ rival: GameCharacter, game: Game) -> DynamicEvent {
        let texts = [
            "\(rival.name) has not been idle. Word reaches you that they have been meeting privately with members of the Central Committee, spreading doubts about your competence.\n\nThree officials who once supported you have grown distant.",
            "At this morning's briefing, \(rival.name) publicly questions a decision you made last week. The General Secretary's expression is unreadable.\n\nThis was no accident.",
            "An anonymous complaint about your department has appeared on the General Secretary's desk. The handwriting looks familiar.\n\n\(rival.name) is making their move."
        ]

        return DynamicEvent(
            eventType: .rivalAction,
            priority: .elevated,
            title: "A Move Against You",
            briefText: texts.randomElement()!,
            initiatingCharacterId: rival.id,
            initiatingCharacterName: rival.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "confront", text: "Confront them publicly", shortText: "Confront", effects: ["standing": -5, "rivalThreat": -15], riskLevel: .high),
                EventResponse(id: "evidence", text: "Gather evidence against them", shortText: "Investigate", effects: ["network": -3], setsFlag: "gathering_rival_evidence"),
                EventResponse(id: "patron", text: "Appeal to your patron", shortText: "Seek Protection", effects: ["patronFavor": -8])
            ],
            iconName: "bolt.fill",
            accentColor: "stampRed"
        )
    }

    private func generateRivalScheme(_ rival: GameCharacter, game: Game) -> DynamicEvent {
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
                EventResponse(id: "ignore", text: "Ignore it", shortText: "Ignore", effects: ["rivalThreat": 5]),
                EventResponse(id: "counter", text: "Spread rumors about them", shortText: "Counter-Rumors", effects: ["rivalThreat": -5, "reputationCunning": 5]),
                EventResponse(id: "warn", text: "Arrange a private warning", shortText: "Private Warning", effects: ["rivalThreat": -3])
            ],
            iconName: "ear.fill",
            accentColor: "inkGray"
        )
    }

    private func generateRivalProbe(_ rival: GameCharacter, game: Game) -> DynamicEvent {
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
                EventResponse(id: "agree", text: "Agree cautiously", shortText: "Agree", effects: ["rivalThreat": -5, "reputationLoyal": -3]),
                EventResponse(id: "deflect", text: "Give a non-committal response", shortText: "Deflect", effects: ["reputationCunning": 3]),
                EventResponse(id: "loyal", text: "Express firm loyalty to the General Secretary", shortText: "Show Loyalty", effects: ["reputationLoyal": 5, "rivalThreat": 3])
            ],
            iconName: "questionmark.circle.fill",
            accentColor: "inkGray"
        )
    }

    private func generateAllyIntel(_ ally: GameCharacter, game: Game) -> DynamicEvent {
        let rivalName = game.primaryRival?.name ?? "your rival"

        return DynamicEvent(
            eventType: .characterMessage,
            priority: .normal,
            title: "Friendly Intelligence",
            briefText: "\(ally.name) finds a moment to speak with you privately.\n\n\"I thought you should know—I overheard something in the canteen. \(rivalName) has been asking about the foreign delegation visit. They may be planning something.\"",
            initiatingCharacterId: ally.id,
            initiatingCharacterName: ally.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "thank", text: "Thank them warmly", shortText: "Thank Them", effects: [:]),
                EventResponse(id: "investigate", text: "Ask them to find out more", shortText: "Investigate", effects: ["network": 3])
            ],
            iconName: "person.fill.checkmark",
            accentColor: "statHigh"
        )
    }

    private func generateAllyRequest(_ ally: GameCharacter, game: Game) -> DynamicEvent {
        // Variety in request types
        let requests: [(title: String, text: String, helpEffect: [String: Int])] = [
            (
                title: "A Request from a Friend",
                text: "\(ally.name) approaches you, looking troubled.\n\n\"Comrade, I need a favor. My brother-in-law has gotten into difficulty with the local party committee. A word from you could resolve things quietly. I would not forget such a kindness.\"",
                helpEffect: ["network": 5, "patronFavor": -3]
            ),
            (
                title: "A Colleague's Plea",
                text: "\(ally.name) finds you in the corridor after the meeting.\n\n\"Comrade, my daughter has been denied admission to the university. Her file was 'lost.' I know you have connections in education. Could you make an inquiry? I would be deeply grateful.\"",
                helpEffect: ["network": 4, "standing": 2]
            ),
            (
                title: "An Old Debt",
                text: "\(ally.name) pulls you aside during the reception.\n\n\"Remember when I helped with that matter last spring? Now I need to call in that favor. There's a procurement contract that needs to go to a particular factory. Nothing illegal—just... steering things in the right direction.\"",
                helpEffect: ["network": 6, "corruptionEvidence": 2]
            ),
            (
                title: "A Personal Matter",
                text: "\(ally.name) approaches with unusual hesitation.\n\n\"This is delicate, comrade. A friend of mine—someone important—needs a certain document to disappear from the archives. Nothing treasonous, just embarrassing youthful indiscretions. Can you help?\"",
                helpEffect: ["network": 8, "corruptionEvidence": 5, "patronFavor": -5]
            ),
            (
                title: "A Friend in Need",
                text: "\(ally.name) catches your arm as you leave.\n\n\"My nephew is being investigated for suspected speculation. He's innocent—just terrible at paperwork. But you know how these things can spiral. Could you speak to someone? Slow things down?\"",
                helpEffect: ["network": 5, "patronFavor": -2, "reputationCunning": 2]
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
                EventResponse(id: "help", text: "Agree to help—favors are currency here", shortText: "Help", effects: request.helpEffect),
                EventResponse(id: "delay", text: "Promise to look into it (noncommittal)", shortText: "Delay", effects: [:]),
                EventResponse(id: "refuse", text: "Decline—you can't afford the exposure", shortText: "Decline", effects: ["network": -3])
            ],
            iconName: "person.fill.questionmark",
            accentColor: "inkGray"
        )
    }

    private func generateContactIntel(_ contact: GameCharacter, game: Game) -> DynamicEvent {
        let rivalName = game.primaryRival?.name ?? "a rival"

        let intels = [
            "Your contacts have gathered intelligence:\n\n\"\(rivalName) has been meeting with foreign diplomats. The conversations appear... unofficial.\"",
            "Word reaches you through back channels: State Security is conducting a review of ministry expenditures. Your department is on the list.",
            "A contact in the records office sends word: someone has been requesting your personnel file. They wouldn't say who.",
            "Your network reports unusual activity: \(rivalName) has been cultivating support among the military leadership."
        ]

        return DynamicEvent(
            eventType: .networkIntel,
            priority: .normal,
            title: "Network Report",
            briefText: intels.randomElement()!,
            initiatingCharacterId: contact.id,
            initiatingCharacterName: contact.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "note", text: "File this away for later", shortText: "Note It", effects: [:]),
                EventResponse(id: "investigate", text: "Have contacts dig deeper", shortText: "Investigate", effects: ["network": -2], setsFlag: "investigating_intel")
            ],
            iconName: "antenna.radiowaves.left.and.right",
            accentColor: "accentGold"
        )
    }

    // MARK: - Living Character System: Discovered Character Actions

    /// Evaluate if a dynamically discovered character should act
    private func evaluateDiscoveredCharacterAction(_ character: GameCharacter, game: Game) -> DynamicEvent? {
        // Characters only act if they've interacted with player before
        guard !character.interactionHistory.isEmpty else { return nil }

        // Check cooldown (at least 5 turns since last action)
        if let lastTurn = character.lastInitiatedTurn,
           game.turnNumber - lastTurn < 5 { return nil }

        // Motivation based on disposition and recent interactions
        let motivation = calculateDiscoveredCharacterMotivation(character, game: game)

        // Action chance
        let actionChance = Double(motivation) / 300.0
        guard Double.random(in: 0...1) < actionChance else { return nil }

        // Check cooldown for character message type
        guard !game.isEventTypeOnCooldown(.characterMessage) else { return nil }

        // For hostile characters, also check rival action cooldown to prevent stacking hostile events
        if character.disposition < 30 {
            guard !game.isEventTypeOnCooldown(.rivalAction) else { return nil }
            return generateHostileCharacterAction(character, game: game)
        } else if character.disposition > 70 {
            return generateFriendlyCharacterAction(character, game: game)
        } else {
            return generateNeutralCharacterAction(character, game: game)
        }
    }

    private func calculateDiscoveredCharacterMotivation(_ character: GameCharacter, game: Game) -> Int {
        var motivation = 10

        // Strong feelings = more likely to act
        motivation += abs(character.disposition - 50) / 2

        // Aggressive characters act more often
        motivation += character.aggressionLevel / 5

        // Recent significant events increase motivation
        let recentInteractions = character.interactionHistory.filter {
            game.turnNumber - $0.turnNumber <= 3
        }
        motivation += recentInteractions.count * 10

        return motivation
    }

    private func generateHostileCharacterAction(_ character: GameCharacter, game: Game) -> DynamicEvent {
        let title = character.title ?? "official"
        let lastInteraction = character.interactionHistory.last

        let texts = [
            "\(character.name) approaches you with cold formality. 'Comrade, we need to discuss the matter from Turn \(lastInteraction?.turnNumber ?? game.turnNumber). Your decision was... noted.'",
            "A message arrives from \(character.name)'s office. The tone is distinctly unfriendly. They have not forgotten.",
            "\(character.name) has been asking questions about your work. The inquiries feel pointed, deliberate.",
            "You encounter \(character.name), the \(title), in the corridor. Their expression hardens when they see you. 'We will speak again, Comrade. Soon.'"
        ]

        character.lastInitiatedTurn = game.turnNumber

        return DynamicEvent(
            eventType: .characterMessage,
            priority: .normal,
            title: "A Cold Reception",
            briefText: texts.randomElement()!,
            initiatingCharacterId: character.id,
            initiatingCharacterName: character.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "confront", text: "Confront their hostility directly", shortText: "Confront", effects: ["standing": -3], riskLevel: .medium),
                EventResponse(id: "ignore", text: "Ignore their posturing", shortText: "Ignore", effects: [:]),
                EventResponse(id: "reconcile", text: "Attempt to make amends", shortText: "Reconcile", effects: ["network": 2])
            ],
            iconName: "person.fill.xmark",
            accentColor: "statLow"
        )
    }

    private func generateFriendlyCharacterAction(_ character: GameCharacter, game: Game) -> DynamicEvent {
        let title = character.title ?? "colleague"

        let texts = [
            "\(character.name) finds a quiet moment to speak with you. 'Comrade, I wanted to thank you for your support. If there is ever anything I can do...'",
            "A note arrives from \(character.name), the \(title). They have heard something interesting and thought you should know.",
            "\(character.name) catches your eye across the ministry canteen. A warm nod. You have a friend here.",
            "\(character.name) approaches during the reception. 'I've been thinking about our previous conversation. I believe I can be of assistance to you.'"
        ]

        character.lastInitiatedTurn = game.turnNumber

        return DynamicEvent(
            eventType: .characterMessage,
            priority: .normal,
            title: "A Friend Reaches Out",
            briefText: texts.randomElement()!,
            initiatingCharacterId: character.id,
            initiatingCharacterName: character.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "accept", text: "Accept their friendship graciously", shortText: "Accept", effects: ["network": 3]),
                EventResponse(id: "leverage", text: "See what they can offer you", shortText: "Leverage", effects: ["network": 2, "reputationCunning": 2]),
                EventResponse(id: "distance", text: "Maintain professional distance", shortText: "Distance", effects: [:])
            ],
            iconName: "person.fill.checkmark",
            accentColor: "statHigh"
        )
    }

    private func generateNeutralCharacterAction(_ character: GameCharacter, game: Game) -> DynamicEvent {
        let title = character.title ?? "colleague"

        // Neutral characters might seek to establish where they stand
        let texts = [
            "\(character.name) requests a brief meeting. 'Comrade, I wanted to discuss our... working relationship. Where do we stand?'",
            "You notice \(character.name), the \(title), observing you during the morning briefing. Their expression is unreadable.",
            "\(character.name) makes a point of greeting you in the corridor. Testing the waters, perhaps.",
            "A junior secretary delivers a message: '\(character.name) would appreciate a moment of your time when convenient.' The tone is carefully neutral."
        ]

        character.lastInitiatedTurn = game.turnNumber

        return DynamicEvent(
            eventType: .characterMessage,
            priority: .background,
            title: "Measuring the Distance",
            briefText: texts.randomElement()!,
            initiatingCharacterId: character.id,
            initiatingCharacterName: character.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "friendly", text: "Respond warmly", shortText: "Be Friendly", effects: [:]),
                EventResponse(id: "cautious", text: "Remain cautiously neutral", shortText: "Be Cautious", effects: [:]),
                EventResponse(id: "cold", text: "Be distant", shortText: "Be Cold", effects: [:])
            ],
            iconName: "person.fill.questionmark",
            accentColor: "inkGray"
        )
    }

    // MARK: - NPC-to-NPC Autonomous Actions

    /// Evaluate and execute NPC-to-NPC actions (called each turn)
    /// Returns the most significant event if any NPC actions affect the player's visibility
    func evaluateNPCvsNPCActions(game: Game) -> DynamicEvent? {
        npcLogger.info("Evaluating NPC autonomous actions for turn \(game.turnNumber)")
        let activeNPCs = game.characters.filter { $0.isActive && !$0.isPatron && !$0.isRival }
        npcLogger.info("Found \(activeNPCs.count) active NPCs to evaluate")

        // Sort by position (higher positions act first)
        let sortedNPCs = activeNPCs.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }

        // Track all events generated this turn (for living world feel)
        var generatedEvents: [DynamicEvent] = []

        // Allow multiple NPCs to act each turn (up to 3 for performance)
        var actionsThisTurn = 0
        let maxActionsPerTurn = 3

        // Each NPC has a chance to take an autonomous action
        for npc in sortedNPCs {
            guard actionsThisTurn < maxActionsPerTurn else { break }

            if let event = evaluateSingleNPCAction(npc, allNPCs: activeNPCs, game: game) {
                generatedEvents.append(event)
                actionsThisTurn += 1
            }
        }

        npcLogger.info("Generated \(generatedEvents.count) NPC action events this turn")

        // Return the highest priority event (others are still recorded in history)
        // Priority: elevated > normal > background
        return generatedEvents.sorted { event1, event2 in
            let priority1 = event1.priority == .elevated ? 2 : (event1.priority == .normal ? 1 : 0)
            let priority2 = event2.priority == .elevated ? 2 : (event2.priority == .normal ? 1 : 0)
            return priority1 > priority2
        }.first
    }

    /// Evaluate if a single NPC should take an autonomous action
    private func evaluateSingleNPCAction(_ actor: GameCharacter, allNPCs: [GameCharacter], game: Game) -> DynamicEvent? {
        // Skip if NPC recently acted (2 turn cooldown - politics moves fast)
        if let lastTurn = actor.lastInitiatedTurn, game.turnNumber - lastTurn < 2 {
            return nil
        }

        // Calculate action motivation based on personality
        let motivation = calculateNPCAutonomousMotivation(actor)

        // Reasonable chance to act based on motivation
        // Base 25% + up to 35% from motivation = max ~60% for highly motivated NPCs
        let actionChance = 0.25 + (Double(motivation) / 200.0)
        guard Double.random(in: 0...1) < actionChance else { return nil }

        // Find potential targets (other NPCs)
        let potentialTargets = allNPCs.filter { $0.id != actor.id }
        guard !potentialTargets.isEmpty else { return nil }

        // Determine action type based on personality and relationships
        let actionType = selectNPCActionType(actor, game: game)

        // Find appropriate target for action
        guard let target = selectNPCActionTarget(actor, actionType: actionType, targets: potentialTargets, game: game) else {
            return nil
        }

        // Per-pair cooldown: Same NPC pair shouldn't interact more than once every 2 turns
        let relationship = getOrCreateNPCRelationship(from: actor, to: target, game: game)
        if game.turnNumber - relationship.lastInteractionTurn < 2 {
            // This pair interacted too recently - find a different target
            let alternateTargets = potentialTargets.filter { $0.id != target.id }
            if let alternateTarget = selectNPCActionTarget(actor, actionType: actionType, targets: alternateTargets, game: game) {
                return executeNPCAction(actor: actor, target: alternateTarget, actionType: actionType, game: game)
            }
            return nil // No valid alternate target, skip this action
        }

        // Execute the action
        return executeNPCAction(actor: actor, target: target, actionType: actionType, game: game)
    }

    private func calculateNPCAutonomousMotivation(_ actor: GameCharacter) -> Int {
        var motivation = 20

        // Ambitious NPCs act more
        motivation += actor.personalityAmbitious / 3

        // Ruthless NPCs take more risks
        motivation += actor.personalityRuthless / 4

        // Competent NPCs are more active schemers
        motivation += actor.personalityCompetent / 4

        // Paranoid NPCs may preemptively strike
        motivation += actor.personalityParanoid / 5

        // Position provides resources to act
        motivation += (actor.positionIndex ?? 0) * 3

        return motivation
    }

    /// Get all actions available to an NPC based on their track and position
    private func getAvailableActionsForNPC(_ actor: GameCharacter, game: Game) -> [NPCActionType] {
        var actions: [NPCActionType] = []

        // Everyone can scheme
        actions += NPCActionType.schemingActions

        let actorPosition = actor.positionIndex ?? 0

        // Track-specific governance actions (require position 3+)
        // Use ExpandedCareerTrack enum for type-safe matching
        if actorPosition >= 3,
           let trackString = actor.positionTrack,
           let track = ExpandedCareerTrack(rawValue: trackString) {
            switch track {
            case .foreignAffairs:
                actions += [.negotiateTreaty, .diplomaticOutreach, .recallAmbassador]
            case .economicPlanning:
                actions += [.setProductionQuota, .allocateResources, .proposeEconomicReform]
            case .securityServices:
                actions += [.launchInvestigation, .conductSurveillance, .detainSuspect]
            case .stateMinistry:
                actions += [.proposeLegislation, .administrativeReform, .manageCrisis]
            case .partyApparatus:
                actions += [.ideologicalCampaign, .cadreReview, .enforceDiscipline]
            case .militaryPolitical:
                actions += [.inspectTroopLoyalty, .politicalIndoctrination, .vetOfficers]
            case .regional:
                // Regional officials can do administrative and crisis management
                actions += [.manageCrisis, .addressShortage, .suppressUnrest]
            case .shared:
                // Shared track (top positions) can access all governance actions at high levels
                if actorPosition >= 6 {
                    actions += [.setNationalPriority, .demandResignation, .reorganizeDepartment]
                }
            }
        }

        // Position-level governance actions
        if actorPosition >= 4 { actions.append(.proposePolicyChange) }
        if actorPosition >= 5 { actions += [.callEmergencyMeeting, .issueDirective] }
        if actorPosition >= 6 { actions += [.demandResignation, .reorganizeDepartment] }
        if actorPosition >= 7 {
            actions.append(.setNationalPriority)
            // Standing Committee members can propose law changes
            if game.standingCommittee?.memberIds.contains(actor.templateId) ?? false {
                actions.append(.proposeLawChange)
            }
        }

        // Reactive actions based on game state (require position 3+)
        if actorPosition >= 3 {
            if game.stability < 50 { actions.append(.respondToCrisis) }
            if game.foodSupply < 40 || game.industrialOutput < 40 { actions.append(.addressShortage) }
            if game.internationalStanding < 40 { actions.append(.handleIncident) }
            if game.stability < 35 { actions.append(.suppressUnrest) }
        }

        return actions
    }

    private func selectNPCActionType(_ actor: GameCharacter, game: Game) -> NPCActionType {
        let availableActions = getAvailableActionsForNPC(actor, game: game)
        var weights: [NPCActionType: Int] = [:]

        // EQUAL BASE WEIGHTS - everyone schemes AND governs equally
        for action in availableActions {
            weights[action] = 20
        }

        let actorPosition = actor.positionIndex ?? 0

        // Personality modifies STYLE, not balance
        if actor.personalityAmbitious > 60 {
            weights[.blockPromotion] = (weights[.blockPromotion] ?? 0) + 15
            weights[.curryFavor] = (weights[.curryFavor] ?? 0) + 10
            weights[.proposePolicyChange] = (weights[.proposePolicyChange] ?? 0) + 15
            weights[.setNationalPriority] = (weights[.setNationalPriority] ?? 0) + 15
            weights[.proposeLawChange] = (weights[.proposeLawChange] ?? 0) + 20
        }
        if actor.personalityRuthless > 60 {
            weights[.denounce] = (weights[.denounce] ?? 0) + 20
            weights[.betrayAlliance] = (weights[.betrayAlliance] ?? 0) + 10
            weights[.makeImplicitThreat] = (weights[.makeImplicitThreat] ?? 0) + 15
            weights[.sabotageProject] = (weights[.sabotageProject] ?? 0) + 12
            weights[.launchInvestigation] = (weights[.launchInvestigation] ?? 0) + 15
            weights[.detainSuspect] = (weights[.detainSuspect] ?? 0) + 15
            weights[.demandResignation] = (weights[.demandResignation] ?? 0) + 10
            weights[.enforceDiscipline] = (weights[.enforceDiscipline] ?? 0) + 10
        }
        if actor.personalityCompetent > 60 {
            weights[.spreadRumors] = (weights[.spreadRumors] ?? 0) + 15
            weights[.shareIntelligence] = (weights[.shareIntelligence] ?? 0) + 10
            weights[.proposeEconomicReform] = (weights[.proposeEconomicReform] ?? 0) + 15
            weights[.administrativeReform] = (weights[.administrativeReform] ?? 0) + 10
            weights[.proposeLegislation] = (weights[.proposeLegislation] ?? 0) + 10
            weights[.proposeLawChange] = (weights[.proposeLawChange] ?? 0) + 15
        }
        if actor.personalityParanoid > 60 {
            weights[.seekProtection] = (weights[.seekProtection] ?? 0) + 20
            weights[.makeImplicitThreat] = (weights[.makeImplicitThreat] ?? 0) + 10
            weights[.conductSurveillance] = (weights[.conductSurveillance] ?? 0) + 15
            weights[.launchInvestigation] = (weights[.launchInvestigation] ?? 0) + 10
            weights[.cadreReview] = (weights[.cadreReview] ?? 0) + 10
        }
        if actor.personalityLoyal > 60 {
            weights[.formAlliance] = (weights[.formAlliance] ?? 0) + 15
            weights[.shareIntelligence] = (weights[.shareIntelligence] ?? 0) + 10
            weights[.betrayAlliance] = 0
            weights[.ideologicalCampaign] = (weights[.ideologicalCampaign] ?? 0) + 10
            weights[.politicalIndoctrination] = (weights[.politicalIndoctrination] ?? 0) + 10
        }

        // High position enables gatherings, threats, and leadership actions
        if actorPosition >= 5 {
            weights[.organizeGathering] = (weights[.organizeGathering] ?? 0) + 15
            weights[.makeImplicitThreat] = (weights[.makeImplicitThreat] ?? 0) + 10
            weights[.issueDirective] = (weights[.issueDirective] ?? 0) + 15
            weights[.callEmergencyMeeting] = (weights[.callEmergencyMeeting] ?? 0) + 10
        }

        // Standing Committee members can propose law changes
        if actorPosition >= 7 && (game.standingCommittee?.memberIds.contains(actor.templateId) ?? false) {
            weights[.proposeLawChange] = (weights[.proposeLawChange] ?? 0) + 25
        }

        // Low position needs to curry favor
        if actorPosition <= 3 {
            weights[.curryFavor] = (weights[.curryFavor] ?? 0) + 20
            weights[.seekProtection] = (weights[.seekProtection] ?? 0) + 10
        }

        // Game state triggers reactive governance
        if game.stability < 40 {
            weights[.denounce] = (weights[.denounce] ?? 0) + 10
            weights[.betrayAlliance] = (weights[.betrayAlliance] ?? 0) + 10
            weights[.makeImplicitThreat] = (weights[.makeImplicitThreat] ?? 0) + 10
            weights[.suppressUnrest] = (weights[.suppressUnrest] ?? 0) + 25
            weights[.manageCrisis] = (weights[.manageCrisis] ?? 0) + 20
            weights[.respondToCrisis] = (weights[.respondToCrisis] ?? 0) + 20
        }

        if game.foodSupply < 30 || game.industrialOutput < 30 {
            weights[.addressShortage] = (weights[.addressShortage] ?? 0) + 25
            weights[.setProductionQuota] = (weights[.setProductionQuota] ?? 0) + 15
            weights[.allocateResources] = (weights[.allocateResources] ?? 0) + 15
        }

        if game.internationalStanding < 40 {
            weights[.handleIncident] = (weights[.handleIncident] ?? 0) + 20
            weights[.diplomaticOutreach] = (weights[.diplomaticOutreach] ?? 0) + 15
            weights[.negotiateTreaty] = (weights[.negotiateTreaty] ?? 0) + 10
        }

        // High stability encourages building networks
        if game.stability > 60 {
            weights[.formAlliance] = (weights[.formAlliance] ?? 0) + 10
            weights[.organizeGathering] = (weights[.organizeGathering] ?? 0) + 10
            weights[.cultivateSupport] = (weights[.cultivateSupport] ?? 0) + 10
        }

        // NPC BEHAVIOR SYSTEM: Goal alignment bonus
        for action in availableActions {
            weights[action] = (weights[action] ?? 0) + goalAlignmentBonus(action: action, actor: actor, game: game)
        }

        // NPC BEHAVIOR SYSTEM: Need satisfaction bonus
        for action in availableActions {
            weights[action] = (weights[action] ?? 0) + needSatisfactionBonus(action: action, actor: actor)
        }

        // NPC BEHAVIOR SYSTEM: Party devotion modifier
        for action in availableActions {
            weights[action] = (weights[action] ?? 0) + partyDevotionModifier(character: actor, action: action)
        }

        // Filter to only available actions
        let filteredWeights = weights.filter { availableActions.contains($0.key) && $0.value > 0 }

        // Weighted random selection
        let totalWeight = filteredWeights.values.reduce(0, +)
        guard totalWeight > 0 else { return .spreadRumors }

        var roll = Int.random(in: 0..<totalWeight)

        for (action, weight) in filteredWeights {
            roll -= weight
            if roll < 0 {
                return action
            }
        }

        return .spreadRumors // fallback
    }

    private func selectNPCActionTarget(_ actor: GameCharacter, actionType: NPCActionType, targets: [GameCharacter], game: Game) -> GameCharacter? {
        let actorPosition = actor.positionIndex ?? 0

        switch actionType {
        case .formAlliance:
            // Target: Someone in similar position, not already allied, positive or neutral disposition
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return !isAllied(actor, with: target, game: game) &&
                       !isRival(actor, with: target, game: game) &&
                       abs(actorPosition - targetPosition) <= 2
            }.randomElement()

        case .betrayAlliance:
            // Target: Current ally - but only if alliance is mature (3+ turns old)
            return targets.filter { target in
                guard isAllied(actor, with: target, game: game) else { return false }
                // Check alliance duration - require at least 3 turns before betrayal is possible
                if let relationship = game.npcRelationships.first(where: {
                    $0.sourceCharacterId == actor.templateId && $0.targetCharacterId == target.templateId
                }), let formedTurn = relationship.allianceFormedTurn {
                    return game.turnNumber - formedTurn >= 3
                }
                return true // Allow if no formed turn tracked (legacy data)
            }.first

        case .denounce:
            // Target: Lower position rival or someone with high corruption traits
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition < actorPosition ||
                       isRival(actor, with: target, game: game)
            }.sorted { $0.personalityCorrupt > $1.personalityCorrupt }.first

        case .blockPromotion:
            // Target: Lower position NPC in same track who might compete
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition == actorPosition - 1 &&
                       target.positionTrack == actor.positionTrack
            }.randomElement()

        case .spreadRumors:
            // Target: Rival or someone who blocked actor previously
            return targets.filter { target in
                isRival(actor, with: target, game: game) ||
                target.disposition < 30
            }.randomElement()

        case .seekProtection:
            // Target: Higher position NPC, preferably same faction
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition > actorPosition
            }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }.first

        case .cultivateSupport:
            // Target: Lower position NPC who could be useful
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition < actorPosition &&
                       !isRival(actor, with: target, game: game)
            }.randomElement()

        case .shareIntelligence:
            // Target: Ally or potential ally at similar level
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return abs(actorPosition - targetPosition) <= 1 &&
                       !isRival(actor, with: target, game: game)
            }.randomElement()

        case .organizeGathering:
            // Target: Multiple NPCs from same faction (represented by one key figure)
            return targets.filter { target in
                target.factionId == actor.factionId && target.factionId != nil
            }.randomElement() ?? targets.randomElement()

        case .makeImplicitThreat:
            // Target: Rival or someone who wronged actor
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return (isRival(actor, with: target, game: game) ||
                        target.disposition < 20) &&
                       targetPosition <= actorPosition
            }.randomElement()

        case .curryFavor:
            // Target: Higher position NPC with power
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition > actorPosition
            }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }.first

        case .sabotageProject:
            // Target: Rival or competitor in same track
            return targets.filter { target in
                (isRival(actor, with: target, game: game) ||
                 target.positionTrack == actor.positionTrack) &&
                target.disposition < 40
            }.randomElement()

        // GOVERNANCE: Foreign Affairs Track
        case .negotiateTreaty:
            // Target: A colleague to coordinate treaty negotiations with
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition >= 3 && !isRival(actor, with: target, game: game)
            }.randomElement()

        case .diplomaticOutreach:
            // Target: Someone in same or related track to coordinate with
            return targets.filter { target in
                !isRival(actor, with: target, game: game) &&
                (target.positionTrack == ExpandedCareerTrack.foreignAffairs.rawValue ||
                 target.positionTrack == ExpandedCareerTrack.stateMinistry.rawValue)
            }.randomElement() ?? targets.randomElement()

        case .recallAmbassador:
            // Target: Senior official to inform about diplomatic escalation
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition >= 4
            }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }.first

        // GOVERNANCE: Economic Planning Track
        case .setProductionQuota:
            // Target: Economic sector official or regional leader affected
            return targets.filter { target in
                target.positionTrack == ExpandedCareerTrack.economicPlanning.rawValue ||
                target.positionTrack == ExpandedCareerTrack.regional.rawValue
            }.randomElement() ?? targets.randomElement()

        case .allocateResources:
            // Target: Official who will receive or lose resources
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition >= 2 && targetPosition <= actorPosition
            }.randomElement()

        case .proposeEconomicReform:
            // Target: Senior leader to present reform proposal to
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition > actorPosition
            }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }.first

        // GOVERNANCE: Security Services Track
        case .launchInvestigation:
            // Target: Someone to investigate - rival, corrupt, or random
            return targets.filter { target in
                isRival(actor, with: target, game: game) ||
                target.personalityCorrupt > 50 ||
                target.disposition < 30
            }.randomElement() ?? targets.randomElement()

        case .conductSurveillance:
            // Target: Anyone of interest
            return targets.filter { target in
                !isAllied(actor, with: target, game: game)
            }.randomElement() ?? targets.randomElement()

        case .detainSuspect:
            // Target: Someone with low standing or already under suspicion
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition < actorPosition &&
                       (target.fearLevel > 30 || target.personalityCorrupt > 60)
            }.randomElement()

        // GOVERNANCE: State Ministry Track
        case .proposeLegislation:
            // Target: Leader to propose legislation to
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition > actorPosition
            }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }.first

        case .administrativeReform:
            // Target: Department or official affected by reform
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition <= actorPosition &&
                       target.positionTrack == actor.positionTrack
            }.randomElement() ?? targets.randomElement()

        case .manageCrisis:
            // Target: Key official to coordinate crisis response with
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition >= 3 && !isRival(actor, with: target, game: game)
            }.randomElement() ?? targets.randomElement()

        // GOVERNANCE: Party Apparatus Track
        case .ideologicalCampaign:
            // Target: Official whose department is targeted for campaign
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition <= actorPosition
            }.randomElement() ?? targets.randomElement()

        case .cadreReview:
            // Target: Official being reviewed
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition < actorPosition
            }.randomElement()

        case .enforceDiscipline:
            // Target: Official who violated party norms (or actor's rival)
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition < actorPosition &&
                       (isRival(actor, with: target, game: game) || target.personalityCorrupt > 50)
            }.randomElement()

        // GOVERNANCE: Military-Political Track
        case .inspectTroopLoyalty:
            // Target: Military or regional official
            return targets.filter { target in
                target.positionTrack == ExpandedCareerTrack.militaryPolitical.rawValue ||
                target.positionTrack == ExpandedCareerTrack.regional.rawValue
            }.randomElement() ?? targets.randomElement()

        case .politicalIndoctrination:
            // Target: Military unit commander or official
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition <= actorPosition
            }.randomElement() ?? targets.randomElement()

        case .vetOfficers:
            // Target: Officer being vetted
            return targets.filter { target in
                target.positionTrack == ExpandedCareerTrack.militaryPolitical.rawValue
            }.randomElement() ?? targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition < actorPosition
            }.randomElement()

        // GOVERNANCE: Position-Level Actions
        case .proposePolicyChange:
            // Target: Senior leader to propose to
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition > actorPosition
            }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }.first

        case .callEmergencyMeeting:
            // Target: Key official to summon
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition >= 3
            }.randomElement()

        case .issueDirective:
            // Target: Subordinate to issue directive to
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition < actorPosition
            }.randomElement()

        case .demandResignation:
            // Target: Subordinate or rival to force out
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition < actorPosition &&
                       (isRival(actor, with: target, game: game) || target.disposition < 30)
            }.randomElement()

        case .reorganizeDepartment:
            // Target: Official in department being reorganized
            return targets.filter { target in
                target.positionTrack == actor.positionTrack
            }.randomElement() ?? targets.randomElement()

        case .setNationalPriority:
            // Target: Senior colleague to coordinate with
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition >= 5
            }.randomElement()

        case .proposeLawChange:
            // Target: Another Standing Committee member to consult (optional, can be nil)
            return targets.filter { target in
                game.standingCommittee?.memberIds.contains(target.templateId) ?? false
            }.randomElement()

        // GOVERNANCE: Reactive Actions
        case .respondToCrisis:
            // Target: Key official to coordinate response with
            return targets.filter { target in
                let targetPosition = target.positionIndex ?? 0
                return targetPosition >= 3 && !isRival(actor, with: target, game: game)
            }.randomElement() ?? targets.randomElement()

        case .addressShortage:
            // Target: Economic or regional official
            return targets.filter { target in
                target.positionTrack == ExpandedCareerTrack.economicPlanning.rawValue ||
                target.positionTrack == ExpandedCareerTrack.regional.rawValue
            }.randomElement() ?? targets.randomElement()

        case .handleIncident:
            // Target: Foreign Affairs or Security official
            return targets.filter { target in
                target.positionTrack == ExpandedCareerTrack.foreignAffairs.rawValue ||
                target.positionTrack == ExpandedCareerTrack.securityServices.rawValue
            }.randomElement() ?? targets.randomElement()

        case .suppressUnrest:
            // Target: Security or Regional official
            return targets.filter { target in
                target.positionTrack == ExpandedCareerTrack.securityServices.rawValue ||
                target.positionTrack == ExpandedCareerTrack.regional.rawValue
            }.randomElement() ?? targets.randomElement()
        }
    }

    private func executeNPCAction(actor: GameCharacter, target: GameCharacter, actionType: NPCActionType, game: Game) -> DynamicEvent? {
        npcLogger.notice("NPC Action: \(actor.name) → \(actionType.rawValue) → \(target.name)")

        // Update last action turn
        actor.lastInitiatedTurn = game.turnNumber

        // Get or create relationship
        let relationship = getOrCreateNPCRelationship(from: actor, to: target, game: game)

        // Execute action effects
        switch actionType {
        case .formAlliance:
            relationship.formAlliance(turn: game.turnNumber, strength: 40 + Int.random(in: 0...20))
            // Create reciprocal relationship
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.formAlliance(turn: game.turnNumber, strength: 40 + Int.random(in: 0...20))

        case .betrayAlliance:
            relationship.breakAlliance(turn: game.turnNumber, reason: .betrayal)
            // Target now has grudge against actor
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.recordBetrayal(turn: game.turnNumber, severity: 40)

        case .denounce:
            relationship.declareRivalry(turn: game.turnNumber)
            // Target may face consequences - increase their fear level
            target.fearLevel = min(100, target.fearLevel + 15)

        case .blockPromotion:
            relationship.disposition = max(-100, relationship.disposition - 20)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.grudgeLevel = min(100, reciprocal.grudgeLevel + 20)

        case .spreadRumors:
            // Target's disposition suffers as their reputation is damaged
            target.disposition = max(-100, target.disposition - 10)
            relationship.disposition = max(-100, relationship.disposition - 10)

        case .seekProtection:
            relationship.isClient = true
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.isPatron = true
            reciprocal.disposition = min(100, reciprocal.disposition + 10)

        case .cultivateSupport:
            relationship.disposition = min(100, relationship.disposition + 15)
            relationship.trust = min(100, relationship.trust + 10)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.gratitudeLevel = min(100, reciprocal.gratitudeLevel + 10)

        case .shareIntelligence:
            // Sharing information builds trust and creates obligation
            relationship.trust = min(100, relationship.trust + 15)
            relationship.disposition = min(100, relationship.disposition + 10)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.gratitudeLevel = min(100, reciprocal.gratitudeLevel + 15)

        case .organizeGathering:
            // Gatherings build faction cohesion
            relationship.disposition = min(100, relationship.disposition + 5)
            relationship.trust = min(100, relationship.trust + 5)
            // May also strengthen the overall faction

        case .makeImplicitThreat:
            // Threats increase fear but may create enmity
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 25)
            reciprocal.disposition = max(-100, reciprocal.disposition - 15)
            target.fearLevel = min(100, target.fearLevel + 10)

        case .curryFavor:
            // Currying favor improves relationship with superior
            relationship.disposition = min(100, relationship.disposition + 10)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.disposition = min(100, reciprocal.disposition + 5)

        case .sabotageProject:
            // Sabotage damages target's standing
            target.disposition = max(-100, target.disposition - 15)
            relationship.disposition = max(-100, relationship.disposition - 20)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.grudgeLevel = min(100, reciprocal.grudgeLevel + 30)

        // GOVERNANCE: Foreign Affairs Track
        case .negotiateTreaty:
            // Coordinating on treaty builds professional rapport
            relationship.trust = min(100, relationship.trust + 10)
            relationship.disposition = min(100, relationship.disposition + 5)
            // May affect international standing
            game.internationalStanding = min(100, game.internationalStanding + Int.random(in: 1...3))

        case .diplomaticOutreach:
            // Diplomatic coordination builds working relationships
            relationship.disposition = min(100, relationship.disposition + 8)
            game.internationalStanding = min(100, game.internationalStanding + Int.random(in: 1...2))

        case .recallAmbassador:
            // Briefing superiors about escalation
            relationship.trust = min(100, relationship.trust + 5)
            // Diplomatic tension
            game.internationalStanding = max(0, game.internationalStanding - Int.random(in: 1...3))

        // GOVERNANCE: Economic Planning Track
        case .setProductionQuota:
            // Setting quotas affects the target's responsibilities
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            if Int.random(in: 1...100) < 50 {
                // Target resents burden
                reciprocal.disposition = max(-100, reciprocal.disposition - 10)
            } else {
                // Target accepts
                reciprocal.disposition = min(100, reciprocal.disposition + 5)
            }
            // Economic effect
            game.industrialOutput = min(100, max(0, game.industrialOutput + Int.random(in: -2...3)))

        case .allocateResources:
            // Resource allocation creates winners and losers
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.gratitudeLevel = min(100, reciprocal.gratitudeLevel + 10)
            relationship.disposition = min(100, relationship.disposition + 5)

        case .proposeEconomicReform:
            // Proposing reform to superiors
            relationship.disposition = min(100, relationship.disposition + 5)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            if actor.personalityCompetent > 50 {
                reciprocal.disposition = min(100, reciprocal.disposition + 5)
            }

        // GOVERNANCE: Security Services Track
        case .launchInvestigation:
            // Investigation creates fear and potential enmity
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 30)
            reciprocal.disposition = max(-100, reciprocal.disposition - 25)
            target.fearLevel = min(100, target.fearLevel + 20)
            // Investigation damages standing
            target.disposition = max(-100, target.disposition - 10)

        case .conductSurveillance:
            // Surveillance builds intel but creates suspicion if discovered
            relationship.trust = min(100, relationship.trust + 5) // Actor learns more
            if Int.random(in: 1...100) < 30 {
                // Target finds out
                let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
                reciprocal.fear = min(100, reciprocal.fear + 15)
                reciprocal.disposition = max(-100, reciprocal.disposition - 10)
            }

        case .detainSuspect:
            // Detention is severe - removes target from active play temporarily
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 50)
            reciprocal.disposition = max(-100, reciprocal.disposition - 40)
            reciprocal.grudgeLevel = min(100, reciprocal.grudgeLevel + 50)
            target.fearLevel = min(100, target.fearLevel + 40)
            // Target is detained - change their status
            target.status = CharacterStatus.detained.rawValue
            target.statusChangedTurn = game.turnNumber
            target.statusDetails = "Detained for questioning by \(actor.name)"

        // GOVERNANCE: State Ministry Track
        case .proposeLegislation:
            // Proposing legislation builds professional relationships
            relationship.disposition = min(100, relationship.disposition + 5)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.disposition = min(100, reciprocal.disposition + 3)

        case .administrativeReform:
            // Reform affects those in the department
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            if Int.random(in: 1...100) < 40 {
                // Target loses in reform
                reciprocal.disposition = max(-100, reciprocal.disposition - 15)
                reciprocal.grudgeLevel = min(100, reciprocal.grudgeLevel + 10)
            } else {
                // Target benefits or unaffected
                reciprocal.disposition = min(100, reciprocal.disposition + 5)
            }

        case .manageCrisis:
            // Crisis management builds cooperation
            relationship.trust = min(100, relationship.trust + 10)
            relationship.disposition = min(100, relationship.disposition + 8)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.trust = min(100, reciprocal.trust + 8)
            // May improve stability
            game.stability = min(100, game.stability + Int.random(in: 1...3))

        // GOVERNANCE: Party Apparatus Track
        case .ideologicalCampaign:
            // Campaigns can be disruptive
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 10)
            if target.personalityLoyal < 50 {
                reciprocal.disposition = max(-100, reciprocal.disposition - 10)
            }
            // Loyalty effect
            game.eliteLoyalty = min(100, game.eliteLoyalty + Int.random(in: 1...3))

        case .cadreReview:
            // Reviews create anxiety
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 15)
            if actor.personalityRuthless > 50 {
                reciprocal.disposition = max(-100, reciprocal.disposition - 10)
            }

        case .enforceDiscipline:
            // Discipline damages relationships but instills fear
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 25)
            reciprocal.disposition = max(-100, reciprocal.disposition - 20)
            reciprocal.grudgeLevel = min(100, reciprocal.grudgeLevel + 20)
            target.fearLevel = min(100, target.fearLevel + 15)

        // GOVERNANCE: Military-Political Track
        case .inspectTroopLoyalty:
            // Inspections create wariness
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 10)
            // Military loyalty effect
            game.militaryLoyalty = min(100, game.militaryLoyalty + Int.random(in: 0...2))

        case .politicalIndoctrination:
            // Indoctrination builds ideological conformity
            relationship.trust = min(100, relationship.trust + 5)
            game.eliteLoyalty = min(100, game.eliteLoyalty + Int.random(in: 1...2))

        case .vetOfficers:
            // Vetting creates anxiety among officers
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 15)
            if target.personalityLoyal < 60 {
                reciprocal.disposition = max(-100, reciprocal.disposition - 10)
            }

        // GOVERNANCE: Position-Level Actions
        case .proposePolicyChange:
            // Proposing policy to leadership
            relationship.disposition = min(100, relationship.disposition + 5)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            if actor.personalityCompetent > 60 {
                reciprocal.disposition = min(100, reciprocal.disposition + 8)
            }

        case .callEmergencyMeeting:
            // Emergency meetings create urgency
            relationship.trust = min(100, relationship.trust + 5)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.disposition = min(100, reciprocal.disposition + 3)

        case .issueDirective:
            // Directives establish authority
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 5)
            if Int.random(in: 1...100) < 30 {
                // Subordinate resents orders
                reciprocal.disposition = max(-100, reciprocal.disposition - 5)
            }

        case .demandResignation:
            // Demanding resignation is severe
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.fear = min(100, reciprocal.fear + 40)
            reciprocal.disposition = max(-100, reciprocal.disposition - 50)
            reciprocal.grudgeLevel = min(100, reciprocal.grudgeLevel + 60)
            target.fearLevel = min(100, target.fearLevel + 30)

        case .reorganizeDepartment:
            // Reorganization affects everyone
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            if Int.random(in: 1...100) < 50 {
                // Target disadvantaged
                reciprocal.disposition = max(-100, reciprocal.disposition - 15)
                reciprocal.grudgeLevel = min(100, reciprocal.grudgeLevel + 15)
            } else {
                // Target benefits
                reciprocal.gratitudeLevel = min(100, reciprocal.gratitudeLevel + 10)
            }

        case .setNationalPriority:
            // Setting priorities affects broad policy
            relationship.trust = min(100, relationship.trust + 10)
            relationship.disposition = min(100, relationship.disposition + 5)

        case .proposeLawChange:
            // NPC proposes a law change beneficial to their faction
            relationship.trust = min(100, relationship.trust + 5)

            // Select a law and state change that benefits the NPC's faction
            if let (law, newState) = selectBeneficialLawChange(for: actor, game: game) {
                _ = StandingCommitteeService.shared.proposeLawChange(
                    law: law,
                    newState: newState,
                    sponsor: actor,
                    game: game
                )
            }

        // GOVERNANCE: Reactive Actions
        case .respondToCrisis:
            // Crisis response builds cooperation
            relationship.trust = min(100, relationship.trust + 15)
            relationship.disposition = min(100, relationship.disposition + 10)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.trust = min(100, reciprocal.trust + 10)
            // Stability improvement
            game.stability = min(100, game.stability + Int.random(in: 2...5))

        case .addressShortage:
            // Addressing shortage helps economy
            relationship.trust = min(100, relationship.trust + 10)
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.gratitudeLevel = min(100, reciprocal.gratitudeLevel + 10)
            // Economic improvement
            game.foodSupply = min(100, game.foodSupply + Int.random(in: 1...4))
            game.industrialOutput = min(100, game.industrialOutput + Int.random(in: 1...3))

        case .handleIncident:
            // Handling incidents coordinates responses
            relationship.trust = min(100, relationship.trust + 10)
            relationship.disposition = min(100, relationship.disposition + 5)
            // International effect
            game.internationalStanding = min(100, max(0, game.internationalStanding + Int.random(in: -1...3)))

        case .suppressUnrest:
            // Suppressing unrest stabilizes but may create resentment
            let reciprocal = getOrCreateNPCRelationship(from: target, to: actor, game: game)
            reciprocal.trust = min(100, reciprocal.trust + 5)
            // Stability but at cost
            game.stability = min(100, game.stability + Int.random(in: 3...6))
            if actor.personalityRuthless > 60 {
                game.eliteLoyalty = max(0, game.eliteLoyalty - Int.random(in: 0...2))
            }
        }

        // Record interaction in both characters' histories
        recordNPCToNPCInteraction(actor: actor, target: target, actionType: actionType, game: game)

        // NPC BEHAVIOR SYSTEM: Record memories for both actor and target
        recordActionMemory(actor: actor, target: target, actionType: actionType, success: true, game: game)

        // NPC BEHAVIOR SYSTEM: Update goal progress
        updateGoalProgress(actor: actor, action: actionType, target: target, success: true, game: game)

        // NPC BEHAVIOR SYSTEM: Update needs after action
        updateNeedsAfterAction(character: actor, action: actionType, success: true, game: game)

        // NPC BEHAVIOR SYSTEM: Update spy suspicion if actor is a spy
        updateSpySuspicion(spy: actor, action: actionType, game: game)

        // Generate player-visible event if action is significant
        return generateNPCActionEvent(actor: actor, target: target, actionType: actionType, game: game)
    }

    /// Record NPC-to-NPC interaction in character histories
    private func recordNPCToNPCInteraction(actor: GameCharacter, target: GameCharacter, actionType: NPCActionType, game: Game) {
        let actionDescription = actionType.historyDescription(actor: actor.name, target: target.name)
        let dispositionEffect = actionType.dispositionEffect

        // Record in actor's history (what they did)
        actor.recordInteraction(
            turn: game.turnNumber,
            scenario: "Political maneuvering with \(target.name)",
            choice: actionType.actorPerspective,
            outcome: actionDescription.actorOutcome,
            dispositionChange: 0
        )

        // Record in target's history (what happened to them)
        target.recordInteraction(
            turn: game.turnNumber,
            scenario: "\(actor.name)'s political move",
            choice: actionType.targetPerspective,
            outcome: actionDescription.targetOutcome,
            dispositionChange: dispositionEffect
        )
    }

    /// Generate a player-visible event for significant NPC-NPC actions
    private func generateNPCActionEvent(actor: GameCharacter, target: GameCharacter, actionType: NPCActionType, game: Game) -> DynamicEvent? {
        // Determine visibility based on various factors
        let involvesPlayerNetwork = game.patron?.id == actor.id || game.patron?.id == target.id ||
                                    game.primaryRival?.id == actor.id || game.primaryRival?.id == target.id

        // High position events are always visible
        let actorPosition = actor.positionIndex ?? 0
        let targetPosition = target.positionIndex ?? 0
        let highVisibility = actorPosition >= 4 || targetPosition >= 4

        // Dramatic scheming actions are more likely to be heard about
        let dramaticAction = [.betrayAlliance, .denounce, .makeImplicitThreat, .sabotageProject,
                              .launchInvestigation, .detainSuspect, .demandResignation, .enforceDiscipline].contains(actionType)

        // Governance actions are generally public knowledge
        let governanceAction = actionType.category != .scheming

        // Same track as player = office gossip reaches you
        let sameTrack = actor.positionTrack == game.currentTrack || target.positionTrack == game.currentTrack

        // Base 50% visibility + bonuses for relevance
        var visibilityChance = 0.5
        if involvesPlayerNetwork { visibilityChance = 1.0 }
        else if highVisibility { visibilityChance = 0.9 }
        else if dramaticAction { visibilityChance += 0.25 }
        else if governanceAction { visibilityChance += 0.15 }  // Governance is more public
        else if sameTrack { visibilityChance += 0.2 }

        guard Double.random(in: 0...1) < visibilityChance else {
            return nil
        }

        let (title, text) = generateNPCActionText(actor: actor, target: target, actionType: actionType)

        return DynamicEvent(
            eventType: .networkIntel,
            priority: highVisibility ? .elevated : .background,
            title: title,
            briefText: text,
            initiatingCharacterId: actor.id,
            initiatingCharacterName: actor.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(id: "note", text: "File this information away", shortText: "Note", effects: [:]),
                EventResponse(id: "investigate", text: "Have your network investigate further", shortText: "Investigate", effects: ["network": -2])
            ],
            iconName: actionType.iconName,
            accentColor: actionType.accentColor
        )
    }

    private func generateNPCActionText(actor: GameCharacter, target: GameCharacter, actionType: NPCActionType) -> (title: String, text: String) {
        switch actionType {
        case .formAlliance:
            return (
                "Political Realignment",
                "Your network reports that \(actor.name) and \(target.name) have been seen meeting privately. Sources suggest they have reached some form of understanding.\n\nA new alliance may be forming in the apparatus."
            )

        case .betrayAlliance:
            return (
                "Alliance Shattered",
                "The political world is abuzz: \(actor.name) has publicly distanced themselves from \(target.name), their former ally.\n\nRumors suggest \(actor.name) provided information to State Security. \(target.name)'s position is now precarious."
            )

        case .denounce:
            return (
                "Denunciation Filed",
                "Word reaches you through back channels: \(actor.name) has filed a formal denunciation against \(target.name).\n\nThe charges are vague but serious. An investigation may follow."
            )

        case .blockPromotion:
            return (
                "Advancement Blocked",
                "Your contacts report that \(target.name)'s expected promotion has been delayed. \(actor.name) is rumored to have intervened.\n\n\"Questions about loyalty\" were cited."
            )

        case .spreadRumors:
            return (
                "Whispers in the Corridors",
                "Unflattering stories about \(target.name) are circulating through the ministry. The source is unclear, but your network suspects \(actor.name)'s involvement.\n\nReputations can be fragile things."
            )

        case .seekProtection:
            return (
                "New Patronage Arrangement",
                "\(actor.name) has been seen seeking audiences with \(target.name) frequently. Sources indicate a patron-client relationship is forming.\n\nThe balance of power shifts slightly."
            )

        case .cultivateSupport:
            return (
                "Building a Following",
                "\(actor.name) has been notably generous to subordinates lately. \(target.name) in particular has received favorable treatment.\n\nSomeone is building their base of support."
            )

        case .shareIntelligence:
            return (
                "Information Exchanged",
                "Your network reports that \(actor.name) has been sharing sensitive information with \(target.name). Whispered conversations in quiet offices. Documents passed hand to hand.\n\nThey are building trust through shared secrets."
            )

        case .organizeGathering:
            return (
                "Informal Meeting Observed",
                "Several officials have been meeting informally at \(actor.name)'s dacha. \(target.name) was among those present.\n\nThe conversation was described as 'political in nature.' No formal agenda. No official record. But something is being organized."
            )

        case .makeImplicitThreat:
            return (
                "Veiled Warning Issued",
                "\(actor.name) was overheard making pointed comments to \(target.name) after the morning briefing. The words were careful—nothing actionable—but the meaning was clear.\n\n\"It would be unfortunate if certain matters came to light,\" they said. \(target.name) has been noticeably subdued since."
            )

        case .curryFavor:
            return (
                "Favor Seeking",
                "\(actor.name) has been exceptionally attentive to \(target.name) lately. Small gifts. Public praise. Offers of assistance.\n\nThe flattery appears to be working. \(target.name) has been seen treating \(actor.name) with new warmth."
            )

        case .sabotageProject:
            return (
                "Suspected Sabotage",
                "\(target.name)'s recent initiative has encountered unexpected problems. Deliveries delayed. Approvals stalled. Key personnel suddenly unavailable.\n\nYour network suspects \(actor.name)'s involvement. The delays may not be coincidental."
            )

        // GOVERNANCE: Foreign Affairs Track
        case .negotiateTreaty:
            return (
                "Treaty Negotiations",
                "\(actor.name) has initiated treaty negotiations with a foreign power. \(target.name) has been brought in to coordinate the diplomatic effort.\n\nThe outcome could significantly affect our international standing."
            )

        case .diplomaticOutreach:
            return (
                "Diplomatic Initiative",
                "\(actor.name) is pursuing a diplomatic outreach campaign. \(target.name) is helping coordinate the effort.\n\nRelations with our allies may improve as a result."
            )

        case .recallAmbassador:
            return (
                "Ambassador Recalled",
                "\(actor.name) has ordered an ambassador recalled, signaling diplomatic displeasure. \(target.name) was briefed on the decision.\n\nTensions with the foreign power may escalate."
            )

        // GOVERNANCE: Economic Planning Track
        case .setProductionQuota:
            return (
                "New Production Targets",
                "\(actor.name) has issued new production quotas for the coming period. \(target.name)'s sector is directly affected.\n\nMeeting these targets will require significant effort—or creative reporting."
            )

        case .allocateResources:
            return (
                "Resource Reallocation",
                "\(actor.name) has directed resources to be reallocated. \(target.name) stands to benefit from the new distribution.\n\nNot everyone will be pleased with these changes."
            )

        case .proposeEconomicReform:
            return (
                "Economic Reform Proposed",
                "\(actor.name) has proposed significant economic reforms to \(target.name) and other senior leaders.\n\nThe reforms are ambitious. Their reception remains to be seen."
            )

        // GOVERNANCE: Security Services Track
        case .launchInvestigation:
            return (
                "Investigation Opened",
                "\(actor.name) has opened an official investigation. \(target.name) is reportedly the primary subject.\n\nThe charges are unspecified, but security is taking the matter seriously. This could end very badly."
            )

        case .conductSurveillance:
            return (
                "Surveillance Operation",
                "Your network reports that \(actor.name) has ordered surveillance on \(target.name). Phones monitored. Movements tracked.\n\nThe security services are watching. One wrong word..."
            )

        case .detainSuspect:
            return (
                "Detention Ordered",
                "\(actor.name) has ordered \(target.name) detained for questioning. Security officers arrived without warning.\n\nThe detention is described as 'temporary.' But in our system, temporary can become permanent."
            )

        // GOVERNANCE: State Ministry Track
        case .proposeLegislation:
            return (
                "New Legislation Proposed",
                "\(actor.name) has drafted new legislation and presented it to \(target.name) for consideration.\n\nIf passed, the law could reshape policy in significant ways."
            )

        case .administrativeReform:
            return (
                "Administrative Restructuring",
                "\(actor.name) has implemented an administrative reform that affects \(target.name)'s department.\n\nReorganizations create winners and losers. Which category \(target.name) falls into remains to be seen."
            )

        case .manageCrisis:
            return (
                "Crisis Management",
                "\(actor.name) is coordinating the response to an ongoing crisis. \(target.name) has been called in to assist.\n\nHow they handle this could make or break careers."
            )

        // GOVERNANCE: Party Apparatus Track
        case .ideologicalCampaign:
            return (
                "Ideological Campaign Launched",
                "\(actor.name) has launched a new ideological campaign. \(target.name)'s department has been targeted for special attention.\n\nSuch campaigns remind everyone of the importance of correct thinking."
            )

        case .cadreReview:
            return (
                "Personnel Review",
                "\(actor.name) is conducting a cadre review. \(target.name)'s file has received particular scrutiny.\n\nThese reviews determine who advances and who is found wanting."
            )

        case .enforceDiscipline:
            return (
                "Party Discipline Enforced",
                "\(actor.name) has taken disciplinary action against \(target.name) for violations of party norms.\n\nThe penalties may range from a warning to something far worse."
            )

        // GOVERNANCE: Military-Political Track
        case .inspectTroopLoyalty:
            return (
                "Loyalty Inspection",
                "\(actor.name) has conducted a loyalty inspection of military units. \(target.name)'s command was examined closely.\n\nThe commissars watch the army. The army watches back."
            )

        case .politicalIndoctrination:
            return (
                "Political Education Campaign",
                "\(actor.name) has intensified political education in the armed forces. \(target.name)'s unit is receiving special instruction.\n\nThe troops must understand why they serve."
            )

        case .vetOfficers:
            return (
                "Officer Vetting",
                "\(actor.name) is vetting the officer corps. \(target.name) is among those being reviewed.\n\nOnly politically reliable officers can be trusted with command."
            )

        // GOVERNANCE: Position-Level Actions
        case .proposePolicyChange:
            return (
                "Policy Proposal",
                "\(actor.name) has proposed a significant policy change to \(target.name) and other senior leaders.\n\nThe proposal could shift priorities across the entire system."
            )

        case .callEmergencyMeeting:
            return (
                "Emergency Session Called",
                "\(actor.name) has called an emergency meeting. \(target.name) was among those summoned.\n\nSomething urgent requires immediate attention. The atmosphere is tense."
            )

        case .issueDirective:
            return (
                "Directive Issued",
                "\(actor.name) has issued a directive to \(target.name) and other subordinates.\n\nThe orders are clear and compliance is expected. Failure is not an option."
            )

        case .demandResignation:
            return (
                "Resignation Demanded",
                "\(actor.name) has demanded that \(target.name) resign their position.\n\nThe reasons are not public, but the message is clear: leave now or face worse consequences."
            )

        case .reorganizeDepartment:
            return (
                "Department Reorganized",
                "\(actor.name) has reorganized their department. \(target.name) is among those affected by the changes.\n\nSome will rise, others will fall. The structure of power shifts."
            )

        case .setNationalPriority:
            return (
                "National Priority Set",
                "\(actor.name) has designated a new national priority. \(target.name) has been consulted on implementation.\n\nResources and attention will flow accordingly."
            )

        case .proposeLawChange:
            return (
                "Law Proposal Submitted",
                "\(actor.name) has submitted a proposal to modify the legal code to the Standing Committee.\n\nThe agenda item will be debated at the next committee session. This could reshape the foundations of state power."
            )

        // GOVERNANCE: Reactive Actions
        case .respondToCrisis:
            return (
                "Crisis Response",
                "\(actor.name) is leading the response to an emerging crisis. \(target.name) has been brought in to coordinate efforts.\n\nThe situation requires decisive action. Careers will be made or broken."
            )

        case .addressShortage:
            return (
                "Shortage Addressed",
                "\(actor.name) is taking action to address a critical shortage. \(target.name) is assisting with the emergency measures.\n\nThe people need food and goods. Failure is not acceptable."
            )

        case .handleIncident:
            return (
                "International Incident",
                "\(actor.name) is managing an international incident. \(target.name) has been brought in to handle the diplomatic fallout.\n\nThe situation is delicate. One wrong move could escalate tensions."
            )

        case .suppressUnrest:
            return (
                "Unrest Suppressed",
                "\(actor.name) has ordered measures to suppress growing unrest. \(target.name) is coordinating security operations.\n\nStability must be maintained. By any means necessary."
            )
        }
    }

    // MARK: - Law Proposal Helpers

    /// Selects a law and state change that would benefit the NPC's faction
    private func selectBeneficialLawChange(for npc: GameCharacter, game: Game) -> (Law, LawState)? {
        guard let factionId = npc.factionId else { return nil }

        // Get the faction's policy preferences
        let faction = game.factions.first { $0.factionId == factionId }
        let factionName = faction?.name ?? ""

        // Find laws where this faction would benefit from a change
        var candidates: [(Law, LawState, Int)] = [] // law, newState, priority

        for law in game.laws {
            let currentStateRaw = law.currentState
            guard let currentState = LawState(rawValue: currentStateRaw) else { continue }

            // Check if faction is a beneficiary of strengthening
            if law.beneficiaries.contains(where: { $0.lowercased().contains(factionName.lowercased()) }) {
                // Faction benefits from this law - try to strengthen it
                if currentState != .strengthened {
                    let newState: LawState = currentState == .defaultState ? .modifiedStrong : .strengthened
                    candidates.append((law, newState, 2))
                }
            }

            // Check if faction is a loser under current law
            if law.losers.contains(where: { $0.lowercased().contains(factionName.lowercased()) }) {
                // Faction loses from this law - try to weaken/abolish it
                if currentState != .abolished {
                    let newState: LawState = currentState == .defaultState ? .modifiedWeak : .abolished
                    candidates.append((law, newState, 3)) // Higher priority - fixing disadvantages
                }
            }

            // For ideologically-driven factions, consider general strengthening/weakening
            if faction != nil {
                // Reformist factions prefer economic freedoms
                if factionName.lowercased().contains("reform") && law.category == "economic" {
                    if currentState == .defaultState || currentState == .modifiedStrong {
                        candidates.append((law, .modifiedWeak, 1))
                    }
                }
                // Old Guard prefers institutional stability
                if factionName.lowercased().contains("old") || factionName.lowercased().contains("guard") {
                    if law.category == "institutional" && currentState != .strengthened {
                        candidates.append((law, .strengthened, 1))
                    }
                }
            }
        }

        // Remove any laws already proposed in pending agenda
        let pendingTitles = Set(game.standingCommittee?.pendingAgenda.map { $0.title } ?? [])
        candidates = candidates.filter { !pendingTitles.contains("Modify: \($0.0.name)") }

        // Select highest priority candidate, with some randomness
        guard !candidates.isEmpty else { return nil }

        let sortedCandidates = candidates.sorted { $0.2 > $1.2 }
        let topCandidates = sortedCandidates.prefix(3)
        if let selected = topCandidates.randomElement() {
            return (selected.0, selected.1)
        }

        return nil
    }

    // MARK: - NPC Relationship Helpers

    private func getOrCreateNPCRelationship(from source: GameCharacter, to target: GameCharacter, game: Game) -> NPCRelationship {
        // Find existing relationship
        if let existing = game.npcRelationships.first(where: {
            $0.sourceCharacterId == source.templateId && $0.targetCharacterId == target.templateId
        }) {
            return existing
        }

        // Create new relationship
        let relationship = NPCRelationship(
            sourceId: source.templateId,
            targetId: target.templateId,
            turn: game.turnNumber
        )
        relationship.game = game
        game.npcRelationships.append(relationship)

        // Initialize based on faction/track
        if source.factionId == target.factionId && source.factionId != nil {
            relationship.disposition = 20
            relationship.trust = 60
        } else {
            relationship.disposition = -10
            relationship.trust = 40
        }

        return relationship
    }

    private func isAllied(_ npc1: GameCharacter, with npc2: GameCharacter, game: Game) -> Bool {
        guard let relationship = game.npcRelationships.first(where: {
            $0.sourceCharacterId == npc1.templateId && $0.targetCharacterId == npc2.templateId
        }) else {
            return false
        }
        return relationship.isAllied
    }

    private func isRival(_ npc1: GameCharacter, with npc2: GameCharacter, game: Game) -> Bool {
        guard let relationship = game.npcRelationships.first(where: {
            $0.sourceCharacterId == npc1.templateId && $0.targetCharacterId == npc2.templateId
        }) else {
            return false
        }
        return relationship.isRival
    }

    // MARK: - NPC Relationship Processing

    /// Process decay and evolution of all NPC relationships (called each turn)
    func processNPCRelationshipDecay(game: Game) {
        for relationship in game.npcRelationships {
            relationship.processDecay(currentTurn: game.turnNumber)
        }
    }

    /// Initialize NPC-NPC relationships at game start
    func initializeNPCRelationships(game: Game) {
        let activeNPCs = game.characters.filter { $0.isActive && !$0.isPatron && !$0.isRival }

        for source in activeNPCs {
            for target in activeNPCs where source.id != target.id {
                // Only create relationship if it doesn't exist
                if game.npcRelationships.first(where: {
                    $0.sourceCharacterId == source.templateId && $0.targetCharacterId == target.templateId
                }) == nil {
                    let relationship = NPCRelationship(
                        sourceId: source.templateId,
                        targetId: target.templateId,
                        turn: game.turnNumber
                    )
                    relationship.game = game

                    // Initialize based on faction and track
                    initializeRelationshipValues(relationship, source: source, target: target)

                    game.npcRelationships.append(relationship)
                }
            }
        }
    }

    private func initializeRelationshipValues(_ relationship: NPCRelationship, source: GameCharacter, target: GameCharacter) {
        // Same faction: friendly
        if source.factionId == target.factionId && source.factionId != nil {
            relationship.disposition = 20 + Int.random(in: 0...20)
            relationship.trust = 50 + Int.random(in: 0...20)
        } else {
            relationship.disposition = -10 + Int.random(in: -10...10)
            relationship.trust = 40 + Int.random(in: -10...10)
        }

        let sourcePosition = source.positionIndex ?? 0
        let targetPosition = target.positionIndex ?? 0

        // Same track: colleagues or competitors
        if source.positionTrack == target.positionTrack {
            if sourcePosition == targetPosition {
                // Direct competitors at same level
                relationship.disposition -= 15
                relationship.isRival = Double.random(in: 0...1) < 0.3
            } else {
                // Colleagues at different levels
                relationship.disposition += 10
            }
        }

        // Position hierarchy affects fear/respect
        if targetPosition > sourcePosition {
            relationship.fear = 20 + (targetPosition - sourcePosition) * 10
            relationship.respect = 40 + (targetPosition - sourcePosition) * 10
        } else if targetPosition < sourcePosition {
            relationship.fear = 0
            relationship.respect = 30
        }

        // Ruthless characters generate fear
        if target.personalityRuthless > 70 {
            relationship.fear = min(100, relationship.fear + 20)
        }
    }

    // MARK: - NPC Behavior System: Goals

    /// Assign initial goals to a character based on personality and circumstances
    func assignInitialGoals(to character: GameCharacter, game: Game) {
        var goals: [NPCGoal] = []

        let position = character.positionIndex ?? 0

        // Primary goal based on personality
        if character.personalityAmbitious > 60 && position < 6 {
            goals.append(NPCGoal(
                goalType: .seekPromotion,
                priority: 70 + character.personalityAmbitious / 5,
                turnCreated: game.turnNumber
            ))
        } else if character.personalityAmbitious > 80 && position >= 6 {
            goals.append(NPCGoal(
                goalType: .joinPolitburo,
                priority: 80,
                turnCreated: game.turnNumber
            ))
        } else if character.personalityParanoid > 60 {
            goals.append(NPCGoal(
                goalType: .protectPosition,
                priority: 70 + character.personalityParanoid / 5,
                turnCreated: game.turnNumber
            ))
        }

        // True believers get party devotion goals
        if character.isTrueBeliever {
            let devotionGoals: [NPCGoalType] = [.serveTheParty, .defendPartyOrthodoxy, .rootOutTraitors, .strengthenTheState]
            if let selectedGoal = devotionGoals.randomElement() {
                goals.append(NPCGoal(
                    goalType: selectedGoal,
                    priority: 75,
                    turnCreated: game.turnNumber
                ))
            }
        }

        // Secondary goal based on relationships
        if let rivalId = findStrongestRivalId(for: character, game: game) {
            if character.personalityRuthless > 50 {
                goals.append(NPCGoal(
                    goalType: .destroyRival,
                    targetCharacterId: rivalId,
                    priority: 50 + character.personalityRuthless / 5,
                    turnCreated: game.turnNumber
                ))
            }
        }

        // Survival goals override others when threatened
        if character.currentStatus == .underInvestigation {
            goals.insert(NPCGoal(
                goalType: .clearName,
                priority: 95,
                turnCreated: game.turnNumber
            ), at: 0)
        }

        // Low security need = find protector
        if character.npcNeeds.security < 30 && !character.isPatron {
            goals.append(NPCGoal(
                goalType: .findProtector,
                priority: 80,
                turnCreated: game.turnNumber
            ))
        }

        // Corrupt characters want wealth
        if character.personalityCorrupt > 60 {
            goals.append(NPCGoal(
                goalType: .accumulateWealth,
                priority: 40 + character.personalityCorrupt / 4,
                turnCreated: game.turnNumber
            ))
        }

        // Set the goals (keep max 3)
        goals.sort { $0.priority > $1.priority }
        character.npcGoals = Array(goals.prefix(3))
    }

    /// Find the strongest rival (most negative relationship)
    private func findStrongestRivalId(for character: GameCharacter, game: Game) -> String? {
        let relationships = game.npcRelationships.filter {
            $0.sourceCharacterId == character.templateId && $0.isRival
        }
        return relationships.min(by: { $0.disposition < $1.disposition })?.targetCharacterId
    }

    /// Calculate goal alignment bonus for action selection
    func goalAlignmentBonus(action: NPCActionType, actor: GameCharacter, game: Game) -> Int {
        var bonus = 0

        for goal in actor.activeGoals {
            switch goal.goalType {
            case .seekPromotion:
                if action == .curryFavor { bonus += 15 }
                if action == .blockPromotion { bonus += 10 }
                if action == .proposePolicyChange { bonus += 10 }

            case .becomeTrackHead, .joinPolitburo:
                if action == .curryFavor { bonus += 20 }
                if action == .blockPromotion { bonus += 15 }
                if action == .cultivateSupport { bonus += 15 }
                if action == .proposePolicyChange { bonus += 15 }

            case .protectPosition:
                if action == .seekProtection { bonus += 20 }
                if action == .formAlliance { bonus += 15 }
                if action == .curryFavor { bonus += 10 }
                if action == .makeImplicitThreat { bonus += 10 }

            case .destroyRival:
                if action == .denounce { bonus += 20 }
                if action == .launchInvestigation { bonus += 25 }
                if action == .spreadRumors { bonus += 15 }
                if action == .sabotageProject { bonus += 15 }
                if action == .blockPromotion { bonus += 15 }

            case .elevateAlly:
                if action == .shareIntelligence { bonus += 15 }
                if action == .curryFavor { bonus += 10 }

            case .avengeBetrayal:
                if action == .denounce { bonus += 25 }
                if action == .launchInvestigation { bonus += 20 }
                if action == .spreadRumors { bonus += 15 }
                if action == .makeImplicitThreat { bonus += 15 }

            case .buildFaction:
                if action == .formAlliance { bonus += 20 }
                if action == .cultivateSupport { bonus += 15 }
                if action == .organizeGathering { bonus += 15 }
                if action == .shareIntelligence { bonus += 10 }

            case .accumulateWealth:
                if action == .allocateResources { bonus += 15 }
                if action == .sabotageProject { bonus += 10 }

            case .expandInfluence:
                if action == .cultivateSupport { bonus += 20 }
                if action == .formAlliance { bonus += 15 }
                if action == .organizeGathering { bonus += 15 }

            case .implementReform:
                if action == .proposePolicyChange { bonus += 20 }
                if action == .proposeLegislation { bonus += 20 }
                if action == .proposeEconomicReform { bonus += 20 }
                if action == .administrativeReform { bonus += 15 }

            case .maintainOrthodoxy:
                if action == .ideologicalCampaign { bonus += 20 }
                if action == .enforceDiscipline { bonus += 15 }
                if action == .cadreReview { bonus += 15 }

            case .purgeEnemies:
                if action == .launchInvestigation { bonus += 25 }
                if action == .denounce { bonus += 20 }
                if action == .detainSuspect { bonus += 20 }
                if action == .demandResignation { bonus += 15 }

            // PARTY DEVOTION Goals
            case .serveTheParty:
                if action == .ideologicalCampaign { bonus += 25 }
                if action == .enforceDiscipline { bonus += 20 }
                if action == .cadreReview { bonus += 15 }
                if action == .launchInvestigation { bonus += 15 }
                // True believers are less self-interested
                bonus -= (action == .curryFavor ? 10 : 0)

            case .defendPartyOrthodoxy:
                if action == .ideologicalCampaign { bonus += 25 }
                if action == .enforceDiscipline { bonus += 20 }
                if action == .proposeLegislation { bonus += 15 }
                if action == .denounce { bonus += 15 }

            case .rootOutTraitors:
                if action == .launchInvestigation { bonus += 30 }
                if action == .conductSurveillance { bonus += 25 }
                if action == .denounce { bonus += 20 }
                if action == .cadreReview { bonus += 20 }
                if action == .detainSuspect { bonus += 25 }

            case .strengthenTheState:
                if action == .setProductionQuota { bonus += 15 }
                if action == .allocateResources { bonus += 15 }
                if action == .administrativeReform { bonus += 15 }
                if action == .proposeLegislation { bonus += 15 }

            // ESPIONAGE Goals
            case .spyForForeignPower:
                if action == .shareIntelligence { bonus += 20 }
                if action == .conductSurveillance { bonus += 15 }
                // Avoid suspicion-raising actions
                if action == .denounce { bonus -= 15 }
                if action == .launchInvestigation { bonus -= 10 }
                if action == .curryFavor { bonus += 10 }

            case .recruitAssets:
                if action == .shareIntelligence { bonus += 20 }
                if action == .cultivateSupport { bonus += 15 }
                if action == .organizeGathering { bonus += 10 }

            case .sabotageFromWithin:
                if action == .sabotageProject { bonus += 25 }
                if action == .spreadRumors { bonus += 15 }

            case .avoidDetection:
                if action == .seekProtection { bonus += 20 }
                if action == .formAlliance { bonus += 15 }
                if action == .curryFavor { bonus += 15 }
                if action == .denounce { bonus -= 25 }
                if action == .makeImplicitThreat { bonus -= 20 }
                if action == .launchInvestigation { bonus -= 15 }

            // SURVIVAL Goals
            case .avoidPurge:
                if action == .seekProtection { bonus += 25 }
                if action == .curryFavor { bonus += 15 }
                if action == .formAlliance { bonus += 15 }
                if action == .denounce { bonus -= 20 }

            case .clearName:
                if action == .curryFavor { bonus += 25 }
                if action == .seekProtection { bonus += 20 }
                if action == .shareIntelligence { bonus += 15 }

            case .escapeDetention:
                if action == .seekProtection { bonus += 30 }
                if action == .curryFavor { bonus += 20 }

            case .findProtector:
                if action == .seekProtection { bonus += 30 }
                if action == .curryFavor { bonus += 25 }
                if action == .formAlliance { bonus += 15 }

            case .repayDebt:
                if action == .shareIntelligence { bonus += 15 }
                if action == .formAlliance { bonus += 15 }

            // DIPLOMATIC Goals
            case .improveAllyRelations:
                if action == .curryFavor { bonus += 15 }
                if action == .formAlliance { bonus += 20 }
                if action == .shareIntelligence { bonus += 10 }

            case .containCapitalistThreat:
                if action == .conductSurveillance { bonus += 15 }
                if action == .launchInvestigation { bonus += 10 }
                if action == .ideologicalCampaign { bonus += 15 }

            case .expandTradeNetwork:
                if action == .allocateResources { bonus += 15 }
                if action == .formAlliance { bonus += 10 }

            case .defuseInternationalCrisis:
                if action == .curryFavor { bonus += 15 }
                if action == .shareIntelligence { bonus += 15 }

            case .advanceIdeologicalGoals:
                if action == .ideologicalCampaign { bonus += 25 }
                if action == .proposeLegislation { bonus += 15 }

            case .proposeForeignPolicy:
                if action == .proposePolicyChange { bonus += 25 }
                if action == .proposeLegislation { bonus += 20 }
                if action == .cultivateSupport { bonus += 15 }

            case .negotiateTreaty:
                if action == .formAlliance { bonus += 20 }
                if action == .curryFavor { bonus += 10 }

            // SECURITY Goals (CCDI/MSS)
            case .investigateCorruption:
                if action == .launchInvestigation { bonus += 30 }
                if action == .conductSurveillance { bonus += 25 }
                if action == .cadreReview { bonus += 20 }
                if action == .detainSuspect { bonus += 20 }

            case .expandSurveillance:
                if action == .conductSurveillance { bonus += 30 }
                if action == .launchInvestigation { bonus += 15 }
                if action == .proposePolicyChange { bonus += 15 }

            case .conductPurge:
                if action == .launchInvestigation { bonus += 30 }
                if action == .denounce { bonus += 25 }
                if action == .detainSuspect { bonus += 25 }
                if action == .demandResignation { bonus += 20 }
                if action == .enforceDiscipline { bonus += 20 }

            case .buildDossiers:
                if action == .conductSurveillance { bonus += 30 }
                if action == .launchInvestigation { bonus += 20 }
                if action == .shareIntelligence { bonus += 15 }

            case .protectPatron:
                if action == .seekProtection { bonus += 20 }
                if action == .curryFavor { bonus += 20 }
                if action == .shareIntelligence { bonus += 15 }
                // Avoid exposing patron
                if action == .denounce { bonus -= 25 }
                if action == .launchInvestigation { bonus -= 20 }

            case .protectRegime:
                if action == .launchInvestigation { bonus += 20 }
                if action == .conductSurveillance { bonus += 20 }
                if action == .ideologicalCampaign { bonus += 15 }
                if action == .enforceDiscipline { bonus += 15 }

            case .eliminateRivals:
                if action == .launchInvestigation { bonus += 30 }
                if action == .denounce { bonus += 25 }
                if action == .detainSuspect { bonus += 25 }
                if action == .spreadRumors { bonus += 15 }

            case .huntForeignSpies:
                if action == .conductSurveillance { bonus += 30 }
                if action == .launchInvestigation { bonus += 30 }
                if action == .detainSuspect { bonus += 25 }
                if action == .denounce { bonus += 20 }

            // Economic Goals (Gosplan) - economic planning NPCs
            case .meetProductionQuotas:
                // Production-focused behavior
                if action == .setProductionQuota { bonus += 25 }
                if action == .allocateResources { bonus += 20 }
                if action == .curryFavor { bonus += 10 }

            case .exceedException:
                // Stakhanovite overachievement behavior
                if action == .setProductionQuota { bonus += 30 }
                if action == .seekProtection { bonus += 15 }
                if action == .curryFavor { bonus += 15 }

            case .expandIndustrialOutput:
                // Growth-focused economic behavior
                if action == .allocateResources { bonus += 25 }
                if action == .proposeEconomicReform { bonus += 20 }
                if action == .formAlliance { bonus += 15 }

            case .modernizeSector:
                // Reform-oriented economic behavior
                if action == .proposeEconomicReform { bonus += 30 }
                if action == .allocateResources { bonus += 15 }
                if action == .shareIntelligence { bonus += 10 }

            case .acquireResources:
                // Resource acquisition behavior
                if action == .allocateResources { bonus += 30 }
                if action == .seekProtection { bonus += 20 }
                if action == .formAlliance { bonus += 15 }

            case .protectBudgetAllocation:
                // Budget defense behavior
                if action == .cultivateSupport { bonus += 25 }
                if action == .formAlliance { bonus += 20 }
                if action == .seekProtection { bonus += 15 }

            case .buildEconomicNetwork:
                // Network-building economic behavior
                if action == .cultivateSupport { bonus += 30 }
                if action == .formAlliance { bonus += 25 }
                if action == .shareIntelligence { bonus += 15 }

            case .advanceEconomicReform:
                // Reform advocacy behavior
                if action == .proposeEconomicReform { bonus += 35 }
                if action == .formAlliance { bonus += 20 }
                if action == .cultivateSupport { bonus += 15 }

            // Military-Political Goals (PLA Commissar)
            case .ensurePartyCommand:
                // Maintain Party control over military
                if action == .ideologicalCampaign { bonus += 30 }
                if action == .enforceDiscipline { bonus += 25 }
                if action == .cadreReview { bonus += 20 }

            case .conductPoliticalWork:
                // Run political education activities
                if action == .ideologicalCampaign { bonus += 35 }
                if action == .cultivateSupport { bonus += 15 }
                if action == .organizeGathering { bonus += 15 }

            case .evaluateOfficerLoyalty:
                // Assess political reliability
                if action == .conductSurveillance { bonus += 30 }
                if action == .cadreReview { bonus += 30 }
                if action == .shareIntelligence { bonus += 20 }

            case .purgeDisloyal:
                // Remove unreliable officers
                if action == .launchInvestigation { bonus += 35 }
                if action == .denounce { bonus += 30 }
                if action == .detainSuspect { bonus += 30 }
                if action == .demandResignation { bonus += 25 }

            case .enforcePartyDiscipline:
                // Implement regulations and standards
                if action == .enforceDiscipline { bonus += 35 }
                if action == .cadreReview { bonus += 25 }
                if action == .ideologicalCampaign { bonus += 20 }

            case .buildCommissarNetwork:
                // Create patronage among commissars
                if action == .cultivateSupport { bonus += 30 }
                if action == .formAlliance { bonus += 30 }
                if action == .shareIntelligence { bonus += 20 }

            case .advanceMilitaryReform:
                // Push PLA modernization
                if action == .proposeEconomicReform { bonus += 25 }
                if action == .proposePolicyChange { bonus += 25 }
                if action == .formAlliance { bonus += 20 }
                if action == .cultivateSupport { bonus += 15 }

            case .preventMilitaryCoup:
                // Prevent threats to Party control
                if action == .conductSurveillance { bonus += 35 }
                if action == .launchInvestigation { bonus += 30 }
                if action == .detainSuspect { bonus += 30 }
                if action == .enforceDiscipline { bonus += 25 }

            // Party Apparatus Goals (Organization Department/Central Committee)
            case .controlNomenklatura:
                // Control cadre appointments
                if action == .cadreReview { bonus += 35 }
                if action == .curryFavor { bonus += 20 }
                if action == .cultivateSupport { bonus += 20 }

            case .enforcePropagandaLine:
                // Ensure correct messaging
                if action == .ideologicalCampaign { bonus += 35 }
                if action == .enforceDiscipline { bonus += 25 }
                if action == .denounce { bonus += 20 }

            case .conductUnitedFrontWork:
                // Influence non-party groups
                if action == .cultivateSupport { bonus += 35 }
                if action == .formAlliance { bonus += 30 }
                if action == .organizeGathering { bonus += 25 }

            case .runPartySchool:
                // Train and indoctrinate cadres
                if action == .ideologicalCampaign { bonus += 35 }
                if action == .cadreReview { bonus += 25 }
                if action == .cultivateSupport { bonus += 20 }

            case .maintainPartyDiscipline:
                // Internal discipline and self-criticism
                if action == .enforceDiscipline { bonus += 35 }
                if action == .cadreReview { bonus += 30 }
                if action == .ideologicalCampaign { bonus += 20 }

            case .expandPartyInfluence:
                // Grow party reach
                if action == .cultivateSupport { bonus += 35 }
                if action == .organizeGathering { bonus += 25 }
                if action == .formAlliance { bonus += 25 }

            case .buildCadreNetwork:
                // Create patronage ties among party officials
                if action == .cultivateSupport { bonus += 35 }
                if action == .formAlliance { bonus += 30 }
                if action == .shareIntelligence { bonus += 20 }
                if action == .curryFavor { bonus += 15 }

            case .purgeDeviationists:
                // Remove those who stray from party line
                if action == .launchInvestigation { bonus += 35 }
                if action == .denounce { bonus += 35 }
                if action == .detainSuspect { bonus += 30 }
                if action == .demandResignation { bonus += 25 }

            // STATE MINISTRY Goals
            case .achieveAdministrativeExcellence:
                // Improve ministry efficiency and competence
                if action == .cultivateSupport { bonus += 25 }
                if action == .proposeLegislation { bonus += 30 }
                if action == .administrativeReform { bonus += 35 }

            case .secureBudgetAllocation:
                // Obtain and protect ministry funding
                if action == .cultivateSupport { bonus += 30 }
                if action == .curryFavor { bonus += 25 }
                if action == .proposeLegislation { bonus += 20 }

            case .advanceMajorProject:
                // Push infrastructure or development initiatives
                if action == .proposeLegislation { bonus += 35 }
                if action == .organizeGathering { bonus += 25 }
                if action == .administrativeReform { bonus += 30 }

            case .coordinateAcrossMinistries:
                // Cross-ministry coordination work
                if action == .organizeGathering { bonus += 40 }
                if action == .formAlliance { bonus += 30 }
                if action == .curryFavor { bonus += 20 }

            case .implementStatePolicy:
                // Execute State Council directives
                if action == .proposeLegislation { bonus += 25 }
                if action == .cultivateSupport { bonus += 20 }
                if action == .demandResignation { bonus += 20 }

            case .auditSubordinateUnits:
                // Conduct oversight of lower departments
                if action == .launchInvestigation { bonus += 40 }
                if action == .denounce { bonus += 25 }
                if action == .demandResignation { bonus += 25 }

            case .modernizeAdministration:
                // Push administrative reforms
                if action == .administrativeReform { bonus += 45 }
                if action == .proposeLegislation { bonus += 35 }
                if action == .reorganizeDepartment { bonus += 30 }

            case .buildBureaucraticNetwork:
                // Create connections across the bureaucracy
                if action == .cultivateSupport { bonus += 50 }
                if action == .formAlliance { bonus += 35 }
                if action == .seekProtection { bonus += 30 }
            }
        }

        return bonus
    }

    /// Calculate bonus for targeting specific character based on goals
    func goalTargetBonus(action: NPCActionType, actor: GameCharacter, target: GameCharacter, game: Game) -> Int {
        var bonus = 0

        for goal in actor.activeGoals {
            // If goal has a specific target
            if let targetId = goal.targetCharacterId, targetId == target.templateId {
                switch goal.goalType {
                case .destroyRival:
                    if action == .denounce || action == .launchInvestigation ||
                       action == .spreadRumors || action == .sabotageProject ||
                       action == .blockPromotion || action == .detainSuspect {
                        bonus += 30
                    }
                case .elevateAlly:
                    if action == .shareIntelligence || action == .formAlliance {
                        bonus += 25
                    }
                case .avengeBetrayal:
                    if action == .denounce || action == .launchInvestigation ||
                       action == .spreadRumors || action == .makeImplicitThreat {
                        bonus += 35
                    }
                case .repayDebt:
                    if action == .shareIntelligence || action == .formAlliance {
                        bonus += 25
                    }
                default:
                    break
                }
            }
        }

        return bonus
    }

    /// Update goal progress after action execution
    func updateGoalProgress(actor: GameCharacter, action: NPCActionType, target: GameCharacter?, success: Bool, game: Game) {
        guard success else {
            // Failed actions increase frustration
            for goal in actor.activeGoals {
                if goalMatchesAction(goal: goal, action: action) {
                    actor.increaseGoalFrustration(goalId: goal.id, amount: 15)
                }
            }
            return
        }

        var goals = actor.npcGoals

        for i in goals.indices where goals[i].isActive {
            var progressIncrease = 0

            switch goals[i].goalType {
            case .seekPromotion:
                if action == .curryFavor { progressIncrease = 10 }
                if action == .blockPromotion { progressIncrease = 15 }
                if action == .proposePolicyChange { progressIncrease = 20 }

            case .destroyRival:
                if let targetId = goals[i].targetCharacterId, target?.templateId == targetId {
                    if action == .denounce { progressIncrease = 20 }
                    if action == .launchInvestigation { progressIncrease = 30 }
                    if action == .detainSuspect { progressIncrease = 40 }
                }

            case .buildFaction:
                if action == .formAlliance { progressIncrease = 20 }
                if action == .cultivateSupport { progressIncrease = 15 }
                if action == .organizeGathering { progressIncrease = 15 }

            case .rootOutTraitors:
                if action == .launchInvestigation { progressIncrease = 15 }
                if action == .detainSuspect { progressIncrease = 25 }
                if action == .denounce { progressIncrease = 15 }

            case .findProtector:
                if action == .seekProtection { progressIncrease = 50 }
                if action == .curryFavor { progressIncrease = 20 }

            default:
                break
            }

            if progressIncrease > 0 {
                goals[i].progress = min(100, goals[i].progress + progressIncrease)
                goals[i].attemptsCount += 1
                goals[i].lastAttemptTurn = game.turnNumber

                // Complete goal if progress reaches 100
                if goals[i].progress >= 100 {
                    goals[i].isActive = false
                }
            }
        }

        actor.npcGoals = goals
    }

    /// Check if a goal would benefit from an action
    private func goalMatchesAction(goal: NPCGoal, action: NPCActionType) -> Bool {
        switch goal.goalType {
        case .seekPromotion:
            return [.curryFavor, .blockPromotion, .proposePolicyChange].contains(action)
        case .destroyRival:
            return [.denounce, .launchInvestigation, .spreadRumors, .sabotageProject].contains(action)
        case .buildFaction:
            return [.formAlliance, .cultivateSupport, .organizeGathering].contains(action)
        case .findProtector:
            return [.seekProtection, .curryFavor].contains(action)
        case .rootOutTraitors:
            return [.launchInvestigation, .conductSurveillance, .denounce, .detainSuspect].contains(action)
        default:
            return false
        }
    }

    // MARK: - NPC Behavior System: Needs

    /// Calculate need satisfaction bonus for action selection
    func needSatisfactionBonus(action: NPCActionType, actor: GameCharacter) -> Int {
        let needs = actor.npcNeeds
        var bonus = 0

        // Security-satisfying actions
        if needs.security < 40 {
            let urgency = (40 - needs.security) / 2
            if action == .seekProtection { bonus += urgency + 15 }
            if action == .formAlliance { bonus += urgency + 10 }
            if action == .curryFavor { bonus += urgency + 5 }
            // Reduce risky actions
            if action == .denounce { bonus -= urgency }
            if action == .betrayAlliance { bonus -= urgency + 10 }
            if action == .launchInvestigation { bonus -= urgency / 2 }
        }

        // Power-satisfying actions
        if needs.power < 40 {
            let urgency = (40 - needs.power) / 2
            if action == .proposePolicyChange { bonus += urgency + 10 }
            if action == .issueDirective { bonus += urgency + 15 }
            if action == .blockPromotion { bonus += urgency + 5 }
            if action == .cultivateSupport { bonus += urgency + 10 }
            if action == .demandResignation { bonus += urgency + 10 }
            if action == .proposeLawChange { bonus += urgency + 20 } // Reshaping laws is major power
        }

        // Loyalty-satisfying actions
        if needs.loyalty < 40 {
            let urgency = (40 - needs.loyalty) / 2
            if action == .formAlliance { bonus += urgency + 15 }
            if action == .organizeGathering { bonus += urgency + 10 }
            if action == .shareIntelligence { bonus += urgency + 10 }
        }

        // Recognition-satisfying actions
        if needs.recognition < 40 {
            let urgency = (40 - needs.recognition) / 2
            if action == .proposePolicyChange { bonus += urgency + 10 }
            if action == .curryFavor { bonus += urgency + 10 }
            if action == .ideologicalCampaign { bonus += urgency + 10 }
            if action == .setNationalPriority { bonus += urgency + 15 }
            if action == .proposeLawChange { bonus += urgency + 15 } // Public legislative impact
        }

        // Stability-satisfying actions (prefer non-aggressive)
        if needs.stability < 40 {
            let urgency = (40 - needs.stability) / 2
            if action == .manageCrisis { bonus += urgency + 15 }
            if action == .respondToCrisis { bonus += urgency + 15 }
            if action == .suppressUnrest { bonus += urgency + 10 }
            // Reduce destabilizing actions
            if action == .denounce { bonus -= urgency / 2 }
            if action == .betrayAlliance { bonus -= urgency }
        }

        // Ideological commitment actions
        if needs.ideologicalCommitment > 70 {
            // True believers prefer ideological work
            if action == .ideologicalCampaign { bonus += 20 }
            if action == .enforceDiscipline { bonus += 15 }
            if action == .cadreReview { bonus += 15 }
        } else if needs.ideologicalCommitment < 30 {
            // Disillusioned avoid ideological work
            if action == .ideologicalCampaign { bonus -= 10 }
        }

        return bonus
    }

    /// Process need decay for a character (call during turn processing)
    func processNeedDecay(character: GameCharacter, game: Game) {
        var needs = character.npcNeeds

        // Natural decay per turn
        needs.security = max(0, needs.security - 2)
        needs.power = max(0, needs.power - 1)
        needs.loyalty = max(0, needs.loyalty - 1)
        needs.recognition = max(0, needs.recognition - 2)
        needs.stability = max(0, needs.stability - 1)

        // Position affects decay
        let position = character.positionIndex ?? 0
        if position >= 5 {
            needs.power = min(100, needs.power + 3)
            needs.recognition = min(100, needs.recognition + 2)
        }
        if position <= 2 {
            needs.security = max(0, needs.security - 2)
        }

        // Game state affects needs
        if game.stability < 40 {
            needs.security = max(0, needs.security - 5)
            needs.stability = max(0, needs.stability - 5)
        }

        // Faction membership helps loyalty need
        if character.factionId != nil {
            needs.loyalty = min(100, needs.loyalty + 2)
        }

        // Patron relationship helps security
        if character.isPatron || hasPatron(character, game: game) {
            needs.security = min(100, needs.security + 3)
        }

        character.npcNeeds = needs
    }

    /// Check if character has a patron
    private func hasPatron(_ character: GameCharacter, game: Game) -> Bool {
        return game.npcRelationships.contains { (relationship: NPCRelationship) in
            relationship.sourceCharacterId == character.templateId && relationship.isClient
        }
    }

    /// Update needs after action completion
    func updateNeedsAfterAction(character: GameCharacter, action: NPCActionType, success: Bool, game: Game) {
        var needs = character.npcNeeds

        guard success else {
            // Failed actions hurt recognition
            needs.recognition = max(0, needs.recognition - 10)
            character.npcNeeds = needs
            return
        }

        switch action {
        case .seekProtection:
            needs.security = min(100, needs.security + 20)
        case .formAlliance:
            needs.loyalty = min(100, needs.loyalty + 15)
            needs.security = min(100, needs.security + 10)
        case .curryFavor:
            needs.recognition = min(100, needs.recognition + 10)
        case .proposePolicyChange, .setNationalPriority:
            needs.power = min(100, needs.power + 15)
            needs.recognition = min(100, needs.recognition + 10)
        case .proposeLawChange:
            needs.power = min(100, needs.power + 20) // Major legislative impact
            needs.recognition = min(100, needs.recognition + 15)
        case .denounce, .launchInvestigation:
            needs.security = max(0, needs.security - 5)
            needs.power = min(100, needs.power + 10)
        case .organizeGathering:
            needs.loyalty = min(100, needs.loyalty + 10)
            needs.recognition = min(100, needs.recognition + 5)
        case .ideologicalCampaign:
            needs.ideologicalCommitment = min(100, needs.ideologicalCommitment + 10)
            needs.recognition = min(100, needs.recognition + 5)
        case .manageCrisis, .respondToCrisis:
            needs.stability = min(100, needs.stability + 15)
        case .issueDirective, .demandResignation:
            needs.power = min(100, needs.power + 15)
        case .cultivateSupport:
            needs.loyalty = min(100, needs.loyalty + 10)
        default:
            break
        }

        character.npcNeeds = needs
    }

    // MARK: - NPC Behavior System: Enhanced Memory

    /// Record memory for both actor and target after action
    func recordActionMemory(actor: GameCharacter, target: GameCharacter, actionType: NPCActionType, success: Bool, game: Game) {
        let severity = actionSeverity(actionType)

        switch actionType {
        case .launchInvestigation:
            let actorMemory = NPCMemory(
                memoryType: .investigatedOther,
                turn: game.turnNumber,
                involvedCharacterId: target.templateId,
                involvedCharacterName: target.name,
                severity: severity,
                sentiment: 0,
                description: "Launched investigation into \(target.name)"
            )
            let targetMemory = NPCMemory(
                memoryType: .wasInvestigated,
                turn: game.turnNumber,
                involvedCharacterId: actor.templateId,
                involvedCharacterName: actor.name,
                severity: severity + 20,
                sentiment: -70,
                description: "Investigated by \(actor.name)"
            )
            actor.addNPCMemory(actorMemory)
            target.addNPCMemory(targetMemory)

        case .formAlliance:
            let allianceMemory = NPCMemory(
                memoryType: .allianceFormed,
                turn: game.turnNumber,
                involvedCharacterId: target.templateId,
                involvedCharacterName: target.name,
                severity: severity,
                sentiment: 40,
                description: "Formed alliance with \(target.name)"
            )
            actor.addNPCMemory(allianceMemory)
            target.addNPCMemory(NPCMemory(
                memoryType: .allianceFormed,
                turn: game.turnNumber,
                involvedCharacterId: actor.templateId,
                involvedCharacterName: actor.name,
                severity: severity,
                sentiment: 40,
                description: "Formed alliance with \(actor.name)"
            ))

        case .denounce:
            actor.addNPCMemory(NPCMemory(
                memoryType: .reportedTraitor,
                turn: game.turnNumber,
                involvedCharacterId: target.templateId,
                involvedCharacterName: target.name,
                severity: severity,
                sentiment: 0,
                description: "Denounced \(target.name)"
            ))
            target.addNPCMemory(NPCMemory(
                memoryType: .publicHumiliation,
                turn: game.turnNumber,
                involvedCharacterId: actor.templateId,
                involvedCharacterName: actor.name,
                severity: severity + 20,
                sentiment: -80,
                description: "Denounced by \(actor.name)"
            ))

        case .betrayAlliance:
            actor.addNPCMemory(NPCMemory(
                memoryType: .allianceBroken,
                turn: game.turnNumber,
                involvedCharacterId: target.templateId,
                involvedCharacterName: target.name,
                severity: severity,
                sentiment: 0,
                description: "Betrayed alliance with \(target.name)"
            ))
            target.addNPCMemory(NPCMemory(
                memoryType: .allianceBroken,
                turn: game.turnNumber,
                involvedCharacterId: actor.templateId,
                involvedCharacterName: actor.name,
                severity: severity + 30,
                sentiment: -90,
                description: "Betrayed by \(actor.name)"
            ))

        case .shareIntelligence:
            let sharedMemory = NPCMemory(
                memoryType: .secretShared,
                turn: game.turnNumber,
                involvedCharacterId: target.templateId,
                involvedCharacterName: target.name,
                severity: severity,
                sentiment: 30,
                description: "Shared intelligence with \(target.name)"
            )
            actor.addNPCMemory(sharedMemory)
            target.addNPCMemory(NPCMemory(
                memoryType: .secretShared,
                turn: game.turnNumber,
                involvedCharacterId: actor.templateId,
                involvedCharacterName: actor.name,
                severity: severity,
                sentiment: 35,
                description: "\(actor.name) shared intelligence"
            ))

        case .makeImplicitThreat:
            target.addNPCMemory(NPCMemory(
                memoryType: .threatReceived,
                turn: game.turnNumber,
                involvedCharacterId: actor.templateId,
                involvedCharacterName: actor.name,
                severity: severity,
                sentiment: -50,
                description: "Threatened by \(actor.name)"
            ))
            actor.addNPCMemory(NPCMemory(
                memoryType: .threatIssued,
                turn: game.turnNumber,
                involvedCharacterId: target.templateId,
                involvedCharacterName: target.name,
                severity: severity,
                sentiment: 0,
                description: "Threatened \(target.name)"
            ))

        case .detainSuspect:
            target.addNPCMemory(NPCMemory(
                memoryType: .wasDetained,
                turn: game.turnNumber,
                involvedCharacterId: actor.templateId,
                involvedCharacterName: actor.name,
                severity: 90,
                sentiment: -90,
                description: "Detained by \(actor.name)"
            ))
            actor.addNPCMemory(NPCMemory(
                memoryType: .detainedOther,
                turn: game.turnNumber,
                involvedCharacterId: target.templateId,
                involvedCharacterName: target.name,
                severity: 70,
                sentiment: 0,
                description: "Detained \(target.name)"
            ))

        case .blockPromotion:
            target.addNPCMemory(NPCMemory(
                memoryType: .promotionBlocked,
                turn: game.turnNumber,
                involvedCharacterId: actor.templateId,
                involvedCharacterName: actor.name,
                severity: severity,
                sentiment: -60,
                description: "Promotion blocked by \(actor.name)"
            ))
            actor.addNPCMemory(NPCMemory(
                memoryType: .blockedPromotion,
                turn: game.turnNumber,
                involvedCharacterId: target.templateId,
                involvedCharacterName: target.name,
                severity: severity,
                sentiment: 0,
                description: "Blocked \(target.name)'s promotion"
            ))

        case .issueDirective:
            target.addNPCMemory(NPCMemory(
                memoryType: .receivedDirective,
                turn: game.turnNumber,
                involvedCharacterId: actor.templateId,
                involvedCharacterName: actor.name,
                severity: 40,
                sentiment: -10,
                description: "Received orders from \(actor.name)"
            ))

        default:
            break
        }
    }

    /// Get severity for an action type
    private func actionSeverity(_ action: NPCActionType) -> Int {
        switch action {
        case .detainSuspect: return 90
        case .denounce, .betrayAlliance: return 75
        case .launchInvestigation, .makeImplicitThreat: return 60
        case .blockPromotion, .sabotageProject, .spreadRumors: return 50
        case .formAlliance, .shareIntelligence: return 50
        case .curryFavor, .cultivateSupport, .organizeGathering: return 30
        default: return 40
        }
    }

    /// Calculate memory modifier for target selection
    func memoryModifier(action: NPCActionType, actor: GameCharacter, potentialTarget: GameCharacter, game: Game) -> Int {
        var modifier = 0

        let relevantMemories = actor.significantMemoriesAbout(characterId: potentialTarget.templateId)

        for memory in relevantMemories {
            let strengthMultiplier = Double(memory.currentStrength) / 100.0

            switch memory.memoryType {
            case .wasInvestigated:
                // They investigated me - revenge actions get bonus
                if action == .denounce { modifier += Int(Double(20) * strengthMultiplier) }
                if action == .launchInvestigation { modifier += Int(Double(25) * strengthMultiplier) }
                if action == .sabotageProject { modifier += Int(Double(15) * strengthMultiplier) }
                // Cooperation actions get penalty
                if action == .formAlliance { modifier -= Int(Double(30) * strengthMultiplier) }
                if action == .shareIntelligence { modifier -= Int(Double(25) * strengthMultiplier) }

            case .allianceFormed:
                // We're allies - cooperation bonus
                if action == .shareIntelligence { modifier += Int(Double(20) * strengthMultiplier) }
                if action == .formAlliance { modifier += Int(Double(10) * strengthMultiplier) }
                // Betrayal less likely
                if action == .betrayAlliance { modifier -= Int(Double(30) * strengthMultiplier) }
                if action == .denounce { modifier -= Int(Double(20) * strengthMultiplier) }

            case .allianceBroken:
                // They betrayed me
                if action == .denounce { modifier += Int(Double(25) * strengthMultiplier) }
                if action == .launchInvestigation { modifier += Int(Double(20) * strengthMultiplier) }
                if action == .formAlliance { modifier -= Int(Double(40) * strengthMultiplier) }

            case .crisisCollaboration:
                // We worked together - trust bonus
                if action == .shareIntelligence { modifier += Int(Double(15) * strengthMultiplier) }
                if action == .formAlliance { modifier += Int(Double(10) * strengthMultiplier) }

            case .threatReceived:
                // They threatened me - fear or retaliation
                if actor.personalityParanoid > 50 {
                    if action == .seekProtection { modifier += Int(Double(20) * strengthMultiplier) }
                }
                if actor.personalityRuthless > 50 {
                    if action == .denounce { modifier += Int(Double(15) * strengthMultiplier) }
                }

            case .secretShared:
                // They trusted me with secrets
                if action == .shareIntelligence { modifier += Int(Double(15) * strengthMultiplier) }
                if action == .formAlliance { modifier += Int(Double(10) * strengthMultiplier) }

            case .publicHumiliation:
                // They humiliated me
                if action == .denounce { modifier += Int(Double(30) * strengthMultiplier) }
                if action == .launchInvestigation { modifier += Int(Double(25) * strengthMultiplier) }
                if action == .formAlliance { modifier -= Int(Double(35) * strengthMultiplier) }

            case .promotionBlocked:
                // They blocked my career - strong grudge
                if action == .blockPromotion { modifier += Int(Double(20) * strengthMultiplier) }
                if action == .sabotageProject { modifier += Int(Double(20) * strengthMultiplier) }
                if action == .denounce { modifier += Int(Double(15) * strengthMultiplier) }
                // STRONGLY penalize cooperation with someone who blocked you
                if action == .formAlliance { modifier -= Int(Double(40) * strengthMultiplier) }
                if action == .shareIntelligence { modifier -= Int(Double(35) * strengthMultiplier) }
                if action == .seekProtection { modifier -= Int(Double(30) * strengthMultiplier) }
                if action == .curryFavor { modifier -= Int(Double(25) * strengthMultiplier) }

            case .blockedPromotion:
                // I blocked their career - they won't cooperate with me
                if action == .formAlliance { modifier -= Int(Double(30) * strengthMultiplier) }
                if action == .shareIntelligence { modifier -= Int(Double(25) * strengthMultiplier) }

            case .betrayal:
                // Strong grudge - no cooperation
                if action == .denounce { modifier += Int(Double(30) * strengthMultiplier) }
                if action == .launchInvestigation { modifier += Int(Double(25) * strengthMultiplier) }
                if action == .formAlliance { modifier -= Int(Double(50) * strengthMultiplier) }
                if action == .shareIntelligence { modifier -= Int(Double(40) * strengthMultiplier) }
                if action == .seekProtection { modifier -= Int(Double(45) * strengthMultiplier) }

            default:
                break
            }
        }

        return modifier
    }

    // MARK: - NPC Behavior System: Espionage

    /// Process spy detection for all active spies
    func processSpyDetection(game: Game) {
        let activeSpies = game.characters.filter { $0.isActiveSpy }

        for spy in activeSpies {
            let agent = spy.foreignAgentStatus

            // Base detection chance from suspicion level
            var detectionChance = agent.suspicionLevel / 5

            // Security services vigilance increases detection
            let securityVigilance = calculateSecurityVigilance(game: game)
            detectionChance += securityVigilance / 10

            // Recent activity increases risk
            if let lastActivity = agent.lastActivityTurn, game.turnNumber - lastActivity <= 2 {
                detectionChance += 10
            }

            // Tradecraft reduces risk
            detectionChance -= agent.tradecraft / 10

            // Roll for detection
            if Int.random(in: 1...100) <= max(1, detectionChance) {
                handleSpyCaught(spy, game: game)
            }
        }
    }

    /// Calculate security services vigilance level
    func calculateSecurityVigilance(game: Game) -> Int {
        var vigilance = 50

        // High paranoia leader increases vigilance
        // Find the highest-ranking character (General Secretary level = 7)
        let topLeader = game.characters.first { $0.isActive && ($0.positionIndex ?? 0) >= 7 }
        if let leader = topLeader ?? game.patron, leader.personalityParanoid > 60 {
            vigilance += 20
        }

        // Low stability increases vigilance
        if game.stability < 40 {
            vigilance += 15
        }

        // Security track head competence
        if let secHead = getSecurityServicesHead(game: game) {
            vigilance += secHead.personalityCompetent / 4
        }

        return min(100, vigilance)
    }

    /// Get security services head
    private func getSecurityServicesHead(game: Game) -> GameCharacter? {
        return game.characters.first { char in
            char.isActive && char.positionTrack == "securityServices" && (char.positionIndex ?? 0) >= 5
        }
    }

    /// Handle catching a spy
    private func handleSpyCaught(_ spy: GameCharacter, game: Game) {
        // Change status
        spy.status = CharacterStatus.detained.rawValue
        spy.statusDetails = "Arrested for espionage"
        spy.statusChangedTurn = game.turnNumber

        // Create memory for security services
        if let secHead = getSecurityServicesHead(game: game) {
            secHead.addNPCMemory(NPCMemory(
                memoryType: .caughtSpy,
                turn: game.turnNumber,
                involvedCharacterId: spy.templateId,
                involvedCharacterName: spy.name,
                severity: 90,
                sentiment: 50,
                description: "Caught foreign spy \(spy.name)"
            ))
        }

        // Spy gets traumatic memory
        spy.addNPCMemory(NPCMemory(
            memoryType: .wasDetained,
            turn: game.turnNumber,
            involvedCharacterId: nil,
            involvedCharacterName: nil,
            severity: 95,
            sentiment: -95,
            description: "Arrested for espionage"
        ))

        // Log event (game will handle creating DynamicEvent)
        #if DEBUG
        print("[ESPIONAGE] \(spy.name) caught as foreign agent for \(spy.foreignAgentStatus.foreignPower ?? "unknown power")")
        #endif
    }

    /// Update spy suspicion after action
    func updateSpySuspicion(spy: GameCharacter, action: NPCActionType, game: Game) {
        guard spy.isActiveSpy else { return }

        var suspicionIncrease = 0

        switch action {
        case .shareIntelligence:
            suspicionIncrease = max(0, 10 - spy.foreignAgentStatus.tradecraft / 20)
        case .conductSurveillance:
            suspicionIncrease = max(0, 5 - spy.foreignAgentStatus.tradecraft / 25)
        case .sabotageProject:
            suspicionIncrease = max(0, 15 - spy.foreignAgentStatus.tradecraft / 15)
        default:
            break
        }

        // Security services investigation drastically increases suspicion
        let wasInvestigated = spy.npcMemoriesEnhanced.contains { memory in
            memory.memoryType == .wasInvestigated && game.turnNumber - memory.turn <= 3
        }
        if wasInvestigated {
            suspicionIncrease += 20
        }

        if suspicionIncrease > 0 {
            spy.increaseSuspicion(amount: suspicionIncrease)
            spy.erodeCover(amount: suspicionIncrease / 3)
            spy.recordSpyActivity(turn: game.turnNumber)
        }
    }

    /// Party devotion modifier for action selection
    func partyDevotionModifier(character: GameCharacter, action: NPCActionType) -> Int {
        guard character.personalityLoyal > 70 else { return 0 }

        var modifier = 0
        let devotionLevel = character.personalityLoyal - 50

        // True believers excel at ideological work
        if action == .ideologicalCampaign { modifier += devotionLevel / 3 }
        if action == .enforceDiscipline { modifier += devotionLevel / 4 }
        if action == .cadreReview { modifier += devotionLevel / 4 }

        // They resist personal enrichment
        if action == .sabotageProject && character.personalityCorrupt < 40 {
            modifier -= devotionLevel / 2
        }

        // They're zealous about finding traitors
        if action == .launchInvestigation { modifier += devotionLevel / 5 }
        if action == .conductSurveillance { modifier += devotionLevel / 5 }

        return modifier
    }

    // MARK: - Initialize Behavior System for All Characters

    /// Initialize goals and needs for all characters
    func initializeBehaviorSystem(game: Game) {
        for character in game.characters where character.isActive {
            // Skip if already initialized
            if !character.npcGoals.isEmpty && character.npcNeedsData != nil {
                continue
            }

            // Initialize goals
            assignInitialGoals(to: character, game: game)

            // Initialize needs based on personality and position
            var needs = NPCNeeds()
            let position = character.positionIndex ?? 0

            // Security based on position and paranoia
            needs.security = 60 - (character.personalityParanoid / 4) + (position * 3)

            // Power based on position
            needs.power = 40 + (position * 5)

            // Recognition
            needs.recognition = 50

            // Stability
            needs.stability = 60 - (character.personalityAmbitious / 5)

            // Loyalty based on faction
            needs.loyalty = character.factionId != nil ? 60 : 45

            // Ideological commitment based on personality
            needs.ideologicalCommitment = 30 + character.personalityLoyal / 2

            character.npcNeeds = needs
        }
    }
}

// MARK: - NPC Action Types

enum NPCActionType: String, CaseIterable {
    // SCHEMING ACTIONS (Original 12)
    case formAlliance       // Two NPCs ally against common threat
    case betrayAlliance     // NPC betrays an ally
    case denounce           // NPC files denunciation against another
    case blockPromotion     // NPC blocks another's advancement
    case spreadRumors       // NPC spreads damaging rumors
    case seekProtection     // NPC seeks patron relationship
    case cultivateSupport   // NPC builds support among juniors
    case shareIntelligence  // NPC shares information with another (bonding)
    case organizeGathering  // NPC hosts informal meeting (faction building)
    case makeImplicitThreat // NPC threatens without overt action
    case curryFavor         // NPC seeks to improve standing with superior
    case sabotageProject    // NPC undermines another's work

    // GOVERNANCE: Foreign Affairs Track (3)
    case negotiateTreaty       // Propose/negotiate with foreign country
    case diplomaticOutreach    // Improve relations with ally/rival nation
    case recallAmbassador      // Escalate diplomatic pressure on nation

    // GOVERNANCE: Economic Planning Track (3)
    case setProductionQuota    // Adjust industrial/agricultural targets
    case allocateResources     // Direct resources to sector/region
    case proposeEconomicReform // Structural economic changes

    // GOVERNANCE: Security Services Track (3)
    case launchInvestigation   // Target a character for investigation
    case conductSurveillance   // Gather intel on target character
    case detainSuspect         // Arrest/detain character

    // GOVERNANCE: State Ministry Track (3)
    case proposeLegislation    // Propose new law/policy
    case administrativeReform  // Restructure bureaucracy
    case manageCrisis          // Handle ongoing crisis

    // GOVERNANCE: Party Apparatus Track (3)
    case ideologicalCampaign   // Launch propaganda/education drive
    case cadreReview           // Evaluate personnel for loyalty
    case enforceDiscipline     // Discipline party members

    // GOVERNANCE: Military-Political Track (3)
    case inspectTroopLoyalty   // Check military unit loyalty
    case politicalIndoctrination // Strengthen army political education
    case vetOfficers           // Screen officer corps

    // GOVERNANCE: Position-Level Actions (6)
    case proposePolicyChange   // Suggest policy to Politburo (4+)
    case callEmergencyMeeting  // Convene urgent session (5+)
    case issueDirective        // Issue orders to subordinates (5+)
    case demandResignation     // Force out subordinate (6+)
    case reorganizeDepartment  // Restructure organization (6+)
    case setNationalPriority   // Influence national agenda (7+)
    case proposeLawChange      // Standing Committee: propose law modification (7+)

    // GOVERNANCE: Reactive Actions (4)
    case respondToCrisis       // Address current crisis
    case addressShortage       // Handle resource emergency
    case handleIncident        // Manage international incident
    case suppressUnrest        // Deal with stability issue

    // Scheming actions array for easy access
    static var schemingActions: [NPCActionType] {
        [.formAlliance, .betrayAlliance, .denounce, .blockPromotion,
         .spreadRumors, .seekProtection, .cultivateSupport,
         .shareIntelligence, .organizeGathering, .makeImplicitThreat,
         .curryFavor, .sabotageProject]
    }

    static var allCases: [NPCActionType] {
        schemingActions + [
            // Foreign Affairs
            .negotiateTreaty, .diplomaticOutreach, .recallAmbassador,
            // Economic Planning
            .setProductionQuota, .allocateResources, .proposeEconomicReform,
            // Security Services
            .launchInvestigation, .conductSurveillance, .detainSuspect,
            // State Ministry
            .proposeLegislation, .administrativeReform, .manageCrisis,
            // Party Apparatus
            .ideologicalCampaign, .cadreReview, .enforceDiscipline,
            // Military-Political
            .inspectTroopLoyalty, .politicalIndoctrination, .vetOfficers,
            // Position-Level
            .proposePolicyChange, .callEmergencyMeeting, .issueDirective,
            .demandResignation, .reorganizeDepartment, .setNationalPriority,
            .proposeLawChange,
            // Reactive
            .respondToCrisis, .addressShortage, .handleIncident, .suppressUnrest
        ]
    }

    var iconName: String {
        switch self {
        // Scheming
        case .formAlliance: return "person.2.fill"
        case .betrayAlliance: return "person.fill.xmark"
        case .denounce: return "exclamationmark.triangle.fill"
        case .blockPromotion: return "hand.raised.fill"
        case .spreadRumors: return "bubble.left.and.bubble.right.fill"
        case .seekProtection: return "shield.fill"
        case .cultivateSupport: return "person.3.fill"
        case .shareIntelligence: return "envelope.fill"
        case .organizeGathering: return "person.3.sequence.fill"
        case .makeImplicitThreat: return "hand.point.right.fill"
        case .curryFavor: return "gift.fill"
        case .sabotageProject: return "xmark.seal.fill"
        // Foreign Affairs
        case .negotiateTreaty: return "doc.text.fill"
        case .diplomaticOutreach: return "globe.europe.africa.fill"
        case .recallAmbassador: return "airplane.departure"
        // Economic Planning
        case .setProductionQuota: return "chart.bar.fill"
        case .allocateResources: return "shippingbox.fill"
        case .proposeEconomicReform: return "chart.line.uptrend.xyaxis"
        // Security Services
        case .launchInvestigation: return "magnifyingglass"
        case .conductSurveillance: return "eye.fill"
        case .detainSuspect: return "lock.fill"
        // State Ministry
        case .proposeLegislation: return "doc.badge.plus"
        case .administrativeReform: return "building.2.fill"
        case .manageCrisis: return "exclamationmark.shield.fill"
        // Party Apparatus
        case .ideologicalCampaign: return "megaphone.fill"
        case .cadreReview: return "person.text.rectangle.fill"
        case .enforceDiscipline: return "hammer.fill"
        // Military-Political
        case .inspectTroopLoyalty: return "star.fill"
        case .politicalIndoctrination: return "book.fill"
        case .vetOfficers: return "person.badge.shield.checkmark.fill"
        // Position-Level
        case .proposePolicyChange: return "doc.richtext.fill"
        case .callEmergencyMeeting: return "bell.badge.fill"
        case .issueDirective: return "scroll.fill"
        case .demandResignation: return "person.fill.badge.minus"
        case .reorganizeDepartment: return "arrow.triangle.branch"
        case .setNationalPriority: return "flag.fill"
        case .proposeLawChange: return "building.columns.fill"
        // Reactive
        case .respondToCrisis: return "bolt.fill"
        case .addressShortage: return "exclamationmark.triangle.fill"
        case .handleIncident: return "globe.badge.chevron.backward"
        case .suppressUnrest: return "shield.lefthalf.filled"
        }
    }

    var accentColor: String {
        switch self {
        // Scheming
        case .formAlliance: return "statHigh"
        case .betrayAlliance: return "stampRed"
        case .denounce: return "sovietRed"
        case .blockPromotion: return "statLow"
        case .spreadRumors: return "inkGray"
        case .seekProtection: return "accentGold"
        case .cultivateSupport: return "statMedium"
        case .shareIntelligence: return "accentGold"
        case .organizeGathering: return "inkBlack"
        case .makeImplicitThreat: return "sovietRed"
        case .curryFavor: return "accentGold"
        case .sabotageProject: return "statLow"
        // Foreign Affairs - diplomatic blue/gold
        case .negotiateTreaty: return "accentGold"
        case .diplomaticOutreach: return "statMedium"
        case .recallAmbassador: return "statLow"
        // Economic Planning - industrial gray/gold
        case .setProductionQuota: return "inkGray"
        case .allocateResources: return "accentGold"
        case .proposeEconomicReform: return "statMedium"
        // Security Services - dark/red
        case .launchInvestigation: return "sovietRed"
        case .conductSurveillance: return "inkBlack"
        case .detainSuspect: return "stampRed"
        // State Ministry - neutral/official
        case .proposeLegislation: return "inkBlack"
        case .administrativeReform: return "inkGray"
        case .manageCrisis: return "statLow"
        // Party Apparatus - red
        case .ideologicalCampaign: return "sovietRed"
        case .cadreReview: return "inkGray"
        case .enforceDiscipline: return "stampRed"
        // Military-Political - military green/gray
        case .inspectTroopLoyalty: return "statMedium"
        case .politicalIndoctrination: return "sovietRed"
        case .vetOfficers: return "inkGray"
        // Position-Level - authority gold
        case .proposePolicyChange: return "accentGold"
        case .callEmergencyMeeting: return "stampRed"
        case .issueDirective: return "accentGold"
        case .demandResignation: return "statLow"
        case .reorganizeDepartment: return "inkGray"
        case .setNationalPriority: return "accentGold"
        case .proposeLawChange: return "sovietRed"
        // Reactive - urgent red/warning
        case .respondToCrisis: return "stampRed"
        case .addressShortage: return "statLow"
        case .handleIncident: return "sovietRed"
        case .suppressUnrest: return "stampRed"
        }
    }

    /// Description for narrative purposes
    var actionDescription: String {
        switch self {
        // Scheming
        case .formAlliance: return "forming a political alliance"
        case .betrayAlliance: return "betraying a former ally"
        case .denounce: return "filing a formal denunciation"
        case .blockPromotion: return "blocking a competitor's advancement"
        case .spreadRumors: return "spreading damaging rumors"
        case .seekProtection: return "seeking political protection"
        case .cultivateSupport: return "building a support network"
        case .shareIntelligence: return "sharing sensitive information"
        case .organizeGathering: return "organizing an informal meeting"
        case .makeImplicitThreat: return "making veiled threats"
        case .curryFavor: return "seeking favor with superiors"
        case .sabotageProject: return "undermining a rival's work"
        // Foreign Affairs
        case .negotiateTreaty: return "negotiating an international treaty"
        case .diplomaticOutreach: return "conducting diplomatic outreach"
        case .recallAmbassador: return "recalling an ambassador in protest"
        // Economic Planning
        case .setProductionQuota: return "setting new production quotas"
        case .allocateResources: return "redirecting state resources"
        case .proposeEconomicReform: return "proposing economic reforms"
        // Security Services
        case .launchInvestigation: return "launching a formal investigation"
        case .conductSurveillance: return "conducting surveillance operations"
        case .detainSuspect: return "ordering the detention of a suspect"
        // State Ministry
        case .proposeLegislation: return "drafting new legislation"
        case .administrativeReform: return "restructuring administrative systems"
        case .manageCrisis: return "managing an ongoing crisis"
        // Party Apparatus
        case .ideologicalCampaign: return "launching an ideological campaign"
        case .cadreReview: return "reviewing cadre personnel files"
        case .enforceDiscipline: return "enforcing Party discipline"
        // Military-Political
        case .inspectTroopLoyalty: return "inspecting military unit loyalty"
        case .politicalIndoctrination: return "conducting political education"
        case .vetOfficers: return "vetting officer candidates"
        // Position-Level
        case .proposePolicyChange: return "proposing a policy change"
        case .callEmergencyMeeting: return "convening an emergency session"
        case .issueDirective: return "issuing an official directive"
        case .demandResignation: return "demanding a resignation"
        case .reorganizeDepartment: return "reorganizing a department"
        case .setNationalPriority: return "setting national priorities"
        case .proposeLawChange: return "proposing law modifications"
        // Reactive
        case .respondToCrisis: return "responding to a crisis"
        case .addressShortage: return "addressing resource shortages"
        case .handleIncident: return "handling an international incident"
        case .suppressUnrest: return "suppressing civil unrest"
        }
    }

    /// How the actor views their own action
    var actorPerspective: String {
        switch self {
        // Scheming
        case .formAlliance: return "Offered alliance"
        case .betrayAlliance: return "Broke with ally"
        case .denounce: return "Filed denunciation"
        case .blockPromotion: return "Blocked advancement"
        case .spreadRumors: return "Spread information"
        case .seekProtection: return "Sought protection"
        case .cultivateSupport: return "Built support"
        case .shareIntelligence: return "Shared intelligence"
        case .organizeGathering: return "Hosted gathering"
        case .makeImplicitThreat: return "Issued warning"
        case .curryFavor: return "Sought favor"
        case .sabotageProject: return "Took action"
        // Foreign Affairs
        case .negotiateTreaty: return "Negotiated treaty"
        case .diplomaticOutreach: return "Made diplomatic contact"
        case .recallAmbassador: return "Recalled ambassador"
        // Economic Planning
        case .setProductionQuota: return "Set new quotas"
        case .allocateResources: return "Redirected resources"
        case .proposeEconomicReform: return "Proposed reform"
        // Security Services
        case .launchInvestigation: return "Opened investigation"
        case .conductSurveillance: return "Initiated surveillance"
        case .detainSuspect: return "Ordered detention"
        // State Ministry
        case .proposeLegislation: return "Drafted legislation"
        case .administrativeReform: return "Reformed administration"
        case .manageCrisis: return "Managed crisis"
        // Party Apparatus
        case .ideologicalCampaign: return "Launched campaign"
        case .cadreReview: return "Reviewed cadres"
        case .enforceDiscipline: return "Enforced discipline"
        // Military-Political
        case .inspectTroopLoyalty: return "Inspected troops"
        case .politicalIndoctrination: return "Conducted education"
        case .vetOfficers: return "Vetted officers"
        // Position-Level
        case .proposePolicyChange: return "Proposed policy"
        case .callEmergencyMeeting: return "Called meeting"
        case .issueDirective: return "Issued directive"
        case .demandResignation: return "Demanded resignation"
        case .reorganizeDepartment: return "Reorganized dept"
        case .setNationalPriority: return "Set priority"
        case .proposeLawChange: return "Proposed law"
        // Reactive
        case .respondToCrisis: return "Responded to crisis"
        case .addressShortage: return "Addressed shortage"
        case .handleIncident: return "Handled incident"
        case .suppressUnrest: return "Suppressed unrest"
        }
    }

    /// How the target experiences the action
    var targetPerspective: String {
        switch self {
        // Scheming
        case .formAlliance: return "Alliance offered"
        case .betrayAlliance: return "Was betrayed"
        case .denounce: return "Was denounced"
        case .blockPromotion: return "Advancement blocked"
        case .spreadRumors: return "Reputation attacked"
        case .seekProtection: return "Approached for protection"
        case .cultivateSupport: return "Support cultivated"
        case .shareIntelligence: return "Received intelligence"
        case .organizeGathering: return "Invited to gathering"
        case .makeImplicitThreat: return "Received threat"
        case .curryFavor: return "Favor sought"
        case .sabotageProject: return "Work undermined"
        // Foreign Affairs (target is usually a country, not NPC)
        case .negotiateTreaty: return "Treaty proposed"
        case .diplomaticOutreach: return "Received overture"
        case .recallAmbassador: return "Diplomatic protest"
        // Economic Planning (targets sectors/regions)
        case .setProductionQuota: return "Quotas adjusted"
        case .allocateResources: return "Resources redirected"
        case .proposeEconomicReform: return "Reform proposed"
        // Security Services
        case .launchInvestigation: return "Under investigation"
        case .conductSurveillance: return "Being watched"
        case .detainSuspect: return "Was detained"
        // State Ministry
        case .proposeLegislation: return "Legislation affects"
        case .administrativeReform: return "Restructured"
        case .manageCrisis: return "Crisis managed"
        // Party Apparatus
        case .ideologicalCampaign: return "Campaign targeted"
        case .cadreReview: return "Under review"
        case .enforceDiscipline: return "Disciplined"
        // Military-Political
        case .inspectTroopLoyalty: return "Inspected"
        case .politicalIndoctrination: return "Indoctrinated"
        case .vetOfficers: return "Vetted"
        // Position-Level
        case .proposePolicyChange: return "Policy affects"
        case .callEmergencyMeeting: return "Summoned to meeting"
        case .issueDirective: return "Received orders"
        case .demandResignation: return "Resignation demanded"
        case .reorganizeDepartment: return "Dept reorganized"
        case .setNationalPriority: return "Priority set"
        case .proposeLawChange: return "Law proposed"
        // Reactive
        case .respondToCrisis: return "Crisis addressed"
        case .addressShortage: return "Shortage addressed"
        case .handleIncident: return "Incident handled"
        case .suppressUnrest: return "Unrest suppressed"
        }
    }

    /// Disposition change from target's perspective
    var dispositionEffect: Int {
        switch self {
        // Scheming
        case .formAlliance: return 15
        case .betrayAlliance: return -35
        case .denounce: return -30
        case .blockPromotion: return -20
        case .spreadRumors: return -15
        case .seekProtection: return 5
        case .cultivateSupport: return 10
        case .shareIntelligence: return 15
        case .organizeGathering: return 5
        case .makeImplicitThreat: return -20
        case .curryFavor: return 5
        case .sabotageProject: return -25
        // Foreign Affairs (mostly neutral - diplomatic)
        case .negotiateTreaty: return 10
        case .diplomaticOutreach: return 5
        case .recallAmbassador: return -15
        // Economic Planning (neutral - just doing job)
        case .setProductionQuota: return 0
        case .allocateResources: return 0
        case .proposeEconomicReform: return 0
        // Security Services (negative - threatening)
        case .launchInvestigation: return -25
        case .conductSurveillance: return -15
        case .detainSuspect: return -40
        // State Ministry (neutral)
        case .proposeLegislation: return 0
        case .administrativeReform: return -5
        case .manageCrisis: return 5
        // Party Apparatus (can be negative)
        case .ideologicalCampaign: return -5
        case .cadreReview: return -10
        case .enforceDiscipline: return -20
        // Military-Political (neutral to negative)
        case .inspectTroopLoyalty: return -5
        case .politicalIndoctrination: return 0
        case .vetOfficers: return -5
        // Position-Level (varies)
        case .proposePolicyChange: return 0
        case .callEmergencyMeeting: return 0
        case .issueDirective: return -5
        case .demandResignation: return -35
        case .reorganizeDepartment: return -10
        case .setNationalPriority: return 0
        case .proposeLawChange: return 0
        // Reactive (neutral - crisis response)
        case .respondToCrisis: return 0
        case .addressShortage: return 5
        case .handleIncident: return 0
        case .suppressUnrest: return -10
        }
    }

    /// Generate history descriptions for both parties
    func historyDescription(actor: String, target: String) -> (actorOutcome: String, targetOutcome: String) {
        switch self {
        // SCHEMING ACTIONS
        case .formAlliance:
            return ("Formed alliance with \(target)", "\(actor) proposed alliance")
        case .betrayAlliance:
            return ("Severed ties with \(target)", "Betrayed by \(actor)")
        case .denounce:
            return ("Denounced \(target) to authorities", "Denounced by \(actor)")
        case .blockPromotion:
            return ("Blocked \(target)'s advancement", "Advancement blocked by \(actor)")
        case .spreadRumors:
            return ("Spread rumors about \(target)", "Rumors spread by \(actor)")
        case .seekProtection:
            return ("Sought protection from \(target)", "\(actor) requested patronage")
        case .cultivateSupport:
            return ("Cultivated support from \(target)", "\(actor) building influence")
        case .shareIntelligence:
            return ("Shared intelligence with \(target)", "Received intel from \(actor)")
        case .organizeGathering:
            return ("Hosted meeting with \(target)", "Attended \(actor)'s gathering")
        case .makeImplicitThreat:
            return ("Warned \(target) of consequences", "Threatened by \(actor)")
        case .curryFavor:
            return ("Sought favor with \(target)", "\(actor) seeking influence")
        case .sabotageProject:
            return ("Undermined \(target)'s work", "Work sabotaged by \(actor)")

        // GOVERNANCE: Foreign Affairs Track
        case .negotiateTreaty:
            return ("Negotiated treaty involving \(target)", "Consulted by \(actor) on treaty")
        case .diplomaticOutreach:
            return ("Diplomatic outreach coordinated with \(target)", "\(actor) coordinated diplomatic effort")
        case .recallAmbassador:
            return ("Recalled ambassador, briefed \(target)", "Briefed by \(actor) on recall")

        // GOVERNANCE: Economic Planning Track
        case .setProductionQuota:
            return ("Set production quotas affecting \(target)", "Quotas set by \(actor)")
        case .allocateResources:
            return ("Allocated resources involving \(target)", "Resource allocation by \(actor)")
        case .proposeEconomicReform:
            return ("Proposed economic reform to \(target)", "\(actor) proposed reform")

        // GOVERNANCE: Security Services Track
        case .launchInvestigation:
            return ("Launched investigation into \(target)", "Under investigation by \(actor)")
        case .conductSurveillance:
            return ("Conducted surveillance on \(target)", "Monitored by \(actor)")
        case .detainSuspect:
            return ("Ordered detention of \(target)", "Detained by order of \(actor)")

        // GOVERNANCE: State Ministry Track
        case .proposeLegislation:
            return ("Proposed legislation affecting \(target)", "\(actor) proposed new law")
        case .administrativeReform:
            return ("Implemented reform affecting \(target)", "Reformed by \(actor)")
        case .manageCrisis:
            return ("Managed crisis involving \(target)", "Crisis managed by \(actor)")

        // GOVERNANCE: Party Apparatus Track
        case .ideologicalCampaign:
            return ("Launched campaign targeting \(target)", "Targeted by \(actor)'s campaign")
        case .cadreReview:
            return ("Reviewed cadre file of \(target)", "Reviewed by \(actor)")
        case .enforceDiscipline:
            return ("Enforced discipline on \(target)", "Disciplined by \(actor)")

        // GOVERNANCE: Military-Political Track
        case .inspectTroopLoyalty:
            return ("Inspected troops under \(target)", "Troops inspected by \(actor)")
        case .politicalIndoctrination:
            return ("Political education for \(target)'s unit", "Unit educated by \(actor)")
        case .vetOfficers:
            return ("Vetted officers under \(target)", "Officers vetted by \(actor)")

        // GOVERNANCE: Position-Level Actions
        case .proposePolicyChange:
            return ("Proposed policy change to \(target)", "\(actor) proposed policy")
        case .callEmergencyMeeting:
            return ("Called emergency meeting with \(target)", "Summoned by \(actor)")
        case .issueDirective:
            return ("Issued directive to \(target)", "Received directive from \(actor)")
        case .demandResignation:
            return ("Demanded resignation of \(target)", "Resignation demanded by \(actor)")
        case .reorganizeDepartment:
            return ("Reorganized department affecting \(target)", "Department reorganized by \(actor)")
        case .setNationalPriority:
            return ("Set national priority affecting \(target)", "Priority set by \(actor)")
        case .proposeLawChange:
            return ("Proposed law change to Standing Committee", "Law proposed by \(actor)")

        // GOVERNANCE: Reactive Actions
        case .respondToCrisis:
            return ("Crisis response involving \(target)", "Crisis response by \(actor)")
        case .addressShortage:
            return ("Addressed shortage affecting \(target)", "Shortage addressed by \(actor)")
        case .handleIncident:
            return ("Handled incident with \(target)", "Incident handled by \(actor)")
        case .suppressUnrest:
            return ("Suppressed unrest involving \(target)", "Unrest suppressed by \(actor)")
        }
    }
}

// MARK: - NPC Action Category

/// Categories for NPC actions - scheming vs governance
enum NPCActionCategory: String {
    case scheming           // Original 12 political scheming actions
    case foreignAffairs     // MFA track governance
    case economicPlanning   // Gosplan track governance
    case security           // BPS track governance
    case administration     // CoM track governance
    case partyWork          // CC track governance
    case militaryPolitical  // MPA track governance
    case leadership         // Position-based actions
    case reactive           // Crisis response actions
}

// MARK: - NPCActionType Category & Requirements

extension NPCActionType {
    /// The category this action belongs to
    var category: NPCActionCategory {
        switch self {
        // Scheming
        case .formAlliance, .betrayAlliance, .denounce, .blockPromotion,
             .spreadRumors, .seekProtection, .cultivateSupport, .shareIntelligence,
             .organizeGathering, .makeImplicitThreat, .curryFavor, .sabotageProject:
            return .scheming

        // Foreign Affairs
        case .negotiateTreaty, .diplomaticOutreach, .recallAmbassador:
            return .foreignAffairs

        // Economic Planning
        case .setProductionQuota, .allocateResources, .proposeEconomicReform:
            return .economicPlanning

        // Security Services
        case .launchInvestigation, .conductSurveillance, .detainSuspect:
            return .security

        // State Ministry
        case .proposeLegislation, .administrativeReform, .manageCrisis:
            return .administration

        // Party Apparatus
        case .ideologicalCampaign, .cadreReview, .enforceDiscipline:
            return .partyWork

        // Military-Political
        case .inspectTroopLoyalty, .politicalIndoctrination, .vetOfficers:
            return .militaryPolitical

        // Position-Level
        case .proposePolicyChange, .callEmergencyMeeting, .issueDirective,
             .demandResignation, .reorganizeDepartment, .setNationalPriority,
             .proposeLawChange:
            return .leadership

        // Reactive
        case .respondToCrisis, .addressShortage, .handleIncident, .suppressUnrest:
            return .reactive
        }
    }

    /// The career track required to perform this action (nil = any track)
    /// Returns ExpandedCareerTrack raw value for comparison with character.positionTrack
    var requiredTrack: String? {
        switch self.category {
        case .foreignAffairs:
            return ExpandedCareerTrack.foreignAffairs.rawValue
        case .economicPlanning:
            return ExpandedCareerTrack.economicPlanning.rawValue
        case .security:
            return ExpandedCareerTrack.securityServices.rawValue
        case .administration:
            return ExpandedCareerTrack.stateMinistry.rawValue
        case .partyWork:
            return ExpandedCareerTrack.partyApparatus.rawValue
        case .militaryPolitical:
            return ExpandedCareerTrack.militaryPolitical.rawValue
        case .scheming, .leadership, .reactive:
            return nil  // Any track can do these
        }
    }

    /// Minimum position index required to perform this action
    var minimumPosition: Int {
        switch self {
        // Track-specific governance requires position 3+
        case .negotiateTreaty, .diplomaticOutreach, .recallAmbassador,
             .setProductionQuota, .allocateResources, .proposeEconomicReform,
             .launchInvestigation, .conductSurveillance, .detainSuspect,
             .proposeLegislation, .administrativeReform, .manageCrisis,
             .ideologicalCampaign, .cadreReview, .enforceDiscipline,
             .inspectTroopLoyalty, .politicalIndoctrination, .vetOfficers:
            return 3

        // Position-level actions have varying requirements
        case .proposePolicyChange:
            return 4  // Department Head+
        case .callEmergencyMeeting, .issueDirective:
            return 5  // Senior Leadership+
        case .demandResignation, .reorganizeDepartment:
            return 6  // Apex/Track Head+
        case .setNationalPriority:
            return 7  // Deputy General Secretary+
        case .proposeLawChange:
            return 7  // Standing Committee membership required

        // Reactive actions require position 3+
        case .respondToCrisis, .addressShortage, .handleIncident, .suppressUnrest:
            return 3

        // Scheming available to everyone
        default:
            return 0
        }
    }

    /// Check if a character can perform this action based on track and position
    func canBePerformedBy(_ character: GameCharacter) -> Bool {
        // Check position requirement
        guard (character.positionIndex ?? 0) >= minimumPosition else { return false }

        // Check track requirement if any
        if let requiredTrack = requiredTrack {
            return character.positionTrack == requiredTrack
        }

        return true
    }
}
