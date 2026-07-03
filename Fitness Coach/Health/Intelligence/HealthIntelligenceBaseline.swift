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

        let summary = WorkoutIntelligenceEngine().evaluate(
            WorkoutIntelligenceInput(
                targetDate: dayStart,
                workoutsToday: todaysWorkouts,
                recentWorkouts: workouts,
                trainingLoadSummary: .unknown,
                baselineContext: .empty(for: dayStart),
                calendar: calendar
            )
        )
        return summary.hasWorkout ? summary : nil
    }

    // MARK: - Recovery

    static func recoverySummary(availability: HealthDataAvailability) -> RecoverySummary {
        guard availability.isHealthDataAvailable else {
            return RecoverySummary(score: nil, readinessLabel: "Unknown")
        }

        let sleepReadable = availability.permissionStatus.access(for: .sleepAnalysis).isReadable
        let restingHRReadable = availability.permissionStatus.access(for: .restingHeartRate).isReadable
        let hrvReadable = availability.permissionStatus.access(for: .heartRateVariabilitySDNN).isReadable

        guard sleepReadable || restingHRReadable || hrvReadable else {
            return RecoverySummary(score: nil, readinessLabel: "Unknown")
        }

        return RecoverySummary(score: nil, readinessLabel: "Insufficient data")
    }

    // MARK: - Weekly review

    static func weeklyReview(
        metricsInWeek: [DailyHealthMetrics],
        workoutDays: Int
    ) -> WeeklyHealthReview? {
        let daysWithActivity = metricsInWeek.filter { dayHasActivity($0) }.count
        guard daysWithActivity >= minimumWeeklyReviewDays else {
            return nil
        }

        return WeeklyHealthReview(
            headline: "Weekly activity available",
            workoutDays: workoutDays,
            narrative: nil
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
        workout: WorkoutSummary?
    ) -> NextBestAction {
        guard availability.isHealthDataAvailable else {
            return NextBestAction(
                title: "Apple Health unavailable",
                detail: "Recovery and activity insights need a device with Apple Health.",
                priority: 1
            )
        }

        guard availability.hasTrainingReadAccess else {
            return NextBestAction(
                title: "Connect Apple Health",
                detail: "Enable activity reads to improve plan confidence.",
                priority: 1
            )
        }

        if workout?.hasWorkout != true,
           activity.steps == nil,
           activity.exerciseMinutes == nil {
            return NextBestAction(
                title: "Waiting for activity data",
                detail: "No steps or workouts are available for today yet.",
                priority: 2
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
