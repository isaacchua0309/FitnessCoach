//
//  TodayReadOnlyCompositionPolicy.swift
//  Fitness Coach
//
//  Forma — Section visibility rules for the Today read-only dashboard.
//

import Foundation

enum TodayReadOnlyCompositionPolicy {

    static func showsHealthIntelligenceSection(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?
    ) -> Bool {
        isUIEnabled && sectionState != nil
    }

    /// Full Health Intelligence stack at the top — retired in favor of split sections.
    static func showsLegacyHealthIntelligenceStack(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?
    ) -> Bool {
        false
    }

    /// Legacy next best action card — folded into mission hero + quick actions.
    static func showsLegacyNextBestAction(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?
    ) -> Bool {
        false
    }

    static func showsRecoverySection(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?
    ) -> Bool {
        isUIEnabled && sectionState != nil
    }

    static func showsHealthWorkoutCard(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?
    ) -> Bool {
        guard showsRecoverySection(isUIEnabled: isUIEnabled, sectionState: sectionState),
              let sectionState else {
            return false
        }
        return sectionState.workoutCard != nil
    }

    static func showsStandaloneHIFallback(
        sectionState: TodayHealthIntelligenceSectionState
    ) -> Bool {
        guard let message = sectionState.fallbackMessage else { return false }
        guard !sectionState.nextBestAction.isVisible else { return false }
        if message == FormaProductCopy.Today.HealthIntelligence.connectHealthFallback {
            return false
        }
        return true
    }

    static func showsHealthNextBestAction(
        sectionState: TodayHealthIntelligenceSectionState
    ) -> Bool {
        guard sectionState.nextBestAction.isVisible else { return false }
        return sectionState.nextBestAction.destination != .connectHealth
    }

    /// Legacy activity/workout card — hides when Health Intelligence already surfaces workout completion.
    static func showsActivitySection(
        isUIEnabled: Bool,
        sectionState: TodayHealthIntelligenceSectionState?,
        activity: TodayActivityState
    ) -> Bool {
        guard showsRecoverySection(isUIEnabled: isUIEnabled, sectionState: sectionState),
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

    static func showsAppleHealthSetupCard(activity: TodayActivityState) -> Bool {
        TodayActivitySectionFormatting.isDisconnected(activity)
            || activity.phase == .healthUnavailable
    }

    static func appleHealthSetupActionTitle(for activity: TodayActivityState) -> String {
        switch activity.trainingIntegration {
        case .denied, .failed:
            return FormaProductCopy.Today.AppleHealthSetup.manageAction
        case .notConnected, .unavailable, .requestingPermission, .connected:
            return FormaProductCopy.Today.AppleHealthSetup.connectAction
        }
    }

    static func missionNextStepLine(
        dashboardNextStep: String,
        healthIntelligenceSection: TodayHealthIntelligenceSectionState?
    ) -> String {
        if let healthIntelligenceSection,
           showsHealthNextBestAction(sectionState: healthIntelligenceSection) {
            let title = healthIntelligenceSection.nextBestAction.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return TodayMissionHeroFormatter.formattedNextStepLine(title)
            }
        }

        let trimmed = dashboardNextStep.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }
}
