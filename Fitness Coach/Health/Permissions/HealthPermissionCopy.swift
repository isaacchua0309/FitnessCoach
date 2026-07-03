//
//  HealthPermissionCopy.swift
//  Fitness Coach
//
//  Forma — User-facing copy for Apple Health permission surfaces (not wired to UI yet).
//

import Foundation

enum HealthPermissionCopy {

    /// Mirrors `NSHealthShareUsageDescription` — keep in sync with Info.plist.
    static let healthShareUsageDescription =
        "Forma reads steps, workouts, active energy, exercise time, sleep, heart rate and variability, and weight from Apple Health to show activity on Today, training insights, recovery guidance, and plan confidence. Forma does not write to Apple Health."

    static let onboardingSummary =
        "Connect Apple Health to bring in steps, workouts, sleep, heart signals, and weight for smarter daily guidance."

    static let settingsExplanation =
        "Manage which health signals Forma can read. Training and Today stay useful even if you connect only part of Apple Health."

    static let partialAccessExplanation =
        "Some Apple Health categories are connected. You can enable more anytime in the Health app."

    static let deniedExplanation =
        "Apple Health access is turned off for one or more categories. Open the Health app to adjust permissions for Forma."

    static func signalLabel(for signal: HealthSignalKind) -> String {
        switch signal {
        case .stepCount:
            return "Steps"
        case .activeEnergyBurned:
            return "Active energy"
        case .appleExerciseTime:
            return "Exercise minutes"
        case .workout:
            return "Workouts"
        case .restingHeartRate:
            return "Resting heart rate"
        case .heartRateVariabilitySDNN:
            return "Heart rate variability"
        case .sleepAnalysis:
            return "Sleep"
        case .bodyMass:
            return "Weight"
        case .walkingHeartRateAverage:
            return "Walking heart rate"
        case .vo2Max:
            return "VO₂ max"
        case .distanceWalkingRunning:
            return "Walking and running distance"
        case .appleStandTime:
            return "Stand time"
        }
    }

    static func signalDetail(for signal: HealthSignalKind) -> String {
        switch signal {
        case .stepCount:
            return "Daily step count on Today."
        case .activeEnergyBurned:
            return "Calories burned during activity."
        case .appleExerciseTime:
            return "Exercise minutes recorded in Apple Health."
        case .workout:
            return "Completed workouts for training insights and Today."
        case .restingHeartRate:
            return "Recovery and readiness context."
        case .heartRateVariabilitySDNN:
            return "Recovery trend context from HRV."
        case .sleepAnalysis:
            return "Sleep duration and timing for recovery guidance."
        case .bodyMass:
            return "Body weight trends alongside your plan."
        case .walkingHeartRateAverage:
            return "Future cardio load context."
        case .vo2Max:
            return "Future cardio fitness context."
        case .distanceWalkingRunning:
            return "Future activity distance context."
        case .appleStandTime:
            return "Future movement context."
        }
    }
}
