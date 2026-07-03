//
//  JourneyHealthIntelligencePresentationState.swift
//  Fitness Coach
//
//  Forma — Presentation models mapping Health Intelligence into Journey-friendly sections.
//  No HealthKit or repository types; snapshot-derived copy only.
//
//  Note: `JourneyHealthMilestoneState` is the Health Intelligence milestone item.
//  The legacy gamification section uses `JourneyMilestoneState` in JourneyPresentationTypes.
//

import Foundation

// MARK: - Section root

struct JourneyHealthIntelligenceSectionState: Equatable, Sendable, Codable {
    var weeklyReviewPreview: JourneyWeeklyReviewPreviewState?
    var recoveryTimeline: JourneyRecoveryTimelineState
    var workoutHistory: JourneyWorkoutHistoryState
    var milestones: JourneyHealthMilestonesState
    var progress: JourneyHealthProgressState
    var isLoading: Bool
    var errorMessage: String?

    var isVisible: Bool {
        !isLoading || errorMessage != nil
    }
}

// MARK: - Shared phase

enum JourneyHealthIntelligenceContentPhase: Equatable, Sendable, Codable {
    case loading
    case empty
    case error
    case loaded
}

// MARK: - Weekly review preview

struct JourneyWeeklyReviewPreviewState: Equatable, Sendable, Codable {
    var phase: JourneyHealthIntelligenceContentPhase
    var sectionTitle: String
    var weekRangeLabel: String
    var title: String
    var summary: String
    var winLines: [String]
    var focusLines: [String]
    var confidenceNote: String?
    var accessibilityLabel: String

    static let loading = JourneyWeeklyReviewPreviewState(
        phase: .loading,
        sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WeeklyReview.sectionTitle,
        weekRangeLabel: "",
        title: FormaProductCopy.Journey.HealthIntelligence.loadingTitle,
        summary: FormaProductCopy.Journey.HealthIntelligence.loadingSubtitle,
        winLines: [],
        focusLines: [],
        confidenceNote: nil,
        accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.loadingAccessibilityLabel
    )
}

// MARK: - Recovery timeline

enum JourneyRecoveryDayStatusKind: Equatable, Sendable, Codable {
    case ready
    case moderate
    case low
    case limitedEstimate
    case unknown
}

struct JourneyRecoveryDayState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var date: Date
    var dateLabel: String
    var weekdayLabel: String
    var statusLabel: String
    var statusKind: JourneyRecoveryDayStatusKind
    var shortExplanation: String?
    var isLimitedEstimate: Bool
    var accessibilityLabel: String
}

struct JourneyRecoveryTimelineState: Equatable, Sendable, Codable {
    var phase: JourneyHealthIntelligenceContentPhase
    var sectionTitle: String
    var headline: String
    var days: [JourneyRecoveryDayState]
    var emptyMessage: String?
    var errorMessage: String?
    var accessibilityLabel: String

    static let loading = JourneyRecoveryTimelineState(
        phase: .loading,
        sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
        headline: FormaProductCopy.Journey.HealthIntelligence.loadingTitle,
        days: [],
        emptyMessage: nil,
        errorMessage: nil,
        accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.loadingAccessibilityLabel
    )
}

// MARK: - Workout history

struct JourneyWorkoutHistoryItemState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var date: Date
    var dateLabel: String
    var workoutTitle: String
    var durationLabel: String
    var demandLabel: String?
    var intensityLabel: String?
    var shortExplanation: String?
    var accessibilityLabel: String
}

struct JourneyWorkoutHistoryState: Equatable, Sendable, Codable {
    var phase: JourneyHealthIntelligenceContentPhase
    var sectionTitle: String
    var headline: String
    var items: [JourneyWorkoutHistoryItemState]
    var emptyMessage: String?
    var errorMessage: String?
    var accessibilityLabel: String

    static let loading = JourneyWorkoutHistoryState(
        phase: .loading,
        sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
        headline: FormaProductCopy.Journey.HealthIntelligence.loadingTitle,
        items: [],
        emptyMessage: nil,
        errorMessage: nil,
        accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.loadingAccessibilityLabel
    )
}

// MARK: - Milestones

enum JourneyHealthMilestoneStatus: Equatable, Sendable, Codable {
    case achieved
    case inProgress
    case upcoming
}

/// Health Intelligence milestone item for Journey progress (distinct from gamification `JourneyMilestoneState`).
struct JourneyHealthMilestoneState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var title: String
    var detail: String
    var status: JourneyHealthMilestoneStatus
    var statusLabel: String
    var progressLabel: String?
    var accessibilityLabel: String
}

struct JourneyHealthMilestonesState: Equatable, Sendable, Codable {
    var phase: JourneyHealthIntelligenceContentPhase
    var sectionTitle: String
    var headline: String
    var items: [JourneyHealthMilestoneState]
    var emptyMessage: String?
    var errorMessage: String?
    var accessibilityLabel: String

    static let loading = JourneyHealthMilestonesState(
        phase: .loading,
        sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
        headline: FormaProductCopy.Journey.HealthIntelligence.loadingTitle,
        items: [],
        emptyMessage: nil,
        errorMessage: nil,
        accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.loadingAccessibilityLabel
    )
}

// MARK: - Progress

struct JourneyHealthProgressMetricRow: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var title: String
    var value: String
    var detail: String?
}

struct JourneyHealthProgressState: Equatable, Sendable, Codable {
    var phase: JourneyHealthIntelligenceContentPhase
    var sectionTitle: String
    var headline: String
    var detailLines: [String]
    var metrics: [JourneyHealthProgressMetricRow]
    var emptyMessage: String?
    var errorMessage: String?
    var accessibilityLabel: String

    static let loading = JourneyHealthProgressState(
        phase: .loading,
        sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
        headline: FormaProductCopy.Journey.HealthIntelligence.loadingTitle,
        detailLines: [FormaProductCopy.Journey.HealthIntelligence.loadingSubtitle],
        metrics: [],
        emptyMessage: nil,
        errorMessage: nil,
        accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.loadingAccessibilityLabel
    )
}

// MARK: - Builder input

struct JourneyHealthIntelligenceBuildInput: Equatable, Sendable {
    var currentSnapshot: HealthIntelligenceSnapshot?
    var historicalSnapshots: [HealthIntelligenceSnapshot]
    var isLoading: Bool
    var errorMessage: String?

    init(
        currentSnapshot: HealthIntelligenceSnapshot? = nil,
        historicalSnapshots: [HealthIntelligenceSnapshot] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.currentSnapshot = currentSnapshot
        self.historicalSnapshots = historicalSnapshots
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
}
