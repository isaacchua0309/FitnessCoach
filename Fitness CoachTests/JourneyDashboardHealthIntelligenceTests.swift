//
//  JourneyDashboardHealthIntelligenceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyDashboardHealthIntelligenceTests: XCTestCase {

    func testHealthIntelligenceSectionAppearsAfterWeeklyProgressInLayout() {
        let order = JourneyProductLayout.sectionOrder
        let goalIndex = order.firstIndex(of: .goalProjection)
        let weeklyProgressIndex = order.firstIndex(of: .weeklyProgress)
        let healthIndex = order.firstIndex(of: .healthIntelligence)
        let milestonesIndex = order.firstIndex(of: .milestones)

        XCTAssertEqual(goalIndex, 2)
        XCTAssertEqual(weeklyProgressIndex, 3)
        XCTAssertEqual(healthIndex, 4)
        XCTAssertEqual(milestonesIndex, 5)
    }

    func testVisibleSectionsExcludeHealthIntelligenceWhenFlagDisabled() {
        let sections = visibleSections(
            for: JourneyPreviewData.strongMomentum,
            healthIntelligenceUIEnabled: false,
            healthIntelligenceSectionState: JourneyHealthIntelligencePreviewData.strongWeek
        )

        XCTAssertFalse(sections.contains(.healthIntelligence))
    }

    func testVisibleSectionsIncludeHealthIntelligenceWhenFlagEnabledAndStatePresent() {
        let sections = visibleSections(
            for: JourneyPreviewData.strongMomentum,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: JourneyHealthIntelligencePreviewData.strongWeek
        )

        XCTAssertTrue(sections.contains(.healthIntelligence))
        XCTAssertLessThan(
            sections.firstIndex(of: .healthIntelligence)!,
            sections.firstIndex(of: .milestones)!
        )
    }

    func testVisibleSectionsExcludeHealthIntelligenceWhenStateMissing() {
        let sections = visibleSections(
            for: JourneyPreviewData.strongMomentum,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceSectionState: nil
        )

        XCTAssertFalse(sections.contains(.healthIntelligence))
    }

    func testWeeklyReviewTrainingHabitHiddenWhenHealthIntelligenceEnabled() {
        let dashboard = JourneyPreviewData.strongMomentum
        XCTAssertTrue(dashboard.weeklyHabit.habits.contains { $0.id == "training" })

        let visibleHabits = dashboard.weeklyHabit.habits.filter { $0.id != "training" }
        XCTAssertFalse(visibleHabits.contains { $0.id == "training" })
        XCTAssertTrue(visibleHabits.contains { $0.id == "food" })
    }

    func testMonthlyRecapWorkoutMetricsHiddenWhenHealthIntelligenceEnabled() {
        let recap = JourneyPreviewData.strongMomentum.monthlyRecap
        XCTAssertTrue(recap.rows.contains { $0.id == "workouts" })

        let visibleRows = recap.rows.filter { $0.id != "workouts" }
        XCTAssertFalse(visibleRows.contains { $0.id == "workouts" })
    }

    func testHealthIntelligenceSectionStateIncludesExpectedSubsections() {
        let section = JourneyHealthIntelligencePreviewData.strongWeek

        XCTAssertNotNil(section.weeklyReviewCard)
        XCTAssertEqual(section.weeklyReviewCard?.phase, .loaded)
        XCTAssertNotNil(section.weeklyReviewDetail)
        XCTAssertEqual(section.recoveryTimeline.phase, .loaded)
        XCTAssertEqual(section.workoutHistory.phase, .loaded)
        XCTAssertEqual(section.milestones.phase, .loaded)
        XCTAssertEqual(section.progress.phase, .loaded)
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
