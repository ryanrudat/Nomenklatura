//
//  EventGenerationService.swift
//  Nomenklatura
//
//  SINGLE SOURCE OF TRUTH for character event generation.
//  Consolidates duplicate event generation from CharacterAgencyService
//  and DynamicEventTriggerService into one authoritative service.
//

import Foundation
import os.log

private let eventLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "EventGeneration")

// MARK: - Event Generation Service

final class EventGenerationService {
    static let shared = EventGenerationService()

    private init() {}

    // MARK: - Patron Events

    /// Generate a patron warning event
    func generatePatronWarning(patron: GameCharacter, game: Game) -> DynamicEvent {
        let titles = [
            "A Word of Caution",
            "Private Communication",
            "A Warning",
            "Confidential Message",
            "Quiet Concerns"
        ]

        let texts = [
            "\(patron.name) sends word through back channels. The tone is concerned:\n\n\"I have heard whispers, Comrade. Questions are being asked about your recent decisions. Questions I cannot easily deflect. You would do well to demonstrate your loyalty in the coming days.\"",
            "A note arrives, written in \(patron.name)'s distinctive hand:\n\n\"Certain parties have taken notice of your... activities. I suggest you consider your position carefully. The General Secretary has a long memory.\"",
            "\(patron.name) catches your eye across the ministry corridor and gestures subtly toward an empty office.\n\n\"Be careful,\" they say quietly. \"Your rivals are circling. I may not always be able to protect you.\"",
            "A trusted aide delivers a verbal message from \(patron.name):\n\n\"The winds are shifting. Your recent performance has raised eyebrows in certain circles. Tread carefully, and remember who your friends are.\"",
            "\(patron.name) pulls you aside after the morning briefing.\n\n\"I've been shielding you from some... criticism. But my influence has limits. You need to produce results soon, or I won't be able to help you.\""
        ]

        eventLogger.info("Generated patron warning from \(patron.name)")

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
                EventResponse(
                    id: "acknowledge",
                    text: "Thank your patron for the warning",
                    shortText: "Acknowledge",
                    effects: [:]
                ),
                EventResponse(
                    id: "ask_advice",
                    text: "Ask what you should do",
                    shortText: "Seek Guidance",
                    effects: ["patronFavor": 3]
                ),
                EventResponse(
                    id: "dismiss",
                    text: "Assure them you have everything under control",
                    shortText: "Dismiss Concerns",
                    effects: ["patronFavor": -5]
                )
            ],
            iconName: "hand.raised.fill",
            accentColor: "accentGold"
        )
    }

    /// Generate a patron opportunity event
    func generatePatronOpportunity(patron: GameCharacter, game: Game) -> DynamicEvent {
        let opportunities = [
            (
                title: "An Opportunity Presents Itself",
                text: "\(patron.name) summons you to their office with unusual warmth.\n\n\"Your loyalty has not gone unnoticed, Comrade. A position on the Foreign Affairs Committee has opened. I have recommended you for consideration.\"",
                effects: ["standing": 5, "patronFavor": 5]
            ),
            (
                title: "A Gift from Your Patron",
                text: "A message from \(patron.name): \"The General Secretary was impressed with your handling of recent matters. I have arranged for you to present at the next Presidium meeting. Do not disappoint me.\"",
                effects: ["standing": 8, "patronFavor": 3]
            ),
            (
                title: "Favorable News",
                text: "\(patron.name) pulls you aside after the morning briefing.\n\n\"Director Kowalski is retiring. His position could be yours, if you play your cards right. I will support your candidacy.\"",
                effects: ["standing": 6, "patronFavor": 4]
            ),
            (
                title: "A Door Opens",
                text: "\(patron.name) catches you in the corridor with a rare smile.\n\n\"The inspection tour of the Eastern provinces needs a leader. I've put your name forward. It's a chance to distinguish yourself.\"",
                effects: ["standing": 4, "patronFavor": 6]
            ),
            (
                title: "Recognition",
                text: "You receive a formal summons to \(patron.name)'s office.\n\n\"Your work on the agricultural report was exemplary. I've ensured it reached the General Secretary's desk with a personal recommendation.\"",
                effects: ["standing": 5, "patronFavor": 5]
            )
        ]

        let selected = opportunities.randomElement()!

        eventLogger.info("Generated patron opportunity from \(patron.name)")

        return DynamicEvent(
            eventType: .patronDirective,
            priority: .normal,
            title: selected.title,
            briefText: selected.text,
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "accept_eager",
                    text: "Accept eagerly and thank your patron",
                    shortText: "Accept Eagerly",
                    effects: selected.effects
                ),
                EventResponse(
                    id: "accept_cautious",
                    text: "Accept with appropriate caution",
                    shortText: "Accept Cautiously",
                    effects: ["standing": selected.effects["standing"] ?? 0 - 2]
                ),
                EventResponse(
                    id: "defer",
                    text: "Suggest you are not yet ready",
                    shortText: "Defer",
                    effects: ["patronFavor": -3]
                )
            ],
            iconName: "star.fill",
            accentColor: "accentGold"
        )
    }

    /// Generate a patron directive event (crisis mode)
    func generatePatronDirective(patron: GameCharacter, game: Game) -> DynamicEvent {
        let crisisArea: String
        if game.stability < GameplayConstants.Stability.criticalThreshold {
            crisisArea = "state stability"
        } else if game.popularSupport < GameplayConstants.Stability.criticalThreshold {
            crisisArea = "popular discontent"
        } else if game.militaryLoyalty < GameplayConstants.Stability.lowThreshold {
            crisisArea = "military loyalty"
        } else {
            crisisArea = "the current situation"
        }

        let directives = [
            "The situation with \(crisisArea) is unacceptable. The General Secretary expects results. I am assigning you to handle this personally. Failure is not an option.",
            "We face a crisis in \(crisisArea). The Presidium is watching. I need you to take charge and resolve this before it spirals further.",
            "There are those who would use the problems with \(crisisArea) to undermine our position. You must act decisively to prevent this."
        ]

        eventLogger.info("Generated patron directive from \(patron.name) regarding \(crisisArea)")

        return DynamicEvent(
            eventType: .patronDirective,
            priority: .elevated,
            title: "Orders from Above",
            briefText: "\(patron.name) is direct:\n\n\"\(directives.randomElement()!)\"",
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: true,
            responseOptions: [
                EventResponse(
                    id: "accept_mission",
                    text: "Accept the assignment with determination",
                    shortText: "Accept",
                    effects: ["patronFavor": 5]
                ),
                EventResponse(
                    id: "request_resources",
                    text: "Accept but request additional resources",
                    shortText: "Request Support",
                    effects: ["patronFavor": 2]
                ),
                EventResponse(
                    id: "express_concern",
                    text: "Express concern about the difficulty",
                    shortText: "Show Hesitation",
                    effects: ["patronFavor": -5]
                )
            ],
            iconName: "exclamationmark.triangle.fill",
            accentColor: "sovietRed"
        )
    }

    /// Generate a patron summons event (critically low favor)
    func generatePatronSummons(patron: GameCharacter, game: Game) -> DynamicEvent {
        let summons = [
            "A stern-faced aide appears at your office door.\n\n\"\(patron.name) demands your presence. Immediately.\"\n\nThe walk to their office feels longer than usual. When you arrive, \(patron.name) does not invite you to sit.",
            "You are intercepted in the corridor by \(patron.name)'s secretary.\n\n\"You will come with me. Now.\"\n\nThe tone brooks no argument. Something is very wrong.",
            "A black car pulls up beside you as you leave the ministry.\n\n\"Get in,\" says the driver. \"Comrade \(patron.name) wishes to speak with you.\"\n\nThe ride is silent. Oppressively so."
        ]

        eventLogger.info("Generated URGENT patron summons from \(patron.name)")

        return DynamicEvent(
            eventType: .patronDirective,
            priority: .urgent,
            title: "URGENT: Summoned by Your Patron",
            briefText: summons.randomElement()!,
            initiatingCharacterId: patron.id,
            initiatingCharacterName: patron.name,
            turnGenerated: game.turnNumber,
            isUrgent: true,
            responseOptions: [
                EventResponse(
                    id: "comply_immediately",
                    text: "Go immediately without protest",
                    shortText: "Comply",
                    effects: [:]
                ),
                EventResponse(
                    id: "request_explanation",
                    text: "Ask what this is about",
                    shortText: "Ask Why",
                    effects: ["patronFavor": -2]
                ),
                EventResponse(
                    id: "stall",
                    text: "Try to delay, claiming urgent business",
                    shortText: "Stall",
                    effects: ["patronFavor": -10]
                )
            ],
            iconName: "bell.badge.fill",
            accentColor: "stampRed"
        )
    }

    // MARK: - Rival Events

    /// Generate a rival confrontation event
    func generateRivalConfrontation(rival: GameCharacter, game: Game) -> DynamicEvent {
        let confrontations = [
            (
                title: "A Challenge",
                text: "\(rival.name) corners you after a committee meeting.\n\n\"I know what you're doing,\" they say, voice low but dangerous. \"You think you can undermine me? I have friends in this building. Powerful friends. Watch your step.\"",
                threatIncrease: 10
            ),
            (
                title: "Public Humiliation",
                text: "During a department briefing, \(rival.name) interrupts your presentation.\n\n\"These figures are questionable at best,\" they announce loudly. \"Perhaps Comrade should review their methodology before wasting the committee's time.\"",
                threatIncrease: 8
            ),
            (
                title: "A Warning Shot",
                text: "You find a document on your desk—a draft report criticizing your department's performance. The authorship is anonymous, but the handwriting is unmistakably \(rival.name)'s.\n\nA note is attached: \"This hasn't been submitted yet. Yet.\"",
                threatIncrease: 12
            ),
            (
                title: "Whispers in the Halls",
                text: "You overhear \(rival.name) speaking to a group of colleagues.\n\n\"...completely incompetent. I don't know how they got this far. The General Secretary will see through them eventually.\"\n\nThey catch your eye and smile coldly.",
                threatIncrease: 6
            )
        ]

        let selected = confrontations.randomElement()!

        eventLogger.info("Generated rival confrontation from \(rival.name)")

        return DynamicEvent(
            eventType: .rivalAction,
            priority: .elevated,
            title: selected.title,
            briefText: selected.text,
            initiatingCharacterId: rival.id,
            initiatingCharacterName: rival.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "confront_back",
                    text: "Confront them directly and forcefully",
                    shortText: "Confront",
                    effects: ["rivalThreat": 5, "standing": -2]
                ),
                EventResponse(
                    id: "ignore",
                    text: "Ignore the provocation and maintain composure",
                    shortText: "Ignore",
                    effects: [:]
                ),
                EventResponse(
                    id: "report",
                    text: "Report their behavior to your patron",
                    shortText: "Report",
                    effects: ["patronFavor": -2, "rivalThreat": -5]
                ),
                EventResponse(
                    id: "gather_intel",
                    text: "Say nothing but begin gathering information on them",
                    shortText: "Investigate",
                    effects: ["rivalThreat": -3]
                )
            ],
            iconName: "exclamationmark.shield.fill",
            accentColor: "stampRed"
        )
    }

    /// Generate a rival plot discovery event
    func generateRivalPlot(rival: GameCharacter, game: Game) -> DynamicEvent {
        let plots = [
            (
                title: "A Plot Uncovered",
                text: "A sympathetic colleague pulls you aside.\n\n\"You didn't hear this from me, but \(rival.name) has been meeting privately with members of the inspection committee. They're building a case against you.\"",
                severity: "serious"
            ),
            (
                title: "Dangerous Maneuvering",
                text: "You discover that \(rival.name) has been copying your correspondence—including messages to your patron.\n\n\"Looking for ammunition,\" your secretary observes grimly.",
                severity: "concerning"
            ),
            (
                title: "Alliance Against You",
                text: "Intelligence reaches you that \(rival.name) has been dining with several department heads—all of whom have reasons to resent your rise.\n\nAn anti-you coalition may be forming.",
                severity: "alarming"
            )
        ]

        let selected = plots.randomElement()!

        eventLogger.info("Generated rival plot discovery regarding \(rival.name)")

        return DynamicEvent(
            eventType: .rivalAction,
            priority: .elevated,
            title: selected.title,
            briefText: selected.text,
            initiatingCharacterId: rival.id,
            initiatingCharacterName: rival.name,
            turnGenerated: game.turnNumber,
            isUrgent: selected.severity == "alarming",
            responseOptions: [
                EventResponse(
                    id: "preemptive_strike",
                    text: "Launch a preemptive political attack",
                    shortText: "Strike First",
                    effects: ["rivalThreat": -15, "stability": -3, "standing": -5]
                ),
                EventResponse(
                    id: "build_defenses",
                    text: "Strengthen your political position defensively",
                    shortText: "Defend",
                    effects: ["standing": 3]
                ),
                EventResponse(
                    id: "seek_allies",
                    text: "Reach out to potential allies",
                    shortText: "Seek Allies",
                    effects: ["eliteLoyalty": 5]
                ),
                EventResponse(
                    id: "expose_plot",
                    text: "Bring the plot to your patron's attention",
                    shortText: "Expose",
                    effects: ["patronFavor": 5, "rivalThreat": -10]
                )
            ],
            iconName: "eye.trianglebadge.exclamationmark.fill",
            accentColor: "stampRed"
        )
    }

    // MARK: - Ally Events

    /// Generate an ally assistance event
    func generateAllyAssistance(ally: GameCharacter, game: Game) -> DynamicEvent {
        let assistance = [
            (
                title: "A Friend's Help",
                text: "\(ally.name) approaches you with valuable information.\n\n\"I thought you should know—there's been talk about reorganizing your department. I have some ideas that might help you position yourself favorably.\"",
                benefit: "information"
            ),
            (
                title: "Unexpected Support",
                text: "During a heated committee meeting, \(ally.name) speaks up in your defense.\n\n\"Comrade's record speaks for itself. I've worked with them closely, and I can vouch for their dedication.\"\n\nThe room's mood shifts noticeably.",
                benefit: "public_support"
            ),
            (
                title: "A Timely Warning",
                text: "\(ally.name) pulls you aside with concern in their eyes.\n\n\"Be careful around Deputy Minister Wallace tomorrow. I've heard he's been asking questions about your department's budget. I thought you should have time to prepare.\"",
                benefit: "warning"
            )
        ]

        let selected = assistance.randomElement()!

        eventLogger.info("Generated ally assistance from \(ally.name)")

        return DynamicEvent(
            eventType: .allyRequest,
            priority: .normal,
            title: selected.title,
            briefText: selected.text,
            initiatingCharacterId: ally.id,
            initiatingCharacterName: ally.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "thank_warmly",
                    text: "Thank them warmly and promise to return the favor",
                    shortText: "Thank Them",
                    effects: ["eliteLoyalty": 3]
                ),
                EventResponse(
                    id: "accept_coolly",
                    text: "Accept their help but maintain professional distance",
                    shortText: "Accept Coolly",
                    effects: [:]
                ),
                EventResponse(
                    id: "offer_reciprocity",
                    text: "Offer to help them with something in return",
                    shortText: "Reciprocate",
                    effects: ["standing": 2, "eliteLoyalty": 2]
                )
            ],
            iconName: "person.2.fill",
            accentColor: "accentGold"
        )
    }

    /// Generate an ally request event
    func generateAllyRequest(ally: GameCharacter, game: Game) -> DynamicEvent {
        let requests = [
            (
                title: "A Favor Asked",
                text: "\(ally.name) seeks you out with an unusual request.\n\n\"I need your support for my proposal in next week's committee meeting. It's a small thing, but it would mean a great deal to me.\"",
                cost: "political_capital"
            ),
            (
                title: "Help Needed",
                text: "\(ally.name) looks troubled when they approach you.\n\n\"My nephew is being considered for a junior position in your department. If you could put in a good word... I know it's a lot to ask.\"",
                cost: "small_favor"
            ),
            (
                title: "A Delicate Matter",
                text: "\(ally.name) speaks in hushed tones.\n\n\"There's an investigation looking into some... irregularities in my department's accounts. If you could vouch for my character when the inspectors come around...\"",
                cost: "risk"
            )
        ]

        let selected = requests.randomElement()!

        eventLogger.info("Generated ally request from \(ally.name)")

        return DynamicEvent(
            eventType: .allyRequest,
            priority: .normal,
            title: selected.title,
            briefText: selected.text,
            initiatingCharacterId: ally.id,
            initiatingCharacterName: ally.name,
            turnGenerated: game.turnNumber,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "agree",
                    text: "Agree to help without hesitation",
                    shortText: "Help",
                    effects: ["eliteLoyalty": 5, "standing": -2]
                ),
                EventResponse(
                    id: "negotiate",
                    text: "Agree but ask for something in return",
                    shortText: "Negotiate",
                    effects: ["eliteLoyalty": 2]
                ),
                EventResponse(
                    id: "decline_politely",
                    text: "Politely decline, citing other commitments",
                    shortText: "Decline",
                    effects: ["eliteLoyalty": -5]
                ),
                EventResponse(
                    id: "promise_later",
                    text: "Promise to help when the time is right",
                    shortText: "Defer",
                    effects: ["eliteLoyalty": -2]
                )
            ],
            iconName: "hand.raised.fill",
            accentColor: "inkGray"
        )
    }

    // MARK: - Political Events

    /// Generate a policy change notification
    func generatePolicyChangeEvent(
        characterName: String,
        policyName: String,
        wasDecree: Bool,
        passed: Bool,
        voteFor: Int?,
        voteAgainst: Int?,
        game: Game
    ) -> DynamicEvent {
        let title: String
        let text: String
        let priority: EventPriority

        if wasDecree {
            title = "General Secretary Decree"
            text = "\(characterName) has issued a decree changing \(policyName).\n\nThe Standing Committee was not consulted. This unprecedented move has sent ripples through the corridors of power."
            priority = .elevated
        } else if passed {
            title = "Policy Change Approved"
            text = "The Standing Committee has voted to change \(policyName).\n\nThe vote was \(voteFor ?? 0) in favor, \(voteAgainst ?? 0) against.\n\nProposed by: \(characterName)"
            priority = .normal
        } else {
            title = "Policy Proposal Rejected"
            text = "\(characterName)'s proposal to change \(policyName) was rejected by the Standing Committee.\n\nThe vote was \(voteFor ?? 0) in favor, \(voteAgainst ?? 0) against."
            priority = .background
        }

        return DynamicEvent(
            eventType: .worldNews,
            priority: priority,
            title: title,
            briefText: text,
            initiatingCharacterName: characterName,
            turnGenerated: game.turnNumber,
            isUrgent: wasDecree,
            responseOptions: [
                EventResponse(id: "note", text: "Note this development", shortText: "Note", effects: [:])
            ],
            iconName: "building.columns.fill",
            accentColor: wasDecree ? "stampRed" : "inkGray"
        )
    }

    // MARK: - Utility Methods

    /// Calculate if a patron event should trigger based on game state
    func shouldTriggerPatronEvent(game: Game, eventType: PatronEventType) -> Bool {
        guard let patron = game.patron, patron.isActive else { return false }

        let baseChance: Double
        let threshold: Int

        switch eventType {
        case .warning:
            baseChance = GameplayConstants.Patron.baseWarningChance
            threshold = GameplayConstants.Patron.lowFavorThreshold
            guard game.patronFavor < threshold else { return false }
            let modifier = Double(threshold - game.patronFavor) / 100.0
            return Double.random(in: 0...1) < (baseChance + modifier)

        case .opportunity:
            baseChance = GameplayConstants.Patron.baseOpportunityChance
            threshold = GameplayConstants.Patron.highFavorThreshold
            guard game.patronFavor > threshold else { return false }
            let modifier = Double(game.patronFavor - threshold) / 100.0
            return Double.random(in: 0...1) < (baseChance + modifier)

        case .directive:
            baseChance = 0.20
            guard game.stability < GameplayConstants.Stability.criticalThreshold else { return false }
            let modifier = Double(GameplayConstants.Stability.criticalThreshold - game.stability) / 100.0
            return Double.random(in: 0...1) < (baseChance + modifier)

        case .summons:
            baseChance = GameplayConstants.Patron.baseSummonsChance
            threshold = GameplayConstants.Patron.criticalFavorThreshold
            guard game.patronFavor < threshold else { return false }
            return Double.random(in: 0...1) < baseChance
        }
    }

    /// Calculate if a rival event should trigger
    func shouldTriggerRivalEvent(game: Game, eventType: RivalEventType) -> Bool {
        guard let rival = game.primaryRival, rival.isActive else { return false }

        let baseChance: Double

        switch eventType {
        case .confrontation:
            baseChance = GameplayConstants.Rival.baseConfrontationChance
            let modifier = Double(game.rivalThreat) / 200.0
            return Double.random(in: 0...1) < (baseChance + modifier)

        case .plot:
            baseChance = GameplayConstants.Rival.basePlotChance
            guard game.rivalThreat > GameplayConstants.Rival.highThreatThreshold else { return false }
            let modifier = Double(game.rivalThreat - GameplayConstants.Rival.highThreatThreshold) / 100.0
            return Double.random(in: 0...1) < (baseChance + modifier)
        }
    }
}

// MARK: - Event Type Enums

enum PatronEventType {
    case warning
    case opportunity
    case directive
    case summons
}

enum RivalEventType {
    case confrontation
    case plot
}
