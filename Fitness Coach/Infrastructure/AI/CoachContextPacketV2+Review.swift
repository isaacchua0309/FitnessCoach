//
//  CoachContextPacketV2+Review.swift
//  Fitness Coach
//
//  Builds a review-scoped CoachContextPacketV2 from deterministic daily review data.
//

import Foundation

extension CoachContextPacketV2 {

    /// Compact packet for daily-review narrative generation on a specific log date.
    static func reviewContext(
        from summary: DailyReviewSummary,
        profile: CoachUserProfileContext? = nil,
        calendar: Calendar = .current
    ) -> CoachContextPacketV2 {
        let meta = CoachContextMeta.make(generatedAt: summary.date, calendar: calendar)
        let today = CoachContextTodayPacket(
            targets: CoachTodayTargetsContext(
                calorieTarget: summary.calorieTarget,
                proteinTarget: summary.proteinTarget,
                carbsTarget: summary.carbsTarget,
                fatTarget: summary.fatTarget,
                waterTargetMl: summary.waterTargetMl
            ),
            nutrition: CoachTodayNutritionContext(
                caloriesConsumed: summary.caloriesConsumed,
                caloriesRemaining: summary.caloriesRemaining,
                proteinConsumed: summary.proteinConsumed,
                proteinRemaining: summary.proteinRemaining,
                carbsConsumed: summary.carbsConsumed,
                carbsRemaining: summary.carbsRemaining,
                fatConsumed: summary.fatConsumed,
                fatRemaining: summary.fatRemaining
            ),
            hydration: CoachTodayHydrationContext(
                waterConsumedMl: summary.waterConsumedMl,
                waterRemainingMl: summary.waterRemainingMl
            ),
            weight: summary.weightKg.map { CoachTodayWeightContext(weightKg: $0) },
            steps: summary.steps.map {
                CoachContextSourcedInt(value: $0, source: "dailyLog")
            },
            workoutCaloriesBurned: CoachContextSourcedInt(
                value: summary.workoutCaloriesBurned,
                source: "dailyLog"
            )
        )
        let training = CoachTrainingContext(workoutsToday: summary.workoutCount)

        return CoachContextPacketV2(
            meta: meta,
            profile: profile,
            today: today,
            training: training,
            generationMode: .degraded,
            sourceAttribution: CoachContextSourceAttribution(
                generationMode: .degraded,
                sources: ["dailyReview"]
            )
        )
    }

    static func reviewProfile(from profile: UserProfile) -> CoachUserProfileContext {
        CoachUserProfileContext(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            currentWeightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg,
            activityLevel: profile.activityLevel,
            trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek
        )
    }
}
