//
//  SmartCoachEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class SmartCoachEngineTests: XCTestCase {

    func testHiddenWhenNoMeaningfulContext() {
        let banner = resolve(
            foodEntries: [],
            proteinConsumed: 0,
            waterConsumedMl: 0,
            calorieConsumed: 0,
            hasWorkout: false
        )

        XCTAssertFalse(banner.isVisible)
        XCTAssertEqual(banner.context, .hidden)
    }

    func testProteinBehindBanner() {
        let banner = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 40,
            waterConsumedMl: 3_000,
            calorieConsumed: 710,
            hasWorkout: false
        )

        XCTAssertEqual(banner.context, .proteinBehind)
        XCTAssertEqual(banner.message, FormaProductCopy.Today.SmartCoach.proteinBehind)
        XCTAssertEqual(banner.coachPrefill, TodayCoachPrompt.logProtein)
        XCTAssertEqual(banner.coachActionTitle, FormaProductCopy.Today.SmartCoach.coachProteinAction)
    }

    func testWaterBehindBanner() {
        let banner = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 160,
            waterConsumedMl: 500,
            calorieConsumed: 710,
            hasWorkout: false
        )

        XCTAssertEqual(banner.context, .waterBehind)
        XCTAssertEqual(banner.message, FormaProductCopy.Today.SmartCoach.waterBehind)
        XCTAssertNil(banner.coachPrefill)
        XCTAssertNil(banner.coachActionTitle)
    }

    func testCaloriesCloseToTargetBanner() {
        let banner = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 160,
            waterConsumedMl: 3_200,
            calorieConsumed: 1_620,
            calorieTarget: 1_800,
            calorieRemaining: 180,
            calorieProgress: 0.9,
            hasWorkout: false
        )

        XCTAssertEqual(banner.context, .caloriesCloseToTarget)
        XCTAssertEqual(banner.message, FormaProductCopy.Today.SmartCoach.caloriesCloseToTarget)
        XCTAssertNil(banner.coachPrefill)
    }

    func testCaloriesExceededBanner() {
        let banner = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 120,
            waterConsumedMl: 2_000,
            calorieConsumed: 2_100,
            calorieTarget: 1_800,
            calorieRemaining: 0,
            calorieProgress: 1.17,
            isOverTarget: true,
            hasWorkout: false
        )

        XCTAssertEqual(banner.context, .caloriesExceeded)
        XCTAssertEqual(banner.message, FormaProductCopy.Today.SmartCoach.caloriesExceeded)
        XCTAssertEqual(banner.coachPrefill, TodayCoachPrompt.reviewToday)
        XCTAssertEqual(banner.coachActionTitle, FormaProductCopy.Today.SmartCoach.coachReviewAction)
    }

    func testWorkoutRecoveryBanner() {
        let banner = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 90,
            waterConsumedMl: 2_000,
            calorieConsumed: 900,
            hasWorkout: true,
            appleHealthWorkoutCount: 1
        )

        XCTAssertEqual(banner.context, .workoutRecovery)
        XCTAssertEqual(banner.message, FormaProductCopy.Today.SmartCoach.workoutRecovery)
        XCTAssertEqual(banner.coachPrefill, TodayCoachPrompt.logProtein)
    }

    func testEndOfDayIncompleteHabitsBanner() {
        let evening = TodayDashboardFixtures.date(hour: 20)
        let banner = resolve(
            date: evening,
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 160,
            waterConsumedMl: 3_200,
            calorieConsumed: 900,
            calorieTarget: 1_800,
            calorieRemaining: 900,
            calorieProgress: 0.5,
            hasWorkout: false
        )

        XCTAssertEqual(banner.context, .endOfDayIncomplete)
        XCTAssertEqual(banner.message, FormaProductCopy.Today.SmartCoach.endOfDayIncomplete)
        XCTAssertEqual(banner.coachPrefill, TodayCoachPrompt.reviewToday)
    }

    func testCaloriesExceededTakesPriorityOverProteinBehind() {
        let banner = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 40,
            waterConsumedMl: 500,
            calorieConsumed: 2_100,
            calorieTarget: 1_800,
            calorieRemaining: 0,
            calorieProgress: 1.17,
            isOverTarget: true,
            hasWorkout: true,
            appleHealthWorkoutCount: 1
        )

        XCTAssertEqual(banner.context, .caloriesExceeded)
    }

    func testOnTrackDayHidesBanner() {
        let banner = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 165,
            waterConsumedMl: 3_500,
            calorieConsumed: 1_200,
            calorieTarget: 1_800,
            calorieRemaining: 600,
            calorieProgress: 0.67,
            hasWorkout: false
        )

        XCTAssertFalse(banner.isVisible)
        XCTAssertEqual(banner.context, .hidden)
    }

    // MARK: - Fixtures

    private func resolve(
        date: Date = TodayDashboardFixtures.date(hour: 14),
        foodEntries: [FoodEntry],
        proteinConsumed: Double,
        proteinTarget: Double = 170,
        waterConsumedMl: Int,
        waterTargetMl: Int = 3_500,
        calorieConsumed: Int,
        calorieTarget: Int = 1_800,
        calorieRemaining: Int? = nil,
        calorieProgress: Double? = nil,
        isOverTarget: Bool = false,
        hasWorkout: Bool,
        appleHealthWorkoutCount: Int? = nil
    ) -> TodaySmartCoachState {
        let proteinRemaining = max(proteinTarget - proteinConsumed, 0)
        let waterRemaining = max(waterTargetMl - waterConsumedMl, 0)
        let remaining = calorieRemaining ?? max(calorieTarget - calorieConsumed, 0)
        let progress = calorieProgress ?? (calorieTarget > 0 ? Double(calorieConsumed) / Double(calorieTarget) : 0)

        return SmartCoachEngine.resolve(
            SmartCoachInput(
                date: date,
                calendar: Calendar(identifier: .gregorian),
                foodEntries: foodEntries,
                proteinProgress: MacroProgress(
                    consumed: proteinConsumed,
                    target: proteinTarget,
                    remaining: proteinRemaining,
                    progress: proteinTarget > 0 ? proteinConsumed / proteinTarget : 0
                ),
                waterProgress: waterTargetMl > 0 ? Double(waterConsumedMl) / Double(waterTargetMl) : 0,
                calorieSummary: CalorieSummary(
                    consumed: calorieConsumed,
                    target: calorieTarget,
                    remaining: remaining,
                    progress: progress,
                    isOverTarget: isOverTarget
                ),
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: hasWorkout ? 250 : 0,
                    workoutCount: hasWorkout ? 1 : 0,
                    hasWorkout: hasWorkout
                ),
                activityContext: TodayActivityContext(
                    trainingIntegration: .connected,
                    trainingDataSource: .appleHealth,
                    appleHealthWorkoutCount: appleHealthWorkoutCount,
                    stepsToday: nil
                )
            )
        )
    }
}
