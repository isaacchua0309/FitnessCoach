//
//  ExerciseSetEntity.swift
//  Fitness Coach
//
//  V2 MIGRATION ONLY — listed in `FormaSchemaV2` for lightweight migration to v3.
//  Removed from active `FormaSchemaV3` schema.
//
//  Official training insights read from Apple Health. Retain until migration
//  retires manual workout storage.
//

import Foundation
import SwiftData

@Model
final class ExerciseSetEntity {

    @Attribute(.unique) var id: UUID
    var workoutEntryId: UUID
    var exerciseName: String
    var setNumber: Int
    var reps: Int
    var weightKg: Double?
    var rpe: Double?
    var createdAt: Date

    // MARK: Relationships

    var workoutEntry: WorkoutEntryEntity?

    init(
        id: UUID,
        workoutEntryId: UUID,
        exerciseName: String,
        setNumber: Int,
        reps: Int,
        weightKg: Double?,
        rpe: Double?,
        createdAt: Date
    ) {
        self.id = id
        self.workoutEntryId = workoutEntryId
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.rpe = rpe
        self.createdAt = createdAt
    }
}
