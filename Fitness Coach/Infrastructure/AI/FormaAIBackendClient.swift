//
//  FormaAIBackendClient.swift
//  Fitness Coach
//
//  FitPilot AI — Thin HTTP client shell for the FitPilot backend AI gateway.
//

import Foundation

typealias AuthTokenProvider = () async throws -> String

final class FormaAIBackendClient: LLMClient {

    /// Timeouts for gateway HTTP calls. Independent of DEBUG pipeline tracing.
    enum HTTPTimeoutProfile {
        /// Hosted Firebase aiGateway (HTTPS).
        case gateway

        static let gatewayRequestTimeout: TimeInterval = 45
        static let gatewayResourceTimeout: TimeInterval = 90

        static func profile(for baseURL: URL) -> HTTPTimeoutProfile {
            _ = baseURL
            return .gateway
        }

        var requestTimeout: TimeInterval {
            switch self {
            case .gateway:
                Self.gatewayRequestTimeout
            }
        }

        var resourceTimeout: TimeInterval {
            switch self {
            case .gateway:
                Self.gatewayResourceTimeout
            }
        }
    }

    private let baseURL: URL
    private let urlSession: URLSession
    private let httpTimeoutProfile: HTTPTimeoutProfile
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let authTokenProvider: AuthTokenProvider?

    init(
        baseURL: URL,
        urlSession: URLSession? = nil,
        authTokenProvider: AuthTokenProvider? = nil
    ) {
        self.baseURL = baseURL
        let timeoutProfile = HTTPTimeoutProfile.profile(for: baseURL)
        self.httpTimeoutProfile = timeoutProfile
        self.urlSession = urlSession ?? Self.makeSession(timeoutProfile: timeoutProfile)
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
        let traceId = await MainActor.run { FormaPipelineTracer.currentTraceId }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let traceId {
            urlRequest.setValue(traceId.uuidString, forHTTPHeaderField: FormaPipelineTracer.traceHeaderName)
        }

        let requestBody: Data
        do {
            requestBody = try encoder.encode(body)
            urlRequest.httpBody = requestBody
        } catch {
            FormaPipelineTracer.logError(
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
                FormaPipelineTracer.logError(
                    stage: .authToken,
                    message: "Auth token unavailable for HTTP request",
                    fields: [
                        "endpoint": endpoint.rawValue,
                        "authError": String(describing: error)
                    ]
                )
                throw LLMClientError.authenticationFailed
            } catch {
                FormaPipelineTracer.logError(
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
            "requestTimeoutSeconds": String(httpTimeoutProfile.requestTimeout),
            "resourceTimeoutSeconds": String(httpTimeoutProfile.resourceTimeout)
        ]
        if let snippet = FormaPipelineTracer.sanitizedJSONSnippet(requestBody) {
            requestFields["requestBody"] = snippet
        }
        FormaPipelineTracer.event(
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
            let mappedError = Self.mapTransportError(error)
            FormaPipelineTracer.logError(
                stage: .httpResponse,
                message: mappedError == .requestTimedOut ?
                    "HTTP request timed out" :
                    "HTTP request failed",
                fields: [
                    "endpoint": endpoint.rawValue,
                    "url": url.absoluteString,
                    "durationMs": String(durationMs),
                    "errorType": String(describing: type(of: error)),
                    "mappedError": String(describing: mappedError)
                ]
            )
            throw mappedError
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
            if let gatewayError = Self.safeGatewayErrorMessage(from: data) {
                errorFields["gatewayError"] = gatewayError
            }
            if let snippet = FormaPipelineTracer.sanitizedJSONSnippet(data) {
                errorFields["responseBody"] = snippet
            }

            if statusCode == 401 {
                FormaPipelineTracer.logError(
                    stage: .httpResponse,
                    message: "Gateway rejected Firebase ID token",
                    fields: errorFields
                )
                throw LLMClientError.authenticationFailed
            }

            if (500...599).contains(statusCode) {
                FormaPipelineTracer.logError(
                    stage: .httpResponse,
                    message: "Gateway server error",
                    fields: errorFields
                )
            } else {
                FormaPipelineTracer.logError(
                    stage: .httpResponse,
                    message: "HTTP non-success status",
                    fields: errorFields
                )
            }
            throw LLMClientError.invalidStatusCode(statusCode)
        }

        var responseFields: [String: String] = [
            "endpoint": endpoint.rawValue,
            "url": url.absoluteString,
            "status": String(statusCode),
            "durationMs": String(durationMs),
            "responseBytes": String(data.count)
        ]
        if let snippet = FormaPipelineTracer.sanitizedJSONSnippet(data) {
            responseFields["responseBody"] = snippet
        }
        FormaPipelineTracer.event(
            stage: .httpResponse,
            level: .info,
            message: "HTTP POST succeeded",
            fields: responseFields
        )

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            FormaPipelineTracer.logError(
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

    private static func makeSession(timeoutProfile: HTTPTimeoutProfile) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutProfile.requestTimeout
        configuration.timeoutIntervalForResource = timeoutProfile.resourceTimeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    private static func mapTransportError(_ error: Error) -> LLMClientError {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return .requestTimedOut
        }

        if error.localizedDescription.localizedCaseInsensitiveContains("timed out") {
            return .requestTimedOut
        }

        return .requestFailed(error.localizedDescription)
    }

    /// Redacted gateway `{ "error": "..." }` text for diagnostics only.
    private static func safeGatewayErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["error"] as? String else {
            return nil
        }

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let redacted = trimmed
            .replacingOccurrences(
                of: #"Bearer\s+\S+"#,
                with: "Bearer <redacted>",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)(api[_-]?key|authorization|secret)\s*[:=]\s*\S+"#,
                with: "<redacted>",
                options: .regularExpression
            )

        if redacted.localizedCaseInsensitiveContains("openai") {
            return "Upstream model provider error"
        }

        return String(redacted.prefix(200))
    }
}
