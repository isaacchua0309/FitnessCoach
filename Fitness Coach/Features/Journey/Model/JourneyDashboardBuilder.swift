//
//  JourneyDashboardBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic builders for the unified Journey dashboard payload.
//

import Foundation

enum JourneyDashboardBuilder {

    // MARK: - Context

    struct Context {
        var profile: UserProfile?
        var baseline: JourneyBaseline
        var maturityLogs: [DailyLog]
        var weekLogs: [DailyLog]
        var previousWeekLogs: [DailyLog]
        var previousWeekWeights: [WeightEntry]
        var previousWeekTrainingDays: Int
        var monthLogs: [DailyLog]
        var rangeLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var weekWeights: [WeightEntry]
        var rangeWeights: [WeightEntry]
        var streakSummary: StreakSummary
        var journeyStreaks: JourneyStreakState
        var weeklyTraining: JourneyWeeklyTrainingStatus
        var weightSummary: ProgressWeightSummary
        var goalProjection: ProgressProjection?
        var healthWorkoutDayStarts: Set<Date>
        var monthHealthWorkoutCount: Int
        var weekHealthWorkoutCount: Int
        var loggedDays: Int
        var nutritionSummary: ProgressNutritionSummary
        var waterSummary: ProgressWaterSummary
        var workoutSummary: ProgressWorkoutSummary?
        var selectedRangeDays: Int
        var asOf: Date
        var calendar: Calendar
    }

    // MARK: - Transformation

    static func transformation(
        context: Context,
        loggedDays: Int
    ) -> JourneyTransformationHeroState {
        JourneyTransformationHeroBuilder.build(
            JourneyTransformationHeroBuilder.Input(
                baseline: context.baseline,
                loggedDays: loggedDays,
                heroStreakChip: context.journeyStreaks.heroStreakChip,
                weightTrendDirection: context.weightSummary.direction,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Weekly review

    static func weeklyReview(context: Context) -> JourneyWeeklyReviewState {
        let weekLogs = context.weekLogs
        let previousWeekLogs = context.previousWeekLogs
        let total = JourneyLogMetrics.weekDayCount

        let foodDays = JourneyLogMetrics.foodLoggedDays(in: weekLogs)
        let proteinDays = JourneyLogMetrics.proteinGoalDays(in: weekLogs)
        let waterDays = JourneyLogMetrics.waterGoalDays(in: weekLogs)
        let calorieDays = JourneyLogMetrics.calorieAdherenceDays(in: weekLogs)

        let proteinEligible = weekLogs.filter { $0.targets.proteinTarget > 0 }
        let waterEligible = weekLogs.filter { $0.targets.waterTargetMl > 0 }
        let calorieEligible = weekLogs.filter { $0.targets.calorieTarget > 0 }

        let trainingDays = context.weeklyTraining.workoutDays ?? 0
        let expectedTraining = JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: context.profile)

        let weightDelta = JourneyLogMetrics.weightDelta(in: context.weekWeights)

        let deficits: [Int] = weekLogs.compactMap { log in
            let target = log.targets.calorieTarget
            guard target > 0 else { return nil }
            return target - log.totals.calories
        }
        let avgDeficit = deficits.isEmpty
            ? nil
            : Int((Double(deficits.reduce(0, +)) / Double(deficits.count)).rounded())

        let signals = weeklyHabitSignals(
            foodDays: foodDays,
            proteinDays: proteinDays,
            waterDays: waterDays,
            calorieDays: calorieDays,
            trainingDays: trainingDays,
            expectedTraining: expectedTraining,
            previousWeekLogs: previousWeekLogs
        )

        let weekSummaryCopy = JourneyWeeklyReviewBuilder.weekSummaryCopy(
            foodDays: foodDays,
            proteinDays: proteinDays,
            trainingDays: trainingDays,
            goalDirection: context.baseline.goalDirection,
            weightDelta: weightDelta
        )

        let previousWeek = JourneyWeeklyReviewBuilder.previousWeekMetrics(
            logs: previousWeekLogs,
            weekWeights: context.previousWeekWeights,
            trainingDays: context.previousWeekTrainingDays
        )

        var review = JourneyWeeklyReviewState(
            foodLoggedDays: foodDays,
            foodLoggedDaysTotal: total,
            proteinGoalDays: proteinDays,
            proteinGoalDaysTotal: max(proteinEligible.count, total),
            waterGoalDays: waterDays,
            waterGoalDaysTotal: max(waterEligible.count, total),
            trainingDays: trainingDays,
            expectedTrainingDays: expectedTraining,
            training: context.weeklyTraining,
            weightDeltaThisWeekKg: weightDelta,
            calorieAdherenceDays: calorieDays,
            calorieAdherenceDaysTotal: max(calorieEligible.count, total),
            strongestPositiveSignal: signals.strongest,
            weakestSignal: signals.weakest,
            weekSummaryCopy: weekSummaryCopy,
            averageCalorieDeficit: avgDeficit,
            rows: [],
            weekOverWeekDetail: nil
        )

        return JourneyWeeklyReviewBuilder.enrich(
            review: review,
            previousWeek: previousWeek.hasComparableData ? previousWeek : nil,
            goalDirection: context.baseline.goalDirection,
            streaks: context.journeyStreaks
        )
    }

    // MARK: - Milestones

    static func milestones(context: Context) -> JourneyMilestonesState {
        JourneyMilestonesBuilder.build(
            JourneyMilestonesBuilder.Input(
                baseline: context.baseline,
                maturityLogs: context.maturityLogs,
                journeyStreaks: context.journeyStreaks,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Story timeline

    static func storyTimeline(context: Context) -> JourneyStoryTimelineState {
        JourneyTimelineBuilder.build(
            JourneyTimelineBuilder.Input(
                profile: context.profile,
                baseline: context.baseline,
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                journeyStreaks: context.journeyStreaks,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Habit insights

    static func habitInsights(context: Context) -> JourneyHabitInsightsState {
        let expectedTraining = JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: context.profile)
        return JourneyHabitInsightsBuilder.build(
            JourneyHabitInsightsBuilder.Input(
                profile: context.profile,
                maturityLogs: context.maturityLogs,
                weekLogs: context.weekLogs,
                weekWeights: context.weekWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                expectedTrainingDaysPerWeek: expectedTraining,
                hasRealWeightEntries: context.baseline.hasRealWeightEntries,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Progress attribution

    static func progressAttribution(context: Context) -> JourneyProgressAttributionState {
        let weeklyTrainingDays = context.weeklyTraining.workoutDays ?? 0
        return JourneyProgressAttributionBuilder.build(
            JourneyProgressAttributionBuilder.Input(
                currentPeriodLogs: context.maturityLogs,
                previousPeriodLogs: context.previousWeekLogs,
                weekLogs: context.weekLogs,
                previousWeekLogs: context.previousWeekLogs,
                weightSummary: context.weightSummary,
                goalDirection: context.baseline.goalDirection,
                weeklyTrainingDays: weeklyTrainingDays,
                previousWeekTrainingDays: context.previousWeekTrainingDays,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Before vs today

    static func beforeToday(context: Context) -> JourneyBeforeTodayState {
        JourneyBeforeTodayBuilder.build(
            JourneyBeforeTodayBuilder.Input(
                profile: context.profile,
                baseline: context.baseline,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Personal records

    static func personalRecords(context: Context) -> JourneyPersonalRecordsState {
        JourneyPersonalRecordsBuilder.build(
            JourneyPersonalRecordsBuilder.Input(
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                goalDirection: context.baseline.goalDirection,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Monthly recap

    static func monthlyRecap(context: Context) -> JourneyMonthlyRecapState {
        let expectedTraining = JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: context.profile)
        return JourneyMonthlyRecapBuilder.build(
            JourneyMonthlyRecapBuilder.Input(
                monthLogs: context.monthLogs,
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                monthHealthWorkoutCount: context.monthHealthWorkoutCount,
                goalDirection: context.baseline.goalDirection,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                expectedTrainingDaysPerWeek: expectedTraining,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Journey level

    static func journeyLevel(context: Context) -> JourneyLevelState {
        let logs = context.maturityLogs
        let foodDays = JourneyLogMetrics.foodLoggedDays(in: logs)
        let proteinDays = JourneyLogMetrics.proteinGoalDays(in: logs)
        let waterDays = JourneyLogMetrics.waterGoalDays(in: logs)
        let workoutDays = context.healthWorkoutDayStarts.count
        let unlockedMilestones = milestones(context: context).unlocked.count

        var xp = 0
        xp += foodDays * 10
        xp += proteinDays * 8
        xp += waterDays * 5
        xp += workoutDays * 15
        xp += unlockedMilestones * 40
        xp += min(context.streakSummary.loggingStreak, 30) * 3

        let levelThresholds = [0, 100, 250, 500, 900, 1_400, 2_000]
        let currentLevel = levelThresholds.lastIndex(where: { xp >= $0 }) ?? 0
        let levelNumber = currentLevel + 1
        let currentThreshold = levelThresholds[currentLevel]
        let nextThreshold = currentLevel + 1 < levelThresholds.count
            ? levelThresholds[currentLevel + 1]
            : currentThreshold + 500
        let span = max(nextThreshold - currentThreshold, 1)
        let progress = Double(xp - currentThreshold) / Double(span)

        let title = levelTitle(for: levelNumber)
        let explanation = "XP comes from logged meals, protein and water targets, workouts, milestones, and streaks."

        return JourneyLevelState(
            currentLevel: levelNumber,
            levelTitle: title,
            currentXP: xp,
            xpRequiredForNextLevel: nextThreshold,
            progressPercent: min(max(progress * 100, 0), 100),
            xpEarnedExplanation: explanation
        )
    }

    // MARK: - Detailed analytics

    static func detailedAnalytics(
        context: Context,
        weightInterpretation: String
    ) -> JourneyDetailedAnalyticsState {
        let rangeStart = context.calendar.date(
            byAdding: .day,
            value: -context.selectedRangeDays + 1,
            to: context.asOf
        ) ?? context.asOf

        let chartPoints = JourneyBaselineResolver.chartPointsInRange(
            context.baseline.chartPoints,
            from: rangeStart,
            to: context.asOf,
            calendar: context.calendar
        )

        return JourneyDetailedAnalyticsState(
            isCollapsedByDefault: true,
            nutritionSummary: context.nutritionSummary,
            waterSummary: context.waterSummary,
            workoutSummary: context.workoutSummary,
            weightChartPoints: chartPoints,
            weightTrendInterpretation: weightInterpretation,
            showsWeightChart: context.baseline.showsWeightChart && !chartPoints.isEmpty
        )
    }

    // MARK: - Consistency calendar

    static func consistencyCalendar(
        logs: [DailyLog],
        healthWorkoutDayStarts: Set<Date>,
        weights: [WeightEntry],
        month: Date,
        calendar: Calendar
    ) -> JourneyConsistencyCalendar {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month) else {
            return JourneyConsistencyCalendar(
                monthTitle: month.formatted(.dateTime.month(.wide).year()),
                weekdaySymbols: calendar.shortWeekdaySymbols,
                days: [],
                completedCount: 0,
                totalLoggedDays: 0
            )
        }

        let completedDays = JourneyLogMetrics.completedDaySet(
            logs: logs,
            healthWorkoutDayStarts: healthWorkoutDayStarts,
            weights: weights,
            calendar: calendar
        )
        let totalLoggedDays = completedDays.count

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
            completedCount: monthCompleted,
            totalLoggedDays: totalLoggedDays
        )
    }

    // MARK: - Private helpers

    private static func weeklyHabitSignals(
        foodDays: Int,
        proteinDays: Int,
        waterDays: Int,
        calorieDays: Int,
        trainingDays: Int,
        expectedTraining: Int,
        previousWeekLogs: [DailyLog]
    ) -> (strongest: String, weakest: String) {
        let prevProtein = JourneyLogMetrics.proteinGoalDays(in: previousWeekLogs)
        let scores: [(String, Int)] = [
            ("Food logging", foodDays),
            ("Protein", proteinDays),
            ("Water", waterDays),
            ("Calorie balance", calorieDays),
            ("Training", trainingDays)
        ]
        let strongest = scores.max(by: { $0.1 < $1.1 })?.0 ?? "Showing up"
        let weakest = scores.min(by: { $0.1 < $1.1 })?.0 ?? "Consistency"

        if proteinDays > prevProtein {
            return ("Protein improved vs last week", weakest == "Protein" ? "Water" : weakest)
        }
        return (strongest, weakest)
    }

    private static func movedTowardGoal(
        start: Double,
        current: Double,
        direction: JourneyGoalDirection
    ) -> Bool {
        weightDeltaMovedTowardGoal(current - start, direction: direction)
    }

    private static func weightDeltaMovedTowardGoal(
        _ delta: Double,
        direction: JourneyGoalDirection
    ) -> Bool {
        switch direction {
        case .lose:
            return delta < -0.05
        case .gain:
            return delta > 0.05
        case .maintain:
            return abs(delta) < 0.5
        }
    }

    private static func levelTitle(for level: Int) -> String {
        switch level {
        case 1: return "Getting started"
        case 2: return "Building rhythm"
        case 3: return "Finding momentum"
        case 4: return "Consistent athlete"
        case 5: return "Dedicated journeyman"
        default: return "Seasoned storyteller"
        }
    }

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
            return FormaProductCopy.Journey.weightTrendEmpty
        }
    }
}
