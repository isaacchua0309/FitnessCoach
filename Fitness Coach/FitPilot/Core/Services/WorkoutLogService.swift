//
//  WorkoutLogService.swift
//  Fitness Coach
//
//  FitPilot AI — Owns workout and exercise set logging.
//

import Foundation
import SwiftData

@MainActor
final class WorkoutLogService {

    private let store: SwiftDataStore
    private let dailyLogService: DailyLogService
    private let userProfileService: UserProfileService

    init(
        store: SwiftDataStore,
        dailyLogService: DailyLogService,
        userProfileService: UserProfileService
    ) {
        self.store = store
        self.dailyLogService = dailyLogService
        self.userProfileService = userProfileService
    }

    // MARK: Create

    func addWorkout(_ draft: WorkoutDraft, date: Date) throws -> WorkoutEntry {
        try validate(draft)

        let log = try dailyLogService.getOrCreateLogEntity(for: date)
        let bodyWeightKg = try userProfileService.getCurrentProfile()?.currentWeightKg ?? 0
        let now = Date()
        let workoutId = UUID()

        let setModels: [ExerciseSet] = draft.exerciseSets.map { setDraft in
            ExerciseSet(
                id: UUID(),
                workoutEntryId: workoutId,
                exerciseName: setDraft.exerciseName,
                setNumber: setDraft.setNumber,
                reps: setDraft.reps,
                weightKg: setDraft.weightKg,
                rpe: setDraft.rpe,
                createdAt: now
            )
        }

        // Provisional workout used to drive calculator fill-in.
        let provisional = WorkoutEntry(
            id: workoutId,
            dailyLogId: log.id,
            name: draft.name,
            durationMinutes: draft.durationMinutes,
            estimatedCaloriesBurned: draft.estimatedCaloriesBurned,
            intensity: draft.intensity,
            recoveryDemand: draft.recoveryDemand,
            notes: draft.notes,
            createdAt: now,
            updatedAt: now
        )

        let result = WorkoutCalorieCalculator.calculate(
            workout: provisional,
            sets: setModels,
            bodyWeightKg: bodyWeightKg
        )

        let workout = WorkoutEntry(
            id: workoutId,
            dailyLogId: log.id,
            name: draft.name,
            durationMinutes: draft.durationMinutes,
            estimatedCaloriesBurned: draft.estimatedCaloriesBurned ?? result.estimatedCaloriesBurned,
            intensity: draft.intensity ?? result.intensity,
            recoveryDemand: draft.recoveryDemand ?? result.recoveryDemand,
            notes: draft.notes,
            createdAt: now,
            updatedAt: now
        )

        let workoutEntity = WorkoutEntryEntity(model: workout)
        workoutEntity.dailyLog = log
        try store.insert(workoutEntity)

        for setModel in setModels {
            let setEntity = ExerciseSetEntity(model: setModel)
            setEntity.workoutEntry = workoutEntity
            try store.insert(setEntity)
        }

        try dailyLogService.recalculateDailyTotals(for: log.date)
        return workoutEntity.toModel()
    }

    // MARK: Delete

    func deleteWorkout(id: UUID) throws {
        guard let entity = try workoutEntity(id: id) else {
            throw ServiceError.workoutEntryNotFound
        }
        let logDate = entity.dailyLog?.date
        try store.delete(entity)
        if let logDate {
            try dailyLogService.recalculateDailyTotals(for: logDate)
        }
    }

    // MARK: Read

    func getWorkouts(for date: Date) throws -> [WorkoutEntry] {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return []
        }
        return log.workoutEntries
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toModel() }
    }

    func getWorkoutHistory(days: Int) throws -> [WorkoutEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -max(days, 0), to: Date()) ?? Date.distantPast
        let descriptor = FetchDescriptor<WorkoutEntryEntity>(
            predicate: #Predicate { $0.createdAt >= cutoff },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try store.fetch(descriptor).map { $0.toModel() }
    }

    func getExerciseSets(for workoutId: UUID) throws -> [ExerciseSet] {
        guard let workout = try workoutEntity(id: workoutId) else {
            throw ServiceError.workoutEntryNotFound
        }
        return workout.exerciseSets
            .sorted {
                if $0.exerciseName == $1.exerciseName {
                    return $0.setNumber < $1.setNumber
                }
                return $0.exerciseName < $1.exerciseName
            }
            .map { $0.toModel() }
    }

    func getWorkoutDetail(id: UUID) throws -> (workout: WorkoutEntry, sets: [ExerciseSet])? {
        guard let workout = try workoutEntity(id: id) else {
            return nil
        }
        let sets = workout.exerciseSets
            .sorted {
                if $0.exerciseName == $1.exerciseName {
                    return $0.setNumber < $1.setNumber
                }
                return $0.exerciseName < $1.exerciseName
            }
            .map { $0.toModel() }
        return (workout.toModel(), sets)
    }

    // MARK: Helpers

    private func workoutEntity(id: UUID) throws -> WorkoutEntryEntity? {
        var descriptor = FetchDescriptor<WorkoutEntryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    private func validate(_ draft: WorkoutDraft) throws {
        if let duration = draft.durationMinutes {
            guard duration > 0 else { throw ServiceError.invalidInput("Duration must be greater than zero.") }
        }
        for set in draft.exerciseSets {
            let trimmed = set.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ServiceError.invalidInput("Exercise name cannot be empty.") }
            guard set.reps > 0 else { throw ServiceError.invalidInput("Reps must be greater than zero.") }
        }
    }

    private func save() throws {
        do {
            try store.save()
        } catch {
            throw ServiceError.persistenceFailed("Could not save the workout.")
        }
    }
}
