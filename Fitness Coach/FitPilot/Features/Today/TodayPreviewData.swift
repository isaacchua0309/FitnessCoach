//
//  TodayPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview-only data for Today UI previews.
//

import Foundation

enum TodayPreviewData {
    static let date = Date()

    static let state = TodayDashboardState(
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
        stepsSummary: StepsSummary(steps: 6_250),
        workoutSummary: TodayWorkoutSummary(
            workoutCaloriesBurned: 320,
            workoutCount: 1,
            hasWorkout: true
        ),
        foodEntries: foodEntries,
        hasDailyLog: true,
        dailyReview: nil,
        coachingNote: "Prioritize lean protein in your next meal."
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
