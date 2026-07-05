//
//  HealthIntelligenceSectionLoaderCore.swift
//  Fitness Coach
//
//  Forma — Shared Health Intelligence loading and UI-state gating helpers used by
//  Today, Plan, and Journey section loaders and presentation builders.
//

import Foundation

enum HealthIntelligenceSectionLoaderCore {

    // MARK: - Parallel fetch

    struct SnapshotAvailabilityLoadResult: Sendable {
        let snapshot: HealthIntelligenceSnapshot?
        let availability: HealthDataAvailability
    }

    static func loadTodaySnapshotAndAvailability(
        referenceDate: Date,
        snapshotProvider: any HealthIntelligenceSnapshotServing,
        healthDataRepository: any HealthDataRepositorying,
        calendar: Calendar = .current
    ) async -> SnapshotAvailabilityLoadResult {
        async let snapshotTask = snapshotProvider.loadTodaySnapshot(
            for: referenceDate,
            calendar: calendar
        )
        async let availabilityTask = healthDataRepository.getHealthDataAvailability()

        return SnapshotAvailabilityLoadResult(
            snapshot: await snapshotTask,
            availability: await availabilityTask
        )
    }

    // MARK: - Connection classification

    static func snapshotPromptsConnectHealth(_ snapshot: HealthIntelligenceSnapshot?) -> Bool {
        guard let snapshot else { return false }
        return snapshot.nextBestAction.reason == .connectHealth
            && !snapshot.nextBestAction.id.isEmpty
    }

    static func journeyHealthConnection(
        isAppleHealthConnected: Bool,
        availability: HealthDataAvailability,
        todaySnapshot: HealthIntelligenceSnapshot?
    ) -> JourneyHealthConnectionState {
        if snapshotPromptsConnectHealth(todaySnapshot) {
            return .notConnected
        }

        if isAppleHealthConnected || availability.hasAnyReadableSignal {
            return .connected
        }

        return .notConnected
    }

    // MARK: - UI gating

    static func shouldShowConnectOnlySection(uiState: HealthIntelligenceUIState) -> Bool {
        switch uiState.kind {
        case .noHealthPermission, .healthKitUnavailable:
            return !uiState.canShowInsight
        default:
            return false
        }
    }

    // MARK: - UI state resolution

    static func resolveUIState(
        snapshot: HealthIntelligenceSnapshot?,
        isLoading: Bool,
        availability: HealthDataAvailability?,
        isAppleHealthConnected: Bool,
        cachedDayCount: Int,
        errorMessage: String?,
        syncPhase: HealthSyncPhase?,
        surface: HealthIntelligenceSurface,
        baseline: HealthBaselineContext? = nil,
        lastSuccessfulLocalSyncAt: Date? = nil,
        isRemoteSyncCapabilityEnabled: Bool = false,
        remoteSyncConsentDecision: HealthSummarySyncConsentDecision = .notDetermined,
        trainingIntegrationState: TrainingIntegrationState = .notConnected,
        connectionRecord: HealthIntegrationConnectionRecord = .empty
    ) -> HealthIntelligenceUIState {
        let presentationContext = HealthIntelligencePresentationCore.presentationContext(
            snapshot: snapshot,
            isLoading: isLoading,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount,
            errorMessage: errorMessage,
            syncPhase: syncPhase,
            trainingIntegrationState: trainingIntegrationState,
            connectionRecord: connectionRecord,
            baseline: baseline
        )

        return HealthIntelligencePresentationCore.resolveUIState(
            from: HealthIntelligenceUIResolutionInput(
                presentationContext: presentationContext,
                baseline: baseline,
                lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
                isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
                remoteSyncConsentDecision: remoteSyncConsentDecision,
                surface: surface
            )
        )
    }

    // MARK: - Weekly review

    static func loadWeeklyReview(
        referenceDate: Date,
        provider: any WeeklyReviewServing,
        forceRefresh: Bool,
        calendar: Calendar
    ) async -> WeeklyHealthReview? {
        if forceRefresh,
           let weekStart = WeeklyReviewWeekPolicy.latestCompletedWeekStart(
               referenceDate: referenceDate,
               calendar: calendar
           ) {
            return await provider.generateWeeklyReview(
                for: weekStart,
                forceRefresh: true,
                allowPreview: false,
                calendar: calendar
            )
        }

        return await provider.getLatestCompletedWeeklyReview(calendar: calendar)
    }

    // MARK: - Integration status input

    static func integrationStatusInput(
        availability: HealthDataAvailability?,
        trainingIntegrationState: TrainingIntegrationState,
        connectionRecord: HealthIntegrationConnectionRecord,
        snapshot: HealthIntelligenceSnapshot?,
        baseline: HealthBaselineContext?,
        cachedDayCount: Int
    ) -> HealthIntegrationStatusInput {
        HealthIntegrationStatusInput(
            isHealthDataAvailable: availability?.isHealthDataAvailable ?? true,
            permissionStatus: availability?.permissionStatus,
            trainingIntegrationState: trainingIntegrationState,
            connectionRecord: connectionRecord,
            snapshot: snapshot,
            baseline: baseline,
            cachedDayCount: cachedDayCount
        )
    }
}
