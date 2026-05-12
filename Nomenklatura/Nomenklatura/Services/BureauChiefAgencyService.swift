//
//  BureauChiefAgencyService.swift
//  Nomenklatura
//
//  Audit-tuning: Bureau chiefs notice when they're ignored — and act.
//
//  Pipeline integration:
//    - Called once per turn from GameEngine.endTurnUpdates(), AFTER directive
//      processing has completed (so we can see which bureaus the player issued
//      orders to this turn) but BEFORE economic processing (chiefs act before
//      the books close).
//
//  Mechanic:
//    - Each turn, for every bureau: if no directive was issued to it, increment
//      bureauNeglectTurns[bureau]. Otherwise reset to 0.
//    - When a bureau hits 3 consecutive neglected turns, the chief acts on their
//      own initiative — applying a bureau-flavored stat hit and (usually) firing
//      a GameEvent that surfaces in the briefing/journal.
//    - After firing, the counter is reset to 0 — this is one-shot per cycle, so
//      the chief doesn't act every turn after the threshold; they act, the
//      player gets a wake-up call, and the cycle restarts.
//
//  Detection of "issued this turn":
//    - For securityServices/economicPlanning/partyApparatus we read the unified
//      BureauOperationsService active-operations view and look for any operation
//      with initiatedTurn == game.turnNumber.
//    - For militaryPolitical we check MilitaryActionService.getActiveCampaigns
//      (campaigns are recorded with initiatedTurn = game.turnNumber on dispatch).
//    - For stateMinistry we check StateMinistryActionService.getActiveProjects.
//    - For foreignAffairs we decode the pending diplomatic actions blob on Game
//      (DiplomaticActionService stores DiplomaticActionRecord with initiatedTurn).
//

import Foundation

@MainActor
final class BureauChiefAgencyService {
    static let shared = BureauChiefAgencyService()

    private init() {}

    // MARK: - Public API

    /// Tick the neglect counter for every bureau, then fire chief consequences
    /// for any bureau that has been ignored for 3+ consecutive turns. Called
    /// once per turn from `GameEngine.endTurnUpdates`.
    func processNeglect(for game: Game) {
        // Snapshot the full counter map once, mutate locally, then assign back.
        // The underlying property is encoded JSON behind a computed accessor,
        // so doing this in one read/write avoids redundant encode round-trips.
        var counters = game.bureauNeglectTurns

        for bureau in trackedBureaus {
            let key = bureau.rawValue
            if didIssueDirective(to: bureau, game: game) {
                counters[key] = 0
                continue
            }

            let updated = (counters[key] ?? 0) + 1
            counters[key] = updated

            if updated >= neglectThreshold {
                applyChiefConsequence(for: bureau, game: game)
                // One-shot per cycle: chief acted; restart the clock so we
                // don't fire every subsequent turn until next directive lands.
                counters[key] = 0
            }
        }

        game.bureauNeglectTurns = counters
    }

    // MARK: - Configuration

    /// Number of consecutive neglected turns before the chief acts on their own.
    private let neglectThreshold = 3

    /// The six bureaus that have chiefs reporting up to the General Secretary.
    /// `.shared` and `.regional` are skipped — they're not bureau slots.
    private let trackedBureaus: [ExpandedCareerTrack] = [
        .securityServices,
        .militaryPolitical,
        .partyApparatus,
        .economicPlanning,
        .stateMinistry,
        .foreignAffairs
    ]

    // MARK: - Detection: "Was this bureau directed this turn?"

    private func didIssueDirective(to bureau: ExpandedCareerTrack, game: Game) -> Bool {
        let turn = game.turnNumber

        switch bureau {
        case .securityServices, .economicPlanning, .partyApparatus:
            // BureauOperationsService normalises all three of these to a
            // unified BureauOperation view. A directive issued this turn
            // shows up as an operation with initiatedTurn == game.turnNumber.
            let ops = BureauOperationsService.shared.getActiveOperations(for: bureau, game: game)
            return ops.contains { $0.initiatedTurn == turn }

        case .militaryPolitical:
            let campaigns = MilitaryActionService.shared.getActiveCampaigns(for: game)
            return campaigns.contains { $0.initiatedTurn == turn }

        case .stateMinistry:
            let projects = StateMinistryActionService.shared.getActiveProjects(for: game)
            return projects.contains { $0.initiatedTurn == turn }

        case .foreignAffairs:
            return diplomaticActionDispatched(thisTurn: turn, game: game)

        case .shared, .regional:
            return false
        }
    }

    /// Inspect the pending diplomatic actions blob stored under
    /// `game.variables["_pending_diplomatic_actions"]` (the same store
    /// DiplomaticActionService writes to). We only need to know whether ANY
    /// record was initiated this turn, so a minimal decoder is sufficient.
    private func diplomaticActionDispatched(thisTurn turn: Int, game: Game) -> Bool {
        guard let data = game.pendingDiplomaticActionsData else { return false }
        guard let records = try? JSONDecoder().decode([DiplomaticTurnProbe].self, from: data) else {
            return false
        }
        return records.contains { $0.initiatedTurn == turn }
    }

    /// A minimal Decodable shape that extracts just the `initiatedTurn` field
    /// from each DiplomaticActionRecord. Avoids coupling this service to the
    /// full record schema (which has many optional fields that may evolve).
    private struct DiplomaticTurnProbe: Decodable {
        let initiatedTurn: Int
    }

    // MARK: - Consequences

    private func applyChiefConsequence(for bureau: ExpandedCareerTrack, game: Game) {
        let turn = game.turnNumber

        switch bureau {
        case .securityServices:
            // The security chief acts alone: opens a quiet file on a sitting
            // Politburo member. The player isn't briefed — a flag marks the
            // event for later narrative payoff.
            let politburoIds = game.standingCommittee?.memberIds ?? []
            let targetId = politburoIds.randomElement()
            let flag = "sec_chief_acted_alone_\(turn)"
            if !game.flags.contains(flag) {
                game.flags.append(flag)
            }
            if let id = targetId {
                // Persist accumulated chief-driven suspicion against the
                // specific committee member so downstream systems (codex,
                // show trials, future security actions) can find it later.
                let key = "sec_chief_suspicion_\(id)"
                game.setIntVariable(key, game.intVariable(key) + 5)
            }
            // No GameEvent — this consequence is deliberately invisible.

        case .militaryPolitical:
            game.applyStat("militaryLoyalty", change: -3)
            recordChiefEvent(
                in: game,
                summary: "General Staff growing restless without direction"
            )

        case .partyApparatus:
            game.applyStat("eliteLoyalty", change: -2)
            recordChiefEvent(
                in: game,
                summary: "Party Secretariat operating without your guidance"
            )

        case .economicPlanning:
            game.applyStat("treasury", change: -10)
            recordChiefEvent(
                in: game,
                summary: "Planning Commission improvising allocations"
            )

        case .stateMinistry:
            game.applyStat("stability", change: -2)
            recordChiefEvent(
                in: game,
                summary: "Council of Ministers ruling by inertia"
            )

        case .foreignAffairs:
            game.applyStat("internationalStanding", change: -2)
            recordChiefEvent(
                in: game,
                summary: "Foreign Ministry making its own decisions"
            )

        case .shared, .regional:
            return
        }
    }

    /// Append a GameEvent describing a chief acting on neglect. Importance is
    /// elevated to 7 so it bubbles up in journal/AI context, but not so high
    /// that it dominates the briefing.
    private func recordChiefEvent(in game: Game, summary: String) {
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .narrative,
            summary: summary
        )
        event.importance = 7
        event.narrativeWeight = 6
        game.events.append(event)
    }
}
