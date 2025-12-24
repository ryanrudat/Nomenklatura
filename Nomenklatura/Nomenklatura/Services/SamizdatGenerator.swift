//
//  SamizdatGenerator.swift
//  Nomenklatura
//
//  Generates underground samizdat publications that tell the "real" story
//

import Foundation

final class SamizdatGenerator {
    static let shared = SamizdatGenerator()

    private init() {}

    // MARK: - Check Availability

    /// Whether samizdat is available to the player
    func isSamizdatAvailable(for game: Game) -> Bool {
        // Must have some underground network
        guard game.network >= 30 else { return false }

        // Must have underground contact flag or high network
        if game.flags.contains("underground_contact") {
            return true
        }

        // High network alone can unlock it
        if game.network >= 50 {
            return true
        }

        return false
    }

    // MARK: - Generate Samizdat

    func generateSamizdat(for game: Game) -> NewspaperEdition {
        let headline = generateTruthHeadline(for: game)
        let secondaryStories = generateTruthStories(for: game)
        let warning = generateWarning()

        return NewspaperEdition(
            turnNumber: game.turnNumber,
            publicationDate: formatSamizdatDate(for: game.turnNumber),
            publicationName: selectPublicationName(),
            publicationType: .samizdat,
            headline: headline,
            secondaryStories: secondaryStories,
            characterFateReport: generateRealFate(for: game),
            internationalNews: nil,  // Samizdat focuses on domestic truth
            propagandaPiece: warning
        )
    }

    // MARK: - Publication Names

    private let samizdatNames = [
        "The Chronicle",
        "Voice of Truth",
        "The Witness",
        "Free America",
        "The Underground Bulletin",
        "Typed Pages",
        "Carbon Copy",
        "Whispered News"
    ]

    private func selectPublicationName() -> String {
        samizdatNames.randomElement() ?? "The Chronicle"
    }

    // MARK: - Truth Headlines (Real Stats)

    private func generateTruthHeadline(for game: Game) -> HeadlineStory {
        // Find the most pressing real crisis
        if game.foodSupply < 35 {
            return HeadlineStory(
                headline: "BREAD LINES GROW AS FOOD CRISIS WORSENS",
                subheadline: "State newspapers claim record harvests while children go hungry",
                body: "Despite official reports of agricultural success, sources across the capital report severe shortages. Ration cards now cover less than half of basic needs. Current food supply assessment: \(game.foodSupply)% of minimum requirements met.",
                category: .economic
            )
        } else if game.stability < 35 {
            return HeadlineStory(
                headline: "UNREST SPREADS DESPITE REGIME DENIALS",
                subheadline: "Workers' discontent can no longer be hidden",
                body: "What the state calls 'isolated incidents' are in fact coordinated protests across multiple provinces. The regime's grip weakens. Current stability assessment: \(game.stability)% confidence in continued control.",
                category: .political
            )
        } else if game.militaryLoyalty < 40 {
            return HeadlineStory(
                headline: "ARMY OFFICERS QUESTION LEADERSHIP",
                subheadline: "Loyalty purges backfire as discontent grows in barracks",
                body: "Military sources reveal growing disaffection among officer corps. Recent purges have demoralized rather than disciplined the armed forces. Current military loyalty: \(game.militaryLoyalty)%.",
                category: .military
            )
        } else if game.industrialOutput < 40 {
            return HeadlineStory(
                headline: "FACTORIES FAIL TO MEET EVEN BASIC QUOTAS",
                subheadline: "Five-Year Plan exposed as fantasy",
                body: "Internal documents reveal industrial production is far below official figures. Managers falsify reports to avoid punishment while infrastructure crumbles. Real industrial output: \(game.industrialOutput)% of claimed.",
                category: .economic
            )
        } else if game.eliteLoyalty < 40 {
            return HeadlineStory(
                headline: "PRESIDIUM FRACTURES BEHIND CLOSED DOORS",
                subheadline: "Faction infighting threatens Party unity",
                body: "Sources close to the leadership describe intense power struggles within the Presidium. Public unity masks private warfare. Elite cohesion currently estimated at: \(game.eliteLoyalty)%.",
                category: .political
            )
        } else {
            // General critique when nothing is critically bad
            return generateGeneralCritique(for: game)
        }
    }

    private func generateGeneralCritique(for game: Game) -> HeadlineStory {
        let critiques = [
            HeadlineStory(
                headline: "THE SYSTEM CONTINUES ITS SLOW DECAY",
                subheadline: "Neither reform nor repression can save what is broken",
                body: "Another month passes under the grey weight of the regime. Neither the true believers nor the cynics can remember what they once hoped for. The machine grinds on, serving no one.",
                category: .political
            ),
            HeadlineStory(
                headline: "TRUTH REMAINS THE FIRST CASUALTY",
                subheadline: "In a land of lies, even silence is suspect",
                body: "State newspapers report another glorious triumph. Reality tells a different story. We continue to document what the regime wishes forgotten. Pass this on. Destroy after reading.",
                category: .ideological
            ),
            HeadlineStory(
                headline: "CORRUPTION REACHES NEW DEPTHS",
                subheadline: "Those who enforce the law are themselves lawless",
                body: "Every official has their price. Every regulation its exception. The Party preaches sacrifice while its members enrich themselves. Current corruption assessment: endemic and worsening.",
                category: .domestic
            )
        ]
        return critiques.randomElement() ?? critiques[0]
    }

    // MARK: - Truth Stories

    private func generateTruthStories(for game: Game) -> [NewspaperStory] {
        var stories: [NewspaperStory] = []

        // Story about player's faction standing if relevant
        if let playerFactionId = game.playerFactionId,
           let faction = game.factions.first(where: { $0.factionId == playerFactionId }) {
            if faction.power < 30 {
                stories.append(NewspaperStory(
                    headline: "YOUR FACTION LOSES INFLUENCE",
                    brief: "The \(faction.name) finds itself increasingly marginalized. Power: \(faction.power)%",
                    importance: 4
                ))
            }
        }

        // Story about general mood
        let averageHealth = (game.stability + game.popularSupport + game.foodSupply) / 3
        if averageHealth < 50 {
            stories.append(NewspaperStory(
                headline: "PEOPLE'S MOOD DARKENS",
                brief: "Surveys we dare not publish show growing despair. Average well-being: \(averageHealth)%",
                importance: 3
            ))
        }

        // Story about treasury
        if game.treasury < 30 {
            stories.append(NewspaperStory(
                headline: "STATE COFFERS NEARLY EMPTY",
                brief: "Despite official optimism, reserves are depleted. Treasury status: \(game.treasury)%",
                importance: 4
            ))
        }

        // If no critical stories, add generic samizdat content
        if stories.isEmpty {
            stories.append(NewspaperStory(
                headline: "ANOTHER WEEK OF SILENCE",
                brief: "The regime reveals nothing. We reveal what we can.",
                importance: 2
            ))
        }

        return stories
    }

    // MARK: - Real Character Fates

    private func generateRealFate(for game: Game) -> CharacterFateReport? {
        // Check for any "disappeared" or "reassigned" characters
        let suspiciousFates = game.characters.filter { character in
            !character.isAlive ||
            (character.disposition < 20 && character.isAlive)
        }

        guard let character = suspiciousFates.first else { return nil }

        if !character.isAlive {
            return CharacterFateReport(
                characterName: character.name,
                characterTitle: character.title,
                fateType: .disappeared,
                euphemism: "The truth behind the official story",
                fullReport: "\(character.name) did not simply 'retire for health reasons' as state media claims. Sources report they were taken from their home by Bureau of People's Security agents. Their current whereabouts remain unknown. We remember them.",
                isRehabilitating: false
            )
        }

        return nil
    }

    // MARK: - Warning

    private func generateWarning() -> String {
        let warnings = [
            "⚠️ DESTROY AFTER READING. Possession of this document is a crime against the state.",
            "⚠️ PASS TO TRUSTED HANDS ONLY. The Bureau has informants everywhere.",
            "⚠️ READ. MEMORIZE. BURN. Knowledge is dangerous. Share it wisely.",
            "⚠️ THIS DOCUMENT DOES NOT EXIST. Neither do those who wrote it.",
            "⚠️ COPY AND DISTRIBUTE. Truth spreads one carbon copy at a time."
        ]
        return warnings.randomElement() ?? warnings[0]
    }

    // MARK: - Date Formatting

    private func formatSamizdatDate(for turn: Int) -> String {
        // Underground publications use simpler dating
        let baseYear = 1953
        let year = baseYear + (turn / 12)
        let month = ((turn - 1) % 12) + 1
        let months = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
        return "\(months[month - 1]).\(year)"
    }
}
