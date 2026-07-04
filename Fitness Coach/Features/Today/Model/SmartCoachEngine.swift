//
//  SmartCoachEngine.swift
//  Fitness Coach
//
//  Deterministic contextual Smart Coach banner for Today (no AI).
//

import Foundation

struct SmartCoachInput: Equatable {
    var date: Date
    var calendar: Calendar
    var foodEntries: [FoodEntry]
    var proteinProgress: MacroProgress
    var waterProgress: Double
    var calorieSummary: CalorieSummary
    var workoutSummary: TodayWorkoutSummary
    var activityContext: TodayActivityContext
}

enum SmartCoachEngine {

    static let proteinSignificantlyBehindThreshold = TodayFocusBuilder.proteinOnTrackThreshold
    static let waterSignificantlyBehindThreshold = TodayFocusBuilder.waterOnTrackThreshold
    static let proteinRecoveryThreshold = 1.0
    static let endOfDayStartHour = TodayPresentationBuilder.endOfDayStartHour

    static func resolve(_ input: SmartCoachInput) -> TodaySmartCoachState {
        guard hasGuidanceContext(input) else {
            return .hidden
        }

        if input.calorieSummary.isOverTarget {
            return state(
                context: .caloriesExceeded,
                message: FormaProductCopy.Today.SmartCoach.caloriesExceeded,
                coachPrefill: TodayCoachPrompt.reviewToday,
                coachActionTitle: FormaProductCopy.Today.SmartCoach.coachReviewAction
            )
        }

        if shouldShowWorkoutRecovery(input) {
            return state(
                context: .workoutRecovery,
                message: FormaProductCopy.Today.SmartCoach.workoutRecovery,
                coachPrefill: TodayCoachPrompt.logProtein,
                coachActionTitle: FormaProductCopy.Today.SmartCoach.coachProteinAction
            )
        }

        if isProteinSignificantlyBehind(input) {
            return state(
                context: .proteinBehind,
                message: FormaProductCopy.Today.SmartCoach.proteinBehind,
                coachPrefill: TodayCoachPrompt.logProtein,
                coachActionTitle: FormaProductCopy.Today.SmartCoach.coachProteinAction
            )
        }

        if isWaterSignificantlyBehind(input) {
            return state(
                context: .waterBehind,
                message: FormaProductCopy.Today.SmartCoach.waterBehind,
                coachPrefill: nil,
                coachActionTitle: nil
            )
        }

        if isCaloriesCloseToTarget(input) {
            return state(
                context: .caloriesCloseToTarget,
                message: FormaProductCopy.Today.SmartCoach.caloriesCloseToTarget,
                coachPrefill: nil,
                coachActionTitle: nil
            )
        }

        if isEndOfDayIncompleteHabits(input) {
            return state(
                context: .endOfDayIncomplete,
                message: FormaProductCopy.Today.SmartCoach.endOfDayIncomplete,
                coachPrefill: TodayCoachPrompt.reviewToday,
                coachActionTitle: FormaProductCopy.Today.SmartCoach.coachReviewAction
            )
        }

        return .hidden
    }

    static func hasGuidanceContext(_ input: SmartCoachInput) -> Bool {
        !input.foodEntries.isEmpty || hasWorkoutToday(input)
    }

    static func isProteinSignificantlyBehind(_ input: SmartCoachInput) -> Bool {
        guard !input.foodEntries.isEmpty else { return false }
        guard input.proteinProgress.target > 0 else { return false }
        return input.proteinProgress.progress < proteinSignificantlyBehindThreshold
    }

    static func isWaterSignificantlyBehind(_ input: SmartCoachInput) -> Bool {
        guard !input.foodEntries.isEmpty else { return false }
        return input.waterProgress < waterSignificantlyBehindThreshold
    }

    static func isCaloriesCloseToTarget(_ input: SmartCoachInput) -> Bool {
        guard !input.foodEntries.isEmpty else { return false }
        guard !input.calorieSummary.isOverTarget else { return false }
        return TodayMissionHeroFormatter.isNearTarget(input.calorieSummary)
    }

    static func shouldShowWorkoutRecovery(_ input: SmartCoachInput) -> Bool {
        guard hasWorkoutToday(input) else { return false }
        guard input.proteinProgress.target > 0 else { return false }
        return input.proteinProgress.progress < proteinRecoveryThreshold
    }

    static func isEndOfDayIncompleteHabits(_ input: SmartCoachInput) -> Bool {
        let hour = input.calendar.component(.hour, from: input.date)
        guard hour >= endOfDayStartHour else { return false }
        guard !input.foodEntries.isEmpty else { return false }

        let caloriesIncomplete = input.calorieSummary.consumed > 0
            && !input.calorieSummary.isOverTarget
            && !TodayPresentationBuilder.isCalorieTargetMet(input.calorieSummary)
            && !TodayMissionHeroFormatter.isNearTarget(input.calorieSummary)

        return caloriesIncomplete
    }

    static func hasWorkoutToday(_ input: SmartCoachInput) -> Bool {
        input.workoutSummary.hasWorkout || (input.activityContext.appleHealthWorkoutCount ?? 0) > 0
    }

    private static func state(
        context: TodaySmartCoachContext,
        message: String,
        coachPrefill: String?,
        coachActionTitle: String?
    ) -> TodaySmartCoachState {
        TodaySmartCoachState(
            context: context,
            message: message,
            coachPrefill: coachPrefill,
            coachActionTitle: coachActionTitle
        )
    }
}
