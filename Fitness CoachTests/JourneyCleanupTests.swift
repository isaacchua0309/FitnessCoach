//
//  JourneyCleanupTests.swift
//  Fitness CoachTests
//
//  Regression tests after Journey revamp preparation cleanup.
//

import XCTest
@testable import Fitness_Coach

final class JourneyCleanupTests: XCTestCase {

    func testJourneyProductLayoutExcludesRemovedSections() {
        let identifiers = Set(JourneyProductLayout.sectionOrder.map(\.rawValue))

        XCTAssertFalse(identifiers.contains("habitInsights"))
        XCTAssertFalse(identifiers.contains("whyProgress"))
        XCTAssertFalse(identifiers.contains("beforeToday"))
        XCTAssertFalse(identifiers.contains("personalRecords"))
        XCTAssertFalse(identifiers.contains("journeyLevel"))
        XCTAssertFalse(identifiers.contains("detailedAnalytics"))
        XCTAssertTrue(identifiers.contains("monthlyRecap"))
        XCTAssertTrue(identifiers.contains("chapters"))
        XCTAssertTrue(identifiers.contains("header"))
    }

    func testBrandNewUserShowsNextAchievementAndStartingEmptyState() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertTrue(dashboard.milestone.isVisible)
        XCTAssertTrue(dashboard.showsStartingEmptyState)
    }

    func testStrongMomentumDoesNotShowStartingEmptyState() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertFalse(dashboard.showsStartingEmptyState)
    }

    func testStartingEmptyStateCopyMatchesProductSpec() {
        XCTAssertEqual(
            FormaProductCopy.Journey.StartingEmptyState.title,
            "Your journey is just starting."
        )
        XCTAssertEqual(
            FormaProductCopy.Journey.StartingEmptyState.body,
            "Log meals, workouts, water, and weight to build your transformation story."
        )
        XCTAssertEqual(
            FormaProductCopy.Journey.StartingEmptyState.action,
            "Go to Today"
        )
    }

    func testJourneyDashboardStateContainsPresentationSections() {
        let dashboard = JourneyPreviewData.strongMomentum
        let mirror = Mirror(reflecting: dashboard)
        let propertyNames = Set(mirror.children.compactMap(\.label))

        XCTAssertEqual(
            propertyNames,
            [
                "hasProfile",
                "baseline",
                "streaks",
                "header",
                "momentum",
                "transformation",
                "goalProjection",
                "milestone",
                "storyEvents",
                "insight",
                "weeklyHabit",
                "monthlyRecap",
                "chapter"
            ]
        )
    }

    func testLegacySectionAccessorsRemainAvailable() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertFalse(dashboard.transformation.primaryMessage.isEmpty)
        XCTAssertFalse(dashboard.weeklyReview.weekSummaryCopy.isEmpty)
        XCTAssertFalse(dashboard.milestones.items.isEmpty)
        XCTAssertFalse(dashboard.storyTimeline.displayEvents.isEmpty)
    }

    func testRevampPreviewPersonasExcludeBannedCopy() {
        let personas: [JourneyDashboardState] = [
            JourneyPreviewData.brandNewUser,
            JourneyPreviewData.weekOne,
            JourneyPreviewData.strongMomentum,
            JourneyPreviewData.sparseData,
            JourneyPreviewData.foodLogsOnly,
            JourneyPreviewData.weightLogsNoLoss,
            JourneyPreviewData.monthlyRecapActive
        ]

        for dashboard in personas {
            JourneyRevampQAChecklistSupport.assertNoBannedLiveCopy(in: dashboard)
            JourneyRevampQAChecklistSupport.assertNoFakeZeroPercentMonthlyRecap(dashboard.monthlyRecap)
            JourneyRevampQAChecklistSupport.assertHeroDoesNotShowZeroKgLost(dashboard.transformation)
        }
    }

    func testChapterSectionDoesNotSurfaceCosmeticXP() {
        let chapter = JourneyPreviewData.strongMomentum.chapter
        XCTAssertFalse(chapter.accessibilitySummary.localizedCaseInsensitiveContains("xp"))
        XCTAssertFalse(chapter.accessibilitySummary.contains("/"))
    }
}
