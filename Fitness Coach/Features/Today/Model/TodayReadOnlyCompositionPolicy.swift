//
//  TodayReadOnlyCompositionPolicy.swift
//  Fitness Coach
//
//  Forma — Section visibility rules when Health Intelligence UI is enabled.
//

import Foundation

enum TodayReadOnlyCompositionPolicy {

    static func showsHealthIntelligenceSection(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?
    ) -> Bool {
        isUIEnabled && sectionState != nil
    }

    static func showsLegacyNextBestAction(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?
    ) -> Bool {
        !showsHealthIntelligenceSection(isUIEnabled: isUIEnabled, sectionState: sectionState)
    }

    /// Hides legacy activity when Health Intelligence already surfaces workout completion.
    static func showsActivitySection(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?,
        activity: TodayActivityState
    ) -> Bool {
        guard showsHealthIntelligenceSection(isUIEnabled: isUIEnabled, sectionState: sectionState),
              let sectionState else {
            return true
        }

        if sectionState.workoutCard != nil {
            return false
        }

        if activity.hasWorkout, sectionState.dailyMission.detailLines.contains(
            FormaProductCopy.Today.HealthIntelligence.DailyMission.workoutCompleteDetail
        ) {
            return false
        }

        return true
    }
}
