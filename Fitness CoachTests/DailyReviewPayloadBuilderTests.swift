//
//  DailyReviewPayloadBuilderTests.swift
//  Fitness CoachTests
//
//  Typed daily review payload builder and backwards-compatibility coverage.
//

import XCTest
@testable import Fitness_Coach

final class DailyReviewPayloadBuilderTests: XCTestCase {

    func testProgressMetricClampsProgressOnInit() {
        let metric = ProgressMetric(
            label: "Calories",
            current: 2_500,
            target: 2_000,
            unit: "kcal",
            remainingText: "Over target",
            progress: 1.4
        )

        XCTAssertEqual(metric.progress, 1)
    }

    func testAllNutritionZeroUsesRequiredStatusCopy() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        var summary = buildReviewSummary(for: log)
        summary.caloriesConsumed = 0
        summary.proteinConsumed = 0
        summary.waterConsumedMl = 0

        let payload = DailyReviewPayloadBuilder.build(
            review: makeReview(from: summary),
            summary: summary
        )

        XCTAssertEqual(payload.statusSummary, "No food or water has been logged yet today.")
        XCTAssertEqual(payload.snapshot.calories.remainingText, "Not logged yet")
        XCTAssertEqual(payload.bestNextMove, "Log your first meal or water entry.")
    }

    func testWithinCalorieTargetStatusWhenFoodLogged() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        let summary = buildReviewSummary(for: log)

        let payload = DailyReviewPayloadBuilder.build(
            review: makeReview(from: summary),
            summary: summary
        )

        XCTAssertEqual(payload.statusSummary, "You are still within today's calorie target.")
        XCTAssertFalse(payload.statusSummary.contains("\(summary.caloriesConsumed)"))
    }

    func testOverCalorieTargetStatus() {
        let log = TestFixtureFactory.nutritionLog(.caloriesOverTarget)
        let summary = buildReviewSummary(for: log)

        let payload = DailyReviewPayloadBuilder.build(
            review: makeReview(from: summary),
            summary: summary
        )

        XCTAssertEqual(payload.statusSummary, "You are over today's calorie target.")
        XCTAssertEqual(payload.snapshot.calories.remainingText, "Over target")
    }

    func testProteinAndWaterGapsSurfaceAsShortNextActions() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        var summary = buildReviewSummary(for: log)
        summary.hasMetProteinTarget = false
        summary.proteinRemaining = 22
        summary.hasMetWaterTarget = false
        summary.waterRemainingMl = 700

        let payload = DailyReviewPayloadBuilder.build(
            review: makeReview(from: summary),
            summary: summary
        )

        XCTAssertTrue(payload.bestNextMove.contains("protein"))
        XCTAssertEqual(payload.tomorrowFocus, "Drink 700ml more water today.")
    }

    func testMissingSignalsUseShortAppleHealthLabels() {
        var missing = CoachMissingDataContext()
        missing.stepsMissing = true
        missing.workoutsUnavailable = true
        missing.sleepMissing = true
        missing.hrvUnavailable = true
        missing.weightMissing = true

        let labels = DailyReviewPayloadBuilder.missingSignalLabels(from: missing)

        XCTAssertEqual(labels, ["Steps", "Workout", "Sleep", "HRV"])
    }

    func testDetailNoteIsCompactAndSkipsFallbackAI() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        let summary = buildReviewSummary(for: log)
        var review = makeReview(from: summary)
        review.summaryText = DailyReviewFormatter.fallbackSummaryText()

        XCTAssertNil(
            DailyReviewPayloadBuilder.build(review: review, summary: summary).detailNote
        )

        review.summaryText = String(repeating: "Solid day. ", count: 20)
        XCTAssertNil(
            DailyReviewPayloadBuilder.build(review: review, summary: summary).detailNote
        )

        review.summaryText = "Solid protein pacing today."
        XCTAssertEqual(
            DailyReviewPayloadBuilder.build(review: review, summary: summary).detailNote,
            "Solid protein pacing today."
        )
    }

    func testBuildSafelySanitizesVerboseAIAndWinLanguage() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        var summary = buildReviewSummary(for: log)
        summary.hasMetProteinTarget = true
        summary.hasMetWaterTarget = true
        var review = makeReview(from: summary)
        review.summaryText = String(repeating: "Great job winning the day. ", count: 12)
        review.tomorrowRecommendation = "Win tomorrow with consistency."

        let payload = DailyReviewPayloadBuilder.buildSafely(review: review, summary: summary)

        XCTAssertNil(payload.detailNote)
        XCTAssertFalse(payload.bestNextMove.lowercased().contains("win"))
        XCTAssertLessThanOrEqual(payload.statusSummary.count, 160)
    }

    func testCompactFallbackUsesLocalSummaryOnly() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        let summary = buildReviewSummary(for: log)

        let payload = DailyReviewPayloadBuilder.compactFallback(summary: summary)

        XCTAssertNil(payload.detailNote)
        XCTAssertEqual(payload.statusSummary, "You are still within today's calorie target.")
        XCTAssertGreaterThan(payload.snapshot.calories.target, 0)
    }

    func testStructuredContentRoundTripPreservesDailyReviewPayload() throws {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        let summary = buildReviewSummary(for: log)
        let payload = DailyReviewPayloadBuilder.build(
            review: makeReview(from: summary),
            summary: summary
        )

        let content = CoachStructuredMessageContent.dailyReview(payload)
        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(CoachStructuredMessageContent.self, from: data)

        guard case .dailyReview(let roundTripped) = decoded else {
            return XCTFail("Expected daily review structured content")
        }

        XCTAssertEqual(roundTripped, payload)
    }

    func testLegacyNutritionEstimateStructuredContentStillDecodes() throws {
        let card = NutritionEstimateCardState(
            id: UUID(),
            foodName: "Banana",
            displayEmoji: nil,
            servingDescription: nil,
            caloriesDisplay: "105 kcal",
            proteinDisplay: nil,
            carbsDisplay: nil,
            fatDisplay: nil,
            confidenceTitle: "Medium confidence",
            confidenceSubtitle: nil,
            coachSummary: nil,
            coachTip: nil,
            caveats: [],
            todayContext: nil,
            suggestedActions: [],
            sourceType: .common,
            confidenceLevel: .medium,
            hasMacros: false,
            hasTodayContext: false,
            logMealPayload: nil
        )

        let content = CoachStructuredMessageContent.nutritionEstimate(card)
        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(CoachStructuredMessageContent.self, from: data)

        guard case .nutritionEstimate(let state) = decoded else {
            return XCTFail("Expected nutrition estimate structured content")
        }
        XCTAssertEqual(state.foodName, "Banana")
    }

    private func buildReviewSummary(for log: DailyLog) -> DailyReviewSummary {
        DailyReviewSummaryBuilder.build(
            dailyLog: log,
            foodEntries: [],
            waterEntries: [],
            weightEntry: nil,
            latestWeightEntry: nil,
            training: .empty
        )
    }

    private func makeReview(from summary: DailyReviewSummary) -> DailyReview {
        DailyReview(
            id: UUID(),
            dailyLogId: UUID(),
            summaryText: "Coach note",
            caloriesSummary: DailyReviewFormatter.caloriesSummary(from: summary),
            proteinSummary: DailyReviewFormatter.proteinSummary(from: summary),
            hydrationSummary: DailyReviewFormatter.hydrationSummary(from: summary),
            workoutSummary: DailyReviewFormatter.workoutSummary(from: summary),
            weightSummary: DailyReviewFormatter.weightSummary(from: summary),
            tomorrowRecommendation: DailyReviewFormatter.tomorrowRecommendation(from: summary),
            createdAt: Date()
        )
    }
}
