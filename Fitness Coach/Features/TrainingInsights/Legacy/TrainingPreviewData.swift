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
        ),
        ExerciseSet(
            id: UUID(),
            workoutEntryId: workoutId,
            exerciseName: "Barbell Row",
            setNumber: 1,
            reps: 8,
            weightKg: 70,
            rpe: 7.5,
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
        exerciseCount: 2,
        setCount: sets.count,
        totalVolumeKg: WorkoutCalorieCalculator.totalVolumeKg(from: sets),
        notes: workout.notes,
        workout: workout,
        exerciseSets: sets
    )

    static let muscleDistribution: [MuscleDistributionItem] = [
        MuscleDistributionItem(name: "Chest", setCount: 2, progress: 1),
        MuscleDistributionItem(name: "Back", setCount: 1, progress: 0.5)
    ]

    static let hero = TrainingHeroState(
        hasWorkoutToday: true,
        primaryWorkout: item,
        lastWorkout: item
    )

    static let restDayHero = TrainingHeroState(
        hasWorkoutToday: false,
        primaryWorkout: nil,
        lastWorkout: item
    )

    static let state = TrainingDashboardState(
        hero: hero,
        weekly: TrainingWeeklySummary(
            workoutsCompleted: 3,
            totalCalories: 890,
            totalDurationMinutes: 165,
            trainingStreak: 2
        ),
        muscleDistribution: muscleDistribution,
        recentWorkouts: [item]
    )
}
