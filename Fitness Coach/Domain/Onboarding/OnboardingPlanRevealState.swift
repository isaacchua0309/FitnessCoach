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
    let weeklyChangeLabel: String?
    let estimatedWeeksLabel: String?
    let journeySummaryLine: String
    let dailyCalorieLabel: String
    let calorieExplanationLine: String
    let proteinLabel: String
    let waterLabel: String
    let secondaryMacroRows: [OnboardingPlanRevealMetricRow]
    let warningMessage: String?

    init(
        currentWeightLabel: String,
        goalWeightLabel: String,
        weeklyChangeLabel: String? = nil,
        estimatedWeeksLabel: String? = nil,
        journeySummaryLine: String,
        dailyCalorieLabel: String,
        calorieExplanationLine: String,
        proteinLabel: String,
        waterLabel: String,
        secondaryMacroRows: [OnboardingPlanRevealMetricRow] = [],
        warningMessage: String? = nil
    ) {
        self.currentWeightLabel = currentWeightLabel
        self.goalWeightLabel = goalWeightLabel
        self.weeklyChangeLabel = weeklyChangeLabel
        self.estimatedWeeksLabel = estimatedWeeksLabel
        self.journeySummaryLine = journeySummaryLine
        self.dailyCalorieLabel = dailyCalorieLabel
        self.calorieExplanationLine = calorieExplanationLine
        self.proteinLabel = proteinLabel
        self.waterLabel = waterLabel
        self.secondaryMacroRows = secondaryMacroRows
        self.warningMessage = warningMessage
    }
}
