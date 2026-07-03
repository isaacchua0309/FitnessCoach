//
//  JourneyPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Presentation section assembly for Journey dashboard scenarios.
//

import XCTest
@testable import Fitness_Coach

final class JourneyPresentationBuilderTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = TrainingInsightsPreviewData.referenceNow

    func testNewUserWithNoLogsUsesIntentionalEmptyStates() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertTrue(dashboard.transformation.isVisible)
        XCTAssertFalse(dashboard.momentum.isVisible)
        XCTAssertEqual(dashboard.momentum.emptyMessage, FormaProductCopy.Journey.Momentum.buildingHeadline)
        XCTAssertFalse(dashboard.insight.isUnlocked)
        XCTAssertTrue(dashboard.insight.showsLearningState)
        XCTAssertEqual(
            dashboard.insight.learningTitle,
            FormaProductCopy.Journey.PersonalizedInsights.learningTitle
        )
        XCTAssertEqual(
            dashboard.insight.learningDetail,
            FormaProductCopy.Journey.PersonalizedInsights.learningDetail
        )
        XCTAssertFalse(dashboard.chapter.isVisible)
        XCTAssertFalse(dashboard.monthlyRecap.isVisible)
        XCTAssertTrue(dashboard.milestone.isVisible)
        XCTAssertFalse(dashboard.weeklyHabit.showsHabitRows)
        XCTAssertEqual(
            dashboard.weeklyHabit.emptyMessage,
            FormaProductCopy.Journey.WeeklyReview.emptyState
        )
        XCTAssertTrue(dashboard.showsStartingEmptyState)
        XCTAssertFalse(dashboard.showsStoryTimelineSection)
        XCTAssertFalse(dashboard.showsGoalProjectionSection)
        XCTAssertFalse(dashboard.showsMonthlyRecapSection)
        XCTAssertFalse(dashboard.showsChapterSection)
    }

    func testHabitLogsWithoutWeightLossStillBuildsWeeklyHabits() {
        let dashboard = JourneyPreviewData.weekOne

        XCTAssertTrue(dashboard.weeklyHabit.isVisible)
        XCTAssertGreaterThan(dashboard.weeklyReview.foodLoggedDays, 0)
        XCTAssertEqual(dashboard.transformation.variant, .earlyHabits)
    }

    func testLosingWeightShowsTransformationHeadlineAndMomentum() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertEqual(dashboard.transformation.variant, .weightLossProgress)
        XCTAssertTrue(dashboard.transformation.primaryMessage.localizedCaseInsensitiveContains("lost"))
        XCTAssertTrue(dashboard.momentum.isVisible)
        XCTAssertGreaterThan(dashboard.momentum.streakDays, 0)
        XCTAssertTrue(dashboard.milestone.isVisible)
    }

    func testGainingWeightUsesPositiveFraming() {
        let dashboard = JourneyPreviewData.gainGoal

        XCTAssertNotEqual(dashboard.transformation.variant, .weightLossProgress)
        XCTAssertFalse(dashboard.transformation.primaryMessage.contains("0 kg"))
        XCTAssertEqual(dashboard.baseline.goalDirection, .gain)
    }

    func testNearGoalUserWithEnoughDataShowsGoalProjection() {
        let dashboard = JourneyPreviewData.nearGoal

        XCTAssertTrue(dashboard.goalProjection.isVisible)
        if case .towardGoal(let title, let detail) = dashboard.goalProjection.status {
            XCTAssertEqual(title, FormaProductCopy.Journey.GoalProjection.towardGoalTitle)
            XCTAssertTrue(detail.contains("around"))
        } else {
            XCTFail("Expected toward-goal projection for near-goal fixture")
        }
    }

    func testStrongMomentumUnlocksMilestonesAndInsights() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertFalse(dashboard.milestones.unlocked.isEmpty)
        XCTAssertTrue(dashboard.insight.isUnlocked)
        XCTAssertFalse(dashboard.insight.insights.isEmpty)
        XCTAssertLessThanOrEqual(dashboard.insight.insights.count, 3)
        XCTAssertTrue(dashboard.chapter.isVisible)
        XCTAssertGreaterThan(dashboard.chapter.totalXP, 0)
    }

    func testSparseDataShowsInsufficientProjectionAndLockedInsights() {
        let dashboard = JourneyPreviewData.sparseData

        XCTAssertTrue(dashboard.goalProjection.isVisible)
        if case .insufficientData(let title, let detail) = dashboard.goalProjection.status {
            XCTAssertEqual(title, FormaProductCopy.Journey.GoalProjection.insufficientTitle)
            XCTAssertEqual(detail, FormaProductCopy.Journey.GoalProjection.insufficientDetail)
        } else {
            XCTFail("Expected insufficient projection for sparse weight data")
        }
        XCTAssertFalse(dashboard.insight.isUnlocked)
    }

    func testStoryEventsCarryPresentationCopy() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertFalse(dashboard.storyEvents.isEmpty)
        XCTAssertFalse(dashboard.storyEvents[0].dayLabel.isEmpty)
        XCTAssertFalse(dashboard.storyEvents[0].title.isEmpty)
        XCTAssertEqual(
            dashboard.storyEvents.map(\.timelineEvent),
            dashboard.storyTimeline.displayEvents
        )
    }

    func testPresentationBuilderProducesAllSectionsFromContext() {
        let logs = (0..<5).map { makeLog(daysAgo: $0, calories: 1_800, protein: 150) }
        let weights = [
            makeWeight(daysAgo: 20, kg: 90),
            makeWeight(daysAgo: 10, kg: 88),
            makeWeight(daysAgo: 0, kg: 86.5)
        ]
        let context = makeContext(
            weekLogs: logs,
            maturityLogs: logs,
            allWeights: weights,
            goalProjection: ProgressProjectionCalculator.projection(
                weights: weights,
                goalWeightKg: 75,
                asOf: asOf
            )
        )

        let dashboard = JourneyPresentationBuilder.buildDashboard(
            hasProfile: true,
            context: context,
            loggedDays: 5
        )

        XCTAssertTrue(dashboard.transformation.isVisible)
        XCTAssertTrue(dashboard.weeklyHabit.isVisible)
        XCTAssertTrue(dashboard.milestone.isVisible)
        XCTAssertTrue(dashboard.goalProjection.isVisible)
        XCTAssertTrue(dashboard.monthlyRecap.isVisible)
    }

    // MARK: - Helpers

    private func makeContext(
        profile: UserProfile? = ProfileTestFixtures.sampleProfile,
        weekLogs: [DailyLog],
        maturityLogs: [DailyLog],
        allWeights: [WeightEntry],
        goalProjection: ProgressProjection?
    ) -> JourneyDashboardBuilder.Context {
        let baseline = JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: profile,
                allWeights: allWeights,
                maturityLogs: maturityLogs,
                goalProjection: goalProjection,
                asOf: asOf,
                calendar: calendar
            )
        )

        return JourneyDashboardBuilder.Context(
            profile: profile,
            baseline: baseline,
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
                        loggingStreak: 3,
                        proteinStreak: 2,
                        hydrationStreak: 1,
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
                latestWeightKg: baseline.currentWeightKg,
                changeKg: baseline.totalChangeKg,
                direction: .decreasing,
                hasSuddenSpike: false
            ),
            goalProjection: goalProjection,
            healthWorkoutDayStarts: [],
            monthHealthWorkoutCount: 0,
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
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 150,
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

    private func makeWeight(daysAgo: Int, kg: Double) -> WeightEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return WeightEntry(
            id: UUID(),
            date: date,
            weightKg: kg,
            note: nil,
            createdAt: date
        )
    }
}
