//
//  ProsecutionPipelineService.swift
//  Nomenklatura
//
//  Unifying coordination layer for the three pre-existing prosecution entry
//  points (Desk document, Security Bureau directive, Personal Action purge).
//  Each entry point keeps its own narrative *feel* — the apparatus brought a
//  warrant; you wielded state power; you orchestrated this personally — but
//  this service holds the canonical "is a prosecution already running against
//  this character?" state and refuses to start a second pipeline against the
//  same target without an explicit ESCALATE / CANCEL decision from the player.
//
//  This is intentionally a coordination layer ON TOP of:
//    - ShowTrialService (handles trial mechanics)
//    - SecurityActionService.executeAction (handles arrest/investigation flows)
//    - GameEngine.executeAction (handles personal action effects)
//
//  We do NOT replace any of those services. We track who is in flight, what
//  stage they are at, and which entry point started it. Each entry point
//  calls `initiate` BEFORE doing its own work, and `initiate` returns false
//  if a prosecution is already active (the entry-point UI then surfaces the
//  3-way "Escalate / Defer / Cancel" prompt). Stage transitions are reported
//  via `updateStage(...)` from the existing services.
//
//  Storage: encoded JSON in `game.variables["prosecution_pipeline"]`, keyed
//  by character UUID string. This matches the BureauChiefAgencyService /
//  SecurityActionService pattern and avoids a schema migration.
//

import Foundation

// MARK: - Initiator

/// Where the player engaged the prosecution. The mechanical effect is the
/// same; this enum is preserved for narrative framing only.
enum ProsecutionInitiator: String, Codable {
    case deskDocument        // arrived as a Desk document (the apparatus brought this)
    case bureauDirective     // player ordered via Security bureau (wielding state power)
    case personalAction      // player organized via personal action (orchestrating personally)

    var displayName: String {
        switch self {
        case .deskDocument: return "Desk Document"
        case .bureauDirective: return "Bureau Directive"
        case .personalAction: return "Personal Action"
        }
    }
}

// MARK: - Stage

/// Coarse stage of a prosecution. Maps to the underlying service's state:
///   - .investigation: SecurityActionService case file / formal investigation
///   - .arrest: shuanggui detention initiated, evidence accumulating
///   - .trial: ShowTrialService has an active ShowTrial in any phase
///   - .sentencing: ShowTrial.phase == .sentencing or .completed
enum ProsecutionStage: String, Codable {
    case investigation
    case arrest
    case trial
    case sentencing

    var displayName: String {
        switch self {
        case .investigation: return "Investigation"
        case .arrest: return "Arrest"
        case .trial: return "Trial"
        case .sentencing: return "Sentencing"
        }
    }
}

// MARK: - State

/// Persistent record of an in-flight prosecution against a single character.
struct ProsecutionState: Codable {
    let targetCharacterId: UUID
    let initiator: ProsecutionInitiator
    let startedTurn: Int
    var stage: ProsecutionStage
    var evidenceLevel: Int        // 0-100, mirrors shuanggui evidence / trial charge weight
    var lastUpdatedTurn: Int

    init(
        targetCharacterId: UUID,
        initiator: ProsecutionInitiator,
        startedTurn: Int,
        stage: ProsecutionStage = .investigation,
        evidenceLevel: Int = 0
    ) {
        self.targetCharacterId = targetCharacterId
        self.initiator = initiator
        self.startedTurn = startedTurn
        self.stage = stage
        self.evidenceLevel = evidenceLevel
        self.lastUpdatedTurn = startedTurn
    }
}

// MARK: - Service

/// Not @MainActor — this is a pure coordination layer that only reads/writes
/// `game.variables` (a String dictionary) and `game.flags` (a String array).
/// It is safe to call from existing services regardless of their actor
/// isolation. The underlying services it advises (ShowTrialService,
/// SecurityActionService, GameEngine) continue to own their own concurrency.
final class ProsecutionPipelineService {
    static let shared = ProsecutionPipelineService()
    private init() {}

    private static let storageKey = "prosecution_pipeline"

    // MARK: Public API

    /// Returns the active prosecution for a character, or nil if none. This
    /// is the single source of truth — both the registry below AND a "live
    /// reality check" against ShowTrialService.activeShowTrials in case some
    /// other code path created a trial without registering (defensive).
    func activeProsecution(for characterId: UUID, in game: Game) -> ProsecutionState? {
        let registry = loadRegistry(from: game)
        if let state = registry[characterId.uuidString] {
            return state
        }
        // Defensive reality check — if a ShowTrial exists but we have no
        // record, synthesize one so we still report `hasActive == true`.
        if let trial = game.activeShowTrials.first(where: { $0.defendantId == characterId }) {
            return ProsecutionState(
                targetCharacterId: characterId,
                initiator: .deskDocument,  // unknown — assume the most common path
                startedTurn: trial.turnInitiated,
                stage: .trial,
                evidenceLevel: 50
            )
        }
        return nil
    }

    /// True if any prosecution is in flight against this character.
    func hasActive(for characterId: UUID, in game: Game) -> Bool {
        return activeProsecution(for: characterId, in: game) != nil
    }

    /// Initiates a prosecution from a specific entry point. The kind tags
    /// the narrative source but the underlying flow is shared.
    ///
    /// - Returns: `true` if the prosecution was registered, `false` if a
    ///   prosecution is already in flight against this target and the caller
    ///   did not pass `escalate: true`. When false is returned, the calling
    ///   entry point should surface its 3-way prompt (Escalate / Defer / Cancel).
    @discardableResult
    func initiate(
        kind: ProsecutionInitiator,
        target: GameCharacter,
        in game: Game,
        escalate: Bool = false
    ) -> Bool {
        let targetId = target.id

        if let existing = activeProsecution(for: targetId, in: game) {
            // Conflict — refuse unless caller explicitly escalates.
            guard escalate else {
                #if DEBUG
                print("[ProsecutionPipeline] REFUSED initiate(\(kind)) for \(target.name) — existing \(existing.initiator) prosecution at \(existing.stage)")
                #endif
                return false
            }
            // ESCALATE path: bump evidenceLevel and (if newer kind is more
            // aggressive) advance the stage. Keep the original initiator —
            // the apparatus remembers who started this — but log the escalation.
            var registry = loadRegistry(from: game)
            var bumped = existing
            bumped.evidenceLevel = min(100, bumped.evidenceLevel + 20)
            bumped.lastUpdatedTurn = game.turnNumber
            // Escalation by personal action / directive jumps a stage if still investigating.
            if bumped.stage == .investigation && (kind == .personalAction || kind == .bureauDirective) {
                bumped.stage = .arrest
            }
            registry[targetId.uuidString] = bumped
            saveRegistry(registry, to: game)

            // Surface escalation flag so the UI and AI prompts can react.
            let flag = "prosecution_escalated_\(targetId.uuidString.prefix(8))_turn_\(game.turnNumber)"
            if !game.flags.contains(flag) {
                game.flags.append(flag)
            }
            return true
        }

        // Fresh prosecution — register canonical state.
        let state = ProsecutionState(
            targetCharacterId: targetId,
            initiator: kind,
            startedTurn: game.turnNumber,
            stage: .investigation
        )
        var registry = loadRegistry(from: game)
        registry[targetId.uuidString] = state
        saveRegistry(registry, to: game)

        #if DEBUG
        print("[ProsecutionPipeline] OPENED prosecution(\(kind)) vs \(target.name) at turn \(game.turnNumber)")
        #endif
        return true
    }

    /// Cancel an in-flight prosecution. Called by an entry point that the
    /// player redirected to "Cancel pending prosecution". Note: this only
    /// clears the canonical registry — the calling service is responsible
    /// for halting its own pipeline (e.g., ShowTrialService.completeShowTrial,
    /// or removing the character from underInvestigation status). This
    /// service does NOT reach into those services automatically because the
    /// caller knows which one it controls.
    func cancel(target characterId: UUID, in game: Game) {
        var registry = loadRegistry(from: game)
        guard registry[characterId.uuidString] != nil else { return }
        registry.removeValue(forKey: characterId.uuidString)
        saveRegistry(registry, to: game)

        let flag = "prosecution_cancelled_\(characterId.uuidString.prefix(8))_turn_\(game.turnNumber)"
        if !game.flags.contains(flag) {
            game.flags.append(flag)
        }
    }

    /// Update stage / evidence on an existing prosecution. Called by the
    /// underlying services as they progress (e.g., SecurityActionService
    /// after a shuanggui evidence tick, ShowTrialService when the trial
    /// transitions phases). Silently no-ops if there's no registered
    /// prosecution — that allows the underlying services to call this
    /// unconditionally without first checking.
    func updateStage(
        for characterId: UUID,
        stage: ProsecutionStage,
        evidenceLevel: Int? = nil,
        in game: Game
    ) {
        var registry = loadRegistry(from: game)
        guard var state = registry[characterId.uuidString] else { return }
        state.stage = stage
        if let evidence = evidenceLevel {
            state.evidenceLevel = max(0, min(100, evidence))
        }
        state.lastUpdatedTurn = game.turnNumber
        registry[characterId.uuidString] = state
        saveRegistry(registry, to: game)
    }

    /// Called at the end of a completed trial (any sentence) or a cleared
    /// detention. Removes the registry entry so future prosecutions can be
    /// opened against the same target if they ever come back (rehabilitated
    /// characters, exiled return paths, etc.).
    func close(target characterId: UUID, in game: Game) {
        var registry = loadRegistry(from: game)
        guard registry[characterId.uuidString] != nil else { return }
        registry.removeValue(forKey: characterId.uuidString)
        saveRegistry(registry, to: game)
    }

    /// All active prosecutions (for UI listings, alert badges, etc.)
    func allActive(in game: Game) -> [ProsecutionState] {
        return Array(loadRegistry(from: game).values)
    }

    /// Remove registry entries that can no longer progress: the target is gone
    /// (dead/executed/removed) or the prosecution has stalled for `stallTurns`
    /// with no advancement and never reached trial/sentencing. Without this,
    /// entries leaked forever (close() only fired on completed show trials), so
    /// once a character was ever investigated they could never be re-prosecuted.
    /// Call once per turn. (Audit 2026-06.)
    func pruneStale(in game: Game, stallTurns: Int = 12) {
        var registry = loadRegistry(from: game)
        guard !registry.isEmpty else { return }

        let livingIds = Set(game.characters.filter { $0.isAlive }.map { $0.id.uuidString })
        let before = registry.count

        registry = registry.filter { key, state in
            // Target no longer exists or is dead → drop.
            guard livingIds.contains(key) else { return false }
            // Stalled below the trial stage for too long → drop so the player
            // can eventually re-prosecute.
            let stalled = (game.turnNumber - state.lastUpdatedTurn) >= stallTurns
            if stalled && state.stage != .trial && state.stage != .sentencing {
                return false
            }
            return true
        }

        if registry.count != before {
            saveRegistry(registry, to: game)
        }
    }

    // MARK: Storage

    private func loadRegistry(from game: Game) -> [String: ProsecutionState] {
        guard let raw = game.variables[Self.storageKey],
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: ProsecutionState].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveRegistry(_ registry: [String: ProsecutionState], to game: Game) {
        guard let data = try? JSONEncoder().encode(registry),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        game.variables[Self.storageKey] = string
    }
}
