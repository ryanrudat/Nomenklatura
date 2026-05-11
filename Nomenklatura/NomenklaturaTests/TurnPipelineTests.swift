//
//  TurnPipelineTests.swift
//  NomenklaturaTests
//
//  Smoke-tests the end-of-turn pipeline by running it 100 times against a
//  minimal Game. Catches new crashes in turn processing and stat-clamping
//  regressions (political stats must stay within 0...100).
//

import XCTest
import SwiftData
@testable import Nomenklatura

@MainActor
final class TurnPipelineTests: XCTestCase {

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

    private func makeMinimalGame(in context: ModelContext) -> Game {
        let game = Game(campaignId: "turn_pipeline_test")
        context.insert(game)
        return game
    }

    func testEndTurnRuns100TimesWithoutThrowing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeMinimalGame(in: context)
        let ladder: [LadderPosition] = []

        // endTurnUpdates does not throw — but it can crash if any subsystem hits a
        // force unwrap or invariant violation. Running 100 iterations exercises the
        // RNG branches and accumulating-state codepaths (sparkline history, stat
        // drift, intelligence leaks, etc.).
        for _ in 0..<100 {
            GameEngine.shared.endTurnUpdates(game: game, ladder: ladder, recordHistory: true)
            // Caller is responsible for advancing the turn number — replicate
            // ContentView's increment so the loop captures realistic state.
            game.turnNumber += 1
        }

        XCTAssertEqual(game.turnNumber, 101, "Expected turn 101 after 100 increments from starting turn 1")
    }

    func testStatsStayInValidRanges() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeMinimalGame(in: context)
        let ladder: [LadderPosition] = []

        for _ in 0..<100 {
            GameEngine.shared.endTurnUpdates(game: game, ladder: ladder, recordHistory: true)
            game.turnNumber += 1
        }

        // Political stats (0...100). Treasury and other unbounded-feeling stats
        // are exempt per the task spec, but in this codebase Game.applyStat
        // clamps treasury to 0...100 too — we still skip asserting it here.
        let politicalStats: [(String, Int)] = [
            ("stability", game.stability),
            ("popularSupport", game.popularSupport),
            ("militaryLoyalty", game.militaryLoyalty),
            ("eliteLoyalty", game.eliteLoyalty),
            ("internationalStanding", game.internationalStanding)
        ]

        for (name, value) in politicalStats {
            XCTAssertGreaterThanOrEqual(value, 0, "\(name) must be >= 0 after 100 turns (got \(value))")
            XCTAssertLessThanOrEqual(value, 100, "\(name) must be <= 100 after 100 turns (got \(value))")
        }
    }
}
