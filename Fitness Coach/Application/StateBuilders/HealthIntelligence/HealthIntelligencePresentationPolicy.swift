//
//  HealthIntelligencePresentationPolicy.swift
//  Fitness Coach
//
//  Forma — Surface-specific presentation policy for Health Intelligence UI state.
//  Encodes per-tab differences in fallback copy, stale labels, and partial-signal
//  gating without moving section layout or card visibility into the core.
//

import Foundation

enum HealthIntelligencePresentationPolicy {

    // MARK: - Section-level messages

    static func fallbackMessage(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface
    ) -> String? {
        switch surface {
        case .today:
            return todayFallbackMessage(for: uiState)
        case .plan:
            return planFallbackMessage(for: uiState)
        case .journey:
            return journeyFallbackMessage(for: uiState)
        case .coach:
            return planFallbackMessage(for: uiState)
        }
    }

    static func staleDataLabel(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface
    ) -> String? {
        switch uiState.kind {
        case .staleData:
            return HealthIntelligencePresentationCopy.staleDataLabel(for: surface)
        case .syncFailed where uiState.canShowInsight:
            return HealthIntelligencePresentationCopy.syncFailedWithCacheLabel(for: surface)
        default:
            return nil
        }
    }

    static func partialSignalsNote(
        for uiState: HealthIntelligenceUIState,
        surface: HealthIntelligenceSurface
    ) -> String? {
        guard surface == .journey else { return nil }
        guard uiState.kind == .partialPermission || !uiState.missingInsightKinds.isEmpty else {
            return nil
        }
        guard uiState.canShowInsight else { return nil }

        let labels = uiState.missingInsightKinds
            .filter { $0 != .remoteSync }
            .map { journeyInsightLabel(for: $0) }
            .sorted()
        guard !labels.isEmpty else {
            return nil
        }
        return HealthIntelligencePresentationCopy.Journey.healthDataSyncing
    }

    static func syncFailureSectionMessage(for uiState: HealthIntelligenceUIState) -> String? {
        guard uiState.kind == .syncFailed, uiState.canShowInsight else { return nil }
        return uiState.message
    }

    // MARK: - Recovery wording

    static func shouldPreferLimitedRecoveryWording(
        for recovery: RecoverySummary,
        surface: HealthIntelligenceSurface
    ) -> Bool {
        if recovery.confidence == .low || recovery.confidence == .unknown {
            return true
        }
        if recovery.status == .unknown {
            return true
        }
        return hasMissingHeartOrSleepSignals(recovery.missingSignals, surface: surface)
    }

    static func limitedRecoveryExplanation(
        for recovery: RecoverySummary,
        surface: HealthIntelligenceSurface
    ) -> String {
        switch surface {
        case .today:
            if hasMissingHeartOrSleepSignals(recovery.missingSignals, surface: .today) {
                return HealthIntelligencePresentationCopy.Today.limitedRecoveryMissingSignals
            }
            if recovery.status == .unknown {
                return HealthIntelligencePresentationCopy.Today.limitedRecoveryUnavailable
            }
            return HealthIntelligencePresentationCopy.Today.limitedRecoveryPartialSignals
        case .journey:
            if hasMissingHeartOrSleepSignals(recovery.missingSignals, surface: .journey) {
                return HealthIntelligencePresentationCopy.Journey.Recovery.limitedMissingSignals
            }
            if recovery.status == .unknown {
                return HealthIntelligencePresentationCopy.Journey.Recovery.unavailableSignals
            }
            return HealthIntelligencePresentationCopy.Journey.Recovery.partialSignals
        case .plan, .coach:
            if hasMissingHeartOrSleepSignals(recovery.missingSignals, surface: .today) {
                return HealthIntelligencePresentationCopy.Today.limitedRecoveryMissingSignals
            }
            if recovery.status == .unknown {
                return HealthIntelligencePresentationCopy.Today.limitedRecoveryUnavailable
            }
            return HealthIntelligencePresentationCopy.Today.limitedRecoveryPartialSignals
        }
    }

    static func statusBasedRecoveryExplanation(
        for recovery: RecoverySummary,
        surface: HealthIntelligenceSurface
    ) -> String? {
        guard surface == .today || surface == .plan || surface == .coach else { return nil }
        switch recovery.status {
        case .ready:
            return HealthIntelligencePresentationCopy.Today.Recovery.readyExplanation
        case .moderate:
            return HealthIntelligencePresentationCopy.Today.Recovery.moderateExplanation
        case .low:
            return HealthIntelligencePresentationCopy.Today.Recovery.lowExplanation
        case .unknown:
            return HealthIntelligencePresentationCopy.Today.limitedRecoveryUnavailable
        }
    }

    static func missingRecoverySignalsNote(
        for recovery: RecoverySummary,
        surface: HealthIntelligenceSurface
    ) -> String? {
        guard surface == .today || surface == .plan || surface == .coach else { return nil }
        guard !recovery.missingSignals.isEmpty else { return nil }

        var labels: [String] = []
        if recovery.missingSignals.contains(.sleep) {
            labels.append("sleep")
        }
        if recovery.missingSignals.contains(.hrv) {
            labels.append("HRV")
        }
        if recovery.missingSignals.contains(.restingHeartRate) {
            labels.append("resting heart rate")
        }
        if recovery.missingSignals.contains(.activity) {
            labels.append("activity")
        }
        if recovery.missingSignals.contains(.workouts) {
            labels.append("workouts")
        }
        if recovery.missingSignals.contains(.trainingLoad) {
            labels.append("training load")
        }

        guard !labels.isEmpty else { return nil }
        return HealthIntelligencePresentationCopy.Shared.missingRecoverySignals(labels)
    }

    static func mergedConfidenceNote(
        recoveryConfidence: String?,
        uiState: HealthIntelligenceUIState?
    ) -> String? {
        guard let uiState else { return recoveryConfidence }

        switch uiState.kind {
        case .partialPermission, .noSleepData, .noHeartData, .notEnoughBaseline, .staleData:
            return uiState.confidenceLabel ?? recoveryConfidence
        case .ready:
            return recoveryConfidence ?? uiState.confidenceLabel
        default:
            return recoveryConfidence
        }
    }

    static func confidenceNote(for confidence: RecoveryConfidence) -> String? {
        switch confidence {
        case .low, .unknown:
            return HealthIntelligencePresentationCopy.Shared.limitedEstimateLabel
        case .moderate, .high:
            return nil
        }
    }

    static func adaptiveNutritionConfidenceNote(for confidence: AdaptiveNutritionConfidence) -> String? {
        confidence == .low
            ? HealthIntelligencePresentationCopy.Today.limitedEstimate
            : nil
    }

    // MARK: - Connect / unavailable states

    static func shouldShowConnectOnlySection(uiState: HealthIntelligenceUIState) -> Bool {
        switch uiState.kind {
        case .noHealthPermission, .healthKitUnavailable:
            return !uiState.canShowInsight
        default:
            return false
        }
    }

    static func workoutHistoryEmptyMessage(
        isHealthConnected: Bool,
        uiState: HealthIntelligenceUIState?,
        surface: HealthIntelligenceSurface
    ) -> String {
        guard surface == .journey else {
            return HealthIntelligencePresentationCopy.Today.Workout.emptyMessage
        }
        if isHealthConnected {
            if uiState?.kind == .noWorkoutHistory {
                return HealthIntelligencePresentationCopy.uiStateMessage(
                    for: .noWorkoutHistory,
                    surface: .journey
                ).message
            }
            return HealthIntelligencePresentationCopy.Journey.connectedNoWorkoutsMessage
        }
        return HealthIntelligencePresentationCopy.Journey.WorkoutHistory.emptyMessage
    }

    // MARK: - Private

    private static func todayFallbackMessage(for uiState: HealthIntelligenceUIState) -> String? {
        switch uiState.kind {
        case .ready, .loading, .staleData:
            return nil
        case .partialPermission, .noSleepData, .noHeartData, .noWorkoutHistory:
            return uiState.canShowInsight ? nil : uiState.message
        case .syncFailed:
            return uiState.canShowInsight ? nil : uiState.message
        case .remoteSyncDisabled:
            return uiState.canShowInsight ? nil : uiState.message
        case .noHealthPermission, .healthKitUnavailable, .notEnoughBaseline, .unknown:
            return uiState.message
        }
    }

    private static func planFallbackMessage(for uiState: HealthIntelligenceUIState) -> String? {
        switch uiState.kind {
        case .ready, .loading, .staleData:
            return nil
        case .partialPermission, .noSleepData, .noHeartData, .noWorkoutHistory, .notEnoughBaseline:
            return uiState.message
        case .syncFailed:
            return uiState.canShowInsight ? nil : uiState.message
        case .noHealthPermission, .healthKitUnavailable:
            return uiState.message
        case .remoteSyncDisabled, .unknown:
            return uiState.message
        }
    }

    private static func journeyFallbackMessage(for uiState: HealthIntelligenceUIState) -> String? {
        switch uiState.kind {
        case .ready, .loading, .staleData, .noHealthPermission, .healthKitUnavailable:
            return nil
        case .partialPermission, .noSleepData, .noHeartData, .noWorkoutHistory, .notEnoughBaseline:
            return uiState.canShowInsight ? uiState.message : nil
        case .syncFailed:
            return uiState.canShowInsight ? nil : uiState.message
        case .remoteSyncDisabled, .unknown:
            return uiState.canShowInsight ? uiState.message : uiState.message
        }
    }

    private static func hasMissingHeartOrSleepSignals(
        _ signals: Set<RecoveryMissingSignal>,
        surface: HealthIntelligenceSurface
    ) -> Bool {
        switch surface {
        case .journey:
            return signals.contains(.sleep)
                && (signals.contains(.hrv) || signals.contains(.restingHeartRate))
        case .today, .plan, .coach:
            return signals.contains(.sleep)
                || signals.contains(.hrv)
                || signals.contains(.restingHeartRate)
        }
    }

    static func insightLabel(for kind: HealthInsightKind) -> String {
        switch kind {
        case .workouts: return "workouts"
        case .steps: return "steps"
        case .sleep: return "sleep"
        case .restingHeartRate, .hrv: return "heart"
        case .weight: return "weight"
        case .activeEnergy: return "active energy"
        case .exerciseMinutes: return "exercise minutes"
        case .recoveryBaseline: return "recovery baseline"
        case .remoteSync: return "health data sync"
        }
    }

    static func journeyInsightLabel(for kind: HealthInsightKind) -> String {
        switch kind {
        case .remoteSync:
            return "health data sync"
        default:
            return insightLabel(for: kind)
        }
    }
}
