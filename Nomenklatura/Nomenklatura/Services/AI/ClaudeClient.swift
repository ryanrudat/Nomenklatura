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
    private let model = "claude-sonnet-4-5-20250929"  // Claude Sonnet 4.5 - best balance of intelligence, speed, and cost
    private let maxTokens = 2048  // Reduced for faster responses - scenarios don't need 4k tokens

    // MARK: - Public API

    /// Generate a scenario using Claude
    func generateScenario(prompt: String) async throws -> ClaudeResponse {
        guard Secrets.isAIEnabled else {
            #if DEBUG
            print("[ClaudeClient] AI not enabled - isAIEnabled returned false")
            #endif
            throw ClaudeError.apiKeyMissing
        }

        #if DEBUG
        print("[ClaudeClient] Making request to: \(baseURL)")
        #endif

        let request = try buildRequest(prompt: prompt)

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
                return try decodeResponse(data)
            case 401:
                #if DEBUG
                print("[ClaudeClient] Unauthorized - check API key on proxy")
                #endif
                throw ClaudeError.unauthorized
            case 429:
                #if DEBUG
                print("[ClaudeClient] Rate limited")
                #endif
                throw ClaudeError.rateLimited
            case 500...599:
                #if DEBUG
                print("[ClaudeClient] Server error: \(httpResponse.statusCode)")
                if let body = String(data: data, encoding: .utf8) {
                    print("[ClaudeClient] Error body: \(body)")
                }
                #endif
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

    private func buildRequest(prompt: String) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw ClaudeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Only add API key header for direct API access (local development)
        // Proxy handles the API key server-side
        if Secrets.useDirectAPI {
            request.addValue(Secrets.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        request.timeoutInterval = 45  // Allow time for complex scenario generation

        let body = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            messages: [
                ClaudeMessage(role: "user", content: prompt)
            ]
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func decodeResponse(_ data: Data) throws -> ClaudeResponse {
        do {
            return try JSONDecoder().decode(ClaudeResponse.self, from: data)
        } catch {
            // Try to get error message from API
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
    let messages: [ClaudeMessage]
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

    /// Extract the text content from the response
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
