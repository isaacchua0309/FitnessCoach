//
//  HealthBaselineService.swift
//  Fitness Coach
//
//  Forma — Rolling health baselines from normalized repository data.
//
//  Engines should consume `HealthBaselineContext` rather than recomputing rolling
//  averages independently. Baselines exclude the target date and return `nil`
//  when history is insufficient — never invented precision.
//

import Foundation

// MARK: - Signals

enum HealthBaselineSignal: String, CaseIterable, Sendable, Hashable, Codable {
    case steps
    case activeEnergy
    case sleep
    case restingHeartRate
    case hrv
    case workoutLoad
}

// MARK: - Context

struct HealthBaselineContext: Equatable, Sendable {
    let targetDate: Date
    let averageSteps7d: Double?
    let averageSteps28d: Double?
    let averageActiveEnergy7d: Double?
    let averageActiveEnergy28d: Double?
    let averageSleepDuration7d: Double?
    let averageSleepDuration28d: Double?
    let averageRestingHeartRate28d: Double?
    let averageHRV28d: Double?
    let averageWorkoutLoad28d: Double?
    let workoutDays7d: Int?
    let workoutDays28d: Int?
    let availableSignals: Set<HealthBaselineSignal>
    let missingSignals: Set<HealthBaselineSignal>
}

// MARK: - Policy

enum HealthBaselinePolicy {
    static let lookback7Days = 7
    static let lookback28Days = 28
    static let minimumHistoryDaysFor7DayBaseline = 7
    static let minimumHistoryDaysFor28DayBaseline = 28
    /// Minimum nights with sleep data required before reporting a sleep average.
    static let minimumSleepNightsFor7DayAverage = 4
    static let minimumSleepNightsFor28DayAverage = 14
    /// Minimum days with heart samples required before reporting a 28-day heart average.
    static let minimumHeartDaysFor28DayAverage = 14
}

// MARK: - Training load helper

/// Pure daily workout load used by baselines and `TrainingLoadEngine`.
enum HealthTrainingLoadCalculator {

    /// Dimensionless load score from duration and active energy. Not comparable across users.
    static func dailyLoad(for workouts: [NormalizedWorkout]) -> Double {
        workouts.reduce(0) { partial, workout in
            partial
                + Double(workout.durationMinutes)
                + (workout.activeEnergyKcal * 0.05)
        }
    }

    static func dailyLoad(
        for workouts: [NormalizedWorkout],
        on day: Date,
        calendar: Calendar
    ) -> Double {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return 0
        }

        let dayWorkouts = workouts.filter { workout in
            workout.startDate >= dayStart && workout.startDate < dayEnd
        }
        return dailyLoad(for: dayWorkouts)
    }
}

// MARK: - Service

protocol HealthBaselineServing: Sendable {
    func buildContext(
        for targetDate: Date,
        calendar: Calendar
    ) async -> HealthBaselineContext
}

extension HealthBaselineServing {
    func buildContext(for targetDate: Date) async -> HealthBaselineContext {
        await buildContext(for: targetDate, calendar: .current)
    }
}

struct HealthBaselineService: HealthBaselineServing {

    private let repository: any HealthDataRepositorying

    init(repository: any HealthDataRepositorying) {
        self.repository = repository
    }

    func buildContext(
        for targetDate: Date,
        calendar: Calendar = .current
    ) async -> HealthBaselineContext {
        let targetDay = calendar.startOfDay(for: targetDate)

        guard let window28 = Self.lookbackWindow(
            endingBefore: targetDay,
            days: HealthBaselinePolicy.lookback28Days,
            calendar: calendar
        ) else {
            return Self.emptyContext(targetDate: targetDay)
        }

        async let availabilityTask = repository.getHealthDataAvailability()
        async let metricsTask = repository.getDailyMetrics(
            from: window28.start,
            to: window28.end,
            calendar: calendar
        )
        async let workoutsTask = repository.getWorkouts(
            from: window28.start,
            to: window28.end,
            calendar: calendar
        )
        async let sleepTask = repository.getSleepRecords(
            from: window28.start,
            to: window28.end,
            calendar: calendar
        )
        async let heartTask = repository.getHeartMetrics(
            from: window28.start,
            to: window28.end,
            calendar: calendar
        )

        let availability = await availabilityTask
        let metrics28 = await metricsTask
        let workouts = await workoutsTask
        let sleepRecords = await sleepTask
        let heartMetrics = await heartTask

        let permissions = availability.permissionStatus
        let stepsReadable = permissions.access(for: .stepCount).isReadable
        let energyReadable = permissions.access(for: .activeEnergyBurned).isReadable
        let sleepReadable = permissions.access(for: .sleepAnalysis).isReadable
        let restingHRReadable = permissions.access(for: .restingHeartRate).isReadable
        let hrvReadable = permissions.access(for: .heartRateVariabilitySDNN).isReadable
        let workoutsReadable = permissions.access(for: .workout).isReadable

        let has7DayHistory = metrics28.count >= HealthBaselinePolicy.minimumHistoryDaysFor7DayBaseline
        let has28DayHistory = metrics28.count >= HealthBaselinePolicy.minimumHistoryDaysFor28DayBaseline

        let metrics7 = has7DayHistory ? Array(metrics28.suffix(HealthBaselinePolicy.lookback7Days)) : []
        let window7 = has7DayHistory
            ? Self.lookbackWindow(
                endingBefore: targetDay,
                days: HealthBaselinePolicy.lookback7Days,
                calendar: calendar
            )
            : nil

        var available = Set<HealthBaselineSignal>()
        var missing = Set<HealthBaselineSignal>()

        let averageSteps7d = stepsReadable && has7DayHistory
            ? Self.average(metrics7.map { Double($0.steps) })
            : nil
        let averageSteps28d = stepsReadable && has28DayHistory
            ? Self.average(metrics28.map { Double($0.steps) })
            : nil
        Self.track(
            signal: .steps,
            isReadable: stepsReadable,
            hasValue: averageSteps7d != nil || averageSteps28d != nil,
            available: &available,
            missing: &missing
        )

        let averageActiveEnergy7d = energyReadable && has7DayHistory
            ? Self.average(metrics7.map(\.activeEnergyKcal))
            : nil
        let averageActiveEnergy28d = energyReadable && has28DayHistory
            ? Self.average(metrics28.map(\.activeEnergyKcal))
            : nil
        Self.track(
            signal: .activeEnergy,
            isReadable: energyReadable,
            hasValue: averageActiveEnergy7d != nil || averageActiveEnergy28d != nil,
            available: &available,
            missing: &missing
        )

        let sleepByDay7 = window7.map {
            Self.sleepMinutesByDay(sleepRecords, in: $0, calendar: calendar)
        } ?? [:]
        let sleepByDay28 = Self.sleepMinutesByDay(sleepRecords, in: window28, calendar: calendar)

        let averageSleepDuration7d: Double?
        if sleepReadable, has7DayHistory {
            let values = Array(sleepByDay7.values)
            averageSleepDuration7d = values.count >= HealthBaselinePolicy.minimumSleepNightsFor7DayAverage
                ? Self.average(values)
                : nil
        } else {
            averageSleepDuration7d = nil
        }

        let averageSleepDuration28d: Double?
        if sleepReadable, has28DayHistory {
            let values = Array(sleepByDay28.values)
            averageSleepDuration28d = values.count >= HealthBaselinePolicy.minimumSleepNightsFor28DayAverage
                ? Self.average(values)
                : nil
        } else {
            averageSleepDuration28d = nil
        }
        Self.track(
            signal: .sleep,
            isReadable: sleepReadable,
            hasValue: averageSleepDuration7d != nil || averageSleepDuration28d != nil,
            available: &available,
            missing: &missing
        )

        let restingHRByDay28 = Self.heartValuesByDay(
            heartMetrics,
            kind: .restingHeartRate,
            in: window28,
            calendar: calendar
        )
        let hrvByDay28 = Self.heartValuesByDay(
            heartMetrics,
            kind: .heartRateVariabilitySDNN,
            in: window28,
            calendar: calendar
        )

        let averageRestingHeartRate28d: Double?
        if restingHRReadable, has28DayHistory {
            let values = Array(restingHRByDay28.values)
            averageRestingHeartRate28d = values.count >= HealthBaselinePolicy.minimumHeartDaysFor28DayAverage
                ? Self.average(values)
                : nil
        } else {
            averageRestingHeartRate28d = nil
        }
        Self.track(
            signal: .restingHeartRate,
            isReadable: restingHRReadable,
            hasValue: averageRestingHeartRate28d != nil,
            available: &available,
            missing: &missing
        )

        let averageHRV28d: Double?
        if hrvReadable, has28DayHistory {
            let values = Array(hrvByDay28.values)
            averageHRV28d = values.count >= HealthBaselinePolicy.minimumHeartDaysFor28DayAverage
                ? Self.average(values)
                : nil
        } else {
            averageHRV28d = nil
        }
        Self.track(
            signal: .hrv,
            isReadable: hrvReadable,
            hasValue: averageHRV28d != nil,
            available: &available,
            missing: &missing
        )

        let workoutDays7d: Int?
        let workoutDays28d: Int?
        let averageWorkoutLoad28d: Double?
        if workoutsReadable, has7DayHistory, let window7 {
            workoutDays7d = Self.workoutDays(in: window7, workouts: workouts, calendar: calendar)
        } else if workoutsReadable {
            workoutDays7d = nil
        } else {
            workoutDays7d = nil
        }

        if workoutsReadable, has28DayHistory {
            workoutDays28d = Self.workoutDays(in: window28, workouts: workouts, calendar: calendar)
            let dailyLoads = Self.days(in: window28, calendar: calendar).map { day in
                HealthTrainingLoadCalculator.dailyLoad(for: workouts, on: day, calendar: calendar)
            }
            averageWorkoutLoad28d = Self.average(dailyLoads)
        } else if workoutsReadable {
            workoutDays28d = nil
            averageWorkoutLoad28d = nil
        } else {
            workoutDays28d = nil
            averageWorkoutLoad28d = nil
        }
        Self.track(
            signal: .workoutLoad,
            isReadable: workoutsReadable,
            hasValue: workoutDays7d != nil || workoutDays28d != nil || averageWorkoutLoad28d != nil,
            available: &available,
            missing: &missing
        )

        return HealthBaselineContext(
            targetDate: targetDay,
            averageSteps7d: averageSteps7d,
            averageSteps28d: averageSteps28d,
            averageActiveEnergy7d: averageActiveEnergy7d,
            averageActiveEnergy28d: averageActiveEnergy28d,
            averageSleepDuration7d: averageSleepDuration7d,
            averageSleepDuration28d: averageSleepDuration28d,
            averageRestingHeartRate28d: averageRestingHeartRate28d,
            averageHRV28d: averageHRV28d,
            averageWorkoutLoad28d: averageWorkoutLoad28d,
            workoutDays7d: workoutDays7d,
            workoutDays28d: workoutDays28d,
            availableSignals: available,
            missingSignals: missing
        )
    }

    // MARK: - Window helpers

    static func lookbackWindow(
        endingBefore targetDay: Date,
        days: Int,
        calendar: Calendar
    ) -> (start: Date, end: Date)? {
        let dayCount = max(days, 1)
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: targetDay) else {
            return nil
        }
        guard let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: dayBefore) else {
            return nil
        }
        return (calendar.startOfDay(for: start), calendar.startOfDay(for: dayBefore))
    }

    static func days(
        in window: (start: Date, end: Date),
        calendar: Calendar
    ) -> [Date] {
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: window.start)
        let end = calendar.startOfDay(for: window.end)
        while cursor <= end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return days
    }

    // MARK: - Aggregation helpers

    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    static func sleepMinutesByDay(
        _ records: [NormalizedSleepRecord],
        in window: (start: Date, end: Date),
        calendar: Calendar
    ) -> [Date: Double] {
        var byDay: [Date: Double] = [:]
        let windowStart = calendar.startOfDay(for: window.start)
        let windowEnd = calendar.startOfDay(for: window.end)

        for record in records {
            let wakeDay = calendar.startOfDay(for: record.endDate)
            guard wakeDay >= windowStart, wakeDay <= windowEnd else { continue }
            byDay[wakeDay, default: 0] += record.asleepMinutes
        }
        return byDay
    }

    static func heartValuesByDay(
        _ metrics: [NormalizedHeartMetric],
        kind: HealthHeartMetricKind,
        in window: (start: Date, end: Date),
        calendar: Calendar
    ) -> [Date: Double] {
        var sums: [Date: Double] = [:]
        var counts: [Date: Int] = [:]
        let windowStart = calendar.startOfDay(for: window.start)
        let windowEnd = calendar.startOfDay(for: window.end)

        for metric in metrics where metric.kind == kind {
            let day = calendar.startOfDay(for: metric.date)
            guard day >= windowStart, day <= windowEnd else { continue }
            sums[day, default: 0] += metric.value
            counts[day, default: 0] += 1
        }

        var averages: [Date: Double] = [:]
        for (day, sum) in sums {
            guard let count = counts[day], count > 0 else { continue }
            averages[day] = sum / Double(count)
        }
        return averages
    }

    static func workoutDays(
        in window: (start: Date, end: Date),
        workouts: [NormalizedWorkout],
        calendar: Calendar
    ) -> Int {
        var days = Set<Date>()
        let windowStart = calendar.startOfDay(for: window.start)
        let windowEnd = calendar.startOfDay(for: window.end)

        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            guard day >= windowStart, day <= windowEnd else { continue }
            days.insert(day)
        }
        return days.count
    }

    private static func track(
        signal: HealthBaselineSignal,
        isReadable: Bool,
        hasValue: Bool,
        available: inout Set<HealthBaselineSignal>,
        missing: inout Set<HealthBaselineSignal>
    ) {
        if isReadable, hasValue {
            available.insert(signal)
        } else {
            missing.insert(signal)
        }
    }

    private static func emptyContext(targetDate: Date) -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: targetDate,
            averageSteps7d: nil,
            averageSteps28d: nil,
            averageActiveEnergy7d: nil,
            averageActiveEnergy28d: nil,
            averageSleepDuration7d: nil,
            averageSleepDuration28d: nil,
            averageRestingHeartRate28d: nil,
            averageHRV28d: nil,
            averageWorkoutLoad28d: nil,
            workoutDays7d: nil,
            workoutDays28d: nil,
            availableSignals: [],
            missingSignals: Set(HealthBaselineSignal.allCases)
        )
    }
}
