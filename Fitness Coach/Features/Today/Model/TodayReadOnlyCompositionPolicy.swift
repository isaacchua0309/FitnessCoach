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

    /// Legacy next best action card — pending removal after Health Intelligence rollout.
    static func showsLegacyNextBestAction(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?
    ) -> Bool {
        !showsHealthIntelligenceSection(isUIEnabled: isUIEnabled, sectionState: sectionState)
    }

    /// Legacy activity/workout card — pending removal after Health Intelligence rollout.
    /// Hides when Health Intelligence already surfaces workout completion.
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
