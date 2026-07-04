//
//  TodayActivityStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayActivityStateTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    func testStepsAvailableShowsCurrentOverGoal() {
        let activity = makeActivity(
            stepsToday: 1_827,
            stepGoalAssumption: 7_500
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        XCTAssertEqual(display.stepsLine, "1,827 / 7,500 steps")
        XCTAssertNil(display.healthNote)
    }

    func testStepsUnavailableShowsFallbackCopy() {
        let activity = makeActivity(
            stepsToday: nil,
            stepGoalAssumption: 7_500
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        XCTAssertEqual(display.stepsLine, FormaProductCopy.Today.Activity.stepsUnavailable)
    }

    func testWorkoutCompletedShowsCompletedLine() {
        let activity = makeActivity(
            stepsToday: 6_120,
            appleHealthWorkoutCount: 1,
            stepGoalAssumption: 7_500
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        XCTAssertEqual(display.workoutLine, FormaProductCopy.Today.Activity.workoutCompletedLine)
        XCTAssertEqual(
            TodayActivitySectionFormatting.workoutStatus(for: activity),
            .completed
        )
    }

    func testNoAppleHealthWorkoutTodayShowsNotLogged() {
        let activity = makeActivity(
            stepsToday: 6_120,
            appleHealthWorkoutCount: 0,
            stepGoalAssumption: 7_500
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        XCTAssertEqual(display.workoutLine, FormaProductCopy.Today.Activity.workoutNotLoggedLine)
        XCTAssertEqual(
            TodayActivitySectionFormatting.workoutStatus(for: activity),
            .notLogged
        )
    }

    func testAppleHealthDisconnectedShowsCompactFallbackNote() {
        let activity = makeActivity(
            trainingIntegration: .notConnected,
            stepGoalAssumption: 7_500,
            showsConnectCTA: true
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        XCTAssertEqual(display.stepsLine, FormaProductCopy.Today.Activity.stepsUnavailable)
        XCTAssertEqual(display.workoutLine, FormaProductCopy.Today.Activity.workoutNotLoggedLine)
        XCTAssertEqual(display.healthNote, FormaProductCopy.Today.Activity.healthConnectNote)
        XCTAssertEqual(display.healthActionTitle, FormaProductCopy.Training.Integration.connectAppleHealth)
    }

    func testPlannedWorkoutOnLikelyTrainingDay() {
        let monday = mondayDate(hour: 14)
        let activity = makeActivity(
            date: monday,
            stepsToday: 4_200,
            appleHealthWorkoutCount: 0,
            stepGoalAssumption: 7_500,
            trainingFrequencyPerWeek: 3
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        XCTAssertEqual(display.workoutLine, FormaProductCopy.Today.Activity.workoutPlannedLine)
    }

    func testHealthUnavailableShowsCompactNote() {
        let activity = makeActivity(
            trainingDataSource: .unavailable,
            stepsToday: nil,
            appleHealthWorkoutCount: 0
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        XCTAssertEqual(display.healthNote, FormaProductCopy.Today.Activity.healthUnavailableNote)
        XCTAssertNil(display.healthActionTitle)
    }

    func testStepsTodayResolverUsesDayBounds() async throws {
        let stepReader = MockHealthKitStepReader(stepCount: 5_678)
        let date = TodayDashboardFixtures.date(hour: 15)

        let query = HealthActivityQueryService(
            workoutReader: MockHealthKitWorkoutReader(),
            stepReader: stepReader
        )

        let steps = try await query.stepsToday(on: date)

        XCTAssertEqual(steps, 5_678)
        XCTAssertEqual(stepReader.fetchCallCount, 1)
        XCTAssertNotNil(stepReader.lastFetchRange)
    }

    func testWeeklyWorkoutResolverUsesRollingSevenDayWindow() async throws {
        let calendar = Calendar.current
        let today = TodayDashboardFixtures.date(hour: 12)
        let todayStart = calendar.startOfDay(for: today)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

        let reader = MockHealthKitWorkoutReader(workouts: [
            makeWorkout(on: weekStart),
            makeWorkout(on: today)
        ])

        let query = HealthActivityQueryService(
            workoutReader: reader,
            stepReader: MockHealthKitStepReader(stepCount: 0)
        )

        let count = await query.workoutCountThisWeek(
            on: today,
            calendar: calendar
        )

        XCTAssertEqual(count, 2)
    }

    // MARK: - Fixtures

    private func mondayDate(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 29
        components.hour = hour
        return calendar.date(from: components) ?? TodayDashboardFixtures.date(hour: hour)
    }

    private func makeActivity(
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        date: Date = TodayDashboardFixtures.date(hour: 14),
        stepsToday: Int? = nil,
        appleHealthWorkoutCount: Int? = nil,
        stepGoalAssumption: Int? = nil,
        trainingFrequencyPerWeek: Int = 0,
        showsConnectCTA: Bool = false
    ) -> ActivityTodayState {
        ActivityTodayState(
            phase: .hasData,
            sectionTitle: FormaProductCopy.Today.Activity.sectionTitle,
            legacyWorkoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 0,
                workoutCount: appleHealthWorkoutCount ?? 0,
                hasWorkout: (appleHealthWorkoutCount ?? 0) > 0
            ),
            trainingIntegration: trainingIntegration,
            trainingDataSource: trainingDataSource,
            appleHealthWorkoutCount: appleHealthWorkoutCount,
            stepsToday: stepsToday,
            stepGoalAssumption: stepGoalAssumption,
            showsConnectCTA: showsConnectCTA,
            date: date,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek
        )
    }

    private func makeWorkout(on date: Date) -> HealthWorkoutRecord {
        HealthWorkoutRecord(
            id: UUID(),
            activityName: "Strength training",
            startDate: date,
            endDate: date.addingTimeInterval(3_600),
            durationMinutes: 60,
            activeCalories: 300
        )
    }
}
