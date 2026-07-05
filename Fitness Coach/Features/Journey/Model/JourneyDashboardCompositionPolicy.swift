//
//  JourneyDashboardCompositionPolicy.swift
//  Fitness Coach
//
//  Forma — Section visibility rules for the consolidated Journey dashboard IA.
//

import Foundation

enum JourneyDashboardCompositionPolicy {

    static func showsHighlightsSection(
        isUIEnabled: Bool,
        sectionState: JourneyHealthIntelligenceSectionState?
    ) -> Bool {
        guard isUIEnabled, let sectionState else { return false }
        guard sectionState.milestones.phase == .loaded else { return false }
        return !sectionState.milestones.items.isEmpty
    }

    static func connectHealthCTA(
        from sectionState: JourneyHealthIntelligenceSectionState?
    ) -> JourneyHealthConnectCTAState? {
        sectionState?.connectHealthCTA
    }

    // MARK: - Legacy (retained for tests referencing old composition helpers)

    static func showsHealthIntelligenceSection(
        isUIEnabled: Bool,
        sectionState: JourneyHealthIntelligenceSectionState?
    ) -> Bool {
        false
    }

    static func showsLegacyInsightsSection(
        isUIEnabled: Bool,
        sectionState: JourneyHealthIntelligenceSectionState?,
        dashboardShowsInsights: Bool
    ) -> Bool {
        false
    }

    static func hidesTrainingHabitRow(
        isUIEnabled: Bool,
        sectionState: JourneyHealthIntelligenceSectionState?
    ) -> Bool {
        true
    }

    static func hidesWorkoutMetrics(
        isUIEnabled: Bool,
        sectionState: JourneyHealthIntelligenceSectionState?
    ) -> Bool {
        true
    }

    static func collapsesLegacyWeeklyHabitRows(showsWeeklyProgressHero: Bool) -> Bool {
        true
    }

    static func showsHealthIntelligenceWeeklyReviewCard(showsUnifiedThisWeekCard: Bool) -> Bool {
        false
    }

    static func showsHealthIntelligenceProgressCard(showsUnifiedThisWeekCard: Bool) -> Bool {
        false
    }

    static func showsLegacyWeeklyReviewSection(
        dashboard: JourneyDashboardState,
        showsWeeklyProgressHero: Bool,
        isHealthIntelligenceUIEnabled: Bool,
        healthIntelligenceSectionState: JourneyHealthIntelligenceSectionState?
    ) -> Bool {
        false
    }
}
