//
//  WorkoutEntryEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

extension WorkoutEntryEntity {

    convenience init(model: WorkoutEntry) {
        self.init(
            id: model.id,
            dailyLogId: model.dailyLogId,
            name: model.name,
            durationMinutes: model.durationMinutes,
            estimatedCaloriesBurned: model.estimatedCaloriesBurned,
            intensityRawValue: model.intensity?.rawValue,
            recoveryDemandRawValue: model.recoveryDemand?.rawValue,
            notes: model.notes,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    func toModel() -> WorkoutEntry {
        WorkoutEntry(
            id: id,
            dailyLogId: dailyLogId,
            name: name,
            durationMinutes: durationMinutes,
            estimatedCaloriesBurned: estimatedCaloriesBurned,
            intensity: intensityRawValue.flatMap { WorkoutIntensity(rawValue: $0) },
            recoveryDemand: recoveryDemandRawValue.flatMap { RecoveryDemand(rawValue: $0) },
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
