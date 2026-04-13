//
//  ScenarioManager.swift
//  Nomenklatura
//
//  Manages scenario selection with AI generation and fallback
//

import Foundation
import Combine
import SwiftUI
import os.log

private let scenarioLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "ScenarioManager")

// MARK: - Background Loading State

/// Observable class that tracks scenario loading state across views
@MainActor
class ScenarioLoadingState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = "Preparing briefing..."
    @Published var cachedScenario: Scenario?
    @Published var cachedNewspaper: NewspaperEdition?
    @Published var cachedSamizdat: NewspaperEdition?
    @Published var cachedDynamicEvent: DynamicEvent?
    @Published var isAIGenerated: Bool = false
    @Published var turnNumber: Int = 0

    /// Check if we have a cached scenario for the current turn
    func hasCachedContent(for turn: Int) -> Bool {
        return turnNumber == turn && (cachedScenario != nil || cachedNewspaper != nil || cachedDynamicEvent != nil)
    }

    /// Clear all cached content
    func clearCache() {
        cachedScenario = nil
        cachedNewspaper = nil
        cachedSamizdat = nil
        cachedDynamicEvent = nil
        isAIGenerated = false
    }
}

/// Pre-generated content cache entry
private struct PreGeneratedContent {
    let scenario: Scenario
    let metadata: ScenarioNarrativeMetadata?
    let isAIGenerated: Bool
}

class ScenarioManager {
    static let shared = ScenarioManager()

    /// Shared loading state that can be observed by views
    @MainActor
    let loadingState = ScenarioLoadingState()

    /// Background loading task (persists across view lifecycle)
    private var backgroundTask: Task<Void, Never>?

    /// Lock to prevent multiple simultaneous loads
    private var isLoadingInProgress = false

    // Track recently used scenarios to avoid repetition
    private var recentlyUsedIds: [String] = []
    private let maxRecentHistory = 5

    // Track if last scenario was AI-generated
    private(set) var lastWasAIGenerated = false

    // Store narrative metadata from last AI-generated scenario
    private(set) var lastNarrativeMetadata: ScenarioNarrativeMetadata?

    // Pacing constants
    private let maxConsecutiveDecisions = 2  // Force variety after just 2 decisions
    private let maxCategoryHistory = 5       // Track more history for better variety
    private let onboardingTurns = 4           // First turns are curated to avoid chaotic early prompts

    // Newspaper appearance chance (base 25%, modified by events)
    private let baseNewspaperChance: Double = 0.25

    // MARK: - Async API (with AI)

    /// Get a scenario using AI generation with fallback to local scenarios
    /// Call this from async context for AI-powered scenarios
    @MainActor
    func getScenarioAsync(for game: Game, config: CampaignConfig) async -> Scenario {
        // Keep the opening turns deterministic and grounded.
        if game.turnNumber <= onboardingTurns {
            lastWasAIGenerated = false
            lastNarrativeMetadata = nil
            return getFallbackScenario(for: game)
        }

        // Build prompt and cache key on MainActor (needs Game access)
        let prompt = ScenarioPromptBuilder.buildPrompt(for: game, config: config)
        let cacheKey = "turn_\(game.turnNumber)_\(game.phase)"

        // Try AI generation
        let result = await AIScenarioGenerator.shared.generateScenario(prompt: prompt, cacheKey: cacheKey)

        switch result {
        case .success(let scenario, let metadata):
            lastWasAIGenerated = true
            lastNarrativeMetadata = metadata
            markAsUsed(scenario.templateId, category: scenario.category, turnNumber: game.turnNumber, game: game)
            return scenario

        case .fallback(let reason):
            #if DEBUG
            print("AI fallback: \(reason)")
            #endif
            lastWasAIGenerated = false
            lastNarrativeMetadata = nil
            return getFallbackScenario(for: game)
        }
    }

    /// Check if AI scenario generation is available
    func isAIAvailable() async -> Bool {
        await AIScenarioGenerator.shared.isAvailable()
    }

    // MARK: - Background Loading API

    /// Start loading scenario in background (continues even if view disappears)
    /// This is the preferred method - call this when entering a turn
    @MainActor
    func startBackgroundLoading(for game: Game, config: CampaignConfig, checkDynamicEvents: @escaping () -> DynamicEvent?) {
        let currentTurn = game.turnNumber

        // Skip if already loading for this turn
        guard !isLoadingInProgress else {
            #if DEBUG
            print("[ScenarioManager] Already loading, skipping duplicate request")
            #endif
            return
        }

        // Skip if we already have cached content for this turn
        if loadingState.hasCachedContent(for: currentTurn) {
            #if DEBUG
            print("[ScenarioManager] Using cached content for turn \(currentTurn)")
            #endif
            return
        }

        // Clear previous cache if turn changed
        if loadingState.turnNumber != currentTurn {
            loadingState.clearCache()
            loadingState.turnNumber = currentTurn
            clearPreGenerationCache()
        }

        // Cancel any existing background task
        backgroundTask?.cancel()

        // Mark as loading
        isLoadingInProgress = true
        loadingState.isLoading = true
        loadingState.loadingMessage = "Preparing briefing..."

        // Create detached task that won't be cancelled when view disappears
        backgroundTask = Task.detached { [weak self] in
            guard let self = self else { return }

            // STEP 1: Check for dynamic events
            await MainActor.run {
                if let dynamicEvent = checkDynamicEvents() {
                    self.loadingState.cachedDynamicEvent = dynamicEvent
                    self.loadingState.isLoading = false
                    self.isLoadingInProgress = false
                    return
                }
            }

            // Check if we got a dynamic event
            let hasDynamicEvent = await MainActor.run { self.loadingState.cachedDynamicEvent != nil }
            if hasDynamicEvent {
                return
            }

            // STEP 2: Generate scenario
            await MainActor.run {
                self.loadingState.loadingMessage = "Generating scenario..."
            }

            // Build prompt on main actor
            let (prompt, cacheKey, useAI) = await MainActor.run {
                let prompt = ScenarioPromptBuilder.buildPrompt(for: game, config: config)
                let cacheKey = "turn_\(game.turnNumber)_\(game.phase)"
                let useAI = Secrets.isAIEnabled && game.turnNumber > self.onboardingTurns
                return (prompt, cacheKey, useAI)
            }

            var scenario: Scenario
            var wasAIGenerated = false

            if useAI {
                // Try AI generation
                let result = await AIScenarioGenerator.shared.generateScenario(prompt: prompt, cacheKey: cacheKey)

                switch result {
                case .success(let aiScenario, let metadata):
                    scenario = aiScenario
                    wasAIGenerated = true
                    await MainActor.run {
                        self.lastNarrativeMetadata = metadata
                    }

                case .fallback(let reason):
                    #if DEBUG
                    print("[ScenarioManager] AI fallback: \(reason)")
                    #endif
                    scenario = await MainActor.run { self.getFallbackScenario(for: game) }
                }
            } else {
                // Use sync fallback
                scenario = await MainActor.run { self.getFallbackScenario(for: game) }
            }

            // Store result on main actor
            let aiGeneratedResult = wasAIGenerated
            let scenarioResult = scenario
            await MainActor.run {
                self.lastWasAIGenerated = aiGeneratedResult
                self.loadingState.isAIGenerated = aiGeneratedResult
                self.markAsUsed(scenarioResult.templateId, category: scenarioResult.category, turnNumber: currentTurn, game: game)

                // Handle newspaper vs regular scenario
                if scenarioResult.format == .newspaper {
                    let newspaper = NewspaperGenerator.shared.generateNewspaper(for: game)
                    self.loadingState.cachedNewspaper = newspaper

                    if SamizdatGenerator.shared.isSamizdatAvailable(for: game) {
                        self.loadingState.cachedSamizdat = SamizdatGenerator.shared.generateSamizdat(for: game)
                    }
                } else {
                    self.loadingState.cachedScenario = scenarioResult
                }

                self.loadingState.isLoading = false
                self.isLoadingInProgress = false
                self.loadingState.loadingMessage = "Preparing briefing..."

                #if DEBUG
                print("[ScenarioManager] Background loading complete for turn \(currentTurn)")
                #endif
            }
        }
    }

    /// Cancel any in-progress background loading
    func cancelBackgroundLoading() {
        backgroundTask?.cancel()
        backgroundTask = nil
        isLoadingInProgress = false
        Task { @MainActor in
            loadingState.isLoading = false
        }
    }

    // MARK: - Smart Pre-generation

    /// Pre-generation task (runs silently in background)
    private var preGenerateTask: Task<Void, Never>?

    /// Cache for pre-generated content (keyed by turn number)
    private var preGeneratedCache: [Int: PreGeneratedContent] = [:]

    /// Pre-generation for next-turn content is intentionally disabled until the
    /// game has a single authoritative turn-finalization path. Generating next-turn
    /// briefings from mid-turn state leads to stale cached content.
    @MainActor
    func preGenerateForNextTurn(game: Game, config: CampaignConfig) {
        clearPreGenerationCache()
    }

    /// Check if pre-generated content exists for a turn and apply it to loading state
    /// Returns true if pre-generated content was applied
    @MainActor
    func applyPreGeneratedContent(for turn: Int) -> Bool {
        guard let preGenerated = preGeneratedCache[turn] else {
            return false
        }

        // Don't apply if content is for newspaper (we can't pre-generate newspapers properly)
        if preGenerated.scenario.format == .newspaper {
            preGeneratedCache.removeValue(forKey: turn)
            return false
        }

        // Apply pre-generated content to loading state
        loadingState.turnNumber = turn
        loadingState.cachedScenario = preGenerated.scenario
        loadingState.isAIGenerated = preGenerated.isAIGenerated
        lastWasAIGenerated = preGenerated.isAIGenerated
        lastNarrativeMetadata = preGenerated.metadata

        // Mark as used
        markAsUsed(preGenerated.scenario.templateId, category: preGenerated.scenario.category, turnNumber: turn, game: nil)

        // Clean up cache
        preGeneratedCache.removeValue(forKey: turn)

        #if DEBUG
        print("[ScenarioManager] Applied pre-generated content for turn \(turn)")
        #endif
        return true
    }

    /// Clear pre-generation cache (call when game state changes significantly)
    func clearPreGenerationCache() {
        preGenerateTask?.cancel()
        preGenerateTask = nil
        preGeneratedCache.removeAll()
    }

    /// Check if pre-generated content is ready for the next turn
    @MainActor
    func hasPreGeneratedContent(forNextTurnAfter currentTurn: Int) -> Bool {
        return preGeneratedCache[currentTurn + 1] != nil
    }

    /// Check if pre-generation is currently in progress
    @MainActor
    var isPreGenerating: Bool {
        return preGenerateTask != nil
    }

    // MARK: - Sync API (fallback only)

    /// Get a fallback scenario (synchronous, no AI)
    /// Use this when you need immediate results without async
    func getScenario(for game: Game) -> Scenario {
        lastWasAIGenerated = false
        return getFallbackScenario(for: game)
    }

    // MARK: - Fallback Selection

    /// Select from local fallback scenarios
    private func getFallbackScenario(for game: Game) -> Scenario {
        // Special case: Turn 1 always gets introduction scenario
        if game.turnNumber == 1 {
            return getIntroductionScenario(for: game)
        }

        // Step 1: Select category with weighted randomness and pacing logic
        let category = selectCategory(for: game)

        // Step 2: Handle non-decision categories
        if !category.requiresDecision {
            return getNonDecisionScenario(for: game, category: category)
        }

        // Step 3: Get scenarios for that category (exclude introduction)
        let categoryScenarios = allScenarios.filter {
            $0.category == category && $0.category != .introduction
        }

        // Step 4: Filter out recently used
        var candidates = categoryScenarios.filter { !recentlyUsedIds.contains($0.templateId) }

        // If all scenarios in category were recently used, allow repeats
        if candidates.isEmpty {
            candidates = categoryScenarios
        }

        // Step 5: Score by relevance to game state
        let scored = candidates.map { scenario -> (Scenario, Int) in
            let score = calculateRelevanceScore(scenario: scenario, game: game)
            return (scenario, score)
        }.sorted { $0.1 > $1.1 }

        // Step 6: Pick from top candidates with randomness
        let topCount = min(3, scored.count)
        let topCandidates = Array(scored.prefix(topCount))
        guard let selected = topCandidates.randomElement()?.0 ?? allScenarios.first(where: { $0.category != .introduction }) else {
            return allScenarios[0]
        }

        // Track usage
        markAsUsed(selected.templateId, category: selected.category, turnNumber: game.turnNumber, game: game)

        return selected
    }

    /// Get a non-decision scenario for pacing/atmosphere
    private func getNonDecisionScenario(for game: Game, category: ScenarioCategory) -> Scenario {
        let scenarios: [Scenario]

        switch category {
        case .routineDay:
            scenarios = routineDayScenarios
        case .characterMoment:
            scenarios = characterMomentScenarios
        case .tensionBuilder:
            scenarios = tensionBuilderScenarios
        case .newspaper:
            // Newspaper will be handled separately with NewspaperGenerator
            // For now, return a placeholder that will trigger newspaper view
            return createNewspaperPlaceholder(for: game)
        default:
            scenarios = routineDayScenarios
        }

        // Filter out recently used
        var candidates = scenarios.filter { !recentlyUsedIds.contains($0.templateId) }
        if candidates.isEmpty {
            candidates = scenarios
        }

        // Random selection from candidates
        guard let selected = candidates.randomElement() ?? scenarios.first else {
            return createNewspaperPlaceholder(for: game)
        }

        markAsUsed(selected.templateId, category: selected.category, turnNumber: game.turnNumber, game: game)

        return selected
    }

    /// Create a placeholder scenario for newspaper (actual content generated separately)
    private func createNewspaperPlaceholder(for game: Game) -> Scenario {
        return Scenario(
            templateId: "newspaper_\(game.turnNumber)",
            category: .newspaper,
            format: .newspaper,
            briefing: "", // Will be populated by NewspaperGenerator
            presenterName: "State Media",
            presenterTitle: nil,
            options: [],
            isFallback: true
        )
    }

    /// Get the Turn 1 introduction scenario - customized for player's chosen faction/background
    private func getIntroductionScenario(for game: Game) -> Scenario {
        // Get player's chosen faction/background
        let playerFaction = game.playerFactionId.flatMap { PlayerFactionConfig.faction(withId: $0) }
        let factionName = playerFaction?.name ?? "the Party"

        // Build faction-specific intro text for a new General Secretary
        let factionContext: String
        switch game.playerFactionId {
        case "youth_league":
            factionContext = """
            Your power base is the Youth League — you organized harvest campaigns, built networks in drafty provincial halls, and proved yourself through results, not connections. The Standing Committee chose you because you owe nothing to the old factions.

            "The Youth League cadres celebrate your election," Sasha notes. "The inner circles are less certain. They see an outsider in the General Secretary's chair."
            """
        case "princelings":
            factionContext = """
            Your father fought alongside the revolution's founders. That name — your name — carried you through every committee and every vote. The Standing Committee chose you because your bloodline reassures the old guard.

            "Your family's legacy won you this office," Sasha says carefully. "But some on the Committee resent a leader who inherited what others spent decades earning."
            """
        case "reformists":
            factionContext = """
            You believe in progress — careful, measured change. The old ways built this state, but the world moves on. The Standing Committee chose you as a signal that reform is possible without chaos.

            "The reformist faction believes their moment has come," Sasha observes. "The old guard voted for you because they think you can be controlled. Prove them wrong — or right."
            """
        case "old_guard":
            factionContext = """
            You remember why the revolution was fought. While others chase economic miracles and foreign investment, you hold fast to the principles that built this state. The Standing Committee chose you to steady the ship.

            "The Party apparatus trusts you," Sasha notes. "But the younger members whisper that the old ways are a dead end. They will test your resolve."
            """
        case "regional":
            factionContext = """
            You built your power base far from these marble halls — in provincial capitals where loyalty is simpler and networks run deeper. The Standing Committee chose you because the regions demanded representation at the top.

            "Your regional allies secured the votes," Sasha advises. "But the capital factions view you as a temporary arrangement. They are already planning your succession."
            """
        default:
            factionContext = """
            Your path here wound through every level of the Party — committees, departments, ministries. You survived purges that claimed better people. The Standing Committee chose you because you were the only candidate no faction could veto.

            "A compromise candidate," Sasha observes quietly. "But every General Secretary in history was a compromise — until they weren't."
            """
        }

        let customizedBriefing = """
        The heavy oak doors of the General Secretary's office close behind you. The room is larger than you expected — mahogany desk, red curtains, a wall of telephones connecting you to every ministry, every military district, every corner of the Republic.

        The portrait of your predecessor has already been removed. The nail hole in the wall is the only trace that anyone sat in this chair before you.

        \(factionContext)

        Your chief of staff, Sasha, sets a leather portfolio on the desk. "Comrade General Secretary. Your first morning briefing."

        "Director Wallace championed your candidacy on the Standing Committee. He expects loyalty in return — and he controls State Security. Deputy Director Sullivan believes he should be sitting where you sit. He has allies."

        Sasha opens the portfolio. "The previous General Secretary left... suddenly. The Standing Committee is fractured. Three factions are already maneuvering. But you hold the seals of office, and for now, that is enough."

        "How do you wish to begin your tenure as General Secretary, representing \(factionName)?"
        """

        return Scenario(
            templateId: "introduction",
            category: .introduction,
            briefing: customizedBriefing,
            presenterName: "Sasha",
            presenterTitle: "Chief of Staff",
            options: introductionScenario.options,  // Reuse the existing options
            isFallback: true
        )
    }

    /// Weighted category selection that avoids obvious patterns
    /// Now includes pacing logic to force variety after consecutive decision events
    private func selectCategory(for game: Game) -> ScenarioCategory {
        // Onboarding window: avoid high-chaos categories while the player is still learning.
        if game.turnNumber <= onboardingTurns {
            return selectOnboardingCategory(for: game)
        }

        // Check if we should force a non-decision event for pacing
        // Use the game's persisted counter
        if game.consecutiveDecisionEvents >= maxConsecutiveDecisions {
            // Force a breather - pick from non-decision categories
            return selectNonDecisionCategory()
        }

        // Check for random newspaper chance (but not back-to-back)
        // Use the game's persisted last newspaper turn
        if game.turnNumber > game.lastNewspaperTurn + 1 {
            let newspaperChance = calculateNewspaperChance(for: game)
            if Double.random(in: 0...1) < newspaperChance {
                return .newspaper
            }
        }

        // Convert persisted categories to enum
        let recentCategories = game.recentScenarioCategories.compactMap {
            ScenarioCategory(rawValue: $0)
        }

        // Build weights, reducing weight for recently used categories
        var weights: [ScenarioCategory: Int] = [:]

        for category in ScenarioCategory.allCases {
            var weight = category.selectionWeight

            // Skip categories with 0 weight (introduction, newspaper handled separately)
            guard weight > 0 else { continue }

            // Heavier penalty for recent usage - 20 points per occurrence
            let recentCount = recentCategories.filter { $0 == category }.count
            weight = max(3, weight - (recentCount * 20))

            // Extra penalty if this was the most recent category (avoid back-to-back)
            if recentCategories.last == category {
                weight = max(3, weight - 15)
            }

            // Slight penalty for crisis if we've had any crisis in recent history
            // This reduces the "always urgent" feel
            if category == .crisis && recentCategories.contains(.crisis) {
                weight = max(3, weight - 10)
            }

            weights[category] = weight
        }

        // Weighted random selection
        let totalWeight = weights.values.reduce(0, +)
        guard totalWeight > 0 else { return .routine }

        var random = Int.random(in: 0..<totalWeight)

        for (category, weight) in weights {
            random -= weight
            if random < 0 {
                return category
            }
        }

        return .routine // Fallback
    }

    /// Curated category selection for the first few turns.
    /// As General Secretary, early turns introduce crisis, governance, and intrigue.
    private func selectOnboardingCategory(for game: Game) -> ScenarioCategory {
        if game.turnNumber == 2 {
            return .crisis  // Turn 2: A border crisis or intelligence briefing — teaches desk/document mechanics
        }
        if game.turnNumber == 3 {
            return .routine  // Turn 3: Standing Committee demands a meeting — introduces factional politics
        }
        if game.turnNumber == 4 {
            return .character  // Turn 4: A rival makes a move — introduces intrigue/threat
        }

        let onboardingCategories: [(ScenarioCategory, Int)] = [
            (.crisis, 30),
            (.routine, 30),
            (.character, 25),
            (.opportunity, 15)
        ]

        let totalWeight = onboardingCategories.reduce(0) { $0 + $1.1 }
        var random = Int.random(in: 0..<totalWeight)

        for (category, weight) in onboardingCategories {
            random -= weight
            if random < 0 {
                return category
            }
        }

        return .routine
    }

    /// Select from non-decision categories to break up decision fatigue
    private func selectNonDecisionCategory() -> ScenarioCategory {
        let nonDecisionCategories: [(ScenarioCategory, Int)] = [
            (.routineDay, 40),
            (.characterMoment, 30),
            (.tensionBuilder, 30)
        ]

        let totalWeight = nonDecisionCategories.reduce(0) { $0 + $1.1 }
        var random = Int.random(in: 0..<totalWeight)

        for (category, weight) in nonDecisionCategories {
            random -= weight
            if random < 0 {
                return category
            }
        }

        return .routineDay
    }

    /// Calculate newspaper appearance chance based on game state
    private func calculateNewspaperChance(for game: Game) -> Double {
        var chance = baseNewspaperChance

        // Increase chance after major events (check recent events for deaths, purges)
        let recentMajorEvents = game.events.filter {
            $0.turnNumber >= game.turnNumber - 2 &&
            ($0.eventType == "death" || $0.eventType == "purge" || $0.importance >= 8)
        }

        if !recentMajorEvents.isEmpty {
            chance += 0.30 // Significant boost after major events
        }

        // Increase slightly if it's been a while since last newspaper
        let turnsSinceNewspaper = game.turnNumber - game.lastNewspaperTurn
        if turnsSinceNewspaper > 5 {
            chance += 0.15
        }

        return min(chance, 0.60) // Cap at 60%
    }

    private func markAsUsed(_ templateId: String, category: ScenarioCategory, turnNumber: Int, game: Game? = nil) {
        recentlyUsedIds.append(templateId)
        if recentlyUsedIds.count > maxRecentHistory {
            recentlyUsedIds.removeFirst()
        }

        // Update persisted game state if available
        if let game = game {
            // Track recent categories
            game.recentScenarioCategories.append(category.rawValue)
            if game.recentScenarioCategories.count > maxCategoryHistory {
                game.recentScenarioCategories.removeFirst()
            }

            // Track consecutive decision events for pacing
            if category.requiresDecision {
                game.consecutiveDecisionEvents += 1
            } else {
                game.consecutiveDecisionEvents = 0 // Reset counter after non-decision event
            }

            // Track newspaper appearances
            if category == .newspaper {
                game.lastNewspaperTurn = turnNumber
            }
        }
    }

    private func calculateRelevanceScore(scenario: Scenario, game: Game) -> Int {
        var score = 10 // Base score

        // Reduced relevance bonuses to prevent crisis domination
        // Previously these were 15-20, now they're 8-12
        switch scenario.templateId {
        // Crisis scenarios - appear when things are bad (but with moderated bonuses)
        case "food_shortage":
            if game.foodSupply < 40 { score += 12 }
            if game.popularSupport < 40 { score += 5 }

        case "military_funding":
            if game.militaryLoyalty < 50 { score += 12 }
            if game.treasury < 40 { score += 5 }

        case "foreign_incident":
            if game.internationalStanding < 50 { score += 10 }
            if game.militaryLoyalty > 60 { score += 5 }

        case "party_faction":
            if game.eliteLoyalty < 50 { score += 12 }
            if game.standing > 40 { score += 5 }

        case "university_protests":
            if game.popularSupport < 50 { score += 10 }
            if game.eliteLoyalty < 50 { score += 8 }

        // Routine scenarios - boost these to compete with crisis
        // These should appear even when times are tough (the state still functions)
        case "budget_allocation":
            score += 8  // Base boost for routine scenarios
            if game.treasury > 40 { score += 10 }
            if game.stability > 50 { score += 5 }

        case "cultural_exhibition":
            score += 8
            if game.internationalStanding > 40 { score += 8 }
            if game.popularSupport > 40 { score += 5 }

        case "regional_appointment":
            score += 10  // Appointments always happen
            if game.standing > 30 { score += 8 }

        case "protocol_violation":
            score += 8
            if game.eliteLoyalty < 60 { score += 8 }

        // Opportunity scenarios - these should appear regularly
        case "foreign_delegation":
            score += 10
            if game.internationalStanding > 50 { score += 10 }
            if game.standing > 40 { score += 5 }

        case "patron_project":
            score += 10
            if game.patronFavor > 40 { score += 10 }
            if game.standing < 60 { score += 5 }

        case "rival_stumble":
            score += 8
            if game.rivalThreat > 30 { score += 12 }
            if game.network > 40 { score += 5 }

        case "committee_vacancy":
            score += 10
            if game.standing > 30 { score += 8 }
            if game.eliteLoyalty > 50 { score += 5 }

        // Character scenarios - these should appear regularly for immersion
        case "patron_test":
            score += 12  // Character moments are important for immersion
            if game.patronFavor < 60 { score += 8 }

        case "rival_approach":
            score += 12
            if game.rivalThreat > 20 { score += 10 }

        case "old_friend":
            score += 10
            if game.network > 30 { score += 8 }

        case "subordinate_problem":
            score += 10
            if game.standing > 30 { score += 8 }

        default:
            break
        }

        // Add randomness to prevent predictability
        score += Int.random(in: 0...15)

        return score
    }

    // MARK: - All Scenarios

    private var allScenarios: [Scenario] {
        crisisScenarios + routineScenarios + opportunityScenarios + characterScenarios
    }

    // MARK: - Crisis Scenarios (Urgent problems)

    private let crisisScenarios: [Scenario] = [
        // 1. University Protests
        Scenario(
            templateId: "university_protests",
            category: .crisis,
            briefing: "\"Comrade, we have a situation. Students at the State University have organized an unauthorized gathering. They claim to be 'discussing philosophy,' but our informants report subversive literature is being circulated. Already the rector is demanding we act before Western journalists notice.\"",
            presenterName: "Director Wallace",
            presenterTitle: "Head of State Security",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .repress,
                    shortDescription: "Support Wallace's crackdown. Authorize arrests of the ringleaders.",
                    immediateOutcome: "Security forces move in at 3 AM. By morning, fourteen students are in custody, and the dormitories are silent.\n\nDirector Wallace catches your eye across the briefing room table. A slight nod. You've proven yourself reliable.\n\nBut in the lecture halls, the remaining students sit in terrified silence. The images of their classmates being dragged away will inspire some, and silence others.",
                    statEffects: ["stability": 15, "popularSupport": -20],
                    personalEffects: ["patronFavor": 5],
                    followUpHook: "The students remember...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .reform,
                    shortDescription: "Propose allowing supervised discussion groups. Channel the energy.",
                    immediateOutcome: "\"Young minds need guidance, not suppression,\" you announce to the assembled committee. A murmur ripples through the room.\n\nThe students return to their studies, now with official 'Marxist Philosophy Circles' to attend. The subversive literature quietly disappears.\n\nSome members of the Politburo take note of your pragmatism. Others mark you as dangerously soft.",
                    statEffects: ["popularSupport": 10, "eliteLoyalty": -10],
                    personalEffects: ["standing": 8],
                    followUpHook: "Some in the Politburo notice your pragmatism.",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .deflect,
                    shortDescription: "Quietly suggest the rector allowed this to fester...",
                    immediateOutcome: "After the meeting, you linger near the General Secretary. \"A troubling situation, Comrade. One wonders how the rector allowed such activities under his own roof...\"\n\nThe old man's eyes narrow. He says nothing, but you can see the calculation behind them.\n\nThe rector will be reassigned within the month. But the students' grievances remain unaddressed.",
                    statEffects: [:],
                    personalEffects: ["network": 5, "reputationCunning": 10],
                    followUpHook: "The new rector owes you a favor.",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 2. Food Shortage Crisis
        Scenario(
            templateId: "food_shortage",
            category: .crisis,
            briefing: "\"The harvest reports are in, Comrade. They are... not encouraging.\" Director Morrison adjusts his glasses nervously. \"The collective farms in the eastern provinces have fallen forty percent short of projections. The cities have perhaps three weeks of grain reserves remaining.\"",
            presenterName: "Director Morrison",
            presenterTitle: "Agricultural Planning",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .repress,
                    shortDescription: "Implement emergency requisitions from the countryside.",
                    immediateOutcome: "The requisition teams fan out across the provinces. Granaries that farmers had hidden for their own families are discovered and seized.\n\nThe cities will eat this winter. The countryside will not forget.\n\nReports filter back of villages where not a single sack of grain remains. But the party newspapers print photographs of smiling workers receiving their bread rations.",
                    statEffects: ["foodSupply": 15, "popularSupport": -25, "stability": -10],
                    personalEffects: ["reputationRuthless": 10],
                    followUpHook: "The countryside remembers the hunger...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .negotiate,
                    shortDescription: "Request emergency grain imports from allied nations.",
                    immediateOutcome: "Your request travels through diplomatic channels. The fraternal socialist republics agree to help—at a price.\n\nShips laden with grain arrive in the harbors. The treasury takes a significant hit, but the bread lines remain manageable.\n\nIn foreign capitals, they note that the People's Republic cannot feed itself.",
                    statEffects: ["foodSupply": 20, "treasury": -20, "internationalStanding": -10],
                    personalEffects: ["standing": 5],
                    followUpHook: "The debt will need to be repaid...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .deflect,
                    shortDescription: "Blame saboteurs and demand an investigation into Agricultural Planning.",
                    immediateOutcome: "\"Clearly, counter-revolutionary elements have infiltrated our agricultural apparatus,\" you declare. Director Morrison goes pale.\n\nThe investigation begins. Several mid-level officials are arrested. The food shortage continues, but now everyone is too afraid to report accurate numbers.\n\nMorrison is quietly reassigned. His replacement knows better than to bring bad news.",
                    statEffects: ["stability": 5, "foodSupply": -5],
                    personalEffects: ["reputationCunning": 8, "network": 5],
                    followUpHook: "The true harvest numbers remain hidden...",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 3. Military Funding Dispute
        Scenario(
            templateId: "military_funding",
            category: .crisis,
            briefing: "General Anderson stands at attention, his chest heavy with medals. \"The Atlantic Union has deployed new missiles in Western bloc nations. Our current defense budget is insufficient to respond. I am requesting a forty percent increase in military allocations.\"",
            presenterName: "General Anderson",
            presenterTitle: "Defense Minister",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .appease,
                    shortDescription: "Grant the full military budget increase.",
                    immediateOutcome: "The Marshal's stern face softens almost imperceptibly. \"The Motherland will not forget this, Comrade.\"\n\nNew tanks roll off the assembly lines. Soldiers receive better equipment. The generals toast to your wisdom.\n\nBut the funds must come from somewhere. Factory modernization is delayed. Hospital supplies run short. The people tighten their belts.",
                    statEffects: ["militaryLoyalty": 20, "treasury": -25, "industrialOutput": -10],
                    personalEffects: ["standing": 5],
                    followUpHook: "The military remembers its friends...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .negotiate,
                    shortDescription: "Approve a modest increase, but demand efficiency reforms.",
                    immediateOutcome: "\"Twenty percent, Marshal. And I expect a full audit of current expenditures.\"\n\nAnderson's jaw tightens, but he nods. The military gets some of what it wants. The treasury survives.\n\nIn the barracks, officers grumble about civilian interference. But they cannot argue with the logic.",
                    statEffects: ["militaryLoyalty": 5, "treasury": -10],
                    personalEffects: ["standing": 3, "reputationCompetent": 8],
                    followUpHook: "The military reform commission begins its work...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .attack,
                    shortDescription: "Deny the request and question the military's spending priorities.",
                    immediateOutcome: "\"Perhaps, Marshal, if your generals spent less on their dachas and more on their soldiers, we would not be having this conversation.\"\n\nThe room goes silent. Anderson's face turns to stone.\n\nYou have made a powerful enemy today. But among the civilian ministers, there are nods of approval. Someone finally said it.",
                    statEffects: ["militaryLoyalty": -20, "treasury": 10, "eliteLoyalty": 5],
                    personalEffects: ["rivalThreat": 15, "reputationRuthless": 5],
                    followUpHook: "The Marshal has a long memory...",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 4. Foreign Diplomatic Incident
        Scenario(
            templateId: "foreign_incident",
            category: .crisis,
            briefing: "\"Our embassy in the Western capital was raided last night. Three of our diplomats have been expelled for 'espionage activities.'\" Foreign Secretary Kennedy pauses. \"They were, of course, doing exactly what they were accused of. But we cannot let this stand.\"",
            presenterName: "Secretary Kennedy",
            presenterTitle: "Foreign Affairs",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .attack,
                    shortDescription: "Expel their diplomats in retaliation and close their cultural center.",
                    immediateOutcome: "Within hours, Western diplomats are escorted to the airport. Their cultural center is padlocked. State media broadcasts footage of the expulsions.\n\nThe people cheer the strong response. The international community condemns it.\n\nBehind closed doors, back-channel communications go silent. The next crisis will be harder to manage.",
                    statEffects: ["internationalStanding": -20, "popularSupport": 10, "stability": 5],
                    personalEffects: ["standing": 5],
                    followUpHook: "Relations enter a deep freeze...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .negotiate,
                    shortDescription: "Issue a formal protest but maintain diplomatic relations.",
                    immediateOutcome: "The protest is lodged. The ambassador delivers a stern speech. Life continues.\n\nKennedy nods approvingly. \"Sometimes the strongest move is restraint, Comrade.\"\n\nThe hardliners mutter about weakness. But the trade agreements remain intact, and the back channels stay open.",
                    statEffects: ["internationalStanding": 5],
                    personalEffects: ["reputationCompetent": 5, "standing": -3],
                    followUpHook: "Quiet negotiations continue...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .deflect,
                    shortDescription: "Use this as justification to increase internal security measures.",
                    immediateOutcome: "\"This incident proves that foreign agents are everywhere,\" you announce. \"We must be more vigilant.\"\n\nNew security protocols are implemented. Travel restrictions tighten. Wallace's department receives expanded powers.\n\nThe foreign incident is forgotten. The new surveillance apparatus is not.",
                    statEffects: ["stability": 10, "popularSupport": -10],
                    personalEffects: ["patronFavor": 8, "network": 5],
                    followUpHook: "The security apparatus grows...",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 5. Party Faction Struggle
        Scenario(
            templateId: "party_faction",
            category: .crisis,
            briefing: "\"There is talk of a resolution at the next Party Congress.\" Comrade Peterson speaks quietly, glancing at the door. \"The reformists want to rehabilitate certain... former comrades. The conservatives are furious. The General Secretary has not indicated which way he will move.\"",
            presenterName: "Comrade Peterson",
            presenterTitle: "Secretary of Ideology",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .reform,
                    shortDescription: "Support the rehabilitation. It's time to address past mistakes.",
                    immediateOutcome: "Your speech at the Congress is measured but clear. \"We honor the party by acknowledging where it has erred.\"\n\nThe reformists embrace you as one of their own. The conservatives mark you as a dangerous revisionist.\n\nFamilies of the rehabilitated send grateful letters. In certain offices, your photograph is quietly removed from the wall.",
                    statEffects: ["eliteLoyalty": -10, "popularSupport": 15],
                    personalEffects: ["standing": 10, "patronFavor": -10],
                    followUpHook: "The conservatives plot their response...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .delay,
                    shortDescription: "Argue that the timing is wrong—propose a committee to study the matter.",
                    immediateOutcome: "\"This matter requires careful consideration,\" you declare. \"I propose a special committee to review each case individually.\"\n\nBoth sides are frustrated. Neither is satisfied. But neither can accuse you of opposing them.\n\nThe committee will deliberate for months. By then, the political winds may have shifted.",
                    statEffects: ["eliteLoyalty": 5],
                    personalEffects: ["standing": 3, "reputationCunning": 5],
                    followUpHook: "The committee begins its endless deliberations...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .repress,
                    shortDescription: "Oppose rehabilitation. The party's past decisions must not be questioned.",
                    immediateOutcome: "\"To rehabilitate these individuals is to condemn the party itself,\" you declare. \"I will not stand for it.\"\n\nThe conservatives rally to your banner. The reformists retreat, for now.\n\nPeterson looks at you with something like disappointment. But in the halls of power, the old guard nods approvingly.",
                    statEffects: ["eliteLoyalty": 15, "popularSupport": -10],
                    personalEffects: ["patronFavor": 10, "reputationLoyal": 10],
                    followUpHook: "The reformists bide their time...",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        )
    ]

    // MARK: - Routine Scenarios (Normal governance)

    private let routineScenarios: [Scenario] = [
        // 1. Budget Allocation
        Scenario(
            templateId: "budget_allocation",
            category: .routine,
            briefing: "\"The quarterly budget review, Comrade.\" Deputy Treasurer Orlova spreads papers across the table. \"We have modest surplus funds to allocate. The ministries have submitted their requests, but we cannot fund everything.\"",
            presenterName: "Deputy Orlova",
            presenterTitle: "State Treasury",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .appease,
                    shortDescription: "Prioritize military equipment upgrades.",
                    immediateOutcome: "The generals receive their new equipment. General Anderson personally thanks you at the next Politburo meeting.\n\n\"Sound investment in our defense capabilities,\" he announces. The other ministers note your priorities.",
                    statEffects: ["militaryLoyalty": 10, "treasury": -10],
                    personalEffects: ["standing": 3],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .reform,
                    shortDescription: "Invest in consumer goods production.",
                    immediateOutcome: "New production lines begin turning out radios, refrigerators, and textiles. The waiting lists at state stores grow shorter.\n\nWorkers smile a little more. The ideologues grumble about 'consumerism.' But empty shelves breed more discontent than any sermon.",
                    statEffects: ["popularSupport": 10, "industrialOutput": 5, "treasury": -10],
                    personalEffects: ["reputationCompetent": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .delay,
                    shortDescription: "Hold the funds in reserve for emergencies.",
                    immediateOutcome: "\"Prudent management,\" Orlova nods. The surplus remains untouched.\n\nNo one is particularly happy. No one is particularly upset. The treasury grows slightly larger, and you've made no enemies today.",
                    statEffects: ["treasury": 5],
                    personalEffects: ["reputationCompetent": 3],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 2. Cultural Exhibition
        Scenario(
            templateId: "cultural_exhibition",
            category: .routine,
            briefing: "\"The French have proposed a cultural exchange exhibition,\" announces Secretary Sullivan. \"Socialist realism displayed in Paris, French art here. It would be the first such exchange in years. The Foreign Ministry supports it, but the ideological implications concern some.\"",
            presenterName: "Secretary Sullivan",
            presenterTitle: "Culture and Propaganda",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .reform,
                    shortDescription: "Approve the exchange. Cultural opening shows confidence.",
                    immediateOutcome: "The exhibition opens to great fanfare. Western journalists photograph citizens studying Impressionist paintings.\n\nSome party members whisper about 'decadent influences.' But the international press coverage is overwhelmingly positive.\n\n\"A new chapter in cultural relations,\" the French ambassador declares.",
                    statEffects: ["internationalStanding": 10, "eliteLoyalty": -5],
                    personalEffects: ["standing": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .negotiate,
                    shortDescription: "Accept, but curate the Western art carefully.",
                    immediateOutcome: "The exhibition proceeds, but only 'acceptable' Western works are displayed. Landscapes and still lifes. Nothing too abstract or provocative.\n\nThe French are mildly disappointed. The conservatives are mildly reassured. The cultural event becomes thoroughly unremarkable.",
                    statEffects: ["internationalStanding": 5],
                    personalEffects: ["reputationCompetent": 3],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .repress,
                    shortDescription: "Decline. Socialist art needs no Western validation.",
                    immediateOutcome: "\"Our artists serve the people, not the bourgeois salons of Galliaport,\" you declare.\n\nThe conservatives applaud. The opportunity for cultural diplomacy passes.\n\nSullivan hides his disappointment. In Western capitals, they note the rejection.",
                    statEffects: ["internationalStanding": -5, "eliteLoyalty": 5],
                    personalEffects: ["reputationLoyal": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 3. Regional Appointment
        Scenario(
            templateId: "regional_appointment",
            category: .routine,
            briefing: "\"The governor of the Eastern Province has requested retirement due to health reasons.\" Comrade Nielsen reviews the dossiers. \"We have two candidates. Comrade Mitchell is experienced but old guard. Comrade Barnes is younger, more dynamic, but less connected.\"",
            presenterName: "Comrade Nielsen",
            presenterTitle: "Personnel Department",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .appease,
                    shortDescription: "Recommend Mitchell. Experience matters.",
                    immediateOutcome: "Mitchell assumes the position. The old guard approves—one of their own elevated.\n\nThe province continues much as before. Stability maintained, if not progress.\n\nMitchell will remember who recommended him.",
                    statEffects: ["eliteLoyalty": 5, "stability": 5],
                    personalEffects: ["network": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .reform,
                    shortDescription: "Recommend Barnes. Fresh leadership is needed.",
                    immediateOutcome: "Barnes's appointment surprises many. She immediately begins implementing new agricultural techniques.\n\nThe old guard mutters about 'inexperience.' The younger officials see a sign of opportunity.\n\nBarnes will remember who gave her this chance.",
                    statEffects: ["eliteLoyalty": -5, "industrialOutput": 5],
                    personalEffects: ["standing": 5, "network": 3],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .deflect,
                    shortDescription: "Suggest a third candidate—someone neutral.",
                    immediateOutcome: "\"Perhaps we should consider expanding the search,\" you suggest. A compromise candidate is found.\n\nNeither faction is pleased, but neither is offended. The province receives competent if uninspired leadership.\n\nYou've avoided making any commitments.",
                    statEffects: [:],
                    personalEffects: ["reputationCunning": 3],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 4. Protocol Violation
        Scenario(
            templateId: "protocol_violation",
            category: .routine,
            briefing: "\"An awkward matter, Comrade.\" Secretary Irving looks uncomfortable. \"At the state dinner last week, Ambassador Foster's remarks about Western agricultural practices were... enthusiastic. Too enthusiastic. Some have complained. It's technically a protocol violation.\"",
            presenterName: "Secretary Irving",
            presenterTitle: "Protocol Office",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .repress,
                    shortDescription: "Foster must face consequences. Standards must be maintained.",
                    immediateOutcome: "Foster is quietly recalled from his position. His career, which spanned decades, ends not with a bang but with a memo.\n\nThe diplomatic corps takes note. Future dinner conversations become more carefully scripted.\n\nFoster's friends remember your role in his downfall.",
                    statEffects: ["stability": 5],
                    personalEffects: ["network": -5, "reputationRuthless": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .deflect,
                    shortDescription: "A private warning should suffice. No need for formal action.",
                    immediateOutcome: "Foster receives a quiet reprimand. He's more careful at the next dinner.\n\nThe complainers are not entirely satisfied, but the matter fades. Foster remains at his post.\n\nHe catches your eye at the next reception. A small nod of gratitude.",
                    statEffects: [:],
                    personalEffects: ["network": 3],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .attack,
                    shortDescription: "Who complained? Perhaps they should be investigated.",
                    immediateOutcome: "\"Before we discuss Foster, perhaps we should examine why certain comrades are so eager to report their colleagues.\"\n\nIrving blinks. The complaint mysteriously vanishes. So does the complainant's next promotion.\n\nWord spreads: bringing matters to your attention can be dangerous.",
                    statEffects: ["stability": -5],
                    personalEffects: ["reputationCunning": 5, "reputationRuthless": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        )
    ]

    // MARK: - Opportunity Scenarios (Chances for advancement)

    private let opportunityScenarios: [Scenario] = [
        // 1. Foreign Delegation
        Scenario(
            templateId: "foreign_delegation",
            category: .opportunity,
            briefing: "\"A delegation from the Non-Aligned Movement will visit next month.\" Foreign Secretary Kennedy looks thoughtful. \"They are considering closer ties. Someone must lead the welcoming committee. It's a visible role—success or failure will be noticed.\"",
            presenterName: "Secretary Kennedy",
            presenterTitle: "Foreign Affairs",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .negotiate,
                    shortDescription: "Volunteer to lead the delegation. This is an opportunity.",
                    immediateOutcome: "You spend weeks preparing. The delegation arrives, and everything proceeds smoothly. Trade agreements are discussed. Photographs are taken.\n\nThe General Secretary mentions your name favorably at the Politburo. \"Comrade handled the visitors well.\"\n\nKennedy notes your ambition. So do others.",
                    statEffects: ["internationalStanding": 10],
                    personalEffects: ["standing": 10, "rivalThreat": 5],
                    followUpHook: "Your visibility has increased...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .delay,
                    shortDescription: "Suggest a colleague better suited for the role.",
                    immediateOutcome: "Deputy Wallace's nephew gets the assignment. The delegation proceeds adequately.\n\nYou've avoided risk. Wallace appreciates your deference. Some wonder why you passed on the opportunity.\n\n\"Not ambitious enough,\" someone whispers. \"Or too clever by half.\"",
                    statEffects: ["internationalStanding": 5],
                    personalEffects: ["patronFavor": 5, "standing": -3],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .deflect,
                    shortDescription: "Propose a joint committee—share the risk and the glory.",
                    immediateOutcome: "A committee is formed. Responsibilities are distributed. When the delegation arrives, several officials share the spotlight.\n\nThe event succeeds, though no one receives particular credit. You've avoided risk while remaining involved.\n\nKennedy notes your political instincts.",
                    statEffects: ["internationalStanding": 5],
                    personalEffects: ["reputationCunning": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 2. Patron's Project
        Scenario(
            templateId: "patron_project",
            category: .opportunity,
            briefing: "Director Wallace summons you privately. \"The General Secretary wants a new sports complex built for the Youth Games. He's mentioned it several times. I'm looking for someone to oversee the project. Successfully, of course.\"",
            presenterName: "Director Wallace",
            presenterTitle: "Head of State Security",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .appease,
                    shortDescription: "Accept enthusiastically. This is the General Secretary's pet project.",
                    immediateOutcome: "The sports complex becomes your responsibility. Months of construction oversight follow. You push contractors, redirect materials, pull strings.\n\nThe complex opens on time. The General Secretary smiles at the ribbon cutting.\n\n\"Well done,\" Wallace says afterward. \"The old man is pleased.\"",
                    statEffects: ["treasury": -10],
                    personalEffects: ["patronFavor": 15, "standing": 8],
                    followUpHook: "The General Secretary remembers those who deliver...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .negotiate,
                    shortDescription: "Accept, but request adequate resources and authority.",
                    immediateOutcome: "\"I'll need real authority over contractors and materials allocation,\" you tell Wallace.\n\nHe nods. \"Reasonable. I'll arrange it.\"\n\nThe project proceeds with fewer obstacles. The complex opens successfully, though some resent your expanded powers.",
                    statEffects: ["treasury": -5],
                    personalEffects: ["patronFavor": 10, "standing": 5, "rivalThreat": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .delay,
                    shortDescription: "Hesitate. This project has many ways to fail.",
                    immediateOutcome: "\"I'm not certain I'm the right choice, Comrade Minister.\"\n\nWallace's expression flickers. \"I see. I'll find someone else.\"\n\nThe project goes to another. When construction delays occur, you're glad you declined. But Wallace remembers your hesitation.",
                    statEffects: [:],
                    personalEffects: ["patronFavor": -10, "reputationCompetent": -5],
                    followUpHook: "Wallace's disappointment lingers...",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 3. Rival's Stumble
        Scenario(
            templateId: "rival_stumble",
            category: .opportunity,
            briefing: "Your aide Sasha speaks quietly. \"Comrade, I have news. Deputy Minister Graham—the one who blocked your initiative last month—has made an error. His department's production figures were falsified. I have documentation. What would you like me to do with it?\"",
            presenterName: "Sasha",
            presenterTitle: "Personal Aide",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .attack,
                    shortDescription: "Forward the evidence to the appropriate authorities.",
                    immediateOutcome: "The documentation reaches the Central Committee. An investigation follows. Graham is removed from his position within weeks.\n\nHis allies know who provided the evidence. But they are scattered now, leaderless.\n\nYou've made enemies. But you've also removed one.",
                    statEffects: ["stability": -5],
                    personalEffects: ["rivalThreat": -15, "reputationRuthless": 10, "network": -5],
                    followUpHook: "Graham's allies remember...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .negotiate,
                    shortDescription: "Approach Graham privately. He now owes you.",
                    immediateOutcome: "You request a private meeting. The documents are displayed. Graham goes pale.\n\n\"I think we can come to an understanding, Comrade.\"\n\nHe nods slowly. A former enemy becomes a reluctant asset. The evidence remains in your safe.",
                    statEffects: [:],
                    personalEffects: ["network": 10, "reputationCunning": 10],
                    followUpHook: "Graham is now in your debt...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .delay,
                    shortDescription: "Hold the information for now. Timing is everything.",
                    immediateOutcome: "\"Keep this safe, Sasha. We'll know when to use it.\"\n\nThe documentation goes into your private files. Graham continues his career, unaware of the sword hanging over him.\n\nSomeday, the timing will be right.",
                    statEffects: [:],
                    personalEffects: ["reputationCunning": 5],
                    followUpHook: "The evidence waits in your files...",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 4. Committee Vacancy
        Scenario(
            templateId: "committee_vacancy",
            category: .opportunity,
            briefing: "\"Comrade Evans has passed away.\" Secretary Nielsen adjusts his papers. \"His seat on the Economic Planning Committee is now vacant. Several names are being considered. Your name has been mentioned.\"",
            presenterName: "Secretary Nielsen",
            presenterTitle: "Personnel Department",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .negotiate,
                    shortDescription: "Actively campaign for the position.",
                    immediateOutcome: "You make calls, arrange meetings, remind colleagues of past favors. The lobbying is transparent but effective.\n\nThe appointment is announced. You join the Economic Planning Committee.\n\nSome admire your ambition. Others note your eagerness. The position brings both influence and scrutiny.",
                    statEffects: ["industrialOutput": 5],
                    personalEffects: ["standing": 12, "rivalThreat": 8],
                    followUpHook: "Your new position draws attention...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .delay,
                    shortDescription: "Express interest quietly, but let others advocate for you.",
                    immediateOutcome: "You mention your interest to the right people, then step back. Allies speak on your behalf.\n\nThe appointment goes to another—but one who remembers your discretion. You're told you'll be considered for the next vacancy.\n\n\"Patience is a virtue,\" Nielsen observes.",
                    statEffects: [:],
                    personalEffects: ["standing": 3, "reputationCompetent": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .deflect,
                    shortDescription: "Recommend a colleague instead—build goodwill.",
                    immediateOutcome: "\"I'm not certain I'm ready, Comrade Nielsen. Perhaps Deputy Vasquez would serve better.\"\n\nVasquez receives the appointment. She's publicly grateful. A future ally, perhaps.\n\nThe General Secretary's office notes your recommendation. Selflessness—or strategy?",
                    statEffects: [:],
                    personalEffects: ["network": 8, "standing": -3],
                    followUpHook: "Vasquez remembers your generosity...",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        )
    ]

    // MARK: - Character Scenarios (NPC-driven events)

    private let characterScenarios: [Scenario] = [
        // 1. Patron's Test
        Scenario(
            templateId: "patron_test",
            category: .character,
            briefing: "Director Wallace invites you to his dacha for the weekend. \"Just a few close colleagues,\" he says. \"Informal. We'll discuss... various matters.\" His eyes hold yours a moment longer than necessary. This is more than a social invitation.",
            presenterName: "Director Wallace",
            presenterTitle: "Head of State Security",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .appease,
                    shortDescription: "Accept immediately. A patron's invitation is a command.",
                    immediateOutcome: "The weekend at Wallace's dacha is tense beneath the surface pleasantries. He probes your loyalties, your ambitions, your weaknesses.\n\nBy Sunday, you've passed some unspoken test. \"I think we understand each other now,\" he says as you leave.\n\nYou are more deeply in his orbit than before.",
                    statEffects: [:],
                    personalEffects: ["patronFavor": 15, "network": 5],
                    followUpHook: "Wallace's trust brings expectations...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .negotiate,
                    shortDescription: "Accept, but bring your spouse. Keep it social.",
                    immediateOutcome: "You arrive with your spouse, deflecting the invitation's more intimate implications.\n\nWallace's expression flickers—surprise, then something like respect. \"A family man,\" he says. \"Good.\"\n\nThe weekend remains social. You've kept distance without giving offense.",
                    statEffects: [:],
                    personalEffects: ["patronFavor": 5, "reputationCompetent": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .delay,
                    shortDescription: "Decline politely—previous commitments.",
                    immediateOutcome: "\"I regret I cannot attend, Comrade Minister. Family obligations.\"\n\nWallace's smile doesn't reach his eyes. \"Of course. Another time.\"\n\nBut there may not be another time. Some doors, once closed, stay closed.",
                    statEffects: [:],
                    personalEffects: ["patronFavor": -10, "standing": -5],
                    followUpHook: "Wallace's disappointment is noted...",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 2. Rival's Approach
        Scenario(
            templateId: "rival_approach",
            category: .character,
            briefing: "You find Deputy Graham waiting in your office. He shouldn't be here. \"We need to talk,\" he says. \"Our... disagreements have been counterproductive. Perhaps we share more interests than you realize.\"",
            presenterName: "Deputy Graham",
            presenterTitle: "Your Known Rival",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .negotiate,
                    shortDescription: "Hear him out. Even enemies can be useful.",
                    immediateOutcome: "You listen. Graham proposes a temporary alliance against a common threat—the rising influence of the reformists.\n\n\"We don't have to like each other,\" he says. \"Just recognize our mutual interests.\"\n\nAn uneasy truce begins. Trust remains scarce.",
                    statEffects: [:],
                    personalEffects: ["rivalThreat": -10, "reputationCunning": 5],
                    followUpHook: "The alliance with Graham is fragile...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .attack,
                    shortDescription: "Reject him coldly. He's desperate and dangerous.",
                    immediateOutcome: "\"Get out of my office, Graham.\"\n\nHis face hardens. \"You'll regret this.\"\n\nPerhaps. But better a known enemy than a treacherous ally. Graham leaves, his desperation confirmed.",
                    statEffects: [:],
                    personalEffects: ["rivalThreat": 10, "reputationRuthless": 5],
                    followUpHook: "Graham's enmity deepens...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .deflect,
                    shortDescription: "Seem interested, but commit to nothing.",
                    immediateOutcome: "You nod thoughtfully, ask questions, make vague agreements. Graham leaves believing he's made progress.\n\nYou've learned his concerns without revealing yours. The information may prove useful.\n\nBut Graham will eventually realize he's been played.",
                    statEffects: [:],
                    personalEffects: ["reputationCunning": 10],
                    followUpHook: "Graham will expect follow-through...",
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 3. Old Friend
        Scenario(
            templateId: "old_friend",
            category: .character,
            briefing: "A letter arrives from David, your old university friend. He's been assigned to a remote posting—clearly a punishment. \"I made enemies,\" he writes. \"I need someone to speak for me. You're the only one who might help.\"",
            presenterName: "David",
            presenterTitle: "Old University Friend",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .negotiate,
                    shortDescription: "Use your connections to help him. Friends matter.",
                    immediateOutcome: "You make calls, call in favors. Within months, David receives a better posting.\n\nHe writes again—grateful, almost tearful. \"I won't forget this.\"\n\nSome colleagues notice your efforts. \"Loyal to his friends,\" they say. Is that admiration or warning?",
                    statEffects: [:],
                    personalEffects: ["network": 8, "patronFavor": -5, "reputationLoyal": 10],
                    followUpHook: "David owes you a significant debt...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .delay,
                    shortDescription: "Promise to help, but move slowly. Be careful.",
                    immediateOutcome: "You write encouraging letters, make tentative inquiries. Nothing too obvious.\n\nMonths pass. David remains in his posting, but hope keeps him going. Eventually, a modest improvement comes.\n\n\"Better than nothing,\" he writes. There's disappointment beneath the gratitude.",
                    statEffects: [:],
                    personalEffects: ["network": 3, "reputationCunning": 3],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .repress,
                    shortDescription: "Distance yourself. He made his enemies; you have yours.",
                    immediateOutcome: "You don't reply to the letter. David writes again, then again. Eventually, the letters stop.\n\nYears later, you hear he died in the remote posting. Natural causes, they say.\n\nYou've protected yourself. The price was an old friendship.",
                    statEffects: [:],
                    personalEffects: ["network": -5, "reputationRuthless": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        ),

        // 4. Subordinate's Problem
        Scenario(
            templateId: "subordinate_problem",
            category: .character,
            briefing: "Your secretary, Anya, asks to speak privately. She's pale. \"Comrade, my brother has been arrested. They say he's a dissident. He's not—he just asked questions. I wouldn't ask, but...\" She trails off, terrified.",
            presenterName: "Anya",
            presenterTitle: "Personal Secretary",
            options: [
                ScenarioOption(
                    id: "A",
                    archetype: .negotiate,
                    shortDescription: "Look into it. A loyal secretary is worth protecting.",
                    immediateOutcome: "You make discreet inquiries. The brother's case is minor—wrong questions at the wrong time.\n\nA word in the right ear. The charges are reduced. He's released with a warning.\n\nAnya's gratitude is boundless. She will never betray you now.",
                    statEffects: ["stability": -3],
                    personalEffects: ["network": 10, "patronFavor": -3],
                    followUpHook: "Anya's loyalty is absolute...",
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "B",
                    archetype: .delay,
                    shortDescription: "Express sympathy but explain you cannot interfere.",
                    immediateOutcome: "\"I understand, Anya. But these matters... I cannot be seen to interfere.\"\n\nShe nods, eyes wet. \"I understand, Comrade.\"\n\nShe continues working, efficient as ever. But something has changed. She knows the limits of your protection.",
                    statEffects: [:],
                    personalEffects: ["network": -3],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                ),
                ScenarioOption(
                    id: "C",
                    archetype: .repress,
                    shortDescription: "Tell her to forget she has a brother. These associations are dangerous.",
                    immediateOutcome: "\"Anya, you must understand. If your brother is under investigation, any connection to him threatens us both. You must distance yourself.\"\n\nShe stares at you, something dying in her eyes. \"Yes, Comrade.\"\n\nShe continues working. But the efficiency now has a mechanical quality.",
                    statEffects: [:],
                    personalEffects: ["network": -5, "reputationRuthless": 5],
                    followUpHook: nil,
                    isLocked: false,
                    lockReason: nil
                )
            ],
            isFallback: true
        )
    ]

    // MARK: - Introduction Scenario (Turn 1 only)

    private let introductionScenario = Scenario(
        templateId: "introduction",
        category: .introduction,
        briefing: """
        The heavy oak doors of the General Secretary's office close behind you. The room is larger than you expected — mahogany desk, red curtains, a wall of telephones connecting you to every ministry, every military district, every corner of the Republic.

        Your chief of staff, Sasha, sets a leather portfolio on the desk. "Comrade General Secretary. Your first morning briefing."

        "Director Wallace championed your candidacy on the Standing Committee. He expects loyalty — and he controls State Security. Deputy Director Sullivan believes he should be sitting where you sit."

        Sasha opens the portfolio. "The Standing Committee is fractured. Three factions are maneuvering. But you hold the seals of office. How do you wish to begin?"
        """,
        presenterName: "Sasha",
        presenterTitle: "Chief of Staff",
        options: [
            ScenarioOption(
                id: "A",
                archetype: .appease,
                shortDescription: "Summon Director Wallace. Reward your champion on the Standing Committee.",
                immediateOutcome: """
                Wallace arrives promptly — the head of State Security does not keep the General Secretary waiting. He sits across from you, smoke curling from his cigarette.

                "You made the right choice, Comrade General Secretary. I didn't champion you out of sentiment. I championed you because you can be trusted to keep things... stable."

                He briefs you on the state of play — which Standing Committee members are reliable, which are already meeting privately with Sullivan, where the military's true loyalties lie.

                "I am your shield," Wallace says, rising to leave. "Use me wisely."

                You now understand your patron's price: his continued power over the security apparatus.
                """,
                statEffects: [:],
                personalEffects: ["patronFavor": 10, "standing": 3],
                followUpHook: "Wallace expects to remain the most powerful man after you...",
                isLocked: false,
                lockReason: nil
            ),
            ScenarioOption(
                id: "B",
                archetype: .negotiate,
                shortDescription: "Review your predecessor's private files. Learn what he knew — and feared.",
                immediateOutcome: """
                The safe behind the portrait contains decades of secrets. Dossiers on every Standing Committee member. Financial records. Intelligence assessments. Personal correspondence that would destroy careers.

                Your predecessor knew everything about everyone. And someone — or something — still killed him.

                A web of relationships emerges. Wallace's shadow network. Sullivan's foreign contacts. The Defense Minister's secret meetings with regional commanders.

                "Knowledge is the only true power in this building," Sasha observes. "Your predecessor understood that. It didn't save him."

                But now you know what he knew. And that changes everything.
                """,
                statEffects: [:],
                personalEffects: ["network": 8, "reputationCompetent": 5],
                followUpHook: "The secrets of the dead carry a weight of their own...",
                isLocked: false,
                lockReason: nil
            ),
            ScenarioOption(
                id: "C",
                archetype: .deflect,
                shortDescription: "Convene the Standing Committee. Let them speak first — observe the factions.",
                immediateOutcome: """
                The Standing Committee chamber falls silent as you enter. Seven faces study you — allies, rivals, and the undecided.

                You say little. You let them debate the agricultural quota revisions, the embassy staffing requests, the border patrol budget. You watch who allies with whom, who defers to Sullivan, who glances at Wallace for guidance.

                The old Marshal, Anderson, watches you watching them. A flicker of respect crosses his weathered face.

                "The new General Secretary listens," someone murmurs afterward. Some find this reassuring. Others find it unsettling.

                You now know the factional map. The real work begins tomorrow.
                """,
                statEffects: [:],
                personalEffects: ["standing": 3, "reputationCunning": 5],
                followUpHook: "Your silence has been noted — and interpreted in many ways...",
                isLocked: false,
                lockReason: nil
            ),
            ScenarioOption(
                id: "D",
                archetype: .attack,
                shortDescription: "Issue your first directive. Show them the office has a new occupant.",
                immediateOutcome: """
                Before the Standing Committee can settle into routine, you announce a directive: an immediate review of all ministerial appointments made in the last six months of your predecessor's tenure.

                The room freezes. Sullivan's jaw tightens — several of those appointments were his allies. Wallace leans back, surprised but intrigued.

                "Comrade General Secretary," Sullivan begins carefully, "surely the wisdom of continuity—"

                "The review will be completed within the month," you reply. "That is all."

                You have drawn a line. Everyone in this room now understands that the old arrangements are not guaranteed. Some will respect this. Others will begin plotting immediately.
                """,
                statEffects: ["stability": -5],
                personalEffects: ["standing": 10, "rivalThreat": 8],
                followUpHook: "Your first act as General Secretary sent a clear signal — for better or worse...",
                isLocked: false,
                lockReason: nil
            )
        ],
        isFallback: true
    )

    // MARK: - Routine Day Scenarios (No decisions, just atmosphere)

    private let routineDayScenarios: [Scenario] = [
        Scenario(
            templateId: "routine_morning_briefing",
            category: .routineDay,
            format: .narrative,
            briefing: "The morning briefing proceeds as usual. Ministers present their reports one by one — production figures, diplomatic cables, troop readiness assessments. They watch your face for reactions, calibrating their words to your mood.\n\nYou sign authorizations, ask a pointed question about grain reserves, and dismiss them by noon.",
            presenterName: "Sasha",
            presenterTitle: "Chief of Staff",
            options: [],
            narrativeConclusion: "By midday, you've reviewed seventeen reports, authorized four ministerial requests, and set the agenda for next week's Standing Committee session. The machinery of state grinds forward under your signature. Tedium means stability, and stability means survival.",
            isFallback: true
        ),
        Scenario(
            templateId: "routine_paperwork",
            category: .routineDay,
            format: .narrative,
            briefing: "Your desk is covered with papers requiring the General Secretary's signature. Agricultural quotas. Military procurement authorizations. Ambassadorial credentials. Each one a small act of state power.\n\nSasha brings tea. Outside, guards patrol the courtyard below. The radiator clicks and hums.",
            presenterName: "Sasha",
            presenterTitle: "Chief of Staff",
            options: [],
            narrativeConclusion: "Hours pass in methodical work. No crises today. No betrayals to navigate. Just the quiet weight of decisions that affect millions. Tomorrow may bring storms — but today is for governance.",
            isFallback: true
        ),
        Scenario(
            templateId: "routine_committee_meeting",
            category: .routineDay,
            format: .narrative,
            briefing: "You preside over the Committee on Agricultural Development for its monthly review. The ministers report their figures, eyes downcast. No one wants to be the bearer of bad numbers to the General Secretary.\n\nThe data is unremarkable. You let them sweat anyway.",
            presenterName: "Committee Chairman",
            presenterTitle: "Agricultural Development",
            options: [],
            narrativeConclusion: "The meeting ends when you decide it ends. Nothing dramatic was accomplished, but your presence reminded every minister in the room who holds the authority. These gatherings exist to demonstrate that you are watching. You return to your office.",
            isFallback: true
        ),
        Scenario(
            templateId: "routine_quiet_lunch",
            category: .routineDay,
            format: .narrative,
            briefing: "The General Secretary's private dining room is silent today. You eat alone — borscht, black bread, strong tea. Through the window, guards and officials move through the courtyard.\n\nFor once, no one has requested an audience. The telephones are quiet.",
            presenterName: "",
            presenterTitle: nil,
            options: [],
            narrativeConclusion: "You finish your meal in rare solitude. At this level, being left alone is either a luxury or a warning. Today, you choose to believe it is a luxury. Tomorrow, the factions will resume their maneuvering, the ministers their petitions, the generals their demands. But this hour belongs to you.",
            isFallback: true
        ),
        Scenario(
            templateId: "routine_reviewing_files",
            category: .routineDay,
            format: .narrative,
            briefing: "Sasha has organized this week's intelligence summaries — the ones marked for the General Secretary's eyes only. Troop movements on the northern border. A foreign ambassador's private remarks at a reception. An intercepted cable between two Standing Committee members.",
            presenterName: "Sasha",
            presenterTitle: "Chief of Staff",
            options: [],
            narrativeConclusion: "The reports reveal little you didn't already suspect. But reading them is the ritual of power — knowing what others think you don't know. The intercepted cable between Standing Committee members is filed away for future use. In this office, even routine intelligence is a weapon waiting to be deployed.",
            isFallback: true
        ),
        Scenario(
            templateId: "routine_waiting",
            category: .routineDay,
            format: .narrative,
            briefing: "Your schedule shows three meetings this afternoon. The Defense Minister wants additional budget allocation. The Foreign Minister has concerns about the Soviet ambassador's latest demands. A regional governor requests a private audience.\n\nYou make them wait. All three sit in your anteroom, studying their papers, avoiding each other's eyes.",
            presenterName: "",
            presenterTitle: nil,
            options: [],
            narrativeConclusion: "Eventually, you see the Defense Minister first — sending a signal about priorities. The Foreign Minister is next, and briefer than expected. The regional governor is told the General Secretary is tired; his meeting will be rescheduled. He returns to his province with his questions unanswered. Being made to wait is its own kind of message.",
            isFallback: true
        )
    ]

    // MARK: - Character Moment Scenarios (Brief NPC interactions, no decisions)

    private let characterMomentScenarios: [Scenario] = [
        Scenario(
            templateId: "moment_corridor_encounter",
            category: .characterMoment,
            format: .interlude,
            briefing: "Sullivan steps aside in the corridor to let you pass. His deference is correct — perfectly timed, perfectly calibrated.\n\n\"Comrade General Secretary,\" he says, with a smile that doesn't reach his eyes.\n\nYou nod and continue walking. Your security detail falls into step behind you. But you can feel Sullivan watching.",
            presenterName: "Deputy Sullivan",
            presenterTitle: "Your Chief Rival",
            options: [],
            narrativeConclusion: "A moment passes. The encounter means nothing — or everything. Sullivan was once favored for this office. Every greeting is a reminder that he believes he was robbed. You file it away and move on.",
            isFallback: true
        ),
        Scenario(
            templateId: "moment_patron_nod",
            category: .characterMoment,
            format: .interlude,
            briefing: "Director Wallace lingers after the Standing Committee session. The others file out, but Wallace takes his time gathering papers, clearly waiting for a private word.\n\nHe catches your eye. A slight nod — conspiratorial, almost paternal.\n\n\"Well managed, Comrade General Secretary,\" he murmurs, and leaves.",
            presenterName: "Director Wallace",
            presenterTitle: "Your Key Ally",
            options: [],
            narrativeConclusion: "Wallace's approval should be reassuring. Instead, it reminds you of the price of his support. The head of State Security does not offer praise freely. Every compliment is a claim on future loyalty.",
            isFallback: true
        ),
        Scenario(
            templateId: "moment_overheard_whispers",
            category: .characterMoment,
            format: .interlude,
            briefing: "Your security detail reports that two Standing Committee members were seen meeting privately in Sullivan's office last evening. No official agenda was filed.\n\nSasha adds quietly: \"The same two members who abstained during your election vote, Comrade General Secretary.\"",
            presenterName: "Sasha",
            presenterTitle: "Chief of Staff",
            options: [],
            narrativeConclusion: "You file the information away. Sullivan, the abstainers, a private meeting. Perhaps nothing. Perhaps the first stirring of a coalition against you. In this building, private meetings always precede storms.",
            isFallback: true
        ),
        Scenario(
            templateId: "moment_aide_observation",
            category: .characterMoment,
            format: .interlude,
            briefing: "Sasha leans in while organizing your briefing papers. \"Comrade General Secretary, I thought you should know — General Anderson has been making inquiries about the military budget through unofficial channels. Not through your office, but through the Defense Ministry directly.\"\n\nYour chief of staff's expression is carefully neutral.",
            presenterName: "Sasha",
            presenterTitle: "Chief of Staff",
            options: [],
            narrativeConclusion: "Why would the Defense Minister bypass the General Secretary's office? Is he testing your authority? Building a power base? Or simply following old habits from your predecessor's time? You thank Sasha and make a mental note to remind Anderson who signs the budget.",
            isFallback: true
        ),
        Scenario(
            templateId: "moment_old_comrade",
            category: .characterMoment,
            format: .interlude,
            briefing: "An elderly marshal, retired now, approaches during a state reception. You remember him from the early days — a hero of the Revolution, now mostly forgotten.\n\n\"I served three General Secretaries,\" he says quietly, leaning on his cane. \"The ones who lasted listened more than they spoke.\" He raises his glass to you and shuffles away.",
            presenterName: "Retired Marshal",
            presenterTitle: "Hero of the Revolution",
            options: [],
            narrativeConclusion: "Was that advice? A warning? The old guard has seen leaders rise and fall. Perhaps he sees something in your future more clearly than you do. Or perhaps he's simply an old soldier, dispensing wisdom to anyone who will listen.",
            isFallback: true
        ),
        Scenario(
            templateId: "moment_photograph_removed",
            category: .characterMoment,
            format: .interlude,
            briefing: "You notice that the official portrait gallery in the main corridor has been updated. Your predecessor's photograph — the man whose death put you in this chair — has been replaced with yours.\n\nThe painter made you look sterner than you feel. But perhaps that's the point.",
            presenterName: "",
            presenterTitle: nil,
            options: [],
            narrativeConclusion: "Every General Secretary's portrait eventually comes down. Your predecessor's lasted fourteen years. You study your own face on the wall, wondering how long yours will remain. In this building, even art is a measure of survival.",
            isFallback: true
        )
    ]

    // MARK: - Tension Builder Scenarios (Foreshadowing, warnings)

    private let tensionBuilderScenarios: [Scenario] = [
        Scenario(
            templateId: "tension_patron_distant",
            category: .tensionBuilder,
            format: .narrative,
            briefing: "Director Wallace has declined your last three meeting requests. His secretary offers excuses — operational matters, field inspections, illness. But the head of State Security does not avoid the General Secretary without reason.\n\nThe silence is louder than any words.",
            presenterName: "Wallace's Secretary",
            presenterTitle: nil,
            options: [],
            narrativeConclusion: "You return to your desk, unease settling in your stomach. When your most powerful ally grows distant, it means something has changed. Has Wallace learned something? Is he hedging his bets? Or is he building something that doesn't include you? A General Secretary who cannot command the security services is a General Secretary on borrowed time.",
            isFallback: true
        ),
        Scenario(
            templateId: "tension_security_questions",
            category: .tensionBuilder,
            format: .narrative,
            briefing: "Sasha reports that State Security agents have been interviewing members of your personal staff. Routine vetting, they claim. But the questions are pointed — your meetings last month, who visited your private residence, which Standing Committee members you've dined with.\n\nSomeone ordered this inquiry. And it wasn't you.",
            presenterName: "Sasha",
            presenterTitle: "Chief of Staff",
            options: [],
            narrativeConclusion: "You are the General Secretary. The security services answer to you — in theory. But Wallace built that apparatus long before you took this office. If he's investigating you through his own organization, it means the ground beneath your feet is less solid than you thought.",
            isFallback: true
        ),
        Scenario(
            templateId: "tension_rivals_meeting",
            category: .tensionBuilder,
            format: .narrative,
            briefing: "Sasha reports that Sullivan was seen leaving General Anderson's private quarters at the military compound last evening. The Defense Minister and your chief rival rarely have cause to meet privately.\n\nUnless they've found common cause — against you.",
            presenterName: "Sasha",
            presenterTitle: "Chief of Staff",
            options: [],
            narrativeConclusion: "You dismiss Sasha with thanks, but the information burns. Sullivan with the military. If the Defense Minister throws his support behind Sullivan at the next Standing Committee session, the balance of power shifts. You need to shore up your own alliances — and quickly.",
            isFallback: true
        ),
        Scenario(
            templateId: "tension_empty_desk",
            category: .tensionBuilder,
            format: .narrative,
            briefing: "A regional governor — one who supported your candidacy — has been recalled to the capital for \"consultation.\" He has not been seen since arriving three days ago.\n\nHis deputy has assumed temporary control of the region. No official explanation has been issued.",
            presenterName: "",
            presenterTitle: nil,
            options: [],
            narrativeConclusion: "You did not order this recall. Which means someone else did — using your authority, or acting without it. Either possibility is alarming. If your allies can be disappeared without your knowledge, your control over the apparatus is weaker than it appears.",
            isFallback: true
        ),
        Scenario(
            templateId: "tension_standing_committee_mood",
            category: .tensionBuilder,
            format: .narrative,
            briefing: "The Standing Committee session today felt different. Normally deferential members challenged your agricultural quota proposal. Two abstained on a routine vote. Sullivan watched the proceedings with barely concealed satisfaction.\n\nThe balance is shifting.",
            presenterName: "",
            presenterTitle: nil,
            options: [],
            narrativeConclusion: "When the Standing Committee stops rubber-stamping your proposals, it means the factions are recalculating. Someone has been building a coalition — or at least testing whether one is possible. You need to identify which members are wavering and remind them why they supported you in the first place.",
            isFallback: true
        ),
        Scenario(
            templateId: "tension_foreign_journalists",
            category: .tensionBuilder,
            format: .narrative,
            briefing: "A delegation of Western journalists has arrived in the capital. Officially, they're covering the Youth Festival. Unofficially, they're publishing stories about internal power struggles — naming names, citing sources close to the Standing Committee.\n\nSomeone has been talking to foreign press. That is treason.",
            presenterName: "Sasha",
            presenterTitle: "Chief of Staff",
            options: [],
            narrativeConclusion: "Foreign journalists publishing accurate details about internal politics means someone powerful is feeding them information. Either to undermine you abroad, to signal foreign governments, or to create pressure for change. You need to find the leak — and decide what to do when you find it.",
            isFallback: true
        )
    ]
}
