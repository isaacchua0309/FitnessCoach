//
//  PlanPresentationModels.swift
//  Fitness Coach
//
//  Forma — Product-facing presentation state for the Plan strategy screen.
//

import Foundation

// MARK: - Goal direction
//
// Uses domain `PlanGoalDirection` from PlanCalculationInput (.cut / .maintain / .gain).

// MARK: - Status

enum PlanStrategyClassification: String, Equatable, Sendable, CaseIterable {
    case aggressiveCut
    case moderateCut
    case gentleCut
    case maintenance
    case leanGain
    case rebuild
    case needsReview
}

struct PlanStatusState: Equatable, Sendable {
    var sectionTitle: String
    var classification: PlanStrategyClassification
    var statusName: String
    var explanation: String
    var bestForLabel: String
    var bestForValue: String
    var watchForLabel: String
    var watchForValue: String
    var accessibilitySummary: String
}

// MARK: - Header

struct PlanHeaderState: Equatable, Sendable {
    var title: String
    var subtitle: String
    var accessibilitySummary: String
}

// MARK: - Strategy

struct PlanStrategyState: Equatable, Sendable {
    var sectionTitle: String
    var primaryGoal: String
    var goalDirection: PlanGoalDirection
    var dailyTargetLabel: String
    var dailyTargetValue: String
    var expectedPaceLabel: String?
    var expectedPaceValue: String?
    var strategyStatusLabel: String
    var strategyStatusValue: String
    var supportiveLine: String
    var accessibilitySummary: String
}

// MARK: - Daily targets

struct DailyTargetsState: Equatable, Sendable {
    var sectionTitle: String
    var caloriesLabel: String
    var proteinLabel: String
    var carbsLabel: String
    var fatLabel: String
    var waterLabel: String
    var trainingTargetLabel: String?
    var prescriptionCopy: String
    var goToTodayTitle: String?
    var accessibilitySummary: String
}

// MARK: - Explanation

struct PlanExplanationEnergyLine: Equatable, Sendable, Identifiable {
    var id: String
    var label: String
    var value: String
}

struct PlanExplanationState: Equatable, Sendable {
    var sectionTitle: String
    var energyLines: [PlanExplanationEnergyLine]
    var guidanceCopy: String
    var seeCalculationTitle: String
    var calculationDetails: PlanCalculationDetailsState?
    var accessibilitySummary: String

    var showsCalculationAction: Bool {
        calculationDetails != nil
    }
}

// MARK: - Rationale metrics

struct PlanRationaleMetrics: Equatable, Sendable {
    var maintenanceCaloriesKcal: Int
    var deficitOrSurplusKcal: Int?
    var deficitOrSurplusLabel: String?
    var targetCaloriesKcal: Int
    var bmrKcal: Int
    var tdeeKcal: Int
    var energyExplanation: String
}

// MARK: - Assumptions

struct PlanAssumptionRow: Equatable, Sendable, Identifiable {
    var id: String
    var label: String
    var value: String
    var isMissing: Bool
}

struct PlanAssumptionsState: Equatable, Sendable {
    var sectionTitle: String
    var rows: [PlanAssumptionRow]
    var adjustActivityTitle: String
    var accessibilitySummary: String
}

// MARK: - Confidence

enum PlanConfidenceEstimateBucket: String, Equatable, Sendable, CaseIterable {
    case low
    case fair
    case good
    case strong

    var label: String {
        switch self {
        case .low: return "Low"
        case .fair: return "Fair"
        case .good: return "Good"
        case .strong: return "Strong"
        }
    }
}

struct PlanConfidenceAction: Equatable, Sendable, Identifiable {
    var id: String
    var text: String
}

struct PlanConfidenceSignal: Equatable, Sendable, Identifiable {
    var id: String
    var label: String
    var value: String
}

struct PlanConfidenceState: Equatable, Sendable {
    var confidenceScore: Int
    var estimateBucket: PlanConfidenceEstimateBucket
    var sectionTitle: String
    var scoreHeadline: String
    var improveAccuracyHeading: String
    var improvementActions: [PlanConfidenceAction]
    var compactSignalsHeading: String
    var compactSignals: [PlanConfidenceSignal]
    var showsAppleHealthAction: Bool
    var appleHealthActionTitle: String?
    var accessibilitySummary: String
}

// MARK: - Weekly recommendation

struct PlanWeeklyRecommendationState: Equatable, Sendable {
    var sectionTitle: String
    var formulaMaintenanceLabel: String
    var formulaMaintenanceKcal: Int?
    var learnedMaintenanceLabel: String
    var learnedMaintenanceKcal: Int?
    var learnedMaintenanceUnavailableCopy: String
    var showsLearnedEstimate: Bool
    var recommendationTitle: String?
    var recommendationMessage: String?
    var suggestedCalorieDelta: Int?
    var suggestedTargetKcal: Int?
    var confidenceLabel: String?
    var showsRecommendation: Bool
    var reviewPlanButtonTitle: String
    var showsReviewPlanCTA: Bool
    var safetyCopy: String
    var recommendationKind: WeeklyPlanRecommendationKind?
    var accessibilitySummary: String
}

// MARK: - Adjustment rules

struct AdjustmentRuleItem: Equatable, Sendable, Identifiable {
    var id: String
    var text: String
}

struct AdjustmentRulesState: Equatable, Sendable {
    var sectionTitle: String
    var reviewHeading: String
    var rules: [AdjustmentRuleItem]
    var trendHint: String?
    var aggressivePlanNote: String?
    var accessibilitySummary: String
}

// MARK: - Review

struct PlanReviewState: Equatable, Sendable {
    var sectionTitle: String
    var headline: String
    var bodyCopy: String
    var weighInHint: String?
    var accessibilitySummary: String
}

// MARK: - Adjust CTA

struct AdjustPlanCTAState: Equatable, Sendable {
    var heading: String
    var bodyCopy: String
    var buttonTitle: String
    var isEnabled: Bool
    var accessibilitySummary: String
    var accessibilityHint: String
}
