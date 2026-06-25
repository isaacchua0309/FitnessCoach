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
}
