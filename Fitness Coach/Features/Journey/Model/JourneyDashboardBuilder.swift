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
        var monthLogs: [DailyLog]
        var rangeLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var weekWeights: [WeightEntry]
        var rangeWeights: [WeightEntry]
        var streakSummary: StreakSummary
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
                loggingStreak: context.streakSummary.loggingStreak,
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
        let expectedTraining = max(context.profile?.trainingFrequencyPerWeek ?? 0, 0)

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

        let weekSummaryCopy = weekSummary(
            foodDays: foodDays,
            proteinDays: proteinDays,
            trainingDays: trainingDays,
            weightDelta: weightDelta,
            goalDirection: context.baseline.goalDirection
        )

        return JourneyWeeklyReviewState(
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
            averageCalorieDeficit: avgDeficit
        )
    }

    // MARK: - Milestones

    static func milestones(context: Context) -> JourneyMilestonesState {
        let items = milestoneItems(context: context)
        guard !items.isEmpty else { return .empty }

        let unlocked = items.filter { $0.status == .completed }
        let upcoming = items.filter { $0.status == .upcoming || $0.status == .current }
        let next = ProgressFormatter.nextMilestone(from: items)

        let completedCount = unlocked.count
        let progressPercent = items.isEmpty
            ? 0
            : (Double(completedCount) / Double(items.count)) * 100

        return JourneyMilestonesState(
            unlocked: unlocked,
            upcoming: upcoming,
            next: next,
            progressPercent: progressPercent,
            items: items
        )
    }

    // MARK: - Story timeline

    static func storyTimeline(context: Context) -> JourneyStoryTimelineState {
        var events: [JourneyTimelineEvent] = []
        let calendar = context.calendar
        let baseline = context.baseline

        if let profile = context.profile {
            events.append(JourneyTimelineEvent(
                id: "onboarding",
                date: profile.createdAt,
                kind: .onboardingStarted,
                title: "Your journey began",
                subtitle: "You set your goal and plan in Forma."
            ))
        }

        if let firstMeal = JourneyLogMetrics.firstFoodLogDate(in: context.maturityLogs) {
            events.append(JourneyTimelineEvent(
                id: "first-meal",
                date: firstMeal,
                kind: .firstMealLogged,
                title: "First meal logged",
                subtitle: "You started building your nutrition picture."
            ))
        }

        if let firstWeight = context.allWeights.map(\.date).min() {
            events.append(JourneyTimelineEvent(
                id: "first-weight",
                date: firstWeight,
                kind: .firstWeightLogged,
                title: "First weight logged",
                subtitle: "Your trend line started taking shape."
            ))
        }

        let completedDays = JourneyLogMetrics.completedDaySet(
            logs: context.maturityLogs,
            healthWorkoutDayStarts: context.healthWorkoutDayStarts,
            weights: context.allWeights,
            calendar: calendar
        )
        if completedDays.count >= 7 {
            let sorted = completedDays.sorted()
            if let seventh = sorted.dropFirst(6).first {
                events.append(JourneyTimelineEvent(
                    id: "first-week",
                    date: seventh,
                    kind: .firstWeekComplete,
                    title: "First week of rhythm",
                    subtitle: "Seven days of showing up — that is real momentum."
                ))
            }
        }

        if let start = baseline.startWeightKg,
           let current = baseline.currentWeightKg,
           abs(current - start) >= 1.0,
           movedTowardGoal(start: start, current: current, direction: baseline.goalDirection) {
            let title: String
            switch baseline.goalDirection {
            case .lose:
                title = "First kilogram toward your goal"
            case .gain:
                title = "First kilogram gained toward your goal"
            case .maintain:
                title = "First kilogram of measurable change"
            }
            events.append(JourneyTimelineEvent(
                id: "first-kg",
                date: context.asOf,
                kind: .firstKgTowardGoal,
                title: title,
                subtitle: "Small shifts add up when you stay consistent."
            ))
        }

        let longest = JourneyLogMetrics.longestStreak(
            in: completedDays.sorted(),
            calendar: calendar
        )
        for threshold in [7, 14, 30] where longest >= threshold {
            events.append(JourneyTimelineEvent(
                id: "streak-\(threshold)",
                date: context.asOf,
                kind: .streakMilestone,
                title: "\(threshold)-day logging streak",
                subtitle: "Consistency is your superpower."
            ))
        }

        if let next = milestones(context: context).next {
            events.append(JourneyTimelineEvent(
                id: "milestone-\(next.id)",
                date: context.asOf,
                kind: .weightMilestone,
                title: "Next stop: \(next.title)",
                subtitle: ProgressFormatter.journeyKg(next.weightKg)
            ))
        }

        events.sort { $0.date < $1.date }
        return JourneyStoryTimelineState(events: events)
    }

    // MARK: - Habit insights

    static func habitInsights(context: Context) -> JourneyHabitInsightsState {
        let weekLogs = context.weekLogs
        let total = max(weekLogs.count, 1)

        let foodScore = JourneyLogMetrics.habitScore(
            achieved: JourneyLogMetrics.foodLoggedDays(in: weekLogs),
            total: JourneyLogMetrics.weekDayCount
        )
        let proteinScore = JourneyLogMetrics.habitScore(
            achieved: JourneyLogMetrics.proteinGoalDays(in: weekLogs),
            total: JourneyLogMetrics.weekDayCount
        )
        let waterScore = JourneyLogMetrics.habitScore(
            achieved: JourneyLogMetrics.waterGoalDays(in: weekLogs),
            total: JourneyLogMetrics.weekDayCount
        )
        let trainingDays = context.weeklyTraining.workoutDays ?? 0
        let expectedTraining = max(context.profile?.trainingFrequencyPerWeek ?? 1, 1)
        let trainingScore = JourneyLogMetrics.habitScore(
            achieved: trainingDays,
            total: expectedTraining
        )
        let weightScore = context.baseline.hasRealWeightEntries
            ? JourneyLogMetrics.habitScore(achieved: min(context.weekWeights.count, 2), total: 2)
            : 0

        let ranked: [(JourneyHabitKind, Double)] = [
            (.foodLogging, foodScore),
            (.protein, proteinScore),
            (.water, waterScore),
            (.training, trainingScore),
            (.weightLogging, weightScore)
        ].sorted { $0.1 > $1.1 }

        let strongest = ranked.first ?? (.foodLogging, 0)
        let weakest = ranked.last ?? (.foodLogging, 0)

        let suggestedNextAction = suggestedAction(
            weakest: weakest.0,
            context: context
        )

        let explanation = habitExplanation(
            strongest: strongest.0,
            strongestPercent: strongest.1,
            weakest: weakest.0,
            streak: context.streakSummary.loggingStreak
        )

        return JourneyHabitInsightsState(
            strongestHabit: strongest.0,
            strongestHabitPercentage: strongest.1 * 100,
            weakestHabit: weakest.0,
            weakestHabitPercentage: weakest.1 * 100,
            suggestedNextAction: suggestedNextAction,
            habitInsightExplanation: explanation,
            loggingStreakDays: context.streakSummary.loggingStreak
        )
    }

    // MARK: - Progress attribution

    static func progressAttribution(context: Context) -> JourneyProgressAttributionState {
        var reasons: [(priority: Int, text: String)] = []
        let maturityCount = context.maturityLogs.count
        let calorieDays = JourneyLogMetrics.calorieAdherenceDays(in: context.maturityLogs)

        if maturityCount > 0 {
            let withinCalories = calorieDays
            reasons.append((
                100,
                "You stayed within calories \(withinCalories) of the last \(maturityCount) logged days."
            ))
        }

        let thisWeekProtein = JourneyLogMetrics.proteinGoalDays(in: context.weekLogs)
        let lastWeekProtein = JourneyLogMetrics.proteinGoalDays(in: context.previousWeekLogs)
        if lastWeekProtein > 0 {
            let change = Double(thisWeekProtein - lastWeekProtein) / Double(lastWeekProtein) * 100
            if abs(change) >= 5 {
                let direction = change > 0 ? "increased" : "decreased"
                reasons.append((
                    90,
                    "You \(direction) protein consistency by \(Int(abs(change).rounded()))%."
                ))
            }
        }

        let foodDays = JourneyLogMetrics.foodLoggedDays(in: context.weekLogs)
        if foodDays > 0 {
            reasons.append((
                80,
                "You logged food \(foodDays) day\(foodDays == 1 ? "" : "s") this week."
            ))
        }

        if context.weightSummary.direction == .decreasing,
           context.baseline.goalDirection == .lose {
            reasons.append((
                70,
                "Your weight trend is moving toward your goal — trust the weekly pattern."
            ))
        } else if context.weightSummary.hasSuddenSpike {
            reasons.append((
                60,
                "A recent weight bump is often water — your longer logging pattern matters more."
            ))
        }

        if case .connected(let days, _, _) = context.weeklyTraining, days >= 3 {
            reasons.append((
                50,
                "Training showed up \(days) days this week — recovery and consistency compound."
            ))
        }

        reasons.sort { $0.priority > $1.priority }

        let primary = reasons.first?.text
            ?? "You're building the habit layer. Consistency matters more than daily noise."

        let supporting = Array(reasons.dropFirst().prefix(3).map(\.text))

        return JourneyProgressAttributionState(
            primaryReason: primary,
            supportingReasons: supporting
        )
    }

    // MARK: - Before vs today

    static func beforeToday(context: Context) -> JourneyBeforeTodayState {
        let profile = context.profile
        let baseline = context.baseline
        let daysOnJourney = max(
            context.calendar.dateComponents(
                [.day],
                from: context.calendar.startOfDay(for: baseline.startDate),
                to: context.calendar.startOfDay(for: context.asOf)
            ).day ?? 0,
            0
        )

        var startingMaintenance: Int?
        var currentMaintenance: Int?
        if let profile {
            let age = profile.resolvedAge(referenceDate: context.asOf)
            if let startKg = baseline.startWeightKg {
                let bmr = EnergyCalculator.bmrKcal(
                    weightKg: startKg,
                    heightCm: profile.heightCm,
                    ageYears: age,
                    sex: profile.sex
                )
                startingMaintenance = EnergyCalculator.tdeeKcal(
                    bmrKcal: bmr,
                    activityLevel: profile.activityLevel,
                    averageStepsPerDay: profile.averageSteps,
                    trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek
                )
            }
            if let currentKg = baseline.currentWeightKg {
                let bmr = EnergyCalculator.bmrKcal(
                    weightKg: currentKg,
                    heightCm: profile.heightCm,
                    ageYears: age,
                    sex: profile.sex
                )
                currentMaintenance = EnergyCalculator.tdeeKcal(
                    bmrKcal: bmr,
                    activityLevel: profile.activityLevel,
                    averageStepsPerDay: profile.averageSteps,
                    trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek
                )
            }
        }

        return JourneyBeforeTodayState(
            startedWeightKg: baseline.startWeightKg,
            currentWeightKg: baseline.currentWeightKg,
            startingMaintenanceCaloriesKcal: startingMaintenance,
            currentMaintenanceCaloriesKcal: currentMaintenance,
            startingTargetCaloriesKcal: profile?.targets.calorieTarget,
            currentTargetCaloriesKcal: profile?.targets.calorieTarget,
            goalWeightKg: baseline.goalWeightKg,
            daysOnJourney: daysOnJourney
        )
    }

    // MARK: - Personal records

    static func personalRecords(context: Context) -> JourneyPersonalRecordsState {
        let calendar = context.calendar
        let completedDays = JourneyLogMetrics.completedDaySet(
            logs: context.maturityLogs,
            healthWorkoutDayStarts: context.healthWorkoutDayStarts,
            weights: context.allWeights,
            calendar: calendar
        )
        let longestStreak = JourneyLogMetrics.longestStreak(
            in: completedDays.sorted(),
            calendar: calendar
        )

        let bestProteinWeek = JourneyLogMetrics.bestProteinDaysInRollingWeek(
            logs: context.maturityLogs,
            calendar: calendar
        )
        let bestWaterWeek = JourneyLogMetrics.bestWaterDaysInRollingWeek(
            logs: context.maturityLogs,
            calendar: calendar
        )

        let bestWeightChange = largestWeeklyWeightChangeTowardGoal(
            weights: context.allWeights,
            direction: context.baseline.goalDirection,
            calendar: calendar
        )

        let mostConsistentMonth = context.monthLogs.isEmpty
            ? 0
            : JourneyLogMetrics.foodLoggedDays(in: context.monthLogs)

        let bestTrainingWeek = bestTrainingWeekCount(
            workoutDayStarts: context.healthWorkoutDayStarts,
            calendar: calendar,
            asOf: context.asOf
        )

        let records: [JourneyPersonalRecord] = [
            JourneyPersonalRecord(
                id: "logging-streak",
                title: "Longest logging streak",
                value: longestStreak > 0 ? "\(longestStreak) days" : "—",
                isActive: longestStreak > 0
            ),
            JourneyPersonalRecord(
                id: "protein-week",
                title: "Best protein week",
                value: bestProteinWeek > 0 ? "\(bestProteinWeek) of 7 days" : "—",
                isActive: bestProteinWeek > 0
            ),
            JourneyPersonalRecord(
                id: "weight-week",
                title: weightRecordTitle(direction: context.baseline.goalDirection),
                value: bestWeightChange.map { String(format: "%.1f kg", abs($0)) } ?? "—",
                isActive: bestWeightChange != nil
            ),
            JourneyPersonalRecord(
                id: "consistent-month",
                title: "Most logged days (recent month)",
                value: mostConsistentMonth > 0 ? "\(mostConsistentMonth) days" : "—",
                isActive: mostConsistentMonth > 0
            ),
            JourneyPersonalRecord(
                id: "water-week",
                title: "Best water week",
                value: bestWaterWeek > 0 ? "\(bestWaterWeek) of 7 days" : "—",
                isActive: bestWaterWeek > 0
            ),
            JourneyPersonalRecord(
                id: "training-week",
                title: "Most training sessions in a week",
                value: bestTrainingWeek > 0 ? "\(bestTrainingWeek) sessions" : "—",
                isActive: bestTrainingWeek > 0
            )
        ]

        return JourneyPersonalRecordsState(records: records)
    }

    // MARK: - Monthly recap

    static func monthlyRecap(context: Context) -> JourneyMonthlyRecapState {
        let monthLogs = context.monthLogs
        let monthWeights = context.allWeights.filter {
            context.calendar.isDate($0.date, equalTo: context.asOf, toGranularity: .month)
        }
        let monthWeightDelta = JourneyLogMetrics.weightDelta(in: monthWeights)

        let proteinEligible = monthLogs.filter { $0.targets.proteinTarget > 0 }
        let waterEligible = monthLogs.filter { $0.targets.waterTargetMl > 0 }
        let calorieEligible = monthLogs.filter { $0.targets.calorieTarget > 0 }

        let proteinPercent = JourneyLogMetrics.adherencePercent(
            achieved: JourneyLogMetrics.proteinGoalDays(in: monthLogs),
            eligible: proteinEligible.count
        )
        let waterPercent = JourneyLogMetrics.adherencePercent(
            achieved: JourneyLogMetrics.waterGoalDays(in: monthLogs),
            eligible: waterEligible.count
        )
        let caloriePercent = JourneyLogMetrics.adherencePercent(
            achieved: JourneyLogMetrics.calorieAdherenceDays(in: monthLogs),
            eligible: calorieEligible.count
        )

        let loggedDays = JourneyLogMetrics.completedDaySet(
            logs: monthLogs,
            healthWorkoutDayStarts: context.healthWorkoutDayStarts,
            weights: monthWeights,
            calendar: context.calendar
        ).count

        let calendar = consistencyCalendar(
            logs: context.maturityLogs,
            healthWorkoutDayStarts: context.healthWorkoutDayStarts,
            weights: context.allWeights,
            month: context.asOf,
            calendar: context.calendar
        )

        let monthLabel = context.asOf.formatted(.dateTime.month(.wide).year())
        let summaryCopy = monthlySummaryCopy(
            loggedDays: loggedDays,
            proteinPercent: proteinPercent,
            weightDelta: monthWeightDelta,
            goalDirection: context.baseline.goalDirection
        )

        return JourneyMonthlyRecapState(
            monthLabel: monthLabel,
            monthWeightDeltaKg: monthWeightDelta,
            calorieAdherencePercent: caloriePercent,
            proteinAdherencePercent: proteinPercent,
            waterAdherencePercent: waterPercent,
            trainingSessions: context.monthHealthWorkoutCount,
            loggedDays: loggedDays,
            summaryCopy: summaryCopy,
            calendar: calendar
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

    private static func milestoneItems(context: Context) -> [JourneyMilestone] {
        guard let startWeight = context.baseline.startWeightKg,
              let goalWeight = context.baseline.goalWeightKg,
              abs(startWeight - goalWeight) > 0.1 else {
            return []
        }

        let descending = context.baseline.goalDirection == .lose
        let span = abs(startWeight - goalWeight)
        let stepCount = 4
        let weights: [Double] = (0...stepCount).map { index in
            let fraction = Double(index) / Double(stepCount)
            let value = descending
                ? startWeight - span * fraction
                : startWeight + span * fraction
            return (value * 10).rounded() / 10
        }

        let current = context.baseline.currentWeightKg ?? startWeight

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

            let title = milestoneTitle(
                index: index,
                total: weights.count,
                status: status,
                direction: context.baseline.goalDirection
            )

            return JourneyMilestone(
                id: "m-\(index)",
                title: title,
                weightKg: weight,
                status: status
            )
        }
    }

    private static func milestoneTitle(
        index: Int,
        total: Int,
        status: JourneyMilestoneStatus,
        direction: JourneyGoalDirection
    ) -> String {
        if index == 0 { return "Start" }
        if index == total - 1 { return "Goal" }
        if status == .current { return "You are here" }
        switch direction {
        case .lose:
            return "Checkpoint \(index)"
        case .gain:
            return "Gain checkpoint \(index)"
        case .maintain:
            return "Milestone \(index)"
        }
    }

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

    private static func weekSummary(
        foodDays: Int,
        proteinDays: Int,
        trainingDays: Int,
        weightDelta: Double?,
        goalDirection: JourneyGoalDirection
    ) -> String {
        if foodDays == 0 {
            return "Log a meal or weight to start this week's chapter."
        }
        var parts: [String] = []
        parts.append("You logged food \(foodDays) of 7 days")
        if proteinDays > 0 {
            parts.append("hit protein on \(proteinDays)")
        }
        if trainingDays > 0 {
            parts.append("\(trainingDays) training day\(trainingDays == 1 ? "" : "s")")
        }
        if let weightDelta, abs(weightDelta) >= 0.1, weightDeltaMovedTowardGoal(weightDelta, direction: goalDirection) {
            parts.append(String(format: "%.1f kg toward your goal this week", abs(weightDelta)))
        }
        return parts.joined(separator: ", ") + "."
    }

    private static func monthlySummaryCopy(
        loggedDays: Int,
        proteinPercent: Double?,
        weightDelta: Double?,
        goalDirection: JourneyGoalDirection
    ) -> String {
        if loggedDays == 0 {
            return "This month is open — your first log starts the recap."
        }
        var parts = ["You logged \(loggedDays) day\(loggedDays == 1 ? "" : "s") this month"]
        if let proteinPercent {
            parts.append("protein sat on target \(Int((proteinPercent * 100).rounded()))% of eligible days")
        }
        if let weightDelta, abs(weightDelta) >= 0.1 {
            parts.append(String(format: "weight shifted %.1f kg", weightDelta))
        }
        _ = goalDirection
        return parts.joined(separator: ", ") + "."
    }

    private static func suggestedAction(
        weakest: JourneyHabitKind,
        context: Context
    ) -> String {
        switch weakest {
        case .foodLogging:
            return "Log your next meal in Coach to keep the story moving."
        case .protein:
            return "Anchor your next meal with a protein-forward choice."
        case .water:
            return "Front-load water before your next meal."
        case .training:
            return context.weeklyTraining == .locked
                ? TrainingIntegrationCopy.includeWorkoutsInProgress
                : "A short workout or walk counts — consistency beats perfection."
        case .weightLogging:
            return "Log your weight to sharpen your trend."
        }
    }

    private static func habitExplanation(
        strongest: JourneyHabitKind,
        strongestPercent: Double,
        weakest: JourneyHabitKind,
        streak: Int
    ) -> String {
        let strongName = habitName(strongest)
        let weakName = habitName(weakest)
        let percent = Int((strongestPercent * 100).rounded())
        if streak > 0 {
            return "\(strongName) is your strongest habit (\(percent)% this week). Keep \(weakName) in view — you're on a \(streak)-day streak."
        }
        return "\(strongName) is leading this week (\(percent)%). A small win on \(weakName) would balance the chapter."
    }

    private static func habitName(_ habit: JourneyHabitKind) -> String {
        switch habit {
        case .foodLogging: return "Food logging"
        case .protein: return "Protein"
        case .water: return "Water"
        case .training: return "Training"
        case .weightLogging: return "Weight logging"
        }
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

    private static func weightRecordTitle(direction: JourneyGoalDirection) -> String {
        switch direction {
        case .lose:
            return "Largest weekly loss toward goal"
        case .gain:
            return "Largest weekly gain toward goal"
        case .maintain:
            return "Largest weekly weight change"
        }
    }

    private static func largestWeeklyWeightChangeTowardGoal(
        weights: [WeightEntry],
        direction: JourneyGoalDirection,
        calendar: Calendar
    ) -> Double? {
        guard weights.count >= 2 else { return nil }
        let sorted = weights.sorted { $0.date < $1.date }
        var best: Double?

        for index in 1..<sorted.count {
            let delta = sorted[index].weightKg - sorted[index - 1].weightKg
            let toward: Bool
            switch direction {
            case .lose:
                toward = delta < 0
            case .gain:
                toward = delta > 0
            case .maintain:
                toward = true
            }
            if toward {
                if best == nil || abs(delta) > abs(best!) {
                    best = delta
                }
            }
        }
        return best
    }

    private static func bestTrainingWeekCount(
        workoutDayStarts: Set<Date>,
        calendar: Calendar,
        asOf: Date
    ) -> Int {
        guard !workoutDayStarts.isEmpty else { return 0 }
        let sorted = workoutDayStarts.sorted()
        var best = 0
        var windowStart = 0
        for end in 0..<sorted.count {
            while let weeks = calendar.date(byAdding: .day, value: -7, to: sorted[end]),
                  sorted[windowStart] < weeks {
                windowStart += 1
            }
            best = max(best, end - windowStart + 1)
        }
        return best
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
