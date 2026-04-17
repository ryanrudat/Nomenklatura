//
//  CodexService.swift
//  Nomenklatura
//
//  Service for managing Codex communication system - Event-Driven NPC-to-Player messaging
//

import Foundation
import SwiftData
import Combine

// MARK: - Codex Service

@MainActor
final class CodexService: ObservableObject {
    static let shared = CodexService()

    /// Current toast notification for new messages
    @Published var currentToast: CodexMessage?

    /// Whether a message is being generated
    @Published var isGenerating: Bool = false

    // MARK: - Pacing Rules

    private struct PacingRules {
        static let minimumTurnsBetweenPatronMessages = 2
        static let minimumTurnsBetweenRivalMessages = 3
        static let maximumMessagesPerTurn = 2
        static let decisionReactionDelay = 1
        static let periodicCheckInThreshold = 5  // Turns without contact
    }

    private init() {}

    // MARK: - Event-Driven Message Generation

    /// Main entry point - process all event-driven triggers for this turn
    func processEventDrivenMessages(game: Game, context: ModelContext) async {
        isGenerating = true
        defer { isGenerating = false }

        var messagesGenerated = 0

        // 1. Deliver any scheduled messages that are now due
        deliverScheduledMessages(game: game)

        // 2. Process relationship triggers (patron favor, rival threat thresholds)
        if messagesGenerated < PacingRules.maximumMessagesPerTurn {
            if let message = await processRelationshipTriggers(game: game, context: context) {
                messagesGenerated += 1
                deliverMessage(message, game: game, context: context)
            }
        }

        // 3. Process state threshold triggers (stability, network, etc.)
        if messagesGenerated < PacingRules.maximumMessagesPerTurn {
            if let message = await processStateThresholds(game: game, context: context) {
                messagesGenerated += 1
                deliverMessage(message, game: game, context: context)
            }
        }

        // 4. Process periodic check-ins (if no contact from patron in X turns)
        if messagesGenerated < PacingRules.maximumMessagesPerTurn {
            if let message = await processPeriodicCheckIns(game: game, context: context) {
                messagesGenerated += 1
                deliverMessage(message, game: game, context: context)
            }
        }
    }

    /// Queue a message to be delivered after a delay (for decision reactions)
    func scheduleDecisionReaction(
        character: GameCharacter,
        decision: DeskDocument,
        option: DocumentOption,
        delay: Int,
        game: Game,
        context: ModelContext
    ) {
        let deliveryTurn = game.turnNumber + delay

        // Determine if character is pleased or displeased
        let isPositive = characterApprovesDecision(character: character, option: option, game: game)

        let (content, messageType) = generateDecisionReactionContent(
            character: character,
            decision: decision,
            option: option,
            isPositive: isPositive,
            game: game
        )

        let message = CodexMessage(
            senderId: character.templateId,
            senderName: character.name,
            senderTitle: character.title,
            messageType: messageType,
            priority: isPositive ? .routine : .urgent,
            subject: "Regarding \(decision.title)",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: !isPositive,  // Negative reactions often need response
            responseOptions: getDecisionReactionOptions(isPositive: isPositive, character: character),
            triggerType: .decisionReaction,
            triggerSourceId: decision.id.uuidString,
            triggerContext: "Reaction to: \(option.text)",
            scheduledDeliveryTurn: deliveryTurn
        )

        context.insert(message)
        message.game = game
        game.codexMessages.append(message)
    }

    /// Queue a consequence reaction message
    func queueConsequenceReaction(
        consequenceType: String,
        consequenceDescription: String,
        characterId: String,
        game: Game,
        context: ModelContext
    ) {
        guard let character = game.characters.first(where: { $0.templateId == characterId }) else { return }

        let content = generateConsequenceReactionContent(
            character: character,
            consequenceType: consequenceType,
            consequenceDescription: consequenceDescription,
            game: game
        )

        let message = CodexMessage(
            senderId: character.templateId,
            senderName: character.name,
            senderTitle: character.title,
            messageType: .warning,
            priority: .urgent,
            subject: "Developments You Should Know",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: true,
            responseOptions: getConsequenceReactionOptions(character: character),
            triggerType: .consequence,
            triggerSourceId: consequenceType,
            triggerContext: consequenceDescription
        )

        deliverMessage(message, game: game, context: context)
    }

    // MARK: - Relationship Triggers

    private func processRelationshipTriggers(game: Game, context: ModelContext) async -> CodexMessage? {
        // Check patron favor thresholds
        if let patron = game.patron {
            let lastPatronTurn = getLastMessageTurn(from: patron.templateId, game: game)
            let turnsSincePatron = game.turnNumber - lastPatronTurn

            if turnsSincePatron >= PacingRules.minimumTurnsBetweenPatronMessages {
                // Low patron favor - warning
                if game.patronFavor < 35 {
                    return await generatePatronWarning(patron: patron, game: game)
                }
                // High patron favor - opportunity
                if game.patronFavor > 75 {
                    return await generatePatronOpportunity(patron: patron, game: game)
                }
            }
        }

        // Check rival threat thresholds
        if let rival = game.primaryRival {
            let lastRivalTurn = getLastMessageTurn(from: rival.templateId, game: game)
            let turnsSinceRival = game.turnNumber - lastRivalTurn

            if turnsSinceRival >= PacingRules.minimumTurnsBetweenRivalMessages {
                // High rival threat - veiled threat
                if game.rivalThreat > 60 {
                    return await generateRivalThreat(rival: rival, game: game)
                }
            }
        }

        // Check ally disposition changes (allies are characters with high disposition who aren't patron/rival)
        for character in game.characters where !character.isPatron && !character.isRival && character.isAlive {
            // If disposition recently dropped below 50, generate concerned message
            if character.disposition < 50 && character.disposition > 30 {
                let lastAllyTurn = getLastMessageTurn(from: character.templateId, game: game)
                if game.turnNumber - lastAllyTurn >= 3 {
                    return await generateAllyConcern(ally: character, game: game)
                }
            }
        }

        return nil
    }

    // MARK: - State Threshold Triggers

    private func processStateThresholds(game: Game, context: ModelContext) async -> CodexMessage? {
        // Stability crisis - patron demands action
        if game.stability < 30 {
            if let patron = game.patron {
                let lastPatronTurn = getLastMessageTurn(from: patron.templateId, game: game)
                if game.turnNumber - lastPatronTurn >= 2 {
                    return await generateStabilityCrisisMessage(patron: patron, game: game)
                }
            }
        }

        // Network milestone - new contact reaches out
        let networkMilestones = [25, 50, 75]
        for milestone in networkMilestones {
            if game.network >= milestone && game.network < milestone + 5 {
                // Just crossed this threshold
                if !game.flags.contains("network_milestone_\(milestone)") {
                    game.flags.append("network_milestone_\(milestone)")
                    return await generateNetworkContactMessage(milestone: milestone, game: game)
                }
            }
        }

        return nil
    }

    // MARK: - Periodic Check-Ins

    private func processPeriodicCheckIns(game: Game, context: ModelContext) async -> CodexMessage? {
        guard let patron = game.patron else { return nil }

        let lastPatronTurn = getLastMessageTurn(from: patron.templateId, game: game)
        let turnsSinceContact = game.turnNumber - lastPatronTurn

        if turnsSinceContact >= PacingRules.periodicCheckInThreshold {
            return await generatePeriodicCheckIn(patron: patron, turnsSince: turnsSinceContact, game: game)
        }

        return nil
    }

    // MARK: - Message Delivery

    private func deliverMessage(_ message: CodexMessage, game: Game, context: ModelContext) {
        context.insert(message)
        message.game = game
        message.isDelivered = true
        game.codexMessages.append(message)

        // Show toast
        currentToast = message

        // Add notification for badge
        NotificationService.shared.notify(
            .newCodexMessage,
            title: "New Message",
            detail: "From \(message.senderName)",
            turn: game.turnNumber
        )
    }

    private func deliverScheduledMessages(game: Game) {
        for message in game.codexMessages {
            if message.isReadyForDelivery {
                message.isDelivered = true
                message.timestamp = Date()  // Update timestamp to delivery time
                currentToast = message

                // Add notification for badge
                NotificationService.shared.notify(
                    .newCodexMessage,
                    title: "New Message",
                    detail: "From \(message.senderName)",
                    turn: game.turnNumber
                )
            }
        }
    }

    // MARK: - Message Content Generation

    private func generatePatronWarning(patron: GameCharacter, game: Game) async -> CodexMessage {
        let content = selectTemplate(from: [
            "Comrade, I have noticed a certain... cooling in our relationship. I hope this is not due to any misunderstanding on your part about where your loyalties should lie.",
            "Your recent performance has been noted - and not always favorably. I had expected more from someone in whom I invested considerable political capital.",
            "There are whispers that you have forgotten who helped you reach your current position. I trust these rumors are unfounded.",
            "I am beginning to question whether my faith in you was misplaced. Prove me wrong."
        ])

        return CodexMessage(
            senderId: patron.templateId,
            senderName: patron.name,
            senderTitle: patron.title,
            messageType: .warning,
            priority: .urgent,
            subject: "A Matter of Concern",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: true,
            responseOptions: [
                CodexResponseOption(text: "I remain your loyal supporter. How may I demonstrate this?", archetype: "respectful", consequences: "May require a favor"),
                CodexResponseOption(text: "I have been occupied with pressing duties, but I have not forgotten my obligations.", archetype: "cooperative"),
                CodexResponseOption(text: "My record speaks for itself. Judge me by my actions.", archetype: "assertive", consequences: "May increase tension")
            ],
            triggerType: .relationship,
            triggerContext: "Patron favor dropped below 35"
        )
    }

    private func generatePatronOpportunity(patron: GameCharacter, game: Game) async -> CodexMessage {
        let content = selectTemplate(from: [
            "Your work has not gone unnoticed. There may be opportunities on the horizon for those who have proven their worth.",
            "I have been speaking favorably of you in certain circles. Continue on your present course.",
            "The Standing Committee will be discussing personnel matters soon. Your name may come up - in a positive context."
        ])

        return CodexMessage(
            senderId: patron.templateId,
            senderName: patron.name,
            senderTitle: patron.title,
            messageType: .social,
            priority: .routine,
            subject: "A Word of Encouragement",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: false,
            triggerType: .relationship,
            triggerContext: "Patron favor exceeded 75"
        )
    }

    private func generateRivalThreat(rival: GameCharacter, game: Game) async -> CodexMessage {
        let content = selectTemplate(from: [
            "I hear you've been busy. Making friends in high places, perhaps? Enjoy it while it lasts.",
            "Interesting times ahead, wouldn't you say? I wonder how history will remember this period.",
            "Some colleagues have been asking questions about your department. I thought you should know that certain... irregularities have been noticed.",
            "You seem confident lately. That can be dangerous in our line of work."
        ])

        return CodexMessage(
            senderId: rival.templateId,
            senderName: rival.name,
            senderTitle: rival.title,
            messageType: .warning,
            priority: .urgent,
            subject: "Professional Observations",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: true,
            responseOptions: [
                CodexResponseOption(text: "I appreciate your concern for my well-being. Rest assured, I am quite secure.", archetype: "assertive"),
                CodexResponseOption(text: "Perhaps we should discuss this in person. Tea sometime?", archetype: "cooperative", consequences: "May defuse or trap"),
                CodexResponseOption(text: "Noted.", archetype: "evasive")
            ],
            triggerType: .relationship,
            triggerContext: "Rival threat exceeded 60"
        )
    }

    private func generateAllyConcern(ally: GameCharacter, game: Game) async -> CodexMessage {
        let content = selectTemplate(from: [
            "Comrade, I must confess some concern about recent developments. Have we drifted apart, or is it my imagination?",
            "I had hoped our alliance would prove more... mutually beneficial. Perhaps we should reconsider our arrangement.",
            "There was a time when we could rely on each other. I wonder if that time has passed."
        ])

        return CodexMessage(
            senderId: ally.templateId,
            senderName: ally.name,
            senderTitle: ally.title,
            messageType: .social,
            priority: .routine,
            subject: "Between Colleagues",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: true,
            responseOptions: [
                CodexResponseOption(text: "Our alliance remains important to me. Let us work to strengthen it.", archetype: "cooperative"),
                CodexResponseOption(text: "I have been preoccupied with other matters. We should meet soon.", archetype: "respectful"),
                CodexResponseOption(text: "Circumstances change. We must each look to our own interests.", archetype: "assertive", consequences: "May damage relationship")
            ],
            triggerType: .relationship,
            triggerContext: "Ally disposition dropped below 50"
        )
    }

    private func generateStabilityCrisisMessage(patron: GameCharacter, game: Game) async -> CodexMessage {
        let content = selectTemplate(from: [
            "The situation is becoming untenable. The Party demands action - decisive action. What is your plan?",
            "Reports from the regions are alarming. If we do not restore order soon, heads will roll. Starting with those closest to the problem.",
            "The General Secretary is watching. He is not pleased. You must demonstrate that you have the situation under control."
        ])

        return CodexMessage(
            senderId: patron.templateId,
            senderName: patron.name,
            senderTitle: patron.title,
            messageType: .directive,
            priority: .critical,
            subject: "URGENT: The Stability Crisis",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: true,
            responseOptions: [
                CodexResponseOption(text: "I am implementing emergency measures. The situation will improve.", archetype: "assertive"),
                CodexResponseOption(text: "I need additional resources and authority to address this crisis.", archetype: "cooperative", consequences: "May gain or owe"),
                CodexResponseOption(text: "The causes of this instability lie outside my jurisdiction.", archetype: "evasive", consequences: "May anger patron")
            ],
            triggerType: .stateThreshold,
            triggerContext: "Stability dropped below 30"
        )
    }

    private func generateNetworkContactMessage(milestone: Int, game: Game) async -> CodexMessage {
        let contactName = ["Mikhail Petrov", "Anna Volkonsky", "Dmitri Orlov", "Elena Kozlova"].randomElement() ?? "Mikhail Petrov"
        let contactTitle = ["Economic Planning Aide", "Party Records Clerk", "Regional Liaison", "Cultural Affairs Deputy"].randomElement() ?? "Party Aide"

        let content = selectTemplate(from: [
            "A mutual acquaintance suggested we might find common ground. In these uncertain times, it helps to know who one's friends are.",
            "I have heard much about you through the proper channels. Perhaps we might be of service to one another.",
            "Word travels in the corridors of power. Your name has been mentioned favorably. I thought it prudent to introduce myself."
        ])

        return CodexMessage(
            senderId: contactName.lowercased().replacingOccurrences(of: " ", with: "_"),
            senderName: contactName,
            senderTitle: contactTitle,
            messageType: .social,
            priority: .low,
            subject: "An Introduction",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: true,
            responseOptions: [
                CodexResponseOption(text: "I am always pleased to make new acquaintances. Let us stay in touch.", archetype: "cooperative"),
                CodexResponseOption(text: "I appreciate the introduction. We shall see if an arrangement proves mutually beneficial.", archetype: "cautious"),
                CodexResponseOption(text: "My schedule is quite full at present.", archetype: "evasive")
            ],
            triggerType: .stateThreshold,
            triggerContext: "Network reached \(milestone)"
        )
    }

    private func generatePeriodicCheckIn(patron: GameCharacter, turnsSince: Int, game: Game) async -> CodexMessage {
        let content = selectTemplate(from: [
            "It has been some time since we last spoke. I trust all is well with your work?",
            "I realized I had not heard from you in a while. In our world, silence can be concerning.",
            "How goes your work, Comrade? The Party expects regular updates from those entrusted with responsibility."
        ])

        return CodexMessage(
            senderId: patron.templateId,
            senderName: patron.name,
            senderTitle: patron.title,
            messageType: .social,
            priority: .routine,
            subject: "Checking In",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: false,
            triggerType: .periodic,
            triggerContext: "\(turnsSince) turns since last patron contact"
        )
    }

    // MARK: - Decision Reaction Content

    private func characterApprovesDecision(character: GameCharacter, option: DocumentOption, game: Game) -> Bool {
        // Determine approval based on option effects and character personality

        // Calculate net effect of the option
        let netEffect = option.effects.values.reduce(0, +)

        // Characters with high ruthlessness prefer harsh/negative options
        if character.personalityRuthless > 60 {
            // Ruthless characters approve of options that reduce stability (harsh measures)
            if let stabilityEffect = option.effects["stability"], stabilityEffect < 0 {
                return true
            }
        }

        // Characters with high competence prefer effective options (positive net effects)
        if character.personalityCompetent > 60 {
            return netEffect > 0
        }

        // Paranoid characters approve of security-focused decisions
        if character.personalityParanoid > 60 {
            // Check for flags that suggest security actions
            if let flag = option.setsFlag, flag.contains("arrest") || flag.contains("investigate") || flag.contains("surveillance") {
                return true
            }
        }

        // Default: base on disposition (friendly characters more forgiving)
        if character.disposition > 60 {
            return Double.random(in: 0...1) > 0.3  // 70% approval
        } else if character.disposition < 40 {
            return Double.random(in: 0...1) > 0.7  // 30% approval
        }

        // Neutral: 50/50
        return Bool.random()
    }

    private func generateDecisionReactionContent(
        character: GameCharacter,
        decision: DeskDocument,
        option: DocumentOption,
        isPositive: Bool,
        game: Game
    ) -> (String, CodexMessageType) {
        let isPatron = character.isPatron
        let isRival = character.isRival
        let category = decision.categoryEnum

        if isPositive {
            // Positive reactions based on relationship and category
            if isPatron {
                let content = selectCategoryTemplate(category: category, templates: [
                    .security: [
                        "Your handling of that security matter was exemplary. The Party appreciates vigilance.",
                        "I was pleased to see you take a firm hand with that situation. Security must always be our priority."
                    ],
                    .political: [
                        "A politically astute decision. You are learning how the game is played.",
                        "Your political instincts are developing well. That decision will be remembered favorably."
                    ],
                    .economic: [
                        "Sound economic judgment. The Five Year Plan depends on officials who understand resource allocation.",
                        "Your economic decision was pragmatic and effective. Well done."
                    ],
                    .military: [
                        "The military appreciated your support. They have long memories for both friends and enemies.",
                        "A strong decision regarding the military matter. The generals will remember this."
                    ],
                    .diplomatic: [
                        "Your diplomatic touch was noted. International relations require finesse, and you showed it.",
                        "A wise approach to the diplomatic matter. We must be subtle in our dealings with foreign powers."
                    ],
                    .crisis: [
                        "You kept your head in a crisis. That is exactly what we need in our leadership.",
                        "Your crisis management was impressive. I knew I was right to support your advancement."
                    ]
                ], fallback: "Your handling of the \(decision.title.lowercased()) matter was commendable. Well done.")
                return (content, .social)
            } else if isRival {
                // Rival grudgingly acknowledging (rare - they prefer to criticize)
                let content = "I see you made a decision regarding \(decision.title.lowercased()). It was... not entirely wrong. This time."
                return (content, .social)
            } else {
                let content = selectTemplate(from: [
                    "I was pleased to hear how you handled the matter of \(decision.title.lowercased()). A wise decision.",
                    "Your recent decision shows good judgment. The Party needs officials who can think clearly.",
                    "Word has reached me of your handling of that situation. Well done, Comrade."
                ])
                return (content, .social)
            }
        } else {
            // Negative reactions based on relationship and category
            if isPatron {
                let content = selectCategoryTemplate(category: category, templates: [
                    .security: [
                        "Your decision on that security matter concerns me. The Party expects vigilance, not leniency.",
                        "I had hoped for a stronger response to the security situation. Some will see this as weakness."
                    ],
                    .political: [
                        "That was a political miscalculation. You have made enemies who will not forget.",
                        "Your political judgment in that matter was... questionable. We should discuss this privately."
                    ],
                    .economic: [
                        "The economic decision you made will have consequences. The planning committees are not pleased.",
                        "I must question your economic priorities. Resources are scarce, and waste is not tolerated."
                    ],
                    .military: [
                        "The military expected your support. They did not receive it. This creates... complications.",
                        "Your decision regarding the military matter has not been well received in certain circles."
                    ],
                    .diplomatic: [
                        "Your handling of the diplomatic matter was clumsy. We must be more careful with foreign relations.",
                        "International affairs require subtlety. Your recent decision lacked it."
                    ],
                    .crisis: [
                        "In a crisis, leadership matters. Your handling of that situation left much to be desired.",
                        "When emergencies arise, we expect decisive action. Your response was... inadequate."
                    ]
                ], fallback: "I must express my concern about your decision regarding \(decision.title.lowercased()). Was this truly wise?")
                return (content, .warning)
            } else if isRival {
                let content = selectTemplate(from: [
                    "Your decision on \(decision.title.lowercased()) was noted. By everyone. Including those who matter.",
                    "An interesting choice you made there. Some might call it a mistake. I couldn't possibly comment.",
                    "I heard about your recent decision. It's good to know that not everyone can handle the pressure.",
                    "People are talking about how you handled that matter. Not favorably, I'm afraid."
                ])
                return (content, .warning)
            } else {
                let content = selectTemplate(from: [
                    "I must express my concern about your decision regarding \(decision.title.lowercased()). Was this truly wise?",
                    "Your recent choice has raised eyebrows in certain circles. I hope you have considered the implications.",
                    "I had expected a different approach from you, Comrade. Perhaps we should discuss this."
                ])
                return (content, .warning)
            }
        }
    }

    private func selectCategoryTemplate(
        category: DocumentCategory,
        templates: [DocumentCategory: [String]],
        fallback: String
    ) -> String {
        if let categoryTemplates = templates[category], !categoryTemplates.isEmpty {
            return categoryTemplates.randomElement() ?? fallback
        }
        return fallback
    }

    private func getDecisionReactionOptions(isPositive: Bool, character: GameCharacter) -> [CodexResponseOption]? {
        if isPositive {
            // Even positive reactions can have a brief acknowledgment
            if character.isPatron {
                return [
                    CodexResponseOption(text: "I am grateful for your guidance. It has shaped my judgment.", archetype: "respectful"),
                    CodexResponseOption(text: "I aim only to serve the Party and those who believe in me.", archetype: "cooperative")
                ]
            }
            return nil
        }

        if character.isPatron {
            return [
                CodexResponseOption(text: "I value your counsel and will reconsider my approach.", archetype: "respectful", consequences: "May regain some favor"),
                CodexResponseOption(text: "The circumstances required a difficult choice. I stand by my decision.", archetype: "assertive", consequences: "May test relationship"),
                CodexResponseOption(text: "How would you have handled it? I wish to learn from your experience.", archetype: "cooperative", consequences: "May owe a favor")
            ]
        } else if character.isRival {
            return [
                CodexResponseOption(text: "Your opinion is noted. I'm sure you have your own affairs to attend to.", archetype: "assertive"),
                CodexResponseOption(text: "We each make the decisions we must. I wonder how yours will be judged.", archetype: "defiant", consequences: "Escalates conflict"),
                CodexResponseOption(text: "Perhaps you would have done differently. We shall see whose approach proves wiser.", archetype: "evasive")
            ]
        } else {
            return [
                CodexResponseOption(text: "I appreciate your perspective and will take it under advisement.", archetype: "respectful"),
                CodexResponseOption(text: "The decision was made with full consideration of the consequences.", archetype: "assertive"),
                CodexResponseOption(text: "Perhaps you are right to be concerned. How would you have handled it?", archetype: "cooperative")
            ]
        }
    }

    // MARK: - Consequence Reaction Content

    private func generateConsequenceReactionContent(
        character: GameCharacter,
        consequenceType: String,
        consequenceDescription: String,
        game: Game
    ) -> String {
        // Generate contextual content based on consequence type and character relationship
        let isPatron = character.isPatron
        let isRival = character.isRival

        switch consequenceType {
        case "eliteBacklash":
            if isPatron {
                return selectTemplate(from: [
                    "I am hearing troubling whispers from the Central Committee. Your recent... initiatives have not been received well in all quarters. You should know that I have been defending you, but my patience is not unlimited.",
                    "The senior membership is restless. They speak of 'reckless reformism' and 'dangerous precedents.' You must be more careful, or I may not be able to protect you.",
                    "Certain colleagues have approached me expressing concern about the direction you are taking. I deflected them, but you are accumulating enemies. Tread carefully."
                ])
            } else if isRival {
                return selectTemplate(from: [
                    "I understand the Central Committee has taken notice of your work. Not in a favorable way, I'm told. How unfortunate.",
                    "People are talking about you. Not the good kind of talking. I thought you should know - as a professional courtesy, of course.",
                    "It seems your grand plans have not impressed everyone. The old guard, in particular, seems... displeased. What a shame."
                ])
            } else {
                return selectTemplate(from: [
                    "Comrade, I thought you should hear this from a friend. There is grumbling among the senior officials about recent changes. Some feel things are moving too fast.",
                    "The mood in the upper echelons has shifted. Your name comes up in conversations, and not always approvingly. Be on your guard."
                ])
            }

        case "coalitionForms":
            if isPatron {
                return selectTemplate(from: [
                    "There are those who meet in private, discussing 'alternatives.' I have my sources. This coalition is still forming, but you should take it seriously.",
                    "A shadow group is coalescing around opposition to your policies. They are being careful, but I know who some of them are. We must discuss this.",
                    "I have learned that certain officials have been holding private meetings. They are not plotting your downfall - yet. But they are preparing for it."
                ])
            } else if isRival {
                return selectTemplate(from: [
                    "I hear you've made some new friends recently. Or should I say, some old friends have found each other? The Party always has room for... dialogue.",
                    "Interesting times, wouldn't you say? When like-minded people begin to find each other, change often follows. I do enjoy watching history unfold.",
                    "There is a certain energy in the corridors lately. A sense that things might be about to shift. Have you noticed?"
                ])
            } else {
                return selectTemplate(from: [
                    "I feel I should warn you: some of our colleagues have been meeting privately. They share concerns about the current direction. You should know who your friends are.",
                    "Factions are forming, as they always do when change is in the air. I thought you should be aware, in case you need to choose a side."
                ])
            }

        case "popularUnrest":
            if isPatron {
                return selectTemplate(from: [
                    "The reports from the regions are concerning. The people are restless, and discontent is spreading. The Party demands order - you must restore it.",
                    "Have you seen the latest reports? Factory slowdowns, petitions, even some protests. This cannot continue. What are you doing about it?",
                    "The masses are becoming ungovernable. If we cannot maintain order, others will step in to do it for us. Act decisively, before it's too late."
                ])
            } else {
                return selectTemplate(from: [
                    "The workers are growing restless. I have heard talk of petitions, work slowdowns, even whispers of strikes. This bears watching.",
                    "Something is stirring among the people. The usual grumbling has taken on a sharper edge lately. Be careful - unrest can spread quickly."
                ])
            }

        case "internationalPressure":
            return selectTemplate(from: [
                "The foreign press has taken notice of recent developments. Their criticism, while predictable, provides ammunition to our internal enemies. Be aware.",
                "International observers are asking uncomfortable questions. This puts pressure on the leadership to appear... responsive. You may be asked to justify certain decisions.",
                "Our friends abroad are concerned. The capitalist press is one thing, but when socialist allies begin to question us... that is more serious."
            ])

        case "militaryUnrest":
            if isPatron {
                return selectTemplate(from: [
                    "The generals are nervous. They sense instability, and the military never likes uncertainty about the succession. You must reassure them - or neutralize them.",
                    "I have contacts in the military who tell me there is... discussion among the officer corps. Nothing organized yet, but the army has historically been kingmaker in times of crisis.",
                    "The Defense Minister has been unusually quiet lately. That is never a good sign. The military is watching and waiting."
                ])
            } else {
                return selectTemplate(from: [
                    "I hear the generals are restless. When the military starts talking amongst themselves, civilians should pay attention.",
                    "There is tension in the barracks. The officers are uncertain about the future, and uncertain soldiers can be dangerous."
                ])
            }

        case "factionRebellion":
            return selectTemplate(from: [
                "A faction that once supported you is now expressing open dissatisfaction. Their cooperation can no longer be assumed.",
                "You have lost the trust of important supporters. They feel betrayed by recent decisions and are making their displeasure known.",
                "Word has reached me that a key faction is reconsidering its alliance with you. Bridges have been burned that may be difficult to rebuild."
            ])

        case "characterAction":
            if isRival {
                return selectTemplate(from: [
                    "I have been busy lately. Making arrangements, meeting with old friends. Nothing you need to concern yourself with, of course.",
                    "Change is coming, Comrade. Those of us who can read the signs are positioning ourselves accordingly. I suggest you do the same.",
                    "I thought you might like to know: you are not the only one building a network. Some of us have been at this game longer than you."
                ])
            } else {
                return selectTemplate(from: [
                    "Something is happening behind the scenes. People are making moves, forming alliances. I thought you should be aware.",
                    "The political landscape is shifting. Old alliances are being tested, new ones formed. Stay alert."
                ])
            }

        default:
            return selectTemplate(from: [
                "Recent developments require your attention. \(consequenceDescription)",
                "I thought you should know about certain matters. \(consequenceDescription). This will have implications.",
                "Word has reached me of developments you should be aware of. \(consequenceDescription)"
            ])
        }
    }

    private func getConsequenceReactionOptions(character: GameCharacter) -> [CodexResponseOption] {
        if character.isPatron {
            return [
                CodexResponseOption(text: "Thank you for the warning. I will take immediate action to address this.", archetype: "cooperative", consequences: "Patron expects results"),
                CodexResponseOption(text: "I am already aware and have the situation under control.", archetype: "assertive"),
                CodexResponseOption(text: "What would you advise? I value your guidance.", archetype: "respectful", consequences: "May increase dependence")
            ]
        } else if character.isRival {
            return [
                CodexResponseOption(text: "Your concern is noted. I suggest you focus on your own affairs.", archetype: "assertive"),
                CodexResponseOption(text: "Interesting information. Thank you for sharing.", archetype: "evasive"),
                CodexResponseOption(text: "Perhaps we should discuss this in person.", archetype: "cautious", consequences: "May be a trap")
            ]
        } else {
            return [
                CodexResponseOption(text: "Thank you for the warning. I am taking appropriate measures.", archetype: "cooperative"),
                CodexResponseOption(text: "I appreciate you bringing this to my attention.", archetype: "respectful"),
                CodexResponseOption(text: "I will handle it. Thank you for your discretion.", archetype: "assertive")
            ]
        }
    }

    // MARK: - Player Response Handling

    /// Record player's response to a message with optional custom text
    func respondToMessage(
        _ message: CodexMessage,
        optionId: String,
        customText: String?,
        game: Game,
        context: ModelContext
    ) {
        // Validate custom text if provided
        if let text = customText {
            let validation = TypedResponseValidator.validate(text)
            if validation != .valid && validation != .empty {
                // Invalid text - just ignore it and proceed with boilerplate
                message.playerCustomText = nil
            } else {
                message.playerCustomText = text
            }
        }

        message.playerResponseId = optionId
        message.isRead = true

        // Find the selected option
        guard let option = message.responseOptions.first(where: { $0.id == optionId }) else { return }

        // Get archetype
        guard let archetype = CodexResponseArchetype(rawValue: option.archetype) else { return }

        // Find sender character
        let senderCharacter = game.characters.first(where: { $0.templateId == message.senderId })

        // Calculate and apply effects
        let effects = CodexResponseEffects.calculate(
            archetype: archetype,
            senderIsPatron: senderCharacter?.isPatron ?? false,
            senderIsRival: senderCharacter?.isRival ?? false
        )

        applyResponseEffects(effects, sender: senderCharacter, game: game)
        message.responseEffectsApplied = true

        // Create player's response message in the thread
        let responseMessage = CodexMessage(
            senderId: "player",
            senderName: "You",
            senderTitle: game.currentPositionName,
            recipientId: message.senderId,
            messageType: .response,
            priority: .routine,
            subject: "Re: \(message.subject ?? "Your Message")",
            content: customText ?? option.text,
            turnNumber: game.turnNumber,
            threadId: message.threadId,
            parentMessageId: message.id,
            triggerType: .playerInitiated
        )

        context.insert(responseMessage)
        responseMessage.game = game
        game.codexMessages.append(responseMessage)

        // Schedule follow-up if needed
        if effects.schedulesFollowUp, let sender = senderCharacter {
            scheduleFollowUpMessage(
                from: sender,
                delay: effects.followUpDelay,
                archetype: archetype,
                game: game,
                context: context
            )
        }

        // Set any flags
        if let flag = effects.setsFlag {
            if !game.flags.contains(flag) {
                game.flags.append(flag)
            }
        }
    }

    private func applyResponseEffects(_ effects: CodexResponseEffects, sender: GameCharacter?, game: Game) {
        // Apply disposition change
        if let sender = sender, effects.dispositionChange != 0 {
            sender.disposition = max(0, min(100, sender.disposition + effects.dispositionChange))
        }

        // Apply patron favor change
        if effects.patronFavorChange != 0 {
            game.applyStat("patronFavor", change: effects.patronFavorChange)
        }

        // Apply rival threat change
        if effects.rivalThreatChange != 0 {
            game.applyStat("rivalThreat", change: effects.rivalThreatChange)
        }
    }

    private func scheduleFollowUpMessage(
        from sender: GameCharacter,
        delay: Int,
        archetype: CodexResponseArchetype,
        game: Game,
        context: ModelContext
    ) {
        let content: String
        let messageType: CodexMessageType
        let priority: CodexMessagePriority

        switch archetype {
        case .defiant:
            content = "I have given thought to your recent... assertiveness. We may need to have a more direct conversation."
            messageType = .summons
            priority = .urgent
        case .cooperative:
            content = "I appreciate your willingness to work together. There may be an opportunity for you to demonstrate this cooperation."
            messageType = .request
            priority = .routine
        default:
            content = "Our previous exchange left some matters unresolved. Let us speak again soon."
            messageType = .social
            priority = .low
        }

        let followUp = CodexMessage(
            senderId: sender.templateId,
            senderName: sender.name,
            senderTitle: sender.title,
            messageType: messageType,
            priority: priority,
            subject: "Following Up",
            content: content,
            turnNumber: game.turnNumber,
            requiresResponse: archetype == .defiant,
            responseOptions: archetype == .defiant ? [
                CodexResponseOption(text: "Of course. I am at your disposal.", archetype: "respectful"),
                CodexResponseOption(text: "I stand by my previous position.", archetype: "defiant", consequences: "May escalate"),
                CodexResponseOption(text: "Let us find common ground.", archetype: "cooperative")
            ] : nil,
            triggerType: .relationship,
            triggerContext: "Follow-up to \(archetype.rawValue) response",
            scheduledDeliveryTurn: game.turnNumber + delay
        )

        context.insert(followUp)
        followUp.game = game
        game.codexMessages.append(followUp)
    }

    // MARK: - Helper Methods

    private func getLastMessageTurn(from senderId: String, game: Game) -> Int {
        let senderMessages = game.codexMessages
            .filter { $0.senderId == senderId && $0.isDelivered }
            .sorted { $0.turnNumber > $1.turnNumber }

        return senderMessages.first?.turnNumber ?? 0
    }

    private func selectTemplate(from templates: [String]) -> String {
        templates.randomElement() ?? templates[0]
    }

    // MARK: - Message Management

    /// Mark a message as read
    func markAsRead(_ message: CodexMessage) {
        message.isRead = true
    }

    /// Archive a message
    func archiveMessage(_ message: CodexMessage) {
        message.isArchived = true
    }

    /// Dismiss current toast
    func dismissToast() {
        currentToast = nil
    }

    // MARK: - Legacy Support (for backward compatibility during transition)

    /// Generate messages for this turn - legacy method that now calls event-driven system
    func generateMessagesForTurn(game: Game, context: ModelContext) async {
        await processEventDrivenMessages(game: game, context: context)
    }

    /// Legacy respond method - now delegates to new system
    func respondToMessage(_ message: CodexMessage, with optionId: String, game: Game, context: ModelContext) {
        respondToMessage(message, optionId: optionId, customText: nil, game: game, context: context)
    }
}
