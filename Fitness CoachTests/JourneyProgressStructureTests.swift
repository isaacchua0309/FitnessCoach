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

    func testBrandNewUserShowsStartingEmptyState() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertTrue(dashboard.showsStartingEmptyState)
        XCTAssertFalse(dashboard.showsMilestonesSection)
        XCTAssertFalse(dashboard.showsStoryTimelineSection)
    }

    func testStrongMomentumHidesStartingEmptyState() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertFalse(dashboard.showsStartingEmptyState)
        XCTAssertTrue(dashboard.showsMilestonesSection)
        XCTAssertTrue(dashboard.showsStoryTimelineSection)
    }
}
