//
//  DomesticSceneService.swift
//  Nomenklatura
//
//  Generates domestic scenes between political crises.
//  These scenes reflect Communist reality:
//  - Brief respites with state propaganda in the background
//  - Children sharing what they learned at Party youth group
//  - Spouse concerns about neighbors disappearing
//  - Innocent revelations that could be dangerous
//  - Late night visitors from the office
//  - Tense silences when walls have ears
//

import Foundation
import os.log

private let domesticLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "DomesticScene")

// MARK: - Domestic Scene Types

enum DomesticSceneType: String, Codable, CaseIterable {
    case quietEvening        // Brief respite, propaganda on radio
    case familyDinner        // Children share youth group lessons
    case spouseConcerns      // Spouse worried about events
    case childsReport        // Child reveals something innocent but dangerous
    case lateNightVisitor    // Unexpected work visitor
    case tenseSilence        // Unable to speak freely
    case celebration         // Achievement or holiday
    case familyWorries       // Discussion about family member
    case neighborGone        // Someone in the building disappeared

    var displayName: String {
        switch self {
        case .quietEvening: return "A Quiet Evening"
        case .familyDinner: return "Family Dinner"
        case .spouseConcerns: return "Spouse's Concerns"
        case .childsReport: return "Child's Report"
        case .lateNightVisitor: return "Late Night Visitor"
        case .tenseSilence: return "Tense Silence"
        case .celebration: return "Family Celebration"
        case .familyWorries: return "Family Worries"
        case .neighborGone: return "The Empty Apartment"
        }
    }

    /// Base frequency weight (higher = more common)
    var frequency: Int {
        switch self {
        case .quietEvening: return 25
        case .familyDinner: return 20
        case .spouseConcerns: return 15
        case .childsReport: return 10
        case .lateNightVisitor: return 8
        case .tenseSilence: return 12
        case .celebration: return 5
        case .familyWorries: return 15
        case .neighborGone: return 8
        }
    }
}

// MARK: - Domestic Scene

struct DomesticScene: Codable, Identifiable {
    var id: UUID = UUID()
    var type: DomesticSceneType
    var title: String
    var narrative: String
    var turnOccurred: Int

    // Effects of the scene
    var harmonyChange: Int = 0
    var riskRevealed: Bool = false     // Did scene reveal family risk?
    var warningGiven: Bool = false     // Did scene provide useful warning?
    var informantClue: Bool = false    // Did scene hint at informant?

    // Related family member
    var involvedMemberId: UUID?
    var involvedMemberName: String?

    // Player choice if applicable
    var hasChoice: Bool = false
    var choicePrompt: String?
    var choices: [DomesticChoice]?
}

struct DomesticChoice: Codable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var harmonyEffect: Int
    var riskEffect: String?  // Description of risk change
    var consequence: String  // What happens after choosing
}

// MARK: - Domestic Scene Service

@MainActor
class DomesticSceneService {
    static let shared = DomesticSceneService()

    private init() {}

    // MARK: - Check for Scene

    /// Check if a domestic scene should occur this turn
    func shouldTriggerScene(family: PlayerFamily, game: Game) -> Bool {
        guard family.hasFamily else { return false }

        // Check minimum turns between scenes (every 3-6 turns)
        let turnsSinceLastScene = game.turnNumber - family.lastDomesticSceneTurn
        guard turnsSinceLastScene >= 3 else { return false }

        // Base 40% chance after minimum interval
        var chance = 40

        // Increase chance if it's been a while
        if turnsSinceLastScene >= 5 {
            chance += 20
        }

        // Increase during times of stress
        if game.stability < 40 {
            chance += 15
        }

        if game.rivalThreat > 60 {
            chance += 10
        }

        // Decrease if harmony is very low (family avoiding you)
        if family.familyHarmony < 20 {
            chance -= 15
        }

        return Int.random(in: 1...100) <= chance
    }

    // MARK: - Generate Scene

    /// Generate a domestic scene based on current situation
    func generateScene(family: PlayerFamily, game: Game) -> DomesticScene {
        // Select scene type based on context
        let sceneType = selectSceneType(family: family, game: game)

        // Generate the scene
        let scene = createScene(type: sceneType, family: family, game: game)

        domesticLogger.info("Generated domestic scene: \(sceneType.rawValue)")

        return scene
    }

    private func selectSceneType(family: PlayerFamily, game: Game) -> DomesticSceneType {
        var weights: [DomesticSceneType: Int] = [:]

        for type in DomesticSceneType.allCases {
            weights[type] = type.frequency
        }

        // Contextual adjustments
        if game.stability < 40 {
            weights[.tenseSilence, default: 0] += 15
            weights[.neighborGone, default: 0] += 10
            weights[.spouseConcerns, default: 0] += 10
        }

        if family.familyHarmony >= 70 {
            weights[.celebration, default: 0] += 10
            weights[.familyDinner, default: 0] += 10
        }

        if family.familyHarmony < 30 {
            weights[.tenseSilence, default: 0] += 15
            weights[.familyWorries, default: 0] += 10
            weights[.quietEvening, default: 0] -= 10
        }

        if game.rivalThreat > 70 {
            weights[.lateNightVisitor, default: 0] += 15
            weights[.spouseConcerns, default: 0] += 10
        }

        if family.children.isEmpty == false {
            weights[.childsReport, default: 0] += 10
            weights[.familyDinner, default: 0] += 5
        }

        // Weighted random selection
        let totalWeight = weights.values.reduce(0, +)
        var roll = Int.random(in: 1...max(totalWeight, 1))

        for (type, weight) in weights {
            roll -= weight
            if roll <= 0 {
                return type
            }
        }

        return .quietEvening
    }

    private func createScene(type: DomesticSceneType, family: PlayerFamily, game: Game) -> DomesticScene {
        let spouse = family.spouse
        let children = family.children

        switch type {
        case .quietEvening:
            return createQuietEveningScene(family: family, spouse: spouse, game: game)

        case .familyDinner:
            return createFamilyDinnerScene(family: family, children: children, game: game)

        case .spouseConcerns:
            return createSpouseConcernsScene(family: family, spouse: spouse, game: game)

        case .childsReport:
            return createChildsReportScene(family: family, children: children, game: game)

        case .lateNightVisitor:
            return createLateNightVisitorScene(family: family, game: game)

        case .tenseSilence:
            return createTenseSilenceScene(family: family, spouse: spouse, game: game)

        case .celebration:
            return createCelebrationScene(family: family, game: game)

        case .familyWorries:
            return createFamilyWorriesScene(family: family, spouse: spouse, game: game)

        case .neighborGone:
            return createNeighborGoneScene(family: family, spouse: spouse, game: game)
        }
    }

    // MARK: - Scene Generators

    private func createQuietEveningScene(family: PlayerFamily, spouse: PlayerFamilyMember?, game: Game) -> DomesticScene {
        let spouseName = spouse?.name ?? "your spouse"

        let narratives = [
            "The apartment is quiet except for the radio playing the evening news. \"Production quotas exceeded again,\" the announcer declares. \(spouseName) hands you tea, and for a moment, the weight of the day lifts. Outside, the city hums with a million invisible struggles.",

            "State radio fills the silence with revolutionary songs. \(spouseName) sits beside you, reading—or pretending to read. Neither of you speaks. There's a strange comfort in shared silence, in knowing that some things cannot be said aloud.",

            "The children are asleep. \(spouseName) dims the lights and joins you by the window. The Capital stretches below, a sea of apartment blocks and watchful eyes. \"Another day survived,\" \(spouseName) murmurs. You nod, not trusting yourself to speak."
        ]

        return DomesticScene(
            type: .quietEvening,
            title: "A Quiet Evening",
            narrative: narratives.randomElement() ?? narratives[0],
            turnOccurred: game.turnNumber,
            harmonyChange: 5,
            involvedMemberId: spouse?.id,
            involvedMemberName: spouse?.name
        )
    }

    private func createFamilyDinnerScene(family: PlayerFamily, children: [PlayerFamilyMember], game: Game) -> DomesticScene {
        guard let child = children.first else {
            return createQuietEveningScene(family: family, spouse: family.spouse, game: game)
        }

        let narratives = [
            "At dinner, \(child.name) excitedly recounts the day's lessons from the Young Pioneers. \"Teacher says we must always be vigilant against counter-revolutionary elements,\" they announce, looking at you expectantly. You feel the weight of your spouse's gaze across the table.",

            "\(child.name) has learned a new revolutionary song and insists on performing it for the family. The enthusiasm is genuine, the ideology carefully learned. You wonder what else they are learning about loyalty, about reporting, about family.",

            "\"We wrote letters to the General Secretary today,\" \(child.name) announces proudly at dinner. \"I wrote about how hard our family works for the revolution.\" Your spoon pauses halfway to your mouth. What exactly did they write?"
        ]

        return DomesticScene(
            type: .familyDinner,
            title: "Family Dinner",
            narrative: narratives.randomElement() ?? narratives[0],
            turnOccurred: game.turnNumber,
            harmonyChange: family.familyHarmony > 50 ? 3 : -2,
            involvedMemberId: child.id,
            involvedMemberName: child.name,
            hasChoice: true,
            choicePrompt: "How do you respond?",
            choices: [
                DomesticChoice(
                    text: "Praise their enthusiasm for the revolution",
                    harmonyEffect: 2,
                    consequence: "\(child.name) beams with pride. Your spouse relaxes slightly."
                ),
                DomesticChoice(
                    text: "Gently remind them that some things are family matters",
                    harmonyEffect: 0,
                    riskEffect: "May teach discretion",
                    consequence: "\(child.name) looks confused but nods. A lesson in survival, perhaps."
                ),
                DomesticChoice(
                    text: "Say nothing and change the subject",
                    harmonyEffect: -1,
                    consequence: "The moment passes. You wonder what they will share next time."
                )
            ]
        )
    }

    private func createSpouseConcernsScene(family: PlayerFamily, spouse: PlayerFamilyMember?, game: Game) -> DomesticScene {
        let spouseName = spouse?.name ?? "your spouse"

        let concerns = [
            "\(spouseName) waits until the children are asleep. \"Comrade Chen's wife hasn't been seen in three days,\" they whisper. \"Her husband won't speak of it. Their curtains stay drawn.\" The implication hangs in the air like smoke.",

            "\"Did you hear about the reorganization at the Ministry?\" \(spouseName) asks quietly. \"Three of Minister Liu's closest associates were transferred to the provinces yesterday. No farewell, no explanation.\" Their eyes search yours for reaction.",

            "\(spouseName) pulls you aside. \"The neighborhood committee chairwoman asked about your schedule today. When you leave, when you return, who visits.\" A pause. \"She's never asked before.\""
        ]

        return DomesticScene(
            type: .spouseConcerns,
            title: "Spouse's Concerns",
            narrative: concerns.randomElement() ?? concerns[0],
            turnOccurred: game.turnNumber,
            warningGiven: true,
            involvedMemberId: spouse?.id,
            involvedMemberName: spouse?.name
        )
    }

    private func createChildsReportScene(family: PlayerFamily, children: [PlayerFamilyMember], game: Game) -> DomesticScene {
        guard let child = children.first else {
            return createQuietEveningScene(family: family, spouse: family.spouse, game: game)
        }

        let reveals = [
            "\(child.name) mentions casually at breakfast: \"My teacher asked what Papa talks about at dinner. I told her you discuss work a lot.\" An innocent statement. But what exactly counts as 'work' in a child's understanding?",

            "\"Auntie from downstairs asked me if any strangers visit our apartment,\" \(child.name) reports while playing. \"I told her only people from Papa's office sometimes.\" You exchange a glance with your spouse. Who is asking? And why?",

            "\(child.name) returns from school troubled. \"My classmate's father was taken away. They said he was a bad person. But \(child.name) looks at you with uncertainty, \"he always seemed nice to me.\" How do you explain the world to a child?"
        ]

        return DomesticScene(
            type: .childsReport,
            title: "Child's Report",
            narrative: reveals.randomElement() ?? reveals[0],
            turnOccurred: game.turnNumber,
            riskRevealed: true,
            involvedMemberId: child.id,
            involvedMemberName: child.name,
            hasChoice: true,
            choicePrompt: "This requires attention.",
            choices: [
                DomesticChoice(
                    text: "Teach them to be more careful about what they share",
                    harmonyEffect: -2,
                    riskEffect: "Child becomes more guarded",
                    consequence: "\(child.name) seems hurt but nods. They understand, perhaps, that trust is complicated."
                ),
                DomesticChoice(
                    text: "Reassure them that everything is fine",
                    harmonyEffect: 3,
                    consequence: "\(child.name) smiles, reassured. Whether this is wise, only time will tell."
                ),
                DomesticChoice(
                    text: "Discuss it privately with your spouse later",
                    harmonyEffect: 0,
                    consequence: "The conversation continues later, in whispers, when little ears are asleep."
                )
            ]
        )
    }

    private func createLateNightVisitorScene(family: PlayerFamily, game: Game) -> DomesticScene {
        let visitors = [
            ("A subordinate from your department appears at the door, looking nervous. \"I'm sorry to disturb you at home, Comrade, but there's something you should know before tomorrow's meeting.\" Behind you, the apartment falls silent as your family waits.",

             true),

            ("The knock comes just as you're preparing for bed. Two men in plain clothes stand in the hallway. \"Just a routine security check,\" one says with a thin smile. \"We won't be long.\" Your spouse grips your arm.",

             false),

            ("An old colleague, someone you haven't seen in months, appears at your door. They look haggard, desperate. \"I need your help,\" they whisper. \"They're coming for me. I have nowhere else to go.\" Do you let them in?",

             true)
        ]

        guard let (narrative, hasChoice) = visitors.randomElement() else {
            return DomesticScene(
                type: .lateNightVisitor,
                title: "Late Night Visitor",
                narrative: "A knock at the door late at night. Your family tenses.",
                turnOccurred: game.turnNumber,
                harmonyChange: -5
            )
        }

        var scene = DomesticScene(
            type: .lateNightVisitor,
            title: "Late Night Visitor",
            narrative: narrative,
            turnOccurred: game.turnNumber,
            harmonyChange: -5
        )

        if hasChoice && narrative.contains("old colleague") {
            scene.hasChoice = true
            scene.choicePrompt = "What do you do?"
            scene.choices = [
                DomesticChoice(
                    text: "Let them in, offer what help you can",
                    harmonyEffect: -3,
                    riskEffect: "Association with a fugitive is dangerous",
                    consequence: "You pull them inside quickly. Your spouse watches in silence. This will have consequences."
                ),
                DomesticChoice(
                    text: "Turn them away - it's too dangerous",
                    harmonyEffect: 0,
                    consequence: "Their face falls. They nod once, understanding, and disappear into the night. You close the door on an old friendship."
                ),
                DomesticChoice(
                    text: "Give them money for a train ticket and send them away",
                    harmonyEffect: -1,
                    riskEffect: "A compromise that may satisfy no one",
                    consequence: "They take the money gratefully and vanish. You may never know what became of them."
                )
            ]
        }

        return scene
    }

    private func createTenseSilenceScene(family: PlayerFamily, spouse: PlayerFamilyMember?, game: Game) -> DomesticScene {
        let spouseName = spouse?.name ?? "your spouse"

        let silences = [
            "Tonight, words feel dangerous. \(spouseName) busies themselves with household tasks, avoiding your eyes. The children sense the tension and retreat to their rooms. You sit with papers you can't focus on. The walls, you both know, have ears.",

            "You want to tell \(spouseName) about the meeting, about the accusations leveled at your colleague, about the fear that wrapped around your throat. But you say nothing. In this apartment, in this building, in this city, silence is safety.",

            "\(spouseName) starts to speak several times, then stops. You recognize the look—there's something they want to say but cannot. Perhaps about the car that's been parked on your street. Perhaps about the new neighbors who ask too many questions. The unsaid fills the room like smoke."
        ]

        return DomesticScene(
            type: .tenseSilence,
            title: "Tense Silence",
            narrative: silences.randomElement() ?? silences[0],
            turnOccurred: game.turnNumber,
            harmonyChange: -3,
            involvedMemberId: spouse?.id,
            involvedMemberName: spouse?.name
        )
    }

    private func createCelebrationScene(family: PlayerFamily, game: Game) -> DomesticScene {
        let celebrations = [
            "A rare evening of genuine happiness. Your youngest received a commendation at school. State wine is poured—not the good stuff, that's hidden—and for one night, the family pretends the world outside doesn't exist.",

            "It's the anniversary of your wedding. \(family.spouse?.name ?? "Your spouse") has managed to find real meat for dinner, a small miracle. The children are permitted to stay up late. For a few hours, you remember why this life is worth living.",

            "News of your promotion arrives officially. The family celebrates cautiously—too much joy might attract attention—but there's warmth in the apartment tonight. \(family.spouse?.name ?? "Your spouse") squeezes your hand under the table."
        ]

        return DomesticScene(
            type: .celebration,
            title: "Family Celebration",
            narrative: celebrations.randomElement() ?? celebrations[0],
            turnOccurred: game.turnNumber,
            harmonyChange: 10
        )
    }

    private func createFamilyWorriesScene(family: PlayerFamily, spouse: PlayerFamilyMember?, game: Game) -> DomesticScene {
        let spouseName = spouse?.name ?? "your spouse"

        let worries: String
        if family.familyUnderPressure {
            worries = "\(spouseName) breaks down tonight. \"They came to my work unit again,\" they confess. \"Asking questions. About you. About us. About our friends.\" The pressure is mounting, and you can see it taking its toll."
        } else if family.familyHarmony < 40 {
            worries = "\"Do you even notice us anymore?\" \(spouseName) asks quietly. \"The children ask where you are. I make excuses.\" The accusation hangs in the air. Politics has consumed you, and your family is paying the price."
        } else {
            worries = "\(spouseName) sits you down after the children are asleep. \"I'm worried about your health,\" they say. \"The late nights, the stress. This life is wearing you down.\" For once, the concern is personal, not political."
        }

        return DomesticScene(
            type: .familyWorries,
            title: "Family Worries",
            narrative: worries,
            turnOccurred: game.turnNumber,
            harmonyChange: family.familyHarmony < 40 ? -5 : 0,
            involvedMemberId: spouse?.id,
            involvedMemberName: spouse?.name,
            hasChoice: family.familyHarmony < 40,
            choicePrompt: family.familyHarmony < 40 ? "Your spouse needs reassurance." : nil,
            choices: family.familyHarmony < 40 ? [
                DomesticChoice(
                    text: "Promise to make more time for the family",
                    harmonyEffect: 8,
                    consequence: "You both know the promise may be empty, but the gesture matters."
                ),
                DomesticChoice(
                    text: "Explain that the work is for their protection",
                    harmonyEffect: 2,
                    consequence: "\(spouseName) nods, not quite believing. But they accept."
                ),
                DomesticChoice(
                    text: "Say nothing - there's nothing to say",
                    harmonyEffect: -5,
                    consequence: "The distance grows. Some chasms cannot be bridged with words."
                )
            ] : nil
        )
    }

    private func createNeighborGoneScene(family: PlayerFamily, spouse: PlayerFamilyMember?, game: Game) -> DomesticScene {
        let spouseName = spouse?.name ?? "your spouse"

        let disappearances = [
            "The apartment next door is empty. The Zhangs lived there for fifteen years. This morning, they were gone—furniture and all—with only a notice on the door: \"Relocated for state purposes.\" \(spouseName) says nothing. You both know not to ask questions.",

            "Old Comrade Wu from the third floor hasn't been seen in a week. His mail piles up outside his door. The building committee chairwoman smiles when asked and says he's \"visiting family.\" But everyone knows Wu had no family left.",

            "\(spouseName) returns from the market ashen-faced. \"They took the grocer,\" they whisper. \"Right there in his shop. His wife was screaming.\" You hold each other in the kitchen, grateful for another day together."
        ]

        return DomesticScene(
            type: .neighborGone,
            title: "The Empty Apartment",
            narrative: disappearances.randomElement() ?? disappearances[0],
            turnOccurred: game.turnNumber,
            harmonyChange: -3,
            warningGiven: true,
            involvedMemberId: spouse?.id,
            involvedMemberName: spouse?.name
        )
    }

    // MARK: - Apply Scene Effects

    /// Apply the effects of a domestic scene to the family
    func applySceneEffects(scene: DomesticScene, selectedChoice: DomesticChoice?, family: PlayerFamily) {
        var harmonyChange = scene.harmonyChange

        if let choice = selectedChoice {
            harmonyChange += choice.harmonyEffect
        }

        if harmonyChange > 0 {
            family.improveHarmony(amount: harmonyChange)
        } else if harmonyChange < 0 {
            family.damageHarmony(amount: abs(harmonyChange))
        }

        family.lastDomesticSceneTurn = scene.turnOccurred
    }
}
