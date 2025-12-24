//
//  NarrativeGenerator.swift
//  Nomenklatura
//
//  Generates dynamic narrative text for character reactions, atmosphere, and immersion
//

import Foundation

// MARK: - Narrative Generator

class NarrativeGenerator {
    static let shared = NarrativeGenerator()

    // MARK: - Character Reactions

    /// Generate a character's reaction based on their personality and the situation
    func generateCharacterReaction(
        character: GameCharacter,
        situation: ReactionSituation,
        playerChoice: String? = nil
    ) -> String {
        let personality = character.personality
        let disposition = character.disposition

        // Get base reactions for the situation
        let reactions = getReactionsForSituation(situation, personality: personality, disposition: disposition)

        // Select and personalize based on character traits
        let selectedReaction = reactions.randomElement() ?? ""
        return personalizeReaction(selectedReaction, character: character)
    }

    private func getReactionsForSituation(
        _ situation: ReactionSituation,
        personality: CharacterPersonality,
        disposition: Int
    ) -> [String] {
        switch situation {
        case .playerMadeRuthlessChoice:
            if personality.ruthless >= 70 {
                return [
                    "nods slowly, a cold smile crossing their face",
                    "watches with unmistakable approval",
                    "\"Now that is how it's done, Comrade.\""
                ]
            } else if personality.ruthless <= 30 {
                return [
                    "looks away, their expression troubled",
                    "shifts uncomfortably in their chair",
                    "\"I see. Well... it is done now.\""
                ]
            } else {
                return [
                    "maintains a careful neutrality",
                    "gives nothing away in their expression",
                    "\"The Party requires difficult decisions.\""
                ]
            }

        case .playerMadeCompassionateChoice:
            if personality.ruthless >= 70 {
                return [
                    "frowns, clearly disappointed",
                    "\"Mercy is a luxury we cannot always afford.\"",
                    "exchanges a meaningful look with others in the room"
                ]
            } else if personality.ruthless <= 30 {
                return [
                    "relaxes visibly, relief in their eyes",
                    "nods with what might be respect",
                    "\"There is wisdom in restraint, Comrade.\""
                ]
            } else {
                return [
                    "considers this silently",
                    "\"Time will tell if this was wise.\"",
                    "makes a note in their file"
                ]
            }

        case .playerGainedPower:
            if disposition >= 60 {
                return [
                    "offers quiet congratulations",
                    "\"Your rise continues. Remember your friends.\"",
                    "seems genuinely pleased"
                ]
            } else if disposition <= 40 {
                return [
                    "watches with barely concealed concern",
                    "\"How quickly fortunes change...\"",
                    "their smile doesn't reach their eyes"
                ]
            } else {
                return [
                    "acknowledges this with a neutral expression",
                    "\"The Party rewards loyalty.\"",
                    "makes careful note of this development"
                ]
            }

        case .playerLostPower:
            if disposition >= 60 {
                return [
                    "offers a look of sympathy",
                    "\"These setbacks are temporary. Stay strong.\"",
                    "seems troubled on your behalf"
                ]
            } else if disposition <= 40 {
                return [
                    "fails to entirely hide their satisfaction",
                    "\"A lesson in humility, perhaps.\"",
                    "watches your discomfort with interest"
                ]
            } else {
                return [
                    "maintains diplomatic silence",
                    "\"The wheel turns for us all.\"",
                    "offers neither comfort nor criticism"
                ]
            }

        case .scenarioBriefing:
            if personality.paranoid >= 70 {
                return [
                    "glances at the door before speaking",
                    "lowers their voice conspiratorially",
                    "\"This matter requires... discretion.\""
                ]
            } else if personality.competent >= 70 {
                return [
                    "presents the facts methodically",
                    "\"I've prepared a full briefing.\"",
                    "speaks with crisp efficiency"
                ]
            } else {
                return [
                    "clears their throat",
                    "\"There is a matter requiring your attention.\"",
                    "shifts papers nervously"
                ]
            }

        case .personalActionSuccess:
            return [
                "\"Well played, Comrade.\"",
                "nods with a knowing look",
                "\"You learn quickly.\""
            ]

        case .personalActionDiscovered:
            if personality.paranoid >= 70 {
                return [
                    "\"I knew something was amiss. I always know.\"",
                    "watches you with cold calculation",
                    "\"Did you think no one was watching?\""
                ]
            } else {
                return [
                    "\"This is... disappointing news.\"",
                    "regards you with new wariness",
                    "\"Explain yourself, Comrade.\""
                ]
            }
        }
    }

    private func personalizeReaction(_ reaction: String, character: GameCharacter) -> String {
        // If it's a quote, attribute it
        if reaction.hasPrefix("\"") {
            return "\(character.name) \(reaction.hasSuffix("\"") ? "says, " : "")\(reaction)"
        }
        // If it's a description, add the character's name
        return "\(character.name) \(reaction)."
    }

    // MARK: - Atmosphere Text

    /// Generate atmospheric description based on game state
    func generateAtmosphere(for phase: NarrativePhase, game: Game) -> String {
        switch phase {
        case .briefing:
            return generateBriefingAtmosphere(game: game)
        case .personalAction:
            return generatePersonalActionAtmosphere(game: game)
        case .outcome:
            return generateOutcomeAtmosphere(game: game)
        }
    }

    private func generateBriefingAtmosphere(game: Game) -> String {
        let timeDescriptions: [String]
        let hour = (game.turnNumber * 3) % 24  // Pseudo time of day

        if hour >= 6 && hour < 12 {
            timeDescriptions = [
                "Morning light filters through dusty curtains.",
                "The samovar steams in the corner. Another day begins.",
                "Outside, workers stream toward the factories."
            ]
        } else if hour >= 12 && hour < 18 {
            timeDescriptions = [
                "The afternoon stretches on, heavy with unspoken tensions.",
                "Cigarette smoke hangs in the air.",
                "The portrait of the General Secretary watches from the wall."
            ]
        } else {
            timeDescriptions = [
                "Night has fallen over the capital.",
                "The building is quiet now. Most have gone home.",
                "Somewhere in the distance, a telephone rings unanswered."
            ]
        }

        var atmosphere = timeDescriptions.randomElement() ?? ""

        // Add tension based on stability
        if game.stability < 30 {
            let tensionTexts = [
                " The air feels electric with tension.",
                " Rumors swirl through the corridors.",
                " Everyone speaks in hushed voices today."
            ]
            atmosphere += tensionTexts.randomElement() ?? ""
        }

        // Add mood based on player standing
        if game.standing < 30 {
            let worryTexts = [
                " You notice colleagues avoiding your gaze.",
                " Your office feels smaller, more isolated.",
                " The weight of scrutiny presses down."
            ]
            atmosphere += worryTexts.randomElement() ?? ""
        } else if game.standing > 70 {
            let confidenceTexts = [
                " People step aside as you pass.",
                " Your name carries weight in these halls.",
                " Even senior officials nod respectfully."
            ]
            atmosphere += confidenceTexts.randomElement() ?? ""
        }

        return atmosphere
    }

    private func generatePersonalActionAtmosphere(game: Game) -> String {
        let baseTexts = [
            "The corridors of power never truly sleep.",
            "In the shadows of the apparatus, deals are made.",
            "Every alliance is temporary. Every friend, a potential enemy.",
            "The game within the game continues.",
            "Here, away from official business, the real work begins."
        ]

        var atmosphere = baseTexts.randomElement() ?? ""

        // Modify based on rival threat
        if game.rivalThreat >= 70 {
            let dangerTexts = [
                " You feel eyes on your back. Someone is watching.",
                " Your rivals circle like wolves sensing weakness.",
                " Trust no one. Not tonight."
            ]
            atmosphere += dangerTexts.randomElement() ?? ""
        }

        // Modify based on patron favor
        if game.patronFavor < 30 {
            let isolationTexts = [
                " Your patron's protection feels increasingly distant.",
                " Without allies, the darkness feels deeper.",
                " You are alone in this."
            ]
            atmosphere += isolationTexts.randomElement() ?? ""
        }

        return atmosphere
    }

    private func generateOutcomeAtmosphere(game: Game) -> String {
        // This will be contextual based on what just happened
        return ""  // Outcomes have their own narrative
    }

    // MARK: - Action Flavor Text

    /// Get immersive flavor text for a personal action
    func getActionFlavorText(for actionId: String, game: Game) -> String {
        let flavorTexts: [String: [String]] = [
            "plant_ally_security": [
                "A chance meeting in the canteen. A shared cigarette. Information has its price.",
                "The junior clerk seems eager to please. Perhaps too eager. But useful.",
                "Everyone in State Security has secrets. Everyone can be turned."
            ],
            "cultivate_military": [
                "The officers' club. Vodka flows, tongues loosen, bonds form.",
                "Generals remember those who remember them. A birthday card here, a kind word there.",
                "The military respects strength. Show them you understand their world."
            ],
            "gather_intel_rival": [
                "Your rival has enemies too. They're happy to share what they know.",
                "Files have a way of finding their way to interested parties.",
                "Knowledge is the currency of power. Time to make a withdrawal."
            ],
            "leak_failures": [
                "A word in the right ear. A document left carelessly visible.",
                "The truth can be a weapon, when wielded at the right moment.",
                "Let others ask the uncomfortable questions. Your hands stay clean."
            ],
            "frame_conspiracy": [
                "Evidence is malleable. History is written by the survivors.",
                "A signature here, a meeting there—all easily arranged.",
                "The line between enemy of the state and patriot is thin indeed."
            ],
            "private_meeting_secretary": [
                "An audience with the General Secretary. Few receive such invitations.",
                "The inner sanctum. Here, fates are decided with a nod.",
                "Speak carefully. Every word will be remembered. Every pause, analyzed."
            ],
            "public_praise_patron": [
                "Loyalty must be demonstrated, not just felt.",
                "A speech in the right forum. Words that will be reported upward.",
                "Let all know whose banner you march under."
            ],
            "prepare_dossier": [
                "Documents, testimonials, records of service. Build your fortress of paper.",
                "When the accusations come—and they always come—be ready.",
                "Your file is your shield. Make it thick."
            ],
            "propose_promotion": [
                "The vacancy awaits. Will you seize it?",
                "Ambition must be disguised as duty. Make the case carefully.",
                "Your name, submitted for consideration. Now the waiting begins."
            ],
            "challenge_rival": [
                "The moment has come. Strike now, or forever look over your shoulder.",
                "Your accusations must be devastating. There are no second chances.",
                "In the arena of the Politburo, only one will walk away."
            ],
            "begin_coup": [
                "The pieces are in position. The hour approaches.",
                "Revolution from within. The most dangerous game.",
                "History remembers the victors. Pray you are among them."
            ]
        ]

        if let texts = flavorTexts[actionId] {
            return texts.randomElement() ?? ""
        }

        // Generic fallbacks by category
        return "The political game continues. Every move carries weight."
    }

    // MARK: - Stat Mood Descriptions

    /// Get a narrative description of the current state based on stats
    func getStateMoodDescription(game: Game) -> String? {
        var descriptions: [String] = []

        // Critical situations get priority
        if game.stability < 25 {
            descriptions.append("The regime teeters on the edge of chaos.")
        }
        if game.popularSupport < 25 {
            descriptions.append("The people's patience has worn dangerously thin.")
        }
        if game.foodSupply < 25 {
            descriptions.append("Hunger stalks the land. Empty shelves breed dangerous thoughts.")
        }
        if game.militaryLoyalty < 25 {
            descriptions.append("The generals grow restless. Loyalty cannot survive on empty promises.")
        }
        if game.treasury < 25 {
            descriptions.append("The coffers run dry. Even ideology cannot pay wages forever.")
        }

        // Positive states
        if game.stability > 75 && game.popularSupport > 75 {
            descriptions.append("The state runs smoothly. For now, the people are content.")
        }
        if game.internationalStanding > 75 {
            descriptions.append("Abroad, your nation's influence grows. Diplomats speak your name with respect.")
        }

        return descriptions.randomElement()
    }

    /// Get a narrative description of the player's personal situation
    func getPersonalMoodDescription(game: Game) -> String? {
        var descriptions: [String] = []

        // Danger signals
        if game.patronFavor < 30 {
            descriptions.append("Your patron's warmth has cooled. You sense the withdrawal of protection.")
        }
        if game.rivalThreat > 70 {
            descriptions.append("Your enemies grow bold. They smell blood.")
        }
        if game.standing < 30 {
            descriptions.append("Your star is fading. Colleagues who once sought your favor now look elsewhere.")
        }

        // Strong positions
        if game.standing > 70 && game.patronFavor > 70 {
            descriptions.append("Your position is strong. Favor flows your way. Use it wisely.")
        }
        if game.network > 70 {
            descriptions.append("Your web of contacts spans the apparatus. Little happens without word reaching you.")
        }

        return descriptions.randomElement()
    }
}

// MARK: - Supporting Types

enum ReactionSituation {
    case playerMadeRuthlessChoice
    case playerMadeCompassionateChoice
    case playerGainedPower
    case playerLostPower
    case scenarioBriefing
    case personalActionSuccess
    case personalActionDiscovered
}

enum NarrativePhase {
    case briefing
    case personalAction
    case outcome
}
