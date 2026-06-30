//
//  JourneyTimelineBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic chronological Journey story events.
//

import Foundation

enum JourneyTimelineBuilder {

    struct Input: Equatable {
        var profile: UserProfile?
        var baseline: JourneyBaseline
        var maturityLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var isAppleHealthConnected: Bool
        var journeyStreaks: JourneyStreakState
        var asOf: Date
        var calendar: Calendar
    }

    private static let displayEventLimit = 5

    static func build(_ input: Input) -> JourneyStoryTimelineState {
        let copy = FormaProductCopy.Journey.Timeline.self
        var events: [JourneyTimelineEvent] = []

        if let profile = input.profile {
            events.append(
                makeEvent(
                    id: "onboarding",
                    date: input.calendar.startOfDay(for: profile.createdAt),
                    type: .onboardingStarted,
                    title: copy.startedForma,
                    icon: "✨",
                    isMajor: true
                )
            )
        }

        if let firstMeal = JourneyLogMetrics.firstFoodLogDate(in: input.maturityLogs) {
            events.append(
                makeEvent(
                    id: "first-meal",
                    date: input.calendar.startOfDay(for: firstMeal),
                    type: .firstMealLogged,
                    title: copy.loggedFirstMeal,
                    icon: "🍽",
                    isMajor: true
                )
            )
        }

        if let firstWater = firstWaterLogDate(in: input.maturityLogs, calendar: input.calendar) {
            events.append(
                makeEvent(
                    id: "first-water",
                    date: firstWater,
                    type: .firstWaterLogged,
                    title: copy.loggedFirstWater,
                    icon: "💧",
                    isMajor: false
                )
            )
        }

        if let firstWeight = input.allWeights
            .filter({ $0.weightKg > 0 })
            .map(\.date)
            .min() {
            events.append(
                makeEvent(
                    id: "first-weight",
                    date: input.calendar.startOfDay(for: firstWeight),
                    type: .firstWeightLogged,
                    title: copy.loggedFirstWeight,
                    icon: "⚖️",
                    isMajor: false
                )
            )
        }

        if input.isAppleHealthConnected,
           let weekEnd = firstWorkoutWeekEndDate(
               workoutDates: input.healthWorkoutDayStarts,
               calendar: input.calendar
           ) {
            events.append(
                makeEvent(
                    id: "first-workout-week",
                    date: weekEnd,
                    type: .firstWorkoutWeek,
                    title: copy.completedFirstWorkoutWeek,
                    icon: "🏋",
                    isMajor: false
                )
            )
        }

        if let seventhFoodDay = nthUniqueFoodLogDay(
            7,
            in: input.maturityLogs,
            calendar: input.calendar
        ) {
            let title = input.baseline.goalDirection == .maintain
                ? copy.stayedConsistentFirstWeek
                : copy.completedFirstWeek
            events.append(
                makeEvent(
                    id: "first-week",
                    date: seventhFoodDay,
                    type: .firstWeekComplete,
                    title: title,
                    icon: "📅",
                    isMajor: true
                )
            )
        }

        if let startWeight = input.baseline.startWeightKg,
           let firstKgDate = firstKgTowardGoalDate(
               weights: input.allWeights,
               startWeight: startWeight,
               direction: input.baseline.goalDirection,
               calendar: input.calendar
           ) {
            let title: String
            switch input.baseline.goalDirection {
            case .lose:
                title = copy.lostFirstKilogram()
            case .gain:
                title = copy.gainedFirstKilogram()
            case .maintain:
                title = copy.stayedConsistentFirstWeek
            }
            events.append(
                makeEvent(
                    id: "first-kg",
                    date: firstKgDate,
                    type: .firstKgTowardGoal,
                    title: title,
                    icon: "🎯",
                    isMajor: true
                )
            )
        }

        if let fifthCalorieDay = nthCalorieAdherenceDay(
            5,
            in: input.maturityLogs,
            calendar: input.calendar
        ) {
            events.append(
                makeEvent(
                    id: "calorie-five",
                    date: fifthCalorieDay,
                    type: .calorieGoalFiveDays,
                    title: copy.hitCalorieGoalDays(5),
                    icon: "🎯",
                    isMajor: false
                )
            )
        }

        if let fifthProteinDay = nthProteinGoalDay(
            5,
            in: input.maturityLogs,
            calendar: input.calendar
        ) {
            events.append(
                makeEvent(
                    id: "protein-five",
                    date: fifthProteinDay,
                    type: .proteinGoalFiveDays,
                    title: copy.hitProteinGoalDays(5),
                    icon: "🔥",
                    isMajor: false
                )
            )
        }

        if let thirtiethMealDay = nthUniqueFoodLogDay(
            30,
            in: input.maturityLogs,
            calendar: input.calendar
        ) {
            events.append(
                makeEvent(
                    id: "thirty-meals",
                    date: thirtiethMealDay,
                    type: .thirtyMealsLogged,
                    title: copy.loggedThirtyMeals,
                    icon: "📝",
                    isMajor: false
                )
            )
        }

        if input.baseline.goalDirection != .maintain,
           let startWeight = input.baseline.startWeightKg,
           let goalWeight = input.baseline.goalWeightKg,
           abs(startWeight - goalWeight) > 0.1,
           let halfwayDate = halfwayToGoalDate(
               weights: input.allWeights,
               startWeight: startWeight,
               goalWeight: goalWeight,
               direction: input.baseline.goalDirection,
               calendar: input.calendar
           ) {
            events.append(
                makeEvent(
                    id: "halfway",
                    date: halfwayDate,
                    type: .halfwayToGoal,
                    title: copy.reachedHalfway,
                    icon: "🏁",
                    isMajor: true
                )
            )
        }

        if let streak = longestLoggingStreakEnd(
            logs: input.maturityLogs,
            calendar: input.calendar
        ), streak.length >= 7 {
            events.append(
                makeEvent(
                    id: "longest-streak-\(streak.length)",
                    date: streak.endDate,
                    type: .longestStreakAchieved,
                    title: copy.longestLoggingStreak(days: streak.length),
                    icon: "🔥",
                    isMajor: true
                )
            )
        }

        if let profile = input.profile,
           let recapDate = firstMonthlyRecapDate(
               profileCreatedAt: profile.createdAt,
               logs: input.maturityLogs,
               asOf: input.asOf,
               calendar: input.calendar
           ) {
            events.append(
                makeEvent(
                    id: "monthly-recap",
                    date: recapDate,
                    type: .monthlyRecapCompleted,
                    title: copy.monthlyRecapCompleted,
                    icon: "📊",
                    isMajor: false
                )
            )
        }

        let deduped = deduplicateByDay(events: events, calendar: input.calendar)
        let sortedNewestFirst = deduped.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            if typePriority(lhs.type) != typePriority(rhs.type) {
                return typePriority(lhs.type) > typePriority(rhs.type)
            }
            return lhs.id < rhs.id
        }

        let displayEvents = buildDisplayEvents(from: sortedNewestFirst)
        let emptyStateMessage = shouldShowEmptyStateMessage(events: sortedNewestFirst)
            ? FormaProductCopy.Journey.Timeline.emptyBody
            : nil

        return JourneyStoryTimelineState(
            events: sortedNewestFirst,
            displayEvents: displayEvents,
            emptyStateMessage: emptyStateMessage
        )
    }

    // MARK: - Display assembly

    private static func buildDisplayEvents(from events: [JourneyTimelineEvent]) -> [JourneyTimelineEvent] {
        guard !events.isEmpty else { return [] }

        let anchor = events.first { $0.type == .onboardingStarted }
        let nonAnchor = events.filter { $0.type != .onboardingStarted }

        if events.count <= displayEventLimit {
            return orderForDisplay(nonAnchor: nonAnchor, anchor: anchor)
        }

        let ranked = nonAnchor.sorted { lhs, rhs in
            let leftScore = selectionScore(for: lhs)
            let rightScore = selectionScore(for: rhs)
            if leftScore != rightScore { return leftScore > rightScore }
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id < rhs.id
        }

        var selected = Array(ranked.prefix(displayEventLimit - (anchor == nil ? 0 : 1)))
        if let anchor {
            selected.append(anchor)
        }
        return orderForDisplay(
            nonAnchor: selected.filter { $0.type != .onboardingStarted },
            anchor: anchor
        )
    }

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
        let nonOnboarding = events.filter { $0.type != .onboardingStarted }
        return nonOnboarding.isEmpty
    }

    private static func selectionScore(for event: JourneyTimelineEvent) -> Int {
        typePriority(event.type) + (event.isMajorEvent ? 10 : 0)
    }

    // MARK: - Event factory

    private static func makeEvent(
        id: String,
        date: Date,
        type: JourneyTimelineEventType,
        title: String,
        icon: String,
        isMajor: Bool
    ) -> JourneyTimelineEvent {
        JourneyTimelineEvent(
            id: id,
            date: date,
            type: type,
            title: title,
            subtitle: nil,
            icon: icon,
            isMajorEvent: isMajor
        )
    }

    // MARK: - Deduplication

    private static func deduplicateByDay(
        events: [JourneyTimelineEvent],
        calendar: Calendar
    ) -> [JourneyTimelineEvent] {
        var bestByDay: [Date: JourneyTimelineEvent] = [:]

        for event in events {
            let day = calendar.startOfDay(for: event.date)
            if let existing = bestByDay[day] {
                if typePriority(event.type) > typePriority(existing.type) {
                    bestByDay[day] = event
                } else if typePriority(event.type) == typePriority(existing.type),
                          event.id < existing.id {
                    bestByDay[day] = event
                }
            } else {
                bestByDay[day] = event
            }
        }

        return bestByDay.values.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.id < rhs.id
        }
    }

    private static func typePriority(_ type: JourneyTimelineEventType) -> Int {
        switch type {
        case .onboardingStarted: return 100
        case .halfwayToGoal: return 90
        case .firstKgTowardGoal: return 85
        case .longestStreakAchieved: return 80
        case .firstWeekComplete: return 75
        case .thirtyMealsLogged: return 70
        case .monthlyRecapCompleted: return 65
        case .proteinGoalFiveDays, .calorieGoalFiveDays: return 60
        case .firstWorkoutWeek: return 55
        case .firstMealLogged: return 50
        case .firstWeightLogged: return 45
        case .firstWaterLogged: return 40
        }
    }

    // MARK: - Date resolution

    private static func firstWaterLogDate(in logs: [DailyLog], calendar: Calendar) -> Date? {
        guard let date = logs.filter({ $0.waterConsumedMl > 0 }).map(\.date).min() else {
            return nil
        }
        return calendar.startOfDay(for: date)
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

    private static func nthProteinGoalDay(
        _ n: Int,
        in logs: [DailyLog],
        calendar: Calendar
    ) -> Date? {
        let days = Set(
            logs.filter { log in
                log.targets.proteinTarget > 0
                    && log.totals.protein >= log.targets.proteinTarget * JourneyLogMetrics.proteinHitThreshold
            }.map { calendar.startOfDay(for: $0.date) }
        ).sorted()
        guard n > 0, n <= days.count else { return nil }
        return days[n - 1]
    }

    private static func nthCalorieAdherenceDay(
        _ n: Int,
        in logs: [DailyLog],
        calendar: Calendar
    ) -> Date? {
        let days = Set(
            logs.filter { log in
                let target = log.targets.calorieTarget
                guard target > 0 else { return false }
                let delta = abs(Double(log.totals.calories - target)) / Double(target)
                return delta <= JourneyLogMetrics.calorieAdherenceTolerance
            }.map { calendar.startOfDay(for: $0.date) }
        ).sorted()
        guard n > 0, n <= days.count else { return nil }
        return days[n - 1]
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

    private static func halfwayToGoalDate(
        weights: [WeightEntry],
        startWeight: Double,
        goalWeight: Double,
        direction: JourneyGoalDirection,
        calendar: Calendar
    ) -> Date? {
        let span = abs(startWeight - goalWeight)
        guard span > 0.1 else { return nil }

        let sorted = weights.filter { $0.weightKg > 0 }.sorted { $0.date < $1.date }
        for entry in sorted {
            let traveled = traveledTowardGoal(
                from: startWeight,
                to: entry.weightKg,
                direction: direction
            )
            if traveled / span >= 0.5 {
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

    private static func firstWorkoutWeekEndDate(
        workoutDates: Set<Date>,
        calendar: Calendar
    ) -> Date? {
        guard let firstWorkout = workoutDates.min() else { return nil }
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: firstWorkout) else {
            return nil
        }
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) else {
            return calendar.startOfDay(for: firstWorkout)
        }
        return calendar.startOfDay(for: lastDay)
    }

    private static func longestLoggingStreakEnd(
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

    private static func firstMonthlyRecapDate(
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
