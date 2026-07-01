//
//  FormaAIBackendClientTests.swift
//  Fitness CoachTests
//
//  Gateway HTTP client contract regressions (no live network).
//

import XCTest
@testable import Fitness_Coach

final class FormaAIBackendClientTests: XCTestCase {

    private let productionBaseURL = URL(
        string: "https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway"
    )!

    private let gatewayEndpointPaths = [
        "v1/ai/classify-coach-intent",
        "v1/ai/parse-command",
        "v1/ai/estimate-food",
        "v1/ai/generate-meal-advice",
        "v1/ai/generate-daily-review",
        "v1/ai/parse-workout",
        "v1/ai/parse-edit-delete",
        "v1/ai/parse-multi-action",
    ]

    override func tearDown() {
        GatewayMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Timeout configuration

    func testGatewayTimeoutProfileUsesProductionSafeValues() {
        let profile = FormaAIBackendClient.HTTPTimeoutProfile.profile(for: productionBaseURL)
        XCTAssertEqual(profile.requestTimeout, 45)
        XCTAssertEqual(profile.resourceTimeout, 90)
    }

    func testGatewayTimeoutConstantsAreNotLegacyShortReleaseValues() {
        XCTAssertEqual(FormaAIBackendClient.HTTPTimeoutProfile.gatewayRequestTimeout, 45)
        XCTAssertEqual(FormaAIBackendClient.HTTPTimeoutProfile.gatewayResourceTimeout, 90)
        XCTAssertNotEqual(FormaAIBackendClient.HTTPTimeoutProfile.gatewayRequestTimeout, 1.5)
        XCTAssertNotEqual(FormaAIBackendClient.HTTPTimeoutProfile.gatewayResourceTimeout, 2.0)
        XCTAssertGreaterThan(FormaAIBackendClient.HTTPTimeoutProfile.gatewayRequestTimeout, 2.0)
    }

    // MARK: - Base URL composition

    func testClassifyCoachIntentComposesGatewayURLWithoutDuplicatedSlashes() async throws {
        GatewayMockURLProtocol.reset()
        GatewayMockURLProtocol.responseBody = Self.validClassifyResponseData

        let client = makeClient(baseURL: productionBaseURL)
        _ = try await client.classifyCoachIntent(request: Self.sampleClassifyRequest())

        let requestURL = try XCTUnwrap(GatewayMockURLProtocol.capturedRequest?.url)
        XCTAssertEqual(
            requestURL.absoluteString,
            "https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway/v1/ai/classify-coach-intent"
        )
        XCTAssertFalse(requestURL.absoluteString.contains("//v1/ai"))
    }

    func testAllGatewayEndpointPathsIncludeV1AIPrefix() async throws {
        GatewayMockURLProtocol.reset()
        GatewayMockURLProtocol.responseBody = Self.validClassifyResponseData

        let client = makeClient(baseURL: productionBaseURL)

        for path in gatewayEndpointPaths {
            GatewayMockURLProtocol.reset()
            let endpoint = try XCTUnwrap(LLMEndpoint(rawValue: path))
            GatewayMockURLProtocol.responseBody = Self.responseData(for: endpoint)

            _ = try await invoke(client: client, endpoint: endpoint)

            let requestURL = try XCTUnwrap(GatewayMockURLProtocol.capturedRequest?.url)
            XCTAssertTrue(
                requestURL.path.hasSuffix("/\(path)"),
                "Expected path suffix /\(path), got \(requestURL.path)"
            )
            XCTAssertTrue(requestURL.path.contains("/v1/ai/"))
        }
    }

    // MARK: - Request headers

    func testRequestIncludesAuthorizationContentTypeAndAcceptHeaders() async throws {
        GatewayMockURLProtocol.reset()
        GatewayMockURLProtocol.responseBody = Self.validClassifyResponseData

        let client = FormaAIBackendClient(
            baseURL: productionBaseURL,
            urlSession: makeMockSession(),
            authTokenProvider: { "firebase-test-token" }
        )

        _ = try await client.classifyCoachIntent(request: Self.sampleClassifyRequest())

        let captured = try XCTUnwrap(GatewayMockURLProtocol.capturedRequest)
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Authorization"), "Bearer firebase-test-token")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    @MainActor
    func testRequestIncludesFormaTraceHeaderWhenTracingActive() async throws {
        GatewayMockURLProtocol.reset()
        GatewayMockURLProtocol.responseBody = Self.validClassifyResponseData
        FormaPipelineTracer.clear()

        let traceId = FormaPipelineTracer.beginTrace(userMessage: "backend client header test")
        let client = makeClient(baseURL: productionBaseURL)

        _ = try await client.classifyCoachIntent(request: Self.sampleClassifyRequest())

        XCTAssertEqual(
            GatewayMockURLProtocol.capturedRequest?
                .value(forHTTPHeaderField: FormaPipelineTracer.traceHeaderName),
            traceId.uuidString
        )
    }

    // MARK: - Error mapping

    func testHTTP401MapsToAuthenticationFailure() async {
        GatewayMockURLProtocol.reset()
        GatewayMockURLProtocol.responseStatusCode = 401
        GatewayMockURLProtocol.responseBody = Data(#"{"error":"Missing Firebase ID token."}"#.utf8)

        let client = makeClient(
            baseURL: productionBaseURL,
            authTokenProvider: { "firebase-test-token" }
        )

        do {
            _ = try await client.classifyCoachIntent(request: Self.sampleClassifyRequest())
            XCTFail("Expected authentication failure.")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .authenticationFailed)
            XCTAssertEqual(
                AICommandParser.map(error).userMessage,
                AIServiceError.coachSessionFailureMessage
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTransportTimeoutMapsToRequestTimedOutAndUserSafeCopy() async {
        GatewayMockURLProtocol.reset()
        GatewayMockURLProtocol.responseError = URLError(.timedOut)

        let client = makeClient(baseURL: productionBaseURL)

        do {
            _ = try await client.classifyCoachIntent(request: Self.sampleClassifyRequest())
            XCTFail("Expected timeout.")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .requestTimedOut)
            XCTAssertEqual(
                AICommandParser.map(error).userMessage,
                FormaProductCopy.Error.coachTimeout
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAuthTokenProviderFailureMapsToAuthenticationFailureWithoutNetworkCall() async {
        GatewayMockURLProtocol.reset()

        let client = FormaAIBackendClient(
            baseURL: productionBaseURL,
            urlSession: makeMockSession(),
            authTokenProvider: { throw AuthManagerError.notSignedIn }
        )

        do {
            _ = try await client.classifyCoachIntent(request: Self.sampleClassifyRequest())
            XCTFail("Expected authentication failure.")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .authenticationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(GatewayMockURLProtocol.capturedRequest)
    }

    func testDecodesClassifyResponseWhenActionDraftIsMissing() async throws {
        GatewayMockURLProtocol.reset()
        GatewayMockURLProtocol.responseData = Data(
            """
            {"intentResult":{"intent":"general_conversation","confidence":0.9,"domain":"general","requiresAppMutation":false,"requiresUserContext":true,"canAnswerWithCheapModel":true,"requiresEscalation":false,"entities":{"food":null,"meal":null,"amountMl":null,"weightKg":null,"durationMinutes":null,"distanceKm":null,"calories":null,"proteinGrams":null,"carbsGrams":null,"fatGrams":null,"quantity":null,"unit":null,"notes":null},"action":{"type":"log_food","foodDraft":null,"waterDraft":null,"weightDraft":null,"workoutDraft":null,"selector":null,"undoTarget":null},"reason":"Greeting."}}
            """.utf8
        )

        let client = makeClient(baseURL: productionBaseURL)
        let response = try await client.classifyCoachIntent(request: Self.sampleClassifyRequest())

        XCTAssertEqual(response.intentResult.intent, .generalConversation)
        XCTAssertNil(response.intentResult.action)
    }
}

// MARK: - Helpers

private extension FormaAIBackendClientTests {

    func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GatewayMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    func makeClient(
        baseURL: URL,
        authTokenProvider: AuthTokenProvider? = nil
    ) -> FormaAIBackendClient {
        FormaAIBackendClient(
            baseURL: baseURL,
            urlSession: makeMockSession(),
            authTokenProvider: authTokenProvider
        )
    }

    func invoke(client: FormaAIBackendClient, endpoint: LLMEndpoint) async throws {
        switch endpoint {
        case .classifyCoachIntent:
            _ = try await client.classifyCoachIntent(request: Self.sampleClassifyRequest())
        case .parseCommand:
            _ = try await client.parseCommand(
                request: AIParseCommandRequest(
                    text: "log water",
                    context: Self.sampleContext
                )
            )
        case .estimateFood:
            _ = try await client.estimateFood(
                request: AIFoodEstimateRequest(text: "2 eggs", context: Self.sampleContext)
            )
        case .mealAdvice:
            _ = try await client.generateMealAdvice(
                request: AIMealAdviceRequest(question: "Pasta tonight?", context: Self.sampleContext)
            )
        case .dailyReview:
            _ = try await client.generateDailyReview(
                request: AIDailyReviewRequest(input: Self.sampleDailyReviewInput, context: Self.sampleContext)
            )
        case .parseWorkout:
            _ = try await client.parseWorkout(
                request: AIWorkoutParseRequest(text: "ran 30 minutes", context: Self.sampleContext)
            )
        case .parseEditDelete:
            _ = try await client.parseEditOrDelete(
                request: AIEditDeleteParseRequest(text: "delete last meal", context: Self.sampleContext)
            )
        case .parseMultiAction:
            _ = try await client.parseMultiAction(
                request: AIMultiActionParseRequest(text: "log water and weight", context: Self.sampleContext)
            )
        }
    }

    static let sampleContext = AIContext(
        date: Date(timeIntervalSince1970: 0),
        timezoneIdentifier: "UTC"
    )

    static func sampleClassifyRequest() -> AICoachIntentClassificationRequest {
        AICoachIntentClassificationRequest(
            text: "hello",
            context: sampleContext,
            modelName: CoachModelConfig.default.cheapClassifierModel,
            modelConfig: .default
        )
    }

    static func responseData(for endpoint: LLMEndpoint) -> Data {
        switch endpoint {
        case .classifyCoachIntent:
            return validClassifyResponseData
        case .parseCommand, .parseEditDelete, .parseMultiAction:
            return validParsedCommandResponseData
        case .estimateFood:
            return validFoodEstimateResponseData
        case .mealAdvice, .dailyReview:
            return validCoachResponseData
        case .parseWorkout:
            return validWorkoutParseResponseData
        }
    }

    static let validClassifyResponseData = Data(
        """
        {"intentResult":{"intent":"general_conversation","confidence":1,"domain":"general","requiresAppMutation":false,"requiresUserContext":false,"canAnswerWithCheapModel":true,"requiresEscalation":false,"entities":{"food":null,"meal":null,"amountMl":null,"weightKg":null,"durationMinutes":null,"distanceKm":null,"calories":null,"proteinGrams":null,"carbsGrams":null,"fatGrams":null,"quantity":null,"unit":null,"notes":null},"action":null,"reason":null}}
        """.utf8
    )

    static let validParsedCommandResponseData = Data(
        """
        {"parsedCommand":{"originalText":"log water","intent":"logWater","actions":[],"confidence":"high","requiresConfirmation":false,"assistantMessage":null,"reasoningSummary":null}}
        """.utf8
    )

    static let validFoodEstimateResponseData = Data(
        """
        {"foodDrafts":[{"mealType":"lunch","name":"Eggs","quantity":2,"unit":"count","calories":140,"protein":12,"carbs":1,"fat":10,"fiber":null,"sodium":null,"source":"aiTextEstimate","confidence":"medium","imageUrl":null,"notes":null}],"confidence":"medium","requiresConfirmation":true,"assistantMessage":null}
        """.utf8
    )

    static let validCoachResponseData = Data(
        """
        {"response":{"message":"Looks good.","confidence":"high","followUpSuggestions":[]}}
        """.utf8
    )

    static let validWorkoutParseResponseData = Data(
        """
        {"workoutDraft":{"name":"Run","durationMinutes":30,"estimatedCaloriesBurned":250,"intensity":"moderate","recoveryDemand":"moderate","notes":null,"exerciseSets":[]},"assistantMessage":"Ready to log?","confidence":"medium"}
        """.utf8
    )

    static let sampleDailyReviewInput = DailyReviewAIInput(
        date: Date(timeIntervalSince1970: 0),
        calorieTarget: 2000,
        caloriesConsumed: 1500,
        caloriesRemaining: 500,
        isOverCalorieTarget: false,
        proteinTarget: 150,
        proteinConsumed: 120,
        proteinRemaining: 30,
        hasMetProteinTarget: false,
        carbsTarget: 200,
        carbsConsumed: 180,
        carbsRemaining: 20,
        fatTarget: 65,
        fatConsumed: 50,
        fatRemaining: 15,
        waterTargetMl: 2500,
        waterConsumedMl: 1800,
        waterRemainingMl: 700,
        hasMetWaterTarget: false,
        weightKg: nil,
        latestWeightKg: nil,
        steps: nil,
        workoutCount: 0,
        workoutCaloriesBurned: 0,
        foodEntryCount: 1,
        lowConfidenceFoodCount: 0,
        topProteinFoodNames: [],
        deterministicNotes: []
    )
}

// MARK: - URLProtocol mock

private final class GatewayMockURLProtocol: URLProtocol {

    static var capturedRequest: URLRequest?
    static var responseStatusCode = 200
    static var responseBody = Data()
    static var responseError: Error?

    static func reset() {
        capturedRequest = nil
        responseStatusCode = 200
        responseBody = Data()
        responseError = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequest = request

        if let responseError = Self.responseError {
            client?.urlProtocol(self, didFailWithError: responseError)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.responseStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
