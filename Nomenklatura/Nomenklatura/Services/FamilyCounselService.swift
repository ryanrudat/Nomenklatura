//
//  FamilyCounselService.swift
//  Nomenklatura
//
//  Service for generating spouse counsel before important decisions.
//  Counsel quality is based on marriage type AND harmony:
//
//  | Marriage Type | Low Harmony | High Harmony |
//  |---------------|-------------|--------------|
//  | Political     | Calculated  | Strategic    |
//  | Love          | Hurt silence| True insight |
//  | Arranged      | Bitter      | Grudging     |
//
//  - Informant Risk: If spouse is under BPS pressure + low harmony,
//    counsel may be a trap
//  - Political Marriage Bonus: +10% accuracy on factional information
//  - Love Marriage Bonus: +10% accuracy on character judgments
//

import Foundation
import os.log

private let counselLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "FamilyCounsel")

// MARK: - Counsel Types

/// The type of advice the spouse can provide
enum CounselType: String, Codable {
    case character     // Insight about an NPC
    case factional     // Information about faction dynamics
    case tactical      // Strategic advice on a decision
    case warning       // Danger alert (may be trap if informant)
    case emotional     // Personal/emotional support
    case silence       // No advice (low harmony or resentment)
}

/// How accurate/reliable the counsel is
enum CounselReliability: String, Codable {
    case trustworthy   // 80%+ chance accurate
    case uncertain     // 50-80% accurate
    case questionable  // 30-50% accurate
    case trap          // Deliberately misleading (informant)

    var accuracyRange: ClosedRange<Int> {
        switch self {
        case .trustworthy: return 80...95
        case .uncertain: return 50...79
        case .questionable: return 30...49
        case .trap: return 0...20
        }
    }
}

// MARK: - Counsel Result

/// The advice provided by the spouse
struct SpouseCounsel: Codable, Identifiable {
    var id: UUID = UUID()
    var type: CounselType
    var reliability: CounselReliability
    var message: String
    var isAccurate: Bool           // Was the advice correct? (determined when evaluated)
    var wasTrap: Bool = false      // Was this deliberately misleading?
    var turnGiven: Int

    // For character/factional counsel
    var targetCharacterId: String?
    var targetFactionId: String?

    /// Visible reliability hint based on marriage harmony
    var reliabilityHint: String {
        switch reliability {
        case .trustworthy:
            return "Your spouse speaks with conviction."
        case .uncertain:
            return "Your spouse seems uncertain."
        case .questionable:
            return "Your spouse hesitates before speaking."
        case .trap:
            return "Your spouse avoids meeting your eyes."
        }
    }
}

// MARK: - Family Counsel Service

@MainActor
class FamilyCounselService {
    static let shared = FamilyCounselService()

    private init() {}

    // MARK: - Generate Counsel

    /// Generate spouse counsel for a decision or situation
    func generateCounsel(
        family: PlayerFamily,
        game: Game,
        context: CounselContext
    ) -> SpouseCounsel? {
        guard family.hasFamily,
              let spouse = family.spouse else {
            return nil
        }

        // Check if spouse will speak at all
        guard shouldSpouseSpeak(family: family, spouse: spouse) else {
            return generateSilence(family: family, spouse: spouse, game: game)
        }

        // Determine counsel type based on context and marriage
        let counselType = determineCounselType(
            family: family,
            spouse: spouse,
            context: context
        )

        // Check for trap (informant spouse with low harmony)
        let isTrap = checkForTrap(family: family, spouse: spouse)

        // Generate the actual counsel
        return generateCounselMessage(
            family: family,
            spouse: spouse,
            type: counselType,
            context: context,
            isTrap: isTrap,
            game: game
        )
    }

    // MARK: - Counsel Logic

    private func shouldSpouseSpeak(family: PlayerFamily, spouse: PlayerFamilyMember) -> Bool {
        // Low harmony may result in silence
        if family.familyHarmony < 20 {
            return Int.random(in: 1...100) <= 30  // Only 30% chance to speak
        }

        // Resentful temperament less likely to help
        if spouse.temperament == .resentful && family.familyHarmony < 50 {
            return Int.random(in: 1...100) <= 40
        }

        // Generally willing to speak
        return true
    }

    private func generateSilence(family: PlayerFamily, spouse: PlayerFamilyMember, game: Game) -> SpouseCounsel {
        let silenceMessages: [String]

        if spouse.temperament == .resentful {
            silenceMessages = [
                "\"\(spouse.name) turns away when you seek their counsel.\"",
                "\"You find \(spouse.name) busy with other matters when you approach.\"",
                "\"The distance between you and \(spouse.name) seems wider than ever.\"",
                "\"\(spouse.name) offers a curt nod but no words of guidance.\""
            ]
        } else if family.familyHarmony < 20 {
            silenceMessages = [
                "\"\(spouse.name) meets your gaze but says nothing.\"",
                "\"The silence in your home is deafening.\"",
                "\"\(spouse.name)'s lips tighten, but they do not speak.\"",
                "\"You sense \(spouse.name) has something to say, but they hold back.\""
            ]
        } else {
            silenceMessages = [
                "\"\(spouse.name) is preoccupied with other matters.\"",
                "\"Tonight is not a night for political discussions.\"",
                "\"\(spouse.name) simply shakes their head.\""
            ]
        }

        return SpouseCounsel(
            type: .silence,
            reliability: .uncertain,
            message: silenceMessages.randomElement() ?? "Silence fills the room.",
            isAccurate: true,
            turnGiven: game.turnNumber
        )
    }

    private func determineCounselType(
        family: PlayerFamily,
        spouse: PlayerFamilyMember,
        context: CounselContext
    ) -> CounselType {
        // Marriage type influences what kind of advice they give
        switch family.marriage {
        case .political:
            // Political spouses are good at factional analysis
            if context.involvesFaction { return .factional }
            if context.involvesCharacter { return .character }
            return .tactical

        case .love:
            // Love marriages give better character insight
            if context.involvesCharacter { return .character }
            if context.isDangerous { return .warning }
            return .emotional

        case .arranged:
            // Arranged marriages are variable
            if spouse.temperament == .ambitious { return .tactical }
            if spouse.temperament == .fearful { return .warning }
            return context.involvesFaction ? .factional : .tactical

        case .none:
            return .silence
        }
    }

    private func checkForTrap(family: PlayerFamily, spouse: PlayerFamilyMember) -> Bool {
        // Trap requires: informant status OR (under pressure + low loyalty + low harmony)
        if spouse.isInformant {
            return true
        }

        if spouse.isUnderPressure &&
           spouse.loyaltyToPlayer < 50 &&
           family.familyHarmony < 40 {
            // May have broken under pressure
            let trapChance = (100 - spouse.loyaltyToPlayer) / 3 +
                            spouse.temperament.informantRisk / 3
            return Int.random(in: 1...100) <= trapChance
        }

        return false
    }

    private func generateCounselMessage(
        family: PlayerFamily,
        spouse: PlayerFamilyMember,
        type: CounselType,
        context: CounselContext,
        isTrap: Bool,
        game: Game
    ) -> SpouseCounsel {
        let reliability = calculateReliability(family: family, spouse: spouse, type: type, isTrap: isTrap)

        // Generate appropriate message
        let (message, isAccurate) = generateMessage(
            family: family,
            spouse: spouse,
            type: type,
            context: context,
            reliability: reliability,
            isTrap: isTrap,
            game: game
        )

        return SpouseCounsel(
            type: type,
            reliability: reliability,
            message: message,
            isAccurate: isAccurate,
            wasTrap: isTrap,
            turnGiven: game.turnNumber,
            targetCharacterId: context.relatedCharacterId,
            targetFactionId: context.relatedFactionId
        )
    }

    private func calculateReliability(
        family: PlayerFamily,
        spouse: PlayerFamilyMember,
        type: CounselType,
        isTrap: Bool
    ) -> CounselReliability {
        if isTrap { return .trap }

        var reliabilityScore = 50

        // Marriage type bonuses
        switch family.marriage {
        case .political:
            if type == .factional { reliabilityScore += 15 }
            reliabilityScore += 10
        case .love:
            if type == .character { reliabilityScore += 20 }
            if type == .warning { reliabilityScore += 10 }
        case .arranged:
            if spouse.temperament == .resentful {
                reliabilityScore -= 10
            }
        case .none:
            return .questionable
        }

        // Harmony modifier
        if family.familyHarmony >= 70 {
            reliabilityScore += 20
        } else if family.familyHarmony >= 50 {
            reliabilityScore += 10
        } else if family.familyHarmony < 30 {
            reliabilityScore -= 15
        }

        // Political awareness modifier
        reliabilityScore += (spouse.politicalAwareness - 50) / 5

        // Temperament modifier
        switch spouse.temperament {
        case .questioning, .cynical:
            reliabilityScore += 5  // More observant
        case .devoted:
            reliabilityScore -= 5  // May overlook negatives
        case .fearful:
            if type == .warning { reliabilityScore += 10 }
        default:
            break
        }

        // Convert score to reliability
        if reliabilityScore >= 75 {
            return .trustworthy
        } else if reliabilityScore >= 50 {
            return .uncertain
        } else {
            return .questionable
        }
    }

    private func generateMessage(
        family: PlayerFamily,
        spouse: PlayerFamilyMember,
        type: CounselType,
        context: CounselContext,
        reliability: CounselReliability,
        isTrap: Bool,
        game: Game
    ) -> (String, Bool) {
        let spouseName = spouse.name

        // Calculate actual accuracy
        let accuracyRoll = Int.random(in: 1...100)
        let isAccurate = accuracyRoll <= reliability.accuracyRange.upperBound

        // Generate message based on type
        switch type {
        case .character:
            return generateCharacterCounsel(
                spouseName: spouseName,
                context: context,
                isAccurate: isAccurate,
                isTrap: isTrap,
                game: game
            )

        case .factional:
            return generateFactionalCounsel(
                spouseName: spouseName,
                context: context,
                isAccurate: isAccurate,
                isTrap: isTrap,
                game: game
            )

        case .tactical:
            return generateTacticalCounsel(
                spouseName: spouseName,
                context: context,
                isAccurate: isAccurate,
                isTrap: isTrap,
                harmony: family.familyHarmony
            )

        case .warning:
            return generateWarningCounsel(
                spouseName: spouseName,
                context: context,
                isAccurate: isAccurate,
                isTrap: isTrap
            )

        case .emotional:
            return generateEmotionalCounsel(
                spouseName: spouseName,
                harmony: family.familyHarmony,
                temperament: spouse.temperament
            )

        case .silence:
            return ("Silence.", true)
        }
    }

    // MARK: - Message Generators

    private func generateCharacterCounsel(
        spouseName: String,
        context: CounselContext,
        isAccurate: Bool,
        isTrap: Bool,
        game: Game
    ) -> (String, Bool) {
        let characterName = context.relatedCharacterName ?? "them"

        if isTrap {
            // Misleading counsel
            let trapMessages = [
                "\"\(spouseName) leans close. 'I've heard \(characterName) is completely loyal to you. You can trust them with anything.'\"",
                "\"\(spouseName) reassures you. '\(characterName) would never betray you. They speak of you with great respect.'\"",
                "\"\(spouseName) dismisses your concerns. '\(characterName) is harmless. They have no ambitions that threaten you.'\""
            ]
            return (trapMessages.randomElement()!, false)
        }

        if isAccurate {
            let accurateMessages = [
                "\"\(spouseName) speaks quietly. 'I've watched \(characterName) at functions. There's something calculating behind their smile.'\"",
                "\"\(spouseName) considers carefully. '\(characterName) seems to be building connections beyond what their position requires.'\"",
                "\"\(spouseName) shares an observation. 'At the last reception, I noticed \(characterName) spent considerable time with your rivals.'\""
            ]
            return (accurateMessages.randomElement()!, true)
        } else {
            let inaccurateMessages = [
                "\"\(spouseName) offers their impression. 'I believe \(characterName) can be trusted.' (Your spouse seems uncertain.)\"",
                "\"\(spouseName) shrugs. 'I've heard nothing concerning about \(characterName), but I have limited insight.'\""
            ]
            return (inaccurateMessages.randomElement()!, false)
        }
    }

    private func generateFactionalCounsel(
        spouseName: String,
        context: CounselContext,
        isAccurate: Bool,
        isTrap: Bool,
        game: Game
    ) -> (String, Bool) {
        let factionName = context.relatedFactionName ?? "the faction"

        if isTrap {
            let trapMessages = [
                "\"\(spouseName) analyzes the situation. '\(factionName) is weakening. Now would be the perfect time to move against them.'\"",
                "\"\(spouseName) shares 'intelligence.' 'I've heard \(factionName) leadership is in disarray. They pose no threat.'\""
            ]
            return (trapMessages.randomElement()!, false)
        }

        if isAccurate {
            let accurateMessages = [
                "\"\(spouseName)'s family connections provide insight. '\(factionName) is positioning for something significant. Their meetings have increased.'\"",
                "\"\(spouseName) shares what they've observed. 'The wives of \(factionName) members have been unusually social lately. Something is being coordinated.'\""
            ]
            return (accurateMessages.randomElement()!, true)
        } else {
            let inaccurateMessages = [
                "\"\(spouseName) offers limited insight. 'I've heard little about \(factionName) lately. Perhaps they are quiet.'\"",
                "\"\(spouseName) admits uncertainty. 'The dynamics of \(factionName) are unclear to me.'\""
            ]
            return (inaccurateMessages.randomElement()!, false)
        }
    }

    private func generateTacticalCounsel(
        spouseName: String,
        context: CounselContext,
        isAccurate: Bool,
        isTrap: Bool,
        harmony: Int
    ) -> (String, Bool) {
        if isTrap {
            let trapMessages = [
                "\"\(spouseName) advises confidently. 'Act boldly now. Your position is stronger than you think.'\"",
                "\"\(spouseName) encourages action. 'Hesitation will be seen as weakness. Move decisively.'\""
            ]
            return (trapMessages.randomElement()!, false)
        }

        if harmony >= 60 {
            // Strategic partnership - good advice
            if isAccurate {
                let strategicMessages = [
                    "\"\(spouseName) studies the situation. 'Consider who benefits if you act, and who benefits if you don't. Sometimes inaction is the strongest move.'\"",
                    "\"\(spouseName) offers strategic counsel. 'Your rivals expect you to react predictably. Perhaps it's time to surprise them.'\""
                ]
                return (strategicMessages.randomElement()!, true)
            }
        }

        // Standard tactical advice
        let tacticalMessages = [
            "\"\(spouseName) weighs in. 'Proceed carefully. The stakes seem higher than they appear.'\"",
            "\"\(spouseName) offers their view. 'Whatever you decide, ensure you have allies who will stand with you.'\""
        ]
        return (tacticalMessages.randomElement()!, isAccurate)
    }

    private func generateWarningCounsel(
        spouseName: String,
        context: CounselContext,
        isAccurate: Bool,
        isTrap: Bool
    ) -> (String, Bool) {
        if isTrap {
            let trapMessages = [
                "\"\(spouseName) dismisses your worries. 'You're seeing shadows where there are none. Everything is fine.'\"",
                "\"\(spouseName) reassures you falsely. 'I've heard nothing concerning. Your position is secure.'\""
            ]
            return (trapMessages.randomElement()!, false)
        }

        if isAccurate {
            let warningMessages = [
                "\"\(spouseName) grips your arm. 'Something isn't right. I sense danger, though I cannot name it.'\"",
                "\"\(spouseName) speaks with urgency. 'Be careful who you trust in the coming days. The mood has shifted.'\"",
                "\"\(spouseName) whispers. 'I've noticed unfamiliar cars on our street. Someone is watching.'\""
            ]
            return (warningMessages.randomElement()!, true)
        } else {
            let falseAlarmMessages = [
                "\"\(spouseName) seems agitated. 'I worry for your safety, though perhaps I am being paranoid.'\"",
                "\"\(spouseName) expresses concern that may be unfounded. 'Something feels wrong, but I have no evidence.'\""
            ]
            return (falseAlarmMessages.randomElement()!, false)
        }
    }

    private func generateEmotionalCounsel(
        spouseName: String,
        harmony: Int,
        temperament: FamilyTemperament
    ) -> (String, Bool) {
        if harmony >= 70 {
            let supportiveMessages = [
                "\"\(spouseName) places a hand on yours. 'Whatever happens, we face it together.'\"",
                "\"\(spouseName) speaks softly. 'You carry so much weight. Remember that I am here.'\"",
                "\"\(spouseName) meets your eyes. 'I believe in you. I always have.'\""
            ]
            return (supportiveMessages.randomElement()!, true)
        } else if harmony >= 40 {
            let mixedMessages = [
                "\"\(spouseName) offers a tired smile. 'Do what you must. I will manage.'\"",
                "\"\(spouseName) sighs. 'We've survived this long. We'll survive this too.'\""
            ]
            return (mixedMessages.randomElement()!, true)
        } else {
            let strainedMessages = [
                "\"\(spouseName) looks away. 'I'm sure you'll do what you think is best. You always do.'\"",
                "\"\(spouseName) says nothing but their expression speaks volumes.\""
            ]
            return (strainedMessages.randomElement()!, true)
        }
    }
}

// MARK: - Counsel Context

/// Context for generating appropriate counsel
struct CounselContext {
    var involvesCharacter: Bool = false
    var involvesFaction: Bool = false
    var isDangerous: Bool = false
    var isDecision: Bool = false

    var relatedCharacterId: String?
    var relatedCharacterName: String?
    var relatedFactionId: String?
    var relatedFactionName: String?

    var decisionTitle: String?

    static func character(_ name: String, id: String) -> CounselContext {
        var context = CounselContext()
        context.involvesCharacter = true
        context.relatedCharacterId = id
        context.relatedCharacterName = name
        return context
    }

    static func faction(_ name: String, id: String) -> CounselContext {
        var context = CounselContext()
        context.involvesFaction = true
        context.relatedFactionId = id
        context.relatedFactionName = name
        return context
    }

    static func danger() -> CounselContext {
        var context = CounselContext()
        context.isDangerous = true
        return context
    }

    static func decision(_ title: String) -> CounselContext {
        var context = CounselContext()
        context.isDecision = true
        context.decisionTitle = title
        return context
    }
}
