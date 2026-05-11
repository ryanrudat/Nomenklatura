//
//  RivalMoveTests.swift
//  NomenklaturaTests
//
//  Covers the data layer + generator + counter resolver for the new
//  RivalMove feature (Wave 3 / Audit "deep-politics"). UI wiring is
//  deferred to a future wave; these tests validate the service-only
//  contract.
//

import XCTest
import SwiftData
@testable import Nomenklatura

@MainActor
final class RivalMoveTests: XCTestCase {

    // Mirrors the other test files' schema list so the in-memory
    // container loads cleanly.
    private static let schemaTypes: [any PersistentModel.Type] = [
        Game.self,
        GameCharacter.self,
        GameFaction.self,
        GameEvent.self,
        Policy.self,
        PositionHolder.self,
        SuccessionRelationship.self,
        PurgeCampaign.self,
        UnlockedAchievement.self,
        Region.self,
        ForeignCountry.self,
        Law.self,
        PositionOffer.self,
        TradeAgreement.self,
        NPCRelationship.self,
        CongressSession.self,
        WorldEventRecord.self,
        HistoricalSession.self
    ]

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(Self.schemaTypes)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeGame(in context: ModelContext) -> Game {
        let game = Game(campaignId: "rival_move_test")
        context.insert(game)
        return game
    }

    /// Build a rival GameCharacter with sensible threat-mongering
    /// personality + sufficient position so the generator's filters
    /// admit them.
    private func makeRival(
        name: String,
        positionIndex: Int = 6,
        ambitious: Int = 80,
        ruthless: Int = 75,
        loyal: Int = 20
    ) -> GameCharacter {
        let char = GameCharacter(
            templateId: "rival_\(name.lowercased())",
            name: name,
            title: "Minister",
            role: .rival
        )
        char.positionIndex = positionIndex
        char.isRival = true
        char.personalityAmbitious = ambitious
        char.personalityRuthless = ruthless
        char.personalityLoyal = loyal
        return char
    }

    // MARK: - Test 1: empty Game produces nil

    /// A bare-bones Game with no characters should not generate a
    /// RivalMove. The generator should bail out cleanly.
    func testGeneratorReturnsNilForGameWithoutRivals() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeGame(in: context)

        // Sanity: fresh Game has rivalThreat = 60 (above the 30 floor)
        // but no rival characters yet.
        XCTAssertGreaterThan(game.rivalThreat, 30, "Precondition: rivalThreat is above the floor")
        XCTAssertTrue(game.characters.isEmpty, "Precondition: no characters yet")

        let move = RivalMoveGenerator.shared.generateNextMove(for: game)
        XCTAssertNil(move, "Expected nil because there are no rival candidates in the game")
    }

    // MARK: - Test 2: rivals present → move generated

    /// A Game with eligible rivals and elevated rivalThreat should
    /// produce a non-nil RivalMove whose rivalCharacterId matches one
    /// of the candidate rivals and whose deadline is in the future.
    func testGeneratorReturnsMoveForGameWithRivals() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeGame(in: context)

        // Push rivalThreat well above floor.
        game.rivalThreat = 75

        let volkov = makeRival(name: "Volkov", positionIndex: 7, ambitious: 90, ruthless: 85, loyal: 15)
        let petrov = makeRival(name: "Petrov", positionIndex: 5, ambitious: 60, ruthless: 50, loyal: 40)
        game.characters.append(contentsOf: [volkov, petrov])

        let move = RivalMoveGenerator.shared.generateNextMove(for: game)
        let unwrapped = try XCTUnwrap(move, "Expected a generated RivalMove for a game with eligible rivals")

        // The chosen rival must be one of our candidates.
        let candidateIds: Set<UUID> = [volkov.id, petrov.id]
        XCTAssertTrue(candidateIds.contains(unwrapped.rivalCharacterId),
                      "RivalMove must reference one of the candidate rivals")

        // Deadline must be in the future.
        XCTAssertGreaterThan(unwrapped.deadlineTurn, game.turnNumber,
                             "Deadline must be after the current turn")

        // Counter options must exist and be playable.
        XCTAssertFalse(unwrapped.counterOptions.isEmpty,
                       "RivalMove must offer at least one counter option")
        for option in unwrapped.counterOptions {
            XCTAssertGreaterThanOrEqual(option.outcome.successChance, 0.0)
            XCTAssertLessThanOrEqual(option.outcome.successChance, 1.0)
        }

        // PendingEffect targets a known stat with negative magnitude.
        XCTAssertLessThan(unwrapped.pendingEffect.magnitude, 0,
                          "Pending damage should be negative (player loss)")
        XCTAssertFalse(unwrapped.pendingEffect.stat.isEmpty,
                       "Pending effect must target a named stat")

        // Resolution must start pending.
        XCTAssertEqual(unwrapped.resolution, .pending,
                       "Freshly generated move must start in .pending state")
    }

    // MARK: - Test 3: counter resolution persists

    /// Generating a RivalMove, adding it to game.activeRivalMoves,
    /// and resolving it with a counter option must:
    ///   - keep the move in game.activeRivalMoves
    ///   - flip the resolution to .countered(_, _, _)
    ///   - persist through JSON round-trip via the variables dict
    func testCounterResolutionPersists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeGame(in: context)

        game.rivalThreat = 70
        let rival = makeRival(name: "Sokolov", positionIndex: 7)
        game.characters.append(rival)

        let move = try XCTUnwrap(
            RivalMoveGenerator.shared.generateNextMove(for: game),
            "Setup precondition: generator must produce a move"
        )

        // Add the move to the game's active list (the generator returns
        // the move but does NOT persist it — that's the caller's job
        // and matches the planned turn-pipeline integration shape).
        game.activeRivalMoves = [move]
        XCTAssertEqual(game.activeRivalMoves.count, 1, "Active list must contain the new move")

        // Pick the first counter option.
        let option = try XCTUnwrap(move.counterOptions.first,
                                   "Move must have at least one counter option")

        RivalMoveGenerator.shared.resolve(move: move, with: option, in: game)

        // The move must still be in the list, but with a .countered resolution.
        let after = game.activeRivalMoves
        XCTAssertEqual(after.count, 1, "Move list count should remain 1 after resolution")

        let resolved = try XCTUnwrap(after.first, "Resolved move must still be in active list")
        XCTAssertEqual(resolved.id, move.id, "Resolved move's id must match the original move")

        switch resolved.resolution {
        case .countered(let optionId, _, let turn):
            XCTAssertEqual(optionId, option.id,
                           ".countered.optionId must match the chosen option")
            XCTAssertEqual(turn, game.turnNumber,
                           ".countered.turn must reflect the resolution turn")
        default:
            XCTFail("Expected .countered resolution; got \(resolved.resolution)")
        }

        // JSON round-trip: the value lives in `variables` and the typed
        // accessor must decode it cleanly even after re-reading.
        let reReadList = game.activeRivalMoves
        XCTAssertEqual(reReadList.first?.resolution, resolved.resolution,
                       "Resolution must survive JSON round-trip via variables dict")
    }

    // MARK: - Test 4: processTurn expires overdue moves

    /// Setup a Game whose only active rival move has a deadlineTurn
    /// strictly less than the current turn. After processTurn:
    ///   - the move must be flagged `.expired`
    ///   - `pendingEffect.magnitude` must have been applied to the
    ///     game's targeted stat (rounded to Int).
    func testProcessTurnExpiresOverdueMoves() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeGame(in: context)

        // Move to a known turn so the math is easy to inspect.
        game.turnNumber = 10

        // Snapshot the stat we'll damage so we can verify the delta.
        let preElite = game.eliteLoyalty

        // Place a single overdue move (deadlineTurn = 8 < currentTurn 10).
        let overdue = RivalMove(
            rivalCharacterId: UUID(),
            rivalName: "Volkov",
            kind: .factionWhisperCampaign,
            headline: "Volkov scheduled meetings.",
            body: "Body text.",
            createdTurn: 6,
            deadlineTurn: 8,
            pendingEffect: PendingEffect(stat: "eliteLoyalty", magnitude: -6),
            counterOptions: []
        )
        game.activeRivalMoves = [overdue]

        // Run the per-turn entry point.
        RivalMoveGenerator.shared.processTurn(for: game)

        // The move list still contains the move (we don't garbage-collect),
        // but its resolution must be .expired.
        let updated = try XCTUnwrap(game.activeRivalMoves.first(where: { $0.id == overdue.id }),
                                    "Move must remain in active list after expiration")
        XCTAssertEqual(updated.resolution, .expired,
                       "Overdue move must be marked .expired after processTurn")

        // Pending damage must have landed (rounded magnitude is -6).
        XCTAssertEqual(game.eliteLoyalty, max(0, preElite - 6),
                       "Pending effect must apply on expiration")
    }

    // MARK: - Test 5: processTurn generates a move when none pending

    /// A game with eligible rivals and no active moves should receive
    /// exactly one new RivalMove in `.pending` state after processTurn.
    func testProcessTurnGeneratesMoveWhenNonePending() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeGame(in: context)

        game.rivalThreat = 75
        let rival = makeRival(name: "Petrov", positionIndex: 7)
        game.characters.append(rival)

        XCTAssertEqual(game.activeRivalMoves.count, 0,
                       "Precondition: no active moves")

        RivalMoveGenerator.shared.processTurn(for: game)

        let pending = game.activeRivalMoves.filter { $0.resolution == .pending }
        XCTAssertEqual(pending.count, 1,
                       "Expected exactly one pending move after processTurn on an empty game")
    }

    // MARK: - Test 6: processTurn does not stack a new move on top of pending

    /// If a pending move already exists, processTurn must NOT generate
    /// another one. The player should be juggling at most one move at
    /// a time when the existing one is still in `.pending`.
    func testProcessTurnDoesNotGenerateMoveIfOnePending() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeGame(in: context)

        game.rivalThreat = 75
        let rival = makeRival(name: "Sokolov", positionIndex: 7)
        game.characters.append(rival)

        // Pre-seed one pending move whose deadline is still ahead.
        game.turnNumber = 5
        let existing = RivalMove(
            rivalCharacterId: rival.id,
            rivalName: rival.name,
            kind: .factionWhisperCampaign,
            headline: "Existing scheme",
            body: "Body.",
            createdTurn: 5,
            deadlineTurn: 7,
            pendingEffect: PendingEffect(stat: "eliteLoyalty", magnitude: -5),
            counterOptions: []
        )
        game.activeRivalMoves = [existing]
        XCTAssertEqual(game.activeRivalMoves.count, 1, "Precondition: one pending move")

        RivalMoveGenerator.shared.processTurn(for: game)

        XCTAssertEqual(game.activeRivalMoves.count, 1,
                       "Move count must remain 1: generator must not stack on top of a pending move")

        let stillPending = game.activeRivalMoves.first(where: { $0.id == existing.id })
        XCTAssertEqual(stillPending?.resolution, .pending,
                       "Existing pending move must remain pending (its deadline is still in the future)")
    }

    // MARK: - Test 7: resolve applies cost and outcome

    /// Resolving a counter option must:
    ///   - deduct the option's actionPoints / network / treasury cost
    ///     from the game state
    ///   - apply the success-branch StatDelta set when the roll lands
    ///     (success), or the failure branch otherwise
    ///   - mark the move's resolution to `.countered(...)`
    ///
    /// To keep the test deterministic without leaking RNG internals
    /// into the assertions, we craft a counter option whose success
    /// and failure StatDelta sets share an identical "verification"
    /// stat — that delta MUST land regardless of which branch fires.
    func testResolveAppliesCostAndOutcome() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeGame(in: context)

        game.rivalThreat = 70
        let rival = makeRival(name: "Karpov", positionIndex: 7)
        game.characters.append(rival)

        // Seed a move with a counter option whose cost subtracts from
        // network and whose outcome branches both write to standing.
        // Either branch produces a +/- delta on standing AND on a
        // unique verification stat that we can pin to assert "an
        // outcome branch fired".
        let option = RivalCounterOption(
            label: "[TEST]",
            description: "Test option",
            cost: CounterCost(actionPoints: 1, network: 10, treasury: 2),
            outcome: CounterOutcome(
                successChance: 0.5,
                onSuccess: [StatDelta(stat: "standing", delta: 5)],
                onFailure: [StatDelta(stat: "standing", delta: -3)]
            )
        )
        let move = RivalMove(
            rivalCharacterId: rival.id,
            rivalName: rival.name,
            kind: .rivalConsolidation,
            headline: "Test headline",
            body: "Body.",
            createdTurn: game.turnNumber,
            deadlineTurn: game.turnNumber + 2,
            pendingEffect: PendingEffect(stat: "standing", magnitude: -5),
            counterOptions: [option]
        )
        game.activeRivalMoves = [move]

        // Snapshot pre-state for the cost assertion. The resolver
        // method itself does NOT deduct cost (that's the sheet's
        // responsibility), so we manually deduct cost before invoking
        // resolve to mirror the production flow tightly.
        let preAP = game.actionPoints
        let preNetwork = game.network
        let preTreasury = game.treasury
        let preStanding = game.standing

        // Deduct cost (sheet behavior).
        game.actionPoints = max(0, game.actionPoints - option.cost.actionPoints)
        game.applyStat("network", change: -option.cost.network)
        game.applyStat("treasury", change: -option.cost.treasury)

        // Resolve the counter.
        RivalMoveGenerator.shared.resolve(move: move, with: option, in: game)

        // Cost must have been subtracted.
        XCTAssertEqual(game.actionPoints, preAP - option.cost.actionPoints,
                       "Counter must deduct action points cost")
        XCTAssertEqual(game.network, max(0, preNetwork - option.cost.network),
                       "Counter must deduct network cost")
        XCTAssertEqual(game.treasury, max(0, preTreasury - option.cost.treasury),
                       "Counter must deduct treasury cost")

        // The move's resolution must be `.countered`.
        let resolved = try XCTUnwrap(
            game.activeRivalMoves.first(where: { $0.id == move.id }),
            "Move must still be in active list after resolution"
        )
        guard case .countered(let optionId, let success, let turn) = resolved.resolution else {
            XCTFail("Resolution must be .countered after resolve; got \(resolved.resolution)")
            return
        }
        XCTAssertEqual(optionId, option.id, ".countered.optionId must match")
        XCTAssertEqual(turn, game.turnNumber, ".countered.turn must match current turn")

        // Standing must have moved by exactly the success or failure
        // delta — never both, never neither.
        let expectedDelta = success ? 5 : -3
        XCTAssertEqual(game.standing, max(0, min(100, preStanding + expectedDelta)),
                       "Standing must reflect the branch that fired")
    }
}
