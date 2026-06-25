//
//  ProgressPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview data for Progress UI previews.
//

import Foundation

enum ProgressPreviewData {
    static let today = Date()

    static let state = ProgressDashboardState(
        selectedRangeDays: 28,
        weightSummary: ProgressWeightSummary(
            latestWeightKg: 88.9,
            sevenDayAverageKg: 89.2,
            previousSevenDayAverageKg: 90.1,
            changeKg: -0.9,
            direction: .decreasing,
            hasSuddenSpike: false
        ),
        weightChartPoints: makeWeightPoints(),
        nutritionSummary: ProgressNutritionSummary(
            loggedDays: 18,
            averageCalories: 1_735,
            averageProtein: 156.4,
            averageCarbs: 148.2,
            averageFat: 58.7,
            averageFiber: 22.1
        ),
        waterSummary: ProgressWaterSummary(
            loggedDays: 18,
            averageWaterMl: 2_650,
            averageWaterTargetMl: 3_200,
            consistencyPercent: 0.72
        ),
        maintenanceEstimate: MaintenanceEstimate(
            days: 18,
            averageCalories: 1_735,
            weightChangeKg: -1.2,
            estimatedDailyDeficit: 513,
            estimatedMaintenanceCalories: 2_248,
            confidence: .high,
            hasEnoughData: true
        ),
        goalProjection: ProgressProjection(
            currentWeightKg: 88.9,
            goalWeightKg: 82.0,
            remainingKg: -6.9,
            weeklyRateKg: -0.5,
            estimatedWeeksToGoal: 13.8,
            projectedGoalDate: Calendar.current.date(byAdding: .day, value: 97, to: today),
            confidence: .high
        ),
        workoutSummary: ProgressWorkoutSummary(
            workoutCount: 9,
            totalEstimatedCaloriesBurned: 2_850,
            averageWorkoutsPerWeek: 2.25
        ),
        hasEnoughData: true
    )

    private static func makeWeightPoints() -> [WeightChartPoint] {
        (0..<10).compactMap { index in
            guard let date = Calendar.current.date(byAdding: .day, value: -9 + index, to: today) else {
                return nil
            }
            let weight = 90.2 - (Double(index) * 0.14)
            return WeightChartPoint(
                date: date,
                weightKg: weight,
                sevenDayAverageKg: weight + 0.1
            )
        }
    }
}
