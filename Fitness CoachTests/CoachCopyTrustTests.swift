//
//  CoachCopyTrustTests.swift
//  Fitness CoachTests
//
//  Estimate-aware Coach copy — no false certainty in user-facing strings.
//

import XCTest
@testable import Fitness_Coach

final class CoachCopyTrustTests: XCTestCase {

    private static let bannedExactnessPatterns = [
        "accurate estimate",
        "exact calories",
        "this is \\d+ calories",
        "that meal has \\d+ calories",
        "confirm below to add it"
    ]

    private let chickenDraft = FoodDraft(
        mealType: nil,
        name: "chicken",
        quantity: nil,
        unit: nil,
        calories: 165,
        protein: 31,
        carbs: 0,
        fat: 4,
        fiber: nil,
        sodium: nil,
        source: .aiTextEstimate,
        confidence: .medium,
        imageUrl: nil,
        notes: nil
    )

    func testPendingEstimateCopyContainsEstimateLanguage() {
        let message = CoachResponseBuilder.aiFoodEstimatePending(
            draft: chickenDraft,
            confidence: .medium,
            originalText: "log chicken"
        )

        let lowered = message.lowercased()
        XCTAssertTrue(
            lowered.contains("estimate") || lowered.contains("about"),
            "Pending copy should frame calories as an estimate"
        )
        assertNoBannedExactnessPhrases(in: message)
    }

    func testLowConfidencePendingCopyContainsUncertainty() {
        let message = CoachResponseBuilder.aiFoodEstimatePending(
            draft: chickenDraft,
            confidence: .low,
            originalText: "log chicken"
        )

        XCTAssertTrue(message.contains(FormaProductCopy.Coach.pendingLowConfidenceWarning))
        assertNoBannedExactnessPhrases(in: message)
    }

    func testLoggedAIFoodConfirmationSaysReviewedEstimate() {
        var entry = CoachMutationTestFixtures.chickenFoodEntry
        entry.source = .aiTextEstimate

        let message = CoachResponseBuilder.food(entry, log: nil)

        XCTAssertTrue(message.contains(FormaProductCopy.Coach.loggedReviewedEstimate))
        XCTAssertTrue(message.contains("About 330 kcal"))
        assertNoBannedExactnessPhrases(in: message)
    }

    func testLoggedPhotoEstimateConfirmationSaysReviewedEstimate() {
        var entry = CoachMutationTestFixtures.chickenFoodEntry
        entry.source = .aiPhotoEstimate

        let message = CoachResponseBuilder.food(
            entry,
            log: nil,
            fromPhotoAnalysis: true
        )

        XCTAssertTrue(message.contains(FormaProductCopy.Coach.loggedReviewedPhotoEstimate))
        XCTAssertTrue(message.contains("About 330 kcal"))
        assertNoBannedExactnessPhrases(in: message)
    }

    func testManualFoodLoggedKeepsExactNutritionLine() {
        let entry = CoachMutationTestFixtures.chickenFoodEntry

        let message = CoachResponseBuilder.food(entry, log: nil)

        XCTAssertTrue(message.hasPrefix("Logged Chicken breast."))
        XCTAssertTrue(message.contains("330 kcal · 62g protein"))
        XCTAssertFalse(message.contains(FormaProductCopy.Coach.loggedReviewedEstimate))
    }

    func testAIFoodPendingConfirmationMentionsReview() {
        XCTAssertTrue(CoachResponseBuilder.aiFoodPendingConfirmation.lowercased().contains("review"))
        XCTAssertTrue(CoachResponseBuilder.aiFoodPendingConfirmation.lowercased().contains("estimate"))
    }

    func testCentralizedCoachCopyAvoidsBannedExactnessPhrases() {
        let samples = [
            FormaProductCopy.Coach.foodConfirmBelowFooter,
            FormaProductCopy.Coach.photoEstimateReviewFooter,
            FormaProductCopy.Coach.pendingReviewBeforeLogging,
            FormaProductCopy.Coach.loggedReviewedEstimate,
            FormaProductCopy.Coach.loggedReviewedPhotoEstimate,
            FormaProductCopy.Coach.pendingLowConfidenceWarning,
            CoachResponseBuilder.aiFoodPendingConfirmation
        ]

        for sample in samples {
            assertNoBannedExactnessPhrases(in: sample)
        }
    }

    private func assertNoBannedExactnessPhrases(in text: String) {
        let lowered = text.lowercased()
        for pattern in Self.bannedExactnessPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(lowered.startIndex..<lowered.endIndex, in: lowered)
            let match = regex?.firstMatch(in: lowered, options: [], range: range)
            XCTAssertNil(
                match,
                "Banned exactness phrase matching '\(pattern)' found in: \(text)"
            )
        }
    }
}
