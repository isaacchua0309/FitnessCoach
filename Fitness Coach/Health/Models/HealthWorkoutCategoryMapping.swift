//
//  HealthWorkoutCategoryMapping.swift
//  Fitness Coach
//
//  Forma — Maps activity labels into Forma workout categories.
//

import Foundation

enum HealthWorkoutCategoryMapping {

    static func category(for activityLabel: String) -> FormaWorkoutCategory {
        let normalized = activityLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return .other
        }

        if matches(normalized, any: ["strength", "weight training", "functional training"]) {
            return .strength
        }
        if matches(normalized, any: ["running", "run", "jog", "jogging", "treadmill run"]) {
            return .running
        }
        if matches(normalized, any: ["walking", "walk", "hike", "hiking"]) {
            return .walking
        }
        if matches(normalized, any: ["cycling", "cycle", "bike", "biking", "spin"]) {
            return .cycling
        }
        if matches(normalized, any: ["swimming", "swim"]) {
            return .swimming
        }
        if matches(normalized, any: ["yoga", "pilates"]) {
            return .yoga
        }
        if matches(normalized, any: ["hiit", "high intensity", "interval"]) {
            return .hiit
        }

        return .other
    }

    // MARK: - Private

    private static func matches(_ value: String, any candidates: [String]) -> Bool {
        candidates.contains { candidate in
            value == candidate || value.contains(candidate)
        }
    }
}
