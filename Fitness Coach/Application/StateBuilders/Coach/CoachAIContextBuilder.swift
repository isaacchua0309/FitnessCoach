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
    private let userProfileReader: any UserProfileReading
    private let actionCenter: FitnessActionCenter?
    private let workoutLogService: WorkoutLogService?

    /// Number of recent messages included for lightweight conversational context.
    private let recentMessageLimit = 5

    init(
        dailyLogService: DailyLogService,
        userProfileReader: any UserProfileReading,
        actionCenter: FitnessActionCenter? = nil,
        workoutLogService: WorkoutLogService? = nil
    ) {
        self.dailyLogService = dailyLogService
        self.userProfileReader = userProfileReader
        self.actionCenter = actionCenter
        self.workoutLogService = workoutLogService
    }

    func makeContext(recentMessages: [ChatMessage]) -> AIContext {
        let context = AIContext(
            date: Date(),
            timezoneIdentifier: TimeZone.current.identifier,
            userProfileSummary: makeProfileSummary(),
            todaySummary: makeTodaySummary(),
            commonFoods: [],
            recentMessages: makeRecentMessages(from: recentMessages)
        )
        FormaPipelineTracer.event(
            stage: .context,
            level: .debug,
            message: "AI context assembled",
            fields: [
                "hasProfile": String(context.userProfileSummary != nil),
                "hasTodaySummary": String(context.todaySummary != nil),
                "recentMessageCount": String(context.recentMessages.count)
            ]
        )
        return context
    }

    // MARK: Profile

    private func makeProfileSummary() -> UserProfileSummary? {
        guard let profile = try? userProfileReader.getCurrentProfile() else {
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

        return TodayAISummaryMapper.from(
            dailyLog: log,
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
