//
//  TestScenarioPickerView.swift
//  Nomenklatura
//
//  DEBUG-only UI for selecting test scenarios.
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

/// UI for selecting and applying test scenarios during development.
/// Allows jumping to specific game states without playing through from the start.
struct TestScenarioPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme

    let onScenarioSelected: (Game) -> Void

    @State private var selectedCategory: TestScenarioCategory = .bureauPositions
    @State private var searchText = ""
    @State private var isApplying = false

    private var filteredScenarios: [TestScenario] {
        let categoryScenarios = TestScenarios.scenarios(inCategory: selectedCategory)
        if searchText.isEmpty {
            return categoryScenarios
        }
        return categoryScenarios.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Warning banner
                HStack {
                    Image(systemName: "hammer.fill")
                    Text("DEBUG MODE - Remove before release")
                    Image(systemName: "hammer.fill")
                }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.orange)

                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TestScenarioCategory.allCases, id: \.self) { category in
                            categoryButton(category)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color.black.opacity(0.3))

                Divider()

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search scenarios...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.black.opacity(0.2))

                // Scenario list
                List {
                    ForEach(filteredScenarios) { scenario in
                        ScenarioRow(scenario: scenario) {
                            applyScenario(scenario)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.15), Color(red: 0.05, green: 0.05, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Test Scenarios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .overlay {
                if isApplying {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Applying scenario...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func categoryButton(_ category: TestScenarioCategory) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(selectedCategory == category ? .bold : .regular)
            }
            .foregroundColor(selectedCategory == category ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedCategory == category ? theme.accentGold : Color.white.opacity(0.15))
            .cornerRadius(20)
        }
    }

    private func applyScenario(_ scenario: TestScenario) {
        isApplying = true

        // Delete existing games first
        let fetchDescriptor = FetchDescriptor<Game>()
        if let existingGames = try? modelContext.fetch(fetchDescriptor) {
            for game in existingGames {
                modelContext.delete(game)
            }
        }

        // Small delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let game = TestScenarioService.shared.applyScenario(scenario, context: modelContext)
            try? modelContext.save()

            isApplying = false
            onScenarioSelected(game)
            dismiss()
        }
    }
}

// MARK: - Scenario Row

private struct ScenarioRow: View {
    let scenario: TestScenario
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(scenario.name)
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    positionBadge
                }

                Text(scenario.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)

                // Quick stats preview
                HStack(spacing: 16) {
                    if let standing = scenario.statsConfig.standing {
                        statPreview("STD", value: standing)
                    }
                    if let patronFavor = scenario.statsConfig.patronFavor {
                        statPreview("PAT", value: patronFavor)
                    }
                    if let rivalThreat = scenario.statsConfig.rivalThreat {
                        statPreview("RIV", value: rivalThreat, isNegative: true)
                    }
                    if let stability = scenario.statsConfig.stability {
                        statPreview("STB", value: stability)
                    }

                    Spacer()

                    Text("Turn \(scenario.turnNumber)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var positionBadge: some View {
        let track = ExpandedCareerTrack(rawValue: scenario.positionConfig.expandedTrack) ?? .shared
        HStack(spacing: 4) {
            Image(systemName: track.iconName)
            Text("L\(scenario.positionConfig.positionIndex)")
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trackColor(track))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func statPreview(_ label: String, value: Int, isNegative: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(statColor(value, isNegative: isNegative))
        }
    }

    private func statColor(_ value: Int, isNegative: Bool) -> Color {
        if isNegative {
            return value > 60 ? .red : (value > 40 ? .orange : .green)
        }
        return value >= 60 ? .green : (value >= 40 ? .orange : .red)
    }

    private func trackColor(_ track: ExpandedCareerTrack) -> Color {
        switch track {
        case .partyApparatus: return Color.red.opacity(0.8)
        case .stateMinistry: return Color.blue.opacity(0.8)
        case .securityServices: return Color.purple.opacity(0.8)
        case .foreignAffairs: return Color.green.opacity(0.8)
        case .economicPlanning: return Color.orange.opacity(0.8)
        case .militaryPolitical: return Color.brown.opacity(0.8)
        case .shared: return Color.gray.opacity(0.8)
        case .regional: return Color.teal.opacity(0.8)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)

    return TestScenarioPickerView { game in
        print("Selected scenario, game at position \(game.currentPositionIndex)")
    }
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}

#endif
