//
//  CoachImageAnalysisDebugLogFormatterTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachImageAnalysisDebugLogFormatterTests: XCTestCase {

    func testFieldsOmitsSensitiveValues() {
        let fields = CoachImageAnalysisDebugLogFormatter.fields(
            from: CoachImageAnalysisDebugContext(
                sessionId: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
                source: .library,
                mimeType: "image/jpeg",
                rawBytes: 4_000_000,
                compressedBytes: 320_000,
                base64Chars: 426_667,
                attempt: 2,
                isRetry: true,
                hasCaption: true,
                backendStatus: 422,
                parseSuccess: false,
                errorCategory: "invalid_nutrition_json"
            )
        )

        XCTAssertEqual(fields["source"], "library")
        XCTAssertEqual(fields["mimeType"], "image/jpeg")
        XCTAssertEqual(fields["compressedBytes"], "320000")
        XCTAssertEqual(fields["attempt"], "2")
        XCTAssertEqual(fields["backendStatus"], "422")
        XCTAssertEqual(fields["errorCategory"], "invalid_nutrition_json")
        XCTAssertFalse(fields.keys.contains("base64"))
        XCTAssertFalse(fields.keys.contains("message"))
        XCTAssertFalse(fields.values.contains(where: { $0.contains("Bearer") }))
    }

    func testErrorCategoryMapsAIServiceErrors() {
        XCTAssertEqual(
            CoachImageAnalysisDebugLogFormatter.errorCategory(for: AIServiceError.networkUnavailable),
            "network"
        )
        XCTAssertEqual(
            CoachImageAnalysisDebugLogFormatter.errorCategory(for: AIServiceError.payloadTooLarge),
            "payload_too_large"
        )
        XCTAssertEqual(
            CoachImageAnalysisDebugLogFormatter.errorCategory(
                for: AIServiceError.invalidNutritionJSON("items missing")
            ),
            "invalid_nutrition_json"
        )
    }

    func testErrorCategoryMapsLLMClientErrors() {
        XCTAssertEqual(
            CoachImageAnalysisDebugLogFormatter.errorCategory(for: LLMClientError.authenticationFailed),
            "authentication"
        )
        XCTAssertEqual(
            CoachImageAnalysisDebugLogFormatter.errorCategory(for: LLMClientError.rateLimited(nil)),
            "rate_limited"
        )
        XCTAssertEqual(
            CoachImageAnalysisDebugLogFormatter.errorCategory(for: CoachMealPhotoError.cameraPermissionDenied),
            "camera_permission_denied"
        )
    }

    func testRedactSensitiveJSONFieldsStripsBase64AndUserText() {
        let raw = """
        {"message":"private lunch caption","image":{"mimeType":"image/jpeg","base64":"abc123"},"clarification":"brown rice"}
        """
        let sanitized = CoachImageAnalysisDebugLogFormatter.redactSensitiveJSONFields(raw)

        XCTAssertTrue(sanitized.contains("\"base64\":\"<redacted>\""))
        XCTAssertTrue(sanitized.contains("\"message\":\"<redacted>\""))
        XCTAssertTrue(sanitized.contains("\"clarification\":\"<redacted>\""))
        XCTAssertFalse(sanitized.contains("private lunch caption"))
        XCTAssertFalse(sanitized.contains("abc123"))
    }
}
