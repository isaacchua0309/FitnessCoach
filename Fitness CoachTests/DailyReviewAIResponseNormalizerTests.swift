//
//  DailyReviewAIResponseNormalizerTests.swift
//  Fitness CoachTests
//
//  Structured daily review AI copy contract coverage.
//

import XCTest
@testable import Fitness_Coach

final class DailyReviewAIResponseNormalizerTests: XCTestCase {

    func testNormalizerStripsTimezoneHeaderProse() {
        let summary = makeSummary()
        let response = DailyReviewAIResponse(
            statusSummary: "Daily review (Asia/Singapore): You are still within today's calorie target.",
            bestNextMove: "Add protein at your next meal."
        )

        let normalized = DailyReviewAIResponseNormalizer.normalize(response, summary: summary)

        XCTAssertEqual(normalized?.statusSummary, "You are still within today's calorie target.")
        XCTAssertFalse(normalized?.statusSummary.contains("Asia/Singapore") ?? true)
    }

    func testNormalizerRejectsFalsePraiseWithoutLoggedWins() {
        var summary = makeSummary()
        summary.caloriesConsumed = 0
        summary.proteinConsumed = 0
        summary.waterConsumedMl = 0
        summary.foodEntryCount = 0

        let response = DailyReviewAIResponse(
            statusSummary: "Win today with amazing consistency.",
            bestNextMove: "Great job tomorrow."
        )

        XCTAssertNil(DailyReviewAIResponseNormalizer.normalize(response, summary: summary))
    }

    func testNormalizerRemovesUnavailableDataSentencesFromFields() {
        let summary = makeSummary()
        let response = DailyReviewAIResponse(
            statusSummary: "You are within target. Steps aren't available from Apple Health right now.",
            bestNextMove: "Add protein at your next meal."
        )

        let normalized = DailyReviewAIResponseNormalizer.normalize(response, summary: summary)

        XCTAssertEqual(normalized?.statusSummary, "You are within target.")
        XCTAssertEqual(normalized?.bestNextMove, "Add protein at your next meal.")
    }

    func testNormalizerTruncatesFieldsToContractMaxLengths() {
        let summary = makeSummary()
        let response = DailyReviewAIResponse(
            statusSummary: String(repeating: "Within target today. ", count: 12),
            bestNextMove: String(repeating: "Add lean protein early. ", count: 12),
            tomorrowFocus: String(repeating: "Hydrate earlier tomorrow. ", count: 12),
            detailNote: String(repeating: "Solid pacing. ", count: 12)
        )

        let normalized = try XCTUnwrap(
            DailyReviewAIResponseNormalizer.normalize(response, summary: summary)
        )

        XCTAssertLessThanOrEqual(
            normalized.statusSummary.count,
            DailyReviewContentContract.maxStatusSummaryLength
        )
        XCTAssertLessThanOrEqual(
            normalized.bestNextMove.count,
            DailyReviewContentContract.maxBestNextMoveLength
        )
        XCTAssertLessThanOrEqual(
            normalized.tomorrowFocus?.count ?? 0,
            DailyReviewContentContract.maxTomorrowFocusLength
        )
        XCTAssertLessThanOrEqual(
            normalized.detailNote?.count ?? 0,
            DailyReviewContentContract.maxDetailNoteLength
        )
    }

    func testPayloadBuilderEnforcesContractMaxLengths() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        let summary = buildReviewSummary(for: log)
        let review = makeReview(from: summary)
        let aiResponse = DailyReviewAIResponse(
            statusSummary: "You are still within today's calorie target.",
            bestNextMove: "Add 22g protein at your next meal.",
            tomorrowFocus: "Drink 700ml more water today.",
            detailNote: "Solid protein pacing today."
        )

        let payload = DailyReviewPayloadBuilder.build(
            review: review,
            summary: summary,
            aiResponse: aiResponse
        )

        XCTAssertLessThanOrEqual(
            payload.statusSummary.count,
            DailyReviewContentContract.maxStatusSummaryLength
        )
        XCTAssertLessThanOrEqual(
            payload.bestNextMove.count,
            DailyReviewContentContract.maxBestNextMoveLength
        )
        XCTAssertLessThanOrEqual(
            payload.tomorrowFocus?.count ?? 0,
            DailyReviewContentContract.maxTomorrowFocusLength
        )
        XCTAssertLessThanOrEqual(
            payload.detailNote?.count ?? 0,
            DailyReviewContentContract.maxDetailNoteLength
        )
    }

    func testPayloadBuilderUsesDeterministicMissingSignalsOverAI() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
        let summary = buildReviewSummary(for: log)
        let review = makeReview(from: summary)
        var missing = CoachMissingDataContext()
        missing.stepsMissing = true
        missing.hrvUnavailable = true

        let payload = DailyReviewPayloadBuilder.build(
            review: review,
            summary: summary,
            aiResponse: DailyReviewAIResponse(
                statusSummary: "You are still within today's calorie target.",
                bestNextMove: "Add protein at your next meal.",
                missingSignals: ["Steps", "Sleep"]
            ),
            contextHints: CoachResponseContextHints(missingData: missing)
        )

        XCTAssertEqual(payload.missingSignals, ["Steps", "HRV"])
    }

    private func makeSummary() -> DailyReviewSummary {
        buildReviewSummary(for: TestFixtureFactory.nutritionLog(.baseline))
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
            summaryText: "",
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
