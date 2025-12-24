//
//  EmbassyPortalView.swift
//  Nomenklatura
//
//  Diplomatic Intelligence Center - hub for foreign affairs information
//

import SwiftUI
import SwiftData

struct EmbassyPortalView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedSection: EmbassySection = .dossiers

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section tabs
            EmbassySectionBar(selectedSection: $selectedSection, accessLevel: accessLevel)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)

            // Content
            ScrollView {
                switch selectedSection {
                case .dossiers:
                    NationDossiersSection(game: game)
                case .treaties:
                    TreatiesSection(game: game)
                case .intelligence:
                    IntelligenceSection(game: game)
                case .actions:
                    DiplomaticActionsSection(game: game)
                }
            }
        }
    }
}

// MARK: - Embassy Sections

enum EmbassySection: String, CaseIterable {
    case dossiers
    case treaties
    case intelligence
    case actions

    var title: String {
        switch self {
        case .dossiers: return "Dossiers"
        case .treaties: return "Treaties"
        case .intelligence: return "Intel"
        case .actions: return "Actions"
        }
    }

    var icon: String {
        switch self {
        case .dossiers: return "folder.fill"
        case .treaties: return "doc.text.fill"
        case .intelligence: return "eye.fill"
        case .actions: return "paperplane.fill"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .dossiers: return 0       // Public info
        case .treaties: return 4        // Position 4+
        case .intelligence: return 6    // Position 6+
        case .actions: return 1         // Position 1+ (all can access, limited actions)
        }
    }
}

// MARK: - Embassy Section Bar

struct EmbassySectionBar: View {
    @Binding var selectedSection: EmbassySection
    let accessLevel: AccessLevel
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(EmbassySection.allCases, id: \.self) { section in
                let hasAccess = accessLevel.effectiveLevel(for: .diplomatic) >= section.requiredLevel

                EmbassySectionButton(
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

struct EmbassySectionButton: View {
    let section: EmbassySection
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
                    (isSelected ? theme.sovietRed : theme.parchmentDark)
            )
            .cornerRadius(6)
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

// MARK: - Nation Dossiers Section

struct NationDossiersSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedNation: NationIdentifier?

    // Foreign nations in the PSRA alternate history
    private let nations = [
        ("soviet_union", "Soviet Union", "Revolutionary Ally", "socialist"),
        ("germany", "Germany", "Socialist Republic", "socialist"),
        ("cuba", "Cuba", "Government-in-Exile", "hostile"),
        ("canada", "Canada", "Lost Provinces Enemy", "hostile"),
        ("united_kingdom", "United Kingdom", "Imperial Adversary", "capitalist"),
        ("france", "France", "Unstable Republic", "capitalist"),
        ("japan", "Japan", "Pacific Occupier", "hostile"),
        ("mexico", "Mexico", "Neutral Neighbor", "neutral"),
        ("italy", "Italy", "Fascist State", "fascist"),
        ("spain", "Spain", "Fascist State", "fascist"),
        ("china", "China", "Contested Territory", "neutral")
    ]

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(nations, id: \.0) { nation in
                NationDossierRow(
                    id: nation.0,
                    name: nation.1,
                    description: nation.2,
                    bloc: nation.3,
                    game: game
                ) {
                    selectedNation = NationIdentifier(id: nation.0)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
        .sheet(item: $selectedNation) { nation in
            NationDossierDetailView(nationId: nation.id, game: game)
        }
    }
}

struct NationIdentifier: Identifiable {
    let id: String
}

struct NationDossierRow: View {
    let id: String
    let name: String
    let description: String
    let bloc: String
    @Bindable var game: Game
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Bloc indicator
                Circle()
                    .fill(blocColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(theme.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.inkBlack)

                    Text(description)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkLight)
            }
            .padding(12)
            .background(theme.parchmentDark)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var blocColor: Color {
        switch bloc {
        case "socialist": return Color(hex: "CD5C5C")     // Red - socialist allies
        case "capitalist": return Color(hex: "4169E1")    // Blue - capitalist powers
        case "neutral": return Color(hex: "808080")       // Gray - neutral nations
        case "hostile": return Color(hex: "8B0000")       // Dark red - active enemies
        case "fascist": return Color(hex: "2F2F2F")       // Dark gray - fascist states
        default: return Color.gray
        }
    }
}

// MARK: - Nation Dossier Detail View

struct NationDossierDetailView: View {
    let nationId: String
    @Bindable var game: Game
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header - always visible
                    Text("Detailed dossier for \(nationId.capitalized) would appear here with position-gated information.")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkBlack)

                    // Relationship data (Position 4+)
                    AccessGatedView(
                        requirement: .relationshipData,
                        accessLevel: accessLevel
                    ) {
                        InfoSection(title: "RELATIONSHIP METRICS") {
                            Text("Relationship scores, diplomatic status, trade volumes...")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkBlack)
                        }
                    }

                    // Intelligence (Position 6+)
                    AccessGatedView(
                        requirement: .intelligenceReports,
                        accessLevel: accessLevel
                    ) {
                        InfoSection(title: "INTELLIGENCE ASSESSMENT") {
                            Text("Internal stability, military readiness, economic indicators...")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkBlack)
                        }
                    }

                    // Classified (Position 8 only)
                    AccessGatedView(
                        requirement: .classifiedCables,
                        accessLevel: accessLevel
                    ) {
                        InfoSection(title: "CLASSIFIED CABLES") {
                            Text("TOP SECRET diplomatic communications...")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkBlack)
                        }
                    }
                }
                .padding(20)
            }
            .background(theme.parchment)
            .navigationTitle(nationId.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.sovietRed)
                }
            }
        }
    }
}

// MARK: - Treaties Section

struct TreatiesSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AccessGatedView(
                requirement: .treatyDetails,
                accessLevel: accessLevel
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ACTIVE TREATIES")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    // Placeholder
                    Text("No active treaties.")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkLight)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.parchmentDark)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

// MARK: - Intelligence Section

struct IntelligenceSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AccessGatedView(
                requirement: .intelligenceReports,
                accessLevel: accessLevel
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("INTELLIGENCE REPORTS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    // Placeholder
                    Text("No new intelligence reports.")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkLight)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.parchmentDark)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

// MARK: - Diplomatic Actions Section

struct DiplomaticActionsSection: View {
    @Bindable var game: Game
    @Environment(\.modelContext) var modelContext
    @Environment(\.theme) var theme
    @State private var selectedAction: DiplomaticAction?
    @State private var selectedCountry: ForeignCountry?
    @State private var showingActionSheet = false
    @State private var showingResultAlert = false
    @State private var resultMessage = ""
    @State private var resultSuccess = false

    private let actionService = DiplomaticActionService.shared

    private var availableActions: [DiplomaticAction] {
        actionService.availableActions(for: game)
    }

    private var lockedActions: [DiplomaticAction] {
        actionService.lockedActions(for: game)
    }

    private var cooldowns: [String: Int] {
        actionService.actionsOnCooldown(for: game)
    }

    private var actionsByCategory: [(category: DiplomaticActionCategory, actions: [DiplomaticAction])] {
        var result: [(DiplomaticActionCategory, [DiplomaticAction])] = []
        for category in DiplomaticActionCategory.allCases {
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
            PositionIndicatorBanner(game: game)

            if availableActions.isEmpty {
                // No actions available - show locked message
                NoActionsAvailableView(nextUnlock: lockedActions.first)
            } else {
                // Available actions by category
                ForEach(actionsByCategory, id: \.category) { category, actions in
                    ActionCategorySection(
                        category: category,
                        actions: actions,
                        cooldowns: cooldowns,
                        game: game
                    ) { action in
                        selectedAction = action
                        if action.targetType == .country {
                            showingActionSheet = true
                        } else {
                            // Execute immediately for non-country actions
                            executeAction(action, targetCountry: nil)
                        }
                    }
                }

                // Locked actions preview
                if !lockedActions.isEmpty {
                    LockedActionsPreview(actions: lockedActions, currentPosition: game.currentPositionIndex)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
        .sheet(isPresented: $showingActionSheet) {
            if let action = selectedAction {
                CountrySelectionSheet(
                    action: action,
                    game: game,
                    onSelect: { country in
                        selectedCountry = country
                        showingActionSheet = false
                        executeAction(action, targetCountry: country)
                    },
                    onCancel: {
                        showingActionSheet = false
                        selectedAction = nil
                    }
                )
            }
        }
        .alert(resultSuccess ? "Action Succeeded" : "Action Failed", isPresented: $showingResultAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resultMessage)
        }
    }

    private func executeAction(_ action: DiplomaticAction, targetCountry: ForeignCountry?) {
        let result = actionService.executeAction(
            action,
            targetCountry: targetCountry,
            for: game,
            modelContext: modelContext
        )

        resultMessage = result.description
        resultSuccess = result.succeeded
        showingResultAlert = true
        selectedAction = nil
        selectedCountry = nil
    }
}

// MARK: - Position Indicator Banner

struct PositionIndicatorBanner: View {
    let game: Game
    @Environment(\.theme) var theme

    private var positionTitle: String {
        let config = CampaignLoader.shared.getColdWarCampaign()
        return config.ladder.first { $0.index == game.currentPositionIndex }?.title ?? "Unknown"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR AUTHORITY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Text(positionTitle)
                    .font(theme.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.inkBlack)
            }

            Spacer()

            Text("Position \(game.currentPositionIndex)")
                .font(theme.tagFont)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(theme.sovietRed)
                .cornerRadius(4)
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

// MARK: - No Actions Available View

struct NoActionsAvailableView: View {
    let nextUnlock: DiplomaticAction?
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text("No Diplomatic Actions Available")
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            if let next = nextUnlock {
                Text("Advance to Position \(next.minimumPositionIndex) to unlock \"\(next.name)\"")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.center)
            } else {
                Text("Advance in rank to unlock diplomatic actions.")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Action Category Section

struct ActionCategorySection: View {
    let category: DiplomaticActionCategory
    let actions: [DiplomaticAction]
    let cooldowns: [String: Int]
    let game: Game
    let onActionTap: (DiplomaticAction) -> Void
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category header
            HStack {
                Text(category.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text("Position \(category.minimumPositionIndex)+")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: category.color))
            }

            // Actions grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(actions, id: \.id) { action in
                    ActionButton(
                        action: action,
                        cooldownTurns: cooldowns[action.id],
                        game: game,
                        onTap: { onActionTap(action) }
                    )
                }
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let action: DiplomaticAction
    let cooldownTurns: Int?
    let game: Game
    let onTap: () -> Void
    @Environment(\.theme) var theme

    private var isOnCooldown: Bool {
        cooldownTurns != nil && cooldownTurns! > 0
    }

    private var validation: ActionValidationResult {
        DiplomaticActionService.shared.validateAction(action, targetCountry: nil, for: game)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Icon and name
                HStack(spacing: 6) {
                    Image(systemName: action.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(isOnCooldown ? theme.inkLight : Color(hex: action.category.color))

                    Text(action.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isOnCooldown ? theme.inkLight : theme.inkBlack)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                // Status indicators
                HStack(spacing: 4) {
                    if isOnCooldown, let turns = cooldownTurns {
                        Text("\(turns) turns")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    } else {
                        Text("\(validation.successChance)%")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkGray)
                    }

                    if action.requiresCommitteeApproval {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 8))
                            .foregroundColor(theme.inkLight)
                    }

                    if action.riskLevel == .high || action.riskLevel == .extreme {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOnCooldown ? theme.parchmentDark.opacity(0.5) : theme.parchmentDark)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOnCooldown ? theme.inkLight.opacity(0.3) : theme.borderTan, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isOnCooldown)
    }
}

// MARK: - Locked Actions Preview

struct LockedActionsPreview: View {
    let actions: [DiplomaticAction]
    let currentPosition: Int
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    // Group by required position
    private var actionsByPosition: [(position: Int, actions: [DiplomaticAction])] {
        var grouped: [Int: [DiplomaticAction]] = [:]
        for action in actions {
            grouped[action.minimumPositionIndex, default: []].append(action)
        }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)

                    Text("LOCKED ACTIONS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(actionsByPosition, id: \.position) { position, positionActions in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Position \(position)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.inkGray)

                        ForEach(positionActions, id: \.id) { action in
                            HStack(spacing: 8) {
                                Image(systemName: action.iconName)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.inkLight)

                                Text(action.name)
                                    .font(theme.tagFont)
                                    .foregroundColor(theme.inkLight)

                                Spacer()

                                Text("+\(position - currentPosition) levels")
                                    .font(.system(size: 9))
                                    .foregroundColor(theme.inkLight)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.leading, 16)
                }
            }
        }
        .padding(12)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Country Selection Sheet

struct CountrySelectionSheet: View {
    let action: DiplomaticAction
    let game: Game
    let onSelect: (ForeignCountry) -> Void
    let onCancel: () -> Void
    @Environment(\.theme) var theme

    private var sortedCountries: [ForeignCountry] {
        game.foreignCountries.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(action.description)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                }

                Section("Select Target Nation") {
                    ForEach(sortedCountries, id: \.id) { country in
                        Button {
                            onSelect(country)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(blocColor(for: country.politicalBloc))
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(country.name)
                                        .font(theme.bodyFont)
                                        .foregroundColor(theme.inkBlack)

                                    Text(country.relationshipCategory)
                                        .font(theme.tagFont)
                                        .foregroundColor(theme.inkGray)
                                }

                                Spacer()

                                // Success chance preview
                                let chance = DiplomaticActionService.shared.calculateSuccessChance(
                                    action,
                                    targetCountry: country,
                                    game: game
                                )
                                Text("\(chance)%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(chanceColor(chance))
                            }
                        }
                    }
                }
            }
            .navigationTitle(action.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
            }
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

    private func chanceColor(_ chance: Int) -> Color {
        if chance >= 70 { return .green }
        if chance >= 50 { return .orange }
        return .red
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "cold_war")

    EmbassyPortalView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
