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

    private let asOf = ProfileTestFixtures.referenceDate

    func testEmptyLogsWithProfileShowsStartedFormaAndEmptyMessage() {
        let state = build(foodLogDays: 0)

        XCTAssertEqual(state.emptyStateMessage, FormaProductCopy.Journey.Timeline.emptyBody)
        XCTAssertTrue(state.displayEvents.contains(where: { $0.type == .onboardingStarted }))
        XCTAssertEqual(
            state.displayEvents.last(where: { $0.type == .onboardingStarted })?.title,
            FormaProductCopy.Journey.Timeline.startedForma
        )
    }

    func testFirstMealEventUsesLoggedDateAndTitle() {
        let mealDate = calendar.date(byAdding: .day, value: -2, to: asOf)!
        let logs = [
            makeLog(date: mealDate, calories: 1_800, protein: 80)
        ]

        let state = build(maturityLogs: logs)

        let mealEvent = state.events.first { $0.type == .firstMealLogged }
        XCTAssertNotNil(mealEvent)
        XCTAssertEqual(mealEvent?.title, FormaProductCopy.Journey.Timeline.loggedFirstMeal)
        XCTAssertEqual(
            calendar.startOfDay(for: mealEvent!.date),
            calendar.startOfDay(for: mealDate)
        )
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
    }

    func testMilestoneDerivedFirstKgEventForLoseGoal() {
        let startDate = calendar.date(byAdding: .day, value: -20, to: asOf)!
        let unlockDate = calendar.date(byAdding: .day, value: -8, to: asOf)!
        let weights = [
            makeWeight(date: startDate, kg: 90),
            makeWeight(date: unlockDate, kg: 88.5)
        ]
        let logs = (0..<10).map { offset in
            makeLog(
                daysAgo: offset,
                calories: 1_800,
                protein: 140
            )
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
        XCTAssertEqual(
            calendar.startOfDay(for: firstKg!.date),
            calendar.startOfDay(for: unlockDate)
        )
    }

    func testDedupesEventsOnSameDayKeepingHigherPriority() {
        let sameDay = calendar.date(byAdding: .day, value: -3, to: asOf)!
        let logs = [makeLog(date: sameDay, calories: 1_800, protein: 80)]

        let state = build(maturityLogs: logs)

        let day = calendar.startOfDay(for: sameDay)
        let eventsOnDay = state.events.filter {
            calendar.isDate($0.date, inSameDayAs: day)
        }
        XCTAssertEqual(eventsOnDay.count, 1)
        XCTAssertEqual(eventsOnDay.first?.type, .firstMealLogged)
    }

    func testStableOrderingIsNewestFirst() {
        let logs = (0..<12).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140)
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

    func testDisplayEventsIncludeStartedFormaAnchorWhenTimelineIsShort() {
        let logs = (0..<3).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140)
        }

        let state = build(maturityLogs: logs)

        XCTAssertLessThanOrEqual(state.displayEvents.count, 5)
        XCTAssertTrue(state.displayEvents.contains(where: { $0.type == .onboardingStarted }))
        XCTAssertEqual(state.displayEvents.last?.type, .onboardingStarted)
    }

    func testDateFormattingUsesAbbreviatedMonthAndDay() {
        let mealDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 18))!
        let logs = [makeLog(date: mealDate, calories: 1_800, protein: 80)]

        let state = build(maturityLogs: logs)
        let mealEvent = state.events.first { $0.type == .firstMealLogged }

        XCTAssertNotNil(mealEvent)
        XCTAssertEqual(ProgressFormatter.timelineDayLabel(mealEvent!.date, calendar: calendar), "Jun 18")
    }

    func testCalorieGoalFiveDaysEventAppears() {
        // Offset logs from onboarding day so the fifth adherence day is not deduped against it.
        let logs = (1..<6).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 80)
        }

        XCTAssertEqual(JourneyLogMetrics.calorieAdherenceDays(in: logs), 5)

        let state = build(maturityLogs: logs)

        XCTAssertTrue(state.events.contains(where: { $0.type == .calorieGoalFiveDays }))
    }

    func testMilestoneDerivedEventAppearsInTimeline() {
        let logs = (0..<12).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140)
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

        XCTAssertTrue(state.events.contains(where: { $0.type == .firstKgTowardGoal }))
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

        let streaks = JourneyStreakState(
            currentLoggingStreakDays: min(logs.count, 7),
            longestLoggingStreakDays: logs.count,
            currentProteinStreakDays: 0,
            currentWaterStreakDays: 0,
            currentTrainingStreakWeeks: nil,
            isTodayLogged: !logs.isEmpty,
            heroStreakChip: .hidden,
            weeklyConsistencyHeadline: "",
            weeklyConsistencyDetail: nil,
            keepStreakAliveCopy: nil
        )

        return JourneyTimelineBuilder.build(
            JourneyTimelineBuilder.Input(
                profile: ProfileTestFixtures.sampleProfile,
                baseline: baseline,
                maturityLogs: logs,
                allWeights: allWeights,
                healthWorkoutDayStarts: [],
                isAppleHealthConnected: false,
                journeyStreaks: streaks,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func makeLog(
        daysAgo: Int,
        calories: Int,
        protein: Double
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return makeLog(date: date, calories: calories, protein: protein)
    }

    private func makeLog(date: Date, calories: Int, protein: Double) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(
                calories: calories,
                protein: protein,
                carbs: 120,
                fat: 50,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 2_000,
            steps: nil,
            workoutCaloriesBurned: 0,
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
