//
//  ReformLaws.swift
//  Nomenklatura
//
//  The two axis laws of the reform system, riding the existing Standing
//  Committee law pipeline (proposeLawChange → vote → processLawChangeVote).
//  Each is a LADDER over LawState — reforms move ONE step per vote, in
//  either direction, mirroring how real regimes liberalize (or re-harden)
//  in stages rather than leaps:
//
//    constitutional_order:  strengthened ← default → modifiedWeak → modifiedStrong
//                           (reinforced     one-party   hybrid        electoral
//                            party-state)   state       assembly      democracy
//
//    economic_constitution: strengthened ← default → modifiedWeak → modifiedStrong
//                           (command        market      mixed         free
//                            economy)       socialism   economy       market
//
//  .abolished is deliberately unreachable by vote: the suspension of
//  constitutional order is what juntas and collapses do TO you (forced
//  transitions), never something a committee passes. Kleptocracy likewise
//  arrives by degeneration, not proposal.
//

import Foundation

enum ReformLaws {
    static let politicalLawId = "constitutional_order"
    static let economicLawId = "economic_constitution"

    /// Ladder position for each votable state; .abolished has none.
    private static func rung(of state: LawState) -> Int? {
        switch state {
        case .strengthened: return 0
        case .defaultState: return 1
        case .modifiedWeak: return 2
        case .modifiedStrong: return 3
        case .abolished: return nil
        }
    }

    static func isReformLaw(_ law: Law) -> Bool {
        law.lawId == politicalLawId || law.lawId == economicLawId
    }

    static func politicalOrder(for state: LawState) -> PoliticalOrderType? {
        switch state {
        case .strengthened, .defaultState: return .partyState
        case .modifiedWeak: return .hybridAssembly
        case .modifiedStrong: return .electoralDemocracy
        case .abolished: return nil
        }
    }

    static func economicSystem(for state: LawState) -> EconomicSystemType? {
        switch state {
        case .strengthened: return .commandEconomy
        case .defaultState: return .marketSocialism
        case .modifiedWeak: return .mixedEconomy
        case .modifiedStrong: return .freeMarket
        case .abolished: return nil
        }
    }

    // MARK: - Proposal gating

    /// Reform laws move one rung at a time; non-reform laws are unrestricted.
    static func isLegalTransition(law: Law, to newState: LawState) -> Bool {
        guard isReformLaw(law) else { return true }
        guard let from = rung(of: law.lawCurrentState), let to = rung(of: newState) else { return false }
        return abs(from - to) == 1
    }

    /// Extra structural preconditions beyond power/faction gates. Returns a
    /// player-readable reason the step is blocked, or nil if it can proceed.
    /// The political-science teeth: the army must acquiesce to
    /// democratization, and elites need enough residual loyalty that
    /// liberalization reads as a pact rather than a surrender.
    static func blockReason(law: Law, to newState: LawState, game: Game) -> String? {
        guard isReformLaw(law) else { return nil }
        if !isLegalTransition(law: law, to: newState) {
            return "Reforms proceed one stage at a time."
        }
        if law.lawId == politicalLawId {
            if newState == .modifiedStrong && game.militaryLoyalty < 55 {
                return "The armed forces will not accept open elections (military loyalty below 55)."
            }
            if newState == .modifiedWeak && game.eliteLoyalty < 40 {
                return "The nomenklatura is too restive to share power safely (elite loyalty below 40)."
            }
        }
        return nil
    }

    // MARK: - Passage effects

    /// Called from processLawChangeVote when a reform law passes. Writes the
    /// axis, applies the immediate transition shock, logs the beat, stages
    /// the full-screen overlay, and cues the morning paper.
    static func applyAxisChange(law: Law, newState: LawState, game: Game) {
        guard isReformLaw(law), let to = rung(of: newState) else { return }
        let from = rung(of: law.lawCurrentState) ?? 1
        let liberalizing = to > from

        if law.lawId == politicalLawId, let order = politicalOrder(for: newState) {
            game.politicalOrder = order
            applyPoliticalShock(game: game, target: order, liberalizing: liberalizing)
            let summary = liberalizing
                ? "The Constitutional Order is amended: the Republic becomes \(order.displayName.lowercased() == "one-party state" ? "a one-party state" : "a \(order.displayName.lowercased())"). \(order.blurb)"
                : "The reforms are rolled back: the Republic returns to \(order.displayName.lowercased() == "one-party state" ? "a one-party state" : "a \(order.displayName.lowercased())"). The apparatus exhales."
            logReform(game: game, summary: summary, importance: 9)
            game.pendingStateEvent = StateEventPayload(
                id: UUID().uuidString,
                stampText: liberalizing ? "AMENDED" : "RESTORED",
                title: order.displayName.uppercased(),
                body: summary,
                accent: liberalizing ? .gold : .red
            )
            game.variables["press_domestic_flash"] = "reform_political"
        }

        if law.lawId == economicLawId, let system = economicSystem(for: newState) {
            game.economicSystemType = system.rawValue
            // A pilot-zone credit is spent the first time it helps a
            // liberalizing step pass (see PilotZone).
            if liberalizing {
                game.flags.removeAll { $0 == PilotZone.reformCreditFlag }
            }
            applyEconomicShock(game: game, liberalizing: liberalizing)
            let summary = "The Economic Constitution is revised: the Republic adopts \(system.displayName.lowercased()). Ministries scramble to reinterpret their mandates."
            logReform(game: game, summary: summary, importance: 8)
            game.variables["press_domestic_flash"] = "reform_economic"
        }
    }

    /// Immediate stat shock of a political-order step. Longer-run pressure
    /// (backlash events, faction shifts) rides the existing
    /// generateLawConsequences machinery.
    private static func applyPoliticalShock(game: Game, target: PoliticalOrderType, liberalizing: Bool) {
        if liberalizing {
            let toDemocracy = target == .electoralDemocracy
            game.applyStat("popularSupport", change: toDemocracy ? 10 : 6)
            game.applyStat("internationalStanding", change: toDemocracy ? 15 : 8)
            game.applyStat("eliteLoyalty", change: toDemocracy ? -12 : -8)
            game.applyStat("stability", change: toDemocracy ? -6 : -4)
            if toDemocracy { game.applyStat("militaryLoyalty", change: -8) }
            game.setIntVariable("elite_resentment", game.intVariable("elite_resentment") + 8)
        } else {
            game.applyStat("stability", change: 6)
            game.applyStat("eliteLoyalty", change: 6)
            game.applyStat("popularSupport", change: -6)
            game.applyStat("internationalStanding", change: -8)
        }
    }

    /// Immediate stat shock of an economic step; growth/inflation dynamics
    /// follow from EconomicSystemType's parameters, which EconomyService
    /// already consumes every turn.
    private static func applyEconomicShock(game: Game, liberalizing: Bool) {
        if liberalizing {
            game.applyStat("internationalStanding", change: 5)
            game.applyStat("eliteLoyalty", change: -5)
            game.applyStat("stability", change: -3)
        } else {
            game.applyStat("stability", change: 4)
            game.applyStat("internationalStanding", change: -5)
            game.applyStat("popularSupport", change: -3)
        }
    }

    private static func logReform(game: Game, summary: String, importance: Int) {
        let event = GameEvent(turnNumber: game.turnNumber, eventType: .crisis, summary: summary)
        event.importance = importance
        game.events.append(event)
    }

    // MARK: - Seeding

    /// Ensure the two reform laws exist (new games get them via
    /// createDefaultLaws; older saves are backfilled here — called when the
    /// Laws tab appears).
    static func ensureSeeded(game: Game) {
        if !game.laws.contains(where: { $0.lawId == politicalLawId }) {
            game.laws.append(makeConstitutionalOrderLaw())
        }
        if !game.laws.contains(where: { $0.lawId == economicLawId }) {
            game.laws.append(makeEconomicConstitutionLaw())
        }
    }

    static func makeConstitutionalOrderLaw() -> Law {
        let law = Law(
            lawId: politicalLawId,
            name: "Constitutional Order of the Republic",
            description: "Defines the structure of state power: one-party rule under the Standing Committee. Amendment toward an empowered assembly or open elections — or reinforcement of Party primacy — reshapes the regime itself. Reforms proceed one stage at a time.",
            category: .institutional
        )
        law.beneficiaries = ["youth_league"]
        law.losers = ["princelings"]
        return law
    }

    static func makeEconomicConstitutionLaw() -> Law {
        let law = Law(
            lawId: economicLawId,
            name: "Economic Constitution",
            description: "Defines the economic system: market socialism under state direction. Revision toward mixed or free markets — or back to full command planning — changes how the entire economy behaves. Reforms proceed one stage at a time.",
            category: .economic
        )
        law.beneficiaries = ["youth_league"]
        return law
    }
}
