//
//  CoachModelTestFactory.swift
//  Fitness CoachTests
//
//  Test-only CoachModel assembly mirroring the retired production legacy initializer.
//  Prefer `CoachRoutingIntegrationTestSupport.makeCoach` for routing harnesses.
//

import Foundation
@testable import Fitness_Coach

@MainActor
enum CoachModelTestFactory {

    static func makeModel(
        localCommandParser: LocalCommandParser? = nil,
        actionCenter: FitnessActionCenter,
        dailyLogReader: any DailyLogReading,
        healthActivityQuery: HealthActivityQueryService,
        healthIntelligenceSnapshotProvider: (any HealthIntelligenceSnapshotServing)? = nil,
        healthDataRepository: (any HealthDataRepositorying)? = nil,
        healthIntelligenceLoadEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence },
        healthSyncPhaseProvider: @escaping () -> HealthSyncPhase? = { nil },
        lastSuccessfulLocalSyncAtProvider: @escaping () -> Date? = { nil },
        remoteSyncConsentDecisionProvider: @escaping () -> HealthSummarySyncConsentDecision = { .notDetermined },
        isRemoteSyncCapabilityEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled },
        weightLogReader: (any WeightLogReading)? = nil,
        aiService: AIServiceProtocol? = nil,
        contextPacketBuilder: CoachContextPacketV2Builder? = nil,
        userProfileReader: (any UserProfileReading)? = nil,
        aiCommandParsingEnabled: Bool = false,
        coachModelConfig: CoachModelConfig? = nil,
        routeDecider: CoachRouteDecider? = nil,
        trainingInsightsStore: TrainingInsightsStore? = nil,
        transcriptStore: CoachChatTranscriptStore = CoachInMemoryChatTranscriptStore(),
        coachAnalyticsLogger: (any CoachAnalyticsLogging)? = nil,
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        timelineRecorder: (any CoachTimelineRecording)? = nil,
        timelineStore: (any CoachTimelineStoring)? = nil,
        foodCorrectionMemoryStore: (any FoodCorrectionMemoryStoring)? = nil
    ) -> CoachModel {
        _ = localCommandParser ?? LocalCommandParser.standard

        let services = CoachServices(
            actionCenter: actionCenter,
            dailyLogReader: dailyLogReader,
            healthActivityQuery: healthActivityQuery,
            healthIntelligenceSnapshotProvider: healthIntelligenceSnapshotProvider,
            healthDataRepository: healthDataRepository,
            healthIntelligenceLoadEnabled: healthIntelligenceLoadEnabled,
            healthSyncPhaseProvider: healthSyncPhaseProvider,
            lastSuccessfulLocalSyncAtProvider: lastSuccessfulLocalSyncAtProvider,
            remoteSyncConsentDecisionProvider: remoteSyncConsentDecisionProvider,
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
            weightLogReader: weightLogReader,
            userProfileReader: userProfileReader,
            trainingInsightsStore: trainingInsightsStore
        )
        let dependencies = CoachDependencies(
            aiService: aiService,
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            coachModelConfig: coachModelConfig ?? .default,
            routeDecider: routeDecider,
            contextPacketBuilder: contextPacketBuilder,
            timelineRecorder: timelineRecorder,
            transcriptStore: transcriptStore,
            timelineStore: timelineStore,
            foodCorrectionMemoryStore: foodCorrectionMemoryStore,
            coachAnalyticsLogger: coachAnalyticsLogger,
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator
        )

        return CoachModel(services: services, dependencies: dependencies)
    }
}
