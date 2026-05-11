//
//  DeterminismTests.swift
//  NomenklaturaTests
//
//  Asserts that two Game instances seeded with the same RNG seed produce
//  identical stat outcomes when driven through 50 turns of `endTurnUpdates`.
//  Closes the determinism gap so player bug reports become reproducible
//  given a save's seed and tests can assert exact stat values rather than
//  just "no exception thrown."
//

import XCTest
import SwiftData
@testable import Nomenklatura

@MainActor
final class DeterminismTests: XCTestCase {

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

    /// Build a fresh Game with an explicit RNG seed so the same seed drives
    /// the same outcomes regardless of `replaySeed` UUID generation.
    private func makeGame(seed: UInt64, in context: ModelContext) -> Game {
        let game = Game(campaignId: "determinism_test_\(seed)")
        game.variables["rng_seed"] = String(seed)
        context.insert(game)
        return game
    }

    /// Two games with the same RNG seed must produce identical stat trajectories
    /// over 50 turns. This is the central determinism contract.
    ///
    /// NOTE: passes today because GameEngine drives the dominant random source
    /// inside the turn pipeline. Will need expansion when EconomyService et al.
    /// are migrated — those services currently still touch the system PRNG, so
    /// any outcome divergence after that migration would surface here first.
    func testSameSeedProducesIdenticalOutcomes() throws {
        // Run 1: seed=42, 50 turns
        let container1 = try makeContainer()
        let context1 = ModelContext(container1)
        let game1 = makeGame(seed: 42, in: context1)
        let ladder: [LadderPosition] = []
        for _ in 0..<50 {
            GameEngine.shared.endTurnUpdates(game: game1, ladder: ladder, recordHistory: true)
            game1.turnNumber += 1
        }
        let snapshot1 = (
            stability: game1.stability,
            popularSupport: game1.popularSupport,
            treasury: game1.treasury,
            turnNumber: game1.turnNumber,
            militaryLoyalty: game1.militaryLoyalty,
            eliteLoyalty: game1.eliteLoyalty,
            rivalThreat: game1.rivalThreat,
            patronFavor: game1.patronFavor,
            internationalStanding: game1.internationalStanding
        )

        // Run 2: fresh container/game, same seed, same number of turns
        let container2 = try makeContainer()
        let context2 = ModelContext(container2)
        let game2 = makeGame(seed: 42, in: context2)
        for _ in 0..<50 {
            GameEngine.shared.endTurnUpdates(game: game2, ladder: ladder, recordHistory: true)
            game2.turnNumber += 1
        }
        let snapshot2 = (
            stability: game2.stability,
            popularSupport: game2.popularSupport,
            treasury: game2.treasury,
            turnNumber: game2.turnNumber,
            militaryLoyalty: game2.militaryLoyalty,
            eliteLoyalty: game2.eliteLoyalty,
            rivalThreat: game2.rivalThreat,
            patronFavor: game2.patronFavor,
            internationalStanding: game2.internationalStanding
        )

        XCTAssertEqual(snapshot1.turnNumber, snapshot2.turnNumber, "turnNumber diverged")
        XCTAssertEqual(snapshot1.stability, snapshot2.stability, "stability diverged")
        XCTAssertEqual(snapshot1.popularSupport, snapshot2.popularSupport, "popularSupport diverged")
        XCTAssertEqual(snapshot1.treasury, snapshot2.treasury, "treasury diverged")
        XCTAssertEqual(snapshot1.militaryLoyalty, snapshot2.militaryLoyalty, "militaryLoyalty diverged")
        XCTAssertEqual(snapshot1.eliteLoyalty, snapshot2.eliteLoyalty, "eliteLoyalty diverged")
        XCTAssertEqual(snapshot1.rivalThreat, snapshot2.rivalThreat, "rivalThreat diverged")
        XCTAssertEqual(snapshot1.patronFavor, snapshot2.patronFavor, "patronFavor diverged")
        XCTAssertEqual(snapshot1.internationalStanding, snapshot2.internationalStanding, "internationalStanding diverged")
    }

    /// Sanity-check the underlying SeededRNG primitive: same seed -> same stream.
    /// This guards against future regressions to SplitMix64 itself.
    func testSeededRNGPrimitiveIsDeterministic() {
        var rngA = SeededRNG(seed: 0xDEADBEEF)
        var rngB = SeededRNG(seed: 0xDEADBEEF)

        // 1000 draws is more than the turn pipeline burns in 50 turns; if the
        // primitive breaks, this test catches it before testSameSeedProducesIdenticalOutcomes
        // does — diagnostics are clearer here.
        for _ in 0..<1000 {
            XCTAssertEqual(rngA.next(), rngB.next(), "SeededRNG diverged between identically-seeded instances")
        }
    }

    /// Different seeds must yield different streams (sanity-check the seed
    /// actually matters — would catch an accidental "ignore seed" regression).
    func testDifferentSeedsDiverge() {
        var rngA = SeededRNG(seed: 1)
        var rngB = SeededRNG(seed: 2)

        // The first draw alone will diverge for SplitMix64; we just need any
        // pair-of-draws not to match.
        XCTAssertNotEqual(rngA.next(), rngB.next(), "Different seeds produced identical first draws — seed is being ignored")
    }
}
