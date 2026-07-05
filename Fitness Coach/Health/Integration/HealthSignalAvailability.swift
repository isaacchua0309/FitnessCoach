//
//  HealthSignalAvailability.swift
//  Fitness Coach
//
//  Forma — Whether useful health data exists right now (distinct from permission state).
//

import Foundation

struct HealthSignalAvailability: Equatable, Sendable, Codable {
    var stepsAvailable: Bool
    var workoutsAvailable: Bool
    var sleepAvailable: Bool
    var hrvAvailable: Bool
    var restingHeartRateAvailable: Bool
    var activeEnergyAvailable: Bool
    var missingSignals: [HealthSignal]

    static let empty = HealthSignalAvailability(
        stepsAvailable: false,
        workoutsAvailable: false,
        sleepAvailable: false,
        hrvAvailable: false,
        restingHeartRateAvailable: false,
        activeEnergyAvailable: false,
        missingSignals: HealthSignal.allCases
    )

    var hasAnyAvailableData: Bool {
        stepsAvailable
            || workoutsAvailable
            || sleepAvailable
            || hrvAvailable
            || restingHeartRateAvailable
            || activeEnergyAvailable
    }

    var hasMissingSignals: Bool {
        !missingSignals.isEmpty
    }
}

enum HealthSignalAvailabilityResolver {

    static func resolve(from input: HealthIntegrationStatusInput) -> HealthSignalAvailability {
        let permission = input.permissionStatus
        let snapshot = input.snapshot
        let baseline = input.baseline
        let recovery = snapshot?.recovery

        let stepsReadable = permission?.access(for: .stepCount).isReadable == true
        let workoutsReadable = permission?.access(for: .workout).isReadable == true
        let sleepReadable = permission?.access(for: .sleepAnalysis).isReadable == true
        let hrvReadable = permission?.access(for: .heartRateVariabilitySDNN).isReadable == true
        let restingHRReadable = permission?.access(for: .restingHeartRate).isReadable == true
        let energyReadable = permission?.access(for: .activeEnergyBurned).isReadable == true

        let stepsAvailable = stepsReadable && (
            snapshot?.activity.steps != nil
                || (baseline?.averageSteps7d ?? 0) > 0
        )
        let workoutsAvailable = workoutsReadable && (
            snapshot?.workout?.hasWorkout == true
                || (baseline?.workoutDays28d ?? 0) > 0
        )
        let sleepAvailable = sleepReadable && (
            recovery?.missingSignals.contains(.sleep) == false
                || (baseline?.averageSleepDuration7d ?? 0) > 0
        )
        let hrvAvailable = hrvReadable && (
            recovery?.missingSignals.contains(.hrv) == false
                || baseline?.averageHRV28d != nil
        )
        let restingHeartRateAvailable = restingHRReadable && (
            recovery?.missingSignals.contains(.restingHeartRate) == false
                || baseline?.averageRestingHeartRate28d != nil
        )
        let activeEnergyAvailable = energyReadable && snapshot?.activity.activeEnergyKcal != nil

        var missingSignals: [HealthSignal] = []
        if stepsReadable, !stepsAvailable { missingSignals.append(.steps) }
        if workoutsReadable, !workoutsAvailable { missingSignals.append(.workouts) }
        if sleepReadable, !sleepAvailable { missingSignals.append(.sleep) }
        if hrvReadable, !hrvAvailable { missingSignals.append(.hrv) }
        if restingHRReadable, !restingHeartRateAvailable { missingSignals.append(.restingHeartRate) }
        if energyReadable, !activeEnergyAvailable { missingSignals.append(.activeEnergy) }

        return HealthSignalAvailability(
            stepsAvailable: stepsAvailable,
            workoutsAvailable: workoutsAvailable,
            sleepAvailable: sleepAvailable,
            hrvAvailable: hrvAvailable,
            restingHeartRateAvailable: restingHeartRateAvailable,
            activeEnergyAvailable: activeEnergyAvailable,
            missingSignals: missingSignals
        )
    }
}
