//
//  SchemaLoadTests.swift
//  NomenklaturaTests
//
//  Verifies the SwiftData schema loads in-memory and that a Game instance
//  survives a save/fetch round-trip. Catches silent save-destruction class
//  of regression.
//

import XCTest
import SwiftData
@testable import Nomenklatura

@MainActor
final class SchemaLoadTests: XCTestCase {

    /// The full app schema. Mirrors NomenklaturaApp.sharedModelContainer.
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

    /// Build a fresh in-memory ModelContainer with the full app schema.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(Self.schemaTypes)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testGameSchemaLoadsInMemory() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let game = Game(campaignId: "test_campaign")
        context.insert(game)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Game>())
        XCTAssertEqual(fetched.count, 1, "Expected exactly one game after insert+save")

        let recovered = try XCTUnwrap(fetched.first, "Fetched game should not be nil")
        XCTAssertEqual(recovered.campaignId, "test_campaign")
        XCTAssertEqual(recovered.turnNumber, 1, "Fresh Game should start at turn 1")
        XCTAssertEqual(recovered.currentPositionIndex, 8, "Player starts at General Secretary (index 8)")
    }

    func testGameSurvivesContainerReinit() throws {
        // SwiftData in-memory stores are NOT shared between container instances —
        // each in-memory container has its own private store. So we test using a
        // shared on-disk URL in a temp directory: insert via container 1, release
        // it, reopen with a fresh container at the same URL, and verify the row.
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("NomenklaturaTests-\(UUID().uuidString).store")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            // Also try to remove WAL/SHM sidecars
            let shm = tempURL.deletingPathExtension().appendingPathExtension("store-shm")
            let wal = tempURL.deletingPathExtension().appendingPathExtension("store-wal")
            try? FileManager.default.removeItem(at: shm)
            try? FileManager.default.removeItem(at: wal)
        }

        let schema = Schema(Self.schemaTypes)

        // Container 1: insert and save
        let gameID: UUID = try {
            let config = ModelConfiguration(schema: schema, url: tempURL)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let game = Game(campaignId: "persisted_campaign")
            context.insert(game)
            try context.save()
            return game.id
        }()

        // Container 2: reopen and fetch — Game should still be there
        let config2 = ModelConfiguration(schema: schema, url: tempURL)
        let container2 = try ModelContainer(for: schema, configurations: [config2])
        let context2 = ModelContext(container2)

        let fetched = try context2.fetch(FetchDescriptor<Game>())
        XCTAssertEqual(fetched.count, 1, "Game should survive container reinit")
        let recovered = try XCTUnwrap(fetched.first)
        XCTAssertEqual(recovered.id, gameID, "ID should round-trip")
        XCTAssertEqual(recovered.campaignId, "persisted_campaign")
        XCTAssertEqual(recovered.turnNumber, 1)
    }
}
