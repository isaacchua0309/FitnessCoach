//
//  PlanWeekStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanWeekStateTests: XCTestCase {

    private let calendar = Calendar.current
    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    func testNoLogsShowsEmptyState() {
        let week = PlanMissionControlFixtures.newUserDashboard.week

        XCTAssertTrue(week.showsEmptyState)
        XCTAssertEqual(week.emptyStateCopy, FormaProductCopy.PlanMissionControl.weekEmptyState)
        XCTAssertEqual(week.overallStatusCopy, FormaProductCopy.PlanMissionControl.weekEmptyState)
        XCTAssertFalse(week.hasWeeklyData)
        XCTAssertEqual(week.overallHeadline, "This week")
    }

    func testPartialWeekShowsAdherenceLines() {
        let week = PlanMissionControlFixtures.activeUserDashboard.week

        XCTAssertFalse(week.showsEmptyState)
        XCTAssertTrue(week.hasWeeklyData)
        XCTAssertEqual(week.calorieAdherence.achieved, 5)
        XCTAssertEqual(week.caloriesLine, "Calories: 5 / 7 days")
        XCTAssertEqual(week.trainingLine, "Training: 2 / 3 sessions")
        XCTAssertFalse(week.accessibilitySummary.isEmpty)
    }

    func testCompleteWeekShowsStrongOverallCopy() {
        let week = PlanMissionControlFixtures.dashboard(
            for: PlanMissionControlFixtures.loseProfile,
            weekLogs: completeWeekLogs,
            weekWeights: completeWeekWeights,
            allWeights: completeWeekWeights,
            weeklyTraining: .connected(
                workoutDays: 3,
                averageCaloriesBurned: 350,
                averageTrainingDurationMinutes: 50
            ),
            integrationState: .connected
        ).week

        XCTAssertEqual(week.overallStatus, .strong)
        XCTAssertEqual(week.overallStatusCopy, "Strong week so far.")
        XCTAssertEqual(week.trainingLine, "Training: 3 / 3 sessions")
        XCTAssertEqual(week.weightLine, "Weight: -0.4 kg")
    }

    func testOverCalorieDaysDoNotCountTowardAdherence() {
        let targets = PlanMissionControlFixtures.loseProfile.targets
        let log = DailyLog(
            id: UUID(),
            date: referenceDate,
            weightKg: nil,
            targets: targets,
            totals: MacroTotals(
                calories: 3200,
                protein: 180,
                carbs: 200,
                fat: 60,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 3200,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let week = PlanMissionControlFixtures.dashboard(
            for: PlanMissionControlFixtures.loseProfile,
            weekLogs: [log]
        ).week

        XCTAssertEqual(week.calorieAdherence.achieved, 0)
        XCTAssertEqual(week.caloriesLine, "Calories: 0 / 7 days")
    }

    func testTrainingTargetUnavailableWhenNoSessionsPlanned() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.trainingFrequencyPerWeek = 0

        let week = PlanMissionControlFixtures.dashboard(
            for: profile,
            weekLogs: makePartialLogs(count: 2)
        ).week

        XCTAssertEqual(
            week.trainingLine,
            FormaProductCopy.PlanMissionControl.weekTrainingUnavailable
        )
    }

    func testTrainingLockedShowsConnectHealthCopy() {
        let week = PlanMissionControlFixtures.dashboard(
            for: PlanMissionControlFixtures.loseProfile,
            weekLogs: makePartialLogs(count: 2),
            weeklyTraining: .locked
        ).week

        XCTAssertEqual(
            week.trainingLine,
            FormaProductCopy.PlanMissionControl.weekTrainingConnectHealth
        )
    }

    private var completeWeekLogs: [DailyLog] {
        let targets = PlanMissionControlFixtures.loseProfile.targets
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: referenceDate)!
            return DailyLog(
                id: UUID(),
                date: date,
                weightKg: nil,
                targets: targets,
                totals: MacroTotals(
                    calories: targets.calorieTarget,
                    protein: targets.proteinTarget,
                    carbs: targets.carbTarget,
                    fat: targets.fatTarget,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: targets.waterTargetMl,
                steps: nil,
                workoutCaloriesBurned: 0,
                dailyReviewId: nil,
                createdAt: date,
                updatedAt: date
            )
        }
    }

    private var completeWeekWeights: [WeightEntry] {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: referenceDate)!
        return [
            WeightEntry(
                id: UUID(),
                date: weekStart,
                weightKg: 90.4,
                note: nil,
                createdAt: weekStart
            ),
            WeightEntry(
                id: UUID(),
                date: referenceDate,
                weightKg: 90.0,
                note: nil,
                createdAt: referenceDate
            )
        ]
    }

    private func makePartialLogs(count: Int) -> [DailyLog] {
        let targets = PlanMissionControlFixtures.loseProfile.targets
        return (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: referenceDate)!
            return DailyLog(
                id: UUID(),
                date: date,
                weightKg: nil,
                targets: targets,
                totals: MacroTotals(
                    calories: targets.calorieTarget,
                    protein: targets.proteinTarget,
                    carbs: targets.carbTarget,
                    fat: targets.fatTarget,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: targets.waterTargetMl,
                steps: nil,
                workoutCaloriesBurned: 0,
                dailyReviewId: nil,
                createdAt: date,
                updatedAt: date
            )
        }
    }
}
