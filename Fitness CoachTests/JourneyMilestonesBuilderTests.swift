//
//  JourneyMilestonesBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyMilestonesBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = ProfileTestFixtures.referenceDate

    func testNewUserShowsLockedFirstMilestone() {
        let state = build(foodLogDays: 0, direction: .lose)

        XCTAssertFalse(state.items.isEmpty)
        XCTAssertEqual(state.unlocked.count, 0)
        XCTAssertEqual(state.next?.id, "first-meal")
        XCTAssertEqual(state.next?.title, FormaProductCopy.Journey.Milestones.loggedFirstMeal)
        XCTAssertEqual(state.next?.status, .current)
    }

    func testOneMealLoggedUnlocksFirstMilestone() {
        let state = build(foodLogDays: 1, direction: .lose)

        XCTAssertTrue(state.unlocked.contains(where: { $0.id == "first-meal" }))
        XCTAssertEqual(state.next?.id, "first-week")
    }

    func testSevenDaysUnlocksFirstWeek() {
        let state = build(foodLogDays: 7, direction: .lose)

        XCTAssertTrue(state.unlocked.contains(where: { $0.id == "first-week" }))
        XCTAssertEqual(state.next?.id, "first-kg")
    }

    func testThirtyMealsUnlocksThirtyMealMilestone() {
        let state = build(foodLogDays: 30, proteinGoalDays: 8, direction: .lose)

        XCTAssertTrue(state.unlocked.contains(where: { $0.id == "thirty-meals" }))
    }

    func testHalfwayToGoalUnlocksForLoseGoal() {
        let state = build(
            foodLogDays: 20,
            proteinGoalDays: 6,
            startWeight: 90,
            currentWeight: 82.5,
            goalWeight: 75,
            direction: .lose,
            progressPercent: 50
        )

        XCTAssertTrue(state.unlocked.contains(where: { $0.id == "halfway" }))
    }

    func testLoseGoalUsesLostCopy() {
        let state = build(
            foodLogDays: 10,
            startWeight: 90,
            currentWeight: 88.5,
            goalWeight: 75,
            direction: .lose,
            progressPercent: 10
        )

        XCTAssertEqual(
            state.items.first(where: { $0.id == "first-kg" })?.title,
            FormaProductCopy.Journey.Milestones.firstKilogramTitle(direction: .lose)
        )
    }

    func testGainGoalUsesGainedCopy() {
        let state = build(
            foodLogDays: 10,
            startWeight: 60,
            currentWeight: 61.5,
            goalWeight: 70,
            direction: .gain,
            progressPercent: 15
        )

        XCTAssertEqual(
            state.items.first(where: { $0.id == "first-kg" })?.title,
            FormaProductCopy.Journey.Milestones.firstKilogramTitle(direction: .gain)
        )
    }

    func testMaintainGoalUsesConsistencyCopy() {
        let state = build(
            foodLogDays: 7,
            startWeight: 72,
            currentWeight: 72.2,
            goalWeight: 72,
            direction: .maintain,
            progressPercent: nil
        )

        XCTAssertEqual(
            state.items.first(where: { $0.id == "first-week" })?.title,
            FormaProductCopy.Journey.Milestones.firstWeekTitle(direction: .maintain)
        )
        XCTAssertFalse(state.items.contains(where: { $0.id == "halfway" }))
    }

    func testUnlockedBeforeLockedOrdering() {
        let state = build(foodLogDays: 3, direction: .lose)
        let firstLockedIndex = state.items.firstIndex(where: { $0.status != .completed })
        let lastUnlockedIndex = state.items.lastIndex(where: { $0.status == .completed })

        if let firstLockedIndex, let lastUnlockedIndex {
            XCTAssertLessThan(lastUnlockedIndex, firstLockedIndex)
        }
    }

    func testNextMilestoneIsFirstIncomplete() {
        let state = build(foodLogDays: 2, direction: .lose)

        XCTAssertEqual(state.next?.status, .current)
        XCTAssertEqual(state.next?.id, "first-week")
        XCTAssertNotNil(state.nextProgressFraction)
    }

    func testWaterFiveDaysUnlocksWaterMilestone() {
        let state = build(foodLogDays: 5, waterHitsGoal: true, direction: .lose)

        XCTAssertTrue(state.unlocked.contains(where: { $0.id == "water-five" }))
    }

    func testFirstWorkoutUnlocksTrainingMilestone() {
        let state = build(foodLogDays: 1, workoutCalories: 250, direction: .lose)

        XCTAssertTrue(state.unlocked.contains(where: { $0.id == "first-workout" }))
    }

    func testLockedMilestonesStayUpcomingAfterCurrent() {
        let state = build(foodLogDays: 0, direction: .lose)

        XCTAssertEqual(state.unlocked.count, 0)
        XCTAssertEqual(state.next?.status, .current)
        XCTAssertTrue(state.items.filter { $0.status == .upcoming }.count >= 2)
    }

    func testLoggingStreakSevenUnlocksStreakMilestone() {
        let state = build(
            foodLogDays: 7,
            proteinGoalDays: 4,
            direction: .lose
        )

        XCTAssertTrue(state.unlocked.contains(where: { $0.id == "logging-streak-seven" }))
    }

    func testTenKgMilestoneOnlyWhenSpanIsLargeEnough() {
        let smallSpan = build(
            foodLogDays: 50,
            startWeight: 72,
            currentWeight: 65,
            goalWeight: 68,
            direction: .lose,
            progressPercent: 80
        )
        let largeSpan = build(
            foodLogDays: 50,
            startWeight: 95,
            currentWeight: 82,
            goalWeight: 75,
            direction: .lose,
            progressPercent: 72
        )

        XCTAssertFalse(smallSpan.items.contains(where: { $0.id == "ten-kg" }))
        XCTAssertTrue(largeSpan.items.contains(where: { $0.id == "ten-kg" }))
    }

    // MARK: - Helpers

    private func build(
        foodLogDays: Int,
        proteinGoalDays: Int = 0,
        waterHitsGoal: Bool = true,
        workoutCalories: Int = 0,
        startWeight: Double = 90,
        currentWeight: Double = 90,
        goalWeight: Double = 75,
        direction: JourneyGoalDirection = .lose,
        progressPercent: Double? = 0
    ) -> JourneyMilestonesState {
        let logs = (0..<foodLogDays).map { offset in
            makeLog(
                daysAgo: offset,
                protein: proteinGoalDays > offset ? 140 : 80,
                waterMl: waterHitsGoal ? 2_000 : 200,
                workoutCalories: workoutCalories
            )
        }

        let baseline = JourneyBaseline(
            startWeightKg: startWeight,
            startDate: calendar.date(byAdding: .day, value: -30, to: asOf) ?? asOf,
            currentWeightKg: currentWeight,
            goalWeightKg: goalWeight,
            goalDirection: direction,
            totalChangeKg: currentWeight - startWeight,
            remainingChangeKg: abs(currentWeight - goalWeight),
            progressPercent: progressPercent,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: foodLogDays > 0,
            usesSyntheticBaselinePoint: foodLogDays == 0,
            onboardingBaselineWeightKg: startWeight,
            chartPoints: [],
            showsWeightChart: true
        )

        let streaks = JourneyStreakState(
            currentLoggingStreakDays: min(foodLogDays, 7),
            longestLoggingStreakDays: foodLogDays,
            currentProteinStreakDays: 0,
            currentWaterStreakDays: 0,
            currentTrainingStreakWeeks: nil,
            isTodayLogged: foodLogDays > 0,
            heroStreakChip: .hidden,
            weeklyConsistencyHeadline: "",
            weeklyConsistencyDetail: nil,
            keepStreakAliveCopy: nil
        )

        return JourneyMilestonesBuilder.build(
            JourneyMilestonesBuilder.Input(
                baseline: baseline,
                maturityLogs: logs,
                journeyStreaks: streaks,
                healthWorkoutDayStarts: [],
                calendar: calendar
            )
        )
    }

    private func makeLog(
        daysAgo: Int,
        protein: Double,
        waterMl: Int = 2_000,
        workoutCalories: Int = 0
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(
                calories: 1_800,
                protein: protein,
                carbs: 120,
                fat: 50,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: workoutCalories,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }
}
