//
//  TrainingModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for basic workout logging.
//
//  TrainingModel calls services only. It does not access SwiftData directly,
//  call AI, or coordinate with other feature models.
//

import Combine
import Foundation

@MainActor
final class TrainingModel: ObservableObject {

    @Published private(set) var viewState: TrainingViewState = .loading
    @Published var isShowingWorkoutEntrySheet = false
    @Published var selectedWorkout: WorkoutDisplayItem?
    @Published private(set) var formErrorMessage: String?

    private let workoutLogService: WorkoutLogService
    private let dailyLogService: DailyLogService
    private let userProfileService: UserProfileService
    private let refreshCenter: AppRefreshCenter

    private let recentRangeDays = 28

    init(
        workoutLogService: WorkoutLogService,
        dailyLogService: DailyLogService,
        userProfileService: UserProfileService,
        refreshCenter: AppRefreshCenter
    ) {
        self.workoutLogService = workoutLogService
        self.dailyLogService = dailyLogService
        self.userProfileService = userProfileService
        self.refreshCenter = refreshCenter
    }

    // MARK: Loading

    func loadTraining() async {
        viewState = .loading
        await refresh()
    }

    func refresh() async {
        do {
            let state = try makeDashboardState()
            viewState = state.todaysWorkouts.isEmpty && state.recentWorkouts.isEmpty
                ? .empty
                : .loaded(state)
        } catch {
            viewState = .error("Could not load workouts.")
        }
    }

    // MARK: Sheet

    func showAddWorkout() {
        formErrorMessage = nil
        isShowingWorkoutEntrySheet = true
    }

    func dismissAddWorkout() {
        formErrorMessage = nil
        isShowingWorkoutEntrySheet = false
    }

    // MARK: Mutations

    func addWorkout(_ formState: WorkoutEntryFormState) async {
        do {
            let draft = try formState.makeDraft()
            _ = try workoutLogService.addWorkout(draft, date: Date())
            dismissAddWorkout()
            await refresh()
            refreshCenter.notifyDataChanged()
        } catch let error as TrainingFormError {
            formErrorMessage = error.message
        } catch ServiceError.invalidInput(let message) {
            formErrorMessage = message
        } catch {
            formErrorMessage = "Could not save workout."
        }
    }

    func deleteWorkout(id: UUID) async {
        do {
            try workoutLogService.deleteWorkout(id: id)
            if selectedWorkout?.id == id {
                selectedWorkout = nil
            }
            await refresh()
            refreshCenter.notifyDataChanged()
        } catch {
            viewState = .error("Could not delete workout.")
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
        // Touch these dependencies so the model owns the intended service seam,
        // while all actual workout state still flows through WorkoutLogService.
        _ = try? dailyLogService.getLog(for: Date())
        _ = try? userProfileService.getCurrentProfile()

        let todaysWorkouts = try workoutLogService.getWorkouts(for: Date())
        let recentWorkouts = try workoutLogService.getWorkoutHistory(days: recentRangeDays)

        let todaysItems = try todaysWorkouts.map { try makeDisplayItem(from: $0) }
        let recentItems = try recentWorkouts.map { try makeDisplayItem(from: $0) }

        let todayVolume = todaysItems.reduce(0.0) { $0 + ($1.totalVolumeKg ?? 0) }
        let todayCalories = todaysWorkouts.reduce(0) { $0 + ($1.estimatedCaloriesBurned ?? 0) }

        return TrainingDashboardState(
            selectedDate: Date(),
            todaysWorkouts: todaysItems,
            recentWorkouts: recentItems,
            summary: TrainingSummary(
                workoutCountToday: todaysItems.count,
                workoutCountInRecentRange: recentItems.count,
                estimatedCaloriesBurnedToday: todayCalories,
                totalVolumeTodayKg: todayVolume > 0 ? todayVolume : nil
            )
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
}
