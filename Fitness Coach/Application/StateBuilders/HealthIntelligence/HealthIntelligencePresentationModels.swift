//
//  HealthIntelligencePresentationModels.swift
//  Fitness Coach
//
//  Forma — Tab-agnostic Health Intelligence presentation fragments shared across
//  Today, Plan, and Journey builders. Tab-specific builders map these into
//  their own section state types; layout and ordering stay in tab builders.
//

import Foundation

// MARK: - Recovery

enum HealthIntelligenceRecoveryPhase: Equatable, Sendable {
    case ready
    case moderate
    case low
    case unknown
    case limitedEstimate
}

/// Shared recovery card fields before tab-specific section titles are applied.
struct HealthIntelligenceRecoveryCardContent: Equatable, Sendable {
    var phase: HealthIntelligenceRecoveryPhase
    var title: String
    var subtitle: String?
    var trainingGuidance: String?
    var nutritionGuidance: String?
    var confidenceNote: String?
    var missingDataNote: String?
    var staleDataLabel: String?
    var accessibilityParts: [String?]
}

// MARK: - Workout / training load

enum HealthIntelligenceWorkoutCardPhase: Equatable, Sendable {
    case completed
    case empty
    case hidden
}

struct HealthIntelligenceWorkoutCardContent: Equatable, Sendable {
    var phase: HealthIntelligenceWorkoutCardPhase
    var title: String
    var subtitle: String?
    var nutritionTip: String?
    var hydrationTip: String?
    var accessibilityParts: [String?]
}

// MARK: - Adaptive nutrition

struct HealthIntelligenceAdaptiveNutritionContent: Equatable, Sendable {
    var isVisible: Bool
    var title: String
    var subtitle: String?
    var proteinGuidance: String?
    var calorieGuidance: String?
    var waterGuidance: String?
    var confidenceNote: String?
    var accessibilityParts: [String?]
}

/// Nutrition progress bridge used by adaptive nutrition and daily-mission helpers.
struct HealthIntelligenceNutritionProgressInput: Equatable, Sendable {
    var calorieRemaining: Int?
    var proteinRemainingGrams: Double?
    var waterRemainingMl: Int?
    var hasCalorieTarget: Bool
    var hasProteinTarget: Bool
    var hasWaterTarget: Bool

    static let unavailable = HealthIntelligenceNutritionProgressInput(
        calorieRemaining: nil,
        proteinRemainingGrams: nil,
        waterRemainingMl: nil,
        hasCalorieTarget: false,
        hasProteinTarget: false,
        hasWaterTarget: false
    )
}

// MARK: - Weekly review (HI card summary)

enum HealthIntelligenceWeeklyReviewBuildingPhase: Equatable, Sendable {
    case empty
    case loading
}

struct HealthIntelligenceWeeklyReviewBuildingContent: Equatable, Sendable {
    var phase: HealthIntelligenceWeeklyReviewBuildingPhase
    var title: String
    var summary: String
    var confidenceLabel: String
    var dateRangeLabel: String
    var accessibilityLabel: String
}

// MARK: - CTA / connect-health copy

struct HealthIntelligenceUIStateCTACopy: Equatable, Sendable {
    var title: String
    var message: String
    var primaryActionTitle: String?
    var secondaryActionTitle: String?
    var accessibilityLabel: String
}

struct HealthIntelligenceConnectCTACopy: Equatable, Sendable {
    var title: String
    var message: String
    var ctaTitle: String?
    var accessibilityLabel: String
}

// MARK: - UI resolution input

struct HealthIntelligenceUIResolutionInput: Equatable, Sendable {
    var presentationContext: HealthIntelligencePresentationContext
    var baseline: HealthBaselineContext?
    var lastSuccessfulLocalSyncAt: Date?
    var isRemoteSyncCapabilityEnabled: Bool
    var remoteSyncConsentDecision: HealthSummarySyncConsentDecision
    var surface: HealthIntelligenceSurface
}

// MARK: - Card build inputs

struct HealthIntelligenceRecoveryCardBuildInput: Equatable, Sendable {
    var recovery: RecoverySummary
    var uiState: HealthIntelligenceUIState?
    var staleDataLabel: String?
    var surface: HealthIntelligenceSurface
}

struct HealthIntelligenceWorkoutCardBuildInput: Equatable, Sendable {
    var workout: WorkoutSummary?
    var uiState: HealthIntelligenceUIState?
}

struct HealthIntelligenceAdaptiveNutritionCardBuildInput: Equatable, Sendable {
    var summary: AdaptiveNutritionSummary
    var nutritionProgress: HealthIntelligenceNutritionProgressInput
}

/// Title and message for HealthKit-disconnected / unavailable recovery summaries.
struct HealthIntelligenceDisconnectedSummary: Equatable, Sendable {
    var title: String
    var message: String
}

// MARK: - Accessibility

enum HealthIntelligencePresentationAccessibility {

    static func joinedLabel(parts: [String?]) -> String {
        parts
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }

    static func cardLabel(sectionTitle: String, parts: [String?]) -> String {
        joinedLabel(parts: [sectionTitle] + parts)
    }
}
