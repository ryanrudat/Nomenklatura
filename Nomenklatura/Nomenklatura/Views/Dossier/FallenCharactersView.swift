//
//  FallenCharactersView.swift
//  Nomenklatura
//
//  Displays fallen characters (dead, purged, exiled, disappeared, etc.)
//  with their fates and potential to return
//

import SwiftUI

struct FallenCharactersView: View {
    let characters: [GameCharacter]
    let game: Game
    @Environment(\.theme) var theme

    /// Characters grouped by their fate severity
    private var groupedCharacters: [(String, [GameCharacter])] {
        var groups: [(String, [GameCharacter])] = []

        let disappeared = characters.filter { $0.currentStatus == .disappeared }
        let underInvestigation = characters.filter {
            $0.currentStatus == .underInvestigation || $0.currentStatus == .detained
        }
        let imprisoned = characters.filter {
            $0.currentStatus == .imprisoned || $0.currentStatus == .exiled
        }
        let executed = characters.filter { $0.currentStatus == .executed }
        let dead = characters.filter { $0.currentStatus == .dead }
        let retired = characters.filter { $0.currentStatus == .retired }

        if !disappeared.isEmpty {
            groups.append(("WHEREABOUTS UNKNOWN", disappeared))
        }
        if !underInvestigation.isEmpty {
            groups.append(("UNDER INVESTIGATION", underInvestigation))
        }
        if !imprisoned.isEmpty {
            groups.append(("DETAINED", imprisoned))
        }
        if !executed.isEmpty {
            groups.append(("EXECUTED", executed))
        }
        if !dead.isEmpty {
            groups.append(("DECEASED", dead))
        }
        if !retired.isEmpty {
            groups.append(("RETIRED", retired))
        }

        return groups
    }

    var body: some View {
        if characters.isEmpty {
            // Empty state
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 40))
                    .foregroundColor(theme.inkLight)

                Text("No fallen comrades")
                    .font(theme.bodyFont)
                    .foregroundColor(theme.inkGray)

                Text("All known associates remain in good standing")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkLight)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 40)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groupedCharacters, id: \.0) { group in
                    FallenGroupSection(
                        title: group.0,
                        characters: group.1,
                        game: game
                    )
                }
            }
        }
    }
}

// MARK: - Group Section

private struct FallenGroupSection: View {
    let title: String
    let characters: [GameCharacter]
    let game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Rectangle()
                    .fill(headerColor)
                    .frame(width: 4)
                    .frame(height: 16)

                Text(title)
                    .font(theme.tagFont)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundColor(headerColor)
            }

            // Characters
            ForEach(characters, id: \.id) { character in
                FallenCharacterCard(character: character, game: game)
            }
        }
    }

    private var headerColor: Color {
        switch title {
        case "WHEREABOUTS UNKNOWN":
            return Color(hex: "666666")
        case "UNDER INVESTIGATION":
            return Color(hex: "B8860B")
        case "DETAINED":
            return Color(hex: "8B4513")
        case "EXECUTED", "DECEASED":
            return Color(hex: "8B0000")
        case "RETIRED":
            return Color(hex: "4A5568")
        default:
            return Color.gray
        }
    }
}

// MARK: - Character Card

private struct FallenCharacterCard: View {
    let character: GameCharacter
    let game: Game
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row - tap to expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(character.name)
                                .font(theme.labelFont)
                                .fontWeight(.medium)
                                .foregroundColor(theme.inkBlack)

                            // Status badge
                            CharacterStatusBadge(status: character.currentStatus)

                            // Return indicator
                            if character.mightReturn {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "666666"))
                            }
                        }

                        if let title = character.title {
                            Text(title)
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkLight)
                        }

                        // Euphemistic status
                        Text(character.currentStatus.euphemism)
                            .font(theme.tagFont)
                            .italic()
                            .foregroundColor(theme.inkGray)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    // Fate narrative (if available)
                    if let narrative = character.fateNarrative {
                        ClickableNarrativeText(
                            text: narrative,
                            game: game,
                            font: theme.bodyFontSmall,
                            color: theme.inkGray,
                            lineSpacing: 4
                        )
                    }

                    // Status details
                    if let details = character.statusDetails {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 12))
                            Text(details)
                                .font(theme.tagFont)
                        }
                        .foregroundColor(theme.inkLight)
                    }

                    // Turn info
                    if let turn = character.statusChangedTurn {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text("Turn \(turn)")
                                .font(theme.tagFont)
                        }
                        .foregroundColor(theme.inkLight)
                    }

                    // Return probability (for disappeared)
                    if character.mightReturn && character.returnProbability > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 12))
                            Text("May resurface")
                                .font(theme.tagFont)
                        }
                        .foregroundColor(Color(hex: "666666"))
                    }

                    // Remaining influence
                    if character.remainingInfluence > 20 {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.wave.2")
                                .font(.system(size: 12))
                            Text("Still has allies: \(character.remainingInfluence)%")
                                .font(theme.tagFont)
                        }
                        .foregroundColor(Color(hex: "8B4513"))
                    }

                    // Rehabilitated badge
                    if character.currentStatus == .rehabilitated {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                            Text("REHABILITATED")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "4A7C59"))
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(borderColor, lineWidth: 1)
        )
        .characterSheetOverlay(game: game)
    }

    private var borderColor: Color {
        if character.currentStatus.isPermanent {
            return Color(hex: "8B0000").opacity(0.5)
        } else if character.mightReturn {
            return Color(hex: "666666").opacity(0.5)
        }
        return theme.borderTan
    }
}

// MARK: - Character Status Badge

private struct CharacterStatusBadge: View {
    let status: CharacterStatus

    var body: some View {
        Text(status.displayText.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(textColor)
    }

    private var backgroundColor: Color {
        switch status {
        case .active, .rehabilitated:
            return Color(hex: "4A7C59")
        case .disappeared:
            return Color(hex: "666666")
        case .underInvestigation, .detained:
            return Color(hex: "B8860B")
        case .imprisoned, .exiled:
            return Color(hex: "8B4513")
        case .dead, .executed:
            return Color(hex: "8B0000")
        case .retired:
            return Color(hex: "4A5568")
        }
    }

    private var textColor: Color {
        return .white
    }
}

// MARK: - Preview

#Preview("Fallen Characters") {
    let game = Game(campaignId: "coldwar")
    let characters: [GameCharacter] = [
        {
            let c = GameCharacter(templateId: "wallace", name: "Director Wallace", title: "Former Head of State Security", role: .patron)
            c.status = CharacterStatus.disappeared.rawValue
            c.statusChangedTurn = 12
            c.statusDetails = "Last seen entering Central Committee building"
            c.fateNarrative = "Director Wallace failed to appear at the morning briefing. His office was found empty, personal effects removed. No official statement has been issued."
            c.canReturnFlag = true
            c.returnProbability = 30
            c.remainingInfluence = 40
            return c
        }(),
        {
            let c = GameCharacter(templateId: "sullivan", name: "Deputy Sullivan", title: "Former Economic Planning", role: .rival)
            c.status = CharacterStatus.executed.rawValue
            c.statusChangedTurn = 8
            c.statusDetails = "Convicted of economic sabotage and espionage"
            c.fateNarrative = "After a brief trial, Deputy Sullivan was found guilty of deliberately sabotaging industrial quotas and passing state secrets to foreign powers. Sentence carried out immediately."
            return c
        }(),
        {
            let c = GameCharacter(templateId: "peterson", name: "Comrade Peterson", title: "Former Secretary", role: .ally)
            c.status = CharacterStatus.imprisoned.rawValue
            c.statusChangedTurn = 15
            c.statusDetails = "Sentenced to 15 years reform through labor"
            c.fateNarrative = "Comrade Peterson was found to have maintained improper contacts with revisionist elements. He has been sent to contribute to the development of the eastern regions."
            c.canReturnFlag = true
            c.returnProbability = 20
            c.remainingInfluence = 15
            return c
        }()
    ]

    ScrollView {
        FallenCharactersView(characters: characters, game: game)
            .padding()
    }
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}
