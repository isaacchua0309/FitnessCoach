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

    func generateNutritionEstimate(
        request: AINutritionEstimateRequest
    ) async throws -> AINutritionEstimateResponse {
        try await post(endpoint: .nutritionEstimate, body: request)
    }

    func generateNutritionComparison(
        request: AINutritionComparisonRequest
    ) async throws -> AINutritionComparisonResponse {
        try await post(endpoint: .nutritionComparison, body: request)
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

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        try await post(endpoint: .analyzeMealImage, body: request)
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
        requestFields.merge(CoachAIRequestLogFormatter.redactedContextFields(from: body)) { _, new in new }
        #if DEBUG
        if let snippet = FormaPipelineTracer.sanitizedJSONSnippet(requestBody) {
            requestFields["requestBody"] = snippet
        }
        #endif
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
            #if DEBUG
            if endpoint == .analyzeMealImage {
                CoachImageAnalysisDebugLogger.logBackendResponse(
                    status: -1,
                    durationMs: durationMs,
                    responseBytes: 0,
                    success: false,
                    errorCategory: CoachImageAnalysisDebugLogFormatter.errorCategory(for: mappedError)
                )
            }
            #endif
            throw mappedError
        }

        let durationMs = Int(Date().timeIntervalSince(started) * 1_000)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if !(200...299).contains(statusCode) {
            let gatewayError = Self.safeGatewayErrorMessage(from: data)
            var errorFields: [String: String] = [
                "endpoint": endpoint.rawValue,
                "url": url.absoluteString,
                "status": String(statusCode),
                "durationMs": String(durationMs),
                "responseBytes": String(data.count)
            ]
            if let gatewayError {
                errorFields["gatewayError"] = gatewayError
            }
            if let snippet = FormaPipelineTracer.sanitizedJSONSnippet(data) {
                errorFields["responseBody"] = snippet
            }

            #if DEBUG
            if endpoint == .analyzeMealImage {
                CoachImageAnalysisDebugLogger.logBackendResponse(
                    status: statusCode,
                    durationMs: durationMs,
                    responseBytes: data.count,
                    success: false,
                    errorCategory: Self.mealImageBackendErrorCategory(statusCode: statusCode)
                )
            }
            #endif

            if statusCode == 401 {
                FormaPipelineTracer.logError(
                    stage: .httpResponse,
                    message: "Gateway rejected Firebase ID token",
                    fields: errorFields
                )
                throw LLMClientError.authenticationFailed
            }

            let mappedStatusError = Self.mapHTTPStatusError(statusCode: statusCode, message: gatewayError)
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
            throw mappedStatusError
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

        #if DEBUG
        if endpoint == .analyzeMealImage {
            CoachImageAnalysisDebugLogger.logBackendResponse(
                status: statusCode,
                durationMs: durationMs,
                responseBytes: data.count,
                success: true
            )
        }
        #endif

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
            #if DEBUG
            if endpoint == .analyzeMealImage {
                CoachImageAnalysisDebugLogger.logResponseParsed(
                    success: false,
                    errorCategory: "parse_failure"
                )
            }
            #endif
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
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .requestTimedOut
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .dataNotAllowed:
                return .networkUnavailable
            default:
                break
            }
        }

        if error.localizedDescription.localizedCaseInsensitiveContains("timed out") {
            return .requestTimedOut
        }

        if error.localizedDescription.localizedCaseInsensitiveContains("offline") ||
            error.localizedDescription.localizedCaseInsensitiveContains("internet") {
            return .networkUnavailable
        }

        return .requestFailed(error.localizedDescription)
    }

    private static func mapHTTPStatusError(statusCode: Int, message: String?) -> LLMClientError {
        switch statusCode {
        case 413:
            return .payloadTooLarge(message)
        case 400:
            return .backendRejected(message)
        case 422:
            return .backendRejected(message)
        case 429:
            return .rateLimited(message)
        case 500...599:
            return .modelUnavailable(message)
        default:
            return .invalidStatusCode(statusCode)
        }
    }

    /// Redacted gateway `{ "error": "..." }` text for diagnostics only.
    private static func safeGatewayErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["error"] as? String else {
            return nil
        }

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let redacted = LogRedactor.redactSecrets(in: trimmed)

        if redacted.localizedCaseInsensitiveContains("openai") {
            return "Upstream model provider error"
        }

        return String(redacted.prefix(200))
    }

    #if DEBUG
    private static func mealImageBackendErrorCategory(statusCode: Int) -> String {
        switch statusCode {
        case 401: return "authentication"
        case 413: return "payload_too_large"
        case 400, 422: return "backend_rejected"
        case 429: return "rate_limited"
        case 500...599: return "model_unavailable"
        default: return "http_status"
        }
    }
    #endif
}
