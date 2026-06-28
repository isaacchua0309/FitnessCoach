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

    func testProgressAttributionDoesNotShameMissingWorkouts() {
        let context = JourneyDashboardBuilder.Context(
            profile: nil,
            baseline: JourneyBaseline(
                startWeightKg: 80,
                startDate: Date(),
                currentWeightKg: 80,
                goalWeightKg: 75,
                goalDirection: .lose,
                totalChangeKg: 0,
                remainingChangeKg: 5,
                progressPercent: 0,
                estimatedCompletionDate: nil,
                estimatedCompletionMonthLabel: nil,
                hasRealWeightEntries: true,
                usesSyntheticBaselinePoint: false,
                onboardingBaselineWeightKg: 80,
                chartPoints: [],
                showsWeightChart: false
            ),
            maturityLogs: [],
            weekLogs: [],
            previousWeekLogs: [],
            monthLogs: [],
            rangeLogs: [],
            allWeights: [],
            weekWeights: [],
            rangeWeights: [],
            streakSummary: StreakSummary(
                loggingStreak: 0,
                proteinStreak: 0,
                hydrationStreak: 0,
                workoutStreak: 0
            ),
            weeklyTraining: .connectedEmpty,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 80,
                changeKg: nil,
                direction: .stable,
                hasSuddenSpike: false
            ),
            goalProjection: nil,
            healthWorkoutDayStarts: [],
            monthHealthWorkoutCount: 0,
            weekHealthWorkoutCount: 0,
            loggedDays: 0,
            nutritionSummary: ProgressNutritionSummary(
                loggedDays: 0,
                averageCalories: nil,
                averageProtein: nil,
                averageCarbs: nil,
                averageFat: nil,
                averageFiber: nil
            ),
            waterSummary: ProgressWaterSummary(
                loggedDays: 0,
                averageWaterMl: nil,
                averageWaterTargetMl: nil,
                consistencyPercent: nil
            ),
            workoutSummary: nil,
            selectedRangeDays: 28,
            asOf: Date(),
            calendar: Calendar.current
        )

        let attribution = JourneyDashboardBuilder.progressAttribution(context: context)
        let messages = [attribution.primaryReason] + attribution.supportingReasons

        XCTAssertFalse(messages.contains { $0.localizedCaseInsensitiveContains("behind") })
        XCTAssertFalse(messages.contains { $0.localizedCaseInsensitiveContains("missed") })
        XCTAssertTrue(
            attribution.primaryReason.contains("habit")
                || attribution.primaryReason.contains("Consistency")
                || attribution.primaryReason.contains("building")
        )
    }
}
