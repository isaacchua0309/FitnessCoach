//
//  TodayEmptyStateFormattingTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayEmptyStateFormattingTests: XCTestCase {

    func testMissingProfileGuidesToPlan() {
        let copy = TodayEmptyStateFormatting.copy(for: .missingProfile)

        XCTAssertEqual(copy.title, FormaProductCopy.Today.EmptyState.missingProfileTitle)
        XCTAssertEqual(copy.actionTitle, FormaProductCopy.Today.EmptyState.missingProfileAction)
        XCTAssertTrue(copy.body.localizedCaseInsensitiveContains("Plan"))
    }

    func testNewProfileNoMealsUsesEncouragingMealsCopy() {
        let mission = TodayMissionHeroFormatter.displayModel(
            calorieSummary: emptyCalories,
            proteinProgress: emptyProtein,
            waterSummary: emptyWater,
            mealsEmptyKind: .newProfileNoMeals
        )
        let mealsCopy = TodayEmptyStateFormatting.mealsEmptyCopy(for: .newProfileNoMeals)

        XCTAssertEqual(mission.statusLine, FormaProductCopy.Today.Mission.statusPlanReady)
        XCTAssertEqual(mealsCopy.title, FormaProductCopy.Today.EmptyState.newProfileMealsTitle)
        XCTAssertTrue(mission.showsLogMealCTA)
    }

    func testReturningUserNewDayNoMealsUsesFreshDayCopy() {
        let kind = TodayEmptyStateFormatting.mealsEmptyKind(
            mealsEmpty: true,
            hasPriorFoodLogs: true
        )
        let mission = TodayMissionHeroFormatter.displayModel(
            calorieSummary: emptyCalories,
            proteinProgress: emptyProtein,
            waterSummary: emptyWater,
            mealsEmptyKind: kind
        )
        let mealsCopy = TodayEmptyStateFormatting.mealsEmptyCopy(for: kind)

        XCTAssertEqual(kind, .newDayNoMeals)
        XCTAssertEqual(mission.statusLine, FormaProductCopy.Today.Mission.statusPlanReady)
        XCTAssertEqual(mealsCopy.title, FormaProductCopy.Today.EmptyState.newDayMealsTitle)
    }

    func testLocalLoadErrorDoesNotMentionNetwork() {
        let message = TodayLoadErrorFormatting.message(
            for: ServiceError.persistenceFailed("disk"),
            isRefresh: false
        )

        XCTAssertEqual(message, FormaProductCopy.Today.EmptyState.loadErrorLocalBody)
        XCTAssertFalse(message.localizedCaseInsensitiveContains("connection"))
    }

    func testNetworkLoadErrorMentionsConnection() {
        let message = TodayLoadErrorFormatting.message(
            for: URLError(.notConnectedToInternet),
            isRefresh: false
        )

        XCTAssertEqual(message, FormaProductCopy.Today.EmptyState.loadErrorNetworkBody)
        XCTAssertTrue(message.localizedCaseInsensitiveContains("connection"))
    }

    func testAppleHealthUnavailableCopyIsOptionalNotRequired() {
        let copy = TodayEmptyStateFormatting.copy(for: .appleHealthUnavailable)

        XCTAssertEqual(copy.title, FormaProductCopy.Today.EmptyState.appleHealthTitle)
        XCTAssertTrue(copy.title.localizedCaseInsensitiveContains("optional"))
        XCTAssertTrue(copy.body.localizedCaseInsensitiveContains("either way"))
    }

    func testNoActivityDataCopyIsEncouraging() {
        let copy = TodayEmptyStateFormatting.copy(for: .noActivityData)

        XCTAssertEqual(copy.title, FormaProductCopy.Today.EmptyState.noActivityTitle)
        XCTAssertTrue(copy.body.localizedCaseInsensitiveContains("rest days"))
    }

    func testNoRecentWeightReminderWhenWeightMissing() {
        XCTAssertTrue(
            TodayEmptyStateFormatting.shouldShowWeightReminder(
                weightLoggedToday: false,
                hasRecentWeight: false
            )
        )

        let copy = TodayEmptyStateFormatting.copy(for: .noRecentWeight)
        XCTAssertEqual(copy.actionTitle, FormaProductCopy.Today.EmptyState.logWeightAction)
    }

    func testHasMealsHidesEmptyMealsCopyAndLogCTA() {
        XCTAssertEqual(
            TodayEmptyStateFormatting.mealsEmptyKind(mealsEmpty: false, hasPriorFoodLogs: true),
            .hasMeals
        )
        XCTAssertFalse(
            TodayMissionHeroFormatter.displayModel(
                calorieSummary: emptyCalories,
                proteinProgress: emptyProtein,
                waterSummary: emptyWater,
                mealsEmptyKind: .hasMeals
            ).showsLogMealCTA
        )
    }

    func testReturningUserEmptyDayUsesNewDayMealsKind() {
        let state = TodayMissionControlStateBuilder.build(
            from: TodayMissionControlInputs(
                date: TodayDashboardFixtures.date(hour: 9),
                calorieSummary: CalorieSummary(
                    consumed: 0,
                    target: 1_800,
                    remaining: 1_800,
                    progress: 0,
                    isOverTarget: false
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(consumed: 0, target: 170, remaining: 170, progress: 0),
                    carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                    fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
                ),
                waterSummary: WaterSummary(
                    consumedMl: 0,
                    targetMl: 3_500,
                    remainingMl: 3_500,
                    progress: 0
                ),
                weightSummary: TodayWeightSummary(
                    weightKg: nil,
                    displayText: "Not logged today"
                ),
                weightLoggedToday: false,
                hasRecentWeight: true,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: 0,
                    workoutCount: 0,
                    hasWorkout: false
                ),
                foodEntries: [],
                hasPriorFoodLogs: true,
                yesterdayReviewInput: nil,
                goalWeightKg: 75,
                profileWeightKg: 80,
                activityContext: .default,
                trainingFrequencyPerWeek: 0
            )
        )

        XCTAssertEqual(state.emptyContext.mealsEmptyKind, .newDayNoMeals)
    }

    func testEmptyStateCopyAvoidsShameLanguage() {
        let samples = [
            TodayEmptyStateFormatting.copy(for: .missingProfile).body,
            TodayEmptyStateFormatting.copy(for: .newProfileNoMeals).body,
            TodayEmptyStateFormatting.copy(for: .returningUserNewDayNoMeals).body,
            TodayEmptyStateFormatting.copy(for: .loadErrorLocal).body,
            TodayEmptyStateFormatting.copy(for: .appleHealthUnavailable).body,
            TodayEmptyStateFormatting.copy(for: .noActivityData).body,
            TodayEmptyStateFormatting.copy(for: .noRecentWeight).body
        ]

        for sample in samples {
            XCTAssertFalse(sample.localizedCaseInsensitiveContains("behind"))
            XCTAssertFalse(sample.localizedCaseInsensitiveContains("failed"))
            XCTAssertFalse(sample.localizedCaseInsensitiveContains("locked"))
        }
    }

    func testEmptyDayFixtureBuildsNewProfileContext() {
        let state = TodayDashboardFixtures.emptyDay()

        XCTAssertEqual(state.emptyContext.mealsEmptyKind, .newProfileNoMeals)
    }

    func testDashboardWithoutRecentWeightShowsReminderContext() {
        let state = TodayMissionControlStateBuilder.build(
            from: TodayMissionControlInputs(
                date: TodayDashboardFixtures.date(hour: 9),
                calorieSummary: CalorieSummary(
                    consumed: 0,
                    target: 1_800,
                    remaining: 1_800,
                    progress: 0,
                    isOverTarget: false
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(consumed: 0, target: 170, remaining: 170, progress: 0),
                    carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                    fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
                ),
                waterSummary: WaterSummary(
                    consumedMl: 0,
                    targetMl: 3_500,
                    remainingMl: 3_500,
                    progress: 0
                ),
                weightSummary: TodayWeightSummary(
                    weightKg: nil,
                    displayText: "Not logged today"
                ),
                weightLoggedToday: false,
                hasRecentWeight: false,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: 0,
                    workoutCount: 0,
                    hasWorkout: false
                ),
                foodEntries: [],
                hasPriorFoodLogs: false,
                yesterdayReviewInput: nil,
                goalWeightKg: 75,
                profileWeightKg: 80,
                activityContext: .default,
                trainingFrequencyPerWeek: 0
            )
        )

        XCTAssertTrue(state.emptyContext.showsWeightReminder)
    }

    // MARK: - Helpers

    private var emptyCalories: CalorieSummary {
        CalorieSummary(consumed: 0, target: 1_800, remaining: 1_800, progress: 0, isOverTarget: false)
    }

    private var emptyProtein: MacroProgress {
        MacroProgress(consumed: 0, target: 170, remaining: 170, progress: 0)
    }

    private var emptyWater: WaterSummary {
        WaterSummary(consumedMl: 0, targetMl: 3_500, remainingMl: 3_500, progress: 0)
    }
}
