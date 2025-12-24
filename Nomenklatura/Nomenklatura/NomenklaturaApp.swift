//
//  NomenklaturaApp.swift
//  Nomenklatura
//
//  A political simulation game
//

import SwiftUI
import SwiftData

@main
struct NomenklaturaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Game.self,
            GameCharacter.self,
            GameFaction.self,
            GameEvent.self,
            Policy.self,
            PositionHolder.self,
            SuccessionRelationship.self,
            PurgeCampaign.self,
            UnlockedAchievement.self,
            // Models added for World/Diplomacy features
            Region.self,
            ForeignCountry.self,
            Law.self,
            PositionOffer.self,
            TradeAgreement.self,
            // NPC autonomy and Congress models
            NPCRelationship.self,
            CongressSession.self,
            WorldEventRecord.self,
            // Historical records
            HistoricalSession.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema changed - try to delete existing data and recreate
            #if DEBUG
            print("SwiftData migration error: \(error)")
            print("Attempting to delete existing store and recreate...")
            #endif

            // Get the default store URL and delete it
            let url = URL.applicationSupportDirectory
                .appending(path: "default.store")

            try? FileManager.default.removeItem(at: url)
            // Also remove the -shm and -wal files
            let shmUrl = url.deletingPathExtension().appendingPathExtension("store-shm")
            let walUrl = url.deletingPathExtension().appendingPathExtension("store-wal")
            try? FileManager.default.removeItem(at: shmUrl)
            try? FileManager.default.removeItem(at: walUrl)

            // Try again with fresh store
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
