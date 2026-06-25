//
//  AppContainer.swift
//  Fitness Coach
//
//  FitPilot AI — Minimal dependency container for the current app shell.
//

import Foundation
import SwiftData

@MainActor
final class AppContainer {

    let modelContainer: ModelContainer
    let store: SwiftDataStore

    let userProfileService: UserProfileService
    let targetService: TargetService
    let dailyLogService: DailyLogService
    let foodLogService: FoodLogService
    let waterLogService: WaterLogService
    let weightLogService: WeightLogService
    let workoutLogService: WorkoutLogService
    let reviewService: ReviewService

    let llmClient: LLMClient
    let aiService: AIService
    let aiCommandParsingEnabled: Bool

    init(inMemory: Bool = false) throws {
        modelContainer = try FitPilotModelContainer.makeContainer(inMemory: inMemory)
        store = SwiftDataStore(container: modelContainer)

        userProfileService = UserProfileService(store: store)
        targetService = TargetService(userProfileService: userProfileService)
        dailyLogService = DailyLogService(
            store: store,
            userProfileService: userProfileService
        )
        foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService
        )
        waterLogService = WaterLogService(
            store: store,
            dailyLogService: dailyLogService
        )
        weightLogService = WeightLogService(
            store: store,
            dailyLogService: dailyLogService
        )
        workoutLogService = WorkoutLogService(
            store: store,
            dailyLogService: dailyLogService,
            userProfileService: userProfileService
        )

        // Local development uses the mock client so the app compiles and runs
        // without a backend. The production backend gateway can be wired later
        // via FitPilotAIBackendClient (no provider API keys live in the app).
        llmClient = MockLLMClient()
        aiService = AIService(llmClient: llmClient)
        aiCommandParsingEnabled = true

        reviewService = ReviewService(
            store: store,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            workoutLogService: workoutLogService,
            userProfileService: userProfileService,
            aiService: aiService
        )
    }

    func makeTodayModel() -> TodayModel {
        TodayModel(
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            workoutLogService: workoutLogService,
            targetService: targetService
        )
    }

    func makeCoachModel() -> CoachModel {
        CoachModel(
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            workoutLogService: workoutLogService,
            reviewService: reviewService,
            aiService: aiService,
            userProfileService: userProfileService,
            aiCommandParsingEnabled: aiCommandParsingEnabled
        )
    }

    func makeProgressModel() -> ProgressModel {
        ProgressModel(
            dailyLogService: dailyLogService,
            weightLogService: weightLogService,
            workoutLogService: workoutLogService,
            userProfileService: userProfileService
        )
    }

    func makeTrainingModel() -> TrainingModel {
        TrainingModel(
            workoutLogService: workoutLogService,
            dailyLogService: dailyLogService,
            userProfileService: userProfileService
        )
    }
}
