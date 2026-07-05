//
//  WeeklyProgressSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Builds WeeklyProgressSummary from restored local logs and profile data.
//

import Foundation

// MARK: - Protocol

protocol WeeklyProgressSummaryBuilding {
    func buildSummary(
        asOf date: Date,
        profile: UserProfile?,
        dailyLogs: [DailyLog],
        weightEntries: [WeightEntry],
        trainingDayStarts: Set<Date>?
    ) -> WeeklyProgressSummary
}

// MARK: - Builder

struct WeeklyProgressSummaryBuilder: WeeklyProgressSummaryBuilding {

    let calendar: Calendar
    let now: () -> Date

    init(
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.calendar = calendar
        self.now = now
    }

    func buildSummary(
        asOf date: Date,
        profile: UserProfile?,
        dailyLogs: [DailyLog],
        weightEntries: [WeightEntry],
        trainingDayStarts: Set<Date>?
    ) -> WeeklyProgressSummary {
        let referenceDate = date
        let enrichedLogs = enrichedDailyLogs(dailyLogs, profile: profile)
        let mergedWeights = mergedWeightEntries(
            weightEntries: weightEntries,
            dailyLogs: enrichedLogs,
            calendar: calendar
        )
        let trainingDays = trainingDayStarts ?? []

        let input = WeeklyProgressSummaryInput(
            referenceDate: referenceDate,
            calendar: calendar,
            dailyLogs: enrichedLogs,
            weightEntries: mergedWeights,
            healthWorkoutDayStarts: trainingDays,
            staticTDEEKcal: staticTDEEKcal(from: profile, asOf: referenceDate),
            calorieTargetKcal: calorieTargetKcal(from: profile),
            goalWeightKg: profile?.goalWeightKg,
            currentWeightKg: resolvedCurrentWeightKg(
                profile: profile,
                weightEntries: mergedWeights,
                asOf: referenceDate
            ),
            generatedAt: now()
        )

        return assemble(input)
    }

    // MARK: Assembly

    private func assemble(_ input: WeeklyProgressSummaryInput) -> WeeklyProgressSummary {
        let weekRange = Self.resolveWeekRange(
            referenceDate: input.referenceDate,
            dailyLogs: input.dailyLogs,
            calendar: input.calendar
        )

        let windowLogs = Self.logs(in: weekRange, from: input.dailyLogs, calendar: input.calendar)
        let windowWeights = Self.weights(in: weekRange, from: input.weightEntries, calendar: input.calendar)
        let weightsThroughEnd = Self.weights(
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

        let averageDailyCalories = Self.averageIntakeCalories(in: windowLogs)
        let averageDailyProteinGrams = Self.averageProteinGrams(in: windowLogs)

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
            foodLoggedDays: Self.foodLoggedDaysForConfidence(
                in: input.dailyLogs,
                through: input.referenceDate,
                calendar: input.calendar
            ),
            totalDays: weekRange.totalDays,
            calendarSpanDays: Self.loggingHistorySpanDays(
                dailyLogs: input.dailyLogs,
                referenceDate: input.referenceDate,
                calendar: input.calendar
            ),
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

        let verdict = Self.resolveVerdict(
            maintenanceEstimate: maintenanceEstimate,
            goalDirection: goalDirection
        )
        let nextAction = Self.resolveNextAction(
            verdict: verdict,
            maintenanceEstimate: maintenanceEstimate,
            foodLoggedDays: foodLoggedDays,
            totalDays: weekRange.totalDays,
            proteinHitDays: proteinHitDays,
            waterTargetHitDays: waterTargetHitDays,
            weightEntryCount: sortedWindowWeights.count
        )

        let copy = Self.buildCopy(
            verdict: verdict,
            nextAction: nextAction,
            maintenanceEstimate: maintenanceEstimate,
            weekRange: weekRange
        )

        var caveats = maintenanceEstimate.caveats
        if weekRange.kind == .rollingSevenDays {
            caveats.append(
                "This review uses your last seven days because a full calendar week is not complete yet."
            )
        }

        return WeeklyProgressSummary(
            id: Self.summaryID(for: weekRange, calendar: input.calendar),
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

    // MARK: Profile & data preparation

    private func enrichedDailyLogs(
        _ logs: [DailyLog],
        profile: UserProfile?
    ) -> [DailyLog] {
        guard let profile else { return logs }

        let profileTargets = profile.targets
        return logs.map { log in
            var enriched = log
            var targets = log.targets

            if targets.calorieTarget <= 0, profileTargets.calorieTarget > 0 {
                targets.calorieTarget = profileTargets.calorieTarget
            }
            if targets.proteinTarget <= 0, profileTargets.proteinTarget > 0 {
                targets.proteinTarget = profileTargets.proteinTarget
            }
            if targets.carbTarget <= 0, profileTargets.carbTarget > 0 {
                targets.carbTarget = profileTargets.carbTarget
            }
            if targets.fatTarget <= 0, profileTargets.fatTarget > 0 {
                targets.fatTarget = profileTargets.fatTarget
            }
            if targets.waterTargetMl <= 0, profileTargets.waterTargetMl > 0 {
                targets.waterTargetMl = profileTargets.waterTargetMl
            }

            enriched.targets = targets
            return enriched
        }
    }

    private func mergedWeightEntries(
        weightEntries: [WeightEntry],
        dailyLogs: [DailyLog],
        calendar: Calendar
    ) -> [WeightEntry] {
        var byDay: [Date: WeightEntry] = Dictionary(
            uniqueKeysWithValues: weightEntries.map {
                (calendar.startOfDay(for: $0.date), $0)
            }
        )

        for log in dailyLogs {
            guard let weightKg = log.weightKg, weightKg > 0 else { continue }
            let day = calendar.startOfDay(for: log.date)
            guard byDay[day] == nil else { continue }

            byDay[day] = WeightEntry(
                id: UUID(),
                date: day,
                weightKg: weightKg,
                note: nil,
                createdAt: log.updatedAt
            )
        }

        return byDay.values.sorted { $0.date < $1.date }
    }

    private func staticTDEEKcal(from profile: UserProfile?, asOf date: Date) -> Double? {
        guard let profile else { return nil }
        guard let result = try? PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: date
        ) else {
            return nil
        }
        return Double(result.tdeeKcal)
    }

    private func calorieTargetKcal(from profile: UserProfile?) -> Double? {
        guard let target = profile?.targets.calorieTarget, target > 0 else {
            return nil
        }
        return Double(target)
    }

    private func resolvedCurrentWeightKg(
        profile: UserProfile?,
        weightEntries: [WeightEntry],
        asOf date: Date
    ) -> Double? {
        if let latest = WeightTrendCalculator.latestWeight(
            from: Self.weights(
                endingOnOrBefore: date,
                from: weightEntries,
                calendar: calendar
            )
        )?.weightKg, latest > 0 {
            return latest
        }
        if let profileWeight = profile?.currentWeightKg, profileWeight > 0 {
            return profileWeight
        }
        return nil
    }
}

// MARK: - Shared assembly helpers

private enum WeeklyProgressSummaryAssembly {

    static let minimumFoodDaysForHabitNudge = 3
    static let proteinHitRateNudgeThreshold = 0.50
    static let waterHitRateNudgeThreshold = 0.50
}

extension WeeklyProgressSummaryBuilder {

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

    /// The review window immediately before `range`.
    static func previousWeekRange(
        for range: WeeklyProgressWeekRange,
        calendar: Calendar
    ) -> WeeklyProgressWeekRange {
        switch range.kind {
        case .completedCalendarWeek:
            let previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: range.startDate)
                .map { calendar.startOfDay(for: $0) } ?? range.startDate
            let previousEnd = calendar.date(byAdding: .day, value: JourneyLogMetrics.weekDayCount - 1, to: previousStart)
                ?? previousStart
            return WeeklyProgressWeekRange(
                kind: .completedCalendarWeek,
                startDate: previousStart,
                endDate: calendar.startOfDay(for: previousEnd),
                totalDays: range.totalDays
            )
        case .rollingSevenDays:
            let endDate = calendar.date(byAdding: .day, value: -JourneyLogMetrics.weekDayCount, to: range.endDate)
                ?? range.startDate
            let startDate = calendar.date(
                byAdding: .day,
                value: -(JourneyLogMetrics.weekDayCount - 1),
                to: endDate
            ) ?? endDate
            return WeeklyProgressWeekRange(
                kind: .rollingSevenDays,
                startDate: calendar.startOfDay(for: startDate),
                endDate: calendar.startOfDay(for: endDate),
                totalDays: range.totalDays
            )
        }
    }

    static func resolveVerdict(
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

    static func resolveNextAction(
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
        guard foodLoggedDays >= WeeklyProgressSummaryAssembly.minimumFoodDaysForHabitNudge,
              totalDays > 0 else {
            return nil
        }

        let proteinRate = Double(proteinHitDays) / Double(foodLoggedDays)
        let waterRate = Double(waterTargetHitDays) / Double(totalDays)

        if proteinRate < WeeklyProgressSummaryAssembly.proteinHitRateNudgeThreshold {
            return .focusProtein
        }
        if waterRate < WeeklyProgressSummaryAssembly.waterHitRateNudgeThreshold {
            return .focusWater
        }

        return nil
    }

    struct SummaryCopy {
        let headline: String
        let summary: String
        let primaryInsight: String
        let nextActionTitle: String
        let nextActionSubtitle: String
    }

    static func buildCopy(
        verdict: WeeklyProgressVerdict,
        nextAction: WeeklyProgressNextAction,
        maintenanceEstimate: MaintenanceEstimate,
        weekRange: WeeklyProgressWeekRange
    ) -> SummaryCopy {
        SummaryCopy(
            headline: headline(for: verdict),
            summary: summary(
                for: verdict,
                maintenanceEstimate: maintenanceEstimate,
                weekRange: weekRange
            ),
            primaryInsight: primaryInsight(
                for: verdict,
                maintenanceEstimate: maintenanceEstimate
            ),
            nextActionTitle: nextActionCopy(for: nextAction, verdict: verdict).title,
            nextActionSubtitle: nextActionCopy(for: nextAction, verdict: verdict).subtitle
        )
    }

    static func headline(for verdict: WeeklyProgressVerdict) -> String {
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
            return FormaProductCopy.WeightSpikeEducation.noisyWeekHeadline
        case .needsConsistencyFirst:
            return "Your logging was inconsistent, so this review is about consistency first."
        case .maintaining:
            return "You're holding steady this week."
        case .unclear:
            return "Your week is still taking shape."
        }
    }

    static func summary(
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

    static func primaryInsight(
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

    static func nextActionCopy(
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

    static func logs(
        in range: WeeklyProgressWeekRange,
        from logs: [DailyLog],
        calendar: Calendar
    ) -> [DailyLog] {
        logs.filter { log in
            let day = calendar.startOfDay(for: log.date)
            return day >= range.startDate && day <= range.endDate
        }
    }

    static func weights(
        in range: WeeklyProgressWeekRange,
        from weights: [WeightEntry],
        calendar: Calendar
    ) -> [WeightEntry] {
        weights.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return day >= range.startDate && day <= range.endDate
        }
    }

    static func weights(
        endingOnOrBefore endDate: Date,
        from weights: [WeightEntry],
        calendar: Calendar
    ) -> [WeightEntry] {
        let endDay = calendar.startOfDay(for: endDate)
        return weights.filter { calendar.startOfDay(for: $0.date) <= endDay }
    }

    static func averageIntakeCalories(in logs: [DailyLog]) -> Double? {
        let foodLogs = logs.filter { $0.totals.calories > 0 }
        guard !foodLogs.isEmpty else { return nil }
        let total = foodLogs.reduce(0) { $0 + $1.totals.calories }
        return Double(total) / Double(foodLogs.count)
    }

    static func averageProteinGrams(in logs: [DailyLog]) -> Double? {
        let foodLogs = logs.filter { $0.totals.calories > 0 }
        guard !foodLogs.isEmpty else { return nil }
        let total = foodLogs.reduce(0.0) { $0 + $1.totals.protein }
        return total / Double(foodLogs.count)
    }

    static func loggingHistorySpanDays(
        dailyLogs: [DailyLog],
        referenceDate: Date,
        calendar: Calendar
    ) -> Int? {
        guard let firstFoodDate = JourneyLogMetrics.firstFoodLogDate(in: dailyLogs) else {
            return nil
        }

        let start = calendar.startOfDay(for: firstFoodDate)
        let end = calendar.startOfDay(for: referenceDate)
        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let span = max(dayCount + 1, 0)
        return span > 0 ? span : nil
    }

    static func foodLoggedDaysForConfidence(
        in logs: [DailyLog],
        through referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        let endDay = calendar.startOfDay(for: referenceDate)
        let spanLogs = logs.filter { calendar.startOfDay(for: $0.date) <= endDay }
        return JourneyLogMetrics.uniqueFoodLoggedDays(in: spanLogs, calendar: calendar)
    }

    static func summaryID(
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
