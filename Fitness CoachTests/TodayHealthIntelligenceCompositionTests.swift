//
//  TodayHealthIntelligenceCompositionTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayHealthIntelligenceCompositionTests: XCTestCase {

    func testFlagOffHidesRecoveryAndShowsActivity() {
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsRecoverySection(
                isUIEnabled: false,
                sectionState: TodayHealthIntelligencePreviewData.readyDay
            )
        )
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsLegacyNextBestAction(
                isUIEnabled: false,
                sectionState: TodayHealthIntelligencePreviewData.readyDay
            )
        )
        XCTAssertTrue(
            TodayReadOnlyCompositionPolicy.showsActivitySection(
                isUIEnabled: false,
                sectionState: TodayHealthIntelligencePreviewData.workoutDay,
                activity: workoutActivityState
            )
        )
    }

    func testFlagOnWithSectionShowsRecoveryAndHidesLegacyNextAction() {
        let section = TodayHealthIntelligencePreviewData.readyDay

        XCTAssertTrue(
            TodayReadOnlyCompositionPolicy.showsRecoverySection(
                isUIEnabled: true,
                sectionState: section
            )
        )
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsLegacyNextBestAction(
                isUIEnabled: true,
                sectionState: section
            )
        )
    }

    func testFlagOnWithoutSectionHidesRecovery() {
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsRecoverySection(
                isUIEnabled: true,
                sectionState: nil
            )
        )
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsLegacyNextBestAction(
                isUIEnabled: true,
                sectionState: nil
            )
        )
    }

    func testWorkoutCardHidesDuplicateActivitySection() {
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsActivitySection(
                isUIEnabled: true,
                sectionState: TodayHealthIntelligencePreviewData.workoutDay,
                activity: workoutActivityState
            )
        )
    }

    func testReadyDayKeepsActivitySectionForSteps() {
        XCTAssertTrue(
            TodayReadOnlyCompositionPolicy.showsActivitySection(
                isUIEnabled: true,
                sectionState: TodayHealthIntelligencePreviewData.readyDay,
                activity: stepsActivityState
            )
        )
    }

    func testHealthIntelligenceSectionIncludesRecoveryDailyMissionAndNextAction() {
        let section = TodayHealthIntelligencePreviewData.workoutDay

        XCTAssertEqual(
            section.recoveryCard.sectionTitle,
            FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle
        )
        XCTAssertEqual(
            section.dailyMission.sectionTitle,
            FormaProductCopy.Today.HealthIntelligence.DailyMission.sectionTitle
        )
        XCTAssertTrue(section.nextBestAction.isVisible)
        XCTAssertNotNil(section.workoutCard)
        XCTAssertNotNil(section.adaptiveNutritionCard)
    }

    func testReadyDayOmitsOptionalWorkoutAndAdaptiveCards() {
        let section = TodayHealthIntelligencePreviewData.readyDay

        XCTAssertNil(section.workoutCard)
        XCTAssertNil(section.adaptiveNutritionCard)
    }

    // MARK: - Helpers

    private var workoutActivityState: TodayActivityState {
        TodayActivityState(
            phase: .workoutCompleted,
            sectionTitle: FormaProductCopy.Today.Activity.sectionTitle,
            legacyWorkoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 320,
                workoutCount: 1,
                hasWorkout: true
            ),
            trainingIntegration: .connected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: 1,
            stepsToday: 9_120,
            stepGoalAssumption: 8_000,
            showsConnectCTA: false,
            date: Date(),
            trainingFrequencyPerWeek: 3
        )
    }

    private var stepsActivityState: TodayActivityState {
        TodayActivityState(
            phase: .hasData,
            sectionTitle: FormaProductCopy.Today.Activity.sectionTitle,
            legacyWorkoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 0,
                workoutCount: 0,
                hasWorkout: false
            ),
            trainingIntegration: .connected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: nil,
            stepsToday: 8_450,
            stepGoalAssumption: 8_000,
            showsConnectCTA: false,
            date: Date(),
            trainingFrequencyPerWeek: 3
        )
    }
}
