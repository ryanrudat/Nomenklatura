//
//  SituationMapView.swift
//  Nomenklatura
//
//  Strategic Situation Room - Position-gated world map with military intelligence
//  "The Situation Room" - view the Cold War through classified briefings
//

import SwiftUI
import SwiftData

struct SituationMapView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedCountryId: String?
    @State private var showCountryDetail = false

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    /// Position determines what intelligence you see
    private var intelligenceLevel: IntelligenceLevel {
        let level = accessLevel.effectiveLevel(for: .diplomatic)
        switch level {
        case 0...2: return .publicBroadcast
        case 3...4: return .ministryAssessment
        case 5...6: return .strategicCommand
        default: return .supremeAuthority
        }
    }

    /// Classification label
    private var classificationLabel: String {
        switch intelligenceLevel {
        case .publicBroadcast: return "UNCLASSIFIED"
        case .ministryAssessment: return "RESTRICTED"
        case .strategicCommand: return "SECRET"
        case .supremeAuthority: return "TOP SECRET"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Classification header
            situationHeader

            // Map with overlays
            ZStack {
                // Base map
                SpriteKitMapView(game: game)

                // Position-gated overlays
                VStack {
                    Spacer()

                    // Intelligence briefing bar at bottom
                    intelligenceBriefingBar
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }

                // World tension indicator (top right)
                VStack {
                    HStack {
                        Spacer()
                        worldTensionIndicator
                            .padding(.trailing, 10)
                            .padding(.top, 10)
                    }
                    Spacer()
                }

                // Active crises indicator (top left)
                if intelligenceLevel.rawValue >= IntelligenceLevel.ministryAssessment.rawValue {
                    VStack {
                        HStack {
                            activeCrisesIndicator
                                .padding(.leading, 10)
                                .padding(.top, 10)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $showCountryDetail) {
            if let countryId = selectedCountryId {
                EnhancedCountryDetailSheet(
                    countryId: countryId,
                    game: game,
                    intelligenceLevel: intelligenceLevel
                )
            }
        }
    }

    // MARK: - Situation Header

    private var situationHeader: some View {
        VStack(spacing: 4) {
            HStack {
                // Classification stamp
                Text(classificationLabel)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(classificationColor)
                    .cornerRadius(3)

                Spacer()

                // Report type
                Text(intelligenceLevel.reportTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.inkGray)
            }

            // Title
            Text("STRATEGIC SITUATION")
                .font(.system(size: 13, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkBlack)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(theme.parchmentDark)
    }

    private var classificationColor: Color {
        switch intelligenceLevel {
        case .publicBroadcast: return .gray
        case .ministryAssessment: return .blue
        case .strategicCommand: return .orange
        case .supremeAuthority: return theme.sovietRed
        }
    }

    // MARK: - World Tension Indicator

    private var worldTensionIndicator: some View {
        let tension = calculateWorldTension()

        return VStack(spacing: 4) {
            // DEFCON-style indicator
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { level in
                    Rectangle()
                        .fill(tensionLevelColor(level, current: tension))
                        .frame(width: 8, height: 16)
                }
            }

            Text(tensionLabel(tension))
                .font(.system(size: 8, weight: .bold))
                .tracking(0.5)
                .foregroundColor(tensionColor(tension))

            if intelligenceLevel.rawValue >= IntelligenceLevel.strategicCommand.rawValue {
                Text("\(tension)%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.inkGray)
            }
        }
        .padding(8)
        .background(theme.parchmentDark.opacity(0.95))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tensionColor(tension).opacity(0.5), lineWidth: 1)
        )
    }

    private func calculateWorldTension() -> Int {
        // Calculate based on hostile relationships and active conflicts
        var tension = 30  // Base tension (Cold War)

        // Add tension from hostile countries
        let hostileCount = game.foreignCountries.filter {
            $0.status == .hostile || $0.status == .atWar
        }.count
        tension += hostileCount * 8

        // Add tension from active crises
        let activeCrises = game.recentWorldEvents(turns: 3).filter { $0.severity == .critical || $0.severity == .major }.count
        tension += activeCrises * 5

        // Factor in stability
        if game.stability < 40 {
            tension += 10
        }

        return min(100, max(0, tension))
    }

    private func tensionLevelColor(_ level: Int, current: Int) -> Color {
        let threshold = level * 20
        if current >= threshold {
            switch level {
            case 5: return .red
            case 4: return .orange
            case 3: return theme.accentGold
            case 2: return .yellow
            default: return .green
            }
        }
        return theme.parchmentDark
    }

    private func tensionLabel(_ tension: Int) -> String {
        switch tension {
        case 80...: return "CRITICAL"
        case 60..<80: return "HIGH"
        case 40..<60: return "ELEVATED"
        case 20..<40: return "GUARDED"
        default: return "LOW"
        }
    }

    private func tensionColor(_ tension: Int) -> Color {
        switch tension {
        case 80...: return .red
        case 60..<80: return .orange
        case 40..<60: return theme.accentGold
        default: return .green
        }
    }

    // MARK: - Active Crises Indicator

    private var activeCrisesIndicator: some View {
        let crises = getActiveCrises()

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(crises.isEmpty ? .green : .orange)

                Text(crises.isEmpty ? "NO ACTIVE CRISES" : "ACTIVE SITUATIONS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(crises.isEmpty ? .green : .orange)
            }

            if !crises.isEmpty {
                ForEach(crises.prefix(3), id: \.id) { crisis in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(crisis.severity == .critical ? Color.red : Color.orange)
                            .frame(width: 6, height: 6)

                        Text(crisis.headline)
                            .font(.system(size: 8))
                            .foregroundColor(theme.inkBlack)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(8)
        .background(theme.parchmentDark.opacity(0.95))
        .cornerRadius(6)
    }

    private func getActiveCrises() -> [WorldEvent] {
        game.recentWorldEvents(turns: 2).filter {
            $0.severity == .critical || $0.severity == .major
        }
    }

    // MARK: - Intelligence Briefing Bar

    private var intelligenceBriefingBar: some View {
        VStack(spacing: 6) {
            // Bloc summary
            HStack(spacing: 12) {
                blocIndicator(
                    label: "SOCIALIST",
                    count: game.foreignCountries.filter { $0.politicalBloc == .socialist }.count,
                    color: Color(hex: "CD5C5C")
                )

                blocIndicator(
                    label: "CAPITALIST",
                    count: game.foreignCountries.filter { $0.politicalBloc == .capitalist }.count,
                    color: Color(hex: "4169E1")
                )

                blocIndicator(
                    label: "NON-ALIGNED",
                    count: game.foreignCountries.filter { $0.politicalBloc == .nonAligned }.count,
                    color: Color(hex: "808080")
                )
            }

            // Additional intel for higher positions
            if intelligenceLevel.rawValue >= IntelligenceLevel.strategicCommand.rawValue {
                Divider()
                    .background(theme.borderTan)

                HStack(spacing: 20) {
                    statBadge(label: "TREATIES", value: activeTreatyCount)
                    statBadge(label: "HOSTILE", value: hostileNationCount)
                    statBadge(label: "OUR ASSETS", value: espionageAssets)
                }
            }
        }
        .padding(10)
        .background(theme.parchmentDark.opacity(0.95))
        .cornerRadius(8)
    }

    private func blocIndicator(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(theme.inkBlack)

            Text(label)
                .font(.system(size: 7, weight: .medium))
                .tracking(0.3)
                .foregroundColor(theme.inkGray)
        }
    }

    private func statBadge(label: String, value: Int) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(theme.accentGold)

            Text(label)
                .font(.system(size: 7, weight: .medium))
                .tracking(0.3)
                .foregroundColor(theme.inkGray)
        }
    }

    private var activeTreatyCount: Int {
        game.foreignCountries.reduce(into: 0) { count, country in
            count += country.treaties.count
        }
    }

    private var hostileNationCount: Int {
        game.foreignCountries.filter {
            $0.status == .hostile || $0.status == .atWar
        }.count
    }

    private var espionageAssets: Int {
        // Sum of our intelligence assets in foreign countries
        game.foreignCountries.reduce(into: 0) { sum, country in
            sum += country.ourIntelligenceAssets
        }
    }
}

// MARK: - Intelligence Level

enum IntelligenceLevel: Int {
    case publicBroadcast = 0      // Position 0-2: Radio broadcast summary
    case ministryAssessment = 1   // Position 3-4: Ministry assessment
    case strategicCommand = 2     // Position 5-6: Strategic command briefing
    case supremeAuthority = 3     // Position 7+: Supreme command authority

    var reportTitle: String {
        switch self {
        case .publicBroadcast: return "Radio Broadcast Summary"
        case .ministryAssessment: return "Ministry Assessment"
        case .strategicCommand: return "Strategic Command Briefing"
        case .supremeAuthority: return "Supreme Command Authority"
        }
    }
}

// MARK: - Enhanced Country Detail Sheet

struct EnhancedCountryDetailSheet: View {
    let countryId: String
    @Bindable var game: Game
    let intelligenceLevel: IntelligenceLevel
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme

    private var country: ForeignCountry? {
        game.foreignCountries.first { $0.countryId == countryId }
    }

    private var nationInfo: NationInfo {
        NationInfo.forId(countryId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    countryHeader

                    Divider()
                        .background(theme.borderTan)

                    // Basic relations (always visible)
                    relationshipSection

                    // Treaties (position 3+)
                    if intelligenceLevel.rawValue >= IntelligenceLevel.ministryAssessment.rawValue {
                        if let country = country, !country.treaties.isEmpty {
                            Divider().background(theme.borderTan)
                            treatySection(country: country)
                        }
                    }

                    // Military assessment (position 5+)
                    if intelligenceLevel.rawValue >= IntelligenceLevel.strategicCommand.rawValue {
                        Divider().background(theme.borderTan)
                        militaryAssessment
                    }

                    // Intelligence report (position 5+)
                    if intelligenceLevel.rawValue >= IntelligenceLevel.strategicCommand.rawValue {
                        Divider().background(theme.borderTan)
                        intelligenceSection
                    }

                    // Espionage data (position 7+)
                    if intelligenceLevel.rawValue >= IntelligenceLevel.supremeAuthority.rawValue {
                        if let country = country {
                            Divider().background(theme.borderTan)
                            espionageSection(country: country)
                        }
                    }

                    // Locked sections
                    if intelligenceLevel.rawValue < IntelligenceLevel.strategicCommand.rawValue {
                        Divider().background(theme.borderTan)
                        lockedSection(
                            title: "MILITARY ASSESSMENT",
                            requirement: "Position 5+ required"
                        )
                    }

                    if intelligenceLevel.rawValue < IntelligenceLevel.supremeAuthority.rawValue &&
                       intelligenceLevel.rawValue >= IntelligenceLevel.strategicCommand.rawValue {
                        Divider().background(theme.borderTan)
                        lockedSection(
                            title: "ESPIONAGE OPERATIONS",
                            requirement: "Position 7+ required"
                        )
                    }
                }
                .padding(20)
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.sovietRed)
                }
            }
        }
    }

    // MARK: - Sections

    private var countryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(nationInfo.color)
                    .frame(width: 20, height: 20)

                Text(nationInfo.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.inkBlack)

                Spacer()

                if let country = country {
                    Text(country.politicalBloc.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(blocColor(country.politicalBloc))
                        .cornerRadius(4)
                }
            }

            Text(nationInfo.governmentType)
                .font(theme.bodyFont)
                .foregroundColor(theme.inkGray)
        }
    }

    private var relationshipSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("DIPLOMATIC STATUS")

            if let country = country {
                HStack {
                    Text("Relationship:")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkGray)

                    Spacer()

                    Text(country.status.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(statusColor(country.status))
                }

                if intelligenceLevel.rawValue >= IntelligenceLevel.ministryAssessment.rawValue {
                    HStack {
                        Text("Disposition:")
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkGray)

                        Spacer()

                        Text("\(country.relationshipScore > 0 ? "+" : "")\(country.relationshipScore)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(country.relationshipScore > 0 ? .green : (country.relationshipScore < 0 ? .red : theme.inkGray))
                    }
                }
            } else {
                Text(nationInfo.relationshipDescription)
                    .font(theme.bodyFont)
                    .foregroundColor(theme.inkBlack)
            }
        }
        .padding()
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private func treatySection(country: ForeignCountry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ACTIVE TREATIES")

            ForEach(country.treaties) { treaty in
                HStack {
                    Image(systemName: treatyIcon(treaty.type))
                        .font(.system(size: 12))
                        .foregroundColor(theme.accentGold)

                    Text(treaty.type.displayName)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkBlack)

                    Spacer()

                    if let expiry = treaty.expirationTurn {
                        Text("Exp: T\(expiry)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(theme.inkGray)
                    }
                }
            }
        }
        .padding()
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private func treatyIcon(_ type: TreatyType) -> String {
        switch type {
        case .mutualDefense: return "shield.fill"
        case .tradeAgreement: return "arrow.left.arrow.right"
        case .aidPackage: return "gift.fill"
        case .nonAggression: return "hand.raised.fill"
        case .culturalExchange: return "person.2.fill"
        case .nuclearSharing: return "atom"
        case .espionageAgreement: return "eye.fill"
        }
    }

    private var militaryAssessment: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("MILITARY ASSESSMENT")

            if let country = country {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Military Strength")
                            .font(.system(size: 10))
                            .foregroundColor(theme.inkGray)
                        Text("\(country.militaryStrength)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(militaryColor(country.militaryStrength))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Nuclear Status")
                            .font(.system(size: 10))
                            .foregroundColor(theme.inkGray)
                        HStack {
                            Image(systemName: country.hasNuclearWeapons ? "atom" : "xmark")
                                .foregroundColor(country.hasNuclearWeapons ? .red : theme.inkGray)
                            Text(country.hasNuclearWeapons ? "ARMED" : "NONE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(country.hasNuclearWeapons ? .red : theme.inkGray)
                        }
                    }
                }

                // Threat assessment
                HStack {
                    Text("Threat Level:")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkGray)

                    Spacer()

                    let threat = calculateThreat(country)
                    Text(threatLabel(threat))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(threatColor(threat))
                }
            }
        }
        .padding()
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("INTELLIGENCE BRIEF")
                Spacer()
                Text("SECRET")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(3)
            }

            Text(nationInfo.intelligenceBrief)
                .font(theme.bodyFont)
                .foregroundColor(theme.inkBlack)
                .lineSpacing(2)
        }
        .padding()
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func espionageSection(country: ForeignCountry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("ESPIONAGE OPERATIONS")
                Spacer()
                Text("TOP SECRET")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.sovietRed)
                    .cornerRadius(3)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Our Assets")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkGray)
                    Text("\(country.ourIntelligenceAssets)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.accentGold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Their Activity")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkGray)
                    Text("\(country.espionageActivity)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(country.espionageActivity > 50 ? .red : theme.inkGray)
                }
            }

            if country.espionageActivity > 60 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("HIGH HOSTILE ESPIONAGE ACTIVITY DETECTED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.sovietRed.opacity(0.3), lineWidth: 1)
        )
    }

    private func lockedSection(title: String, requirement: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20))
                .foregroundColor(theme.inkLight)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            Text(requirement)
                .font(.system(size: 10))
                .foregroundColor(theme.inkLight)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1)
            .foregroundColor(theme.inkGray)
    }

    private func blocColor(_ bloc: PoliticalBloc) -> Color {
        switch bloc {
        case .socialist: return Color(hex: "CD5C5C")
        case .capitalist: return Color(hex: "4169E1")
        case .nonAligned: return Color(hex: "808080")
        case .rival: return Color(hex: "FF8C00")
        }
    }

    private func statusColor(_ status: DiplomaticStatus) -> Color {
        switch status {
        case .allied: return .green
        case .friendly: return Color(hex: "90EE90")
        case .neutral: return theme.inkGray
        case .strained: return .orange
        case .hostile: return .red
        case .atWar: return Color(hex: "8B0000")
        case .noRelations: return theme.inkLight
        }
    }

    private func militaryColor(_ strength: Int) -> Color {
        switch strength {
        case 80...: return .red
        case 60..<80: return .orange
        case 40..<60: return theme.accentGold
        default: return .green
        }
    }

    private func calculateThreat(_ country: ForeignCountry) -> Int {
        var threat = 0

        // Base on relationship
        if country.relationshipScore < -30 { threat += 30 }
        else if country.relationshipScore < 0 { threat += 15 }

        // Military strength factor
        threat += country.militaryStrength / 3

        // Nuclear weapons
        if country.hasNuclearWeapons { threat += 20 }

        // Espionage activity
        threat += country.espionageActivity / 5

        return min(100, threat)
    }

    private func threatLabel(_ threat: Int) -> String {
        switch threat {
        case 70...: return "SEVERE"
        case 50..<70: return "HIGH"
        case 30..<50: return "MODERATE"
        default: return "LOW"
        }
    }

    private func threatColor(_ threat: Int) -> Color {
        switch threat {
        case 70...: return .red
        case 50..<70: return .orange
        case 30..<50: return theme.accentGold
        default: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "cold_war")

    SituationMapView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
