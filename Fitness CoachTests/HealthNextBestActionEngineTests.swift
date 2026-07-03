import XCTest
@testable import Fitness_Coach

final class HealthNextBestActionEngineTests: XCTestCase {
    private var engine: HealthNextBestActionEngine!
    private var calendar: Calendar!
    private var targetDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.engine = HealthNextBestActionEngine()
        self.targetDate = makeDate(2026, 7, 3)
    }

    // MARK: - 1. Post-workout + protein remaining

    func testPostWorkoutProteinRemaining() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 14),
            nutritionProgress: makeNutritionProgress(proteinRemaining: 45),
            workoutSummary: makeWorkoutSummary(demand: .high, hydrationAdviceMl: 700)
        )

        let action = engine.evaluate(input)

        XCTAssertEqual(action.destination, .logMeal)
        XCTAssertEqual(action.ctaTitle, "Log meal")
        XCTAssertEqual(action.priority, 1)
        XCTAssertEqual(action.reason, .postWorkoutRecovery)
        XCTAssertNotNil(action.expiresAt)
    }

    // MARK: - 2. Post-workout + protein already hit

    func testPostWorkoutProteinAlreadyHit() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 14),
            nutritionProgress: makeNutritionProgress(
                proteinConsumed: 145,
                proteinTarget: 150,
                proteinRemaining: 5
            ),
            workoutSummary: makeWorkoutSummary(demand: .high, hydrationAdviceMl: 0)
        )

        let action = engine.evaluate(input)

        XCTAssertNotEqual(action.reason, .postWorkoutRecovery)
    }

    // MARK: - 3. Hydration behind

    func testHydrationBehind() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 14),
            nutritionProgress: makeNutritionProgress(
                waterConsumed: 800,
                waterTarget: 2_500,
                waterRemaining: 1_200
            ),
            workoutSummary: makeWorkoutSummary(hasWorkout: false, demand: .low),
            recoverySummary: makeRecoverySummary(status: .ready)
        )

        let action = engine.evaluate(input)

        XCTAssertEqual(action.destination, .addWater)
        XCTAssertEqual(action.ctaTitle, "Add water")
        XCTAssertEqual(action.reason, .hydration)
        XCTAssertNotNil(action.expiresAt)
    }

    // MARK: - 4. Low recovery

    func testLowRecovery() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 9),
            nutritionProgress: makeNutritionProgress(
                waterConsumed: 2_300,
                waterTarget: 2_500,
                waterRemaining: 200
            ),
            workoutSummary: makeWorkoutSummary(hasWorkout: false, demand: .low),
            recoverySummary: makeRecoverySummary(status: .low)
        )

        let action = engine.evaluate(input)

        XCTAssertEqual(action.destination, .askCoach)
        XCTAssertEqual(action.ctaTitle, "Ask Coach")
        XCTAssertEqual(action.reason, .lowRecovery)
    }

    // MARK: - 5. No meal logged

    func testNoMealLoggedLateMorning() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 12),
            nutritionProgress: makeNutritionProgress(caloriesConsumed: 0),
            workoutSummary: makeWorkoutSummary(hasWorkout: false, demand: .low),
            recoverySummary: makeRecoverySummary(status: .ready)
        )

        let action = engine.evaluate(input)

        XCTAssertEqual(action.destination, .logMeal)
        XCTAssertEqual(action.reason, .noMealLogged)
        XCTAssertNotNil(action.expiresAt)
    }

    // MARK: - 6. Low steps late day

    func testLowStepsLateDay() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 17),
            nutritionProgress: makeNutritionProgress(
                caloriesConsumed: 1_200,
                waterConsumed: 2_300,
                waterTarget: 2_500,
                waterRemaining: 200
            ),
            workoutSummary: makeWorkoutSummary(hasWorkout: false, demand: .low),
            recoverySummary: makeRecoverySummary(status: .ready),
            activitySummary: ActivitySummary(steps: 2_000, activeEnergyKcal: 120, exerciseMinutes: 10)
        )

        let action = engine.evaluate(input)

        XCTAssertEqual(action.reason, .stepEncouragement)
        XCTAssertTrue(action.destination == .askCoach || action.destination == .none)
    }

    // MARK: - 7. Missing weight

    func testMissingWeight() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 9),
            nutritionProgress: makeNutritionProgress(
                caloriesConsumed: 500,
                waterConsumed: 2_300,
                waterTarget: 2_500,
                waterRemaining: 200
            ),
            workoutSummary: makeWorkoutSummary(hasWorkout: false, demand: .low),
            recoverySummary: makeRecoverySummary(status: .ready),
            activitySummary: ActivitySummary(steps: 6_000, activeEnergyKcal: 250, exerciseMinutes: 30),
            hasLoggedWeightRecently: false
        )

        let action = engine.evaluate(input)

        XCTAssertEqual(action.destination, .logWeight)
        XCTAssertEqual(action.reason, .missingWeight)
    }

    // MARK: - 8. Default action

    func testDefaultAction() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 9),
            nutritionProgress: makeNutritionProgress(
                caloriesConsumed: 800,
                proteinConsumed: 140,
                proteinTarget: 150,
                proteinRemaining: 10,
                waterConsumed: 2_300,
                waterTarget: 2_500,
                waterRemaining: 200
            ),
            workoutSummary: makeWorkoutSummary(hasWorkout: false, demand: .low),
            recoverySummary: makeRecoverySummary(status: .ready),
            activitySummary: ActivitySummary(steps: 7_000, activeEnergyKcal: 300, exerciseMinutes: 35),
            hasLoggedWeightRecently: true
        )

        let action = engine.evaluate(input)

        XCTAssertEqual(action.title, "Stay on plan")
        XCTAssertEqual(action.reason, .stayOnPlan)
        XCTAssertTrue(action.destination == .askCoach || action.destination == .none)
    }

    // MARK: - 9. Priority conflict resolution

    func testPriorityConflictResolution() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 14),
            nutritionProgress: makeNutritionProgress(
                caloriesConsumed: 0,
                proteinRemaining: 40,
                waterConsumed: 500,
                waterTarget: 2_500,
                waterRemaining: 1_500
            ),
            workoutSummary: makeWorkoutSummary(demand: .high, hydrationAdviceMl: 800),
            recoverySummary: makeRecoverySummary(status: .low),
            hasLoggedWeightRecently: false
        )

        let action = engine.evaluate(input)

        XCTAssertEqual(action.reason, .postWorkoutRecovery)
        XCTAssertEqual(action.priority, 1)
    }

    // MARK: - Determinism

    func testDeterministicOutput() {
        let input = makeInput(
            timeOfDay: makeDate(2026, 7, 3, hour: 14),
            nutritionProgress: makeNutritionProgress(proteinRemaining: 30),
            workoutSummary: makeWorkoutSummary(demand: .moderate)
        )

        let first = engine.evaluate(input)
        let second = engine.evaluate(input)

        XCTAssertEqual(first, second)
    }

    // MARK: - Helpers

    private func makeInput(
        timeOfDay: Date,
        nutritionProgress: AdaptiveNutritionProgress = makeNutritionProgress(),
        userPlan: AdaptiveNutritionUserPlan = AdaptiveNutritionUserPlan(
            calorieTarget: 2_200,
            proteinTargetGrams: 150,
            waterTargetMl: 2_500
        ),
        recoverySummary: RecoverySummary = makeRecoverySummary(),
        workoutSummary: WorkoutSummary = makeWorkoutSummary(),
        activitySummary: ActivitySummary = ActivitySummary(
            steps: 5_000,
            activeEnergyKcal: 200,
            exerciseMinutes: 20
        ),
        adaptiveNutritionSummary: AdaptiveNutritionSummary = .none,
        trainingLoadSummary: TrainingLoadSummary = .unknown,
        hasLoggedWeightRecently: Bool = true
    ) -> NextBestActionEngineInput {
        NextBestActionEngineInput(
            targetDate: targetDate,
            timeOfDay: timeOfDay,
            nutritionProgress: nutritionProgress,
            userPlan: userPlan,
            recoverySummary: recoverySummary,
            workoutSummary: workoutSummary,
            activitySummary: activitySummary,
            adaptiveNutritionSummary: adaptiveNutritionSummary,
            trainingLoadSummary: trainingLoadSummary,
            hasLoggedWeightRecently: hasLoggedWeightRecently,
            calendar: calendar
        )
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }

    private static func makeNutritionProgress(
        caloriesConsumed: Int = 1_000,
        proteinConsumed: Double = 100,
        proteinTarget: Double = 150,
        proteinRemaining: Double = 50,
        waterConsumed: Int = 1_700,
        waterTarget: Int = 2_500,
        waterRemaining: Int = 800
    ) -> AdaptiveNutritionProgress {
        AdaptiveNutritionProgress(
            proteinConsumedGrams: proteinConsumed,
            proteinTargetGrams: proteinTarget,
            proteinRemainingGrams: proteinRemaining,
            caloriesConsumed: caloriesConsumed,
            calorieTarget: 2_200,
            calorieRemaining: max(0, 2_200 - caloriesConsumed),
            waterConsumedMl: waterConsumed,
            waterTargetMl: waterTarget,
            waterRemainingMl: waterRemaining
        )
    }

    private static func makeWorkoutSummary(
        hasWorkout: Bool = true,
        demand: WorkoutDemand = .moderate,
        hydrationAdviceMl: Int = 500
    ) -> WorkoutSummary {
        WorkoutSummary(
            hasWorkout: hasWorkout,
            primaryWorkoutType: hasWorkout ? .strength : nil,
            title: hasWorkout ? "Strength training" : "Rest day so far",
            workoutCount: hasWorkout ? 1 : 0,
            totalDurationMinutes: hasWorkout ? 45 : 0,
            totalActiveCalories: hasWorkout ? 300 : nil,
            intensity: demand == .high ? .high : .moderate,
            demand: demand,
            latestWorkoutStart: nil,
            latestWorkoutEnd: nil,
            nutritionAdvice: "Add protein after training.",
            hydrationAdviceMl: hydrationAdviceMl,
            explanation: "Test workout",
            confidence: .high,
            sourceSummary: "Test"
        )
    }

    private static func makeRecoverySummary(status: RecoveryStatus = .moderate) -> RecoverySummary {
        RecoverySummary(
            score: status == .low ? 35 : (status == .ready ? 80 : 60),
            status: status,
            title: "Recovery",
            explanation: "Test recovery",
            recommendedTraining: "Train as planned",
            recommendedNutrition: "Stay on plan",
            confidence: .high,
            contributingFactors: [],
            missingSignals: []
        )
    }
}
