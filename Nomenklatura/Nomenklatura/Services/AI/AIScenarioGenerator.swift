//
//  AIScenarioGenerator.swift
//  Nomenklatura
//
//  High-level service for AI-powered scenario generation with fallback
//

import Foundation

// MARK: - AI Scenario Generator

actor AIScenarioGenerator {
    static let shared = AIScenarioGenerator()

    // Cache for generated scenarios
    private var cache: [String: CachedScenario] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    // Track failures for circuit breaker
    private var consecutiveFailures = 0
    private let maxFailures = 3
    private var circuitBreakerResetTime: Date?

    // MARK: - Public API

    /// Generate a scenario using AI, with fallback to local scenarios
    /// The prompt must be pre-built on MainActor before calling this
    func generateScenario(prompt: String, cacheKey: String) async -> ScenarioResult {
        // Check if AI is enabled (access from MainActor)
        let aiEnabled = await MainActor.run { Secrets.isAIEnabled }
        guard aiEnabled else {
            return .fallback(reason: "AI not configured")
        }

        // Check circuit breaker
        if isCircuitOpen() {
            return .fallback(reason: "AI temporarily unavailable")
        }

        // Check cache
        if let cached = getCachedScenario(key: cacheKey) {
            return .success(cached.scenario, cached.metadata)
        }

        // Generate new scenario
        do {
            let (scenario, metadata) = try await generateFromAI(prompt: prompt)

            // Cache successful result
            cacheScenario(scenario, metadata: metadata, key: cacheKey)

            // Reset failure count on success
            consecutiveFailures = 0

            return .success(scenario, metadata)
        } catch {
            // Track failure
            consecutiveFailures += 1
            if consecutiveFailures >= maxFailures {
                openCircuitBreaker()
            }

            return .fallback(reason: error.localizedDescription)
        }
    }

    /// Check if AI generation is available
    func isAvailable() async -> Bool {
        let aiEnabled = await MainActor.run { Secrets.isAIEnabled }
        guard aiEnabled else { return false }
        guard !isCircuitOpen() else { return false }
        return await ClaudeClient.shared.checkConnection()
    }

    /// Clear the scenario cache
    func clearCache() {
        cache.removeAll()
    }

    /// Reset the circuit breaker (for testing/debugging)
    func resetCircuitBreaker() {
        consecutiveFailures = 0
        circuitBreakerResetTime = nil
    }

    // MARK: - Private Methods

    private func generateFromAI(prompt: String) async throws -> (Scenario, ScenarioNarrativeMetadata) {
        let startTime = Date()
        let promptTokenEstimate = prompt.count / 4  // Rough estimate: 4 chars per token
        #if DEBUG
        print("[AI] Starting API call with ~\(promptTokenEstimate) input tokens...")
        #endif

        // Call API
        let response = try await ClaudeClient.shared.generateScenario(prompt: prompt)
        let duration = Date().timeIntervalSince(startTime)

        // Log AI metrics for diagnostics
        logAIMetrics(
            promptTokens: response.usage.input_tokens,
            responseTokens: response.usage.output_tokens,
            duration: duration,
            success: true
        )

        // Extract text
        guard let text = response.text else {
            throw AIGeneratorError.noContent
        }

        // Validate and parse on MainActor
        let result = await MainActor.run {
            ScenarioValidator.validate(response: text)
        }

        switch result {
        case .valid(let scenario, let metadata):
            return (scenario, metadata)
        case .invalid(let reason):
            logAIMetrics(promptTokens: response.usage.input_tokens, responseTokens: response.usage.output_tokens, duration: duration, success: false, error: reason)
            throw AIGeneratorError.validationFailed(reason)
        }
    }

    // MARK: - Diagnostics

    private func logAIMetrics(promptTokens: Int, responseTokens: Int, duration: TimeInterval, success: Bool, error: String? = nil) {
        #if DEBUG
        let status = success ? "SUCCESS" : "FAILED"
        print("[AI] \(status) | Duration: \(String(format: "%.2f", duration))s | Input: \(promptTokens) tokens | Output: \(responseTokens) tokens")
        if let error = error {
            print("[AI] Error: \(error)")
        }
        #endif
    }

    // MARK: - Caching

    private func getCachedScenario(key: String) -> CachedScenario? {
        guard let cached = cache[key] else { return nil }

        // Check if expired
        if Date().timeIntervalSince(cached.timestamp) > cacheTimeout {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached
    }

    private func cacheScenario(_ scenario: Scenario, metadata: ScenarioNarrativeMetadata, key: String) {
        cache[key] = CachedScenario(scenario: scenario, metadata: metadata, timestamp: Date())

        // Clean old entries
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) < cacheTimeout }
    }

    // MARK: - Circuit Breaker

    private func isCircuitOpen() -> Bool {
        guard let resetTime = circuitBreakerResetTime else { return false }

        // Auto-reset after 60 seconds
        if Date() > resetTime {
            circuitBreakerResetTime = nil
            consecutiveFailures = 0
            return false
        }

        return true
    }

    private func openCircuitBreaker() {
        circuitBreakerResetTime = Date().addingTimeInterval(60)
    }
}

// MARK: - Result Types

enum ScenarioResult: Sendable {
    case success(Scenario, ScenarioNarrativeMetadata)
    case fallback(reason: String)

    var scenario: Scenario? {
        switch self {
        case .success(let scenario, _):
            return scenario
        case .fallback:
            return nil
        }
    }

    var metadata: ScenarioNarrativeMetadata? {
        switch self {
        case .success(_, let metadata):
            return metadata
        case .fallback:
            return nil
        }
    }

    var usedFallback: Bool {
        if case .fallback = self {
            return true
        }
        return false
    }
}

// MARK: - Errors

enum AIGeneratorError: LocalizedError, Sendable {
    case noContent
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noContent:
            return "AI returned no content"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        }
    }
}

// MARK: - Cache Entry

private struct CachedScenario: Sendable {
    let scenario: Scenario
    let metadata: ScenarioNarrativeMetadata
    let timestamp: Date
}
