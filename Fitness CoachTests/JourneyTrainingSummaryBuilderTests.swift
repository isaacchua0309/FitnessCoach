//
//  JourneyTrainingSummaryBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyTrainingSummaryBuilderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private let referenceNow = TrainingInsightsPreviewData.referenceNow

    func testWeeklyTrainingLockedWhenNotConnected() {
        let status = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: .notConnected,
            dataSource: .appleHealth,
            weekWorkouts: [],
            calendar: calendar
        )
        XCTAssertEqual(status, .locked)
    }

    func testWeeklyTrainingHiddenWhenUnavailable() {
        let status = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: .connected,
            dataSource: .unavailable,
            weekWorkouts: TrainingInsightsPreviewData.sampleWorkouts,
            calendar: calendar
        )
        XCTAssertEqual(status, .hidden)
    }

    func testWeeklyTrainingConnectedEmptyWithoutWorkouts() {
        let status = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: .connected,
            dataSource: .appleHealth,
            weekWorkouts: [],
            calendar: calendar
        )
        XCTAssertEqual(status, .connectedEmpty)
    }

    func testWeeklyTrainingUsesAppleHealthWorkoutDays() {
        let status = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: .connected,
            dataSource: .appleHealth,
            weekWorkouts: TrainingInsightsPreviewData.sampleWorkouts,
            asOf: referenceNow,
            calendar: calendar
        )

        guard case .connected(let days, let avgBurn, let avgDuration) = status else {
            return XCTFail("Expected connected training status")
        }
        XCTAssertEqual(days, 2)
        XCTAssertNotNil(avgBurn)
        XCTAssertNotNil(avgDuration)
    }

    func testWorkoutAnalyticsNilWhenNotConnected() {
        let analytics = JourneyTrainingSummaryBuilder.workoutAnalytics(
            integrationState: .notConnected,
            dataSource: .appleHealth,
            workouts: TrainingInsightsPreviewData.sampleWorkouts,
            rangeDays: 28,
            calendar: calendar
        )
        XCTAssertNil(analytics)
    }

    func testWorkoutAnalyticsFromAppleHealthWhenConnected() {
        let analytics = JourneyTrainingSummaryBuilder.workoutAnalytics(
            integrationState: .connected,
            dataSource: .appleHealth,
            workouts: TrainingInsightsPreviewData.sampleWorkouts,
            rangeDays: 28,
            calendar: calendar
        )

        XCTAssertEqual(analytics?.workoutCount, 3)
        XCTAssertEqual(analytics?.isFromAppleHealth, true)
        XCTAssertEqual(analytics?.workoutDays, 3)
    }

    func testCoachInsightsDoNotShameMissingWorkouts() {
        let insights = JourneyStateBuilder.coachInsights(
            weekLogs: [],
            previousWeekLogs: [],
            training: .connectedEmpty,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 80,
                changeKg: nil,
                direction: .stable,
                hasSuddenSpike: false
            ),
            nutrition: ProgressNutritionSummary(
                loggedDays: 0,
                averageCalories: nil,
                averageProtein: nil,
                averageCarbs: nil,
                averageFat: nil,
                averageFiber: nil
            ),
            water: ProgressWaterSummary(
                loggedDays: 0,
                averageWaterMl: nil,
                averageWaterTargetMl: nil,
                consistencyPercent: nil
            )
        )

        XCTAssertFalse(insights.contains { $0.message.localizedCaseInsensitiveContains("behind") })
        XCTAssertFalse(insights.contains { $0.message.localizedCaseInsensitiveContains("missed") })
        if let message = insights.first?.message {
            XCTAssertTrue(
                message.contains("Apple Fitness")
                    || message.contains("building the habit")
                    || message.contains("Consistency")
            )
        }
    }
}
