//
//  ScenarioValidator.swift
//  Nomenklatura
//
//  Validates and parses AI-generated scenario responses
//

import Foundation

// MARK: - Scenario Validator

/// Stateless validator for AI-generated scenarios
@MainActor
struct ScenarioValidator {

    // MARK: - Validation Result

    enum ValidationResult: Sendable {
        case valid(Scenario, ScenarioNarrativeMetadata)
        case invalid(String)
    }

    // MARK: - Public API

    /// Parse and validate an AI response into a Scenario
    static func validate(response: String) -> ValidationResult {
        // Step 1: Extract JSON from response
        guard let jsonString = extractJSON(from: response) else {
            return .invalid("No valid JSON found in response")
        }

        // Step 2: Parse JSON
        guard let data = jsonString.data(using: .utf8) else {
            return .invalid("Failed to encode response as data")
        }

        let rawScenario: RawAIScenario
        do {
            rawScenario = try JSONDecoder().decode(RawAIScenario.self, from: data)
        } catch {
            return .invalid("JSON parsing failed: \(error.localizedDescription)")
        }

        // Step 3: Validate structure
        if let error = validateStructure(rawScenario) {
            return .invalid(error)
        }

        // Step 4: Validate content safety
        if let error = validateContentSafety(rawScenario) {
            return .invalid(error)
        }

        // Step 5: Convert to Scenario and extract metadata
        let (scenario, metadata) = convertToScenario(rawScenario)
        return .valid(scenario, metadata)
    }

    // MARK: - JSON Extraction

    private static func extractJSON(from response: String) -> String? {
        // Try to find JSON object in response
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // If it starts with {, assume it's pure JSON
        if trimmed.hasPrefix("{") {
            // Find matching closing brace
            var braceCount = 0
            var endIndex = trimmed.startIndex

            for (index, char) in trimmed.enumerated() {
                if char == "{" { braceCount += 1 }
                if char == "}" { braceCount -= 1 }
                if braceCount == 0 {
                    endIndex = trimmed.index(trimmed.startIndex, offsetBy: index + 1)
                    break
                }
            }

            return String(trimmed[..<endIndex])
        }

        // Try to extract JSON from markdown code block
        if let jsonMatch = trimmed.range(of: "```json\\s*\\n([\\s\\S]*?)\\n```", options: .regularExpression) {
            let match = String(trimmed[jsonMatch])
            let cleaned = match
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned
        }

        // Try to find JSON object anywhere in response
        if let start = trimmed.range(of: "{"),
           let end = trimmed.range(of: "}", options: .backwards) {
            return String(trimmed[start.lowerBound...end.upperBound])
        }

        return nil
    }

    // MARK: - Structure Validation

    private static func validateStructure(_ raw: RawAIScenario) -> String? {
        // Check required fields
        if raw.templateId.isEmpty {
            return "Missing templateId"
        }

        if raw.briefing.isEmpty {
            return "Missing briefing"
        }

        if raw.presenterName.isEmpty {
            return "Missing presenterName"
        }

        // Must have exactly 3 options
        if raw.options.count != 3 {
            return "Must have exactly 3 options, got \(raw.options.count)"
        }

        // Validate each option
        for (index, option) in raw.options.enumerated() {
            if option.id.isEmpty {
                return "Option \(index) missing id"
            }
            if option.shortDescription.isEmpty {
                return "Option \(index) missing shortDescription"
            }
            if option.immediateOutcome.isEmpty {
                return "Option \(index) missing immediateOutcome"
            }

            // Validate stat effects are within bounds (using BalanceConfig)
            var totalPositive = 0
            var totalNegative = 0

            for (stat, value) in option.statEffects ?? [:] {
                if !isValidStatKey(stat) {
                    return "Option \(index) has invalid stat key: \(stat)"
                }
                if abs(value) > BalanceConfig.maxNationalStatChange {
                    return "Option \(index) stat effect too extreme: \(stat) = \(value) (max ±\(BalanceConfig.maxNationalStatChange))"
                }
                // Track positive/negative totals
                if value > 0 { totalPositive += value }
                if value < 0 { totalNegative += abs(value) }
            }

            for (stat, value) in option.personalEffects ?? [:] {
                if !isValidPersonalStatKey(stat) {
                    return "Option \(index) has invalid personal stat key: \(stat)"
                }
                if abs(value) > BalanceConfig.maxPersonalStatChange {
                    return "Option \(index) personal effect too extreme: \(stat) = \(value) (max ±\(BalanceConfig.maxPersonalStatChange))"
                }
                // Track positive/negative totals (rivalThreat is inverted - higher is worse for player)
                if stat == "rivalThreat" {
                    if value > 0 { totalNegative += value }  // Increasing rival threat is bad
                    if value < 0 { totalPositive += abs(value) }  // Decreasing is good
                } else {
                    if value > 0 { totalPositive += value }
                    if value < 0 { totalNegative += abs(value) }
                }
            }

            // Validate net balance - options should have trade-offs
            if totalPositive > BalanceConfig.maxTotalPositiveEffects {
                return "Option \(index) has too many positive effects: \(totalPositive) (max \(BalanceConfig.maxTotalPositiveEffects))"
            }
            if totalNegative > BalanceConfig.maxTotalNegativeEffects {
                return "Option \(index) has too many negative effects: \(totalNegative) (max \(BalanceConfig.maxTotalNegativeEffects))"
            }

            let netBalance = totalPositive - totalNegative
            if abs(netBalance) > BalanceConfig.maxNetImbalance {
                return "Option \(index) is unbalanced (net \(netBalance > 0 ? "+" : "")\(netBalance), max imbalance ±\(BalanceConfig.maxNetImbalance))"
            }
        }

        return nil
    }

    private static func isValidStatKey(_ key: String) -> Bool {
        let validKeys = ["stability", "popularSupport", "militaryLoyalty", "eliteLoyalty",
                         "treasury", "industrialOutput", "foodSupply", "internationalStanding"]
        return validKeys.contains(key)
    }

    private static func isValidPersonalStatKey(_ key: String) -> Bool {
        let validKeys = ["standing", "patronFavor", "rivalThreat", "network",
                         "reputationCompetent", "reputationLoyal", "reputationCunning", "reputationRuthless"]
        return validKeys.contains(key)
    }

    // MARK: - Content Safety Validation

    private static func validateContentSafety(_ raw: RawAIScenario) -> String? {
        let allText = [
            raw.briefing,
            raw.presenterName,
            raw.presenterTitle ?? ""
        ] + raw.options.flatMap { [
            $0.shortDescription,
            $0.immediateOutcome,
            $0.followUpHook ?? ""
        ]}

        let combinedText = allText.joined(separator: " ").lowercased()

        // Check for inappropriate content
        let blockedTerms = [
            "real person", "actual politician", "trump", "biden", "putin", "xi jinping",
            "explicit", "sexual", "nude", "graphic violence", "torture details"
        ]

        for term in blockedTerms {
            if combinedText.contains(term) {
                return "Content contains blocked term: \(term)"
            }
        }

        // Check for excessive length
        if raw.briefing.count > 2000 {
            return "Briefing too long (\(raw.briefing.count) chars, max 2000)"
        }

        for option in raw.options {
            if option.immediateOutcome.count > 1500 {
                return "Option outcome too long (\(option.immediateOutcome.count) chars, max 1500)"
            }
        }

        return nil
    }

    // MARK: - Conversion

    private static func convertToScenario(_ raw: RawAIScenario) -> (Scenario, ScenarioNarrativeMetadata) {
        let category = ScenarioCategory(rawValue: raw.category) ?? .routine

        let options = raw.options.map { rawOption -> ScenarioOption in
            let archetype = OptionArchetype(rawValue: rawOption.archetype) ?? .negotiate

            return ScenarioOption(
                id: rawOption.id,
                archetype: archetype,
                shortDescription: rawOption.shortDescription,
                immediateOutcome: rawOption.immediateOutcome,
                statEffects: rawOption.statEffects ?? [:],
                personalEffects: rawOption.personalEffects,
                followUpHook: rawOption.followUpHook,
                isLocked: false,
                lockReason: nil
            )
        }

        let scenario = Scenario(
            templateId: "ai_\(raw.templateId)_\(Int(Date().timeIntervalSince1970))",
            category: category,
            briefing: raw.briefing,
            presenterName: raw.presenterName,
            presenterTitle: raw.presenterTitle,
            options: options,
            isFallback: false,
            aiProvider: "claude"
        )

        // Extract narrative metadata
        var newThread: (id: String, title: String, summary: String)? = nil
        if let intro = raw.plotThreads?.introducesThread {
            newThread = (intro.id, intro.title, intro.summary)
        }

        // Convert raw character details to public CharacterDetail structs (Living Character System)
        let characterDetails: [CharacterDetail] = (raw.characterDetails ?? []).map { rawDetail in
            CharacterDetail(
                name: rawDetail.name,
                title: rawDetail.title,
                roleHint: rawDetail.role,
                dispositionHint: rawDetail.dispositionHint
            )
        }

        let metadata = ScenarioNarrativeMetadata(
            narrativeSummary: raw.narrativeSummary,
            charactersInvolved: raw.charactersInvolved ?? [],
            characterDetails: characterDetails,
            continuesThreadIds: raw.plotThreads?.continuesThreads ?? [],
            newThread: newThread,
            suggestedCallbackTurn: raw.suggestedCallbackTurn
        )

        return (scenario, metadata)
    }
}

// MARK: - Raw AI Response Model

/// Intermediate model for parsing AI responses before validation
private struct RawAIScenario: Decodable, Sendable {
    let templateId: String
    let category: String
    let briefing: String
    let presenterName: String
    let presenterTitle: String?
    let options: [RawAIOption]

    // Narrative Memory fields (optional, for continuity)
    let narrativeSummary: String?           // Brief summary for future AI context
    let charactersInvolved: [String]?       // Names of characters appearing
    let characterDetails: [RawCharacterDetail]?  // Detailed info about characters (Living Character System)
    let plotThreads: RawPlotThreadInfo?     // Plot thread continuity info
    let suggestedCallbackTurn: Int?         // When to revisit this storyline
}

/// Character detail info from AI response (Living Character System)
private struct RawCharacterDetail: Decodable, Sendable {
    let name: String
    let title: String?
    let role: String?               // "ally", "neutral", "antagonist", "authority", "subordinate"
    let dispositionHint: String?    // "friendly", "hostile", "neutral", "wary"
}

private struct RawAIOption: Decodable, Sendable {
    let id: String
    let archetype: String
    let shortDescription: String
    let immediateOutcome: String
    let statEffects: [String: Int]?
    let personalEffects: [String: Int]?
    let followUpHook: String?
}

/// Plot thread info from AI response
private struct RawPlotThreadInfo: Decodable, Sendable {
    let continuesThreads: [String]?     // Existing thread IDs being continued
    let introducesThread: RawNewThread? // New thread being introduced
}

private struct RawNewThread: Decodable, Sendable {
    let id: String
    let title: String
    let summary: String
}

// MARK: - Scenario Metadata (Public)

/// Detail about a character mentioned in a scenario (Living Character System)
public struct CharacterDetail: Sendable {
    public let name: String
    public let title: String?
    public let roleHint: String?           // "ally", "neutral", "antagonist", "authority", "subordinate"
    public let dispositionHint: String?    // "friendly", "hostile", "neutral", "wary"

    /// Convert disposition hint to initial disposition value
    public var initialDisposition: Int {
        switch dispositionHint?.lowercased() {
        case "friendly": return 65
        case "hostile": return 25
        case "wary": return 40
        default: return 50  // neutral
        }
    }

    /// Convert role hint to CharacterRole
    public var suggestedRole: CharacterRole {
        switch roleHint?.lowercased() {
        case "ally": return .ally
        case "antagonist": return .rival
        case "authority": return .leader
        case "subordinate": return .subordinate
        default: return .neutral
        }
    }
}

/// Additional metadata from AI-generated scenarios for narrative memory
public struct ScenarioNarrativeMetadata: Sendable {
    public let narrativeSummary: String?
    public let charactersInvolved: [String]
    public let characterDetails: [CharacterDetail]   // Living Character System
    public let continuesThreadIds: [String]
    public let newThread: (id: String, title: String, summary: String)?
    public let suggestedCallbackTurn: Int?

    public static let empty = ScenarioNarrativeMetadata(
        narrativeSummary: nil,
        charactersInvolved: [],
        characterDetails: [],
        continuesThreadIds: [],
        newThread: nil,
        suggestedCallbackTurn: nil
    )
}
