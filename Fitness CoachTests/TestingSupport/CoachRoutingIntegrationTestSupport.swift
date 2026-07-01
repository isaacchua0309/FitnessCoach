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

        func makeCoach(
            aiService: AIServiceProtocol,
            includeTrainingInsights: Bool = false
        ) -> CoachModel {
            CoachModel(
                actionCenter: actionCenter,
                dailyLogReader: dailyLogService,
                healthActivityQuery: healthActivityQuery,
                aiService: aiService,
                userProfileReader: userProfileService,
                aiCommandParsingEnabled: true,
                trainingInsightsStore: includeTrainingInsights ? trainingInsightsStore : nil
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
