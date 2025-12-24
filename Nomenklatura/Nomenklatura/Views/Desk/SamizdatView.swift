//
//  SamizdatView.swift
//  Nomenklatura
//
//  Underground samizdat publication view - typewriter aesthetic
//

import SwiftUI

struct SamizdatView: View {
    let edition: NewspaperEdition
    let onContinue: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Samizdat header - rough, typed
            SamizdatHeader(
                name: edition.publicationName,
                date: edition.publicationDate
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Main headline
                    SamizdatHeadline(story: edition.headline)

                    // Dashed separator
                    SamizdatSeparator()
                        .padding(.vertical, 12)

                    // Secondary stories
                    if !edition.secondaryStories.isEmpty {
                        SamizdatStories(stories: edition.secondaryStories)

                        SamizdatSeparator()
                            .padding(.vertical, 10)
                    }

                    // Character fate (truth version)
                    if let fate = edition.characterFateReport {
                        SamizdatFate(fate: fate)

                        SamizdatSeparator()
                            .padding(.vertical, 10)
                    }

                    // Warning/propaganda slot - used for samizdat warnings
                    if let warning = edition.propagandaPiece {
                        SamizdatWarning(text: warning)
                    }

                    // Continue button
                    SamizdatContinueButton(action: onContinue)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .background(SamizdatColors.paper)
    }
}

// MARK: - Header

private struct SamizdatHeader: View {
    let name: String
    let date: String

    var body: some View {
        VStack(spacing: 6) {
            // Publication name - typewriter style
            Text(name.uppercased())
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(SamizdatColors.ink)

            // Carbon copy aesthetic
            HStack {
                Text("COPY NO. \(Int.random(in: 1...7))")
                Spacer()
                Text(date)
                Spacer()
                Text("PASS ON")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(SamizdatColors.ink.opacity(0.6))

            // Typed underline
            Text(String(repeating: "=", count: 40))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(SamizdatColors.ink.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SamizdatColors.paper)
    }
}

// MARK: - Headline

private struct SamizdatHeadline: View {
    let story: HeadlineStory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main headline - emphasized typewriter
            Text(story.headline)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(SamizdatColors.ink)
                .lineSpacing(2)

            // Subheadline
            if let subheadline = story.subheadline {
                Text(">> \(subheadline)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .italic()
                    .foregroundColor(SamizdatColors.ink.opacity(0.8))
            }

            // Body text - typewriter
            Text(story.body)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(SamizdatColors.ink.opacity(0.9))
                .lineSpacing(4)
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Stories

private struct SamizdatStories: View {
    let stories: [NewspaperStory]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("[ WHAT THEY WON'T TELL YOU ]")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(SamizdatColors.ink)

            ForEach(stories) { story in
                VStack(alignment: .leading, spacing: 4) {
                    Text("* \(story.headline)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(SamizdatColors.ink)

                    Text(story.brief)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(SamizdatColors.ink.opacity(0.8))
                        .lineSpacing(2)
                }
            }
        }
    }
}

// MARK: - Character Fate

private struct SamizdatFate: View {
    let fate: CharacterFateReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("[ THE TRUTH ABOUT ]")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(SamizdatColors.ink)

            VStack(alignment: .leading, spacing: 2) {
                Text(fate.characterName.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))

                if let title = fate.characterTitle {
                    Text("(\(title))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(SamizdatColors.ink.opacity(0.7))
                }
            }

            Text(fate.fullReport)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(SamizdatColors.ink.opacity(0.9))
                .lineSpacing(3)
                .padding(.top, 2)
        }
    }
}

// MARK: - Warning

private struct SamizdatWarning: View {
    let text: String

    var body: some View {
        VStack {
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(SamizdatColors.warning)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .foregroundColor(SamizdatColors.warning.opacity(0.5))
                )
        }
    }
}

// MARK: - Separator

private struct SamizdatSeparator: View {
    var body: some View {
        Text(String(repeating: "-", count: 45))
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(SamizdatColors.ink.opacity(0.3))
    }
}

// MARK: - Continue Button

private struct SamizdatContinueButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("[ DESTROY AFTER READING ]")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundColor(SamizdatColors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(SamizdatColors.paper)
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 3]))
                        .foregroundColor(SamizdatColors.ink)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Colors

private enum SamizdatColors {
    static let paper = Color(hex: "E8E4D8")      // Rough paper, slightly grey
    static let ink = Color(hex: "2C2C2C")        // Typewriter ink, not pure black
    static let warning = Color(hex: "8B4513")    // Brown/sepia warning color
}

// MARK: - Preview

#Preview("Samizdat") {
    let edition = NewspaperEdition(
        turnNumber: 14,
        publicationDate: "III.1960",
        publicationName: "The Chronicle",
        publicationType: .samizdat,
        headline: HeadlineStory(
            headline: "BREAD LINES GROW AS FOOD CRISIS WORSENS",
            subheadline: "State newspapers claim record harvests while children go hungry",
            body: "Despite official reports of agricultural success, sources across the capital report severe shortages. Ration cards now cover less than half of basic needs. Current food supply assessment: 32% of minimum requirements met.",
            category: .economic
        ),
        secondaryStories: [
            NewspaperStory(
                headline: "YOUR FACTION LOSES INFLUENCE",
                brief: "The reformists find themselves increasingly marginalized. Power: 28%",
                importance: 4
            )
        ],
        characterFateReport: CharacterFateReport(
            characterName: "Deputy Minister Kowalski",
            characterTitle: "Ministry of Heavy Industry",
            fateType: .disappeared,
            euphemism: "The truth behind the official story",
            fullReport: "Kowalski did not simply 'retire for health reasons' as state media claims. Sources report he was taken from his home by Bureau of People's Security agents. His current whereabouts remain unknown.",
            isRehabilitating: false
        ),
        propagandaPiece: "DESTROY AFTER READING. Possession of this document is a crime against the state."
    )

    return SamizdatView(edition: edition) {
        print("Continue tapped")
    }
}
