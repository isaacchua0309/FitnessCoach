//
//  JourneyProgressStructureTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyProgressStructureTests: XCTestCase {

    func testProductSectionOrderMatchesCanonicalLayout() {
        XCTAssertEqual(JourneyProductLayout.sectionOrder, [
            .hero,
            .nextAction,
            .weeklyProgress,
            .progress,
            .highlights,
            .storyTimeline,
            .chapters
        ])
        XCTAssertEqual(JourneyProductLayout.sectionOrder.last, .chapters)
    }

    func testRemovedSectionsAreNotPartOfCanonicalOrder() {
        let identifiers = Set(JourneyProductLayout.sectionOrder.map(\.rawValue))

        XCTAssertFalse(identifiers.contains("header"))
        XCTAssertFalse(identifiers.contains("transformation"))
        XCTAssertFalse(identifiers.contains("goalProjection"))
        XCTAssertFalse(identifiers.contains("healthIntelligence"))
        XCTAssertFalse(identifiers.contains("milestones"))
        XCTAssertFalse(identifiers.contains("weeklyReview"))
        XCTAssertFalse(identifiers.contains("insights"))
        XCTAssertFalse(identifiers.contains("monthlyRecap"))
        XCTAssertFalse(identifiers.contains("startingEmptyState"))
        XCTAssertFalse(identifiers.contains("habitInsights"))
        XCTAssertFalse(identifiers.contains("whyProgress"))
        XCTAssertFalse(identifiers.contains("beforeToday"))
        XCTAssertFalse(identifiers.contains("personalRecords"))
        XCTAssertFalse(identifiers.contains("journeyLevel"))
        XCTAssertFalse(identifiers.contains("detailedAnalytics"))
        XCTAssertFalse(identifiers.contains("consistencyCalendar"))
        XCTAssertFalse(identifiers.contains("coachInsights"))
        XCTAssertFalse(identifiers.contains("achievements"))
    }

    func testBrandNewUserShowsLeanAboveTheFoldLayout() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertFalse(dashboard.showsStartingEmptyState)
        XCTAssertTrue(dashboard.milestone.isVisible)
        XCTAssertFalse(dashboard.showsMilestonesSection)
        XCTAssertTrue(dashboard.showsNextActionSection)
        XCTAssertTrue(dashboard.showsDashboardHeroSection)
        XCTAssertTrue(dashboard.showsWeeklyProgressSection)
        XCTAssertTrue(dashboard.showsProgressSection)
        XCTAssertTrue(dashboard.showsChapterSection)
        XCTAssertEqual(
            dashboard.screenPresentation.unlockDashboard.nextActionCard?.title,
            FormaProductCopy.Journey.NextBestAction.logFirstMeal
        )
    }

    func testStrongMomentumHidesNextActionAndShowsChapter() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertFalse(dashboard.showsNextActionSection)
        XCTAssertTrue(dashboard.showsChapterSection)
        XCTAssertTrue(dashboard.showsDashboardHeroSection)
        XCTAssertTrue(dashboard.showsWeeklyProgressSection)
    }
}
