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
                currentWeightKg: 88.5,
                goalWeightKg: 75,
                goalDirection: .lose,
                totalChangeKg: -1.5,
                remainingChangeKg: 13.5,
                progressPercent: 10,
                estimatedCompletionDate: nil,
                estimatedCompletionMonthLabel: nil,
                hasRealWeightEntries: true,
                usesSyntheticBaselinePoint: false,
                onboardingBaselineWeightKg: 90,
                chartPoints: [],
                showsWeightChart: true
            ),
            maturityLogs: (0..<10).map { makeLog(daysAgo: $0, calories: 1_800, protein: 150) }
        )

        let milestones = JourneyDashboardBuilder.milestones(context: context)
        XCTAssertFalse(milestones.items.isEmpty)
        XCTAssertEqual(
            milestones.items.first(where: { $0.id == "first-kg" })?.title,
            FormaProductCopy.Journey.Milestones.NextAchievement.firstKgTitle
        )
        XCTAssertNotNil(milestones.next)
    }

    func testStoryTimelineBuildsFromLoggedHistory() {
        let logs = (0..<5).map { makeLog(daysAgo: $0, calories: 1_800, protein: 150) }
        let context = makeContext(maturityLogs: logs)
        let timeline = JourneyDashboardBuilder.storyTimeline(context: context)

        XCTAssertFalse(timeline.displayEvents.isEmpty)
    }

    // MARK: - Helpers

    private func makeContext(
        profile: UserProfile? = ProfileTestFixtures.sampleProfile,
        baseline: JourneyBaseline? = nil,
        weekLogs: [DailyLog] = [],
        maturityLogs: [DailyLog] = [],
        allWeights: [WeightEntry] = []
    ) -> JourneyDashboardBuilder.Context {
        let resolvedBaseline = baseline ?? JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: profile,
                allWeights: allWeights,
                maturityLogs: maturityLogs,
                goalProjection: nil,
                asOf: asOf,
                calendar: calendar
            )
        )

        return JourneyDashboardBuilder.Context(
            profile: profile,
            baseline: resolvedBaseline,
            maturityLogs: maturityLogs,
            monthLogs: weekLogs,
            weekLogs: weekLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            allWeights: allWeights,
            weekWeights: allWeights,
            journeyStreaks: JourneyStreakBuilder.build(
                JourneyStreakBuilder.Input(
                    streakSummary: StreakSummary(
                        loggingStreak: 2,
                        mealLoggingStreak: 2,
                        checkInStreak: 2,
                        proteinStreak: 1,
                        hydrationStreak: 0,
                        workoutStreak: 0
                    ),
                    maturityLogs: maturityLogs,
                    workoutDates: [],
                    isAppleHealthConnected: false,
                    asOf: asOf,
                    calendar: calendar
                )
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
