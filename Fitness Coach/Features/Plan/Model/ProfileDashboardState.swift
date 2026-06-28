//
//  ProfileDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Mission Control view state for the Plan screen.
//

import Foundation

struct ProfileDashboardState: Equatable {
    var profile: UserProfile
    /// Product-facing Mission Control read model for the Plan dashboard redesign.
    var missionControl: PlanMissionControlDashboard
    var strategy: PlanStrategyState
    var todaysTargets: PlanTodaysTargetsState
    var rationale: PlanRationaleState
    var lifestyle: PlanLifestyleState
}

// MARK: Strategy Hero

struct PlanStrategyState: Equatable {
    var strategyName: String
    var calorieTargetText: String
    var proteinTargetText: String
    var trainingFrequencyText: String
    var startedLabel: String
    var coachSummary: String
}

// MARK: Today's Targets

struct PlanTodaysTargetsState: Equatable {
    var calories: String
    var protein: String
    var water: String
    var trainingFrequency: String
}

// MARK: Lifestyle

struct PlanLifestyleState: Equatable {
    var activityLevel: String
    var trainingFrequency: String
    var averageSteps: String
    var dietPreference: String
}

// MARK: Wizard

enum PlanGoalType: String, CaseIterable, Identifiable {
    case loseFat = "Lose Fat"
    case maintain = "Maintain"
    case gainMuscle = "Gain Muscle"

    var id: String { rawValue }
}
