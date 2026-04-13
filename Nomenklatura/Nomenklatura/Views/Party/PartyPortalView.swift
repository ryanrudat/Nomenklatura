//
//  PartyPortalView.swift
//  Nomenklatura
//
//  Party Apparatus Bureau Portal - CCP organizational operations
//  Modeled on Organization Dept, Propaganda Dept, United Front, Central Party School
//
//  Three sections:
//  - Overview: Party situation and organs
//  - Campaigns: Active ideological campaigns
//  - Actions: Execute party actions based on position
//

import SwiftUI
import SwiftData

struct PartyPortalView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedSection: PartySection = .overview

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            PortalHeader(
                title: "PARTY APPARATUS BUREAU",
                subtitle: "Central Committee Organization Department",
                accentColor: Color(hex: "#CC0000")
            )
            .padding(.horizontal, 15)
            .padding(.top, 10)

            // Section tabs
            PortalSectionBar(
                selectedSection: $selectedSection,
                accessLevel: accessLevel,
                featureCategory: .administrative,
                accentColor: Color(hex: "#CC0000")
            )
            .padding(.horizontal, 15)
            .padding(.vertical, 10)

            // Content
            ScrollView {
                switch selectedSection {
                case .overview:
                    PartyOverviewSection(game: game)
                case .campaigns:
                    PartyCampaignsSection(game: game)
                case .actions:
                    PartyActionsSection(game: game)
                }
            }
        }
    }
}

// MARK: - Party Sections

enum PartySection: String, CaseIterable, PortalSection {
    case overview
    case campaigns
    case actions

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .campaigns: return "Campaigns"
        case .actions: return "Actions"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "star.fill"
        case .campaigns: return "flag.fill"
        case .actions: return "person.crop.rectangle.stack.fill"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .overview: return 0
        case .campaigns: return 2
        case .actions: return 1
        }
    }
}

// MARK: - Overview Section

struct PartyOverviewSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private let actionService = PartyActionService.shared

    private var activeCampaigns: [PartyCampaign] {
        actionService.getActiveCampaigns(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            PortalPositionBanner(game: game, config: .party(accentColor: Color(hex: "#CC0000")))

            // Party Situation Card
            PartySituationCard(game: game)

            // Quick Stats
            PartyQuickStats(game: game, campaignCount: activeCampaigns.count)

            // Organ Status
            PartyOrganStatusCard(game: game)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

// MARK: - Party Position Banner Config

extension PortalPositionBannerConfig {
    static func party(accentColor: Color) -> PortalPositionBannerConfig {
        PortalPositionBannerConfig(
            track: .partyApparatus,
            accentColor: accentColor,
            authorityLabel: "YOUR PARTY RANK",
            positionTitle: { position in
                switch position {
                case 0...1: return "Party Worker"
                case 2: return "Party Secretary"
                case 3: return "Department Cadre"
                case 4...5: return "Bureau Director"
                case 6: return "Provincial Level"
                default: return "Central Level"
                }
            },
            equivalentTitle: { position in
                PartyActionCategory.allCases
                    .filter { position >= $0.minimumPositionIndex }
                    .last?.ccpEquivalent ?? "Grassroots Party Member"
            },
            noAuthorityEquivalent: "No Party Apparatus Authority"
        )
    }
}

struct PartySituationCard: View {
    let game: Game
    @Environment(\.theme) var theme

    private var partyRating: String {
        let avgScore = (game.eliteLoyalty + game.stability + game.popularSupport) / 3
        switch avgScore {
        case 70...: return "STRONG"
        case 50..<70: return "STABLE"
        case 30..<50: return "WAVERING"
        default: return "CRISIS"
        }
    }

    private var ratingColor: String {
        let avgScore = (game.eliteLoyalty + game.stability + game.popularSupport) / 3
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
                Text("PARTY SITUATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text(partyRating)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: ratingColor))
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                PortalMetricView(label: "Elite Loyalty", value: "\(game.eliteLoyalty)", color: game.eliteLoyalty >= 50 ? .green : .orange)
                PortalMetricView(label: "Stability", value: "\(game.stability)", color: game.stability >= 50 ? .green : .orange)
                PortalMetricView(label: "Support", value: "\(game.popularSupport)", color: game.popularSupport >= 50 ? .green : .orange)
            }

            Divider()

            HStack(spacing: 12) {
                PortalStatusIndicator(label: "Centralism", isStrong: game.eliteLoyalty >= 60)
                PortalStatusIndicator(label: "Discipline", isStrong: game.stability >= 60)
                PortalStatusIndicator(label: "Mass Line", isStrong: game.popularSupport >= 60)
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

struct PartyQuickStats: View {
    let game: Game
    let campaignCount: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            PartyStatBox(title: "NETWORK", value: "\(game.network)", icon: "person.3.fill")
            PartyStatBox(title: "STANDING", value: "\(game.standing)", icon: "arrow.up.circle.fill")
            PartyStatBox(title: "CAMPAIGNS", value: "\(campaignCount)", icon: "flag.fill")
        }
    }
}

struct PartyStatBox: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#CC0000"))

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

struct PartyOrganStatusCard: View {
    let game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PARTY ORGANS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(PartyOrgan.allCases, id: \.self) { organ in
                PartyOrganRow(organ: organ, game: game)
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

struct PartyOrganRow: View {
    let organ: PartyOrgan
    let game: Game
    @Environment(\.theme) var theme

    private var organStatus: String {
        // Status based on relevant game state
        switch organ {
        case .organizationDept:
            return game.network >= 60 ? "Active" : "Limited"
        case .propagandaDept:
            return game.popularSupport >= 50 ? "Effective" : "Struggling"
        case .unitedFrontDept:
            return game.internationalStanding >= 50 ? "Engaged" : "Isolated"
        case .centralPartySchool:
            return game.eliteLoyalty >= 50 ? "Training" : "Undermined"
        case .disciplineInspection:
            return game.stability >= 50 ? "Vigilant" : "Compromised"
        case .secretariat, .generalOffice:
            return game.standing >= 50 ? "Functioning" : "Disrupted"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: organ.iconName)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CC0000"))
                .frame(width: 24)

            Text(organ.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.inkBlack)

            Spacer()

            Text(organStatus.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(theme.inkGray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Campaigns Section

struct PartyCampaignsSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private let actionService = PartyActionService.shared

    private var activeCampaigns: [PartyCampaign] {
        actionService.getActiveCampaigns(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if activeCampaigns.isEmpty {
                PortalEmptyStateView(
                    icon: "flag.slash",
                    title: "No Active Campaigns",
                    message: "Launch ideological campaigns from the Actions tab"
                )
            } else {
                ForEach(activeCampaigns) { campaign in
                    PartyCampaignCard(campaign: campaign, game: game)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct PartyCampaignCard: View {
    let campaign: PartyCampaign
    let game: Game
    @Environment(\.theme) var theme

    private var turnsRemaining: Int {
        max(0, campaign.completionTurn - game.turnNumber)
    }

    private var progressPercent: Double {
        let total = campaign.completionTurn - campaign.initiatedTurn
        guard total > 0 else { return 0 }
        return Double(campaign.progress) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: campaign.organ.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#CC0000"))

                Text(campaign.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.inkBlack)

                Spacer()

                Text(campaign.phase.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(phaseColor(campaign.phase))
                    .cornerRadius(4)
            }

            Text(campaign.description)
                .font(.system(size: 10))
                .foregroundColor(theme.inkGray)
                .lineLimit(2)

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.inkLight.opacity(0.3))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#CC0000"))
                            .frame(width: geometry.size.width * progressPercent, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Success Chance: \(campaign.successChance)%")
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
                .stroke(Color(hex: "#CC0000").opacity(0.3), lineWidth: 1)
        )
    }

    private func phaseColor(_ phase: PartyCampaignPhase) -> Color {
        switch phase {
        case .preparation: return .blue
        case .mobilization: return .orange
        case .implementation: return Color(hex: "#CC0000")
        case .concluded: return .green
        case .failed: return .gray
        }
    }
}

// MARK: - Actions Section

struct PartyActionsSection: View {
    @Bindable var game: Game
    @Environment(\.modelContext) var modelContext
    @Environment(\.theme) var theme

    private let actionService = PartyActionService.shared

    // Track authority check
    private var hasTrackAuthority: Bool {
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInTrack = playerTrack == .partyApparatus
        let isTopLeadership = game.currentPositionIndex >= 7
        return isInTrack || isTopLeadership
    }

    private var availableActions: [PartyAction] {
        let position = game.currentPositionIndex
        return PartyAction.allActions.filter { $0.minimumPositionIndex <= position }
    }

    private var groupedActions: [(PartyActionCategory, [PartyAction])] {
        let grouped = Dictionary(grouping: availableActions) { $0.category }
        return PartyActionCategory.allCases.compactMap { category in
            guard let actions = grouped[category], !actions.isEmpty else { return nil }
            return (category, actions)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            PortalPositionBanner(game: game, config: .party(accentColor: Color(hex: "#CC0000")))

            // Check track authority before showing actions
            if !hasTrackAuthority {
                NoTrackAuthorityView(
                    bureauName: "Party Apparatus Bureau",
                    requiredTrack: "Party Apparatus",
                    accentColor: Color(hex: "#CC0000")
                )
            } else if groupedActions.isEmpty {
                PortalEmptyStateView(
                    icon: "person.crop.circle.badge.xmark",
                    title: "No Party Actions Available",
                    message: "Advance in position to unlock party apparatus actions."
                )
            } else {
                ForEach(groupedActions, id: \.0) { category, actions in
                    PartyActionCategorySection(
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

struct PartyActionCategorySection: View {
    let category: PartyActionCategory
    let actions: [PartyAction]
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

                Text(category.ccpEquivalent)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)
            }

            ForEach(actions, id: \.id) { action in
                PartyActionRow(action: action, game: game, modelContext: modelContext)
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

    private func categoryBorderColor(_ category: PartyActionCategory) -> Color {
        Color(hex: category.color).opacity(0.5)
    }
}

struct PartyActionRow: View {
    let action: PartyAction
    @Bindable var game: Game
    let modelContext: ModelContext
    @Environment(\.theme) var theme
    @State private var showingConfirmation = false
    @State private var lastResult: PartyActionService.ExecutionResult?

    private let actionService = PartyActionService.shared

    private var validation: PartyActionService.ValidationResult {
        actionService.validateAction(action, targetCadre: nil, for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: action.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#CC0000"))
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
                            .background(Color(hex: "#CC0000"))
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
                        Text("Approval Required")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                    }
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
                accentColor: Color(hex: "#CC0000"),
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
            targetCadre: nil,
            targetDepartment: nil,
            for: game,
            modelContext: modelContext
        )
    }

    private func riskColor(_ risk: PartyRiskLevel) -> Color {
        switch risk {
        case .routine: return .green
        case .moderate: return .blue
        case .significant: return .orange
        case .major: return .red
        case .extreme: return .purple
        }
    }
}
