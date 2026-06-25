//
//  TrainingFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight Training display formatting.
//
//  Formatting only. No service calls, AI, SwiftData, or persistence.
//

import Foundation

enum TrainingFormatter {
    static func workoutName(_ workout: WorkoutEntry) -> String {
        let trimmed = workout.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Workout" : trimmed
    }

    static func duration(_ minutes: Int?) -> String? {
        guard let minutes else { return nil }
        return "\(minutes) min"
    }

    static func calories(_ calories: Int?) -> String? {
        guard let calories else { return nil }
        return "\(calories) kcal"
    }

    static func kg(_ value: Double?) -> String {
        guard let value else { return "--" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : "\(String(format: "%.1f", value)) kg"
    }

    static func volume(_ value: Double?) -> String {
        guard let value, value > 0 else { return "--" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : "\(String(format: "%.1f", value)) kg"
    }

    static func rpe(_ value: Double?) -> String? {
        guard let value else { return nil }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "RPE \(Int(value))"
            : "RPE \(String(format: "%.1f", value))"
    }

    static func intensity(_ intensity: WorkoutIntensity?) -> String? {
        guard let intensity else { return nil }
        switch intensity {
        case .low:
            return "Low"
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        }
    }

    static func recovery(_ demand: RecoveryDemand?) -> String? {
        guard let demand else { return nil }
        switch demand {
        case .low:
            return "Low recovery"
        case .moderate:
            return "Moderate recovery"
        case .high:
            return "High recovery"
        }
    }

    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func setLine(_ set: ExerciseSet) -> String {
        var parts = ["Set \(set.setNumber)", "\(set.reps) reps"]
        if let weight = set.weightKg {
            parts.append(kg(weight))
        }
        if let rpe = rpe(set.rpe) {
            parts.append(rpe)
        }
        return parts.joined(separator: " · ")
    }
}
