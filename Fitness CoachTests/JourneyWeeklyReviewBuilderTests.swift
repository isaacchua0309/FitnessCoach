//
//  JourneyWeeklyReviewBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyWeeklyReviewBuilderTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = ProfileTestFixtures.referenceDate

    // MARK: - Full / partial week

    func testFullWeekRowsUseCompactFractionCopy() {
        let review = enrich(makeBaseReview(
            foodLoggedDays: 7,
            proteinGoalDays: 6,
            waterGoalDays: 5,
            trainingDays: 4,
            expectedTrainingDays: 4,
            training: .connected(workoutDays: 4, averageCaloriesBurned: 300, averageTrainingDurationMinutes: 40),
            weightDeltaThisWeekKg: -0.6,
            calorieAdherenceDays: 6
        ))

        XCTAssertEqual(row(id: "food", in: review)?.value, "7/7 days")
        XCTAssertEqual(row(id: "protein", in: review)?.value, "6/7 days")
        XCTAssertEqual(row(id: "water", in: review)?.value, "5/7 days")
        XCTAssertEqual(row(id: "training", in: review)?.value, "4/4")
        XCTAssertEqual(row(id: "weight", in: review)?.value, "-0.6kg")
    }

    func testPartialWeekStillShowsNeutralFractions() {
        let review = enrich(makeBaseReview(
            foodLoggedDays: 3,
            proteinGoalDays: 2,
            waterGoalDays: 1,
            trainingDays: 1,
            expectedTrainingDays: 3,
            training: .connected(workoutDays: 1, averageCaloriesBurned: 200, averageTrainingDurationMinutes: 30),
            weightDeltaThisWeekKg: nil,
            calorieAdherenceDays: 2
        ))

        XCTAssertEqual(row(id: "food", in: review)?.value, "3/7 days")
        XCTAssertEqual(
            row(id: "weight", in: review)?.value,
            FormaProductCopy.Journey.WeeklyReview.weightUnavailable
        )
    }

    func testNoFoodLogsUsesEncouragingSummary() {
        let review = enrich(makeBaseReview(
            foodLoggedDays: 0,
            proteinGoalDays: 0,
            waterGoalDays: 0,
            trainingDays: 0,
            expectedTrainingDays: 3,
            training: .connectedEmpty,
            weightDeltaThisWeekKg: nil,
            calorieAdherenceDays: 0
        ))

        XCTAssertEqual(
            review.weekSummaryCopy,
            FormaProductCopy.Journey.WeeklyReview.noFoodLogsSummary
        )
    }

    // MARK: - Training

    func testAppleHealthDisconnectedShowsConnectCopy() {
        let review = enrich(makeBaseReview(
            foodLoggedDays: 4,
            proteinGoalDays: 3,
            waterGoalDays: 2,
            trainingDays: 0,
            expectedTrainingDays: 3,
            training: .locked,
            weightDeltaThisWeekKg: nil,
            calorieAdherenceDays: 3
        ))

        XCTAssertEqual(
            row(id: "training", in: review)?.value,
            FormaProductCopy.Journey.WeeklyReview.trainingConnectAppleHealth
        )
    }

    func testAppleHealthConnectedUsesGymGoalFraction() {
        let value = JourneyWeeklyReviewBuilder.trainingValue(
            for: .connected(
                workoutDays: 2,
                averageCaloriesBurned: 250,
                averageTrainingDurationMinutes: 35
            )
        )

        XCTAssertEqual(value, "2 days")
    }

    func testExpectedTrainingDaysUsesProfileFrequencyFirst() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.trainingFrequencyPerWeek = 4

        XCTAssertEqual(JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: profile), 4)
    }

    func testExpectedTrainingDaysFallsBackToActivityDefaults() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.trainingFrequencyPerWeek = 0
        profile.activityLevel = .moderatelyActive

        XCTAssertEqual(JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: profile), 3)
    }

    // MARK: - Weight delta

    func testLoseGoalWeightDeltaShowsNegativeChange() {
        let value = JourneyWeeklyReviewBuilder.formattedWeightDelta(
            -0.6,
            goalDirection: .lose
        )
        XCTAssertEqual(value, "-0.6kg")
    }

    func testGainGoalWeightDeltaShowsPositiveChange() {
        let value = JourneyWeeklyReviewBuilder.formattedWeightDelta(
            0.8,
            goalDirection: .gain
        )
        XCTAssertEqual(value, "+0.8kg")
    }

    func testMaintainGoalWeightDeltaShowsSignedMagnitude() {
        let value = JourneyWeeklyReviewBuilder.formattedWeightDelta(
            -0.3,
            goalDirection: .maintain
        )
        XCTAssertEqual(value, "-0.3kg")
    }

    // MARK: - Week over week

    func testWeekOverWeekDetailWhenPreviousWeekHasData() {
        let review = enrich(
            makeBaseReview(
                foodLoggedDays: 6,
                proteinGoalDays: 5,
                waterGoalDays: 4,
                trainingDays: 3,
                expectedTrainingDays: 3,
                training: .connected(workoutDays: 3, averageCaloriesBurned: 250, averageTrainingDurationMinutes: 35),
                weightDeltaThisWeekKg: -0.4,
                calorieAdherenceDays: 5
            ),
            previousWeek: JourneyWeeklyReviewPreviousWeek(
                foodLoggedDays: 4,
                proteinGoalDays: 3,
                waterGoalDays: 2,
                calorieAdherenceDays: 3,
                trainingDays: 2,
                weightDeltaKg: -0.2
            )
        )

        XCTAssertNotNil(review.weekOverWeekDetail)
        XCTAssertTrue(review.weekOverWeekDetail?.contains("last week") == true)
        XCTAssertTrue(review.weekOverWeekDetail?.contains("Food 6/7") == true)
    }

    func testWeekOverWeekDetailHiddenWithoutPreviousData() {
        let review = enrich(makeBaseReview(
            foodLoggedDays: 2,
            proteinGoalDays: 1,
            waterGoalDays: 0,
            trainingDays: 0,
            expectedTrainingDays: 3,
            training: .connectedEmpty,
            weightDeltaThisWeekKg: nil,
            calorieAdherenceDays: 1
        ))

        XCTAssertNil(review.weekOverWeekDetail)
    }

    // MARK: - Wins first

    func testRowsSortWinsFirst() {
        let review = enrich(makeBaseReview(
            foodLoggedDays: 7,
            proteinGoalDays: 2,
            waterGoalDays: 6,
            trainingDays: 4,
            expectedTrainingDays: 4,
            training: .connected(workoutDays: 4, averageCaloriesBurned: 300, averageTrainingDurationMinutes: 40),
            weightDeltaThisWeekKg: -0.5,
            calorieAdherenceDays: 5
        ))

        XCTAssertEqual(review.rows.first?.id, "food")
        XCTAssertTrue(review.rows.first?.winScore ?? 0 >= review.rows.last?.winScore ?? 0)
    }

    // MARK: - Dashboard integration

    func testDashboardWeeklyReviewUsesValidWeightDelta() {
        let dayOne = asOf
        let dayTwo = calendar.date(byAdding: .day, value: 2, to: asOf)!
        let weights = [
            WeightEntry(id: UUID(), date: dayOne, weightKg: 90, note: nil, createdAt: dayOne),
            WeightEntry(id: UUID(), date: dayTwo, weightKg: 89.4, note: nil, createdAt: dayTwo)
        ]
        let logs = [makeLog(daysAgo: 0, calories: 1_800, protein: 150)]

        let context = makeContext(weekLogs: logs, allWeights: weights)
        let review = JourneyDashboardBuilder.weeklyReview(context: context)

        XCTAssertEqual(review.weightDeltaThisWeekKg ?? 0, -0.6, accuracy: 0.01)
        XCTAssertFalse(review.rows.isEmpty)
    }

    // MARK: - Helpers

    private func enrich(
        _ review: JourneyWeeklyReviewState,
        previousWeek: JourneyWeeklyReviewPreviousWeek? = nil
    ) -> JourneyWeeklyReviewState {
        JourneyWeeklyReviewBuilder.enrich(
            review: review,
            previousWeek: previousWeek,
            goalDirection: .lose
        )
    }

    private func makeBaseReview(
        foodLoggedDays: Int,
        proteinGoalDays: Int,
        waterGoalDays: Int,
        trainingDays: Int,
        expectedTrainingDays: Int,
        training: JourneyWeeklyTrainingStatus,
        weightDeltaThisWeekKg: Double?,
        calorieAdherenceDays: Int
    ) -> JourneyWeeklyReviewState {
        JourneyWeeklyReviewState(
            foodLoggedDays: foodLoggedDays,
            foodLoggedDaysTotal: 7,
            proteinGoalDays: proteinGoalDays,
            proteinGoalDaysTotal: 7,
            waterGoalDays: waterGoalDays,
            waterGoalDaysTotal: 7,
            trainingDays: trainingDays,
            expectedTrainingDays: expectedTrainingDays,
            training: training,
            weightDeltaThisWeekKg: weightDeltaThisWeekKg,
            calorieAdherenceDays: calorieAdherenceDays,
            calorieAdherenceDaysTotal: 7,
            strongestPositiveSignal: "Food logging",
            weakestSignal: "Water",
            weekSummaryCopy: JourneyWeeklyReviewBuilder.weekSummaryCopy(
                foodDays: foodLoggedDays,
                proteinDays: proteinGoalDays,
                trainingDays: trainingDays,
                goalDirection: .lose,
                weightDelta: weightDeltaThisWeekKg
            ),
            averageCalorieDeficit: nil,
            rows: [],
            weekOverWeekDetail: nil
        )
    }

    private func row(id: String, in review: JourneyWeeklyReviewState) -> JourneyWeeklyReviewRow? {
        review.rows.first { $0.id == id }
    }

    private func makeContext(
        weekLogs: [DailyLog],
        allWeights: [WeightEntry]
    ) -> JourneyDashboardBuilder.Context {
        let baseline = JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: ProfileTestFixtures.sampleProfile,
                allWeights: allWeights,
                maturityLogs: weekLogs,
                goalProjection: nil,
                asOf: asOf,
                calendar: calendar
            )
        )

        return JourneyDashboardBuilder.Context(
            profile: ProfileTestFixtures.sampleProfile,
            baseline: baseline,
            maturityLogs: weekLogs,
            weekLogs: weekLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            monthLogs: weekLogs,
            rangeLogs: weekLogs,
            allWeights: allWeights,
            weekWeights: allWeights,
            rangeWeights: allWeights,
            streakSummary: StreakSummary(
                loggingStreak: 1,
                proteinStreak: 1,
                hydrationStreak: 0,
                workoutStreak: 0
            ),
            weeklyTraining: .connectedEmpty,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: allWeights.last?.weightKg,
                changeKg: JourneyLogMetrics.weightDelta(in: allWeights),
                direction: .decreasing,
                hasSuddenSpike: false
            ),
            goalProjection: nil,
            healthWorkoutDayStarts: [],
            monthHealthWorkoutCount: 0,
            weekHealthWorkoutCount: 0,
            loggedDays: weekLogs.count,
            nutritionSummary: ProgressLogSummaryBuilder.nutritionSummary(from: weekLogs),
            waterSummary: ProgressLogSummaryBuilder.waterSummary(from: weekLogs),
            workoutSummary: nil,
            selectedRangeDays: 28,
            asOf: asOf,
            calendar: calendar
        )
    }

    private func makeLog(
        daysAgo: Int,
        calories: Int,
        protein: Double
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
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
}
