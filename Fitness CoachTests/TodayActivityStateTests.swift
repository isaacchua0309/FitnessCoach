//
//  TodayActivityStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayActivityStateTests: XCTestCase {

    func testConnectedWithWorkoutsShowsStepsWorkoutStatusAndWeeklyProgress() {
        let activity = makeActivity(
            stepsToday: 8_432,
            weeklyWorkoutCount: 1,
            appleHealthWorkoutCount: 1,
            stepGoalAssumption: 7_500,
            trainingFrequencyPerWeek: 4
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        guard case .connected(let model) = display else {
            return XCTFail("Expected connected presentation")
        }

        XCTAssertFalse(model.showsEmptyState)
        XCTAssertEqual(model.stepsLine, "8,432 steps")
        XCTAssertEqual(model.stepAssumptionLine, "Typical: 7,500/day")
        XCTAssertEqual(model.workoutStatusLine, FormaProductCopy.Today.workoutsToday(1))
        XCTAssertEqual(model.weeklyProgressLine, "1 of 4 sessions")
        XCTAssertTrue(model.accessibilitySummary.contains("8,432 steps"))
        XCTAssertTrue(model.accessibilitySummary.contains("1 of 4 sessions"))
        XCTAssertFalse(model.accessibilitySummary.contains("calorie"))
        XCTAssertFalse(model.accessibilitySummary.contains("adjust"))
    }

    func testDisconnectedShowsConnectCTAWithoutLockIcon() {
        let activity = makeActivity(
            trainingIntegration: .notConnected,
            stepGoalAssumption: 7_500,
            trainingFrequencyPerWeek: 4,
            showsConnectCTA: true
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        guard case .disconnected(let model) = display else {
            return XCTFail("Expected disconnected presentation")
        }

        XCTAssertFalse(model.showsLockedIcon)
        XCTAssertEqual(model.title, FormaProductCopy.Today.EmptyState.appleHealthTitle)
        XCTAssertTrue(model.title.localizedCaseInsensitiveContains("optional"))
        XCTAssertEqual(model.actionTitle, FormaProductCopy.Training.Integration.connectAppleHealth)
        XCTAssertTrue(model.message.localizedCaseInsensitiveContains("either way"))
    }

    func testNoWorkoutsTodayShowsWorkoutStatusWithoutEmptyStateWhenStepsAvailable() {
        let activity = makeActivity(
            stepsToday: 6_120,
            weeklyWorkoutCount: 0,
            appleHealthWorkoutCount: 0,
            stepGoalAssumption: 7_500,
            trainingFrequencyPerWeek: 4
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        guard case .connected(let model) = display else {
            return XCTFail("Expected connected presentation")
        }

        XCTAssertFalse(model.showsEmptyState)
        XCTAssertEqual(model.workoutStatusLine, FormaProductCopy.Today.statusNoAppleHealthWorkoutToday)
        XCTAssertEqual(model.weeklyProgressLine, "0 of 4 sessions")
    }

    func testTrainingFrequencyUnavailableHidesWeeklyProgressLine() {
        let activity = makeActivity(
            stepsToday: 4_500,
            weeklyWorkoutCount: 2,
            appleHealthWorkoutCount: 1,
            stepGoalAssumption: 7_500,
            trainingFrequencyPerWeek: nil
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        guard case .connected(let model) = display else {
            return XCTFail("Expected connected presentation")
        }

        XCTAssertNil(model.weeklyProgressLine)
        XCTAssertFalse(model.accessibilitySummary.contains("sessions"))
    }

    func testNoActivityDataShowsEmptyStateWhenConnectedAndHealthReadsAreEmpty() {
        let activity = makeActivity(
            stepsToday: nil,
            weeklyWorkoutCount: 0,
            appleHealthWorkoutCount: 0,
            trainingFrequencyPerWeek: 4
        )

        let display = TodayActivitySectionFormatting.displayModel(for: activity)

        guard case .connected(let model) = display else {
            return XCTFail("Expected connected presentation")
        }

        XCTAssertTrue(model.showsEmptyState)
        XCTAssertEqual(model.emptyStateTitle, FormaProductCopy.Today.EmptyState.noActivityTitle)
        XCTAssertEqual(model.emptyStateLine, FormaProductCopy.Today.EmptyState.noActivityBody)
        XCTAssertTrue(model.accessibilitySummary.contains(FormaProductCopy.Today.EmptyState.noActivityBody))
    }

    func testStepsTodayResolverUsesDayBounds() async throws {
        let reader = MockHealthKitStepReader(stepCount: 5_678)
        let date = TodayDashboardFixtures.date(hour: 15)

        let steps = try await TodayHealthStepResolver.stepsToday(reader: reader, on: date)

        XCTAssertEqual(steps, 5_678)
        XCTAssertEqual(reader.fetchCallCount, 1)
        XCTAssertNotNil(reader.lastFetchRange)
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

        let count = try await TodayHealthWorkoutResolver.workoutCountThisWeek(
            reader: reader,
            on: today,
            calendar: calendar
        )

        XCTAssertEqual(count, 2)
    }

    // MARK: - Fixtures

    private func makeActivity(
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        stepsToday: Int? = nil,
        weeklyWorkoutCount: Int? = nil,
        appleHealthWorkoutCount: Int? = nil,
        stepGoalAssumption: Int? = nil,
        trainingFrequencyPerWeek: Int? = nil,
        showsConnectCTA: Bool = false
    ) -> ActivityTodayState {
        ActivityTodayState(
            legacyWorkoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 0,
                workoutCount: appleHealthWorkoutCount ?? 0,
                hasWorkout: (appleHealthWorkoutCount ?? 0) > 0
            ),
            trainingIntegration: trainingIntegration,
            trainingDataSource: trainingDataSource,
            appleHealthWorkoutCount: appleHealthWorkoutCount,
            stepsToday: stepsToday,
            weeklyWorkoutCount: weeklyWorkoutCount,
            stepGoalAssumption: stepGoalAssumption,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek,
            displayLine: FormaProductCopy.Today.statusNoAppleHealthWorkoutToday,
            showsConnectCTA: showsConnectCTA
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
