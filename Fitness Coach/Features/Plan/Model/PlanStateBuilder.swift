//
//  PlanStateBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Builds strategy-first Plan state from profile.
//

import Foundation

enum PlanStateBuilder {

    static func dashboardState(
        profile: UserProfile,
        context: PlanDashboardContext? = nil,
        referenceDate: Date = Date()
    ) -> ProfileDashboardState {
        let strategyName = strategyName(for: profile)
        let targets = profile.targets
        let dashboardContext = context ?? PlanDashboardContext.profileOnly(
            profile: profile,
            referenceDate: referenceDate
        )
        let missionControl = PlanDashboardBuilder.missionControlDashboard(
            context: dashboardContext,
            referenceDate: referenceDate
        )

        return ProfileDashboardState(
            profile: profile,
            missionControl: missionControl,
            strategy: PlanStrategyState(
                strategyName: strategyName,
                calorieTargetText: "\(targets.calorieTarget) kcal/day",
                proteinTargetText: "\(formatGrams(targets.proteinTarget)) protein",
                trainingFrequencyText: "\(max(profile.trainingFrequencyPerWeek, 0)) strength workouts/week",
                startedLabel: "Started \(profile.createdAt.formatted(.dateTime.month(.abbreviated).day()))",
                coachSummary: strategySummary(for: profile)
            ),
            todaysTargets: PlanTodaysTargetsState(
                calories: ProfileFormatter.kcal(targets.calorieTarget),
                protein: ProfileFormatter.gramsCompact(targets.proteinTarget),
                water: ProfileFormatter.mlCompact(targets.waterTargetMl),
                trainingFrequency: trainingFrequencyLabel(profile.trainingFrequencyPerWeek)
            ),
            rationale: missionControl.rationale,
            adaptiveCoach: adaptiveCoachState(),
            lifestyle: PlanLifestyleState(
                activityLevel: ProfileFormatter.activityLevel(profile.activityLevel),
                trainingFrequency: trainingFrequencyLabel(profile.trainingFrequencyPerWeek),
                averageSteps: ProfileFormatter.stepsCompact(profile.averageSteps),
                dietPreference: ProfileFormatter.dietPreference(profile.dietPreference)
            )
        )
    }

    // MARK: Strategy

    static func strategyName(for profile: UserProfile) -> String {
        let pace = ProfileFormatter.aggressiveness(profile.targets.aggressiveness)
        if profile.goalWeightKg < profile.currentWeightKg - 0.5 {
            return "\(pace) Cut"
        }
        if profile.goalWeightKg > profile.currentWeightKg + 0.5 {
            return "\(pace) Build"
        }
        return "Maintenance"
    }

    static func strategySummary(for profile: UserProfile) -> String {
        let isLoss = profile.goalWeightKg < profile.currentWeightKg
        switch profile.targets.aggressiveness {
        case .conservative:
            return isLoss
                ? "Designed for sustainable fat loss while preserving strength."
                : "Designed for gradual progress without rushing recovery."
        case .moderate:
            return isLoss
                ? "Built around recovery and strength — not just fat loss."
                : "Supports lean muscle gain with a controlled surplus."
        case .aggressive:
            return isLoss
                ? "A faster cut — protect sleep, protein, and training quality."
                : "A stronger surplus — consistency and recovery matter most."
        }
    }

    static func adaptiveCoachState() -> PlanAdaptiveCoachState {
        PlanAdaptiveCoachState(
            currentStatus: "No changes recommended.",
            futureTriggers: [
                "Calories may automatically adjust if weight plateaus",
                "Targets may change if weight drops too quickly",
                "Activity shifts will recalibrate your plan"
            ]
        )
    }

    static func goalType(for profile: UserProfile) -> PlanGoalType {
        if profile.goalWeightKg < profile.currentWeightKg - 0.5 { return .loseFat }
        if profile.goalWeightKg > profile.currentWeightKg + 0.5 { return .gainMuscle }
        return .maintain
    }

    // MARK: Helpers

    private static func trainingFrequencyLabel(_ frequency: Int) -> String {
        let count = max(frequency, 0)
        return count == 1 ? "1 session/week" : "\(count) sessions/week"
    }

    private static func formatGrams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))g"
            : String(format: "%.0fg", value)
    }
}
