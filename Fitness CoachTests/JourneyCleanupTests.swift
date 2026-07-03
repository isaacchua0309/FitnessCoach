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
        XCTAssertFalse(identifiers.contains("monthlyRecap"))
        XCTAssertFalse(identifiers.contains("journeyLevel"))
        XCTAssertFalse(identifiers.contains("detailedAnalytics"))
    }

    func testBrandNewUserShowsStartingEmptyState() {
        let dashboard = JourneyPreviewData.brandNewUser

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

    func testJourneyDashboardStateOnlyContainsLeanFields() {
        let dashboard = JourneyPreviewData.strongMomentum
        let mirror = Mirror(reflecting: dashboard)
        let propertyNames = Set(mirror.children.compactMap(\.label))

        XCTAssertEqual(
            propertyNames,
            [
                "hasProfile",
                "baseline",
                "transformation",
                "weeklyReview",
                "streaks",
                "milestones",
                "storyTimeline"
            ]
        )
    }
}
