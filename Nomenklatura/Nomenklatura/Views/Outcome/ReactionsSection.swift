//
//  ReactionsSection.swift
//  Nomenklatura
//
//  Multi-character reactions to player decisions
//

import SwiftUI
import SwiftData

// MARK: - Reaction Model

struct CharacterReactionItem: Identifiable {
    let id = UUID()
    let character: GameCharacter
    let reaction: String
    let reactionType: ReactionType

    enum ReactionType {
        case approval      // Supports the decision
        case disapproval   // Opposes the decision
        case concern       // Worried about consequences
        case neutral       // Observational
    }
}

// MARK: - Reactions Section

struct ReactionsSection: View {
    let game: Game
    let statChanges: [StatChange]
    let optionArchetype: OptionArchetype?

    @Environment(\.theme) var theme

    /// Generate multiple character reactions based on decision impact
    private var characterReactions: [CharacterReactionItem] {
        guard let archetype = optionArchetype else { return [] }

        var reactions: [CharacterReactionItem] = []
        var usedCharacterIds: Set<UUID> = []
        let aliveCharacters = game.characters.filter { $0.isAlive }

        // 1. Government/Elite reaction (Patron, high-ranking officials)
        if let governmentReactor = selectGovernmentReactor(from: aliveCharacters, archetype: archetype) {
            let reaction = generateReaction(for: governmentReactor, archetype: archetype, isGovernment: true)
            reactions.append(reaction)
            usedCharacterIds.insert(governmentReactor.id)
        }

        // 2. Faction reactions - show 1-2 faction perspectives that differ on this decision
        let factionReactions = generateFactionReactions(archetype: archetype, aliveCharacters: aliveCharacters, excludeIds: usedCharacterIds)
        for factionReaction in factionReactions.prefix(2) {
            reactions.append(factionReaction)
            usedCharacterIds.insert(factionReaction.character.id)
        }

        // 3. Popular/Worker reaction (for decisions affecting popular support, food, stability)
        if shouldShowPopularReaction(archetype: archetype) && reactions.count < 4 {
            let popularReaction = generatePopularReaction(archetype: archetype)
            reactions.append(popularReaction)
        }

        // 4. Rival reaction (if they would care and we have space)
        if reactions.count < 4,
           let rival = game.primaryRival,
           rival.isAlive,
           !usedCharacterIds.contains(rival.id),
           shouldRivalReact(archetype: archetype) {
            let reaction = generateReaction(for: rival, archetype: archetype, isRival: true)
            reactions.append(reaction)
        }

        return Array(reactions.prefix(4)) // Max 4 reactions
    }

    var body: some View {
        if !characterReactions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Section header
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.stampRed)

                    Text("REACTIONS")
                        .font(theme.labelFont)
                        .tracking(2)
                        .foregroundColor(theme.inkBlack)
                }

                // Horizontal scroll of reaction cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(characterReactions) { item in
                            ReactionCard(
                                item: item,
                                game: game
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Character Selection Logic

    private func selectGovernmentReactor(from characters: [GameCharacter], archetype: OptionArchetype) -> GameCharacter? {
        // Prefer patron first
        if let patron = game.patron, patron.isAlive {
            return patron
        }

        // Then look for high-ranking officials
        let officials = characters.filter { char in
            char.currentRole == .leader ||
            char.title?.lowercased().contains("minister") == true ||
            char.title?.lowercased().contains("secretary") == true ||
            char.title?.lowercased().contains("director") == true
        }

        return officials.first
    }

    private func selectMilitaryReactor(from characters: [GameCharacter]) -> GameCharacter? {
        // Look for military characters
        let military = characters.filter { char in
            char.title?.lowercased().contains("general") == true ||
            char.title?.lowercased().contains("marshal") == true ||
            char.title?.lowercased().contains("colonel") == true ||
            char.title?.lowercased().contains("commander") == true ||
            char.title?.lowercased().contains("military") == true
        }

        return military.first
    }

    private func shouldShowMilitaryReaction(archetype: OptionArchetype) -> Bool {
        let militaryArchetypes: [OptionArchetype] = [.military, .mobilize, .attack, .repress]
        if militaryArchetypes.contains(archetype) {
            return true
        }

        // Check if military loyalty changed
        return statChanges.contains { $0.statKey == "militaryLoyalty" && abs($0.delta) >= 5 }
    }

    private func shouldShowPopularReaction(archetype: OptionArchetype) -> Bool {
        let popularArchetypes: [OptionArchetype] = [.repress, .reform, .appease, .sacrifice, .allocate, .production]
        if popularArchetypes.contains(archetype) {
            return true
        }

        // Check if popular support, food, or stability changed significantly
        return statChanges.contains { change in
            (change.statKey == "popularSupport" ||
             change.statKey == "foodSupply" ||
             change.statKey == "stability") && abs(change.delta) >= 5
        }
    }

    private func shouldRivalReact(archetype: OptionArchetype) -> Bool {
        // Rivals react to power moves and failures
        let rivalInterestArchetypes: [OptionArchetype] = [.repress, .attack, .sacrifice, .investigate, .personnel]
        if rivalInterestArchetypes.contains(archetype) {
            return true
        }

        // React to standing changes
        return statChanges.contains { $0.statKey == "standing" && abs($0.delta) >= 5 }
    }

    // MARK: - Faction Reactions

    /// Determines which factions care about this decision and generates their reactions
    private func generateFactionReactions(archetype: OptionArchetype, aliveCharacters: [GameCharacter], excludeIds: Set<UUID>) -> [CharacterReactionItem] {
        var reactions: [CharacterReactionItem] = []

        // Get factions that would react differently to this decision
        let affectedFactions = getAffectedFactions(for: archetype)

        for (factionId, stance) in affectedFactions {
            // Find a character from this faction who isn't already used
            if let factionMember = aliveCharacters.first(where: { char in
                char.factionId == factionId && !excludeIds.contains(char.id)
            }) {
                let (reaction, reactionType) = generateFactionReactionText(
                    factionId: factionId,
                    archetype: archetype,
                    stance: stance
                )

                reactions.append(CharacterReactionItem(
                    character: factionMember,
                    reaction: reaction,
                    reactionType: reactionType
                ))
            }
        }

        return reactions
    }

    /// Maps decision archetypes to factions that would care, with their likely stance
    private func getAffectedFactions(for archetype: OptionArchetype) -> [(factionId: String, stance: FactionStance)] {
        switch archetype {
        // Security/Repression - Proletariat Union approves, Reformists disapprove
        case .repress, .investigate, .surveil:
            return [
                ("old_guard", .approve),
                ("reformists", .disapprove)
            ]

        // Reform/Liberalization - Reformists approve, Proletariat Union disapproves
        case .reform, .appease:
            return [
                ("reformists", .approve),
                ("old_guard", .disapprove)
            ]

        // Military action - Princelings approve, Reformists concerned
        case .military, .mobilize, .attack:
            return [
                ("princelings", .approve),
                ("reformists", .concerned)
            ]

        // Economic decisions - Reformists care most, Provincial Admin affected
        case .production, .trade, .allocate:
            return [
                ("reformists", .neutral),
                ("regional", .concerned)
            ]

        // Centralization vs Provincial autonomy
        case .administrative, .governance:
            return [
                ("youth_league", .approve),
                ("regional", .disapprove)
            ]

        // Ideological matters - Proletariat Union and Youth League care
        case .ideological, .orthodox:
            return [
                ("old_guard", .approve),
                ("youth_league", .neutral)
            ]

        // Personnel decisions - affects power structures
        case .personnel:
            return [
                ("princelings", .concerned),
                ("youth_league", .neutral)
            ]

        // Loyalty/Party matters
        case .loyalty:
            return [
                ("old_guard", .approve),
                ("princelings", .neutral)
            ]

        // Negotiation/Diplomacy
        case .negotiate, .international:
            return [
                ("reformists", .approve),
                ("old_guard", .concerned)
            ]

        // Sacrifice decisions
        case .sacrifice:
            return [
                ("old_guard", .approve),
                ("regional", .disapprove)
            ]

        // Delay/Deflect - seen as weak by some
        case .delay, .deflect:
            return [
                ("old_guard", .disapprove),
                ("reformists", .neutral)
            ]

        // Regulation
        case .regulate:
            return [
                ("youth_league", .approve),
                ("regional", .concerned)
            ]
        }
    }

    /// Generates faction-specific reaction text based on their ideology
    private func generateFactionReactionText(factionId: String, archetype: OptionArchetype, stance: FactionStance) -> (String, CharacterReactionItem.ReactionType) {
        switch factionId {
        case "old_guard":
            return generateOldGuardReaction(archetype: archetype, stance: stance)
        case "reformists":
            return generateReformistReaction(archetype: archetype, stance: stance)
        case "princelings":
            return generatePrincelingsReaction(archetype: archetype, stance: stance)
        case "youth_league":
            return generateYouthLeagueReaction(archetype: archetype, stance: stance)
        case "regional":
            return generateRegionalReaction(archetype: archetype, stance: stance)
        default:
            return ("The Party notes this development.", .neutral)
        }
    }

    // MARK: - Faction-Specific Reactions

    private func generateOldGuardReaction(archetype: OptionArchetype, stance: FactionStance) -> (String, CharacterReactionItem.ReactionType) {
        switch stance {
        case .approve:
            let approvals = [
                "The organs of state security stand ready. Vigilance protects the Revolution.",
                "This is the correct application of socialist discipline. The Party approves.",
                "Revolutionary justice must be swift. You understand this, Comrade.",
                "The enemies of the state never rest. Neither must we."
            ]
            return (approvals.randomElement()!, .approval)

        case .disapprove:
            let disapprovals = [
                "Softness invites counter-revolution. The ideological foundations must not be weakened.",
                "This path leads to revisionism. The founders would not approve.",
                "We have seen where compromise leads. Remember the Doctrinal Divergence.",
                "The Party's vigilance cannot be relaxed. This concerns me deeply."
            ]
            return (disapprovals.randomElement()!, .disapproval)

        case .concerned:
            let concerns = [
                "Such matters require careful consideration. The security implications are significant.",
                "I will be monitoring the situation closely. For the Party's sake.",
                "Proceed carefully, Comrade. Not everyone shares your... perspective."
            ]
            return (concerns.randomElement()!, .concern)

        case .neutral:
            return ("The Party's instruments are prepared for any eventuality.", .neutral)
        }
    }

    private func generateReformistReaction(archetype: OptionArchetype, stance: FactionStance) -> (String, CharacterReactionItem.ReactionType) {
        switch stance {
        case .approve:
            let approvals = [
                "A pragmatic approach. This is how socialism advances—carefully, methodically.",
                "Economic rationality must guide our decisions. This is a step forward.",
                "Progress through practical measures. The people will benefit.",
                "This demonstrates the flexibility our system requires to thrive."
            ]
            return (approvals.randomElement()!, .approval)

        case .disapprove:
            let disapprovals = [
                "Such methods belong to an earlier era. We must modernize our approach.",
                "The costs will outweigh the benefits. I have seen the projections.",
                "This risks alienating those we need most. Reconsider, Comrade.",
                "Efficiency suffers when ideology overrides pragmatism."
            ]
            return (disapprovals.randomElement()!, .disapproval)

        case .concerned:
            let concerns = [
                "The economic implications require study. Let us proceed with data.",
                "I would advise consultation with the planning commission.",
                "There may be unintended consequences. We should model the outcomes."
            ]
            return (concerns.randomElement()!, .concern)

        case .neutral:
            return ("The plan must account for all variables. We shall adjust accordingly.", .neutral)
        }
    }

    private func generatePrincelingsReaction(archetype: OptionArchetype, stance: FactionStance) -> (String, CharacterReactionItem.ReactionType) {
        switch stance {
        case .approve:
            let approvals = [
                "The armed forces stand behind this decision. Strength preserves the Revolution.",
                "My father would have approved. This honors the revolutionary legacy.",
                "Decisive action—the hallmark of true leadership. The military is ready.",
                "This demonstrates the resolve our enemies fear."
            ]
            return (approvals.randomElement()!, .approval)

        case .disapprove:
            let disapprovals = [
                "The revolutionary heritage demands better. Our fathers fought for more than this.",
                "The generals are... discussing this among themselves. Not favorably.",
                "Military matters require military minds. Perhaps consult those who served.",
                "This weakens our position. The armed forces take note."
            ]
            return (disapprovals.randomElement()!, .disapproval)

        case .concerned:
            let concerns = [
                "The defense implications must be considered. I will speak with the General Staff.",
                "Our readiness cannot be compromised. Ensure the military is consulted.",
                "There are strategic dimensions to consider. Allow me to advise."
            ]
            return (concerns.randomElement()!, .concern)

        case .neutral:
            return ("The military maintains its vigilance. We are prepared for all scenarios.", .neutral)
        }
    }

    private func generateYouthLeagueReaction(archetype: OptionArchetype, stance: FactionStance) -> (String, CharacterReactionItem.ReactionType) {
        switch stance {
        case .approve:
            let approvals = [
                "Proper procedure followed, proper results achieved. This is how it should be.",
                "Merit and competence rewarded. The system works when applied correctly.",
                "This demonstrates the Party's commitment to capable leadership.",
                "An orderly approach. The apparatus functions as designed."
            ]
            return (approvals.randomElement()!, .approval)

        case .disapprove:
            let disapprovals = [
                "The procedures exist for reasons. Bypassing them sets a dangerous precedent.",
                "Competence must remain our standard. This decision concerns me.",
                "The system requires consistency. Ad hoc measures weaken it.",
                "I expected more rigorous analysis. The data does not fully support this."
            ]
            return (disapprovals.randomElement()!, .disapproval)

        case .concerned:
            let concerns = [
                "Let us ensure proper documentation. The records must be complete.",
                "I recommend a formal review process. For transparency.",
                "The organizational implications should be studied."
            ]
            return (concerns.randomElement()!, .concern)

        case .neutral:
            return ("The apparatus continues its work. We serve the collective will.", .neutral)
        }
    }

    private func generateRegionalReaction(archetype: OptionArchetype, stance: FactionStance) -> (String, CharacterReactionItem.ReactionType) {
        switch stance {
        case .approve:
            let approvals = [
                "The zones will benefit from this. Washington finally understands our needs.",
                "This acknowledges the reality on the ground. The regions are grateful.",
                "Local conditions matter. This decision reflects that wisdom.",
                "The center cannot manage everything. This is appropriate delegation."
            ]
            return (approvals.randomElement()!, .approval)

        case .disapprove:
            let disapprovals = [
                "Washington does not understand conditions here. This will fail in the zones.",
                "Another decree from the capital that ignores local realities.",
                "The regions bear the burden while the center makes decisions.",
                "We who implement these policies see what the Presidium cannot."
            ]
            return (disapprovals.randomElement()!, .disapproval)

        case .concerned:
            let concerns = [
                "How will this affect resource allocation to the provinces?",
                "The regional committees will need guidance on implementation.",
                "Local conditions vary greatly. Flexibility will be required."
            ]
            return (concerns.randomElement()!, .concern)

        case .neutral:
            return ("The provinces await direction. We will adapt as always.", .neutral)
        }
    }

    /// Faction stance toward a decision
    private enum FactionStance {
        case approve
        case disapprove
        case concerned
        case neutral
    }

    // MARK: - Reaction Generation

    private func generateReaction(for character: GameCharacter, archetype: OptionArchetype, isGovernment: Bool = false, isMilitary: Bool = false, isRival: Bool = false) -> CharacterReactionItem {
        let disposition = character.disposition
        let isPositiveToPlayer = disposition >= 50

        let (reaction, reactionType) = generateReactionText(
            character: character,
            archetype: archetype,
            isPositive: isPositiveToPlayer,
            isGovernment: isGovernment,
            isMilitary: isMilitary,
            isRival: isRival
        )

        return CharacterReactionItem(
            character: character,
            reaction: reaction,
            reactionType: reactionType
        )
    }

    private func generatePopularReaction(archetype: OptionArchetype) -> CharacterReactionItem {
        // Create a synthetic "Worker" character for popular reactions
        let workerNames = ["Worker Anna", "Worker David", "Citizen Martha", "Worker John", "Citizen Ellen"]
        let selectedName = workerNames.randomElement() ?? "Worker Anna"

        // Get the mood from stat changes
        let popularChange = statChanges.first { $0.statKey == "popularSupport" }?.delta ?? 0
        let foodChange = statChanges.first { $0.statKey == "foodSupply" }?.delta ?? 0
        let overallSentiment = popularChange + foodChange

        let (reaction, reactionType) = generatePopularReactionText(
            archetype: archetype,
            sentiment: overallSentiment
        )

        // Create a temporary character for display
        let tempCharacter = createPopularCharacter(name: selectedName)

        return CharacterReactionItem(
            character: tempCharacter,
            reaction: reaction,
            reactionType: reactionType
        )
    }

    private func createPopularCharacter(name: String) -> GameCharacter {
        // Create a temporary character representation for the "voice of the people"
        let character = GameCharacter(
            templateId: "popular_voice",
            name: name,
            role: .subordinate
        )
        character.title = "Factory Worker"
        character.disposition = 50 // Neutral by default
        return character
    }

    private func generateReactionText(character: GameCharacter, archetype: OptionArchetype, isPositive: Bool, isGovernment: Bool, isMilitary: Bool, isRival: Bool) -> (String, CharacterReactionItem.ReactionType) {

        // Government/Patron reactions
        if isGovernment {
            return generateGovernmentReaction(archetype: archetype, isPositive: isPositive)
        }

        // Military reactions
        if isMilitary {
            return generateMilitaryReaction(archetype: archetype)
        }

        // Rival reactions
        if isRival {
            return generateRivalReaction(archetype: archetype, character: character)
        }

        // Default reaction
        return ("An interesting development, Comrade.", .neutral)
    }

    private func generateGovernmentReaction(archetype: OptionArchetype, isPositive: Bool) -> (String, CharacterReactionItem.ReactionType) {
        switch archetype {
        case .repress, .attack, .military:
            if isPositive {
                return ("Efficient work, comrade. The state appreciates your decisiveness.", .approval)
            } else {
                return ("Such methods require careful consideration. The Party is watching.", .concern)
            }

        case .appease, .reform, .negotiate:
            if isPositive {
                return ("A measured approach. The Presidium notes your diplomatic skill.", .approval)
            } else {
                return ("Softness can be mistaken for weakness, Comrade. Remember that.", .disapproval)
            }

        case .sacrifice, .allocate:
            return ("Resources must serve the greater good. Your allocation is noted.", .neutral)

        case .investigate, .surveil:
            return ("Vigilance protects the Revolution. Continue your work.", .approval)

        case .production, .trade:
            return ("Economic matters require steady hands. The plan advances.", .neutral)

        default:
            return ("The machinery of state continues. Carry on, Comrade.", .neutral)
        }
    }

    private func generateMilitaryReaction(archetype: OptionArchetype) -> (String, CharacterReactionItem.ReactionType) {
        let militaryChange = statChanges.first { $0.statKey == "militaryLoyalty" }?.delta ?? 0

        switch archetype {
        case .military, .mobilize:
            if militaryChange >= 0 {
                return ("The armed forces stand ready. Your orders are clear.", .approval)
            } else {
                return ("The generals are... discussing your directives.", .concern)
            }

        case .repress, .attack:
            return ("Force applied correctly solves many problems. The troops are prepared.", .approval)

        case .appease, .reform:
            return ("Political solutions have their place. The military awaits decisive orders.", .neutral)

        case .negotiate, .international:
            return ("Diplomacy backed by strength. We maintain readiness.", .neutral)

        default:
            if militaryChange > 0 {
                return ("The armed forces note your support with appreciation.", .approval)
            } else if militaryChange < 0 {
                return ("Military matters require attention, Comrade Secretary.", .concern)
            }
            return ("The defense of the state continues.", .neutral)
        }
    }

    private func generateRivalReaction(archetype: OptionArchetype, character: GameCharacter) -> (String, CharacterReactionItem.ReactionType) {
        let standingChange = statChanges.first { $0.statKey == "standing" }?.delta ?? 0
        let isRuthless = character.personalityRuthless > 60

        switch archetype {
        case .repress, .attack:
            if standingChange > 0 {
                return (isRuthless ? "Interesting tactics. I expected no less." : "Such methods... the Party takes note of everything.", .neutral)
            } else {
                return ("Your heavy hand may yet prove your undoing, Comrade.", .approval) // Rival approves of your mistakes
            }

        case .sacrifice, .investigate:
            return ("Sacrifices must be made, yes. But who decides the cost?", .concern)

        case .personnel:
            return ("Personnel changes... everyone is watching who rises and falls.", .neutral)

        default:
            if standingChange > 0 {
                return ("You climb well, Comrade. But every ladder has a top.", .concern)
            } else {
                return ("Difficulties arise for all of us. Some more than others.", .approval)
            }
        }
    }

    private func generatePopularReactionText(archetype: OptionArchetype, sentiment: Int) -> (String, CharacterReactionItem.ReactionType) {
        switch archetype {
        case .repress, .attack:
            if sentiment >= 0 {
                return ("Order is necessary, yes. We understand.", .neutral)
            } else {
                return ("We cannot sustain this pace. The people are exhausted.", .disapproval)
            }

        case .appease, .reform:
            if sentiment > 0 {
                return ("Finally, someone listens! The workers are grateful.", .approval)
            } else {
                return ("Words are spoken, but bread remains scarce.", .concern)
            }

        case .sacrifice, .allocate:
            if sentiment >= 0 {
                return ("We give what we can for the motherland.", .neutral)
            } else {
                return ("How much more can we sacrifice? Our children go hungry.", .disapproval)
            }

        case .production:
            if sentiment > 0 {
                return ("The factory quotas are met. We have done our part.", .approval)
            } else {
                return ("Production increases, but at what cost to the workers?", .concern)
            }

        default:
            if sentiment > 0 {
                return ("Life improves, slowly. We are hopeful.", .approval)
            } else if sentiment < 0 {
                return ("The people whisper in the bread lines. Discontent grows.", .disapproval)
            }
            return ("We work. We wait. What else can be done?", .neutral)
        }
    }
}

// MARK: - Reaction Card

struct ReactionCard: View {
    let item: CharacterReactionItem
    let game: Game

    @Environment(\.theme) var theme

    private var portraitImageName: String? {
        // Try to find portrait based on character templateId
        guard !item.character.templateId.isEmpty else { return nil }
        let imageName = "portrait_\(item.character.templateId)"
        return UIImage(named: imageName) != nil ? imageName : nil
    }

    private var dispositionIndicator: some View {
        Group {
            if item.character.disposition >= 60 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.statHigh)
            } else if item.character.disposition <= 40 {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.statLow)
            } else {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(theme.inkLight)
            }
        }
        .font(.system(size: 12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Portrait
            CharacterPortrait(
                name: item.character.name,
                imageName: portraitImageName,
                size: 80,
                showFrame: false
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Name with disposition indicator
            HStack(spacing: 4) {
                TappableName(name: item.character.name, game: game)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                dispositionIndicator
            }

            // Reaction quote
            Text("\"\(item.reaction)\"")
                .font(.custom("AmericanTypewriter", size: 13))
                .italic()
                .foregroundColor(theme.inkGray)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 150)
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    ReactionsPreviewContainer()
}

private struct ReactionsPreviewContainer: View {
    var body: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Game.self, configurations: config)
        let game = Game(campaignId: "coldwar")

        // Add test characters to game
        let patron = GameCharacter(templateId: "sutton", name: "Gen. Sutton", role: .patron)
        patron.title = "Chief of General Staff"
        patron.disposition = 70
        patron.isPatron = true
        game.characters.append(patron)

        let rival = GameCharacter(templateId: "kowalski", name: "Deputy Kowalski", role: .rival)
        rival.title = "Deputy Minister"
        rival.disposition = 30
        rival.isRival = true
        rival.personalityRuthless = 75
        game.characters.append(rival)

        let changes = [
            StatChange(statKey: "popularSupport", statName: "Popular Support", oldValue: 50, newValue: 35, isPersonal: false),
            StatChange(statKey: "militaryLoyalty", statName: "Military Loyalty", oldValue: 50, newValue: 60, isPersonal: false),
            StatChange(statKey: "stability", statName: "Stability", oldValue: 50, newValue: 55, isPersonal: false)
        ]

        return ScrollView {
            ReactionsSection(
                game: game,
                statChanges: changes,
                optionArchetype: .repress
            )
            .padding()
        }
        .background(Color(hex: "F4F1E8"))
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
    }
}
