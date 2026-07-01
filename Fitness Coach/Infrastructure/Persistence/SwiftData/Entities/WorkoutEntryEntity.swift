//
//  WorkoutEntryEntity.swift
//  Fitness Coach
//
//  SwiftData entity for legacy on-device manual workouts.
//
//  Official training insights read from Apple Health. Retain this entity for
//  on-disk history until a future migration drops legacy manual workout rows.
//

import Foundation
import SwiftData

@Model
final class WorkoutEntryEntity {

    // MARK: Identity

    @Attribute(.unique) var id: UUID
    var dailyLogId: UUID

    // MARK: Description

    var name: String?
    var durationMinutes: Int?
    var estimatedCaloriesBurned: Int?
    var intensityRawValue: String?
    var recoveryDemandRawValue: String?
    var notes: String?

    // MARK: Metadata

    var createdAt: Date
    var updatedAt: Date

    // MARK: Relationships

    var dailyLog: DailyLogEntity?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSetEntity.workoutEntry)
    var exerciseSets: [ExerciseSetEntity]

    init(
        id: UUID,
        dailyLogId: UUID,
        name: String?,
        durationMinutes: Int?,
        estimatedCaloriesBurned: Int?,
        intensityRawValue: String?,
        recoveryDemandRawValue: String?,
        notes: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.dailyLogId = dailyLogId
        self.name = name
        self.durationMinutes = durationMinutes
        self.estimatedCaloriesBurned = estimatedCaloriesBurned
        self.intensityRawValue = intensityRawValue
        self.recoveryDemandRawValue = recoveryDemandRawValue
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.exerciseSets = []
    }
}
