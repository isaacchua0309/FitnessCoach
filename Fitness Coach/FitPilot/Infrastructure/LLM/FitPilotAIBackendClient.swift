//
//  FitPilotAIBackendClient.swift
//  Fitness Coach
//
//  FitPilot AI — Thin HTTP client shell for the FitPilot backend AI gateway.
//
//  This client posts request contracts to the backend and decodes structured
//  responses. It contains no provider API keys and no hardcoded production URL;
//  the base URL is injected. If no backend exists yet, this client compiles but
//  is not wired as the default (MockLLMClient is used for local development).
//

import Foundation

final class FitPilotAIBackendClient: LLMClient {

    private let baseURL: URL
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func classifyCoachIntent(
        request: AICoachIntentClassificationRequest
    ) async throws -> AICoachIntentClassificationResponse {
        try await post(endpoint: .classifyCoachIntent, body: request)
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        try await post(endpoint: .parseCommand, body: request)
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        try await post(endpoint: .estimateFood, body: request)
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        try await post(endpoint: .mealAdvice, body: request)
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        try await post(endpoint: .dailyReview, body: request)
    }

    // MARK: HTTP

    private func post<Body: Encodable, Response: Decodable>(
        endpoint: LLMEndpoint,
        body: Body
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(endpoint.rawValue)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            urlRequest.httpBody = try encoder.encode(body)
        } catch {
            throw LLMClientError.decodingFailed("Could not encode request.")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: urlRequest)
        } catch {
            throw LLMClientError.requestFailed(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw LLMClientError.invalidStatusCode(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw LLMClientError.decodingFailed("Could not decode backend response.")
        }
    }
}
