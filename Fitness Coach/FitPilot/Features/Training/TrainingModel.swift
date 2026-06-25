//
//  TrainingModel.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Training intelligence dashboard.
//
//  All workout logging happens in Coach. This model only observes persisted data.
//

import Combine
import Foundation

@MainActor
final class TrainingModel: ObservableObject {

    @Published private(set) var viewState: TrainingViewState = .loading
    @Published var selectedWorkout: WorkoutDisplayItem?

    private let workoutLogService: WorkoutLogService
    private let dailyLogService: DailyLogService

    private let recentRangeDays = 28
    private let weeklyRangeDays = 7
    private let muscleRangeDays = 7
    private let recentListLimit = 12

    init(
        workoutLogService: WorkoutLogService,
        dailyLogService: DailyLogService
    ) {
        self.workoutLogService = workoutLogService
        self.dailyLogService = dailyLogService
    }

    // MARK: Loading

    func loadTraining() async {
        viewState = .loading
        await refresh()
    }

    func refresh() async {
        do {
            let state = try makeDashboardState()
            viewState = .loaded(state)
        } catch {
            viewState = .error("Could not load training data.")
        }
    }

    // MARK: Selection

    func selectWorkout(_ workout: WorkoutDisplayItem) {
        selectedWorkout = workout
    }

    func clearSelectedWorkout() {
        selectedWorkout = nil
    }

    // MARK: State Building

    private func makeDashboardState() throws -> TrainingDashboardState {
        let today = Date()
        let todaysWorkouts = try workoutLogService.getWorkouts(for: today)
        let history = try workoutLogService.getWorkoutHistory(days: recentRangeDays)
        let weeklyWorkouts = workoutsInLastDays(history, days: weeklyRangeDays, asOf: today)

        let todaysItems = try todaysWorkouts.map { try makeDisplayItem(from: $0) }
        let allItems = try history.map { try makeDisplayItem(from: $0) }
        let sortedItems = allItems.sorted { $0.workout.createdAt > $1.workout.createdAt }

        let weeklySets = try sets(for: weeklyWorkouts)
        let muscleSets = try sets(for: workoutsInLastDays(history, days: muscleRangeDays, asOf: today))

        let streak = try trainingStreak(asOf: today)

        return TrainingDashboardState(
            hero: TrainingHeroState(
                hasWorkoutToday: !todaysItems.isEmpty,
                primaryWorkout: todaysItems.first,
                lastWorkout: sortedItems.first
            ),
            weekly: TrainingWeeklySummary(
                workoutsCompleted: weeklyWorkouts.count,
                totalCalories: weeklyWorkouts.compactMap(\.estimatedCaloriesBurned).reduce(0, +),
                totalDurationMinutes: weeklyWorkouts.compactMap(\.durationMinutes).reduce(0, +),
                trainingStreak: streak
            ),
            muscleDistribution: TrainingMuscleDistributionBuilder.distribution(from: muscleSets),
            recentWorkouts: Array(sortedItems.prefix(recentListLimit))
        )
    }

    private func makeDisplayItem(from workout: WorkoutEntry) throws -> WorkoutDisplayItem {
        let sets = try workoutLogService.getExerciseSets(for: workout.id)
        let volume = WorkoutCalorieCalculator.totalVolumeKg(from: sets)
        let exerciseCount = Set(sets.map(\.exerciseName)).count

        return WorkoutDisplayItem(
            id: workout.id,
            name: TrainingFormatter.workoutName(workout),
            dateText: TrainingFormatter.date(workout.createdAt),
            durationText: TrainingFormatter.duration(workout.durationMinutes),
            estimatedCaloriesText: TrainingFormatter.calories(workout.estimatedCaloriesBurned),
            intensityText: TrainingFormatter.intensity(workout.intensity),
            recoveryDemandText: TrainingFormatter.recovery(workout.recoveryDemand),
            exerciseCount: exerciseCount,
            setCount: sets.count,
            totalVolumeKg: volume > 0 ? volume : nil,
            notes: workout.notes,
            workout: workout,
            exerciseSets: sets
        )
    }

    private func workoutsInLastDays(
        _ workouts: [WorkoutEntry],
        days: Int,
        asOf date: Date
    ) -> [WorkoutEntry] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: date)) ?? date
        return workouts.filter { $0.createdAt >= start }
    }

    private func sets(for workouts: [WorkoutEntry]) throws -> [ExerciseSet] {
        try workouts.flatMap { try workoutLogService.getExerciseSets(for: $0.id) }
    }

    private func trainingStreak(asOf date: Date) throws -> Int {
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: date) ?? date
        let logs = try dailyLogService.getLogs(from: startDate, to: date)
        let workouts = try workoutLogService.getWorkoutHistory(days: 90)
        let workoutDates = Set(workouts.map { Calendar.current.startOfDay(for: $0.createdAt) })
        return StreakCalculator.calculate(logs: logs, workoutDates: workoutDates, asOf: date).workoutStreak
    }
}
