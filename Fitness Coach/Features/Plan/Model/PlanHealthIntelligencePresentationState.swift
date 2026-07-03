//
//  PlanHealthIntelligencePresentationState.swift
//  Fitness Coach
//
//  Forma — Presentation models for Plan Health Intelligence.
//  Maps from HealthIntelligenceSnapshot.planConfidence and HealthBaselineContext only.
//

import Foundation

// MARK: - Content phase

enum PlanHealthIntelligenceContentPhase: Equatable, Sendable, Codable {
    case loading
    case empty
    case loaded
}

// MARK: - Confidence card

struct PlanHealthConfidenceCardState: Equatable, Sendable, Codable {
    var phase: PlanHealthIntelligenceContentPhase
    var sectionTitle: String
    var headline: String
    var summary: String
    var confidenceLabel: String
    var scorePercent: Int?
    var disclaimerLine: String
    var accessibilityLabel: String

    static let loading = PlanHealthConfidenceCardState(
        phase: .loading,
        sectionTitle: FormaProductCopy.PlanHealthIntelligencePresentation.confidenceSectionTitle,
        headline: FormaProductCopy.PlanHealthIntelligencePresentation.loadingTitle,
        summary: FormaProductCopy.PlanHealthIntelligencePresentation.loadingSubtitle,
        confidenceLabel: "",
        scorePercent: nil,
        disclaimerLine: "",
        accessibilityLabel: FormaProductCopy.PlanHealthIntelligencePresentation.loadingAccessibilityLabel
    )

    static let empty = PlanHealthConfidenceCardState(
        phase: .empty,
        sectionTitle: FormaProductCopy.PlanHealthIntelligencePresentation.confidenceSectionTitle,
        headline: FormaProductCopy.PlanHealthIntelligencePresentation.emptyTitle,
        summary: FormaProductCopy.PlanHealthIntelligencePresentation.emptySummary,
        confidenceLabel: FormaProductCopy.PlanHealthIntelligencePresentation.confidenceUnknown,
        scorePercent: nil,
        disclaimerLine: FormaProductCopy.PlanHealthIntelligencePresentation.disclaimer,
        accessibilityLabel: FormaProductCopy.PlanHealthIntelligencePresentation.emptyAccessibilityLabel
    )
}

// MARK: - Signals

enum PlanHealthSignalKind: String, Equatable, Sendable, Codable {
    case recoveryTrend
    case workoutConsistency
    case averageSteps
    case trainingFrequency
    case sleep
    case heartVariability
    case weight
    case nutrition
    case activityEnergy
}

enum PlanHealthSignalStatus: Equatable, Sendable, Codable {
    case available
    case limited
    case missing
}

struct PlanHealthSignalState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var kind: PlanHealthSignalKind
    var title: String
    var value: String
    var detail: String?
    var status: PlanHealthSignalStatus
    var accessibilityLabel: String
}

// MARK: - Assumptions

/// Health-signal assumptions backing the plan — distinct from profile `PlanAssumptionsState`.
struct PlanHealthAssumptionsState: Equatable, Sendable, Codable {
    var sectionTitle: String
    var summary: String
    var items: [PlanAssumptionItemState]
    var accessibilityLabel: String
}

struct PlanAssumptionItemState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var label: String
    var value: String
    var isLimited: Bool
    var accessibilityLabel: String
}

// MARK: - Data quality

struct PlanHealthDataQualityState: Equatable, Sendable, Codable {
    var sectionTitle: String
    var summary: String
    var signals: [PlanHealthSignalState]
    var accessibilityLabel: String
}

// MARK: - Missing data actions

struct PlanHealthMissingDataActionState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var title: String
    var message: String
    var accessibilityLabel: String
}

// MARK: - Section root

struct PlanHealthIntelligenceSectionState: Equatable, Sendable, Codable {
    var confidenceCard: PlanHealthConfidenceCardState
    var assumptions: PlanHealthAssumptionsState
    var dataQuality: PlanHealthDataQualityState
    var missingDataActions: [PlanHealthMissingDataActionState]
    var isLoading: Bool
    var accessibilityLabel: String
}

// MARK: - Build input

struct PlanHealthIntelligenceBuildInput: Equatable, Sendable {
    var planConfidence: PlanHealthConfidence
    var baselineContext: HealthBaselineContext
    var recovery: RecoverySummary?
    var hasNutritionLogging: Bool
    var hasRecentWeightLog: Bool
    var isLoading: Bool

    init(
        planConfidence: PlanHealthConfidence = .unknown,
        baselineContext: HealthBaselineContext = .empty(for: Date()),
        recovery: RecoverySummary? = nil,
        hasNutritionLogging: Bool = false,
        hasRecentWeightLog: Bool = false,
        isLoading: Bool = false
    ) {
        self.planConfidence = planConfidence
        self.baselineContext = baselineContext
        self.recovery = recovery
        self.hasNutritionLogging = hasNutritionLogging
        self.hasRecentWeightLog = hasRecentWeightLog
        self.isLoading = isLoading
    }

    static func from(
        snapshot: HealthIntelligenceSnapshot,
        baselineContext: HealthBaselineContext,
        hasNutritionLogging: Bool = false,
        hasRecentWeightLog: Bool = false,
        isLoading: Bool = false
    ) -> PlanHealthIntelligenceBuildInput {
        PlanHealthIntelligenceBuildInput(
            planConfidence: snapshot.planConfidence,
            baselineContext: baselineContext,
            recovery: snapshot.recovery,
            hasNutritionLogging: hasNutritionLogging,
            hasRecentWeightLog: hasRecentWeightLog,
            isLoading: isLoading
        )
    }
}
