//
//  ExerciseSetEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

extension ExerciseSetEntity {

    convenience init(model: ExerciseSet) {
        self.init(
            id: model.id,
            workoutEntryId: model.workoutEntryId,
            exerciseName: model.exerciseName,
            setNumber: model.setNumber,
            reps: model.reps,
            weightKg: model.weightKg,
            rpe: model.rpe,
            createdAt: model.createdAt
        )
    }

    func toModel() -> ExerciseSet {
        ExerciseSet(
            id: id,
            workoutEntryId: workoutEntryId,
            exerciseName: exerciseName,
            setNumber: setNumber,
            reps: reps,
            weightKg: weightKg,
            rpe: rpe,
            createdAt: createdAt
        )
    }
}
