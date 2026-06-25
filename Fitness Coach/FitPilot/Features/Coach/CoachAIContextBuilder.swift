//
//  CoachAIContextBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Builds a compact AIContext for the Coach feature.
//
//  Reads only summarized state from existing services. It never sends full
//  database history or full chat history, and it never mutates state.
//

import Foundation

@MainActor
struct CoachAIContextBuilder {

    private let dailyLogService: DailyLogService
    private let userProfileService: UserProfileService

    /// Number of recent messages included for lightweight conversational context.
    private let recentMessageLimit = 5

    init(dailyLogService: DailyLogService, userProfileService: UserProfileService) {
        self.dailyLogService = dailyLogService
        self.userProfileService = userProfileService
    }

    func makeContext(recentMessages: [ChatMessage]) -> AIContext {
        AIContext(
            date: Date(),
            timezoneIdentifier: TimeZone.current.identifier,
            userProfileSummary: makeProfileSummary(),
            todaySummary: makeTodaySummary(),
            commonFoods: [],
            recentMessages: makeRecentMessages(from: recentMessages)
        )
    }

    // MARK: Profile

    private func makeProfileSummary() -> UserProfileSummary? {
        guard let profile = try? userProfileService.getCurrentProfile() else {
            return nil
        }
        return UserProfileSummary(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            currentWeightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg,
            activityLevel: profile.activityLevel,
            trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek
        )
    }

    // MARK: Today

    private func makeTodaySummary() -> TodayAISummary? {
        guard let log = try? dailyLogService.getTodayLog() else {
            return nil
        }

        let targets = MacroCalculator.macroTargets(from: log.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: log.totals)

        return TodayAISummary(
            calorieTarget: targets.calories,
            caloriesConsumed: log.totals.calories,
            caloriesRemaining: remaining.calories,
            proteinTarget: targets.protein,
            proteinConsumed: log.totals.protein,
            carbsTarget: targets.carbs,
            carbsConsumed: log.totals.carbs,
            fatTarget: targets.fat,
            fatConsumed: log.totals.fat,
            waterTargetMl: log.targets.waterTargetMl,
            waterConsumedMl: log.waterConsumedMl,
            weightKg: log.weightKg,
            steps: log.steps,
            workoutCaloriesBurned: log.workoutCaloriesBurned
        )
    }

    // MARK: Messages

    private func makeRecentMessages(from messages: [ChatMessage]) -> [AIMessageContext] {
        messages
            .suffix(recentMessageLimit)
            .map { AIMessageContext(role: $0.role, text: $0.text) }
    }
}
