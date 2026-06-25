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
    let actionCenter: FitnessActionCenter

    let llmClient: LLMClient
    let aiService: AIService
    let aiCommandParsingEnabled: Bool
    let refreshCenter: AppRefreshCenter

    init(inMemory: Bool = false) throws {
        refreshCenter = AppRefreshCenter()
        modelContainer = try FitPilotModelContainer.makeContainer(inMemory: inMemory)
        store = SwiftDataStore(container: modelContainer)

        userProfileService = UserProfileService(store: store)
        dailyLogService = DailyLogService(
            store: store,
            userProfileService: userProfileService
        )
        targetService = TargetService(
            userProfileService: userProfileService,
            dailyLogService: dailyLogService
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

        // Debug builds use the local backend gateway when available. The
        // gateway reads .env on the Mac and calls OpenAI, so provider keys still
        // do not live in the iOS app bundle.
        #if DEBUG
        let backendURL = URL(
            string: ProcessInfo.processInfo.environment["FITPILOT_AI_BACKEND_URL"]
                ?? "http://127.0.0.1:8787"
        )
        if let backendURL {
            llmClient = FallbackLLMClient(
                primary: FitPilotAIBackendClient(baseURL: backendURL),
                fallback: MockLLMClient()
            )
        } else {
            llmClient = MockLLMClient()
        }
        #else
        llmClient = MockLLMClient()
        #endif
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

        actionCenter = FitnessActionCenter(
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            workoutLogService: workoutLogService,
            dailyLogService: dailyLogService,
            targetService: targetService,
            userProfileService: userProfileService,
            reviewService: reviewService,
            refreshCenter: refreshCenter
        )
    }

    func makeTodayModel() -> TodayModel {
        TodayModel(
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            workoutLogService: workoutLogService,
            weightLogService: weightLogService,
            reviewService: reviewService,
            userProfileService: userProfileService
        )
    }

    func makeCoachModel() -> CoachModel {
        CoachModel(
            actionCenter: actionCenter,
            dailyLogService: dailyLogService,
            workoutLogService: workoutLogService,
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
            dailyLogService: dailyLogService
        )
    }

    func makeProfileModel() -> ProfileModel {
        ProfileModel(
            actionCenter: actionCenter,
            userProfileService: userProfileService,
            targetService: targetService
        )
    }

    func makeRootModel() -> RootModel {
        RootModel(userProfileService: userProfileService)
    }

    func makeOnboardingModel(onCompletion: @escaping () -> Void) -> OnboardingModel {
        OnboardingModel(
            userProfileService: userProfileService,
            targetService: targetService,
            onCompletion: onCompletion
        )
    }
}
