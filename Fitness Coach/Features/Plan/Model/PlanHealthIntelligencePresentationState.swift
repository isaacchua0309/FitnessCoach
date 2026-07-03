//
//  PlanHealthIntelligencePresentationState.swift
//  Fitness Coach
//
//  Forma — Presentation models for Plan Health Intelligence.
//  Maps from HealthIntelligenceSnapshot, HealthBaselineContext, and UserPlanContext only.
//

import Foundation

// MARK: - Content phase

enum PlanHealthIntelligenceContentPhase: Equatable, Sendable, Codable {
    case loading
    case empty
    case loaded
}

// MARK: - Health connection

enum PlanHealthConnectionState: Equatable, Sendable, Codable {
    case disconnected
    case partial
    case connected

    static func resolve(
        isAppleHealthConnected: Bool,
        availability: HealthDataAvailability?
    ) -> PlanHealthConnectionState {
        guard isAppleHealthConnected || availability?.hasAnyReadableSignal == true else {
            return .disconnected
        }

        if let availability,
           availability.hasTrainingReadAccess,
           availability.permissionStatus.availableSignals.count >= 4 {
            return .connected
        }

        return .partial
    }
}

// MARK: - User plan context

struct UserPlanContext: Equatable, Sendable, Codable {
    var calorieTarget: Int?
    var proteinTargetGrams: Double?
    var isAppleHealthConnected: Bool

    init(
        calorieTarget: Int? = nil,
        proteinTargetGrams: Double? = nil,
        isAppleHealthConnected: Bool = false
    ) {
        self.calorieTarget = calorieTarget
        self.proteinTargetGrams = proteinTargetGrams
        self.isAppleHealthConnected = isAppleHealthConnected
    }

    static func from(profile: UserProfile, isAppleHealthConnected: Bool) -> UserPlanContext {
        UserPlanContext(
            calorieTarget: profile.targets.calorieTarget > 0 ? profile.targets.calorieTarget : nil,
            proteinTargetGrams: profile.targets.proteinTarget > 0 ? profile.targets.proteinTarget : nil,
            isAppleHealthConnected: isAppleHealthConnected
        )
    }
}

// MARK: - Confidence card

struct PlanHealthConfidenceCardState: Equatable, Sendable, Codable {
    var phase: PlanHealthIntelligenceContentPhase
    var sectionTitle: String
    var headline: String
    var summary: String
    var confidenceLabel: String
    var scorePercent: Int?
    var reasons: [String]
    var disclaimerLine: String
    var accessibilityLabel: String

    static let loading = PlanHealthConfidenceCardState(
        phase: .loading,
        sectionTitle: FormaProductCopy.PlanHealthIntelligencePresentation.confidenceSectionTitle,
        headline: FormaProductCopy.PlanHealthIntelligencePresentation.loadingTitle,
        summary: FormaProductCopy.PlanHealthIntelligencePresentation.loadingSubtitle,
        confidenceLabel: "",
        scorePercent: nil,
        reasons: [],
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
        reasons: [],
        disclaimerLine: FormaProductCopy.PlanHealthIntelligencePresentation.disclaimer,
        accessibilityLabel: FormaProductCopy.PlanHealthIntelligencePresentation.emptyAccessibilityLabel
    )
}

// MARK: - Signals

enum PlanHealthSignalKind: String, Equatable, Sendable, Codable {
    case appleHealthWorkouts
    case stepHistory
    case activeEnergy
    case sleep
    case heartMetrics
    case weight
    case nutritionLogs
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

enum PlanHealthDataQualityLevel: String, Equatable, Sendable, Codable {
    case strong
    case moderate
    case limited
}

struct PlanHealthDataQualityState: Equatable, Sendable, Codable {
    var sectionTitle: String
    var qualityLevel: PlanHealthDataQualityLevel
    var qualityLabel: String
    var explanation: String
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
    var userPlan: UserPlanContext
    var healthConnection: PlanHealthConnectionState
    var hasNutritionLogging: Bool
    var hasRecentWeightLog: Bool
    var isLoading: Bool

    init(
        planConfidence: PlanHealthConfidence = .unknown,
        baselineContext: HealthBaselineContext = .empty(for: Date()),
        recovery: RecoverySummary? = nil,
        userPlan: UserPlanContext = UserPlanContext(),
        healthConnection: PlanHealthConnectionState = .disconnected,
        hasNutritionLogging: Bool = false,
        hasRecentWeightLog: Bool = false,
        isLoading: Bool = false
    ) {
        self.planConfidence = planConfidence
        self.baselineContext = baselineContext
        self.recovery = recovery
        self.userPlan = userPlan
        self.healthConnection = healthConnection
        self.hasNutritionLogging = hasNutritionLogging
        self.hasRecentWeightLog = hasRecentWeightLog
        self.isLoading = isLoading
    }

    static func from(
        snapshot: HealthIntelligenceSnapshot,
        baselineContext: HealthBaselineContext,
        userPlan: UserPlanContext,
        healthAvailability: HealthDataAvailability? = nil,
        hasNutritionLogging: Bool = false,
        hasRecentWeightLog: Bool = false,
        isLoading: Bool = false
    ) -> PlanHealthIntelligenceBuildInput {
        PlanHealthIntelligenceBuildInput(
            planConfidence: snapshot.planConfidence,
            baselineContext: baselineContext,
            recovery: snapshot.recovery,
            userPlan: userPlan,
            healthConnection: PlanHealthConnectionState.resolve(
                isAppleHealthConnected: userPlan.isAppleHealthConnected,
                availability: healthAvailability
            ),
            hasNutritionLogging: hasNutritionLogging,
            hasRecentWeightLog: hasRecentWeightLog,
            isLoading: isLoading
        )
    }
}
