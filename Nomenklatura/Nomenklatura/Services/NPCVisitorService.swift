//
//  NPCVisitorService.swift
//  Nomenklatura
//
//  Service for generating NPC visitors during the personal action phase
//  Makes NPCs feel more alive by having them approach the player proactively
//

import Foundation

// MARK: - NPC Visitor

/// Represents an NPC who has approached the player during the personal action phase
struct NPCVisitor: Identifiable {
    var id: UUID = UUID()
    var character: GameCharacter
    var visitType: NPCVisitType
    var title: String
    var message: String
    var responseOptions: [VisitorResponse]
    var turnGenerated: Int
    var priority: Int  // Higher = more urgent
    var iconName: String

    /// Check if visitor should still be shown (not expired)
    func isActive(currentTurn: Int) -> Bool {
        // Visitors only last one turn
        return currentTurn == turnGenerated
    }
}

enum NPCVisitType: String, Codable {
    case seekingEndorsement     // NPC wants player's support for a promotion
    case offeringAlliance       // NPC proposes working together
    case warningOfDanger        // NPC warns player about threats
    case askingFavor           // NPC needs player's help with something
    case sharingIntel          // NPC shares useful information
    case expressingGratitude    // NPC thanks player for past help
    case probingIntentions      // NPC is feeling out the player
    case makingThreat          // Rival is intimidating the player

    var displayName: String {
        switch self {
        case .seekingEndorsement: return "Seeking Support"
        case .offeringAlliance: return "Offering Alliance"
        case .warningOfDanger: return "Warning"
        case .askingFavor: return "Request"
        case .sharingIntel: return "Intelligence"
        case .expressingGratitude: return "Gratitude"
        case .probingIntentions: return "Probing"
        case .makingThreat: return "Confrontation"
        }
    }

    var icon: String {
        switch self {
        case .seekingEndorsement: return "hand.raised.fill"
        case .offeringAlliance: return "person.2.fill"
        case .warningOfDanger: return "exclamationmark.triangle.fill"
        case .askingFavor: return "questionmark.circle.fill"
        case .sharingIntel: return "eye.fill"
        case .expressingGratitude: return "heart.fill"
        case .probingIntentions: return "magnifyingglass"
        case .makingThreat: return "bolt.fill"
        }
    }
}

struct VisitorResponse: Identifiable {
    var id: String
    var text: String
    var shortText: String
    var effects: [String: Int]
    var dispositionChange: Int  // Change to NPC's disposition toward player
    var isHostile: Bool = false
    var memoryTag: String?  // Tag for NPC memory system
}

// MARK: - NPC Visitor Service

@MainActor
class NPCVisitorService {
    static let shared = NPCVisitorService()

    private init() {}

    // Cache visitors per turn to prevent regeneration
    private var cachedVisitors: [Int: [NPCVisitor]] = [:]

    /// Generate visitors for the current personal action phase
    func generateVisitors(for game: Game) -> [NPCVisitor] {
        // Check cache first
        if let cached = cachedVisitors[game.turnNumber] {
            return cached.filter { $0.isActive(currentTurn: game.turnNumber) }
        }

        var visitors: [NPCVisitor] = []

        // Limit to 1-2 visitors per turn for pacing
        let maxVisitors = game.turnNumber < 5 ? 1 : 2

        // Check each type of potential visitor
        visitors.append(contentsOf: checkForEndorsementSeekers(game: game))
        visitors.append(contentsOf: checkForAllianceOffers(game: game))
        visitors.append(contentsOf: checkForFavorRequests(game: game))
        visitors.append(contentsOf: checkForWarnings(game: game))
        visitors.append(contentsOf: checkForIntelSharing(game: game))
        visitors.append(contentsOf: checkForRivalConfrontations(game: game))

        // Sort by priority and take top visitors
        visitors.sort { $0.priority > $1.priority }
        let result = Array(visitors.prefix(maxVisitors))

        // Cache the result
        cachedVisitors[game.turnNumber] = result

        return result
    }

    /// Clear cached visitors (call at turn end)
    func clearCache() {
        cachedVisitors.removeAll()
    }

    /// Apply visitor response effects to game state
    func applyVisitorResponse(visitor: NPCVisitor, response: VisitorResponse, game: Game) {
        // Apply stat effects
        for (key, value) in response.effects {
            switch key {
            case "standing": game.standing = max(0, min(100, game.standing + value))
            case "network": game.network = max(0, min(100, game.network + value))
            case "patronFavor": game.patronFavor = max(0, min(100, game.patronFavor + value))
            case "rivalThreat": game.rivalThreat = max(0, min(100, game.rivalThreat + value))
            case "reputationLoyal": game.reputationLoyal = max(0, min(100, game.reputationLoyal + value))
            case "reputationCunning": game.reputationCunning = max(0, min(100, game.reputationCunning + value))
            case "reputationRuthless": game.reputationRuthless = max(0, min(100, game.reputationRuthless + value))
            case "reputationCompetent": game.reputationCompetent = max(0, min(100, game.reputationCompetent + value))
            default: break
            }
        }

        // Apply disposition change to visitor character
        visitor.character.disposition = max(-100, min(100, visitor.character.disposition + response.dispositionChange))

        // Record memory if applicable
        if let memoryTag = response.memoryTag {
            recordVisitorMemory(character: visitor.character, tag: memoryTag, game: game)
        }

        // Record interaction in character history
        recordInteraction(visitor: visitor, response: response, game: game)
    }

    private func recordVisitorMemory(character: GameCharacter, tag: String, game: Game) {
        // Use the memory system to record this interaction
        let memory = NPCMemory(
            type: tag.contains("helped") ? .gratitude :
                  tag.contains("refused") ? .grudge :
                  tag.contains("betrayed") ? .betrayal : .neutral,
            description: "Interaction during personal action phase",
            relatedCharacterId: nil,  // Player
            intensity: 30,
            decayRate: 5
        )
        character.addMemory(memory, game: game)
    }

    private func recordInteraction(visitor: NPCVisitor, response: VisitorResponse, game: Game) {
        let record = CharacterInteractionRecord(
            turnNumber: game.turnNumber,
            otherCharacterName: "Player",
            actionDescription: "Approached player: \(visitor.visitType.displayName). Response: \(response.shortText)",
            dispositionChange: response.dispositionChange
        )
        visitor.character.interactionHistory.append(record)
    }

    // MARK: - Visitor Generation

    private func checkForEndorsementSeekers(game: Game) -> [NPCVisitor] {
        var visitors: [NPCVisitor] = []

        // NPCs at lower positions who want player's endorsement for advancement
        let potentialSeekers = game.characters.filter { npc in
            guard npc.isAlive,
                  let npcPosition = npc.positionIndex,
                  npcPosition < game.currentPositionIndex,  // Must be below player
                  npcPosition >= game.currentPositionIndex - 2,  // Not too far below
                  npc.disposition >= 30,  // Must have decent relationship
                  !npc.isRival else { return false }
            return true
        }

        // 15% chance for each eligible NPC
        for npc in potentialSeekers {
            guard Double.random(in: 0...1) < 0.15 else { continue }

            let visitor = NPCVisitor(
                character: npc,
                visitType: .seekingEndorsement,
                title: "A Request for Support",
                message: "\(npc.name) knocks on your office door, looking hopeful.\n\n\"Comrade, I understand a position is opening up in the \(npc.positionTrack ?? "apparatus"). Your word carries weight. Might I count on your support?\"\n\nThey wait anxiously for your response.",
                responseOptions: [
                    VisitorResponse(
                        id: "endorse",
                        text: "Promise your support for their advancement",
                        shortText: "Support",
                        effects: ["network": 5],
                        dispositionChange: 15,
                        memoryTag: "helped_advancement"
                    ),
                    VisitorResponse(
                        id: "consider",
                        text: "Say you'll consider it without committing",
                        shortText: "Consider",
                        effects: [:],
                        dispositionChange: 0
                    ),
                    VisitorResponse(
                        id: "refuse",
                        text: "Politely decline to get involved",
                        shortText: "Decline",
                        effects: [:],
                        dispositionChange: -10,
                        memoryTag: "refused_help"
                    )
                ],
                turnGenerated: game.turnNumber,
                priority: 3,
                iconName: "hand.raised.fill"
            )
            visitors.append(visitor)
        }

        return visitors
    }

    private func checkForAllianceOffers(game: Game) -> [NPCVisitor] {
        var visitors: [NPCVisitor] = []

        // NPCs at similar positions who want to form an alliance
        let potentialAllies = game.characters.filter { npc in
            guard npc.isAlive,
                  let npcPosition = npc.positionIndex,
                  abs(npcPosition - game.currentPositionIndex) <= 1,  // Similar rank
                  npc.disposition >= 20 && npc.disposition < 60,  // Not already close ally, not hostile
                  !npc.isPatron && !npc.isRival else { return false }
            return true
        }

        // 10% chance for each eligible NPC
        for npc in potentialAllies {
            guard Double.random(in: 0...1) < 0.10 else { continue }

            let visitor = NPCVisitor(
                character: npc,
                visitType: .offeringAlliance,
                title: "An Interesting Proposition",
                message: "\(npc.name) catches you in the corridor, speaking quietly.\n\n\"Comrade, I've been watching you. We share certain... perspectives. The current situation is fluid. Perhaps we should discuss mutual interests?\"\n\nThey glance around to ensure no one is listening.",
                responseOptions: [
                    VisitorResponse(
                        id: "accept",
                        text: "Agree to work together",
                        shortText: "Accept",
                        effects: ["network": 8, "standing": 2],
                        dispositionChange: 20,
                        memoryTag: "alliance_formed"
                    ),
                    VisitorResponse(
                        id: "cautious",
                        text: "Express interest but want to know more",
                        shortText: "Learn More",
                        effects: ["network": 2],
                        dispositionChange: 5
                    ),
                    VisitorResponse(
                        id: "refuse",
                        text: "Politely decline their overture",
                        shortText: "Decline",
                        effects: ["reputationLoyal": 3],
                        dispositionChange: -5
                    )
                ],
                turnGenerated: game.turnNumber,
                priority: 4,
                iconName: "person.2.fill"
            )
            visitors.append(visitor)
        }

        return visitors
    }

    private func checkForFavorRequests(game: Game) -> [NPCVisitor] {
        var visitors: [NPCVisitor] = []

        // NPCs with good disposition asking for favors
        let potentialAskers = game.characters.filter { npc in
            guard npc.isAlive,
                  npc.disposition >= 40,  // Friendly enough to ask
                  !npc.isPatron else { return false }
            return true
        }

        // 8% chance for each eligible NPC
        for npc in potentialAskers {
            guard Double.random(in: 0...1) < 0.08 else { continue }

            let favors = [
                (
                    title: "A Delicate Matter",
                    message: "\(npc.name) approaches with a troubled expression.\n\n\"Comrade, I need a favor. My nephew has gotten into difficulty with the local committee. A word from someone of your standing could resolve things. I would be grateful.\"",
                    helpEffects: ["network": 6, "patronFavor": -2],
                    refuseDisposition: -8
                ),
                (
                    title: "Information Request",
                    message: "\(npc.name) stops by your office.\n\n\"Comrade, I need access to certain files regarding production quotas in Zone 3. Officially, I don't have clearance, but you might be able to help me get them. For the good of the state, of course.\"",
                    helpEffects: ["network": 4],
                    refuseDisposition: -5
                ),
                (
                    title: "A Friend in Need",
                    message: "\(npc.name) appears at your door looking stressed.\n\n\"Comrade, I may have made an enemy in the wrong department. Someone is spreading rumors about my past. Could you... speak to the right people? Put in a good word?\"",
                    helpEffects: ["network": 5, "standing": -2],
                    refuseDisposition: -10
                )
            ]

            let favor = favors.randomElement()!

            let visitor = NPCVisitor(
                character: npc,
                visitType: .askingFavor,
                title: favor.title,
                message: favor.message,
                responseOptions: [
                    VisitorResponse(
                        id: "help",
                        text: "Agree to help them",
                        shortText: "Help",
                        effects: favor.helpEffects,
                        dispositionChange: 12,
                        memoryTag: "helped_favor"
                    ),
                    VisitorResponse(
                        id: "conditional",
                        text: "Offer to help but expect something in return",
                        shortText: "Bargain",
                        effects: ["reputationCunning": 3],
                        dispositionChange: 5
                    ),
                    VisitorResponse(
                        id: "refuse",
                        text: "Politely refuse to get involved",
                        shortText: "Refuse",
                        effects: [:],
                        dispositionChange: favor.refuseDisposition,
                        memoryTag: "refused_favor"
                    )
                ],
                turnGenerated: game.turnNumber,
                priority: 2,
                iconName: "questionmark.circle.fill"
            )
            visitors.append(visitor)
        }

        return visitors
    }

    private func checkForWarnings(game: Game) -> [NPCVisitor] {
        var visitors: [NPCVisitor] = []

        // Only if player is in some danger (rival threat high, standing low, etc.)
        guard game.rivalThreat >= 50 || game.standing <= 40 || game.patronFavor <= 30 else {
            return visitors
        }

        // Friendly NPCs who might warn the player
        let potentialWarners = game.characters.filter { npc in
            guard npc.isAlive,
                  npc.disposition >= 50,  // Friendly enough to warn
                  !npc.isRival else { return false }
            return true
        }

        // 12% chance for each eligible NPC
        for npc in potentialWarners {
            guard Double.random(in: 0...1) < 0.12 else { continue }

            let rivalName = game.primaryRival?.name ?? "certain individuals"

            let warnings = [
                (
                    title: "A Word of Warning",
                    message: "\(npc.name) pulls you aside after the morning briefing.\n\n\"Comrade, be careful. I've heard whispers. \(rivalName) is gathering support against you. There may be an accusation coming. Watch your back.\""
                ),
                (
                    title: "Troubling News",
                    message: "\(npc.name) knocks softly and slips into your office.\n\n\"Comrade, I shouldn't be telling you this, but... there was a meeting yesterday. Your name came up. Not favorably. Someone is building a case against you.\""
                ),
                (
                    title: "A Friendly Alert",
                    message: "\(npc.name) catches your eye in the canteen and gestures toward an empty corner.\n\n\"Listen,\" they whisper. \"The General Secretary asked about you at the last Secretariat meeting. I don't know if that's good or bad, but I thought you should know.\""
                )
            ]

            let warning = warnings.randomElement()!

            let visitor = NPCVisitor(
                character: npc,
                visitType: .warningOfDanger,
                title: warning.title,
                message: warning.message,
                responseOptions: [
                    VisitorResponse(
                        id: "thank",
                        text: "Thank them sincerely for the warning",
                        shortText: "Thank",
                        effects: [:],
                        dispositionChange: 8,
                        memoryTag: "warned_player"
                    ),
                    VisitorResponse(
                        id: "ask_more",
                        text: "Press them for more details",
                        shortText: "Ask More",
                        effects: ["network": 3],
                        dispositionChange: 2
                    ),
                    VisitorResponse(
                        id: "dismiss",
                        text: "Dismiss their concerns as rumors",
                        shortText: "Dismiss",
                        effects: [:],
                        dispositionChange: -5
                    )
                ],
                turnGenerated: game.turnNumber,
                priority: 5,  // High priority for warnings
                iconName: "exclamationmark.triangle.fill"
            )
            visitors.append(visitor)
        }

        return visitors
    }

    private func checkForIntelSharing(game: Game) -> [NPCVisitor] {
        var visitors: [NPCVisitor] = []

        // Only if player has decent network
        guard game.network >= 30 else { return visitors }

        // NPCs in informant role or with good disposition
        let potentialSources = game.characters.filter { npc in
            guard npc.isAlive,
                  npc.currentRole == .informant || npc.disposition >= 55 else { return false }
            return true
        }

        // 10% chance for each eligible NPC
        for npc in potentialSources {
            guard Double.random(in: 0...1) < 0.10 else { continue }

            let intel = [
                (
                    title: "Whispers from the Corridors",
                    message: "\(npc.name) approaches with a knowing look.\n\n\"Comrade, I've learned something interesting. There's a faction fight brewing in the Ministry of Heavy Industry. The reformists and old guard are at each other's throats. Might be an opportunity for someone clever.\"",
                    effects: ["network": 4] as [String: Int]
                ),
                (
                    title: "A Piece of the Puzzle",
                    message: "\(npc.name) slides a folded paper across your desk.\n\n\"Don't ask where I got this. Production numbers from Zone 3. The official reports don't match. Someone is cooking the books. Thought you'd find it interesting.\"",
                    effects: ["network": 5] as [String: Int]
                ),
                (
                    title: "Useful Information",
                    message: "\(npc.name) catches you leaving a meeting.\n\n\"Comrade, a word? I happened to overhear something. The General Secretary is planning to reorganize the Planning Commission. There will be openings. You might want to position yourself.\"",
                    effects: ["network": 3, "standing": 2] as [String: Int]
                )
            ]

            let item = intel.randomElement()!

            let visitor = NPCVisitor(
                character: npc,
                visitType: .sharingIntel,
                title: item.title,
                message: item.message,
                responseOptions: [
                    VisitorResponse(
                        id: "accept",
                        text: "Accept the information gratefully",
                        shortText: "Accept",
                        effects: item.effects,
                        dispositionChange: 5,
                        memoryTag: "shared_intel"
                    ),
                    VisitorResponse(
                        id: "reward",
                        text: "Promise them a reward for their loyalty",
                        shortText: "Reward",
                        effects: item.effects.merging(["network": 3]) { _, new in new },
                        dispositionChange: 10
                    )
                ],
                turnGenerated: game.turnNumber,
                priority: 3,
                iconName: "eye.fill"
            )
            visitors.append(visitor)
        }

        return visitors
    }

    private func checkForRivalConfrontations(game: Game) -> [NPCVisitor] {
        var visitors: [NPCVisitor] = []

        // Only if rival threat is high
        guard game.rivalThreat >= 40 else { return visitors }

        guard let rival = game.primaryRival, rival.isAlive else { return visitors }

        // 15% chance of rival confrontation when threat is high
        guard Double.random(in: 0...1) < 0.15 else { return visitors }

        let confrontations = [
            (
                title: "An Unexpected Visitor",
                message: "\(rival.name) appears in your doorway, blocking the exit.\n\n\"Comrade,\" they say, their tone dripping with false courtesy. \"I think we should have a little chat. You've been... busy lately. Perhaps too busy for your own good.\"\n\nThe threat is barely veiled."
            ),
            (
                title: "A Cold Warning",
                message: "\(rival.name) intercepts you in the corridor.\n\n\"I know what you're doing,\" they hiss. \"Your little schemes. Your back-channel conversations. Did you think I wouldn't notice? Consider this a warning. Back off, or face the consequences.\""
            ),
            (
                title: "The Mask Slips",
                message: "\(rival.name) corners you after a meeting.\n\n\"You think you're clever, don't you? Building your networks, whispering in ears. Well, I have ears too. And files. Perhaps it's time the Standing Committee reviewed certain... documents.\"\n\nTheir smile doesn't reach their eyes."
            )
        ]

        let confrontation = confrontations.randomElement()!

        let visitor = NPCVisitor(
            character: rival,
            visitType: .makingThreat,
            title: confrontation.title,
            message: confrontation.message,
            responseOptions: [
                VisitorResponse(
                    id: "defiant",
                    text: "Stand your ground and refuse to be intimidated",
                    shortText: "Defy",
                    effects: ["standing": 3, "reputationRuthless": 5],
                    dispositionChange: -10,
                    isHostile: true,
                    memoryTag: "defied_threat"
                ),
                VisitorResponse(
                    id: "counter",
                    text: "Make a veiled counter-threat of your own",
                    shortText: "Counter",
                    effects: ["rivalThreat": -5, "reputationCunning": 5],
                    dispositionChange: -15,
                    isHostile: true,
                    memoryTag: "counter_threat"
                ),
                VisitorResponse(
                    id: "placate",
                    text: "Try to defuse the situation diplomatically",
                    shortText: "Placate",
                    effects: ["rivalThreat": 5],
                    dispositionChange: 5
                ),
                VisitorResponse(
                    id: "retreat",
                    text: "Back down and hope they leave you alone",
                    shortText: "Retreat",
                    effects: ["standing": -5, "rivalThreat": 8],
                    dispositionChange: 3,
                    memoryTag: "backed_down"
                )
            ],
            turnGenerated: game.turnNumber,
            priority: 6,  // Highest priority for rival confrontations
            iconName: "bolt.fill"
        )
        visitors.append(visitor)

        return visitors
    }
}
