//
//  AIBackendErrorMappingTests.swift
//  Fitness CoachTests
//
//  AI gateway error mapping regressions.
//

import XCTest
@testable import Fitness_Coach

final class AIBackendErrorMappingTests: XCTestCase {

    func testMissingConfigurationMapsToBackendUnavailable() {
        XCTAssertEqual(
            AICommandParser.map(.missingConfiguration),
            .backendUnavailable
        )
        XCTAssertEqual(
            AICommandParser.map(.missingConfiguration).userMessage,
            FormaProductCopy.Error.coachUnavailable
        )
    }

    func testRequestTimedOutMapsToDedicatedUserMessage() {
        XCTAssertEqual(
            AICommandParser.map(.requestTimedOut),
            .requestTimedOut
        )
        XCTAssertEqual(
            AICommandParser.map(.requestTimedOut).userMessage,
            FormaProductCopy.Error.coachTimeout
        )
        XCTAssertNotEqual(
            AIServiceError.requestTimedOut.userMessage,
            FormaProductCopy.Error.coachUnavailable
        )
    }

    func testUnauthorizedStatusMapsToAuthenticationFailure() {
        XCTAssertEqual(
            AICommandParser.map(.invalidStatusCode(401)),
            .authenticationFailed
        )
        XCTAssertEqual(
            AICommandParser.map(.invalidStatusCode(401)).userMessage,
            AIServiceError.coachSessionFailureMessage
        )
    }

    func testServerErrorMapsToBackendUnavailableNotOpenAICopy() {
        let mapped = AICommandParser.map(.invalidStatusCode(500))
        XCTAssertEqual(mapped, .backendUnavailable)
        XCTAssertEqual(mapped.userMessage, FormaProductCopy.Error.coachUnavailable)
        XCTAssertFalse(mapped.userMessage.localizedCaseInsensitiveContains("openai"))
    }

    func testFallbackLLMClientPreservesTimeoutError() async {
        let client = FallbackLLMClient(primary: TimeoutFailingLLMClient())

        do {
            _ = try await client.classifyCoachIntent(
                request: AICoachIntentClassificationRequest(
                    text: "hello",
                    context: AIContext(date: Date(timeIntervalSince1970: 0), timezoneIdentifier: "UTC"),
                    modelName: CoachModelConfig.default.cheapClassifierModel,
                    modelConfig: .default
                )
            )
            XCTFail("Expected timeout.")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .requestTimedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class TimeoutFailingLLMClient: LLMClient, @unchecked Sendable {
    func classifyCoachIntent(
        request: AICoachIntentClassificationRequest
    ) async throws -> AICoachIntentClassificationResponse {
        throw LLMClientError.requestTimedOut
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        throw LLMClientError.requestTimedOut
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        throw LLMClientError.requestTimedOut
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        throw LLMClientError.requestTimedOut
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        throw LLMClientError.requestTimedOut
    }

    func parseWorkout(request: AIWorkoutParseRequest) async throws -> AIWorkoutParseResponse {
        throw LLMClientError.requestTimedOut
    }

    func parseEditOrDelete(request: AIEditDeleteParseRequest) async throws -> AIEditDeleteParseResponse {
        throw LLMClientError.requestTimedOut
    }

    func parseMultiAction(request: AIMultiActionParseRequest) async throws -> AIMultiActionParseResponse {
        throw LLMClientError.requestTimedOut
    }
}
