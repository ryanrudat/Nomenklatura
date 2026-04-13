//
//  PersonalSecurityView.swift
//  Nomenklatura
//
//  Personal security dossier - YOUR security status, not system-wide surveillance
//  Shows clearance level, investigation status, network security, and threat assessment
//  Preserves the paranoia of not knowing who else is being watched
//

import SwiftUI
import SwiftData

// MARK: - Personal Security View

struct PersonalSecurityView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var riskLevel: PersonalRiskLevel {
        calculateRiskLevel()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Dossier header
            dossierHeader

            // Your clearance level
            clearanceLevelSection

            // Investigation status
            investigationStatusSection

            // Personal vulnerability indicators
            vulnerabilitySection

            // Threat assessment — always shown for General Secretary
            threatAssessmentSection

            // Network security — always shown for General Secretary
            networkSecuritySection
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }

    // MARK: - Dossier Header

    private var dossierHeader: some View {
        VStack(spacing: 8) {
            // Folder aesthetic with stamped classification
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PERSONAL DOSSIER")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(2)
                        .foregroundColor(theme.inkBlack)

                    Text("State Protection Bureau File")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                // Classification stamp
                PersonalClassificationStamp(riskLevel: riskLevel)
            }

            Divider()
                .background(theme.borderTan)

            // Subject identification
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SUBJECT:")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkGray)

                    Text(subjectName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.inkBlack)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("POSITION:")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkGray)

                    Text("Level \(game.currentPositionIndex)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.inkBlack)
                }
            }
        }
        .padding(16)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 2)
        )
    }

    // MARK: - Clearance Level Section

    private var clearanceLevelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "YOUR CLEARANCE LEVEL", icon: "key.fill")

            HStack(spacing: 12) {
                // Current clearance badge
                VStack(spacing: 6) {
                    Text(currentClearance.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(currentClearance.color)
                        .cornerRadius(6)

                    Text("Current Access")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                // Access breakdown
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(accessibleBureaus, id: \.self) { bureau in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text(bureau)
                                .font(.system(size: 10))
                                .foregroundColor(theme.inkBlack)
                        }
                    }
                }
            }
            .padding(12)
            .background(theme.parchment)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
    }

    // MARK: - Investigation Status Section

    private var investigationStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "INVESTIGATION STATUS", icon: "magnifyingglass")

            VStack(spacing: 12) {
                // Are you under investigation?
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Status")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(theme.inkGray)

                        Text(investigationStatus.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(investigationStatus.color)
                    }

                    Spacer()

                    // Status indicator
                    Circle()
                        .fill(investigationStatus.color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: investigationStatus.color.opacity(0.5), radius: 4)
                }

                Divider()

                // Suspicion indicators — always shown for General Secretary
                VStack(alignment: .leading, spacing: 8) {
                    Text("KNOWN INDICATORS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkGray)

                    SuspicionIndicator(
                        label: "Evidence File",
                        value: game.corruptionEvidence,
                        description: evidenceDescription
                    )

                    SuspicionIndicator(
                        label: "Visibility Level",
                        value: game.wealthVisibility,
                        description: visibilityDescription
                    )
                }
            }
            .padding(12)
            .background(theme.parchment)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(investigationStatus.color.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Vulnerability Section

    private var vulnerabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "VULNERABILITY ASSESSMENT", icon: "shield.lefthalf.filled")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VulnerabilityCard(
                    title: "Corruption Exposure",
                    value: game.corruptionEvidence,
                    icon: "doc.text.magnifyingglass",
                    risk: riskFromValue(game.corruptionEvidence)
                )

                VulnerabilityCard(
                    title: "Wealth Visibility",
                    value: game.wealthVisibility,
                    icon: "banknote",
                    risk: riskFromValue(game.wealthVisibility)
                )

                VulnerabilityCard(
                    title: "Rival Hostility",
                    value: game.rivalThreat,
                    icon: "person.fill.xmark",
                    risk: riskFromValue(game.rivalThreat)
                )

                VulnerabilityCard(
                    title: "Overall Risk",
                    value: riskLevel.score,
                    icon: "exclamationmark.triangle.fill",
                    risk: riskLevel
                )
            }
        }
    }

    // MARK: - Threat Assessment Section (Position 3+)

    private var threatAssessmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "THREAT ASSESSMENT", icon: "exclamationmark.shield.fill")

            VStack(alignment: .leading, spacing: 12) {
                Text("CLASSIFIED - INTERNAL ASSESSMENT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.sovietRed)

                // Active rival threat
                if let rival = game.primaryRival {
                    ThreatCard(
                        sourceName: rival.name,
                        sourcePosition: "Position \(rival.positionIndex ?? 0)",
                        threatLevel: rivalThreatLevel,
                        description: "Actively working against your interests",
                        icon: "person.fill.xmark"
                    )
                }

                // Faction threats (if any hostile factions)
                let hostileFactions = getHostileFactions()
                if !hostileFactions.isEmpty {
                    ForEach(hostileFactions.prefix(2), id: \.0) { faction, hostility in
                        ThreatCard(
                            sourceName: faction,
                            sourcePosition: "Faction",
                            threatLevel: hostility > 60 ? .high : .moderate,
                            description: "Opposes your political line",
                            icon: "person.3.fill"
                        )
                    }
                }

                if game.primaryRival == nil && hostileFactions.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(.green)
                        Text("No active threats identified")
                            .font(.system(size: 12))
                            .foregroundColor(theme.inkBlack)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(12)
            .background(theme.parchmentDark.opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.sovietRed.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Network Security Section (Position 5+)

    private var networkSecuritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "NETWORK SECURITY", icon: "network")

            VStack(alignment: .leading, spacing: 12) {
                Text("SECRET - COUNTER-INTELLIGENCE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.purple)

                // Patron status
                if let patron = game.patron {
                    NetworkContactCard(
                        name: patron.name,
                        role: "Patron",
                        position: "Position \(patron.positionIndex ?? 0)",
                        status: patronSecurityStatus(patron),
                        icon: "person.badge.shield.checkmark"
                    )
                }

                // Contacts in network
                let allies = game.characters.filter { $0.disposition > 60 && $0.isAlive }
                if !allies.isEmpty {
                    Text("ALLIED CONTACTS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkGray)
                        .padding(.top, 4)

                    ForEach(allies.prefix(3)) { ally in
                        NetworkContactCard(
                            name: ally.name,
                            role: "Ally",
                            position: "Position \(ally.positionIndex ?? 0)",
                            status: allySecurityStatus(ally),
                            icon: "person.fill.checkmark"
                        )
                    }
                }

                // Warning if any contacts compromised
                let compromisedCount = allies.filter { isContactCompromised($0) }.count
                if compromisedCount > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(compromisedCount) contact(s) may be compromised")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(12)
            .background(theme.parchmentDark.opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Computed Properties

    private var subjectName: String {
        let config = CampaignLoader.shared.getColdWarCampaign()
        let positionTitle = config.ladder.first(where: { $0.index == game.currentPositionIndex })?.title ?? "Official"
        return "Comrade \(positionTitle)"
    }

    private var currentClearance: (name: String, color: Color) {
        switch game.currentPositionIndex {
        case 0...1: return ("RESTRICTED", .gray)
        case 2...3: return ("CONFIDENTIAL", .blue)
        case 4...5: return ("SECRET", .orange)
        case 6...7: return ("TOP SECRET", .red)
        default: return ("COSMIC", .purple)
        }
    }

    private var accessibleBureaus: [String] {
        // General Secretary has access to all bureaus
        return ["Personnel Files", "Public Reports", "Economic Data", "Security Intel", "Foreign Intel", "Politburo Files"]
    }

    private var investigationStatus: (label: String, color: Color) {
        if game.corruptionEvidence >= 70 {
            return ("UNDER REVIEW", .red)
        } else if game.corruptionEvidence >= 50 {
            return ("FLAGGED", .orange)
        } else if game.corruptionEvidence >= 30 {
            return ("MONITORED", .yellow)
        } else {
            return ("CLEARED", .green)
        }
    }

    private var evidenceDescription: String {
        switch game.corruptionEvidence {
        case 0...20: return "No documented concerns"
        case 21...40: return "Minor irregularities noted"
        case 41...60: return "Significant items in file"
        case 61...80: return "Active investigation likely"
        default: return "Substantial case file exists"
        }
    }

    private var visibilityDescription: String {
        switch game.wealthVisibility {
        case 0...20: return "Living modestly"
        case 21...40: return "Comfortable but discrete"
        case 41...60: return "Lifestyle attracting notice"
        case 61...80: return "Conspicuous consumption"
        default: return "Openly flaunting wealth"
        }
    }

    private var rivalThreatLevel: PersonalRiskLevel {
        riskFromValue(game.rivalThreat)
    }

    private func calculateRiskLevel() -> PersonalRiskLevel {
        let score = (game.corruptionEvidence + game.wealthVisibility + game.rivalThreat) / 3
        return riskFromValue(score)
    }

    private func riskFromValue(_ value: Int) -> PersonalRiskLevel {
        switch value {
        case 0...20: return .minimal
        case 21...40: return .low
        case 41...60: return .moderate
        case 61...80: return .high
        default: return .severe
        }
    }

    private func getHostileFactions() -> [(String, Int)] {
        // Find hostile NPCs and group by faction
        var hostileFactions: [(String, Int)] = []

        // Check characters with negative disposition who are rivals or actively opposing
        let hostileCharacters = game.characters.filter {
            $0.isAlive && $0.disposition < 30 && ($0.isRival || $0.disposition < 20)
        }

        // Group by faction and report hostility
        var factionHostility: [String: Int] = [:]
        for character in hostileCharacters {
            let factionId = character.factionId ?? "Unknown"
            let currentHostility = factionHostility[factionId] ?? 0
            factionHostility[factionId] = currentHostility + (50 - character.disposition)
        }

        for (faction, hostility) in factionHostility where hostility > 30 {
            hostileFactions.append((faction, min(100, hostility)))
        }

        return hostileFactions.sorted { $0.1 > $1.1 }
    }

    private func patronSecurityStatus(_ patron: GameCharacter) -> ContactSecurityStatus {
        if patron.isDetained || patron.status == CharacterStatus.executed.rawValue ||
           patron.status == CharacterStatus.imprisoned.rawValue {
            return .compromised
        }
        if patron.disposition < 30 {
            return .unreliable
        }
        return .secure
    }

    private func allySecurityStatus(_ ally: GameCharacter) -> ContactSecurityStatus {
        if ally.isDetained {
            return .compromised
        }
        if ally.isUnderInvestigation {
            return .atRisk
        }
        return .secure
    }

    private func isContactCompromised(_ character: GameCharacter) -> Bool {
        character.isDetained || character.isUnderInvestigation
    }
}

// MARK: - Supporting Types

enum PersonalRiskLevel: Int {
    case minimal = 0
    case low = 1
    case moderate = 2
    case high = 3
    case severe = 4

    var score: Int {
        rawValue * 25
    }

    var label: String {
        switch self {
        case .minimal: return "MINIMAL"
        case .low: return "LOW"
        case .moderate: return "MODERATE"
        case .high: return "HIGH"
        case .severe: return "SEVERE"
        }
    }

    var color: Color {
        switch self {
        case .minimal: return .green
        case .low: return .blue
        case .moderate: return .yellow
        case .high: return .orange
        case .severe: return .red
        }
    }
}

enum ContactSecurityStatus {
    case secure
    case atRisk
    case unreliable
    case compromised

    var label: String {
        switch self {
        case .secure: return "Secure"
        case .atRisk: return "At Risk"
        case .unreliable: return "Unreliable"
        case .compromised: return "Compromised"
        }
    }

    var color: Color {
        switch self {
        case .secure: return .green
        case .atRisk: return .yellow
        case .unreliable: return .orange
        case .compromised: return .red
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(theme.sovietRed)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkBlack)
        }
    }
}

// MARK: - Classification Stamp

struct PersonalClassificationStamp: View {
    let riskLevel: PersonalRiskLevel
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(stampLabel)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(stampColor)

            Text("BPS FILE")
                .font(.system(size: 7, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
        .padding(8)
        .background(theme.parchment)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(stampColor, lineWidth: 2)
        )
        .rotationEffect(.degrees(-5))
    }

    private var stampLabel: String {
        switch riskLevel {
        case .minimal, .low: return "CLEARED"
        case .moderate: return "REVIEWED"
        case .high: return "FLAGGED"
        case .severe: return "PRIORITY"
        }
    }

    private var stampColor: Color {
        switch riskLevel {
        case .minimal, .low: return .green
        case .moderate: return .orange
        case .high, .severe: return .red
        }
    }
}

// MARK: - Suspicion Indicator

struct SuspicionIndicator: View {
    let label: String
    let value: Int
    let description: String
    @Environment(\.theme) var theme

    private var indicatorColor: Color {
        switch value {
        case 0...30: return .green
        case 31...50: return .yellow
        case 51...70: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.inkBlack)

                Text(description)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkGray)
            }

            Spacer()

            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.parchmentDark)
                    .frame(width: 60, height: 8)

                RoundedRectangle(cornerRadius: 2)
                    .fill(indicatorColor)
                    .frame(width: 60 * CGFloat(value) / 100, height: 8)
            }

            Text("\(value)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Vulnerability Card

struct VulnerabilityCard: View {
    let title: String
    let value: Int
    let icon: String
    let risk: PersonalRiskLevel
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(risk.color)

                Spacer()

                Text(risk.label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(risk.color)
                    .cornerRadius(3)
            }

            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(risk.color)

            Text(title)
                .font(.system(size: 9))
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(12)
        .background(theme.parchment)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(risk.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Threat Card

struct ThreatCard: View {
    let sourceName: String
    let sourcePosition: String
    let threatLevel: PersonalRiskLevel
    let description: String
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(threatLevel.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(sourceName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.inkBlack)

                Text(sourcePosition)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkGray)

                Text(description)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkGray)
                    .italic()
            }

            Spacer()

            VStack {
                Text(threatLevel.label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(threatLevel.color)
                    .cornerRadius(3)
            }
        }
        .padding(10)
        .background(theme.parchment)
        .cornerRadius(6)
    }
}

// MARK: - Network Contact Card

struct NetworkContactCard: View {
    let name: String
    let role: String
    let position: String
    let status: ContactSecurityStatus
    let icon: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(status.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.inkBlack)

                    Text("(\(role))")
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkGray)
                }

                Text(position)
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkGray)
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)

                Text(status.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(status.color)
            }
        }
        .padding(8)
        .background(theme.parchment.opacity(0.5))
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "cold_war")
    game.corruptionEvidence = 35
    game.wealthVisibility = 45
    game.rivalThreat = 60

    return ScrollView {
        PersonalSecurityView(game: game)
    }
    .background(ColdWarTheme().parchment)
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
