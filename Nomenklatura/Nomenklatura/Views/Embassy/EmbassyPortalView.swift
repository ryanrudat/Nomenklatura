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
            PortalSectionBar(
                selectedSection: $selectedSection,
                accessLevel: accessLevel,
                featureCategory: .diplomatic,
                accentColor: theme.sovietRed
            )
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

enum EmbassySection: String, CaseIterable, PortalSection {
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

// MARK: - Nation Dossiers Section

struct NationDossiersSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedCountry: ForeignCountry?

    private var countriesByBloc: [(bloc: String, countries: [ForeignCountry])] {
        let grouped = Dictionary(grouping: game.foreignCountries) { $0.politicalBloc.rawValue }
        let order = ["socialist", "rivalSocialist", "nonAligned", "capitalist"]
        return order.compactMap { bloc in
            guard let countries = grouped[bloc], !countries.isEmpty else { return nil }
            return (bloc, countries.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        LazyVStack(spacing: 16) {
            if game.foreignCountries.isEmpty {
                Text("No foreign nations in the current campaign.")
                    .font(theme.bodyFont)
                    .foregroundColor(theme.inkLight)
                    .padding()
            } else {
                ForEach(countriesByBloc, id: \.bloc) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(blocDisplayName(group.bloc))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(blocColor(group.bloc))
                            .padding(.horizontal, 4)

                        ForEach(group.countries, id: \.countryId) { country in
                            CountryDossierRow(country: country) {
                                selectedCountry = country
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
        .sheet(item: $selectedCountry) { country in
            CountryDossierDetailView(country: country, game: game)
        }
    }

    private func blocDisplayName(_ bloc: String) -> String {
        switch bloc {
        case "socialist": return "SOCIALIST BLOC"
        case "rivalSocialist": return "RIVAL SOCIALIST STATES"
        case "nonAligned": return "NON-ALIGNED NATIONS"
        case "capitalist": return "CAPITALIST POWERS"
        default: return bloc.uppercased()
        }
    }

    private func blocColor(_ bloc: String) -> Color {
        switch bloc {
        case "socialist": return Color(hex: "CD5C5C")
        case "rivalSocialist": return Color(hex: "FF8C00")
        case "nonAligned": return Color(hex: "808080")
        case "capitalist": return Color(hex: "4169E1")
        default: return .gray
        }
    }
}

struct CountryDossierRow: View {
    let country: ForeignCountry
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(country.name)
                        .font(theme.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.inkBlack)

                    HStack(spacing: 8) {
                        Text(country.relationshipCategory)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)

                        if country.hasNuclearWeapons {
                            Text("NUCLEAR")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: "8B0000"))
                                .cornerRadius(2)
                        }
                    }
                }

                Spacer()

                // Relationship score gauge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(country.relationshipScore)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(relationshipColor)

                    Text(country.leaderName.isEmpty ? "Unknown" : country.leaderName)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(theme.inkLight)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
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

    private var statusColor: Color {
        switch country.status {
        case .allied: return Color(hex: "228B22")
        case .friendly: return Color(hex: "32CD32")
        case .neutral: return .gray
        case .strained: return .orange
        case .hostile: return Color(hex: "CD5C5C")
        case .atWar: return Color(hex: "8B0000")
        case .noRelations: return Color(hex: "2F2F2F")
        }
    }

    private var relationshipColor: Color {
        if country.relationshipScore > 30 { return Color(hex: "228B22") }
        if country.relationshipScore > -30 { return .gray }
        return Color(hex: "CD5C5C")
    }
}

// MARK: - Country Dossier Detail View

struct CountryDossierDetailView: View {
    let country: ForeignCountry
    @Bindable var game: Game
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(country.officialName.isEmpty ? country.name : country.officialName)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.inkBlack)

                        HStack(spacing: 8) {
                            Text(country.governmentType.displayName)
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)

                            Text("•")
                                .foregroundColor(theme.inkLight)

                            Text(country.politicalBloc.displayName)
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)

                            if !country.leaderName.isEmpty {
                                Text("•")
                                    .foregroundColor(theme.inkLight)
                                Text("\(country.leaderTitle) \(country.leaderName)")
                                    .font(theme.tagFont)
                                    .foregroundColor(theme.inkGray)
                            }
                        }
                    }

                    if !country.countryDescription.isEmpty {
                        Text(country.countryDescription)
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)
                    }

                    Divider()

                    // Diplomatic Status
                    dossierSection(title: "DIPLOMATIC STATUS") {
                        dossierRow("Status", country.status.displayName)
                        dossierRow("Relationship", "\(country.relationshipScore) (\(country.relationshipCategory))")
                        dossierRow("Tension", "\(country.diplomaticTension)%")
                        dossierRow("Trade Volume", "\(country.tradeVolume)")
                    }

                    // Military Assessment
                    dossierSection(title: "MILITARY ASSESSMENT") {
                        dossierRow("Strength", "\(country.militaryStrength)/100")
                        dossierRow("Nuclear Capable", country.hasNuclearWeapons ? "YES" : "No")
                        dossierRow("Our Bases Present", country.hasOurMilitaryBases ? "YES" : "No")
                    }

                    // Economic Profile
                    dossierSection(title: "ECONOMIC PROFILE") {
                        dossierRow("Economic Power", "\(country.economicPower)/100")
                        dossierRow("GDP Growth", "\(country.gdpGrowth)%")
                        dossierRow("Inflation", "\(country.countryInflationRate)%")
                        dossierRow("Trade Balance", "\(country.countryTradeBalance)")
                        if !country.strategicResources.isEmpty {
                            dossierRow("Resources", country.strategicResources.joined(separator: ", "))
                        }
                    }

                    // Intelligence
                    dossierSection(title: "INTELLIGENCE") {
                        dossierRow("Their Espionage", "\(country.espionageActivity)/100")
                        dossierRow("Our Assets", "\(country.ourIntelligenceAssets)/100")
                    }

                    // Treaties
                    if !country.treaties.isEmpty {
                        dossierSection(title: "ACTIVE TREATIES") {
                            ForEach(country.treaties, id: \.type) { treaty in
                                dossierRow(treaty.type.displayName, "Active")
                            }
                        }
                    }

                    // Strategic Assessment
                    if !country.strategicImportance.isEmpty {
                        dossierSection(title: "STRATEGIC ASSESSMENT") {
                            Text(country.strategicImportance)
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkBlack)
                        }
                    }

                    if !country.relationshipHistory.isEmpty {
                        dossierSection(title: "RELATIONSHIP HISTORY") {
                            Text(country.relationshipHistory)
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkBlack)
                        }
                    }
                }
                .padding(20)
            }
            .background(theme.parchment)
            .navigationTitle(country.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.sovietRed)
                }
            }
        }
    }

    @ViewBuilder
    private func dossierSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(theme.inkGray)

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.parchmentDark)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
    }

    private func dossierRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.inkGray)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.inkBlack)
        }
    }
}

// MARK: - Treaties Section

struct TreatiesSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var allTreaties: [(countryName: String, treaty: ActiveTreaty)] {
        game.foreignCountries.flatMap { country in
            country.treaties.map { (country.name, $0) }
        }.sorted { $0.countryName < $1.countryName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVE TREATIES")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(theme.inkGray)

            if allTreaties.isEmpty {
                Text("No active treaties with foreign nations.")
                    .font(theme.bodyFont)
                    .foregroundColor(theme.inkLight)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(theme.parchmentDark)
                    .cornerRadius(8)
            } else {
                ForEach(allTreaties, id: \.treaty.type) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.inkGray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.treaty.type.displayName)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(theme.inkBlack)

                            Text("with \(item.countryName)")
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)
                        }

                        Spacer()

                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "228B22"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "228B22").opacity(0.1))
                            .cornerRadius(3)
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
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

// MARK: - Intelligence Section

struct IntelligenceSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var hostileCountries: [ForeignCountry] {
        game.foreignCountries.filter { $0.espionageActivity > 50 }
            .sorted { $0.espionageActivity > $1.espionageActivity }
    }

    private var highValueAssets: [ForeignCountry] {
        game.foreignCountries.filter { $0.ourIntelligenceAssets > 40 }
            .sorted { $0.ourIntelligenceAssets > $1.ourIntelligenceAssets }
    }

    private var threats: [ForeignCountry] {
        game.foreignCountries.filter { $0.isThreat }
            .sorted { $0.militaryStrength > $1.militaryStrength }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Espionage threats
            intelSection(title: "HOSTILE INTELLIGENCE ACTIVITY", icon: "exclamationmark.triangle.fill") {
                if hostileCountries.isEmpty {
                    Text("No significant foreign espionage activity detected.")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkLight)
                } else {
                    ForEach(hostileCountries, id: \.countryId) { country in
                        intelRow(
                            country.name,
                            detail: "Espionage: \(country.espionageActivity)%",
                            severity: country.espionageActivity > 70 ? .high : .medium
                        )
                    }
                }
            }

            // Our assets abroad
            intelSection(title: "OUR INTELLIGENCE ASSETS", icon: "eye.fill") {
                if highValueAssets.isEmpty {
                    Text("No significant intelligence assets in place.")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkLight)
                } else {
                    ForEach(highValueAssets, id: \.countryId) { country in
                        intelRow(
                            country.name,
                            detail: "Asset strength: \(country.ourIntelligenceAssets)%",
                            severity: .info
                        )
                    }
                }
            }

            // Military threats
            intelSection(title: "MILITARY THREAT ASSESSMENT", icon: "shield.lefthalf.filled") {
                if threats.isEmpty {
                    Text("No immediate military threats identified.")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkLight)
                } else {
                    ForEach(threats, id: \.countryId) { country in
                        intelRow(
                            country.name,
                            detail: "Strength: \(country.militaryStrength) | \(country.hasNuclearWeapons ? "NUCLEAR" : "Conventional")",
                            severity: country.hasNuclearWeapons ? .high : .medium
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }

    private enum IntelSeverity {
        case info, medium, high
        var color: Color {
            switch self {
            case .info: return Color(hex: "4169E1")
            case .medium: return .orange
            case .high: return Color(hex: "CD5C5C")
            }
        }
    }

    @ViewBuilder
    private func intelSection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkGray)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(theme.inkGray)
            }

            VStack(spacing: 6) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.parchmentDark)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
    }

    private func intelRow(_ name: String, detail: String, severity: IntelSeverity) -> some View {
        HStack {
            Circle()
                .fill(severity.color)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.inkBlack)
            Spacer()
            Text(detail)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.inkGray)
        }
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
                PortalEmptyStateView(
                    icon: "lock.fill",
                    title: "No Diplomatic Actions Available",
                    message: lockedActions.first.map { "Advance to Position \($0.minimumPositionIndex) to unlock \"\($0.name)\"" } ?? "Advance in rank to unlock diplomatic actions."
                )
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
