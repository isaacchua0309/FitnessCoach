//
//  HealthIntelligenceAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Health Intelligence analytics events and safe property bag.
//  Privacy: no raw HealthKit values, HRV/RHR, workout titles, or food text.
//

import Foundation

enum HealthIntelligenceAnalyticsEvent: String, Sendable {
    case snapshotLoaded = "health_intelligence_snapshot_loaded"
    case snapshotFailed = "health_intelligence_snapshot_failed"
    case todayRecoveryCardViewed = "today_recovery_card_viewed"
    case todayNextBestActionTapped = "today_next_best_action_tapped"
    case coachHealthContextUsed = "coach_health_context_used"
    case journeyRecoveryTimelineViewed = "journey_recovery_timeline_viewed"
    case journeyWorkoutHistoryViewed = "journey_workout_history_viewed"
    case weeklyReviewCardViewed = "weekly_review_card_viewed"
    case weeklyReviewDetailOpened = "weekly_review_detail_opened"
    case planHealthConfidenceViewed = "plan_health_confidence_viewed"
    case healthPermissionCTATapped = "health_permission_cta_tapped"
}

enum HealthIntelligenceAnalyticsDataState: String, Sendable {
    case full
    case partial
    case none
    case unavailable
}

enum HealthIntelligenceAnalyticsPermissionCTASurface: String, Sendable {
    case today
    case journey
    case plan
}

enum HealthIntelligenceAnalyticsFailureReason: String, Sendable {
    case unknown
    case cancelled
    case syncFailed
    case unavailable
}

struct HealthIntelligenceAnalyticsProperties: Sendable {
    var healthDataState: String?
    var recoveryStatus: String?
    var confidenceBucket: String?
    var hasWorkoutToday: Bool?
    var missingSignalCount: Int?
    var featureFlagState: String?
    var surface: String?
    var actionType: String?
    var ctaSurface: String?
    var failureReason: String?

    static let empty = HealthIntelligenceAnalyticsProperties()

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let healthDataState { parameters["health_data_state"] = healthDataState }
        if let recoveryStatus { parameters["recovery_status"] = recoveryStatus }
        if let confidenceBucket { parameters["confidence_bucket"] = confidenceBucket }
        if let hasWorkoutToday {
            parameters["has_workout_today"] = hasWorkoutToday ? "true" : "false"
        }
        if let missingSignalCount {
            parameters["missing_signal_count"] = String(missingSignalCount)
        }
        if let featureFlagState { parameters["feature_flag_state"] = featureFlagState }
        if let surface { parameters["surface"] = surface }
        if let actionType { parameters["action_type"] = actionType }
        if let ctaSurface { parameters["cta_surface"] = ctaSurface }
        if let failureReason { parameters["failure_reason"] = failureReason }
        return parameters
    }

    func merging(_ other: HealthIntelligenceAnalyticsProperties) -> HealthIntelligenceAnalyticsProperties {
        var merged = self
        if let healthDataState = other.healthDataState { merged.healthDataState = healthDataState }
        if let recoveryStatus = other.recoveryStatus { merged.recoveryStatus = recoveryStatus }
        if let confidenceBucket = other.confidenceBucket { merged.confidenceBucket = confidenceBucket }
        if let hasWorkoutToday = other.hasWorkoutToday { merged.hasWorkoutToday = hasWorkoutToday }
        if let missingSignalCount = other.missingSignalCount { merged.missingSignalCount = missingSignalCount }
        if let featureFlagState = other.featureFlagState { merged.featureFlagState = featureFlagState }
        if let surface = other.surface { merged.surface = surface }
        if let actionType = other.actionType { merged.actionType = actionType }
        if let ctaSurface = other.ctaSurface { merged.ctaSurface = ctaSurface }
        if let failureReason = other.failureReason { merged.failureReason = failureReason }
        return merged
    }
}

protocol HealthIntelligenceAnalyticsLogging: Sendable {
    func log(_ event: HealthIntelligenceAnalyticsEvent, properties: HealthIntelligenceAnalyticsProperties)
}

enum HealthIntelligenceAnalyticsContextBuilder {

    static func properties(
        from context: HealthIntelligencePresentationContext,
        surface: HealthIntelligenceSurface,
        confidenceBucket: String? = nil
    ) -> HealthIntelligenceAnalyticsProperties {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(context)
        let snapshot = context.snapshot
        let resolvedConfidence = confidenceBucket
            ?? snapshot.map { confidenceBucket(from: $0.planConfidence) }

        return HealthIntelligenceAnalyticsProperties(
            healthDataState: healthDataState(from: lifecycle).rawValue,
            recoveryStatus: snapshot?.recovery.status.rawValue ?? RecoveryStatus.unknown.rawValue,
            confidenceBucket: resolvedConfidence,
            hasWorkoutToday: snapshot?.workout?.hasWorkout,
            missingSignalCount: snapshot.map { $0.recovery.missingSignals.count },
            featureFlagState: featureFlagState(),
            surface: surface.rawValue
        )
    }

    static func properties(
        from snapshot: HealthIntelligenceSnapshot?,
        surface: HealthIntelligenceSurface,
        isAppleHealthConnected: Bool = false,
        cachedDayCount: Int = 0,
        availability: HealthDataAvailability? = nil,
        confidenceBucket: String? = nil
    ) -> HealthIntelligenceAnalyticsProperties {
        let context = HealthIntelligencePresentationContext(
            isLoading: false,
            availability: availability,
            snapshot: snapshot,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount
        )
        return properties(
            from: context,
            surface: surface,
            confidenceBucket: confidenceBucket ?? snapshot.map { confidenceBucket(from: $0.planConfidence) }
        )
    }

    static func healthDataState(
        from lifecycle: HealthIntelligencePresentationLifecycle
    ) -> HealthIntelligenceAnalyticsDataState {
        switch lifecycle {
        case .ready:
            return .full
        case .partialHealthPermission, .limitedEstimate:
            return .partial
        case .noHealthPermission, .noHealthDataYet:
            return .none
        case .loading, .syncFailed, .unavailableOnDevice:
            return .unavailable
        }
    }

    static func confidenceBucket(from confidence: PlanHealthConfidence) -> String {
        let normalized = confidence.label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.contains("strong") || normalized.contains("high") {
            return "high"
        }
        if normalized.contains("moderate") || normalized.contains("reasonable") {
            return "moderate"
        }
        if normalized.contains("limited") || normalized.contains("low") {
            return "low"
        }
        return "unknown"
    }

    static func confidenceBucket(from label: String) -> String {
        confidenceBucket(from: PlanHealthConfidence(score: 0, label: label))
    }

    static func nextBestActionType(for destination: TodayHealthNextBestActionDestination) -> String {
        switch destination {
        case .logMeal: return "log_meal"
        case .addWater: return "add_water"
        case .askCoach: return "ask_coach"
        case .viewRecovery: return "view_recovery"
        case .logWeight: return "log_weight"
        case .connectHealth: return "connect_health"
        case .none: return "none"
        }
    }

    static func featureFlagState(
        from snapshot: HealthIntelligenceFeatureFlags.Snapshot = HealthIntelligenceFeatureFlags.snapshot()
    ) -> String {
        [
            "foundation:\(snapshot.healthIntelligenceEnabled ? 1 : 0)",
            "engines:\(snapshot.healthIntelligenceEnginesEnabled ? 1 : 0)",
            "ui:\(snapshot.healthIntelligenceUIEnabled ? 1 : 0)",
            "coach:\(snapshot.healthIntelligenceCoachContextEnabled ? 1 : 0)",
            "weekly:\(snapshot.healthIntelligenceWeeklyReviewEnabled ? 1 : 0)",
        ].joined(separator: ",")
    }

    static func failureReason(
        for error: Error?,
        context: HealthIntelligencePresentationContext
    ) -> HealthIntelligenceAnalyticsFailureReason {
        if error is CancellationError {
            return .cancelled
        }

        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(context)
        switch lifecycle {
        case .syncFailed:
            return .syncFailed
        case .unavailableOnDevice:
            return .unavailable
        default:
            return .unknown
        }
    }
}
