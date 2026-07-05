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
            remainingText: "500 kcal over target",
            progress: 1.4
        )

        XCTAssertEqual(metric.progress, 1)
    }

    func testProgressMetricClampsNegativeProgressOnDecode() throws {
        let json = """
        {
          "label": "Water",
          "current": 0,
          "target": 2500,
          "unit": "ml",
          "remainingText": "No water logged yet",
          "progress": -0.2
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let metric = try JSONDecoder().decode(ProgressMetric.self, from: data)

        XCTAssertEqual(metric.progress, 0)
    }

    func testZeroCurrentDoesNotUseWinLanguage() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        var summary = buildReviewSummary(for: log)
        summary.caloriesConsumed = 0
        summary.proteinConsumed = 0
        summary.waterConsumedMl = 0
        summary.hasMetProteinTarget = false
        summary.hasMetWaterTarget = false

        let payload = DailyReviewPayloadBuilder.build(
            review: makeReview(from: summary),
            summary: summary
        )

        XCTAssertEqual(payload.snapshot.calories.remainingText, "No calories logged yet")
        XCTAssertEqual(payload.snapshot.protein.remainingText, "No protein logged yet")
        XCTAssertEqual(payload.snapshot.water.remainingText, "No water logged yet")
        XCTAssertFalse(payload.snapshot.protein.remainingText.localizedCaseInsensitiveContains("met"))
        XCTAssertFalse(payload.snapshot.water.remainingText.localizedCaseInsensitiveContains("met"))
        XCTAssertEqual(payload.statusSummary, "No food logged yet today.")
    }

    func testProgressRatioIsZeroWhenCurrentIsZeroEvenIfTargetMetFlagsExist() {
        let log = TestFixtureFactory.nutritionLog(.waterExactlyAtTarget)
        var summary = buildReviewSummary(for: log)
        summary.waterConsumedMl = 0
        summary.hasMetWaterTarget = true

        let payload = DailyReviewPayloadBuilder.build(
            review: makeReview(from: summary),
            summary: summary
        )

        XCTAssertEqual(payload.snapshot.water.progress, 0)
        XCTAssertEqual(payload.snapshot.water.remainingText, "No water logged yet")
    }

    func testMissingSignalsAreConsolidatedWithoutDuplicates() {
        var missing = CoachMissingDataContext()
        missing.stepsMissing = true
        missing.stepsUnavailable = true
        missing.healthKitDenied = true
        missing.healthKitUnavailable = true

        let messages = DailyReviewPayloadBuilder.missingSignalMessages(
            from: missing
        )

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], "Steps aren't available from Apple Health right now.")
        XCTAssertEqual(messages[1], "Some Apple Health signals are unavailable.")
    }

    func testPayloadIncludesDetailNoteAndTomorrowFocus() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        var summary = buildReviewSummary(for: log)
        summary.hasWorkout = true
        var review = makeReview(from: summary)
        review.summaryText = "Strong protein pacing today."
        review.workoutSummary = "Workout: 1 session logged, estimated 320 kcal burned."
        review.tomorrowRecommendation = "Start hydration earlier tomorrow."

        let payload = DailyReviewPayloadBuilder.build(review: review, summary: summary)

        XCTAssertEqual(payload.detailNote, "Strong protein pacing today.")
        XCTAssertEqual(payload.bestNextMove, "Start hydration earlier tomorrow.")
        XCTAssertEqual(payload.tomorrowFocus, review.workoutSummary)
        XCTAssertGreaterThan(payload.snapshot.calories.progress, 0)
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

    func testAccessibilityFormatterIncludesMissingSignalsOnceEach() {
        let payload = DailyReviewPayload(
            title: "Daily Review",
            timezoneLabel: "Jul 5, 2026 · GMT",
            generatedAt: Date(),
            snapshot: DailyReviewSnapshot(
                calories: ProgressMetric(
                    label: "Calories",
                    current: 0,
                    target: 2_000,
                    unit: "kcal",
                    remainingText: "No calories logged yet",
                    progress: 0
                ),
                protein: ProgressMetric(
                    label: "Protein",
                    current: 0,
                    target: 140,
                    unit: "g",
                    remainingText: "No protein logged yet",
                    progress: 0
                ),
                water: ProgressMetric(
                    label: "Water",
                    current: 0,
                    target: 2_500,
                    unit: "ml",
                    remainingText: "No water logged yet",
                    progress: 0
                )
            ),
            statusSummary: "No food logged yet today.",
            bestNextMove: "Log your first meal.",
            tomorrowFocus: nil,
            missingSignals: ["Steps aren't available from Apple Health right now."],
            detailNote: nil
        )

        let text = DailyReviewPayloadAccessibilityFormatter.text(from: payload)

        XCTAssertTrue(text.contains("Missing signals:"))
        XCTAssertEqual(text.components(separatedBy: "Steps aren't available from Apple Health right now.").count - 1, 1)
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
