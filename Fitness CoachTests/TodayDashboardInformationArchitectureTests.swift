//
//  TodayDashboardInformationArchitectureTests.swift
//  Fitness CoachTests
//
//  Verifies the action-oriented Today dashboard information architecture.
//

import XCTest
@testable import Fitness_Coach

final class TodayDashboardInformationArchitectureTests: XCTestCase {

    func testMissionHeroPrecedesRecoveryInCanonicalOrder() {
        let sections = TodayDashboardSectionOrder.sections.map(\.rawValue)
        let missionIndex = sections.firstIndex(of: "missionHero")
        let recoveryIndex = sections.firstIndex(of: "recovery")
        let appleHealthIndex = sections.firstIndex(of: "appleHealthSetup")

        XCTAssertEqual(sections.first, "header")
        XCTAssertEqual(sections[1], "missionHero")
        XCTAssertEqual(sections[2], "waterQuickLog")
        XCTAssertLessThan(missionIndex!, recoveryIndex!)
        XCTAssertLessThan(recoveryIndex!, appleHealthIndex!)
    }

    func testAppleHealthSetupCardShowsOnlyWhenDisconnected() {
        let disconnected = TodayPreviewData.healthDisconnected.activity
        let connected = TodayPreviewData.partialDay.activity

        XCTAssertTrue(TodayReadOnlyCompositionPolicy.showsAppleHealthSetupCard(activity: disconnected))
        XCTAssertFalse(TodayReadOnlyCompositionPolicy.showsAppleHealthSetupCard(activity: connected))
    }

    func testActivityHidesInlineAppleHealthPromptWhenSetupCardShows() {
        let disconnected = TodayPreviewData.healthDisconnected.activity
        let withSetupCard = TodayActivitySectionFormatting.displayModel(
            for: disconnected,
            includesAppleHealthSetupCard: true
        )
        let withoutSetupCard = TodayActivitySectionFormatting.displayModel(
            for: disconnected,
            includesAppleHealthSetupCard: false
        )

        XCTAssertNil(withSetupCard.healthNote)
        XCTAssertNil(withSetupCard.healthActionTitle)
        XCTAssertNotNil(withoutSetupCard.healthNote)
        XCTAssertNotNil(withoutSetupCard.healthActionTitle)
    }

    func testRecoveryUsesCompactPresentationForUnclearData() {
        let state = TodayHealthIntelligencePreviewData.noHealthData.recoveryCard

        XCTAssertTrue(TodayRecoverySectionFormatting.isCompact(state))
        XCTAssertEqual(
            TodayRecoverySectionFormatting.compactBody(for: state),
            FormaProductCopy.Today.Recovery.unclearBody
        )
    }

    func testRecoveryUsesFullPresentationForReadyDay() {
        let state = TodayHealthIntelligencePreviewData.readyDay.recoveryCard

        XCTAssertFalse(TodayRecoverySectionFormatting.isCompact(state))
    }

    func testHealthConnectFallbackIsSuppressedForBottomSetupCard() {
        let section = TodayHealthIntelligencePreviewData.noHealthData

        XCTAssertFalse(TodayReadOnlyCompositionPolicy.showsStandaloneHIFallback(sectionState: section))
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsHealthNextBestAction(sectionState: section)
        )
    }

    func testEmptyDayMissionAndMealsCopyAreActionable() {
        let state = TodayPreviewData.brandNewDay

        XCTAssertEqual(
            state.mission.statusLine,
            FormaProductCopy.Today.Mission.statusEmptyDay
        )
        XCTAssertTrue(state.mission.waterRemainingLine.contains("Water remaining"))
        XCTAssertFalse(state.mission.nextStepLine.isEmpty)
    }

    func testHeaderPlanStatusChipOnlyWhenNeedsAttention() {
        XCTAssertNil(
            TodayDashboardHeaderFormatting.planStatusChip(for: .onTrack)
        )
        XCTAssertEqual(
            TodayDashboardHeaderFormatting.planStatusChip(for: .needsFocus),
            FormaProductCopy.Today.Header.planStatusNeedsFocus
        )
        XCTAssertEqual(
            TodayDashboardHeaderFormatting.planStatusChip(for: .overBudget),
            FormaProductCopy.Today.Header.planStatusOverTarget
        )
    }
}
