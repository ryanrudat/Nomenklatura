//
//  PersonalityDriftService.swift
//  Nomenklatura
//
//  Audit fix: NPCs have personality traits seeded once at character creation
//  and never change. The memory system tracks emotional impact but does NOT
//  propagate into personality. An NPC who survives a purge does not become
//  more paranoid; one passed over for promotion does not become more bitter.
//
//  This service closes that loop. Each turn (end-of-turn pipeline) it scans
//  recent events + character state for four trigger conditions and applies
//  modest, clamped personality shifts.
//
//  Pipeline integration:
//    - Called once per turn from GameEngine.endTurnUpdates(), AFTER
//      processBureauChiefAgency (so chiefs' acts-on-neglect events are visible
//      in this scan window) and BEFORE processEconomicSystem (drift should
//      reflect personnel reality before the books close — though drift never
//      touches economic state, so ordering vs. economy is mostly cosmetic).
//    - turnNumber is NOT mutated inside endTurnUpdates (caller increments
//      AFTER), so "events from this turn" means `event.turnNumber ==
//      game.turnNumber`. The same is true for `character.statusChangedTurn`.
//
//  Design notes — flexibility on event detail keys:
//    - The original spec called for scanning events with details["kind"] ==
//      "trial_demotion" / "trial_execution" / "trial_imprisonment" /
//      "appointment". A code audit found that ShowTrialService writes its
//      outcomes via DynamicEvent (not GameEvent) and never emits a
//      details["kind"] marker; only CodexService and RivalMoveGenerator
//      currently populate details["kind"]. Rather than touch other services
//      (out of scope for this work), this service detects the same situations
//      via state-side signals:
//        * Demotion/promotion → snapshot positionIndex via
//          `game.variables["pos_drift_\(characterId)"]` and compare turn-over-
//          turn. (Promotion is corroborated by an event of type .promotion
//          this turn referencing the character; absent that, the snapshot
//          delta alone is treated as a re-shuffle and ignored.)
//        * Purge → scan characters whose `statusChangedTurn ==
//          game.turnNumber` AND whose `currentStatus` is
//          `.executed/.imprisoned/.exiled`. These are the "removed" NPCs;
//          their faction-mates are the witnesses.
//    - If a future agent wires details["kind"] = "trial_demotion" /
//      "appointment" etc. into the underlying services, the snapshot-based
//      detection here is still correct and idempotent (the dedupe flags are
//      keyed by the removed character's id + turn, not by event id).
//
//  Patron-protection trigger note:
//    - The spec referenced `character.patronCharacterId` and "patron
//      standing > 70". GameCharacter has no patronCharacterId field; patron
//      identity is modeled as `isPatron: Bool` on the GameCharacter that is
//      the PLAYER's patron, and `standing` is a property of `Game` (the
//      player's standing — there is no per-character standing). The
//      pragmatic interpretation used here: when the player has a living
//      patron (`game.patron != nil`) AND `game.standing > 70`, every active
//      NPC in the patron's faction gets +1 loyalty. This matches the spec's
//      intent ("patron's protection ripples through the faction") given the
//      actual data model.
//

import Foundation
import os.log

private let driftLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "PersonalityDrift")

@MainActor
final class PersonalityDriftService {
    static let shared = PersonalityDriftService()

    private init() {}

    // MARK: - Public API

    /// Run all four drift scans for this turn. Idempotent: per-event dedupe
    /// flags ensure re-running on the same turn cannot double-apply drift.
    /// Called once per turn from `GameEngine.endTurnUpdates`.
    func processDrift(for game: Game) {
        // Skip if game has no characters yet (very early bootstrap states).
        guard !game.characters.isEmpty else {
            updatePositionSnapshots(for: game)
            return
        }

        // Order matters only loosely. We run the three event-driven scans
        // first (they read snapshots), then the patron cycle, then refresh
        // snapshots for next turn's comparison.
        scanDemotions(in: game)
        scanPromotions(in: game)
        scanPurgeWitnesses(in: game)
        scanPatronProtection(in: game)

        updatePositionSnapshots(for: game)
    }

    // MARK: - Trigger 1: Demotion (positionIndex decreased this turn)

    /// Detect characters whose positionIndex DROPPED since last turn's
    /// snapshot. Applies resentment + ambition drift. Snapshot-based rather
    /// than event-scan because no service currently emits a `trial_demotion`
    /// kind marker.
    private func scanDemotions(in game: Game) {
        for character in game.characters where isDriftable(character) {
            guard let currentPos = character.positionIndex else { continue }
            guard let previousPos = priorPositionSnapshot(for: character, in: game) else {
                // No snapshot yet — first time we see this character. Skip
                // this turn (we'll catch a real drop next turn).
                continue
            }
            guard currentPos < previousPos else { continue }

            // Dedupe: one drift application per character per turn for this
            // trigger. Using turn + characterId keys the flag.
            let flagKey = "drift_demotion_\(character.id.uuidString)_t\(game.turnNumber)"
            if game.flags.contains(flagKey) { continue }
            game.flags.append(flagKey)

            applyDrift(
                to: character,
                trait: .ambitious,
                delta: 5,
                reason: "demotion (\(previousPos) -> \(currentPos))"
            )
            applyDrift(
                to: character,
                trait: .loyal,
                delta: -3,
                reason: "demotion (\(previousPos) -> \(currentPos))"
            )
        }
    }

    // MARK: - Trigger 2: Promotion by appointment

    /// Detect characters whose positionIndex INCREASED since last turn's
    /// snapshot. Corroborated by the presence of a `.promotion` GameEvent on
    /// this turn — without that corroboration we treat the delta as a
    /// re-shuffle and ignore it (so e.g. a character being seeded into a slot
    /// by some bootstrap path doesn't trigger gratitude drift).
    private func scanPromotions(in game: Game) {
        // Pre-collect promotion events for this turn. The current code emits
        // GameEvents of type .promotion for the PLAYER's own promotion; NPC
        // appointments are not yet uniformly logged with a structured kind
        // marker, so we accept either:
        //   (a) any .promotion event this turn, OR
        //   (b) any event this turn whose details["kind"] is in the
        //       appointment-y set (so when other agents wire those keys
        //       later, this trigger will sharpen).
        let promotionMarkersThisTurn = game.events.contains { event in
            guard event.turnNumber == game.turnNumber else { return false }
            if event.currentEventType == .promotion { return true }
            let kind = event.details["kind"] ?? ""
            return Self.appointmentKindMarkers.contains(kind)
        }

        for character in game.characters where isDriftable(character) {
            guard let currentPos = character.positionIndex else { continue }
            guard let previousPos = priorPositionSnapshot(for: character, in: game) else { continue }
            guard currentPos > previousPos else { continue }

            // Only apply gratitude if there's corroborating evidence of an
            // appointment this turn. Without it, the position delta could be
            // from any internal re-numbering and we don't want to falsely
            // boost loyalty.
            guard promotionMarkersThisTurn else { continue }

            let flagKey = "drift_promotion_\(character.id.uuidString)_t\(game.turnNumber)"
            if game.flags.contains(flagKey) { continue }
            game.flags.append(flagKey)

            applyDrift(
                to: character,
                trait: .loyal,
                delta: 3,
                reason: "appointment (\(previousPos) -> \(currentPos))"
            )
        }
    }

    // MARK: - Trigger 3: Witnessed a purge

    /// Identify characters whose status changed THIS turn to a "removed"
    /// state (executed / imprisoned / exiled). Their faction-mates witness
    /// the purge and gain paranoia. Per-removed-character + per-witness
    /// dedupe via flag so the same witness can't drift twice off the same
    /// purge if drift is re-run.
    private func scanPurgeWitnesses(in game: Game) {
        let removedCharacters = game.characters.filter { character in
            guard let changeTurn = character.statusChangedTurn else { return false }
            guard changeTurn == game.turnNumber else { return false }
            switch character.currentStatus {
            case .executed, .imprisoned, .exiled:
                return true
            default:
                return false
            }
        }

        guard !removedCharacters.isEmpty else { return }

        for removed in removedCharacters {
            guard let removedFaction = removed.factionId, !removedFaction.isEmpty else {
                // No faction → no witnesses to ripple to. (We could fall back
                // to "everyone in the same position track" but that would
                // over-fire on apolitical removals. Skip for v1.)
                continue
            }

            for witness in game.characters where isDriftable(witness) {
                // Don't witness yourself.
                guard witness.id != removed.id else { continue }
                // Same faction = ripple.
                guard witness.factionId == removedFaction else { continue }

                // Dedupe: one paranoia bump per witness per removed-event.
                // Spec called for `purge_witnessed_\(eventId)_by_\(characterId)`
                // — we don't always have a distinct eventId for the removal
                // (ShowTrialService doesn't emit a GameEvent for the
                // conclusion), so we key by the REMOVED character's id +
                // turn instead. This is functionally equivalent: a given
                // removal can only happen once.
                let flagKey = "purge_witnessed_\(removed.id.uuidString)_t\(game.turnNumber)_by_\(witness.id.uuidString)"
                if game.flags.contains(flagKey) { continue }
                game.flags.append(flagKey)

                applyDrift(
                    to: witness,
                    trait: .paranoid,
                    delta: 3,
                    reason: "witnessed purge of \(removed.name) (\(removed.currentStatus.displayText))"
                )
            }
        }
    }

    // MARK: - Trigger 4: Sustained patron protection (every 10 turns)

    /// Once every 10 turns, if the player has a living patron and the
    /// player's standing is > 70, every active NPC in the patron's faction
    /// gets +1 loyalty. Cycle-based idempotency via game flag keyed on
    /// `turnNumber / 10`.
    private func scanPatronProtection(in game: Game) {
        // Cycle window: turn 0-9 = cycle 0, 10-19 = cycle 1, etc. Once the
        // cycle's flag is set, we don't re-fire until the next 10-turn
        // window. We fire at the FIRST turn of each cycle that meets the
        // conditions — so if the player loses their patron mid-cycle and
        // gets one back before the cycle's flag is set, the protection
        // still applies.
        let cycle = game.turnNumber / 10
        let cycleFlagKey = "patron_protection_loyalty_cycle_\(cycle)"
        if game.flags.contains(cycleFlagKey) { return }

        guard let patron = game.patron, patron.isAlive else { return }
        guard game.standing > 70 else { return }
        guard let patronFaction = patron.factionId, !patronFaction.isEmpty else { return }

        // Mark cycle as processed regardless of whether we find recipients,
        // so we don't re-scan every turn within the cycle.
        game.flags.append(cycleFlagKey)

        for character in game.characters where isDriftable(character) {
            // Don't drift the patron themselves.
            guard character.id != patron.id else { continue }
            guard character.factionId == patronFaction else { continue }

            applyDrift(
                to: character,
                trait: .loyal,
                delta: 1,
                reason: "sustained patron protection (cycle \(cycle), patron \(patron.name))"
            )
        }
    }

    // MARK: - Snapshot management

    /// Capture each driftable character's current positionIndex into
    /// `game.variables` so next turn's scan can compare. Called at the END
    /// of `processDrift` so this turn's deltas are detected against last
    /// turn's snapshot, then refreshed for next time.
    private func updatePositionSnapshots(for game: Game) {
        for character in game.characters {
            let key = Self.positionSnapshotKey(for: character)
            if let pos = character.positionIndex {
                game.variables[key] = String(pos)
            } else {
                // Clear stale snapshot when character has no position
                // (e.g., just removed). This is correct: next turn's scan
                // shouldn't compare against a stale value.
                game.variables.removeValue(forKey: key)
            }
        }
    }

    private func priorPositionSnapshot(for character: GameCharacter, in game: Game) -> Int? {
        let key = Self.positionSnapshotKey(for: character)
        guard let stored = game.variables[key] else { return nil }
        return Int(stored)
    }

    private static func positionSnapshotKey(for character: GameCharacter) -> String {
        "pos_drift_\(character.id.uuidString)"
    }

    // MARK: - Drift application & filtering

    /// Whether this character is eligible for any drift in this scan. The
    /// safety contract from the spec: do not drift the player character or
    /// characters whose status is not .active.
    ///
    /// "Player character" is interpreted as "the leader role" — the game's
    /// Game model represents the player; there is no GameCharacter row for
    /// the player. The CharacterRole.leader role marks the in-game General
    /// Secretary persona that NPCs interact with. Excluding role == .leader
    /// is a conservative interpretation that ensures the player-facing AI
    /// proxy never drifts.
    private func isDriftable(_ character: GameCharacter) -> Bool {
        guard character.currentStatus == .active else { return false }
        if character.currentRole == .leader { return false }
        return true
    }

    /// Apply a clamped delta to a personality trait, log the change, and
    /// log a no-op if the trait was already at the bound. Logging happens
    /// only for actual changes to keep the os.log signal-to-noise high.
    private func applyDrift(
        to character: GameCharacter,
        trait: DriftableTrait,
        delta: Int,
        reason: String
    ) {
        let before: Int
        let after: Int

        switch trait {
        case .ambitious:
            before = character.personalityAmbitious
            after = max(0, min(100, before + delta))
            character.personalityAmbitious = after
        case .paranoid:
            before = character.personalityParanoid
            after = max(0, min(100, before + delta))
            character.personalityParanoid = after
        case .loyal:
            before = character.personalityLoyal
            after = max(0, min(100, before + delta))
            character.personalityLoyal = after
        }

        guard before != after else {
            // Trait was already pinned at the bound; nothing changed. Skip
            // logging to keep noise down.
            return
        }

        let signedDelta = after - before
        let sign = signedDelta >= 0 ? "+" : ""
        driftLogger.info(
            "Personality drift: \(character.id.uuidString, privacy: .public) \(trait.rawValue, privacy: .public) \(sign)\(signedDelta) (reason: \(reason, privacy: .public))"
        )
    }

    // MARK: - Trait & marker enums

    private enum DriftableTrait: String {
        case ambitious
        case paranoid
        case loyal
    }

    /// Event detail-kind markers that, if any service starts emitting them,
    /// will sharpen the promotion-trigger detection. Today none of these are
    /// populated by production code; the promotion trigger falls back to
    /// `event.currentEventType == .promotion` corroboration of the snapshot
    /// delta.
    private static let appointmentKindMarkers: Set<String> = [
        "appointment",
        "appointment_made",
        "promotion",
        "trial_promotion"
    ]
}
