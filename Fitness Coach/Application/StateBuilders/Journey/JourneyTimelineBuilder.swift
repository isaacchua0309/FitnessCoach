//
//  JourneyTimelineBuilder.swift
//  Fitness Coach
//
//  Forma — Curated Journey story timeline from meaningful milestones only.
//

import Foundation

enum JourneyTimelineBuilder {

    struct Input: Equatable {
        var profile: UserProfile?
        var baseline: JourneyBaseline
        var maturityLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var healthWorkoutRecords: [HealthWorkoutRecord] = []
        var isAppleHealthConnected: Bool
        var unlockedMilestoneCount: Int
        var asOf: Date
        var calendar: Calendar
    }

    static func build(_ input: Input, additionalEvents: [JourneyTimelineEvent] = []) -> JourneyStoryTimelineState {
        let copy = FormaProductCopy.Journey.Timeline.self
        var events: [JourneyTimelineEvent] = []

        if let profile = input.profile {
            events.append(
                curatedEvent(
                    id: "onboarding",
                    date: input.calendar.startOfDay(for: profile.createdAt),
                    type: .onboardingStarted,
                    title: copy.startedForma,
                    icon: "✨",
                    isMajor: true,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if let firstMeal = JourneyLogMetrics.firstFoodLogDate(in: input.maturityLogs) {
            events.append(
                curatedEvent(
                    id: "first-meal",
                    date: input.calendar.startOfDay(for: firstMeal),
                    type: .firstMealLogged,
                    title: copy.loggedFirstMeal,
                    icon: "🍽",
                    isMajor: true,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if let firstFullDay = firstFullDayDate(input: input) {
            events.append(
                curatedEvent(
                    id: "first-full-day",
                    date: firstFullDay,
                    type: .firstFullDayComplete,
                    title: copy.completedFirstFullDay,
                    icon: "✅",
                    isMajor: true,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if let firstWorkout = firstWorkoutDate(input: input) {
            events.append(
                curatedEvent(
                    id: "first-workout",
                    date: firstWorkout,
                    type: .firstWorkoutLogged,
                    title: copy.completedFirstWorkout,
                    icon: "🏋",
                    isMajor: true,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if let firstWeight = input.allWeights
            .filter({ $0.weightKg > 0 })
            .map(\.date)
            .min() {
            events.append(
                curatedEvent(
                    id: "first-weight",
                    date: input.calendar.startOfDay(for: firstWeight),
                    type: .firstWeightLogged,
                    title: copy.loggedFirstWeight,
                    icon: "⚖️",
                    isMajor: true,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if let seventhFoodDay = nthUniqueFoodLogDay(7, in: input.maturityLogs, calendar: input.calendar) {
            let title = input.baseline.goalDirection == .maintain
                ? copy.stayedConsistentFirstWeek
                : copy.completedFirstWeek
            events.append(
                curatedEvent(
                    id: "first-week",
                    date: seventhFoodDay,
                    type: .firstWeekComplete,
                    title: title,
                    icon: "📅",
                    isMajor: true,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if let proteinWeekDate = firstWeekMeeting(
            goalDaysByWeek: goalDaysByWeek(in: input.maturityLogs, calendar: input.calendar, kind: .protein),
            threshold: 3
        ) {
            events.append(
                curatedEvent(
                    id: "protein-three-week",
                    date: proteinWeekDate,
                    type: .proteinThreeDaysInWeek,
                    title: copy.proteinThreeDaysInWeek,
                    icon: "🔥",
                    isMajor: false,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if let waterWeekDate = firstWeekMeeting(
            goalDaysByWeek: goalDaysByWeek(in: input.maturityLogs, calendar: input.calendar, kind: .water),
            threshold: 3
        ) {
            events.append(
                curatedEvent(
                    id: "water-three-week",
                    date: waterWeekDate,
                    type: .waterThreeDaysInWeek,
                    title: copy.waterThreeDaysInWeek,
                    icon: "💧",
                    isMajor: false,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if input.baseline.goalDirection == .lose || input.baseline.goalDirection == .gain,
           let startWeight = input.baseline.startWeightKg,
           let firstKgDate = firstKgTowardGoalDate(
               weights: input.allWeights,
               startWeight: startWeight,
               direction: input.baseline.goalDirection,
               calendar: input.calendar
           ) {
            let title = input.baseline.goalDirection == .lose
                ? copy.lostFirstKilogram()
                : copy.gainedFirstKilogram()
            events.append(
                curatedEvent(
                    id: "first-kg",
                    date: firstKgDate,
                    type: .firstKgTowardGoal,
                    title: title,
                    icon: "🎯",
                    isMajor: true,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if let chapterDate = firstChapterReachedDate(input: input) {
            events.append(
                curatedEvent(
                    id: "chapter-two",
                    date: chapterDate,
                    type: .chapterReached,
                    title: copy.reachedNewChapter,
                    icon: "📖",
                    isMajor: true,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        if let profile = input.profile,
           let monthDate = firstCompletedMonthDate(
               profileCreatedAt: profile.createdAt,
               logs: input.maturityLogs,
               asOf: input.asOf,
               calendar: input.calendar
           ) {
            events.append(
                curatedEvent(
                    id: "first-month",
                    date: monthDate,
                    type: .firstMonthComplete,
                    title: copy.completedFirstMonth,
                    icon: "📆",
                    isMajor: true,
                    goalDirection: input.baseline.goalDirection
                )
            )
        }

        let merged = deduplicateByID(
            events: mergeAdditionalEvents(events, additionalEvents: additionalEvents)
        )
        let sortedNewestFirst = merged.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            if typePriority(lhs.type) != typePriority(rhs.type) {
                return typePriority(lhs.type) > typePriority(rhs.type)
            }
            return lhs.id < rhs.id
        }

        let displayEvents = orderForDisplay(
            nonAnchor: sortedNewestFirst.filter { $0.type != .onboardingStarted },
            anchor: sortedNewestFirst.first { $0.type == .onboardingStarted }
        )
        let emptyStateMessage = shouldShowEmptyStateMessage(events: sortedNewestFirst)
            ? FormaProductCopy.Journey.Timeline.emptyBody
            : nil

        return JourneyStoryTimelineState(
            events: sortedNewestFirst,
            displayEvents: displayEvents,
            emptyStateMessage: emptyStateMessage
        )
    }

    // MARK: - Event factory

    private static func curatedEvent(
        id: String,
        date: Date,
        type: JourneyTimelineEventType,
        title: String,
        icon: String,
        isMajor: Bool,
        goalDirection: JourneyGoalDirection
    ) -> JourneyTimelineEvent {
        JourneyTimelineEvent(
            id: id,
            date: date,
            type: type,
            title: title,
            subtitle: reflection(for: type, goalDirection: goalDirection),
            icon: icon,
            isMajorEvent: isMajor
        )
    }

    private static func reflection(
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

    // MARK: - Display assembly

    private static func orderForDisplay(
        nonAnchor: [JourneyTimelineEvent],
        anchor: JourneyTimelineEvent?
    ) -> [JourneyTimelineEvent] {
        var ordered = nonAnchor.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if typePriority(lhs.type) != typePriority(rhs.type) {
                return typePriority(lhs.type) > typePriority(rhs.type)
            }
            return lhs.id < rhs.id
        }
        if let anchor {
            ordered.append(anchor)
        }
        return ordered
    }

    private static func shouldShowEmptyStateMessage(events: [JourneyTimelineEvent]) -> Bool {
        events.isEmpty
    }

    // MARK: - Deduplication

    private static func deduplicateByID(events: [JourneyTimelineEvent]) -> [JourneyTimelineEvent] {
        var bestByID: [String: JourneyTimelineEvent] = [:]

        for event in events {
            if let existing = bestByID[event.id] {
                let existingHasSubtitle = existing.subtitle?.isEmpty == false
                let eventHasSubtitle = event.subtitle?.isEmpty == false
                if eventHasSubtitle && !existingHasSubtitle {
                    bestByID[event.id] = event
                }
            } else {
                bestByID[event.id] = event
            }
        }

        return Array(bestByID.values)
    }

    private static func mergeAdditionalEvents(
        _ events: [JourneyTimelineEvent],
        additionalEvents: [JourneyTimelineEvent]
    ) -> [JourneyTimelineEvent] {
        guard !additionalEvents.isEmpty else { return events }

        var merged = events
        let existingIDs = Set(events.map(\.id))

        for event in additionalEvents where !existingIDs.contains(event.id) {
            merged.append(event)
        }

        return merged
    }

    private static func typePriority(_ type: JourneyTimelineEventType) -> Int {
        switch type {
        case .onboardingStarted: return 100
        case .firstMonthComplete: return 90
        case .chapterReached: return 88
        case .firstKgTowardGoal: return 85
        case .firstWeekComplete: return 80
        case .firstFullDayComplete: return 75
        case .proteinThreeDaysInWeek, .waterThreeDaysInWeek: return 70
        case .firstWorkoutLogged: return 65
        case .firstMealLogged: return 60
        case .firstWeightLogged: return 55
        case .fourWorkoutWeeksComplete: return 50
        case .weightLoggedThreeTimes: return 45
        case .firstWorkoutWeek, .firstWaterLogged, .calorieGoalFiveDays,
             .proteinGoalFiveDays, .thirtyMealsLogged, .halfwayToGoal,
             .longestStreakAchieved, .monthlyRecapCompleted: return 10
        }
    }

    // MARK: - Date resolution

    private enum WeekGoalKind {
        case protein
        case water
    }

    private static func firstFullDayDate(input: Input) -> Date? {
        let calendar = input.calendar
        let weights = input.allWeights.filter { $0.weightKg > 0 }
        let weightDays = JourneyLogMetrics.weightDays(
            in: input.maturityLogs,
            weights: weights,
            calendar: calendar
        )
        let workoutDays = JourneyLogMetrics.workoutDaySet(
            in: input.maturityLogs,
            healthWorkoutDayStarts: input.healthWorkoutDayStarts,
            calendar: calendar
        )

        let fullDays = input.maturityLogs.compactMap { log -> Date? in
            let day = calendar.startOfDay(for: log.date)
            guard log.totals.calories > 0, log.waterConsumedMl > 0 else { return nil }

            let proteinHit = JourneyLogMetrics.isProteinGoalMet(
                on: day,
                logsByDay: [day: log]
            )
            let waterHit = JourneyLogMetrics.isWaterGoalMet(
                on: day,
                logsByDay: [day: log]
            )
            let hasWorkout = log.workoutCaloriesBurned > 0 || workoutDays.contains(day)
            let hasWeight = weightDays.contains(day)

            return (proteinHit && waterHit) || (proteinHit && (hasWorkout || hasWeight))
                ? day
                : nil
        }

        return fullDays.sorted().first
    }

    private static func firstWorkoutDate(input: Input) -> Date? {
        let calendar = input.calendar
        let logged = input.maturityLogs
            .filter { $0.workoutCaloriesBurned > 0 }
            .map { calendar.startOfDay(for: $0.date) }
        let healthFromRecords = input.healthWorkoutRecords
            .map { calendar.startOfDay(for: $0.startDate) }
        let healthFromDayStarts = input.healthWorkoutDayStarts
            .map { calendar.startOfDay(for: $0) }
        let health = healthFromRecords.isEmpty ? healthFromDayStarts : healthFromRecords
        return (logged + health).sorted().first
    }

    private static func nthUniqueFoodLogDay(
        _ n: Int,
        in logs: [DailyLog],
        calendar: Calendar
    ) -> Date? {
        let days = Set(
            logs.filter { $0.totals.calories > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        ).sorted()
        guard n > 0, n <= days.count else { return nil }
        return days[n - 1]
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
                hitsGoal = JourneyLogMetrics.isProteinGoalMet(on: day, logsByDay: [day: log])
            case .water:
                hitsGoal = JourneyLogMetrics.isWaterGoalMet(on: day, logsByDay: [day: log])
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

    private static func firstKgTowardGoalDate(
        weights: [WeightEntry],
        startWeight: Double,
        direction: JourneyGoalDirection,
        calendar: Calendar
    ) -> Date? {
        let sorted = weights.filter { $0.weightKg > 0 }.sorted { $0.date < $1.date }
        for entry in sorted {
            let traveled = traveledTowardGoal(
                from: startWeight,
                to: entry.weightKg,
                direction: direction
            )
            if traveled >= 1.0 {
                return calendar.startOfDay(for: entry.date)
            }
        }
        return nil
    }

    private static func traveledTowardGoal(
        from start: Double,
        to current: Double,
        direction: JourneyGoalDirection
    ) -> Double {
        switch direction {
        case .lose:
            return max(0, start - current)
        case .gain:
            return max(0, current - start)
        case .maintain:
            return abs(current - start)
        }
    }

    private static func firstChapterReachedDate(input: Input) -> Date? {
        let sortedDays = Set(
            input.maturityLogs.map { input.calendar.startOfDay(for: $0.date) }
        ).sorted()
        guard !sortedDays.isEmpty else { return nil }

        var previousLevel = 1
        for day in sortedDays {
            let logsThroughDay = input.maturityLogs.filter {
                input.calendar.startOfDay(for: $0.date) <= day
            }
            let xp = JourneyChapterBuilder.computeTotalXP(
                input: JourneyChapterBuilder.Input(
                    maturityLogs: logsThroughDay,
                    allWeights: input.allWeights.filter {
                        input.calendar.startOfDay(for: $0.date) <= day
                    },
                    healthWorkoutDayStarts: input.healthWorkoutDayStarts.filter { $0 <= day },
                    isAppleHealthConnected: input.isAppleHealthConnected,
                    unlockedMilestoneCount: 0,
                    calendar: input.calendar
                )
            )
            let chapter = JourneyChapterBuilder.chapterProgress(totalXP: xp).chapter
            if chapter > 1, previousLevel == 1 {
                return day
            }
            previousLevel = max(previousLevel, chapter)
        }

        return nil
    }

    private static func firstCompletedMonthDate(
        profileCreatedAt: Date,
        logs: [DailyLog],
        asOf: Date,
        calendar: Calendar
    ) -> Date? {
        guard let startMonth = calendar.dateInterval(of: .month, for: profileCreatedAt) else {
            return nil
        }

        var monthCursor = startMonth.start
        while monthCursor < asOf {
            guard let monthInterval = calendar.dateInterval(of: .month, for: monthCursor) else { break }
            let monthEnded = monthInterval.end <= asOf
            if monthEnded {
                let foodDays = Set(
                    logs.filter {
                        $0.totals.calories > 0
                            && $0.date >= monthInterval.start
                            && $0.date < monthInterval.end
                    }.map { calendar.startOfDay(for: $0.date) }
                ).count
                if foodDays >= 7,
                   let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) {
                    return calendar.startOfDay(for: lastDay)
                }
            }
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else { break }
            monthCursor = nextMonth
        }

        return nil
    }
}
