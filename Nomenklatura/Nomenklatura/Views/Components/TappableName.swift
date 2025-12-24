//
//  TappableName.swift
//  Nomenklatura
//
//  Tappable character name component that opens a quick info sheet
//

import SwiftUI
import SwiftData

struct TappableName: View {
    let name: String
    let game: Game
    @Environment(\.theme) var theme
    @State private var showingCharacterSheet = false

    /// The character matching this name (if found)
    private var character: GameCharacter? {
        game.characters.first { $0.name.lowercased() == name.lowercased() }
    }

    var body: some View {
        if let character = character {
            Button {
                showingCharacterSheet = true
            } label: {
                Text(name)
                    .underline()
                    .foregroundColor(dispositionColor(for: character))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingCharacterSheet) {
                CharacterQuickInfoSheet(character: character, game: game)
                    .presentationDetents([.medium])
            }
        } else {
            // No matching character found - just show plain text
            Text(name)
                .foregroundColor(theme.inkBlack)
        }
    }

    private func dispositionColor(for character: GameCharacter) -> Color {
        if character.isPatron {
            return Color(hex: "1B5E20")  // Dark green for patron
        } else if character.isRival {
            return theme.sovietRed  // Red for rival
        } else if character.disposition >= 70 {
            return Color(hex: "2E7D32")  // Green for friendly
        } else if character.disposition <= 30 {
            return Color(hex: "C62828")  // Red for hostile
        } else {
            return theme.inkBlack  // Neutral
        }
    }
}

// MARK: - Character Quick Info Sheet

struct CharacterQuickInfoSheet: View {
    let character: GameCharacter
    let game: Game
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @State private var showingFullDossier = false

    private var factionName: String {
        guard let factionId = character.factionId else { return "Unaligned" }
        return game.factions.first { $0.factionId == factionId }?.name ?? factionId.capitalized
    }

    private var recentInteractions: [CharacterInteractionRecord] {
        character.interactionHistory.suffix(3).reversed()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with portrait placeholder and name
                    headerSection

                    Divider()

                    // Disposition bar
                    dispositionSection

                    // Relationship tags
                    if character.isPatron || character.isRival || character.disposition >= 70 || character.disposition <= 30 {
                        relationshipTags
                    }

                    Divider()

                    // Faction and position
                    infoSection

                    // Recent interactions
                    if !recentInteractions.isEmpty {
                        Divider()
                        interactionsSection
                    }

                    // View full dossier button
                    Button {
                        showingFullDossier = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("VIEW FULL DOSSIER")
                        }
                        .font(theme.labelFont)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundColor(theme.sovietRed)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.sovietRed, lineWidth: 1)
                        )
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .background(theme.parchment)
            .navigationTitle("DOSSIER SUMMARY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.sovietRed)
                }
            }
            .sheet(isPresented: $showingFullDossier) {
                CharacterDetailView(character: character, game: game)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Portrait placeholder
            ZStack {
                Circle()
                    .fill(theme.parchmentDark)
                    .frame(width: 70, height: 70)

                Image(systemName: "person.fill")
                    .font(.system(size: 30))
                    .foregroundColor(theme.inkLight)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(character.name.uppercased())
                    .font(theme.headerFont)
                    .tracking(1)
                    .foregroundColor(theme.inkBlack)

                if let title = character.title {
                    Text(title)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                }

                // UNVERIFIED badge for dynamically discovered characters
                if character.wasDiscoveredDynamically && !character.isFullyRevealed {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 10))
                        Text("UNVERIFIED")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(Color(hex: "5D4037"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "5D4037").opacity(0.1))
                    .cornerRadius(2)
                }

                // Status badge if not active
                if character.currentStatus != .active {
                    Text(character.currentStatus.displayText.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor)
                        .foregroundColor(.white)
                }
            }

            Spacer()
        }
    }

    private var statusColor: Color {
        switch character.currentStatus {
        case .active: return .clear
        case .dead, .executed: return Color(hex: "5D4037")
        case .imprisoned, .detained: return theme.sovietRed
        case .exiled, .retired, .disappeared: return theme.inkGray
        case .underInvestigation: return Color(hex: "E65100")
        case .rehabilitated: return Color(hex: "1565C0")
        }
    }

    // MARK: - Disposition Section

    private var dispositionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DISPOSITION")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(theme.inkLight)

                Spacer()

                Text(dispositionText)
                    .font(theme.labelFont)
                    .foregroundColor(dispositionColor)
            }

            // Disposition bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(theme.parchmentDark)
                        .frame(height: 8)

                    // Fill
                    Rectangle()
                        .fill(dispositionColor)
                        .frame(width: geometry.size.width * CGFloat(character.disposition) / 100, height: 8)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
        }
    }

    private var dispositionText: String {
        switch character.disposition {
        case 80...100: return "Devoted"
        case 60..<80: return "Friendly"
        case 40..<60: return "Neutral"
        case 20..<40: return "Unfriendly"
        default: return "Hostile"
        }
    }

    private var dispositionColor: Color {
        switch character.disposition {
        case 70...100: return Color(hex: "2E7D32")
        case 40..<70: return theme.accentGold
        default: return Color(hex: "C62828")
        }
    }

    // MARK: - Relationship Tags

    private var relationshipTags: some View {
        HStack(spacing: 8) {
            if character.isPatron {
                relationshipTag(text: "PATRON", color: Color(hex: "1B5E20"))
            }
            if character.isRival {
                relationshipTag(text: "RIVAL", color: theme.sovietRed)
            }
            if !character.isPatron && !character.isRival {
                if character.disposition >= 70 {
                    relationshipTag(text: "ALLY", color: Color(hex: "2E7D32"))
                } else if character.disposition <= 30 {
                    relationshipTag(text: "ENEMY", color: Color(hex: "C62828"))
                }
            }

            Spacer()
        }
    }

    private func relationshipTag(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .overlay(
                Rectangle()
                    .stroke(color, lineWidth: 1)
            )
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 12) {
            infoRow(label: "FACTION", value: factionName)

            if let position = character.positionIndex {
                infoRow(label: "POSITION", value: "Level \(position)")
            }

            if character.isFullyRevealed {
                infoRow(label: "PERSONALITY", value: dominantTrait)
            } else {
                HStack {
                    Text("PERSONALITY")
                        .font(theme.tagFont)
                        .tracking(1)
                        .foregroundColor(theme.inkLight)
                    Spacer()
                    Text("[UNKNOWN]")
                        .font(theme.bodyFontSmall)
                        .italic()
                        .foregroundColor(theme.inkLight)
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(theme.tagFont)
                .tracking(1)
                .foregroundColor(theme.inkLight)
            Spacer()
            Text(value)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
        }
    }

    private var dominantTrait: String {
        let traits: [(String, Int)] = [
            ("Ambitious", character.personalityAmbitious),
            ("Paranoid", character.personalityParanoid),
            ("Ruthless", character.personalityRuthless),
            ("Competent", character.personalityCompetent),
            ("Loyal", character.personalityLoyal),
            ("Corrupt", character.personalityCorrupt)
        ]

        if let highest = traits.max(by: { $0.1 < $1.1 }), highest.1 >= 60 {
            return highest.0
        }
        return "Unremarkable"
    }

    // MARK: - Interactions Section

    private var interactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT INTERACTIONS")
                .font(theme.tagFont)
                .tracking(1)
                .foregroundColor(theme.inkLight)

            ForEach(recentInteractions, id: \.turnNumber) { interaction in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(interactionColor(for: interaction.outcomeEffect))
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Turn \(interaction.turnNumber)")
                            .font(.system(size: 10))
                            .foregroundColor(theme.inkLight)

                        Text(interaction.scenarioSummary)
                            .font(theme.bodyFontSmall)
                            .foregroundColor(theme.inkGray)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private func interactionColor(for outcomeEffect: String) -> Color {
        switch outcomeEffect {
        case "positive", "majorPositive":
            return Color(hex: "2E7D32")
        case "negative", "majorNegative":
            return Color(hex: "C62828")
        default:
            return theme.inkLight
        }
    }
}

// MARK: - Preview

#Preview("Tappable Name") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, GameCharacter.self, GameFaction.self, configurations: config)
    let context = container.mainContext

    let game = Game(campaignId: "cold_war")
    context.insert(game)

    let character = GameCharacter(templateId: "brenner", name: "Victor Bennett", title: "General Secretary", role: .leader)
    character.disposition = 75
    character.isPatron = true
    character.factionId = "old_guard"
    character.personalityAmbitious = 85
    character.isFullyRevealed = true
    context.insert(character)
    character.game = game
    game.characters.append(character)

    let faction = GameFaction(factionId: "old_guard", name: "Proletariat Union", description: "Labor union guardians of revolutionary ideals")
    context.insert(faction)
    faction.game = game
    game.factions.append(faction)

    return VStack(spacing: 20) {
        HStack {
            Text("Presenter:")
            TappableName(name: "Victor Bennett", game: game)
        }
        .padding()
    }
    .environment(\.theme, ColdWarTheme())
}
