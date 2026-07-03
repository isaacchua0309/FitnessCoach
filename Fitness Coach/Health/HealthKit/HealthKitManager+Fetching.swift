//
//  HealthKitManager+Fetching.swift
//  Fitness Coach
//
//  Forma — HealthKitManager read APIs.
//

import Foundation

#if canImport(HealthKit) && os(iOS)
import HealthKit

extension HealthKitManager {

    // MARK: - Daily metrics

    func fetchDailyMetrics(
        for date: Date,
        calendar: Calendar = .current
    ) async throws -> HealthDailyMetrics {
        try ensureHealthDataAvailable()

        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw HealthKitManagerError.queryFailed
        }

        async let steps = fetchStepsSum(from: dayStart, to: dayEnd)
        async let energy = fetchActiveEnergySum(from: dayStart, to: dayEnd)
        async let exercise = fetchExerciseMinutesSum(from: dayStart, to: dayEnd)

        return HealthDailyMetrics(
            date: dayStart,
            steps: try await steps,
            activeEnergyKcal: try await energy,
            exerciseMinutes: try await exercise
        )
    }

    func fetchDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) async throws -> [HealthDailyMetrics] {
        try ensureHealthDataAvailable()

        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        guard rangeStart <= rangeEnd else {
            return []
        }

        guard let queryEnd = calendar.date(byAdding: .day, value: 1, to: rangeEnd) else {
            throw HealthKitManagerError.queryFailed
        }

        let interval = DateComponents(day: 1)

        async let stepValues = fetchDailyQuantityCollection(
            signal: .stepCount,
            unit: HealthKitSampleMapper.stepCountUnit,
            startDate: rangeStart,
            endDate: queryEnd,
            anchorDate: rangeStart,
            interval: interval
        )
        async let energyValues = fetchDailyQuantityCollection(
            signal: .activeEnergyBurned,
            unit: HealthKitSampleMapper.activeEnergyUnit,
            startDate: rangeStart,
            endDate: queryEnd,
            anchorDate: rangeStart,
            interval: interval
        )
        async let exerciseValues = fetchDailyQuantityCollection(
            signal: .appleExerciseTime,
            unit: HealthKitSampleMapper.exerciseTimeUnit,
            startDate: rangeStart,
            endDate: queryEnd,
            anchorDate: rangeStart,
            interval: interval
        )

        let stepsByDay = dictionaryByDay(try await stepValues, calendar: calendar)
        let energyByDay = dictionaryByDay(try await energyValues, calendar: calendar)
        let exerciseByDay = dictionaryByDay(try await exerciseValues, calendar: calendar)

        var metrics: [HealthDailyMetrics] = []
        var cursor = rangeStart
        while cursor <= rangeEnd {
            let day = calendar.startOfDay(for: cursor)
            metrics.append(
                HealthDailyMetrics(
                    date: day,
                    steps: stepsByDay[day].map { Int($0.rounded()) },
                    activeEnergyKcal: energyByDay[day],
                    exerciseMinutes: exerciseByDay[day]
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return metrics
    }

    // MARK: - Workouts

    func fetchWorkouts(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthFetchedWorkout] {
        try ensureHealthDataAvailable()

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let samples = try await executeSampleQuery(
            sampleType: HKObjectType.workoutType(),
            startDate: startDate,
            endDate: endDate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        )

        return samples.compactMap { sample -> HealthFetchedWorkout? in
            guard let workout = sample as? HKWorkout else { return nil }
            return HealthKitSampleMapper.mapWorkout(workout)
        }
    }

    // MARK: - Sleep

    func fetchSleepRecords(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthSleepRecord] {
        try ensureHealthDataAvailable()

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        let samples = try await executeSampleQuery(
            sampleType: sleepType,
            startDate: startDate,
            endDate: endDate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        )

        return samples.compactMap { sample -> HealthSleepRecord? in
            guard let category = sample as? HKCategorySample else { return nil }
            return HealthKitSampleMapper.mapSleepSample(category)
        }
    }

    // MARK: - Heart

    func fetchHeartMetrics(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthHeartMetric] {
        try ensureHealthDataAvailable()

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        async let restingSamples = fetchQuantitySamples(
            signal: .restingHeartRate,
            startDate: startDate,
            endDate: endDate,
            sortDescriptors: [sort]
        )
        async let hrvSamples = fetchQuantitySamples(
            signal: .heartRateVariabilitySDNN,
            startDate: startDate,
            endDate: endDate,
            sortDescriptors: [sort]
        )

        let resting = try await restingSamples.map(HealthKitSampleMapper.mapRestingHeartRateSample)
        let hrv = try await hrvSamples.map(HealthKitSampleMapper.mapHRVSample)

        return (resting + hrv).sorted { $0.date < $1.date }
    }

    // MARK: - Body mass

    func fetchBodyMassRecords(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthBodyMassRecord] {
        try ensureHealthDataAvailable()

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        let samples = try await fetchQuantitySamples(
            signal: .bodyMass,
            startDate: startDate,
            endDate: endDate,
            sortDescriptors: [sort]
        )

        return samples.map(HealthKitSampleMapper.mapBodyMassSample)
    }

    // MARK: - Private helpers

    private func ensureHealthDataAvailable() throws {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.unavailable
        }
    }

    private func fetchStepsSum(from startDate: Date, to endDate: Date) async throws -> Int? {
        guard let quantityType = quantityType(for: .stepCount) else { return nil }
        let value = try await executeStatisticsSum(
            quantityType: quantityType,
            startDate: startDate,
            endDate: endDate,
            unit: HealthKitSampleMapper.stepCountUnit
        )
        guard let value else { return nil }
        return max(Int(value.rounded()), 0)
    }

    private func fetchActiveEnergySum(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let quantityType = quantityType(for: .activeEnergyBurned) else { return nil }
        let value = try await executeStatisticsSum(
            quantityType: quantityType,
            startDate: startDate,
            endDate: endDate,
            unit: HealthKitSampleMapper.activeEnergyUnit
        )
        guard let value, value > 0 else { return nil }
        return value
    }

    private func fetchExerciseMinutesSum(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let quantityType = quantityType(for: .appleExerciseTime) else { return nil }
        let value = try await executeStatisticsSum(
            quantityType: quantityType,
            startDate: startDate,
            endDate: endDate,
            unit: HealthKitSampleMapper.exerciseTimeUnit
        )
        guard let value, value > 0 else { return nil }
        return value
    }

    private func fetchDailyQuantityCollection(
        signal: HealthSignalKind,
        unit: HKUnit,
        startDate: Date,
        endDate: Date,
        anchorDate: Date,
        interval: DateComponents
    ) async throws -> [(Date, Double)] {
        guard let quantityType = quantityType(for: signal) else { return [] }
        return try await executeStatisticsCollection(
            quantityType: quantityType,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            unit: unit
        )
    }

    private func fetchQuantitySamples(
        signal: HealthSignalKind,
        startDate: Date,
        endDate: Date,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKQuantitySample] {
        guard let sampleType = HealthKitReadTypeRegistry.hkSampleType(for: signal) else {
            return []
        }

        let samples = try await executeSampleQuery(
            sampleType: sampleType,
            startDate: startDate,
            endDate: endDate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sortDescriptors
        )

        return samples.compactMap { $0 as? HKQuantitySample }
    }

    private func dictionaryByDay(
        _ values: [(Date, Double)],
        calendar: Calendar
    ) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for (date, value) in values {
            let day = calendar.startOfDay(for: date)
            result[day] = value
        }
        return result
    }
}

#endif
