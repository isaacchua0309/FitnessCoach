//
//  WeeklyReviewEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class WeeklyReviewEngineTests: XCTestCase {

    private var calendar: Calendar!
    private var engine: WeeklyReviewEngine!
    private var weekStart: Date!
    private var weekEnd: Date!
    private var generatedAt: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.engine = WeeklyReviewEngine()
        self.weekStart = makeDate(2026, 7, 1)
        self.weekEnd = makeDate(2026, 7, 7)
        self.generatedAt = makeDate(2026, 7, 7, hour: 18)
    }

    func testStrongWeek() {
        let review = evaluate(
            dailyMetrics: weekMetrics(steps: 8_500),
            workouts: [
                makeWorkout(day: 1),
                makeWorkout(day: 3),
                makeWorkout(day: 5),
                makeWorkout(day: 7)
            ],
            recoverySummaries: weekRecovery(statuses: Array(repeating: .ready, count: 7), score: 78),
            nutritionDailySummaries: weekNutrition(
                days: 7,
                proteinHit: true,
                calorieHit: true,
                waterHit: true
            ),
            weightRecords: [
                makeWeight(day: 1, kg: 80.0),
                makeWeight(day: 7, kg: 79.7)
            ],
            userPlan: defaultPlan(goal: .loseFat)
        )

        XCTAssertEqual(review?.title, "Strong week")
        XCTAssertEqual(review?.confidence, .high)
        XCTAssertGreaterThanOrEqual(review?.wins.count ?? 0, 3)
        XCTAssertEqual(review?.stats.totalWorkouts, 4)
        XCTAssertEqual(review?.stats.proteinHitDays, 7)
        XCTAssertEqual(review?.stats.loggingConsistencyDays, 7)
    }

    func testNoWorkouts() {
        let review = evaluate(
            dailyMetrics: weekMetrics(steps: 6_000),
            workouts: [],
            nutritionDailySummaries: weekNutrition(days: 5, proteinHit: true, calorieHit: true)
        )

        XCTAssertEqual(review?.stats.totalWorkouts, 0)
        XCTAssertTrue(review?.risks.contains(where: { $0.contains("No workouts") }) == true)
        XCTAssertTrue(review?.nextWeekFocus.contains("Schedule 2–3 training sessions.") == true)
        XCTAssertTrue(review?.missingSignals.contains(.workouts) == true)
    }

    func testProteinInconsistent() {
        let nutrition = (0..<7).map { offset in
            makeNutrition(
                dayOffset: offset,
                proteinConsumed: offset < 2 ? 140 : 80,
                proteinTarget: 150,
                caloriesConsumed: 2_000,
                calorieTarget: 2_200,
                didLogFood: true
            )
        }

        let review = evaluate(
            dailyMetrics: weekMetrics(steps: 7_000),
            workouts: [makeWorkout(day: 2), makeWorkout(day: 5)],
            nutritionDailySummaries: nutrition
        )

        XCTAssertLessThanOrEqual(review?.stats.proteinHitDays ?? 0, 2)
        XCTAssertTrue(review?.risks.contains(where: { $0.contains("Protein was below target") }) == true)
        XCTAssertTrue(review?.nextWeekFocus.contains("Anchor protein at breakfast and lunch.") == true)
    }

    func testCaloriesInconsistent() {
        let nutrition = (0..<7).map { offset in
            makeNutrition(
                dayOffset: offset,
                proteinConsumed: 140,
                proteinTarget: 150,
                caloriesConsumed: offset < 3 ? 2_100 : 1_400,
                calorieTarget: 2_200,
                didLogFood: true
            )
        }

        let review = evaluate(
            dailyMetrics: weekMetrics(steps: 7_000),
            workouts: [makeWorkout(day: 2)],
            nutritionDailySummaries: nutrition
        )

        XCTAssertLessThanOrEqual(review?.stats.calorieTargetHitDays ?? 0, 3)
        XCTAssertTrue(review?.risks.contains(where: { $0.contains("Calorie intake varied") }) == true)
    }

    func testWeightDownAlignedWithFatLoss() {
        let review = evaluate(
            dailyMetrics: weekMetrics(steps: 7_500),
            workouts: [makeWorkout(day: 2), makeWorkout(day: 4), makeWorkout(day: 6)],
            nutritionDailySummaries: weekNutrition(days: 6, proteinHit: true, calorieHit: true),
            weightRecords: [
                makeWeight(day: 1, kg: 82.0),
                makeWeight(day: 7, kg: 81.2)
            ],
            userPlan: defaultPlan(goal: .loseFat)
        )

        XCTAssertLessThan(review?.stats.weightChangeKg ?? 0, 0)
        XCTAssertTrue(
            review?.wins.contains(where: { $0.contains("fat-loss goal") }) == true
        )
    }

    func testLowRecoveryRepeated() {
        let review = evaluate(
            dailyMetrics: weekMetrics(steps: 6_500),
            workouts: [makeWorkout(day: 1), makeWorkout(day: 3)],
            recoverySummaries: weekRecovery(
                statuses: [.low, .low, .moderate, .low, .ready, .moderate, .ready],
                score: 50
            ),
            nutritionDailySummaries: weekNutrition(days: 5, proteinHit: true, calorieHit: true)
        )

        XCTAssertGreaterThanOrEqual(review?.stats.lowRecoveryDays ?? 0, 3)
        XCTAssertTrue(review?.risks.contains(where: { $0.contains("Recovery was low") }) == true)
        XCTAssertTrue(review?.nextWeekFocus.contains("Prioritize sleep and lighter training when needed.") == true)
    }

    func testSparseData() {
        let review = evaluate(
            dailyMetrics: [
                DailyHealthMetrics(
                    date: makeDate(2026, 7, 3),
                    steps: 4_000,
                    activeEnergyKcal: 200,
                    exerciseMinutes: 20
                )
            ],
            workouts: [],
            recoverySummaries: [],
            nutritionDailySummaries: [],
            weightRecords: []
        )

        XCTAssertNotNil(review)
        XCTAssertEqual(review?.confidence, .low)
        XCTAssertEqual(review?.title, "Getting started")
        XCTAssertTrue(review?.missingSignals.contains(.nutrition) == true)
        XCTAssertTrue(review?.missingSignals.contains(.weight) == true)
    }

    func testMissingWeight() {
        let review = evaluate(
            dailyMetrics: weekMetrics(steps: 7_000),
            workouts: [makeWorkout(day: 2)],
            nutritionDailySummaries: weekNutrition(days: 6, proteinHit: true, calorieHit: true),
            weightRecords: []
        )

        XCTAssertNil(review?.stats.weightChangeKg)
        XCTAssertTrue(review?.missingSignals.contains(.weight) == true)
        XCTAssertTrue(review?.risks.contains(where: { $0.contains("Not enough weigh-ins") }) == true)
    }

    func testMissingNutrition() {
        let review = evaluate(
            dailyMetrics: weekMetrics(steps: 7_000),
            workouts: [makeWorkout(day: 2)],
            nutritionDailySummaries: []
        )

        XCTAssertTrue(review?.missingSignals.contains(.nutrition) == true)
        XCTAssertEqual(review?.stats.loggingConsistencyDays, 0)
        XCTAssertFalse(review?.risks.contains(where: { $0.contains("Protein was below target") }) == true)
    }

    func testFocusItemLimitMaxThree() {
        let review = evaluate(
            dailyMetrics: weekMetrics(steps: 2_000),
            workouts: [],
            recoverySummaries: weekRecovery(
                statuses: Array(repeating: .low, count: 7),
                score: 40
            ),
            nutritionDailySummaries: (0..<7).map { offset in
                makeNutrition(
                    dayOffset: offset,
                    proteinConsumed: 60,
                    proteinTarget: 150,
                    caloriesConsumed: 1_200,
                    calorieTarget: 2_200,
                    didLogFood: true
                )
            },
            weightRecords: []
        )

        XCTAssertLessThanOrEqual(review?.nextWeekFocus.count ?? 0, 3)
        XCTAssertGreaterThanOrEqual(review?.nextWeekFocus.count ?? 0, 1)
    }

    func testDeterministicOutput() {
        let input = makeInput(
            dailyMetrics: weekMetrics(steps: 7_500),
            workouts: [makeWorkout(day: 2), makeWorkout(day: 5)],
            recoverySummaries: [],
            nutritionDailySummaries: weekNutrition(days: 6, proteinHit: true, calorieHit: true),
            weightRecords: [],
            userPlan: defaultPlan()
        )

        let first = try! engine.evaluate(input)
        let second = try! engine.evaluate(input)

        XCTAssertEqual(first, second)
    }

    // MARK: - Helpers

    private func evaluate(
        dailyMetrics: [DailyHealthMetrics],
        workouts: [NormalizedWorkout] = [],
        recoverySummaries: [DailyRecoverySummary] = [],
        nutritionDailySummaries: [WeeklyNutritionDailySummary] = [],
        weightRecords: [NormalizedBodyMass] = [],
        userPlan: WeeklyReviewUserPlan? = nil
    ) -> WeeklyHealthReview? {
        try! engine.evaluate(
            makeInput(
                dailyMetrics: dailyMetrics,
                workouts: workouts,
                recoverySummaries: recoverySummaries,
                nutritionDailySummaries: nutritionDailySummaries,
                weightRecords: weightRecords,
                userPlan: userPlan ?? defaultPlan()
            )
        )
    }

    private func makeInput(
        dailyMetrics: [DailyHealthMetrics],
        workouts: [NormalizedWorkout],
        recoverySummaries: [DailyRecoverySummary],
        nutritionDailySummaries: [WeeklyNutritionDailySummary],
        weightRecords: [NormalizedBodyMass],
        userPlan: WeeklyReviewUserPlan
    ) -> WeeklyReviewEngineInput {
        WeeklyReviewEngineInput(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            dailyMetrics: dailyMetrics,
            workouts: workouts,
            recoverySummaries: recoverySummaries,
            nutritionDailySummaries: nutritionDailySummaries,
            weightRecords: weightRecords,
            userPlan: userPlan,
            calendar: calendar,
            generatedAt: generatedAt
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func weekMetrics(steps: Int) -> [DailyHealthMetrics] {
        (0..<7).map { offset in
            DailyHealthMetrics(
                date: calendar.date(byAdding: .day, value: offset, to: weekStart)!,
                steps: steps,
                activeEnergyKcal: 350,
                exerciseMinutes: 35
            )
        }
    }

    private func makeWorkout(day: Int) -> NormalizedWorkout {
        let start = makeDate(2026, 7, day, hour: 8)
        return NormalizedWorkout(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", day))!,
            category: .strength,
            activityLabel: "Strength training",
            startDate: start,
            endDate: calendar.date(byAdding: .minute, value: 45, to: start) ?? start,
            durationMinutes: 45,
            activeEnergyKcal: 280,
            sourceName: "Apple Watch"
        )
    }

    private func makeWeight(day: Int, kg: Double) -> NormalizedBodyMass {
        NormalizedBodyMass(
            id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", day))!,
            date: makeDate(2026, 7, day, hour: 7),
            valueKg: kg
        )
    }

    private func makeNutrition(
        dayOffset: Int,
        proteinConsumed: Double,
        proteinTarget: Double,
        caloriesConsumed: Int,
        calorieTarget: Int,
        didLogFood: Bool,
        waterConsumed: Int = 2_300,
        waterTarget: Int = 2_500
    ) -> WeeklyNutritionDailySummary {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
        return WeeklyNutritionDailySummary(
            date: date,
            caloriesConsumed: caloriesConsumed,
            calorieTarget: calorieTarget,
            proteinConsumedGrams: proteinConsumed,
            proteinTargetGrams: proteinTarget,
            waterConsumedMl: waterConsumed,
            waterTargetMl: waterTarget,
            didLogFood: didLogFood
        )
    }

    private func weekNutrition(
        days: Int,
        proteinHit: Bool,
        calorieHit: Bool = false,
        waterHit: Bool = false
    ) -> [WeeklyNutritionDailySummary] {
        (0..<days).map { offset in
            makeNutrition(
                dayOffset: offset,
                proteinConsumed: proteinHit ? 150 : 90,
                proteinTarget: 150,
                caloriesConsumed: calorieHit ? 2_150 : 1_600,
                calorieTarget: 2_200,
                didLogFood: true,
                waterConsumed: waterHit ? 2_400 : 1_500,
                waterTarget: 2_500
            )
        }
    }

    private func weekRecovery(
        statuses: [RecoveryStatus],
        score: Int
    ) -> [DailyRecoverySummary] {
        statuses.enumerated().map { index, status in
            DailyRecoverySummary(
                date: calendar.date(byAdding: .day, value: index, to: weekStart)!,
                summary: RecoverySummary(
                    score: score,
                    status: status,
                    title: "Recovery",
                    explanation: "Test",
                    recommendedTraining: "Train as planned",
                    recommendedNutrition: "Stay on plan",
                    confidence: .moderate,
                    contributingFactors: [],
                    missingSignals: status == .unknown ? [.sleep, .hrv] : []
                )
            )
        }
    }

    private func defaultPlan(goal: PlanGoalType = .maintain) -> WeeklyReviewUserPlan {
        WeeklyReviewUserPlan(
            goal: goal,
            calorieTarget: 2_200,
            proteinTargetGrams: 150,
            waterTargetMl: 2_500
        )
    }
}
