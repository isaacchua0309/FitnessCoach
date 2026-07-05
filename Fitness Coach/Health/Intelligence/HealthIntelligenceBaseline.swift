//
//  HealthIntelligenceBaseline.swift
//  Fitness Coach
//
//  Forma — Deterministic Phase 5 baseline snapshot composition helpers.
//

import Foundation

enum HealthIntelligenceBaseline {

    static let minimumWeeklyReviewDays = 7
    static let minimumPlanConfidenceDays = 7

    // MARK: - Activity

    static func activitySummary(
        metrics: DailyHealthMetrics,
        availability: HealthDataAvailability
    ) -> ActivitySummary {
        let permission = availability.permissionStatus
        let stepsReadable = permission.access(for: .stepCount).isReadable
        let energyReadable = permission.access(for: .activeEnergyBurned).isReadable
        let exerciseReadable = permission.access(for: .appleExerciseTime).isReadable

        return ActivitySummary(
            steps: stepsReadable ? metrics.steps : nil,
            activeEnergyKcal: energyReadable ? Int(metrics.activeEnergyKcal.rounded()) : nil,
            exerciseMinutes: exerciseReadable ? Int(metrics.exerciseMinutes.rounded()) : nil
        )
    }

    // MARK: - Workout

    static func workoutSummary(
        workouts: [NormalizedWorkout],
        on day: Date,
        calendar: Calendar
    ) -> WorkoutSummary? {
        let dayStart = calendar.startOfDay(for: day)
        let todaysWorkouts = WorkoutIntelligenceEngine.workoutsOnTargetDay(
            workouts,
            targetDay: dayStart,
            calendar: calendar
        )

        guard !todaysWorkouts.isEmpty else {
            return nil
        }

        guard let summary = try? WorkoutIntelligenceEngine().evaluate(
            WorkoutIntelligenceInput(
                targetDate: dayStart,
                workoutsToday: todaysWorkouts,
                recentWorkouts: workouts,
                trainingLoadSummary: .unknown,
                baselineContext: .empty(for: dayStart),
                calendar: calendar
            )
        ) else {
            return nil
        }
        return summary.hasWorkout ? summary : nil
    }

    // MARK: - Recovery

    static func recoverySummary(availability: HealthDataAvailability) -> RecoverySummary {
        guard availability.isHealthDataAvailable else {
            return .unknown
        }

        let sleepReadable = availability.permissionStatus.access(for: .sleepAnalysis).isReadable
        let restingHRReadable = availability.permissionStatus.access(for: .restingHeartRate).isReadable
        let hrvReadable = availability.permissionStatus.access(for: .heartRateVariabilitySDNN).isReadable

        guard sleepReadable || restingHRReadable || hrvReadable else {
            return RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery unclear",
                explanation: "Sleep and heart signals are not available yet.",
                recommendedTraining: "Use how you feel before adding intensity today.",
                recommendedNutrition: "Stay on your usual plan until more data arrives.",
                confidence: .unknown,
                contributingFactors: [],
                missingSignals: [.sleep, .restingHeartRate, .hrv]
            )
        }

        return RecoverySummary(
            score: nil,
            status: .unknown,
            title: "Recovery unclear",
            explanation: "Recovery signals are available, but today's estimate is not ready yet.",
            recommendedTraining: "Use how you feel before adding intensity today.",
            recommendedNutrition: "Stay on your usual plan until more data arrives.",
            confidence: .low,
            contributingFactors: [],
            missingSignals: [.activity, .workouts, .trainingLoad]
        )
    }

    // MARK: - Weekly review

    static func weeklyReview(
        metricsInWeek: [DailyHealthMetrics],
        workoutDays: Int,
        weekEndDate: Date,
        calendar: Calendar
    ) -> WeeklyHealthReview? {
        let daysWithActivity = metricsInWeek.filter { dayHasActivity($0) }.count
        guard daysWithActivity >= minimumWeeklyReviewDays else {
            return nil
        }

        guard let weekStart = calendar.date(
            byAdding: .day,
            value: -(minimumWeeklyReviewDays - 1),
            to: calendar.startOfDay(for: weekEndDate)
        ) else {
            return nil
        }

        let stepValues = metricsInWeek.map(\.steps).filter { $0 > 0 }
        let averageSteps = stepValues.isEmpty
            ? nil
            : stepValues.reduce(0, +) / stepValues.count

        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: calendar.startOfDay(for: weekEndDate),
            title: "Weekly activity available",
            summary: "Activity data is available for the past week. A fuller coaching review will appear as nutrition and weight signals sync.",
            stats: WeeklyStats(
                totalWorkouts: workoutDays,
                totalWorkoutMinutes: 0,
                totalActiveCalories: nil,
                averageSteps: averageSteps,
                totalSteps: stepValues.isEmpty ? nil : stepValues.reduce(0, +),
                proteinHitDays: 0,
                calorieTargetHitDays: 0,
                waterHitDays: 0,
                averageRecoveryScore: nil,
                lowRecoveryDays: 0,
                weightChangeKg: nil,
                loggingConsistencyDays: 0
            ),
            wins: averageSteps.map { ["Movement averaged about \($0) steps per day."] } ?? [],
            risks: [],
            nextWeekFocus: ["Keep logging activity and meals to unlock a richer review."],
            confidence: .low,
            missingSignals: [.nutrition, .weight, .recovery, .sleep, .hrv],
            generatedAt: weekEndDate
        )
    }

    // MARK: - Plan confidence

    static func planConfidence(
        availability: HealthDataAvailability,
        daysWithActivityData: Int
    ) -> PlanHealthConfidence {
        guard availability.isHealthDataAvailable else {
            return PlanHealthConfidence(score: 0, label: "Unknown")
        }

        guard availability.hasTrainingReadAccess else {
            return PlanHealthConfidence(score: 0.2, label: "Low")
        }

        if daysWithActivityData >= minimumPlanConfidenceDays {
            return PlanHealthConfidence(score: 0.75, label: "Moderate")
        }

        if daysWithActivityData > 0 {
            return PlanHealthConfidence(score: 0.45, label: "Limited")
        }

        return PlanHealthConfidence(score: 0.25, label: "Low")
    }

    // MARK: - Next best action

    static func nextBestAction(
        availability: HealthDataAvailability,
        activity: ActivitySummary,
        workout: WorkoutSummary?,
        referenceDate: Date = Date()
    ) -> NextBestAction {
        guard availability.isHealthDataAvailable else {
            return NextBestAction(
                id: "health-unavailable",
                title: "Apple Health unavailable",
                message: "Recovery and activity insights need a device with Apple Health.",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .healthDataLimited,
                createdAt: referenceDate,
                expiresAt: nil
            )
        }

        if workout?.hasWorkout != true,
           activity.steps == nil,
           activity.exerciseMinutes == nil {
            return NextBestAction(
                id: "waiting-for-activity",
                title: "Waiting for activity data",
                message: "No steps or workouts are available for today yet.",
                ctaTitle: "",
                destination: .none,
                priority: 2,
                reason: .waitingForData,
                createdAt: referenceDate,
                expiresAt: nil
            )
        }

        return .none
    }

    // MARK: - Helpers

    static func dayHasActivity(_ metrics: DailyHealthMetrics) -> Bool {
        metrics.steps > 0 || metrics.exerciseMinutes > 0 || metrics.activeEnergyKcal > 0
    }

    static func workoutDays(
        in workouts: [NormalizedWorkout],
        endingOn day: Date,
        calendar: Calendar
    ) -> Int {
        guard let weekStart = calendar.date(byAdding: .day, value: -(minimumWeeklyReviewDays - 1), to: day) else {
            return 0
        }

        var daysWithWorkouts = Set<Date>()
        for workout in workouts where workout.startDate >= weekStart {
            daysWithWorkouts.insert(calendar.startOfDay(for: workout.startDate))
        }
        return daysWithWorkouts.count
    }

    static func metricsInWeek(
        endingOn day: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date)? {
        let end = calendar.startOfDay(for: day)
        guard let start = calendar.date(byAdding: .day, value: -(minimumWeeklyReviewDays - 1), to: end) else {
            return nil
        }
        return (start, end)
    }
}
