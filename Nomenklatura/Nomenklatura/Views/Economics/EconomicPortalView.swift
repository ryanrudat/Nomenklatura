//
//  EconomicPortalView.swift
//  Nomenklatura
//
//  Gosplan Economic Planning Bureau Portal - hub for economic planning operations
//  Modeled on Soviet Gosplan structure with position-gated actions and projects
//
//  Three sections:
//  - Overview: Economic situation summary and key metrics
//  - Projects: Active economic projects and their progress
//  - Actions: Execute economic planning actions based on position
//

import SwiftUI
import SwiftData

struct EconomicPortalView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedSection: EconomicSection = .overview

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            EconomicPortalHeader()
                .padding(.horizontal, 15)
                .padding(.top, 10)

            // Section tabs
            EconomicSectionBar(selectedSection: $selectedSection, accessLevel: accessLevel)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)

            // Content
            ScrollView {
                switch selectedSection {
                case .overview:
                    EconomicOverviewSection(game: game)
                case .projects:
                    EconomicProjectsSection(game: game)
                case .actions:
                    EconomicActionsSection(game: game)
                }
            }
        }
    }
}

// MARK: - Economic Portal Header

struct EconomicPortalHeader: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Text("ECONOMIC PLANNING BUREAU")
                .font(.system(size: 14, weight: .bold))
                .tracking(2)
                .foregroundColor(theme.accentGold)

            Text("State Planning Committee (Gosplan)")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.accentGold.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Economic Sections

enum EconomicSection: String, CaseIterable {
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
        case .overview: return "chart.bar.fill"
        case .projects: return "building.2.fill"
        case .actions: return "bolt.fill"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .overview: return 0      // All can view
        case .projects: return 2      // Position 2+ (planners)
        case .actions: return 1       // Position 1+ (limited actions)
        }
    }
}

// MARK: - Economic Section Bar

struct EconomicSectionBar: View {
    @Binding var selectedSection: EconomicSection
    let accessLevel: AccessLevel
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(EconomicSection.allCases, id: \.self) { section in
                let hasAccess = accessLevel.effectiveLevel(for: .economic) >= section.requiredLevel

                EconomicSectionButton(
                    section: section,
                    isSelected: selectedSection == section,
                    isLocked: !hasAccess
                ) {
                    if hasAccess {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                        }
                    }
                }
            }
        }
    }
}

struct EconomicSectionButton: View {
    let section: EconomicSection
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: section.icon)
                        .font(.system(size: 16))

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                            .offset(x: 8, y: 8)
                    }
                }

                Text(section.title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.3)
            }
            .foregroundColor(
                isLocked ? theme.inkLight :
                    (isSelected ? .white : theme.inkGray)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isLocked ? theme.parchmentDark.opacity(0.5) :
                    (isSelected ? theme.accentGold : theme.parchmentDark)
            )
            .cornerRadius(6)
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

// MARK: - Overview Section

struct EconomicOverviewSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private let actionService = EconomicActionService.shared

    private var activeProjects: [EconomicProject] {
        actionService.getActiveProjects(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            EconomicPositionBanner(game: game)

            // Economic Situation Card
            EconomicSituationCard(game: game)

            // Quick Stats
            EconomicQuickStats(game: game, projectCount: activeProjects.count)

            // Sector Performance
            SectorPerformanceCard(game: game)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct EconomicPositionBanner: View {
    let game: Game
    @Environment(\.theme) var theme

    private var isInTrack: Bool {
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        return playerTrack == .economicPlanning
    }

    private var isTopLeadership: Bool {
        game.currentPositionIndex >= 7
    }

    private var hasAuthority: Bool {
        isInTrack || isTopLeadership
    }

    private var categoryTitle: String {
        guard hasAuthority else { return "Observer Only" }
        let position = game.currentPositionIndex
        switch position {
        case 0...1: return "Factory Floor"
        case 2...3: return "Planning Office"
        case 4...5: return "Sector Directorate"
        case 6: return "Deputy Chairman"
        default: return "Gosplan Chairman"
        }
    }

    private var gosplanEquivalent: String {
        guard hasAuthority else { return "No Economic Authority" }
        return EconomicActionCategory.allCases
            .filter { game.currentPositionIndex >= $0.minimumPositionIndex }
            .last?.gosplanEquivalent ?? "Worker"
    }

    private var headerText: String {
        hasAuthority ? "YOUR ECONOMIC RANK" : "ACCESS STATUS"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerText)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Text(categoryTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(hasAuthority ? theme.inkBlack : theme.inkLight)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if hasAuthority {
                    Text("POSITION \(game.currentPositionIndex)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.accentGold)
                } else {
                    Text("VIEW ONLY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.inkLight)
                }

                Text(gosplanEquivalent)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkGray)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasAuthority ? theme.accentGold.opacity(0.3) : theme.inkLight.opacity(0.3), lineWidth: 1)
        )
    }
}

struct EconomicSituationCard: View {
    let game: Game
    @Environment(\.theme) var theme

    private var economicRating: String {
        let avgScore = (game.industrialOutput + game.foodSupply + min(100, max(0, game.treasury))) / 3
        switch avgScore {
        case 70...: return "EXCELLENT"
        case 50..<70: return "STABLE"
        case 30..<50: return "CONCERNING"
        default: return "CRITICAL"
        }
    }

    private var ratingColor: String {
        let avgScore = (game.industrialOutput + game.foodSupply + min(100, max(0, game.treasury))) / 3
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
                Text("ECONOMIC SITUATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text(economicRating)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: ratingColor))
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                EconomicMetric(label: "Industrial", value: "\(game.industrialOutput)", color: game.industrialOutput >= 50 ? .green : .orange)
                EconomicMetric(label: "Food Supply", value: "\(game.foodSupply)", color: game.foodSupply >= 50 ? .green : .orange)
                EconomicMetric(label: "Treasury", value: "\(game.treasury)", color: game.treasury >= 50 ? .green : .orange)
            }

            Divider()

            HStack(spacing: 12) {
                SectorIndicator(label: "Industry", isStrong: game.industrialOutput >= 60)
                SectorIndicator(label: "Agriculture", isStrong: game.foodSupply >= 60)
                SectorIndicator(label: "Trade", isStrong: game.treasury >= 60)
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

struct EconomicMetric: View {
    let label: String
    let value: String
    let color: Color
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(theme.inkGray)
        }
    }
}

struct SectorIndicator: View {
    let label: String
    let isStrong: Bool
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isStrong ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.inkGray)

                Text(isStrong ? "Strong" : "Weak")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)
            }
        }
    }
}

struct EconomicQuickStats: View {
    let game: Game
    let projectCount: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            QuickStatBox(label: "Active Projects", value: "\(projectCount)", icon: "hammer.fill")
            QuickStatBox(label: "Stability", value: "\(game.stability)%", icon: "shield.fill")
            QuickStatBox(label: "Popular Support", value: "\(game.popularSupport)%", icon: "person.3.fill")
        }
    }
}

struct QuickStatBox: View {
    let label: String
    let value: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accentGold)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.inkBlack)

            Text(label)
                .font(.system(size: 8))
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct SectorPerformanceCard: View {
    let game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SECTOR PERFORMANCE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(EconomicSector.allCases.prefix(4), id: \.self) { sector in
                SectorRow(sector: sector, performance: sectorPerformance(sector))
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private func sectorPerformance(_ sector: EconomicSector) -> Int {
        switch sector {
        case .heavyIndustry: return min(100, max(0, game.industrialOutput + 10))
        case .agriculture: return game.foodSupply
        case .energy: return min(100, max(0, game.industrialOutput - 5))
        case .defense: return min(100, max(0, game.militaryLoyalty))
        default: return min(100, max(0, (game.industrialOutput + game.stability) / 2))
        }
    }
}

struct SectorRow: View {
    let sector: EconomicSector
    let performance: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sector.iconName)
                .font(.system(size: 12))
                .foregroundColor(theme.accentGold)
                .frame(width: 20)

            Text(sector.displayName)
                .font(.system(size: 11))
                .foregroundColor(theme.inkBlack)

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.parchment)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(performanceColor)
                        .frame(width: geo.size.width * CGFloat(performance) / 100, height: 8)
                }
            }
            .frame(width: 80, height: 8)

            Text("\(performance)%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(performanceColor)
                .frame(width: 35, alignment: .trailing)
        }
    }

    private var performanceColor: Color {
        switch performance {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - Projects Section

struct EconomicProjectsSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private let actionService = EconomicActionService.shared

    private var activeProjects: [EconomicProject] {
        actionService.getActiveProjects(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            EconomicPositionBanner(game: game)

            // Active projects
            if !activeProjects.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accentGold)

                        Text("ACTIVE PROJECTS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(theme.inkBlack)

                        Spacer()

                        Text("\(activeProjects.count)/3")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.inkGray)
                    }

                    ForEach(activeProjects) { project in
                        ProjectCard(project: project, currentTurn: game.turnNumber)
                    }
                }
            } else {
                EmptyProjectsView()
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct ProjectCard: View {
    let project: EconomicProject
    let currentTurn: Int
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    private var turnsRemaining: Int {
        max(0, project.completionTurn - currentTurn)
    }

    private var progressPercent: Double {
        let totalTurns = project.completionTurn - project.initiatedTurn
        guard totalTurns > 0 else { return 0 }
        return Double(project.progress) / Double(totalTurns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundColor(theme.inkBlack)

                    if let sector = project.targetSector {
                        Text(sector.displayName)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)
                    }
                }

                Spacer()

                // Phase badge
                Text(project.phase.displayName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(phaseColor)
                    .cornerRadius(4)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                    Spacer()
                    Text("\(Int(progressPercent * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.inkBlack)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.parchmentDark)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.accentGold)
                            .frame(width: geo.size.width * progressPercent, height: 6)
                    }
                }
                .frame(height: 6)
            }

            // Expanded details
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    ProjectDetailRow(label: "Turns Remaining", value: "\(turnsRemaining)")
                    ProjectDetailRow(label: "Success Chance", value: "\(project.successChance)%")
                    ProjectDetailRow(label: "Current Phase", value: project.phase.displayName)
                }
            }

            // Tap to expand
            HStack {
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)
                Spacer()
            }
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private var phaseColor: Color {
        switch project.phase {
        case .planning: return .purple
        case .resourceAllocation: return .orange
        case .construction: return .blue
        case .implementation: return .green
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct ProjectDetailRow: View {
    let label: String
    let value: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(theme.inkGray)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.inkBlack)
        }
    }
}

struct EmptyProjectsView: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text("No Active Projects")
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            Text("Initiate economic projects from the Actions tab to begin construction programs.")
                .font(theme.tagFont)
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Actions Section

struct EconomicActionsSection: View {
    @Bindable var game: Game
    @Environment(\.modelContext) var modelContext
    @Environment(\.theme) var theme

    private let actionService = EconomicActionService.shared

    // Track authority check
    private var hasTrackAuthority: Bool {
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInTrack = playerTrack == .economicPlanning
        let isTopLeadership = game.currentPositionIndex >= 7
        return isInTrack || isTopLeadership
    }

    private var availableActions: [EconomicAction] {
        EconomicAction.actions(forPosition: game.currentPositionIndex)
    }

    private var lockedActions: [EconomicAction] {
        EconomicAction.allActions.filter { $0.minimumPositionIndex > game.currentPositionIndex }
    }

    private var cooldowns: EconomicCooldownTracker {
        actionService.getEconomicCooldowns(for: game)
    }

    private var actionsByCategory: [(category: EconomicActionCategory, actions: [EconomicAction])] {
        var result: [(EconomicActionCategory, [EconomicAction])] = []
        for category in EconomicActionCategory.allCases {
            let categoryActions = availableActions.filter { $0.category == category }
            if !categoryActions.isEmpty {
                result.append((category, categoryActions))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            EconomicPositionBanner(game: game)

            // Check track authority before showing actions
            if !hasTrackAuthority {
                NoTrackAuthorityView(
                    bureauName: "Economic Planning Bureau",
                    requiredTrack: "Economic Planning",
                    accentColor: theme.accentGold
                )
            } else if availableActions.isEmpty {
                NoEconomicActionsView(nextUnlock: lockedActions.first)
            } else {
                // Available actions by category
                ForEach(actionsByCategory, id: \.category) { category, actions in
                    EconomicActionCategorySection(
                        category: category,
                        actions: actions,
                        cooldowns: cooldowns,
                        currentTurn: game.turnNumber,
                        game: game,
                        modelContext: modelContext
                    )
                }

                // Locked actions preview
                if !lockedActions.isEmpty {
                    LockedEconomicActionsPreview(actions: lockedActions, currentPosition: game.currentPositionIndex)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct EconomicActionCategorySection: View {
    let category: EconomicActionCategory
    let actions: [EconomicAction]
    let cooldowns: EconomicCooldownTracker
    let currentTurn: Int
    @Bindable var game: Game
    let modelContext: ModelContext
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 8) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 0) {
                    Text(category.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    Text(category.gosplanEquivalent)
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                Text("Pos \(category.minimumPositionIndex)+")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.inkGray)
            }

            // Actions
            ForEach(actions, id: \.id) { action in
                EconomicActionCard(
                    action: action,
                    isOnCooldown: cooldowns.isOnCooldown(actionId: action.id, currentTurn: currentTurn),
                    cooldownRemaining: cooldowns.turnsRemaining(actionId: action.id, currentTurn: currentTurn),
                    validation: EconomicActionService.shared.validateAction(action, targetSector: nil, for: game),
                    game: game,
                    modelContext: modelContext
                )
            }
        }
    }

    private var categoryColor: Color {
        switch category {
        case .production: return .blue
        case .planning: return .purple
        case .allocation: return .orange
        case .reform: return .green
        case .strategic: return .red
        case .supreme: return Color(hex: "#FFD700")
        }
    }
}

struct EconomicActionCard: View {
    let action: EconomicAction
    let isOnCooldown: Bool
    let cooldownRemaining: Int
    let validation: EconomicActionService.ValidationResult
    @Bindable var game: Game
    let modelContext: ModelContext
    @Environment(\.theme) var theme
    @State private var isExpanded = false
    @State private var showingConfirmation = false
    @State private var showingSectorSheet = false
    @State private var lastResult: EconomicActionService.ExecutionResult?

    private let actionService = EconomicActionService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: action.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(isOnCooldown ? theme.inkLight : theme.accentGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name)
                        .font(theme.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(isOnCooldown ? theme.inkLight : theme.inkBlack)

                    Text(action.description)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                        .lineLimit(isExpanded ? nil : 1)
                }

                Spacer()

                if isOnCooldown {
                    Text("\(cooldownRemaining)t")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                } else {
                    Text("\(validation.successChance)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.accentGold)
                }
            }

            if isExpanded {
                Divider()

                Text(action.detailedDescription)
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkGray)

                HStack {
                    ActionInfoBadge(label: "Risk", value: action.riskLevel.displayName)
                    if action.executionTurns > 1 {
                        ActionInfoBadge(label: "Duration", value: "\(action.executionTurns) turns")
                    }
                    if action.requiresCommitteeApproval {
                        ActionInfoBadge(label: "Approval", value: "Required")
                    }
                }
            }

            // Action button
            if !isOnCooldown && validation.canExecute {
                Button(action: { showingConfirmation = true }) {
                    Text(action.actionVerb.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(theme.accentGold)
                        .cornerRadius(4)
                }
            }

            // Inline result display
            if let result = lastResult {
                Text(result.description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(result.succeeded ? .green : .red)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isOnCooldown ? theme.inkLight.opacity(0.3) : theme.borderTan, lineWidth: 1)
        )
        .opacity(isOnCooldown ? 0.7 : 1.0)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .sheet(isPresented: $showingConfirmation) {
            ActionConfirmationSheet(
                title: action.name,
                description: action.detailedDescription,
                successChance: validation.successChance,
                riskLevel: action.riskLevel.displayName,
                riskColor: riskColor(action.riskLevel),
                accentColor: theme.accentGold,
                actionVerb: action.actionVerb,
                onConfirm: {
                    showingConfirmation = false
                    if action.targetType == .sector {
                        showingSectorSheet = true
                    } else {
                        executeAction(sector: nil)
                    }
                },
                onCancel: {
                    showingConfirmation = false
                }
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color.clear)
        }
        .sheet(isPresented: $showingSectorSheet) {
            SectorSelectionSheet(
                action: action,
                onSelect: { sector in
                    showingSectorSheet = false
                    executeAction(sector: sector)
                },
                onCancel: {
                    showingSectorSheet = false
                }
            )
        }
    }

    private func executeAction(sector: EconomicSector?) {
        lastResult = actionService.executeAction(
            action,
            targetSector: sector,
            for: game,
            modelContext: modelContext
        )
    }

    private func riskColor(_ risk: EconomicRiskLevel) -> Color {
        switch risk {
        case .routine: return .green
        case .moderate: return .blue
        case .significant: return .orange
        case .major: return .red
        case .systemic: return .purple
        }
    }
}

struct ActionInfoBadge: View {
    let label: String
    let value: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.system(size: 9))
                .foregroundColor(theme.inkGray)
            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(theme.inkBlack)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(theme.parchmentDark)
        .cornerRadius(4)
    }
}

struct NoEconomicActionsView: View {
    let nextUnlock: EconomicAction?
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text("No Actions Available")
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            if let next = nextUnlock {
                Text("Next unlock at Position \(next.minimumPositionIndex): \(next.name)")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(12)
    }
}

struct LockedEconomicActionsPreview: View {
    let actions: [EconomicAction]
    let currentPosition: Int
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkLight)

                Text("LOCKED ACTIONS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkLight)
            }

            ForEach(actions.prefix(3), id: \.id) { action in
                HStack {
                    Text(action.name)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkLight)

                    Spacer()

                    Text("Position \(action.minimumPositionIndex)")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkLight)
                }
            }

            if actions.count > 3 {
                Text("+ \(actions.count - 3) more...")
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)
            }
        }
        .padding(12)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(8)
    }
}

struct SectorSelectionSheet: View {
    let action: EconomicAction
    let onSelect: (EconomicSector) -> Void
    let onCancel: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        NavigationView {
            List {
                ForEach(EconomicSector.allCases, id: \.self) { sector in
                    Button {
                        onSelect(sector)
                    } label: {
                        HStack {
                            Image(systemName: sector.iconName)
                                .foregroundColor(theme.accentGold)

                            VStack(alignment: .leading) {
                                Text(sector.displayName)
                                    .foregroundColor(theme.inkBlack)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(theme.inkGray)
                        }
                    }
                }
            }
            .navigationTitle("Select Sector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
}

// MARK: - Phase Display Extension

extension ProjectPhase {
    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .resourceAllocation: return "Resources"
        case .construction: return "Building"
        case .implementation: return "Implementing"
        case .completed: return "Complete"
        case .failed: return "Failed"
        }
    }
}
