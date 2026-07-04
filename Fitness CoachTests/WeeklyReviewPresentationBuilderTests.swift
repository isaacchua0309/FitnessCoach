//
//  WeeklyReviewPresentationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class WeeklyReviewPresentationBuilderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var weekStart: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 6, day: 27))!
        )
    }

    private var weekEnd: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
    }

    func testStrongReviewMapsCardAndDetail() {
        let review = makeStrongReview()

        let card = WeeklyReviewPresentationBuilder.buildCard(from: review, calendar: calendar)
        let detail = WeeklyReviewPresentationBuilder.buildDetail(from: review, calendar: calendar)

        XCTAssertEqual(card.phase, .loaded)
        XCTAssertEqual(card.title, "Solid training week")
        XCTAssertEqual(card.confidenceLabel, FormaProductCopy.WeeklyReviewPresentation.confidenceModerate)
        XCTAssertEqual(
            card.dateRangeLabel,
            JourneyFormatter.timelineDateRangeLabel(start: weekStart, end: weekEnd, calendar: calendar)
        )
        XCTAssertEqual(card.headlineStatLabel, "4 workouts")

        XCTAssertNotNil(detail)
        XCTAssertEqual(detail?.title, "Solid training week")
        XCTAssertEqual(detail?.wins.count, 2)
        XCTAssertEqual(detail?.nextWeekFocus.count, 2)
        XCTAssertNil(detail?.missingDataNotice)
        XCTAssertFalse(detail?.generatedAtLabel.isEmpty ?? true)
        XCTAssertTrue(detail?.statsGrid.items.contains { $0.id == "workouts" && !$0.isLimited } == true)
        XCTAssertTrue(detail?.statsGrid.items.contains { $0.id == "weight" && !$0.isLimited } == true)
    }

    func testSparseReviewUsesLimitedConfidenceAndNotice() {
        let review = WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Building week",
            summary: "A lighter week with partial signals. Keep logging to strengthen next week's review.",
            stats: WeeklyStats(
                totalWorkouts: 1,
                totalWorkoutMinutes: 35,
                totalActiveCalories: 220,
                averageSteps: 5_400,
                totalSteps: 37_800,
                proteinHitDays: 2,
                calorieTargetHitDays: 2,
                waterHitDays: 1,
                averageRecoveryScore: nil,
                lowRecoveryDays: 2,
                weightChangeKg: nil,
                loggingConsistencyDays: 3
            ),
            wins: ["1 workout logged"],
            risks: ["Recovery was limited on 2 days"],
            nextWeekFocus: ["Add one more training day"],
            confidence: .low,
            missingSignals: [.recovery, .weight],
            generatedAt: weekEnd
        )

        let card = WeeklyReviewPresentationBuilder.buildCard(from: review, calendar: calendar)
        let detail = WeeklyReviewPresentationBuilder.buildDetail(from: review, calendar: calendar)

        XCTAssertEqual(card.confidenceLabel, FormaProductCopy.WeeklyReviewPresentation.confidenceLow)
        XCTAssertNotNil(detail?.missingDataNotice)
        XCTAssertTrue(detail?.missingDataNotice?.contains("Recovery") == true)
        XCTAssertTrue(detail?.missingDataNotice?.contains("Weight") == true)
        XCTAssertTrue(detail?.statsGrid.items.contains { $0.id == "weight" && $0.isLimited } == true)
        XCTAssertTrue(detail?.statsGrid.items.contains { $0.id == "recovery" && $0.isLimited } == true)
    }

    func testMissingWeightShowsLimitedWeightStat() {
        var review = makeStrongReview()
        review.stats.weightChangeKg = nil
        review.missingSignals.insert(.weight)

        let detail = WeeklyReviewPresentationBuilder.buildDetail(from: review, calendar: calendar)

        let weight = detail?.statsGrid.items.first { $0.id == "weight" }
        XCTAssertEqual(weight?.value, FormaProductCopy.WeeklyReviewPresentation.weightUnavailable)
        XCTAssertTrue(weight?.isLimited == true)
        XCTAssertNotNil(detail?.missingDataNotice)
    }

    func testMissingNutritionMarksNutritionStatsLimited() {
        var review = makeStrongReview()
        review.stats.proteinHitDays = 0
        review.stats.calorieTargetHitDays = 0
        review.stats.waterHitDays = 0
        review.stats.loggingConsistencyDays = 0
        review.missingSignals.insert(.nutrition)

        let detail = WeeklyReviewPresentationBuilder.buildDetail(from: review, calendar: calendar)

        XCTAssertTrue(detail?.statsGrid.items.contains { $0.id == "protein" && $0.isLimited } == true)
        XCTAssertTrue(detail?.statsGrid.items.contains { $0.id == "calories" && $0.isLimited } == true)
        XCTAssertTrue(detail?.statsGrid.items.contains { $0.id == "water" && $0.isLimited } == true)
        XCTAssertTrue(detail?.missingDataNotice?.contains("Nutrition") == true)
    }

    func testNoWeeklyReviewReturnsEmptyCardAndNilDetail() {
        let emptyCard = WeeklyReviewPresentationBuilder.buildCard(from: nil, calendar: calendar)
        let emptyTitleCard = WeeklyReviewPresentationBuilder.buildCard(
            from: WeeklyHealthReview.empty,
            calendar: calendar
        )

        XCTAssertEqual(emptyCard.phase, .empty)
        XCTAssertEqual(emptyTitleCard.phase, .empty)
        XCTAssertNil(WeeklyReviewPresentationBuilder.buildDetail(from: nil, calendar: calendar))
        XCTAssertNil(WeeklyReviewPresentationBuilder.buildDetail(from: WeeklyHealthReview.empty, calendar: calendar))
    }

    func testSanitizesRiskyMetricLanguageInSummary() {
        var review = makeStrongReview()
        review.summary = "HRV was below your recent baseline and sleep was short."

        let card = WeeklyReviewPresentationBuilder.buildCard(from: review, calendar: calendar)

        XCTAssertEqual(card.summary, FormaProductCopy.WeeklyReviewPresentation.partialDataSummary)
        XCTAssertFalse(card.summary.lowercased().contains("hrv"))
        XCTAssertFalse(card.summary.contains("baseline"))
    }

    func testDetailAccessibilityLabelIncludesConfidenceAndGeneratedAt() {
        let detail = WeeklyReviewPresentationBuilder.buildDetail(
            from: makeStrongReview(),
            calendar: calendar
        )

        XCTAssertTrue(detail?.accessibilityLabel.contains(FormaProductCopy.WeeklyReviewPresentation.confidenceModerate) == true)
        XCTAssertTrue(detail?.accessibilityLabel.contains("Updated") == true)
    }

    // MARK: - Fixtures

    private func makeStrongReview() -> WeeklyHealthReview {
        WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Solid training week",
            summary: "You logged consistent workouts and kept protein on track most days.",
            stats: WeeklyStats(
                totalWorkouts: 4,
                totalWorkoutMinutes: 210,
                totalActiveCalories: 1_420,
                averageSteps: 8_200,
                totalSteps: 57_400,
                proteinHitDays: 5,
                calorieTargetHitDays: 4,
                waterHitDays: 3,
                averageRecoveryScore: 68,
                lowRecoveryDays: 1,
                weightChangeKg: -0.3,
                loggingConsistencyDays: 6
            ),
            wins: ["4 workouts logged", "Protein on target 5 days"],
            risks: ["Hydration dipped mid-week"],
            nextWeekFocus: ["Front-load water", "Keep one rest day lighter"],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: weekEnd
        )
    }
}
