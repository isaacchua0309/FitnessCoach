//
//  ProgressPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview data for Journey UI previews.
//

import Foundation

enum ProgressPreviewData {
    static let today = Date()
    private static let calendar = Calendar.current

    private static var previewTargets: UserTargets {
        UserTargets(
            calorieTarget: 1_800,
            proteinTarget: 130,
            carbTarget: 170,
            fatTarget: 55,
            waterTargetMl: 2_400,
            expectedWeeklyWeightLossKg: 0.34,
            aggressiveness: .moderate
        )
    }

    private static var previewProfile: UserProfile {
        UserProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Alex",
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 86.2,
            goalWeightKg: 75,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7_000,
            unitSystem: .metric,
            targets: previewTargets,
            createdAt: calendar.date(byAdding: .day, value: -40, to: today) ?? today,
            updatedAt: today
        )
    }

    static let baseline = JourneyBaseline(
        startWeightKg: 90,
        startDate: calendar.date(byAdding: .day, value: -24, to: today) ?? today,
        currentWeightKg: 86.2,
        goalWeightKg: 75,
        goalDirection: .lose,
        totalChangeKg: -3.8,
        remainingChangeKg: 11.2,
        progressPercent: 42,
        estimatedCompletionDate: calendar.date(byAdding: .month, value: 3, to: today),
        estimatedCompletionMonthLabel: "October",
        hasRealWeightEntries: true,
        usesSyntheticBaselinePoint: false,
        onboardingBaselineWeightKg: 90,
        chartPoints: makeWeightPoints(),
        showsWeightChart: true
    )

    static let transformationActiveFatLoss = makeTransformation(
        baseline: baseline,
        loggedDays: 18,
        loggingStreak: 7,
        weightTrendDirection: .decreasing
    )

    static let transformationNewUser = makeTransformation(
        baseline: JourneyBaseline(
            startWeightKg: 82,
            startDate: today,
            currentWeightKg: 82,
            goalWeightKg: 74,
            goalDirection: .lose,
            totalChangeKg: 0,
            remainingChangeKg: 8,
            progressPercent: 0,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: false,
            usesSyntheticBaselinePoint: true,
            onboardingBaselineWeightKg: 82,
            chartPoints: [],
            showsWeightChart: true
        ),
        loggedDays: 1,
        loggingStreak: 0,
        weightTrendDirection: .insufficientData
    )

    static let transformationNearGoal = makeTransformation(
        baseline: JourneyBaseline(
            startWeightKg: 90,
            startDate: calendar.date(byAdding: .day, value: -60, to: today) ?? today,
            currentWeightKg: 76.5,
            goalWeightKg: 75,
            goalDirection: .lose,
            totalChangeKg: -13.5,
            remainingChangeKg: 1.5,
            progressPercent: 90,
            estimatedCompletionDate: calendar.date(byAdding: .day, value: 10, to: today),
            estimatedCompletionMonthLabel: "July",
            hasRealWeightEntries: true,
            usesSyntheticBaselinePoint: false,
            onboardingBaselineWeightKg: 90,
            chartPoints: [],
            showsWeightChart: true
        ),
        loggedDays: 42,
        loggingStreak: 12,
        weightTrendDirection: .decreasing
    )

    static let transformationGainGoal = makeTransformation(
        baseline: JourneyBaseline(
            startWeightKg: 62,
            startDate: calendar.date(byAdding: .day, value: -30, to: today) ?? today,
            currentWeightKg: 65.8,
            goalWeightKg: 70,
            goalDirection: .gain,
            totalChangeKg: 3.8,
            remainingChangeKg: 4.2,
            progressPercent: 48,
            estimatedCompletionDate: calendar.date(byAdding: .month, value: 2, to: today),
            estimatedCompletionMonthLabel: "August",
            hasRealWeightEntries: true,
            usesSyntheticBaselinePoint: false,
            onboardingBaselineWeightKg: 62,
            chartPoints: [],
            showsWeightChart: true
        ),
        loggedDays: 20,
        loggingStreak: 5,
        weightTrendDirection: .increasing
    )

    static let transformationMaintainGoal = makeTransformation(
        baseline: JourneyBaseline(
            startWeightKg: 72,
            startDate: calendar.date(byAdding: .day, value: -45, to: today) ?? today,
            currentWeightKg: 72.4,
            goalWeightKg: 72,
            goalDirection: .maintain,
            totalChangeKg: 0.4,
            remainingChangeKg: 0.4,
            progressPercent: nil,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: true,
            usesSyntheticBaselinePoint: false,
            onboardingBaselineWeightKg: 72,
            chartPoints: [],
            showsWeightChart: true
        ),
        loggedDays: 25,
        loggingStreak: 4,
        weightTrendDirection: .stable
    )

    static let weeklyReviewFullWeek = makeWeeklyReview(
        foodLoggedDays: 7,
        proteinGoalDays: 6,
        waterGoalDays: 5,
        trainingDays: 4,
        expectedTrainingDays: 4,
        training: .connected(
            workoutDays: 4,
            averageCaloriesBurned: 310,
            averageTrainingDurationMinutes: 45
        ),
        weightDeltaThisWeekKg: -0.6,
        calorieAdherenceDays: 6,
        strongestPositiveSignal: "Food logging",
        weakestSignal: "Water",
        previousWeek: JourneyWeeklyReviewPreviousWeek(
            foodLoggedDays: 5,
            proteinGoalDays: 4,
            waterGoalDays: 3,
            calorieAdherenceDays: 4,
            trainingDays: 3,
            weightDeltaKg: -0.3
        )
    )

    static let weeklyReviewPartialWeek = makeWeeklyReview(
        foodLoggedDays: 3,
        proteinGoalDays: 2,
        waterGoalDays: 1,
        trainingDays: 1,
        expectedTrainingDays: 3,
        training: .connected(
            workoutDays: 1,
            averageCaloriesBurned: 220,
            averageTrainingDurationMinutes: 35
        ),
        weightDeltaThisWeekKg: nil,
        calorieAdherenceDays: 2,
        strongestPositiveSignal: "Food logging",
        weakestSignal: "Water"
    )

    static let weeklyReviewTrainingLocked = makeWeeklyReview(
        foodLoggedDays: 4,
        proteinGoalDays: 3,
        waterGoalDays: 2,
        trainingDays: 0,
        expectedTrainingDays: 3,
        training: .locked,
        weightDeltaThisWeekKg: -0.2,
        calorieAdherenceDays: 3,
        strongestPositiveSignal: "Food logging",
        weakestSignal: "Training"
    )

    static let milestonesActive = makeMilestones(
        foodLogDays: 32,
        proteinGoalDays: 8,
        startWeight: 90,
        currentWeight: 82,
        goalWeight: 75,
        direction: .lose,
        progressPercent: 53,
        loggingStreak: 7,
        longestStreak: 14
    )

    static let milestonesNewUser = makeMilestones(
        foodLogDays: 0,
        proteinGoalDays: 0,
        startWeight: 82,
        currentWeight: 82,
        goalWeight: 74,
        direction: .lose,
        progressPercent: 0,
        loggingStreak: 0,
        longestStreak: 0
    )

    static let milestonesNearGoal = makeMilestones(
        foodLogDays: 105,
        proteinGoalDays: 40,
        startWeight: 90,
        currentWeight: 76,
        goalWeight: 75,
        direction: .lose,
        progressPercent: 93,
        loggingStreak: 12,
        longestStreak: 21
    )

    static let storyTimelineNewUser = makeStoryTimeline(
        foodLogDays: 0,
        startWeight: 82,
        currentWeight: 82,
        goalWeight: 74,
        direction: .lose,
        progressPercent: 0,
        loggingStreak: 0,
        longestStreak: 0
    )

    static let storyTimelineActive = makeStoryTimeline(
        foodLogDays: 32,
        startWeight: 90,
        currentWeight: 82,
        goalWeight: 75,
        direction: .lose,
        progressPercent: 53,
        loggingStreak: 7,
        longestStreak: 14,
        weightEntries: [
            (daysAgo: 30, kg: 90.0),
            (daysAgo: 18, kg: 88.5),
            (daysAgo: 4, kg: 82.0)
        ]
    )

    static let habitInsightsActive = JourneyHabitInsightsState(
        isUnlocked: true,
        lockedMessage: nil,
        strongestHabitLabel: FormaProductCopy.Journey.HabitInsights.proteinLabel,
        strongestScorePercent: 91,
        strongestQualitative: FormaProductCopy.Journey.HabitInsights.strongestQualitative(percent: 91),
        weakestHabitLabel: FormaProductCopy.Journey.HabitInsights.weekendLabel,
        weakestScorePercent: 42,
        weakestScorePrefix: FormaProductCopy.Journey.HabitInsights.weakestScorePrefix(percent: 42),
        suggestedNextAction: FormaProductCopy.Journey.HabitInsights.suggestWeekendLogging
    )

    static let progressAttributionActive = JourneyProgressAttributionState(
        primaryReasonTitle: FormaProductCopy.Journey.WhyProgress.calorieLikelyHelpedTitle,
        primaryReasonDetail: FormaProductCopy.Journey.WhyProgress.stayedWithinCalories(
            achieved: 19,
            eligible: 23
        ),
        supportingReasons: [
            FormaProductCopy.Journey.WhyProgress.increasedProteinConsistency(percent: 42),
            FormaProductCopy.Journey.WhyProgress.loggedFoodDaysThisWeek(7)
        ],
        confidence: .high
    )

    static let beforeTodayActive = JourneyBeforeTodayState(
        startedWeightKg: 90,
        currentWeightKg: 86,
        startingMaintenanceCaloriesKcal: 3_100,
        currentMaintenanceCaloriesKcal: 2_950,
        startingTargetCaloriesKcal: 1_600,
        currentTargetCaloriesKcal: 2_100,
        goalWeightKg: 75,
        daysOnJourney: 24,
        showsMaintenanceRow: true,
        showsTargetRow: true,
        showsAdaptedTargetCopy: true
    )

    static let beforeTodayWeightsOnly = JourneyBeforeTodayState(
        startedWeightKg: 72,
        currentWeightKg: 72,
        startingMaintenanceCaloriesKcal: nil,
        currentMaintenanceCaloriesKcal: nil,
        startingTargetCaloriesKcal: nil,
        currentTargetCaloriesKcal: nil,
        goalWeightKg: 72,
        daysOnJourney: 3,
        showsMaintenanceRow: false,
        showsTargetRow: false,
        showsAdaptedTargetCopy: false
    )

    static let personalRecordsActive = JourneyPersonalRecordsState(
        isUnlocked: true,
        lockedMessage: nil,
        records: [
            JourneyPersonalRecord(
                id: "logging-streak",
                title: FormaProductCopy.Journey.PersonalRecords.longestStreakTitle,
                value: "21 days",
                subtitle: nil,
                periodLabel: "Nov 14",
                isActive: true,
                isEarlyRecord: false
            ),
            JourneyPersonalRecord(
                id: "protein-week",
                title: FormaProductCopy.Journey.PersonalRecords.highestProteinWeekTitle,
                value: "142g/day",
                subtitle: "Avg over 7 logged days",
                periodLabel: "Nov 8–14",
                isActive: true,
                isEarlyRecord: false
            ),
            JourneyPersonalRecord(
                id: "weight-week",
                title: FormaProductCopy.Journey.PersonalRecords.largestWeeklyLossTitle,
                value: "1.3 kg",
                subtitle: nil,
                periodLabel: "Nov 1–7",
                isActive: true,
                isEarlyRecord: false
            ),
            JourneyPersonalRecord(
                id: "water-week",
                title: FormaProductCopy.Journey.PersonalRecords.bestWaterWeekTitle,
                value: "6/7 days",
                subtitle: nil,
                periodLabel: "Nov 8–14",
                isActive: true,
                isEarlyRecord: false
            )
        ]
    )

    static let monthlyRecapActive = JourneyMonthlyRecapState(
        sectionTitle: FormaProductCopy.Journey.MonthlyRecap.sectionTitle(
            monthName: today.formatted(.dateTime.month(.wide))
        ),
        isComplete: true,
        buildingMessage: nil,
        monthLabel: today.formatted(.dateTime.month(.wide).year()),
        monthWeightDeltaKg: -2.4,
        calorieAdherencePercent: 0.91,
        proteinAdherencePercent: 0.87,
        waterAdherencePercent: 0.72,
        trainingSessions: 13,
        showsTrainingRow: true,
        loggedDays: 18,
        bestHabitCopy: FormaProductCopy.Journey.MonthlyRecap.bestHabit(for: .protein),
        summaryCopy: "You logged 18 days this month. Protein was your strongest habit.",
        rows: [
            JourneyMonthlyRecapMetricRow(id: "weight", title: "Weight", value: "↓ 2.4kg"),
            JourneyMonthlyRecapMetricRow(id: "calories", title: "Calories", value: "91% adherence"),
            JourneyMonthlyRecapMetricRow(id: "protein", title: "Protein", value: "87%"),
            JourneyMonthlyRecapMetricRow(id: "water", title: "Water", value: "72%"),
            JourneyMonthlyRecapMetricRow(id: "training", title: "Training", value: "13 sessions")
        ],
        calendar: JourneyConsistencyCalendar(
            monthTitle: today.formatted(.dateTime.month(.wide).year()),
            weekdaySymbols: Calendar.current.shortWeekdaySymbols,
            days: [],
            completedCount: 18,
            totalLoggedDays: 18
        )
    )

    static let state = ProgressDashboardState(
        selectedRangeDays: 28,
        hasProfile: true,
            baseline: baseline,
            transformation: transformationActiveFatLoss,
            weeklyReview: weeklyReviewFullWeek,
            streaks: makeStreaks(
                currentLogging: 7,
                longestLogging: 21,
                proteinStreak: 5,
                waterStreak: 4,
                trainingWeeks: 3,
                isTodayLogged: true
            ),
        milestones: milestonesActive,
        storyTimeline: storyTimelineActive,
        habitInsights: habitInsightsActive,
        progressAttribution: progressAttributionActive,
        beforeToday: beforeTodayActive,
        personalRecords: personalRecordsActive,
        monthlyRecap: monthlyRecapActive,
        journeyLevel: JourneyLevelState(
            currentLevel: 2,
            levelTitle: "Building rhythm",
            currentXP: 180,
            xpRequiredForNextLevel: 250,
            progressPercent: 53,
            xpEarnedExplanation: "XP comes from logged meals, protein and water targets, workouts, milestones, and streaks."
        ),
        detailedAnalytics: JourneyDetailedAnalyticsState(
            isCollapsedByDefault: true,
            nutritionSummary: ProgressNutritionSummary(
                loggedDays: 18,
                averageCalories: 1_735,
                averageProtein: 156.4,
                averageCarbs: 148.2,
                averageFat: 58.7,
                averageFiber: 22.1
            ),
            waterSummary: ProgressWaterSummary(
                loggedDays: 18,
                averageWaterMl: 2_650,
                averageWaterTargetMl: 3_200,
                consistencyPercent: 0.72
            ),
            workoutSummary: ProgressWorkoutSummary(
                workoutCount: 9,
                workoutDays: 6,
                totalEstimatedCaloriesBurned: 2_850,
                averageWorkoutsPerWeek: 2.25,
                averageDurationMinutes: 42,
                isFromAppleHealth: true
            ),
            weightChartPoints: makeWeightPoints(),
            weightTrendInterpretation: "The trend is moving toward your goal. Stay patient through normal daily fluctuations.",
            showsWeightChart: true
        )
    )

    private static func makeMilestones(
        foodLogDays: Int,
        proteinGoalDays: Int,
        startWeight: Double,
        currentWeight: Double,
        goalWeight: Double,
        direction: JourneyGoalDirection,
        progressPercent: Double,
        loggingStreak: Int,
        longestStreak: Int
    ) -> JourneyMilestonesState {
        var logs: [DailyLog] = []
        if foodLogDays > 0 {
            logs = (0..<foodLogDays).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
                return DailyLog(
                    id: UUID(),
                    date: date,
                    weightKg: nil,
                    targets: previewTargets,
                    totals: MacroTotals(
                        calories: 1_800,
                        protein: proteinGoalDays > offset ? 140 : 80,
                        carbs: 120,
                        fat: 50,
                        fiber: nil,
                        sodium: nil
                    ),
                    waterConsumedMl: 2_000,
                    steps: nil,
                    workoutCaloriesBurned: 0,
                    dailyReviewId: nil,
                    createdAt: date,
                    updatedAt: date
                )
            }
        }

        let baseline = JourneyBaseline(
            startWeightKg: startWeight,
            startDate: calendar.date(byAdding: .day, value: -max(foodLogDays, 1), to: today) ?? today,
            currentWeightKg: currentWeight,
            goalWeightKg: goalWeight,
            goalDirection: direction,
            totalChangeKg: currentWeight - startWeight,
            remainingChangeKg: abs(currentWeight - goalWeight),
            progressPercent: progressPercent,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: foodLogDays > 0,
            usesSyntheticBaselinePoint: foodLogDays == 0,
            onboardingBaselineWeightKg: startWeight,
            chartPoints: [],
            showsWeightChart: true
        )

        let streaks = makeStreaks(
            currentLogging: loggingStreak,
            longestLogging: longestStreak,
            proteinStreak: min(proteinGoalDays, 5),
            waterStreak: 2,
            trainingWeeks: loggingStreak > 0 ? 2 : nil,
            isTodayLogged: loggingStreak > 0
        )

        return JourneyMilestonesBuilder.build(
            JourneyMilestonesBuilder.Input(
                baseline: baseline,
                maturityLogs: logs,
                journeyStreaks: streaks,
                healthWorkoutDayStarts: [],
                calendar: calendar
            )
        )
    }

    private static func makeStoryTimeline(
        foodLogDays: Int,
        startWeight: Double,
        currentWeight: Double,
        goalWeight: Double,
        direction: JourneyGoalDirection,
        progressPercent: Double,
        loggingStreak: Int,
        longestStreak: Int,
        weightEntries: [(daysAgo: Int, kg: Double)] = []
    ) -> JourneyStoryTimelineState {
        var logs: [DailyLog] = []
        if foodLogDays > 0 {
            logs = (0..<foodLogDays).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
                return DailyLog(
                    id: UUID(),
                    date: date,
                    weightKg: nil,
                    targets: previewTargets,
                    totals: MacroTotals(
                        calories: 1_800,
                        protein: 140,
                        carbs: 120,
                        fat: 50,
                        fiber: nil,
                        sodium: nil
                    ),
                    waterConsumedMl: 2_000,
                    steps: nil,
                    workoutCaloriesBurned: 0,
                    dailyReviewId: nil,
                    createdAt: date,
                    updatedAt: date
                )
            }
        }

        let weights: [WeightEntry] = weightEntries.compactMap { entry in
            guard let date = calendar.date(byAdding: .day, value: -entry.daysAgo, to: today) else { return nil }
            return WeightEntry(
                id: UUID(),
                date: date,
                weightKg: entry.kg,
                note: nil,
                createdAt: date
            )
        }

        let baseline = JourneyBaseline(
            startWeightKg: startWeight,
            startDate: calendar.date(byAdding: .day, value: -max(foodLogDays, 1), to: today) ?? today,
            currentWeightKg: currentWeight,
            goalWeightKg: goalWeight,
            goalDirection: direction,
            totalChangeKg: currentWeight - startWeight,
            remainingChangeKg: abs(currentWeight - goalWeight),
            progressPercent: progressPercent,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: !weights.isEmpty,
            usesSyntheticBaselinePoint: weights.isEmpty,
            onboardingBaselineWeightKg: startWeight,
            chartPoints: [],
            showsWeightChart: true
        )

        let streaks = makeStreaks(
            currentLogging: loggingStreak,
            longestLogging: longestStreak,
            proteinStreak: min(foodLogDays, 5),
            waterStreak: min(foodLogDays, 4),
            trainingWeeks: foodLogDays > 0 ? 2 : nil,
            isTodayLogged: loggingStreak > 0
        )

        return JourneyTimelineBuilder.build(
            JourneyTimelineBuilder.Input(
                profile: previewProfile,
                baseline: baseline,
                maturityLogs: logs,
                allWeights: weights,
                healthWorkoutDayStarts: [],
                isAppleHealthConnected: false,
                journeyStreaks: streaks,
                asOf: today,
                calendar: calendar
            )
        )
    }

    private static func makeWeeklyReview(
        foodLoggedDays: Int,
        proteinGoalDays: Int,
        waterGoalDays: Int,
        trainingDays: Int,
        expectedTrainingDays: Int,
        training: JourneyWeeklyTrainingStatus,
        weightDeltaThisWeekKg: Double?,
        calorieAdherenceDays: Int,
        strongestPositiveSignal: String,
        weakestSignal: String,
        previousWeek: JourneyWeeklyReviewPreviousWeek? = nil
    ) -> JourneyWeeklyReviewState {
        let base = JourneyWeeklyReviewState(
            foodLoggedDays: foodLoggedDays,
            foodLoggedDaysTotal: 7,
            proteinGoalDays: proteinGoalDays,
            proteinGoalDaysTotal: 7,
            waterGoalDays: waterGoalDays,
            waterGoalDaysTotal: 7,
            trainingDays: trainingDays,
            expectedTrainingDays: expectedTrainingDays,
            training: training,
            weightDeltaThisWeekKg: weightDeltaThisWeekKg,
            calorieAdherenceDays: calorieAdherenceDays,
            calorieAdherenceDaysTotal: 7,
            strongestPositiveSignal: strongestPositiveSignal,
            weakestSignal: weakestSignal,
            weekSummaryCopy: JourneyWeeklyReviewBuilder.weekSummaryCopy(
                foodDays: foodLoggedDays,
                proteinDays: proteinGoalDays,
                trainingDays: trainingDays,
                goalDirection: .lose,
                weightDelta: weightDeltaThisWeekKg
            ),
            averageCalorieDeficit: 280,
            rows: [],
            weekOverWeekDetail: nil
        )

        return JourneyWeeklyReviewBuilder.enrich(
            review: base,
            previousWeek: previousWeek,
            goalDirection: .lose,
            streaks: makeStreaks(
                currentLogging: foodLoggedDays > 0 ? 7 : 0,
                longestLogging: 21,
                proteinStreak: proteinGoalDays,
                waterStreak: waterGoalDays,
                trainingWeeks: trainingDays > 0 ? 2 : nil,
                isTodayLogged: foodLoggedDays > 0
            )
        )
    }

    private static func makeStreaks(
        currentLogging: Int,
        longestLogging: Int,
        proteinStreak: Int,
        waterStreak: Int,
        trainingWeeks: Int?,
        isTodayLogged: Bool
    ) -> JourneyStreakState {
        let copy = FormaProductCopy.Journey.Streaks.self
        let heroChip: JourneyStreakChipState = currentLogging > 0
            ? JourneyStreakChipState(
                isVisible: true,
                days: currentLogging,
                label: copy.loggingStreak(days: currentLogging)
            )
            : .hidden
        let weekly = currentLogging > 0
            ? (copy.loggingStreak(days: currentLogging), copy.longestLoggingStreak(days: longestLogging))
            : (copy.buildingConsistency, copy.longestLoggingStreak(days: longestLogging))

        return JourneyStreakState(
            currentLoggingStreakDays: currentLogging,
            longestLoggingStreakDays: longestLogging,
            currentProteinStreakDays: proteinStreak,
            currentWaterStreakDays: waterStreak,
            currentTrainingStreakWeeks: trainingWeeks,
            isTodayLogged: isTodayLogged,
            heroStreakChip: heroChip,
            weeklyConsistencyHeadline: weekly.0,
            weeklyConsistencyDetail: weekly.1,
            habitInsightStreakCopy: currentLogging > 0
                ? copy.loggingStreak(days: currentLogging)
                : copy.buildingConsistency,
            keepStreakAliveCopy: nil
        )
    }

    private static func makeTransformation(
        baseline: JourneyBaseline,
        loggedDays: Int,
        loggingStreak: Int,
        weightTrendDirection: WeightTrendDirection
    ) -> JourneyTransformationHeroState {
        let streaks = makeStreaks(
            currentLogging: loggingStreak,
            longestLogging: max(loggingStreak, 12),
            proteinStreak: 3,
            waterStreak: 2,
            trainingWeeks: loggingStreak > 0 ? 2 : nil,
            isTodayLogged: loggingStreak > 0
        )
        return JourneyTransformationHeroBuilder.build(
            JourneyTransformationHeroBuilder.Input(
                baseline: baseline,
                loggedDays: loggedDays,
                heroStreakChip: streaks.heroStreakChip,
                weightTrendDirection: weightTrendDirection,
                asOf: today,
                calendar: calendar
            )
        )
    }

    private static func makeWeightPoints() -> [WeightChartPoint] {
        (0..<10).compactMap { index in
            guard let date = Calendar.current.date(byAdding: .day, value: -9 + index, to: today) else {
                return nil
            }
            return WeightChartPoint(
                date: date,
                weightKg: 90.2 - (Double(index) * 0.14),
                isSynthetic: index == 0,
                pointLabel: index == 0 ? .onboarding : .logged
            )
        }
    }
}
