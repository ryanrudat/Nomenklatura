//
//  NarrativeEventView.swift
//  Nomenklatura
//
//  Displays non-decision events (routine days, character moments, tension builders)
//  with immersive narrative text and a simple "Continue" button
//

import SwiftUI

struct NarrativeEventView: View {
    let scenario: Scenario
    let turnNumber: Int
    var game: Game? = nil
    let onContinue: () -> Void
    @Environment(\.theme) var theme

    private var formattedDate: String {
        // Use Revolutionary Calendar - each turn = 2 weeks, date is consistent
        return RevolutionaryCalendar.formatTurnFull(turnNumber)
    }

    /// Category-specific styling
    private var categoryStyle: NarrativeStyle {
        switch scenario.category {
        case .routineDay:
            return NarrativeStyle(
                headerText: "A QUIET MOMENT",
                headerColor: .inkLight,
                showPresenter: true,
                atmospherePrefix: nil
            )
        case .characterMoment:
            return NarrativeStyle(
                headerText: "AN ENCOUNTER",
                headerColor: .inkGray,
                showPresenter: true,
                atmospherePrefix: nil
            )
        case .tensionBuilder:
            return NarrativeStyle(
                headerText: "RUMORS & WHISPERS",
                headerColor: .stampRed,
                showPresenter: scenario.presenterName != "The Atmosphere",
                atmospherePrefix: "You sense something in the air..."
            )
        case .newspaper:
            return NarrativeStyle(
                headerText: "FROM THE PRESS",
                headerColor: .inkBlack,
                showPresenter: false,
                atmospherePrefix: nil
            )
        default:
            return NarrativeStyle(
                headerText: "INTERLUDE",
                headerColor: .inkGray,
                showPresenter: true,
                atmospherePrefix: nil
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with category indicator
            HStack(alignment: .top) {
                Text(categoryStyle.headerText)
                    .font(theme.tagFont)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundColor(categoryStyle.headerColor)

                Spacer()

                DateBadge(date: formattedDate)
            }
            .padding(.bottom, 15)

            // Divider line
            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)
                .padding(.bottom, 15)

            // Atmosphere prefix for tension builders
            if let prefix = categoryStyle.atmospherePrefix {
                Text(prefix)
                    .font(theme.tagFont)
                    .italic()
                    .foregroundColor(theme.inkLight)
                    .padding(.bottom, 10)
            }

            // Presenter attribution (if applicable)
            if categoryStyle.showPresenter && !scenario.presenterName.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        if let game = game {
                            TappableName(name: scenario.presenterName, game: game)
                                .font(theme.labelFont)
                                .fontWeight(.semibold)
                        } else {
                            Text(scenario.presenterName)
                                .font(theme.labelFont)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.inkBlack)
                        }

                        Text(" \(presenterAction)")
                            .font(theme.labelFont)
                            .italic()
                            .foregroundColor(theme.inkGray)
                    }

                    if let title = scenario.presenterTitle {
                        Text(title)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkLight)
                    }
                }
                .padding(.bottom, 12)
            }

            // Main narrative text - larger for readability with clickable names
            if let game = game {
                ClickableNarrativeText(
                    text: scenario.briefing,
                    game: game,
                    font: theme.narrativeFontLarge,
                    color: theme.inkBlack,
                    lineSpacing: 7
                )
            } else {
                Text(scenario.briefing)
                    .font(theme.narrativeFontLarge)
                    .foregroundColor(theme.inkBlack)
                    .lineSpacing(7)
            }

            // Narrative conclusion (if present)
            if let conclusion = scenario.narrativeConclusion {
                if let game = game {
                    ClickableNarrativeText(
                        text: conclusion,
                        game: game,
                        font: theme.narrativeFont,
                        color: theme.inkGray,
                        lineSpacing: 6
                    )
                    .italic()
                    .padding(.top, 15)
                } else {
                    Text(conclusion)
                        .font(theme.narrativeFont)
                        .italic()
                        .foregroundColor(theme.inkGray)
                        .lineSpacing(6)
                        .padding(.top, 15)
                }
            }

            // Action buttons
            NarrativeActionButtons(
                scenario: scenario,
                game: game,
                turnNumber: turnNumber,
                onContinue: onContinue
            )
            .padding(.top, 25)
        }
        .padding(20)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 2, y: 2)
        .modifier(CharacterSheetOverlayModifier(game: game))
    }

    /// Action description based on category
    private var presenterAction: String {
        switch scenario.category {
        case .routineDay:
            return ["shuffles papers nearby.", "passes by your desk.", "is working quietly.", "glances up briefly."].randomElement() ?? "is present."
        case .characterMoment:
            return ["catches your eye.", "pauses near your office.", "seems to want a word.", "lingers for a moment."].randomElement() ?? "appears."
        case .tensionBuilder:
            return ["mentions something troubling.", "speaks in hushed tones.", "seems uneasy.", "shares a concerning rumor."].randomElement() ?? "appears worried."
        default:
            return "is present."
        }
    }
}

// MARK: - Narrative Style

private struct NarrativeStyle {
    let headerText: String
    let headerColor: Color
    let showPresenter: Bool
    let atmospherePrefix: String?
}

private extension Color {
    static var inkLight: Color { Color(hex: "999999") }
    static var inkGray: Color { Color(hex: "666666") }
    static var inkBlack: Color { Color(hex: "2C2C2C") }
    static var stampRed: Color { Color(hex: "8B0000") }
}

// MARK: - Action Buttons

struct NarrativeActionButtons: View {
    let scenario: Scenario
    let game: Game?
    let turnNumber: Int
    let onContinue: () -> Void
    @Environment(\.theme) var theme
    @State private var hasNoted = false

    var body: some View {
        HStack(spacing: 12) {
            // Note this button
            if let game = game {
                Button {
                    guard !hasNoted else { return }
                    saveToJournal(game: game)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasNoted = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: hasNoted ? "checkmark" : "note.text.badge.plus")
                            .font(.system(size: 12))
                        Text(hasNoted ? "NOTED" : "NOTE THIS")
                            .font(theme.tagFont)
                            .fontWeight(.medium)
                            .tracking(1)
                    }
                    .foregroundColor(hasNoted ? theme.inkLight : theme.inkGray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "E8E4D9"))
                    .overlay(
                        Rectangle()
                            .stroke(theme.borderTan, lineWidth: 1)
                    )
                    .opacity(hasNoted ? 0.5 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(hasNoted)
                .allowsHitTesting(!hasNoted)
            }

            // Continue button (expands to fill remaining space)
            Button(action: onContinue) {
                Text("CONTINUE")
                    .font(theme.labelFont)
                    .fontWeight(.medium)
                    .tracking(2)
                    .foregroundColor(theme.inkBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "E8E4D9"))
                    .overlay(
                        Rectangle()
                            .stroke(theme.borderTan, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func saveToJournal(game: Game) {
        // Determine category based on scenario type
        let category: JournalCategory = {
            switch scenario.category {
            case .characterMoment:
                return .personalityReveal
            case .tensionBuilder:
                return .factionDiscovery
            case .routineDay:
                return .plotDevelopment
            default:
                return .plotDevelopment
            }
        }()

        // Determine importance based on scenario category
        let importance: Int = {
            switch scenario.category {
            case .tensionBuilder: return 6
            case .characterMoment: return 5
            case .routineDay: return 3
            default: return 4
            }
        }()

        // Build the title
        let title: String = {
            if !scenario.presenterName.isEmpty && scenario.presenterName != "The Atmosphere" {
                return "Encounter with \(scenario.presenterName)"
            } else {
                switch scenario.category {
                case .tensionBuilder: return "Whispers in the Halls"
                case .characterMoment: return "A Notable Encounter"
                case .routineDay: return "Office Observation"
                default: return "A Moment Noted"
                }
            }
        }()

        // Build the content
        var content = scenario.briefing
        if let conclusion = scenario.narrativeConclusion {
            content += "\n\n\(conclusion)"
        }

        // Find related character if presenter is a known character
        let relatedCharacterId: String? = {
            if let character = game.characters.first(where: {
                $0.name.lowercased() == scenario.presenterName.lowercased() ||
                scenario.presenterName.lowercased().contains($0.name.lowercased())
            }) {
                return character.id.uuidString
            }
            return nil
        }()

        // Save to journal
        JournalService.shared.addEntry(
            to: game,
            category: category,
            title: title,
            content: content,
            relatedCharacterId: relatedCharacterId,
            importance: importance
        )

        // Notify the tab bar
        NotificationService.shared.notify(
            .newJournalEntry,
            title: "Note Saved",
            detail: title,
            turn: turnNumber
        )
    }
}

// MARK: - Continue Button (Legacy - kept for compatibility)

struct NarrativeContinueButton: View {
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            Text("CONTINUE")
                .font(theme.labelFont)
                .fontWeight(.medium)
                .tracking(2)
                .foregroundColor(theme.inkBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "E8E4D9"))
                .overlay(
                    Rectangle()
                        .stroke(theme.borderTan, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Routine Day") {
    let scenario = Scenario(
        templateId: "routine_day_1",
        category: .routineDay,
        format: .narrative,
        briefing: "The morning passes without incident. You review agricultural reports, approve routine personnel transfers, and initial a stack of requisition forms. The rhythms of bureaucracy continue unabated.",
        presenterName: "Secretary Peterson",
        presenterTitle: "Administrative Assistant",
        narrativeConclusion: "Another day in the machinery of the state."
    )

    return NarrativeEventView(scenario: scenario, turnNumber: 14) {
        print("Continue tapped")
    }
    .padding()
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}

#Preview("Tension Builder") {
    let scenario = Scenario(
        templateId: "tension_1",
        category: .tensionBuilder,
        format: .narrative,
        briefing: "\"Have you heard about Comrade Wallace?\" The whisper comes from nowhere and everywhere. \"They say the investigators visited his apartment last night. His wife hasn't been seen since...\"",
        presenterName: "A colleague",
        presenterTitle: nil,
        narrativeConclusion: "You file this information away, wondering what it portends."
    )

    return NarrativeEventView(scenario: scenario, turnNumber: 14) {
        print("Continue tapped")
    }
    .padding()
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}

#Preview("Character Moment") {
    let scenario = Scenario(
        templateId: "character_1",
        category: .characterMoment,
        format: .narrative,
        briefing: "General Anderson stops by your office, ostensibly to discuss next week's parade logistics. But his eyes linger on the portrait of the General Secretary on your wall. \"Interesting times,\" he murmurs, then leaves without further explanation.",
        presenterName: "General Anderson",
        presenterTitle: "Defense Ministry"
    )

    return NarrativeEventView(scenario: scenario, turnNumber: 14) {
        print("Continue tapped")
    }
    .padding()
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}
