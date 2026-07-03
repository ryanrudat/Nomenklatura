//
//  ConspiracyService.swift
//  Nomenklatura
//
//  The aggregator the betrayal fantasy was missing: individual grudges,
//  factional resentment, and regime weakness coalesce into an actual plot
//  against the Chairman — one that forms silently, recruits over turns,
//  leaks through your network, offers a dramatic decision when exposed,
//  and climaxes in a coup attempt resolved against your real defenses.
//
//  Deliberately schema-free: the single active conspiracy is JSON-encoded
//  into game.variables["active_conspiracy"] (the RivalMove/prosecution
//  pattern). Counterplay works through EXISTING tools — detain, exile, or
//  execute an exposed conspirator via the Dossier/Security bureau and the
//  plot weakens automatically; remove the instigator and it collapses.
//

import Foundation

struct Conspiracy: Codable {
    var instigatorId: String          // GameCharacter.templateId
    var memberIds: [String]           // includes instigator
    var formedTurn: Int
    var exposed: Bool = false
    var watchBonus: Bool = false      // player chose WATCH after exposure
    var whisperSent: Bool = false     // early ambient warning fired
}

@MainActor
final class ConspiracyService {
    static let shared = ConspiracyService()
    private init() {}

    private static let storageKey = "active_conspiracy"

    // MARK: - Persistence

    func activeConspiracy(in game: Game) -> Conspiracy? {
        guard let raw = game.variables[Self.storageKey],
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Conspiracy.self, from: data)
    }

    private func save(_ conspiracy: Conspiracy?, in game: Game) {
        guard let conspiracy,
              let data = try? JSONEncoder().encode(conspiracy),
              let raw = String(data: data, encoding: .utf8) else {
            game.variables[Self.storageKey] = nil
            return
        }
        game.variables[Self.storageKey] = raw
    }

    // MARK: - Turn Processing

    func processTurn(game: Game) {
        var rng = game.rng
        defer { game.rng = rng }

        guard var conspiracy = activeConspiracy(in: game) else {
            // Stale response flags from a previous conspiracy would silently
            // auto-resolve the next one the turn it forms — clear them first.
            // Only mutate the persisted flags array when something matches,
            // so the common no-conspiracy path stays a true no-op.
            if game.flags.contains(where: { $0.hasPrefix("conspiracy_") }) {
                game.flags.removeAll { $0.hasPrefix("conspiracy_") }
            }
            checkFormation(game: game, using: &rng)
            return
        }

        // Resolve the player's exposure-event stance from last briefing.
        if game.flags.contains("conspiracy_strike") {
            game.flags.removeAll { $0.hasPrefix("conspiracy_") }
            resolveStrike(conspiracy, game: game)
            save(nil, in: game)
            return
        }
        if game.flags.contains("conspiracy_infiltrate") {
            game.flags.removeAll { $0.hasPrefix("conspiracy_") }
            resolveInfiltration(conspiracy, game: game)
            save(nil, in: game)
            return
        }
        if game.flags.contains("conspiracy_watch") {
            game.flags.removeAll { $0.hasPrefix("conspiracy_") }
            conspiracy.watchBonus = true
        }

        // Members removed from active service (detained, exiled, executed by
        // the player's existing tools) fall out of the plot.
        let before = conspiracy.memberIds.count
        conspiracy.memberIds = conspiracy.memberIds.filter { id in
            character(id, in: game)?.isActive == true
        }
        if conspiracy.memberIds.count < before {
            logEvent(game, importance: 6,
                     "The arrests have been noticed. Certain late-night meetings have gone quiet.")
        }

        // Decapitation: instigator removed -> the plot unravels.
        guard conspiracy.memberIds.contains(conspiracy.instigatorId),
              let instigator = character(conspiracy.instigatorId, in: game) else {
            collapse(conspiracy, game: game)
            save(nil, in: game)
            return
        }

        // Recruitment: one attempt per turn, capped at 5 members.
        if conspiracy.memberIds.count < 5, Int.random(in: 1...100, using: &rng) <= 40,
           let recruit = recruitCandidate(for: instigator, conspiracy: conspiracy, game: game, using: &rng) {
            conspiracy.memberIds.append(recruit.templateId)
        }

        // Early ambient warning — paranoia fuel, names no one.
        if !conspiracy.whisperSent && !conspiracy.exposed
            && game.turnNumber >= conspiracy.formedTurn + 2 && game.network >= 30 {
            conspiracy.whisperSent = true
            logEvent(game, importance: 7,
                     "Your sources report a pattern: certain senior men keep finding reasons to meet without minutes being taken.")
        }

        // Leak: more conspirators = more surfaces; your network does the rest.
        if !conspiracy.exposed {
            let leakChance = conspiracy.memberIds.count * 4 + game.network / 10
            if Int.random(in: 1...100, using: &rng) <= leakChance {
                conspiracy.exposed = true
                queueExposureEvent(conspiracy, instigator: instigator, game: game)
                // The player must get at least one turn to answer the
                // exposure event before the climax can fire.
                save(conspiracy, in: game)
                return
            }
        }

        // Climax: the plot moves when it is strong or has waited long enough.
        let turnsActive = game.turnNumber - conspiracy.formedTurn
        if turnsActive >= 8 || (strength(of: conspiracy, in: game) >= 50 && turnsActive >= 5) {
            resolveCoupAttempt(conspiracy, game: game, using: &rng)
            save(nil, in: game)
            return
        }

        save(conspiracy, in: game)
    }

    // MARK: - Formation

    private func checkFormation(game: Game, using rng: inout SeededRNG) {
        // Regime weakness is the precondition; a credible aggrieved senior
        // figure is the spark. The primary rival qualifies naturally.
        let weakness = game.eliteLoyalty < 45 || game.stability < 35
            || game.intVariable("elite_resentment") >= 50
        guard weakness, game.turnNumber > 8 else { return }

        let candidates = game.characters.filter { c in
            c.isActive && !c.isPatron
                && (c.positionIndex ?? 0) >= 5
                && c.personalityAmbitious >= 50
                && (c.disposition <= -20 || c.grudgeLevel <= -40 || (c.isRival && c.disposition <= 10))
        }
        guard !candidates.isEmpty, Int.random(in: 1...100, using: &rng) <= 8,
              let instigator = candidates.randomElement(using: &rng) else { return }

        let conspiracy = Conspiracy(
            instigatorId: instigator.templateId,
            memberIds: [instigator.templateId],
            formedTurn: game.turnNumber
        )
        save(conspiracy, in: game)
        // Formation is silent. The Chairman learns of it the hard way.
    }

    private func recruitCandidate(for instigator: GameCharacter, conspiracy: Conspiracy, game: Game, using rng: inout SeededRNG) -> GameCharacter? {
        game.characters.filter { c in
            c.isActive && !c.isPatron
                && !conspiracy.memberIds.contains(c.templateId)
                && (c.positionIndex ?? 0) >= 4
                && c.fearLevel <= 70   // the terrified do not conspire
                && ((c.disposition < 25 && c.grudgeLevel < -20)
                    || (c.factionId != nil && c.factionId == instigator.factionId && c.disposition < 35))
        }.randomElement(using: &rng)
    }

    // MARK: - Exposure decision

    private func queueExposureEvent(_ conspiracy: Conspiracy, instigator: GameCharacter, game: Game) {
        let others = conspiracy.memberIds.count - 1
        let scale = others > 0 ? "at least \(others) other figure\(others == 1 ? "" : "s")" : "an unknown number of others"
        let event = DynamicEvent(
            eventType: .urgentInterruption,
            priority: .critical,
            title: "A Conspiracy Uncovered",
            briefText: "A courier you trust delivers a single sheet, unsigned.\n\n\(instigator.name) has been holding meetings that do not appear in any calendar. \(scale.prefix(1).uppercased() + scale.dropFirst()) attend. They speak of \"the question of succession\" — and you are still alive.\n\nHow the Chairman answers a conspiracy defines the Chairmanship.",
            turnGenerated: game.turnNumber,
            isUrgent: true,
            responseOptions: [
                EventResponse(
                    id: "strike",
                    text: "Strike now — arrest everyone implicated tonight",
                    shortText: "Strike Now",
                    effects: [:],
                    followUpHint: "Decisive, public, and the elite will remember the knock at the door",
                    setsFlag: "conspiracy_strike"
                ),
                EventResponse(
                    id: "infiltrate",
                    text: "Turn one of them quietly — unravel it from inside",
                    shortText: "Infiltrate",
                    effects: ["network": -15],
                    followUpHint: "Bloodless, if your network is good enough to manage it",
                    setsFlag: "conspiracy_infiltrate"
                ),
                EventResponse(
                    id: "watch",
                    text: "Watch and wait — let them commit themselves fully",
                    shortText: "Watch",
                    effects: [:],
                    followUpHint: "Forewarned is forearmed — but the plot keeps growing",
                    setsFlag: "conspiracy_watch"
                )
            ],
            iconName: "eye.trianglebadge.exclamationmark.fill",
            accentColor: "stampRed"
        )
        game.queueDynamicEvent(event)
        logEvent(game, importance: 9, "Conspiracy exposed: \(instigator.name) is plotting against the Chairman.")
    }

    // MARK: - Resolutions

    private func resolveStrike(_ conspiracy: Conspiracy, game: Game) {
        let members = conspiracy.memberIds.compactMap { character($0, in: game) }
        for member in members where member.isActive {
            member.markRemovedFromPosition(reason: .imprisoned, turn: game.turnNumber)
            member.fearLevel = min(100, member.fearLevel + 40)
            member.disposition = max(-100, member.disposition - 20)
        }
        game.applyStat("standing", change: 8)
        game.applyStat("stability", change: -5)
        game.applyStat("eliteLoyalty", change: -(3 * members.count))
        let summary = "The conspiracy is broken in a single night. \(members.map(\.name).joined(separator: ", ")) taken from their beds. The Politburo is silent at breakfast — the kind of silence that remembers."
        logEvent(game, importance: 9, summary)
        stageOverlay(game, stamp: "EXECUTED", title: "THE NIGHT OF ARRESTS", body: summary, accent: .red)
        game.variables["press_domestic_flash"] = "order_restored"
    }

    private func resolveInfiltration(_ conspiracy: Conspiracy, game: Game) {
        let members = conspiracy.memberIds.compactMap { character($0, in: game) }
        for member in members {
            member.fearLevel = min(100, member.fearLevel + 30)
            member.disposition = max(-100, member.disposition - 10)
        }
        game.applyStat("rivalThreat", change: -5)
        let summary = "Your agent inside the conspiracy delivered everything: names, dates, hesitations. Confronted privately with their own words, the plotters scatter. No arrests, no martyrs — only \(members.count) senior figures who now know the Chairman saw them coming. Full list filed: \(members.map(\.name).joined(separator: ", "))."
        logEvent(game, importance: 9, summary)
        stageOverlay(game, stamp: "CLASSIFIED", title: "THE PLOT UNRAVELED", body: summary, accent: .gold)
    }

    private func collapse(_ conspiracy: Conspiracy, game: Game) {
        for id in conspiracy.memberIds {
            if let member = character(id, in: game), member.isActive {
                member.fearLevel = min(100, member.fearLevel + 25)
            }
        }
        logEvent(game, importance: 7,
                 "With its center removed, the conspiracy dissolves before it ever had a name. Its members return to their offices and wait, very quietly, to see who knew.")
    }

    private func resolveCoupAttempt(_ conspiracy: Conspiracy, game: Game, using rng: inout SeededRNG) {
        let attack = strength(of: conspiracy, in: game) + Int.random(in: 1...20, using: &rng)
        let chiefCompetence = bureauChief(for: "securityServices", in: game)?.personalityCompetent ?? 50
        let defense = game.militaryLoyalty / 2 + game.network / 4 + game.eliteLoyalty / 4
            + chiefCompetence / 5 + (conspiracy.watchBonus ? 15 : 0)

        let members = conspiracy.memberIds.compactMap { character($0, in: game) }
        let names = members.map(\.name).joined(separator: ", ")

        if attack > defense {
            if game.militaryLoyalty < 35 {
                // The garrison does not answer. The run ends here.
                game.status = GameStatus.lost.rawValue
                game.endReason = "Soldiers in the corridors before dawn. The men who came for you carried a typed resolution with \(members.count) signatures — and the garrison commander's was among them."
                logEvent(game, importance: 10, "The conspiracy struck. The military did not answer the Chairman's call.")
            } else {
                // The coup fails to take the building but wounds the throne.
                for member in members where member.isActive {
                    member.disposition = max(-100, member.disposition - 10)
                }
                if let instigator = character(conspiracy.instigatorId, in: game), instigator.isActive {
                    instigator.markRemovedFromPosition(reason: .exiled, turn: game.turnNumber)
                }
                game.applyStat("standing", change: -25)
                game.applyStat("eliteLoyalty", change: -15)
                game.applyStat("stability", change: -12)
                game.applyStat("militaryLoyalty", change: -8)
                game.applyStat("rivalThreat", change: 20)
                let summary = "A night of confused orders and seized radio stations. You hold the building — barely. \(names) moved openly against you, and though the plot failed, the whole apparatus watched the Chairman bleed."
                logEvent(game, importance: 10, summary)
                stageOverlay(game, stamp: "STATE OF EMERGENCY", title: "THE NIGHT THEY MOVED", body: summary, accent: .red)
                game.variables["press_domestic_flash"] = "state_of_emergency"
            }
        } else {
            for member in members where member.isActive {
                member.markRemovedFromPosition(reason: .imprisoned, turn: game.turnNumber)
                member.fearLevel = min(100, member.fearLevel + 40)
            }
            game.applyStat("standing", change: 10)
            game.applyStat("eliteLoyalty", change: 5)
            game.applyStat("stability", change: -5)
            let summary = "They moved at 3 a.m. and found every door already held against them. \(names) in custody by sunrise. The apparatus draws the obvious lesson: the Chairman cannot be surprised."
            logEvent(game, importance: 10, summary)
            stageOverlay(game, stamp: "ORDER RESTORED", title: "THE 3 A.M. PLOT", body: summary, accent: .gold)
            game.variables["press_domestic_flash"] = "order_restored"
        }
    }

    // MARK: - Helpers

    private func strength(of conspiracy: Conspiracy, in game: Game) -> Int {
        conspiracy.memberIds.compactMap { character($0, in: game) }
            .reduce(0) { $0 + ($1.positionIndex ?? 0) * 2 } + conspiracy.memberIds.count * 5
    }

    private func character(_ templateId: String, in game: Game) -> GameCharacter? {
        game.characters.first { $0.templateId == templateId }
    }

    /// Stage the full-screen Constructivist overlay for the next briefing.
    private func stageOverlay(_ game: Game, stamp: String, title: String, body: String, accent: StateEventPayload.Accent) {
        game.pendingStateEvent = StateEventPayload(
            id: UUID().uuidString, stampText: stamp, title: title, body: body, accent: accent
        )
    }

    private func logEvent(_ game: Game, importance: Int, _ summary: String) {
        let event = GameEvent(turnNumber: game.turnNumber, eventType: .crisis, summary: summary)
        event.importance = importance
        event.game = game
        game.events.append(event)
    }
}
