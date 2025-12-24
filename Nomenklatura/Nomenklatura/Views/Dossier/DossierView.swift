//
//  DossierView.swift
//  Nomenklatura
//
//  The Dossier - Intelligence files on characters and factions
//

import SwiftUI
import SwiftData

// MARK: - Character Filter (Living Character System)

enum CharacterFilter: String, CaseIterable {
    case all = "ALL"
    case keyFigures = "KEY"
    case allies = "ALLIES"
    case others = "OTHERS"
}

struct DossierView: View {
    @Bindable var game: Game
    var onWorldTap: (() -> Void)? = nil
    var onCongressTap: (() -> Void)? = nil
    @State private var selectedTab: DossierTab = .profile
    @State private var characterFilter: CharacterFilter = .all
    @Environment(\.theme) var theme

    // MARK: - Memoized Character Filters (Performance Optimization)
    // Compute all filter results once and cache them

    private var activeCharacters: [GameCharacter] {
        game.characters.filter { $0.isAlive }
    }

    private var fallenCharacters: [GameCharacter] {
        game.characters.filter { !$0.isAlive }
    }

    private var filteredCharacters: [GameCharacter] {
        let active = activeCharacters
        switch characterFilter {
        case .all:
            return active
        case .keyFigures:
            return active.filter { $0.isPatron || $0.isRival || $0.disposition >= 70 || $0.disposition <= 30 }
        case .allies:
            return active.filter { $0.disposition >= 60 && !$0.isRival }
        case .others:
            return active.filter { !$0.isPatron && !$0.isRival && $0.disposition > 30 && $0.disposition < 60 }
        }
    }

    var body: some View {
        ZStack {
            // Background
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with optional world and congress buttons
                ScreenHeader(
                    title: "The Dossier",
                    subtitle: "Intelligence Files",
                    showWorldButton: onWorldTap != nil,
                    onWorldTap: onWorldTap,
                    showCongressButton: onCongressTap != nil,
                    onCongressTap: onCongressTap
                )

                // Tab selector
                DossierTabBar(selectedTab: $selectedTab)

                // Content
                ScrollView {
                    VStack(spacing: 10) {
                        switch selectedTab {
                        case .profile:
                            profileContent
                        case .figures:
                            figuresContent
                        case .factions:
                            factionsContent
                        case .journal:
                            journalContent
                        }
                    }
                    .padding(15)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 100)
                }
            }
        }
    }

    // MARK: - Profile Content (Your Background)

    @ViewBuilder
    private var profileContent: some View {
        // Player stats summary
        PlayerStatsCard(game: game)

        // Personal wealth card (if any wealth or it becomes relevant)
        if game.personalWealth > 0 || game.wealthVisibility > 0 || game.corruptionEvidence > 0 {
            PersonalWealthCard(game: game)
        }

        // Player faction background
        if let faction = game.playerFaction {
            PlayerFactionDisplayCard(faction: faction)
        }

        // Reputation section
        ReputationCard(game: game)
    }

    @ViewBuilder
    private var figuresContent: some View {
        // Use memoized filter properties for performance
        let active = activeCharacters
        let fallen = fallenCharacters
        let filtered = filteredCharacters

        if !active.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Header with filter bar (Living Character System)
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(theme.accentGold)
                    Text("ACTIVE FIGURES")
                        .font(theme.tagFont)
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    Spacer()

                    Text("\(filtered.count)")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkLight)
                }
                .padding(.bottom, 4)

                // Filter bar (Living Character System)
                HStack(spacing: 6) {
                    ForEach(CharacterFilter.allCases, id: \.self) { filter in
                        Button {
                            characterFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.5)
                                .foregroundColor(characterFilter == filter ? theme.inkBlack : theme.inkGray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(characterFilter == filter ? theme.accentGold.opacity(0.3) : Color.clear)
                                .overlay(
                                    Rectangle()
                                        .stroke(characterFilter == filter ? theme.accentGold : theme.borderTan, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)

                if filtered.isEmpty {
                    Text("No figures match this filter")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkLight)
                        .italic()
                        .padding(.vertical, 20)
                } else {
                    ForEach(filtered) { character in
                        CharacterCardView(character: character, game: game)
                    }
                }
            }
        }

        // Fallen figures (if any)
        if !fallen.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.fill.xmark")
                        .foregroundColor(theme.stampRed)
                    Text("FALLEN COMRADES")
                        .font(theme.tagFont)
                        .tracking(1)
                        .foregroundColor(theme.stampRed)
                }
                .padding(.top, 16)
                .padding(.bottom, 4)

                FallenCharactersView(characters: fallen, game: game)
            }
        }

        if active.isEmpty && fallen.isEmpty {
            EmptyStateView(message: "No intelligence available")
        }
    }

    @ViewBuilder
    private var factionsContent: some View {
        ForEach(game.factions) { faction in
            FactionCardView(faction: faction)
        }

        if game.factions.isEmpty {
            EmptyStateView(message: "No factions established")
        }
    }

    @ViewBuilder
    private var journalContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Saved Notes section (from JournalEntries)
            SavedNotesView(game: game)

            // Divider between sections
            if !game.journalEntries.isEmpty && !game.events.filter({ $0.currentEventType == .decision }).isEmpty {
                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 2)
                    .padding(.vertical, 8)
            }

            // Decision Journal section (from GameEvents)
            DecisionJournalView(game: game)
        }
    }
}

// MARK: - Saved Notes View (JournalEntries)

struct SavedNotesView: View {
    let game: Game
    @Environment(\.theme) var theme

    private var sortedEntries: [JournalEntry] {
        game.journalEntries.sorted { $0.turnDiscovered > $1.turnDiscovered }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundColor(theme.accentGold)
                    Text("SAVED NOTES")
                        .font(theme.labelFont)
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    Spacer()

                    // Unread count badge
                    if game.unreadJournalCount > 0 {
                        Text("\(game.unreadJournalCount) NEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.stampRed)
                            .clipShape(Capsule())
                    }
                }

                Text("Information you've noted for later reference")
                    .font(theme.tagFont)
                    .italic()
                    .foregroundColor(theme.inkGray)
            }
            .padding(.bottom, 8)

            if sortedEntries.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(theme.inkLight)

                    Text("No notes saved yet")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkGray)

                    Text("When you see important information in briefings, tap \"Note this\" or \"File this away\" to save it here.")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkLight)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Notes list
                ForEach(sortedEntries) { entry in
                    SavedNoteCard(entry: entry, game: game)
                }
            }
        }
    }
}

// MARK: - Saved Note Card

struct SavedNoteCard: View {
    let entry: JournalEntry
    let game: Game
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(alignment: .top) {
                // Category icon
                Image(systemName: entry.category.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(theme.accentGold)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text(entry.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.inkBlack)

                    // Category and turn
                    HStack(spacing: 8) {
                        Text(entry.category.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(theme.inkGray)

                        Text("•")
                            .foregroundColor(theme.inkLight)

                        Text("Turn \(entry.turnDiscovered)")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkLight)
                    }
                }

                Spacer()

                // Unread indicator
                if !entry.isRead {
                    Circle()
                        .fill(theme.stampRed)
                        .frame(width: 8, height: 8)
                }

                // Expand button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                        if isExpanded && !entry.isRead {
                            game.markJournalEntryRead(id: entry.id)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.inkGray)
                }
            }

            // Expanded content
            if isExpanded {
                Text(entry.content)
                    .font(theme.bodyFont)
                    .foregroundColor(theme.inkBlack)
                    .padding(.leading, 24)
                    .padding(.top, 4)

                // Related character link if present
                if let characterId = entry.relatedCharacterId,
                   let character = game.characters.first(where: { $0.templateId == characterId }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text("Related: \(character.name)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(theme.accentGold)
                    .padding(.leading, 24)
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(entry.isRead ? Color.clear : theme.parchment.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(entry.isRead ? theme.borderTan : theme.accentGold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Decision Journal View

struct DecisionJournalView: View {
    let game: Game
    @Environment(\.theme) var theme

    /// Filter to only decision events (not narrative, newspaper, etc.)
    private var decisionEvents: [GameEvent] {
        game.events
            .filter { $0.currentEventType == .decision }
            .sorted { $0.turnNumber > $1.turnNumber }  // Most recent first
    }

    /// Group decisions by phase of career
    private var careerPhases: [(String, [GameEvent])] {
        let early = decisionEvents.filter { $0.turnNumber <= 5 }
        let middle = decisionEvents.filter { $0.turnNumber > 5 && $0.turnNumber <= 15 }
        let late = decisionEvents.filter { $0.turnNumber > 15 }

        var phases: [(String, [GameEvent])] = []
        if !late.isEmpty { phases.append(("RECENT DECISIONS", late)) }
        if !middle.isEmpty { phases.append(("EARLIER DECISIONS", middle)) }
        if !early.isEmpty { phases.append(("FIRST DAYS", early)) }
        return phases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(theme.accentGold)
                    Text("YOUR RECORD")
                        .font(theme.labelFont)
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)
                }

                Text("A chronicle of your decisions and their consequences")
                    .font(theme.tagFont)
                    .italic()
                    .foregroundColor(theme.inkGray)
            }
            .padding(.bottom, 8)

            if decisionEvents.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(theme.inkLight)

                    Text("No decisions recorded yet")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkGray)

                    Text("Your choices will be recorded here as you navigate the corridors of power.")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkLight)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Decision timeline
                ForEach(careerPhases, id: \.0) { phase, events in
                    VStack(alignment: .leading, spacing: 8) {
                        // Phase header
                        Text(phase)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(theme.inkLight)
                            .padding(.top, 8)

                        // Decision cards
                        ForEach(events) { event in
                            DecisionJournalCard(event: event, game: game)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Decision Journal Card

struct DecisionJournalCard: View {
    let event: GameEvent
    let game: Game
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    /// Find any consequence events linked to this decision
    private var consequenceEvents: [GameEvent] {
        game.events.filter { consequenceEvent in
            consequenceEvent.sourceDecisionId == event.id.uuidString
        }
    }

    /// Get archetype color
    private var archetypeColor: Color {
        guard let archetype = event.optionArchetype else { return theme.inkGray }
        switch archetype.lowercased() {
        case "hardline", "ruthless": return theme.stampRed
        case "reformist", "progressive": return Color(hex: "4CAF50")
        case "pragmatic", "moderate": return theme.accentGold
        case "corrupt", "opportunist": return Color(hex: "9C27B0")
        case "loyal", "orthodox": return Color(hex: "2196F3")
        default: return theme.inkGray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main decision card
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    // Turn number badge
                    VStack(spacing: 2) {
                        Text("T\(event.turnNumber)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.inkBlack)
                    }
                    .frame(width: 36)
                    .padding(.vertical, 8)
                    .background(theme.parchment)
                    .overlay(
                        Rectangle()
                            .stroke(theme.borderTan, lineWidth: 1)
                    )

                    // Decision content
                    VStack(alignment: .leading, spacing: 6) {
                        // What was decided
                        Text(event.optionChosen ?? event.summary)
                            .font(theme.bodyFontSmall)
                            .fontWeight(.medium)
                            .foregroundColor(theme.inkBlack)
                            .multilineTextAlignment(.leading)

                        // Archetype tag if available
                        if let archetype = event.optionArchetype {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(archetypeColor)
                                    .frame(width: 6, height: 6)
                                Text(archetype.uppercased())
                                    .font(.system(size: 9, weight: .semibold))
                                    .tracking(0.5)
                                    .foregroundColor(archetypeColor)
                            }
                        }

                        // Context if available
                        if let context = event.decisionContext, isExpanded {
                            Text(context)
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)
                                .italic()
                                .padding(.top, 4)
                        }
                    }

                    Spacer()

                    // Expansion indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)
                .background(theme.parchmentDark)
            }
            .buttonStyle(.plain)

            // Consequence events (if any and expanded)
            if isExpanded && !consequenceEvents.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(consequenceEvents) { consequence in
                        HStack(alignment: .top, spacing: 12) {
                            // Connection line
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(theme.borderTan)
                                    .frame(width: 1)
                                    .frame(height: 20)
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.inkLight)
                            }
                            .frame(width: 36)

                            // Consequence content
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("T\(consequence.turnNumber)")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(theme.inkGray)
                                    Text(consequence.consequenceNote ?? "Consequence")
                                        .font(theme.tagFont)
                                        .foregroundColor(theme.inkGray)
                                }

                                Text(consequence.summary)
                                    .font(theme.tagFont)
                                    .foregroundColor(theme.inkBlack)
                            }
                            .padding(.vertical, 8)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .background(theme.parchment.opacity(0.5))
                    }
                }
            }
        }
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Player Stats Card

struct PlayerStatsCard: View {
    let game: Game
    @Environment(\.theme) var theme

    private var campaignConfig: CampaignConfig {
        CampaignLoader.shared.getColdWarCampaign()
    }

    private var currentPosition: String {
        campaignConfig.ladder[safe: game.currentPositionIndex]?.title ?? "Official"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with portrait
            HStack(spacing: 16) {
                // Player silhouette portrait
                PlayerSilhouette(size: 70, showFrame: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR STATUS")
                        .font(theme.tagFont)
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    Text(currentPosition.uppercased())
                        .font(theme.headerFont)
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    Text("Turn \(game.turnNumber)")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkLight)
                }

                Spacer()
            }

            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            // Personal stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                PersonalStatRow(label: "Standing", value: game.standing, icon: "star.fill")
                PersonalStatRow(label: "Network", value: game.network, icon: "person.3.fill")
                PersonalStatRow(label: "Patron Favor", value: game.patronFavor, icon: "hand.thumbsup.fill")
                PersonalStatRow(label: "Rival Threat", value: game.rivalThreat, icon: "exclamationmark.triangle.fill", isNegative: true)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct PersonalStatRow: View {
    let label: String
    let value: Int
    let icon: String
    var isNegative: Bool = false
    @Environment(\.theme) var theme

    private var statColor: Color {
        if isNegative {
            // For negative stats like rival threat, higher is worse
            return value >= 70 ? .statLow : (value >= 40 ? .statMedium : .statHigh)
        } else {
            return value >= 70 ? .statHigh : (value >= 40 ? .statMedium : .statLow)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(statColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkGray)
                Text("\(value)")
                    .font(theme.statFont)
                    .fontWeight(.bold)
                    .foregroundColor(statColor)
            }
            Spacer()
        }
        .padding(8)
        .background(statColor.opacity(0.1))
    }
}

// MARK: - Player Faction Display Card

struct PlayerFactionDisplayCard: View {
    let faction: PlayerFactionConfig
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(theme.stampRed)
                Text("YOUR BACKGROUND")
                    .font(theme.labelFont)
                    .tracking(1)
                    .foregroundColor(theme.inkBlack)
            }

            // Faction name and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(faction.name.uppercased())
                    .font(theme.headerFont)
                    .tracking(2)
                    .foregroundColor(theme.inkBlack)

                Text(faction.subtitle)
                    .font(theme.tagFont)
                    .italic()
                    .foregroundColor(theme.accentGold)
            }

            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            // Description
            Text(faction.description)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
                .lineSpacing(3)

            // Special ability if present
            if let ability = faction.specialAbility {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.accentGold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ability.name)
                            .font(theme.tagFont)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.inkBlack)
                        Text(ability.description)
                            .font(.system(size: 11))
                            .foregroundColor(theme.inkGray)
                    }
                }
                .padding(8)
                .background(theme.accentGold.opacity(0.1))
            }

            // Vulnerability if present
            if let vulnerability = faction.vulnerability {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "FF9800"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vulnerability.name)
                            .font(theme.tagFont)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.inkBlack)
                        Text(vulnerability.description)
                            .font(.system(size: 11))
                            .foregroundColor(theme.inkGray)
                    }
                }
                .padding(8)
                .background(Color(hex: "FF9800").opacity(0.1))
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Reputation Card

struct ReputationCard: View {
    let game: Game
    @Environment(\.theme) var theme

    /// Generate overall reputation description based on traits
    private var overallReputation: String {
        // Find dominant traits (above 60)
        var dominant: [String] = []
        if game.reputationCompetent >= 60 { dominant.append("competent") }
        if game.reputationLoyal >= 60 { dominant.append("loyal") }
        if game.reputationCunning >= 60 { dominant.append("cunning") }
        if game.reputationRuthless >= 60 { dominant.append("ruthless") }

        // Find weak traits (below 30)
        var weak: [String] = []
        if game.reputationCompetent < 30 { weak.append("incompetent") }
        if game.reputationLoyal < 30 { weak.append("disloyal") }
        if game.reputationCunning < 30 { weak.append("naive") }

        // Generate description
        if dominant.isEmpty && weak.isEmpty {
            return "You remain an enigma to most colleagues. Your true nature is yet to be revealed."
        } else if dominant.count >= 3 {
            return "You are considered a formidable figure—\(dominant.prefix(2).joined(separator: " and ")). Few dare cross you."
        } else if dominant.contains("ruthless") && game.reputationRuthless >= 75 {
            return "Whispers follow you in the corridors. Your reputation for ruthlessness precedes you."
        } else if dominant.contains("loyal") && dominant.contains("competent") {
            return "You are seen as an ideal Party member—competent and loyal. Advancement awaits."
        } else if dominant.contains("cunning") && !dominant.contains("loyal") {
            return "Colleagues watch their words around you. Your political instincts are well-known."
        } else if !weak.isEmpty && dominant.isEmpty {
            let weakStr = weak.prefix(2).joined(separator: " and ")
            return "There are concerns about your reputation: some consider you \(weakStr)."
        } else if !dominant.isEmpty {
            return "You are known primarily for being \(dominant.first!)."
        }

        return "Your reputation is in flux. Every decision shapes how others perceive you."
    }

    /// Get the most notable trait for emphasis
    private var notableTrait: (name: String, value: Int, description: String)? {
        let traits = [
            ("Competent", game.reputationCompetent, competenceDescriptor),
            ("Loyal", game.reputationLoyal, loyaltyDescriptor),
            ("Cunning", game.reputationCunning, cunningDescriptor),
            ("Ruthless", game.reputationRuthless, ruthlessDescriptor)
        ]

        // Find highest trait above 70 or lowest trait below 30
        if let highest = traits.max(by: { $0.1 < $1.1 }), highest.1 >= 70 {
            return highest
        }
        if let lowest = traits.min(by: { $0.1 < $1.1 }), lowest.1 < 30 {
            return lowest
        }
        return nil
    }

    private var competenceDescriptor: String {
        switch game.reputationCompetent {
        case 80...: return "Highly effective administrator"
        case 60..<80: return "Capable and dependable"
        case 40..<60: return "Adequate performance"
        case 20..<40: return "Questionable abilities"
        default: return "Doubts about your competence"
        }
    }

    private var loyaltyDescriptor: String {
        switch game.reputationLoyal {
        case 80...: return "Unquestionable Party loyalty"
        case 60..<80: return "Reliable servant of the state"
        case 40..<60: return "Loyalty not yet proven"
        case 20..<40: return "Subject to loyalty reviews"
        default: return "Suspected of disloyalty"
        }
    }

    private var cunningDescriptor: String {
        switch game.reputationCunning {
        case 80...: return "Master political operator"
        case 60..<80: return "Skilled in the political arts"
        case 40..<60: return "Learning the game"
        case 20..<40: return "Politically naive"
        default: return "Easily outmaneuvered"
        }
    }

    private var ruthlessDescriptor: String {
        switch game.reputationRuthless {
        case 80...: return "Feared by all"
        case 60..<80: return "Not to be crossed"
        case 40..<60: return "Will do what's necessary"
        case 20..<40: return "Shows restraint"
        default: return "Considered soft"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(theme.inkGray)
                Text("HOW OTHERS SEE YOU")
                    .font(theme.labelFont)
                    .tracking(1)
                    .foregroundColor(theme.inkBlack)
            }

            // Overall reputation summary
            Text(overallReputation)
                .font(theme.bodyFontSmall)
                .italic()
                .foregroundColor(theme.inkGray)
                .lineSpacing(3)
                .padding(.bottom, 4)

            // Trait grid with descriptors
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                DynamicReputationRow(
                    label: "Competent",
                    value: game.reputationCompetent,
                    descriptor: competenceDescriptor
                )
                DynamicReputationRow(
                    label: "Loyal",
                    value: game.reputationLoyal,
                    descriptor: loyaltyDescriptor
                )
                DynamicReputationRow(
                    label: "Cunning",
                    value: game.reputationCunning,
                    descriptor: cunningDescriptor
                )
                DynamicReputationRow(
                    label: "Ruthless",
                    value: game.reputationRuthless,
                    descriptor: ruthlessDescriptor
                )
            }

            // Notable trait callout
            if let notable = notableTrait, notable.1 >= 70 || notable.1 < 30 {
                HStack(spacing: 6) {
                    Image(systemName: notable.1 >= 70 ? "star.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(notable.1 >= 70 ? theme.accentGold : Color(hex: "FF9800"))

                    Text(notable.2)
                        .font(theme.tagFont)
                        .foregroundColor(notable.1 >= 70 ? theme.accentGold : Color(hex: "FF9800"))
                }
                .padding(8)
                .background((notable.1 >= 70 ? theme.accentGold : Color(hex: "FF9800")).opacity(0.1))
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Personal Wealth Card

struct PersonalWealthCard: View {
    let game: Game
    @Environment(\.theme) var theme

    private var corruptionLevel: CorruptionLevel {
        CorruptionLevel.level(for: game.personalWealth)
    }

    private var riskLevel: CorruptionRiskLevel {
        CorruptionRiskLevel.level(for: game.wealthVisibility, evidence: game.corruptionEvidence)
    }

    private var wealthColor: Color {
        switch corruptionLevel {
        case .clean: return .statHigh
        case .modest: return .statMedium
        case .comfortable: return Color(hex: "FF9800")
        case .wealthy, .oligarch: return .statLow
        }
    }

    private var riskColor: Color {
        switch riskLevel {
        case .safe: return .statHigh
        case .cautious: return .statMedium
        case .exposed: return Color(hex: "FF9800")
        case .dangerous, .imminent: return .statLow
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "banknote.fill")
                    .foregroundColor(wealthColor)
                Text("PERSONAL ASSETS")
                    .font(theme.labelFont)
                    .tracking(1)
                    .foregroundColor(theme.inkBlack)
            }

            // Corruption level description
            Text(corruptionLevel.description)
                .font(theme.bodyFontSmall)
                .italic()
                .foregroundColor(theme.inkGray)
                .lineSpacing(3)

            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            // Wealth bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Accumulated Wealth")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                    Spacer()
                    Text("\(game.personalWealth)")
                        .font(theme.statFont)
                        .fontWeight(.semibold)
                        .foregroundColor(wealthColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.borderTan.opacity(0.5))

                        RoundedRectangle(cornerRadius: 2)
                            .fill(wealthColor)
                            .frame(width: geometry.size.width * CGFloat(game.personalWealth) / 100)
                    }
                }
                .frame(height: 4)
            }
            .padding(8)
            .background(theme.parchment.opacity(0.5))

            // Visibility bar (if > 0)
            if game.wealthVisibility > 0 {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 12))
                        .foregroundColor(riskColor)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Visibility")
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)
                            Spacer()
                            Text("\(game.wealthVisibility)%")
                                .font(theme.tagFont)
                                .foregroundColor(riskColor)
                        }
                        Text("How noticed your lifestyle has become")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkLight)
                    }
                }
                .padding(8)
                .background(riskColor.opacity(0.1))
            }

            // Evidence bar (if > 0)
            if game.corruptionEvidence > 0 {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                        .foregroundColor(riskColor)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Evidence")
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)
                            Spacer()
                            Text("\(game.corruptionEvidence)%")
                                .font(theme.tagFont)
                                .foregroundColor(riskColor)
                        }
                        Text("Documented proof in Bureau files")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkLight)
                    }
                }
                .padding(8)
                .background(riskColor.opacity(0.1))
            }

            // Risk warning (if applicable)
            if let warning = riskLevel.warningText {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(riskColor)

                    Text(warning)
                        .font(theme.tagFont)
                        .foregroundColor(riskColor)
                }
                .padding(8)
                .background(riskColor.opacity(0.15))
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Dynamic Reputation Row

struct DynamicReputationRow: View {
    let label: String
    let value: Int
    let descriptor: String
    @Environment(\.theme) var theme

    private var barColor: Color {
        switch value {
        case 70...: return .statHigh
        case 40..<70: return .statMedium
        default: return .statLow
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                Spacer()
                Text("\(value)")
                    .font(theme.statFont)
                    .fontWeight(.semibold)
                    .foregroundColor(value >= 60 ? theme.inkBlack : theme.inkGray)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.borderTan.opacity(0.5))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: geometry.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 4)
        }
        .padding(8)
        .background(theme.parchment.opacity(0.5))
    }
}

// Legacy row for compatibility
struct ReputationRow: View {
    let label: String
    let value: Int
    @Environment(\.theme) var theme

    var body: some View {
        HStack {
            Text(label)
                .font(theme.tagFont)
                .foregroundColor(theme.inkGray)
            Spacer()
            Text("\(value)")
                .font(theme.statFont)
                .fontWeight(.semibold)
                .foregroundColor(value >= 60 ? theme.inkBlack : theme.inkGray)
        }
        .padding(8)
        .background(theme.parchment.opacity(0.5))
    }
}

// MARK: - Dossier Tab

enum DossierTab: String, CaseIterable {
    case profile = "PROFILE"
    case figures = "FIGURES"
    case factions = "FACTIONS"
    case journal = "JOURNAL"
}

// MARK: - Tab Bar

struct DossierTabBar: View {
    @Binding var selectedTab: DossierTab
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DossierTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(theme.tagFont)
                        .foregroundColor(selectedTab == tab ? theme.inkBlack : theme.inkGray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(theme.stampRed)
                                    .frame(height: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .background(theme.parchmentDark)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)
        }
    }
}

// MARK: - Faction Card

struct FactionCardView: View {
    let faction: GameFaction
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(faction.displayIcon)
                    .font(.system(size: 20))

                Text(faction.name)
                    .font(theme.labelFont)
                    .fontWeight(.bold)
                    .foregroundColor(theme.inkBlack)

                Spacer()
            }

            if let desc = faction.factionDescription {
                Text(desc)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("POWER")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.inkLight)
                    StatBarView(label: "", value: faction.power, showLabel: false, compact: true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("YOUR STANDING")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.inkLight)
                    StatBarView(label: "", value: faction.playerStanding, showLabel: false, compact: true)
                }
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let message: String
    @Environment(\.theme) var theme

    var body: some View {
        Text(message)
            .font(theme.bodyFont)
            .foregroundColor(theme.inkLight)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

// MARK: - Game Menu Sheet

struct GameMenuSheet: View {
    var onRestart: (() -> Void)?
    var onMainMenu: (() -> Void)?
    var onDeleteAllData: (() -> Void)?
    @State private var showRestartConfirmation = false
    @State private var showMainMenuConfirmation = false
    @State private var showDeleteConfirmation = false
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Menu options
                VStack(spacing: 0) {
                    if onRestart != nil {
                        MenuOptionRow(
                            icon: "arrow.clockwise",
                            title: "Restart Game",
                            subtitle: "Start a new game with the same faction",
                            iconColor: theme.accentGold
                        ) {
                            showRestartConfirmation = true
                        }
                    }

                    if onMainMenu != nil {
                        MenuOptionRow(
                            icon: "house.fill",
                            title: "Main Menu",
                            subtitle: "Return to campaign and faction selection",
                            iconColor: theme.sovietRed
                        ) {
                            showMainMenuConfirmation = true
                        }
                    }

                    if onDeleteAllData != nil {
                        Divider()
                            .padding(.vertical, 10)

                        MenuOptionRow(
                            icon: "trash.fill",
                            title: "Delete All Data",
                            subtitle: "Completely reset app - removes all saved games",
                            iconColor: .red
                        ) {
                            showDeleteConfirmation = true
                        }
                    }
                }
                .padding(.top, 20)

                Spacer()

                // Warning text
                Text("Your current progress will be lost.")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkLight)
                    .padding(.bottom, 16)

                // Version number
                Text("Version \(Bundle.main.appVersion)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(theme.inkLight.opacity(0.5))
                    .padding(.bottom, 20)
            }
            .background(theme.parchment)
            .navigationTitle("GAME MENU")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(theme.stampRed)
                }
            }
        }
        .confirmationDialog(
            "Restart Game?",
            isPresented: $showRestartConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restart", role: .destructive) {
                dismiss()
                onRestart?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current game will be ended and a new game will begin.")
        }
        .confirmationDialog(
            "Return to Main Menu?",
            isPresented: $showMainMenuConfirmation,
            titleVisibility: .visible
        ) {
            Button("Main Menu", role: .destructive) {
                dismiss()
                onMainMenu?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current game will be ended.")
        }
        .confirmationDialog(
            "Delete All Data?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                dismiss()
                onDeleteAllData?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all saved games and settings. The app will reset to initial state.")
        }
    }
}

struct MenuOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(theme.labelFont)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.inkBlack)

                    Text(subtitle)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(theme.inkLight)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(theme.parchmentDark)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, GameCharacter.self, GameFaction.self, configurations: config)

    let game = Game(campaignId: "coldwar")

    // Add sample characters
    let wallace = GameCharacter(templateId: "wallace", name: "Director Wallace", title: "Head of State Security", role: .patron)
    wallace.isPatron = true
    wallace.isRival = true
    wallace.game = game

    let peterson = GameCharacter(templateId: "peterson", name: "Comrade Peterson", title: "Secretary of Ideology", role: .ally)
    peterson.disposition = 65
    peterson.game = game

    game.characters = [wallace, peterson]

    // Add sample factions (using player faction IDs)
    let princelings = GameFaction(factionId: "princelings", name: "Princelings", description: "Red aristocracy - descendants of revolutionary heroes with military ties.")
    princelings.power = 70
    princelings.playerStanding = 40
    princelings.game = game

    game.factions = [princelings]

    container.mainContext.insert(game)

    return DossierView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
