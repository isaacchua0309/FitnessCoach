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

struct OnboardingPlanRevealState: Equatable, Sendable {

    let currentWeightLabel: String
    let goalWeightLabel: String
    let goalProgressLabel: String
    let weeklyChangeLabel: String?
    let paceLabel: String?
    let estimatedWeeksLabel: String?
    let journeySummaryLine: String
    let strategyLabel: String
    let dailyCalorieLabel: String
    let calorieExplanationLine: String
    let proteinLabel: String
    let waterLabel: String
    let secondaryMacroRows: [OnboardingPlanRevealMetricRow]
    let planStatus: OnboardingPlanRevealStatus

    init(
        currentWeightLabel: String,
        goalWeightLabel: String,
        goalProgressLabel: String,
        weeklyChangeLabel: String? = nil,
        paceLabel: String? = nil,
        estimatedWeeksLabel: String? = nil,
        journeySummaryLine: String,
        strategyLabel: String,
        dailyCalorieLabel: String,
        calorieExplanationLine: String,
        proteinLabel: String,
        waterLabel: String,
        secondaryMacroRows: [OnboardingPlanRevealMetricRow] = [],
        planStatus: OnboardingPlanRevealStatus
    ) {
        self.currentWeightLabel = currentWeightLabel
        self.goalWeightLabel = goalWeightLabel
        self.goalProgressLabel = goalProgressLabel
        self.weeklyChangeLabel = weeklyChangeLabel
        self.paceLabel = paceLabel
        self.estimatedWeeksLabel = estimatedWeeksLabel
        self.journeySummaryLine = journeySummaryLine
        self.strategyLabel = strategyLabel
        self.dailyCalorieLabel = dailyCalorieLabel
        self.calorieExplanationLine = calorieExplanationLine
        self.proteinLabel = proteinLabel
        self.waterLabel = waterLabel
        self.secondaryMacroRows = secondaryMacroRows
        self.planStatus = planStatus
    }
}
