//
//  PlanReviewStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanReviewStateTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!
    private let calendar = Calendar.current

    func testRecentlyUpdatedPlan() {
        let review = PlanMissionControlFixtures.loseDashboard.review

        XCTAssertEqual(review.sectionTitle, "Next Review")
        XCTAssertEqual(review.headline, "In 7 days")
        XCTAssertEqual(
            review.bodyCopy,
            FormaProductCopy.PlanMissionControl.planReviewBodyCopy
        )
    }

    func testReadyForReview() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.updatedAt = calendar.date(byAdding: .day, value: -8, to: referenceDate)!

        let review = PlanReviewStateBuilder.build(
            profile: profile,
            weekLogs: activeWeekLogs,
            allWeights: recentWeightEntries,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(review.headline, "Ready for review")
        XCTAssertNil(review.weighInHint)
    }

    func testMissingWeighInHint() {
        let review = PlanMissionControlFixtures.newUserDashboard.review

        XCTAssertEqual(
            review.weighInHint,
            FormaProductCopy.PlanMissionControl.planReviewWeighInHint
        )
        XCTAssertEqual(review.headline, "In 7 days")
    }

    func testNoDateFallback() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.updatedAt = Date(timeIntervalSince1970: 0)
        profile.createdAt = Date(timeIntervalSince1970: 0)

        let anchor = PlanReviewStateBuilder.reviewAnchorDate(
            profile: profile,
            fallback: referenceDate
        )
        let review = PlanReviewStateBuilder.build(
            profile: profile,
            weekLogs: [],
            allWeights: [],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(anchor, referenceDate)
        XCTAssertEqual(review.headline, "In 7 days")
    }

    func testDashboardReviewUsesNextReviewPresentation() {
        let review = PlanMissionControlFixtures.loseDashboard.review

        XCTAssertFalse(review.headline.hasPrefix("Last updated"))
        XCTAssertFalse(review.accessibilitySummary.isEmpty)
    }

    private var recentWeightEntries: [WeightEntry] {
        [
            WeightEntry(
                id: UUID(),
                date: referenceDate,
                weightKg: 89.6,
                note: nil,
                createdAt: referenceDate
            )
        ]
    }

    private var activeWeekLogs: [DailyLog] {
        (0..<5).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: referenceDate)!
            return DailyLog(
                id: UUID(),
                date: date,
                weightKg: nil,
                targets: PlanMissionControlFixtures.loseProfile.targets,
                totals: MacroTotals(
                    calories: 2200,
                    protein: 170,
                    carbs: 175,
                    fat: 55,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: 3000,
                steps: nil,
                workoutCaloriesBurned: 0,
                dailyReviewId: nil,
                createdAt: date,
                updatedAt: date
            )
        }
    }
}
