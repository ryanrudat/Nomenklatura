//
//  DirectivePhaseView.swift
//  Nomenklatura
//
//  The Directive Phase - where the General Secretary issues orders to bureau heads.
//  Replaces passive desk-reading with active governance through bureau commands.
//

import SwiftUI
import SwiftData

// MARK: - Directive Phase View

struct DirectivePhaseView: View {
    @Bindable var game: Game
    let onComplete: () -> Void

    @Environment(\.theme) var theme
    @Environment(\.modelContext) var modelContext

    @State private var expandedBureau: ExpandedCareerTrack?
    @State private var selectedTask: BureauTask?
    @State private var showTaskConfirmation = false
    @State private var lastResult: BureauOperationsService.TaskExecutionResult?
    @State private var showResult = false

    // The 6 bureaus available for directives
    private let bureaus: [ExpandedCareerTrack] = [
        .securityServices,
        .partyApparatus,
        .economicPlanning,
        .militaryPolitical,
        .foreignAffairs,
        .stateMinistry
    ]

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(hex: "1A1A1A"),
                    Color(hex: "2D2420"),
                    Color(hex: "1A1A1A")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle texture overlay
            FiftiesColors.agedPaper.opacity(0.03)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                directiveHeader

                // Scrollable bureau grid
                ScrollView {
                    VStack(spacing: 12) {
                        // Directive points indicator
                        directivePointsBar

                        // Bureau cards grid
                        ForEach(bureaus, id: \.rawValue) { bureau in
                            let headInfo = bureauHead(for: bureau)
                            let summary = BureauOperationsService.shared.getOperationsSummary(for: bureau, game: game)
                            let availableTasks = availableTasksForBureau(bureau)

                            VStack(spacing: 0) {
                                BureauCommandCard(
                                    bureau: bureau,
                                    head: headInfo,
                                    activeOpsCount: summary.activeOperations,
                                    availableTaskCount: availableTasks.count,
                                    isExpanded: expandedBureau == bureau,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            expandedBureau = expandedBureau == bureau ? nil : bureau
                                        }
                                    }
                                )

                                // Expanded task list
                                if expandedBureau == bureau {
                                    expandedTaskList(tasks: availableTasks, bureau: bureau)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }

                        // Skip / Complete button
                        completeButton
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }

            // Task confirmation overlay
            if showTaskConfirmation, let task = selectedTask {
                taskConfirmationOverlay(task: task)
            }

            // Result overlay
            if showResult, let result = lastResult {
                resultOverlay(result: result)
            }
        }
    }

    // MARK: - Header

    private var directiveHeader: some View {
        VStack(spacing: 0) {
            // Top gold bar
            Rectangle()
                .fill(theme.accentGold)
                .frame(height: 3)

            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("BUREAU DIRECTIVES")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(theme.accentGold)

                    Text("ISSUE ORDERS TO YOUR GOVERNMENT APPARATUS")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(FiftiesColors.carbonCopy)
                }

                Spacer()

                // Turn indicator
                VStack(alignment: .trailing, spacing: 1) {
                    Text("TURN \(game.turnNumber)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(FiftiesColors.carbonCopy)

                    Text(RevolutionaryCalendar.formatTurnWithMonth(game.turnNumber))
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundColor(FiftiesColors.carbonCopy.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "1C1C1C"))

            // Bottom gold bar
            Rectangle()
                .fill(theme.accentGold.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Directive Points Bar

    private var directivePointsBar: some View {
        HStack(spacing: 12) {
            // Directive points display
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { index in
                    Image(systemName: index < game.directivePoints ? "seal.fill" : "seal")
                        .font(.system(size: 16))
                        .foregroundColor(index < game.directivePoints ? theme.accentGold : FiftiesColors.carbonCopy.opacity(0.3))
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("DIRECTIVE AUTHORITY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(theme.accentGold)

                Text("\(game.directivePoints) ORDER\(game.directivePoints == 1 ? "" : "S") REMAINING")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(FiftiesColors.carbonCopy)
            }

            Spacer()

            // Status
            if game.directivePoints == 0 {
                Text("ALL ORDERS ISSUED")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(FiftiesColors.approvedGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FiftiesColors.approvedGreen.opacity(0.15))
                    .cornerRadius(3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "2A2520"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.accentGold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Expanded Task List

    private func expandedTaskList(tasks: [BureauTask], bureau: ExpandedCareerTrack) -> some View {
        let bureauColor = BureauColors.primary(for: bureau)

        return VStack(spacing: 0) {
            // Section header
            HStack {
                Rectangle()
                    .fill(bureauColor.opacity(0.3))
                    .frame(height: 1)

                Text("AVAILABLE DIRECTIVES")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(bureauColor)
                    .fixedSize()

                Rectangle()
                    .fill(bureauColor.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)

            if tasks.isEmpty {
                Text("No directives available at this time")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(FiftiesColors.carbonCopy)
                    .padding(.vertical, 12)
            } else {
                ForEach(tasks, id: \.id) { task in
                    taskRow(task: task, bureauColor: bureauColor)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(FiftiesColors.cardstock)
        .cornerRadius(0)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(bureauColor.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Task Row

    private func taskRow(task: BureauTask, bureauColor: Color) -> some View {
        Button {
            if task.canInitiate && game.directivePoints > 0 {
                selectedTask = task
                showTaskConfirmation = true
            }
        } label: {
            HStack(spacing: 10) {
                // Task icon
                Image(systemName: task.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(task.canInitiate ? bureauColor : FiftiesColors.carbonCopy.opacity(0.4))
                    .frame(width: 24)

                // Task info
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(task.canInitiate ? FiftiesColors.typewriterInk : FiftiesColors.carbonCopy)

                    Text(task.briefDescription)
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundColor(FiftiesColors.carbonCopy)
                        .lineLimit(2)
                }

                Spacer()

                // Risk level indicator
                riskBadge(task.riskLevel)

                // Availability
                if !task.canInitiate {
                    if let reason = task.unavailableReason {
                        Text(reason)
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(FiftiesColors.stampRed)
                            .lineLimit(1)
                    }
                } else if game.directivePoints <= 0 {
                    Text("NO POINTS")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(FiftiesColors.stampRed)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(bureauColor)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                task.canInitiate && game.directivePoints > 0
                    ? bureauColor.opacity(0.04)
                    : Color.clear
            )
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(!task.canInitiate || game.directivePoints <= 0)
    }

    // MARK: - Risk Badge

    private func riskBadge(_ level: BureauRiskLevel) -> some View {
        Text(level.displayName.uppercased())
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(Color(hex: level.colorHex))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(hex: level.colorHex).opacity(0.12))
            .cornerRadius(2)
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button {
            onComplete()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: game.directivePoints < 2 ? "checkmark.seal.fill" : "arrow.right")
                    .font(.system(size: 12))

                Text(game.directivePoints < 2 ? "PROCEED TO PERSONAL ACTIONS" : "SKIP DIRECTIVES")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .foregroundColor(game.directivePoints < 2 ? FiftiesColors.agedPaper : FiftiesColors.carbonCopy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(game.directivePoints < 2 ? theme.sovietRed : Color(hex: "2A2520"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        game.directivePoints < 2 ? theme.sovietRed : FiftiesColors.carbonCopy.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Task Confirmation Overlay

    private func taskConfirmationOverlay(task: BureauTask) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showTaskConfirmation = false
                        selectedTask = nil
                    }
                }

            VStack(spacing: 0) {
                // Gold header
                Rectangle()
                    .fill(theme.accentGold)
                    .frame(height: 3)

                VStack(spacing: 16) {
                    // Icon and title
                    VStack(spacing: 8) {
                        Image(systemName: task.iconName)
                            .font(.system(size: 30))
                            .foregroundColor(theme.accentGold)

                        Text("ISSUE DIRECTIVE")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(theme.accentGold)

                        Text(task.name.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(FiftiesColors.typewriterInk)
                    }

                    // Divider
                    Rectangle()
                        .fill(FiftiesColors.carbonCopy.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 20)

                    // Description
                    Text(task.fullDescription)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Details grid
                    VStack(spacing: 6) {
                        if task.networkCost > 0 {
                            detailRow(label: "NETWORK COST", value: "-\(task.networkCost)", color: FiftiesColors.stampRed)
                        }
                        if let duration = task.estimatedDuration {
                            detailRow(label: "DURATION", value: "\(duration) TURNS", color: FiftiesColors.brassGold)
                        }
                        detailRow(label: "RISK", value: task.riskLevel.displayName.uppercased(), color: Color(hex: task.riskLevel.colorHex))
                    }
                    .padding(.horizontal, 20)

                    // Effects preview
                    if !task.potentialEffects.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(task.potentialEffects, id: \.self) { effect in
                                Text(effect)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(FiftiesColors.carbonCopy)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(FiftiesColors.cardstock)
                                    .cornerRadius(2)
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showTaskConfirmation = false
                                selectedTask = nil
                            }
                        } label: {
                            Text("CANCEL")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(FiftiesColors.carbonCopy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(FiftiesColors.cardstock)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        Button {
                            executeDirective(task)
                        } label: {
                            Text("AUTHORIZE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(theme.sovietRed)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(theme.parchment)

                // Gold footer
                Rectangle()
                    .fill(theme.accentGold)
                    .frame(height: 3)
            }
            .frame(maxWidth: 320)
            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
        }
    }

    // MARK: - Result Overlay

    private func resultOverlay(result: BureauOperationsService.TaskExecutionResult) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showResult = false
                        lastResult = nil
                    }
                }

            VStack(spacing: 16) {
                // Result icon
                Image(systemName: result.succeeded ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(result.succeeded ? FiftiesColors.approvedGreen : FiftiesColors.stampRed)

                Text(result.succeeded ? "DIRECTIVE ISSUED" : "DIRECTIVE FAILED")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(result.succeeded ? FiftiesColors.approvedGreen : FiftiesColors.stampRed)

                Text(result.description)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(FiftiesColors.fadedInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                if result.networkCostApplied > 0 {
                    Text("NETWORK: -\(result.networkCostApplied)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(FiftiesColors.stampRed)
                }

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showResult = false
                        lastResult = nil
                    }
                } label: {
                    Text("ACKNOWLEDGED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(theme.sovietRed)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(theme.parchment)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        result.succeeded ? FiftiesColors.approvedGreen.opacity(0.5) : FiftiesColors.stampRed.opacity(0.5),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
            .frame(maxWidth: 300)
        }
    }

    // MARK: - Detail Row Helper

    private func detailRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(FiftiesColors.carbonCopy)
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    // MARK: - Data Helpers

    /// Get the bureau head character info for a given bureau
    private func bureauHead(for bureau: ExpandedCareerTrack) -> BureauHeadInfo {
        // Find the highest-ranking character assigned to this bureau's track
        let candidates = game.characters.filter { character in
            guard character.isAlive,
                  character.status == "active",
                  let track = character.positionTrack else {
                return false
            }
            return track == bureau.rawValue
        }

        // Pick the highest-positioned character as the bureau head
        if let head = candidates.max(by: { ($0.positionIndex ?? 0) < ($1.positionIndex ?? 0) }) {
            return BureauHeadInfo(
                name: head.name,
                title: head.title ?? bureau.displayName,
                loyalty: head.disposition,
                characterId: head.id
            )
        }

        // Fallback placeholder
        return BureauHeadInfo.placeholder(for: bureau)
    }

    /// Get available tasks for a bureau, augmented with all 6 bureau types
    private func availableTasksForBureau(_ bureau: ExpandedCareerTrack) -> [BureauTask] {
        // The existing BureauOperationsService supports 3 core bureaus
        // For the other 3 bureaus, generate tasks from their action lists
        switch bureau {
        case .securityServices, .economicPlanning, .partyApparatus:
            return BureauOperationsService.shared.getAvailableTasks(for: bureau, game: game)

        case .militaryPolitical:
            return generateMilitaryTasks(bureau: bureau)

        case .foreignAffairs:
            return generateDiplomaticTasks(bureau: bureau)

        case .stateMinistry:
            return generateStateMinistryTasks(bureau: bureau)

        default:
            return []
        }
    }

    /// Generate BureauTask items from any action array using closures to extract fields
    private func generateDirectiveTasks<T: Identifiable>(
        from actions: [T],
        bureau: ExpandedCareerTrack,
        category: String,
        minPosition: (T) -> Int,
        id: (T) -> String,
        name: (T) -> String,
        description: (T) -> String,
        iconName: (T) -> String,
        cooldown: (T) -> Int,
        executionTurns: (T) -> Int,
        riskLevel: (T) -> BureauRiskLevel
    ) -> [BureauTask] {
        let positionIndex = game.currentPositionIndex
        return actions
            .filter { minPosition($0) <= positionIndex }
            .prefix(4)
            .map { action in
                let execTurns = executionTurns(action)
                return BureauTask(
                    id: "dir_\(id(action))",
                    bureauTrack: bureau.rawValue,
                    name: name(action),
                    briefDescription: description(action),
                    iconName: iconName(action),
                    actionId: id(action),
                    actionCategory: category,
                    minimumPosition: minPosition(action),
                    cooldownTurns: cooldown(action),
                    estimatedDuration: execTurns > 1 ? execTurns : nil,
                    riskLevel: riskLevel(action),
                    potentialEffects: []
                )
            }
    }

    private func generateMilitaryTasks(bureau: ExpandedCareerTrack) -> [BureauTask] {
        generateDirectiveTasks(
            from: MilitaryAction.allActions, bureau: bureau, category: "military",
            minPosition: { $0.minimumPositionIndex }, id: { $0.id },
            name: { $0.name }, description: { $0.description }, iconName: { $0.iconName },
            cooldown: { $0.cooldownTurns }, executionTurns: { $0.executionTurns },
            riskLevel: { mapRisk($0.riskLevel) }
        )
    }

    private func generateDiplomaticTasks(bureau: ExpandedCareerTrack) -> [BureauTask] {
        generateDirectiveTasks(
            from: DiplomaticAction.allActions, bureau: bureau, category: "diplomatic",
            minPosition: { $0.category.minimumPositionIndex }, id: { $0.id },
            name: { $0.name }, description: { $0.description }, iconName: { $0.iconName },
            cooldown: { $0.cooldownTurns }, executionTurns: { $0.executionTurns },
            riskLevel: { mapRisk($0.riskLevel) }
        )
    }

    private func generateStateMinistryTasks(bureau: ExpandedCareerTrack) -> [BureauTask] {
        generateDirectiveTasks(
            from: StateMinistryAction.allActions, bureau: bureau, category: "stateMinistry",
            minPosition: { $0.category.minimumPositionIndex }, id: { $0.id },
            name: { $0.name }, description: { $0.description }, iconName: { $0.iconName },
            cooldown: { $0.cooldownTurns }, executionTurns: { $0.executionTurns },
            riskLevel: { mapRisk($0.riskLevel) }
        )
    }

    // MARK: - Risk Level Mapping

    /// Overloaded risk mapping for the three non-core bureau risk types
    private func mapRisk(_ risk: MilitaryRiskLevel) -> BureauRiskLevel {
        switch risk {
        case .routine: return .minimal
        case .moderate: return .moderate
        case .significant, .major: return .high
        case .extreme: return .critical
        }
    }

    private func mapRisk(_ risk: DiplomaticRiskLevel) -> BureauRiskLevel {
        switch risk {
        case .minimal: return .minimal
        case .low: return .low
        case .moderate: return .moderate
        case .high: return .high
        case .extreme: return .critical
        }
    }

    private func mapRisk(_ risk: MinistryRiskLevel) -> BureauRiskLevel {
        switch risk {
        case .routine: return .minimal
        case .moderate: return .moderate
        case .significant, .major: return .high
        case .extreme: return .critical
        }
    }

    // MARK: - Directive Execution

    private func executeDirective(_ task: BureauTask) {
        guard game.directivePoints > 0 else { return }

        // Close confirmation
        withAnimation(.easeOut(duration: 0.2)) {
            showTaskConfirmation = false
        }

        // Route to the appropriate service
        let result: BureauOperationsService.TaskExecutionResult

        switch task.actionCategory {
        case "security", "economic", "party":
            // Core bureaus - use BureauOperationsService
            result = BureauOperationsService.shared.executeTask(task, for: game, modelContext: modelContext)

        case "military":
            // Execute via MilitaryActionService
            result = executeMilitaryDirective(task)

        case "diplomatic":
            // Execute via DiplomaticActionService
            result = executeDiplomaticDirective(task)

        case "stateMinistry":
            // Execute via StateMinistryActionService
            result = executeStateMinistryDirective(task)

        default:
            result = .failure("Unknown bureau category")
        }

        // Spend directive point if operation was initiated
        if result.operationInitiated {
            game.directivePoints -= 1
        }

        // Show result
        lastResult = result
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showResult = true
            selectedTask = nil
        }
    }

    private func executeMilitaryDirective(_ task: BureauTask) -> BureauOperationsService.TaskExecutionResult {
        guard let action = MilitaryAction.allActions.first(where: { $0.id == task.actionId }) else {
            return .failure("Military action not found: \(task.actionId)")
        }

        let result = MilitaryActionService.shared.executeAction(
            action,
            targetOfficer: nil,
            targetUnit: nil,
            targetTheater: nil,
            for: game,
            modelContext: modelContext
        )

        return BureauOperationsService.TaskExecutionResult(
            succeeded: result.succeeded,
            roll: result.roll,
            successChance: result.successChance,
            description: result.description,
            networkCostApplied: 0,
            operationInitiated: result.succeeded || result.roll > 0,
            errorMessage: result.succeeded ? nil : result.description
        )
    }

    private func executeDiplomaticDirective(_ task: BureauTask) -> BureauOperationsService.TaskExecutionResult {
        guard let action = DiplomaticAction.allActions.first(where: { $0.id == task.actionId }) else {
            return .failure("Diplomatic action not found: \(task.actionId)")
        }

        let result = DiplomaticActionService.shared.executeAction(
            action,
            targetCountry: nil,
            for: game,
            modelContext: modelContext
        )

        return BureauOperationsService.TaskExecutionResult(
            succeeded: result.succeeded,
            roll: 0,
            successChance: action.baseSuccessChance,
            description: result.description,
            networkCostApplied: 0,
            operationInitiated: result.succeeded || result.pendingRecord != nil,
            errorMessage: result.succeeded ? nil : result.description
        )
    }

    private func executeStateMinistryDirective(_ task: BureauTask) -> BureauOperationsService.TaskExecutionResult {
        guard let action = StateMinistryAction.allActions.first(where: { $0.id == task.actionId }) else {
            return .failure("State ministry action not found: \(task.actionId)")
        }

        let result = StateMinistryActionService.shared.executeAction(
            action,
            targetMinistry: nil,
            targetOfficial: nil,
            for: game,
            modelContext: modelContext
        )

        return BureauOperationsService.TaskExecutionResult(
            succeeded: result.succeeded,
            roll: result.roll,
            successChance: result.successChance,
            description: result.description,
            networkCostApplied: 0,
            operationInitiated: result.succeeded || result.roll > 0,
            errorMessage: result.succeeded ? nil : result.description
        )
    }
}
