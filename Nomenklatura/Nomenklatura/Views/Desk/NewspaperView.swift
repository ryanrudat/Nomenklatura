//
//  NewspaperView.swift
//  Nomenklatura
//
//  Newspaper display view - Stitch-inspired Soviet press aesthetic
//

import SwiftUI

struct NewspaperView: View {
    let edition: NewspaperEdition
    var game: Game? = nil
    let onContinue: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Game Status Bar (Stitch-style HUD)
            NewspaperStatusBar(game: game, date: edition.publicationDate)

            // Scrollable newspaper content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Masthead
                    NewspaperMasthead(
                        name: edition.publicationName,
                        date: edition.publicationDate,
                        volumeNumber: edition.turnNumber
                    )

                    // Hero headline section
                    HeroHeadlineSection(story: edition.headline)

                    // Divider
                    NewspaperDivider()
                        .padding(.vertical, 8)

                    // Propaganda box (if present) - moved up for impact
                    if let propaganda = edition.propagandaPiece {
                        PropagandaBox(text: propaganda)
                            .padding(.bottom, 12)
                    }

                    // Secondary stories
                    if !edition.secondaryStories.isEmpty {
                        SecondaryStoriesSection(stories: edition.secondaryStories)
                            .padding(.bottom, 12)
                    }

                    // Character fate report (if present)
                    if let fate = edition.characterFateReport {
                        NewspaperDivider(opacity: 0.3)
                            .padding(.bottom, 12)

                        CharacterFateSection(fate: fate, game: game)
                            .padding(.bottom, 12)
                    }

                    // International news (if present)
                    if let international = edition.internationalNews {
                        NewspaperDivider(opacity: 0.3)
                            .padding(.bottom, 12)

                        InternationalSection(news: international)
                            .padding(.bottom, 12)
                    }

                    // Spacer for bottom nav
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
            }
            .background(NewspaperColors.paper)

            // Industrial bottom bar
            NewspaperBottomBar(action: onContinue)
        }
        .background(NewspaperColors.paper)
    }
}

// MARK: - Status Bar (Game HUD)

private struct NewspaperStatusBar: View {
    var game: Game?
    let date: String

    var body: some View {
        HStack {
            // Date
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                Text(date.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
            }

            Spacer()

            // DEFCON-style indicator (based on stability)
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(NewspaperColors.red)
                Text(alertLevel)
                    .font(.system(size: 11, weight: .bold))
            }

            Spacer()

            // Treasury
            HStack(spacing: 4) {
                Image(systemName: "banknote")
                    .font(.system(size: 14))
                Text(treasuryDisplay)
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .foregroundColor(NewspaperColors.paperLight)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(NewspaperColors.ink)
    }

    private var alertLevel: String {
        guard let game = game else { return "STABLE" }
        switch game.stability {
        case 0..<30: return "CRISIS"
        case 30..<50: return "TENSE"
        case 50..<70: return "ALERT"
        default: return "STABLE"
        }
    }

    private var treasuryDisplay: String {
        guard let game = game else { return "—" }
        if game.treasury >= 1000 {
            return "\(game.treasury / 1000)B"
        } else {
            return "\(game.treasury)M"
        }
    }
}

// MARK: - Masthead (Stitch-style)

private struct NewspaperMasthead: View {
    let name: String
    let date: String
    let volumeNumber: Int

    var body: some View {
        VStack(spacing: 0) {
            // Volume and Price line
            HStack {
                Text("VOL. \(volumeNumber)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .opacity(0.7)
                Spacer()
                Text("PRICE: 3 KOPEKS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .opacity(0.7)
            }
            .foregroundColor(NewspaperColors.ink)
            .padding(.bottom, 8)

            // Top border
            Rectangle()
                .fill(NewspaperColors.ink)
                .frame(height: 2)

            // Publication name
            Text(name.uppercased())
                .font(.custom("PlayfairDisplay-Black", size: 48, relativeTo: .largeTitle))
                .tracking(-2)
                .foregroundColor(NewspaperColors.ink)
                .padding(.vertical, 8)

            // Subtitle with decorative lines
            HStack(spacing: 8) {
                Rectangle()
                    .fill(NewspaperColors.ink.opacity(0.4))
                    .frame(width: 32, height: 1)

                Text("ORGAN OF THE CENTRAL COMMITTEE OF THE PWP")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(NewspaperColors.ink.opacity(0.8))

                Rectangle()
                    .fill(NewspaperColors.ink.opacity(0.4))
                    .frame(width: 32, height: 1)
            }

            // Bottom border (thicker)
            Rectangle()
                .fill(NewspaperColors.ink)
                .frame(height: 4)
                .padding(.top, 8)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

// MARK: - Hero Headline Section

private struct HeroHeadlineSection: View {
    let story: HeadlineStory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main headline
            Text(story.headline.uppercased())
                .font(.custom("PlayfairDisplay-ExtraBold", size: 28, relativeTo: .title))
                .tracking(-0.5)
                .foregroundColor(NewspaperColors.ink)
                .lineSpacing(-4)
                .fixedSize(horizontal: false, vertical: true)

            // Hero image placeholder with halftone effect
            HeroImageView()

            // Dateline and lead paragraph
            VStack(alignment: .leading, spacing: 8) {
                // Dateline
                HStack(spacing: 8) {
                    Text("WASHINGTON —")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(NewspaperColors.red)

                    Text("STATE WIRE")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(NewspaperColors.ink.opacity(0.6))
                }

                // Lead paragraph with drop cap effect
                DropCapText(text: story.body)
            }

            // Subheadline (if present)
            if let subheadline = story.subheadline {
                Text(subheadline)
                    .font(.custom("Georgia-Italic", size: 14, relativeTo: .subheadline))
                    .foregroundColor(NewspaperColors.ink.opacity(0.85))
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Hero Image with Halftone Effect

private struct HeroImageView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Placeholder industrial image
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            NewspaperColors.ink.opacity(0.3),
                            NewspaperColors.ink.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 180)
                .overlay(
                    // Factory silhouette placeholder
                    VStack {
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                Rectangle()
                                    .fill(NewspaperColors.ink.opacity(0.6))
                                    .frame(width: CGFloat.random(in: 20...40), height: CGFloat.random(in: 60...120))
                            }
                        }
                        .padding(.bottom, 40)
                    }
                )
                .overlay(
                    // Halftone dot pattern overlay
                    HalftoneOverlay()
                )

            // Caption bar
            HStack {
                Text("GLORIOUS VICTORY FOR THE PROLETARIAT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(NewspaperColors.ink.opacity(0.9))
        }
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(NewspaperColors.ink, lineWidth: 2)
        )
    }
}

// MARK: - Halftone Overlay Effect

private struct HalftoneOverlay: View {
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 2
            let spacing: CGFloat = 4

            for x in stride(from: 0, to: size.width, by: spacing) {
                for y in stride(from: 0, to: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.black.opacity(0.15))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Drop Cap Text

private struct DropCapText: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Drop cap (first letter)
            if let firstChar = text.first {
                Text(String(firstChar))
                    .font(.custom("PlayfairDisplay-Black", size: 56, relativeTo: .largeTitle))
                    .foregroundColor(NewspaperColors.ink)
                    .lineLimit(1)
                    .frame(width: 44, alignment: .leading)
                    .padding(.top, -8)
            }

            // Rest of text
            let remainingText = text.dropFirst()
            Text(String(remainingText))
                .font(.custom("Georgia", size: 15, relativeTo: .body))
                .foregroundColor(NewspaperColors.ink)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Propaganda Box (Stitch-style)

private struct PropagandaBox: View {
    let text: String

    var body: some View {
        VStack {
            Text(text)
                .font(.system(size: 16, weight: .black))
                .italic()
                .tracking(0.5)
                .multilineTextAlignment(.center)
                .foregroundColor(NewspaperColors.red)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
        }
        .background(NewspaperColors.red.opacity(0.05))
        .overlay(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(NewspaperColors.red)
                    .frame(height: 2)
                Spacer()
                Rectangle()
                    .fill(NewspaperColors.red)
                    .frame(height: 2)
            }
        )
    }
}

// MARK: - Secondary Stories Section (Stitch-style)

private struct SecondaryStoriesSection: View {
    let stories: [NewspaperStory]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.headline.uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(NewspaperColors.ink)

                    Text(story.brief)
                        .font(.custom("Georgia", size: 12, relativeTo: .caption))
                        .foregroundColor(NewspaperColors.ink.opacity(0.7))
                        .lineSpacing(2)
                        .lineLimit(3)
                }

                // Divider between stories (not after last)
                if index < stories.count - 1 {
                    Rectangle()
                        .fill(NewspaperColors.ink.opacity(0.2))
                        .frame(width: 100, height: 1)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Character Fate Section

private struct CharacterFateSection: View {
    let fate: CharacterFateReport
    var game: Game? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 8) {
                Text("PERSONNEL MATTERS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(NewspaperColors.ink)

                if fate.isRehabilitating {
                    Text("CORRECTION")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(NewspaperColors.red.opacity(0.15))
                        .foregroundColor(NewspaperColors.red)
                }
            }

            // Character info
            VStack(alignment: .leading, spacing: 2) {
                if let game = game {
                    TappableName(name: fate.characterName, game: game)
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Text(fate.characterName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(NewspaperColors.ink)
                }

                if let title = fate.characterTitle {
                    Text(title)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(NewspaperColors.ink.opacity(0.6))
                }
            }

            // Euphemism
            Text("— \(fate.euphemism)")
                .font(.custom("Georgia-Italic", size: 12, relativeTo: .caption))
                .foregroundColor(NewspaperColors.ink.opacity(0.75))

            // Full report
            Text(fate.fullReport)
                .font(.custom("Georgia", size: 12, relativeTo: .caption))
                .foregroundColor(NewspaperColors.ink.opacity(0.85))
                .lineSpacing(2)
        }
    }
}

// MARK: - International Section

private struct InternationalSection: View {
    let news: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INTERNATIONAL")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundColor(NewspaperColors.ink)

            Text(news)
                .font(.custom("Georgia", size: 12, relativeTo: .caption))
                .foregroundColor(NewspaperColors.ink.opacity(0.85))
                .lineSpacing(2)
        }
    }
}

// MARK: - Newspaper Divider

private struct NewspaperDivider: View {
    var opacity: Double = 1.0

    var body: some View {
        Rectangle()
            .fill(NewspaperColors.ink.opacity(opacity))
            .frame(height: 1)
    }
}

// MARK: - Industrial Bottom Bar (Stitch-style)

private struct NewspaperBottomBar: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top border accent
            Rectangle()
                .fill(NewspaperColors.ink)
                .frame(height: 4)

            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 18))

                    Text("PUT ASIDE NEWSPAPER")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                }
                .foregroundColor(NewspaperColors.paperLight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
        }
        .background(NewspaperColors.ink)
    }
}

// MARK: - Colors (Stitch-aligned)

private enum NewspaperColors {
    static let paper = Color(hex: "F5F0E1")           // Aged newsprint
    static let paperLight = Color(hex: "FDFBF7")      // Light paper for dark backgrounds
    static let ink = Color(hex: "141414")             // Deep ink (Stitch)
    static let red = Color(hex: "B82E2E")             // Soviet red (Stitch)
}

// MARK: - Previews

#Preview("Full Newspaper - Stitch Style") {
    let edition = NewspaperEdition(
        turnNumber: 42,
        publicationDate: "12 OCT 1982",
        publicationName: "The People's Weekly",
        headline: HeadlineStory(
            headline: "PREMIER ANNOUNCES FIVE-YEAR PLAN TRIUMPH",
            subheadline: "Steel Production Rises 12% Across the Urals",
            body: "In a decisive address to the Supreme Soviet, the Premier declared the latest industrial quotas not merely met, but shattered. Steel production has risen by 12% across the Urals, signaling a new era of dominance against Western imperialism.",
            category: .political
        ),
        secondaryStories: [
            NewspaperStory(
                headline: "Border Security Tightened",
                brief: "New directives from the Politburo authorize increased patrols along the Western frontier. Citizens are reminded to report suspicious activity.",
                importance: 3
            ),
            NewspaperStory(
                headline: "Space Program Update",
                brief: "Cosmonauts successfully docked with the orbital station, marking another victory in the race for the stars.",
                importance: 2
            )
        ],
        characterFateReport: CharacterFateReport(
            characterName: "Deputy Minister Kowalski",
            characterTitle: "Ministry of Heavy Industry",
            fateType: .reassigned,
            euphemism: "transferred to other important work",
            fullReport: "Deputy Minister Kowalski has been reassigned to contribute his expertise to agricultural mechanization efforts in the Virgin Lands.",
            isRehabilitating: false
        ),
        internationalNews: "Western powers continue to refuse reasonable proposals for nuclear disarmament, exposing the aggressive nature of imperialist policy.",
        propagandaPiece: "\"Vigilance is our weapon against the West.\""
    )

    return NewspaperView(edition: edition) {
        print("Continue tapped")
    }
}

#Preview("Minimal Newspaper") {
    let edition = NewspaperEdition(
        turnNumber: 5,
        publicationDate: "8 SEP 1958",
        publicationName: "The People's Voice",
        headline: HeadlineStory(
            headline: "HARVEST COLLECTION PROCEEDS SUCCESSFULLY",
            subheadline: "Collective Farms Report Strong Yields",
            body: "Agricultural officials report satisfactory progress in grain collection. The application of advanced techniques continues to improve productivity across collective farms.",
            category: .economic
        )
    )

    return NewspaperView(edition: edition) {
        print("Continue tapped")
    }
}
