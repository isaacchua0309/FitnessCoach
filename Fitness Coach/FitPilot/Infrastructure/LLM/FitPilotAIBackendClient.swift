//
//  FitPilotAIBackendClient.swift
//  Fitness Coach
//
//  FitPilot AI — Thin HTTP client shell for the FitPilot backend AI gateway.
//

import Foundation

typealias AuthTokenProvider = () async throws -> String

final class FitPilotAIBackendClient: LLMClient {

    private let baseURL: URL
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let authTokenProvider: AuthTokenProvider?

    init(
        baseURL: URL,
        urlSession: URLSession? = nil,
        authTokenProvider: AuthTokenProvider? = nil
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession ?? Self.makeSession()
        self.authTokenProvider = authTokenProvider

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

    func parseWorkout(request: AIWorkoutParseRequest) async throws -> AIWorkoutParseResponse {
        try await post(endpoint: .parseWorkout, body: request)
    }

    func parseEditOrDelete(request: AIEditDeleteParseRequest) async throws -> AIEditDeleteParseResponse {
        try await post(endpoint: .parseEditDelete, body: request)
    }

    func parseMultiAction(request: AIMultiActionParseRequest) async throws -> AIMultiActionParseResponse {
        try await post(endpoint: .parseMultiAction, body: request)
    }

    // MARK: HTTP

    private func post<Body: Encodable, Response: Decodable>(
        endpoint: LLMEndpoint,
        body: Body
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(endpoint.rawValue)
        let traceId = await MainActor.run { FitPilotPipelineTracer.currentTraceId }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let traceId {
            urlRequest.setValue(traceId.uuidString, forHTTPHeaderField: FitPilotPipelineTracer.traceHeaderName)
        }

        let requestBody: Data
        do {
            requestBody = try encoder.encode(body)
            urlRequest.httpBody = requestBody
        } catch {
            FitPilotPipelineTracer.logError(
                stage: .httpRequest,
                message: "Request encoding failed",
                fields: [
                    "endpoint": endpoint.rawValue,
                    "url": url.absoluteString,
                    "error": error.localizedDescription
                ]
            )
            throw LLMClientError.decodingFailed("Could not encode request.")
        }

        var authHeaderPresent = false
        if let authTokenProvider {
            do {
                let token = try await authTokenProvider()
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                authHeaderPresent = true
            } catch let error as AuthManagerError {
                FitPilotPipelineTracer.logError(
                    stage: .authToken,
                    message: "Auth token unavailable for HTTP request",
                    fields: [
                        "endpoint": endpoint.rawValue,
                        "authError": String(describing: error)
                    ]
                )
                throw LLMClientError.authenticationFailed
            } catch {
                FitPilotPipelineTracer.logError(
                    stage: .authToken,
                    message: "Auth token fetch failed",
                    fields: [
                        "endpoint": endpoint.rawValue,
                        "error": error.localizedDescription
                    ]
                )
                throw LLMClientError.authenticationFailed
            }
        }

        var requestFields: [String: String] = [
            "endpoint": endpoint.rawValue,
            "url": url.absoluteString,
            "requestBytes": String(requestBody.count),
            "authHeaderPresent": String(authHeaderPresent),
            "extendedTimeout": String(FitPilotPipelineTracer.usesExtendedHTTPTimeout)
        ]
        if let snippet = FitPilotPipelineTracer.sanitizedJSONSnippet(requestBody) {
            requestFields["requestBody"] = snippet
        }
        FitPilotPipelineTracer.event(
            stage: .httpRequest,
            level: .info,
            message: "HTTP POST started",
            fields: requestFields
        )

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: urlRequest)
        } catch {
            let durationMs = Int(Date().timeIntervalSince(started) * 1_000)
            FitPilotPipelineTracer.logError(
                stage: .httpResponse,
                message: "HTTP request failed",
                fields: [
                    "endpoint": endpoint.rawValue,
                    "url": url.absoluteString,
                    "durationMs": String(durationMs),
                    "error": error.localizedDescription,
                    "errorType": String(describing: type(of: error))
                ]
            )
            throw LLMClientError.requestFailed(error.localizedDescription)
        }

        let durationMs = Int(Date().timeIntervalSince(started) * 1_000)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if !(200...299).contains(statusCode) {
            var errorFields: [String: String] = [
                "endpoint": endpoint.rawValue,
                "url": url.absoluteString,
                "status": String(statusCode),
                "durationMs": String(durationMs),
                "responseBytes": String(data.count)
            ]
            if let snippet = FitPilotPipelineTracer.sanitizedJSONSnippet(data) {
                errorFields["responseBody"] = snippet
            }
            FitPilotPipelineTracer.logError(
                stage: .httpResponse,
                message: "HTTP non-success status",
                fields: errorFields
            )
            throw LLMClientError.invalidStatusCode(statusCode)
        }

        var responseFields: [String: String] = [
            "endpoint": endpoint.rawValue,
            "url": url.absoluteString,
            "status": String(statusCode),
            "durationMs": String(durationMs),
            "responseBytes": String(data.count)
        ]
        if let snippet = FitPilotPipelineTracer.sanitizedJSONSnippet(data) {
            responseFields["responseBody"] = snippet
        }
        FitPilotPipelineTracer.event(
            stage: .httpResponse,
            level: .info,
            message: "HTTP POST succeeded",
            fields: responseFields
        )

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            FitPilotPipelineTracer.logError(
                stage: .httpResponse,
                message: "Response decoding failed",
                fields: [
                    "endpoint": endpoint.rawValue,
                    "url": url.absoluteString,
                    "status": String(statusCode),
                    "durationMs": String(durationMs),
                    "error": error.localizedDescription
                ]
            )
            throw LLMClientError.decodingFailed("Could not decode backend response.")
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        if FitPilotPipelineTracer.usesExtendedHTTPTimeout {
            configuration.timeoutIntervalForRequest = 8
            configuration.timeoutIntervalForResource = 12
        } else {
            configuration.timeoutIntervalForRequest = 1.5
            configuration.timeoutIntervalForResource = 2.0
        }
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
