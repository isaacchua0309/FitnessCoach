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

    static let state = ProgressDashboardState(
        selectedRangeDays: 28,
        hasProfile: true,
        baseline: baseline,
        transformation: transformationActiveFatLoss,
        weeklyReview: weeklyReviewFullWeek,
        milestones: JourneyMilestonesState(
            unlocked: [],
            upcoming: [
                JourneyMilestone(id: "m-0", title: "Start", weightKg: 90, status: .current),
                JourneyMilestone(id: "m-1", title: "Checkpoint 1", weightKg: 86.3, status: .upcoming)
            ],
            next: JourneyMilestone(id: "m-1", title: "Checkpoint 1", weightKg: 86.3, status: .upcoming),
            progressPercent: 0,
            items: [
                JourneyMilestone(id: "m-0", title: "Start", weightKg: 90, status: .current),
                JourneyMilestone(id: "m-1", title: "Checkpoint 1", weightKg: 86.3, status: .upcoming),
                JourneyMilestone(id: "m-2", title: "Checkpoint 2", weightKg: 82.5, status: .upcoming),
                JourneyMilestone(id: "m-3", title: "Checkpoint 3", weightKg: 78.8, status: .upcoming),
                JourneyMilestone(id: "m-4", title: "Goal", weightKg: 75, status: .upcoming)
            ]
        ),
        storyTimeline: JourneyStoryTimelineState(events: [
            JourneyTimelineEvent(
                id: "onboarding",
                date: today,
                kind: .onboardingStarted,
                title: "Your journey began",
                subtitle: "You set your goal and plan in Forma."
            )
        ]),
        habitInsights: JourneyHabitInsightsState(
            strongestHabit: .protein,
            strongestHabitPercentage: 71,
            weakestHabit: .water,
            weakestHabitPercentage: 57,
            suggestedNextAction: "Front-load water before your next meal.",
            habitInsightExplanation: "Protein is your strongest habit (71% this week). Keep Water in view — you're on a 5-day streak.",
            loggingStreakDays: 5
        ),
        progressAttribution: JourneyProgressAttributionState(
            primaryReason: "You logged food 6 days this week.",
            supportingReasons: [
                "You stayed within calories 12 of the last 18 logged days.",
                "Training showed up 3 days this week — recovery and consistency compound."
            ]
        ),
        beforeToday: JourneyBeforeTodayState(
            startedWeightKg: 90,
            currentWeightKg: 86.2,
            startingMaintenanceCaloriesKcal: 2_450,
            currentMaintenanceCaloriesKcal: 2_420,
            startingTargetCaloriesKcal: 1_950,
            currentTargetCaloriesKcal: 1_950,
            goalWeightKg: 75,
            daysOnJourney: 24
        ),
        personalRecords: JourneyPersonalRecordsState(records: [
            JourneyPersonalRecord(id: "logging-streak", title: "Longest logging streak", value: "5 days", isActive: true),
            JourneyPersonalRecord(id: "protein-week", title: "Best protein week", value: "5 of 7 days", isActive: true)
        ]),
        monthlyRecap: JourneyMonthlyRecapState(
            monthLabel: today.formatted(.dateTime.month(.wide).year()),
            monthWeightDeltaKg: -1.2,
            calorieAdherencePercent: 0.72,
            proteinAdherencePercent: 0.68,
            waterAdherencePercent: 0.55,
            trainingSessions: 9,
            loggedDays: 12,
            summaryCopy: "You logged 12 days this month, protein sat on target 68% of eligible days.",
            calendar: JourneyConsistencyCalendar(
                monthTitle: today.formatted(.dateTime.month(.wide).year()),
                weekdaySymbols: Calendar.current.shortWeekdaySymbols,
                days: [],
                completedCount: 12,
                totalLoggedDays: 12
            )
        ),
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
            goalDirection: .lose
        )
    }

    private static func makeTransformation(
        baseline: JourneyBaseline,
        loggedDays: Int,
        loggingStreak: Int,
        weightTrendDirection: WeightTrendDirection
    ) -> JourneyTransformationHeroState {
        JourneyTransformationHeroBuilder.build(
            JourneyTransformationHeroBuilder.Input(
                baseline: baseline,
                loggedDays: loggedDays,
                loggingStreak: loggingStreak,
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
