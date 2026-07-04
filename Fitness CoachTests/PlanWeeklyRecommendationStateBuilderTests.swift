//
//  PlanWeeklyRecommendationStateBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanWeeklyRecommendationStateBuilderTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!
    private let calendar = Calendar.current

    func testInsufficientDataShowsLearnedMaintenanceUnavailable() {
        let state = PlanMissionControlFixtures.newUserDashboard.weeklyRecommendation

        XCTAssertFalse(state.showsLearnedEstimate)
        XCTAssertNil(state.learnedMaintenanceKcal)
        XCTAssertEqual(
            state.learnedMaintenanceUnavailableCopy,
            FormaProductCopy.PlanMissionControl.learnedMaintenanceUnavailable
        )
        XCTAssertFalse(state.showsRecommendation)
        XCTAssertFalse(state.showsReviewPlanCTA)
    }

    func testFormulaMaintenanceUsesPlanTDEE() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let state = PlanMissionControlFixtures.loseDashboard.weeklyRecommendation

        XCTAssertEqual(state.formulaMaintenanceLabel, "Initial estimate")
        XCTAssertEqual(state.formulaMaintenanceKcal, result.tdeeKcal)
    }

    func testSafetyCopyIsAlwaysPresent() {
        let dashboards = [
            PlanMissionControlFixtures.newUserDashboard,
            PlanMissionControlFixtures.activeUserDashboard
        ]

        for dashboard in dashboards {
            XCTAssertEqual(
                dashboard.weeklyRecommendation.safetyCopy,
                FormaProductCopy.PlanMissionControl.weeklyRecommendationSafetyCopy
            )
            XCTAssertTrue(dashboard.weeklyRecommendation.accessibilitySummary.contains(
                FormaProductCopy.PlanMissionControl.weeklyRecommendationSafetyCopy
            ))
        }
    }

    func testRecommendationMatchesJourneyUnifiedPresentation() throws {
        let journeyDashboard = JourneyPreviewData.strongMomentum
        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: journeyDashboard)
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: journeyDashboard.weeklyProgressSummary.endDate
        )

        let context = PlanDashboardContext(
            profile: profile,
            weekLogs: PlanMissionControlFixtures.activeWeekLogsForTests(referenceDate: referenceDate),
            maturityLogs: PlanMissionControlFixtures.activeWeekLogsForTests(referenceDate: referenceDate),
            allWeights: PlanMissionControlFixtures.activeWeightEntriesForTests(referenceDate: referenceDate),
            integrationState: .connected,
            dataSource: .appleHealth,
            healthWorkoutDayStarts: [],
            asOf: journeyDashboard.weeklyProgressSummary.endDate,
            calendar: calendar
        )

        let planState = PlanWeeklyRecommendationStateBuilder.build(
            context: context,
            planResult: result,
            referenceDate: journeyDashboard.weeklyProgressSummary.endDate,
            weeklyProgressSummaryBuilder: FixedWeeklyProgressSummaryBuilder(
                summary: journeyDashboard.weeklyProgressSummary
            )
        )

        XCTAssertEqual(planState.recommendationTitle, unified.planRecommendationBlock?.title)
        XCTAssertEqual(planState.recommendationMessage, unified.planRecommendationBlock?.message)
        XCTAssertEqual(
            planState.suggestedCalorieDelta,
            unified.planRecommendationBlock?.suggestedCalorieDelta
        )

        let goalDirection = JourneyGoalDirection.resolve(
            currentWeightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg
        )
        let policyRecommendation = PlanRecommendationPolicy.recommend(
            PlanRecommendationInput(
                summary: journeyDashboard.weeklyProgressSummary,
                currentCalorieTargetKcal: profile.targets.calorieTarget,
                staticTDEEKcal: result.tdeeKcal,
                calorieFloorKcal: result.calories.calorieFloorKcal,
                goalDirection: goalDirection
            )
        )
        XCTAssertEqual(planState.showsReviewPlanCTA, policyRecommendation.shouldShowPlanCTA)
        XCTAssertEqual(planState.showsRecommendation, policyRecommendation.kind != .notEnoughData)
    }

    func testEligibleLearnedMaintenanceShowsValue() {
        let summary = JourneyPreviewData.strongMomentum.weeklyProgressSummary
        XCTAssertTrue(summary.maintenanceEstimate.sufficiency.isEligibleForKcalMaintenanceDisplay)

        let state = buildState(summary: summary)

        if summary.maintenanceEstimate.estimatedMaintenanceKcal != nil {
            XCTAssertTrue(state.showsLearnedEstimate)
            XCTAssertEqual(
                state.learnedMaintenanceKcal,
                summary.maintenanceEstimate.estimatedMaintenanceKcal
            )
        }
    }

    func testBrandNewUserSummaryHasNoRecommendation() {
        let summary = JourneyPreviewData.brandNewUser.weeklyProgressSummary
        let state = buildState(summary: summary)

        XCTAssertFalse(state.showsLearnedEstimate)
        XCTAssertFalse(state.showsRecommendation)
        XCTAssertFalse(state.showsReviewPlanCTA)
    }

    // MARK: Helpers

    private func buildState(summary: WeeklyProgressSummary) -> PlanWeeklyRecommendationState {
        let profile = PlanMissionControlFixtures.loseProfile
        let context = PlanDashboardContext.profileOnly(
            profile: profile,
            referenceDate: summary.endDate,
            calendar: calendar
        )

        return PlanWeeklyRecommendationStateBuilder.build(
            context: context,
            planResult: try? PlanCalculationBridge.planResult(
                from: profile,
                referenceDate: summary.endDate
            ),
            referenceDate: summary.endDate,
            weeklyProgressSummaryBuilder: FixedWeeklyProgressSummaryBuilder(summary: summary)
        )
    }
}

private struct FixedWeeklyProgressSummaryBuilder: WeeklyProgressSummaryBuilding {
    let summary: WeeklyProgressSummary

    func buildSummary(
        asOf date: Date,
        profile: UserProfile?,
        dailyLogs: [DailyLog],
        weightEntries: [WeightEntry],
        trainingDayStarts: Set<Date>?
    ) -> WeeklyProgressSummary {
        summary
    }
}

private extension PlanMissionControlFixtures {
    static func activeWeekLogsForTests(referenceDate: Date) -> [DailyLog] {
        let calendar = Calendar.current
        return (0..<5).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: referenceDate)!
            return DailyLog(
                id: UUID(),
                date: date,
                weightKg: nil,
                targets: loseProfile.targets,
                totals: MacroTotals(
                    calories: 2200,
                    protein: 170,
                    carbs: 175,
                    fat: 55,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: 3000,
                steps: nil,
                workoutCaloriesBurned: 0,
                dailyReviewId: nil,
                createdAt: date,
                updatedAt: date
            )
        }
    }

    static func activeWeightEntriesForTests(referenceDate: Date) -> [WeightEntry] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -21, to: referenceDate)!
        return [
            WeightEntry(id: UUID(), date: start, weightKg: 91.2, note: nil, createdAt: start),
            WeightEntry(
                id: UUID(),
                date: calendar.date(byAdding: .day, value: -14, to: referenceDate)!,
                weightKg: 90.8,
                note: nil,
                createdAt: calendar.date(byAdding: .day, value: -14, to: referenceDate)!
            ),
            WeightEntry(
                id: UUID(),
                date: calendar.date(byAdding: .day, value: -7, to: referenceDate)!,
                weightKg: 90.1,
                note: nil,
                createdAt: calendar.date(byAdding: .day, value: -7, to: referenceDate)!
            ),
            WeightEntry(id: UUID(), date: referenceDate, weightKg: 89.6, note: nil, createdAt: referenceDate)
        ]
    }
}
