//
//  JourneyThisWeekSectionTests.swift
//  Fitness CoachTests
//
//  Forma — Unified This Week section composition and presentation tests.
//

import XCTest
@testable import Fitness_Coach

final class JourneyThisWeekSectionTests: XCTestCase {

    private let hiSection = JourneyHealthIntelligencePreviewData.strongWeek

    func testExactlyOneWeeklySummarySectionForStrongMomentum() {
        let dashboard = JourneyPreviewData.strongMomentum
        let sections = visibleSections(
            for: dashboard,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: hiSection
        )

        XCTAssertEqual(sections.filter { $0 == .weeklyProgress }.count, 1)
        XCTAssertFalse(sections.contains(.weeklyReview))
    }

    func testHealthIntelligenceWeeklyReviewHiddenWhenUnifiedCardVisible() {
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsHealthIntelligenceWeeklyReviewCard(
                showsUnifiedThisWeekCard: true
            )
        )
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsHealthIntelligenceProgressCard(
                showsUnifiedThisWeekCard: true
            )
        )
    }

    func testWeeklyDateRangeMatchesScreenPresentation() {
        let dashboard = JourneyPreviewData.strongMomentum
        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertEqual(
            unified.dateRangeText,
            dashboard.screenPresentation.weekly.dateRangeText
        )
        XCTAssertFalse(unified.dateRangeText.isEmpty)
    }

    func testEarlyStateUsesGettingStartedTitle() {
        let dashboard = JourneyPreviewData.brandNewUser
        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertTrue(unified.isInsufficientData)
        XCTAssertEqual(
            unified.cardStateTitle,
            FormaProductCopy.Journey.ThisWeek.gettingStarted
        )
        XCTAssertEqual(
            unified.confidenceLabel,
            FormaProductCopy.Journey.WeeklyConfidence.building
        )
        XCTAssertFalse(unified.cardSummary.isEmpty)
    }

    func testEarlyStateCompactStatsIncludeMealsAndWorkouts() {
        let dashboard = JourneyPreviewData.brandNewUser
        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertFalse(unified.compactStats.isEmpty)
        XCTAssertTrue(unified.compactStats.contains { $0.id == "meals" })
        XCTAssertTrue(unified.compactStats.contains { $0.id == "workouts" })
    }

    func testStrongStateUsesWeeklyReviewReadyOrBuildingConsistency() {
        let dashboard = JourneyPreviewData.strongMomentum
        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        let allowedTitles = [
            FormaProductCopy.Journey.ThisWeek.weeklyReviewReady,
            FormaProductCopy.Journey.ThisWeek.buildingConsistency
        ]
        XCTAssertTrue(allowedTitles.contains(unified.cardStateTitle))
        XCTAssertFalse(unified.cardSummary.isEmpty)
    }

    func testSectionTitleIsThisWeek() {
        let dashboard = JourneyPreviewData.strongMomentum
        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertEqual(
            unified.weekTitle,
            FormaProductCopy.Journey.WeeklyReview.sectionTitle
        )
        XCTAssertEqual(unified.weekTitle, "This Week")
    }

    func testPrimaryCTALogFirstMealForBrandNewUser() {
        let dashboard = JourneyPreviewData.brandNewUser
        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertEqual(unified.primaryCTA?.kind, .logFood)
        XCTAssertEqual(
            unified.primaryCTA?.title,
            FormaProductCopy.Journey.NextBestAction.logFirstMeal
        )
        XCTAssertTrue(unified.suppressDuplicateUnlockCTA)
        XCTAssertNotNil(unified.unlockChecklist)
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
            case .weeklyProgress:
                return state.showsWeeklyProgressSection
            case .healthIntelligence:
                return JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
                    isUIEnabled: healthIntelligenceUIEnabled,
                    sectionState: healthIntelligenceSectionState
                )
            case .milestones:
                return state.showsMilestonesSection
            case .weeklyReview:
                return JourneyDashboardCompositionPolicy.showsLegacyWeeklyReviewSection(
                    dashboard: state,
                    showsWeeklyProgressHero: state.showsWeeklyProgressSection,
                    isHealthIntelligenceUIEnabled: healthIntelligenceUIEnabled,
                    healthIntelligenceSectionState: healthIntelligenceSectionState
                )
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
