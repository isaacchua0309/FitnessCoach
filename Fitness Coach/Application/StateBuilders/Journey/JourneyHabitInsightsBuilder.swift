//
//  JourneyHabitInsightsBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic strongest/weakest habit insights for Journey.
//

import Foundation

enum JourneyHabitInsightsBuilder {

    struct Input: Equatable {
        var profile: UserProfile?
        var maturityLogs: [DailyLog]
        var weekLogs: [DailyLog]
        var weekWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var isAppleHealthConnected: Bool
        var expectedTrainingDaysPerWeek: Int
        var hasRealWeightEntries: Bool
        var asOf: Date
        var calendar: Calendar
    }

    private struct HabitScore: Equatable {
        var kind: JourneyHabitKind
        var score: Int
        var eligibleForWeakest: Bool
    }

    private static let lookbackDays = 14
    private static let minimumFoodLogDaysToUnlock = 3
    private static let minimumDaysOnJourneyForWeightWeakest = 3

    static func build(_ input: Input) -> JourneyHabitInsightsState {
        let copy = FormaProductCopy.Journey.HabitInsights.self
        let windowLogs = logsInLookbackWindow(input: input)
        let foodLogDays = uniqueFoodLogDays(in: windowLogs, calendar: input.calendar)

        guard foodLogDays >= minimumFoodLogDaysToUnlock else {
            return .locked
        }

        var candidates = baseHabitScores(windowLogs: windowLogs, input: input)

        if input.isAppleHealthConnected {
            candidates.append(trainingScore(input: input, windowLogs: windowLogs))
        }

        let rankedForStrongest = candidates.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return kindOrder(lhs.kind) < kindOrder(rhs.kind)
        }

        let weakestPool = candidates.filter(\.eligibleForWeakest)
        let rankedForWeakest = weakestPool.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return kindOrder(lhs.kind) < kindOrder(rhs.kind)
        }

        guard let strongest = rankedForStrongest.first,
              let weakest = rankedForWeakest.first else {
            return .locked
        }

        let strongestPercent = strongest.score
        let weakestPercent = weakest.score

        return JourneyHabitInsightsState(
            isUnlocked: true,
            lockedMessage: nil,
            strongestHabitLabel: habitLabel(for: strongest.kind),
            strongestScorePercent: strongestPercent,
            strongestQualitative: copy.strongestQualitative(percent: strongestPercent),
            weakestHabitLabel: habitLabel(for: weakest.kind),
            weakestHabitKind: weakest.kind,
            weakestScorePercent: weakestPercent,
            weakestScorePrefix: nil,
            suggestedNextAction: suggestedAction(for: weakest.kind, input: input),
            suggestionCTA: JourneyCTARouter.habitSuggestionCTA(
                weakestKind: weakest.kind,
                isAppleHealthConnected: input.isAppleHealthConnected
            )
        )
    }

    // MARK: - Scoring

    private static func baseHabitScores(
        windowLogs: [DailyLog],
        input: Input
    ) -> [HabitScore] {
        let calendar = input.calendar
        let foodDays = uniqueFoodLogDays(in: windowLogs, calendar: calendar)
        let foodEligible = max(lookbackDays, 1)

        let proteinEligible = windowLogs.filter { $0.targets.proteinTarget > 0 }.count
        let waterEligible = windowLogs.filter { $0.targets.waterTargetMl > 0 }.count
        let calorieEligible = windowLogs.filter { $0.targets.calorieTarget > 0 }.count

        let proteinAchieved = JourneyLogMetrics.proteinGoalDays(in: windowLogs)
        let waterAchieved = JourneyLogMetrics.waterGoalDays(in: windowLogs)
        let calorieAchieved = JourneyLogMetrics.calorieAdherenceDays(in: windowLogs)

        let weekendDays = weekendDaysInWindow(input: input)
        let loggedWeekendDays = weekendDays.filter { day in
            windowLogs.contains { log in
                calendar.isDate(log.date, inSameDayAs: day) && log.totals.calories > 0
            }
        }.count

        let weightLogsThisWeek = input.weekWeights.filter { $0.weightKg > 0 }.count
        let daysOnJourney = daysSinceJourneyStart(input: input)

        return [
            HabitScore(
                kind: .foodLogging,
                score: percentScore(achieved: foodDays, eligible: foodEligible),
                eligibleForWeakest: foodDays > 0
            ),
            HabitScore(
                kind: .protein,
                score: percentScore(achieved: proteinAchieved, eligible: max(proteinEligible, 1)),
                eligibleForWeakest: proteinEligible > 0
            ),
            HabitScore(
                kind: .water,
                score: percentScore(achieved: waterAchieved, eligible: max(waterEligible, 1)),
                eligibleForWeakest: waterEligible > 0
            ),
            HabitScore(
                kind: .calorieAdherence,
                score: percentScore(achieved: calorieAchieved, eligible: max(calorieEligible, 1)),
                eligibleForWeakest: calorieEligible > 0
            ),
            HabitScore(
                kind: .weightLogging,
                score: percentScore(achieved: weightLogsThisWeek, eligible: 2),
                eligibleForWeakest: daysOnJourney >= minimumDaysOnJourneyForWeightWeakest
            ),
            HabitScore(
                kind: .weekendLogging,
                score: percentScore(achieved: loggedWeekendDays, eligible: max(weekendDays.count, 1)),
                eligibleForWeakest: weekendDays.count >= 2
            )
        ]
    }

    private static func trainingScore(input: Input, windowLogs: [DailyLog]) -> HabitScore {
        let windowStart = lookbackWindowStart(input: input)
        let workoutDays = input.healthWorkoutDayStarts.filter {
            $0 >= windowStart && $0 <= input.calendar.startOfDay(for: input.asOf)
        }.count
        let weeksInWindow = Double(lookbackDays) / 7.0
        let expected = max(
            1,
            Int((weeksInWindow * Double(max(input.expectedTrainingDaysPerWeek, 1))).rounded())
        )

        return HabitScore(
            kind: .training,
            score: percentScore(achieved: workoutDays, eligible: expected),
            eligibleForWeakest: true
        )
    }

    // MARK: - Suggestions

    private static func suggestedAction(for habit: JourneyHabitKind, input: Input) -> String {
        let copy = FormaProductCopy.Journey.HabitInsights.self
        switch habit {
        case .weekendLogging:
            return copy.suggestWeekendLogging
        case .water:
            return copy.suggestWaterCheckIn
        case .protein:
            return copy.suggestProteinFirstMeal
        case .weightLogging:
            return copy.suggestLogWeightTwice
        case .foodLogging:
            return copy.suggestLogNextMeal
        case .calorieAdherence:
            return copy.suggestCaloriePlanning
        case .training:
            return copy.suggestTrainingWalk
        }
    }

    // MARK: - Labels & ordering

    private static func habitLabel(for kind: JourneyHabitKind) -> String {
        let copy = FormaProductCopy.Journey.HabitInsights.self
        switch kind {
        case .foodLogging: return copy.foodLoggingLabel
        case .protein: return copy.proteinLabel
        case .water: return copy.waterLabel
        case .calorieAdherence: return copy.calorieLabel
        case .training: return copy.trainingLabel
        case .weightLogging: return copy.weightLabel
        case .weekendLogging: return copy.weekendLabel
        }
    }

    private static func kindOrder(_ kind: JourneyHabitKind) -> Int {
        switch kind {
        case .foodLogging: return 0
        case .protein: return 1
        case .water: return 2
        case .calorieAdherence: return 3
        case .training: return 4
        case .weightLogging: return 5
        case .weekendLogging: return 6
        }
    }

    // MARK: - Window helpers

    private static func logsInLookbackWindow(input: Input) -> [DailyLog] {
        let start = lookbackWindowStart(input: input)
        let end = input.calendar.startOfDay(for: input.asOf)
        return input.maturityLogs.filter {
            let day = input.calendar.startOfDay(for: $0.date)
            return day >= start && day <= end
        }
    }

    private static func lookbackWindowStart(input: Input) -> Date {
        input.calendar.startOfDay(
            for: input.calendar.date(
                byAdding: .day,
                value: -(lookbackDays - 1),
                to: input.asOf
            ) ?? input.asOf
        )
    }

    private static func uniqueFoodLogDays(in logs: [DailyLog], calendar: Calendar) -> Int {
        Set(
            logs.filter { $0.totals.calories > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    private static func weekendDaysInWindow(input: Input) -> [Date] {
        let calendar = input.calendar
        let start = lookbackWindowStart(input: input)
        let end = calendar.startOfDay(for: input.asOf)
        var days: [Date] = []
        var cursor = start

        while cursor <= end {
            if isWeekend(cursor, calendar: calendar) {
                days.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return days
    }

    private static func isWeekend(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private static func daysSinceJourneyStart(input: Input) -> Int {
        guard let profile = input.profile else { return lookbackDays }
        let start = input.calendar.startOfDay(for: profile.createdAt)
        let end = input.calendar.startOfDay(for: input.asOf)
        return (input.calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    private static func percentScore(achieved: Int, eligible: Int) -> Int {
        guard eligible > 0 else { return 0 }
        return min(100, max(0, Int((Double(achieved) / Double(eligible) * 100).rounded())))
    }
}
