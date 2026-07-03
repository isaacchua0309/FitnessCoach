//
//  HealthIntelligencePresentationTextSanitizerTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligencePresentationTextSanitizerTests: XCTestCase {

    func testSanitizeReturnsPlainCopyWhenSafe() {
        XCTAssertEqual(
            HealthIntelligencePresentationTextSanitizer.sanitize("Recovery looks supportive today."),
            "Recovery looks supportive today."
        )
    }

    func testSanitizeReturnsNilForRawMetricLanguage() {
        XCTAssertNil(
            HealthIntelligencePresentationTextSanitizer.sanitize("HRV was below your recent baseline.")
        )
        XCTAssertNil(
            HealthIntelligencePresentationTextSanitizer.sanitize("Resting heart rate was 58 bpm.")
        )
    }

    func testContainsRiskyMetricLanguageDetectsKnownPatterns() {
        XCTAssertTrue(
            HealthIntelligencePresentationTextSanitizer.containsRiskyMetricLanguage("Sleep was short at 42 ms HRV.")
        )
        XCTAssertFalse(
            HealthIntelligencePresentationTextSanitizer.containsRiskyMetricLanguage("Keep today lighter.")
        )
    }
}
