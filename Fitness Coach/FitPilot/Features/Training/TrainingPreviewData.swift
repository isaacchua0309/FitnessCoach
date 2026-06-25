//
//  TrainingPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview data for Training UI previews.
//

import Foundation

enum TrainingPreviewData {
    static let workoutId = UUID()
    static let now = Date()

    static let sets: [ExerciseSet] = [
        ExerciseSet(
            id: UUID(),
            workoutEntryId: workoutId,
            exerciseName: "Bench Press",
            setNumber: 1,
            reps: 5,
            weightKg: 90,
            rpe: 8,
            createdAt: now
        ),
        ExerciseSet(
            id: UUID(),
            workoutEntryId: workoutId,
            exerciseName: "Bench Press",
            setNumber: 2,
            reps: 5,
            weightKg: 90,
            rpe: 8.5,
            createdAt: now
        )
    ]

    static let workout = WorkoutEntry(
        id: workoutId,
        dailyLogId: UUID(),
        name: "Upper Body",
        durationMinutes: 55,
        estimatedCaloriesBurned: 310,
        intensity: .moderate,
        recoveryDemand: .moderate,
        notes: "Felt strong today.",
        createdAt: now,
        updatedAt: now
    )

    static let item = WorkoutDisplayItem(
        id: workout.id,
        name: TrainingFormatter.workoutName(workout),
        dateText: TrainingFormatter.date(workout.createdAt),
        durationText: TrainingFormatter.duration(workout.durationMinutes),
        estimatedCaloriesText: TrainingFormatter.calories(workout.estimatedCaloriesBurned),
        intensityText: TrainingFormatter.intensity(workout.intensity),
        recoveryDemandText: TrainingFormatter.recovery(workout.recoveryDemand),
        exerciseCount: 1,
        setCount: sets.count,
        totalVolumeKg: WorkoutCalorieCalculator.totalVolumeKg(from: sets),
        notes: workout.notes,
        workout: workout,
        exerciseSets: sets
    )

    static let state = TrainingDashboardState(
        selectedDate: now,
        todaysWorkouts: [item],
        recentWorkouts: [item],
        summary: TrainingSummary(
            workoutCountToday: 1,
            workoutCountInRecentRange: 1,
            estimatedCaloriesBurnedToday: 310,
            totalVolumeTodayKg: WorkoutCalorieCalculator.totalVolumeKg(from: sets)
        )
    )
}
