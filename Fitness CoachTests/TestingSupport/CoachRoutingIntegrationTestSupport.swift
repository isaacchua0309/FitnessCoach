//
//  CoachRoutingIntegrationTestSupport.swift
//  Fitness CoachTests
//
//  Lightweight Coach integration harness (no full AppContainer).
//

import Foundation
@testable import Fitness_Coach

@MainActor
enum CoachRoutingIntegrationTestSupport {

    @MainActor
    struct Harness {
        let fitness: FitnessActionCenterTestSupport.Harness
        let healthTrainingService: HealthTrainingService
        let trainingInsightsStore: TrainingInsightsStore

        var actionCenter: FitnessActionCenter { fitness.actionCenter }
        var dailyLogService: DailyLogService { fitness.dailyLogService }
        var healthActivityQuery: HealthActivityQueryService { fitness.healthActivityQuery }
        var userProfileService: UserProfileService { fitness.profileService }
        var today: Date { fitness.today }

        func makeCoachServices(includeTrainingInsights: Bool = false) -> CoachServices {
            CoachServices(
                actionCenter: actionCenter,
                dailyLogReader: dailyLogService,
                healthActivityQuery: healthActivityQuery,
                healthIntelligenceSnapshotProvider: nil,
                healthDataRepository: nil,
                healthIntelligenceLoadEnabled: { false },
                healthSyncPhaseProvider: { nil },
                lastSuccessfulLocalSyncAtProvider: { nil },
                remoteSyncConsentDecisionProvider: { .notDetermined },
                isRemoteSyncCapabilityEnabled: { false },
                weightLogReader: fitness.weightLogService,
                userProfileReader: userProfileService,
                trainingInsightsStore: includeTrainingInsights ? trainingInsightsStore : nil
            )
        }

        func makeCoachDependencies(
            aiService: AIServiceProtocol,
            timelineStore: FakeCoachTimelineStore? = nil,
            transcriptStore: CoachChatTranscriptStore = CoachInMemoryChatTranscriptStore(),
            foodCorrectionMemoryStore: (any FoodCorrectionMemoryStoring)? = nil,
            coachAnalyticsLogger: (any CoachAnalyticsLogging)? = nil
        ) -> CoachDependencies {
            let recorder: (any CoachTimelineRecording)? = timelineStore.map {
                DefaultCoachTimelineRecorder(store: $0)
            }
            let packetBuilder = CoachContextPacketV2Builder(
                dailyLogService: dailyLogService,
                foodLogService: fitness.base.foodLogService,
                waterLogService: fitness.base.waterLogService,
                weightLogService: fitness.weightLogService,
                userProfileService: userProfileService,
                healthActivityQuery: healthActivityQuery,
                timelineStore: timelineStore,
                timelineRecorder: recorder,
                foodCorrectionMemoryStore: foodCorrectionMemoryStore
            )
            return CoachDependencies(
                aiService: aiService,
                aiCommandParsingEnabled: true,
                contextPacketBuilder: packetBuilder,
                timelineRecorder: recorder,
                transcriptStore: transcriptStore,
                timelineStore: timelineStore,
                foodCorrectionMemoryStore: foodCorrectionMemoryStore,
                coachAnalyticsLogger: coachAnalyticsLogger
            )
        }

        func makeCoach(
            aiService: AIServiceProtocol,
            includeTrainingInsights: Bool = false,
            timelineStore: FakeCoachTimelineStore? = nil,
            transcriptStore: CoachChatTranscriptStore = CoachInMemoryChatTranscriptStore(),
            foodCorrectionMemoryStore: (any FoodCorrectionMemoryStoring)? = nil,
            coachAnalyticsLogger: (any CoachAnalyticsLogging)? = nil
        ) -> CoachModel {
            CoachModel(
                services: makeCoachServices(includeTrainingInsights: includeTrainingInsights),
                dependencies: makeCoachDependencies(
                    aiService: aiService,
                    timelineStore: timelineStore,
                    transcriptStore: transcriptStore,
                    foodCorrectionMemoryStore: foodCorrectionMemoryStore,
                    coachAnalyticsLogger: coachAnalyticsLogger
                )
            )
        }
    }

    static func makeHarness(cloudUID: String? = nil) throws -> Harness {
        let fitness = try FitnessActionCenterTestSupport.makeHarness(
            referenceNow: Date(),
            cloudUID: cloudUID
        )
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let healthTrainingService = HealthTrainingService(userDefaults: defaults)
        let trainingInsightsStore = TrainingInsightsStore(integration: healthTrainingService)
        return Harness(
            fitness: fitness,
            healthTrainingService: healthTrainingService,
            trainingInsightsStore: trainingInsightsStore
        )
    }

    static func seedCoachProfile(in harness: Harness) throws {
        let targets = UserTargets(
            calorieTarget: 2_100,
            proteinTarget: 160,
            carbTarget: 220,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: 0.4,
            aggressiveness: .moderate
        )
        let draft = UserProfileDraft(
            name: "Test",
            age: 30,
            sex: .male,
            heightCm: 178,
            currentWeightKg: 90,
            goalWeightKg: 82,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7_000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: targets
        )
        _ = try harness.userProfileService.createProfile(draft)
        _ = try harness.dailyLogService.ensureTodayLog()
    }
}
