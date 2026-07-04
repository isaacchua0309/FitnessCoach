//
//  AIContext+LegacyAdapter.swift
//  Fitness Coach
//
//  Temporary bridge for legacy parse-command requests that still expect AIContext.
//  Remove once the parse-command gateway accepts CoachContextPacketV2.
//

import Foundation

extension AIContext {

    /// Minimal legacy context derived from a v2 packet for non-migrated endpoints.
    static func legacyCompact(from packet: CoachContextPacketV2) -> AIContext {
        let todaySummary: TodayAISummary?
        if let today = packet.today {
            todaySummary = TodayAISummary(
                calorieTarget: today.targets?.calorieTarget ?? 0,
                caloriesConsumed: today.nutrition?.caloriesConsumed ?? 0,
                caloriesRemaining: today.nutrition?.caloriesRemaining ?? 0,
                isOverCalorieTarget: (today.nutrition?.caloriesRemaining ?? 0) < 0,
                proteinTarget: today.targets?.proteinTarget ?? 0,
                proteinConsumed: today.nutrition?.proteinConsumed ?? 0,
                proteinRemaining: today.nutrition?.proteinRemaining ?? 0,
                hasMetProteinTarget: (today.nutrition?.proteinRemaining ?? 1) <= 0,
                carbsTarget: today.targets?.carbsTarget ?? 0,
                carbsConsumed: today.nutrition?.carbsConsumed ?? 0,
                carbsRemaining: today.nutrition?.carbsRemaining ?? 0,
                fatTarget: today.targets?.fatTarget ?? 0,
                fatConsumed: today.nutrition?.fatConsumed ?? 0,
                fatRemaining: today.nutrition?.fatRemaining ?? 0,
                waterTargetMl: today.targets?.waterTargetMl ?? 0,
                waterConsumedMl: today.hydration?.waterConsumedMl ?? 0,
                waterRemainingMl: today.hydration?.waterRemainingMl ?? 0,
                hasMetWaterTarget: (today.hydration?.waterRemainingMl ?? 1) <= 0,
                weightKg: today.weight?.weightKg,
                steps: today.steps?.value,
                workoutCaloriesBurned: today.workoutCaloriesBurned?.value ?? 0,
                workoutsToday: packet.training?.workoutsToday ?? 0,
                recentMeals: packet.recentMealsStructured.map(\.displayLabel)
            )
        } else {
            todaySummary = nil
        }

        let profileSummary: UserProfileSummary?
        if let profile = packet.profile {
            profileSummary = UserProfileSummary(
                age: profile.age,
                sex: profile.sex,
                heightCm: profile.heightCm,
                currentWeightKg: profile.currentWeightKg,
                goalWeightKg: profile.goalWeightKg,
                activityLevel: profile.activityLevel,
                trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek
            )
        } else {
            profileSummary = nil
        }

        return AIContext(
            date: packet.meta.generatedAt,
            timezoneIdentifier: packet.meta.timezoneIdentifier,
            userProfileSummary: profileSummary,
            todaySummary: todaySummary,
            commonFoods: packet.commonFoods.map(\.name),
            recentMessages: packet.recentChatMessages.map {
                AIMessageContext(
                    role: ChatMessageRole(rawValue: $0.role) ?? .user,
                    text: $0.textPreview
                )
            },
            healthIntelligence: packet.healthIntelligence,
            healthIntelligenceAwarenessAvailable: packet.healthIntelligence != nil
        )
    }
}

private extension CoachRecentMealContext {
    var displayLabel: String {
        [
            quantity.map { $0.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", $0) : String(format: "%.1f", $0) },
            unit,
            name
        ]
        .compactMap(\.self)
        .joined(separator: " ")
    }
}
