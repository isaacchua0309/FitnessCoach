//
//  HealthNormalizedSampleDeriver.swift
//  Fitness Coach
//
//  Forma — Derives normalized samples from prefetched day bundles without extra HealthKit reads.
//

import Foundation

enum HealthNormalizedSampleDeriver {

    static func derive(
        from bundle: HealthNormalizedDayBundle,
        calendar: Calendar
    ) -> [HealthNormalizedSample] {
        var samples: [HealthNormalizedSample] = []
        let dayStart = calendar.startOfDay(for: bundle.dailyMetrics.date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let metrics = bundle.dailyMetrics
        if metrics.steps > 0 {
            samples.append(
                HealthNormalizedSample(
                    kind: .stepCount,
                    startDate: dayStart,
                    endDate: dayEnd,
                    value: Double(metrics.steps),
                    unitSymbol: HealthUnitSymbol.count
                )
            )
        }
        if metrics.activeEnergyKcal > 0 {
            samples.append(
                HealthNormalizedSample(
                    kind: .activeEnergy,
                    startDate: dayStart,
                    endDate: dayEnd,
                    value: metrics.activeEnergyKcal,
                    unitSymbol: HealthUnitSymbol.kilocalorie
                )
            )
        }
        if metrics.exerciseMinutes > 0 {
            samples.append(
                HealthNormalizedSample(
                    kind: .exerciseTime,
                    startDate: dayStart,
                    endDate: dayEnd,
                    value: metrics.exerciseMinutes,
                    unitSymbol: HealthUnitSymbol.minutes
                )
            )
        }

        for workout in bundle.workouts {
            samples.append(
                HealthNormalizedSample(
                    id: workout.id,
                    kind: .workout,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    value: Double(workout.durationMinutes),
                    unitSymbol: HealthUnitSymbol.minutes,
                    sourceBundleIdentifier: workout.sourceName
                )
            )
        }

        for metric in bundle.heartMetrics {
            let kind: HealthSampleKind = metric.kind == .restingHeartRate ? .restingHeartRate : .heartRate
            samples.append(
                HealthNormalizedSample(
                    id: metric.id,
                    kind: kind,
                    startDate: metric.date,
                    endDate: metric.date,
                    value: metric.value,
                    unitSymbol: metric.unitSymbol
                )
            )
        }

        for sleep in bundle.sleepRecords where sleep.asleepMinutes > 0 {
            samples.append(
                HealthNormalizedSample(
                    id: sleep.id,
                    kind: .sleep,
                    startDate: sleep.startDate,
                    endDate: sleep.endDate,
                    value: sleep.asleepMinutes,
                    unitSymbol: HealthUnitSymbol.minutes
                )
            )
        }

        return samples
    }
}
