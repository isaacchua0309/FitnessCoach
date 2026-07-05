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
            return staleDataCopy(for: surface).stale
        case .syncFailed where uiState.canShowInsight:
            return staleDataCopy(for: surface).syncFailedWithCache
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
            return uiState.kind == .partialPermission ? uiState.message : nil
        }
        return "Missing signals: \(labels.joined(separator: ", "))."
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
                return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryMissingSignals
            }
            if recovery.status == .unknown {
                return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryUnavailable
            }
            return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryPartialSignals
        case .journey:
            if hasMissingHeartOrSleepSignals(recovery.missingSignals, surface: .journey) {
                return "Limited estimate because key recovery signals are missing."
            }
            if recovery.status == .unknown {
                return "Not enough recovery signals yet."
            }
            return "Limited estimate from partial recovery signals."
        case .plan, .coach:
            if hasMissingHeartOrSleepSignals(recovery.missingSignals, surface: .today) {
                return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryMissingSignals
            }
            if recovery.status == .unknown {
                return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryUnavailable
            }
            return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryPartialSignals
        }
    }

    static func statusBasedRecoveryExplanation(
        for recovery: RecoverySummary,
        surface: HealthIntelligenceSurface
    ) -> String? {
        guard surface == .today || surface == .plan || surface == .coach else { return nil }
        switch recovery.status {
        case .ready:
            return FormaProductCopy.Today.HealthIntelligence.Recovery.readyExplanation
        case .moderate:
            return FormaProductCopy.Today.HealthIntelligence.Recovery.moderateExplanation
        case .low:
            return FormaProductCopy.Today.HealthIntelligence.Recovery.lowExplanation
        case .unknown:
            return FormaProductCopy.Today.HealthIntelligence.limitedRecoveryUnavailable
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
        return FormaProductCopy.Today.HealthIntelligence.missingRecoverySignals(labels)
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
            return FormaProductCopy.HealthIntelligence.limitedEstimateLabel
        case .moderate, .high:
            return nil
        }
    }

    static func adaptiveNutritionConfidenceNote(for confidence: AdaptiveNutritionConfidence) -> String? {
        confidence == .low
            ? FormaProductCopy.Today.HealthIntelligence.limitedEstimate
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
            return FormaProductCopy.Today.HealthIntelligence.Workout.emptyMessage
        }
        if isHealthConnected {
            if uiState?.kind == .noWorkoutHistory {
                return FormaProductCopy.HealthIntelligence.UIState.message(
                    for: .noWorkoutHistory,
                    surface: .journey,
                    explicitErrorMessage: nil
                ).message
            }
            return FormaProductCopy.Journey.HealthIntelligence.connectedNoWorkoutsMessage
        }
        return FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.emptyMessage
    }

    // MARK: - Private

    private struct StaleDataCopy {
        let stale: String
        let syncFailedWithCache: String
    }

    private static func staleDataCopy(for surface: HealthIntelligenceSurface) -> StaleDataCopy {
        switch surface {
        case .journey:
            return StaleDataCopy(
                stale: FormaProductCopy.Journey.HealthIntelligence.staleDataLabel,
                syncFailedWithCache: FormaProductCopy.Journey.HealthIntelligence.syncFailedWithCacheLabel
            )
        case .today, .plan, .coach:
            return StaleDataCopy(
                stale: FormaProductCopy.Today.HealthIntelligence.staleDataLabel,
                syncFailedWithCache: FormaProductCopy.Today.HealthIntelligence.syncFailedWithCacheLabel
            )
        }
    }

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
