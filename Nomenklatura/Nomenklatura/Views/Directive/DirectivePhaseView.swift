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

    // Target selection state for directives that require targets
    @State private var pendingDirectiveTask: BureauTask?
    @State private var showCountrySelection = false
    @State private var showOfficerSelection = false
    @State private var showTheaterSelection = false
    @State private var showMinistrySelection = false
    @State private var showOfficialSelection = false
    @State private var pendingTargetType: String = ""
    @State private var showCharacterSelection = false
    @State private var pendingSecurityTask: BureauTask?

    // Chairman's Decree state — mirrors SecurityPortalView's decree flow but for the
    // directive phase. When a player taps "EXECUTE BY DECREE" on a canBeDecree security
    // directive, we go directly to character selection (bypasses normal "AUTHORIZE"
    // confirmation overlay) and then prompt the same political-cost alert before
    // routing through BureauOperationsService.executeTask(..., viaDecree: true).
    @State private var showDecreeConfirmAlert = false
    @State private var pendingDecreeTask: BureauTask?
    @State private var pendingDecreeTarget: GameCharacter?

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
            theme.agedPaper.opacity(0.03)
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
                        let crises = UrgencyAdvisor.detectCrises(game: game)

                        ForEach(bureaus, id: \.rawValue) { bureau in
                            let headInfo = bureauHead(for: bureau)
                            let summary = BureauOperationsService.shared.getOperationsSummary(for: bureau, game: game)
                            let availableTasks = availableTasksForBureau(bureau)
                            let bureauCrisis = UrgencyAdvisor.isUrgentDirective(
                                bureauTrack: bureau.rawValue, crises: crises
                            )

                            VStack(spacing: 0) {
                                BureauCommandCard(
                                    bureau: bureau,
                                    head: headInfo,
                                    activeOpsCount: summary.activeOperations,
                                    availableTaskCount: availableTasks.count,
                                    isExpanded: expandedBureau == bureau,
                                    urgentCrisis: bureauCrisis,
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

            // Target selection overlays
            if showCountrySelection, let task = pendingDirectiveTask {
                countrySelectionOverlay(task: task)
            }
            if showOfficerSelection, let task = pendingDirectiveTask {
                officerSelectionOverlay(task: task)
            }
            if showTheaterSelection, let task = pendingDirectiveTask {
                theaterSelectionOverlay(task: task)
            }
            if showMinistrySelection, let task = pendingDirectiveTask {
                ministrySelectionOverlay(task: task)
            }
            if showOfficialSelection, let task = pendingDirectiveTask {
                officialSelectionOverlay(task: task)
            }

            // Character selection overlay for security directives
            if showCharacterSelection, let task = pendingSecurityTask {
                characterSelectionOverlay(task: task)
            }
        }
        // Chairman's Decree confirmation — fired after a decree-flow target is chosen.
        // Mirrors SecurityPortalView.SecurityActionCard's "Issue Chairman's Decree?" alert.
        .alert("Issue Chairman's Decree?", isPresented: $showDecreeConfirmAlert) {
            Button("CANCEL", role: .cancel) {
                pendingDecreeTask = nil
                pendingDecreeTarget = nil
                pendingSecurityTask = nil
                selectedTask = nil
            }
            Button("ISSUE DECREE", role: .destructive) {
                if let task = pendingDecreeTask, let target = pendingDecreeTarget {
                    finalizeSecurityDirective(task: task, target: target, viaDecree: true)
                }
            }
        } message: {
            Text(decreeAlertMessage)
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
                        .foregroundColor(theme.carbonCopy)
                }

                Spacer()

                // Turn indicator
                VStack(alignment: .trailing, spacing: 1) {
                    Text("TURN \(game.turnNumber)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.carbonCopy)

                    Text(RevolutionaryCalendar.formatTurnWithMonth(game.turnNumber))
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundColor(theme.carbonCopy.opacity(0.7))
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
                        .foregroundColor(index < game.directivePoints ? theme.accentGold : theme.carbonCopy.opacity(0.3))
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("DIRECTIVE AUTHORITY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(theme.accentGold)

                Text("\(game.directivePoints) ORDER\(game.directivePoints == 1 ? "" : "S") REMAINING")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.carbonCopy)
            }

            Spacer()

            // Shared decree-charge counter — placed alongside the directive
            // points display so the player sees BOTH costs of a decree
            // (1 directive point + 1 charge) in the same row.
            DecreeChargesCounter(game: game)

            // Status
            if game.directivePoints == 0 {
                Text("ALL ORDERS ISSUED")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(theme.approvedGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.approvedGreen.opacity(0.15))
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
        let bureauColor = ColdWarTheme.shared.bureauPrimary(for: bureau)

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
                    .foregroundColor(theme.carbonCopy)
                    .padding(.vertical, 12)
            } else {
                ForEach(tasks, id: \.id) { task in
                    taskRow(task: task, bureauColor: bureauColor)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(theme.cardstock)
        .cornerRadius(0)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(bureauColor.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Task Row

    private func taskRow(task: BureauTask, bureauColor: Color) -> some View {
        VStack(spacing: 4) {
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
                        .foregroundColor(task.canInitiate ? bureauColor : theme.carbonCopy.opacity(0.4))
                        .frame(width: 24)

                    // Task info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.name.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(task.canInitiate ? theme.inkBlack : theme.carbonCopy)

                        Text(task.briefDescription)
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundColor(theme.carbonCopy)
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
                                .foregroundColor(theme.sovietRed)
                                .lineLimit(1)
                        }
                    } else if game.directivePoints <= 0 {
                        Text("NO POINTS")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.sovietRed)
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

            // Chairman's Decree affordance — parallel to the normal AUTHORIZE flow.
            // Surfaces only on security directives whose underlying action is flagged
            // canBeDecree (currently investigate_politburo_member, execute_without_trial,
            // and a few other high-position actions). Mirrors SecurityPortalView's
            // EXECUTE BY DECREE button so the player can bypass committee approval
            // from the directive phase too.
            if decreeEligibleSecurityAction(for: task) != nil {
                decreeButton(task: task)
            }
        }
    }

    // MARK: - Decree Button (Directive Phase)

    /// Returns the SecurityAction backing this task IF the action is flagged canBeDecree.
    /// Used to gate the visibility of the EXECUTE BY DECREE button.
    private func decreeEligibleSecurityAction(for task: BureauTask) -> SecurityAction? {
        guard task.actionCategory == "security" else { return nil }
        guard let action = SecurityAction.allActions.first(where: { $0.id == task.actionId }) else {
            return nil
        }
        return action.canBeDecree ? action : nil
    }

    /// Whether the player can currently issue a decree: must have at least one charge
    /// remaining and a directive point to spend, and the underlying task must be initiable.
    private func decreeAvailable(for task: BureauTask) -> Bool {
        game.decreeChargesRemaining > 0 && game.directivePoints > 0 && task.canInitiate
    }

    /// The red EXECUTE BY DECREE pill mirrors SecurityPortalView.SecurityActionCard's
    /// secondary button: same color, same n/3 charges badge, same heavy tracking.
    /// Tapping opens character selection in decree mode (maxTargetPosition bypassed),
    /// then prompts the political-cost alert before routing through
    /// BureauOperationsService.executeTask(..., viaDecree: true).
    private func decreeButton(task: BureauTask) -> some View {
        let isAvailable = decreeAvailable(for: task)
        return Button {
            guard isAvailable else { return }
            // Mark this as a decree flow BEFORE opening character selection.
            // characterSelectionOverlay will widen its eligibility filter when
            // pendingDecreeTask is set, and finalizeSecurityDirective will route
            // through BureauOperationsService with viaDecree: true.
            pendingDecreeTask = task
            pendingSecurityTask = task
            withAnimation(.easeInOut(duration: 0.2)) {
                showCharacterSelection = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("EXECUTE BY DECREE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                Spacer()
                Text("\(game.decreeChargesRemaining)/\(game.chairmanshipTier.decreeMax)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .opacity(0.85)
            }
            .foregroundColor(isAvailable ? .white : theme.carbonCopy)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(isAvailable ? theme.sovietRed : theme.cardstock.opacity(0.4))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isAvailable ? theme.inkBlack.opacity(0.6) : theme.carbonCopy.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .padding(.horizontal, 8)
        .accessibilityHint(isAvailable
            ? "Bypass Standing Committee approval at a steep political cost. \(game.decreeChargesRemaining) of \(game.chairmanshipTier.decreeMax) charges remaining."
            : (game.decreeChargesRemaining == 0
                ? "No decree charges remaining. Charges regenerate slowly."
                : "Insufficient directive points."))
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
            .foregroundColor(game.directivePoints < 2 ? theme.agedPaper : theme.carbonCopy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(game.directivePoints < 2 ? theme.sovietRed : Color(hex: "2A2520"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        game.directivePoints < 2 ? theme.sovietRed : theme.carbonCopy.opacity(0.3),
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
                            .foregroundColor(theme.inkBlack)
                    }

                    // Divider
                    Rectangle()
                        .fill(theme.carbonCopy.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 20)

                    // Description
                    Text(task.fullDescription)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(theme.inkGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Details grid
                    VStack(spacing: 6) {
                        if task.networkCost > 0 {
                            detailRow(label: "NETWORK COST", value: "-\(task.networkCost)", color: theme.sovietRed)
                        }
                        if let duration = task.estimatedDuration {
                            detailRow(label: "DURATION", value: "\(duration) TURNS", color: theme.bronzeGold)
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
                                    .foregroundColor(theme.carbonCopy)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(theme.cardstock)
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
                                .foregroundColor(theme.carbonCopy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(theme.cardstock)
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
                    .foregroundColor(result.succeeded ? theme.approvedGreen : theme.sovietRed)

                Text(result.succeeded ? "DIRECTIVE ISSUED" : "DIRECTIVE FAILED")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(result.succeeded ? theme.approvedGreen : theme.sovietRed)

                Text(result.description)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                if result.networkCostApplied > 0 {
                    Text("NETWORK: -\(result.networkCostApplied)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.sovietRed)
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
                        result.succeeded ? theme.approvedGreen.opacity(0.5) : theme.sovietRed.opacity(0.5),
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
                .foregroundColor(theme.carbonCopy)
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

        // Check if this directive needs a target selection first
        if let targetNeeded = directiveNeedsTarget(task) {
            pendingDirectiveTask = task
            pendingTargetType = targetNeeded
            withAnimation(.easeInOut(duration: 0.2)) {
                switch targetNeeded {
                case "country": showCountrySelection = true
                case "officer": showOfficerSelection = true
                case "theater": showTheaterSelection = true
                case "ministry": showMinistrySelection = true
                case "official": showOfficialSelection = true
                case "character":
                    pendingSecurityTask = task
                    showCharacterSelection = true
                default: break
                }
            }
            return
        }

        // No target needed — execute immediately
        finalizeDirective(task)
    }

    /// Check if a directive action requires the player to select a target
    private func directiveNeedsTarget(_ task: BureauTask) -> String? {
        switch task.actionCategory {
        case "diplomatic":
            if let action = DiplomaticAction.allActions.first(where: { $0.id == task.actionId }) {
                if action.targetType == .country { return "country" }
            }
        case "military":
            if let action = MilitaryAction.allActions.first(where: { $0.id == task.actionId }) {
                switch action.targetType {
                case .officer: return "officer"
                case .theater: return "theater"
                case .unit, .serviceArm, .none: return nil
                }
            }
        case "stateMinistry":
            if let action = StateMinistryAction.allActions.first(where: { $0.id == task.actionId }) {
                switch action.targetType {
                case .ministry: return "ministry"
                case .official: return "official"
                case .policy, .region, .sector, .none: return nil
                }
            }
        case "security":
            if let action = SecurityAction.allActions.first(where: { $0.id == task.actionId }) {
                if action.targetType == .character { return "character" }
            }
        default:
            return nil
        }
        return nil
    }

    /// Execute the directive after any required target has been selected
    private func finalizeDirective(
        _ task: BureauTask,
        targetCountry: ForeignCountry? = nil,
        targetOfficer: GameCharacter? = nil,
        targetTheater: TheaterCommand? = nil,
        targetMinistry: MinistryDepartment? = nil,
        targetOfficial: GameCharacter? = nil,
        targetCharacter: GameCharacter? = nil
    ) {
        let result: BureauOperationsService.TaskExecutionResult

        switch task.actionCategory {
        case "security":
            result = BureauOperationsService.shared.executeTask(task, for: game, modelContext: modelContext, targetCharacter: targetCharacter)

        case "economic", "party":
            result = BureauOperationsService.shared.executeTask(task, for: game, modelContext: modelContext)

        case "military":
            result = executeMilitaryDirective(task, targetOfficer: targetOfficer, targetTheater: targetTheater)

        case "diplomatic":
            result = executeDiplomaticDirective(task, targetCountry: targetCountry)

        case "stateMinistry":
            result = executeStateMinistryDirective(task, targetMinistry: targetMinistry, targetOfficial: targetOfficial)

        default:
            result = .failure("Unknown bureau category")
        }

        // Spend directive point if operation was initiated
        if result.operationInitiated {
            game.directivePoints -= 1

            // Apply track affinity for bureau directive
            if let directiveTrack = task.bureau {
                game.addTrackAffinity(
                    track: directiveTrack,
                    amount: 3,
                    source: .personalAction,
                    description: "Issued directive: \(task.name)"
                )
            }
        }

        // Show result
        lastResult = result
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showResult = true
            selectedTask = nil
            pendingDirectiveTask = nil
        }
    }

    // MARK: - Bureau Execution (with targets)

    private func executeMilitaryDirective(
        _ task: BureauTask,
        targetOfficer: GameCharacter? = nil,
        targetTheater: TheaterCommand? = nil
    ) -> BureauOperationsService.TaskExecutionResult {
        guard let action = MilitaryAction.allActions.first(where: { $0.id == task.actionId }) else {
            return .failure("Military action not found: \(task.actionId)")
        }

        let result = MilitaryActionService.shared.executeAction(
            action,
            targetOfficer: targetOfficer,
            targetUnit: nil,
            targetTheater: targetTheater,
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

    private func executeDiplomaticDirective(
        _ task: BureauTask,
        targetCountry: ForeignCountry? = nil
    ) -> BureauOperationsService.TaskExecutionResult {
        guard let action = DiplomaticAction.allActions.first(where: { $0.id == task.actionId }) else {
            return .failure("Diplomatic action not found: \(task.actionId)")
        }

        let result = DiplomaticActionService.shared.executeAction(
            action,
            targetCountry: targetCountry,
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

    private func executeStateMinistryDirective(
        _ task: BureauTask,
        targetMinistry: MinistryDepartment? = nil,
        targetOfficial: GameCharacter? = nil
    ) -> BureauOperationsService.TaskExecutionResult {
        guard let action = StateMinistryAction.allActions.first(where: { $0.id == task.actionId }) else {
            return .failure("State ministry action not found: \(task.actionId)")
        }

        let result = StateMinistryActionService.shared.executeAction(
            action,
            targetMinistry: targetMinistry,
            targetOfficial: targetOfficial,
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

    // MARK: - Target Selection Overlays

    /// Country selection for diplomatic directives
    private func countrySelectionOverlay(task: BureauTask) -> some View {
        let action = DiplomaticAction.allActions.first(where: { $0.id == task.actionId })

        return ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismissTargetSelection() }

            VStack(spacing: 0) {
                Rectangle().fill(theme.accentGold).frame(height: 3)

                VStack(spacing: 12) {
                    // Header
                    targetSelectionHeader(
                        icon: "globe",
                        title: "SELECT TARGET NATION",
                        subtitle: task.name
                    )

                    Rectangle()
                        .fill(theme.carbonCopy.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    // Country list
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(game.foreignCountries.sorted(by: { $0.name < $1.name }), id: \.id) { country in
                                Button {
                                    dismissTargetSelection()
                                    finalizeDirective(task, targetCountry: country)
                                } label: {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(blocColor(for: country.politicalBloc))
                                            .frame(width: 8, height: 8)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(country.name.uppercased())
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .tracking(0.5)
                                                .foregroundColor(theme.inkBlack)

                                            Text(country.relationshipCategory)
                                                .font(.system(size: 8, weight: .regular, design: .monospaced))
                                                .foregroundColor(theme.carbonCopy)
                                        }

                                        Spacer()

                                        if let action = action {
                                            let chance = DiplomaticActionService.shared.calculateSuccessChance(
                                                action, targetCountry: country, game: game
                                            )
                                            Text("\(chance)%")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(successChanceColor(chance))
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9))
                                            .foregroundColor(theme.carbonCopy.opacity(0.5))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(theme.cardstock.opacity(0.3))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: 340)

                    cancelTargetButton()
                }
                .padding(.vertical, 16)
                .background(theme.parchment)

                Rectangle().fill(theme.accentGold).frame(height: 3)
            }
            .frame(maxWidth: 320)
            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
        }
    }

    /// Officer selection for military directives
    private func officerSelectionOverlay(task: BureauTask) -> some View {
        let officers = game.characters.filter { char in
            char.isAlive && char.status == "active" &&
            char.positionTrack == ExpandedCareerTrack.militaryPolitical.rawValue
        }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }

        return ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismissTargetSelection() }

            VStack(spacing: 0) {
                Rectangle().fill(theme.accentGold).frame(height: 3)

                VStack(spacing: 12) {
                    targetSelectionHeader(
                        icon: "person.military.fill",
                        title: "SELECT TARGET OFFICER",
                        subtitle: task.name
                    )

                    Rectangle()
                        .fill(theme.carbonCopy.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    ScrollView {
                        VStack(spacing: 2) {
                            if officers.isEmpty {
                                Text("NO MILITARY OFFICERS AVAILABLE")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(theme.carbonCopy)
                                    .padding(.vertical, 20)
                            }
                            ForEach(officers, id: \.id) { officer in
                                Button {
                                    dismissTargetSelection()
                                    finalizeDirective(task, targetOfficer: officer)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(dispositionColor(officer.disposition))
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(officer.name.uppercased())
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .tracking(0.5)
                                                .foregroundColor(theme.inkBlack)

                                            Text(officer.title ?? "Military Officer")
                                                .font(.system(size: 8, weight: .regular, design: .monospaced))
                                                .foregroundColor(theme.carbonCopy)
                                        }

                                        Spacer()

                                        Text("DISP: \(officer.disposition)")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundColor(dispositionColor(officer.disposition))

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9))
                                            .foregroundColor(theme.carbonCopy.opacity(0.5))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(theme.cardstock.opacity(0.3))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: 340)

                    cancelTargetButton()
                }
                .padding(.vertical, 16)
                .background(theme.parchment)

                Rectangle().fill(theme.accentGold).frame(height: 3)
            }
            .frame(maxWidth: 320)
            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
        }
    }

    /// Theater selection for military directives
    private func theaterSelectionOverlay(task: BureauTask) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismissTargetSelection() }

            VStack(spacing: 0) {
                Rectangle().fill(theme.accentGold).frame(height: 3)

                VStack(spacing: 12) {
                    targetSelectionHeader(
                        icon: "map.fill",
                        title: "SELECT THEATER COMMAND",
                        subtitle: task.name
                    )

                    Rectangle()
                        .fill(theme.carbonCopy.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    VStack(spacing: 2) {
                        ForEach(TheaterCommand.allCases, id: \.rawValue) { theater in
                            Button {
                                dismissTargetSelection()
                                finalizeDirective(task, targetTheater: theater)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "shield.lefthalf.filled")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.accentGold)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(theater.displayName.uppercased())
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .tracking(0.5)
                                            .foregroundColor(theme.inkBlack)

                                        Text(theater.strategicFocus)
                                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                                            .foregroundColor(theme.carbonCopy)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(theme.carbonCopy.opacity(0.5))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(theme.cardstock.opacity(0.3))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)

                    cancelTargetButton()
                }
                .padding(.vertical, 16)
                .background(theme.parchment)

                Rectangle().fill(theme.accentGold).frame(height: 3)
            }
            .frame(maxWidth: 320)
            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
        }
    }

    /// Ministry selection for state ministry directives
    private func ministrySelectionOverlay(task: BureauTask) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismissTargetSelection() }

            VStack(spacing: 0) {
                Rectangle().fill(theme.accentGold).frame(height: 3)

                VStack(spacing: 12) {
                    targetSelectionHeader(
                        icon: "building.columns.fill",
                        title: "SELECT MINISTRY",
                        subtitle: task.name
                    )

                    Rectangle()
                        .fill(theme.carbonCopy.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(MinistryDepartment.allCases, id: \.rawValue) { ministry in
                                Button {
                                    dismissTargetSelection()
                                    finalizeDirective(task, targetMinistry: ministry)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: ministry.iconName)
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.accentGold)
                                            .frame(width: 20)

                                        Text(ministry.displayName.uppercased())
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .tracking(0.5)
                                            .foregroundColor(theme.inkBlack)

                                        Spacer()

                                        if ministry.isCommission {
                                            Text("COMMISSION")
                                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                                .foregroundColor(theme.accentGold)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(theme.accentGold.opacity(0.12))
                                                .cornerRadius(2)
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9))
                                            .foregroundColor(theme.carbonCopy.opacity(0.5))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(theme.cardstock.opacity(0.3))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: 340)

                    cancelTargetButton()
                }
                .padding(.vertical, 16)
                .background(theme.parchment)

                Rectangle().fill(theme.accentGold).frame(height: 3)
            }
            .frame(maxWidth: 320)
            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
        }
    }

    /// Official selection for state ministry directives
    private func officialSelectionOverlay(task: BureauTask) -> some View {
        let officials = game.characters.filter { char in
            char.isAlive && char.status == "active" &&
            char.positionTrack == ExpandedCareerTrack.stateMinistry.rawValue
        }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }

        return ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismissTargetSelection() }

            VStack(spacing: 0) {
                Rectangle().fill(theme.accentGold).frame(height: 3)

                VStack(spacing: 12) {
                    targetSelectionHeader(
                        icon: "person.text.rectangle.fill",
                        title: "SELECT OFFICIAL",
                        subtitle: task.name
                    )

                    Rectangle()
                        .fill(theme.carbonCopy.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    ScrollView {
                        VStack(spacing: 2) {
                            if officials.isEmpty {
                                Text("NO MINISTRY OFFICIALS AVAILABLE")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(theme.carbonCopy)
                                    .padding(.vertical, 20)
                            }
                            ForEach(officials, id: \.id) { official in
                                Button {
                                    dismissTargetSelection()
                                    finalizeDirective(task, targetOfficial: official)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(dispositionColor(official.disposition))
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(official.name.uppercased())
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .tracking(0.5)
                                                .foregroundColor(theme.inkBlack)

                                            Text(official.title ?? "Ministry Official")
                                                .font(.system(size: 8, weight: .regular, design: .monospaced))
                                                .foregroundColor(theme.carbonCopy)
                                        }

                                        Spacer()

                                        Text("DISP: \(official.disposition)")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundColor(dispositionColor(official.disposition))

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9))
                                            .foregroundColor(theme.carbonCopy.opacity(0.5))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(theme.cardstock.opacity(0.3))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: 340)

                    cancelTargetButton()
                }
                .padding(.vertical, 16)
                .background(theme.parchment)

                Rectangle().fill(theme.accentGold).frame(height: 3)
            }
            .frame(maxWidth: 320)
            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
        }
    }

    // MARK: - Target Selection Helpers

    private func targetSelectionHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(theme.accentGold)

            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundColor(theme.accentGold)

            Text(subtitle.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
        .padding(.top, 4)
    }

    private func cancelTargetButton() -> some View {
        Button {
            dismissTargetSelection()
        } label: {
            Text("CANCEL")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.carbonCopy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(theme.cardstock)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    private func dismissTargetSelection() {
        withAnimation(.easeOut(duration: 0.2)) {
            showCountrySelection = false
            showOfficerSelection = false
            showTheaterSelection = false
            showMinistrySelection = false
            showOfficialSelection = false
            showCharacterSelection = false
            pendingDirectiveTask = nil
            pendingSecurityTask = nil
            pendingDecreeTask = nil
            pendingDecreeTarget = nil
            pendingTargetType = ""
        }
    }

    private func blocColor(for bloc: PoliticalBloc) -> Color {
        switch bloc {
        case .socialist: return .red
        case .capitalist: return .blue
        case .nonAligned: return .gray
        case .rival: return .orange
        }
    }

    private func successChanceColor(_ chance: Int) -> Color {
        if chance >= 70 { return theme.approvedGreen }
        if chance >= 50 { return theme.bronzeGold }
        return theme.sovietRed
    }

    private func dispositionColor(_ disposition: Int) -> Color {
        if disposition >= 60 { return theme.approvedGreen }
        if disposition >= 20 { return theme.bronzeGold }
        return theme.sovietRed
    }

    // MARK: - Character Selection Overlay (Security Directives)

    private func characterSelectionOverlay(task: BureauTask) -> some View {
        let action = SecurityAction.allActions.first(where: { $0.id == task.actionId })
        // Under Chairman's Decree, the maxTargetPosition gate is waived — Chairman
        // can reach anyone at or below his rank (Position 8 → everyone). Matches
        // the bypass logic in SecurityActionService.validateAction(viaDecree: true).
        let isDecreeFlow = pendingDecreeTask?.id == task.id
        let maxPosition = isDecreeFlow ? Int.max : (action?.maxTargetPosition ?? Int.max)
        let eligibleCharacters = game.characters.filter { character in
            guard character.isAlive && character.isActive else { return false }
            let position = character.positionIndex ?? 0
            if position > maxPosition { return false }
            if character.currentStatus == .detained || character.currentStatus == .underInvestigation {
                return false
            }
            return true
        }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }

        return ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showCharacterSelection = false
                        pendingSecurityTask = nil
                        pendingDecreeTask = nil
                        pendingDecreeTarget = nil
                        selectedTask = nil
                    }
                }

            VStack(spacing: 0) {
                Rectangle()
                    .fill(theme.accentGold)
                    .frame(height: 3)

                VStack(spacing: 12) {
                    // Title
                    VStack(spacing: 6) {
                        Image(systemName: task.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(isDecreeFlow ? theme.sovietRed : theme.accentGold)

                        Text(isDecreeFlow ? "DECREE TARGET" : "SELECT TARGET")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(isDecreeFlow ? theme.sovietRed : theme.accentGold)

                        Text(task.name.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(theme.inkBlack)

                        if isDecreeFlow {
                            Text("COMMITTEE GATES BYPASSED")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.sovietRed)
                        } else if let maxPos = action?.maxTargetPosition {
                            Text("TARGETS POSITION \(maxPos) AND BELOW")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.carbonCopy)
                        }
                    }

                    Rectangle()
                        .fill(theme.carbonCopy.opacity(0.2))
                        .frame(height: 1)

                    if eligibleCharacters.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 24))
                                .foregroundColor(theme.carbonCopy)

                            Text("NO ELIGIBLE TARGETS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.sovietRed)

                            Text("No characters meet the requirements for this action.")
                                .font(.system(size: 8, weight: .regular, design: .monospaced))
                                .foregroundColor(theme.carbonCopy)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(eligibleCharacters, id: \.id) { character in
                                    characterTargetRow(character: character, task: task)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showCharacterSelection = false
                            pendingSecurityTask = nil
                            pendingDecreeTask = nil
                            pendingDecreeTarget = nil
                            selectedTask = nil
                        }
                    } label: {
                        Text("CANCEL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(theme.carbonCopy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.cardstock)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(theme.parchment)

                Rectangle()
                    .fill(theme.accentGold)
                    .frame(height: 3)
            }
            .frame(maxWidth: 320)
            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
        }
    }

    private func characterTargetRow(character: GameCharacter, task: BureauTask) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                showCharacterSelection = false
            }
            // Decree flow stages the target and prompts the political-cost alert;
            // normal flow executes immediately as before.
            if pendingDecreeTask?.id == task.id {
                pendingDecreeTarget = character
                showDecreeConfirmAlert = true
            } else {
                finalizeSecurityDirective(task: task, target: character)
            }
        } label: {
            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text("\(character.positionIndex ?? 0)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.accentGold)
                    Text("POS")
                        .font(.system(size: 6, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.carbonCopy)
                }
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(character.name.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(theme.inkBlack)
                        .lineLimit(1)

                    Text(character.title ?? "Unknown Position")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundColor(theme.carbonCopy)
                        .lineLimit(1)
                }

                Spacer()

                securityTargetStatusIndicator(for: character)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
                    .foregroundColor(theme.carbonCopy.opacity(0.5))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(theme.cardstock)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func securityTargetStatusIndicator(for character: GameCharacter) -> some View {
        let disposition = character.disposition
        let label: String
        let color: Color

        if disposition >= 70 {
            label = "LOYAL"
            color = theme.approvedGreen
        } else if disposition >= 40 {
            label = "NEUTRAL"
            color = theme.bronzeGold
        } else {
            label = "HOSTILE"
            color = theme.sovietRed
        }

        return Text(label)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(2)
    }

    private func finalizeSecurityDirective(task: BureauTask, target: GameCharacter, viaDecree: Bool = false) {
        guard game.directivePoints > 0 else { return }
        // Decree path requires a charge — SecurityActionService also enforces this,
        // but guard here to avoid spending a directive point on a no-op execution.
        if viaDecree && game.decreeChargesRemaining <= 0 { return }

        let result = BureauOperationsService.shared.executeTask(
            task,
            for: game,
            modelContext: modelContext,
            targetCharacter: target,
            viaDecree: viaDecree
        )

        if result.operationInitiated {
            game.directivePoints -= 1

            // Apply track affinity for security directive
            game.addTrackAffinity(
                track: .securityServices,
                amount: 3,
                source: .personalAction,
                description: viaDecree ? "Decreed: \(task.name)" : "Issued directive: \(task.name)"
            )
        }

        pendingSecurityTask = nil
        pendingDecreeTask = nil
        pendingDecreeTarget = nil
        lastResult = result
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showResult = true
            selectedTask = nil
        }
    }

    // MARK: - Decree Confirmation Alert

    /// The political-cost wording mirrors SecurityPortalView.SecurityActionCard.decreeAlertMessage
    /// verbatim so the player sees identical disclosure regardless of where they invoke decree.
    private var decreeAlertMessage: String {
        let actionName = pendingDecreeTask?.name ?? "Security action"
        let targetClause: String
        if let target = pendingDecreeTarget {
            targetClause = "Target: \(target.name)"
        } else {
            targetClause = "No specific target."
        }
        var message = """
        \(actionName) — bypassing Standing Committee approval.

        \(targetClause)

        POLITICAL COST:
        \u{2022} \u{2212}20 Elite Loyalty
        \u{2022} \u{2212}10 Stability
        \u{2022} +20 Rival Threat
        \u{2022} \u{2212}15 International Standing

        This will consume 1 of \(game.decreeChargesRemaining) decree charges. The apparatus will not forget.
        """
        // Last-charge nudge — see DecreeChargesCounter.swift for shared phrasing.
        // The decree pool is shared with SecurityPortal, Crisis, and Emergency
        // surfaces, so the player should know before they spend their final charge.
        if let warning = decreeLastChargeWarning(for: game) {
            message += "\n\n" + warning
        }
        return message
    }
}
