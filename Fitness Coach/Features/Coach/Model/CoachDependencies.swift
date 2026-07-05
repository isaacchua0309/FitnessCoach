//
//  CoachDependencies.swift
//  Fitness Coach
//
//  Forma — Coach service wiring and pipeline assembly for CoachModel.
//

import Foundation

@MainActor
struct CoachServices {
    let actionCenter: FitnessActionCenter
    let dailyLogReader: any DailyLogReading
    let healthActivityQuery: HealthActivityQueryService
    let healthIntelligenceSnapshotProvider: (any HealthIntelligenceSnapshotServing)?
    let healthDataRepository: (any HealthDataRepositorying)?
    let healthIntelligenceLoadEnabled: () -> Bool
    let healthSyncPhaseProvider: () -> HealthSyncPhase?
    let lastSuccessfulLocalSyncAtProvider: () -> Date?
    let remoteSyncConsentDecisionProvider: () -> HealthSummarySyncConsentDecision
    let isRemoteSyncCapabilityEnabled: () -> Bool
    let weightLogReader: (any WeightLogReading)?
    let userProfileReader: (any UserProfileReading)?
    let trainingInsightsStore: TrainingInsightsStore?
}

@MainActor
struct CoachDependencies {
    var aiService: AIServiceProtocol?
    var aiCommandParsingEnabled = false
    var coachModelConfig: CoachModelConfig = .default
    var routeDecider: CoachRouteDecider?
    var routeHandler: CoachAIRouteHandler?
    var mutationExecutor: CoachMutationExecutor?
    var contextPacketBuilder: CoachContextPacketV2Builder?
    var mealPhotoAnalyzer: CoachMealPhotoAnalyzer?
    var timelineRecorder: (any CoachTimelineRecording)?
    var transcriptStore: CoachChatTranscriptStore = CoachInMemoryChatTranscriptStore()
    var timelineStore: (any CoachTimelineStoring)?
    var foodCorrectionMemoryStore: (any FoodCorrectionMemoryStoring)?
    var coachAnalyticsLogger: (any CoachAnalyticsLogging)?
    var healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?

    func assemble(services: CoachServices) -> CoachAssembledPipeline {
        let resolvedTimelineRecorder = timelineRecorder ?? NoOpCoachTimelineRecorder()
        let resolvedContextPacketBuilder = services.userProfileReader != nil ? contextPacketBuilder : nil

        let mutationHistory = CoachMutationHistory()
        let resolvedMutationExecutor = mutationExecutor ?? CoachMutationExecutor(
            actionCenter: services.actionCenter,
            dailyLogReader: services.dailyLogReader,
            healthActivityQuery: services.healthActivityQuery,
            mutationHistory: mutationHistory,
            timelineRecorder: resolvedTimelineRecorder,
            timelineStore: timelineStore,
            foodCorrectionMemoryStore: foodCorrectionMemoryStore
        )
        let resolvedRouteHandler = routeHandler ?? CoachAIRouteHandler(
            aiService: aiService,
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            dailyLogReader: services.dailyLogReader,
            userProfileReader: services.userProfileReader,
            trainingInsightsStore: services.trainingInsightsStore,
            mutationExecutor: resolvedMutationExecutor,
            foodCorrectionMemoryStore: foodCorrectionMemoryStore
        )
        let resolvedRouteDecider = routeDecider ?? CoachRouteDecider()
        let resolvedMealPhotoAnalyzer = mealPhotoAnalyzer ?? CoachMealPhotoAnalyzer(
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            contextPacketBuilder: resolvedContextPacketBuilder,
            routeHandler: resolvedRouteHandler
        )

        let contextPacketCoordinator = CoachContextPacketCoordinator(
            contextPacketBuilder: resolvedContextPacketBuilder,
            healthIntelligenceSnapshotProvider: services.healthIntelligenceSnapshotProvider,
            healthDataRepository: services.healthDataRepository,
            healthActivityQuery: services.healthActivityQuery,
            healthIntelligenceLoadEnabled: services.healthIntelligenceLoadEnabled,
            healthSyncPhaseProvider: services.healthSyncPhaseProvider,
            lastSuccessfulLocalSyncAtProvider: services.lastSuccessfulLocalSyncAtProvider,
            remoteSyncConsentDecisionProvider: services.remoteSyncConsentDecisionProvider,
            isRemoteSyncCapabilityEnabled: services.isRemoteSyncCapabilityEnabled,
            trainingInsightsStore: services.trainingInsightsStore,
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator
        )
        let messagePersistenceCoordinator = CoachMessagePersistenceCoordinator(
            transcriptStore: transcriptStore,
            timelineRecorder: resolvedTimelineRecorder
        )
        let pendingConfirmationCoordinator = CoachPendingConfirmationCoordinator(
            mutationExecutor: resolvedMutationExecutor,
            timelineRecorder: resolvedTimelineRecorder,
            foodCorrectionMemoryStore: foodCorrectionMemoryStore
        )
        let todayContextCoordinator = CoachTodayContextCoordinator(
            actionCenter: services.actionCenter,
            dailyLogReader: services.dailyLogReader,
            weightLogReader: services.weightLogReader,
            healthActivityQuery: services.healthActivityQuery,
            contextPacketCoordinator: contextPacketCoordinator,
            healthIntelligenceLoadEnabled: services.healthIntelligenceLoadEnabled,
            trainingInsightsStore: services.trainingInsightsStore
        )

        return CoachAssembledPipeline(
            aiService: aiService,
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            coachModelConfig: coachModelConfig,
            routeDecider: resolvedRouteDecider,
            routeHandler: resolvedRouteHandler,
            mutationExecutor: resolvedMutationExecutor,
            mealPhotoAnalyzer: resolvedMealPhotoAnalyzer,
            contextPacketBuilder: resolvedContextPacketBuilder,
            contextPacketCoordinator: contextPacketCoordinator,
            messagePersistenceCoordinator: messagePersistenceCoordinator,
            pendingConfirmationCoordinator: pendingConfirmationCoordinator,
            todayContextCoordinator: todayContextCoordinator,
            timelineRecorder: resolvedTimelineRecorder,
            analyticsLogger: AnalyticsLoggerFactory.coach(coachAnalyticsLogger)
        )
    }
}

@MainActor
struct CoachAssembledPipeline {
    let aiService: AIServiceProtocol?
    let aiCommandParsingEnabled: Bool
    let coachModelConfig: CoachModelConfig
    let routeDecider: CoachRouteDecider
    let routeHandler: CoachAIRouteHandler
    let mutationExecutor: CoachMutationExecutor
    let mealPhotoAnalyzer: CoachMealPhotoAnalyzer
    let contextPacketBuilder: CoachContextPacketV2Builder?
    let contextPacketCoordinator: CoachContextPacketCoordinator
    let messagePersistenceCoordinator: CoachMessagePersistenceCoordinator
    let pendingConfirmationCoordinator: CoachPendingConfirmationCoordinator
    let todayContextCoordinator: CoachTodayContextCoordinator
    let timelineRecorder: any CoachTimelineRecording
    let analyticsLogger: any CoachAnalyticsLogging
}
