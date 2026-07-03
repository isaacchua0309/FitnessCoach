//
//  JourneyProgressStructureTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyProgressStructureTests: XCTestCase {

    func testProductSectionOrderMatchesCanonicalLayout() {
        XCTAssertEqual(JourneyProductLayout.sectionOrder, [
            .transformation,
            .goalProjection,
            .weeklyReview,
            .milestones,
            .storyTimeline,
            .startingEmptyState
        ])
        XCTAssertEqual(JourneyProductLayout.sectionOrder.last, .startingEmptyState)
    }

    func testRemovedSectionsAreNotPartOfCanonicalOrder() {
        let identifiers = Set(JourneyProductLayout.sectionOrder.map(\.rawValue))

        XCTAssertFalse(identifiers.contains("habitInsights"))
        XCTAssertFalse(identifiers.contains("whyProgress"))
        XCTAssertFalse(identifiers.contains("beforeToday"))
        XCTAssertFalse(identifiers.contains("personalRecords"))
        XCTAssertFalse(identifiers.contains("monthlyRecap"))
        XCTAssertFalse(identifiers.contains("journeyLevel"))
        XCTAssertFalse(identifiers.contains("detailedAnalytics"))
        XCTAssertFalse(identifiers.contains("consistencyCalendar"))
        XCTAssertFalse(identifiers.contains("coachInsights"))
        XCTAssertFalse(identifiers.contains("achievements"))
    }

    func testBrandNewUserShowsNextAchievementCard() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertFalse(dashboard.showsStartingEmptyState)
        XCTAssertTrue(dashboard.showsMilestonesSection)
        XCTAssertTrue(dashboard.showsStoryTimelineSection)
        XCTAssertEqual(
            dashboard.milestone.title,
            FormaProductCopy.Journey.Milestones.NextAchievement.firstMealTitle
        )
    }

    func testStrongMomentumHidesStartingEmptyState() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertFalse(dashboard.showsStartingEmptyState)
        XCTAssertTrue(dashboard.showsMilestonesSection)
        XCTAssertTrue(dashboard.showsStoryTimelineSection)
    }
}
