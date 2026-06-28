//
//  PlanNextMilestoneTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanNextMilestoneTests: XCTestCase {

    private let calendar = Calendar.current
    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    // MARK: - No weight data

    func testNoWeightDataPrefersLoggingMilestone() {
        let milestone = PlanMissionControlFixtures.loseDashboard.nextMilestone

        XCTAssertFalse(milestone.showsEmptyState)
        XCTAssertEqual(milestone.kind, .loggingConsistency)
        XCTAssertEqual(milestone.headline, "Complete 7 days of logging")
        XCTAssertTrue(milestone.showsJourneyCTA)
    }

    // MARK: - Weight progress

    func testWeightDataPrefersWeightCheckpointOverHabits() {
        let milestone = PlanMissionControlFixtures.activeUserDashboard.nextMilestone

        XCTAssertEqual(milestone.kind, .weightCheckpoint)
        XCTAssertTrue(milestone.headline.contains("to reach"))
        XCTAssertTrue(milestone.headline.hasPrefix("Lose"))
        XCTAssertNotNil(milestone.milestoneLabel)
    }

    func testWeightCheckpointHeadlineFormat() {
        let candidate = PlanNextMilestoneSelector.weightCandidate(
            context: weightContext(
                currentWeight: 88,
                goalWeight: 80,
                weights: [
                    WeightEntry(
                        id: UUID(),
                        date: referenceDate,
                        weightKg: 88,
                        note: nil,
                        createdAt: referenceDate
                    )
                ]
            ),
            baseline: JourneyBaseline(
                startWeightKg: 90,
                startDate: referenceDate,
                currentWeightKg: 88,
                goalWeightKg: 80,
                goalDirection: .lose,
                totalChangeKg: -2,
                remainingChangeKg: 8,
                progressPercent: 20,
                estimatedCompletionDate: nil,
                estimatedCompletionMonthLabel: nil,
                hasRealWeightEntries: true,
                usesSyntheticBaselinePoint: false,
                onboardingBaselineWeightKg: 90,
                chartPoints: [],
                showsWeightChart: true
            ),
            asOf: referenceDate
        )

        XCTAssertEqual(candidate?.headline, "Lose 3 kg to reach 85 kg")
    }

    func testWeightMilestoneWinsOverProteinWhenBothIncomplete() {
        let logs = lowProteinWeekLogs(days: 2)
        let weights = activeWeights(current: 89.6)

        let milestone = PlanMissionControlFixtures.dashboard(
            for: PlanMissionControlFixtures.loseProfile,
            weekLogs: logs,
            weekWeights: weights,
            allWeights: weights
        ).nextMilestone

        XCTAssertEqual(milestone.kind, .weightCheckpoint)
    }

    // MARK: - Protein adherence

    func testProteinMilestoneSelectedWhenWeightUnavailableAndProteinIncomplete() {
        // Logging wins over protein when the week still has open log days (priority 95 vs 60).
        let logs = lowProteinWeekLogs(days: 7)
        let milestone = PlanMissionControlFixtures.dashboard(
            for: PlanMissionControlFixtures.loseProfile,
            weekLogs: logs
        ).nextMilestone

        XCTAssertEqual(milestone.kind, .proteinAdherence)
        XCTAssertEqual(
            milestone.headline,
            FormaProductCopy.PlanMissionControl.proteinAdherenceHeadline
        )
    }

    // MARK: - Maintain

    func testMaintainProfileUsesLoggingMilestone() {
        let milestone = PlanMissionControlFixtures.maintainDashboard.nextMilestone

        XCTAssertFalse(milestone.showsEmptyState)
        XCTAssertEqual(milestone.kind, .loggingConsistency)
    }

    // MARK: - Training adherence

    func testTrainingMilestoneWhenLoggingAndProteinComplete() {
        let logs = completeHabitLogs

        let dashboard = PlanMissionControlFixtures.dashboard(
            for: PlanMissionControlFixtures.loseProfile,
            weekLogs: logs,
            weeklyTraining: .connected(
                workoutDays: 1,
                averageCaloriesBurned: 300,
                averageTrainingDurationMinutes: 40
            ),
            integrationState: .connected
        )

        XCTAssertEqual(dashboard.week.proteinAdherence.achieved, 7)
        XCTAssertEqual(dashboard.nextMilestone.kind, .trainingAdherence)
        XCTAssertTrue(dashboard.nextMilestone.headline.contains("training session"))
    }

    func testTrainingUnavailableWhenNoSessionsPlanned() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.trainingFrequencyPerWeek = 0

        let logs = completeHabitLogs
        let milestone = PlanMissionControlFixtures.dashboard(
            for: profile,
            weekLogs: logs
        ).nextMilestone

        XCTAssertNotEqual(milestone.kind, .trainingAdherence)
    }

    // MARK: - Presentation

    func testAccessibilitySummaryIncludesHeadline() {
        let milestone = PlanMissionControlFixtures.loseDashboard.nextMilestone

        XCTAssertTrue(milestone.accessibilitySummary.contains("Next Milestone"))
        XCTAssertTrue(milestone.accessibilitySummary.contains(milestone.headline))
    }

    // MARK: - Helpers

    private var completeHabitLogs: [DailyLog] {
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

    private func lowProteinWeekLogs(days: Int) -> [DailyLog] {
        let targets = PlanMissionControlFixtures.loseProfile.targets
        return (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: referenceDate)!
            return DailyLog(
                id: UUID(),
                date: date,
                weightKg: nil,
                targets: targets,
                totals: MacroTotals(
                    calories: targets.calorieTarget,
                    protein: 80,
                    carbs: 150,
                    fat: 50,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: 2500,
                steps: nil,
                workoutCaloriesBurned: 0,
                dailyReviewId: nil,
                createdAt: date,
                updatedAt: date
            )
        }
    }

    private func activeWeights(current: Double) -> [WeightEntry] {
        [
            WeightEntry(
                id: UUID(),
                date: calendar.date(byAdding: .day, value: -6, to: referenceDate)!,
                weightKg: current + 0.4,
                note: nil,
                createdAt: calendar.date(byAdding: .day, value: -6, to: referenceDate)!
            ),
            WeightEntry(
                id: UUID(),
                date: referenceDate,
                weightKg: current,
                note: nil,
                createdAt: referenceDate
            )
        ]
    }

    private func weightContext(
        currentWeight: Double,
        goalWeight: Double,
        weights: [WeightEntry]
    ) -> PlanDashboardContext {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.currentWeightKg = currentWeight
        profile.goalWeightKg = goalWeight

        return PlanDashboardContext(
            profile: profile,
            weekLogs: [],
            weekWeights: weights,
            allWeights: weights,
            weeklyTraining: .hidden,
            integrationState: .notConnected,
            dataSource: .appleHealth,
            asOf: referenceDate,
            calendar: calendar
        )
    }
}
