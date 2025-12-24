//
//  ClickableNarrativeText.swift
//  Nomenklatura
//
//  Renders narrative text with character names as tappable links
//  Parses text to identify known character names and makes them interactive
//  Also detects potential character names via Soviet/bureaucratic title patterns
//

import SwiftUI
import SwiftData

struct ClickableNarrativeText: View {
    let text: String
    let game: Game
    let font: Font
    let color: Color
    let lineSpacing: CGFloat

    @Environment(\.theme) var theme

    // MARK: - Soviet/Bureaucratic Title Patterns

    /// Title patterns for detecting potential character names
    private static let titlePatterns: [String] = [
        "Deputy Minister", "Vice Minister", "Assistant Minister",
        "Deputy Director", "Assistant Director",
        "First Secretary", "Deputy Secretary", "General Secretary",
        "Vice Chairman", "Deputy Chairman",
        "Deputy Commissar", "Assistant Commissar",
        "Chief Inspector", "Deputy Chief",
        "Regional Governor", "Deputy Governor",
        "Minister", "Director", "Comrade", "Citizen",
        "General", "Colonel", "Major", "Captain", "Lieutenant",
        "Secretary", "Chairman", "Commissar", "Marshal", "Admiral",
        "Professor", "Doctor", "Dr.", "Ambassador", "Envoy",
        "Inspector", "Prosecutor", "Judge", "Governor", "Chief"
    ]

    /// Compiled regex for matching title + name patterns
    private static var titleRegex: NSRegularExpression? = {
        // Escape special characters in patterns and sort by length (longest first)
        let sortedPatterns = titlePatterns.sorted { $0.count > $1.count }
        let escapedPatterns = sortedPatterns.map { NSRegularExpression.escapedPattern(for: $0) }
        let titlePattern = escapedPatterns.joined(separator: "|")
        // Match: Title + one or two capitalized words
        // e.g., "Minister Wallace", "Director Ivan Petrov", "Comrade Chen"
        let pattern = "\\b(\(titlePattern))\\s+([A-Z][a-z]+)(?:\\s+([A-Z][a-z]+))?\\b"
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    init(text: String, game: Game, font: Font = .body, color: Color = .primary, lineSpacing: CGFloat = 6) {
        self.text = text
        self.game = game
        self.font = font
        self.color = color
        self.lineSpacing = lineSpacing
    }

    /// Get all known character names from the game
    private var characterNames: [String] {
        game.characters.map { $0.name }
    }

    /// Parse text into segments (text, character name, or potential character)
    private var segments: [TextSegment] {
        parseText(text, names: characterNames)
    }

    var body: some View {
        // Use AttributedString approach for seamless text flow
        Text(attributedText)
            .font(font)
            .lineSpacing(lineSpacing)
            .environment(\.openURL, OpenURLAction { url in
                // Handle character name taps
                if url.scheme == "character" {
                    let name = url.host ?? ""
                    // The sheet will be shown by the overlay
                    NotificationCenter.default.post(
                        name: .showCharacterSheet,
                        object: name.removingPercentEncoding
                    )
                    return .handled
                } else if url.scheme == "newcharacter" {
                    let name = url.host ?? ""
                    // Create and show a new placeholder character
                    NotificationCenter.default.post(
                        name: .createAndShowCharacter,
                        object: name.removingPercentEncoding
                    )
                    return .handled
                }
                return .systemAction
            })
    }

    /// Build attributed string with tappable character names
    private var attributedText: AttributedString {
        var result = AttributedString()

        for segment in segments {
            switch segment {
            case .text(let str):
                var attr = AttributedString(str)
                attr.foregroundColor = color
                result.append(attr)

            case .characterName(let name):
                var attr = AttributedString(name)
                // Style as underlined link
                attr.foregroundColor = characterColor(for: name)
                attr.underlineStyle = .single
                // Use custom URL scheme for character links
                if let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                    attr.link = URL(string: "character://\(encoded)")
                }
                result.append(attr)

            case .potentialCharacter(let name):
                var attr = AttributedString(name)
                // Style differently - sepia color to indicate "unknown official"
                attr.foregroundColor = Color(hex: "5D4037")  // Sepia brown
                attr.underlineStyle = .single
                // Use different scheme to indicate potential character
                if let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                    attr.link = URL(string: "newcharacter://\(encoded)")
                }
                result.append(attr)
            }
        }

        return result
    }

    /// Get color based on character's disposition/relationship
    private func characterColor(for name: String) -> Color {
        guard let character = game.characters.first(where: {
            $0.name.lowercased() == name.lowercased()
        }) else {
            return color
        }

        if character.isPatron {
            return Color(hex: "1B5E20")  // Dark green for patron
        } else if character.isRival {
            return theme.sovietRed  // Red for rival
        } else if character.disposition >= 70 {
            return Color(hex: "2E7D32")  // Green for friendly
        } else if character.disposition <= 30 {
            return Color(hex: "C62828")  // Red for hostile
        } else {
            return theme.inkBlack  // Neutral - keep same as text
        }
    }

    /// Parse text to identify character names (known and potential)
    private func parseText(_ text: String, names: [String]) -> [TextSegment] {
        var segments: [TextSegment] = []
        var remaining = text

        while !remaining.isEmpty {
            // Find the earliest occurring known name OR potential character
            var earliestMatch: (name: String, range: Range<String.Index>, isKnown: Bool)? = nil

            // Check known character names
            for name in names {
                // Look for name with word boundaries (not partial matches)
                if let range = remaining.range(of: name, options: .caseInsensitive) {
                    // Check it's a word boundary (not part of a larger word)
                    let isWordStart = range.lowerBound == remaining.startIndex ||
                        !remaining[remaining.index(before: range.lowerBound)].isLetter
                    let isWordEnd = range.upperBound == remaining.endIndex ||
                        !remaining[range.upperBound].isLetter

                    if isWordStart && isWordEnd {
                        if earliestMatch == nil || range.lowerBound < earliestMatch!.range.lowerBound {
                            earliestMatch = (name, range, true)
                        }
                    }
                }
            }

            // Check for potential character names via title patterns
            if let potentialMatch = findPotentialCharacterName(in: remaining) {
                // Only use if it's earlier than known matches, or if no known match found
                if earliestMatch == nil || potentialMatch.range.lowerBound < earliestMatch!.range.lowerBound {
                    // Make sure this potential character isn't already a known character
                    let matchedText = String(remaining[potentialMatch.range])
                    let isActuallyKnown = names.contains { name in
                        name.lowercased() == matchedText.lowercased() ||
                        matchedText.lowercased().contains(name.lowercased())
                    }
                    if !isActuallyKnown {
                        earliestMatch = (matchedText, potentialMatch.range, false)
                    }
                }
            }

            if let match = earliestMatch {
                // Add text before the match
                if match.range.lowerBound > remaining.startIndex {
                    let beforeText = String(remaining[remaining.startIndex..<match.range.lowerBound])
                    segments.append(.text(beforeText))
                }

                // Add the character name (preserve original case from text)
                let originalName = String(remaining[match.range])
                if match.isKnown {
                    segments.append(.characterName(originalName))
                } else {
                    segments.append(.potentialCharacter(originalName))
                }

                // Continue with remaining text
                remaining = String(remaining[match.range.upperBound...])
            } else {
                // No more matches, add remaining text
                segments.append(.text(remaining))
                break
            }
        }

        return segments
    }

    /// Find potential character name using title patterns
    private func findPotentialCharacterName(in text: String) -> (name: String, range: Range<String.Index>)? {
        guard let regex = Self.titleRegex else { return nil }

        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let range = Range(match.range, in: text) else {
            return nil
        }

        return (String(text[range]), range)
    }
}

// MARK: - Text Segment

enum TextSegment {
    case text(String)
    case characterName(String)       // Known character in game.characters
    case potentialCharacter(String)  // Detected via title pattern, not yet in game
}

// MARK: - Notification for Character Sheet

extension Notification.Name {
    static let showCharacterSheet = Notification.Name("showCharacterSheet")
    static let createAndShowCharacter = Notification.Name("createAndShowCharacter")
}

// MARK: - Character Sheet Overlay Modifier

struct CharacterSheetOverlay: ViewModifier {
    let game: Game
    @State private var selectedCharacter: GameCharacter? = nil
    @Environment(\.theme) var theme
    @Environment(\.modelContext) var modelContext

    /// Title patterns for parsing detected names
    private static let titlePatterns: [String] = [
        "Deputy Minister", "Vice Minister", "Assistant Minister",
        "Deputy Director", "Assistant Director",
        "First Secretary", "Deputy Secretary", "General Secretary",
        "Vice Chairman", "Deputy Chairman",
        "Deputy Commissar", "Assistant Commissar",
        "Chief Inspector", "Deputy Chief",
        "Regional Governor", "Deputy Governor",
        "Minister", "Director", "Comrade", "Citizen",
        "General", "Colonel", "Major", "Captain", "Lieutenant",
        "Secretary", "Chairman", "Commissar", "Marshal", "Admiral",
        "Professor", "Doctor", "Dr.", "Ambassador", "Envoy",
        "Inspector", "Prosecutor", "Judge", "Governor", "Chief"
    ]

    private func findCharacter(named name: String) -> GameCharacter? {
        // Try exact match first
        if let character = game.characters.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return character
        }
        // Try partial match (e.g., "Wallace" matches "Minister Wallace")
        if let character = game.characters.first(where: {
            $0.name.lowercased().contains(name.lowercased()) ||
            name.lowercased().contains($0.name.lowercased())
        }) {
            return character
        }
        return nil
    }

    /// Parse title and name from a detected name string like "Deputy Minister Graham"
    private func parsePotentialCharacter(_ fullName: String) -> (title: String?, name: String) {
        // Sort by length (longest first) to match "Deputy Minister" before "Minister"
        let sortedPatterns = Self.titlePatterns.sorted { $0.count > $1.count }

        for pattern in sortedPatterns {
            if fullName.hasPrefix(pattern + " ") {
                let name = String(fullName.dropFirst(pattern.count + 1))
                return (pattern, name)
            }
        }
        return (nil, fullName)
    }

    /// Create a placeholder character from a detected name
    private func createPlaceholderCharacter(from fullName: String) -> GameCharacter {
        let (title, name) = parsePotentialCharacter(fullName)

        let character = GameCharacter(
            name: name,
            title: title,
            role: .neutral,
            introducedTurn: game.turnNumber,
            disposition: 50
        )

        // Mark as dynamically discovered - personality not yet known
        character.wasDiscoveredDynamically = true
        character.isFullyRevealed = false

        // Assign random personality traits (hidden until revealed through gameplay)
        character.personalityAmbitious = Int.random(in: 30...70)
        character.personalityParanoid = Int.random(in: 30...70)
        character.personalityRuthless = Int.random(in: 30...70)
        character.personalityCompetent = Int.random(in: 30...70)
        character.personalityLoyal = Int.random(in: 30...70)
        character.personalityCorrupt = Int.random(in: 30...70)

        return character
    }

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .showCharacterSheet)) { notification in
                if let name = notification.object as? String,
                   let character = findCharacter(named: name) {
                    selectedCharacter = character
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .createAndShowCharacter)) { notification in
                if let fullName = notification.object as? String {
                    // Check if character already exists (double-check)
                    if let existing = findCharacter(named: fullName) {
                        selectedCharacter = existing
                    } else {
                        // Create new placeholder character
                        let newCharacter = createPlaceholderCharacter(from: fullName)

                        // Add to SwiftData and game
                        modelContext.insert(newCharacter)
                        newCharacter.game = game
                        game.characters.append(newCharacter)

                        // Show the sheet
                        selectedCharacter = newCharacter
                    }
                }
            }
            .sheet(item: $selectedCharacter) { character in
                CharacterQuickInfoSheet(character: character, game: game)
                    .presentationDetents([.medium])
            }
    }
}

/// Modifier that handles optional Game
struct CharacterSheetOverlayModifier: ViewModifier {
    let game: Game?
    @State private var selectedCharacter: GameCharacter? = nil
    @Environment(\.modelContext) var modelContext

    /// Title patterns for parsing detected names
    private static let titlePatterns: [String] = [
        "Deputy Minister", "Vice Minister", "Assistant Minister",
        "Deputy Director", "Assistant Director",
        "First Secretary", "Deputy Secretary", "General Secretary",
        "Vice Chairman", "Deputy Chairman",
        "Deputy Commissar", "Assistant Commissar",
        "Chief Inspector", "Deputy Chief",
        "Regional Governor", "Deputy Governor",
        "Minister", "Director", "Comrade", "Citizen",
        "General", "Colonel", "Major", "Captain", "Lieutenant",
        "Secretary", "Chairman", "Commissar", "Marshal", "Admiral",
        "Professor", "Doctor", "Dr.", "Ambassador", "Envoy",
        "Inspector", "Prosecutor", "Judge", "Governor", "Chief"
    ]

    private func findCharacter(named name: String, in game: Game) -> GameCharacter? {
        // Try exact match first
        if let character = game.characters.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return character
        }
        // Try partial match (e.g., "Wallace" matches "Minister Wallace")
        if let character = game.characters.first(where: {
            $0.name.lowercased().contains(name.lowercased()) ||
            name.lowercased().contains($0.name.lowercased())
        }) {
            return character
        }
        return nil
    }

    /// Parse title and name from a detected name string
    private func parsePotentialCharacter(_ fullName: String) -> (title: String?, name: String) {
        let sortedPatterns = Self.titlePatterns.sorted { $0.count > $1.count }
        for pattern in sortedPatterns {
            if fullName.hasPrefix(pattern + " ") {
                let name = String(fullName.dropFirst(pattern.count + 1))
                return (pattern, name)
            }
        }
        return (nil, fullName)
    }

    /// Create a placeholder character from a detected name
    private func createPlaceholderCharacter(from fullName: String, game: Game) -> GameCharacter {
        let (title, name) = parsePotentialCharacter(fullName)

        let character = GameCharacter(
            name: name,
            title: title,
            role: .neutral,
            introducedTurn: game.turnNumber,
            disposition: 50
        )

        character.wasDiscoveredDynamically = true
        character.isFullyRevealed = false
        character.personalityAmbitious = Int.random(in: 30...70)
        character.personalityParanoid = Int.random(in: 30...70)
        character.personalityRuthless = Int.random(in: 30...70)
        character.personalityCompetent = Int.random(in: 30...70)
        character.personalityLoyal = Int.random(in: 30...70)
        character.personalityCorrupt = Int.random(in: 30...70)

        return character
    }

    func body(content: Content) -> some View {
        if let game = game {
            content
                .onReceive(NotificationCenter.default.publisher(for: .showCharacterSheet)) { notification in
                    if let name = notification.object as? String,
                       let character = findCharacter(named: name, in: game) {
                        selectedCharacter = character
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .createAndShowCharacter)) { notification in
                    if let fullName = notification.object as? String {
                        if let existing = findCharacter(named: fullName, in: game) {
                            selectedCharacter = existing
                        } else {
                            let newCharacter = createPlaceholderCharacter(from: fullName, game: game)
                            modelContext.insert(newCharacter)
                            newCharacter.game = game
                            game.characters.append(newCharacter)
                            selectedCharacter = newCharacter
                        }
                    }
                }
                .sheet(item: $selectedCharacter) { character in
                    CharacterQuickInfoSheet(character: character, game: game)
                        .presentationDetents([.medium])
                }
        } else {
            content
        }
    }
}

extension View {
    func characterSheetOverlay(game: Game) -> some View {
        modifier(CharacterSheetOverlay(game: game))
    }

    func characterSheetOverlay(game: Game?) -> some View {
        modifier(CharacterSheetOverlayModifier(game: game))
    }
}

// MARK: - Preview

#Preview {
    let text = "Minister Wallace approaches you after the morning briefing. Director Kovacs has been asking questions about your background."

    return VStack {
        Text("Demo - names should be clickable:")
            .padding()

        // Note: Preview won't work without actual game data
        Text(text)
            .padding()
    }
}
