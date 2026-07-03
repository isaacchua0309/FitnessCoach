//
//  TodayPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview-only data for Today UI previews.
//

import Foundation

enum TodayPreviewData {
    static let date = Date()

    static let eveningDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = 20
        components.minute = 30
        return Calendar.current.date(from: components) ?? Date()
    }()

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
            activityContext: .default,
            trainingFrequencyPerWeek: 0
        )
    )

    static let brandNewDay = emptyDay

    static let breakfastLogged = build(
        foodEntries: [foodEntries[0]],
        calorieConsumed: 360,
        calorieRemaining: 1_440,
        calorieProgress: 0.2,
        proteinConsumed: 72,
        waterConsumedMl: 500
    )

    static let proteinBehind = build(
        foodEntries: foodEntries,
        calorieConsumed: 710,
        calorieRemaining: 1_090,
        calorieProgress: 0.39,
        proteinConsumed: 40,
        waterConsumedMl: 2_800
    )

    static let waterBehind = build(
        foodEntries: foodEntries,
        calorieConsumed: 710,
        calorieRemaining: 1_090,
        calorieProgress: 0.39,
        proteinConsumed: 160,
        waterConsumedMl: 500
    )

    static let caloriesExceeded = build(
        foodEntries: foodEntries,
        calorieConsumed: 2_050,
        calorieRemaining: 0,
        calorieProgress: 1.14,
        isOverTarget: true,
        proteinConsumed: 140,
        waterConsumedMl: 2_800
    )

    static let overTargetDay = caloriesExceeded

    static let workoutCompleted = build(
        foodEntries: foodEntries,
        calorieConsumed: 1_400,
        calorieRemaining: 400,
        calorieProgress: 0.78,
        proteinConsumed: 165,
        waterConsumedMl: 3_400,
        hasWorkout: true,
        appleHealthWorkoutCount: 1,
        stepsToday: 8_432
    )

    static let endOfDay = build(
        date: eveningDate,
        foodEntries: foodEntries,
        calorieConsumed: 710,
        calorieRemaining: 1_090,
        calorieProgress: 0.39,
        proteinConsumed: 79,
        waterConsumedMl: 1_200,
        hasWorkout: false,
        stepsToday: 4_200
    )

    static let healthDisconnected = build(
        foodEntries: foodEntries,
        calorieConsumed: 710,
        calorieRemaining: 1_090,
        calorieProgress: 0.39,
        proteinConsumed: 79,
        waterConsumedMl: 1_200,
        activityContext: TodayActivityContext(
            trainingIntegration: .notConnected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: nil,
            stepsToday: nil
        )
    )

    static let partialDay = build(
        foodEntries: foodEntries,
        calorieConsumed: 710,
        calorieRemaining: 1_090,
        calorieProgress: 0.39,
        proteinConsumed: 79,
        waterConsumedMl: 1_200,
        hasWorkout: true,
        appleHealthWorkoutCount: 1,
        stepsToday: 8_432
    )

    static let completeDay = build(
        foodEntries: foodEntries,
        calorieConsumed: 1_400,
        calorieRemaining: 400,
        calorieProgress: 0.78,
        proteinConsumed: 165,
        waterConsumedMl: 3_400,
        hasWorkout: true,
        appleHealthWorkoutCount: 1,
        stepsToday: 8_432
    )

    static let state = partialDay

    private static func build(
        date: Date = TodayPreviewData.date,
        foodEntries: [FoodEntry],
        calorieConsumed: Int,
        calorieRemaining: Int,
        calorieProgress: Double,
        calorieTarget: Int = 1_800,
        isOverTarget: Bool = false,
        proteinConsumed: Double,
        proteinTarget: Double = 170,
        waterConsumedMl: Int,
        waterTargetMl: Int = 3_500,
        hasWorkout: Bool = false,
        appleHealthWorkoutCount: Int? = nil,
        stepsToday: Int? = nil,
        hasPriorFoodLogs: Bool = true,
        activityContext: TodayActivityContext? = nil
    ) -> TodayDashboardState {
        let proteinRemaining = max(proteinTarget - proteinConsumed, 0)
        let waterRemaining = max(waterTargetMl - waterConsumedMl, 0)

        return TodayMissionControlStateBuilder.build(
            from: TodayMissionControlInputs(
                date: date,
                calorieSummary: CalorieSummary(
                    consumed: calorieConsumed,
                    target: calorieTarget,
                    remaining: calorieRemaining,
                    progress: calorieProgress,
                    isOverTarget: isOverTarget
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(
                        consumed: proteinConsumed,
                        target: proteinTarget,
                        remaining: proteinRemaining,
                        progress: proteinTarget > 0 ? proteinConsumed / proteinTarget : 0
                    ),
                    carbs: MacroProgress(consumed: 55, target: 160, remaining: 105, progress: 0.34),
                    fat: MacroProgress(consumed: 19.5, target: 60, remaining: 40.5, progress: 0.33)
                ),
                waterSummary: WaterSummary(
                    consumedMl: waterConsumedMl,
                    targetMl: waterTargetMl,
                    remainingMl: waterRemaining,
                    progress: waterTargetMl > 0 ? Double(waterConsumedMl) / Double(waterTargetMl) : 0
                ),
                weightSummary: TodayWeightSummary(
                    weightKg: 90.15,
                    displayText: "90.15 kg"
                ),
                weightLoggedToday: true,
                hasRecentWeight: true,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: hasWorkout ? 320 : 0,
                    workoutCount: hasWorkout ? 1 : 0,
                    hasWorkout: hasWorkout
                ),
                foodEntries: foodEntries,
                hasPriorFoodLogs: hasPriorFoodLogs,
                dailyReview: nil,
                goalWeightKg: 75,
                profileWeightKg: 90.15,
                activityContext: activityContext ?? TodayActivityContext(
                    trainingIntegration: .connected,
                    trainingDataSource: .appleHealth,
                    appleHealthWorkoutCount: appleHealthWorkoutCount,
                    stepsToday: stepsToday
                ),
                stepGoalAssumption: 7_500,
                trainingFrequencyPerWeek: hasWorkout ? 3 : 0
            )
        )
    }
}
