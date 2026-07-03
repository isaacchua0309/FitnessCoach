//
//  HealthIntelligenceContextBuilder.swift
//  Fitness Coach
//
//  Forma — Gathers repository and app data once, then builds Health Intelligence
//  engine inputs without duplicating fetches across engines.
//
//  No HealthKit imports. Safe to call from background tasks — domain adapters hop
//  to MainActor only when reading SwiftData-backed nutrition, weight, and plan data.
//

import Foundation

// MARK: - Data gaps

enum HealthIntelligenceDataGap: String, Equatable, Sendable, Hashable {
    case nutritionUnavailable
    case weightUnavailable
    case userPlanUnavailable
    case normalizedSamplesFailed
}

// MARK: - Provider protocols

struct HealthIntelligenceUserPlanSnapshot: Equatable, Sendable {
    var goal: PlanGoalType
    var calorieTarget: Int
    var proteinTargetGrams: Double
    var waterTargetMl: Int

    var adaptivePlan: AdaptiveNutritionUserPlan {
        AdaptiveNutritionUserPlan(
            calorieTarget: calorieTarget,
            proteinTargetGrams: proteinTargetGrams,
            waterTargetMl: waterTargetMl
        )
    }

    var weeklyPlan: WeeklyReviewUserPlan {
        WeeklyReviewUserPlan(
            goal: goal,
            calorieTarget: calorieTarget,
            proteinTargetGrams: proteinTargetGrams,
            waterTargetMl: waterTargetMl
        )
    }
}

protocol HealthIntelligenceNutritionProviding: Sendable {
    func dailyLog(for date: Date, calendar: Calendar) async -> DailyLog?
    func dailyLogs(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyLog]
}

protocol HealthIntelligenceWeightProviding: Sendable {
    func weightEntries(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [WeightEntry]
    func hasLoggedWeightRecently(referenceDate: Date, withinDays: Int, calendar: Calendar) async -> Bool
}

protocol HealthIntelligenceUserPlanProviding: Sendable {
    func userPlan(referenceDate: Date) async -> HealthIntelligenceUserPlanSnapshot?
}

protocol HealthIntelligenceClockProviding: Sendable {
    func now() -> Date
    func calendar() -> Calendar
}

struct SystemHealthIntelligenceClockProvider: HealthIntelligenceClockProviding {
    private let calendarValue: Calendar

    init(calendar: Calendar = .current) {
        self.calendarValue = calendar
    }

    func now() -> Date { Date() }

    func calendar() -> Calendar { calendarValue }
}

// MARK: - Placeholders

struct EmptyHealthIntelligenceNutritionProvider: HealthIntelligenceNutritionProviding {
    func dailyLog(for date: Date, calendar: Calendar) async -> DailyLog? { nil }

    func dailyLogs(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyLog] {
        []
    }
}

struct EmptyHealthIntelligenceWeightProvider: HealthIntelligenceWeightProviding {
    func weightEntries(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [WeightEntry] {
        []
    }

    func hasLoggedWeightRecently(referenceDate: Date, withinDays: Int, calendar: Calendar) async -> Bool {
        false
    }
}

struct EmptyHealthIntelligenceUserPlanProvider: HealthIntelligenceUserPlanProviding {
    func userPlan(referenceDate: Date) async -> HealthIntelligenceUserPlanSnapshot? { nil }
}

// MARK: - MainActor adapters

final class DailyLogNutritionProvider: HealthIntelligenceNutritionProviding, @unchecked Sendable {

    private let reader: any DailyLogReading

    init(reader: any DailyLogReading) {
        self.reader = reader
    }

    func dailyLog(for date: Date, calendar: Calendar) async -> DailyLog? {
        await MainActor.run {
            try? reader.getLog(for: date)
        }
    }

    func dailyLogs(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyLog] {
        await MainActor.run {
            (try? reader.getLogs(from: startDate, to: endDate)) ?? []
        }
    }
}

final class WeightLogWeightProvider: HealthIntelligenceWeightProviding, @unchecked Sendable {

    private let reader: any WeightLogReading

    init(reader: any WeightLogReading) {
        self.reader = reader
    }

    func weightEntries(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [WeightEntry] {
        await MainActor.run {
            (try? reader.getWeightEntries(from: startDate, to: endDate)) ?? []
        }
    }

    func hasLoggedWeightRecently(referenceDate: Date, withinDays: Int, calendar: Calendar) async -> Bool {
        let endDay = calendar.startOfDay(for: referenceDate)
        guard let startDay = calendar.date(byAdding: .day, value: -(withinDays - 1), to: endDay) else {
            return false
        }
        let entries = await weightEntries(from: startDay, to: endDay, calendar: calendar)
        return !entries.isEmpty
    }
}

final class UserProfilePlanProvider: HealthIntelligenceUserPlanProviding, @unchecked Sendable {

    private let profileService: UserProfileService

    init(profileService: UserProfileService) {
        self.profileService = profileService
    }

    func userPlan(referenceDate: Date) async -> HealthIntelligenceUserPlanSnapshot? {
        await MainActor.run {
            guard let profile = try? profileService.getCurrentProfile() else { return nil }
            return HealthIntelligenceUserPlanSnapshot(
                goal: PlanStateBuilder.goalType(for: profile),
                calorieTarget: profile.targets.calorieTarget,
                proteinTargetGrams: profile.targets.proteinTarget,
                waterTargetMl: profile.targets.waterTargetMl
            )
        }
    }
}

// MARK: - Context

struct HealthIntelligenceContext: Equatable, Sendable {
    let targetDate: Date
    let calendar: Calendar
    let generatedAt: Date
    let availability: HealthDataAvailability
    let dataGaps: Set<HealthIntelligenceDataGap>
    let normalizedSamples: [HealthNormalizedSample]
    let baselineContext: HealthBaselineContext
    let metricsLast7Days: [DailyHealthMetrics]
    let metricsLast28Days: [DailyHealthMetrics]
    let todayMetrics: DailyHealthMetrics
    let yesterdayMetrics: DailyHealthMetrics
    let workoutsToday: [NormalizedWorkout]
    let workoutsLast7Days: [NormalizedWorkout]
    let workoutsLast28Days: [NormalizedWorkout]
    let sleepRecords: [NormalizedSleepRecord]
    let heartMetrics: [NormalizedHeartMetric]
    let nutritionProgress: AdaptiveNutritionProgress
    let userPlan: AdaptiveNutritionUserPlan
    let hasLoggedWeightRecently: Bool
    let trainingLoadInput: TrainingLoadEngineInput
    let weeklyReviewContext: HealthIntelligenceWeeklyReviewContext?
}

// MARK: - Builder

struct HealthIntelligenceContextBuilder: HealthIntelligenceContextBuilding {

    private let repository: any HealthDataRepositorying
    private let nutritionProvider: any HealthIntelligenceNutritionProviding
    private let weightProvider: any HealthIntelligenceWeightProviding
    private let userPlanProvider: any HealthIntelligenceUserPlanProviding
    private let clock: any HealthIntelligenceClockProviding

    init(
        repository: any HealthDataRepositorying,
        nutritionProvider: any HealthIntelligenceNutritionProviding = EmptyHealthIntelligenceNutritionProvider(),
        weightProvider: any HealthIntelligenceWeightProviding = EmptyHealthIntelligenceWeightProvider(),
        userPlanProvider: any HealthIntelligenceUserPlanProviding = EmptyHealthIntelligenceUserPlanProvider(),
        clock: any HealthIntelligenceClockProviding = SystemHealthIntelligenceClockProvider()
    ) {
        self.repository = repository
        self.nutritionProvider = nutritionProvider
        self.weightProvider = weightProvider
        self.userPlanProvider = userPlanProvider
        self.clock = clock
    }

    func buildContext(for targetDate: Date, calendar: Calendar) async -> HealthIntelligenceContext {
        let targetDay = calendar.startOfDay(for: targetDate)
        let generatedAt = clock.now()
        var dataGaps = Set<HealthIntelligenceDataGap>()

        let inclusive28 = Self.inclusiveDayRange(
            endingOn: targetDay,
            days: HealthBaselinePolicy.lookback28Days,
            calendar: calendar
        )
        let baselineWindow = HealthBaselineService.lookbackWindow(
            endingBefore: targetDay,
            days: HealthBaselinePolicy.lookback28Days,
            calendar: calendar
        )
        let weekRange = HealthIntelligenceBaseline.metricsInWeek(endingOn: targetDay, calendar: calendar)

        async let availabilityTask = repository.getHealthDataAvailability()
        async let metricsTask = repository.getDailyMetrics(
            from: inclusive28.start,
            to: inclusive28.end,
            calendar: calendar
        )
        async let workoutsTask = repository.getWorkouts(
            from: inclusive28.start,
            to: inclusive28.end,
            calendar: calendar
        )
        async let sleepTask = repository.getSleepRecords(
            from: inclusive28.start,
            to: inclusive28.end,
            calendar: calendar
        )
        async let heartTask = repository.getHeartMetrics(
            from: inclusive28.start,
            to: inclusive28.end,
            calendar: calendar
        )
        async let bodyMassTask = repository.getBodyMassHistory(
            days: HealthBaselinePolicy.lookback28Days,
            calendar: calendar
        )
        async let todayLogTask = nutritionProvider.dailyLog(for: targetDay, calendar: calendar)
        async let weekLogsTask: [DailyLog] = {
            guard let weekRange else { return [] }
            return await nutritionProvider.dailyLogs(
                from: weekRange.start,
                to: weekRange.end,
                calendar: calendar
            )
        }()
        async let userPlanTask = userPlanProvider.userPlan(referenceDate: targetDay)
        async let hasRecentWeightTask = weightProvider.hasLoggedWeightRecently(
            referenceDate: targetDay,
            withinDays: 7,
            calendar: calendar
        )
        async let appWeightEntriesTask: [WeightEntry] = {
            guard let weekRange else { return [] }
            return await weightProvider.weightEntries(
                from: weekRange.start,
                to: weekRange.end,
                calendar: calendar
            )
        }()

        let availability = await availabilityTask
        let metrics = await metricsTask
        let workouts = await workoutsTask
        let sleepRecords = await sleepTask
        let heartMetrics = await heartTask
        let healthWeightRecords = await bodyMassTask
        let todayLog = await todayLogTask
        let weekLogs = await weekLogsTask
        let userPlanSnapshot = await userPlanTask
        let hasLoggedWeightRecently = await hasRecentWeightTask
        let appWeightEntries = await appWeightEntriesTask

        var normalizedSamples: [HealthNormalizedSample] = []
        do {
            normalizedSamples = try await repository.normalizedSamples(for: targetDay, calendar: calendar)
        } catch {
            dataGaps.insert(.normalizedSamplesFailed)
        }

        if todayLog == nil, weekLogs.isEmpty {
            dataGaps.insert(.nutritionUnavailable)
        }
        if userPlanSnapshot == nil {
            dataGaps.insert(.userPlanUnavailable)
        }
        if healthWeightRecords.isEmpty, appWeightEntries.isEmpty {
            dataGaps.insert(.weightUnavailable)
        }

        let baselineMetrics28: [DailyHealthMetrics]
        if let baselineWindow {
            baselineMetrics28 = metrics.filter {
                let day = calendar.startOfDay(for: $0.date)
                return day >= calendar.startOfDay(for: baselineWindow.start)
                    && day <= calendar.startOfDay(for: baselineWindow.end)
            }
        } else {
            baselineMetrics28 = []
        }

        let baselineContext = HealthBaselineService.buildContext(
            for: targetDay,
            prefetched: HealthBaselinePrefetch(
                availability: availability,
                metrics28: baselineMetrics28,
                workouts: workouts,
                sleepRecords: sleepRecords,
                heartMetrics: heartMetrics
            ),
            calendar: calendar
        )

        let todayMetrics = metrics.first {
            calendar.isDate($0.date, inSameDayAs: targetDay)
        } ?? .empty(for: targetDay)
        let yesterdayDay = calendar.date(byAdding: .day, value: -1, to: targetDay) ?? targetDay
        let yesterdayMetrics = metrics.first {
            calendar.isDate($0.date, inSameDayAs: yesterdayDay)
        } ?? .empty(for: yesterdayDay)

        let workoutsToday = Self.workouts(on: targetDay, in: workouts, calendar: calendar)
        let workoutsLast7 = Self.workouts(
            in: Self.inclusiveDayRange(endingOn: targetDay, days: 7, calendar: calendar),
            from: workouts,
            calendar: calendar
        )
        let workoutsLast28 = Self.workouts(
            in: Self.inclusiveDayRange(endingOn: targetDay, days: 28, calendar: calendar),
            from: workouts,
            calendar: calendar
        )

        let baselineWeeklyLoad = baselineContext.averageWorkoutLoad28d.map { $0 * 7 }

        let trainingLoadInput = TrainingLoadEngineInput(
            targetDate: targetDay,
            workoutsToday: workoutsToday,
            workoutsLast7Days: workoutsLast7,
            workoutsLast28Days: workoutsLast28,
            baselineAverageWeeklyLoad: baselineWeeklyLoad,
            calendar: calendar
        )

        let nutritionProgress = Self.adaptiveNutritionProgress(
            from: todayLog,
            fallbackPlan: userPlanSnapshot?.adaptivePlan
        )
        let adaptivePlan = userPlanSnapshot?.adaptivePlan ?? .unavailable

        let weekMetrics: [DailyHealthMetrics]
        if let weekRange {
            weekMetrics = metrics.filter {
                let day = calendar.startOfDay(for: $0.date)
                return day >= weekRange.start && day <= weekRange.end
            }
        } else {
            weekMetrics = []
        }

        let activeWeekDays = weekMetrics.filter(HealthIntelligenceBaseline.dayHasActivity).count
        let weeklyReviewContext: HealthIntelligenceWeeklyReviewContext?
        if let weekRange {
            weeklyReviewContext = HealthIntelligenceWeeklyReviewContext(
                weekStartDate: weekRange.start,
                weekEndDate: weekRange.end,
                weekMetrics: weekMetrics,
                weekWorkouts: Self.workouts(in: weekRange, from: workouts, calendar: calendar),
                weekLogs: weekLogs,
                weightRecords: Self.mergedWeightRecords(
                    health: healthWeightRecords,
                    app: appWeightEntries,
                    in: weekRange,
                    calendar: calendar
                ),
                userPlan: userPlanSnapshot?.weeklyPlan ?? .unavailable,
                hasEnoughActivity: activeWeekDays >= HealthIntelligenceBaseline.minimumWeeklyReviewDays
            )
        } else {
            weeklyReviewContext = nil
        }

        return HealthIntelligenceContext(
            targetDate: targetDay,
            calendar: calendar,
            generatedAt: generatedAt,
            availability: availability,
            dataGaps: dataGaps,
            normalizedSamples: normalizedSamples,
            baselineContext: baselineContext,
            metricsLast7Days: weekMetrics,
            metricsLast28Days: metrics,
            todayMetrics: todayMetrics,
            yesterdayMetrics: yesterdayMetrics,
            workoutsToday: workoutsToday,
            workoutsLast7Days: workoutsLast7,
            workoutsLast28Days: workoutsLast28,
            sleepRecords: sleepRecords,
            heartMetrics: heartMetrics,
            nutritionProgress: nutritionProgress,
            userPlan: adaptivePlan,
            hasLoggedWeightRecently: hasLoggedWeightRecently,
            trainingLoadInput: trainingLoadInput,
            weeklyReviewContext: weeklyReviewContext
        )
    }

    // MARK: - Weekly review helpers (input assembly lives in engine)

    static func adaptiveNutritionProgress(
        from log: DailyLog?,
        fallbackPlan: AdaptiveNutritionUserPlan?
    ) -> AdaptiveNutritionProgress {
        guard let log else {
            if let fallbackPlan, fallbackPlan.isAvailable {
                return AdaptiveNutritionProgress(
                    proteinConsumedGrams: 0,
                    proteinTargetGrams: fallbackPlan.proteinTargetGrams,
                    proteinRemainingGrams: fallbackPlan.proteinTargetGrams,
                    caloriesConsumed: 0,
                    calorieTarget: fallbackPlan.calorieTarget,
                    calorieRemaining: fallbackPlan.calorieTarget,
                    waterConsumedMl: 0,
                    waterTargetMl: fallbackPlan.waterTargetMl,
                    waterRemainingMl: fallbackPlan.waterTargetMl
                )
            }
            return .unavailable
        }

        let summary = DailyNutritionSummaryBuilder.build(from: log)
        return AdaptiveNutritionProgress(
            proteinConsumedGrams: summary.totals.protein,
            proteinTargetGrams: summary.targets.protein,
            proteinRemainingGrams: summary.remaining.protein,
            caloriesConsumed: summary.totals.calories,
            calorieTarget: summary.targets.calories,
            calorieRemaining: summary.remaining.calories,
            waterConsumedMl: summary.water.consumedMl,
            waterTargetMl: summary.water.targetMl,
            waterRemainingMl: summary.water.remainingMl
        )
    }

    static func weeklyNutritionSummary(from log: DailyLog) -> WeeklyNutritionDailySummary {
        let summary = DailyNutritionSummaryBuilder.build(from: log)
        return WeeklyNutritionDailySummary(
            date: log.date,
            caloriesConsumed: summary.totals.calories,
            calorieTarget: summary.targets.calories,
            proteinConsumedGrams: summary.totals.protein,
            proteinTargetGrams: summary.targets.protein,
            waterConsumedMl: summary.water.consumedMl,
            waterTargetMl: summary.water.targetMl,
            didLogFood: summary.totals.calories > 0
        )
    }

    // MARK: - Weight mapping

    static func mergedWeightRecords(
        health: [NormalizedBodyMass],
        app: [WeightEntry],
        in range: (start: Date, end: Date),
        calendar: Calendar
    ) -> [NormalizedBodyMass] {
        var byDay: [Date: NormalizedBodyMass] = [:]

        for record in health {
            let day = calendar.startOfDay(for: record.date)
            guard day >= range.start, day <= range.end else { continue }
            byDay[day] = record
        }

        for entry in app {
            let day = calendar.startOfDay(for: entry.date)
            guard day >= range.start, day <= range.end else { continue }
            byDay[day] = NormalizedBodyMass(id: entry.id, date: entry.date, valueKg: entry.weightKg)
        }

        return byDay.values.sorted { $0.date < $1.date }
    }

    // MARK: - Date helpers

    static func inclusiveDayRange(
        endingOn day: Date,
        days: Int,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: day)
        let start = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: end) ?? end
        return (start, end)
    }

    static func workouts(
        on day: Date,
        in workouts: [NormalizedWorkout],
        calendar: Calendar
    ) -> [NormalizedWorkout] {
        workouts.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
    }

    static func workouts(
        in range: (start: Date, end: Date),
        from workouts: [NormalizedWorkout],
        calendar: Calendar
    ) -> [NormalizedWorkout] {
        workouts.filter {
            let workoutDay = calendar.startOfDay(for: $0.startDate)
            return workoutDay >= range.start && workoutDay <= range.end
        }
    }
}
