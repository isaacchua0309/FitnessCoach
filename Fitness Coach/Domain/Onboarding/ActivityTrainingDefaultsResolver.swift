//
//  ActivityTrainingDefaultsResolver.swift
//  Fitness Coach
//
//  Forma — Client-side training rhythm defaults from activity level.
//

import Foundation

struct TrainingRhythmDefaults: Equatable, Sendable {
    let trainingDaysPerWeek: Int
    let averageStepsPerDay: Int
}

struct ActivityTrainingDefaultsResolver: Equatable, Sendable {
    func defaults(for activityLevel: ActivityLevel) -> TrainingRhythmDefaults {
        switch activityLevel {
        case .sedentary:
            return TrainingRhythmDefaults(trainingDaysPerWeek: 0, averageStepsPerDay: 3000)
        case .lightlyActive:
            return TrainingRhythmDefaults(trainingDaysPerWeek: 1, averageStepsPerDay: 5000)
        case .moderatelyActive:
            return TrainingRhythmDefaults(trainingDaysPerWeek: 3, averageStepsPerDay: 7500)
        case .veryActive:
            return TrainingRhythmDefaults(trainingDaysPerWeek: 5, averageStepsPerDay: 10_000)
        case .athlete:
            return TrainingRhythmDefaults(trainingDaysPerWeek: 6, averageStepsPerDay: 12_000)
        }
    }
}

extension UserProfile {

    /// Uses stored rhythm values when present; falls back to activity-level defaults for legacy profiles.
    func resolvedTrainingRhythm(
        defaultsResolver: ActivityTrainingDefaultsResolver = ActivityTrainingDefaultsResolver()
    ) -> TrainingRhythmDefaults {
        let defaults = defaultsResolver.defaults(for: activityLevel)
        if averageSteps == 0, trainingFrequencyPerWeek == 0 {
            return defaults
        }
        return TrainingRhythmDefaults(
            trainingDaysPerWeek: trainingFrequencyPerWeek,
            averageStepsPerDay: averageSteps > 0 ? averageSteps : defaults.averageStepsPerDay
        )
    }
}
