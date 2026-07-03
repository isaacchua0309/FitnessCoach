//
//  HealthKitSampleMapper.swift
//  Fitness Coach
//
//  Forma — Maps HealthKit samples to Health Intelligence records (no I/O).
//

import Foundation

#if canImport(HealthKit)
import HealthKit

enum HealthKitSampleMapper {

    static var stepCountUnit: HKUnit { .count() }
    static var activeEnergyUnit: HKUnit { .kilocalorie() }
    static var exerciseTimeUnit: HKUnit { .minute() }
    static var restingHeartRateUnit: HKUnit { .count().unitDivided(by: .minute()) }
    static var hrvSDNNUnit: HKUnit { .secondUnit(with: .milli) }
    static var bodyMassUnit: HKUnit { .gramUnit(with: .kilo) }

    // MARK: - Workouts

    static func mapWorkout(_ workout: HKWorkout) -> HealthFetchedWorkout {
        let durationMinutes = max(Int((workout.duration / 60.0).rounded()), 1)
        let calories = activeCaloriesKcal(from: workout)
        let sourceName = sanitizedSourceName(workout.sourceRevision.source.name)

        return HealthFetchedWorkout(
            id: workout.uuid,
            activityTypeName: displayName(for: workout.workoutActivityType),
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationMinutes: durationMinutes,
            activeCaloriesKcal: calories,
            sourceName: sourceName
        )
    }

    private static func activeCaloriesKcal(from workout: HKWorkout) -> Double? {
        let energyType = HKQuantityType(.activeEnergyBurned)
        guard let quantity = workout.statistics(for: energyType)?.sumQuantity() else {
            return nil
        }
        let kcal = quantity.doubleValue(for: activeEnergyUnit)
        return kcal > 0 ? kcal : nil
    }

    // MARK: - Sleep

    static func mapSleepSample(_ sample: HKCategorySample) -> HealthSleepRecord? {
        let duration = sample.endDate.timeIntervalSince(sample.startDate)
        guard duration > 0 else { return nil }

        switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
        case .inBed:
            return HealthSleepRecord(
                id: sample.uuid,
                startDate: sample.startDate,
                endDate: sample.endDate,
                asleepDuration: 0,
                inBedDuration: duration
            )
        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
            return HealthSleepRecord(
                id: sample.uuid,
                startDate: sample.startDate,
                endDate: sample.endDate,
                asleepDuration: duration,
                inBedDuration: nil
            )
        case .awake, .none:
            return nil
        @unknown default:
            return nil
        }
    }

    // MARK: - Heart

    static func mapRestingHeartRateSample(_ sample: HKQuantitySample) -> HealthHeartMetric {
        HealthHeartMetric(
            id: sample.uuid,
            kind: .restingHeartRate,
            date: sample.startDate,
            value: sample.quantity.doubleValue(for: restingHeartRateUnit),
            unitSymbol: HealthUnitSymbol.beatsPerMinute
        )
    }

    static func mapHRVSample(_ sample: HKQuantitySample) -> HealthHeartMetric {
        HealthHeartMetric(
            id: sample.uuid,
            kind: .heartRateVariabilitySDNN,
            date: sample.startDate,
            value: sample.quantity.doubleValue(for: hrvSDNNUnit),
            unitSymbol: HealthUnitSymbol.milliseconds
        )
    }

    // MARK: - Body mass

    static func mapBodyMassSample(_ sample: HKQuantitySample) -> HealthBodyMassRecord {
        HealthBodyMassRecord(
            id: sample.uuid,
            date: sample.startDate,
            valueKg: sample.quantity.doubleValue(for: bodyMassUnit)
        )
    }

    // MARK: - Activity names

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

    // MARK: - Private

    private static func sanitizedSourceName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#endif
