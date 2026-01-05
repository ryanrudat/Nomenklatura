//
//  TestScenarioLaunchView.swift
//  Nomenklatura
//
//  Handles launch argument scenario loading for automated testing.
//
//  ============================================================================
//  DEBUG/DEVELOPMENT CODE - REMOVE BEFORE APP STORE RELEASE
//  This entire file should be removed before production release.
//  All code is wrapped in #if DEBUG to prevent accidental inclusion.
//  ============================================================================
//

import SwiftUI
import SwiftData

#if DEBUG

/// View that handles loading a test scenario via launch arguments.
/// Used with -testScenario <scenario_id> launch argument in Xcode.
struct TestScenarioLaunchView: View {
    let scenarioId: String
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared

    @State private var game: Game?
    @State private var error: String?
    @State private var selectedTab: NavTab = .desk

    var body: some View {
        Group {
            if let game = game {
                GameView(
                    game: game,
                    selectedTab: $selectedTab,
                    onReturnToMenu: {
                        // In test mode, just restart with same scenario
                        loadScenario()
                    },
                    onRestartWithSameFaction: {
                        loadScenario()
                    }
                )
            } else if let error = error {
                errorView(error)
            } else {
                loadingView
            }
        }
        .environment(\.theme, themeManager.currentTheme)
        .task {
            loadScenario()
        }
    }

    private var loadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.orange)
                    .scaleEffect(1.5)
                Text("Loading test scenario...")
                    .foregroundColor(.white)
                    .font(.headline)
                Text(scenarioId)
                    .foregroundColor(.orange)
                    .font(.subheadline.monospaced())
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("Test Scenario Error")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(message)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Divider()
                    .background(Color.gray)
                    .padding(.horizontal, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Available scenarios:")
                        .font(.caption)
                        .foregroundColor(.gray)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(TestScenarios.allScenarioIds, id: \.self) { id in
                                Text("• \(id)")
                                    .font(.caption.monospaced())
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal)

                Text("Usage: -testScenario <scenario_id>")
                    .font(.caption.monospaced())
                    .foregroundColor(.gray)
            }
        }
    }

    private func loadScenario() {
        guard let scenario = TestScenarios.scenario(withId: scenarioId) else {
            error = "Scenario '\(scenarioId)' not found"
            return
        }

        // Clear existing games
        let fetchDescriptor = FetchDescriptor<Game>()
        if let existingGames = try? modelContext.fetch(fetchDescriptor) {
            for existingGame in existingGames {
                modelContext.delete(existingGame)
            }
        }

        // Apply scenario
        let newGame = TestScenarioService.shared.applyScenario(scenario, context: modelContext)
        try? modelContext.save()

        themeManager.setTheme(for: newGame.campaignId)
        game = newGame
    }
}

#endif
