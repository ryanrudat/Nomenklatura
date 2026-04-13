//
//  StateMinistryPortalView.swift
//  Nomenklatura
//
//  State Ministry Bureau Portal - State Council administrative operations
//  Modeled on China's State Council structure with ministries and commissions
//
//  Three sections:
//  - Overview: Ministry situation and departments
//  - Projects: Active state projects
//  - Actions: Execute ministry actions based on position
//

import SwiftUI
import SwiftData

struct StateMinistryPortalView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedSection: MinistrySection = .overview

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(spacing: 0) {
            PortalHeader(
                title: "STATE MINISTRY BUREAU",
                subtitle: "Council of State Administration",
                accentColor: Color(hex: "#2563EB")
            )
            .padding(.horizontal, 15)
            .padding(.top, 10)

            PortalSectionBar(
                selectedSection: $selectedSection,
                accessLevel: accessLevel,
                featureCategory: .administrative,
                accentColor: Color(hex: "#2563EB")
            )
            .padding(.horizontal, 15)
            .padding(.vertical, 10)

            // Content
            ScrollView {
                switch selectedSection {
                case .overview:
                    MinistryOverviewSection(game: game)
                case .projects:
                    MinistryProjectsSection(game: game)
                case .actions:
                    MinistryActionsSection(game: game)
                }
            }
        }
    }
}

// MARK: - Ministry Sections

enum MinistrySection: String, CaseIterable, PortalSection {
    case overview
    case projects
    case actions

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .projects: return "Projects"
        case .actions: return "Actions"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "building.columns.fill"
        case .projects: return "building.2.fill"
        case .actions: return "doc.badge.gearshape.fill"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .overview: return 0
        case .projects: return 2
        case .actions: return 1
        }
    }
}

// MARK: - Overview Section

struct MinistryOverviewSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private let actionService = StateMinistryActionService.shared

    private var activeProjects: [MinistryProject] {
        actionService.getActiveProjects(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            PortalPositionBanner(game: game, config: .ministry(accentColor: Color(hex: "#2563EB")))

            // State Situation Card
            StateSituationCard(game: game)

            // Quick Stats
            MinistryQuickStats(game: game, projectCount: activeProjects.count)

            // Department Status
            MinistryDepartmentStatusCard(game: game)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

extension PortalPositionBannerConfig {
    static func ministry(accentColor: Color) -> PortalPositionBannerConfig {
        PortalPositionBannerConfig(
            track: .stateMinistry,
            accentColor: accentColor,
            authorityLabel: "YOUR MINISTRY RANK",
            positionTitle: { position in
                switch position {
                case 0...1: return "Ministry Staff"
                case 2: return "Section Officer"
                case 3: return "Division Director"
                case 4...5: return "Vice Minister"
                case 6: return "Minister Level"
                default: return "Premier Level"
                }
            },
            equivalentTitle: { position in
                StateMinistryActionCategory.allCases
                    .filter { position >= $0.minimumPositionIndex }
                    .last?.stateCouncilEquivalent ?? "Administrative Staff"
            },
            noAuthorityEquivalent: "No Ministry Authority"
        )
    }
}

struct StateSituationCard: View {
    let game: Game
    @Environment(\.theme) var theme

    private var stateRating: String {
        let avgScore = (game.stability + game.treasury + game.industrialOutput) / 3
        switch avgScore {
        case 70...: return "PROSPEROUS"
        case 50..<70: return "STABLE"
        case 30..<50: return "STRAINED"
        default: return "CRISIS"
        }
    }

    private var ratingColor: String {
        let avgScore = (game.stability + game.treasury + game.industrialOutput) / 3
        switch avgScore {
        case 70...: return "#22c55e"
        case 50..<70: return "#3b82f6"
        case 30..<50: return "#f59e0b"
        default: return "#ef4444"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STATE SITUATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text(stateRating)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: ratingColor))
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                PortalMetricView(label: "Stability", value: "\(game.stability)", color: game.stability >= 50 ? .green : .orange)
                PortalMetricView(label: "Treasury", value: "\(game.treasury)", color: game.treasury >= 50 ? .green : .orange)
                PortalMetricView(label: "Industry", value: "\(game.industrialOutput)", color: game.industrialOutput >= 50 ? .green : .orange)
            }

            Divider()

            HStack(spacing: 12) {
                PortalStatusIndicator(label: "Budget", isStrong: game.treasury >= 60)
                PortalStatusIndicator(label: "Admin", isStrong: game.stability >= 60)
                PortalStatusIndicator(label: "Output", isStrong: game.industrialOutput >= 60)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct MinistryQuickStats: View {
    let game: Game
    let projectCount: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            MinistryStatBox(title: "NETWORK", value: "\(game.network)", icon: "person.3.fill")
            MinistryStatBox(title: "STANDING", value: "\(game.standing)", icon: "arrow.up.circle.fill")
            MinistryStatBox(title: "PROJECTS", value: "\(projectCount)", icon: "building.2.fill")
        }
    }
}

struct MinistryStatBox: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#2563EB"))

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(theme.inkBlack)

            Text(title)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct MinistryDepartmentStatusCard: View {
    let game: Game
    @Environment(\.theme) var theme

    // Show key departments
    private var keyDepartments: [MinistryDepartment] {
        [.generalOffice, .developmentReform, .finance, .industry, .audit, .commerce]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEY DEPARTMENTS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(keyDepartments, id: \.self) { department in
                MinistryDepartmentRow(department: department, game: game)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct MinistryDepartmentRow: View {
    let department: MinistryDepartment
    let game: Game
    @Environment(\.theme) var theme

    private var departmentStatus: String {
        switch department {
        case .generalOffice:
            return game.network >= 60 ? "Coordinating" : "Overwhelmed"
        case .developmentReform:
            return game.industrialOutput >= 50 ? "Planning" : "Delayed"
        case .finance:
            return game.treasury >= 50 ? "Funded" : "Constrained"
        case .industry:
            return game.industrialOutput >= 60 ? "Productive" : "Struggling"
        case .audit:
            return game.stability >= 50 ? "Monitoring" : "Compromised"
        case .commerce:
            return game.internationalStanding >= 50 ? "Trading" : "Isolated"
        default:
            return game.stability >= 50 ? "Functioning" : "Disrupted"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: department.iconName)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#2563EB"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(department.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.inkBlack)

                if department.isCommission {
                    Text("COMMISSION")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color(hex: "#7C3AED"))
                }
            }

            Spacer()

            Text(departmentStatus.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(theme.inkGray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Projects Section

struct MinistryProjectsSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private let actionService = StateMinistryActionService.shared

    private var activeProjects: [MinistryProject] {
        actionService.getActiveProjects(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if activeProjects.isEmpty {
                PortalEmptyStateView(
                    icon: "building.2.crop.circle",
                    title: "No Active Projects",
                    message: "Launch state projects from the Actions tab"
                )
            } else {
                ForEach(activeProjects) { project in
                    MinistryProjectCard(project: project, game: game)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct MinistryProjectCard: View {
    let project: MinistryProject
    let game: Game
    @Environment(\.theme) var theme

    private var turnsRemaining: Int {
        max(0, project.completionTurn - game.turnNumber)
    }

    private var progressPercent: Double {
        let total = project.completionTurn - project.initiatedTurn
        guard total > 0 else { return 0 }
        return Double(project.progress) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: project.department.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#2563EB"))

                Text(project.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.inkBlack)

                Spacer()

                Text(project.phase.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(phaseColor(project.phase))
                    .cornerRadius(4)
            }

            Text(project.description)
                .font(.system(size: 10))
                .foregroundColor(theme.inkGray)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(project.department.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "#2563EB"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#2563EB").opacity(0.1))
                    .cornerRadius(4)

                if project.department.isCommission {
                    Text("COMMISSION")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(hex: "#7C3AED"))
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.inkLight.opacity(0.3))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#2563EB"))
                            .frame(width: geometry.size.width * progressPercent, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Success Chance: \(project.successChance)%")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)

                    Spacer()

                    Text("\(turnsRemaining) turns remaining")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.inkBlack)
                }
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#2563EB").opacity(0.3), lineWidth: 1)
        )
    }

    private func phaseColor(_ phase: MinistryProjectPhase) -> Color {
        switch phase {
        case .planning: return .blue
        case .implementation: return .cyan
        case .execution: return .orange
        case .completion: return Color(hex: "#2563EB")
        case .completed: return .green
        case .failed: return .gray
        }
    }
}

// MARK: - Actions Section

struct MinistryActionsSection: View {
    @Bindable var game: Game
    @Environment(\.modelContext) var modelContext
    @Environment(\.theme) var theme

    private let actionService = StateMinistryActionService.shared

    // Track authority check
    private var hasTrackAuthority: Bool {
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInTrack = playerTrack == .stateMinistry
        let isTopLeadership = game.currentPositionIndex >= 7
        return isInTrack || isTopLeadership
    }

    private var availableActions: [StateMinistryAction] {
        let position = game.currentPositionIndex
        return StateMinistryAction.allActions.filter { $0.minimumPositionIndex <= position }
    }

    private var groupedActions: [(StateMinistryActionCategory, [StateMinistryAction])] {
        let grouped = Dictionary(grouping: availableActions) { $0.category }
        return StateMinistryActionCategory.allCases.compactMap { category in
            guard let actions = grouped[category], !actions.isEmpty else { return nil }
            return (category, actions)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            PortalPositionBanner(game: game, config: .ministry(accentColor: Color(hex: "#2563EB")))

            // Check track authority before showing actions
            if !hasTrackAuthority {
                NoTrackAuthorityView(
                    bureauName: "State Ministry Bureau",
                    requiredTrack: "State Ministry",
                    accentColor: Color(hex: "#2563EB")
                )
            } else if groupedActions.isEmpty {
                PortalEmptyStateView(
                    icon: "building.columns.fill",
                    title: "No Ministry Actions Available",
                    message: "Advance in position to unlock state ministry actions."
                )
            } else {
                ForEach(groupedActions, id: \.0) { category, actions in
                    MinistryActionCategorySection(
                        category: category,
                        actions: actions,
                        game: game,
                        modelContext: modelContext
                    )
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct MinistryActionCategorySection: View {
    let category: StateMinistryActionCategory
    let actions: [StateMinistryAction]
    @Bindable var game: Game
    let modelContext: ModelContext
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text(category.stateCouncilEquivalent)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)
            }

            ForEach(actions, id: \.id) { action in
                MinistryActionRow(action: action, game: game, modelContext: modelContext)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(categoryBorderColor(category), lineWidth: 1)
        )
    }

    private func categoryBorderColor(_ category: StateMinistryActionCategory) -> Color {
        Color(hex: category.color).opacity(0.5)
    }
}

struct MinistryActionRow: View {
    let action: StateMinistryAction
    @Bindable var game: Game
    let modelContext: ModelContext
    @Environment(\.theme) var theme
    @State private var showingConfirmation = false
    @State private var lastResult: StateMinistryActionService.ExecutionResult?

    private let actionService = StateMinistryActionService.shared

    private var validation: StateMinistryActionService.ValidationResult {
        actionService.validateAction(action, targetMinistry: nil, targetOfficial: nil, for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: action.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#2563EB"))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.inkBlack)

                    Text(action.description)
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                        .lineLimit(1)
                }

                Spacer()

                if validation.canExecute {
                    Button(action: { showingConfirmation = true }) {
                        Text(action.actionVerb)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#2563EB"))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(validation.reason ?? "Unavailable")
                        .font(.system(size: 8))
                        .foregroundColor(theme.inkLight)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                }
            }

            if validation.canExecute {
                HStack(spacing: 16) {
                    Text("Success: \(validation.successChance)%")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)

                    Text("Risk: \(action.riskLevel.displayName)")
                        .font(.system(size: 9))
                        .foregroundColor(riskColor(action.riskLevel))

                    if action.cooldownTurns > 1 {
                        Text("CD: \(action.cooldownTurns)t")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkGray)
                    }

                    if action.requiresCommitteeApproval {
                        Text("State Council Approval")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }

                if let department = action.department {
                    Text(department.displayName)
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "#2563EB"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#2563EB").opacity(0.1))
                        .cornerRadius(4)
                }
            }

            if let result = lastResult {
                Text(result.description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(result.succeeded ? .green : .red)
                    .padding(.top, 4)
            }
        }
        .padding(10)
        .background(theme.parchment)
        .cornerRadius(6)
        .sheet(isPresented: $showingConfirmation) {
            ActionConfirmationSheet(
                title: action.name,
                description: action.detailedDescription,
                successChance: validation.successChance,
                riskLevel: action.riskLevel.displayName,
                riskColor: riskColor(action.riskLevel),
                accentColor: Color(hex: "#2563EB"),
                actionVerb: action.actionVerb,
                onConfirm: {
                    executeAction()
                    showingConfirmation = false
                },
                onCancel: {
                    showingConfirmation = false
                }
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.clear)
        }
    }

    private func executeAction() {
        lastResult = actionService.executeAction(
            action,
            targetMinistry: nil,
            targetOfficial: nil,
            for: game,
            modelContext: modelContext
        )
    }

    private func riskColor(_ risk: MinistryRiskLevel) -> Color {
        switch risk {
        case .routine: return .green
        case .moderate: return .blue
        case .significant: return .orange
        case .major: return .red
        case .extreme: return .purple
        }
    }
}
