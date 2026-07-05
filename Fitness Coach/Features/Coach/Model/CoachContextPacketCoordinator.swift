//
//  CoachContextPacketCoordinator.swift
//  Fitness Coach
//
//  Forma — AI activity resolution and Coach context packet assembly.
//

import Foundation

@MainActor
final class CoachContextPacketCoordinator {

    private let contextPacketBuilder: CoachContextPacketV2Builder?
    private let healthIntelligenceSnapshotProvider: (any HealthIntelligenceSnapshotServing)?
    private let healthDataRepository: (any HealthDataRepositorying)?
    private let healthActivityQuery: HealthActivityQueryService
    private let healthIntelligenceLoadEnabled: () -> Bool
    private let healthSyncPhaseProvider: () -> HealthSyncPhase?
    private let lastSuccessfulLocalSyncAtProvider: () -> Date?
    private let remoteSyncConsentDecisionProvider: () -> HealthSummarySyncConsentDecision
    private let isRemoteSyncCapabilityEnabled: () -> Bool
    private let trainingInsightsStore: TrainingInsightsStore?
    private let healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?

    init(
        contextPacketBuilder: CoachContextPacketV2Builder?,
        healthIntelligenceSnapshotProvider: (any HealthIntelligenceSnapshotServing)?,
        healthDataRepository: (any HealthDataRepositorying)?,
        healthActivityQuery: HealthActivityQueryService,
        healthIntelligenceLoadEnabled: @escaping () -> Bool,
        healthSyncPhaseProvider: @escaping () -> HealthSyncPhase?,
        lastSuccessfulLocalSyncAtProvider: @escaping () -> Date?,
        remoteSyncConsentDecisionProvider: @escaping () -> HealthSummarySyncConsentDecision,
        isRemoteSyncCapabilityEnabled: @escaping () -> Bool,
        trainingInsightsStore: TrainingInsightsStore?,
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    ) {
        self.contextPacketBuilder = contextPacketBuilder
        self.healthIntelligenceSnapshotProvider = healthIntelligenceSnapshotProvider
        self.healthDataRepository = healthDataRepository
        self.healthActivityQuery = healthActivityQuery
        self.healthIntelligenceLoadEnabled = healthIntelligenceLoadEnabled
        self.healthSyncPhaseProvider = healthSyncPhaseProvider
        self.lastSuccessfulLocalSyncAtProvider = lastSuccessfulLocalSyncAtProvider
        self.remoteSyncConsentDecisionProvider = remoteSyncConsentDecisionProvider
        self.isRemoteSyncCapabilityEnabled = isRemoteSyncCapabilityEnabled
        self.trainingInsightsStore = trainingInsightsStore
        self.healthIntelligenceAnalyticsCoordinator = healthIntelligenceAnalyticsCoordinator
    }

    func prepareContextPacket(
        recentMessages: [ChatMessage],
        currentUserMessage: String? = nil
    ) async -> CoachContextPacketV2? {
        guard let contextPacketBuilder else { return nil }
        let activity = await resolveAIActivityContext()
        if let snapshot = activity.sourceSnapshot {
            if activity.healthIntelligenceAwarenessAvailable {
                healthIntelligenceAnalyticsCoordinator?.logCoachHealthContextAvailable(from: snapshot)
            } else if activity.healthIntelligence != nil {
                healthIntelligenceAnalyticsCoordinator?.logCoachHealthContextPartial(from: snapshot)
            }
            if activity.healthIntelligence != nil {
                healthIntelligenceAnalyticsCoordinator?.logCoachHealthContextUsed(from: snapshot)
            }
        }
        return await contextPacketBuilder.makeContext(
            recentMessages: recentMessages,
            currentUserMessage: currentUserMessage
        )
    }

    func resolveAIActivityContext(for date: Date = Date()) async -> CoachAIActivityContext {
        async let availabilityTask: HealthDataAvailability? = {
            guard let healthDataRepository else { return nil }
            return await healthDataRepository.getHealthDataAvailability()
        }()

        let availability = await availabilityTask
        let resolveInput = CoachAIActivityContextResolver.ResolveInput(
            availability: availability,
            lastHealthSyncAt: lastSuccessfulLocalSyncAtProvider(),
            isAppleHealthConnected: trainingInsightsStore?.integrationState.isConnected == true,
            syncPhase: healthSyncPhaseProvider(),
            remoteSyncConsentDecision: remoteSyncConsentDecisionProvider(),
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled()
        )

        return await CoachAIActivityContextResolver.resolve(
            date: date,
            snapshotProvider: healthIntelligenceSnapshotProvider,
            healthActivityQuery: healthActivityQuery,
            loadHealthIntelligence: healthIntelligenceLoadEnabled,
            resolveInput: resolveInput
        )
    }
}
