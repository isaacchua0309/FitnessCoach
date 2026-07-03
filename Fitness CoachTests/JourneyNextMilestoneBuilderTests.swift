//
//  JourneyNextMilestoneBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyNextMilestoneBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }()

    private let asOf = ProfileTestFixtures.referenceDate

    func testNewUserShowsFirstMealMilestone() {
        let result = build(foodLogDays: 0)

        XCTAssertTrue(result.presentation.isVisible)
        XCTAssertEqual(result.presentation.header, FormaProductCopy.Journey.Milestones.NextAchievement.header)
        XCTAssertEqual(result.presentation.title, FormaProductCopy.Journey.Milestones.NextAchievement.firstMealTitle)
        XCTAssertEqual(result.presentation.progressText, "0 / 1 meals")
        XCTAssertEqual(result.presentation.progressFraction, 0, accuracy: 0.001)
        XCTAssertEqual(result.legacyMilestones.next?.id, "first-meal")
        XCTAssertTrue(result.completedTimelineEvents.isEmpty)
    }

    func testAfterFirstMealNextMilestoneIsFirstFullDay() {
        let result = build(foodLogDays: 1, waterGoalDays: 0)

        XCTAssertTrue(result.legacyMilestones.unlocked.contains(where: { $0.id == "first-meal" }))
        XCTAssertEqual(result.presentation.title, FormaProductCopy.Journey.Milestones.NextAchievement.firstFullDayTitle)
        XCTAssertEqual(result.legacyMilestones.next?.id, "first-full-day")
        XCTAssertTrue(result.completedTimelineEvents.contains(where: { $0.id == "first-meal" }))
    }

    func testAfterWorkoutNextMilestoneIsWeightLogging() {
        let logs = [
            makeLog(daysAgo: 1, protein: 150, waterMl: 2_500, workoutCalories: 300),
            makeLog(daysAgo: 0, protein: 150, waterMl: 2_500, workoutCalories: 0)
        ]

        let result = build(
            maturityLogs: logs,
            weights: [
                makeWeight(daysAgo: 1, kg: 90),
                makeWeight(daysAgo: 0, kg: 89.8)
            ],
            startWeight: 90,
            currentWeight: 89.8
        )

        XCTAssertTrue(result.legacyMilestones.unlocked.contains(where: { $0.id == "first-meal" }))
        XCTAssertTrue(result.legacyMilestones.unlocked.contains(where: { $0.id == "first-full-day" }))
        XCTAssertTrue(result.legacyMilestones.unlocked.contains(where: { $0.id == "first-workout" }))
        XCTAssertEqual(result.presentation.title, FormaProductCopy.Journey.Milestones.NextAchievement.weightThreeTimesTitle)
        XCTAssertEqual(result.legacyMilestones.next?.id, "weight-three-times")
    }

    func testAfterFirstKgLostNextMilestoneIsFourWorkoutWeeks() {
        let logs = (0..<7).map { offset in
            makeLog(
                daysAgo: offset,
                protein: 150,
                waterMl: 2_500,
                workoutCalories: offset == 0 ? 300 : 0
            )
        }
        let weights = [
            makeWeight(daysAgo: 20, kg: 90),
            makeWeight(daysAgo: 10, kg: 89.2),
            makeWeight(daysAgo: 0, kg: 88.5)
        ]

        let result = build(
            maturityLogs: logs,
            weights: weights,
            startWeight: 90,
            currentWeight: 88.5,
            progressPercent: 12
        )

        XCTAssertTrue(result.legacyMilestones.unlocked.contains(where: { $0.id == "first-kg" }))
        XCTAssertEqual(result.presentation.title, FormaProductCopy.Journey.Milestones.NextAchievement.fourWorkoutWeeksTitle)
        XCTAssertEqual(result.legacyMilestones.next?.id, "four-workout-weeks")
    }

    func testCompletedMilestonesAppearAsStoryEvents() {
        let logs = (0..<3).map { offset in
            makeLog(daysAgo: offset, protein: 150, waterMl: 2_500)
        }

        let result = build(
            maturityLogs: logs,
            weights: [
                makeWeight(daysAgo: 2, kg: 90),
                makeWeight(daysAgo: 1, kg: 89.7),
                makeWeight(daysAgo: 0, kg: 89.4)
            ],
            startWeight: 90,
            currentWeight: 89.4
        )

        let completedIDs = Set(result.completedTimelineEvents.map(\.id))
        XCTAssertTrue(completedIDs.contains("first-meal"))
        XCTAssertTrue(completedIDs.contains("weight-three-times"))

        let timeline = JourneyDashboardBuilder.storyTimeline(
            context: makeContext(
                maturityLogs: logs,
                allWeights: [
                    makeWeight(daysAgo: 2, kg: 90),
                    makeWeight(daysAgo: 1, kg: 89.7),
                    makeWeight(daysAgo: 0, kg: 89.4)
                ],
                baseline: makeBaseline(startWeight: 90, currentWeight: 89.4)
            ),
            additionalEvents: result.completedTimelineEvents
        )

        XCTAssertTrue(timeline.events.contains(where: { $0.id == "first-meal" }))
        XCTAssertTrue(timeline.events.contains(where: { $0.id == "weight-three-times" }))
        XCTAssertFalse(result.legacyMilestones.upcoming.contains(where: { $0.status == .upcoming }))
    }

    // MARK: - Helpers

    private func build(
        foodLogDays: Int = 0,
        waterGoalDays: Int = 0,
        maturityLogs: [DailyLog]? = nil,
        weights: [WeightEntry] = [],
        startWeight: Double = 90,
        currentWeight: Double = 90,
        goalWeight: Double = 75,
        direction: JourneyGoalDirection = .lose,
        progressPercent: Double? = 0
    ) -> JourneyNextMilestoneBuilder.BuildResult {
        let logs = maturityLogs ?? (0..<foodLogDays).map { offset in
            makeLog(
                daysAgo: offset,
                protein: 80,
                waterMl: offset < waterGoalDays ? 2_500 : 200
            )
        }

        return JourneyNextMilestoneBuilder.build(
            JourneyNextMilestoneBuilder.Input(
                profile: ProfileTestFixtures.sampleProfile,
                baseline: makeBaseline(
                    startWeight: startWeight,
                    currentWeight: currentWeight,
                    goalWeight: goalWeight,
                    direction: direction,
                    progressPercent: progressPercent
                ),
                maturityLogs: logs,
                allWeights: weights,
                healthWorkoutDayStarts: [],
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func makeBaseline(
        startWeight: Double,
        currentWeight: Double,
        goalWeight: Double = 75,
        direction: JourneyGoalDirection = .lose,
        progressPercent: Double? = 0
    ) -> JourneyBaseline {
        JourneyBaseline(
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
            hasRealWeightEntries: true,
            usesSyntheticBaselinePoint: false,
            onboardingBaselineWeightKg: startWeight,
            chartPoints: [],
            showsWeightChart: true
        )
    }

    private func makeContext(
        maturityLogs: [DailyLog],
        allWeights: [WeightEntry],
        baseline: JourneyBaseline
    ) -> JourneyDashboardBuilder.Context {
        JourneyDashboardBuilder.Context(
            profile: ProfileTestFixtures.sampleProfile,
            baseline: baseline,
            maturityLogs: maturityLogs,
            monthLogs: maturityLogs,
            weekLogs: maturityLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            allWeights: allWeights,
            weekWeights: allWeights,
            journeyStreaks: JourneyStreakState(
                currentLoggingStreakDays: maturityLogs.count,
                longestLoggingStreakDays: maturityLogs.count,
                currentProteinStreakDays: 0,
                currentWaterStreakDays: 0,
                currentTrainingStreakWeeks: nil,
                isTodayLogged: !maturityLogs.isEmpty,
                heroStreakChip: .hidden,
                weeklyConsistencyHeadline: "",
                weeklyConsistencyDetail: nil,
                keepStreakAliveCopy: nil
            ),
            weeklyTraining: .connectedEmpty,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: baseline.currentWeightKg,
                changeKg: baseline.totalChangeKg,
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
        protein: Double,
        waterMl: Int = 2_500,
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
