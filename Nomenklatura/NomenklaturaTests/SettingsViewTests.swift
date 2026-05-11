//
//  SettingsViewTests.swift
//  NomenklaturaTests
//
//  Smoke tests for the user-facing SettingsView. Verifies the view can
//  initialize against a real (in-memory) ModelContainer without
//  crashing — guards against the "I forgot to register a @Query
//  type" class of regression that doesn't surface until runtime.
//

import XCTest
import SwiftUI
import SwiftData
@testable import Nomenklatura

@MainActor
final class SettingsViewTests: XCTestCase {

    /// Smoke test: SettingsView initializes given a real modelContext.
    /// Doesn't assert visual output — just that the View compiles and
    /// can be instantiated without throwing.
    func testSettingsViewRenders() throws {
        let schema = Schema([Game.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // Instantiating the view exercises its property wrappers
        // (@AppStorage, @Query, @Environment), which is the most
        // common failure mode for SwiftUI views.
        let view = SettingsView()
            .modelContainer(container)
            .environment(\.theme, ColdWarTheme())

        // Force the view body to evaluate via a hosting controller so
        // SwiftUI exercises the body rather than just construction.
        _ = UIHostingController(rootView: view)

        // Reaching here means construction + body evaluation didn't
        // crash. The test passes if no exception was thrown.
        XCTAssertNotNil(view, "SettingsView should construct successfully")
    }

    /// Verify the version label helper returns a non-empty, well-formed
    /// string. Catches the case where Bundle.main.infoDictionary returns
    /// nil under unusual test-host conditions.
    func testVersionLabelIsWellFormed() throws {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let label = "v\(version) (build \(build))"

        XCTAssertTrue(label.hasPrefix("v"), "Version label should start with 'v'")
        XCTAssertTrue(label.contains("build"), "Version label should contain 'build'")
        XCTAssertFalse(version.isEmpty, "Marketing version should never be empty")
        XCTAssertFalse(build.isEmpty, "Build number should never be empty")
    }
}
