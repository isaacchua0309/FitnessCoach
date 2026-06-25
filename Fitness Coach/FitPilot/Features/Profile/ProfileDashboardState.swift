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
    var rationale: String
    var adaptiveCoach: PlanAdaptiveCoachState
    var lifestyle: PlanLifestyleState
    var timeline: PlanTimelineState
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

// MARK: Timeline

enum PlanPhaseStatus: Equatable, Sendable {
    case current
    case upcoming
    case past
}

struct PlanPhase: Identifiable, Equatable {
    var id: String
    var name: String
    var status: PlanPhaseStatus
}

struct PlanTimelineState: Equatable {
    var phases: [PlanPhase]
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
