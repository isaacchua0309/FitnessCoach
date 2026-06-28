//
//  JourneyProgressStructureTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyProgressStructureTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = ProfileTestFixtures.referenceDate

    func testProductSectionOrderMatchesCanonicalLayout() {
        XCTAssertEqual(JourneyProductLayout.sectionOrder, [
            .transformation,
            .weeklyReview,
            .milestones,
            .storyTimeline,
            .habitInsights,
            .whyProgress,
            .beforeToday,
            .personalRecords,
            .monthlyRecap,
            .journeyLevel,
            .detailedAnalytics
        ])
        XCTAssertEqual(JourneyProductLayout.sectionOrder.last, .detailedAnalytics)
    }

    func testDetailedAnalyticsCollapsedByDefaultInBuiltState() {
        let analytics = JourneyDashboardBuilder.detailedAnalytics(
            context: minimalContext(),
            weightInterpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.stable
        )

        XCTAssertTrue(analytics.isCollapsedByDefault)
    }

    func testBuiltDetailedAnalyticsIncludesAppleHealthTrainingMetrics() {
        let workout = ProgressWorkoutSummary(
            workoutCount: 3,
            workoutDays: 2,
            totalEstimatedCaloriesBurned: 900,
            averageWorkoutsPerWeek: 2,
            averageDurationMinutes: 35,
            isFromAppleHealth: true
        )
        let analytics = JourneyDashboardBuilder.detailedAnalytics(
            context: minimalContext(
                weeklyTraining: .connected(
                    workoutDays: 2,
                    averageCaloriesBurned: 400,
                    averageTrainingDurationMinutes: 35
                ),
                workoutSummary: workout
            ),
            weightInterpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.stable
        )

        guard case .metrics(let summary) = analytics.trainingDisplay else {
            return XCTFail("Expected training metrics in built analytics")
        }

        XCTAssertTrue(summary.isFromAppleHealth)
        XCTAssertGreaterThan(summary.workoutCount, 0)
    }

    func testDefaultSelectedRangeDaysIsTwentyEight() {
        XCTAssertEqual(minimalContext().selectedRangeDays, 28)
    }

    func testTrainingAnalyticsDisplayResolverMatchesWeeklyTrainingState() {
        let workout = ProgressWorkoutSummary(
            workoutCount: 3,
            workoutDays: 2,
            totalEstimatedCaloriesBurned: 900,
            averageWorkoutsPerWeek: 2,
            averageDurationMinutes: 35,
            isFromAppleHealth: true
        )

        XCTAssertEqual(
            JourneyDashboardBuilder.trainingAnalyticsDisplay(
                weeklyTraining: .connectedEmpty,
                workoutSummary: nil
            ),
            .connectedEmpty
        )
        XCTAssertEqual(
            JourneyDashboardBuilder.trainingAnalyticsDisplay(
                weeklyTraining: .connected(
                    workoutDays: 2,
                    averageCaloriesBurned: 400,
                    averageTrainingDurationMinutes: 35
                ),
                workoutSummary: workout
            ),
            .metrics(workout)
        )
        XCTAssertEqual(
            JourneyDashboardBuilder.trainingAnalyticsDisplay(
                weeklyTraining: .locked,
                workoutSummary: workout
            ),
            .hidden
        )
    }

    func testRemovedSectionsAreNotPartOfCanonicalOrder() {
        let identifiers = Set(JourneyProductLayout.sectionOrder.map(\.rawValue))

        XCTAssertFalse(identifiers.contains("consistencyCalendar"))
        XCTAssertFalse(identifiers.contains("coachInsights"))
        XCTAssertFalse(identifiers.contains("achievements"))
    }

    private func minimalContext(
        weeklyTraining: JourneyWeeklyTrainingStatus = .connectedEmpty,
        workoutSummary: ProgressWorkoutSummary? = nil
    ) -> JourneyDashboardBuilder.Context {
        let profile = ProfileTestFixtures.sampleProfile
        let baseline = JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: profile,
                allWeights: [],
                maturityLogs: [],
                goalProjection: nil,
                asOf: asOf,
                calendar: calendar
            )
        )

        return JourneyDashboardBuilder.Context(
            profile: profile,
            baseline: baseline,
            maturityLogs: [],
            weekLogs: [],
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            monthLogs: [],
            allWeights: [],
            weekWeights: [],
            journeyStreaks: JourneyStreakBuilder.build(
                JourneyStreakBuilder.Input(
                    streakSummary: StreakSummary(
                        loggingStreak: 0,
                        proteinStreak: 0,
                        hydrationStreak: 0,
                        workoutStreak: 0
                    ),
                    maturityLogs: [],
                    workoutDates: [],
                    isAppleHealthConnected: false,
                    asOf: asOf,
                    calendar: calendar
                )
            ),
            weeklyTraining: weeklyTraining,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: baseline.currentWeightKg,
                changeKg: nil,
                direction: .insufficientData,
                hasSuddenSpike: false
            ),
            goalProjection: nil,
            healthWorkoutDayStarts: [],
            monthHealthWorkoutCount: 0,
            nutritionSummary: ProgressLogSummaryBuilder.nutritionSummary(from: []),
            waterSummary: ProgressLogSummaryBuilder.waterSummary(from: []),
            workoutSummary: workoutSummary,
            selectedRangeDays: 28,
            asOf: asOf,
            calendar: calendar
        )
    }
}
