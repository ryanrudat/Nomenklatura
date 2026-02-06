//
//  NPCWorldActionService.swift
//  Nomenklatura
//
//  Generates visible NPC-to-NPC interaction events that make the political world
//  feel alive. These events are visible to the player based on the layered
//  visibility system (Network stat determines what level of intrigue is revealed).
//
//  Event Categories:
//  - Grudge-driven actions (attacks, accusations, sabotage)
//  - Alliance formation and betrayal
//  - Position competition
//  - Faction maneuvering
//  - Mentor/protégé actions
//

import Foundation
import os.log

private let worldActionLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "NPCWorldActions")

// MARK: - NPC World Action Service

@MainActor
class NPCWorldActionService {
    static let shared = NPCWorldActionService()

    private init() {}

    // MARK: - Visibility Thresholds (shared with NPCLifeEventsService)

    private struct VisibilityThresholds {
        static let rumor = 30
        static let intel = 50
        static let secret = 70
    }

    // MARK: - Main Processing

    /// Process NPC-to-NPC world actions each turn
    /// Returns events visible to the player based on their Network stat
    func processWorldActions(game: Game) -> [NPCWorldActionResult] {
        var results: [NPCWorldActionResult] = []

        // Only process after early game
        guard game.turnNumber > 2 else { return [] }

        // Check for various NPC-to-NPC interactions

        // 1. Grudge-driven actions (NPCs attacking each other)
        if let grudgeEvent = checkGrudgeActions(game: game) {
            if shouldPlayerSeeEvent(event: grudgeEvent, game: game) {
                results.append(grudgeEvent)
            }
            applyWorldActionEffects(event: grudgeEvent, game: game)
        }

        // 2. Alliance formation or betrayal
        if let allianceEvent = checkAllianceEvents(game: game) {
            if shouldPlayerSeeEvent(event: allianceEvent, game: game) {
                results.append(allianceEvent)
            }
            applyWorldActionEffects(event: allianceEvent, game: game)
        }

        // 3. Position competition
        if let competitionEvent = checkPositionCompetition(game: game) {
            if shouldPlayerSeeEvent(event: competitionEvent, game: game) {
                results.append(competitionEvent)
            }
            applyWorldActionEffects(event: competitionEvent, game: game)
        }

        // 4. Faction maneuvering
        if let factionEvent = checkFactionManeuvering(game: game) {
            if shouldPlayerSeeEvent(event: factionEvent, game: game) {
                results.append(factionEvent)
            }
        }

        // 5. Mentor/protégé actions
        if let patronageEvent = checkPatronageActions(game: game) {
            if shouldPlayerSeeEvent(event: patronageEvent, game: game) {
                results.append(patronageEvent)
            }
            applyWorldActionEffects(event: patronageEvent, game: game)
        }

        // Limit to 1-2 events per turn (avoid overwhelming)
        let limitedResults = Array(results.shuffled().prefix(2))

        // Log visible events to journal
        for event in limitedResults {
            addEventToJournal(event: event, game: game)
        }

        return limitedResults
    }

    private func shouldPlayerSeeEvent(event: NPCWorldActionResult, game: Game) -> Bool {
        switch event.visibilityLevel {
        case .public:
            return true
        case .rumor:
            return game.network >= VisibilityThresholds.rumor
        case .intel:
            return game.network >= VisibilityThresholds.intel
        case .secret:
            return game.network >= VisibilityThresholds.secret
        }
    }

    // MARK: - Grudge-Driven Actions

    private func checkGrudgeActions(game: Game) -> NPCWorldActionResult? {
        // Find NPCs with high grudges against other NPCs
        let grudgeRelationships = game.npcRelationships.filter { rel in
            rel.grudgeLevel >= 60 && rel.disposition < -30
        }

        guard !grudgeRelationships.isEmpty else { return nil }

        // Low chance per turn (5%)
        guard Int.random(in: 1...100) <= 5 else { return nil }

        // Pick a random grudge relationship
        guard let relationship = grudgeRelationships.randomElement(),
              let attacker = game.characters.first(where: { $0.templateId == relationship.sourceCharacterId && $0.isActive }),
              let target = game.characters.first(where: { $0.templateId == relationship.targetCharacterId && $0.isActive }) else {
            return nil
        }

        // Determine attack type based on attacker's personality
        let attackType = determineAttackType(attacker: attacker, target: target, relationship: relationship)

        return attackType.generateEvent(attacker: attacker, target: target, game: game)
    }

    private func determineAttackType(attacker: GameCharacter, target: GameCharacter, relationship: NPCRelationship) -> GrudgeAttackType {
        // Ruthless attackers go for the throat
        if attacker.personalityRuthless > 70 {
            return [.publicAccusation, .formalComplaint, .sabotage].randomElement()!
        }

        // Ambitious attackers try to benefit politically
        if attacker.personalityAmbitious > 60 {
            return [.publicAccusation, .factionPressure].randomElement()!
        }

        // Paranoid attackers act defensively
        if attacker.personalityParanoid > 60 {
            return [.spreadRumors, .formalComplaint].randomElement()!
        }

        // Default: spread rumors
        return .spreadRumors
    }

    // MARK: - Alliance Events

    private func checkAllianceEvents(game: Game) -> NPCWorldActionResult? {
        // 3% chance per turn
        guard Int.random(in: 1...100) <= 3 else { return nil }

        // Check for alliance formation (shared enemies create alliances)
        if let formationEvent = checkAllianceFormation(game: game) {
            return formationEvent
        }

        // Check for alliance betrayal
        if let betrayalEvent = checkAllianceBetrayal(game: game) {
            return betrayalEvent
        }

        return nil
    }

    private func checkAllianceFormation(game: Game) -> NPCWorldActionResult? {
        // Find pairs of NPCs who share a common enemy
        let activeNPCs = game.characters.filter { $0.isActive && !$0.isPatron }

        for npc1 in activeNPCs {
            for npc2 in activeNPCs where npc1.id != npc2.id {
                // Check if they share a common enemy
                let npc1Enemies = game.npcRelationships.filter {
                    $0.sourceCharacterId == npc1.templateId && $0.isRival
                }.map { $0.targetCharacterId }

                let npc2Enemies = game.npcRelationships.filter {
                    $0.sourceCharacterId == npc2.templateId && $0.isRival
                }.map { $0.targetCharacterId }

                let commonEnemies = Set(npc1Enemies).intersection(Set(npc2Enemies))

                if !commonEnemies.isEmpty {
                    // Check if they're not already allied
                    let existingRelation = game.npcRelationships.first {
                        $0.sourceCharacterId == npc1.templateId && $0.targetCharacterId == npc2.templateId
                    }

                    if existingRelation?.isAllied != true && (existingRelation?.disposition ?? 0) > 0 {
                        // Form alliance
                        if let commonEnemyId = commonEnemies.first,
                           let commonEnemy = game.characters.first(where: { $0.templateId == commonEnemyId }) {
                            return NPCWorldActionResult(
                                eventType: .allianceFormed,
                                headline: "\(npc1.name) and \(npc2.name) Growing Closer",
                                details: "Whispers suggest that \(npc1.name) and \(npc2.name) have been seen conferring frequently. Both share a mutual distrust of \(commonEnemy.name), and appear to be coordinating their positions.",
                                visibilityLevel: .rumor,
                                involvedCharacters: [npc1, npc2],
                                targetCharacter: commonEnemy
                            )
                        }
                    }
                }
            }
        }

        return nil
    }

    private func checkAllianceBetrayal(game: Game) -> NPCWorldActionResult? {
        // Find existing alliances
        let alliances = game.npcRelationships.filter { $0.isAllied && $0.allianceStrength < 40 }

        guard let weakAlliance = alliances.randomElement(),
              let betrayer = game.characters.first(where: { $0.templateId == weakAlliance.sourceCharacterId && $0.isActive }),
              let victim = game.characters.first(where: { $0.templateId == weakAlliance.targetCharacterId && $0.isActive }) else {
            return nil
        }

        // Ambitious and low-loyalty characters are more likely to betray
        // Range: 0-100, where 100 = max ambitious + min loyal, 0 = min ambitious + max loyal
        let betrayalChance = (betrayer.personalityAmbitious + (100 - betrayer.personalityLoyal)) / 2
        guard Int.random(in: 1...100) <= betrayalChance else { return nil }

        return NPCWorldActionResult(
            eventType: .allianceBetrayed,
            headline: "\(betrayer.name) Distances from \(victim.name)",
            details: "Your sources report that \(betrayer.name) has been distancing themselves from their former ally \(victim.name). In a recent meeting, \(betrayer.name) notably failed to support \(victim.name)'s position, causing visible tension.",
            visibilityLevel: .intel,
            involvedCharacters: [betrayer, victim]
        )
    }

    // MARK: - Position Competition

    private func checkPositionCompetition(game: Game) -> NPCWorldActionResult? {
        // 4% chance per turn
        guard Int.random(in: 1...100) <= 4 else { return nil }

        // Find NPCs with seekPromotion goal at similar position levels
        let promotionSeekers = game.characters.filter { character in
            character.isActive &&
            character.primaryGoal?.goalType == .seekPromotion &&
            (character.positionIndex ?? 0) >= 3  // Mid-level or higher
        }

        guard promotionSeekers.count >= 2 else { return nil }

        // Find two at similar levels
        for seeker1 in promotionSeekers {
            for seeker2 in promotionSeekers where seeker1.id != seeker2.id {
                let level1 = seeker1.positionIndex ?? 0
                let level2 = seeker2.positionIndex ?? 0

                if abs(level1 - level2) <= 1 {
                    // They're competing for similar positions
                    return NPCWorldActionResult(
                        eventType: .positionCompetition,
                        headline: "Tensions Between \(seeker1.name) and \(seeker2.name)",
                        details: "Competition for advancement has created visible friction between \(seeker1.name) and \(seeker2.name). Both are reportedly lobbying senior figures for the same upcoming vacancy, and their once-cordial relations have cooled noticeably.",
                        visibilityLevel: .rumor,
                        involvedCharacters: [seeker1, seeker2]
                    )
                }
            }
        }

        return nil
    }

    // MARK: - Faction Maneuvering

    private func checkFactionManeuvering(game: Game) -> NPCWorldActionResult? {
        // 3% chance per turn
        guard Int.random(in: 1...100) <= 3 else { return nil }

        // Find factions with significant power differences
        let factions = game.factions.filter { $0.power > 20 }
        guard factions.count >= 2 else { return nil }

        let strongestFaction = factions.max(by: { $0.power < $1.power })
        let challengerFaction = factions.filter { $0.id != strongestFaction?.id }.randomElement()

        guard let dominant = strongestFaction, let challenger = challengerFaction else { return nil }

        // Determine type of maneuvering
        let maneuverTypes: [(String, String, WorldActionVisibilityLevel)] = [
            ("Faction Pressure",
             "The \(challenger.name) faction is reportedly organizing to challenge \(dominant.name) faction policies. Informal caucuses have been observed, and a coordinated initiative may be forthcoming.",
             .intel),
            ("Ideological Clash",
             "Tensions between the \(dominant.name) and \(challenger.name) factions have surfaced publicly. Competing editorials in Party publications suggest a deeper struggle over ideological direction.",
             .public),
            ("Backroom Negotiations",
             "Your sources report secret negotiations between \(dominant.name) and \(challenger.name) faction leaders. The subject remains unclear, but something significant appears to be in motion.",
             .secret),
            ("Factional Recruitment",
             "The \(challenger.name) faction appears to be actively recruiting wavering members from other factions, promising advancement in exchange for loyalty.",
             .rumor)
        ]

        let maneuver = maneuverTypes.randomElement()!

        return NPCWorldActionResult(
            eventType: .factionManeuvering,
            headline: maneuver.0,
            details: maneuver.1,
            visibilityLevel: maneuver.2,
            involvedFactions: [dominant, challenger]
        )
    }

    // MARK: - Patronage Actions

    private func checkPatronageActions(game: Game) -> NPCWorldActionResult? {
        // 3% chance per turn
        guard Int.random(in: 1...100) <= 3 else { return nil }

        // Find patron-client relationships
        let patronRelations = game.npcRelationships.filter { $0.isPatron }

        guard let relation = patronRelations.randomElement(),
              let patron = game.characters.first(where: { $0.templateId == relation.sourceCharacterId && $0.isActive }),
              let client = game.characters.first(where: { $0.templateId == relation.targetCharacterId && $0.isActive }) else {
            return nil
        }

        // Determine action type
        let actionTypes: [(NPCWorldActionType, String, String, WorldActionVisibilityLevel)] = [
            (.protégéElevation,
             "\(patron.name) Advancing \(client.name)",
             "\(patron.name) has been observed actively promoting \(client.name) in meetings and informal gatherings. It appears \(client.name) is being groomed for greater responsibilities.",
             .rumor),
            (.protégéDefense,
             "\(patron.name) Shields \(client.name)",
             "When criticism arose of \(client.name)'s performance, \(patron.name) intervened decisively, redirecting blame and defending their protégé. Their patronage remains strong.",
             .intel),
            (.patronDemand,
             "\(patron.name) Pressures \(client.name)",
             "Your sources suggest \(patron.name) has made significant demands of \(client.name), testing their loyalty. The nature of the request remains unclear, but \(client.name) appears stressed.",
             .secret)
        ]

        let action = actionTypes.randomElement()!

        return NPCWorldActionResult(
            eventType: action.0,
            headline: action.1,
            details: action.2,
            visibilityLevel: action.3,
            involvedCharacters: [patron, client]
        )
    }

    // MARK: - Effect Application

    private func applyWorldActionEffects(event: NPCWorldActionResult, game: Game) {
        switch event.eventType {
        case .grudgeAttack:
            // Attacked character loses disposition
            if let target = event.targetCharacter {
                target.disposition = max(-100, target.disposition - 10)
            }
            // Attacker's grudge is reduced (vented)
            if let attacker = event.involvedCharacters.first,
               let target = event.targetCharacter,
               let relationship = game.npcRelationships.first(where: {
                   $0.sourceCharacterId == attacker.templateId && $0.targetCharacterId == target.templateId
               }) {
                relationship.grudgeLevel = max(0, relationship.grudgeLevel - 20)
            }

        case .allianceFormed:
            // Update relationship to allied
            if event.involvedCharacters.count >= 2 {
                let npc1 = event.involvedCharacters[0]
                let npc2 = event.involvedCharacters[1]
                if let rel = game.npcRelationships.first(where: {
                    $0.sourceCharacterId == npc1.templateId && $0.targetCharacterId == npc2.templateId
                }) {
                    rel.isAllied = true
                    rel.allianceStrength = 50
                    rel.allianceFormedTurn = game.turnNumber
                }
            }

        case .allianceBetrayed:
            // Update relationship - alliance broken
            if event.involvedCharacters.count >= 2 {
                let betrayer = event.involvedCharacters[0]
                let victim = event.involvedCharacters[1]
                if let rel = game.npcRelationships.first(where: {
                    $0.sourceCharacterId == betrayer.templateId && $0.targetCharacterId == victim.templateId
                }) {
                    rel.isAllied = false
                    rel.allianceStrength = 0
                }
                // Victim gains grudge against betrayer
                if let reverseRel = game.npcRelationships.first(where: {
                    $0.sourceCharacterId == victim.templateId && $0.targetCharacterId == betrayer.templateId
                }) {
                    reverseRel.grudgeLevel = min(100, reverseRel.grudgeLevel + 30)
                    reverseRel.timesBetrayed += 1
                }
            }

        case .positionCompetition:
            // Create/intensify rivalry
            if event.involvedCharacters.count >= 2 {
                let seeker1 = event.involvedCharacters[0]
                let seeker2 = event.involvedCharacters[1]
                if let rel = game.npcRelationships.first(where: {
                    $0.sourceCharacterId == seeker1.templateId && $0.targetCharacterId == seeker2.templateId
                }) {
                    rel.isRival = true
                    rel.disposition = max(-100, rel.disposition - 15)
                }
            }

        default:
            break
        }
    }

    private func addEventToJournal(event: NPCWorldActionResult, game: Game) {
        let category: JournalCategory = {
            switch event.eventType {
            case .grudgeAttack, .positionCompetition:
                return .npcActivity
            case .allianceFormed, .allianceBetrayed:
                return .relationshipChange
            case .factionManeuvering:
                return .factionDiscovery
            case .protégéElevation, .protégéDefense, .patronDemand:
                return .npcActivity
            }
        }()

        let prefix: String = {
            switch event.visibilityLevel {
            case .public:
                return ""
            case .rumor:
                return "Whispers suggest: "
            case .intel:
                return "Your sources report: "
            case .secret:
                return "[CLASSIFIED] "
            }
        }()

        JournalService.shared.addEntry(
            to: game,
            category: category,
            title: prefix + event.headline,
            content: event.details,
            relatedCharacterId: event.involvedCharacters.first?.templateId,
            importance: event.visibilityLevel == .secret ? 8 : 6
        )
    }
}

// MARK: - Supporting Types

struct NPCWorldActionResult {
    let eventType: NPCWorldActionType
    let headline: String
    let details: String
    let visibilityLevel: WorldActionVisibilityLevel
    var involvedCharacters: [GameCharacter] = []
    var targetCharacter: GameCharacter? = nil
    var involvedFactions: [GameFaction] = []
}

/// Visibility levels for world action events
enum WorldActionVisibilityLevel: String, Codable {
    case `public` = "public"
    case rumor = "rumor"
    case intel = "intel"
    case secret = "secret"
}

enum NPCWorldActionType: String, Codable {
    case grudgeAttack = "grudge_attack"
    case allianceFormed = "alliance_formed"
    case allianceBetrayed = "alliance_betrayed"
    case positionCompetition = "position_competition"
    case factionManeuvering = "faction_maneuvering"
    case protégéElevation = "protege_elevation"
    case protégéDefense = "protege_defense"
    case patronDemand = "patron_demand"
}

enum GrudgeAttackType {
    case publicAccusation
    case formalComplaint
    case sabotage
    case spreadRumors
    case factionPressure

    func generateEvent(attacker: GameCharacter, target: GameCharacter, game: Game) -> NPCWorldActionResult {
        switch self {
        case .publicAccusation:
            return NPCWorldActionResult(
                eventType: .grudgeAttack,
                headline: "\(attacker.name) Publicly Accuses \(target.name)",
                details: "In a tense session, \(attacker.name) publicly accused \(target.name) of 'bureaucratic negligence' and 'failure to uphold Party standards.' The accusation drew gasps and careful note-taking from observers.",
                visibilityLevel: .public,
                involvedCharacters: [attacker],
                targetCharacter: target
            )

        case .formalComplaint:
            return NPCWorldActionResult(
                eventType: .grudgeAttack,
                headline: "\(attacker.name) Files Complaint Against \(target.name)",
                details: "Your sources report that \(attacker.name) has filed a formal complaint through Party channels against \(target.name). The specific allegations remain confidential, but the action signals escalating hostility.",
                visibilityLevel: .intel,
                involvedCharacters: [attacker],
                targetCharacter: target
            )

        case .sabotage:
            return NPCWorldActionResult(
                eventType: .grudgeAttack,
                headline: "\(target.name)'s Initiative Mysteriously Fails",
                details: "A project championed by \(target.name) has collapsed due to 'administrative obstacles.' Those close to the situation whisper that \(attacker.name) played a quiet role in its demise.",
                visibilityLevel: .intel,
                involvedCharacters: [attacker],
                targetCharacter: target
            )

        case .spreadRumors:
            return NPCWorldActionResult(
                eventType: .grudgeAttack,
                headline: "Rumors Circulate About \(target.name)",
                details: "Unflattering whispers about \(target.name) have begun circulating in the corridors. The source is unclear, but \(attacker.name)'s associates seem particularly well-informed.",
                visibilityLevel: .rumor,
                involvedCharacters: [attacker],
                targetCharacter: target
            )

        case .factionPressure:
            return NPCWorldActionResult(
                eventType: .grudgeAttack,
                headline: "\(attacker.name)'s Faction Targets \(target.name)",
                details: "\(attacker.name) appears to have enlisted factional allies against \(target.name). A coordinated campaign of criticism has begun, with multiple voices raising 'concerns' about \(target.name)'s work.",
                visibilityLevel: .intel,
                involvedCharacters: [attacker],
                targetCharacter: target
            )
        }
    }
}
