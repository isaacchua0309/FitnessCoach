//
//  ProgressPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview data for Journey UI previews.
//

import Foundation

enum ProgressPreviewData {
    static let today = Date()

    static let state = ProgressDashboardState(
        selectedRangeDays: 28,
        transformation: JourneyTransformationState(
            goalTitle: "Lose 15 kg",
            startedLabel: "Started Jun 25",
            currentWeightKg: 90,
            goalWeightKg: 75,
            progressPercent: 0,
            estimatedCompletionLabel: "November",
            currentPhase: "Getting started",
            coachInsight: "You've started strong. Consistency this week matters more than scale movement."
        ),
        milestones: [
            JourneyMilestone(id: "m-0", weightKg: 90, status: .current),
            JourneyMilestone(id: "m-1", weightKg: 86.3, status: .upcoming),
            JourneyMilestone(id: "m-2", weightKg: 82.5, status: .upcoming),
            JourneyMilestone(id: "m-3", weightKg: 78.8, status: .upcoming),
            JourneyMilestone(id: "m-4", weightKg: 75, status: .upcoming)
        ],
        nextCheckpointKg: 86.3,
        sectionVisibility: JourneySectionVisibility(
            showsWeightTrendSection: true,
            showsMilestonesSection: false
        ),
        weeklySnapshot: JourneyWeeklySnapshot(
            training: .connected(
                workoutDays: 3,
                averageCaloriesBurned: 285,
                averageTrainingDurationMinutes: 42
            ),
            proteinDaysAchieved: 5,
            proteinDaysTotal: 7,
            waterDaysAchieved: 4,
            waterDaysTotal: 7,
            averageCalorieDeficit: 320
        ),
        coachInsights: [
            JourneyCoachInsight(id: "protein", message: "You maintained excellent protein intake this week."),
            JourneyCoachInsight(id: "water", message: "Water intake decreased this week. Front-load hydration earlier in the day."),
            JourneyCoachInsight(id: "training", message: "Training consistency is building — that's what compounds results.")
        ],
        consistencyCalendar: JourneyConsistencyCalendar(
            monthTitle: today.formatted(.dateTime.month(.wide).year()),
            weekdaySymbols: Calendar.current.shortWeekdaySymbols,
            days: [],
            completedCount: 12,
            totalLoggedDays: 12
        ),
        achievements: [
            JourneyAchievement(id: "first-workout", title: "First workout", isUnlocked: true),
            JourneyAchievement(id: "first-week", title: "Complete your first week", isUnlocked: true),
            JourneyAchievement(id: "first-kg", title: "Lose your first kilogram", isUnlocked: false),
            JourneyAchievement(id: "14-day", title: "Build a 14-day streak", isUnlocked: false)
        ],
        weightTrend: JourneyWeightTrendState(
            chartPoints: makeWeightPoints(),
            interpretation: "The trend is moving toward your goal. Stay patient through normal daily fluctuations."
        ),
        analytics: ProgressAnalyticsDetail(
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
            workoutSummary: ProgressWorkoutSummary(
                workoutCount: 9,
                workoutDays: 6,
                totalEstimatedCaloriesBurned: 2_850,
                averageWorkoutsPerWeek: 2.25,
                averageDurationMinutes: 42,
                isFromAppleHealth: true
            ),
            weightChartPoints: makeWeightPoints()
        ),
        hasProfile: true
    )

    private static func makeWeightPoints() -> [WeightChartPoint] {
        (0..<10).compactMap { index in
            guard let date = Calendar.current.date(byAdding: .day, value: -9 + index, to: today) else {
                return nil
            }
            return WeightChartPoint(
                date: date,
                weightKg: 90.2 - (Double(index) * 0.14)
            )
        }
    }
}
