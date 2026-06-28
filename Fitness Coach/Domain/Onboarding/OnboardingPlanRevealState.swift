//
//  OnboardingPlanRevealState.swift
//  Fitness Coach
//
//  Forma — Presentation-only model for onboarding plan reveal (step 9).
//  Values are produced by OnboardingPlanRevealBuilder; this type performs no calculation.
//

import Foundation

struct OnboardingPlanRevealMetricRow: Equatable, Sendable, Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct OnboardingPlanRevealMission: Equatable, Sendable, Identifiable {
    let icon: String
    let title: String

    var id: String { title }
}

struct OnboardingPlanRevealState: Equatable, Sendable {

    let goalDirection: PlanGoalDirection
    let currentWeightLabel: String
    let goalWeightLabel: String
    let goalProgressLabel: String
    let goalHeroSectionTitle: String
    let goalHeroHeadline: String
    let accessibilitySummary: String
    let paceLabel: String?
    let estimatedWeeksLabel: String?
    let strategyLabel: String
    let dailyCalorieLabel: String
    let calorieExplanationLine: String
    let proteinLabel: String
    let waterLabel: String
    let secondaryMacroRows: [OnboardingPlanRevealMetricRow]
    let journeyBeliefLine: String
    let firstWeekMissions: [OnboardingPlanRevealMission]
    let coachMessage: String
    let planStatus: OnboardingPlanRevealStatus
}
