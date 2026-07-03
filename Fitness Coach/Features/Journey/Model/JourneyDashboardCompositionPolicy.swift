//
//  JourneyDashboardCompositionPolicy.swift
//  Fitness Coach
//
//  Forma — Section visibility rules when Health Intelligence UI is enabled.
//

import Foundation

enum JourneyDashboardCompositionPolicy {

    static func showsHealthIntelligenceSection(
        isUIEnabled: Bool,
        sectionState: JourneyHealthIntelligenceSectionState?
    ) -> Bool {
        isUIEnabled && sectionState != nil
    }

    /// Legacy training insights duplicate recovery timeline and workout history cards.
    static func showsLegacyInsightsSection(
        isUIEnabled: Bool,
        sectionState: JourneyHealthIntelligenceSectionState?,
        dashboardShowsInsights: Bool
    ) -> Bool {
        guard dashboardShowsInsights else { return false }
        return !showsHealthIntelligenceSection(isUIEnabled: isUIEnabled, sectionState: sectionState)
    }

    static func hidesTrainingHabitRow(
        isUIEnabled: Bool,
        sectionState: JourneyHealthIntelligenceSectionState?
    ) -> Bool {
        showsHealthIntelligenceSection(isUIEnabled: isUIEnabled, sectionState: sectionState)
    }

    static func hidesWorkoutMetrics(
        isUIEnabled: Bool,
        sectionState: JourneyHealthIntelligenceSectionState?
    ) -> Bool {
        showsHealthIntelligenceSection(isUIEnabled: isUIEnabled, sectionState: sectionState)
    }
}
