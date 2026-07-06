//
//  CoachDailyStatusBuilderTests.swift
//  Fitness CoachTests
//
//  Timeline-aware deterministic daily status response tests.
//

import XCTest
@testable import Fitness_Coach

final class CoachDailyStatusBuilderTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        self.calendar = calendar

        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = 12
        referenceDate = calendar.date(from: components)!
    }

    func testNoLogsStatusEncouragesFirstMeal() {
        let log = makeLog()
        let message = CoachResponseBuilder.status(
            from: CoachDailyStatusSnapshot.make(log: log)
        )

        XCTAssertTrue(message.contains("0 / 1,800 kcal"))
        XCTAssertTrue(message.contains("1,800 kcal remaining"))
        XCTAssertTrue(message.contains("No meals logged yet today."))
        XCTAssertTrue(message.contains("Next: Log your first meal"))
    }

    func testMealsLoggedStatusIncludesLastMealAndRemainingMacros() {
        let log = makeLog(
            totals: MacroTotals(calories: 620, protein: 42, carbs: 55, fat: 18, fiber: nil, sodium: nil)
        )
        let foodEvent = timelineEvent(
            type: .foodLogged,
            status: .confirmed,
            summary: "Logged food: Chicken bowl",
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Chicken bowl",
                    calories: 620,
                    proteinGrams: 42,
                    carbsGrams: 55,
                    fatGrams: 18
                )
            )
        )
        let snapshot = CoachDailyStatusSnapshot.make(
            log: log,
            recentMeals: [
                CoachRecentMealContext(
                    name: "Chicken bowl",
                    calories: 620,
                    proteinGrams: 42,
                    loggedAt: referenceDate,
                    linkedEntryId: UUID()
                )
            ],
            timelineEvents: [contextEvent(from: foodEvent)]
        )

        let message = CoachResponseBuilder.status(from: snapshot)

        XCTAssertTrue(message.contains("620 / 1,800 kcal"))
        XCTAssertTrue(message.contains("1,180 kcal remaining"))
        XCTAssertTrue(message.contains("Last logged meal: Chicken bowl (620 kcal)"))
        XCTAssertTrue(message.contains("Next:"))
    }

    func testWaterLoggedStatusIncludesWaterRemaining() {
        let log = makeLog(waterConsumedMl: 1_800)
        let waterEvent = timelineEvent(
            type: .waterLogged,
            status: .confirmed,
            summary: "Logged 500ml water",
            payload: .waterLogged(WaterLoggedPayload(entryId: UUID(), amountMl: 500))
        )
        let message = CoachResponseBuilder.status(
            from: CoachDailyStatusSnapshot.make(
                log: log,
                timelineEvents: [contextEvent(from: waterEvent)]
            )
        )

        XCTAssertTrue(message.contains("1,800 / 2,400ml water"))
        XCTAssertTrue(message.contains("600ml remaining"))
        XCTAssertTrue(message.contains("Logged 500ml water"))
    }

    func testWorkoutDetectedStatusIncludesWorkoutLine() {
        let log = makeLog()
        let workoutEvent = timelineEvent(
            type: .workoutDetected,
            status: .confirmed,
            summary: "Workout detected: Run (35 min)",
            payload: .workoutDetected(
                WorkoutDetectedPayload(
                    workoutCount: 1,
                    totalDurationMinutes: 35,
                    totalActiveCalories: 320,
                    primaryWorkoutTitle: "Run",
                    demand: "moderate"
                )
            )
        )
        let training = DailyTrainingActivity(
            workouts: [
                HealthWorkoutRecord(
                    id: UUID(),
                    activityName: "Run",
                    startDate: referenceDate,
                    endDate: referenceDate.addingTimeInterval(2_100),
                    durationMinutes: 35,
                    activeCalories: 320
                )
            ]
        )
        let message = CoachResponseBuilder.status(
            from: CoachDailyStatusSnapshot.make(
                log: log,
                training: training,
                primaryWorkoutTitle: "Run",
                timelineEvents: [contextEvent(from: workoutEvent)]
            )
        )

        XCTAssertTrue(message.contains("Workout: Workout detected: Run (35 min)"))
        XCTAssertTrue(message.contains("Refuel with protein"))
    }

    func testStepsMissingDoesNotInventStepCount() {
        let log = makeLog()
        var missing = CoachMissingDataContext()
        missing.stepsUnavailable = true
        let message = CoachResponseBuilder.status(
            log,
            contextHints: CoachResponseContextHints(
                missingData: missing,
                steps: 9_120
            )
        )

        XCTAssertTrue(message.contains("Steps: unavailable"))
        XCTAssertFalse(message.contains("9,120"))
        XCTAssertFalse(message.matches(regex: #"\b\d{1,3}(,\d{3})*\s*steps\b"#))
    }

    func testPendingFoodEstimateExcludedFromConsumedStatus() {
        let log = makeLog()
        let pending = timelineEvent(
            type: .foodEstimateCreated,
            status: .pending,
            summary: "Estimate: Pizza",
            payload: .foodEstimate(
                FoodEstimatePayload(mealName: "Pizza", calories: 800, requiresConfirmation: true)
            )
        )
        let message = CoachResponseBuilder.status(
            from: CoachDailyStatusSnapshot.make(
                log: log,
                timelineEvents: [contextEvent(from: pending)]
            )
        )

        XCTAssertTrue(message.contains("No meals logged yet today."))
        XCTAssertFalse(message.contains("Pizza"))
        XCTAssertTrue(message.contains("0 / 1,800 kcal"))
    }

    func testRejectedFoodEstimateExcludedFromConsumedStatus() {
        let log = makeLog()
        let rejected = timelineEvent(
            type: .foodRejected,
            status: .rejected,
            summary: "Rejected estimate: Burger",
            payload: .foodEstimate(
                FoodEstimatePayload(mealName: "Burger", calories: 650, requiresConfirmation: true)
            )
        )
        let message = CoachResponseBuilder.status(
            from: CoachDailyStatusSnapshot.make(
                log: log,
                timelineEvents: [contextEvent(from: rejected)]
            )
        )

        XCTAssertTrue(message.contains("No meals logged yet today."))
        XCTAssertFalse(message.contains("Burger"))
        XCTAssertFalse(message.contains("650"))
    }

    func testLiveStepsIncludedWhenAvailable() {
        let log = makeLog()
        let message = CoachResponseBuilder.status(
            from: CoachDailyStatusSnapshot.make(
                log: log,
                steps: 8_450
            )
        )

        XCTAssertTrue(message.contains("Steps: 8,450"))
    }

    // MARK: Helpers

    private func makeLog(
        totals: MacroTotals = MacroTotals(
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: nil,
            sodium: nil
        ),
        waterConsumedMl: Int = 0
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: referenceDate,
            weightKg: nil,
            targets: ProfileFixtures.sampleTargets,
            totals: totals,
            waterConsumedMl: waterConsumedMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    private func timelineEvent(
        type: CoachTimelineEventType,
        status: CoachTimelineEventStatus,
        summary: String,
        payload: CoachTimelineEventPayload
    ) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: type,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: status,
            payload: payload,
            occurredAt: referenceDate,
            calendar: calendar
        )
    }

    private func contextEvent(from event: CoachTimelineEvent) -> CoachTimelineContextEvent {
        CoachTimelineContextEvent.from(
            event: event,
            summary: CoachTimelineEventSummaryBuilder.summary(for: event)
        )
    }
}

private extension String {
    func matches(regex pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}
