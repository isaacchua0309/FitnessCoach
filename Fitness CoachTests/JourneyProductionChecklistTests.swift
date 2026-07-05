//
//  JourneyProductionChecklistTests.swift
//  Fitness CoachTests
//
//  Sprint sign-off regression tests for the Journey production cleanup pass.
//

import XCTest
@testable import Fitness_Coach

final class JourneyProductionChecklistTests: XCTestCase {

    // MARK: - UI structure

    func testCanonicalSectionOrder() {
        XCTAssertEqual(JourneyProductLayout.sectionOrder, [
            .hero,
            .nextAction,
            .weeklyProgress,
            .progress,
            .highlights,
            .storyTimeline,
            .chapters
        ])
    }

    func testStrongMomentumVisibleSectionsMatchIA() {
        let dashboard = JourneyPreviewData.strongMomentum
        let sections = JourneyDashboardSectionSupport.visibleSections(
            for: dashboard,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: JourneyHealthIntelligencePreviewData.strongWeek
        )

        XCTAssertEqual(sections, [
            .hero,
            .weeklyProgress,
            .progress,
            .highlights,
            .storyTimeline,
            .chapters
        ])
    }

    // MARK: - Removed duplication

    func testLegacySectionsAreNotMountedInProductLayout() {
        let identifiers = Set(JourneyProductLayout.sectionOrder.map(\.rawValue))

        XCTAssertFalse(identifiers.contains("healthIntelligence"))
        XCTAssertFalse(identifiers.contains("header"))
        XCTAssertFalse(identifiers.contains("weeklyReview"))
        XCTAssertFalse(identifiers.contains("insights"))
        XCTAssertFalse(identifiers.contains("monthlyRecap"))
    }

    func testHealthIntelligenceFullSectionPolicyIsDisabled() {
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: true,
                sectionState: JourneyHealthIntelligencePreviewData.strongWeek
            )
        )
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsLegacyWeeklyReviewSection(
                dashboard: JourneyPreviewData.strongMomentum,
                showsWeeklyProgressHero: true,
                isHealthIntelligenceUIEnabled: true,
                healthIntelligenceSectionState: JourneyHealthIntelligencePreviewData.strongWeek
            )
        )
    }

    func testPreviewPersonasExcludeForbiddenCopy() {
        let personas: [JourneyDashboardState] = [
            JourneyPreviewData.brandNewUser,
            JourneyPreviewData.weekOne,
            JourneyPreviewData.strongMomentum,
            JourneyPreviewData.highlyConsistent,
            JourneyPreviewData.sparseData,
        ]

        for dashboard in personas {
            JourneyPresentationTestSupport.assertNoForbiddenCopy(in: dashboard)
            JourneyPresentationTestSupport.assertNoDuplicateWeeklySections(dashboard)
        }
    }

    func testSyncNoticeCopyIsUserFriendly() {
        XCTAssertEqual(
            FormaProductCopy.Journey.Sync.healthDataSyncing,
            "Some health data is still syncing."
        )
        XCTAssertFalse(
            FormaProductCopy.Journey.Sync.healthDataSyncing.localizedCaseInsensitiveContains("remote sync")
        )
    }

    // MARK: - Layout

    func testScrollBottomInsetClearsFloatingTabBar() {
        let inset = JourneyLayout.scrollBottomInset(
            bottomSafeArea: FormaTokens.Layout.homeIndicatorSafeAreaEstimate,
            dynamicTypeSize: .large
        )

        XCTAssertGreaterThan(inset, FormaTokens.Layout.floatingTabBarHeight)
    }

    // MARK: - Themes

    func testDashboardSectionsUseFormaThemeTokens() {
        XCTAssertGreaterThan(JourneyLayout.sectionSpacing, 0)
        XCTAssertEqual(JourneyLayout.tabBarBreathingRoom, FormaTokens.Spacing.xl)
    }

    // MARK: - Accessibility

    func testImportantCardsExposeAccessibilitySummaries() {
        let dashboard = JourneyPreviewData.weekOne

        XCTAssertFalse(dashboard.dashboardHero.accessibilitySummary.isEmpty)
        XCTAssertFalse(dashboard.progressSection.accessibilitySummary.isEmpty)
        XCTAssertFalse(dashboard.chapter.accessibilitySummary.isEmpty)

        if let nextAction = dashboard.screenPresentation.unlockDashboard.nextActionCard {
            XCTAssertFalse(nextAction.accessibilityLabel.isEmpty)
        }
    }

    func testProgressRowsUseSymbolAndTextNotColorAlone() {
        let row = JourneyPreviewData.weekOne.progressSection.rows.first!
        XCTAssertFalse(row.accessibilityLabel.isEmpty)
        XCTAssertFalse(row.title.isEmpty)
        XCTAssertFalse(row.value.isEmpty)
    }
}

@MainActor
final class JourneyModelPresentationCachingTests: XCTestCase {

    func testPreviewModelPopulatesPresentationReadyDashboard() {
        let model = JourneyModel.preview(scenario: .strongMomentum)

        XCTAssertNotNil(model.presentationReadyDashboard)
        XCTAssertTrue(model.presentationReadyDashboard!.showsDashboardHeroSection)
        XCTAssertFalse(model.presentationReadyDashboard!.dashboardHero.weekLabel.isEmpty)
    }
}
