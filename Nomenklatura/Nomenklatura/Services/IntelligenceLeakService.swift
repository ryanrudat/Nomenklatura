//
//  IntelligenceLeakService.swift
//  Nomenklatura
//
//  Service for generating random intelligence leak events based on Network stat
//  Higher Network = more frequent and better quality leaks
//

import Foundation

// MARK: - Intelligence Leak Types

enum IntelligenceQuality: String, Codable {
    case low       // Network 30+ - Informant tips, rumors
    case medium    // Network 50+ - Document leaks, internal memos
    case high      // Network 70+ - High-level source access

    var displayName: String {
        switch self {
        case .low: return "Informant Tip"
        case .medium: return "Leaked Document"
        case .high: return "High-Level Source"
        }
    }
}

struct IntelligenceLeak {
    let quality: IntelligenceQuality
    let title: String
    let content: String
    let relatedCharacterId: String?
    let relatedFactionId: String?
    let revealsHistoricalSecrets: Bool
}

// MARK: - Intelligence Leak Service

final class IntelligenceLeakService {
    static let shared = IntelligenceLeakService()

    private init() {}

    // MARK: - Public Methods

    /// Try to generate a leak event based on Network stat
    /// Returns a leak if conditions are met, nil otherwise
    func tryGenerateLeakEvent(for game: Game) -> IntelligenceLeak? {
        let network = game.network

        // Minimum threshold for any leaks
        guard network >= 30 else { return nil }

        // Calculate probability based on Network
        // Base 10% at Network 30, up to 35% at Network 100
        let baseProbability = 0.10
        let networkBonus = Double(network - 30) / 280.0  // 0 to 0.25 bonus
        let probability = baseProbability + networkBonus

        // Roll for leak
        guard Double.random(in: 0...1) < probability else { return nil }

        // Determine quality
        let quality = determineQuality(network: network)

        // Generate appropriate leak
        return generateLeak(quality: quality, game: game)
    }

    /// Generate a specific type of leak (for testing or scripted events)
    func generateSpecificLeak(quality: IntelligenceQuality, game: Game) -> IntelligenceLeak {
        return generateLeak(quality: quality, game: game)
    }

    // MARK: - Quality Determination

    private func determineQuality(network: Int) -> IntelligenceQuality {
        if network >= 70 && Double.random(in: 0...1) < 0.3 {
            return .high
        } else if network >= 50 && Double.random(in: 0...1) < 0.5 {
            return .medium
        } else {
            return .low
        }
    }

    // MARK: - Leak Generation

    private func generateLeak(quality: IntelligenceQuality, game: Game) -> IntelligenceLeak {
        switch quality {
        case .low:
            return generateLowQualityLeak(game: game)
        case .medium:
            return generateMediumQualityLeak(game: game)
        case .high:
            return generateHighQualityLeak(game: game)
        }
    }

    private func generateLowQualityLeak(game: Game) -> IntelligenceLeak {
        let leaks: [(title: String, content: String, character: Bool, faction: Bool)] = [
            (
                "Whispers in the Corridor",
                "An informant reports overhearing heated arguments coming from the Ministry of Finance. \"Something about missing funds,\" they say. \"Names were mentioned but I couldn't hear clearly.\"",
                false, false
            ),
            (
                "Suspicious Meetings",
                "Your network reports that certain senior officials have been meeting privately at a dacha outside the city. The meetings occur late at night, away from official eyes.",
                false, true
            ),
            (
                "Grumblings in the Ranks",
                "A low-level informant passes word that junior cadres are dissatisfied with recent policy changes. Nothing organized yet, but the atmosphere is tense.",
                false, false
            ),
            (
                "Nervous Behavior",
                "One of your contacts reports that a prominent official has been acting strangely—burning documents late at night and receiving coded phone calls.",
                true, false
            ),
            (
                "Foreign Contact Rumors",
                "Unverified reports suggest that someone in the upper ranks has been meeting with foreign diplomats outside official channels. The details are murky.",
                false, false
            )
        ]

        let selected = leaks.randomElement()!
        var characterId: String? = nil
        var factionId: String? = nil

        if selected.character {
            characterId = game.characters.filter { $0.isAlive && ($0.positionIndex ?? 0) >= 4 }
                .randomElement()?.templateId
        }
        if selected.faction {
            factionId = game.factions.randomElement()?.factionId
        }

        return IntelligenceLeak(
            quality: .low,
            title: selected.title,
            content: selected.content,
            relatedCharacterId: characterId,
            relatedFactionId: factionId,
            revealsHistoricalSecrets: false
        )
    }

    private func generateMediumQualityLeak(game: Game) -> IntelligenceLeak {
        // Try to leak faction scheming or character information
        if Bool.random() {
            return generateFactionSchemeLeaks(game: game)
        } else {
            return generateCharacterSecretLeak(game: game)
        }
    }

    private func generateFactionSchemeLeaks(game: Game) -> IntelligenceLeak {
        let factions = game.factions
        guard let faction = factions.randomElement() else {
            return generateGenericMediumLeak()
        }

        let schemes: [String] = [
            "\(faction.name) operatives have been quietly building support among provincial committees. Internal memos suggest they're positioning for influence at the next Party Congress.",
            "A leaked document reveals that \(faction.name) leadership has been cultivating relationships with key military figures. The implications are concerning.",
            "Your contact obtained minutes from a \(faction.name) strategy meeting. They're planning to challenge current policy on economic reform at the next Central Committee plenum.",
            "Sources within \(faction.name) confirm they've identified several \"unreliable\" officials for removal. Your name was not mentioned, but caution is advised."
        ]

        return IntelligenceLeak(
            quality: .medium,
            title: "Faction Intelligence: \(faction.name)",
            content: schemes.randomElement()!,
            relatedCharacterId: nil,
            relatedFactionId: faction.factionId,
            revealsHistoricalSecrets: false
        )
    }

    private func generateCharacterSecretLeak(game: Game) -> IntelligenceLeak {
        let candidates = game.characters.filter {
            $0.isAlive && ($0.positionIndex ?? 0) >= 4 && !$0.isFullyRevealed
        }

        guard let character = candidates.randomElement() else {
            return generateGenericMediumLeak()
        }

        let secrets: [(trait: String, content: String)] = [
            ("ambition", "\(character.name) has been quietly meeting with foreign journalists. Sources suggest they're positioning for a leadership role and building an international profile."),
            ("paranoia", "A leaked security report reveals that \(character.name) maintains personal files on numerous colleagues, including detailed notes on their weaknesses and vulnerabilities."),
            ("corruption", "Financial documents obtained by your network show irregular transfers to accounts linked to \(character.name)'s relatives. The amounts are substantial."),
            ("loyalty", "Intercepted correspondence suggests \(character.name) has been privately critical of current leadership, expressing doubts about the Party's direction."),
            ("competence", "Internal performance reviews reveal that \(character.name)'s department has been falsifying production statistics. The discrepancies are significant.")
        ]

        let selected = secrets.randomElement()!

        return IntelligenceLeak(
            quality: .medium,
            title: "Character Dossier: \(character.name)",
            content: selected.content,
            relatedCharacterId: character.templateId,
            relatedFactionId: nil,
            revealsHistoricalSecrets: false
        )
    }

    private func generateGenericMediumLeak() -> IntelligenceLeak {
        return IntelligenceLeak(
            quality: .medium,
            title: "Internal Memorandum",
            content: "A classified memo circulating within the security apparatus suggests that an investigation into \"irregularities\" at the highest levels is being quietly prepared. No names are mentioned, but the scope appears broad.",
            relatedCharacterId: nil,
            relatedFactionId: nil,
            revealsHistoricalSecrets: false
        )
    }

    private func generateHighQualityLeak(game: Game) -> IntelligenceLeak {
        // High quality leaks can reveal historical secrets or major plot information
        if Bool.random() {
            return generateHistoricalSecretLeak(game: game)
        } else {
            return generateHighLevelSourceLeak(game: game)
        }
    }

    private func generateHistoricalSecretLeak(game: Game) -> IntelligenceLeak {
        let secrets: [(title: String, content: String)] = [
            (
                "Declassified Archive Fragment",
                "A sympathetic archivist has provided documents from the Great Purge era. The files reveal that many \"confessions\" were extracted through methods the Party has never publicly acknowledged. Several current officials had family members among the victims."
            ),
            (
                "Secret Protocol Uncovered",
                "Your high-level source has obtained a copy of secret protocols from Year 17. The documents show that purge quotas were negotiated between central and regional authorities—with specific numbers for executions and imprisonments."
            ),
            (
                "War-Era Cover-Up",
                "Previously classified reports from the Great Patriotic War reveal that certain military disasters were caused by direct interference from Party leadership, not \"enemy action\" as officially claimed. The responsible officials were quietly promoted, not punished."
            ),
            (
                "Succession Struggle Documents",
                "Internal communications from the period following the Leader's death have been leaked. They reveal intense maneuvering and threats among the current senior leadership—including compromising arrangements that still bind certain factions together."
            ),
            (
                "Economic Falsification Records",
                "Archive documents prove that Five-Year Plan achievements were systematically exaggerated. The actual figures suggest the economy performed far worse than publicly acknowledged. Current policies are built on these false foundations."
            )
        ]

        let selected = secrets.randomElement()!

        return IntelligenceLeak(
            quality: .high,
            title: selected.title,
            content: selected.content,
            relatedCharacterId: nil,
            relatedFactionId: nil,
            revealsHistoricalSecrets: true
        )
    }

    private func generateHighLevelSourceLeak(game: Game) -> IntelligenceLeak {
        let seniorCharacters = game.characters.filter {
            $0.isAlive && ($0.positionIndex ?? 0) >= 7
        }

        let character = seniorCharacters.randomElement()

        let leaks: [(title: String, content: String)] = [
            (
                "Standing Committee Deliberations",
                "A source within the inner circle reports that the Standing Committee is deeply divided on the question of economic reform. Heated exchanges have occurred behind closed doors, with some members threatening to take disputes public."
            ),
            (
                "Security Assessment",
                "Your contact in the security services has obtained a highly classified threat assessment. The report identifies several senior officials as potential \"security risks\" and recommends enhanced surveillance."
            ),
            (
                "Succession Planning",
                "Sources at the highest levels indicate that informal discussions about leadership succession have begun. Several candidates are being quietly evaluated, though no decisions have been made."
            ),
            (
                "Foreign Intelligence Brief",
                "A leaked intelligence brief reveals that foreign powers have successfully cultivated sources within the Party apparatus. Counterintelligence is investigating, but the damage assessment remains incomplete."
            )
        ]

        let selected = leaks.randomElement()!

        return IntelligenceLeak(
            quality: .high,
            title: selected.title,
            content: selected.content,
            relatedCharacterId: character?.templateId,
            relatedFactionId: nil,
            revealsHistoricalSecrets: false
        )
    }

    // MARK: - Integration with Journal

    /// Process a leak and add it to the journal
    @MainActor
    func processLeakToJournal(leak: IntelligenceLeak, game: Game) {
        JournalService.shared.onSecretIntelligence(
            title: leak.title,
            content: leak.content,
            relatedCharacterId: leak.relatedCharacterId,
            game: game
        )
    }
}
