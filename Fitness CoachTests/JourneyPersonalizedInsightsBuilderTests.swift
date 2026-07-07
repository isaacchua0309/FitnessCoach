//
//  JourneyPersonalizedInsightsBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyPersonalizedInsightsBuilderTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = TrainingInsightsPreviewData.referenceNow

    func testProteinInsightAppearsWhenProteinDataExists() {
        let weekLogs = (0..<4).map { offset in
            makeLog(
                daysAgo: offset,
                calories: 1_800,
                protein: 140,
                waterMl: 400
            )
        }

        let state = build(
            weekLogs: weekLogs,
            baseline: makeBaseline(direction: .lose)
        )

        XCTAssertFalse(state.showsLearningState)
        XCTAssertTrue(state.insights.contains { $0.type == .proteinConsistency })
        XCTAssertEqual(
            state.insights.first(where: { $0.type == .proteinConsistency })?.title,
            FormaProductCopy.Journey.PersonalizedInsights.proteinStrongestTitle
        )
    }

    func testWeightInsightAppearsWhenEnoughWeighInsExist() {
        let weekLogs = (0..<3).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 80, waterMl: 400)
        }
        let weights = [
            makeWeight(daysAgo: 14, kg: 90),
            makeWeight(daysAgo: 10, kg: 89.2),
            makeWeight(daysAgo: 6, kg: 88.4),
            makeWeight(daysAgo: 2, kg: 87.6),
            makeWeight(daysAgo: 0, kg: 87.0)
        ]

        let state = build(
            weekLogs: weekLogs,
            allWeights: weights,
            baseline: makeBaseline(direction: .lose, currentWeight: 87)
        )

        XCTAssertTrue(state.insights.contains { $0.type == .weightTrend })
        XCTAssertEqual(
            state.insights.first(where: { $0.type == .weightTrend })?.title,
            FormaProductCopy.Journey.PersonalizedInsights.weightTrendTowardTitle
        )
    }

    func testCalorieOpportunityAppearsWhenWeekendPatternExists() {
        let weekStarts = JourneyLogMetrics.rollingWeekDayStarts(asOf: asOf, calendar: calendar)
        let saturday = weekStarts.first { calendar.component(.weekday, from: $0) == 7 }!
        let sunday = weekStarts.first { calendar.component(.weekday, from: $0) == 1 }!
        let weekLogs = [
            makeLog(date: saturday, calories: 2_400, protein: 90, waterMl: 400),
            makeLog(date: sunday, calories: 2_350, protein: 85, waterMl: 400),
            makeLog(daysAgo: 3, calories: 1_800, protein: 80, waterMl: 400)
        ]

        let state = build(
            weekLogs: weekLogs,
            baseline: makeBaseline(direction: .lose)
        )

        XCTAssertTrue(state.insights.contains { $0.type == .calorieOpportunity })
        XCTAssertEqual(
            state.insights.first(where: { $0.type == .calorieOpportunity })?.title,
            FormaProductCopy.Journey.PersonalizedInsights.weekendCalorieTitle
        )
    }

    func testInsufficientDataFallbackAppears() {
        let state = build(weekLogs: [], allWeights: [])

        XCTAssertTrue(state.showsLearningState)
        XCTAssertTrue(state.insights.isEmpty)
        XCTAssertEqual(
            state.learningTitle,
            FormaProductCopy.Journey.PersonalizedInsights.learningTitle
        )
        XCTAssertEqual(
            state.learningDetail,
            FormaProductCopy.Journey.PersonalizedInsights.learningDetail
        )
        XCTAssertFalse(state.isUnlocked)
    }

    func testNoContradictoryInsightsShown() {
        let weekStarts = JourneyLogMetrics.rollingWeekDayStarts(asOf: asOf, calendar: calendar)
        let saturday = weekStarts.first { calendar.component(.weekday, from: $0) == 7 }!
        let sunday = weekStarts.first { calendar.component(.weekday, from: $0) == 1 }!
        let weekLogs = (0..<4).map { offset in
            makeLog(
                daysAgo: offset,
                calories: offset < 2 ? 2_400 : 1_800,
                protein: 140,
                waterMl: 400
            )
        } + [
            makeLog(date: saturday, calories: 2_400, protein: 140, waterMl: 400),
            makeLog(date: sunday, calories: 2_350, protein: 140, waterMl: 400)
        ]
        let weights = [
            makeWeight(daysAgo: 14, kg: 90),
            makeWeight(daysAgo: 10, kg: 89.2),
            makeWeight(daysAgo: 6, kg: 88.4),
            makeWeight(daysAgo: 2, kg: 87.6),
            makeWeight(daysAgo: 0, kg: 87.0)
        ]

        let state = build(
            weekLogs: weekLogs,
            allWeights: weights,
            baseline: makeBaseline(direction: .lose, currentWeight: 87)
        )

        XCTAssertLessThanOrEqual(state.insights.count, 3)

        let types = Set(state.insights.map(\.type))
        XCTAssertFalse(types.contains(.proteinConsistency) && types.contains(.bestHabit))
        XCTAssertFalse(types.contains(.calorieOpportunity) && types.contains(.biggestOpportunity))
    }

    // MARK: - Helpers

    private func build(
        weekLogs: [DailyLog],
        allWeights: [WeightEntry] = [],
        baseline: JourneyBaseline? = nil
    ) -> JourneyInsightState {
        JourneyPersonalizedInsightsBuilder.build(
            JourneyPersonalizedInsightsBuilder.Input(
                profile: ProfileFixtures.sampleProfile,
                baseline: baseline ?? makeBaseline(direction: .lose),
                weekLogs: weekLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: [],
                isAppleHealthConnected: false,
                expectedTrainingDaysPerWeek: 4,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func makeBaseline(
        direction: JourneyGoalDirection,
        currentWeight: Double = 88
    ) -> JourneyBaseline {
        JourneyBaseline(
            startWeightKg: 90,
            startDate: calendar.date(byAdding: .day, value: -30, to: asOf)!,
            currentWeightKg: currentWeight,
            goalWeightKg: 75,
            goalDirection: direction,
            totalChangeKg: currentWeight - 90,
            remainingChangeKg: abs(currentWeight - 75),
            progressPercent: 20,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: true,
            usesSyntheticBaselinePoint: false,
            onboardingBaselineWeightKg: 90,
            chartPoints: [],
            showsWeightChart: false
        )
    }

    private func makeLog(
        daysAgo: Int = 0,
        date: Date? = nil,
        calories: Int,
        protein: Double,
        waterMl: Int
    ) -> DailyLog {
        let resolvedDate = date ?? calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
            id: UUID(),
            date: resolvedDate,
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 1_800,
                proteinTarget: 130,
                carbTarget: 170,
                fatTarget: 55,
                waterTargetMl: 2_400,
                expectedWeeklyWeightLossKg: 0.34,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: calories,
                protein: protein,
                carbs: 155,
                fat: 55,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: resolvedDate,
            updatedAt: resolvedDate
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
