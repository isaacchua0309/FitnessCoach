//
//  HealthIntelligenceSnapshot+Preview.swift
//  Fitness Coach
//
//  Forma — Preview and mock factories for HealthIntelligenceSnapshot.
//
//  Named scenario mocks (`mockReadyDay`, `mockWorkoutDay`, etc.) live in
//  `HealthIntelligenceMocks.swift` and compile in DEBUG builds only.
//

import Foundation

extension HealthIntelligenceSnapshot {

    static func placeholder(for date: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: date,
            recovery: .placeholder,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )
    }

    static func previewUnavailable(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> HealthIntelligenceSnapshot {
        let day = calendar.startOfDay(for: date)
        return HealthIntelligenceSnapshot(
            date: day,
            recovery: .unknown,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0, label: "Unknown"),
            nextBestAction: NextBestAction(
                id: "health-unavailable",
                title: "Apple Health unavailable",
                message: "Recovery and activity insights need a device with Apple Health.",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: day,
                expiresAt: nil
            )
        )
    }

    static func previewConnected(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> HealthIntelligenceSnapshot {
        let day = calendar.startOfDay(for: date)
        return HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery unclear",
                explanation: "Recovery signals are available, but today's estimate is not ready yet.",
                recommendedTraining: "Use how you feel before adding intensity today.",
                recommendedNutrition: "Stay on your usual plan until more data arrives.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.activity, .workouts, .trainingLoad]
            ),
            workout: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .running,
                title: "Running",
                workoutCount: 1,
                totalDurationMinutes: 42,
                totalActiveCalories: 380,
                intensity: .moderate,
                demand: .moderate,
                latestWorkoutStart: nil,
                latestWorkoutEnd: nil,
                nutritionAdvice: "Aim for 20–35g protein in your next meal.",
                hydrationAdviceMl: 500,
                explanation: "Running added solid training volume today. A balanced next meal will help you stay on track.",
                confidence: .high,
                sourceSummary: "Based on synced workouts. Calorie figures are estimates and can vary."
            ),
            activity: ActivitySummary(
                steps: 8_432,
                activeEnergyKcal: 515,
                exerciseMinutes: 42
            ),
            nutritionAdjustment: .none,
            weeklyReview: WeeklyHealthReview(
                weekStartDate: calendar.date(byAdding: .day, value: -6, to: day) ?? day,
                weekEndDate: day,
                title: "Strong week",
                summary: "You built solid momentum with consistent training and fueling.",
                stats: WeeklyStats(
                    totalWorkouts: 4,
                    totalWorkoutMinutes: 180,
                    totalActiveCalories: 1_420,
                    averageSteps: 8_432,
                    totalSteps: 59_024,
                    proteinHitDays: 6,
                    calorieTargetHitDays: 5,
                    waterHitDays: 5,
                    averageRecoveryScore: 72,
                    lowRecoveryDays: 1,
                    weightChangeKg: -0.3,
                    loggingConsistencyDays: 6
                ),
                wins: [
                    "You trained on 4 days this week.",
                    "Protein targets were hit on 6 days."
                ],
                risks: [],
                nextWeekFocus: ["Keep your current rhythm and stay consistent."],
                confidence: .high,
                missingSignals: [],
                generatedAt: day
            ),
            planConfidence: PlanHealthConfidence(score: 0.75, label: "Moderate"),
            nextBestAction: .none
        )
    }

    static func previewLimitedData(
        for date: Date = Date(),
        calendar: Calendar = .current
    ) -> HealthIntelligenceSnapshot {
        let day = calendar.startOfDay(for: date)
        return HealthIntelligenceSnapshot(
            date: day,
            recovery: .unknown,
            workout: nil,
            activity: ActivitySummary(steps: 4_210, activeEnergyKcal: 280, exerciseMinutes: 18),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.45, label: "Limited"),
            nextBestAction: NextBestAction(
                id: "connect-health",
                title: "Connect Apple Health",
                message: "Enable activity reads to improve plan confidence.",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: day,
                expiresAt: nil
            )
        )
    }
}
