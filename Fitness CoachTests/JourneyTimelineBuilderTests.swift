//
//  JourneyTimelineBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyTimelineBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }()

    private let asOf = ProfileFixtures.referenceDate

    func testTimelineCreatesStartedFormaForNewUser() {
        let state = build(foodLogDays: 0)

        XCTAssertNil(state.emptyStateMessage)
        XCTAssertTrue(state.displayEvents.contains(where: { $0.type == .onboardingStarted }))
        XCTAssertEqual(
            state.displayEvents.last(where: { $0.type == .onboardingStarted })?.title,
            FormaProductCopy.Journey.Timeline.startedForma
        )
        XCTAssertEqual(
            state.displayEvents.last(where: { $0.type == .onboardingStarted })?.subtitle,
            FormaProductCopy.Journey.Timeline.Reflection.startedForma
        )
    }

    func testFirstMealCreatesStoryEvent() {
        let mealDate = calendar.date(byAdding: .day, value: -2, to: asOf)!
        let logs = [makeLog(date: mealDate, calories: 1_800, protein: 80)]

        let state = build(maturityLogs: logs)

        let mealEvent = state.events.first { $0.type == .firstMealLogged }
        XCTAssertNotNil(mealEvent)
        XCTAssertEqual(mealEvent?.title, FormaProductCopy.Journey.Timeline.loggedFirstMeal)
        XCTAssertEqual(mealEvent?.subtitle, FormaProductCopy.Journey.Timeline.Reflection.loggedFirstMeal)
        XCTAssertEqual(
            calendar.startOfDay(for: mealEvent!.date),
            calendar.startOfDay(for: mealDate)
        )
    }

    func testFirstWorkoutCreatesStoryEvent() {
        let workoutDate = calendar.date(byAdding: .day, value: -1, to: asOf)!
        let logs = [
            makeLog(date: workoutDate, calories: 1_800, protein: 140, workoutCalories: 300)
        ]

        let state = build(maturityLogs: logs)

        let workoutEvent = state.events.first { $0.type == .firstWorkoutLogged }
        XCTAssertNotNil(workoutEvent)
        XCTAssertEqual(workoutEvent?.title, FormaProductCopy.Journey.Timeline.completedFirstWorkout)
        XCTAssertEqual(
            workoutEvent?.subtitle,
            FormaProductCopy.Journey.Timeline.Reflection.completedFirstWorkout
        )
    }

    func testFirstKgLostCreatesStoryEvent() {
        let startDate = calendar.date(byAdding: .day, value: -20, to: asOf)!
        let unlockDate = calendar.date(byAdding: .day, value: -8, to: asOf)!
        let weights = [
            makeWeight(date: startDate, kg: 90),
            makeWeight(date: unlockDate, kg: 88.5)
        ]
        let logs = (0..<10).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140)
        }

        let state = build(
            maturityLogs: logs,
            allWeights: weights,
            startWeight: 90,
            currentWeight: 88.5,
            goalWeight: 75,
            direction: .lose,
            progressPercent: 10
        )

        let firstKg = state.events.first { $0.type == .firstKgTowardGoal }
        XCTAssertNotNil(firstKg)
        XCTAssertEqual(firstKg?.title, FormaProductCopy.Journey.Timeline.lostFirstKilogram())
        XCTAssertEqual(firstKg?.subtitle, FormaProductCopy.Journey.Timeline.Reflection.lostFirstKg)
        XCTAssertEqual(
            calendar.startOfDay(for: firstKg!.date),
            calendar.startOfDay(for: unlockDate)
        )
    }

    func testNoDuplicateStoryEvents() {
        let logs = (0..<12).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140, waterMl: 2_500)
        }
        let weights = [
            makeWeight(daysAgo: 12, kg: 90),
            makeWeight(daysAgo: 4, kg: 88.5)
        ]

        let state = build(
            maturityLogs: logs,
            allWeights: weights,
            startWeight: 90,
            currentWeight: 88.5,
            goalWeight: 75,
            direction: .lose,
            progressPercent: 10
        )

        let ids = state.events.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testCuratedTimelineExcludesNoisyDailyEvents() {
        let logs = (1..<6).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 80)
        }

        let state = build(maturityLogs: logs)

        XCTAssertFalse(state.events.contains(where: { $0.type == .calorieGoalFiveDays }))
        XCTAssertFalse(state.events.contains(where: { $0.type == .proteinGoalFiveDays }))
        XCTAssertFalse(state.events.contains(where: { $0.type == .thirtyMealsLogged }))
        XCTAssertFalse(state.events.contains(where: { $0.type == .firstWaterLogged }))
    }

    func testStableOrderingIsNewestFirst() {
        let logs = (0..<12).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140, waterMl: 2_500)
        }
        let weights = [
            makeWeight(daysAgo: 12, kg: 90),
            makeWeight(daysAgo: 4, kg: 88.5)
        ]

        let state = build(
            maturityLogs: logs,
            allWeights: weights,
            startWeight: 90,
            currentWeight: 88.5,
            goalWeight: 75,
            direction: .lose,
            progressPercent: 10
        )

        let dates = state.events.map(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func testDisplayEventsAnchorStartedFormaAtBottom() {
        let logs = (0..<3).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140)
        }

        let state = build(maturityLogs: logs)

        XCTAssertTrue(state.displayEvents.contains(where: { $0.type == .onboardingStarted }))
        XCTAssertEqual(state.displayEvents.last?.type, .onboardingStarted)
    }

    func testFirstWeightEventUsesEarliestWeightDate() {
        let earlier = calendar.date(byAdding: .day, value: -5, to: asOf)!
        let later = calendar.date(byAdding: .day, value: -1, to: asOf)!
        let weights = [
            makeWeight(date: later, kg: 88),
            makeWeight(date: earlier, kg: 90)
        ]

        let state = build(allWeights: weights)

        let weightEvent = state.events.first { $0.type == .firstWeightLogged }
        XCTAssertNotNil(weightEvent)
        XCTAssertEqual(
            calendar.startOfDay(for: weightEvent!.date),
            calendar.startOfDay(for: earlier)
        )
        XCTAssertEqual(
            weightEvent?.subtitle,
            FormaProductCopy.Journey.Timeline.Reflection.loggedFirstWeight
        )
    }

    // MARK: - Helpers

    private func build(
        foodLogDays: Int = 0,
        maturityLogs: [DailyLog]? = nil,
        allWeights: [WeightEntry] = [],
        startWeight: Double = 90,
        currentWeight: Double = 90,
        goalWeight: Double = 75,
        direction: JourneyGoalDirection = .lose,
        progressPercent: Double = 0
    ) -> JourneyStoryTimelineState {
        let logs = maturityLogs ?? (0..<foodLogDays).map {
            makeLog(daysAgo: $0, calories: 1_800, protein: 140)
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
            hasRealWeightEntries: !allWeights.isEmpty,
            usesSyntheticBaselinePoint: allWeights.isEmpty,
            onboardingBaselineWeightKg: startWeight,
            chartPoints: [],
            showsWeightChart: true
        )

        return JourneyTimelineBuilder.build(
            JourneyTimelineBuilder.Input(
                profile: ProfileFixtures.sampleProfile,
                baseline: baseline,
                maturityLogs: logs,
                allWeights: allWeights,
                healthWorkoutDayStarts: [],
                isAppleHealthConnected: false,
                unlockedMilestoneCount: 0,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func makeLog(
        daysAgo: Int,
        calories: Int,
        protein: Double,
        waterMl: Int = 2_000,
        workoutCalories: Int = 0
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return makeLog(
            date: date,
            calories: calories,
            protein: protein,
            waterMl: waterMl,
            workoutCalories: workoutCalories
        )
    }

    private func makeLog(
        date: Date,
        calories: Int,
        protein: Double,
        waterMl: Int = 2_000,
        workoutCalories: Int = 0
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: ProfileFixtures.sampleTargets,
            totals: MacroTotals(
                calories: calories,
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

    private func makeWeight(daysAgo: Int, kg: Double) -> WeightEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return makeWeight(date: date, kg: kg)
    }

    private func makeWeight(date: Date, kg: Double) -> WeightEntry {
        WeightEntry(
            id: UUID(),
            date: date,
            weightKg: kg,
            note: nil,
            createdAt: date
        )
    }
}
