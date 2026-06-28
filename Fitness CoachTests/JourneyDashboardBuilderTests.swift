//
//  JourneyDashboardBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyDashboardBuilderTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = TrainingInsightsPreviewData.referenceNow

    func testWeeklyReviewCountsFoodAndProteinDays() {
        let logs = (0..<5).map { offset in
            makeLog(
                daysAgo: offset,
                calories: 1_800,
                protein: 150,
                proteinTarget: 150
            )
        }

        let context = makeContext(weekLogs: logs, maturityLogs: logs)
        let review = JourneyDashboardBuilder.weeklyReview(context: context)

        XCTAssertEqual(review.foodLoggedDays, 5)
        XCTAssertEqual(review.proteinGoalDays, 5)
        XCTAssertFalse(review.weekSummaryCopy.isEmpty)
    }

    func testMilestonesIncludeGoalDirectionAwareTitles() {
        let context = makeContext(
            baseline: JourneyBaseline(
                startWeightKg: 90,
                startDate: asOf,
                currentWeightKg: 88,
                goalWeightKg: 75,
                goalDirection: .lose,
                totalChangeKg: -2,
                remainingChangeKg: 13,
                progressPercent: 13,
                estimatedCompletionDate: nil,
                estimatedCompletionMonthLabel: nil,
                hasRealWeightEntries: true,
                usesSyntheticBaselinePoint: false,
                onboardingBaselineWeightKg: 90,
                chartPoints: [],
                showsWeightChart: true
            )
        )

        let milestones = JourneyDashboardBuilder.milestones(context: context)
        XCTAssertFalse(milestones.items.isEmpty)
        XCTAssertEqual(milestones.items.last?.title, "Goal")
        XCTAssertNotNil(milestones.next)
    }

    func testJourneyLevelXPIncreasesWithLoggedFoodDays() {
        let logs = (0..<3).map { makeLog(daysAgo: $0, calories: 500) }
        let emptyContext = makeContext(maturityLogs: [])
        let loggedContext = makeContext(maturityLogs: logs)

        let emptyLevel = JourneyDashboardBuilder.journeyLevel(context: emptyContext)
        let loggedLevel = JourneyDashboardBuilder.journeyLevel(context: loggedContext)

        XCTAssertGreaterThan(loggedLevel.currentXP, emptyLevel.currentXP)
        XCTAssertFalse(loggedLevel.xpEarnedExplanation.isEmpty)
    }

    func testDetailedAnalyticsShowsChartWithSingleLoggedWeightUsingSyntheticBaseline() {
        let logDate = calendar.date(byAdding: .day, value: 7, to: asOf)!
        let allWeights = [
            WeightEntry(id: UUID(), date: logDate, weightKg: 66, note: nil, createdAt: logDate)
        ]
        let context = makeContext(allWeights: allWeights)

        let analytics = JourneyDashboardBuilder.detailedAnalytics(
            context: context,
            weightInterpretation: "Need more data"
        )

        XCTAssertTrue(analytics.isCollapsedByDefault)
        XCTAssertTrue(analytics.showsWeightChart)
        XCTAssertGreaterThanOrEqual(analytics.weightChartPoints.count, 1)
        XCTAssertTrue(analytics.weightChartPoints.contains(where: \.isSynthetic))
    }

    // MARK: - Helpers

    private func makeContext(
        baseline: JourneyBaseline? = nil,
        weekLogs: [DailyLog] = [],
        maturityLogs: [DailyLog] = [],
        allWeights: [WeightEntry] = []
    ) -> JourneyDashboardBuilder.Context {
        let resolvedBaseline = baseline ?? JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: ProfileTestFixtures.sampleProfile,
                allWeights: allWeights,
                maturityLogs: maturityLogs,
                goalProjection: nil,
                asOf: asOf,
                calendar: calendar
            )
        )

        return JourneyDashboardBuilder.Context(
            profile: ProfileTestFixtures.sampleProfile,
            baseline: resolvedBaseline,
            maturityLogs: maturityLogs,
            weekLogs: weekLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            monthLogs: maturityLogs,
            rangeLogs: maturityLogs,
            allWeights: allWeights,
            weekWeights: allWeights,
            rangeWeights: allWeights,
            streakSummary: StreakSummary(
                loggingStreak: 2,
                proteinStreak: 1,
                hydrationStreak: 0,
                workoutStreak: 0
            ),
            weeklyTraining: .connectedEmpty,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: resolvedBaseline.currentWeightKg,
                changeKg: nil,
                direction: .insufficientData,
                hasSuddenSpike: false
            ),
            goalProjection: nil,
            healthWorkoutDayStarts: [],
            monthHealthWorkoutCount: 0,
            weekHealthWorkoutCount: 0,
            loggedDays: maturityLogs.count,
            nutritionSummary: ProgressLogSummaryBuilder.nutritionSummary(from: maturityLogs),
            waterSummary: ProgressLogSummaryBuilder.waterSummary(from: maturityLogs),
            workoutSummary: nil,
            selectedRangeDays: 28,
            asOf: asOf,
            calendar: calendar
        )
    }

    private func makeLog(
        daysAgo: Int,
        calories: Int,
        protein: Double = 0,
        proteinTarget: Double = 150
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: proteinTarget,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: calories,
                protein: protein,
                carbs: 0,
                fat: 0,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 0,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }
}
