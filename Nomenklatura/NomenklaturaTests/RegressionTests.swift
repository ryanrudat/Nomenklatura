//
//  RegressionTests.swift
//  NomenklaturaTests
//
//  Pinned regression tests for previously-fixed bugs. Each test maps to a
//  named entry in the project memory's known-bug-history so a future
//  refactor reintroducing the bug fails CI.
//
//  Currently covers: Game.applyStat(_:_:) must clamp political stats to
//  0...100 regardless of out-of-range input. This corresponds to the
//  "Stat clamping inconsistency fixed across 7 service files" entry in
//  the project memory (2026-04-14). The richer treasury-application
//  regression was deferred because EconomyService.applyEconomicReport
//  also re-clamps treasury via applyStat (0...100 clamp), which means
//  asserting "treasury changed by exactly netChange" requires synthesizing
//  a Game whose treasury sits well clear of either clamp boundary AND
//  building a fake EconomicReport — entangled enough that it would
//  expand this PR beyond its "establish foundation" scope. See commit
//  message for details.
//

import XCTest
import SwiftData
@testable import Nomenklatura

@MainActor
final class RegressionTests: XCTestCase {

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
        let game = Game(campaignId: "regression_test")
        context.insert(game)
        return game
    }

    /// Regression: applyStat must clamp the stability stat to 0...100 even
    /// when the resulting value would otherwise be out-of-range. Catches
    /// any future refactor that bypasses clampStat or replaces it with a
    /// non-clamping setter.
    func testApplyStatClampsStabilityToValidRange() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeGame(in: context)

        // Fresh Game starts with stability == 50.
        XCTAssertEqual(game.stability, 50, "Precondition: fresh game stability is 50")

        // Apply a massive positive change — must clamp at 100.
        game.applyStat("stability", change: 999_999)
        XCTAssertEqual(game.stability, 100, "Stability must clamp to 100 (was \(game.stability))")

        // Apply a massive negative change — must clamp at 0.
        game.applyStat("stability", change: -999_999)
        XCTAssertEqual(game.stability, 0, "Stability must clamp to 0 (was \(game.stability))")

        // Mid-range change still works (0 + 50 = 50).
        game.applyStat("stability", change: 50)
        XCTAssertEqual(game.stability, 50, "Mid-range change should add normally")
    }

    /// Regression: applyStat clamps every political stat, not just stability.
    /// If a future refactor introduces a switch-case that forgets clampStat
    /// for one stat (a class of bug the project has hit before per the
    /// known-issues memory), this test catches it.
    func testApplyStatClampsAllPoliticalStats() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let game = makeGame(in: context)

        let stats: [(String, () -> Int)] = [
            ("popularSupport", { game.popularSupport }),
            ("militaryLoyalty", { game.militaryLoyalty }),
            ("eliteLoyalty", { game.eliteLoyalty }),
            ("internationalStanding", { game.internationalStanding })
        ]

        for (key, getter) in stats {
            // Push way past upper bound.
            game.applyStat(key, change: 999_999)
            XCTAssertEqual(getter(), 100, "\(key) must clamp to 100 (was \(getter()))")

            // Push way past lower bound.
            game.applyStat(key, change: -999_999)
            XCTAssertEqual(getter(), 0, "\(key) must clamp to 0 (was \(getter()))")
        }
    }
}
