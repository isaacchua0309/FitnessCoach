//
//  PlanPresentationModels.swift
//  Fitness Coach
//
//  Forma — Product-facing presentation state for the Plan strategy screen.
//

import Foundation

// MARK: - Goal direction

enum PlanGoalDirection: String, Equatable, Sendable, CaseIterable {
    case lose
    case gain
    case maintain
}

typealias PlanMissionGoalDirection = PlanGoalDirection

// MARK: - Status

enum PlanStatusTone: String, Equatable, Sendable {
    case onTrack
    case needsData
    case aheadOfSchedule
    case newPlan
}

struct PlanStatusState: Equatable, Sendable {
    var message: String
    var tone: PlanStatusTone
}

// MARK: - Strategy

struct PlanStrategyState: Equatable, Sendable {
    var sectionTitle: String
    var headline: String
    var strategyName: String
    var goalDirection: PlanGoalDirection
    var progressRouteLabel: String
    var progressCompleteLabel: String?
    var progressBarFill: Double
    var showsProgressBar: Bool
    var expectedCompletionLabel: String?
    var expectedPaceLabel: String?
    var usesLoggedCurrentWeight: Bool
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
    var summaryCopy: String
    var goToTodayTitle: String?
    var accessibilitySummary: String
}

// MARK: - Explanation

struct PlanExplanationState: Equatable, Sendable {
    var sectionTitle: String
    var summary: String
    var highlights: [PlanRationaleHighlight]?
    var flowSteps: [PlanRationaleFlowStep]?
    var basedOnItems: [PlanRationaleBasedOnItem]?
    var seeCalculationTitle: String
    var sustainabilityNote: String?
    var calculationDetails: PlanCalculationDetailsState?
    var accessibilitySummary: String

    var usesHighlightLayout: Bool {
        guard let highlights, !highlights.isEmpty else { return false }
        return true
    }

    var usesVisualFlowLayout: Bool {
        guard let flowSteps, !flowSteps.isEmpty else { return false }
        return true
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

struct PlanAssumptionsState: Equatable, Sendable {
    var activityLevel: String
    var estimatedStepsPerDay: Int
    var estimatedStepsLabel: String
    var trainingSessionsPerWeek: Int
    var trainingSessionsLabel: String
    var usesActivityLevelDefaults: Bool
    var resolvedAgeYears: Int
    var ageLabel: String
    var heightLabel: String
    var sexLabel: String

    var sectionTitle: String
    var activityFieldLabel: String
    var estimatedStepsFieldLabel: String
    var trainingFieldLabel: String
    var assumptionsNote: String
    var adjustActivityTitle: String
    var accessibilitySummary: String
}

// MARK: - Confidence

struct PlanConfidenceReasonItem: Equatable, Sendable, Identifiable {
    var id: String
    var text: String
}

struct PlanConfidenceState: Equatable, Sendable {
    var confidenceScore: Int
    var confidenceLevel: ConfidenceLevel
    var sectionTitle: String
    var scoreLabel: String
    var whyHeading: String
    var missingHeading: String
    var whyItems: [PlanConfidenceReasonItem]
    var missingItems: [PlanConfidenceReasonItem]
    var footerCopy: String
    var showsAppleHealthStatus: Bool
    var appleHealthStatusLabel: String?
    var showsAppleHealthAction: Bool
    var appleHealthActionTitle: String?
    var accessibilitySummary: String
}

// MARK: - Adjustment rules

struct AdjustmentRuleItem: Equatable, Sendable, Identifiable {
    var id: String
    var text: String
}

struct AdjustmentRulesState: Equatable, Sendable {
    var sectionTitle: String
    var rules: [AdjustmentRuleItem]
    var footerCopy: String
    var accessibilitySummary: String
}

// MARK: - Review

struct PlanReviewState: Equatable, Sendable {
    var lastUpdatedLabel: String?
    var lastUpdateReasonCopy: String?
    var showsRecalculateHint: Bool
    var recalculateHintCopy: String?
    var accessibilitySummary: String
}

// MARK: - Adjust CTA

struct AdjustPlanCTAState: Equatable, Sendable {
    var title: String
    var isEnabled: Bool
    var accessibilityHint: String
}
