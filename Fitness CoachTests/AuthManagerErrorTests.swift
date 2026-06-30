//
//  AuthManagerErrorTests.swift
//  Fitness CoachTests
//
//  FitPilot — lightweight auth foundation tests (no Firebase SDK calls).
//

import XCTest
@testable import Fitness_Coach

final class AuthManagerErrorTests: XCTestCase {

    func testAuthManagerErrorDescriptions() {
        XCTAssertEqual(
            AuthManagerError.notSignedIn.errorDescription,
            "You're not signed in."
        )
        XCTAssertEqual(
            AuthManagerError.missingToken.errorDescription,
            "We couldn't verify your session."
        )
    }

    func testAuthStateEquality() {
        XCTAssertEqual(AuthState.unknown, AuthState.unknown)
        XCTAssertEqual(AuthState.signedOut, AuthState.signedOut)
        XCTAssertEqual(AuthState.signingIn, AuthState.signingIn)
        XCTAssertEqual(AuthState.signedIn(uid: "abc"), AuthState.signedIn(uid: "abc"))
        XCTAssertEqual(AuthState.failed("offline"), AuthState.failed("offline"))
        XCTAssertNotEqual(AuthState.signedIn(uid: "a"), AuthState.signedIn(uid: "b"))
    }

    func testAuthenticationFailureMapsToDedicatedAIServiceError() {
        XCTAssertEqual(
            AICommandParser.map(.authenticationFailed),
            .authenticationFailed
        )
    }

    func testAuthenticationFailureUserFacingCopy() {
        XCTAssertEqual(
            AIServiceError.authenticationFailed.userMessage,
            AIServiceError.coachSessionFailureMessage
        )
        XCTAssertFalse(
            AIServiceError.authenticationFailed.userMessage
                .localizedCaseInsensitiveContains("firebase")
        )
        XCTAssertFalse(
            AIServiceError.coachSessionFailureMessage
                .localizedCaseInsensitiveContains("token")
        )
    }

    func testCoachSessionFailureTitle() {
        XCTAssertEqual(
            AIServiceError.coachSessionFailureTitle,
            FormaProductCopy.Error.coachSessionTitle
        )
    }

    func testAuthenticationFailureDiffersFromBackendUnavailable() {
        XCTAssertNotEqual(
            AIServiceError.authenticationFailed.userMessage,
            AIServiceError.backendUnavailable.userMessage
        )
    }

    func testFallbackLLMClientRethrowsAuthenticationFailure() async {
        let client = FallbackLLMClient(primary: AuthenticationFailingLLMClient())
        let request = AICoachIntentClassificationRequest(
            text: "hello",
            context: AIContext(date: Date(timeIntervalSince1970: 0), timezoneIdentifier: "UTC"),
            modelName: CoachModelConfig.default.cheapClassifierModel,
            modelConfig: .default
        )

        do {
            _ = try await client.classifyCoachIntent(request: request)
            XCTFail("Expected authentication failure.")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .authenticationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBackendClientMapsAuthManagerErrorToAuthenticationFailure() async {
        let client = FormaAIBackendClient(
            baseURL: URL(string: "http://127.0.0.1:8787")!,
            authTokenProvider: { throw AuthManagerError.notSignedIn }
        )
        let request = AICoachIntentClassificationRequest(
            text: "hello",
            context: AIContext(date: Date(timeIntervalSince1970: 0), timezoneIdentifier: "UTC"),
            modelName: CoachModelConfig.default.cheapClassifierModel,
            modelConfig: .default
        )

        do {
            _ = try await client.classifyCoachIntent(request: request)
            XCTFail("Expected authentication failure.")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .authenticationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Test doubles

private final class AuthenticationFailingLLMClient: LLMClient, @unchecked Sendable {
    func classifyCoachIntent(
        request: AICoachIntentClassificationRequest
    ) async throws -> AICoachIntentClassificationResponse {
        throw LLMClientError.authenticationFailed
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        throw LLMClientError.authenticationFailed
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        throw LLMClientError.authenticationFailed
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        throw LLMClientError.authenticationFailed
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        throw LLMClientError.authenticationFailed
    }

    func parseWorkout(request: AIWorkoutParseRequest) async throws -> AIWorkoutParseResponse {
        throw LLMClientError.authenticationFailed
    }

    func parseEditOrDelete(request: AIEditDeleteParseRequest) async throws -> AIEditDeleteParseResponse {
        throw LLMClientError.authenticationFailed
    }

    func parseMultiAction(request: AIMultiActionParseRequest) async throws -> AIMultiActionParseResponse {
        throw LLMClientError.authenticationFailed
    }
}
