//
//  JourneyHealthIntelligenceCompositionTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyHealthIntelligenceCompositionTests: XCTestCase {

    private let section = JourneyHealthIntelligencePreviewData.strongWeek
    private let dashboard = JourneyPreviewData.strongMomentum

    func testFlagOffPreservesLegacyInsightsSection() {
        XCTAssertTrue(
            JourneyDashboardCompositionPolicy.showsLegacyInsightsSection(
                isUIEnabled: false,
                sectionState: section,
                dashboardShowsInsights: dashboard.showsInsightSection
            )
        )
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: false,
                sectionState: section
            )
        )
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.hidesTrainingHabitRow(
                isUIEnabled: false,
                sectionState: section
            )
        )
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.hidesWorkoutMetrics(
                isUIEnabled: false,
                sectionState: section
            )
        )
    }

    func testFlagOnWithSectionHidesLegacyInsightsAndTrainingDuplicates() {
        XCTAssertTrue(
            JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: true,
                sectionState: section
            )
        )
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsLegacyInsightsSection(
                isUIEnabled: true,
                sectionState: section,
                dashboardShowsInsights: dashboard.showsInsightSection
            )
        )
        XCTAssertTrue(
            JourneyDashboardCompositionPolicy.hidesTrainingHabitRow(
                isUIEnabled: true,
                sectionState: section
            )
        )
        XCTAssertTrue(
            JourneyDashboardCompositionPolicy.hidesWorkoutMetrics(
                isUIEnabled: true,
                sectionState: section
            )
        )
    }

    func testFlagOnWithoutSectionFallsBackToLegacyInsights() {
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: true,
                sectionState: nil
            )
        )
        XCTAssertTrue(
            JourneyDashboardCompositionPolicy.showsLegacyInsightsSection(
                isUIEnabled: true,
                sectionState: nil,
                dashboardShowsInsights: dashboard.showsInsightSection
            )
        )
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.hidesTrainingHabitRow(
                isUIEnabled: true,
                sectionState: nil
            )
        )
    }

    func testVisibleSectionsExcludeInsightsWhenHealthIntelligenceEnabled() {
        let sections = visibleSections(
            for: dashboard,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: section
        )

        XCTAssertTrue(sections.contains(.healthIntelligence))
        XCTAssertFalse(sections.contains(.insights))
    }

    func testVisibleSectionsIncludeInsightsWhenHealthIntelligenceDisabled() {
        let sections = visibleSections(
            for: dashboard,
            healthIntelligenceUIEnabled: false,
            healthIntelligenceSectionState: section
        )

        XCTAssertFalse(sections.contains(.healthIntelligence))
        XCTAssertTrue(sections.contains(.insights))
    }

    // MARK: - Helpers

    private func visibleSections(
        for state: JourneyDashboardState,
        healthIntelligenceUIEnabled: Bool,
        healthIntelligenceSectionState: JourneyHealthIntelligenceSectionState?
    ) -> [JourneyProductSection] {
        JourneyProductLayout.sectionOrder.filter { section in
            switch section {
            case .header, .transformation:
                return true
            case .goalProjection:
                return state.showsGoalProjectionSection
            case .healthIntelligence:
                return JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
                    isUIEnabled: healthIntelligenceUIEnabled,
                    sectionState: healthIntelligenceSectionState
                )
            case .milestones:
                return state.showsMilestonesSection
            case .weeklyReview:
                return state.showsWeeklyReviewSection
            case .storyTimeline:
                return state.showsStoryTimelineSection
            case .insights:
                return JourneyDashboardCompositionPolicy.showsLegacyInsightsSection(
                    isUIEnabled: healthIntelligenceUIEnabled,
                    sectionState: healthIntelligenceSectionState,
                    dashboardShowsInsights: state.showsInsightSection
                )
            case .monthlyRecap:
                return state.showsMonthlyRecapSection
            case .chapters:
                return state.showsChapterSection
            case .startingEmptyState:
                return state.showsStartingEmptyState
            }
        }
    }
}
