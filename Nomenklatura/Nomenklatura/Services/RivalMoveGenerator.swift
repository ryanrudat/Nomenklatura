//
//  RivalMoveGenerator.swift
//  Nomenklatura
//
//  Wave 3 / Audit "deep-politics" — once-per-turn generator that picks
//  the most threatening eligible rival and produces 1 RivalMove for
//  them. Wave 5 wired this into the turn pipeline via `processTurn` and
//  added the matching Desk UI; resolution rolls thread through
//  `game.rng` so outcomes are reproducible per-seed.
//

import Foundation
import os.log

private let rivalMoveLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "RivalMoves")

@MainActor
final class RivalMoveGenerator {
    static let shared = RivalMoveGenerator()
    private init() {}

    // MARK: - Tuning

    /// Minimum rivalThreat for any rival move to spawn. Below this the
    /// political layer is too quiet for named threats to feel earned.
    private static let minimumRivalThreat: Int = 30

    /// Minimum positionIndex a character must hold to mount a named
    /// scheme against the Chairman. Junior NPCs lack the standing.
    private static let minimumRivalPosition: Int = 4

    /// Player has this turn plus N more to respond before the deadline
    /// triggers `pendingEffect`. `deadlineTurn = createdTurn + this`.
    private static let deadlineTurnsAhead: Int = 2

    /// Minimum turns that must elapse after a rival's last move (measured
    /// from `createdTurn`) before that rival can generate another. Without
    /// this gate the most-threatening rival was deterministically re-picked
    /// every turn the queue was empty, producing the "same rival again"
    /// repetition reported by playtest.
    private static let rivalReuseCooldownTurns: Int = 5

    // MARK: - Public API

    /// Per-turn entry point called from GameEngine.endTurnUpdates.
    ///
    /// Responsibilities:
    ///   1. Expires any move whose `deadlineTurn < game.turnNumber` and
    ///      applies its `pendingEffect` to game stats.
    ///   2. Generates one new move if no pending move exists (the
    ///      player should only juggle 1-2 at a time, not a stack).
    ///   3. Emits GameEvents for both expirations and new appearances
    ///      so the Journal records the political dance.
    ///
    /// All RNG is threaded through `game.rng` via the resolve/generate
    /// callees, which already take a `var rng` snapshot and restore on
    /// exit. This method itself does no random rolls — kind/template
    /// selection happens inside `generateNextMove`.
    func processTurn(for game: Game) {
        // 1. Expire overdue moves — apply pending damage, mark resolved.
        var moves = game.activeRivalMoves
        let expiredIndices = moves.indices.filter { idx in
            let move = moves[idx]
            // Treat moves whose deadline has passed (deadlineTurn < current)
            // as expired. Equality means "deadline is THIS turn" — the
            // player still gets one final chance to respond before
            // expiration applies at the next turn boundary.
            return move.resolution == .pending && move.deadlineTurn < game.turnNumber
        }

        var expiredEvents: [GameEvent] = []
        for idx in expiredIndices {
            let move = moves[idx]
            // Expiration applies 1.5× pendingEffect — caught-unaware penalty.
            // Players who explicitly tap "Take no action" pay 1.0× via
            // applyExpiredMove called from DeskView+TurnManagement.swift.
            applyExpiredMove(move, to: game, multiplier: 1.5)
            moves[idx].resolution = .expired

            let magnitude = Int((abs(move.pendingEffect.magnitude) * 1.5).rounded())
            let stat = move.pendingEffect.stat
            let summary = "\(move.rivalName)'s \(move.kind.shortLabel) cost you \(magnitude) \(stat)"
            let event = GameEvent(
                turnNumber: game.turnNumber,
                eventType: .crisis,
                summary: summary
            )
            event.importance = 7
            event.details = [
                "kind": "rival_move_expired",
                "rivalName": move.rivalName,
                "moveKind": move.kind.rawValue,
                "stat": stat,
                "magnitude": String(magnitude)
            ]
            event.game = game
            expiredEvents.append(event)

            rivalMoveLogger.info("Expired RivalMove on processTurn: \(move.rivalName, privacy: .public) → \(stat, privacy: .public) -\(magnitude)")
        }

        // Persist mutated list before generation so generator sees the
        // newly-expired moves as resolved (they no longer count toward
        // "pending" for candidate gating).
        if !expiredIndices.isEmpty {
            game.activeRivalMoves = moves
        }

        // Append expiration events.
        for event in expiredEvents {
            game.events.append(event)
        }

        // 2. Generate a new move only if no pending move exists.
        let pendingCount = game.activeRivalMoves.filter { !$0.resolution.isResolved }.count
        if pendingCount == 0, let newMove = generateNextMove(for: game) {
            var updated = game.activeRivalMoves
            updated.append(newMove)
            game.activeRivalMoves = updated

            let summary = "\(newMove.rivalName) is making a move: \(newMove.headline)"
            let event = GameEvent(
                turnNumber: game.turnNumber,
                eventType: .crisis,
                summary: summary
            )
            event.importance = 8
            event.details = [
                "kind": "rival_move_appeared",
                "rivalName": newMove.rivalName,
                "moveKind": newMove.kind.rawValue,
                "deadlineTurn": String(newMove.deadlineTurn)
            ]
            event.game = game
            game.events.append(event)

            rivalMoveLogger.info("Appeared RivalMove on processTurn: \(newMove.rivalName, privacy: .public) → \(newMove.kind.rawValue, privacy: .public)")
        }
    }

    /// Called once per turn (from GameEngine end-of-turn pipeline,
    /// eventually). Selects the most threatening rival who isn't
    /// already in an active move and generates 1 RivalMove for them.
    ///
    /// Returns nil when:
    ///   - game.rivalThreat < `minimumRivalThreat`
    ///   - no active character qualifies (no `isRival` / hostile-role
    ///     characters at position ≥ `minimumRivalPosition`)
    ///   - all eligible rivals already have an unresolved active move
    func generateNextMove(for game: Game) -> RivalMove? {
        var rng = game.rng
        defer { game.rng = rng }

        // Gate: rival threat must be high enough for named schemes to fire.
        guard game.rivalThreat >= Self.minimumRivalThreat else {
            rivalMoveLogger.debug("RivalMove suppressed: rivalThreat \(game.rivalThreat) < \(Self.minimumRivalThreat)")
            return nil
        }

        // Candidate rivals: active characters at sufficient position who
        // are flagged hostile (isRival) or whose role is .rival. Exclude
        // anyone with an unresolved active move OR anyone whose previous
        // move was made within the reuse cooldown window — that's the
        // gate that stops the same rival from re-spawning every turn.
        let activeRivalIds: Set<UUID> = Set(
            game.activeRivalMoves
                .filter { !$0.resolution.isResolved }
                .map { $0.rivalCharacterId }
        )

        let recentlyMovedRivalIds: Set<UUID> = Set(
            game.activeRivalMoves
                .filter { $0.resolution.isResolved }
                .filter { (game.turnNumber - $0.createdTurn) < Self.rivalReuseCooldownTurns }
                .map { $0.rivalCharacterId }
        )

        let candidates = game.characters.filter { char in
            char.isActive
                && (char.isRival || char.currentRole == .rival)
                && (char.positionIndex ?? 0) >= Self.minimumRivalPosition
                && !activeRivalIds.contains(char.id)
                && !recentlyMovedRivalIds.contains(char.id)
                // Belt-and-suspenders: a character co-opted via "Promote
                // Sideways" should never schedule new rival moves, even if
                // isRival flips back to true (e.g., disposition crashes).
                // The Co-opt Rival path already clears isRival at success
                // time, but a later drift could re-flag them — this stops
                // ceremonial members from re-entering the rival pool.
                && !char.hasCeremonialRole(in: game)
        }

        guard !candidates.isEmpty else {
            rivalMoveLogger.debug("RivalMove suppressed: no eligible rival candidates (active: \(activeRivalIds.count), on cooldown: \(recentlyMovedRivalIds.count))")
            return nil
        }

        // Score each candidate by ambition × ruthlessness × inverse loyalty.
        // Higher score = more likely to mount a named scheme. Pick via a
        // weighted roll over the top three (or fewer) so even a clear
        // dominant rival doesn't always go first — adds variety without
        // sacrificing the "biggest threat usually acts" intuition.
        let scored = candidates
            .map { char -> (GameCharacter, Double) in (char, scoreCandidate(char)) }
            .sorted { $0.1 > $1.1 }

        let topPool = Array(scored.prefix(3))
        guard let (rival, _) = weightedPick(topPool, using: &rng) else {
            return nil
        }

        // Pick a kind biased by the rival's personality / role, rotated
        // away from this rival's last kind so the same threat archetype
        // (e.g., "whisper campaign") doesn't repeat on every appearance.
        let lastKindForRival = mostRecentResolvedKind(forRival: rival.id, in: game)
        let kind = pickKind(for: rival, game: game, avoiding: lastKindForRival, using: &rng)

        // Pick a template for the chosen kind.
        let template = pickTemplate(for: kind, rivalName: rival.name, using: &rng)

        // Pending effect: kind drives stat; magnitude scaled by threat
        // and the rival's ruthlessness.
        let magnitude = pendingEffectMagnitude(for: game, rival: rival)
        let pending = PendingEffect(stat: kind.defaultStat, magnitude: magnitude)

        // Counter options: 3-4 sensible choices, costs and chances vary.
        let counters = buildCounterOptions(for: kind, rival: rival)

        let move = RivalMove(
            rivalCharacterId: rival.id,
            rivalName: rival.name,
            kind: kind,
            headline: template.headline,
            body: template.body,
            createdTurn: game.turnNumber,
            deadlineTurn: game.turnNumber + Self.deadlineTurnsAhead,
            pendingEffect: pending,
            counterOptions: counters
        )

        rivalMoveLogger.info("Generated RivalMove: \(rival.name, privacy: .public) → \(kind.rawValue, privacy: .public)")
        return move
    }

    /// Apply the pending effect of a move that the player did not counter.
    ///
    /// - Parameter multiplier: Scale factor on `pendingEffect.magnitude`.
    ///   Use `1.0` when the player explicitly chose `.ignored` ("Take no
    ///   action"); use `1.5` when the move silently `.expired` (player
    ///   let the deadline pass without responding — caught-unaware penalty).
    ///
    /// Caller is responsible for marking the move's resolution to
    /// `.expired` / `.ignored` and persisting the updated list.
    func applyExpiredMove(_ move: RivalMove, to game: Game, multiplier: Double = 1.0) {
        // applyStat takes an Int; round half-away-from-zero.
        let scaled = move.pendingEffect.magnitude * multiplier
        let change = Int(scaled.rounded())
        game.applyStat(move.pendingEffect.stat, change: change)
        rivalMoveLogger.info("Applied RivalMove damage: \(move.rivalName, privacy: .public) → \(move.pendingEffect.stat, privacy: .public) \(change) (×\(multiplier))")
    }

    /// Apply a player-chosen counter option. Rolls for success, applies
    /// the resulting deltas, and updates `game.activeRivalMoves` with
    /// the new `.countered(...)` resolution.
    ///
    /// If the move is not currently in `game.activeRivalMoves` (e.g.,
    /// already resolved or never added), the stat deltas are still
    /// applied but no list mutation happens.
    func resolve(move: RivalMove, with option: RivalCounterOption, in game: Game) {
        var rng = game.rng
        defer { game.rng = rng }
        let roll = Double.random(in: 0...1, using: &rng)
        let success = roll < option.outcome.successChance
        let deltas = success ? option.outcome.onSuccess : option.outcome.onFailure

        for delta in deltas {
            let change = Int(delta.delta.rounded())
            game.applyStat(delta.stat, change: change)
        }

        // Mark the move resolved in the persisted list (if present).
        var moves = game.activeRivalMoves
        if let idx = moves.firstIndex(where: { $0.id == move.id }) {
            moves[idx].resolution = .countered(
                optionId: option.id,
                success: success,
                turn: game.turnNumber
            )
            game.activeRivalMoves = moves
        }

        rivalMoveLogger.info("Resolved RivalMove: \(move.rivalName, privacy: .public) counter=\(option.label, privacy: .public) success=\(success)")
    }

    // MARK: - Scoring

    /// Score a candidate rival. Higher = more likely to mount a scheme.
    /// Weights: ambition and ruthlessness raise the score; loyalty
    /// reduces it; ambitious rivals not yet flagged as primary rival get
    /// a small bump so a secondary heel can also act.
    private func scoreCandidate(_ char: GameCharacter) -> Double {
        let ambition = Double(char.personalityAmbitious)
        let ruthless = Double(char.personalityRuthless)
        let disloyalty = Double(100 - char.personalityLoyal)

        // Multiplicative core captures "ambitious AND ruthless AND
        // disloyal" being much worse than any one alone.
        var score = (ambition / 100.0) * (ruthless / 100.0) * (disloyalty / 100.0) * 100.0

        // Bias: secondary rivals (isRival flag but lower position) still
        // matter; primary rivals at high position skew up.
        score += Double(char.positionIndex ?? 0) * 1.5

        // Bias: high grudge means they've been waiting for an opening.
        if char.grudgeLevel < -20 {
            score += Double(abs(char.grudgeLevel)) * 0.3
        }

        return score
    }

    // MARK: - Candidate / kind helpers

    /// Weighted pick over a small ranked pool. Top entry gets the most
    /// weight but lower-ranked candidates still have a real chance, so
    /// the same dominant rival doesn't go every single time.
    private func weightedPick(_ pool: [(GameCharacter, Double)], using rng: inout SeededRNG) -> (GameCharacter, Double)? {
        guard !pool.isEmpty else { return nil }
        if pool.count == 1 { return pool[0] }
        // Weights: 60% / 30% / 10% for top-three, normalized for shorter pools.
        let baseWeights: [Double] = [0.60, 0.30, 0.10]
        let weights = Array(baseWeights.prefix(pool.count))
        let total = weights.reduce(0, +)
        let roll = Double.random(in: 0..<total, using: &rng)
        var cursor: Double = 0
        for (i, w) in weights.enumerated() {
            cursor += w
            if roll < cursor { return pool[i] }
        }
        return pool.last
    }

    /// Last move kind this rival made, looking only at resolved moves on
    /// the game's history. Returns nil if this rival has never moved
    /// before. Used to bias `pickKind` away from immediate repetition.
    private func mostRecentResolvedKind(forRival rivalId: UUID, in game: Game) -> RivalMoveKind? {
        return game.activeRivalMoves
            .filter { $0.rivalCharacterId == rivalId && $0.resolution.isResolved }
            .sorted { $0.createdTurn > $1.createdTurn }
            .first?.kind
    }

    // MARK: - Kind selection

    private func pickKind(for rival: GameCharacter, game: Game, avoiding: RivalMoveKind? = nil, using rng: inout SeededRNG) -> RivalMoveKind {
        // Personality-driven biases build a candidate pool; the final pick
        // is random among candidates that don't match `avoiding`, so the
        // same rival rotates schemes between appearances.
        let amb = rival.personalityAmbitious
        let ruth = rival.personalityRuthless
        let corrupt = rival.personalityCorrupt

        var candidates: [RivalMoveKind] = []

        if rival.positionTrack == "military" || rival.positionTrack == "armedForces" {
            candidates.append(.militaryCircleApproach)
        }
        if rival.factionId != nil && amb >= 60 {
            candidates.append(.factionWhisperCampaign)
        }
        if rival.foreignAgentStatus.isForeignAgent || corrupt >= 70 {
            candidates.append(.foreignContact)
        }
        if ruth >= 70 && amb >= 60 {
            candidates.append(.rivalConsolidation)
        }
        if game.patronFavor <= 45 && amb >= 50 {
            candidates.append(.patronUnderminding)
        }
        if amb >= 50 && rival.personalityLoyal <= 40 {
            candidates.append(.publicCriticism)
        }
        // Always-available fallback.
        candidates.append(.factionWhisperCampaign)

        // Random pick among candidates that aren't the rival's last move;
        // if avoidance empties the pool, fall back to the full candidate set.
        let pool = candidates.filter { $0 != avoiding }
        return pool.randomElement(using: &rng)
            ?? candidates.randomElement(using: &rng)
            ?? .factionWhisperCampaign
    }

    // MARK: - Templates

    /// Pull a template (headline + 2-3 sentence body) for the chosen
    /// kind. Keep it simple — 2-3 variants per kind is plenty for this
    /// commit; LLM-driven content can come in a later wave.
    private func pickTemplate(for kind: RivalMoveKind, rivalName: String, using rng: inout SeededRNG) -> (headline: String, body: String) {
        let templates: [(String, String)] = templateLibrary(for: kind, rivalName: rivalName)
        // Deterministic-ish: pick by element count modulo a random index
        // so repeated calls don't always hit the same template.
        let i = Int.random(in: 0..<templates.count, using: &rng)
        return templates[i]
    }

    private func templateLibrary(for kind: RivalMoveKind, rivalName: String) -> [(String, String)] {
        switch kind {
        case .factionWhisperCampaign:
            return [
                (
                    "\(rivalName) is scheduling private meetings.",
                    "Three senior Politburo members are listed on his calendar tonight. The agenda is unstated. If the meeting goes unanswered, members of the apparatus will begin to wonder which way the wind blows."
                ),
                (
                    "A whispering campaign has begun in the corridors.",
                    "\(rivalName) is letting it be known that the Chairman's recent decisions have unsettled the senior cadre. Two department heads have already excused themselves from your weekly briefing."
                ),
                (
                    "\(rivalName) has begun courting the old guard.",
                    "Quiet dinners. Long lunches. The kind of patient cultivation that becomes a faction. Allow it to mature and the standing committee will recalculate its loyalties without telling you."
                )
            ]
        case .militaryCircleApproach:
            return [
                (
                    "\(rivalName) is taking tea with the General Staff.",
                    "Officers at three commands report visits. Pleasantries, mostly. But every general remembers who came calling before the crisis arrived. Failure to interrupt the pattern hardens it."
                ),
                (
                    "An unscheduled meeting at the Ministry of Defense.",
                    "\(rivalName) has been seen with the deputy chief of staff. No minutes. No clerk. The kind of conversation that doesn't appear in the records but does appear in subsequent decisions."
                ),
                (
                    "\(rivalName) is lobbying the armed forces.",
                    "Promises of expanded budgets. Whispered grievances about the Chairman's interference. The brass is listening — they always listen to anyone offering them more."
                )
            ]
        case .publicCriticism:
            return [
                (
                    "\(rivalName) is preparing a public address.",
                    "The text, smuggled out of his secretariat, contains a coded critique of recent decrees. Phrased carefully — nothing actionable — but the working class will hear it clearly enough."
                ),
                (
                    "A subordinate of \(rivalName) has been talking to the press.",
                    "Two articles in the regional papers carry the unmistakable rhythm of his speeches. The Chairman is not named. The Chairman never is, in these things."
                ),
                (
                    "Posters have appeared on the factory walls.",
                    "Not openly hostile — the censors won't catch them — but the workers will read between the lines. \(rivalName) has friends in the cultural department, and they have ink."
                )
            ]
        case .foreignContact:
            return [
                (
                    "\(rivalName) was seen at the foreign embassy reception.",
                    "Longer conversations than protocol required. The Western ambassador is a careful reader of internal politics. He left with an impression, and that impression will travel."
                ),
                (
                    "A back-channel has opened to a neighbouring capital.",
                    "Coded correspondence. Officially attributed to a low-level trade delegation. The signature, when our analysts squint, is unmistakably \(rivalName)'s."
                ),
                (
                    "\(rivalName) is talking out of school to foreigners.",
                    "The intercepts are fragmentary but the tone is unflattering. Allow this to continue and we will read about the Chairman's failings in next week's foreign press."
                )
            ]
        case .patronUnderminding:
            return [
                (
                    "\(rivalName) is poisoning the well with your patron.",
                    "Three separate visits this week. Each time, the topic drifted to your recent missteps. Your patron is patient, but patience is a finite resource and \(rivalName) seems determined to exhaust it."
                ),
                (
                    "A whispered dossier has reached your patron's desk.",
                    "Compiled, our sources say, by \(rivalName)'s staff. Nothing fabricated — but selectively assembled, in the way these things always are. The framing is not flattering."
                ),
                (
                    "\(rivalName) is offering to brief your patron in your stead.",
                    "An efficiency, he calls it. The Chairman is so busy — let me handle the routine matters. A pleasant offer with a knife inside it."
                )
            ]
        case .rivalConsolidation:
            return [
                (
                    "\(rivalName) is moving openly to consolidate.",
                    "Two of his deputies have been promoted into key vacancies this week. The patronage tree is growing in earnest. Each branch will support the trunk when the time comes."
                ),
                (
                    "\(rivalName) has begun granting favors.",
                    "Apartments. Plum assignments. Quiet pardons for cousins. Standard apparatus currency, and \(rivalName) is spending it with enthusiasm. Spent favors become owed loyalty."
                ),
                (
                    "A small but loyal faction is taking shape around \(rivalName).",
                    "Half a dozen names — junior, but capable. The kind of bench you build before you make a move. Watch the bench grow long enough and the move is already won."
                )
            ]
        }
    }

    // MARK: - Pending effect magnitude

    /// Scale the pending damage by overall rival threat: a quiet
    /// political layer produces -3 to -5; a violent one produces -8 to -10.
    /// The rival's `ruthlessDamageMultiplier` further scales the base by
    /// 0.7x...1.3x — merciful rivals hit softer, ruthless ones hit harder.
    private func pendingEffectMagnitude(for game: Game, rival: GameCharacter) -> Double {
        let threat = Double(game.rivalThreat)
        // Linear map from rivalThreat 30...100 onto magnitude 3...10.
        let clamped = max(30.0, min(100.0, threat))
        let baseScale = 3.0 + ((clamped - 30.0) / 70.0) * 7.0
        return -(baseScale * rival.ruthlessDamageMultiplier)
    }

    // MARK: - Counter options

    /// Build a small library of counter options tailored to the kind.
    /// Costs are sensible defaults; the player picks whichever feels
    /// worth the risk-vs-reward trade.
    private func buildCounterOptions(for kind: RivalMoveKind, rival: GameCharacter) -> [RivalCounterOption] {
        switch kind {
        case .factionWhisperCampaign:
            return [
                RivalCounterOption(
                    label: "[SURVEIL]",
                    description: "Have State Security shadow him. If we catch a misstep it's leverage; if not we have a paper trail.",
                    cost: CounterCost(actionPoints: 1, network: 15, treasury: 0),
                    outcome: CounterOutcome(
                        successChance: 0.65,
                        onSuccess: [StatDelta(stat: "eliteLoyalty", delta: 4), StatDelta(stat: "rivalThreat", delta: -5)],
                        onFailure: [StatDelta(stat: "eliteLoyalty", delta: -2)]
                    )
                ),
                RivalCounterOption(
                    label: "[CONFRONT]",
                    description: "Summon him publicly. Make the campaign explicit and let the Politburo see it.",
                    cost: CounterCost(actionPoints: 1, network: 5, treasury: 0),
                    outcome: CounterOutcome(
                        successChance: 0.45,
                        onSuccess: [StatDelta(stat: "standing", delta: 5), StatDelta(stat: "eliteLoyalty", delta: 2)],
                        onFailure: [StatDelta(stat: "standing", delta: -4), StatDelta(stat: "eliteLoyalty", delta: -3)]
                    )
                ),
                RivalCounterOption(
                    label: "[OUT-MEET]",
                    description: "Schedule your own quiet dinners with the same three members. Match him move for move.",
                    cost: CounterCost(actionPoints: 1, network: 10, treasury: 3),
                    outcome: CounterOutcome(
                        successChance: 0.70,
                        onSuccess: [StatDelta(stat: "eliteLoyalty", delta: 5), StatDelta(stat: "patronFavor", delta: 2)],
                        onFailure: [StatDelta(stat: "eliteLoyalty", delta: -2)]
                    )
                )
            ]

        case .militaryCircleApproach:
            return [
                RivalCounterOption(
                    label: "[REASSIGN]",
                    description: "Issue a routine rotation order moving the implicated officers. Standard discipline, nothing pointed.",
                    cost: CounterCost(actionPoints: 1, network: 10, treasury: 2),
                    outcome: CounterOutcome(
                        successChance: 0.60,
                        onSuccess: [StatDelta(stat: "militaryLoyalty", delta: 5)],
                        onFailure: [StatDelta(stat: "militaryLoyalty", delta: -3)]
                    )
                ),
                RivalCounterOption(
                    label: "[DECORATE]",
                    description: "Award medals at this week's parade. Reaffirm whose army it is.",
                    cost: CounterCost(actionPoints: 1, network: 5, treasury: 4),
                    outcome: CounterOutcome(
                        successChance: 0.75,
                        onSuccess: [StatDelta(stat: "militaryLoyalty", delta: 6), StatDelta(stat: "popularSupport", delta: 1)],
                        onFailure: [StatDelta(stat: "treasury", delta: -3)]
                    )
                ),
                RivalCounterOption(
                    label: "[INVESTIGATE]",
                    description: "Quiet inquiry into the General Staff visits. Risky — generals don't enjoy being audited.",
                    cost: CounterCost(actionPoints: 1, network: 20, treasury: 0),
                    outcome: CounterOutcome(
                        successChance: 0.40,
                        onSuccess: [StatDelta(stat: "militaryLoyalty", delta: 3), StatDelta(stat: "rivalThreat", delta: -7)],
                        onFailure: [StatDelta(stat: "militaryLoyalty", delta: -6)]
                    )
                )
            ]

        case .publicCriticism:
            return [
                RivalCounterOption(
                    label: "[PRE-EMPT]",
                    description: "Place a friendly editorial in tomorrow's papers framing the issue first.",
                    cost: CounterCost(actionPoints: 1, network: 5, treasury: 2),
                    outcome: CounterOutcome(
                        successChance: 0.70,
                        onSuccess: [StatDelta(stat: "popularSupport", delta: 4)],
                        onFailure: [StatDelta(stat: "popularSupport", delta: -2)]
                    )
                ),
                RivalCounterOption(
                    label: "[CENSOR]",
                    description: "Have the cultural department suppress the relevant pieces. Heavy-handed but effective.",
                    cost: CounterCost(actionPoints: 1, network: 10, treasury: 0),
                    outcome: CounterOutcome(
                        successChance: 0.65,
                        onSuccess: [StatDelta(stat: "popularSupport", delta: 2), StatDelta(stat: "rivalThreat", delta: -4)],
                        onFailure: [StatDelta(stat: "popularSupport", delta: -5)]
                    )
                ),
                RivalCounterOption(
                    label: "[CO-OPT]",
                    description: "Announce a popular gesture before he can — bread subsidy, holiday bonus, public works.",
                    cost: CounterCost(actionPoints: 1, network: 0, treasury: 5),
                    outcome: CounterOutcome(
                        successChance: 0.80,
                        onSuccess: [StatDelta(stat: "popularSupport", delta: 6)],
                        onFailure: [StatDelta(stat: "treasury", delta: -3)]
                    )
                )
            ]

        case .foreignContact:
            return [
                RivalCounterOption(
                    label: "[INTERCEPT]",
                    description: "Have State Security tighten coverage of the embassy. Catch the next exchange.",
                    cost: CounterCost(actionPoints: 1, network: 20, treasury: 0),
                    outcome: CounterOutcome(
                        successChance: 0.55,
                        onSuccess: [StatDelta(stat: "internationalStanding", delta: 2), StatDelta(stat: "rivalThreat", delta: -6)],
                        onFailure: [StatDelta(stat: "internationalStanding", delta: -3)]
                    )
                ),
                RivalCounterOption(
                    label: "[EXPEL]",
                    description: "Quietly request the foreign attaché's reassignment. The signal will be unmistakable.",
                    cost: CounterCost(actionPoints: 1, network: 5, treasury: 0),
                    outcome: CounterOutcome(
                        successChance: 0.50,
                        onSuccess: [StatDelta(stat: "internationalStanding", delta: -2), StatDelta(stat: "rivalThreat", delta: -5)],
                        onFailure: [StatDelta(stat: "internationalStanding", delta: -6)]
                    )
                ),
                RivalCounterOption(
                    label: "[DENOUNCE]",
                    description: "Publish a measured editorial about foreign meddling. Hint without naming.",
                    cost: CounterCost(actionPoints: 1, network: 5, treasury: 1),
                    outcome: CounterOutcome(
                        successChance: 0.65,
                        onSuccess: [StatDelta(stat: "popularSupport", delta: 3), StatDelta(stat: "internationalStanding", delta: -1)],
                        onFailure: [StatDelta(stat: "popularSupport", delta: -2)]
                    )
                )
            ]

        case .patronUnderminding:
            return [
                RivalCounterOption(
                    label: "[REASSURE]",
                    description: "Request a private audience with your patron. Address the dossier point by point.",
                    cost: CounterCost(actionPoints: 1, network: 10, treasury: 0),
                    outcome: CounterOutcome(
                        successChance: 0.70,
                        onSuccess: [StatDelta(stat: "patronFavor", delta: 6)],
                        onFailure: [StatDelta(stat: "patronFavor", delta: -2)]
                    )
                ),
                RivalCounterOption(
                    label: "[COUNTER-DOSSIER]",
                    description: "Have your secretariat prepare a richer record of \(rival.name)'s own missteps and circulate it.",
                    cost: CounterCost(actionPoints: 1, network: 15, treasury: 2),
                    outcome: CounterOutcome(
                        successChance: 0.55,
                        onSuccess: [StatDelta(stat: "patronFavor", delta: 4), StatDelta(stat: "rivalThreat", delta: -5)],
                        onFailure: [StatDelta(stat: "patronFavor", delta: -4)]
                    )
                ),
                RivalCounterOption(
                    label: "[GIFT]",
                    description: "A timely, well-chosen tribute to your patron. Cynical but effective.",
                    cost: CounterCost(actionPoints: 0, network: 0, treasury: 5),
                    outcome: CounterOutcome(
                        successChance: 0.75,
                        onSuccess: [StatDelta(stat: "patronFavor", delta: 5)],
                        onFailure: [StatDelta(stat: "treasury", delta: -3)]
                    )
                )
            ]

        case .rivalConsolidation:
            return [
                RivalCounterOption(
                    label: "[BLOCK-APPOINTMENTS]",
                    description: "Veto the next two of \(rival.name)'s personnel proposals at the cadre department.",
                    cost: CounterCost(actionPoints: 1, network: 15, treasury: 0),
                    outcome: CounterOutcome(
                        successChance: 0.60,
                        onSuccess: [StatDelta(stat: "standing", delta: 5), StatDelta(stat: "rivalThreat", delta: -6)],
                        onFailure: [StatDelta(stat: "standing", delta: -3), StatDelta(stat: "eliteLoyalty", delta: -2)]
                    )
                ),
                RivalCounterOption(
                    label: "[REWARD-LOYALISTS]",
                    description: "Promote two of your own people into the same vacancies. Match the patronage tree branch for branch.",
                    cost: CounterCost(actionPoints: 1, network: 10, treasury: 3),
                    outcome: CounterOutcome(
                        successChance: 0.70,
                        onSuccess: [StatDelta(stat: "standing", delta: 4), StatDelta(stat: "eliteLoyalty", delta: 3)],
                        onFailure: [StatDelta(stat: "standing", delta: -2)]
                    )
                ),
                RivalCounterOption(
                    label: "[ISOLATE]",
                    description: "Move \(rival.name) sideways — a prestigious but powerless committee chair. A velvet coffin.",
                    cost: CounterCost(actionPoints: 1, network: 20, treasury: 0),
                    outcome: CounterOutcome(
                        successChance: 0.40,
                        onSuccess: [StatDelta(stat: "rivalThreat", delta: -10), StatDelta(stat: "standing", delta: 3)],
                        onFailure: [StatDelta(stat: "standing", delta: -6), StatDelta(stat: "eliteLoyalty", delta: -3)]
                    )
                )
            ]
        }
    }
}

// MARK: - RivalMoveKind display helpers

extension RivalMoveKind {

    /// Short, lowercased label used in Journal summaries — e.g.
    /// "Volkov's whisper campaign cost you 6 eliteLoyalty". Kept tight
    /// so the summary fits the existing GameEvent.summary phrasing.
    var shortLabel: String {
        switch self {
        case .factionWhisperCampaign: return "whisper campaign"
        case .militaryCircleApproach: return "military outreach"
        case .publicCriticism:        return "public criticism"
        case .foreignContact:         return "foreign contact"
        case .patronUnderminding:     return "patron undermining"
        case .rivalConsolidation:     return "consolidation push"
        }
    }

    /// Display label for the targeted stat — used in the Desk card's
    /// "IF UNANSWERED" line and the counter sheet's outcome rows.
    var threatStatDisplay: String {
        switch self {
        case .factionWhisperCampaign: return "ELITE LOYALTY"
        case .militaryCircleApproach: return "MILITARY LOYALTY"
        case .publicCriticism:        return "POPULAR SUPPORT"
        case .foreignContact:         return "INTERNATIONAL STANDING"
        case .patronUnderminding:     return "PATRON FAVOR"
        case .rivalConsolidation:     return "STANDING"
        }
    }
}

// MARK: - StatDelta display helpers

extension StatDelta {

    /// Uppercased monospace-friendly stat label used in the counter
    /// sheet's outcome rows. Keeps the wire stat keys ("eliteLoyalty")
    /// out of the player-facing UI.
    var displayStat: String {
        switch stat {
        case "stability":             return "STABILITY"
        case "popularSupport":        return "POPULAR SUPPORT"
        case "militaryLoyalty":       return "MILITARY LOYALTY"
        case "eliteLoyalty":          return "ELITE LOYALTY"
        case "treasury":              return "TREASURY"
        case "industrialOutput":      return "INDUSTRIAL OUTPUT"
        case "foodSupply":            return "FOOD SUPPLY"
        case "internationalStanding": return "INTERNATIONAL STANDING"
        case "standing":              return "STANDING"
        case "patronFavor":           return "PATRON FAVOR"
        case "rivalThreat":           return "RIVAL THREAT"
        case "network":               return "NETWORK"
        default:                      return stat.uppercased()
        }
    }
}
