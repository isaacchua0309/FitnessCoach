//
//  WeeklyProgressSummary.swift
//  Fitness Coach
//
//  Forma — Canonical weekly progress summary for Journey, Plan, Today, and analytics.
//

import Foundation

// MARK: - Verdict & actions

enum WeeklyProgressVerdict: String, Codable, Equatable {
    case notEnoughData
    case onTrack
    case likelyTooAggressive
    case likelyTooSlow
    case noisyButLikelyOkay
    case needsConsistencyFirst
    case maintaining
    case unclear
}

enum WeeklyProgressNextAction: String, Codable, Equatable {
    case keepLogging
    case holdSteady
    case reviewPlan
    case improveLoggingConsistency
    case logWeightMoreOften
    case focusProtein
    case focusWater
    case reviewDailySummary
}

// MARK: - Week window

enum WeeklyProgressWeekWindowKind: String, Codable, Equatable {
    /// Most recent fully completed calendar week (preferred for v1 ritual).
    case completedCalendarWeek
    /// Rolling seven-day window ending on the reference date.
    case rollingSevenDays
}

struct WeeklyProgressWeekRange: Equatable {
    let kind: WeeklyProgressWeekWindowKind
    let startDate: Date
    let endDate: Date
    let totalDays: Int
}

// MARK: - Summary

struct WeeklyProgressSummary: Equatable {
    let id: String
    let startDate: Date
    let endDate: Date
    let generatedAt: Date

    let confidence: WeeklyProgressConfidenceLevel
    let verdict: WeeklyProgressVerdict
    let nextAction: WeeklyProgressNextAction

    let maintenanceEstimate: MaintenanceEstimate

    let foodLoggedDays: Int
    let totalDays: Int
    let averageDailyCalories: Int?
    let averageDailyProteinGrams: Int?
    let proteinHitDays: Int
    let calorieTargetHitDays: Int
    let waterTargetHitDays: Int
    let trainingDays: Int?

    let startingWeightKg: Double?
    let endingWeightKg: Double?
    let weightChangeKg: Double?
    let weeklyWeightChangeKg: Double?
    let hasSuddenSpike: Bool

    let headline: String
    let summary: String
    let primaryInsight: String
    let nextActionTitle: String
    let nextActionSubtitle: String
    let caveats: [String]
}

// MARK: - Input

struct WeeklyProgressSummaryInput: Equatable {
    let referenceDate: Date
    let calendar: Calendar
    let dailyLogs: [DailyLog]
    let weightEntries: [WeightEntry]
    let healthWorkoutDayStarts: Set<Date>
    let staticTDEEKcal: Double?
    let calorieTargetKcal: Double?
    let goalWeightKg: Double?
    let currentWeightKg: Double?
    let generatedAt: Date
}

// MARK: - Builder

enum WeeklyProgressSummaryBuilder {

    private static let minimumFoodDaysForHabitNudge = 3
    private static let proteinHitRateNudgeThreshold = 0.50
    private static let waterHitRateNudgeThreshold = 0.50

    static func build(_ input: WeeklyProgressSummaryInput) -> WeeklyProgressSummary {
        let weekRange = resolveWeekRange(
            referenceDate: input.referenceDate,
            dailyLogs: input.dailyLogs,
            calendar: input.calendar
        )

        let windowLogs = logs(in: weekRange, from: input.dailyLogs, calendar: input.calendar)
        let windowWeights = weights(in: weekRange, from: input.weightEntries, calendar: input.calendar)
        let weightsThroughEnd = weights(
            endingOnOrBefore: weekRange.endDate,
            from: input.weightEntries,
            calendar: input.calendar
        )

        let foodLoggedDays = JourneyLogMetrics.uniqueFoodLoggedDays(
            in: windowLogs,
            calendar: input.calendar
        )
        let proteinHitDays = JourneyLogMetrics.uniqueProteinGoalDays(
            in: windowLogs,
            calendar: input.calendar
        )
        let calorieTargetHitDays = JourneyLogMetrics.uniqueCalorieAdherenceDays(
            in: windowLogs,
            calendar: input.calendar
        )
        let waterTargetHitDays = JourneyLogMetrics.uniqueWaterGoalDays(
            in: windowLogs,
            calendar: input.calendar
        )
        let trainingDays = JourneyLogMetrics.workoutDays(
            in: windowLogs,
            healthWorkoutDayStarts: input.healthWorkoutDayStarts,
            calendar: input.calendar
        )

        let averageDailyCalories = averageIntakeCalories(in: windowLogs)
        let averageDailyProteinGrams = averageProteinGrams(in: windowLogs)

        let sortedWindowWeights = windowWeights
            .filter { $0.weightKg > 0 }
            .sorted { $0.date < $1.date }
        let startingWeightKg = sortedWindowWeights.first?.weightKg
        let endingWeightKg = sortedWindowWeights.last?.weightKg

        let weightTrend = WeightTrendCalculator.trend(
            from: weightsThroughEnd,
            endingOn: weekRange.endDate
        )

        let maintenanceInput = MaintenanceEstimateInput(
            startDate: weekRange.startDate,
            endDate: weekRange.endDate,
            averageDailyCalories: averageDailyCalories,
            foodLoggedDays: foodLoggedDays,
            totalDays: weekRange.totalDays,
            startingWeightKg: startingWeightKg,
            endingWeightKg: endingWeightKg,
            currentSevenDayAverageKg: weightTrend.sevenDayAverageKg,
            previousSevenDayAverageKg: weightTrend.previousSevenDayAverageKg,
            weightEntryCount: sortedWindowWeights.count,
            staticTDEE: input.staticTDEEKcal,
            calorieTarget: input.calorieTargetKcal,
            goalWeightKg: input.goalWeightKg,
            currentWeightKg: input.currentWeightKg,
            hasSuddenSpike: weightTrend.hasSuddenSpike
        )

        let maintenanceEstimate = MaintenanceEstimateCalculator.estimate(maintenanceInput)
        let goalDirection = JourneyGoalDirection.resolve(
            startWeightKg: input.currentWeightKg,
            goalWeightKg: input.goalWeightKg
        )

        let verdict = resolveVerdict(
            maintenanceEstimate: maintenanceEstimate,
            goalDirection: goalDirection
        )
        let nextAction = resolveNextAction(
            verdict: verdict,
            maintenanceEstimate: maintenanceEstimate,
            foodLoggedDays: foodLoggedDays,
            totalDays: weekRange.totalDays,
            proteinHitDays: proteinHitDays,
            waterTargetHitDays: waterTargetHitDays,
            weightEntryCount: sortedWindowWeights.count
        )

        let copy = buildCopy(
            verdict: verdict,
            nextAction: nextAction,
            maintenanceEstimate: maintenanceEstimate,
            weekRange: weekRange
        )

        var caveats = maintenanceEstimate.caveats
        if weekRange.kind == .rollingSevenDays {
            caveats.append("This review uses your last seven days because a full calendar week is not complete yet.")
        }

        return WeeklyProgressSummary(
            id: summaryID(for: weekRange, calendar: input.calendar),
            startDate: weekRange.startDate,
            endDate: weekRange.endDate,
            generatedAt: input.generatedAt,
            confidence: maintenanceEstimate.confidence,
            verdict: verdict,
            nextAction: nextAction,
            maintenanceEstimate: maintenanceEstimate,
            foodLoggedDays: foodLoggedDays,
            totalDays: weekRange.totalDays,
            averageDailyCalories: maintenanceEstimate.averageDailyCalories,
            averageDailyProteinGrams: averageDailyProteinGrams.map { Int($0.rounded()) },
            proteinHitDays: proteinHitDays,
            calorieTargetHitDays: calorieTargetHitDays,
            waterTargetHitDays: waterTargetHitDays,
            trainingDays: trainingDays > 0 ? trainingDays : nil,
            startingWeightKg: startingWeightKg,
            endingWeightKg: endingWeightKg,
            weightChangeKg: maintenanceEstimate.weightChangeKg,
            weeklyWeightChangeKg: maintenanceEstimate.weeklyWeightChangeKg,
            hasSuddenSpike: weightTrend.hasSuddenSpike,
            headline: copy.headline,
            summary: copy.summary,
            primaryInsight: copy.primaryInsight,
            nextActionTitle: copy.nextActionTitle,
            nextActionSubtitle: copy.nextActionSubtitle,
            caveats: caveats
        )
    }

    // MARK: Week window

    static func resolveWeekRange(
        referenceDate: Date,
        dailyLogs: [DailyLog],
        calendar: Calendar
    ) -> WeeklyProgressWeekRange {
        if let completed = completedCalendarWeekRange(
            referenceDate: referenceDate,
            dailyLogs: dailyLogs,
            calendar: calendar
        ) {
            return completed
        }

        return rollingWeekRange(referenceDate: referenceDate, calendar: calendar)
    }

    private static func completedCalendarWeekRange(
        referenceDate: Date,
        dailyLogs: [DailyLog],
        calendar: Calendar
    ) -> WeeklyProgressWeekRange? {
        guard let weekStart = WeeklyReviewWeekPolicy.latestCompletedWeekStart(
            referenceDate: referenceDate,
            calendar: calendar
        ),
              let weekEnd = WeeklyReviewWeekPolicy.weekEndDate(
                forWeekStarting: weekStart,
                calendar: calendar
              ) else {
            return nil
        }

        let range = WeeklyProgressWeekRange(
            kind: .completedCalendarWeek,
            startDate: calendar.startOfDay(for: weekStart),
            endDate: calendar.startOfDay(for: weekEnd),
            totalDays: JourneyLogMetrics.weekDayCount
        )

        let windowLogs = logs(in: range, from: dailyLogs, calendar: calendar)
        let foodDays = JourneyLogMetrics.uniqueFoodLoggedDays(in: windowLogs, calendar: calendar)

        guard foodDays > 0 else {
            return nil
        }

        return range
    }

    private static func rollingWeekRange(
        referenceDate: Date,
        calendar: Calendar
    ) -> WeeklyProgressWeekRange {
        let dayStarts = JourneyLogMetrics.rollingWeekDayStarts(
            asOf: referenceDate,
            calendar: calendar
        )
        let startDate = dayStarts.first ?? calendar.startOfDay(for: referenceDate)
        let endDate = calendar.startOfDay(for: referenceDate)

        return WeeklyProgressWeekRange(
            kind: .rollingSevenDays,
            startDate: startDate,
            endDate: endDate,
            totalDays: JourneyLogMetrics.weekDayCount
        )
    }

    // MARK: Verdict & action

    private static func resolveVerdict(
        maintenanceEstimate: MaintenanceEstimate,
        goalDirection: JourneyGoalDirection
    ) -> WeeklyProgressVerdict {
        let sufficiency = maintenanceEstimate.sufficiency

        if sufficiency.confidence == .unavailable
            || !sufficiency.isEligibleForMaintenanceEstimate {
            return .notEnoughData
        }

        if sufficiency.reasons.contains(.inconsistentLogging) {
            return .needsConsistencyFirst
        }

        if maintenanceEstimate.shouldShowWaterWeightDisclaimer,
           sufficiency.isEligibleForPlanRecommendation {
            return .noisyButLikelyOkay
        }

        switch maintenanceEstimate.trendDirection {
        case .losingFasterThanExpected:
            return goalDirection == .lose ? .likelyTooAggressive : .unclear
        case .losingSlowerThanExpected:
            return goalDirection == .lose ? .likelyTooSlow : .unclear
        case .losingAboutAsExpected:
            return .onTrack
        case .maintaining:
            return goalDirection == .maintain ? .maintaining : .onTrack
        case .gaining:
            return goalDirection == .gain ? .onTrack : .likelyTooSlow
        case .unclear:
            return .unclear
        }
    }

    private static func resolveNextAction(
        verdict: WeeklyProgressVerdict,
        maintenanceEstimate: MaintenanceEstimate,
        foodLoggedDays: Int,
        totalDays: Int,
        proteinHitDays: Int,
        waterTargetHitDays: Int,
        weightEntryCount: Int
    ) -> WeeklyProgressNextAction {
        let sufficiency = maintenanceEstimate.sufficiency

        if sufficiency.confidence == .unavailable {
            if sufficiency.reasons.contains(.notEnoughWeightEntries) {
                return .logWeightMoreOften
            }
            return .keepLogging
        }

        switch verdict {
        case .notEnoughData:
            if sufficiency.reasons.contains(.notEnoughWeightEntries) {
                return .logWeightMoreOften
            }
            return .keepLogging
        case .needsConsistencyFirst:
            return .improveLoggingConsistency
        case .noisyButLikelyOkay:
            return .holdSteady
        case .onTrack, .maintaining:
            if let habitAction = habitNudgeAction(
                foodLoggedDays: foodLoggedDays,
                totalDays: totalDays,
                proteinHitDays: proteinHitDays,
                waterTargetHitDays: waterTargetHitDays
            ) {
                return habitAction
            }
            return .holdSteady
        case .likelyTooAggressive, .likelyTooSlow:
            return .reviewPlan
        case .unclear:
            if weightEntryCount < WeeklyProgressConfidencePolicy.minimumWeightEntries {
                return .logWeightMoreOften
            }
            return .keepLogging
        }
    }

    private static func habitNudgeAction(
        foodLoggedDays: Int,
        totalDays: Int,
        proteinHitDays: Int,
        waterTargetHitDays: Int
    ) -> WeeklyProgressNextAction? {
        guard foodLoggedDays >= minimumFoodDaysForHabitNudge, totalDays > 0 else {
            return nil
        }

        let proteinRate = Double(proteinHitDays) / Double(foodLoggedDays)
        let waterRate = Double(waterTargetHitDays) / Double(totalDays)

        if proteinRate < proteinHitRateNudgeThreshold {
            return .focusProtein
        }
        if waterRate < waterHitRateNudgeThreshold {
            return .focusWater
        }

        return nil
    }

    // MARK: Copy

    private struct SummaryCopy {
        let headline: String
        let summary: String
        let primaryInsight: String
        let nextActionTitle: String
        let nextActionSubtitle: String
    }

    private static func buildCopy(
        verdict: WeeklyProgressVerdict,
        nextAction: WeeklyProgressNextAction,
        maintenanceEstimate: MaintenanceEstimate,
        weekRange: WeeklyProgressWeekRange
    ) -> SummaryCopy {
        let headline = headline(for: verdict)
        let summary = summary(
            for: verdict,
            maintenanceEstimate: maintenanceEstimate,
            weekRange: weekRange
        )
        let primaryInsight = primaryInsight(
            for: verdict,
            maintenanceEstimate: maintenanceEstimate
        )
        let actionCopy = nextActionCopy(for: nextAction, verdict: verdict)

        return SummaryCopy(
            headline: headline,
            summary: summary,
            primaryInsight: primaryInsight,
            nextActionTitle: actionCopy.title,
            nextActionSubtitle: actionCopy.subtitle
        )
    }

    private static func headline(for verdict: WeeklyProgressVerdict) -> String {
        switch verdict {
        case .notEnoughData:
            return "Keep logging a few more days before we estimate maintenance."
        case .onTrack:
            return "You're on track this week."
        case .likelyTooAggressive:
            return "Your plan looks aggressive this week."
        case .likelyTooSlow:
            return "Progress looks slower than expected this week."
        case .noisyButLikelyOkay:
            return "The scale looks noisy, so hold steady before changing your target."
        case .needsConsistencyFirst:
            return "Your logging was inconsistent, so this review is about consistency first."
        case .maintaining:
            return "You're holding steady this week."
        case .unclear:
            return "Your week is still taking shape."
        }
    }

    private static func summary(
        for verdict: WeeklyProgressVerdict,
        maintenanceEstimate: MaintenanceEstimate,
        weekRange: WeeklyProgressWeekRange
    ) -> String {
        var parts: [String] = [maintenanceEstimate.sufficiency.userFacingSummary]

        if let maintenance = maintenanceEstimate.estimatedMaintenanceKcal {
            parts.append("Learned maintenance is about \(maintenance) kcal per day.")
        } else {
            parts.append(maintenanceEstimate.explanation)
        }

        switch weekRange.kind {
        case .completedCalendarWeek:
            parts.append("This review covers your most recent completed calendar week.")
        case .rollingSevenDays:
            parts.append("This review covers your last seven days.")
        }

        if verdict == .likelyTooAggressive {
            parts.append("Review your plan before lowering calories further.")
        }

        return parts.joined(separator: " ")
    }

    private static func primaryInsight(
        for verdict: WeeklyProgressVerdict,
        maintenanceEstimate: MaintenanceEstimate
    ) -> String {
        switch verdict {
        case .notEnoughData:
            return maintenanceEstimate.sufficiency.userFacingSummary
        case .onTrack:
            return "Weight trend and logging look aligned with your plan this week."
        case .likelyTooAggressive:
            return "Weight is moving faster than a typical weekly pace for your goal."
        case .likelyTooSlow:
            return "Weight trend is flat or slow relative to your goal, despite logging."
        case .noisyButLikelyOkay:
            return WeeklyProgressConfidencePolicy.holdSteadyDespiteNoiseCopy()
        case .needsConsistencyFirst:
            return "Steadier daily logging will make next week's review more useful."
        case .maintaining:
            return "Weight is staying within a small weekly band."
        case .unclear:
            return maintenanceEstimate.explanation
        }
    }

    private static func nextActionCopy(
        for action: WeeklyProgressNextAction,
        verdict: WeeklyProgressVerdict
    ) -> (title: String, subtitle: String) {
        switch action {
        case .keepLogging:
            return (
                "Keep logging",
                "A few more food and weight entries will unlock your weekly review."
            )
        case .holdSteady:
            return (
                "Hold steady",
                "No calorie change recommended yet — keep your current targets."
            )
        case .reviewPlan:
            let subtitle = verdict == .likelyTooAggressive
                ? "Review your plan before lowering calories further."
                : "Consider reviewing your calorie target in Plan."
            return ("Review your plan", subtitle)
        case .improveLoggingConsistency:
            return (
                "Build logging consistency",
                "Try to log most days next week for a clearer maintenance estimate."
            )
        case .logWeightMoreOften:
            return (
                "Log weight more often",
                "A few more weigh-ins will smooth out weekly noise."
            )
        case .focusProtein:
            return (
                "Prioritize protein",
                "Hitting protein more often will support your goal next week."
            )
        case .focusWater:
            return (
                "Focus on water",
                "More consistent hydration is the easiest win for next week."
            )
        case .reviewDailySummary:
            return (
                "Review your daily summaries",
                "Check how each day went before changing your plan."
            )
        }
    }

    // MARK: Data helpers

    private static func logs(
        in range: WeeklyProgressWeekRange,
        from logs: [DailyLog],
        calendar: Calendar
    ) -> [DailyLog] {
        logs.filter { log in
            let day = calendar.startOfDay(for: log.date)
            return day >= range.startDate && day <= range.endDate
        }
    }

    private static func weights(
        in range: WeeklyProgressWeekRange,
        from weights: [WeightEntry],
        calendar: Calendar
    ) -> [WeightEntry] {
        weights.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return day >= range.startDate && day <= range.endDate
        }
    }

    private static func weights(
        endingOnOrBefore endDate: Date,
        from weights: [WeightEntry],
        calendar: Calendar
    ) -> [WeightEntry] {
        let endDay = calendar.startOfDay(for: endDate)
        return weights.filter { calendar.startOfDay(for: $0.date) <= endDay }
    }

    private static func averageIntakeCalories(in logs: [DailyLog]) -> Double? {
        let foodLogs = logs.filter { $0.totals.calories > 0 }
        guard !foodLogs.isEmpty else { return nil }
        let total = foodLogs.reduce(0) { $0 + $1.totals.calories }
        return Double(total) / Double(foodLogs.count)
    }

    private static func averageProteinGrams(in logs: [DailyLog]) -> Double? {
        let foodLogs = logs.filter { $0.totals.calories > 0 }
        guard !foodLogs.isEmpty else { return nil }
        let total = foodLogs.reduce(0.0) { $0 + $1.totals.protein }
        return total / Double(foodLogs.count)
    }

    private static func summaryID(
        for range: WeeklyProgressWeekRange,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.string(from: range.startDate)
        return "weekly-progress-\(range.kind.rawValue)-\(start)"
    }
}
