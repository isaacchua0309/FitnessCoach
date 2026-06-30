//
//  HealthWorkoutActivityFormatter.swift
//  Fitness Coach
//
//  Forma — User-facing labels for HealthKit workout activity types.
//

import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

enum HealthWorkoutActivityFormatter {

    static func displayName(for activityName: String) -> String {
        let trimmed = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Workout" : trimmed
    }

    #if canImport(HealthKit)
    static func displayName(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return "Strength training"
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .yoga:
            return "Yoga"
        case .swimming:
            return "Swimming"
        case .coreTraining:
            return "Core training"
        case .elliptical:
            return "Elliptical"
        case .rowing:
            return "Rowing"
        case .stairClimbing:
            return "Stair climbing"
        case .mixedCardio:
            return "Mixed cardio"
        case .pilates:
            return "Pilates"
        case .cooldown:
            return "Cooldown"
        case .flexibility:
            return "Flexibility"
        default:
            return "Workout"
        }
    }
    #endif
}
