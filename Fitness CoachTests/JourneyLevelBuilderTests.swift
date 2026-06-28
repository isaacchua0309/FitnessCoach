//
//  JourneyLevelBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyLevelBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    // Wednesday, 15 Nov 2023
    private let asOf = Date(timeIntervalSince1970: 1_700_044_800)

    func testXPCalculationFromRealBehaviors() {
        let day = calendar.startOfDay(for: asOf)
        let logs = [
            makeLog(
                date: day,
                calories: 1_900,
                protein: 140,
                waterMl: 2_500
            )
        ]
        let weights = [
            makeWeight(date: day, kg: 80)
        ]
        let workouts: Set<Date> = [day]

        let state = build(
            maturityLogs: logs,
            allWeights: weights,
            healthWorkoutDayStarts: workouts,
            isAppleHealthConnected: true,
            unlockedMilestoneCount: 2
        )

        // food 10 + protein 10 + water 5 + calorie 10 + workout 15 + weight 10 + milestones 50
        XCTAssertEqual(JourneyLevelBuilder.dailyBehaviorXP(input: buildInput(
            maturityLogs: logs,
            healthWorkoutDayStarts: workouts,
            isAppleHealthConnected: true
        )), 50)
        XCTAssertEqual(JourneyLevelBuilder.weightXP(input: buildInput(
            maturityLogs: logs,
            allWeights: weights
        )), 10)
        XCTAssertEqual(JourneyLevelBuilder.milestoneXP(input: buildInput(unlockedMilestoneCount: 2)), 50)
        XCTAssertEqual(state.totalXP, 110)
        XCTAssertTrue(state.hasData)
    }

    func testDailyCapPreventsStackingBeyondFiftyPerDay() {
        let day = calendar.startOfDay(for: asOf)
        let logs = [
            makeLog(date: day, calories: 1_900, protein: 140, waterMl: 2_500)
        ]
        let workouts: Set<Date> = [day]

        let xp = JourneyLevelBuilder.dailyBehaviorXP(
            input: buildInput(
                maturityLogs: logs,
                healthWorkoutDayStarts: workouts,
                isAppleHealthConnected: true
            )
        )

        XCTAssertEqual(xp, 50)
    }

    func testWeightXPWeeklyCapCountsOneAwardPerWeek() {
        let weights = (0..<3).map { offset in
            makeWeight(
                date: calendar.date(byAdding: .day, value: -offset, to: asOf)!,
                kg: 80 - Double(offset) * 0.1
            )
        }

        let xp = JourneyLevelBuilder.weightXP(
            input: buildInput(allWeights: weights)
        )

        XCTAssertEqual(xp, 10)
    }

    func testLevelProgressionUsesDeterministicCurve() {
        XCTAssertEqual(JourneyLevelBuilder.xpRequiredToAdvance(fromLevel: 1), 150)
        XCTAssertEqual(JourneyLevelBuilder.xpRequiredToAdvance(fromLevel: 7), 450)

        let levelTwo = JourneyLevelBuilder.levelProgress(totalXP: 150)
        XCTAssertEqual(levelTwo.level, 2)
        XCTAssertEqual(levelTwo.xpInLevel, 0)
        XCTAssertEqual(levelTwo.xpRequired, 200)

        let levelSeven = JourneyLevelBuilder.levelProgress(totalXP: 1_650 + 350)
        XCTAssertEqual(levelSeven.level, 7)
        XCTAssertEqual(levelSeven.xpInLevel, 350)
        XCTAssertEqual(levelSeven.xpRequired, 450)
    }

    func testMilestoneBonusAddsTwentyFivePerUnlock() {
        let xp = JourneyLevelBuilder.milestoneXP(
            input: buildInput(unlockedMilestoneCount: 4)
        )

        XCTAssertEqual(xp, 100)
    }

    func testNoDataState() {
        let state = build(maturityLogs: [], allWeights: [])

        XCTAssertFalse(state.hasData)
        XCTAssertEqual(state.currentLevel, 1)
        XCTAssertEqual(state.currentXP, 0)
        XCTAssertEqual(state.totalXP, 0)
        XCTAssertEqual(state.xpEarnedExplanation, FormaProductCopy.Journey.Level.emptyBody)
    }

    func testIndividualXPRewardValues() {
        XCTAssertEqual(JourneyLevelBuilder.dailyBehaviorXP(input: buildInput(
            maturityLogs: [makeLog(date: calendar.startOfDay(for: asOf), calories: 500, protein: 60, waterMl: 100)]
        )), 10)

        XCTAssertEqual(JourneyLevelBuilder.milestoneXP(input: buildInput(unlockedMilestoneCount: 1)), 25)
    }

    func testHealthDisconnectedDoesNotAwardWorkoutXPButDoesNotPenalizeOtherXP() {
        let day = calendar.startOfDay(for: asOf)
        let logs = [makeLog(date: day, calories: 1_800, protein: 80, waterMl: 500)]
        let workouts: Set<Date> = [day]

        let disconnected = build(
            maturityLogs: logs,
            healthWorkoutDayStarts: workouts,
            isAppleHealthConnected: false
        )
        let connected = build(
            maturityLogs: logs,
            healthWorkoutDayStarts: workouts,
            isAppleHealthConnected: true
        )

        XCTAssertEqual(disconnected.totalXP, 20)
        XCTAssertEqual(connected.totalXP, 35)
        XCTAssertEqual(
            disconnected.levelTitle,
            FormaProductCopy.Journey.Level.title(for: disconnected.currentLevel)
        )
    }

    func testLevelSevenTitle() {
        let progress = JourneyLevelBuilder.levelProgress(totalXP: 2_000)
        XCTAssertEqual(progress.level, 7)
        XCTAssertEqual(progress.xpInLevel, 350)
        XCTAssertEqual(FormaProductCopy.Journey.Level.title(for: 7), "Consistency Master")

        let state = build(
            maturityLogs: logsForTotalXP(2_000),
            unlockedMilestoneCount: 0
        )

        XCTAssertEqual(state.currentLevel, 7)
        XCTAssertEqual(state.levelTitle, "Consistency Master")
        XCTAssertGreaterThanOrEqual(state.currentXP, 350)
        XCTAssertEqual(state.xpRequiredForNextLevel, 450)
    }

    func testRepeatedEditsOnSameDayDoNotMultiplyFoodXP() {
        let day = calendar.startOfDay(for: asOf)
        let older = makeLog(date: day, calories: 1_200, protein: 60, waterMl: 500)
        var newer = older
        newer.totals = MacroTotals(calories: 1_900, protein: 140, carbs: 100, fat: 40)
        newer.updatedAt = calendar.date(byAdding: .hour, value: 2, to: day)!

        let state = build(maturityLogs: [older, newer])

        let xp = JourneyLevelBuilder.dailyBehaviorXP(input: buildInput(maturityLogs: [older, newer]))
        XCTAssertEqual(xp, 30)
        XCTAssertEqual(state.totalXP, 30)
    }

    // MARK: - Helpers

    private func build(
        maturityLogs: [DailyLog],
        allWeights: [WeightEntry] = [],
        healthWorkoutDayStarts: Set<Date> = [],
        isAppleHealthConnected: Bool = false,
        unlockedMilestoneCount: Int = 0
    ) -> JourneyLevelState {
        JourneyLevelBuilder.build(
            buildInput(
                maturityLogs: maturityLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: healthWorkoutDayStarts,
                isAppleHealthConnected: isAppleHealthConnected,
                unlockedMilestoneCount: unlockedMilestoneCount
            )
        )
    }

    private func buildInput(
        maturityLogs: [DailyLog] = [],
        allWeights: [WeightEntry] = [],
        healthWorkoutDayStarts: Set<Date> = [],
        isAppleHealthConnected: Bool = false,
        unlockedMilestoneCount: Int = 0
    ) -> JourneyLevelBuilder.Input {
        JourneyLevelBuilder.Input(
            maturityLogs: maturityLogs,
            allWeights: allWeights,
            healthWorkoutDayStarts: healthWorkoutDayStarts,
            isAppleHealthConnected: isAppleHealthConnected,
            unlockedMilestoneCount: unlockedMilestoneCount,
            calendar: calendar
        )
    }

    private func logsForTotalXP(_ targetXP: Int) -> [DailyLog] {
        var logs: [DailyLog] = []
        var earned = 0
        var dayOffset = 0

        while earned < targetXP {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: asOf)!
            logs.append(makeLog(date: date, calories: 1_900, protein: 140, waterMl: 2_500))
            earned = JourneyLevelBuilder.computeTotalXP(
                input: buildInput(maturityLogs: logs)
            )
            dayOffset += 1
        }

        return logs
    }

    private func makeLog(
        date: Date,
        calories: Int,
        protein: Double,
        waterMl: Int
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 120,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2_000,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(calories: calories, protein: protein, carbs: 100, fat: 40),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
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
