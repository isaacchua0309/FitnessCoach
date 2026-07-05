//
//  JourneyScreenPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Journey source-of-truth presentation builder tests.
//

import XCTest
@testable import Fitness_Coach

final class JourneyScreenPresentationBuilderTests: XCTestCase {

    func testMealLoggingStreakZeroWhenNoMealDaysInWeek() {
        let asOf = WeeklyProgressFixtures.asOf
        let calendar = WeeklyProgressFixtures.calendar
        let logs = [WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0, waterMl: 500)]

        let streaks = JourneyStreakBuilder.build(
            JourneyStreakBuilder.Input(
                streakSummary: StreakSummary(
                    loggingStreak: 1,
                    mealLoggingStreak: 0,
                    checkInStreak: 1,
                    proteinStreak: 0,
                    hydrationStreak: 0,
                    workoutStreak: 0
                ),
                maturityLogs: logs,
                workoutDates: [],
                isAppleHealthConnected: false,
                asOf: asOf,
                calendar: calendar
            )
        )

        XCTAssertEqual(streaks.currentMealLoggingStreakDays, 0)
        XCTAssertEqual(streaks.currentCheckInStreakDays, 1)
        XCTAssertEqual(streaks.heroStreakChip.label, FormaProductCopy.Journey.Streaks.checkInStreak(days: 1))
    }

    func testNextBestActionLogFirstMealWhenNoMealsLogged() {
        let dashboard = JourneyPreviewData.brandNewUser
        XCTAssertEqual(
            dashboard.screenPresentation.nextBestAction.kind,
            .logFirstMeal
        )
        XCTAssertFalse(dashboard.screenPresentation.copy.allowsFewMoreMealsCopy)
    }

    func testCanonicalWeekRangeMatchesWeeklySummary() {
        let dashboard = JourneyPreviewData.strongMomentum
        XCTAssertEqual(
            dashboard.screenPresentation.weekly.dateRangeText,
            dashboard.unifiedWeeklyReview.dateRangeText
        )
        XCTAssertEqual(
            dashboard.screenPresentation.weekly.weekRange.startDate,
            dashboard.weeklyProgressSummary.startDate
        )
    }

    func testConfidenceBuildingLabelForLowConfidence() {
        let dashboard = JourneyPreviewData.sparseData
        XCTAssertEqual(
            dashboard.screenPresentation.copy.confidenceLabel,
            FormaProductCopy.Journey.WeeklyConfidence.building
        )
    }

    func testStoryEventsSortedNewestFirst() {
        let dashboard = JourneyPreviewData.strongMomentum
        let events = dashboard.screenPresentation.story.events
        guard events.count >= 2 else {
            XCTFail("Expected multiple story events")
            return
        }
        XCTAssertGreaterThanOrEqual(events[0].date, events[1].date)
    }
}
