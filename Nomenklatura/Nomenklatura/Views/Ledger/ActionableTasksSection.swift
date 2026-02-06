//
//  ActionableTasksSection.swift
//  Nomenklatura
//
//  Displays available tasks that players can initiate from the Ledger.
//  Part of the Bureau Operations Center in the Ledger view.
//

import SwiftUI
import SwiftData

// MARK: - Actionable Tasks Section

/// Section showing available tasks for the player's bureau
struct ActionableTasksSection: View {
    let game: Game
    let bureau: ExpandedCareerTrack
    @Environment(\.modelContext) private var modelContext

    @State private var tasks: [BureauTask] = []
    @State private var selectedTask: BureauTask?
    @State private var showingConfirmation = false

    private var bureauColor: Color {
        BureauColors.primary(for: bureau)
    }

    private var availableTasks: [BureauTask] {
        tasks.filter { $0.canInitiate }
    }

    private var unavailableTasks: [BureauTask] {
        tasks.filter { !$0.canInitiate }
    }

    private var refreshToken: String {
        let cooldownKey: String
        switch bureau {
        case .securityServices:
            cooldownKey = "security_cooldowns"
        case .economicPlanning:
            cooldownKey = "economic_cooldowns"
        case .partyApparatus:
            cooldownKey = "party_cooldowns"
        default:
            cooldownKey = ""
        }

        return [
            "\(game.turnNumber)",
            "\(game.currentPositionIndex)",
            "\(game.network)",
            "\(game.variables[cooldownKey] ?? "")"
        ].joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            sectionHeader

            if tasks.isEmpty {
                emptyState
            } else {
                tasksList
            }
        }
        .onAppear {
            loadTasks()
        }
        .onChange(of: refreshToken) { _ in
            loadTasks()
        }
        .sheet(isPresented: $showingConfirmation, onDismiss: {
            loadTasks()
        }) {
            if let task = selectedTask {
                TaskConfirmationSheet(task: task, game: game, bureauColor: bureauColor)
            }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 10))
                .foregroundColor(bureauColor)

            Text("AVAILABLE ACTIONS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(FiftiesColors.typewriterInk)

            Spacer()

            Text("\(availableTasks.count) available")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(FiftiesColors.carbonCopy)
        }
    }

    // MARK: - Tasks List

    private var tasksList: some View {
        VStack(spacing: 8) {
            // Available tasks
            ForEach(availableTasks, id: \.id) { task in
                TaskCard(
                    task: task,
                    bureauColor: bureauColor,
                    onTap: {
                        selectedTask = task
                        showingConfirmation = true
                    }
                )
            }

            // Unavailable tasks (collapsed)
            if !unavailableTasks.isEmpty {
                DisclosureGroup {
                    ForEach(unavailableTasks, id: \.id) { task in
                        TaskCard(task: task, bureauColor: bureauColor, onTap: nil)
                    }
                } label: {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(FiftiesColors.carbonCopy)

                        Text("\(unavailableTasks.count) Locked Actions")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)
                    }
                }
                .tint(FiftiesColors.carbonCopy)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 20))
                    .foregroundColor(FiftiesColors.carbonCopy)

                Text("No Actions Available")
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(FiftiesColors.fadedInk)
            }
            .padding(.vertical, 16)
            Spacer()
        }
        .background(FiftiesColors.agedPaper.opacity(0.5))
        .cornerRadius(4)
    }

    // MARK: - Data Loading

    private func loadTasks() {
        tasks = BureauOperationsService.shared.getAvailableTasks(for: bureau, game: game)
    }
}

// MARK: - Task Card

/// Individual task card
struct TaskCard: View {
    let task: BureauTask
    let bureauColor: Color
    let onTap: (() -> Void)?

    private var isAvailable: Bool {
        task.canInitiate
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: task.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isAvailable ? bureauColor : FiftiesColors.carbonCopy)
                    .frame(width: 24)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isAvailable ? FiftiesColors.typewriterInk : FiftiesColors.carbonCopy)

                    Text(task.briefDescription)
                        .font(.system(size: 9, design: .serif))
                        .foregroundColor(FiftiesColors.fadedInk)
                        .lineLimit(1)

                    // Unavailable reason
                    if !isAvailable, let reason = task.unavailableReason {
                        Text(reason)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(Color(hex: "CD853F"))
                    }
                }

                Spacer()

                // Right side info
                VStack(alignment: .trailing, spacing: 4) {
                    // Risk level
                    riskBadge

                    // Initiate button (if available)
                    if isAvailable {
                        Text("INITIATE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(bureauColor)
                            .cornerRadius(2)
                    }
                }
            }
            .padding(10)
            .background(isAvailable ? FiftiesColors.manillaFolder : FiftiesColors.agedPaper.opacity(0.5))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isAvailable ? bureauColor.opacity(0.3) : FiftiesColors.carbonCopy.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(!isAvailable)
        .buttonStyle(.plain)
    }

    private var riskBadge: some View {
        let riskColor: Color
        switch task.riskLevel {
        case .minimal, .low:
            riskColor = FiftiesColors.approvedGreen
        case .moderate:
            riskColor = FiftiesColors.brassGold
        case .high:
            riskColor = Color(hex: "CD853F")
        case .critical:
            riskColor = Color(hex: "8B0000")
        }

        return Text(task.riskLevel.displayName.uppercased())
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(riskColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(riskColor.opacity(0.1))
            .cornerRadius(2)
    }
}

// MARK: - Task Confirmation Sheet

/// Confirmation sheet when initiating a task
struct TaskConfirmationSheet: View {
    let task: BureauTask
    let game: Game
    let bureauColor: Color
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isExecuting = false
    @State private var executionResult: BureauOperationsService.TaskExecutionResult?
    @State private var showingResult = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Task header
                HStack(spacing: 12) {
                    Image(systemName: task.iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(bureauColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FiftiesColors.typewriterInk)

                        Text(task.briefDescription)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(FiftiesColors.fadedInk)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FiftiesColors.manillaFolder)
                .cornerRadius(6)

                // Description
                Text(task.fullDescription)
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(FiftiesColors.typewriterInk)
                    .padding()
                    .background(FiftiesColors.agedPaper)
                    .cornerRadius(4)

                // Requirements & Effects
                VStack(alignment: .leading, spacing: 12) {
                    // Requirements
                    if task.networkCost > 0 || task.cooldownTurns > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("REQUIREMENTS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(FiftiesColors.carbonCopy)

                            HStack(spacing: 16) {
                                if task.networkCost > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 10))
                                        Text("-\(task.networkCost) Network")
                                            .font(.system(size: 10, design: .monospaced))
                                    }
                                    .foregroundColor(FiftiesColors.fadedInk)
                                }

                                if task.cooldownTurns > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 10))
                                        Text("\(task.cooldownTurns) turn cooldown")
                                            .font(.system(size: 10, design: .monospaced))
                                    }
                                    .foregroundColor(FiftiesColors.fadedInk)
                                }
                            }
                        }
                    }

                    // Effects preview
                    if !task.potentialEffects.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("POTENTIAL EFFECTS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(FiftiesColors.carbonCopy)

                            FlowLayout(spacing: 8) {
                                ForEach(task.potentialEffects, id: \.self) { effect in
                                    Text(effect)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(effectColor(for: effect))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(FiftiesColors.agedPaper)
                                        .cornerRadius(3)
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isExecuting)

                    Button(isExecuting ? "Initiating..." : "Initiate Action") {
                        executeTask()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(bureauColor)
                    .disabled(isExecuting)
                }
            }
            .padding()
            .navigationTitle("Confirm Action")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .alert(
            executionResult?.succeeded == true ? "Action Initiated" : "Action Failed",
            isPresented: $showingResult
        ) {
            Button("OK") {
                if executionResult?.succeeded == true {
                    dismiss()
                }
            }
        } message: {
            if let result = executionResult {
                Text(result.description)
            }
        }
    }

    // MARK: - Task Execution

    private func executeTask() {
        isExecuting = true

        // Execute the task via BureauOperationsService
        let result = BureauOperationsService.shared.executeTask(
            task,
            for: game,
            modelContext: modelContext
        )

        executionResult = result
        isExecuting = false
        showingResult = true
    }

    private func effectColor(for effect: String) -> Color {
        if effect.hasPrefix("+") {
            return FiftiesColors.approvedGreen
        } else if effect.hasPrefix("-") {
            return Color(hex: "8B0000")
        } else {
            return FiftiesColors.fadedInk
        }
    }
}
