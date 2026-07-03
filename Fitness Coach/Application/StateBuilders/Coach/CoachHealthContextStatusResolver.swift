//
//  CoachHealthContextStatusResolver.swift
//  Fitness Coach
//
//  Forma — Maps Health Intelligence inputs into Coach-safe context status and signal lists.
//

import Foundation

enum CoachHealthContextStatusResolver {

    struct Input: Equatable, Sendable {
        var snapshot: HealthIntelligenceSnapshot?
        var availability: HealthDataAvailability?
        var baseline: HealthBaselineContext?
        var lastHealthSyncAt: Date?
        var isAppleHealthConnected: Bool = false
        var syncPhase: HealthSyncPhase? = nil
        var remoteSyncConsentDecision: HealthSummarySyncConsentDecision = .notDetermined
        var isRemoteSyncCapabilityEnabled: Bool = false
        var awarenessAvailable: Bool = true
        var now: Date = Date()
        var staleAfter: TimeInterval = HealthIntelligenceUIStatePolicy.defaultStaleInterval
    }

    static func resolveStatus(from input: Input) -> CoachHealthContextStatus {
        guard input.awarenessAvailable else { return .unavailable }
        guard input.snapshot != nil else { return .unavailable }

        let uiState = HealthIntelligenceUIStateMapper.resolve(uiContext(from: input))

        switch uiState.kind {
        case .ready:
            return .available
        case .staleData:
            return .stale
        case .syncFailed:
            return uiState.canShowInsight ? .stale : .unavailable
        case .partialPermission, .noSleepData, .noHeartData, .noWorkoutHistory, .notEnoughBaseline:
            return uiState.canShowInsight ? .partial : .unavailable
        case .unknown:
            return uiState.canShowInsight ? .partial : .unavailable
        case .loading, .noHealthPermission, .healthKitUnavailable, .remoteSyncDisabled:
            return .unavailable
        }
    }

    static func availableSignalLabels(from input: Input) -> [String] {
        guard input.awarenessAvailable else { return [] }

        return HealthInsightAvailabilityResolver.resolveAll(from: uiContext(from: input))
            .filter(\.isAvailable)
            .map(\.kind)
            .filter { $0 != .remoteSync }
            .map(\.coachPromptLabel)
            .sorted()
    }

    static func missingSignalLabels(from input: Input) -> [String] {
        guard input.awarenessAvailable else {
            return coachFacingUnavailableSignals(from: input)
        }

        let missing = HealthInsightAvailabilityResolver.missing(from: uiContext(from: input))
            .map(\.kind)
            .filter { $0 != .remoteSync }
            .map(\.coachPromptLabel)

        if missing.isEmpty {
            return legacyMissingSignalLabels(from: input)
        }

        return Array(Set(missing)).sorted()
    }

    // MARK: - Private

    private static func uiContext(from input: Input) -> HealthIntelligenceUIContext {
        HealthIntelligenceUIContext.from(
            presentationContext: HealthIntelligencePresentationContext(
                isLoading: input.syncPhase == .syncing,
                explicitErrorMessage: input.syncPhase == .failed ? "sync_failed" : nil,
                syncPhase: input.syncPhase,
                availability: input.availability,
                snapshot: input.snapshot,
                isAppleHealthConnected: input.isAppleHealthConnected,
                cachedDayCount: input.availability?.cachedDayCount ?? 0
            ),
            baseline: input.baseline,
            lastSuccessfulLocalSyncAt: input.lastHealthSyncAt,
            isRemoteSyncCapabilityEnabled: input.isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: input.remoteSyncConsentDecision,
            surface: .coach,
            now: input.now
        )
    }

    private static func coachFacingUnavailableSignals(from input: Input) -> [String] {
        if input.snapshot?.nextBestAction.reason == .connectHealth {
            return ["Apple Health connection"]
        }

        if input.availability?.isHealthDataAvailable == false {
            return ["Apple Health on this device"]
        }

        return ["health data"]
    }

    private static func legacyMissingSignalLabels(from input: Input) -> [String] {
        guard let snapshot = input.snapshot else { return [] }

        return CoachHealthIntelligenceContextBuilder.plainLanguageMissingSignals(
            recovery: snapshot.recovery,
            nutrition: snapshot.nutritionAdjustment,
            trainingLoad: .unknown
        )
    }
}
