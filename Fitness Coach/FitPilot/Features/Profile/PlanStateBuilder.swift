//
//  PlanStateBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Builds strategy-first Plan state from profile.
//

import Foundation

enum PlanStateBuilder {

    static func dashboardState(profile: UserProfile) -> ProfileDashboardState {
        let strategyName = strategyName(for: profile)
        let targets = profile.targets

        return ProfileDashboardState(
            profile: profile,
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
            rationale: planRationale(for: profile),
            adaptiveCoach: adaptiveCoachState(),
            lifestyle: PlanLifestyleState(
                activityLevel: ProfileFormatter.activityLevel(profile.activityLevel),
                trainingFrequency: trainingFrequencyLabel(profile.trainingFrequencyPerWeek),
                averageSteps: ProfileFormatter.stepsCompact(profile.averageSteps),
                dietPreference: ProfileFormatter.dietPreference(profile.dietPreference)
            ),
            whatHappensNext: whatHappensNext(for: profile, currentStrategyName: strategyName),
            aboutYou: PlanAboutYouState(
                age: ProfileFormatter.age(profile.age),
                height: ProfileFormatter.cm(profile.heightCm),
                sex: ProfileFormatter.sex(profile.sex),
                bodyFat: ProfileFormatter.percent(profile.estimatedBodyFatPercentage),
                units: ProfileFormatter.unitSystem(profile.unitSystem)
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

    static func planRationale(for profile: UserProfile) -> String {
        let activity = ProfileFormatter.activityLevel(profile.activityLevel).lowercased()
        let training = profile.trainingFrequencyPerWeek
        let isLoss = profile.goalWeightKg < profile.currentWeightKg - 0.5
        let isGain = profile.goalWeightKg > profile.currentWeightKg + 0.5

        let goalPhrase: String
        if isLoss {
            goalPhrase = "sustainable fat loss"
        } else if isGain {
            goalPhrase = "lean muscle gain"
        } else {
            goalPhrase = "weight maintenance"
        }

        if let bodyFat = profile.estimatedBodyFatPercentage {
            let bfText = bodyFat.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(bodyFat))%"
                : String(format: "%.1f%%", bodyFat)
            return "Based on your current weight, body fat around \(bfText), \(activity) activity level, and \(training) strength sessions per week, this calorie target balances \(goalPhrase) with recovery from strength training."
        }

        return "Based on your current weight, \(activity) activity level, and goal, this calorie target balances \(goalPhrase) with recovery from strength training."
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

    // MARK: What Happens Next

    static func whatHappensNext(
        for profile: UserProfile,
        currentStrategyName: String
    ) -> WhatHappensNextState {
        let nextPhase = nextLikelyPhase(after: currentStrategyName)
        let roadmap = roadmapPhaseNames(for: profile, currentStrategyName: currentStrategyName)

        return WhatHappensNextState(
            currentPhaseName: currentStrategyName,
            currentPhaseGoal: phaseGoal(for: currentStrategyName, role: .current),
            nextCheckpoint: "Review after 4 weeks or when your weight trend stalls.",
            nextPhaseName: nextPhase.name,
            nextPhaseGoal: nextPhase.goal,
            roadmapSummary: roadmap.isEmpty ? nil : roadmap.joined(separator: " → ")
        )
    }

    private enum PhaseCopyRole {
        case current
        case next
    }

    private static func roadmapPhaseNames(
        for profile: UserProfile,
        currentStrategyName: String
    ) -> [String] {
        let isLoss = profile.goalWeightKg < profile.currentWeightKg - 0.5
        let isGain = profile.goalWeightKg > profile.currentWeightKg + 0.5

        if isLoss {
            return [currentStrategyName, "Maintenance", "Lean Bulk", "Mini Cut"]
        }
        if isGain {
            return [currentStrategyName, "Maintenance", "Mini Cut", "Lean Bulk"]
        }
        return ["Maintenance", "Lean Bulk", "Mini Cut", currentStrategyName]
    }

    private static func phaseGoal(for phaseName: String, role: PhaseCopyRole) -> String {
        let normalized = phaseName.lowercased()

        if normalized.contains("mini cut") {
            return "Trim fat quickly while protecting muscle and recovery."
        }
        if normalized.contains("cut") {
            return "Lose fat while keeping strength and recovery stable."
        }
        if normalized.contains("build") || normalized.contains("lean bulk") {
            return "Add muscle gradually with a controlled surplus and solid recovery."
        }
        if role == .next {
            return "Hold your new weight and recover before changing strategy."
        }
        return "Keep your weight stable while you train consistently."
    }

    private static func nextLikelyPhase(after currentName: String) -> (name: String, goal: String) {
        let normalized = currentName.lowercased()

        if normalized.contains("mini cut") || normalized.contains("cut") {
            return ("Maintenance", phaseGoal(for: "Maintenance", role: .next))
        }
        if normalized == "maintenance" {
            return ("Lean Bulk", phaseGoal(for: "Lean Bulk", role: .current))
        }
        if normalized.contains("lean bulk") || normalized.contains("build") {
            return ("Mini Cut", phaseGoal(for: "Mini Cut", role: .current))
        }
        return ("Maintenance", phaseGoal(for: "Maintenance", role: .next))
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
