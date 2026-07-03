//
//  HealthIntelligenceSnapshot+Preview.swift
//  Fitness Coach
//
//  Forma — Preview and mock factories for HealthIntelligenceSnapshot.
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
            recovery: RecoverySummary(score: nil, readinessLabel: "Unknown"),
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0, label: "Unknown"),
            nextBestAction: NextBestAction(
                title: "Apple Health unavailable",
                detail: "Recovery and activity insights need a device with Apple Health.",
                priority: 1
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
            recovery: RecoverySummary(score: nil, readinessLabel: "Insufficient data"),
            workout: WorkoutSummary(
                hasWorkoutToday: true,
                workoutCount: 1,
                primaryActivityName: "Running",
                primaryDurationMinutes: 42,
                primaryActiveEnergyKcal: 380,
                primaryCategory: .running
            ),
            activity: ActivitySummary(
                steps: 8_432,
                activeEnergyKcal: 515,
                exerciseMinutes: 42
            ),
            nutritionAdjustment: .none,
            weeklyReview: WeeklyHealthReview(
                headline: "Weekly activity available",
                workoutDays: 4,
                narrative: nil
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
            recovery: RecoverySummary(score: nil, readinessLabel: "Unknown"),
            workout: nil,
            activity: ActivitySummary(steps: 4_210, activeEnergyKcal: 280, exerciseMinutes: 18),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.45, label: "Limited"),
            nextBestAction: NextBestAction(
                title: "Connect Apple Health",
                detail: "Enable activity reads to improve plan confidence.",
                priority: 1
            )
        )
    }
}
