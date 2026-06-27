//
//  ProfileDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Strategy-first view state for the Plan screen.
//

import Foundation

struct ProfileDashboardState: Equatable {
    var profile: UserProfile
    var strategy: PlanStrategyState
    var todaysTargets: PlanTodaysTargetsState
    var rationale: PlanRationaleState
    var adaptiveCoach: PlanAdaptiveCoachState
    var lifestyle: PlanLifestyleState
    var whatHappensNext: WhatHappensNextState
    var aboutYou: PlanAboutYouState
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

// MARK: Adaptive Coach

struct PlanAdaptiveCoachState: Equatable {
    var currentStatus: String
    var futureTriggers: [String]
}

// MARK: Lifestyle

struct PlanLifestyleState: Equatable {
    var activityLevel: String
    var trainingFrequency: String
    var averageSteps: String
    var dietPreference: String
}

// MARK: What Happens Next

struct WhatHappensNextState: Equatable {
    var currentPhaseName: String
    var currentPhaseGoal: String
    var nextCheckpoint: String
    var nextPhaseName: String
    var nextPhaseGoal: String
    var roadmapSummary: String?
}

// MARK: About You

struct PlanAboutYouState: Equatable {
    var age: String
    var height: String
    var sex: String
    var bodyFat: String?
    var units: String
}

// MARK: Wizard

enum PlanGoalType: String, CaseIterable, Identifiable {
    case loseFat = "Lose Fat"
    case maintain = "Maintain"
    case gainMuscle = "Gain Muscle"

    var id: String { rawValue }
}
