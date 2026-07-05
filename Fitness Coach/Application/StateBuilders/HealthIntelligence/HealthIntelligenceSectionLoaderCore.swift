//
//  HealthIntelligenceSectionLoaderCore.swift
//  Fitness Coach
//
//  Forma — Shared Health Intelligence loading and UI-state gating helpers used by
//  Today, Plan, and Journey section loaders and presentation builders.
//

import Foundation

// MARK: - Section loading classification

enum HealthIntelligenceSectionAvailability: Equatable, Sendable {
    case disabled
    case healthUnavailable
    case disconnected
    case loading
    case empty
    case ready
    case stale
    case partial
}

struct HealthIntelligenceSectionLoadingResult: Equatable, Sendable {
    let availability: HealthIntelligenceSectionAvailability
    let shouldShowSection: Bool
    let staleDataLabel: String?
    let partialSignalsLabel: String?
    let unavailableReason: String?
}

struct HealthIntelligenceSectionLoadingInput: Equatable, Sendable {
    var isUIEnabled: Bool = true
    var isLoading: Bool = false
    var enginesEnabled: Bool = true
    var weeklyReviewEnabled: Bool = true
    var weeklyReview: WeeklyHealthReview? = nil
    var snapshot: HealthIntelligenceSnapshot? = nil
    var availability: HealthDataAvailability? = nil
    var isAppleHealthConnected: Bool = false
    var cachedDayCount: Int = 0
    var errorMessage: String? = nil
    var syncPhase: HealthSyncPhase? = nil
    var lastSuccessfulLocalSyncAt: Date? = nil
    var baseline: HealthBaselineContext? = nil
    var surface: HealthIntelligenceSurface = .today
    var trainingIntegrationState: TrainingIntegrationState = .notConnected
    var connectionRecord: HealthIntegrationConnectionRecord = .empty
    var isRemoteSyncCapabilityEnabled: Bool = false
    var remoteSyncConsentDecision: HealthSummarySyncConsentDecision = .notDetermined
}

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

    // MARK: - Section loading / gating classification

    /// Classifies shared loading and gating state for Today, Plan, and Journey.
    /// Tab loaders retain surface-specific fetch orchestration and presentation wiring.
    static func classifySectionLoading(
        from input: HealthIntelligenceSectionLoadingInput
    ) -> HealthIntelligenceSectionLoadingResult {
        guard input.isUIEnabled else {
            return HealthIntelligenceSectionLoadingResult(
                availability: .disabled,
                shouldShowSection: false,
                staleDataLabel: nil,
                partialSignalsLabel: nil,
                unavailableReason: nil
            )
        }

        if input.isLoading || input.syncPhase == .syncing {
            return makeLoadingResult()
        }

        let uiState = resolveUIState(from: input)

        if uiState.kind == .loading {
            return makeLoadingResult()
        }

        let availability = mapSectionAvailability(uiState: uiState, input: input)
        return makeResult(availability: availability, uiState: uiState, input: input)
    }

    // MARK: - UI gating

    static func shouldShowConnectOnlySection(uiState: HealthIntelligenceUIState) -> Bool {
        HealthIntelligencePresentationPolicy.shouldShowConnectOnlySection(uiState: uiState)
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

    static func resolveUIState(
        from input: HealthIntelligenceSectionLoadingInput
    ) -> HealthIntelligenceUIState {
        resolveUIState(
            snapshot: input.snapshot,
            isLoading: false,
            availability: input.availability,
            isAppleHealthConnected: input.isAppleHealthConnected,
            cachedDayCount: resolvedCachedDayCount(from: input),
            errorMessage: input.errorMessage,
            syncPhase: input.syncPhase,
            surface: input.surface,
            baseline: input.baseline,
            lastSuccessfulLocalSyncAt: input.lastSuccessfulLocalSyncAt,
            isRemoteSyncCapabilityEnabled: input.isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: input.remoteSyncConsentDecision,
            trainingIntegrationState: input.trainingIntegrationState,
            connectionRecord: input.connectionRecord
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

    // MARK: - Private classification helpers

    private static func makeLoadingResult() -> HealthIntelligenceSectionLoadingResult {
        HealthIntelligenceSectionLoadingResult(
            availability: .loading,
            shouldShowSection: true,
            staleDataLabel: nil,
            partialSignalsLabel: nil,
            unavailableReason: nil
        )
    }

    private static func makeResult(
        availability: HealthIntelligenceSectionAvailability,
        uiState: HealthIntelligenceUIState,
        input: HealthIntelligenceSectionLoadingInput
    ) -> HealthIntelligenceSectionLoadingResult {
        HealthIntelligenceSectionLoadingResult(
            availability: availability,
            shouldShowSection: input.isUIEnabled,
            staleDataLabel: HealthIntelligencePresentationCore.staleDataLabel(
                for: uiState,
                surface: input.surface
            ),
            partialSignalsLabel: HealthIntelligencePresentationCore.partialSignalsNote(
                for: uiState,
                surface: input.surface
            ),
            unavailableReason: unavailableReason(
                availability: availability,
                uiState: uiState,
                input: input
            )
        )
    }

    private static func mapSectionAvailability(
        uiState: HealthIntelligenceUIState,
        input: HealthIntelligenceSectionLoadingInput
    ) -> HealthIntelligenceSectionAvailability {
        if snapshotPromptsConnectHealth(input.snapshot) {
            return .disconnected
        }

        if isEnginesUnavailableWithoutData(input: input) {
            return .empty
        }

        switch uiState.kind {
        case .loading:
            return .loading
        case .healthKitUnavailable:
            return .healthUnavailable
        case .noHealthPermission:
            return .disconnected
        case .partialPermission:
            return .partial
        case .staleData:
            return .stale
        case .ready:
            return .ready
        case .syncFailed:
            return uiState.canShowInsight ? .stale : .empty
        case .noSleepData, .noHeartData:
            return .partial
        case .noWorkoutHistory:
            return .partial
        case .notEnoughBaseline, .unknown, .remoteSyncDisabled:
            return .empty
        }
    }

    private static func isEnginesUnavailableWithoutData(
        input: HealthIntelligenceSectionLoadingInput
    ) -> Bool {
        !input.enginesEnabled
            && input.cachedDayCount == 0
            && input.snapshot == nil
            && !input.isAppleHealthConnected
            && input.availability?.hasAnyReadableSignal != true
    }

    private static func unavailableReason(
        availability: HealthIntelligenceSectionAvailability,
        uiState: HealthIntelligenceUIState,
        input: HealthIntelligenceSectionLoadingInput
    ) -> String? {
        switch availability {
        case .disabled, .loading, .ready, .stale, .partial:
            return nil
        case .healthUnavailable, .disconnected, .empty:
            if !input.enginesEnabled,
               input.cachedDayCount == 0,
               input.snapshot == nil {
                return trimmedMessage(uiState.message) ?? trimmedMessage(input.errorMessage)
            }
            return trimmedMessage(uiState.message)
        }
    }

    private static func resolvedCachedDayCount(
        from input: HealthIntelligenceSectionLoadingInput
    ) -> Int {
        input.cachedDayCount > 0 ? input.cachedDayCount : (input.availability?.cachedDayCount ?? 0)
    }

    private static func trimmedMessage(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
