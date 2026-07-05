//
//  JourneyHealthIntelligenceCompositionTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyHealthIntelligenceCompositionTests: XCTestCase {

    private let section = JourneyHealthIntelligencePreviewData.strongWeek
    private let dashboard = JourneyPreviewData.strongMomentum

    func testHealthIntelligenceDiagnosticsSectionIsNotMountedOnDashboard() {
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: true,
                sectionState: section
            )
        )
    }

    func testHighlightsVisibleWhenMilestonesLoaded() {
        XCTAssertTrue(
            JourneyDashboardCompositionPolicy.showsHighlightsSection(
                isUIEnabled: true,
                sectionState: section
            )
        )
    }

    func testHighlightsHiddenWhenMilestonesEmpty() {
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsHighlightsSection(
                isUIEnabled: true,
                sectionState: JourneyHealthIntelligencePreviewData.unavailable
            )
        )
    }

    func testVisibleSectionsIncludeHighlightsNotLegacyHealthIntelligence() {
        let sections = JourneyDashboardSectionSupport.visibleSections(
            for: dashboard,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: section
        )

        XCTAssertTrue(sections.contains(.highlights))
        XCTAssertTrue(sections.contains(.hero))
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: true,
                sectionState: section
            )
        )
    }

    func testWeeklyProgressAppearsBeforeHighlights() {
        let sections = JourneyDashboardSectionSupport.visibleSections(
            for: dashboard,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: section
        )

        guard let weeklyIndex = sections.firstIndex(of: .weeklyProgress),
              let highlightsIndex = sections.firstIndex(of: .highlights) else {
            return XCTFail("Expected weekly progress and highlights sections")
        }
        XCTAssertLessThan(weeklyIndex, highlightsIndex)
    }

    func testLegacyWeeklyReviewAndInsightsSectionsAreSuppressed() {
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsLegacyWeeklyReviewSection(
                dashboard: dashboard,
                showsWeeklyProgressHero: true,
                isHealthIntelligenceUIEnabled: true,
                healthIntelligenceSectionState: section
            )
        )
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsLegacyInsightsSection(
                isUIEnabled: true,
                sectionState: section,
                dashboardShowsInsights: dashboard.showsInsightSection
            )
        )
    }
}
