//
//  HealthWorkoutActivityFormatter.swift
//  Fitness Coach
//
//  Forma — User-facing labels for workout activity names.
//

import Foundation

enum HealthWorkoutActivityFormatter {

    static func displayName(for activityName: String) -> String {
        let trimmed = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Workout" : trimmed
    }
}
