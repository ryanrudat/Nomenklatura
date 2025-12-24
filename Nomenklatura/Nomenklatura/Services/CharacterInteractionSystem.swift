//
//  CharacterInteractionSystem.swift
//  Nomenklatura
//
//  System for direct character interactions based on rank and relationship
//

import Foundation

// MARK: - Character Interaction System

class CharacterInteractionSystem {
    static let shared = CharacterInteractionSystem()

    /// Get available interactions for a character based on game state
    func getAvailableInteractions(for character: GameCharacter, game: Game) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Leader powers (position 5+ = Deputy General Secretary or higher)
        if game.currentPositionIndex >= 5 {
            interactions.append(contentsOf: getLeaderPowers(character: character, game: game))
        }

        // Patron-specific interactions
        if character.isPatron {
            interactions.append(contentsOf: getPatronInteractions(character: character, game: game))
        }

        // Rival-specific interactions
        if character.isRival {
            interactions.append(contentsOf: getRivalInteractions(character: character, game: game))
        }

        // Ally/neutral interactions
        if !character.isPatron && !character.isRival {
            interactions.append(contentsOf: getAllyInteractions(character: character, game: game))
        }

        // Network contact interactions
        if character.currentRole == .informant || character.templateId.hasPrefix("contact_") {
            interactions.append(contentsOf: getContactInteractions(character: character, game: game))
        }

        // Filter by rank requirements
        return interactions.filter { interaction in
            if let minRank = interaction.minPositionIndex, game.currentPositionIndex < minRank {
                return false
            }
            if let maxRank = interaction.maxPositionIndex, game.currentPositionIndex > maxRank {
                return false
            }
            return true
        }
    }

    // MARK: - Patron Interactions

    private func getPatronInteractions(character: GameCharacter, game: Game) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Request Audience (always available with patron)
        interactions.append(CharacterInteraction(
            id: "request_audience_patron",
            title: "Request Private Audience",
            description: "Seek a one-on-one meeting with your patron",
            category: .diplomatic,
            riskLevel: .low,
            costAP: 1,
            effects: ["patronFavor": Int.random(in: -3...5)],
            successNarratives: [
                "\(character.name) grants you a brief meeting. 'What is it, Comrade?'",
                "Your patron receives you in his office. The conversation is... productive.",
                "\(character.name) listens to your concerns with apparent interest."
            ],
            failureNarratives: [
                "\(character.name) is too busy to see you today. Perhaps tomorrow.",
                "The secretary informs you that your patron's schedule is full."
            ],
            flavorText: "A chance to strengthen—or damage—your relationship."
        ))

        // Seek Guidance (builds favor, low risk)
        interactions.append(CharacterInteraction(
            id: "seek_guidance_patron",
            title: "Seek Guidance",
            description: "Ask your patron for advice on a political matter",
            category: .diplomatic,
            riskLevel: .low,
            costAP: 1,
            effects: ["patronFavor": 3, "reputationLoyal": 2],
            successNarratives: [
                "\(character.name) appreciates being consulted. 'You show wisdom in asking.'",
                "Your patron offers cryptic advice. Reading between the lines is your task.",
                "'The answer,' \(character.name) says, 'is obvious to those who are loyal.'"
            ],
            flavorText: "Flattery disguised as humility. The oldest trick in the book."
        ))

        // Warn of Threats (higher risk, higher reward)
        if game.currentPositionIndex >= 2 {
            interactions.append(CharacterInteraction(
                id: "warn_patron_threats",
                title: "Warn of Threats",
                description: "Alert your patron to potential dangers (real or imagined)",
                category: .informing,
                riskLevel: .medium,
                costAP: 1,
                effects: ["patronFavor": 5, "reputationLoyal": 5],
                successNarratives: [
                    "\(character.name) nods gravely. 'I appreciate your vigilance, Comrade.'",
                    "'Interesting,' your patron murmurs, making a note. 'Very interesting.'",
                    "Your warning is received well. \(character.name) values those who watch his back."
                ],
                failureNarratives: [
                    "'You waste my time with rumors?' \(character.name)'s displeasure is evident.",
                    "Your patron dismisses your concerns. Perhaps you've cried wolf too often."
                ],
                flavorText: "Information is currency. Spend it wisely.",
                minPositionIndex: 2
            ))
        }

        return interactions
    }

    // MARK: - Rival Interactions

    private func getRivalInteractions(character: GameCharacter, game: Game) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Public Confrontation (high risk)
        if game.currentPositionIndex >= 2 && game.standing >= 40 {
            interactions.append(CharacterInteraction(
                id: "confront_rival_public",
                title: "Public Confrontation",
                description: "Challenge your rival's position in a committee meeting",
                category: .hostile,
                riskLevel: .high,
                costAP: 2,
                effects: ["rivalThreat": -10, "standing": 5, "reputationCunning": 5],
                successNarratives: [
                    "Your accusations ring through the chamber. \(character.name) has no immediate response.",
                    "The committee members exchange glances. You've drawn blood.",
                    "\(character.name)'s face goes pale. 'These are lies!' But the damage is done."
                ],
                failureNarratives: [
                    "\(character.name) turns your attack back on you. The humiliation is complete.",
                    "'Comrade, your desperation is showing,' your rival sneers to general laughter."
                ],
                flavorText: "A dangerous gambit. Victory is sweet, but defeat is catastrophic.",
                minPositionIndex: 2
            ))
        }

        // Offer Truce (diplomatic option)
        interactions.append(CharacterInteraction(
            id: "offer_truce_rival",
            title: "Offer Temporary Truce",
            description: "Propose a ceasefire in your ongoing conflict",
            category: .diplomatic,
            riskLevel: .medium,
            costAP: 1,
            effects: ["rivalThreat": -5],
            successNarratives: [
                "\(character.name) considers your offer. 'Perhaps... we have common enemies.'",
                "'A truce,' your rival muses. 'For now.' The threat diminishes—temporarily.",
                "An uneasy peace is established. Neither of you trusts the other."
            ],
            failureNarratives: [
                "\(character.name) laughs in your face. 'You think I fear you?'",
                "'Negotiate with you? I think not.' Your rival turns away dismissively."
            ],
            flavorText: "The enemy of my enemy... is still my enemy, but a useful one."
        ))

        // Study Weaknesses (gather intel)
        interactions.append(CharacterInteraction(
            id: "study_rival",
            title: "Study Their Movements",
            description: "Observe your rival's habits and associations",
            category: .intelligence,
            riskLevel: .low,
            costAP: 1,
            effects: ["network": 2],
            successNarratives: [
                "You note \(character.name)'s daily routine. Knowledge is power.",
                "Your observations reveal interesting patterns in your rival's behavior.",
                "A weakness, perhaps? \(character.name) seems nervous around certain colleagues."
            ],
            flavorText: "Know thy enemy."
        ))

        return interactions
    }

    // MARK: - Ally Interactions

    private func getAllyInteractions(character: GameCharacter, game: Game) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Cultivate Friendship
        interactions.append(CharacterInteraction(
            id: "cultivate_ally_\(character.templateId)",
            title: "Cultivate Friendship",
            description: "Spend time building your relationship with \(character.name)",
            category: .diplomatic,
            riskLevel: .low,
            costAP: 1,
            effects: ["network": 1],
            successNarratives: [
                "A pleasant evening discussing politics and vodka. \(character.name) seems warmer toward you.",
                "\(character.name) appreciates your attention. Allies are valuable in these times.",
                "Your relationship with \(character.name) grows stronger."
            ],
            flavorText: "In a world of enemies, a friend is priceless."
        ))

        // Request Favor (if disposition is high enough)
        if character.disposition >= 60 {
            interactions.append(CharacterInteraction(
                id: "request_favor_\(character.templateId)",
                title: "Request a Favor",
                description: "Ask \(character.name) to help you with something",
                category: .diplomatic,
                riskLevel: .medium,
                costAP: 1,
                effects: ["standing": 3],
                successNarratives: [
                    "\(character.name) agrees to help. 'You would do the same for me.'",
                    "Your request is granted, though you now owe a favor in return.",
                    "'Consider it done,' \(character.name) says. 'I trust you'll remember this.'"
                ],
                failureNarratives: [
                    "'I cannot help you with this,' \(character.name) says apologetically.",
                    "\(character.name) seems reluctant. Perhaps you've asked too much."
                ],
                flavorText: "Every favor creates a debt. Debts must be repaid."
            ))
        }

        return interactions
    }

    // MARK: - Contact Interactions

    private func getContactInteractions(character: GameCharacter, game: Game) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Extract Information
        interactions.append(CharacterInteraction(
            id: "extract_info_\(character.templateId)",
            title: "Extract Information",
            description: "Press your contact for useful intelligence",
            category: .intelligence,
            riskLevel: .low,
            costAP: 1,
            effects: ["network": 2],
            successNarratives: [
                "\(character.name) has heard rumors. Some may even be true.",
                "Your contact provides useful tidbits from the corridors of power.",
                "'I shouldn't tell you this,' \(character.name) whispers, 'but...'"
            ],
            flavorText: "Your contact's access has its limits, but every scrap helps."
        ))

        // Request Surveillance
        if game.currentPositionIndex >= 2 {
            interactions.append(CharacterInteraction(
                id: "request_surveillance_\(character.templateId)",
                title: "Request Surveillance",
                description: "Ask your contact to watch someone specific",
                category: .intelligence,
                riskLevel: .medium,
                costAP: 2,
                effects: ["rivalThreat": -3, "network": 1],
                successNarratives: [
                    "\(character.name) agrees to keep eyes on your target.",
                    "'I can do this,' your contact says, 'but it won't be easy.'",
                    "Your contact begins their assignment. Information will follow."
                ],
                failureNarratives: [
                    "'Too risky,' \(character.name) says. 'I could be exposed.'",
                    "Your contact refuses. The target is too well-protected."
                ],
                flavorText: "Everyone watches everyone. That's how things work here.",
                minPositionIndex: 2
            ))
        }

        return interactions
    }

    // MARK: - Cultivation System

    /// Get available cultivation options based on player position and relationship
    func getCultivateInteractions(for character: GameCharacter, game: Game) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Can't cultivate dead characters or those already fully loyal
        guard character.currentStatus == .active ||
              character.currentStatus == .rehabilitated else {
            return interactions
        }

        // Can't cultivate yourself or the General Secretary (unless you ARE the GS)
        guard character.currentRole != .leader else {
            return interactions
        }

        let playerPosition = game.currentPositionIndex
        let isInBPS = isPlayerInStateProtection(game: game)
        let currentDisposition = character.disposition
        let isRival = character.isRival
        let isPatron = character.isPatron

        // TIER 1: Casual Contact (Everyone)
        // Basic relationship building - available for most characters
        if !isPatron { // Can't casually approach your patron
            interactions.append(CharacterInteraction(
                id: "cultivate_casual_\(character.templateId)",
                title: "Casual Contact",
                description: "Strike up a conversation with \(character.name) in the corridors or canteen",
                category: .diplomatic,
                riskLevel: .low,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "A pleasant exchange with \(character.name). You discuss the weather, the latest Party directives, nothing dangerous.",
                    "\(character.name) seems to enjoy the conversation. 'We should talk more often,' they say.",
                    "You share a laugh with \(character.name) over the absurdities of bureaucratic life.",
                    "A brief but warm exchange. \(character.name) remembers your name now."
                ],
                failureNarratives: [
                    "\(character.name) seems distracted. Your attempt at conversation falls flat.",
                    "'I'm busy,' \(character.name) says curtly, brushing past you.",
                    "\(character.name) gives you a suspicious look. Perhaps they don't trust your motives."
                ],
                flavorText: isRival
                    ? "Even rivals can be approached... carefully."
                    : "Relationships begin with small talk."
            ))
        }

        // TIER 2: Share a Drink (Position 1+)
        // More intimate relationship building
        if playerPosition >= 1 {
            interactions.append(CharacterInteraction(
                id: "cultivate_drink_\(character.templateId)",
                title: "Share a Drink",
                description: "Invite \(character.name) for vodka after work",
                category: .diplomatic,
                riskLevel: .low,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "Over vodka, \(character.name) relaxes. Tongues loosened, you learn much about their views.",
                    "'To the Party,' you toast. 'To survival,' \(character.name) replies with a knowing smile.",
                    "The evening is productive. \(character.name) speaks more freely than usual.",
                    "By the third glass, \(character.name) is calling you 'friend.' Whether they'll remember tomorrow..."
                ],
                failureNarratives: [
                    "\(character.name) declines your invitation. 'I don't drink with people I don't trust.'",
                    "The evening is awkward. \(character.name) barely touches their glass and leaves early.",
                    "'Another time, perhaps,' \(character.name) says. The refusal is polite but firm."
                ],
                flavorText: "Vodka loosens tongues and builds bonds. An ancient tradition.",
                minPositionIndex: 1
            ))
        }

        // TIER 3: Offer Gift (Position 2+)
        // Strategic gift-giving
        if playerPosition >= 2 {
            let riskLevel: RiskLevel = isRival ? .medium : .low
            interactions.append(CharacterInteraction(
                id: "cultivate_gift_\(character.templateId)",
                title: "Offer Gift",
                description: "Present \(character.name) with a thoughtful gift—imported goods, rare books, or other luxuries",
                category: .diplomatic,
                riskLevel: riskLevel,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "\(character.name) accepts the gift graciously. 'You have excellent taste, Comrade.'",
                    "'How did you know I collected these?' \(character.name) is genuinely pleased.",
                    "The gift is well-received. \(character.name) will remember this generosity.",
                    "'You shouldn't have,' \(character.name) says, clearly delighted. 'But I'm glad you did.'"
                ],
                failureNarratives: [
                    "\(character.name) eyes the gift suspiciously. 'What do you want from me?'",
                    "'I cannot accept this,' \(character.name) says coldly. 'It would be... inappropriate.'",
                    "Your gift is politely refused. 'I prefer not to create obligations,' \(character.name) explains."
                ],
                flavorText: isRival
                    ? "Even enemies can be bought. Sometimes."
                    : "In a world of scarcity, a gift is power.",
                minPositionIndex: 2
            ))
        }

        // TIER 4: Do Them a Favor (Position 2+)
        // Help them with something to build obligation
        if playerPosition >= 2 && currentDisposition >= 30 {
            interactions.append(CharacterInteraction(
                id: "cultivate_favor_\(character.templateId)",
                title: "Do Them a Favor",
                description: "Use your position to help \(character.name) with a problem they're facing",
                category: .diplomatic,
                riskLevel: .medium,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "You smooth over a bureaucratic problem for \(character.name). They owe you now.",
                    "'I won't forget this,' \(character.name) says. A useful debt is created.",
                    "Your intervention resolves \(character.name)'s difficulty. Gratitude is evident in their eyes.",
                    "The favor is granted. \(character.name) now understands your value as an ally."
                ],
                failureNarratives: [
                    "Your attempt to help backfires. \(character.name) is embarrassed rather than grateful.",
                    "The favor cannot be completed. \(character.name) is disappointed.",
                    "'I didn't ask for your help,' \(character.name) says stiffly. Your interference was unwelcome."
                ],
                flavorText: "Favors create obligations. Obligations create loyalty.",
                minPositionIndex: 2
            ))
        }

        // TIER 5: Share Intelligence (Position 3+)
        // Build trust by sharing useful information
        if playerPosition >= 3 {
            let riskLevel: RiskLevel = isRival ? .high : .medium
            interactions.append(CharacterInteraction(
                id: "cultivate_intel_\(character.templateId)",
                title: "Share Intelligence",
                description: "Pass useful information to \(character.name) about rivals or opportunities",
                category: .intelligence,
                riskLevel: riskLevel,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "'This is valuable,' \(character.name) says, studying the information. 'I am in your debt.'",
                    "The intelligence proves useful. \(character.name) views you as a trusted source now.",
                    "'You could have used this against me instead,' \(character.name) observes. 'Why share it?'",
                    "Trust deepens. \(character.name) shares some information of their own in return."
                ],
                failureNarratives: [
                    "\(character.name) dismisses your information. 'I already knew this.'",
                    "'Is this a test?' \(character.name) asks suspiciously. Your offering breeds distrust.",
                    "The information proves worthless. \(character.name) questions your competence."
                ],
                flavorText: isRival
                    ? "Sharing intelligence with a rival is extremely risky. But also potentially powerful."
                    : "Information is the currency of power. Spend it to build alliances.",
                minPositionIndex: 3
            ))
        }

        // TIER 6: Extend Patronage (Position 4+)
        // Take them under your wing, recommend for advancement
        if playerPosition >= 4 && !isPatron && !isRival && currentDisposition >= 40 {
            interactions.append(CharacterInteraction(
                id: "cultivate_patronage_\(character.templateId)",
                title: "Extend Patronage",
                description: "Take \(character.name) under your protection and recommend them for advancement",
                category: .diplomatic,
                riskLevel: .medium,
                costAP: 2,
                effects: [:],
                successNarratives: [
                    "\(character.name) accepts your patronage gratefully. They are now your protégé.",
                    "'I will not forget your support,' \(character.name) pledges. A new ally is secured.",
                    "Your recommendation carries weight. \(character.name)'s career advances—and they know who to thank.",
                    "\(character.name) becomes part of your circle. Their loyalty is now bound to your success."
                ],
                failureNarratives: [
                    "\(character.name) politely declines. 'I prefer to advance on my own merits.'",
                    "'Your patronage comes with strings,' \(character.name) observes. 'I'm not ready to be tied.'",
                    "The offer is rejected. \(character.name) already has patrons of their own."
                ],
                flavorText: "Building a network of protégés is how lasting power is created.",
                minPositionIndex: 4
            ))
        }

        // TIER 7: Propose Alliance (Position 4+)
        // Formal mutual support arrangement
        if playerPosition >= 4 && currentDisposition >= 50 {
            interactions.append(CharacterInteraction(
                id: "cultivate_alliance_\(character.templateId)",
                title: "Propose Alliance",
                description: "Suggest a formal arrangement of mutual support with \(character.name)",
                category: .diplomatic,
                riskLevel: .medium,
                costAP: 2,
                effects: [:],
                successNarratives: [
                    "'An alliance?' \(character.name) considers. 'Yes, I believe that serves both our interests.'",
                    "Terms are agreed. You and \(character.name) will support each other in the struggles to come.",
                    "'Together, we are stronger,' \(character.name) agrees. The pact is sealed.",
                    "A handshake that means more than words. \(character.name) is now bound to your cause."
                ],
                failureNarratives: [
                    "'I don't make alliances,' \(character.name) says. 'They create vulnerabilities.'",
                    "'What do you bring to such an arrangement?' \(character.name) asks. Your answer is unconvincing.",
                    "The proposal is rejected. \(character.name) doesn't see you as an equal partner."
                ],
                flavorText: isRival
                    ? "An alliance with a rival? Stranger things have happened in politics."
                    : "Formal alliances are the building blocks of faction power.",
                minPositionIndex: 4
            ))
        }

        // TIER 8: Recruit as Asset (Position 5+ OR BPS at 3+)
        // Turn them into an informant or active supporter
        if (playerPosition >= 5 || (isInBPS && playerPosition >= 3)) && !isPatron {
            let riskLevel: RiskLevel = isRival ? .high : .medium
            interactions.append(CharacterInteraction(
                id: "cultivate_recruit_\(character.templateId)",
                title: "Recruit as Asset",
                description: "Attempt to recruit \(character.name) as an active asset—informant, supporter, or agent",
                category: .intelligence,
                riskLevel: riskLevel,
                costAP: 2,
                effects: [:],
                successNarratives: [
                    "\(character.name) agrees to provide regular information. A valuable asset is secured.",
                    "'I will do as you ask,' \(character.name) says. Whether from loyalty or fear, they are yours now.",
                    "The recruitment succeeds. \(character.name) will act on your behalf when called upon.",
                    "\(character.name) becomes your eyes and ears in their department. Information flows."
                ],
                failureNarratives: [
                    "\(character.name) recoils. 'You want me to spy for you? I am no informer!'",
                    "'I know what you're asking,' \(character.name) says coldly. 'The answer is no.'",
                    "The recruitment attempt fails. Worse, \(character.name) may now view you as a threat."
                ],
                flavorText: isInBPS
                    ? "Your BPS connections make recruitment easier."
                    : "Everyone has a price. Find theirs.",
                minPositionIndex: isInBPS ? 3 : 5
            ))
        }

        // SPECIAL: Reconcile (for rivals only, requires Position 3+)
        if isRival && playerPosition >= 3 && currentDisposition >= 20 {
            interactions.append(CharacterInteraction(
                id: "cultivate_reconcile_\(character.templateId)",
                title: "Seek Reconciliation",
                description: "Attempt to end your rivalry with \(character.name) through negotiation",
                category: .diplomatic,
                riskLevel: .medium,
                costAP: 2,
                effects: [:],
                successNarratives: [
                    "'Perhaps we have been foolish to fight each other,' \(character.name) admits. A truce is reached.",
                    "Grudges are set aside. You and \(character.name) agree to end your hostility.",
                    "'The Party is better served by cooperation,' \(character.name) agrees. The rivalry ends.",
                    "Old wounds are acknowledged. Both of you agree to move forward. Trust will take longer."
                ],
                failureNarratives: [
                    "'Reconcile?' \(character.name) laughs bitterly. 'After what you did to me?'",
                    "'Some things cannot be forgiven,' \(character.name) says. The rivalry continues.",
                    "Your overture is rejected. \(character.name) sees it as weakness, not strength."
                ],
                flavorText: "Ending a rivalry can free resources for other battles. Or expose you to betrayal.",
                minPositionIndex: 3
            ))
        }

        // SPECIAL: Strengthen Bond (for patron only)
        if isPatron {
            interactions.append(CharacterInteraction(
                id: "cultivate_patron_\(character.templateId)",
                title: "Strengthen Bond",
                description: "Reinforce your relationship with your patron through dedicated service",
                category: .diplomatic,
                riskLevel: .low,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "Your dedication is noticed. \(character.name) seems pleased with your loyalty.",
                    "'You serve me well,' your patron says. 'I will remember that.'",
                    "The bond between patron and protégé grows stronger.",
                    "\(character.name) confides in you more freely. You have earned greater trust."
                ],
                failureNarratives: [
                    "\(character.name) seems preoccupied with other matters. Your efforts go unnoticed.",
                    "'Not now,' your patron says dismissively. Perhaps your timing was poor.",
                    "Your patron has other concerns. You remain in their shadow, waiting."
                ],
                flavorText: "A patron's favor is your greatest asset. Nurture it carefully."
            ))
        }

        return interactions
    }

    /// Execute a cultivation action and return results
    func executeCultivation(_ interaction: CharacterInteraction, target character: GameCharacter, game: Game) -> CultivateResult {
        let playerPosition = game.currentPositionIndex
        let isInBPS = isPlayerInStateProtection(game: game)
        let isRival = character.isRival
        _ = character.isPatron  // Reserved for patron-specific cultivation logic
        let currentDisposition = character.disposition

        // Calculate base success chance
        var successChance = 0.6 // Base 60%

        // Disposition affects success significantly
        if currentDisposition >= 60 {
            successChance += 0.15 // Already friendly
        } else if currentDisposition >= 40 {
            successChance += 0.05 // Neutral-positive
        } else if currentDisposition < 20 {
            successChance -= 0.15 // Hostile
        }

        // Interaction type modifiers
        if interaction.id.contains("casual") || interaction.id.contains("drink") {
            successChance += 0.1 // Easy interactions
        } else if interaction.id.contains("recruit") || interaction.id.contains("alliance") {
            successChance -= 0.1 // Harder commitments
        }

        // Rival modifier
        if isRival {
            successChance -= 0.2 // Rivals are harder to cultivate
        }

        // Position helps with certain interactions
        if playerPosition >= 4 && (interaction.id.contains("patronage") || interaction.id.contains("alliance")) {
            successChance += 0.1
        }

        // BPS bonus for recruitment
        if isInBPS && interaction.id.contains("recruit") {
            successChance += 0.15
        }

        // Network helps
        if game.network > 50 {
            successChance += 0.1
        }

        // Paranoid targets harder to cultivate
        if character.personalityParanoid > 70 {
            successChance -= 0.15
        }

        // Ambitious targets may see opportunity
        if character.personalityAmbitious > 60 && playerPosition >= 4 {
            successChance += 0.1
        }

        successChance = max(0.15, min(0.9, successChance))

        let success = Double.random(in: 0...1) < successChance

        var dispositionGain = 0
        var becameAlly = false
        var rivalryEnded = false
        var becameProtege = false
        var becameAsset = false
        var trustLevel = 0
        var effects: [String: Int] = [:]
        var narrative: String

        if success {
            narrative = interaction.successNarratives?.randomElement() ?? "Your cultivation effort succeeds."

            // Calculate disposition gain based on interaction type
            if interaction.id.contains("casual") {
                dispositionGain = Int.random(in: 5...10)
                trustLevel = 1
            } else if interaction.id.contains("drink") {
                dispositionGain = Int.random(in: 8...15)
                trustLevel = 2
            } else if interaction.id.contains("gift") {
                dispositionGain = Int.random(in: 10...18)
                trustLevel = 2
            } else if interaction.id.contains("favor") {
                dispositionGain = Int.random(in: 12...20)
                trustLevel = 3
                effects["network"] = 1
            } else if interaction.id.contains("intel") {
                dispositionGain = Int.random(in: 10...15)
                trustLevel = 3
            } else if interaction.id.contains("patronage") {
                dispositionGain = Int.random(in: 15...25)
                trustLevel = 4
                becameProtege = true
                effects["network"] = 2
            } else if interaction.id.contains("alliance") {
                dispositionGain = Int.random(in: 15...25)
                trustLevel = 4
                becameAlly = true
                effects["network"] = 2
            } else if interaction.id.contains("recruit") {
                dispositionGain = Int.random(in: 10...20)
                trustLevel = 5
                becameAsset = true
                effects["network"] = 3
            } else if interaction.id.contains("reconcile") {
                dispositionGain = Int.random(in: 20...35)
                rivalryEnded = true
                trustLevel = 3
            } else if interaction.id.contains("patron") {
                dispositionGain = Int.random(in: 8...15)
                trustLevel = 2
                effects["patronFavor"] = 3
            }

            // Apply disposition gain
            character.disposition = min(100, character.disposition + dispositionGain)

            // Handle special outcomes
            if rivalryEnded {
                character.isRival = false
                character.grudgeLevel = max(0, character.grudgeLevel + 30)
                game.invalidateCharacterRoleCaches() // Rival status changed
            }

            if becameProtege {
                // Mark as being under player's patronage
                character.hasProtection = true
                character.protectorId = "player"
            }

            if becameAsset {
                // Increase their willingness to share information
                character.fearLevel += 10
            }

            if becameAlly && !isRival {
                // Strong allies might become patrons in certain situations
                if character.disposition >= 80 {
                    effects["network"] = (effects["network"] ?? 0) + 1
                }
            }

        } else {
            narrative = interaction.failureNarratives?.randomElement() ?? "Your cultivation effort fails."

            // Failed cultivation may cause suspicion
            if interaction.id.contains("recruit") || interaction.id.contains("intel") {
                // Failed recruitment/intel sharing breeds distrust
                dispositionGain = Int.random(in: -15...(-5))
                character.fearLevel += 5
            } else if interaction.id.contains("alliance") || interaction.id.contains("patronage") {
                // Failed formal proposals are awkward
                dispositionGain = Int.random(in: -10...(-3))
            } else {
                // Minor failures have minor consequences
                dispositionGain = Int.random(in: -5...0)
            }

            character.disposition = max(-100, character.disposition + dispositionGain)

            // Failed reconciliation with rival makes things worse
            if interaction.id.contains("reconcile") {
                character.grudgeLevel -= 10
                effects["rivalThreat"] = 5
            }
        }

        // Record the interaction
        character.recordInteraction(
            turn: game.turnNumber,
            scenario: "Cultivation: \(interaction.title)",
            choice: interaction.id,
            outcome: success ? "positive" : "negative",
            dispositionChange: dispositionGain
        )

        return CultivateResult(
            success: success,
            narrative: narrative,
            targetName: character.name,
            dispositionGain: dispositionGain,
            newDisposition: character.disposition,
            becameAlly: becameAlly,
            rivalryEnded: rivalryEnded,
            becameProtege: becameProtege,
            becameAsset: becameAsset,
            trustLevel: trustLevel,
            effects: effects
        )
    }

    // MARK: - Investigation System

    /// Get available investigation options based on player position
    func getInvestigateInteractions(for character: GameCharacter, game: Game) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Can't investigate dead characters
        guard character.currentStatus == .active ||
              character.currentStatus == .underInvestigation ||
              character.currentStatus == .rehabilitated else {
            return interactions
        }

        let playerPosition = game.currentPositionIndex
        let isInBPS = isPlayerInStateProtection(game: game)
        _ = character.evidenceLevel >= 30  // Reserved for evidence-gated options
        let personalityRevealed = character.isFullyRevealed

        // TIER 1: Informal Observation (Everyone)
        // Basic intel gathering - watch movements, listen to gossip
        interactions.append(CharacterInteraction(
            id: "investigate_observe_\(character.templateId)",
            title: "Informal Observation",
            description: "Watch \(character.name)'s movements and listen for gossip about them",
            category: .intelligence,
            riskLevel: .low,
            costAP: 1,
            effects: [:],
            successNarratives: [
                "You notice \(character.name) meets frequently with certain colleagues. Interesting patterns emerge.",
                "Casual conversations in the canteen reveal useful tidbits about \(character.name)'s habits.",
                "Your observations confirm some suspicions about \(character.name)'s daily routine.",
                "A colleague mentions \(character.name)'s name in an... interesting context."
            ],
            failureNarratives: [
                "Your observations reveal nothing unusual. Perhaps you need better methods.",
                "\(character.name) keeps a low profile. You learn nothing of value.",
                "The gossip mill has nothing on \(character.name) today."
            ],
            flavorText: "Everyone watches everyone. That's life in the Party."
        ))

        // TIER 2: Cultivate Informant (Position 2+)
        // Use your network to plant an informant near the target
        if playerPosition >= 2 {
            interactions.append(CharacterInteraction(
                id: "investigate_informant_\(character.templateId)",
                title: "Cultivate Informant",
                description: "Recruit someone close to \(character.name) to report on their activities",
                category: .intelligence,
                riskLevel: .medium,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "A secretary in \(character.name)'s office agrees to keep you informed. For a price.",
                    "You find a disgruntled subordinate willing to share information about \(character.name).",
                    "An informant is in place. They will report on \(character.name)'s visitors and correspondence.",
                    "Your new source provides their first report: \(character.name) has been making unusual phone calls."
                ],
                failureNarratives: [
                    "No one close to \(character.name) is willing to talk. They're too loyal—or too afraid.",
                    "Your attempt to recruit an informant fails. Worse, they may have mentioned it to \(character.name).",
                    "The potential informant gets cold feet. 'I can't be seen talking to you,' they say."
                ],
                flavorText: "Every organization has its weak links. Find them.",
                minPositionIndex: 2
            ))
        }

        // TIER 3: Request Surveillance (Position 3+ OR BPS member at 2+)
        // Formal surveillance through security apparatus
        if playerPosition >= 3 || (isInBPS && playerPosition >= 2) {
            let riskLevel: RiskLevel = playerPosition >= 4 ? .low : .medium
            interactions.append(CharacterInteraction(
                id: "investigate_surveillance_\(character.templateId)",
                title: "Request Surveillance",
                description: "Have State Security monitor \(character.name)'s communications and movements",
                category: .intelligence,
                riskLevel: riskLevel,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "State Security agrees to monitor \(character.name). Phone calls will be recorded, mail will be read.",
                    "'We already have a file on this one,' the officer says with a knowing smile. He shares the contents.",
                    "Surveillance is approved. Within days, you have transcripts of \(character.name)'s private conversations.",
                    "The surveillance report arrives: \(character.name) has been meeting with some... unexpected people."
                ],
                failureNarratives: [
                    "'We don't have the resources,' you're told. Translation: someone is protecting them.",
                    "The surveillance request is denied. \(character.name) has friends in the security apparatus.",
                    "Your request goes unanswered. It seems to have disappeared into bureaucratic limbo."
                ],
                flavorText: isInBPS
                    ? "Your BPS connections make this easier."
                    : "The Bureau has eyes and ears everywhere—if they choose to use them.",
                minPositionIndex: isInBPS ? 2 : 3
            ))
        }

        // TIER 4: Order Full Investigation (Position 5+ OR BPS at 4+)
        // Full BPS investigation with access to archives, interrogation of contacts
        if playerPosition >= 5 || (isInBPS && playerPosition >= 4) {
            interactions.append(CharacterInteraction(
                id: "investigate_full_\(character.templateId)",
                title: "Order Full Investigation",
                description: "Direct State Security to conduct a comprehensive investigation into \(character.name)",
                category: .intelligence,
                riskLevel: .medium,
                costAP: 2,
                effects: [:],
                successNarratives: [
                    "A full dossier is compiled on \(character.name). Family history, known associates, financial records—everything.",
                    "The investigation uncovers \(character.name)'s secrets. Some of them are... quite useful.",
                    "State Security's report is thorough: they've traced \(character.name)'s activities back years.",
                    "'We found something interesting,' the investigator reports. \(character.name)'s past isn't as clean as they claim."
                ],
                failureNarratives: [
                    "The investigation is blocked at the highest levels. \(character.name) has powerful protectors.",
                    "'Nothing actionable,' the report concludes. Either they're clean, or someone cleaned up.",
                    "The investigators seem... reluctant. Perhaps they've been warned off."
                ],
                flavorText: "The full weight of State Security. Use it wisely.",
                minPositionIndex: isInBPS ? 4 : 5
            ))
        }

        // TIER 5: Access Archives (Position 4+ OR BPS at 3+)
        // Search old files, look for skeletons in closets
        if playerPosition >= 4 || (isInBPS && playerPosition >= 3) {
            interactions.append(CharacterInteraction(
                id: "investigate_archives_\(character.templateId)",
                title: "Search the Archives",
                description: "Dig through old Party records and security files for dirt on \(character.name)",
                category: .intelligence,
                riskLevel: .low,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "The archives reveal a youthful indiscretion: \(character.name) once had... questionable associations.",
                    "You find an old denunciation against \(character.name). It was buried, but not destroyed.",
                    "Records show \(character.name)'s family had bourgeois origins. This was quietly omitted from their file.",
                    "An old photograph shows \(character.name) with someone now considered an enemy of the state."
                ],
                failureNarratives: [
                    "\(character.name)'s file is surprisingly thin. Either they're clean, or someone sanitized their records.",
                    "The relevant files are 'missing.' How convenient.",
                    "You find nothing useful. \(character.name) has been careful—or lucky."
                ],
                flavorText: "The past is never truly buried. Not in the archives.",
                minPositionIndex: isInBPS ? 3 : 4
            ))
        }

        // SPECIAL: Reveal Personality (if not yet revealed)
        // Costs more but specifically targets personality discovery
        if !personalityRevealed {
            let minPos = isInBPS ? 2 : 3
            if playerPosition >= minPos {
                interactions.append(CharacterInteraction(
                    id: "investigate_personality_\(character.templateId)",
                    title: "Psychological Assessment",
                    description: "Have specialists analyze \(character.name)'s behavior to determine their true character",
                    category: .intelligence,
                    riskLevel: .low,
                    costAP: 2,
                    effects: [:],
                    successNarratives: [
                        "The psychological profile is complete. You now understand what drives \(character.name).",
                        "After careful analysis, \(character.name)'s true nature is revealed. They are more \(["ambitious", "paranoid", "ruthless", "calculating"].randomElement()!) than they appear.",
                        "The assessment confirms your suspicions about \(character.name)'s character."
                    ],
                    failureNarratives: [
                        "The assessment is inconclusive. \(character.name) is skilled at hiding their true nature.",
                        "The analysts provide only generalities. More observation is needed."
                    ],
                    flavorText: "Know thy enemy—and thy friends. Especially thy friends.",
                    minPositionIndex: minPos
                ))
            }
        }

        return interactions
    }

    /// Execute an investigation and return results
    func executeInvestigation(_ interaction: CharacterInteraction, target character: GameCharacter, game: Game) -> InvestigateResult {
        let playerPosition = game.currentPositionIndex
        let isInBPS = isPlayerInStateProtection(game: game)
        let targetIsHigherRank = (character.positionIndex ?? 0) > playerPosition
        let hasProtection = character.hasProtection

        // Calculate base success chance
        var successChance = 0.65 // Base 65%

        // Investigation type modifiers
        if interaction.id.contains("observe") {
            successChance += 0.15 // Observation is easy
        } else if interaction.id.contains("full") {
            successChance -= 0.1 // Full investigation is harder
        }

        // BPS bonus
        if isInBPS {
            successChance += 0.15
        }

        // Position helps
        if playerPosition >= 5 {
            successChance += 0.1
        }

        // Target modifiers
        if targetIsHigherRank {
            successChance -= 0.15
        }
        if hasProtection {
            successChance -= 0.2
        }

        // Paranoid targets harder to investigate
        if character.personalityParanoid > 70 {
            successChance -= 0.1
        }

        // Network helps
        if game.network > 50 {
            successChance += 0.1
        }

        successChance = max(0.2, min(0.9, successChance))

        let success = Double.random(in: 0...1) < successChance

        var evidenceGained = 0
        var secretsRevealed: [String] = []
        var personalityRevealed = false
        var alertedTarget = false
        var narrative: String

        if success {
            narrative = interaction.successNarratives?.randomElement() ?? "The investigation succeeds."

            // Calculate evidence gained based on investigation type
            if interaction.id.contains("full") {
                evidenceGained = Int.random(in: 25...40)
            } else if interaction.id.contains("surveillance") || interaction.id.contains("archives") {
                evidenceGained = Int.random(in: 15...25)
            } else if interaction.id.contains("informant") {
                evidenceGained = Int.random(in: 10...20)
            } else {
                evidenceGained = Int.random(in: 5...15)
            }

            // Update character's evidence level
            character.evidenceLevel = min(100, character.evidenceLevel + evidenceGained)

            // Personality reveal
            if interaction.id.contains("personality") {
                personalityRevealed = true
                character.isFullyRevealed = true
                character.personalityRevealedTurn = game.turnNumber
            } else if character.evidenceLevel >= 60 && !character.isFullyRevealed {
                // High evidence may reveal personality automatically
                if Double.random(in: 0...1) < 0.4 {
                    personalityRevealed = true
                    character.isFullyRevealed = true
                    character.personalityRevealedTurn = game.turnNumber
                }
            }

            // Generate secrets based on investigation depth
            secretsRevealed = generateSecrets(
                for: character,
                investigationType: interaction.id,
                evidenceGained: evidenceGained
            )

        } else {
            narrative = interaction.failureNarratives?.randomElement() ?? "The investigation yields nothing."

            // Failed investigation might alert target
            if !interaction.id.contains("observe") && !interaction.id.contains("archives") {
                if Double.random(in: 0...1) < 0.3 {
                    alertedTarget = true
                    character.disposition -= 10
                    character.fearLevel += 10
                    character.grudgeLevel -= 10
                }
            }
        }

        // Record the interaction
        character.recordInteraction(
            turn: game.turnNumber,
            scenario: "Investigation: \(interaction.title)",
            choice: interaction.id,
            outcome: success ? "positive" : "negative",
            dispositionChange: alertedTarget ? -10 : 0
        )

        return InvestigateResult(
            success: success,
            narrative: narrative,
            targetName: character.name,
            evidenceGained: evidenceGained,
            totalEvidence: character.evidenceLevel,
            secretsRevealed: secretsRevealed,
            personalityRevealed: personalityRevealed,
            alertedTarget: alertedTarget
        )
    }

    /// Generate secrets revealed by investigation
    private func generateSecrets(for character: GameCharacter, investigationType: String, evidenceGained: Int) -> [String] {
        var secrets: [String] = []

        // Base secrets based on investigation type
        if investigationType.contains("archives") {
            let archiveSecrets = [
                "Family had ties to pre-revolutionary aristocracy",
                "Briefly associated with Trotskyist group in youth",
                "Father was denounced during the '48 purges",
                "Once wrote letter critical of Party leadership",
                "Has relatives abroad who fled after the revolution",
                "Early Party record shows 'ideological deviations'"
            ]
            if evidenceGained > 15 {
                secrets.append(archiveSecrets.randomElement()!)
            }
        }

        if investigationType.contains("surveillance") || investigationType.contains("informant") {
            let currentSecrets = [
                "Meets regularly with foreign diplomats",
                "Receives unexplained deposits in state bank account",
                "Private conversations show disloyalty to current leadership",
                "Has been stockpiling foreign currency",
                "Maintains contact with disgraced former officials",
                "Shows signs of alcoholism affecting work"
            ]
            if evidenceGained > 10 {
                secrets.append(currentSecrets.randomElement()!)
            }
        }

        if investigationType.contains("full") {
            let deepSecrets = [
                "Evidence of economic crimes and embezzlement",
                "Connections to black market networks",
                "Secret meetings with opposition figures",
                "Falsified production reports in previous position",
                "Covered up industrial accident that killed workers",
                "Maintains secret apartment for unknown purposes"
            ]
            secrets.append(deepSecrets.randomElement()!)
            if evidenceGained > 30 {
                secrets.append(deepSecrets.filter { !secrets.contains($0) }.randomElement() ?? "Additional irregularities found")
            }
        }

        // Personality-based secrets
        if character.personalityCorrupt > 70 && evidenceGained > 15 {
            secrets.append("Evidence of accepting bribes from subordinates")
        }
        if character.personalityAmbitious > 70 && evidenceGained > 20 {
            secrets.append("Has been cultivating allies to move against superiors")
        }

        return secrets
    }

    /// Check if player is in Bureau of People's Security track
    private func isPlayerInStateProtection(game: Game) -> Bool {
        // Check if player's current position track is security services
        // This would be set based on career choices
        // For now, approximate by checking if they have high network + certain position
        return game.network >= 60 && game.currentPositionIndex >= 3
    }

    // MARK: - Denouncement System

    /// Get available denouncement options based on player position and evidence
    func getDenounceInteractions(for character: GameCharacter, game: Game) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Can't denounce yourself, the General Secretary (unless you ARE the GS), or dead characters
        guard character.currentStatus == .active || character.currentStatus == .underInvestigation else {
            return interactions
        }

        // Don't allow re-denouncing too soon
        if let lastDenounced = character.lastDenouncedTurn, game.turnNumber - lastDenounced < 3 {
            return interactions
        }

        let playerPosition = game.currentPositionIndex
        let hasEvidence = character.evidenceLevel >= 30
        let hasStrongEvidence = character.evidenceLevel >= 60
        let targetIsHigherRank = (character.positionIndex ?? 0) > playerPosition
        let targetIsPatronAlly = isProtectedByPatron(character: character, game: game)

        // TIER 1: Anonymous Tip (Position 0-2)
        // Available to everyone, but risky without evidence
        if playerPosition <= 4 {
            interactions.append(CharacterInteraction(
                id: "denounce_anonymous_\(character.templateId)",
                title: "File Anonymous Tip",
                description: "Send an unsigned letter to State Security about \(character.name)'s suspicious activities",
                category: .informing,
                riskLevel: hasEvidence ? .medium : .high,
                costAP: 1,
                effects: [:], // Effects calculated in executeDenouncement
                successNarratives: [
                    "Your anonymous letter reaches the right desk. Questions are being asked about \(character.name).",
                    "State Security has opened a file on \(character.name). Your identity remains hidden—for now.",
                    "The tip is taken seriously. \(character.name) may soon feel the heat of investigation."
                ],
                failureNarratives: [
                    "Your letter is dismissed as baseless rumor. Perhaps you need evidence.",
                    "State Security ignores the anonymous tip. \(character.name) has too many friends.",
                    "Worse—your handwriting is recognized. \(character.name) knows someone is watching."
                ],
                flavorText: targetIsHigherRank
                    ? "Dangerous to denounce your superiors without proof."
                    : "Anonymous letters fill the mailboxes of State Security. Most are ignored."
            ))
        }

        // TIER 2: Formal Complaint (Position 3-4)
        // More credible, goes through Party channels
        if playerPosition >= 3 && playerPosition < 5 {
            let baseRisk: RiskLevel = hasEvidence ? .medium : .high
            interactions.append(CharacterInteraction(
                id: "denounce_formal_\(character.templateId)",
                title: "File Formal Complaint",
                description: "Submit an official Party complaint against \(character.name) through proper channels",
                category: .informing,
                riskLevel: baseRisk,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "Your complaint is reviewed by the Party Control Commission. \(character.name) is summoned for questioning.",
                    "The formal channels prove effective. An official inquiry into \(character.name) begins.",
                    "'We take such matters seriously,' the commissioner says. \(character.name)'s file grows thicker."
                ],
                failureNarratives: [
                    "'Insufficient evidence,' the reply reads. Your complaint is filed away—along with a note about your accusation.",
                    "\(character.name)'s friends in the Commission ensure your complaint goes nowhere.",
                    "The complaint backfires. 'Perhaps the accuser has something to hide,' someone suggests."
                ],
                flavorText: hasEvidence
                    ? "Your evidence strengthens the complaint significantly."
                    : "Filing formal accusations without evidence is... inadvisable.",
                minPositionIndex: 3,
                maxPositionIndex: 4
            ))
        }

        // TIER 3: Official Denunciation (Position 5+)
        // Direct power - use BPS/Party apparatus
        if playerPosition >= 5 {
            interactions.append(CharacterInteraction(
                id: "denounce_official_\(character.templateId)",
                title: "Order Official Investigation",
                description: "Direct State Security to investigate \(character.name) for anti-Party activities",
                category: .hostile,
                riskLevel: .medium,
                costAP: 1,
                effects: [:],
                successNarratives: [
                    "State Security opens an official investigation into \(character.name). The machinery begins to turn.",
                    "'It will be done, Comrade,' the security chief confirms. \(character.name)'s days may be numbered.",
                    "Agents are dispatched. \(character.name)'s movements will be watched, their contacts questioned."
                ],
                failureNarratives: [
                    "Even your authority has limits. \(character.name) is protected by forces you cannot yet command.",
                    "The investigation is quietly blocked. Someone higher up is shielding them.",
                    "'Administrative difficulties,' they tell you. The real message: back off."
                ],
                flavorText: "At your level, a denunciation is an official act with official consequences.",
                minPositionIndex: 5
            ))
        }

        // TIER 4: Public Accusation (Position 4+ with strong evidence OR very high standing)
        // High-profile, high-reward, high-risk
        if (playerPosition >= 4 && hasStrongEvidence) || game.standing >= 70 {
            interactions.append(CharacterInteraction(
                id: "denounce_public_\(character.templateId)",
                title: "Public Accusation",
                description: "Denounce \(character.name) publicly before the Party committee",
                category: .hostile,
                riskLevel: hasStrongEvidence ? .medium : .high,
                costAP: 2,
                effects: [:],
                successNarratives: [
                    "Your accusations ring through the chamber. \(character.name) stands speechless as colleagues turn away.",
                    "'These are the facts!' you declare. The evidence is damning. \(character.name)'s allies begin to distance themselves.",
                    "A murmur runs through the committee. \(character.name) has been publicly marked as suspect."
                ],
                failureNarratives: [
                    "'Slander!' \(character.name) roars. 'This is a personal vendetta!' The room's sympathy shifts against you.",
                    "Your accusations fall flat. Without undeniable proof, you look like the schemer.",
                    "\(character.name) produces counter-evidence. 'Perhaps we should investigate the accuser instead?'"
                ],
                flavorText: targetIsPatronAlly
                    ? "WARNING: This target is protected by a powerful patron."
                    : "A public accusation cannot be taken back. Be certain.",
                minPositionIndex: 4
            ))
        }

        return interactions
    }

    /// Execute a denouncement and calculate all consequences
    func executeDenouncement(_ interaction: CharacterInteraction, target character: GameCharacter, game: Game) -> DenounceResult {
        let playerPosition = game.currentPositionIndex
        let hasEvidence = character.evidenceLevel >= 30
        let hasStrongEvidence = character.evidenceLevel >= 60
        let targetIsHigherRank = (character.positionIndex ?? 0) > playerPosition
        let targetIsPatronAlly = isProtectedByPatron(character: character, game: game)
        let targetIsPlayerPatron = character.isPatron

        // Calculate base success chance
        var successChance = 0.5 // Base 50%

        // Evidence modifiers (most important)
        if hasStrongEvidence {
            successChance += 0.3
        } else if hasEvidence {
            successChance += 0.15
        } else {
            successChance -= 0.2 // No evidence = risky
        }

        // Position modifiers
        if targetIsHigherRank {
            successChance -= 0.2
        }
        if playerPosition >= 5 {
            successChance += 0.15 // Authority helps
        }

        // Protection modifiers
        if character.hasProtection {
            successChance -= 0.25
        }
        if targetIsPatronAlly {
            successChance -= 0.15
        }

        // Previous denouncements make it easier
        if character.denouncementCount > 0 {
            successChance += Double(character.denouncementCount) * 0.1
        }

        // Player network helps
        if game.network > 60 {
            successChance += 0.1
        }

        // Clamp to reasonable bounds
        successChance = max(0.1, min(0.9, successChance))

        let success = Double.random(in: 0...1) < successChance

        var repercussions: [String: Int] = [:]
        var narrative: String
        var relationshipDamage: Int = 0
        var patronAnger: Int = 0
        var targetStatusChange: CharacterStatus? = nil

        if success {
            narrative = interaction.successNarratives?.randomElement() ?? "The denunciation succeeds."

            // Update target's evidence/denouncement tracking
            character.denouncementCount += 1
            character.lastDenouncedTurn = game.turnNumber
            character.denouncedByPlayer = true

            // Determine outcome severity
            let isPublicAccusation = interaction.id.contains("public")
            let isOfficialInvestigation = interaction.id.contains("official")

            if isOfficialInvestigation || isPublicAccusation {
                // Serious outcomes
                targetStatusChange = .underInvestigation
                repercussions["standing"] = 5
                repercussions["reputationCunning"] = 5

                if hasStrongEvidence && isPublicAccusation {
                    // Devastating success
                    repercussions["standing"] = 10
                    character.disposition -= 50 // They hate you now
                    character.fearLevel += 30
                }
            } else {
                // Anonymous/formal - less dramatic but still effective
                character.evidenceLevel += 15 // Investigation reveals more
                repercussions["network"] = 2
            }

            // If they were your rival, reduce their threat
            if character.isRival {
                repercussions["rivalThreat"] = -15
            }

            // Target remembers
            character.grudgeLevel -= 30
            character.lastBetrayalTurn = game.turnNumber

        } else {
            narrative = interaction.failureNarratives?.randomElement() ?? "The denunciation backfires."

            let isPublicAccusation = interaction.id.contains("public")

            // Failed denouncement consequences
            repercussions["standing"] = isPublicAccusation ? -15 : -5
            repercussions["reputationLoyal"] = -5 // Seen as troublemaker

            // Target becomes hostile
            relationshipDamage = isPublicAccusation ? -40 : -20
            character.disposition += relationshipDamage // Actually += because it's negative... let me fix
            character.disposition = max(-100, character.disposition - abs(relationshipDamage))

            // If they find out who denounced them
            if !interaction.id.contains("anonymous") || Double.random(in: 0...1) < 0.3 {
                character.isRival = true
                character.grudgeLevel -= 50
                game.invalidateCharacterRoleCaches() // Rival status changed
            }

            // If target is protected by patron, patron is angry
            if targetIsPatronAlly || targetIsPlayerPatron {
                patronAnger = 20
                // Find patron and reduce their disposition
                if let patron = game.characters.first(where: { $0.isPatron }) {
                    patron.disposition -= patronAnger
                    repercussions["patronFavor"] = -patronAnger
                }
            }
        }

        // Record the interaction
        character.recordInteraction(
            turn: game.turnNumber,
            scenario: "Denouncement: \(interaction.title)",
            choice: interaction.id,
            outcome: success ? "positive" : "negative",
            dispositionChange: success ? -30 : abs(relationshipDamage)
        )

        return DenounceResult(
            success: success,
            narrative: narrative,
            targetName: character.name,
            newTargetStatus: targetStatusChange,
            repercussions: repercussions,
            relationshipDamage: relationshipDamage,
            patronAnger: patronAnger,
            madeEnemy: !success && character.isRival,
            evidenceRevealed: success ? character.evidenceLevel : 0
        )
    }

    /// Check if character is protected by the player's patron
    private func isProtectedByPatron(character: GameCharacter, game: Game) -> Bool {
        // Check if they share faction with patron
        guard let patron = game.characters.first(where: { $0.isPatron }) else { return false }

        // Same faction = protected
        if let charFaction = character.factionId,
           let patronFaction = patron.factionId,
           charFaction == patronFaction {
            return true
        }

        // Check explicit protection
        if character.hasProtection,
           let protectorId = character.protectorId,
           protectorId == patron.id.uuidString {
            return true
        }

        return false
    }

    // MARK: - Leader Powers (Position 5+)

    private func getLeaderPowers(character: GameCharacter, game: Game) -> [CharacterInteraction] {
        var interactions: [CharacterInteraction] = []

        // Can't use leader powers on yourself or the General Secretary (if not you)
        guard character.currentRole != .leader else { return interactions }

        let isGeneralSecretary = game.currentPositionIndex >= 6

        // Order Investigation (Deputy General Secretary+)
        interactions.append(CharacterInteraction(
            id: "order_investigation_\(character.templateId)",
            title: "Order Investigation",
            description: "Direct State Security to investigate \(character.name)",
            category: .hostile,
            riskLevel: .medium,
            costAP: 1,
            effects: [:], // Effects applied separately based on outcome
            successNarratives: [
                "State Security opens a file on \(character.name). The investigation begins.",
                "'It will be done,' the security chief says. \(character.name) will be watched.",
                "Questions are being asked about \(character.name)'s activities."
            ],
            failureNarratives: [
                "The security apparatus seems reluctant. Perhaps \(character.name) has protectors.",
                "'There is... insufficient evidence,' you are told. Someone is blocking this."
            ],
            flavorText: "The machinery of the state can crush anyone. But using it has costs.",
            minPositionIndex: 5
        ))

        // Order Arrest (General Secretary only, or Deputy with high support)
        if isGeneralSecretary || (game.currentPositionIndex == 5 && game.network >= 70) {
            interactions.append(CharacterInteraction(
                id: "order_arrest_\(character.templateId)",
                title: "Order Arrest",
                description: "Have \(character.name) detained for questioning",
                category: .hostile,
                riskLevel: .high,
                costAP: 2,
                effects: ["stability": -5, "eliteLoyalty": -8],
                successNarratives: [
                    "\(character.name) is taken in the night. By morning, their office is empty.",
                    "The arrest proceeds without incident. \(character.name) goes quietly—they always do.",
                    "'Counter-revolutionary activities,' the report will say. The details can be filled in later."
                ],
                failureNarratives: [
                    "The arrest attempt fails. \(character.name) was warned—by whom?",
                    "Your orders were... delayed. Someone in the apparatus is protecting them."
                ],
                flavorText: "Arrest first, find evidence later. The Party way.",
                minPositionIndex: 5
            ))
        }

        // Order Execution (General Secretary only)
        if isGeneralSecretary {
            interactions.append(CharacterInteraction(
                id: "order_execution_\(character.templateId)",
                title: "Order Execution",
                description: "Sign the order for \(character.name)'s execution",
                category: .hostile,
                riskLevel: .high,
                costAP: 2,
                effects: ["stability": -10, "eliteLoyalty": -15, "reputationRuthless": 15],
                successNarratives: [
                    "The sentence is carried out at dawn. \(character.name) is no more.",
                    "'Crimes against the state.' The tribunal was brief. The execution briefer.",
                    "\(character.name) joins the ranks of those who underestimated your resolve."
                ],
                failureNarratives: [
                    "The Politburo blocks the execution. Even your power has limits.",
                    "International pressure stays your hand. \(character.name) lives—for now."
                ],
                flavorText: "The ultimate power. Use it wisely, or not at all.",
                minPositionIndex: 6
            ))

            // Order Exile (less severe than execution)
            interactions.append(CharacterInteraction(
                id: "order_exile_\(character.templateId)",
                title: "Order Exile",
                description: "Banish \(character.name) to a distant region",
                category: .hostile,
                riskLevel: .medium,
                costAP: 1,
                effects: ["stability": -3, "eliteLoyalty": -5],
                successNarratives: [
                    "\(character.name) will contribute to agricultural development in the Plains Zone.",
                    "'For health reasons,' the announcement says. \(character.name) departs within the hour.",
                    "A one-way ticket to Alaska. \(character.name)'s career in Washington is over."
                ],
                failureNarratives: [
                    "\(character.name) has too many allies. The exile order is quietly shelved.",
                    "The People's Congress finds your reasoning 'insufficient.' \(character.name) remains."
                ],
                flavorText: "Not death, but close enough. Alaska is very cold this time of year.",
                minPositionIndex: 6
            ))

            // Forced Retirement (mildest option)
            interactions.append(CharacterInteraction(
                id: "force_retirement_\(character.templateId)",
                title: "Force Retirement",
                description: "Pressure \(character.name) to retire 'for health reasons'",
                category: .hostile,
                riskLevel: .low,
                costAP: 1,
                effects: ["eliteLoyalty": -3],
                successNarratives: [
                    "\(character.name) announces retirement, citing health concerns. No one believes it.",
                    "'I have served the Party faithfully,' \(character.name) says in their farewell. Bitterness barely concealed.",
                    "A pension and a dacha. \(character.name) should be grateful for your mercy."
                ],
                failureNarratives: [
                    "\(character.name) refuses to go quietly. 'I will not be pushed out!'",
                    "The old guard rallies around \(character.name). Forcing them out would cost too much."
                ],
                flavorText: "A gentle push toward the exit. Or not so gentle.",
                minPositionIndex: 6
            ))

            // Rehabilitate (if investigating/detained - shows mercy)
            if character.currentStatus == .underInvestigation || character.currentStatus == .detained {
                interactions.append(CharacterInteraction(
                    id: "rehabilitate_\(character.templateId)",
                    title: "Order Rehabilitation",
                    description: "Clear \(character.name) of all charges and restore them",
                    category: .diplomatic,
                    riskLevel: .low,
                    costAP: 1,
                    effects: ["eliteLoyalty": 5, "reputationLoyal": 3],
                    successNarratives: [
                        "\(character.name) is released. 'Errors were made,' the statement reads.",
                        "The investigation found nothing. \(character.name) returns to their duties, grateful.",
                        "Mercy is remembered. \(character.name) owes you their life."
                    ],
                    flavorText: "Showing mercy can be as powerful as showing strength.",
                    minPositionIndex: 6
                ))
            }
        }

        return interactions
    }

    // MARK: - Execute Leader Action

    /// Execute a leader power (arrest, execute, exile) with full repercussions
    func executeLeaderAction(_ interaction: CharacterInteraction, target character: GameCharacter, game: Game) -> LeaderActionResult {
        // Determine success based on political factors
        var successChance = 0.75 // Base 75%

        // Modifiers
        if character.isPatron { successChance -= 0.3 } // Very hard to move against patron
        if character.isRival { successChance += 0.1 }  // Easier against known rival
        if character.disposition > 70 { successChance -= 0.15 } // Popular figures are harder
        if game.stability < 40 { successChance -= 0.1 } // Unstable times = resistance
        if game.eliteLoyalty > 70 { successChance += 0.1 } // Loyal apparatus = easier

        let success = Double.random(in: 0...1) < successChance

        var repercussions: [String: Int] = [:]
        var narrative: String
        var newStatus: CharacterStatus? = nil

        if success {
            narrative = interaction.successNarratives?.randomElement() ?? "The order is carried out."

            // Apply the fate based on action type
            if interaction.id.contains("execution") {
                newStatus = .executed
                repercussions = calculateExecutionRepercussions(character: character, game: game)
            } else if interaction.id.contains("arrest") {
                newStatus = .detained
                repercussions = calculateArrestRepercussions(character: character, game: game)
            } else if interaction.id.contains("exile") {
                newStatus = .exiled
                repercussions = calculateExileRepercussions(character: character, game: game)
            } else if interaction.id.contains("retirement") {
                newStatus = .retired
                repercussions = calculateRetirementRepercussions(character: character, game: game)
            } else if interaction.id.contains("investigation") {
                newStatus = .underInvestigation
                repercussions = ["eliteLoyalty": -3]
            } else if interaction.id.contains("rehabilitate") {
                newStatus = .rehabilitated
                repercussions = ["eliteLoyalty": 5]
            }

            // Add base effects from interaction
            for (key, value) in interaction.effects {
                repercussions[key, default: 0] += value
            }
        } else {
            narrative = interaction.failureNarratives?.randomElement() ?? "The order cannot be carried out."

            // Failed actions have their own repercussions
            repercussions = [
                "standing": -10,
                "eliteLoyalty": -5,
                "rivalThreat": character.isRival ? 15 : 5
            ]
        }

        return LeaderActionResult(
            success: success,
            narrative: narrative,
            newStatus: newStatus,
            repercussions: repercussions,
            targetName: character.name
        )
    }

    private func calculateExecutionRepercussions(character: GameCharacter, game: Game) -> [String: Int] {
        var effects: [String: Int] = [
            "stability": -10,
            "eliteLoyalty": -15,
            "reputationRuthless": 20
        ]

        // Executing popular figures has more impact
        if character.disposition > 60 {
            effects["popularSupport"] = -10
            effects["eliteLoyalty"]! -= 10
        }

        // Executing rivals pleases some
        if character.isRival {
            effects["standing"] = 5
            effects["rivalThreat"] = -100 // Eliminate threat entirely
        }

        // International reaction for prominent figures
        if character.currentRole == .patron || character.templateId.contains("minister") {
            effects["internationalStanding"] = -8
        }

        // Princeling faction (red aristocracy with military ties) = military unhappy
        if character.factionId == "princelings" {
            effects["militaryLoyalty"] = -20
        }

        return effects
    }

    private func calculateArrestRepercussions(character: GameCharacter, game: Game) -> [String: Int] {
        var effects: [String: Int] = [
            "stability": -5,
            "eliteLoyalty": -8,
            "reputationRuthless": 8
        ]

        if character.isRival {
            effects["rivalThreat"] = -30
        }

        if character.factionId == "princelings" {
            effects["militaryLoyalty"] = -10
        }

        return effects
    }

    private func calculateExileRepercussions(character: GameCharacter, game: Game) -> [String: Int] {
        var effects: [String: Int] = [
            "stability": -3,
            "eliteLoyalty": -5,
            "reputationRuthless": 5
        ]

        if character.isRival {
            effects["rivalThreat"] = -50
        }

        return effects
    }

    private func calculateRetirementRepercussions(character: GameCharacter, game: Game) -> [String: Int] {
        var effects: [String: Int] = [
            "eliteLoyalty": -3
        ]

        if character.isRival {
            effects["rivalThreat"] = -20
        }

        // Forced retirement of popular figures noticed
        if character.disposition > 70 {
            effects["popularSupport"] = -3
        }

        return effects
    }

    // MARK: - Execute Interaction

    /// Execute a character interaction and return the result
    func executeInteraction(_ interaction: CharacterInteraction, with character: GameCharacter, game: Game) -> InteractionResult {
        // Calculate success chance based on disposition and risk
        var successChance = 0.7 // Base 70%

        // Disposition modifier
        let dispositionModifier = Double(character.disposition - 50) / 100.0 * 0.2
        successChance += dispositionModifier

        // Risk modifier
        switch interaction.riskLevel {
        case .low: successChance += 0.1
        case .medium: break
        case .high: successChance -= 0.15
        }

        // Network bonus
        if game.network > 50 {
            successChance += 0.1
        }

        // Roll for success
        let success = Double.random(in: 0...1) < successChance

        // Generate narrative
        let narrative: String
        if success {
            narrative = interaction.successNarratives?.randomElement() ?? "The interaction succeeds."
        } else {
            narrative = interaction.failureNarratives?.randomElement() ?? "The interaction does not go as planned."
        }

        // Calculate effects (reduced on failure)
        var actualEffects = interaction.effects
        if !success {
            actualEffects = actualEffects.mapValues { value in
                if value > 0 {
                    return 0 // No positive effects on failure
                } else {
                    return value * 2 // Double negative effects on failure
                }
            }
        }

        // Disposition change
        let dispositionChange = success ? Int.random(in: 2...5) : Int.random(in: -5...(-2))

        return InteractionResult(
            success: success,
            narrative: narrative,
            effects: actualEffects,
            dispositionChange: dispositionChange,
            characterName: character.name
        )
    }
}

// MARK: - Supporting Types

struct CharacterInteraction: Identifiable {
    let id: String
    let title: String
    let description: String
    let category: InteractionCategory
    let riskLevel: RiskLevel
    let costAP: Int
    let effects: [String: Int]
    var successNarratives: [String]?
    var failureNarratives: [String]?
    var flavorText: String?
    var minPositionIndex: Int?
    var maxPositionIndex: Int?
}

enum InteractionCategory: String {
    case diplomatic = "Diplomatic"
    case hostile = "Hostile"
    case intelligence = "Intelligence"
    case informing = "Informing"

    var icon: String {
        switch self {
        case .diplomatic: return "hand.raised.fill"
        case .hostile: return "bolt.fill"
        case .intelligence: return "eye.fill"
        case .informing: return "exclamationmark.bubble.fill"
        }
    }
}

struct InteractionResult {
    let success: Bool
    let narrative: String
    let effects: [String: Int]
    let dispositionChange: Int
    let characterName: String
}

struct LeaderActionResult {
    let success: Bool
    let narrative: String
    let newStatus: CharacterStatus?
    let repercussions: [String: Int]
    let targetName: String

    var isSignificant: Bool {
        newStatus == .executed || newStatus == .exiled || newStatus == .imprisoned
    }
}

/// Result of an investigation action
struct InvestigateResult {
    let success: Bool
    let narrative: String
    let targetName: String
    let evidenceGained: Int
    let totalEvidence: Int
    let secretsRevealed: [String]
    let personalityRevealed: Bool
    let alertedTarget: Bool

    /// Summary for UI display
    var summaryText: String {
        if success {
            if personalityRevealed {
                return "Investigation reveals \(targetName)'s true character. Evidence level: \(totalEvidence)%"
            } else if !secretsRevealed.isEmpty {
                return "Investigation uncovers secrets. Evidence level: \(totalEvidence)%"
            } else {
                return "Investigation gathered useful intelligence. Evidence level: \(totalEvidence)%"
            }
        } else {
            if alertedTarget {
                return "Investigation failed. \(targetName) may have been alerted."
            } else {
                return "Investigation yielded nothing useful."
            }
        }
    }

    /// Icon for UI
    var outcomeIcon: String {
        if success {
            if personalityRevealed { return "brain.head.profile" }
            if !secretsRevealed.isEmpty { return "doc.text.magnifyingglass" }
            return "checkmark.circle"
        } else {
            return alertedTarget ? "exclamationmark.triangle.fill" : "xmark.circle"
        }
    }
}

/// Result of a denouncement action
struct DenounceResult {
    let success: Bool
    let narrative: String
    let targetName: String
    let newTargetStatus: CharacterStatus?
    let repercussions: [String: Int]
    let relationshipDamage: Int
    let patronAnger: Int
    let madeEnemy: Bool
    let evidenceRevealed: Int

    /// Summary text for UI display
    var summaryText: String {
        if success {
            if newTargetStatus == .underInvestigation {
                return "\(targetName) is now under investigation."
            } else {
                return "Your denunciation has been noted. \(targetName) is under scrutiny."
            }
        } else {
            if madeEnemy {
                return "Your denunciation failed. \(targetName) now knows you are their enemy."
            } else if patronAnger > 0 {
                return "Your denunciation failed and angered your patron."
            } else {
                return "Your denunciation failed. Your reputation suffers."
            }
        }
    }

    /// Risk level indicator for UI
    var outcomeIcon: String {
        if success {
            return newTargetStatus != nil ? "checkmark.seal.fill" : "checkmark.circle"
        } else {
            return madeEnemy ? "exclamationmark.triangle.fill" : "xmark.circle"
        }
    }
}

/// Result of a cultivation action
struct CultivateResult {
    let success: Bool
    let narrative: String
    let targetName: String
    let dispositionGain: Int
    let newDisposition: Int
    let becameAlly: Bool
    let rivalryEnded: Bool
    let becameProtege: Bool
    let becameAsset: Bool
    let trustLevel: Int // 1-5 scale
    let effects: [String: Int]

    /// Summary text for UI display
    var summaryText: String {
        if success {
            if becameAlly {
                return "\(targetName) is now a formal ally. They will support you in political struggles."
            } else if rivalryEnded {
                return "Your rivalry with \(targetName) has ended. A new chapter begins."
            } else if becameProtege {
                return "\(targetName) is now under your patronage. Their success is tied to yours."
            } else if becameAsset {
                return "\(targetName) has been recruited as an asset. They will provide information and support."
            } else if dispositionGain > 15 {
                return "Significant progress with \(targetName). Trust is growing."
            } else {
                return "Your relationship with \(targetName) has improved."
            }
        } else {
            if dispositionGain < -10 {
                return "Your approach backfired. \(targetName) trusts you less now."
            } else {
                return "Your cultivation effort was unsuccessful."
            }
        }
    }

    /// Icon for UI
    var outcomeIcon: String {
        if success {
            if becameAlly || becameProtege { return "person.2.fill" }
            if rivalryEnded { return "hand.raised.fill" }
            if becameAsset { return "eye.fill" }
            if trustLevel >= 3 { return "heart.fill" }
            return "checkmark.circle"
        } else {
            return dispositionGain < -10 ? "exclamationmark.triangle.fill" : "xmark.circle"
        }
    }

    /// Trust level description
    var trustLevelText: String {
        switch trustLevel {
        case 0: return "No change"
        case 1: return "Acquaintance"
        case 2: return "Friendly"
        case 3: return "Trusted"
        case 4: return "Close Ally"
        case 5: return "Asset"
        default: return "Unknown"
        }
    }
}

// MARK: - Show Trial System Extension
//
// Uses existing ShowTrial, ShowTrialPhase, ConfessionType, and TrialSentence from HistoricalMechanics.swift
// This extension adds processing methods for the trial flow

extension CharacterInteractionSystem {

    /// Initiate a show trial against a detained character
    func initiateShowTrial(defendant: GameCharacter, game: Game) -> ShowTrial {
        // Generate charges based on character
        let charges = generateCharges(for: defendant)

        let trial = ShowTrial(
            defendantId: defendant.id,
            defendantName: defendant.name,
            defendantTitle: defendant.title,
            charges: charges,
            turnInitiated: game.turnNumber
        )

        // Transition defendant status
        defendant.status = CharacterStatus.underInvestigation.rawValue

        return trial
    }

    /// Generate appropriate charges based on character's position and track
    func generateCharges(for character: GameCharacter) -> [TrialCharge] {
        var charges: [TrialCharge] = []

        // Always include a political charge
        charges.append([.counterRevolutionary, .trotskyism, .bourgeoisNationalism].randomElement()!)

        // Add track-specific charges
        if character.positionTrack == "economicPlanning" || character.positionTrack == "stateMinistry" {
            charges.append(.economicSabotage)
        }
        if character.positionTrack == "securityServices" {
            charges.append(.corruption)
        }
        if character.positionTrack == "foreignAffairs" {
            charges.append(.espionage)
        }

        // Possibly add corruption charge
        if character.personalityCorrupt > 50 || Double.random(in: 0...1) < 0.3 {
            if !charges.contains(.corruption) {
                charges.append(.corruption)
            }
        }

        return charges
    }

    /// Process a trial phase and return the result
    func processTrialPhase(trial: inout ShowTrial, game: Game) -> TrialPhaseResult {
        let currentTurn = game.turnNumber
        let turnsElapsed = currentTurn - trial.turnInitiated

        switch trial.phase {
        case .accusation:
            // Accusation is immediate, move to interrogation
            trial.phase = .confessionExtraction
            let chargeNames = trial.charges.map { $0.displayName }.joined(separator: ", ")
            return TrialPhaseResult(
                phase: .accusation,
                narrative: "The People's Prosecutor announces charges against \(trial.defendantName): \(chargeNames).",
                headline: "ENEMY OF THE PEOPLE ARRESTED",
                nextPhase: .confessionExtraction
            )

        case .confessionExtraction:
            // Takes 2 turns
            if turnsElapsed < 2 {
                return TrialPhaseResult(
                    phase: .confessionExtraction,
                    narrative: "Interrogation of \(trial.defendantName) continues in the cellars of State Protection.",
                    headline: nil,
                    nextPhase: nil
                )
            }

            // Determine confession type based on personality
            let defendant = game.characters.first { $0.id == trial.defendantId }
            trial.confessionType = determineConfessionType(defendant: defendant)
            trial.confessionObtained = (trial.confessionType != .resisted)

            trial.phase = .publicTrial

            let confessionNarrative: String
            switch trial.confessionType! {
            case .scripted:
                confessionNarrative = "\(trial.defendantName) has confessed fully to all charges. The confession will be read at the trial."
            case .resisted:
                confessionNarrative = "\(trial.defendantName) remains defiant, refusing to confess. The trial will proceed regardless."
                trial.martyrCreated = true
            case .recanted:
                confessionNarrative = "\(trial.defendantName) initially confessed but has withdrawn the confession. This will not save them."
                trial.martyrCreated = true
            case .implicatedOthers:
                confessionNarrative = "\(trial.defendantName) has confessed and implicated numerous co-conspirators. Additional arrests will follow."
            }

            return TrialPhaseResult(
                phase: .confessionExtraction,
                narrative: confessionNarrative,
                headline: trial.confessionType == .implicatedOthers ? "CONSPIRACY WIDER THAN FIRST BELIEVED" : nil,
                nextPhase: .publicTrial
            )

        case .publicTrial:
            // Public trial takes 1 turn after interrogation
            if turnsElapsed < 3 {
                return TrialPhaseResult(
                    phase: .publicTrial,
                    narrative: "The trial of \(trial.defendantName) proceeds in the Great Hall of Justice. Foreign observers are permitted to witness the confession.",
                    headline: "TRIAL OF \(trial.defendantName.uppercased()) BEGINS",
                    nextPhase: nil
                )
            }

            trial.phase = .sentencing

            return TrialPhaseResult(
                phase: .publicTrial,
                narrative: "The court finds \(trial.defendantName) GUILTY on all charges. The chamber erupts in applause.",
                headline: "\(trial.defendantName.uppercased()) FOUND GUILTY",
                nextPhase: .sentencing
            )

        case .sentencing:
            // Determine sentence based on various factors
            let defendant = game.characters.first { $0.id == trial.defendantId }
            trial.sentence = determineSentence(trial: trial, defendant: defendant, game: game)

            // Calculate effects
            let chargeSeverity = trial.charges.reduce(0) { $0 + $1.severity }
            trial.intimidationGained = chargeSeverity * 2
            if trial.martyrCreated {
                trial.internationalCondemnation = 15
            }

            trial.phase = .completed
            trial.executedTurn = currentTurn

            let sentenceNarrative: String
            switch trial.sentence! {
            case .execution:
                sentenceNarrative = "\(trial.defendantName) is sentenced to death. The sentence will be carried out immediately."
            case .imprisonment25, .imprisonment15, .imprisonment10:
                sentenceNarrative = "\(trial.defendantName) is sentenced to \(trial.sentence!.displayName). They will serve their sentence in the Eastern Territories."
            case .exile:
                sentenceNarrative = "\(trial.defendantName) is sentenced to internal exile in the Far Eastern Region."
            case .demotion:
                sentenceNarrative = "\(trial.defendantName) is publicly disgraced but spared imprisonment."
            }

            return TrialPhaseResult(
                phase: .sentencing,
                narrative: sentenceNarrative,
                headline: sentenceHeadline(for: trial.sentence!, name: trial.defendantName),
                nextPhase: .completed
            )

        case .completed:
            return TrialPhaseResult(
                phase: .completed,
                narrative: "The trial of \(trial.defendantName) has concluded. The Party's justice has been served.",
                headline: nil,
                nextPhase: nil
            )
        }
    }

    /// Determine confession type based on defendant personality
    private func determineConfessionType(defendant: GameCharacter?) -> ConfessionType {
        guard let defendant = defendant else { return .scripted }

        // Resisted confessions are rare and require strong character
        if defendant.personalityLoyal < 30 && defendant.personalityParanoid < 40 && Double.random(in: 0...1) < 0.1 {
            return .resisted
        }

        // Corrupt/ambitious characters more likely to implicate others
        if defendant.personalityCorrupt > 60 || defendant.personalityAmbitious > 70 {
            if Double.random(in: 0...1) < 0.4 {
                return .implicatedOthers
            }
        }

        // Loyal characters may recant
        if defendant.personalityLoyal > 70 && Double.random(in: 0...1) < 0.2 {
            return .recanted
        }

        // Default is scripted confession (most common)
        return .scripted
    }

    /// Determine sentence based on trial circumstances
    private func determineSentence(trial: ShowTrial, defendant: GameCharacter?, game: Game) -> TrialSentence {
        guard let defendant = defendant else { return .execution }

        // Resisted defendants almost always executed
        if trial.confessionType == .resisted || trial.confessionType == .recanted {
            return Double.random(in: 0...1) < 0.9 ? .execution : .imprisonment25
        }

        // Implicating others might earn leniency
        if trial.confessionType == .implicatedOthers {
            let roll = Double.random(in: 0...1)
            if roll < 0.3 { return .imprisonment15 }
            if roll < 0.6 { return .imprisonment10 }
            if roll < 0.8 { return .exile }
            return .imprisonment25
        }

        // Position affects severity (higher = harsher example needed)
        let positionIndex = defendant.positionIndex ?? 0
        if positionIndex >= 5 {
            return Double.random(in: 0...1) < 0.7 ? .execution : .imprisonment25
        }
        if positionIndex >= 3 {
            let roll = Double.random(in: 0...1)
            if roll < 0.4 { return .execution }
            if roll < 0.7 { return .imprisonment25 }
            return .imprisonment15
        }

        // Lower positions may get lighter sentences
        let roll = Double.random(in: 0...1)
        if roll < 0.2 { return .execution }
        if roll < 0.5 { return .imprisonment15 }
        if roll < 0.8 { return .imprisonment10 }
        return .exile
    }

    private func sentenceHeadline(for sentence: TrialSentence, name: String) -> String {
        switch sentence {
        case .execution:
            return "\(name.uppercased()) SENTENCED TO DEATH"
        case .imprisonment25, .imprisonment15, .imprisonment10:
            return "TRAITOR \(name.uppercased()) IMPRISONED"
        case .exile:
            return "\(name.uppercased()) BANISHED TO EASTERN TERRITORIES"
        case .demotion:
            return "\(name.uppercased()) PUBLICLY DISGRACED"
        }
    }

    /// Apply trial aftermath effects to game state
    func applyTrialAftermath(trial: ShowTrial, game: Game) {
        guard let defendant = game.characters.first(where: { $0.id == trial.defendantId }) else { return }

        // Update defendant status based on sentence
        switch trial.sentence {
        case .execution:
            defendant.status = CharacterStatus.executed.rawValue
            defendant.positionIndex = nil
            defendant.positionTrack = nil
        case .imprisonment25, .imprisonment15, .imprisonment10:
            defendant.status = CharacterStatus.imprisoned.rawValue
            defendant.positionIndex = nil
            defendant.positionTrack = nil
        case .exile:
            defendant.status = CharacterStatus.exiled.rawValue
            defendant.positionIndex = nil
            defendant.positionTrack = nil
        case .demotion:
            // Demotion keeps them active but at lower position
            defendant.status = CharacterStatus.active.rawValue
            defendant.positionIndex = max(0, (defendant.positionIndex ?? 0) - 2)
        case .none:
            break
        }

        // Apply stability/loyalty effects based on intimidation and condemnation
        game.stability = max(0, min(100, game.stability - trial.internationalCondemnation / 3))
        game.eliteLoyalty = max(0, min(100, game.eliteLoyalty - 5))

        // Intimidation increases faction fear
        if trial.intimidationGained > 0 {
            // Would update faction fear here
        }
    }
}

/// Result of processing a trial phase
struct TrialPhaseResult {
    let phase: ShowTrialPhase
    let narrative: String
    let headline: String?
    let nextPhase: ShowTrialPhase?
}
