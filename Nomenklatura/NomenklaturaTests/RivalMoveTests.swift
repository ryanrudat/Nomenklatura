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
}
