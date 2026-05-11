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
    // ============================================================================
    // DEBUG/DEVELOPMENT CODE - REMOVE BEFORE APP STORE RELEASE
    // ============================================================================
    #if DEBUG
    /// Check for test scenario launch argument (-testScenario <scenario_id>)
    private var testScenarioId: String? {
        if let index = CommandLine.arguments.firstIndex(of: "-testScenario"),
           index + 1 < CommandLine.arguments.count {
            return CommandLine.arguments[index + 1]
        }
        return nil
    }
    #endif

    var sharedModelContainer: ModelContainer = {
        // V1 versioned schema (see Models/Schema/NomenklaturaSchemaV1.swift)
        // + explicit SchemaMigrationPlan so future @Model changes can
        // migrate user saves rather than wiping them on schema mismatch.
        let schema = Schema(versionedSchema: NomenklaturaSchemaV1.self)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: NomenklaturaMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            // IMPORTANT: do NOT delete the on-disk store here. Earlier
            // revisions of this code silently destroyed players' saves on
            // any schema mismatch — losing dozens of hours of run state.
            //
            // If the container fails to open (e.g. the migration plan
            // is incomplete for some V_N → V_M transition), we instead:
            //   1) log the error verbosely, and
            //   2) fall back to an in-memory ModelContainer so the app
            //      still launches.
            //
            // The on-disk save file remains untouched so a future build
            // — with a fixed migration plan — can still recover it.
            print("[NomenklaturaApp] CRITICAL: persistent ModelContainer failed to open.")
            print("[NomenklaturaApp] Error: \(error)")
            print("[NomenklaturaApp] Falling back to in-memory store. The on-disk save has NOT been modified.")

            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: NomenklaturaMigrationPlan.self,
                    configurations: [inMemoryConfig]
                )
            } catch {
                // If even the in-memory container fails, something is
                // fundamentally broken about the schema declarations
                // (e.g. a malformed @Model class). At this point a
                // fatalError is acceptable because there is nothing to
                // lose — no on-disk data is being destroyed.
                fatalError("Could not create even an in-memory ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            // ============================================================================
            // DEBUG/DEVELOPMENT CODE - REMOVE BEFORE APP STORE RELEASE
            // ============================================================================
            #if DEBUG
            if let scenarioId = testScenarioId {
                TestScenarioLaunchView(scenarioId: scenarioId)
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
        .modelContainer(sharedModelContainer)
    }
}
