//
//  NetworkContactSystem.swift
//  Nomenklatura
//
//  System for spawning network contacts as actual characters
//  and managing character deaths with varied narrative tones
//

import Foundation

// MARK: - Network Contact System

class NetworkContactSystem {
    static let shared = NetworkContactSystem()

    // Contact templates by action type
    private let contactTemplates: [String: [ContactTemplate]] = [
        "plant_ally_security": [
            ContactTemplate(
                namePool: ["Daniel O'Brien", "Andrew Morrison", "Eugene Kelly", "Paul Simpson", "Nathan Pierce"],
                titlePool: ["Junior Clerk, State Security", "Filing Clerk, Second Directorate", "Records Assistant, Bureau of Internal Affairs"],
                role: .informant,
                personalityPreset: .nervous,
                flavorText: "A mousy man who startles at loud noises but remembers everything he sees."
            ),
            ContactTemplate(
                namePool: ["Bernard Wilson", "Gregory Chapman", "Arthur Franklin"],
                titlePool: ["Archive Supervisor", "Night Shift Duty Officer", "Communications Room Technician"],
                role: .informant,
                personalityPreset: .opportunist,
                flavorText: "He has expensive tastes that his salary cannot support."
            )
        ],
        "cultivate_military": [
            ContactTemplate(
                namePool: ["Colonel Zimmerman", "Major Kirkpatrick", "Captain Bennett", "Lieutenant Colonel Osborne"],
                titlePool: ["Deputy Commander, Armored Division", "Staff Officer, Eastern Military District", "Logistics Officer, General Staff"],
                role: .ally,
                personalityPreset: .pragmatic,
                flavorText: "A professional soldier who values competence over ideology."
            ),
            ContactTemplate(
                namePool: ["General Thornton", "General Vasquez", "Commissar Rockwell"],
                titlePool: ["Inspector General", "Chief of Artillery", "Political Officer, Tank Corps"],
                role: .ally,
                personalityPreset: .ambitious,
                flavorText: "He sees which way the wind blows and positions himself accordingly."
            )
        ],
        "gather_intel_rival": [
            ContactTemplate(
                namePool: ["The Accountant", "Comrade X", "The Secretary"],
                titlePool: ["Anonymous Source", "Confidential Informant", "Unnamed Contact"],
                role: .informant,
                personalityPreset: .paranoid,
                flavorText: "Never meets in the same place twice. Payments in unmarked envelopes only."
            )
        ]
    ]

    // MARK: - Spawn Contact

    /// Attempt to spawn a new contact character from a network action
    func trySpawnContact(actionId: String, game: Game) -> GameCharacter? {
        // Only spawn contacts sometimes (40% chance for immersion, not every action)
        guard Double.random(in: 0...1) < 0.4 else { return nil }

        // Check if we have templates for this action
        guard let templates = contactTemplates[actionId],
              let template = templates.randomElement() else {
            return nil
        }

        // Check if we already have too many contacts (max 5 network contacts)
        let existingContacts = game.characters.filter { $0.currentRole == .informant || $0.templateId.hasPrefix("contact_") }
        guard existingContacts.count < 5 else { return nil }

        // Generate the contact
        let contact = template.generateCharacter()
        contact.game = game

        return contact
    }

    // MARK: - Contact Templates

    struct ContactTemplate {
        let namePool: [String]
        let titlePool: [String]
        let role: CharacterRole
        let personalityPreset: PersonalityPreset
        let flavorText: String

        func generateCharacter() -> GameCharacter {
            let name = namePool.randomElement() ?? "Unknown Contact"
            let title = titlePool.randomElement() ?? "Contact"

            let character = GameCharacter(
                templateId: "contact_\(UUID().uuidString.prefix(8))",
                name: name,
                title: title,
                role: role
            )

            // Apply personality preset
            switch personalityPreset {
            case .nervous:
                character.personalityParanoid = Int.random(in: 60...80)
                character.personalityAmbitious = Int.random(in: 20...40)
                character.personalityLoyal = Int.random(in: 50...70)
                character.personalityCompetent = Int.random(in: 40...60)
            case .opportunist:
                character.personalityAmbitious = Int.random(in: 70...90)
                character.personalityCorrupt = Int.random(in: 60...80)
                character.personalityLoyal = Int.random(in: 20...40)
                character.personalityCompetent = Int.random(in: 50...70)
            case .pragmatic:
                character.personalityCompetent = Int.random(in: 70...90)
                character.personalityLoyal = Int.random(in: 40...60)
                character.personalityAmbitious = Int.random(in: 40...60)
                character.personalityParanoid = Int.random(in: 30...50)
            case .ambitious:
                character.personalityAmbitious = Int.random(in: 80...100)
                character.personalityRuthless = Int.random(in: 50...70)
                character.personalityCompetent = Int.random(in: 60...80)
                character.personalityLoyal = Int.random(in: 30...50)
            case .paranoid:
                character.personalityParanoid = Int.random(in: 80...100)
                character.personalityLoyal = Int.random(in: 30...50)
                character.personalityAmbitious = Int.random(in: 20...40)
            }

            // Set initial disposition (contacts start friendly)
            character.disposition = Int.random(in: 55...75)

            // Store flavor text in notes or speechPattern
            character.speechPattern = flavorText

            return character
        }
    }

    enum PersonalityPreset {
        case nervous, opportunist, pragmatic, ambitious, paranoid
    }
}

// MARK: - Character Death System

class CharacterDeathSystem {
    static let shared = CharacterDeathSystem()

    /// Generate a death/removal notification with appropriate tone
    func generateDeathNotification(character: GameCharacter, cause: DeathCause, game: Game) -> DeathNotification {
        let tone = determineTone(character: character, cause: cause, game: game)
        let (headline, details) = generateNarrativeText(character: character, cause: cause, tone: tone)

        return DeathNotification(
            characterName: character.name,
            characterTitle: character.title ?? "Official",
            cause: cause,
            tone: tone,
            headline: headline,
            details: details,
            wasRival: character.isRival,
            wasPatron: character.isPatron,
            wasAlly: character.disposition > 60
        )
    }

    private func determineTone(character: GameCharacter, cause: DeathCause, game: Game) -> DeathTone {
        // Rivals dying can be darkly humorous
        if character.isRival {
            return cause == .naturalCauses ? .ironic : .darklyComic
        }

        // Patron dying is always grim
        if character.isPatron {
            return .grim
        }

        // Corrupt characters getting caught can be ironic
        if character.personalityCorrupt > 70 && cause == .arrested {
            return .ironic
        }

        // Random deaths of minor characters can vary
        if !character.isPatron && !character.isRival {
            let tones: [DeathTone] = [.grim, .bureaucratic, .ironic, .absurd]
            return tones.randomElement() ?? .bureaucratic
        }

        return .grim
    }

    private func generateNarrativeText(character: GameCharacter, cause: DeathCause, tone: DeathTone) -> (headline: String, details: String) {
        switch cause {
        case .executed, .executionByMilitary:
            return generateExecutionText(character: character, tone: tone)
        case .executionByPurge, .purged:
            return generatePurgeText(character: character, tone: tone)
        case .naturalCauses, .illness:
            return generateNaturalDeathText(character: character, tone: tone)
        case .accident, .carAccident, .planeAccident, .fallingAccident:
            return generateAccidentText(character: character, tone: tone)
        case .heartAttack:
            return generateNaturalDeathText(character: character, tone: tone)
        case .suicide:
            return generateSuicideText(character: character, tone: tone)
        case .arrested:
            return generateArrestText(character: character, tone: tone)
        case .resistingArrest:
            return generateResistingArrestText(character: character, tone: tone)
        case .disappeared:
            return generateDisappearanceText(character: character, tone: tone)
        case .exiled:
            return generateExileText(character: character, tone: tone)
        }
    }

    private func generateSuicideText(character: GameCharacter, tone: DeathTone) -> (String, String) {
        switch tone {
        case .darklyComic:
            return ("\(character.name) Takes Drastic Career Step",
                    "Officials expressed surprise at the timing, given the investigation.")
        case .ironic:
            return ("\(character.name) Finds Own Solution",
                    "The official report notes multiple self-inflicted injuries.")
        case .absurd:
            return ("\(character.name) Commits Suicide By Multiple Means",
                    "Despite being under 24-hour guard, security saw nothing.")
        case .bureaucratic, .grim:
            return ("\(character.name) Found Dead",
                    "Investigation ruled suicide. No further inquiry deemed necessary.")
        }
    }

    private func generateResistingArrestText(character: GameCharacter, tone: DeathTone) -> (String, String) {
        switch tone {
        case .darklyComic:
            return ("\(character.name) Makes Poor Career Decision",
                    "Security forces commended for their restraint.")
        case .ironic:
            return ("\(character.name) Fails To Surrender Peacefully",
                    "The 47 bullet wounds were ruled proportionate response.")
        case .absurd:
            return ("\(character.name) Trips Into Bullets",
                    "Security report notes the unfortunate series of accidents.")
        case .bureaucratic, .grim:
            return ("\(character.name) Shot During Arrest",
                    "Forces responded to armed resistance with appropriate measures.")
        }
    }

    private func generateExecutionText(character: GameCharacter, tone: DeathTone) -> (String, String) {
        switch tone {
        case .darklyComic:
            let headlines = [
                "\(character.name) Discovers Terminal Career Limitation",
                "\(character.name)'s Retirement Accelerated",
                "\(character.name) Receives Final Performance Review"
            ]
            let details = [
                "The firing squad noted his punctuality, even at the end.",
                "His last words were reportedly about meeting quotas. Some habits die hard.",
                "The paperwork was filed correctly, which he would have appreciated."
            ]
            return (headlines.randomElement()!, details.randomElement()!)

        case .ironic:
            return (
                "\(character.name) Meets Fate He Often Prescribed for Others",
                "Those who live by the denunciation often die by it. The irony was not lost on observers."
            )

        case .grim:
            return (
                "\(character.name) Executed for Crimes Against the State",
                "The sentence was carried out at dawn. No appeals were permitted."
            )

        case .bureaucratic:
            return (
                "\(character.name): Status Updated to 'Deceased'",
                "The relevant forms have been filed. His office has been reassigned."
            )

        case .absurd:
            let headlines = [
                "\(character.name) Tragically Shot While Attempting to Flee (While Seated)",
                "\(character.name) Succumbs to Acute Lead Poisoning"
            ]
            return (headlines.randomElement()!, "The official report contains certain... inconsistencies.")
        }
    }

    private func generateNaturalDeathText(character: GameCharacter, tone: DeathTone) -> (String, String) {
        switch tone {
        case .darklyComic, .ironic:
            if character.isRival {
                return (
                    "\(character.name) Inconsiderately Dies of Natural Causes",
                    "Just when things were getting interesting. How disappointing."
                )
            }
            return (
                "\(character.name) Achieves What Few Party Members Manage",
                "Dying of old age in this business is quite an accomplishment."
            )

        case .grim:
            return (
                "\(character.name) Has Passed Away",
                "The state mourns the loss of a dedicated servant."
            )

        case .bureaucratic:
            return (
                "Administrative Notice: \(character.name) Deceased",
                "Natural causes. Pension payments have been terminated."
            )

        case .absurd:
            return (
                "\(character.name) Chooses Worst Possible Moment to Die",
                "His timing, as always, was impeccable."
            )
        }
    }

    private func generateAccidentText(character: GameCharacter, tone: DeathTone) -> (String, String) {
        let accidents = [
            "fell from a window",
            "suffered a car accident",
            "had an unfortunate encounter with stairs",
            "experienced mechanical difficulties in an elevator"
        ]
        let accident = accidents.randomElement()!

        switch tone {
        case .darklyComic, .absurd:
            return (
                "\(character.name) Has Tragic Accident (Nothing Suspicious)",
                "Official report: \(character.name) \(accident). Witnesses confirm everything was entirely normal and there is no need for further questions."
            )

        case .ironic:
            return (
                "\(character.name) Falls Victim to Unfortunate Coincidence",
                "The timing of the accident was purely coincidental, as were the three similar accidents this week."
            )

        default:
            return (
                "\(character.name) Dies in Accident",
                "A tragic accident has claimed the life of \(character.name). An investigation has concluded there was no foul play."
            )
        }
    }

    private func generateArrestText(character: GameCharacter, tone: DeathTone) -> (String, String) {
        switch tone {
        case .ironic:
            if character.personalityCorrupt > 70 {
                return (
                    "\(character.name) Discovers Corruption Is Only Acceptable at Higher Levels",
                    "His mistake was not being corrupt—it was being caught."
                )
            }
            return (
                "\(character.name) Arrested on Charges He Himself Once Leveled at Others",
                "The wheel turns."
            )

        case .bureaucratic:
            return (
                "\(character.name) Detained Pending Investigation",
                "State Security has taken custody. His calendar has been cleared indefinitely."
            )

        default:
            return (
                "\(character.name) Arrested for Counter-Revolutionary Activities",
                "The evidence, we are told, is overwhelming."
            )
        }
    }

    private func generateDisappearanceText(character: GameCharacter, tone: DeathTone) -> (String, String) {
        switch tone {
        case .darklyComic:
            return (
                "\(character.name) Takes Unexpected Leave of Absence",
                "His desk has been cleaned out. No one remembers who he was or that he ever existed."
            )

        case .absurd:
            return (
                "\(character.name) Reportedly 'On Vacation'",
                "He has been on vacation for six months. His family has also gone on vacation. No one has their address."
            )

        default:
            return (
                "\(character.name): Whereabouts Unknown",
                "He was last seen entering a black car. Inquiries are not encouraged."
            )
        }
    }

    private func generateExileText(character: GameCharacter, tone: DeathTone) -> (String, String) {
        let destinations = ["the Mountain Zone", "a remote collective farm in the Plains", "the Northern Territories", "Alaska"]
        let destination = destinations.randomElement()!

        switch tone {
        case .darklyComic:
            return (
                "\(character.name) Volunteered for Important Work in \(destination.capitalized)",
                "He seemed surprised by his own enthusiasm for the transfer."
            )

        case .ironic:
            return (
                "\(character.name) Discovers the Joys of Regional Administration",
                "His new posting in \(destination) comes with fewer responsibilities. And guards."
            )

        default:
            return (
                "\(character.name) Reassigned to \(destination.capitalized)",
                "The Party has found a more suitable position for his talents."
            )
        }
    }

    private func generatePurgeText(character: GameCharacter, tone: DeathTone) -> (String, String) {
        switch tone {
        case .bureaucratic:
            return (
                "\(character.name) Removed from Position",
                "As part of ongoing efforts to improve efficiency, certain personnel changes have been made."
            )

        case .grim:
            return (
                "\(character.name) Falls in Party Purge",
                "Another name crossed from the rolls. Another office emptied overnight."
            )

        default:
            return (
                "\(character.name) Swept Up in Reorganization",
                "The restructuring continues. \(character.name) has been... restructured."
            )
        }
    }
}

// MARK: - Supporting Types

enum DeathCause: String, Codable, CaseIterable {
    // Official executions
    case executed            // Standard execution
    case executionByPurge    // Mass purge execution
    case executionByMilitary // Military tribunal
    case purged              // Removed during purge

    // "Accidents" and "Natural Causes"
    case naturalCauses       // Natural death
    case accident            // Generic accident
    case carAccident         // "Car accident"
    case planeAccident       // "Plane crash"
    case heartAttack         // "Heart attack"
    case suicide             // "Committed suicide"
    case illness             // "Died of illness"
    case fallingAccident     // "Fell from window"

    // Security outcomes
    case arrested            // Arrested (leads to trial)
    case resistingArrest     // "Shot resisting arrest"

    // Unknown
    case disappeared         // Simply vanished
    case exiled              // Sent away (not death)

    /// Whether this is a permanent death (vs arrest/exile)
    var isPermanentDeath: Bool {
        switch self {
        case .arrested, .exiled:
            return false
        default:
            return true
        }
    }

    /// Whether this was an official execution
    var isOfficial: Bool {
        switch self {
        case .executed, .executionByPurge, .executionByMilitary, .purged:
            return true
        default:
            return false
        }
    }

    /// Display text
    var displayText: String {
        switch self {
        case .executed: return "Executed"
        case .executionByPurge: return "Purged"
        case .executionByMilitary: return "Military execution"
        case .purged: return "Purged"
        case .naturalCauses: return "Natural causes"
        case .accident: return "Accident"
        case .carAccident: return "Car accident"
        case .planeAccident: return "Plane crash"
        case .heartAttack: return "Heart attack"
        case .suicide: return "Suicide"
        case .illness: return "Illness"
        case .fallingAccident: return "Accidental fall"
        case .arrested: return "Arrested"
        case .resistingArrest: return "Shot resisting arrest"
        case .disappeared: return "Disappeared"
        case .exiled: return "Exiled"
        }
    }

    /// Official/euphemistic description
    var officialDescription: String {
        switch self {
        case .executed: return "sentence carried out"
        case .executionByPurge: return "removed during anti-corruption campaign"
        case .executionByMilitary: return "military justice applied"
        case .purged: return "removed from position"
        case .naturalCauses: return "passed away peacefully"
        case .accident: return "died in accident"
        case .carAccident: return "died in tragic automobile accident"
        case .planeAccident: return "perished in aviation incident"
        case .heartAttack: return "suffered fatal cardiac arrest"
        case .suicide: return "took their own life"
        case .illness: return "succumbed to illness"
        case .fallingAccident: return "died in accidental fall"
        case .arrested: return "detained for questioning"
        case .resistingArrest: return "died resisting lawful detention"
        case .disappeared: return "whereabouts unknown"
        case .exiled: return "transferred to provincial assignment"
        }
    }
}

enum DeathTone {
    case grim           // Serious, dark
    case darklyComic    // Black humor
    case ironic         // Karma/poetic justice
    case bureaucratic   // Coldly administrative
    case absurd         // Soviet absurdism
}

struct DeathNotification {
    let characterName: String
    let characterTitle: String
    let cause: DeathCause
    let tone: DeathTone
    let headline: String
    let details: String
    let wasRival: Bool
    let wasPatron: Bool
    let wasAlly: Bool

    var isSignificant: Bool {
        wasRival || wasPatron || wasAlly
    }
}
