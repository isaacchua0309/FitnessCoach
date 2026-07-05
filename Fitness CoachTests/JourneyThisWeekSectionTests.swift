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
        XCTAssertFalse(sections.contains(.highlights))
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
        JourneyDashboardSectionSupport.visibleSections(
            for: state,
            healthIntelligenceUIEnabled: healthIntelligenceUIEnabled,
            healthIntelligenceSectionState: healthIntelligenceSectionState
        )
    }
}
