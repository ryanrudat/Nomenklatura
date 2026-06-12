//
//  ClaudeClient.swift
//  Nomenklatura
//
//  Claude API client for AI-powered scenario generation
//

import Foundation

// MARK: - Claude Client

final class ClaudeClient: Sendable {
    static let shared = ClaudeClient()

    // Use proxy URL in production, direct API for local development
    private let baseURL = Secrets.proxyURL
    private let model = "claude-sonnet-4-6"  // Claude Sonnet 4.6 - latest balanced model
    private let maxTokens = 4096  // Headroom for the full scenario JSON (briefing + 3 options + metadata). At 2048 rich scenarios truncated mid-JSON → validator rejected them → silent fallback to canned content.
    private let temperature = 1.0  // High temperature for narrative variety / replayability

    // MARK: - Public API

    /// Generate a scenario using Claude (legacy single-prompt path).
    func generateScenario(prompt: String) async throws -> ClaudeResponse {
        guard Secrets.isAIEnabled else {
            #if DEBUG
            print("[ClaudeClient] AI not enabled - isAIEnabled returned false")
            #endif
            throw ClaudeError.apiKeyMissing
        }
        let request = try buildRequest(prompt: prompt)
        return try await executeRequest(request)
    }

    /// Generate a scenario using Claude with prompt caching enabled.
    /// The system prompt (static setting/role/guidance) is marked cacheable via cache_control so repeat calls pay only for the dynamic userPrompt tokens.
    func generateScenario(systemPrompt: String, userPrompt: String) async throws -> ClaudeResponse {
        guard Secrets.isAIEnabled else {
            #if DEBUG
            print("[ClaudeClient] AI not enabled - isAIEnabled returned false")
            #endif
            throw ClaudeError.apiKeyMissing
        }
        let request = try buildCachedRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
        return try await executeRequest(request)
    }

    /// Check if the API is available and key is valid
    func checkConnection() async -> Bool {
        guard Secrets.isAIEnabled else { return false }

        do {
            let request = try buildRequest(prompt: "Respond with only the word 'connected'")
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    /// Execute an already-built URLRequest and decode the response, with shared error handling.
    private func executeRequest(_ request: URLRequest) async throws -> ClaudeResponse {
        #if DEBUG
        print("[ClaudeClient] Making request to: \(baseURL)")
        #endif
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                print("[ClaudeClient] Invalid response - not HTTPURLResponse")
                #endif
                throw ClaudeError.invalidResponse
            }
            #if DEBUG
            print("[ClaudeClient] HTTP \(httpResponse.statusCode) - Response size: \(data.count) bytes")
            #endif
            switch httpResponse.statusCode {
            case 200:
                let decoded = try decodeResponse(data)
                #if DEBUG
                if decoded.stop_reason == "max_tokens" {
                    print("[ClaudeClient] ⚠️ stop_reason=max_tokens — output hit the \(maxTokens)-token cap and was truncated; JSON may be incomplete and fail validation.")
                }
                #endif
                return decoded
            case 401:
                throw ClaudeError.unauthorized
            case 429:
                throw ClaudeError.rateLimited
            case 500...599:
                throw ClaudeError.serverError(httpResponse.statusCode)
            default:
                let body = String(data: data, encoding: .utf8)
                #if DEBUG
                print("[ClaudeClient] HTTP error \(httpResponse.statusCode): \(body ?? "no body")")
                #endif
                throw ClaudeError.httpError(httpResponse.statusCode, body)
            }
        } catch let error as ClaudeError {
            throw error
        } catch {
            #if DEBUG
            print("[ClaudeClient] Network error: \(error.localizedDescription)")
            #endif
            throw error
        }
    }

    /// Build a URLRequest for a simple text prompt (no prompt caching).
    private func buildRequest(prompt: String) throws -> URLRequest {
        var request = try baseRequest()
        let body = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            temperature: temperature,
            messages: [ClaudeMessage(role: "user", content: prompt)]
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Build a URLRequest with prompt caching enabled: the system prompt is cacheable, the user prompt is dynamic.
    private func buildCachedRequest(systemPrompt: String, userPrompt: String) throws -> URLRequest {
        var request = try baseRequest()
        let body = CachedClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            temperature: temperature,
            system: [SystemBlock(type: "text", text: systemPrompt, cache_control: CacheControl(type: "ephemeral"))],
            messages: [ClaudeMessage(role: "user", content: userPrompt)]
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Shared URLRequest skeleton: URL, method, headers, timeout.
    private func baseRequest() throws -> URLRequest {
        guard let url = URL(string: baseURL) else { throw ClaudeError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if Secrets.useDirectAPI {
            request.addValue(Secrets.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else {
            request.addValue(Secrets.proxyAuthToken, forHTTPHeaderField: "x-proxy-token")
        }
        request.timeoutInterval = 45
        return request
    }

    private func decodeResponse(_ data: Data) throws -> ClaudeResponse {
        do {
            return try JSONDecoder().decode(ClaudeResponse.self, from: data)
        } catch {
            if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw ClaudeError.apiError(errorResponse.error.message)
            }
            throw ClaudeError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Request/Response Models

struct ClaudeRequest: Encodable, Sendable {
    let model: String
    let max_tokens: Int
    let temperature: Double
    let messages: [ClaudeMessage]
}

/// Request body with Anthropic prompt-caching markers on the system block.
struct CachedClaudeRequest: Encodable, Sendable {
    let model: String
    let max_tokens: Int
    let temperature: Double
    let system: [SystemBlock]
    let messages: [ClaudeMessage]
}

/// A system prompt content block that can carry a cache_control marker.
struct SystemBlock: Encodable, Sendable {
    let type: String
    let text: String
    let cache_control: CacheControl?
}

/// Anthropic cache control marker. {"type": "ephemeral"} turns on prompt caching for the preceding content.
struct CacheControl: Encodable, Sendable {
    let type: String  // Currently only "ephemeral" is supported
}

struct ClaudeMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct ClaudeResponse: Decodable, Sendable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stop_reason: String?
    let usage: ClaudeUsage

    nonisolated var text: String? {
        content.first { $0.type == "text" }?.text
    }
}

struct ClaudeContent: Decodable, Sendable {
    let type: String
    let text: String?
}

struct ClaudeUsage: Decodable, Sendable {
    let input_tokens: Int
    let output_tokens: Int
    let cache_creation_input_tokens: Int?
    let cache_read_input_tokens: Int?
}

struct ClaudeErrorResponse: Decodable, Sendable {
    let type: String
    let error: ClaudeAPIError
}

struct ClaudeAPIError: Decodable, Sendable {
    let type: String
    let message: String
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError(Int)
    case httpError(Int, String?)
    case apiError(String)
    case decodingError(String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key not configured. Add your key to Secrets.swift"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid API key"
        case .rateLimited:
            return "Rate limited - please wait before trying again"
        case .serverError(let code):
            return "Server error (\(code))"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message ?? "Unknown")"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .noContent:
            return "No content in response"
        }
    }
}
