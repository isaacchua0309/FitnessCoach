//
//  JourneyStateBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic Journey narrative from logged data.
//

import Foundation

enum JourneyStateBuilder {

    // MARK: Transformation

    static func transformation(
        profile: UserProfile?,
        currentWeightKg: Double?,
        projection: ProgressProjection?,
        weightDirection: WeightTrendDirection,
        journeyStartDate: Date,
        loggedDays: Int
    ) -> JourneyTransformationState {
        let goal = profile?.goalWeightKg
        let current = currentWeightKg ?? profile?.currentWeightKg
        let start = profile?.currentWeightKg

        let goalTitle: String
        if let start, let goal, abs(start - goal) > 0.1 {
            let delta = abs(start - goal)
            let formatted = delta.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(delta)) kg"
                : String(format: "%.1f kg", delta)
            goalTitle = goal < start ? "Lose \(formatted)" : "Gain \(formatted)"
        } else {
            goalTitle = "Your transformation"
        }

        let progress = goalProgressPercent(start: start, current: current, goal: goal)

        return JourneyTransformationState(
            goalTitle: goalTitle,
            startedLabel: "Started \(journeyStartDate.formatted(.dateTime.month(.abbreviated).day()))",
            currentWeightKg: current,
            goalWeightKg: goal,
            progressPercent: progress,
            estimatedCompletionLabel: projection?.projectedGoalDate.map {
                $0.formatted(.dateTime.month(.wide).year())
            },
            currentPhase: currentPhase(progress: progress, loggedDays: loggedDays, direction: weightDirection),
            coachInsight: transformationCoachInsight(
                progress: progress,
                direction: weightDirection,
                loggedDays: loggedDays,
                projection: projection
            )
        )
    }

    // MARK: Milestones

    static func milestones(
        startWeight: Double?,
        currentWeight: Double?,
        goalWeight: Double?
    ) -> [JourneyMilestone] {
        guard let startWeight, let goalWeight, abs(startWeight - goalWeight) > 0.1 else {
            return []
        }

        let descending = goalWeight < startWeight
        let span = abs(startWeight - goalWeight)
        let stepCount = 4
        let weights: [Double] = (0...stepCount).map { index in
            let fraction = Double(index) / Double(stepCount)
            let value = descending
                ? startWeight - span * fraction
                : startWeight + span * fraction
            return (value * 10).rounded() / 10
        }

        let current = currentWeight ?? startWeight

        return weights.enumerated().map { index, weight in
            let nextIndex: Int
            if descending {
                if current >= weights[0] - 0.05 {
                    nextIndex = 0
                } else if let idx = weights.firstIndex(where: { $0 < current - 0.05 }) {
                    nextIndex = idx
                } else {
                    nextIndex = weights.count - 1
                }
            } else if current <= weights[0] + 0.05 {
                nextIndex = 0
            } else if let idx = weights.firstIndex(where: { $0 > current + 0.05 }) {
                nextIndex = idx
            } else {
                nextIndex = weights.count - 1
            }

            let status: JourneyMilestoneStatus
            if index < nextIndex {
                status = .completed
            } else if index == nextIndex {
                status = .current
            } else {
                status = .upcoming
            }

            return JourneyMilestone(
                id: "m-\(index)",
                weightKg: weight,
                status: status
            )
        }
    }

    // MARK: Weekly Snapshot

    static func weeklySnapshot(
        weekLogs: [DailyLog],
        weekWorkouts: [WorkoutEntry]
    ) -> JourneyWeeklySnapshot {
        let calendar = Calendar.current
        let workoutDays = Set(weekWorkouts.map { calendar.startOfDay(for: $0.createdAt) }).count

        let proteinEligible = weekLogs.filter { $0.targets.proteinTarget > 0 }
        let proteinDays = proteinEligible.filter {
            $0.totals.protein >= $0.targets.proteinTarget * 0.9
        }.count

        let waterEligible = weekLogs.filter { $0.targets.waterTargetMl > 0 }
        let waterDays = waterEligible.filter {
            Double($0.waterConsumedMl) >= Double($0.targets.waterTargetMl) * 0.8
        }.count

        let deficits: [Int] = weekLogs.compactMap { log in
            let target = log.targets.calorieTarget
            guard target > 0 else { return nil }
            return target - log.totals.calories
        }
        let avgDeficit = deficits.isEmpty
            ? nil
            : Int((Double(deficits.reduce(0, +)) / Double(deficits.count)).rounded())

        let burnValues = weekWorkouts.compactMap(\.estimatedCaloriesBurned)
        let avgBurn = burnValues.isEmpty
            ? nil
            : Int((Double(burnValues.reduce(0, +)) / Double(burnValues.count)).rounded())

        let durations = weekWorkouts.compactMap(\.durationMinutes)
        let avgDuration = durations.isEmpty
            ? nil
            : Int((Double(durations.reduce(0, +)) / Double(durations.count)).rounded())

        return JourneyWeeklySnapshot(
            workoutDays: workoutDays,
            proteinDaysAchieved: proteinDays,
            proteinDaysTotal: max(proteinEligible.count, weekLogs.count),
            waterDaysAchieved: waterDays,
            waterDaysTotal: max(waterEligible.count, weekLogs.count),
            averageCalorieDeficit: avgDeficit,
            averageCaloriesBurned: avgBurn,
            averageTrainingDurationMinutes: avgDuration
        )
    }

    // MARK: Coach Insights

    static func coachInsights(
        weekLogs: [DailyLog],
        previousWeekLogs: [DailyLog],
        weekWorkouts: [WorkoutEntry],
        weightSummary: ProgressWeightSummary,
        nutrition: ProgressNutritionSummary,
        water: ProgressWaterSummary
    ) -> [JourneyCoachInsight] {
        var insights: [JourneyCoachInsight] = []

        let proteinEligible = weekLogs.filter { $0.targets.proteinTarget > 0 }
        if !proteinEligible.isEmpty {
            let hitCount = proteinEligible.filter { $0.totals.protein >= $0.targets.proteinTarget * 0.9 }.count
            let ratio = Double(hitCount) / Double(proteinEligible.count)
            if ratio >= 0.7 {
                insights.append(JourneyCoachInsight(
                    id: "protein-strong",
                    message: "You maintained excellent protein intake this week."
                ))
            } else if ratio < 0.4 {
                insights.append(JourneyCoachInsight(
                    id: "protein-low",
                    message: "Protein dipped this week — anchor each meal with a lean source."
                ))
            }
        }

        let waterEligible = weekLogs.filter { $0.targets.waterTargetMl > 0 }
        let prevWaterEligible = previousWeekLogs.filter { $0.targets.waterTargetMl > 0 }
        if !waterEligible.isEmpty, !prevWaterEligible.isEmpty {
            let thisWeek = averageWaterConsistency(logs: waterEligible)
            let lastWeek = averageWaterConsistency(logs: prevWaterEligible)
            if thisWeek < lastWeek - 0.15 {
                insights.append(JourneyCoachInsight(
                    id: "water-down",
                    message: "Water intake decreased this week. Front-load hydration earlier in the day."
                ))
            } else if thisWeek >= 0.8 {
                insights.append(JourneyCoachInsight(
                    id: "water-strong",
                    message: "Hydration stayed strong — that supports recovery and appetite control."
                ))
            }
        }

        if weightSummary.direction == .stable, !weekWorkouts.isEmpty {
            insights.append(JourneyCoachInsight(
                id: "weight-stable-training",
                message: "Weight remained stable after heavy strength training — normal with glycogen and water shifts."
            ))
        } else if weightSummary.direction == .decreasing {
            insights.append(JourneyCoachInsight(
                id: "weight-trend",
                message: "Your weight trend is moving in the right direction. Trust the weekly pattern, not daily noise."
            ))
        }

        if weekWorkouts.count >= 3 {
            insights.append(JourneyCoachInsight(
                id: "training-consistency",
                message: "Training consistency is building — that's what compounds results."
            ))
        }

        if let avgCal = nutrition.averageCalories, !weekLogs.isEmpty {
            let targets = weekLogs.map(\.targets.calorieTarget).filter { $0 > 0 }
            if let targetAvg = average(targets.map(Double.init)), abs(Double(avgCal) - targetAvg) <= targetAvg * 0.1 {
                insights.append(JourneyCoachInsight(
                    id: "calories-steady",
                    message: "Calorie intake stayed steady — discipline without perfection."
                ))
            }
        }

        if insights.isEmpty {
            insights.append(JourneyCoachInsight(
                id: "keep-going",
                message: "You're building the habit layer. Consistency this week matters more than scale movement."
            ))
        }

        return Array(insights.prefix(4))
    }

    // MARK: Consistency Calendar

    static func consistencyCalendar(
        logs: [DailyLog],
        workouts: [WorkoutEntry],
        weights: [WeightEntry],
        month: Date = Date()
    ) -> JourneyConsistencyCalendar {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month) else {
            return JourneyConsistencyCalendar(
                monthTitle: month.formatted(.dateTime.month(.wide).year()),
                weekdaySymbols: calendar.shortWeekdaySymbols,
                days: [],
                completedCount: 0
            )
        }

        let completedDays = completedDaySet(logs: logs, workouts: workouts, weights: weights, calendar: calendar)

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [JourneyCalendarDay] = []
        for _ in 0..<leadingBlanks {
            days.append(JourneyCalendarDay(id: UUID().uuidString, dayNumber: nil, isCompleted: false))
        }

        var monthCompleted = 0
        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else {
                continue
            }
            let dayStart = calendar.startOfDay(for: date)
            let isCompleted = completedDays.contains(dayStart)
            if isCompleted { monthCompleted += 1 }
            days.append(JourneyCalendarDay(
                id: "d-\(day)",
                dayNumber: day,
                isCompleted: isCompleted
            ))
        }

        return JourneyConsistencyCalendar(
            monthTitle: month.formatted(.dateTime.month(.wide).year()),
            weekdaySymbols: calendar.shortWeekdaySymbols,
            days: days,
            completedCount: monthCompleted
        )
    }

    // MARK: Achievements

    static func achievements(
        logs: [DailyLog],
        workouts: [WorkoutEntry],
        weights: [WeightEntry],
        profile: UserProfile?,
        calendar: Calendar = .current
    ) -> [JourneyAchievement] {
        let completedDays = completedDaySet(
            logs: logs,
            workouts: workouts,
            weights: weights,
            calendar: calendar
        )
        let sortedCompleted = completedDays.sorted()
        let streak = longestStreak(in: sortedCompleted, calendar: calendar)

        let startWeight = profile?.currentWeightKg
        let latestWeight = WeightTrendCalculator.latestWeight(from: weights)?.weightKg
        let lostFirstKg: Bool = {
            guard let startWeight, let latestWeight, startWeight > latestWeight else { return false }
            return (startWeight - latestWeight) >= 1.0
        }()

        return [
            JourneyAchievement(id: "first-workout", title: "First workout", isUnlocked: !workouts.isEmpty),
            JourneyAchievement(id: "first-week", title: "First week", isUnlocked: streak >= 7 || completedDays.count >= 7),
            JourneyAchievement(id: "first-kg", title: "Lost first kilogram", isUnlocked: lostFirstKg),
            JourneyAchievement(id: "14-day", title: "14-day consistency", isUnlocked: streak >= 14 || completedDays.count >= 14)
        ]
    }

    // MARK: Weight Trend

    static func weightTrendInterpretation(summary: ProgressWeightSummary) -> String {
        if summary.hasSuddenSpike {
            if let change = summary.changeKg, change > 0 {
                return "A recent bump is likely water retention — your longer trend matters more."
            }
            return "Daily weight jumped — often water or sodium. Keep logging and watch the weekly shape."
        }

        switch summary.direction {
        case .decreasing:
            return "The trend is moving toward your goal. Stay patient through normal daily fluctuations."
        case .increasing:
            return "Weight has drifted up recently. Review intake and recovery if that wasn't the plan."
        case .stable:
            return "Weight is holding steady — recomposition and maintenance both show up here first."
        case .insufficientData:
            return "Log weight a few times in Coach to reveal your trend."
        }
    }

    // MARK: Helpers

    static func journeyStartDate(
        profile: UserProfile?,
        logs: [DailyLog],
        weights: [WeightEntry]
    ) -> Date {
        let earliestLog = logs.map(\.date).min()
        let earliestWeight = weights.map(\.date).min()
        let candidates = [profile?.createdAt, earliestLog, earliestWeight].compactMap { $0 }
        return candidates.min() ?? Date()
    }

    private static func goalProgressPercent(
        start: Double?,
        current: Double?,
        goal: Double?
    ) -> Double? {
        guard let start, let current, let goal, start != goal else { return nil }
        let total = goal - start
        let traveled = current - start
        return max(0, min(100, (traveled / total) * 100))
    }

    private static func currentPhase(
        progress: Double?,
        loggedDays: Int,
        direction: WeightTrendDirection
    ) -> String {
        if loggedDays < 7 { return "Getting started" }
        guard let progress else { return "Building momentum" }
        if progress >= 75 { return "Closing in" }
        if progress >= 25 { return direction == .decreasing ? "Building momentum" : "Pushing forward" }
        return "Laying foundations"
    }

    private static func transformationCoachInsight(
        progress: Double?,
        direction: WeightTrendDirection,
        loggedDays: Int,
        projection: ProgressProjection?
    ) -> String {
        if loggedDays < 7 {
            return "You've started strong. Consistency this week matters more than scale movement."
        }
        if let progress, progress >= 75 {
            return "You're deep into this journey. Protect the habits that got you here."
        }
        if direction == .decreasing {
            return "Momentum is on your side. Keep logging honestly — the trend will reward patience."
        }
        if projection?.projectedGoalDate != nil {
            return "You're on a path. Small daily choices are writing the outcome."
        }
        return "Consistency this week matters more than scale movement."
    }

    private static func completedDaySet(
        logs: [DailyLog],
        workouts: [WorkoutEntry],
        weights: [WeightEntry],
        calendar: Calendar
    ) -> Set<Date> {
        var days = Set<Date>()

        for log in logs where log.totals.calories > 0 || log.waterConsumedMl > 0 {
            days.insert(calendar.startOfDay(for: log.date))
        }
        for weight in weights {
            days.insert(calendar.startOfDay(for: weight.date))
        }
        for workout in workouts {
            days.insert(calendar.startOfDay(for: workout.createdAt))
        }

        return days
    }

    private static func averageWaterConsistency(logs: [DailyLog]) -> Double {
        guard !logs.isEmpty else { return 0 }
        let hits = logs.filter {
            Double($0.waterConsumedMl) >= Double($0.targets.waterTargetMl) * 0.8
        }.count
        return Double(hits) / Double(logs.count)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func longestStreak(in sortedDays: [Date], calendar: Calendar) -> Int {
        guard !sortedDays.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let day = sortedDays[index]
            if let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }
}

/// Lightweight weight summary for Journey builders (no spreadsheet UI).
struct ProgressWeightSummary: Equatable {
    var latestWeightKg: Double?
    var changeKg: Double?
    var direction: WeightTrendDirection
    var hasSuddenSpike: Bool
}
