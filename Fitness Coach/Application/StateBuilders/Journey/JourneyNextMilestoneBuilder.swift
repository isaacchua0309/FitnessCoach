//
//  JourneyNextMilestoneBuilder.swift
//  Fitness Coach
//
//  Forma — Single next-achievement milestone card with real progress.
//

import Foundation

enum JourneyNextMilestoneBuilder {

    enum MilestoneID: String, Equatable, Sendable, CaseIterable {
        case firstMeal = "first-meal"
        case firstFullDay = "first-full-day"
        case firstWorkout = "first-workout"
        case weightThreeTimes = "weight-three-times"
        case firstWeek = "first-week"
        case proteinThreeInWeek = "protein-three-week"
        case waterThreeInWeek = "water-three-week"
        case firstKg = "first-kg"
        case fourWorkoutWeeks = "four-workout-weeks"
        case firstMonth = "first-month"
    }

    struct Input: Equatable {
        var profile: UserProfile?
        var baseline: JourneyBaseline
        var maturityLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var asOf: Date
        var calendar: Calendar
    }

    struct MilestoneProgress: Equatable {
        var id: MilestoneID
        var title: String
        var icon: String
        var progressText: String
        var progressFraction: Double
        var rewardCopy: String
        var isComplete: Bool
        var completionDate: Date?
        var timelineTitle: String
        var timelineType: JourneyTimelineEventType
        var isMajorTimelineEvent: Bool
    }

    struct BuildResult: Equatable {
        var presentation: JourneyMilestoneState
        var completedTimelineEvents: [JourneyTimelineEvent]
        var unlockedCount: Int
        var legacyMilestones: JourneyMilestonesState
    }

    static func build(_ input: Input) -> BuildResult {
        let metrics = makeMetrics(input: input)
        let milestones = evaluateMilestones(metrics: metrics, input: input)
        let completed = milestones.filter(\.isComplete)
        let next = milestones.first { !$0.isComplete }

        let presentation = makePresentation(
            next: next,
            completedCount: completed.count,
            legacyMilestones: legacyState(from: milestones)
        )
        let timelineEvents = completed.compactMap { milestone -> JourneyTimelineEvent? in
            guard let date = milestone.completionDate else { return nil }
            return JourneyTimelineEvent(
                id: milestone.id.rawValue,
                date: input.calendar.startOfDay(for: date),
                type: milestone.timelineType,
                title: milestone.timelineTitle,
                subtitle: timelineReflection(
                    for: milestone.timelineType,
                    goalDirection: input.baseline.goalDirection
                ),
                icon: milestone.icon,
                isMajorEvent: milestone.isMajorTimelineEvent
            )
        }

        return BuildResult(
            presentation: presentation,
            completedTimelineEvents: timelineEvents,
            unlockedCount: completed.count,
            legacyMilestones: legacyState(from: milestones)
        )
    }

    // MARK: - Presentation

    private static func makePresentation(
        next: MilestoneProgress?,
        completedCount: Int,
        legacyMilestones: JourneyMilestonesState
    ) -> JourneyMilestoneState {
        let copy = FormaProductCopy.Journey.Milestones.self
        let nextCopy = copy.NextAchievement.self

        guard let next else {
            return JourneyMilestoneState(
                isVisible: false,
                sectionTitle: copy.sectionTitle,
                header: nextCopy.header,
                icon: "",
                title: "",
                progressText: "",
                progressFraction: 0,
                rewardCopy: "",
                accessibilitySummary: "",
                unlockedCount: completedCount,
                completedMilestoneIDs: MilestoneID.allCases.map(\.rawValue),
                legacyMilestones: legacyMilestones
            )
        }

        let accessibilitySummary = nextCopy.accessibilitySummary(
            header: nextCopy.header,
            title: next.title,
            progress: next.progressText,
            reward: next.rewardCopy
        )

        return JourneyMilestoneState(
            isVisible: true,
            sectionTitle: copy.sectionTitle,
            header: nextCopy.header,
            icon: next.icon,
            title: next.title,
            progressText: next.progressText,
            progressFraction: next.progressFraction,
            rewardCopy: next.rewardCopy,
            accessibilitySummary: accessibilitySummary,
            unlockedCount: completedCount,
            completedMilestoneIDs: legacyMilestones.unlocked.map(\.id),
            legacyMilestones: legacyMilestones
        )
    }

    private static func legacyState(from milestones: [MilestoneProgress]) -> JourneyMilestonesState {
        let completed = milestones.filter(\.isComplete)
        let next = milestones.first { !$0.isComplete }

        let unlocked = completed.map { milestone in
            JourneyMilestone(
                id: milestone.id.rawValue,
                title: milestone.title,
                category: category(for: milestone.id),
                status: .completed,
                progressFraction: nil
            )
        }

        var items = unlocked
        if let next {
            let current = JourneyMilestone(
                id: next.id.rawValue,
                title: next.title,
                category: category(for: next.id),
                status: .current,
                progressFraction: next.progressFraction
            )
            items.append(current)
        }

        return JourneyMilestonesState(
            unlocked: unlocked,
            upcoming: [],
            next: items.first { $0.status == .current },
            nextProgressFraction: next?.progressFraction,
            items: items
        )
    }

    private static func category(for id: MilestoneID) -> JourneyMilestoneCategory {
        switch id {
        case .firstMeal, .firstFullDay, .firstWeek, .firstMonth:
            return .foodLogging
        case .firstWorkout, .fourWorkoutWeeks:
            return .trainingConsistency
        case .weightThreeTimes, .firstKg:
            return .weightProgress
        case .proteinThreeInWeek:
            return .proteinConsistency
        case .waterThreeInWeek:
            return .waterConsistency
        }
    }

    // MARK: - Evaluation

    private static func evaluateMilestones(
        metrics: Metrics,
        input: Input
    ) -> [MilestoneProgress] {
        let copy = FormaProductCopy.Journey.Milestones.NextAchievement.self
        let timelineCopy = FormaProductCopy.Journey.Timeline.self
        var milestones: [MilestoneProgress] = []

        milestones.append(
            MilestoneProgress(
                id: .firstMeal,
                title: copy.firstMealTitle,
                icon: "🍽",
                progressText: copy.progressCount(
                    current: min(metrics.foodLogDays, 1),
                    total: 1,
                    unit: metrics.foodLogDays == 1 ? "meal" : "meals"
                ),
                progressFraction: min(1, Double(metrics.foodLogDays)),
                rewardCopy: copy.firstMealReward,
                isComplete: metrics.foodLogDays >= 1,
                completionDate: metrics.firstMealDate,
                timelineTitle: timelineCopy.loggedFirstMeal,
                timelineType: .firstMealLogged,
                isMajorTimelineEvent: true
            )
        )

        milestones.append(
            MilestoneProgress(
                id: .firstFullDay,
                title: copy.firstFullDayTitle,
                icon: "✅",
                progressText: copy.progressCount(
                    current: metrics.fullDays >= 1 ? 1 : 0,
                    total: 1,
                    unit: "day"
                ),
                progressFraction: metrics.fullDays >= 1 ? 1 : 0,
                rewardCopy: copy.firstFullDayReward,
                isComplete: metrics.fullDays >= 1,
                completionDate: metrics.firstFullDayDate,
                timelineTitle: copy.firstFullDayTitle,
                timelineType: .firstFullDayComplete,
                isMajorTimelineEvent: true
            )
        )

        milestones.append(
            MilestoneProgress(
                id: .firstWorkout,
                title: copy.firstWorkoutTitle,
                icon: "🏋",
                progressText: copy.progressCount(
                    current: min(metrics.trainingWorkoutDays, 1),
                    total: 1,
                    unit: "workout"
                ),
                progressFraction: min(1, Double(metrics.trainingWorkoutDays)),
                rewardCopy: copy.firstWorkoutReward,
                isComplete: metrics.trainingWorkoutDays >= 1,
                completionDate: metrics.firstWorkoutDate,
                timelineTitle: copy.firstWorkoutTitle,
                timelineType: .firstWorkoutLogged,
                isMajorTimelineEvent: true
            )
        )

        milestones.append(
            MilestoneProgress(
                id: .weightThreeTimes,
                title: copy.weightThreeTimesTitle,
                icon: "⚖️",
                progressText: copy.progressCount(
                    current: min(metrics.weightLogCount, 3),
                    total: 3,
                    unit: "logs"
                ),
                progressFraction: min(1, Double(metrics.weightLogCount) / 3),
                rewardCopy: copy.weightThreeTimesReward,
                isComplete: metrics.weightLogCount >= 3,
                completionDate: metrics.thirdWeightDate,
                timelineTitle: copy.weightThreeTimesTitle,
                timelineType: .weightLoggedThreeTimes,
                isMajorTimelineEvent: false
            )
        )

        milestones.append(
            MilestoneProgress(
                id: .firstWeek,
                title: copy.firstWeekTitle,
                icon: "📅",
                progressText: copy.progressDays(
                    current: min(metrics.foodLogDays, 7),
                    total: 7
                ),
                progressFraction: min(1, Double(metrics.foodLogDays) / 7),
                rewardCopy: copy.firstWeekReward,
                isComplete: metrics.foodLogDays >= 7,
                completionDate: metrics.seventhFoodDayDate,
                timelineTitle: input.baseline.goalDirection == .maintain
                    ? timelineCopy.stayedConsistentFirstWeek
                    : timelineCopy.completedFirstWeek,
                timelineType: .firstWeekComplete,
                isMajorTimelineEvent: true
            )
        )

        milestones.append(
            MilestoneProgress(
                id: .proteinThreeInWeek,
                title: copy.proteinThreeDaysTitle,
                icon: "🔥",
                progressText: copy.progressDays(
                    current: min(metrics.bestProteinDaysInWeek, 3),
                    total: 3
                ),
                progressFraction: min(1, Double(metrics.bestProteinDaysInWeek) / 3),
                rewardCopy: copy.proteinThreeDaysReward,
                isComplete: metrics.bestProteinDaysInWeek >= 3,
                completionDate: metrics.proteinThreeInWeekDate,
                timelineTitle: copy.proteinThreeDaysTitle,
                timelineType: .proteinThreeDaysInWeek,
                isMajorTimelineEvent: false
            )
        )

        milestones.append(
            MilestoneProgress(
                id: .waterThreeInWeek,
                title: copy.waterThreeDaysTitle,
                icon: "💧",
                progressText: copy.progressDays(
                    current: min(metrics.bestWaterDaysInWeek, 3),
                    total: 3
                ),
                progressFraction: min(1, Double(metrics.bestWaterDaysInWeek) / 3),
                rewardCopy: copy.waterThreeDaysReward,
                isComplete: metrics.bestWaterDaysInWeek >= 3,
                completionDate: metrics.waterThreeInWeekDate,
                timelineTitle: copy.waterThreeDaysTitle,
                timelineType: .waterThreeDaysInWeek,
                isMajorTimelineEvent: false
            )
        )

        if metrics.goalDirection == .lose || metrics.goalDirection == .gain {
            let kgTitle = metrics.goalDirection == .lose
                ? copy.firstKgTitle
                : copy.firstKgGainTitle
            milestones.append(
                MilestoneProgress(
                    id: .firstKg,
                    title: kgTitle,
                    icon: "🎯",
                    progressText: copy.progressKg(
                        current: min(metrics.weightChangeTowardGoalKg, 1),
                        total: 1
                    ),
                    progressFraction: min(1, metrics.weightChangeTowardGoalKg),
                    rewardCopy: copy.firstKgReward,
                    isComplete: metrics.weightChangeTowardGoalKg >= 1,
                    completionDate: metrics.firstKgDate,
                    timelineTitle: metrics.goalDirection == .lose
                        ? timelineCopy.lostFirstKilogram()
                        : timelineCopy.gainedFirstKilogram(),
                    timelineType: .firstKgTowardGoal,
                    isMajorTimelineEvent: true
                )
            )
        }

        milestones.append(
            MilestoneProgress(
                id: .fourWorkoutWeeks,
                title: copy.fourWorkoutWeeksTitle,
                icon: "🏆",
                progressText: copy.progressCount(
                    current: min(metrics.workoutWeeks, 4),
                    total: 4,
                    unit: "weeks"
                ),
                progressFraction: min(1, Double(metrics.workoutWeeks) / 4),
                rewardCopy: copy.fourWorkoutWeeksReward,
                isComplete: metrics.workoutWeeks >= 4,
                completionDate: metrics.fourthWorkoutWeekEndDate,
                timelineTitle: copy.fourWorkoutWeeksTitle,
                timelineType: .fourWorkoutWeeksComplete,
                isMajorTimelineEvent: true
            )
        )

        milestones.append(
            MilestoneProgress(
                id: .firstMonth,
                title: copy.firstMonthTitle,
                icon: "📆",
                progressText: copy.progressDays(
                    current: min(metrics.bestMonthFoodDays, 7),
                    total: 7
                ),
                progressFraction: min(1, Double(metrics.bestMonthFoodDays) / 7),
                rewardCopy: copy.firstMonthReward,
                isComplete: metrics.firstCompletedMonthDate != nil,
                completionDate: metrics.firstCompletedMonthDate,
                timelineTitle: copy.firstMonthTitle,
                timelineType: .firstMonthComplete,
                isMajorTimelineEvent: true
            )
        )

        return milestones
    }

    // MARK: - Metrics

    private struct Metrics: Equatable {
        var foodLogDays: Int
        var fullDays: Int
        var trainingWorkoutDays: Int
        var weightLogCount: Int
        var bestProteinDaysInWeek: Int
        var bestWaterDaysInWeek: Int
        var weightChangeTowardGoalKg: Double
        var workoutWeeks: Int
        var bestMonthFoodDays: Int
        var goalDirection: JourneyGoalDirection

        var firstMealDate: Date?
        var firstFullDayDate: Date?
        var firstWorkoutDate: Date?
        var thirdWeightDate: Date?
        var seventhFoodDayDate: Date?
        var proteinThreeInWeekDate: Date?
        var waterThreeInWeekDate: Date?
        var firstKgDate: Date?
        var fourthWorkoutWeekEndDate: Date?
        var firstCompletedMonthDate: Date?
    }

    private static func makeMetrics(input: Input) -> Metrics {
        let calendar = input.calendar
        let logs = input.maturityLogs
        let baseline = input.baseline
        let weights = input.allWeights.filter { $0.weightKg > 0 }.sorted { $0.date < $1.date }

        let foodDays = uniqueFoodLogDays(in: logs, calendar: calendar)
        let fullDayDates = fullDayDates(in: logs, weights: weights, input: input)
        let workoutDays = uniqueTrainingWorkoutDays(
            in: logs,
            healthWorkoutDayStarts: input.healthWorkoutDayStarts,
            calendar: calendar
        )
        let proteinWeeks = goalDaysByWeek(in: logs, calendar: calendar, kind: .protein)
        let waterWeeks = goalDaysByWeek(in: logs, calendar: calendar, kind: .water)
        let workoutWeekEnds = workoutWeekEndDates(
            logs: logs,
            healthWorkoutDayStarts: input.healthWorkoutDayStarts,
            calendar: calendar
        )
        let monthCompletion = firstCompletedMonth(
            profile: input.profile,
            logs: logs,
            asOf: input.asOf,
            calendar: calendar
        )

        let start = baseline.startWeightKg ?? 0
        let current = baseline.currentWeightKg ?? start
        let traveled: Double
        switch baseline.goalDirection {
        case .lose:
            traveled = max(0, start - current)
        case .gain:
            traveled = max(0, current - start)
        case .maintain:
            traveled = abs(current - start)
        }

        return Metrics(
            foodLogDays: foodDays.count,
            fullDays: fullDayDates.count,
            trainingWorkoutDays: workoutDays.count,
            weightLogCount: weights.count,
            bestProteinDaysInWeek: proteinWeeks.values.max() ?? 0,
            bestWaterDaysInWeek: waterWeeks.values.max() ?? 0,
            weightChangeTowardGoalKg: traveled,
            workoutWeeks: workoutWeekEnds.count,
            bestMonthFoodDays: monthCompletion.bestFoodDays,
            goalDirection: baseline.goalDirection,
            firstMealDate: foodDays.first,
            firstFullDayDate: fullDayDates.first,
            firstWorkoutDate: workoutDays.first,
            thirdWeightDate: weights.count >= 3 ? weights[2].date : nil,
            seventhFoodDayDate: foodDays.count >= 7 ? foodDays[6] : nil,
            proteinThreeInWeekDate: firstWeekMeeting(goalDaysByWeek: proteinWeeks, threshold: 3),
            waterThreeInWeekDate: firstWeekMeeting(goalDaysByWeek: waterWeeks, threshold: 3),
            firstKgDate: firstKgDate(
                weights: weights,
                startWeight: baseline.startWeightKg,
                direction: baseline.goalDirection,
                calendar: calendar
            ),
            fourthWorkoutWeekEndDate: workoutWeekEnds.count >= 4 ? workoutWeekEnds[3] : nil,
            firstCompletedMonthDate: monthCompletion.completionDate
        )
    }

    // MARK: - Metric helpers

    private enum WeekGoalKind {
        case protein
        case water
    }

    private static func uniqueFoodLogDays(in logs: [DailyLog], calendar: Calendar) -> [Date] {
        Array(
            Set(
                logs.filter { $0.totals.calories > 0 }
                    .map { calendar.startOfDay(for: $0.date) }
            )
        ).sorted()
    }

    private static func fullDayDates(
        in logs: [DailyLog],
        weights: [WeightEntry],
        input: Input
    ) -> [Date] {
        let calendar = input.calendar
        let weightDays = Set(weights.map { calendar.startOfDay(for: $0.date) })
        let workoutDays = uniqueTrainingWorkoutDays(
            in: logs,
            healthWorkoutDayStarts: input.healthWorkoutDayStarts,
            calendar: calendar
        )

        let fullDays = logs.compactMap { log -> Date? in
            let day = calendar.startOfDay(for: log.date)
            guard log.totals.calories > 0, log.waterConsumedMl > 0 else { return nil }

            let proteinHit = log.targets.proteinTarget > 0
                && log.totals.protein >= log.targets.proteinTarget * JourneyLogMetrics.proteinHitThreshold
            let waterHit = log.targets.waterTargetMl > 0
                && Double(log.waterConsumedMl) >= Double(log.targets.waterTargetMl) * JourneyLogMetrics.waterHitThreshold
            let hasWorkout = log.workoutCaloriesBurned > 0 || workoutDays.contains(day)
            let hasWeight = weightDays.contains(day)

            return (proteinHit && waterHit) || (proteinHit && (hasWorkout || hasWeight))
                ? day
                : nil
        }

        return Array(Set(fullDays)).sorted()
    }

    private static func uniqueTrainingWorkoutDays(
        in logs: [DailyLog],
        healthWorkoutDayStarts: Set<Date>,
        calendar: Calendar
    ) -> [Date] {
        let logged = Set(
            logs.filter { $0.workoutCaloriesBurned > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )
        return Array(logged.union(healthWorkoutDayStarts)).sorted()
    }

    private static func goalDaysByWeek(
        in logs: [DailyLog],
        calendar: Calendar,
        kind: WeekGoalKind
    ) -> [Date: Int] {
        var daysByWeek: [Date: Set<Date>] = [:]

        for log in logs {
            let day = calendar.startOfDay(for: log.date)
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start else {
                continue
            }
            let weekKey = calendar.startOfDay(for: weekStart)

            let hitsGoal: Bool
            switch kind {
            case .protein:
                hitsGoal = log.targets.proteinTarget > 0
                    && log.totals.protein >= log.targets.proteinTarget * JourneyLogMetrics.proteinHitThreshold
            case .water:
                hitsGoal = log.targets.waterTargetMl > 0
                    && Double(log.waterConsumedMl) >= Double(log.targets.waterTargetMl) * JourneyLogMetrics.waterHitThreshold
            }

            guard hitsGoal else { continue }
            daysByWeek[weekKey, default: []].insert(day)
        }

        return daysByWeek.mapValues(\.count)
    }

    private static func firstWeekMeeting(goalDaysByWeek: [Date: Int], threshold: Int) -> Date? {
        goalDaysByWeek
            .filter { $0.value >= threshold }
            .keys
            .sorted()
            .first
    }

    private static func workoutWeekEndDates(
        logs: [DailyLog],
        healthWorkoutDayStarts: Set<Date>,
        calendar: Calendar
    ) -> [Date] {
        let workoutDays = uniqueTrainingWorkoutDays(
            in: logs,
            healthWorkoutDayStarts: healthWorkoutDayStarts,
            calendar: calendar
        )

        var weekEnds: [Date] = []
        var seenWeeks = Set<Date>()

        for day in workoutDays {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: day) else { continue }
            let weekStart = calendar.startOfDay(for: interval.start)
            guard !seenWeeks.contains(weekStart) else { continue }
            seenWeeks.insert(weekStart)
            let weekEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? day
            weekEnds.append(calendar.startOfDay(for: weekEnd))
        }

        return weekEnds.sorted()
    }

    private static func firstKgDate(
        weights: [WeightEntry],
        startWeight: Double?,
        direction: JourneyGoalDirection,
        calendar: Calendar
    ) -> Date? {
        guard let startWeight else { return nil }
        for entry in weights {
            let traveled: Double
            switch direction {
            case .lose:
                traveled = max(0, startWeight - entry.weightKg)
            case .gain:
                traveled = max(0, entry.weightKg - startWeight)
            case .maintain:
                traveled = abs(entry.weightKg - startWeight)
            }
            if traveled >= 1 {
                return calendar.startOfDay(for: entry.date)
            }
        }
        return nil
    }

    private static func firstCompletedMonth(
        profile: UserProfile?,
        logs: [DailyLog],
        asOf: Date,
        calendar: Calendar
    ) -> (completionDate: Date?, bestFoodDays: Int) {
        let start = profile.map { calendar.startOfDay(for: $0.createdAt) }
            ?? calendar.startOfDay(for: asOf)
        var monthCursor = start
        var bestFoodDays = 0

        while monthCursor < asOf {
            guard let monthInterval = calendar.dateInterval(of: .month, for: monthCursor) else { break }
            let foodDays = Set(
                logs.filter {
                    $0.totals.calories > 0
                        && $0.date >= monthInterval.start
                        && $0.date < monthInterval.end
                }.map { calendar.startOfDay(for: $0.date) }
            ).count
            bestFoodDays = max(bestFoodDays, foodDays)

            if foodDays >= 7,
               monthInterval.end <= asOf,
               let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) {
                return (calendar.startOfDay(for: lastDay), bestFoodDays)
            }

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else { break }
            monthCursor = nextMonth
        }

        guard let currentMonth = calendar.dateInterval(of: .month, for: asOf) else {
            return (nil, bestFoodDays)
        }
        let currentFoodDays = Set(
            logs.filter {
                $0.totals.calories > 0
                    && $0.date >= currentMonth.start
                    && $0.date <= asOf
            }.map { calendar.startOfDay(for: $0.date) }
        ).count
        bestFoodDays = max(bestFoodDays, currentFoodDays)

        return (nil, bestFoodDays)
    }

    private static func timelineReflection(
        for type: JourneyTimelineEventType,
        goalDirection: JourneyGoalDirection
    ) -> String? {
        if type == .firstKgTowardGoal {
            switch goalDirection {
            case .lose:
                return FormaProductCopy.Journey.Timeline.Reflection.lostFirstKg
            case .gain:
                return FormaProductCopy.Journey.Timeline.Reflection.gainedFirstKg
            case .maintain:
                return FormaProductCopy.Journey.Timeline.Reflection.completedFirstWeek
            }
        }
        return FormaProductCopy.Journey.Timeline.reflection(for: type)
    }
}
