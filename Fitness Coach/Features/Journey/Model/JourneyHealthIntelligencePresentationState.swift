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
    var weeklyReviewCard: WeeklyReviewCardState?
    var weeklyReviewDetail: WeeklyReviewDetailState?
    var recoveryTimeline: JourneyRecoveryTimelineState
    var workoutHistory: JourneyWorkoutHistoryState
    var milestones: JourneyHealthMilestonesState
    var progress: JourneyHealthProgressState
    var connectHealthCTA: JourneyHealthConnectCTAState?
    var isLoading: Bool
    var errorMessage: String?

    var isVisible: Bool {
        !isLoading || errorMessage != nil || connectHealthCTA != nil
    }
}

// MARK: - Connect health CTA

struct JourneyHealthConnectCTAState: Equatable, Sendable, Codable {
    var title: String
    var message: String
    var ctaTitle: String
    var accessibilityLabel: String
}

// MARK: - Shared phase

enum JourneyHealthIntelligenceContentPhase: Equatable, Sendable, Codable {
    case loading
    case empty
    case error
    case loaded
}

enum JourneyHealthIntelligenceEmptyKind: Equatable, Sendable, Codable {
    case noHealthData
    case connectedNoWorkouts
    case insufficientHistory
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
    var statusColorToken: String
    var recoveryScore: Int?
    var limitedEstimateLabel: String?
    var shortExplanation: String?
    var isLimitedEstimate: Bool
    var accessibilityLabel: String
}

struct JourneyRecoveryTimelineState: Equatable, Sendable, Codable {
    var phase: JourneyHealthIntelligenceContentPhase
    var sectionTitle: String
    var headline: String
    var days: [JourneyRecoveryDayState]
    var dayCount: Int
    var emptyMessage: String?
    var errorMessage: String?
    var accessibilityLabel: String

    static let loading = JourneyRecoveryTimelineState(
        phase: .loading,
        sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
        headline: FormaProductCopy.Journey.HealthIntelligence.loadingTitle,
        days: [],
        dayCount: 7,
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
    var caloriesLabel: String?
    var demandLabel: String?
    var intensityLabel: String?
    var shortExplanation: String?
    var accessibilityLabel: String
}

struct JourneyWorkoutHistoryGroupState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var date: Date
    var dateLabel: String
    var items: [JourneyWorkoutHistoryItemState]
    var accessibilityLabel: String
}

struct JourneyWorkoutHistoryState: Equatable, Sendable, Codable {
    var phase: JourneyHealthIntelligenceContentPhase
    var sectionTitle: String
    var headline: String
    var groups: [JourneyWorkoutHistoryGroupState]
    var items: [JourneyWorkoutHistoryItemState]
    var emptyKind: JourneyHealthIntelligenceEmptyKind?
    var emptyMessage: String?
    var errorMessage: String?
    var accessibilityLabel: String

    static let loading = JourneyWorkoutHistoryState(
        phase: .loading,
        sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
        headline: FormaProductCopy.Journey.HealthIntelligence.loadingTitle,
        groups: [],
        items: [],
        emptyKind: nil,
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

enum JourneyHealthMilestoneKind: Equatable, Sendable, Codable {
    case workoutStreak
    case longestWorkout
    case mostActiveDay
    case consistency
    case weeklyWin
    case weeklyFocus
}

/// Health Intelligence milestone item for Journey progress (distinct from gamification `JourneyMilestoneState`).
struct JourneyHealthMilestoneState: Equatable, Sendable, Identifiable, Codable {
    var id: String
    var kind: JourneyHealthMilestoneKind
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

enum JourneyHealthConnectionState: Equatable, Sendable, Codable {
    case unknown
    case notConnected
    case connected
}

struct JourneyHealthIntelligenceRecoveryDayInput: Equatable, Sendable {
    var date: Date
    var recovery: RecoverySummary
    var steps: Int?
}

struct JourneyHealthIntelligenceWorkoutRecordInput: Equatable, Sendable {
    var id: String
    var date: Date
    var title: String
    var durationMinutes: Int
    var activeCalories: Int?
    var demand: WorkoutDemand
    var intensity: WorkoutSummaryIntensity

    init(
        id: String = UUID().uuidString,
        date: Date,
        title: String,
        durationMinutes: Int,
        activeCalories: Int? = nil,
        demand: WorkoutDemand = .unknown,
        intensity: WorkoutSummaryIntensity = .unknown
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.durationMinutes = durationMinutes
        self.activeCalories = activeCalories
        self.demand = demand
        self.intensity = intensity
    }

    init(from record: HealthWorkoutRecord) {
        self.init(
            id: record.id.uuidString,
            date: record.startDate,
            title: record.activityName,
            durationMinutes: record.durationMinutes,
            activeCalories: record.activeCalories
        )
    }
}

struct JourneyHealthIntelligencePlanProgressInput: Equatable, Sendable {
    var proteinHitDays: Int?
    var loggingConsistencyDays: Int?
    var weightChangeKg: Double?
    var averageSteps: Int?
    var totalWorkouts: Int?
}

struct JourneyHealthIntelligenceBuildInput: Equatable, Sendable {
    var todaySnapshot: HealthIntelligenceSnapshot?
    var recoveryDays: [JourneyHealthIntelligenceRecoveryDayInput]
    var workoutRecords: [JourneyHealthIntelligenceWorkoutRecordInput]
    var weeklyReview: WeeklyHealthReview?
    var planProgress: JourneyHealthIntelligencePlanProgressInput?
    var healthConnection: JourneyHealthConnectionState
    var availability: HealthDataAvailability?
    var cachedDayCount: Int
    var recoveryTimelineDayCount: Int
    var isLoading: Bool
    var errorMessage: String?

    init(
        todaySnapshot: HealthIntelligenceSnapshot? = nil,
        recoveryDays: [JourneyHealthIntelligenceRecoveryDayInput] = [],
        workoutRecords: [JourneyHealthIntelligenceWorkoutRecordInput] = [],
        weeklyReview: WeeklyHealthReview? = nil,
        planProgress: JourneyHealthIntelligencePlanProgressInput? = nil,
        healthConnection: JourneyHealthConnectionState = .unknown,
        availability: HealthDataAvailability? = nil,
        cachedDayCount: Int = 0,
        recoveryTimelineDayCount: Int = 7,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.todaySnapshot = todaySnapshot
        self.recoveryDays = recoveryDays
        self.workoutRecords = workoutRecords
        self.weeklyReview = weeklyReview
        self.planProgress = planProgress
        self.healthConnection = healthConnection
        self.availability = availability
        self.cachedDayCount = cachedDayCount
        self.recoveryTimelineDayCount = recoveryTimelineDayCount
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }

    /// Legacy convenience for snapshot-only callers.
    init(
        currentSnapshot: HealthIntelligenceSnapshot?,
        historicalSnapshots: [HealthIntelligenceSnapshot] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        calendar: Calendar = .current
    ) {
        self.init(
            todaySnapshot: currentSnapshot,
            recoveryDays: Self.recoveryDays(
                from: currentSnapshot,
                historicalSnapshots: historicalSnapshots,
                calendar: calendar
            ),
            workoutRecords: Self.workoutRecords(
                from: currentSnapshot,
                historicalSnapshots: historicalSnapshots,
                calendar: calendar
            ),
            weeklyReview: currentSnapshot?.weeklyReview,
            planProgress: Self.planProgress(from: currentSnapshot?.weeklyReview),
            healthConnection: Self.healthConnection(from: currentSnapshot),
            recoveryTimelineDayCount: 7,
            isLoading: isLoading,
            errorMessage: errorMessage
        )
    }

    var currentSnapshot: HealthIntelligenceSnapshot? { todaySnapshot }

    var historicalSnapshots: [HealthIntelligenceSnapshot] {
        guard let todaySnapshot else { return [] }
        return [todaySnapshot]
    }

    private static func recoveryDays(
        from current: HealthIntelligenceSnapshot?,
        historicalSnapshots: [HealthIntelligenceSnapshot],
        calendar: Calendar
    ) -> [JourneyHealthIntelligenceRecoveryDayInput] {
        var byDay: [Date: HealthIntelligenceSnapshot] = [:]
        for snapshot in historicalSnapshots {
            byDay[calendar.startOfDay(for: snapshot.date)] = snapshot
        }
        if let current {
            byDay[calendar.startOfDay(for: current.date)] = current
        }

        return byDay.values.map { snapshot in
            JourneyHealthIntelligenceRecoveryDayInput(
                date: snapshot.date,
                recovery: snapshot.recovery,
                steps: snapshot.activity.steps
            )
        }
    }

    private static func workoutRecords(
        from current: HealthIntelligenceSnapshot?,
        historicalSnapshots: [HealthIntelligenceSnapshot],
        calendar: Calendar
    ) -> [JourneyHealthIntelligenceWorkoutRecordInput] {
        var snapshots = historicalSnapshots
        if let current {
            snapshots.append(current)
        }

        return snapshots.compactMap { snapshot -> JourneyHealthIntelligenceWorkoutRecordInput? in
            guard let workout = snapshot.workout, workout.hasWorkout else { return nil }
            return JourneyHealthIntelligenceWorkoutRecordInput(
                id: "\(calendar.startOfDay(for: snapshot.date).timeIntervalSince1970)-workout",
                date: snapshot.date,
                title: workout.title,
                durationMinutes: workout.totalDurationMinutes,
                activeCalories: workout.totalActiveCalories,
                demand: workout.demand,
                intensity: workout.intensity
            )
        }
    }

    private static func planProgress(from review: WeeklyHealthReview?) -> JourneyHealthIntelligencePlanProgressInput? {
        guard let review else { return nil }
        return JourneyHealthIntelligencePlanProgressInput(
            proteinHitDays: review.stats.proteinHitDays,
            loggingConsistencyDays: review.stats.loggingConsistencyDays,
            weightChangeKg: review.stats.weightChangeKg,
            averageSteps: review.stats.averageSteps,
            totalWorkouts: review.stats.totalWorkouts
        )
    }

    private static func healthConnection(from snapshot: HealthIntelligenceSnapshot?) -> JourneyHealthConnectionState {
        guard let snapshot else { return .unknown }
        if snapshot.nextBestAction.reason == .connectHealth, !snapshot.nextBestAction.id.isEmpty {
            return .notConnected
        }
        return .connected
    }
}
