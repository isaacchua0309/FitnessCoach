//
//  PlanMissionControlModels.swift
//  Fitness Coach
//
//  Forma — Product-facing Mission Control state for the Plan dashboard.
//

import Foundation

// MARK: - Mission Control bundle

/// Product-facing read model for the Plan strategy dashboard.
struct PlanMissionControlDashboard: Equatable, Sendable {
    var mission: PlanMissionState
    var todayMission: PlanTodayMissionState
    var week: PlanWeekState
    var nextMilestone: PlanNextMilestoneState
    var rationale: PlanRationaleState
    var activityAssumptions: PlanActivityAssumptionsState
    var confidence: PlanConfidenceState
    var adjustment: PlanAdjustmentState
}

// MARK: - 1. Mission

enum PlanMissionGoalDirection: String, Equatable, Sendable, CaseIterable {
    case lose
    case gain
    case maintain
}

struct PlanMissionState: Equatable, Sendable {
    var currentWeightKg: Double?
    var goalWeightKg: Double?
    var startWeightKg: Double?
    var totalToLoseOrGainKg: Double?
    /// Normalized progress toward goal, 0...1 when computable.
    var progressPercent: Double?
    var expectedCompletionDate: Date?
    var expectedCompletionLabel: String?
    var expectedWeeklyChangeKg: Double?
    var expectedWeeklyChangeLabel: String?
    var goalDirection: PlanMissionGoalDirection
    var strategyName: String
    var statusCopy: String
    var usesLoggedCurrentWeight: Bool

    var currentWeightLabel: String
    var goalWeightLabel: String
    var startWeightLabel: String?
    var progressPercentLabel: String?
    var totalChangeLabel: String?
}

// MARK: - 2. Today's mission

struct PlanTodayMissionState: Equatable, Sendable {
    var calorieTarget: Int
    var proteinTargetG: Double
    var carbTargetG: Double
    var fatTargetG: Double
    var waterTargetMl: Int

    var caloriesLabel: String
    var proteinLabel: String
    var carbsLabel: String
    var fatLabel: String
    var waterLabel: String
    var progressCopy: String
}

// MARK: - 3. This week

enum PlanWeekOverallStatus: String, Equatable, Sendable {
    case strong
    case onTrack
    case building
    case incomplete
}

struct PlanWeekAdherenceCount: Equatable, Sendable {
    var achieved: Int
    var eligible: Int

    var label: String {
        guard eligible > 0 else { return "—" }
        return "\(achieved)/\(eligible)"
    }
}

struct PlanWeekState: Equatable, Sendable {
    var calorieAdherence: PlanWeekAdherenceCount
    var proteinAdherence: PlanWeekAdherenceCount
    var waterAdherence: PlanWeekAdherenceCount
    var trainingDays: Int
    var expectedTrainingDays: Int
    var trainingProgressLabel: String
    var weightChangeKg: Double?
    var weightChangeLabel: String?
    var overallStatus: PlanWeekOverallStatus
    var overallStatusCopy: String
    var hasWeeklyData: Bool
}

// MARK: - 4. Next milestone

enum PlanMilestoneType: String, Equatable, Sendable {
    case weightCheckpoint
    case goalWeight
    case phaseReview
}

struct PlanNextMilestoneState: Equatable, Sendable {
    var milestoneLabel: String?
    var remainingKg: Double?
    var remainingLabel: String?
    var expectedDate: Date?
    var expectedDateLabel: String?
    var milestoneType: PlanMilestoneType?
    var detailCopy: String?
    var showsEmptyState: Bool
}

// MARK: - 5. Rationale metrics (extends display-oriented PlanRationaleState)

struct PlanRationaleMetrics: Equatable, Sendable {
    var maintenanceCaloriesKcal: Int
    var deficitOrSurplusKcal: Int?
    var deficitOrSurplusLabel: String?
    var targetCaloriesKcal: Int
    var bmrKcal: Int
    var tdeeKcal: Int
    var energyExplanation: String
}

// MARK: - 6. Activity assumptions

struct PlanActivityAssumptionsState: Equatable, Sendable {
    var activityLevel: String
    var estimatedStepsPerDay: Int
    var estimatedStepsLabel: String
    var trainingSessionsPerWeek: Int
    var trainingSessionsLabel: String
    var usesActivityLevelDefaults: Bool
    var isAppleHealthConnected: Bool
    var appleHealthInsightsNote: String
    var resolvedAgeYears: Int
    var ageLabel: String
    var heightLabel: String
    var sexLabel: String
}

// MARK: - 7. Confidence

struct PlanConfidenceState: Equatable, Sendable {
    /// Deterministic score 0...100 for display.
    var confidenceScore: Int
    var confidenceLevel: ConfidenceLevel
    var confidenceReasons: [String]
    var missingSignals: [String]
    var safeCopy: String
}

// MARK: - 8. Adjustment

struct PlanAdjustmentState: Equatable, Sendable {
    var canEditPlan: Bool
    var lastUpdated: Date
    var lastUpdatedLabel: String
    var lastUpdateReason: String?
    var editSafetyCopy: String
    var showsTargetRecalculateHint: Bool
}
