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
        var rng = game.rng
        defer { game.rng = rng }
        var results: [NPCWorldActionResult] = []

        // Only process after early game
        guard game.turnNumber > 2 else { return [] }

        // Check for various NPC-to-NPC interactions

        // 1. Grudge-driven actions (NPCs attacking each other)
        if let grudgeEvent = checkGrudgeActions(game: game, using: &rng) {
            if shouldPlayerSeeEvent(event: grudgeEvent, game: game) {
                results.append(grudgeEvent)
            }
            applyWorldActionEffects(event: grudgeEvent, game: game)
        }

        // 2. Alliance formation or betrayal
        if let allianceEvent = checkAllianceEvents(game: game, using: &rng) {
            if shouldPlayerSeeEvent(event: allianceEvent, game: game) {
                results.append(allianceEvent)
            }
            applyWorldActionEffects(event: allianceEvent, game: game)
        }

        // 3. Position competition
        if let competitionEvent = checkPositionCompetition(game: game, using: &rng) {
            if shouldPlayerSeeEvent(event: competitionEvent, game: game) {
                results.append(competitionEvent)
            }
            applyWorldActionEffects(event: competitionEvent, game: game)
        }

        // 4. Faction maneuvering
        if let factionEvent = checkFactionManeuvering(game: game, using: &rng) {
            if shouldPlayerSeeEvent(event: factionEvent, game: game) {
                results.append(factionEvent)
            }
        }

        // 5. Mentor/protégé actions
        if let patronageEvent = checkPatronageActions(game: game, using: &rng) {
            if shouldPlayerSeeEvent(event: patronageEvent, game: game) {
                results.append(patronageEvent)
            }
            applyWorldActionEffects(event: patronageEvent, game: game)
        }

        // 6. Private meetings (alliance signals visible to the player)
        if let meetingEvent = checkPrivateMeetings(game: game, using: &rng) {
            if shouldPlayerSeeEvent(event: meetingEvent, game: game) {
                results.append(meetingEvent)
            }
        }

        // 7. Public policy criticism (opposition signals)
        if let criticismEvent = checkPolicyCriticism(game: game, using: &rng) {
            if shouldPlayerSeeEvent(event: criticismEvent, game: game) {
                results.append(criticismEvent)
            }
        }

        // 8. Production report discrepancies (corruption signals)
        if let corruptionEvent = checkProductionDiscrepancies(game: game, using: &rng) {
            if shouldPlayerSeeEvent(event: corruptionEvent, game: game) {
                results.append(corruptionEvent)
            }
        }

        // 9. Trust-based coalition formation from CharacterAgencyService
        let coalitionEvents = CharacterAgencyService.shared.evaluateCoalitionFormation(game: game)
        for event in coalitionEvents {
            if shouldPlayerSeeEvent(event: event, game: game) {
                results.append(event)
            }
        }

        // 10. Fear-driven informing from CharacterAgencyService
        let informingEvents = CharacterAgencyService.shared.evaluateFearDrivenInforming(game: game)
        for event in informingEvents {
            if shouldPlayerSeeEvent(event: event, game: game) {
                results.append(event)
            }
        }

        // Allow up to 4 events per turn for a livelier political world
        let limitedResults = Array(results.shuffled(using: &rng).prefix(4))

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

    private func checkGrudgeActions(game: Game, using rng: inout SeededRNG) -> NPCWorldActionResult? {
        // Find NPCs with grudges against other NPCs (lowered threshold for more activity)
        let grudgeRelationships = game.npcRelationships.filter { rel in
            rel.grudgeLevel >= 40 && rel.disposition < -10
        }

        guard !grudgeRelationships.isEmpty else { return nil }

        guard Int.random(in: 1...100, using: &rng) <= 12 else { return nil }

        // Pick a random grudge relationship
        guard let relationship = grudgeRelationships.randomElement(using: &rng),
              let attacker = game.characters.first(where: { $0.templateId == relationship.sourceCharacterId && $0.isActive }),
              let target = game.characters.first(where: { $0.templateId == relationship.targetCharacterId && $0.isActive }) else {
            return nil
        }

        // Determine attack type based on attacker's personality
        let attackType = determineAttackType(attacker: attacker, target: target, relationship: relationship, using: &rng)

        return attackType.generateEvent(attacker: attacker, target: target, game: game)
    }

    private func determineAttackType(attacker: GameCharacter, target: GameCharacter, relationship: NPCRelationship, using rng: inout SeededRNG) -> GrudgeAttackType {
        // Ruthless attackers go for the throat
        if attacker.personalityRuthless > 70 {
            return [.publicAccusation, .formalComplaint, .sabotage].randomElement(using: &rng)!
        }

        // Ambitious attackers try to benefit politically
        if attacker.personalityAmbitious > 60 {
            return [.publicAccusation, .factionPressure].randomElement(using: &rng)!
        }

        // Paranoid attackers act defensively
        if attacker.personalityParanoid > 60 {
            return [.spreadRumors, .formalComplaint].randomElement(using: &rng)!
        }

        // Default: spread rumors
        return .spreadRumors
    }

    // MARK: - Alliance Events

    private func checkAllianceEvents(game: Game, using rng: inout SeededRNG) -> NPCWorldActionResult? {
        // 8% chance per turn - alliances form more readily
        guard Int.random(in: 1...100, using: &rng) <= 8 else { return nil }

        // Check for alliance formation (shared enemies create alliances)
        if let formationEvent = checkAllianceFormation(game: game) {
            return formationEvent
        }

        // Check for alliance betrayal
        if let betrayalEvent = checkAllianceBetrayal(game: game, using: &rng) {
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

    private func checkAllianceBetrayal(game: Game, using rng: inout SeededRNG) -> NPCWorldActionResult? {
        // Find existing alliances
        let alliances = game.npcRelationships.filter { $0.isAllied && $0.allianceStrength < 40 }

        guard let weakAlliance = alliances.randomElement(using: &rng),
              let betrayer = game.characters.first(where: { $0.templateId == weakAlliance.sourceCharacterId && $0.isActive }),
              let victim = game.characters.first(where: { $0.templateId == weakAlliance.targetCharacterId && $0.isActive }) else {
            return nil
        }

        // Ambitious and low-loyalty characters are more likely to betray
        // Range: 0-100, where 100 = max ambitious + min loyal, 0 = min ambitious + max loyal
        let betrayalChance = (betrayer.personalityAmbitious + (100 - betrayer.personalityLoyal)) / 2
        guard Int.random(in: 1...100, using: &rng) <= betrayalChance else { return nil }

        return NPCWorldActionResult(
            eventType: .allianceBetrayed,
            headline: "\(betrayer.name) Distances from \(victim.name)",
            details: "Your sources report that \(betrayer.name) has been distancing themselves from their former ally \(victim.name). In a recent meeting, \(betrayer.name) notably failed to support \(victim.name)'s position, causing visible tension.",
            visibilityLevel: .intel,
            involvedCharacters: [betrayer, victim]
        )
    }

    // MARK: - Position Competition

    private func checkPositionCompetition(game: Game, using rng: inout SeededRNG) -> NPCWorldActionResult? {
        // 10% chance per turn - ambitious NPCs compete openly
        guard Int.random(in: 1...100, using: &rng) <= 10 else { return nil }

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

    private func checkFactionManeuvering(game: Game, using rng: inout SeededRNG) -> NPCWorldActionResult? {
        // 8% chance per turn - factions are always maneuvering
        guard Int.random(in: 1...100, using: &rng) <= 8 else { return nil }

        // Find factions with significant power differences
        let factions = game.factions.filter { $0.power > 20 }
        guard factions.count >= 2 else { return nil }

        let strongestFaction = factions.max(by: { $0.power < $1.power })
        let challengerFaction = factions.filter { $0.id != strongestFaction?.id }.randomElement(using: &rng)

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

        let maneuver = maneuverTypes.randomElement(using: &rng)!

        return NPCWorldActionResult(
            eventType: .factionManeuvering,
            headline: maneuver.0,
            details: maneuver.1,
            visibilityLevel: maneuver.2,
            involvedFactions: [dominant, challenger]
        )
    }

    // MARK: - Patronage Actions

    private func checkPatronageActions(game: Game, using rng: inout SeededRNG) -> NPCWorldActionResult? {
        // 7% chance per turn - patronage networks are active
        guard Int.random(in: 1...100, using: &rng) <= 7 else { return nil }

        // Find patron-client relationships
        let patronRelations = game.npcRelationships.filter { $0.isPatron }

        guard let relation = patronRelations.randomElement(using: &rng),
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

        let action = actionTypes.randomElement(using: &rng)!

        return NPCWorldActionResult(
            eventType: action.0,
            headline: action.1,
            details: action.2,
            visibilityLevel: action.3,
            involvedCharacters: [patron, client]
        )
    }

    // MARK: - Private Meetings (Alliance Signals)

    private func checkPrivateMeetings(game: Game, using rng: inout SeededRNG) -> NPCWorldActionResult? {
        // 10% chance per turn
        guard Int.random(in: 1...100, using: &rng) <= 10 else { return nil }

        let activeNPCs = game.characters.filter { $0.isActive && !$0.isPatron }
        guard activeNPCs.count >= 2 else { return nil }

        // Find pairs with high trust or shared faction who aren't already allied
        let npc1 = activeNPCs.randomElement(using: &rng)!
        let potentialPartners = activeNPCs.filter { npc in
            npc.id != npc1.id &&
            ((npc.factionId == npc1.factionId && npc.factionId != nil) ||
             npc.trustLevel > 50)
        }

        guard let npc2 = potentialPartners.randomElement(using: &rng) else { return nil }

        let locations = ["the government dacha", "a private dining room at the Metropol", "an unmarked office in the old quarter", "the Party archives reading room"]
        let location = locations.randomElement(using: &rng)!

        let subjects = [
            "The subject of their conversation remains unknown, but both appeared pleased afterward.",
            "Sources report they discussed upcoming personnel changes in the Central Committee.",
            "They were reportedly comparing notes on your recent policy directives.",
            "The meeting lasted over two hours. Your intelligence suggests they are coordinating strategy."
        ]
        let subject = subjects.randomElement(using: &rng)!

        return NPCWorldActionResult(
            eventType: .allianceFormed,
            headline: "\(npc1.name) Met Privately with \(npc2.name)",
            details: "Your sources report that \(npc1.name) and \(npc2.name) were observed meeting privately at \(location). \(subject)",
            visibilityLevel: .intel,
            involvedCharacters: [npc1, npc2]
        )
    }

    // MARK: - Policy Criticism (Opposition Signals)

    private func checkPolicyCriticism(game: Game, using rng: inout SeededRNG) -> NPCWorldActionResult? {
        // 8% chance per turn, higher during instability
        let baseChance = game.stability < 50 ? 15 : 8
        guard Int.random(in: 1...100, using: &rng) <= baseChance else { return nil }

        // Find NPCs with low disposition or high aggression who might criticize
        let critics = game.characters.filter { npc in
            npc.isActive &&
            (npc.disposition < 40 || npc.aggressionLevel > BalanceConfig.npcHighAggressionThreshold) &&
            npc.fearLevel < BalanceConfig.npcHighFearThreshold  // Not too afraid to speak up
        }

        guard let critic = critics.randomElement(using: &rng) else { return nil }

        let policies = [
            "economic reform program",
            "foreign policy direction",
            "security apparatus expansion",
            "agricultural collectivization targets",
            "military modernization priorities",
            "ideological education campaign"
        ]
        let policy = policies.randomElement(using: &rng)!

        let criticisms: [(String, WorldActionVisibilityLevel)] = [
            ("\(critic.name) publicly questioned the wisdom of your \(policy) during the morning briefing. Their remarks drew careful attention from several committee members.", .public),
            ("In a pointed editorial submitted to the Party newspaper, \(critic.name) offered 'constructive criticism' of the \(policy). The subtext was unmistakable — this is a challenge to your authority.", .public),
            ("Your sources report that \(critic.name) has been circulating a memorandum critiquing your \(policy) among senior officials. The document stops short of open opposition but lays groundwork for a formal challenge.", .intel),
            ("\(critic.name) made disparaging remarks about your \(policy) at a private gathering. 'The General Secretary's approach shows a troubling detachment from reality,' they reportedly said.", .rumor)
        ]
        let (details, visibility) = criticisms.randomElement(using: &rng)!

        return NPCWorldActionResult(
            eventType: .positionCompetition,
            headline: "\(critic.name) Criticizes Your Policy",
            details: details,
            visibilityLevel: visibility,
            involvedCharacters: [critic]
        )
    }

    // MARK: - Production Discrepancies (Corruption Signals)

    private func checkProductionDiscrepancies(game: Game, using rng: inout SeededRNG) -> NPCWorldActionResult? {
        // 6% chance per turn
        guard Int.random(in: 1...100, using: &rng) <= 6 else { return nil }

        // Find NPCs with corrupt personality traits
        let suspects = game.characters.filter { npc in
            npc.isActive &&
            npc.personalityCorrupt > 40 &&
            (npc.positionIndex ?? 0) >= 2  // Must have enough position to embezzle
        }

        guard let suspect = suspects.randomElement(using: &rng) else { return nil }

        let discrepancies: [(String, String, WorldActionVisibilityLevel)] = [
            ("\(suspect.name)'s Production Reports Contain Discrepancies",
             "An audit of \(suspect.name)'s ministry has revealed significant discrepancies between reported production figures and actual output. Grain reserves in their jurisdiction are 30% below stated levels. The numbers suggest either gross incompetence or deliberate falsification.",
             .intel),
            ("Unexplained Expenditures in \(suspect.name)'s Department",
             "Budget analysts have flagged irregular expenditures in \(suspect.name)'s department. Large sums have been allocated to 'infrastructure maintenance' with no corresponding projects. \(suspect.name)'s lifestyle has also become notably more luxurious.",
             .secret),
            ("Supply Chain Irregularities Linked to \(suspect.name)",
             "Reports indicate that state goods designated for distribution in \(suspect.name)'s region have been diverted. The quantities are significant enough to notice but not so large as to cause immediate crisis — suggesting a practiced hand.",
             .intel),
            ("\(suspect.name)'s Financial Records Under Question",
             "Routine review of financial records has uncovered that \(suspect.name) authorized several unusual transfers to entities with no apparent connection to state operations. The amounts are modest individually but substantial in aggregate.",
             .secret)
        ]
        let (headline, details, visibility) = discrepancies.randomElement(using: &rng)!

        return NPCWorldActionResult(
            eventType: .grudgeAttack,
            headline: headline,
            details: details,
            visibilityLevel: visibility,
            involvedCharacters: [suspect]
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
                // Chairman Sees Everything — no redaction. Always shows the
                // eyes-only prefix regardless of position. Previous logic
                // gated reveal behind position 7+, but the player is
                // Position 8 by design and the locked rule is that no UI
                // path should hide content from them.
                return "Eyes Only: "
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
