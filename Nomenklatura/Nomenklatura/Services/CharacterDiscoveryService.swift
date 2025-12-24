//
//  CharacterDiscoveryService.swift
//  Nomenklatura
//
//  Living Character System - Detects new characters from AI narratives
//  and creates GameCharacter objects for them
//

import Foundation

// MARK: - Character Discovery Service

class CharacterDiscoveryService {
    static let shared = CharacterDiscoveryService()

    /// Common title prefixes to strip when comparing names
    private let titlePrefixes = [
        "comrade", "minister", "deputy", "marshal", "general", "colonel",
        "director", "chairman", "secretary", "commissar", "citizen",
        "doctor", "professor", "chief", "head", "senior", "junior"
    ]

    /// Maximum number of discovered characters to track (prevents overflow)
    private let maxDiscoveredCharacters = 15

    // MARK: - Public API

    /// Process characters from an AI scenario response
    /// Returns newly created GameCharacter objects (not yet added to game.characters)
    func processCharactersFromScenario(
        metadata: ScenarioNarrativeMetadata,
        presenterName: String?,
        presenterTitle: String?,
        briefingText: String,
        game: Game,
        turnNumber: Int
    ) -> [GameCharacter] {
        var newCharacters: [GameCharacter] = []

        // Count existing discovered characters
        let existingDiscoveredCount = game.characters.filter { $0.wasDiscoveredDynamically }.count
        guard existingDiscoveredCount < maxDiscoveredCharacters else {
            return []  // Cap reached
        }

        // Process each character mentioned
        for name in metadata.charactersInvolved {
            // Skip empty names
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            // Check if this character already exists
            if findExistingCharacter(name: name, in: game.characters) != nil {
                continue  // Already known
            }

            // Find character details if available
            let details = metadata.characterDetails.first { namesMatch($0.name, name) }

            // Create new character
            let character = createCharacter(
                name: name,
                details: details,
                presenterName: presenterName,
                presenterTitle: presenterTitle,
                briefingText: briefingText,
                turnNumber: turnNumber
            )

            newCharacters.append(character)

            // Stop if we've reached the cap
            if existingDiscoveredCount + newCharacters.count >= maxDiscoveredCharacters {
                break
            }
        }

        return newCharacters
    }

    /// Update lastAppearedTurn for all characters involved in a scenario
    func updateCharacterAppearances(
        characterNames: [String],
        game: Game,
        turnNumber: Int
    ) {
        for name in characterNames {
            if let character = findExistingCharacter(name: name, in: game.characters) {
                character.lastAppearedTurn = turnNumber
            }
        }
    }

    /// Find an existing character by name (with fuzzy matching)
    func findExistingCharacter(name: String, in characters: [GameCharacter]) -> GameCharacter? {
        // Exact match first
        if let exact = characters.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return exact
        }

        // Fuzzy match - strip prefixes and compare
        let normalizedName = normalizeName(name)
        for character in characters {
            let normalizedCharName = normalizeName(character.name)
            if normalizedName == normalizedCharName {
                return character
            }
            // Check if one contains the other (e.g., "Wallace" matches "Minister Wallace")
            if normalizedName.contains(normalizedCharName) || normalizedCharName.contains(normalizedName) {
                // Only match if the contained part is substantial (> 4 chars)
                let shorter = min(normalizedName.count, normalizedCharName.count)
                if shorter >= 4 {
                    return character
                }
            }
        }

        return nil
    }

    /// Check if two names refer to the same person
    func namesMatch(_ name1: String, _ name2: String) -> Bool {
        let n1 = normalizeName(name1)
        let n2 = normalizeName(name2)

        if n1 == n2 { return true }
        if n1.contains(n2) || n2.contains(n1) {
            let shorter = min(n1.count, n2.count)
            return shorter >= 4
        }
        return false
    }

    // MARK: - Private Helpers

    /// Normalize a name by removing common prefixes and lowercasing
    private func normalizeName(_ name: String) -> String {
        var normalized = name.lowercased().trimmingCharacters(in: .whitespaces)

        // Remove common title prefixes
        for prefix in titlePrefixes {
            if normalized.hasPrefix(prefix + " ") {
                normalized = String(normalized.dropFirst(prefix.count + 1))
                break
            }
        }

        return normalized.trimmingCharacters(in: .whitespaces)
    }

    /// Create a new GameCharacter from discovered information
    private func createCharacter(
        name: String,
        details: CharacterDetail?,
        presenterName: String?,
        presenterTitle: String?,
        briefingText: String,
        turnNumber: Int
    ) -> GameCharacter {
        // Determine title
        var title: String? = details?.title

        // If this is the presenter and we don't have a title, use presenter title
        if title == nil && presenterName != nil && namesMatch(name, presenterName!) {
            title = presenterTitle
        }

        // If still no title, try to extract from briefing
        if title == nil {
            title = extractTitleFromContext(name: name, briefingText: briefingText)
        }

        // Determine role and disposition
        let role = details?.suggestedRole ?? inferRoleFromContext(name: name, briefingText: briefingText)
        let disposition = details?.initialDisposition ?? inferDispositionFromContext(name: name, briefingText: briefingText)

        // Create the character
        let character = GameCharacter(
            name: name,
            title: title,
            role: role,
            introducedTurn: turnNumber,
            disposition: disposition
        )

        // Set random personality (hidden until revealed)
        character.personalityAmbitious = Int.random(in: 30...70)
        character.personalityParanoid = Int.random(in: 30...70)
        character.personalityRuthless = Int.random(in: 30...70)
        character.personalityCompetent = Int.random(in: 40...80)
        character.personalityLoyal = Int.random(in: 30...70)
        character.personalityCorrupt = Int.random(in: 20...60)

        // Set aggression based on role
        switch role {
        case .rival:
            character.aggressionLevel = Int.random(in: 60...90)
        case .ally:
            character.aggressionLevel = Int.random(in: 30...50)
        default:
            character.aggressionLevel = Int.random(in: 40...60)
        }

        return character
    }

    /// Try to extract a title from the briefing text
    private func extractTitleFromContext(name: String, briefingText: String) -> String? {
        let text = briefingText.lowercased()
        let nameLower = name.lowercased()

        // Common patterns: "Minister Wallace", "Wallace, the Director", "Deputy Director Wallace"
        let patterns = [
            "minister", "deputy", "director", "chairman", "secretary",
            "general", "marshal", "colonel", "major", "captain",
            "commissar", "inspector", "chief", "head"
        ]

        for pattern in patterns {
            // Check "Title Name" pattern
            if text.contains("\(pattern) \(nameLower)") ||
               text.contains("\(pattern) \(normalizeName(name))") {
                return pattern.capitalized
            }
            // Check "Name, the Title" pattern
            if text.contains("\(nameLower), the \(pattern)") ||
               text.contains("\(normalizeName(name)), the \(pattern)") {
                return pattern.capitalized
            }
        }

        return nil
    }

    /// Infer role from context clues in the briefing
    private func inferRoleFromContext(name: String, briefingText: String) -> CharacterRole {
        let text = briefingText.lowercased()
        let nameLower = normalizeName(name)

        // Check for ally indicators
        let allyWords = ["friend", "ally", "supporter", "loyal", "trusted", "faithful"]
        for word in allyWords {
            if text.contains("\(nameLower)") && text.contains(word) {
                return .ally
            }
        }

        // Check for antagonist indicators
        let antagonistWords = ["rival", "enemy", "opponent", "threat", "hostile", "dangerous"]
        for word in antagonistWords {
            if text.contains("\(nameLower)") && text.contains(word) {
                return .rival
            }
        }

        // Check for authority indicators
        let authorityWords = ["orders", "commands", "demands", "superior", "authority"]
        for word in authorityWords {
            if text.contains("\(nameLower)") && text.contains(word) {
                return .leader
            }
        }

        return .neutral
    }

    /// Infer initial disposition from context clues
    private func inferDispositionFromContext(name: String, briefingText: String) -> Int {
        let text = briefingText.lowercased()
        let nameLower = normalizeName(name)

        // Check for positive indicators
        let positiveWords = ["friend", "ally", "supporter", "grateful", "appreciates", "thanks", "helpful"]
        for word in positiveWords {
            if text.contains("\(nameLower)") && text.contains(word) {
                return Int.random(in: 60...75)
            }
        }

        // Check for negative indicators
        let negativeWords = ["rival", "enemy", "hostile", "threatens", "angry", "furious", "suspicious"]
        for word in negativeWords {
            if text.contains("\(nameLower)") && text.contains(word) {
                return Int.random(in: 25...40)
            }
        }

        // Check for wary/cautious indicators
        let waryWords = ["cautious", "wary", "careful", "guarded", "uncertain"]
        for word in waryWords {
            if text.contains("\(nameLower)") && text.contains(word) {
                return Int.random(in: 40...50)
            }
        }

        // Default neutral
        return Int.random(in: 45...55)
    }
}
