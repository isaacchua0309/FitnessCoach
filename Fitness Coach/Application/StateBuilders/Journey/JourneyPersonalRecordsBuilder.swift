//
//  JourneyPersonalRecordsBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic personal records for Journey.
//

import Foundation

enum JourneyPersonalRecordsBuilder {

    struct Input: Equatable {
        var maturityLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var goalDirection: JourneyGoalDirection
        var isAppleHealthConnected: Bool
        var calendar: Calendar
    }

    private static let minimumFoodLogDaysToUnlock = 3
    private static let rollingWeekDays = JourneyLogMetrics.weekDayCount

    static func build(_ input: Input) -> JourneyPersonalRecordsState {
        let copy = FormaProductCopy.Journey.PersonalRecords.self
        let foodLogDays = uniqueFoodLogDays(in: input.maturityLogs, calendar: input.calendar)

        guard foodLogDays >= minimumFoodLogDaysToUnlock else {
            return .locked
        }

        var records: [JourneyPersonalRecord] = []

        if let streak = longestLoggingStreak(logs: input.maturityLogs, calendar: input.calendar) {
            records.append(
                JourneyPersonalRecord(
                    id: "logging-streak",
                    title: copy.longestStreakTitle,
                    value: copy.streakDays(streak.length),
                    subtitle: streak.length == 1 ? copy.earlyRecord : nil,
                    periodLabel: streak.length > 1
                        ? JourneyFormatter.timelineDayLabel(streak.endDate, calendar: input.calendar)
                        : nil,
                    isActive: streak.length > 0,
                    isEarlyRecord: streak.length == 1
                )
            )
        }

        if let protein = bestProteinAverageWeek(logs: input.maturityLogs, calendar: input.calendar) {
            records.append(
                JourneyPersonalRecord(
                    id: "protein-week",
                    title: copy.highestProteinWeekTitle,
                    value: copy.proteinPerDay(protein.averageGrams),
                    subtitle: protein.loggedDays == 1 ? copy.earlyRecord : copy.averageOverDays(protein.loggedDays),
                    periodLabel: weekPeriodLabel(start: protein.windowStart, calendar: input.calendar),
                    isActive: protein.averageGrams > 0,
                    isEarlyRecord: protein.loggedDays == 1
                )
            )
        }

        if let weight = bestWeeklyWeightChange(
            weights: input.allWeights,
            direction: input.goalDirection,
            calendar: input.calendar
        ) {
            records.append(
                JourneyPersonalRecord(
                    id: "weight-week",
                    title: weightTitle(direction: input.goalDirection, copy: copy),
                    value: weightValue(changeKg: weight.changeKg, direction: input.goalDirection),
                    subtitle: weight.isEarly ? copy.earlyRecord : nil,
                    periodLabel: weekPeriodLabel(start: weight.windowStart, calendar: input.calendar),
                    isActive: true,
                    isEarlyRecord: weight.isEarly
                )
            )
        }

        if let month = mostConsistentMonth(logs: input.maturityLogs, calendar: input.calendar) {
            records.append(
                JourneyPersonalRecord(
                    id: "consistent-month",
                    title: copy.mostConsistentMonthTitle,
                    value: month.monthName,
                    subtitle: copy.loggedDaysInMonth(month.loggedDays),
                    periodLabel: month.yearLabel,
                    isActive: month.loggedDays > 0,
                    isEarlyRecord: month.loggedDays == 1
                )
            )
        }

        if let water = bestWaterWeek(logs: input.maturityLogs, calendar: input.calendar) {
            records.append(
                JourneyPersonalRecord(
                    id: "water-week",
                    title: copy.bestWaterWeekTitle,
                    value: copy.daysOfWeek(water.goalDays),
                    subtitle: water.goalDays == 1 ? copy.earlyRecord : nil,
                    periodLabel: weekPeriodLabel(start: water.windowStart, calendar: input.calendar),
                    isActive: water.goalDays > 0,
                    isEarlyRecord: water.goalDays == 1
                )
            )
        }

        if input.isAppleHealthConnected,
           let training = bestTrainingWeek(
               workoutDayStarts: input.healthWorkoutDayStarts,
               calendar: input.calendar
           ) {
            records.append(
                JourneyPersonalRecord(
                    id: "training-week",
                    title: copy.mostTrainingSessionsTitle,
                    value: copy.sessionsPerWeek(training.sessionCount),
                    subtitle: training.sessionCount == 1 ? copy.earlyRecord : nil,
                    periodLabel: weekPeriodLabel(start: training.windowStart, calendar: input.calendar),
                    isActive: training.sessionCount > 0,
                    isEarlyRecord: training.sessionCount == 1
                )
            )
        }

        if let meals = bestMealsLoggedWeek(logs: input.maturityLogs, calendar: input.calendar) {
            records.append(
                JourneyPersonalRecord(
                    id: "meals-week",
                    title: copy.mostMealsLoggedTitle,
                    value: copy.mealsLoggedInWeek(meals.loggedDays),
                    subtitle: meals.loggedDays == 1 ? copy.earlyRecord : nil,
                    periodLabel: weekPeriodLabel(start: meals.windowStart, calendar: input.calendar),
                    isActive: meals.loggedDays > 0,
                    isEarlyRecord: meals.loggedDays == 1
                )
            )
        }

        return JourneyPersonalRecordsState(
            isUnlocked: true,
            lockedMessage: nil,
            records: records
        )
    }

    // MARK: - Streak

    private static func longestLoggingStreak(
        logs: [DailyLog],
        calendar: Calendar
    ) -> (length: Int, endDate: Date)? {
        let sortedDays = Set(
            logs.filter { StreakCalculator.isLoggingDay($0) }
                .map { calendar.startOfDay(for: $0.date) }
        ).sorted()
        guard !sortedDays.isEmpty else { return nil }

        var bestLength = 1
        var bestEnd = sortedDays[0]
        var currentLength = 1
        var currentEnd = sortedDays[0]

        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let day = sortedDays[index]
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(nextDay, inSameDayAs: day) {
                currentLength += 1
                currentEnd = day
            } else {
                if currentLength > bestLength {
                    bestLength = currentLength
                    bestEnd = currentEnd
                }
                currentLength = 1
                currentEnd = day
            }
        }

        if currentLength > bestLength {
            bestLength = currentLength
            bestEnd = currentEnd
        }

        return (bestLength, bestEnd)
    }

    // MARK: - Protein week

    private static func bestProteinAverageWeek(
        logs: [DailyLog],
        calendar: Calendar
    ) -> (averageGrams: Double, loggedDays: Int, windowStart: Date)? {
        let dayStarts = Set(logs.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !dayStarts.isEmpty else { return nil }

        var best: (averageGrams: Double, loggedDays: Int, windowStart: Date)?

        for windowStart in dayStarts {
            guard let windowEnd = calendar.date(byAdding: .day, value: rollingWeekDays - 1, to: windowStart) else {
                continue
            }
            let weekLogs = logs.filter {
                let day = calendar.startOfDay(for: $0.date)
                return day >= windowStart && day <= windowEnd && $0.totals.calories > 0
            }
            guard !weekLogs.isEmpty else { continue }

            let totalProtein = weekLogs.reduce(0.0) { $0 + $1.totals.protein }
            let average = totalProtein / Double(weekLogs.count)

            if best == nil || average > best!.averageGrams {
                best = (average, weekLogs.count, windowStart)
            }
        }

        return best
    }

    // MARK: - Weight week

    private static func bestWeeklyWeightChange(
        weights: [WeightEntry],
        direction: JourneyGoalDirection,
        calendar: Calendar
    ) -> (changeKg: Double, windowStart: Date, isEarly: Bool)? {
        let sorted = weights.filter { $0.weightKg > 0 }.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return nil }

        let dayStarts = Set(sorted.map { calendar.startOfDay(for: $0.date) }).sorted()
        var best: (changeKg: Double, windowStart: Date, isEarly: Bool)?

        for windowStart in dayStarts {
            guard let windowEnd = calendar.date(byAdding: .day, value: rollingWeekDays - 1, to: windowStart) else {
                continue
            }
            let inWindow = sorted.filter {
                let day = calendar.startOfDay(for: $0.date)
                return day >= windowStart && day <= windowEnd
            }
            guard inWindow.count >= 2,
                  let first = inWindow.first,
                  let last = inWindow.last else { continue }

            let delta = last.weightKg - first.weightKg
            let qualifies: Bool
            switch direction {
            case .lose:
                qualifies = delta < -0.05
            case .gain:
                qualifies = delta > 0.05
            case .maintain:
                qualifies = true
            }
            guard qualifies else { continue }

            let spanDays = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: first.date),
                to: calendar.startOfDay(for: last.date)
            ).day ?? 0
            let isEarly = inWindow.count == 2 && spanDays < 3

            let isBetter: Bool
            switch direction {
            case .lose, .gain:
                isBetter = best == nil || abs(delta) > abs(best!.changeKg)
            case .maintain:
                isBetter = best == nil || abs(delta) < abs(best!.changeKg)
            }

            if isBetter {
                best = (delta, windowStart, isEarly)
            }
        }

        return best
    }

    private static func weightTitle(
        direction: JourneyGoalDirection,
        copy: FormaProductCopy.Journey.PersonalRecords.Type
    ) -> String {
        switch direction {
        case .lose:
            return copy.largestWeeklyLossTitle
        case .gain:
            return copy.largestWeeklyGainTitle
        case .maintain:
            return copy.mostStableWeekTitle
        }
    }

    private static func weightValue(changeKg: Double, direction: JourneyGoalDirection) -> String {
        switch direction {
        case .maintain:
            return String(format: "%.1f kg", abs(changeKg))
        case .lose, .gain:
            return String(format: "%.1f kg", abs(changeKg))
        }
    }

    // MARK: - Consistent month

    private static func mostConsistentMonth(
        logs: [DailyLog],
        calendar: Calendar
    ) -> (monthName: String, yearLabel: String, loggedDays: Int)? {
        var buckets: [Date: Int] = [:]

        for log in logs where log.totals.calories > 0 {
            let components = calendar.dateComponents([.year, .month], from: log.date)
            guard let monthStart = calendar.date(from: components) else { continue }
            buckets[monthStart, default: 0] += 1
        }

        guard let best = buckets.max(by: { $0.value < $1.value }) else { return nil }

        let monthName = best.key.formatted(.dateTime.month(.wide).locale(calendar.locale ?? .current))
        let yearLabel = best.key.formatted(.dateTime.year().locale(calendar.locale ?? .current))

        return (monthName, yearLabel, best.value)
    }

    // MARK: - Water week

    private static func bestWaterWeek(
        logs: [DailyLog],
        calendar: Calendar
    ) -> (goalDays: Int, windowStart: Date)? {
        let dayStarts = Set(logs.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !dayStarts.isEmpty else { return nil }

        var best: (goalDays: Int, windowStart: Date)?

        for windowStart in dayStarts {
            guard let windowEnd = calendar.date(byAdding: .day, value: rollingWeekDays - 1, to: windowStart) else {
                continue
            }
            let weekLogs = logs.filter {
                let day = calendar.startOfDay(for: $0.date)
                return day >= windowStart && day <= windowEnd
            }
            let goalDays = JourneyLogMetrics.waterGoalDays(in: weekLogs)

            if best == nil || goalDays > best!.goalDays {
                best = (goalDays, windowStart)
            }
        }

        return best
    }

    // MARK: - Training week

    private static func bestTrainingWeek(
        workoutDayStarts: Set<Date>,
        calendar: Calendar
    ) -> (sessionCount: Int, windowStart: Date)? {
        guard !workoutDayStarts.isEmpty else { return nil }
        let sorted = workoutDayStarts.sorted()

        var best: (sessionCount: Int, windowStart: Date)?

        for windowStart in sorted {
            guard let windowEnd = calendar.date(byAdding: .day, value: rollingWeekDays - 1, to: windowStart) else {
                continue
            }
            let count = sorted.filter { $0 >= windowStart && $0 <= windowEnd }.count
            if best == nil || count > best!.sessionCount {
                best = (count, windowStart)
            }
        }

        return best
    }

    // MARK: - Meals week

    private static func bestMealsLoggedWeek(
        logs: [DailyLog],
        calendar: Calendar
    ) -> (loggedDays: Int, windowStart: Date)? {
        let dayStarts = Set(logs.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !dayStarts.isEmpty else { return nil }

        var best: (loggedDays: Int, windowStart: Date)?

        for windowStart in dayStarts {
            guard let windowEnd = calendar.date(byAdding: .day, value: rollingWeekDays - 1, to: windowStart) else {
                continue
            }
            let weekLogs = logs.filter {
                let day = calendar.startOfDay(for: $0.date)
                return day >= windowStart && day <= windowEnd
            }
            let loggedDays = JourneyLogMetrics.foodLoggedDays(in: weekLogs)

            if best == nil || loggedDays > best!.loggedDays {
                best = (loggedDays, windowStart)
            }
        }

        return best
    }

    // MARK: - Helpers

    private static func uniqueFoodLogDays(in logs: [DailyLog], calendar: Calendar) -> Int {
        Set(
            logs.filter { $0.totals.calories > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    private static func weekPeriodLabel(start: Date, calendar: Calendar) -> String {
        guard let end = calendar.date(byAdding: .day, value: rollingWeekDays - 1, to: start) else {
            return JourneyFormatter.timelineDayLabel(start, calendar: calendar)
        }
        let startLabel = JourneyFormatter.timelineDayLabel(start, calendar: calendar)
        let endLabel = JourneyFormatter.timelineDayLabel(end, calendar: calendar)
        return "\(startLabel)–\(endLabel)"
    }
}
