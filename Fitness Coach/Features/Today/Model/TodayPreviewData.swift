//
//  TodayPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview-only data for Today UI previews.
//

import Foundation

enum TodayPreviewData {
    static let date = Date()

    static let state = partialDay

    static let emptyDay = TodayMissionControlStateBuilder.build(
        from: TodayMissionControlInputs(
            date: date,
            calorieSummary: CalorieSummary(
                consumed: 0,
                target: 1_800,
                remaining: 1_800,
                progress: 0,
                isOverTarget: false
            ),
            macroSummary: MacroSummary(
                protein: MacroProgress(consumed: 0, target: 170, remaining: 170, progress: 0),
                carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
            ),
            waterSummary: WaterSummary(
                consumedMl: 0,
                targetMl: 3_500,
                remainingMl: 3_500,
                progress: 0
            ),
            weightSummary: TodayWeightSummary(
                weightKg: nil,
                displayText: "Not logged today"
            ),
            weightLoggedToday: false,
            hasRecentWeight: true,
            workoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 0,
                workoutCount: 0,
                hasWorkout: false
            ),
            foodEntries: [],
            hasPriorFoodLogs: false,
            dailyReview: nil,
            goalWeightKg: 75,
            profileWeightKg: 90.15,
            activityContext: .default
        )
    )

    static let partialDay = TodayMissionControlStateBuilder.build(
        from: TodayMissionControlInputs(
            date: date,
            calorieSummary: CalorieSummary(
                consumed: 710,
                target: 1_800,
                remaining: 1_090,
                progress: 0.39,
                isOverTarget: false
            ),
            macroSummary: MacroSummary(
                protein: MacroProgress(consumed: 79, target: 170, remaining: 91, progress: 0.46),
                carbs: MacroProgress(consumed: 55, target: 160, remaining: 105, progress: 0.34),
                fat: MacroProgress(consumed: 19.5, target: 60, remaining: 40.5, progress: 0.33)
            ),
            waterSummary: WaterSummary(
                consumedMl: 1_200,
                targetMl: 3_500,
                remainingMl: 2_300,
                progress: 0.34
            ),
            weightSummary: TodayWeightSummary(
                weightKg: 90.15,
                displayText: "90.15 kg"
            ),
            weightLoggedToday: true,
            hasRecentWeight: true,
            workoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 320,
                workoutCount: 1,
                hasWorkout: true
            ),
            foodEntries: foodEntries,
            hasPriorFoodLogs: true,
            dailyReview: nil,
            goalWeightKg: 75,
            profileWeightKg: 90.15,
            activityContext: TodayActivityContext(
                trainingIntegration: .connected,
                trainingDataSource: .appleHealth,
                appleHealthWorkoutCount: 1,
                stepsToday: 8_432
            ),
            stepGoalAssumption: 7_500
        )
    )

    static let completeDay = TodayMissionControlStateBuilder.build(
        from: TodayMissionControlInputs(
            date: date,
            calorieSummary: CalorieSummary(
                consumed: 1_720,
                target: 1_800,
                remaining: 80,
                progress: 0.96,
                isOverTarget: false
            ),
            macroSummary: MacroSummary(
                protein: MacroProgress(consumed: 165, target: 170, remaining: 5, progress: 0.97),
                carbs: MacroProgress(consumed: 150, target: 160, remaining: 10, progress: 0.94),
                fat: MacroProgress(consumed: 55, target: 60, remaining: 5, progress: 0.92)
            ),
            waterSummary: WaterSummary(
                consumedMl: 3_400,
                targetMl: 3_500,
                remainingMl: 100,
                progress: 0.97
            ),
            weightSummary: TodayWeightSummary(
                weightKg: 89.8,
                displayText: "89.80 kg"
            ),
            weightLoggedToday: true,
            hasRecentWeight: true,
            workoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 420,
                workoutCount: 1,
                hasWorkout: true
            ),
            foodEntries: foodEntries,
            hasPriorFoodLogs: true,
            dailyReview: nil,
            goalWeightKg: 75,
            profileWeightKg: 89.8,
            activityContext: TodayActivityContext(
                trainingIntegration: .connected,
                trainingDataSource: .appleHealth,
                appleHealthWorkoutCount: 1
            )
        )
    )

    static let overTargetDay = TodayMissionControlStateBuilder.build(
        from: TodayMissionControlInputs(
            date: date,
            calorieSummary: CalorieSummary(
                consumed: 2_050,
                target: 1_800,
                remaining: 0,
                progress: 1.14,
                isOverTarget: true
            ),
            macroSummary: MacroSummary(
                protein: MacroProgress(consumed: 140, target: 170, remaining: 30, progress: 0.82),
                carbs: MacroProgress(consumed: 210, target: 160, remaining: 0, progress: 1.31),
                fat: MacroProgress(consumed: 72, target: 60, remaining: 0, progress: 1.2)
            ),
            waterSummary: WaterSummary(
                consumedMl: 2_800,
                targetMl: 3_500,
                remainingMl: 700,
                progress: 0.8
            ),
            weightSummary: TodayWeightSummary(
                weightKg: 90.15,
                displayText: "90.15 kg"
            ),
            weightLoggedToday: true,
            hasRecentWeight: true,
            workoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 0,
                workoutCount: 0,
                hasWorkout: false
            ),
            foodEntries: foodEntries,
            hasPriorFoodLogs: true,
            dailyReview: nil,
            goalWeightKg: 75,
            profileWeightKg: 90.15,
            activityContext: .default
        )
    )

    static let foodEntries: [FoodEntry] = [
        FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: .breakfast,
            name: "Protein shake",
            quantity: 3,
            unit: "scoops",
            calories: 360,
            protein: 72,
            carbs: 9,
            fat: 4.5,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil,
            createdAt: date,
            updatedAt: date
        ),
        FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: .lunch,
            name: "Chicken rice",
            quantity: 1,
            unit: "plate",
            calories: 350,
            protein: 7,
            carbs: 46,
            fat: 15,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .medium,
            imageUrl: nil,
            notes: nil,
            createdAt: date,
            updatedAt: date
        )
    ]
}
