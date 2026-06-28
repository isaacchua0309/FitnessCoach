//
//  JourneyMilestonesBuilder.swift
//  Fitness Coach
//
//  Forma — Duolingo-style Journey milestone checkpoints.
//

import Foundation

enum JourneyMilestonesBuilder {

    struct Input: Equatable {
        var baseline: JourneyBaseline
        var maturityLogs: [DailyLog]
        var journeyStreaks: JourneyStreakState
        var healthWorkoutDayStarts: Set<Date>
        var calendar: Calendar
    }

    private struct Definition: Equatable {
        var id: String
        var category: JourneyMilestoneCategory
        var title: (JourneyGoalDirection) -> String
        var isUnlocked: (Metrics) -> Bool
        var progress: (Metrics) -> Double
        var isApplicable: (Metrics) -> Bool
    }

    private struct Metrics: Equatable {
        var foodLogDays: Int
        var proteinGoalDays: Int
        var waterGoalDays: Int
        var trainingWorkoutDays: Int
        var weightChangeTowardGoalKg: Double
        var goalProgressPercent: Double
        var weightSpanKg: Double
        var currentLoggingStreak: Int
        var longestLoggingStreak: Int
        var goalDirection: JourneyGoalDirection
    }

    static func build(_ input: Input) -> JourneyMilestonesState {
        let metrics = makeMetrics(input: input)
        let definitions = milestoneDefinitions(for: metrics)

        var items: [JourneyMilestone] = []
        var foundCurrent = false

        for definition in definitions where definition.isApplicable(metrics) {
            let unlocked = definition.isUnlocked(metrics)
            let progress = min(max(definition.progress(metrics), 0), 1)

            let status: JourneyMilestoneStatus
            if unlocked {
                status = .completed
            } else if !foundCurrent {
                status = .current
                foundCurrent = true
            } else {
                status = .upcoming
            }

            items.append(
                JourneyMilestone(
                    id: definition.id,
                    title: definition.title(metrics.goalDirection),
                    category: definition.category,
                    status: status,
                    progressFraction: unlocked ? nil : progress
                )
            )
        }

        guard !items.isEmpty else { return .empty }

        let unlocked = items.filter { $0.status == .completed }
        let upcoming = items.filter { $0.status != .completed }
        let next = items.first { $0.status == .current }
        let nextProgress = next?.progressFraction
        let progressPercent = items.isEmpty
            ? 0
            : (Double(unlocked.count) / Double(items.count)) * 100

        return JourneyMilestonesState(
            unlocked: unlocked,
            upcoming: upcoming,
            next: next,
            nextProgressFraction: nextProgress,
            progressPercent: progressPercent,
            items: items
        )
    }

    // MARK: - Definitions

    private static func milestoneDefinitions(for metrics: Metrics) -> [Definition] {
        var definitions: [Definition] = [
            Definition(
                id: "first-meal",
                category: .foodLogging,
                title: { _ in "Logged first meal" },
                isUnlocked: { $0.foodLogDays >= 1 },
                progress: { min(1, Double($0.foodLogDays)) },
                isApplicable: { _ in true }
            ),
            Definition(
                id: "first-week",
                category: .onboarding,
                title: { direction in
                    direction == .maintain
                        ? "Stayed consistent for first week"
                        : "First week complete"
                },
                isUnlocked: { $0.foodLogDays >= 7 },
                progress: { min(1, Double($0.foodLogDays) / 7) },
                isApplicable: { _ in true }
            ),
            Definition(
                id: "first-kg",
                category: .weightProgress,
                title: { direction in
                    switch direction {
                    case .lose: return "Lost first kilogram"
                    case .gain: return "Gained first kilogram"
                    case .maintain: return "Stayed consistent for first week"
                    }
                },
                isUnlocked: { metrics in
                    switch metrics.goalDirection {
                    case .lose, .gain:
                        return metrics.weightChangeTowardGoalKg >= 1
                    case .maintain:
                        return metrics.foodLogDays >= 7
                    }
                },
                progress: { metrics in
                    switch metrics.goalDirection {
                    case .lose, .gain:
                        return min(1, metrics.weightChangeTowardGoalKg)
                    case .maintain:
                        return min(1, Double(metrics.foodLogDays) / 7)
                    }
                },
                isApplicable: { _ in true }
            ),
            Definition(
                id: "protein-five",
                category: .proteinConsistency,
                title: { _ in "Hit protein target 5 days" },
                isUnlocked: { $0.proteinGoalDays >= 5 },
                progress: { min(1, Double($0.proteinGoalDays) / 5) },
                isApplicable: { _ in true }
            ),
            Definition(
                id: "water-five",
                category: .waterConsistency,
                title: { _ in "Hit water target 5 days" },
                isUnlocked: { $0.waterGoalDays >= 5 },
                progress: { min(1, Double($0.waterGoalDays) / 5) },
                isApplicable: { _ in true }
            ),
            Definition(
                id: "first-workout",
                category: .trainingConsistency,
                title: { _ in "Logged first workout" },
                isUnlocked: { $0.trainingWorkoutDays >= 1 },
                progress: { min(1, Double($0.trainingWorkoutDays)) },
                isApplicable: { _ in true }
            ),
            Definition(
                id: "logging-streak-seven",
                category: .streaks,
                title: { _ in "7-day logging streak" },
                isUnlocked: { max($0.currentLoggingStreak, $0.longestLoggingStreak) >= 7 },
                progress: { min(1, Double(max($0.currentLoggingStreak, $0.longestLoggingStreak)) / 7) },
                isApplicable: { _ in true }
            ),
            Definition(
                id: "thirty-meals",
                category: .foodLogging,
                title: { _ in "Logged 30 meals" },
                isUnlocked: { $0.foodLogDays >= 30 },
                progress: { min(1, Double($0.foodLogDays) / 30) },
                isApplicable: { _ in true }
            ),
            Definition(
                id: "halfway",
                category: .weightProgress,
                title: { _ in "Halfway to goal" },
                isUnlocked: { $0.goalProgressPercent >= 50 },
                progress: { min(1, $0.goalProgressPercent / 100) },
                isApplicable: { $0.goalDirection != .maintain && $0.weightSpanKg > 0.1 }
            ),
            Definition(
                id: "hundred-meals",
                category: .foodLogging,
                title: { _ in "Logged 100 meals" },
                isUnlocked: { $0.foodLogDays >= 100 },
                progress: { min(1, Double($0.foodLogDays) / 100) },
                isApplicable: { _ in true }
            ),
            Definition(
                id: "ten-kg",
                category: .weightProgress,
                title: { direction in
                    switch direction {
                    case .lose: return "10 kg lost"
                    case .gain: return "10 kg gained"
                    case .maintain: return "10 kg tracked"
                    }
                },
                isUnlocked: { $0.weightChangeTowardGoalKg >= 10 },
                progress: { min(1, $0.weightChangeTowardGoalKg / 10) },
                isApplicable: { $0.goalDirection != .maintain && $0.weightSpanKg >= 10 }
            )
        ]

        return definitions
    }

    // MARK: - Metrics

    private static func makeMetrics(input: Input) -> Metrics {
        let logs = input.maturityLogs
        let calendar = input.calendar
        let baseline = input.baseline
        let direction = baseline.goalDirection

        let foodLogDays = uniqueFoodLogDays(in: logs, calendar: calendar)
        let proteinGoalDays = JourneyLogMetrics.proteinGoalDays(in: logs)
        let waterGoalDays = JourneyLogMetrics.waterGoalDays(in: logs)

        let start = baseline.startWeightKg ?? 0
        let current = baseline.currentWeightKg ?? start
        let goal = baseline.goalWeightKg ?? start
        let span = abs(start - goal)

        let traveled: Double
        switch direction {
        case .lose:
            traveled = max(0, start - current)
        case .gain:
            traveled = max(0, current - start)
        case .maintain:
            traveled = abs(current - start)
        }

        let trainingWorkoutDays = uniqueTrainingWorkoutDays(
            in: logs,
            healthWorkoutDayStarts: input.healthWorkoutDayStarts,
            calendar: calendar
        )

        return Metrics(
            foodLogDays: foodLogDays,
            proteinGoalDays: proteinGoalDays,
            waterGoalDays: waterGoalDays,
            trainingWorkoutDays: trainingWorkoutDays,
            weightChangeTowardGoalKg: traveled,
            goalProgressPercent: baseline.progressPercent ?? 0,
            weightSpanKg: span,
            currentLoggingStreak: input.journeyStreaks.currentLoggingStreakDays,
            longestLoggingStreak: input.journeyStreaks.longestLoggingStreakDays,
            goalDirection: direction
        )
    }

    private static func uniqueFoodLogDays(in logs: [DailyLog], calendar: Calendar) -> Int {
        Set(
            logs.filter { $0.totals.calories > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    private static func uniqueTrainingWorkoutDays(
        in logs: [DailyLog],
        healthWorkoutDayStarts: Set<Date>,
        calendar: Calendar
    ) -> Int {
        let loggedWorkoutDays = Set(
            logs.filter { $0.workoutCaloriesBurned > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )
        return loggedWorkoutDays.union(healthWorkoutDayStarts).count
    }
}
