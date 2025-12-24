//
//  SecurityPortalView.swift
//  Nomenklatura
//
//  State Protection Bureau (BPS) Portal - hub for security operations
//  Modeled on CCP's Central Commission for Discipline Inspection (CCDI)
//
//  Four sections:
//  - Operations: Active investigations and case management
//  - Intelligence: Position-gated security briefings
//  - Detention: Shuanggui management and interrogation
//  - Actions: Execute security actions based on position
//

import SwiftUI
import SwiftData

struct SecurityPortalView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedSection: SecuritySection = .operations

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SecurityPortalHeader()
                .padding(.horizontal, 15)
                .padding(.top, 10)

            // Section tabs
            SecuritySectionBar(selectedSection: $selectedSection, accessLevel: accessLevel)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)

            // Content
            ScrollView {
                switch selectedSection {
                case .operations:
                    SecurityOperationsSection(game: game)
                case .intelligence:
                    SecurityIntelligenceSection(game: game)
                case .detention:
                    SecurityDetentionSection(game: game)
                case .actions:
                    SecurityActionsSection(game: game)
                }
            }
        }
    }
}

// MARK: - Security Portal Header

struct SecurityPortalHeader: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Text("STATE PROTECTION BUREAU")
                .font(.system(size: 14, weight: .bold))
                .tracking(2)
                .foregroundColor(theme.sovietRed)

            Text("Central Commission for Discipline Inspection")
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
                .stroke(theme.sovietRed.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Security Sections

enum SecuritySection: String, CaseIterable {
    case operations
    case intelligence
    case detention
    case actions

    var title: String {
        switch self {
        case .operations: return "Operations"
        case .intelligence: return "Intel"
        case .detention: return "Detention"
        case .actions: return "Actions"
        }
    }

    var icon: String {
        switch self {
        case .operations: return "folder.fill"
        case .intelligence: return "eye.fill"
        case .detention: return "lock.fill"
        case .actions: return "bolt.fill"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .operations: return 0      // All can view (filtered content)
        case .intelligence: return 1    // Position 1+ (all security personnel)
        case .detention: return 3       // Position 3+ (case officers)
        case .actions: return 1         // Position 1+ (limited actions)
        }
    }
}

// MARK: - Security Section Bar

struct SecuritySectionBar: View {
    @Binding var selectedSection: SecuritySection
    let accessLevel: AccessLevel
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(SecuritySection.allCases, id: \.self) { section in
                let hasAccess = accessLevel.effectiveLevel(for: .intelligence) >= section.requiredLevel

                SecuritySectionButton(
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

struct SecuritySectionButton: View {
    let section: SecuritySection
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

// MARK: - Operations Section

struct SecurityOperationsSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var pendingActions: [SecurityActionRecord] {
        SecurityActionService.shared.getPendingActions(for: game)
    }

    private var activeInvestigations: [SecurityActionRecord] {
        pendingActions.filter { $0.status == .inProgress }
    }

    private var awaitingApproval: [SecurityActionRecord] {
        pendingActions.filter { $0.status == .awaitingApproval }
    }

    private var completedActions: [SecurityActionRecord] {
        pendingActions.filter { $0.status == .completed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            SecurityPositionBanner(game: game)

            // Situation Summary
            SecuritySituationCard(game: game)

            // Active Investigations
            if !activeInvestigations.isEmpty {
                OperationsSubsection(title: "ACTIVE INVESTIGATIONS", icon: "magnifyingglass") {
                    ForEach(activeInvestigations, id: \.id) { action in
                        InvestigationCard(action: action, game: game)
                    }
                }
            }

            // Awaiting Approval
            if !awaitingApproval.isEmpty {
                OperationsSubsection(title: "AWAITING APPROVAL", icon: "clock.fill") {
                    ForEach(awaitingApproval, id: \.id) { action in
                        InvestigationCard(action: action, game: game)
                    }
                }
            }

            // Recent Completed
            if !completedActions.isEmpty {
                OperationsSubsection(title: "RECENTLY CONCLUDED", icon: "checkmark.circle.fill") {
                    ForEach(completedActions.prefix(5), id: \.id) { action in
                        CompletedActionCard(action: action, game: game)
                    }
                }
            }

            // Empty state
            if pendingActions.isEmpty {
                EmptyOperationsView()
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct OperationsSubsection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.sovietRed)

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkBlack)
            }

            content
        }
    }
}

struct SecuritySituationCard: View {
    let game: Game
    @Environment(\.theme) var theme

    private var summary: SecuritySituationSummary {
        SecurityBriefingService.shared.generateSituationSummary(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SECURITY SITUATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text(summary.overallSecurityRating.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: summary.overallSecurityRating.displayColor))
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                SituationMetric(label: "Investigations", value: "\(summary.activeInvestigations)")
                SituationMetric(label: "Detentions", value: "\(summary.activeDetentions)")
                SituationMetric(label: "Pending Trials", value: "\(summary.pendingTrials)")
            }

            Divider()

            HStack(spacing: 12) {
                ThreatIndicator(label: "Domestic", level: summary.domesticUnrestThreat)
                ThreatIndicator(label: "Factions", level: summary.factionIntrigueThreat)
                ThreatIndicator(label: "Foreign", level: summary.foreignSpyThreat)
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

struct SituationMetric: View {
    let label: String
    let value: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.inkBlack)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(theme.inkGray)
        }
    }
}

struct ThreatIndicator: View {
    let label: String
    let level: SecuritySituationSummary.ThreatLevel
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: level.displayColor))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.inkGray)

                Text(level.rawValue)
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)
            }
        }
    }
}

struct InvestigationCard: View {
    let action: SecurityActionRecord
    let game: Game
    @Environment(\.theme) var theme

    private var target: GameCharacter? {
        guard let targetId = action.targetCharacterId else { return nil }
        return game.characters.first { $0.id.uuidString == targetId }
    }

    private var actionInfo: SecurityAction? {
        SecurityAction.action(withId: action.actionId)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(action.status == .inProgress ? theme.sovietRed : Color.orange)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(target?.name ?? "Unknown Target")
                    .font(theme.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.inkBlack)

                Text(actionInfo?.name ?? action.actionId)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(action.successChance)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.inkBlack)

                Text("Success")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkGray)
            }
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct CompletedActionCard: View {
    let action: SecurityActionRecord
    let game: Game
    @Environment(\.theme) var theme

    private var target: GameCharacter? {
        guard let targetId = action.targetCharacterId else { return nil }
        return game.characters.first { $0.id.uuidString == targetId }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: action.result?.succeeded == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(action.result?.succeeded == true ? .green : theme.sovietRed)

            Text(target?.name ?? "Unknown")
                .font(theme.tagFont)
                .foregroundColor(theme.inkBlack)

            Spacer()

            Text(action.result?.succeeded == true ? "SUCCESS" : "FAILED")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(action.result?.succeeded == true ? .green : theme.sovietRed)
        }
        .padding(8)
        .background(theme.parchment.opacity(0.5))
        .cornerRadius(4)
    }
}

struct EmptyOperationsView: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text("No Active Operations")
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            Text("Initiate investigations from the Actions tab to begin security operations.")
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

// MARK: - Intelligence Section

struct SecurityIntelligenceSection: View {
    @Bindable var game: Game
    @Environment(\.modelContext) var modelContext
    @Environment(\.theme) var theme

    private var briefing: DailySecurityBriefing {
        SecurityBriefingService.shared.generateDailyBriefing(for: game, modelContext: modelContext)
    }

    private var visibleItems: [SecurityBriefingItem] {
        briefing.visibleItems(forPositionIndex: game.currentPositionIndex)
    }

    private var urgentItems: [SecurityBriefingItem] {
        visibleItems.filter { $0.isUrgent }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            SecurityPositionBanner(game: game)

            // Classification legend
            ClassificationLegend(currentPosition: game.currentPositionIndex)

            // Urgent briefings
            if !urgentItems.isEmpty {
                IntelSubsection(title: "URGENT BRIEFINGS", icon: "exclamationmark.triangle.fill", isUrgent: true) {
                    ForEach(urgentItems) { item in
                        SecurityBriefingCard(item: item, positionIndex: game.currentPositionIndex)
                    }
                }
            }

            // All briefings by category
            ForEach(SecurityBriefingCategory.allCases, id: \.self) { category in
                let categoryItems = visibleItems.filter { $0.category == category && !$0.isUrgent }
                if !categoryItems.isEmpty {
                    IntelSubsection(title: category.displayName.uppercased(), icon: category.iconName, isUrgent: false) {
                        ForEach(categoryItems) { item in
                            SecurityBriefingCard(item: item, positionIndex: game.currentPositionIndex)
                        }
                    }
                }
            }

            if visibleItems.isEmpty {
                EmptyIntelligenceView()
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct ClassificationLegend: View {
    let currentPosition: Int
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR CLEARANCE LEVEL")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            HStack(spacing: 8) {
                ForEach(SecurityClassification.allCases, id: \.self) { classification in
                    let hasAccess = currentPosition >= classification.minimumPositionIndex
                    ClassificationBadge(classification: classification, hasAccess: hasAccess)
                }
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }
}

struct ClassificationBadge: View {
    let classification: SecurityClassification
    let hasAccess: Bool
    @Environment(\.theme) var theme

    var body: some View {
        Text(classification.rawValue.prefix(3))
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(hasAccess ? .white : theme.inkLight)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(hasAccess ? Color(hex: classification.displayColor) : theme.parchment)
            .cornerRadius(3)
            .opacity(hasAccess ? 1.0 : 0.5)
    }
}

struct IntelSubsection<Content: View>: View {
    let title: String
    let icon: String
    let isUrgent: Bool
    @ViewBuilder let content: Content
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isUrgent ? theme.sovietRed : theme.inkGray)

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(isUrgent ? theme.sovietRed : theme.inkBlack)
            }

            content
        }
    }
}

struct SecurityBriefingCard: View {
    let item: SecurityBriefingItem
    let positionIndex: Int
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    private var content: SecurityBriefingContent {
        item.content(forPositionIndex: positionIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                // Classification badge
                Text(item.classification.rawValue)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: item.classification.displayColor))
                    .cornerRadius(3)

                if let rating = content.reliabilityRating {
                    Text("[\(rating)]")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                if item.isUrgent {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }

                Image(systemName: item.category.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkGray)
            }

            // Headline
            Text(content.headline)
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            // Body (expandable)
            if isExpanded {
                Text(content.body)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .padding(.top, 4)

                if content.showsRecommendations, let actions = item.recommendedActions {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RECOMMENDED ACTIONS:")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(theme.inkGray)

                        ForEach(actions, id: \.self) { action in
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                Text(action)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(theme.inkBlack)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.isUrgent ? theme.sovietRed.opacity(0.5) : theme.borderTan, lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}

struct EmptyIntelligenceView: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text("No Intelligence Available")
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            Text("Security briefings will appear as operations generate intelligence.")
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

// MARK: - Detention Section

struct SecurityDetentionSection: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var activeDetentions: [ShuangguiDetention] {
        SecurityActionService.shared.getActiveDetentions(for: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Position indicator
            SecurityPositionBanner(game: game)

            // Detention overview
            DetentionOverview(detentions: activeDetentions)

            // Active detentions
            if !activeDetentions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.sovietRed)

                        Text("ACTIVE SHUANGGUI DETENTIONS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(theme.inkBlack)
                    }

                    ForEach(activeDetentions) { detention in
                        DetentionCard(detention: detention, game: game)
                    }
                }
            } else {
                EmptyDetentionView()
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct DetentionOverview: View {
    let detentions: [ShuangguiDetention]
    @Environment(\.theme) var theme

    private var confessionsObtained: Int {
        detentions.filter { $0.confessionObtained }.count
    }

    private var referredToTrial: Int {
        detentions.filter { $0.referredToTrial }.count
    }

    var body: some View {
        HStack(spacing: 16) {
            DetentionStat(label: "Active", value: "\(detentions.count)", color: theme.sovietRed)
            DetentionStat(label: "Confessions", value: "\(confessionsObtained)", color: .orange)
            DetentionStat(label: "To Trial", value: "\(referredToTrial)", color: .green)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }
}

struct DetentionStat: View {
    let label: String
    let value: String
    let color: Color
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DetentionCard: View {
    let detention: ShuangguiDetention
    let game: Game
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(detention.targetName)
                        .font(theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundColor(theme.inkBlack)

                    Text("Position \(detention.targetPosition)")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                // Phase badge
                Text(detention.phase.displayName)
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
                    Text("Evidence")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                    Spacer()
                    Text("\(detention.evidenceAccumulated)%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.inkBlack)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.parchmentDark)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.sovietRed)
                            .frame(width: geo.size.width * CGFloat(detention.evidenceAccumulated) / 100, height: 6)
                    }
                }
                .frame(height: 6)
            }

            // Expanded details
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Location", value: detention.location.displayName)
                    DetailRow(label: "Duration", value: "\(detention.turnsInDetention * 2) weeks")
                    DetailRow(label: "Guards", value: "\(detention.accompanyingProtectors)")
                    DetailRow(label: "Confession", value: detention.confessionObtained ? "OBTAINED" : "Not yet")
                    DetailRow(label: "Suicide Watch", value: detention.suicideWatchActive ? "Active" : "Inactive")
                    DetailRow(label: "Lawyer Access", value: detention.lawyerAccessDenied ? "DENIED" : "Allowed")

                    if !detention.implicatedCharacterIds.isEmpty {
                        DetailRow(label: "Implicated", value: "\(detention.implicatedCharacterIds.count) others")
                    }
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
        switch detention.phase {
        case .isolation: return .purple
        case .interrogation: return .orange
        case .confession: return .blue
        case .documentation: return .green
        case .referral: return .gray
        }
    }
}

struct DetailRow: View {
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

struct EmptyDetentionView: View {
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text("No Active Detentions")
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            Text("Use security actions to initiate shuanggui detention of suspects.")
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

struct SecurityActionsSection: View {
    @Bindable var game: Game
    @Environment(\.modelContext) var modelContext
    @Environment(\.theme) var theme

    private let actionService = SecurityActionService.shared

    // Track authority check
    private var hasTrackAuthority: Bool {
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let isInTrack = playerTrack == .securityServices
        let isTopLeadership = game.currentPositionIndex >= 7
        return isInTrack || isTopLeadership
    }

    private var availableActions: [SecurityAction] {
        SecurityAction.actionsForPosition(game.currentPositionIndex)
    }

    private var lockedActions: [SecurityAction] {
        SecurityAction.allActions.filter { $0.effectiveMinimumPosition > game.currentPositionIndex }
    }

    private var cooldowns: SecurityCooldownTracker {
        actionService.getSecurityCooldowns(for: game)
    }

    private var actionsByCategory: [(category: SecurityActionCategory, actions: [SecurityAction])] {
        var result: [(SecurityActionCategory, [SecurityAction])] = []
        for category in SecurityActionCategory.allCases {
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
            SecurityPositionBanner(game: game)

            // Check track authority before showing actions
            if !hasTrackAuthority {
                NoTrackAuthorityView(
                    bureauName: "State Protection Bureau",
                    requiredTrack: "Security Services",
                    accentColor: theme.sovietRed
                )
            } else if availableActions.isEmpty {
                NoSecurityActionsView(nextUnlock: lockedActions.first)
            } else {
                // Available actions by category
                ForEach(actionsByCategory, id: \.category) { category, actions in
                    SecurityActionCategorySection(
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
                    LockedSecurityActionsPreview(actions: lockedActions, currentPosition: game.currentPositionIndex)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }
}

struct SecurityActionCategorySection: View {
    let category: SecurityActionCategory
    let actions: [SecurityAction]
    let cooldowns: SecurityCooldownTracker
    let currentTurn: Int
    @Bindable var game: Game
    let modelContext: ModelContext
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: category.color))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 0) {
                    Text(category.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    Text(category.ccpEquivalent)
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                }
            }

            // Actions
            ForEach(actions, id: \.id) { action in
                let isOnCooldown = cooldowns.isOnCooldown(actionId: action.id, currentTurn: currentTurn)
                let turnsRemaining = cooldowns.turnsRemaining(actionId: action.id, currentTurn: currentTurn)

                SecurityActionCard(
                    action: action,
                    isOnCooldown: isOnCooldown,
                    cooldownTurns: turnsRemaining,
                    game: game,
                    modelContext: modelContext
                )
            }
        }
    }
}

struct SecurityActionCard: View {
    let action: SecurityAction
    let isOnCooldown: Bool
    let cooldownTurns: Int
    @Bindable var game: Game
    let modelContext: ModelContext
    @Environment(\.theme) var theme
    @State private var showingConfirmation = false
    @State private var showingTargetSheet = false
    @State private var selectedTarget: GameCharacter?
    @State private var lastResult: SecurityActionService.ExecutionResult?

    private let actionService = SecurityActionService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                if !isOnCooldown {
                    if action.targetType == .character {
                        showingTargetSheet = true
                    } else {
                        showingConfirmation = true
                    }
                }
            }) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: action.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(isOnCooldown ? theme.inkLight : theme.sovietRed)
                        .frame(width: 32)

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(action.name)
                                .font(theme.bodyFont)
                                .fontWeight(.semibold)
                                .foregroundColor(isOnCooldown ? theme.inkLight : theme.inkBlack)

                            if action.requiresCommitteeApproval {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                            }
                        }

                        Text(action.description)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Status
                    if isOnCooldown {
                        VStack {
                            Text("\(cooldownTurns)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(theme.inkLight)
                            Text("turns")
                                .font(.system(size: 8))
                                .foregroundColor(theme.inkLight)
                        }
                    } else {
                        VStack {
                            Text("\(action.baseSuccessChance)%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(theme.inkBlack)
                            Text("base")
                                .font(.system(size: 8))
                                .foregroundColor(theme.inkGray)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(isOnCooldown ? theme.inkLight : theme.inkGray)
                }
                .padding(12)
                .background(isOnCooldown ? theme.parchmentDark.opacity(0.5) : theme.parchment)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.borderTan, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isOnCooldown)

            // Inline result display
            if let result = lastResult {
                Text(result.description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(result.succeeded ? .green : .red)
                    .padding(.horizontal, 12)
            }
        }
        .sheet(isPresented: $showingTargetSheet) {
            TargetSelectionSheet(
                action: action,
                game: game,
                onSelect: { target in
                    selectedTarget = target
                    showingTargetSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingConfirmation = true
                    }
                },
                onCancel: {
                    showingTargetSheet = false
                }
            )
        }
        .sheet(isPresented: $showingConfirmation) {
            ActionConfirmationSheet(
                title: action.name,
                description: action.detailedDescription,
                successChance: action.baseSuccessChance,
                riskLevel: action.riskLevel.displayName,
                riskColor: riskColor(action.riskLevel),
                accentColor: theme.sovietRed,
                actionVerb: action.actionVerb,
                onConfirm: {
                    showingConfirmation = false
                    executeAction()
                },
                onCancel: {
                    showingConfirmation = false
                    selectedTarget = nil
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
            targetCharacter: selectedTarget,
            targetFaction: nil,
            for: game,
            modelContext: modelContext
        )
        selectedTarget = nil
    }

    private func riskColor(_ risk: SecurityRiskLevel) -> Color {
        switch risk {
        case .minimal: return .green
        case .low: return .blue
        case .moderate: return .orange
        case .high: return .red
        case .extreme: return .purple
        }
    }
}

struct NoSecurityActionsView: View {
    let nextUnlock: SecurityAction?
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text("No Security Actions Available")
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            if let next = nextUnlock {
                Text("Advance to Position \(next.effectiveMinimumPosition) to unlock \"\(next.name)\"")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.center)
            } else {
                Text("Advance in rank to unlock security actions.")
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

struct LockedSecurityActionsPreview: View {
    let actions: [SecurityAction]
    let currentPosition: Int
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCKED ACTIONS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(actions.prefix(3), id: \.id) { action in
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)

                    Text(action.name)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkLight)

                    Spacer()

                    Text("Position \(action.effectiveMinimumPosition)+")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkLight)
                }
                .padding(8)
                .background(theme.parchmentDark.opacity(0.3))
                .cornerRadius(4)
            }

            if actions.count > 3 {
                Text("+ \(actions.count - 3) more locked actions")
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkLight)
                    .italic()
            }
        }
    }
}

// MARK: - Target Selection Sheet

struct TargetSelectionSheet: View {
    let action: SecurityAction
    let game: Game
    let onSelect: (GameCharacter) -> Void
    let onCancel: () -> Void
    @Environment(\.theme) var theme

    private var eligibleTargets: [GameCharacter] {
        let playerPosition = game.currentPositionIndex
        let maxTargetPosition = action.maxTargetPosition ?? 10

        return game.characters.filter { character in
            character.isAlive &&
            !character.isDetained &&
            (character.positionIndex ?? 0) <= maxTargetPosition &&
            (character.positionIndex ?? 0) <= playerPosition // Can't target superiors
        }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Action info
                VStack(spacing: 8) {
                    Image(systemName: action.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(theme.sovietRed)

                    Text(action.name)
                        .font(theme.headerFont)
                        .foregroundColor(theme.inkBlack)

                    if let maxPos = action.maxTargetPosition {
                        Text("Can target positions up to \(maxPos)")
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(theme.parchmentDark)

                // Targets list
                if eligibleTargets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 32))
                            .foregroundColor(theme.inkLight)

                        Text("No Eligible Targets")
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)

                        Text("No characters meet the requirements for this action.")
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    List(eligibleTargets, id: \.id) { character in
                        Button {
                            onSelect(character)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(character.name)
                                        .font(theme.bodyFont)
                                        .foregroundColor(theme.inkBlack)

                                    Text("Position \(character.positionIndex ?? 0) - \(character.positionTrack ?? "Unknown")")
                                        .font(theme.tagFont)
                                        .foregroundColor(theme.inkGray)
                                }

                                Spacer()

                                if let factionId = character.factionId {
                                    Text(factionId.prefix(8))
                                        .font(.system(size: 9))
                                        .foregroundColor(theme.inkLight)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Security Position Banner

struct SecurityPositionBanner: View {
    let game: Game
    @Environment(\.theme) var theme

    private var isInTrack: Bool {
        let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        return playerTrack == .securityServices
    }

    private var isTopLeadership: Bool {
        game.currentPositionIndex >= 7
    }

    private var hasAuthority: Bool {
        isInTrack || isTopLeadership
    }

    private var positionTitle: String {
        guard hasAuthority else { return "Observer Only" }
        let config = CampaignLoader.shared.getColdWarCampaign()
        return config.ladder.first { $0.index == game.currentPositionIndex }?.title ?? "Unknown"
    }

    private var ccdiEquivalent: String {
        guard hasAuthority else { return "No Security Authority" }
        switch game.currentPositionIndex {
        case 1...2: return "Local Discipline Inspector"
        case 3: return "Case Handler"
        case 4: return "Section Chief"
        case 5: return "Department Director"
        case 6: return "CCDI Standing Committee"
        case 7...8: return "CCDI Secretary"
        default: return "Observer"
        }
    }

    private var headerText: String {
        hasAuthority ? "YOUR SECURITY AUTHORITY" : "ACCESS STATUS"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerText)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Text(positionTitle)
                    .font(theme.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(hasAuthority ? theme.inkBlack : theme.inkLight)

                Text(ccdiEquivalent)
                    .font(.system(size: 10))
                    .foregroundColor(hasAuthority ? theme.sovietRed : theme.inkGray)
            }

            Spacer()

            if hasAuthority {
                Text("Position \(game.currentPositionIndex)")
                    .font(theme.tagFont)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.sovietRed)
                    .cornerRadius(4)
            } else {
                Text("VIEW ONLY")
                    .font(theme.tagFont)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.inkLight)
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasAuthority ? theme.borderTan : theme.inkLight.opacity(0.3), lineWidth: 1)
        )
    }
}
