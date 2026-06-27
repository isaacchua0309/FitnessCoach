//
//  WorkoutCalorieCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic workout volume, intensity, and burn estimation.
//

import Foundation

struct WorkoutCalorieCalculator {

    // MARK: Volume

    static func totalVolumeKg(from sets: [ExerciseSet]) -> Double {
        sets.reduce(0.0) { partial, set in
            guard let weight = set.weightKg else { return partial }
            return partial + (Double(set.reps) * weight)
        }
    }

    // MARK: Intensity

    static func estimateIntensity(durationMinutes: Int?, sets: [ExerciseSet]) -> WorkoutIntensity {
        let setCount = sets.count
        let duration = durationMinutes ?? 0

        // Combine training volume signals (set count) with session length.
        if setCount >= 18 || duration >= 75 {
            return .high
        }
        if setCount >= 9 || duration >= 40 {
            return .moderate
        }
        return .low
    }

    // MARK: Recovery

    static func estimateRecoveryDemand(intensity: WorkoutIntensity, sets: [ExerciseSet]) -> RecoveryDemand {
        let heavyLoad = sets.contains { ($0.weightKg ?? 0) > 0 && $0.reps <= 5 }

        switch intensity {
        case .high:
            return .high
        case .moderate:
            return heavyLoad ? .high : .moderate
        case .low:
            return heavyLoad ? .moderate : .low
        }
    }

    // MARK: Calorie Burn

    static func estimateCaloriesBurned(
        bodyWeightKg: Double,
        durationMinutes: Int?,
        intensity: WorkoutIntensity
    ) -> Int? {
        guard let durationMinutes, durationMinutes > 0, bodyWeightKg > 0 else { return nil }

        // MET-based estimate: kcal/min = MET * 3.5 * kg / 200.
        let met = metValue(for: intensity)
        let kcalPerMinute = met * 3.5 * bodyWeightKg / 200.0
        let total = kcalPerMinute * Double(durationMinutes)
        return Int(total.rounded())
    }

    // MARK: Combined

    static func calculate(
        workout: WorkoutEntry,
        sets: [ExerciseSet],
        bodyWeightKg: Double
    ) -> WorkoutCalculationResult {
        let volume = totalVolumeKg(from: sets)
        let intensity = workout.intensity
            ?? estimateIntensity(durationMinutes: workout.durationMinutes, sets: sets)
        let recovery = workout.recoveryDemand
            ?? estimateRecoveryDemand(intensity: intensity, sets: sets)
        let calories = workout.estimatedCaloriesBurned
            ?? estimateCaloriesBurned(
                bodyWeightKg: bodyWeightKg,
                durationMinutes: workout.durationMinutes,
                intensity: intensity
            )

        return WorkoutCalculationResult(
            estimatedVolumeKg: volume > 0 ? volume : nil,
            estimatedCaloriesBurned: calories,
            intensity: intensity,
            recoveryDemand: recovery
        )
    }

    // MARK: Helpers

    private static func metValue(for intensity: WorkoutIntensity) -> Double {
        switch intensity {
        case .low:
            return 3.5
        case .moderate:
            return 5.0
        case .high:
            return 6.5
        }
    }
}
