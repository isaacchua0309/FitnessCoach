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
struct CoachContextBuilder {

    private let dailyLogService: DailyLogService
    private let userProfileService: UserProfileService
    private let actionCenter: FitnessActionCenter?
    private let workoutLogService: WorkoutLogService?

    /// Number of recent messages included for lightweight conversational context.
    private let recentMessageLimit = 5

    init(
        dailyLogService: DailyLogService,
        userProfileService: UserProfileService,
        actionCenter: FitnessActionCenter? = nil,
        workoutLogService: WorkoutLogService? = nil
    ) {
        self.dailyLogService = dailyLogService
        self.userProfileService = userProfileService
        self.actionCenter = actionCenter
        self.workoutLogService = workoutLogService
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
            proteinRemaining: remaining.protein,
            carbsTarget: targets.carbs,
            carbsConsumed: log.totals.carbs,
            carbsRemaining: remaining.carbs,
            fatTarget: targets.fat,
            fatConsumed: log.totals.fat,
            fatRemaining: remaining.fat,
            waterTargetMl: log.targets.waterTargetMl,
            waterConsumedMl: log.waterConsumedMl,
            waterRemainingMl: WaterTargetCalculator.remainingMl(
                consumedMl: log.waterConsumedMl,
                targetMl: log.targets.waterTargetMl
            ),
            weightKg: log.weightKg,
            steps: log.steps,
            workoutCaloriesBurned: log.workoutCaloriesBurned,
            workoutsToday: (try? workoutLogService?.getWorkouts(for: Date()).count) ?? 0,
            recentMeals: makeRecentMeals()
        )
    }

    private func makeRecentMeals() -> [String] {
        guard let entries = try? actionCenter?.getFoodEntries(for: Date()) else {
            return []
        }
        return entries.suffix(6).map { entry in
            [
                entry.quantity.map { formatQuantity($0) },
                entry.unit,
                entry.name
            ]
            .compactMap(\.self)
            .joined(separator: " ")
        }
    }

    // MARK: Messages

    private func makeRecentMessages(from messages: [ChatMessage]) -> [AIMessageContext] {
        messages
            .suffix(recentMessageLimit)
            .map { AIMessageContext(role: $0.role, text: $0.text) }
    }

    private func formatQuantity(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

typealias CoachAIContextBuilder = CoachContextBuilder
