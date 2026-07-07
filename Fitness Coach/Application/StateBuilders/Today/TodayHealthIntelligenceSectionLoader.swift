//
//  TodayHealthIntelligenceSectionLoader.swift
//  Fitness Coach
//
//  Forma — Loads Health Intelligence inputs for Today presentation.
//

import Foundation

enum TodayHealthIntelligenceSectionLoader {

    struct LoadRequest: Sendable {
        var referenceDate: Date
        var nutritionProgress: TodayHealthIntelligenceNutritionProgress
        var isAppleHealthConnected: Bool
        var trainingIntegrationState: TrainingIntegrationState
        var connectionRecord: HealthIntegrationConnectionRecord
        var uiEnabled: Bool
        var syncPhase: HealthSyncPhase?
        var lastSuccessfulLocalSyncAt: Date?
        var isRemoteSyncCapabilityEnabled: Bool
        var remoteSyncConsentDecision: HealthSummarySyncConsentDecision
        var calendar: Calendar
    }

    static func loadSection(
        request: LoadRequest,
        snapshotProvider: any HealthIntelligenceSnapshotServing,
        healthDataRepository: (any HealthDataRepositorying)?
    ) async throws -> TodayHealthIntelligenceLoadResult {
        try Task.checkCancellation()

        let nutritionProgress = request.nutritionProgress
        let isAppleHealthConnected = request.isAppleHealthConnected
        let connectionRecord = request.connectionRecord
        let uiEnabled = request.uiEnabled

        guard uiEnabled else {
            return TodayHealthIntelligenceLoadResult(
                sectionState: nil,
                snapshot: nil,
                availability: nil,
                analyticsContext: HealthIntelligencePresentationContext(
                    isAppleHealthConnected: isAppleHealthConnected,
                    trainingIntegrationState: request.trainingIntegrationState,
                    connectionRecord: connectionRecord
                )
            )
        }

        let snapshot: HealthIntelligenceSnapshot?
        let availability: HealthDataAvailability?

        if let healthDataRepository {
            let loadResult = await HealthIntelligenceSectionLoaderCore.loadTodaySnapshotAndAvailability(
                referenceDate: request.referenceDate,
                snapshotProvider: snapshotProvider,
                healthDataRepository: healthDataRepository,
                calendar: request.calendar
            )
            snapshot = loadResult.snapshot
            availability = loadResult.availability
        } else {
            snapshot = await snapshotProvider.loadTodaySnapshot(
                for: request.referenceDate,
                calendar: request.calendar
            )
            availability = nil
        }

        try Task.checkCancellation()

        let cachedDayCount = availability?.cachedDayCount ?? 0
        let sectionState = buildSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            trainingIntegrationState: request.trainingIntegrationState,
            connectionRecord: connectionRecord,
            cachedDayCount: cachedDayCount,
            syncPhase: request.syncPhase,
            lastSuccessfulLocalSyncAt: request.lastSuccessfulLocalSyncAt,
            isRemoteSyncCapabilityEnabled: request.isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: request.remoteSyncConsentDecision
        )

        let analyticsContext = HealthIntelligencePresentationContext(
            availability: availability,
            snapshot: snapshot,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount,
            trainingIntegrationState: request.trainingIntegrationState,
            connectionRecord: connectionRecord
        )

        return TodayHealthIntelligenceLoadResult(
            sectionState: sectionState,
            snapshot: snapshot,
            availability: availability,
            analyticsContext: analyticsContext
        )
    }

    static func fallbackSection(
        request: LoadRequest,
        availability: HealthDataAvailability? = nil,
        errorMessage: String? = nil
    ) -> TodayHealthIntelligenceLoadResult {
        let sectionState = buildSection(
            snapshot: nil,
            nutritionProgress: request.nutritionProgress,
            availability: availability,
            isAppleHealthConnected: request.isAppleHealthConnected,
            trainingIntegrationState: request.trainingIntegrationState,
            connectionRecord: request.connectionRecord,
            cachedDayCount: availability?.cachedDayCount ?? 0,
            errorMessage: errorMessage,
            syncPhase: request.syncPhase,
            lastSuccessfulLocalSyncAt: request.lastSuccessfulLocalSyncAt,
            isRemoteSyncCapabilityEnabled: request.isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: request.remoteSyncConsentDecision
        )

        let analyticsContext = HealthIntelligencePresentationContext(
            explicitErrorMessage: errorMessage,
            availability: availability,
            snapshot: nil,
            isAppleHealthConnected: request.isAppleHealthConnected,
            cachedDayCount: availability?.cachedDayCount ?? 0,
            trainingIntegrationState: request.trainingIntegrationState,
            connectionRecord: request.connectionRecord
        )

        return TodayHealthIntelligenceLoadResult(
            sectionState: sectionState,
            snapshot: nil,
            availability: availability,
            analyticsContext: analyticsContext
        )
    }

    // MARK: - Private

    private static func buildSection(
        snapshot: HealthIntelligenceSnapshot?,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress,
        availability: HealthDataAvailability?,
        isAppleHealthConnected: Bool,
        trainingIntegrationState: TrainingIntegrationState,
        connectionRecord: HealthIntegrationConnectionRecord,
        cachedDayCount: Int,
        errorMessage: String? = nil,
        syncPhase: HealthSyncPhase?,
        lastSuccessfulLocalSyncAt: Date?,
        isRemoteSyncCapabilityEnabled: Bool,
        remoteSyncConsentDecision: HealthSummarySyncConsentDecision
    ) -> TodayHealthIntelligenceSectionState? {
        TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            isUIEnabled: true,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            trainingIntegrationState: trainingIntegrationState,
            connectionRecord: connectionRecord,
            cachedDayCount: cachedDayCount > 0 ? cachedDayCount : (availability?.cachedDayCount ?? 0),
            errorMessage: errorMessage,
            syncPhase: syncPhase,
            lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: remoteSyncConsentDecision
        )
    }
}
