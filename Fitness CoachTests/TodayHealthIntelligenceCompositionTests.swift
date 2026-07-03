//
//  TodayHealthIntelligenceCompositionTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayHealthIntelligenceCompositionTests: XCTestCase {

    func testFlagOffPreservesLegacySectionVisibility() {
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: false,
                sectionState: TodayHealthIntelligencePreviewData.readyDay
            )
        )
        XCTAssertTrue(
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

    func testFlagOnWithSectionShowsHealthIntelligenceAndHidesLegacyNextAction() {
        let section = TodayHealthIntelligencePreviewData.readyDay

        XCTAssertTrue(
            TodayReadOnlyCompositionPolicy.showsHealthIntelligenceSection(
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

    func testFlagOnWithoutSectionFallsBackToLegacyNextAction() {
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: true,
                sectionState: nil
            )
        )
        XCTAssertTrue(
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
            displayLine: FormaProductCopy.Today.Activity.workoutCompletedLine,
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
            displayLine: FormaProductCopy.Today.Activity.stepsToday(8_450),
            showsConnectCTA: false,
            date: Date(),
            trainingFrequencyPerWeek: 3
        )
    }
}
