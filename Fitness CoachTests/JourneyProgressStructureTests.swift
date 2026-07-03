//
//  JourneyProgressStructureTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyProgressStructureTests: XCTestCase {

    func testProductSectionOrderMatchesCanonicalLayout() {
        XCTAssertEqual(JourneyProductLayout.sectionOrder, [
            .header,
            .transformation,
            .goalProjection,
            .healthIntelligence,
            .milestones,
            .weeklyReview,
            .storyTimeline,
            .insights,
            .monthlyRecap,
            .chapters,
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
        XCTAssertFalse(identifiers.contains("journeyLevel"))
        XCTAssertFalse(identifiers.contains("detailedAnalytics"))
        XCTAssertFalse(identifiers.contains("consistencyCalendar"))
        XCTAssertFalse(identifiers.contains("coachInsights"))
        XCTAssertFalse(identifiers.contains("achievements"))
    }

    func testBrandNewUserShowsLeanAboveTheFoldLayout() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertTrue(dashboard.showsStartingEmptyState)
        XCTAssertTrue(dashboard.showsMilestonesSection)
        XCTAssertFalse(dashboard.showsStoryTimelineSection)
        XCTAssertFalse(dashboard.showsGoalProjectionSection)
        XCTAssertFalse(dashboard.showsWeeklyReviewSection)
        XCTAssertFalse(dashboard.showsInsightSection)
        XCTAssertFalse(dashboard.showsMonthlyRecapSection)
        XCTAssertFalse(dashboard.showsChapterSection)
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
        XCTAssertTrue(dashboard.showsMonthlyRecapSection)
        XCTAssertTrue(dashboard.showsChapterSection)
    }
}
