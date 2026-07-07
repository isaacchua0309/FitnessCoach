//
//  MainTabLayoutPreviewTests.swift
//  Fitness CoachTests
//
//  Forma — Lightweight coverage for shared main-tab layout preview fixtures.
//

import XCTest
@testable import Fitness_Coach

final class MainTabLayoutPreviewTests: XCTestCase {

    func testSnapshotFixturesCoverSharedComponentsAndTabTops() {
        let fixtures = MainTabLayoutSnapshotFixture.allCases.map(\.rawValue)

        XCTAssertTrue(fixtures.contains("pageHeaderTitleOnly"))
        XCTAssertTrue(fixtures.contains("pageHeaderWithSubtitle"))
        XCTAssertTrue(fixtures.contains("pageHeaderWithTrailingPill"))
        XCTAssertTrue(fixtures.contains("sectionLabels"))
        XCTAssertTrue(fixtures.contains("mainTabCards"))
        XCTAssertTrue(fixtures.contains("scaffoldSample"))
        XCTAssertTrue(fixtures.contains("todayTop"))
        XCTAssertTrue(fixtures.contains("coachEmptyTop"))
        XCTAssertTrue(fixtures.contains("coachActiveChatTop"))
        XCTAssertTrue(fixtures.contains("journeyTop"))
        XCTAssertTrue(fixtures.contains("planTop"))
        XCTAssertEqual(fixtures.count, 11)
    }

    func testTodayTopPreviewUsesStaticPreviewData() {
        let state = TodayPreviewData.partialDay
        XCTAssertFalse(state.mission.sectionTitle.isEmpty)
        XCTAssertFalse(
            TodayDashboardHeaderFormatting.dateLine(for: state.date).isEmpty
        )
    }

    func testPlanTopPreviewUsesMissionControlFixtures() {
        let state = PlanPreviewScreens.dashboard(.aggressiveCut)
        XCTAssertEqual(state.status.classification, .aggressiveCut)
        XCTAssertFalse(state.strategy.primaryGoal.isEmpty)
    }

    func testJourneyTopPreviewUsesJourneyPreviewData() {
        let state = JourneyPreviewData.dashboard(.strongMomentum)
        XCTAssertFalse(state.transformation.title.isEmpty)
        XCTAssertFalse(state.header.title.isEmpty)
    }

    func testCoachPreviewMessagesUseStaticFixtures() {
        XCTAssertFalse(CoachPreviewData.messages.isEmpty)
        XCTAssertFalse(CoachPreviewData.confirmationMessage.text.isEmpty)
    }

    func testPreviewMetricsUsePositiveLayoutValues() {
        XCTAssertGreaterThan(MainTabLayoutPreviewScreens.Metrics.previewWidth, 320)
        XCTAssertGreaterThan(MainTabLayoutPreviewScreens.Metrics.topLayoutHeight, 400)
        XCTAssertGreaterThan(MainTabLayoutPreviewScreens.Metrics.fullPhoneHeight, 700)
    }

    func testSnapshotFixtureHeightsMatchPreviewMetrics() {
        XCTAssertEqual(
            MainTabLayoutSnapshotFixture.todayTop.exportHeight,
            MainTabLayoutPreviewScreens.Metrics.topLayoutHeight
        )
        XCTAssertEqual(
            MainTabLayoutSnapshotFixture.coachActiveChatTop.exportHeight,
            MainTabLayoutPreviewScreens.Metrics.fullPhoneHeight
        )
    }
}
