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

    func testPayloadTooLargeMapsToDedicatedError() {
        XCTAssertEqual(
            AICommandParser.map(.payloadTooLarge("too big")),
            .payloadTooLarge
        )
        XCTAssertEqual(
            AICommandParser.map(.invalidStatusCode(413)),
            .payloadTooLarge
        )
        XCTAssertEqual(
            AICommandParser.mapFoodEstimate(.payloadTooLarge(nil)).userMessage,
            FormaProductCopy.Error.coachPhotoTooLarge
        )
    }

    func testNetworkUnavailableMapsToDedicatedError() {
        XCTAssertEqual(
            AICommandParser.map(.networkUnavailable),
            .networkUnavailable
        )
        XCTAssertEqual(
            AICommandParser.map(.networkUnavailable).userMessage,
            FormaProductCopy.Error.coachNetworkUnavailable
        )
    }

    func testServerErrorMapsToModelUnavailable() {
        let mapped = AICommandParser.map(.modelUnavailable("upstream"))
        XCTAssertEqual(mapped, .modelUnavailable)
        XCTAssertEqual(mapped.userMessage, FormaProductCopy.Error.coachUnavailable)
        XCTAssertFalse(mapped.userMessage.localizedCaseInsensitiveContains("openai"))
    }

    func testPhotoEstimateInvalidNutritionJSONMapsToDedicatedCopy() {
        let mapped = AICommandParser.mapFoodEstimate(.invalidStatusCode(422))
        XCTAssertEqual(mapped, .invalidNutritionJSON("Nutrition extraction failed validation."))
        XCTAssertEqual(
            mapped.userMessage,
            FormaProductCopy.Error.coachPhotoAnalysisUnreadable
        )
    }

    func testPhotoEstimateImageRejectionMapsToDedicatedCopy() {
        let mapped = AICommandParser.mapFoodEstimate(
            .backendRejected("Missing or invalid imageJPEGBase64.")
        )
        XCTAssertEqual(mapped, .backendRejectedImage)
        XCTAssertEqual(
            mapped.userMessage,
            FormaProductCopy.Error.coachPhotoRejected
        )
    }

    func testFallbackLLMClientRethrowsTypedLLMError() async {
        let client = FallbackLLMClient(primary: PayloadTooLargeFailingLLMClient())

        do {
            _ = try await client.estimateFood(
                request: AIFoodEstimateRequest(
                    text: "meal photo",
                    context: AIContext(date: Date(timeIntervalSince1970: 0), timezoneIdentifier: "UTC")
                )
            )
            XCTFail("Expected payload too large.")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .payloadTooLarge(nil))
            XCTAssertEqual(AICommandParser.mapFoodEstimate(error), .payloadTooLarge)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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

    func generateNutritionEstimate(request: AINutritionEstimateRequest) async throws -> AINutritionEstimateResponse {
        throw LLMClientError.requestTimedOut
    }

    func generateNutritionComparison(request: AINutritionComparisonRequest) async throws -> AINutritionComparisonResponse {
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

private final class PayloadTooLargeFailingLLMClient: LLMClient, @unchecked Sendable {
    func classifyCoachIntent(
        request: AICoachIntentClassificationRequest
    ) async throws -> AICoachIntentClassificationResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func generateNutritionEstimate(request: AINutritionEstimateRequest) async throws -> AINutritionEstimateResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func generateNutritionComparison(request: AINutritionComparisonRequest) async throws -> AINutritionComparisonResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func parseWorkout(request: AIWorkoutParseRequest) async throws -> AIWorkoutParseResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func parseEditOrDelete(request: AIEditDeleteParseRequest) async throws -> AIEditDeleteParseResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }

    func parseMultiAction(request: AIMultiActionParseRequest) async throws -> AIMultiActionParseResponse {
        throw LLMClientError.payloadTooLarge(nil)
    }
}
