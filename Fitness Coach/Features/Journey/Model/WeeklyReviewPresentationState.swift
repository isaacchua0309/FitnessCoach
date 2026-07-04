//
//  WeeklyReviewPresentationState.swift
//  Fitness Coach
//
//  Forma — Presentation models for Health Intelligence weekly reviews.
//  Maps from WeeklyHealthReview only; no HealthKit or repository types.
//

import Foundation

// MARK: - Content phase

enum WeeklyReviewContentPhase: Equatable, Sendable, Codable {
    case loading
    case empty
    case loaded
}

// MARK: - Card

struct WeeklyReviewCardState: Equatable, Sendable, Codable {
    var phase: WeeklyReviewContentPhase
    var sectionTitle: String
    var dateRangeLabel: String
    var title: String
    var summary: String
    var confidenceLabel: String
    var headlineStatLabel: String?
    var accessibilityLabel: String

    static let loading = WeeklyReviewCardState(
        phase: .loading,
        sectionTitle: FormaProductCopy.WeeklyReviewPresentation.sectionTitle,
        dateRangeLabel: "",
        title: FormaProductCopy.WeeklyReviewPresentation.loadingTitle,
        summary: FormaProductCopy.WeeklyReviewPresentation.loadingSubtitle,
        confidenceLabel: "",
        headlineStatLabel: nil,
        accessibilityLabel: FormaProductCopy.WeeklyReviewPresentation.loadingAccessibilityLabel
    )

    static let empty = WeeklyReviewCardState(
        phase: .empty,
        sectionTitle: FormaProductCopy.WeeklyReviewPresentation.sectionTitle,
        dateRangeLabel: "",
        title: FormaProductCopy.WeeklyReviewPresentation.emptyTitle,
        summary: FormaProductCopy.WeeklyReviewPresentation.emptySummary,
        confidenceLabel: FormaProductCopy.WeeklyReviewPresentation.confidenceLow,
        headlineStatLabel: nil,
        accessibilityLabel: FormaProductCopy.WeeklyReviewPresentation.emptyAccessibilityLabel
    )
}

// MARK: - Detail

struct WeeklyReviewDetailState: Equatable, Sendable, Codable {
    var title: String
    var dateRangeLabel: String
    var summary: String
    var statsGrid: WeeklyReviewStatsGridState
    var wins: [WeeklyReviewInsightState]
    var risks: [WeeklyReviewInsightState]
    var nextWeekFocus: [WeeklyReviewFocusItemState]
    var confidenceLabel: String
    var missingDataNotice: String?
    var generatedAtLabel: String
    var accessibilityLabel: String
}

// MARK: - Stats grid

struct WeeklyReviewStatsGridState: Equatable, Sendable, Codable {
    var items: [WeeklyReviewStatItemState]
    var accessibilityLabel: String
}

struct WeeklyReviewStatItemState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var title: String
    var value: String
    var detail: String?
    var isLimited: Bool
}

// MARK: - Insights & focus

enum WeeklyReviewInsightKind: Equatable, Sendable, Codable {
    case win
    case risk
}

struct WeeklyReviewInsightState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var kind: WeeklyReviewInsightKind
    var message: String
    var accessibilityLabel: String
}

struct WeeklyReviewFocusItemState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var message: String
    var accessibilityLabel: String
}

// MARK: - Weekly progress detail (canonical)

struct WeeklyProgressConsistencySectionState: Equatable {
    var foodLoggedLabel: String?
    var averageCaloriesLabel: String?
    var proteinLabel: String?
    var waterLabel: String?
    var calorieAdherenceLabel: String?
    var trainingLabel: String?

    var hasContent: Bool {
        foodLoggedLabel != nil
            || averageCaloriesLabel != nil
            || proteinLabel != nil
            || waterLabel != nil
            || calorieAdherenceLabel != nil
            || trainingLabel != nil
    }
}

struct WeeklyProgressTDEEComparisonState: Equatable {
    var learnedMaintenanceKcal: Int
    var staticTDEEKcal: Int
    var comparisonCopy: String
    var accessibilityLabel: String
}

struct WeeklyProgressDetailState: Equatable {
    var unified: UnifiedWeeklyReviewState
    var verdictTitle: String
    var primaryInsight: String
    var consistency: WeeklyProgressConsistencySectionState
    var staticTDEEComparison: WeeklyProgressTDEEComparisonState?
    var nextWeekFocus: [WeeklyReviewFocusItemState]
    var generatedAtLabel: String
    var healthKitLimitedNotice: String?
    var uncertaintyTitle: String
    var accessibilityLabel: String
}
