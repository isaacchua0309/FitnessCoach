//
//  HealthSampleNormalizer.swift
//  Fitness Coach
//
//  Forma — Converts HealthKit-facing raw values into Forma domain models.
//

import Foundation

protocol HealthSampleNormalizing: Sendable {
    func normalize(day: HealthRawDayInput, calendar: Calendar) -> HealthNormalizedDayBundle
    func normalizeDailyMetrics(_ raw: HealthDailyMetrics) -> DailyHealthMetrics
    func normalizeWorkouts(_ raw: [HealthFetchedWorkout]) -> [NormalizedWorkout]
    func normalizeSleepRecords(_ raw: [HealthSleepRecord]) -> [NormalizedSleepRecord]
    func normalizeHeartMetrics(_ raw: [HealthHeartMetric]) -> [NormalizedHeartMetric]
    func normalizeBodyMassRecords(_ raw: [HealthBodyMassRecord]) -> [NormalizedBodyMass]
    func deduplicate(samples: [HealthNormalizedSample]) -> [HealthNormalizedSample]
}

struct HealthSampleNormalizer: HealthSampleNormalizing {

    func normalize(day: HealthRawDayInput, calendar: Calendar = .current) -> HealthNormalizedDayBundle {
        HealthNormalizedDayBundle(
            dailyMetrics: normalizeDailyMetrics(day.dailyMetrics, calendar: calendar),
            workouts: normalizeWorkouts(day.workouts),
            sleepRecords: normalizeSleepRecords(day.sleepRecords),
            heartMetrics: normalizeHeartMetrics(day.heartMetrics),
            bodyMassRecords: normalizeBodyMassRecords(day.bodyMassRecords)
        )
    }

    func normalizeDailyMetrics(_ raw: HealthDailyMetrics) -> DailyHealthMetrics {
        normalizeDailyMetrics(raw, calendar: .current)
    }

    func normalizeDailyMetrics(
        _ raw: HealthDailyMetrics,
        calendar: Calendar
    ) -> DailyHealthMetrics {
        let day = calendar.startOfDay(for: raw.date)
        return DailyHealthMetrics(
            date: day,
            steps: max(raw.steps ?? 0, 0),
            activeEnergyKcal: HealthQuantityNormalization.kilocalories(
                value: raw.activeEnergyKcal ?? 0,
                unitSymbol: HealthUnitSymbol.kilocalorie
            ),
            exerciseMinutes: HealthQuantityNormalization.minutes(
                value: raw.exerciseMinutes ?? 0,
                unitSymbol: HealthUnitSymbol.minutes
            )
        )
    }

    func normalizeWorkouts(_ raw: [HealthFetchedWorkout]) -> [NormalizedWorkout] {
        let mapped = raw.map(normalizeWorkout(_:))
        return deduplicateWorkouts(mapped)
    }

    func normalizeSleepRecords(_ raw: [HealthSleepRecord]) -> [NormalizedSleepRecord] {
        let mapped = raw.map(normalizeSleepRecord(_:))
        return deduplicateSleepRecords(mapped)
    }

    func normalizeHeartMetrics(_ raw: [HealthHeartMetric]) -> [NormalizedHeartMetric] {
        let mapped = raw.map(normalizeHeartMetric(_:))
        return deduplicateHeartMetrics(mapped)
    }

    func normalizeBodyMassRecords(_ raw: [HealthBodyMassRecord]) -> [NormalizedBodyMass] {
        let mapped = raw.map(normalizeBodyMassRecord(_:))
        return deduplicateBodyMassRecords(mapped)
    }

    func deduplicate(samples: [HealthNormalizedSample]) -> [HealthNormalizedSample] {
        var seen = Set<String>()
        var unique: [HealthNormalizedSample] = []
        unique.reserveCapacity(samples.count)

        let sorted = samples.sorted {
            if $0.startDate == $1.startDate {
                return $0.kind.rawValue < $1.kind.rawValue
            }
            return $0.startDate < $1.startDate
        }

        for sample in sorted {
            let key = dedupeKey(for: sample)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            unique.append(clamp(sample))
        }

        return unique
    }

    // MARK: - Single-record normalization

    func normalizeWorkout(_ raw: HealthFetchedWorkout) -> NormalizedWorkout {
        let category = HealthWorkoutCategoryMapping.category(for: raw.activityTypeName)
        let durationMinutes = max(raw.durationMinutes, 1)
        let activeEnergyKcal = HealthQuantityNormalization.kilocalories(
            value: raw.activeCaloriesKcal ?? 0,
            unitSymbol: HealthUnitSymbol.kilocalorie
        )
        let sourceName = sanitizedSourceName(raw.sourceName)
        let activityLabel = sanitizedActivityLabel(raw.activityTypeName)

        return NormalizedWorkout(
            id: HealthStableIdentifier.workoutID(
                sourceName: sourceName,
                startDate: raw.startDate,
                endDate: raw.endDate,
                durationMinutes: durationMinutes,
                category: category
            ),
            category: category,
            activityLabel: activityLabel,
            startDate: raw.startDate,
            endDate: raw.endDate,
            durationMinutes: durationMinutes,
            activeEnergyKcal: activeEnergyKcal,
            sourceName: sourceName
        )
    }

    func normalizeSleepRecord(_ raw: HealthSleepRecord) -> NormalizedSleepRecord {
        let asleepMinutes = HealthQuantityNormalization.minutes(
            value: raw.asleepDuration / 60.0,
            unitSymbol: HealthUnitSymbol.minutes
        )
        let inBedMinutes = raw.inBedDuration.map {
            HealthQuantityNormalization.minutes(
                value: $0 / 60.0,
                unitSymbol: HealthUnitSymbol.minutes
            )
        }

        return NormalizedSleepRecord(
            id: HealthStableIdentifier.sleepID(
                startDate: raw.startDate,
                endDate: raw.endDate,
                asleepMinutes: asleepMinutes,
                inBedMinutes: inBedMinutes
            ),
            startDate: raw.startDate,
            endDate: raw.endDate,
            asleepMinutes: asleepMinutes,
            inBedMinutes: inBedMinutes
        )
    }

    func normalizeHeartMetric(_ raw: HealthHeartMetric) -> NormalizedHeartMetric {
        let normalizedValue: Double
        let unitSymbol: String

        switch raw.kind {
        case .restingHeartRate:
            normalizedValue = HealthQuantityNormalization.beatsPerMinute(
                value: raw.value,
                unitSymbol: raw.unitSymbol
            )
            unitSymbol = HealthUnitSymbol.beatsPerMinute
        case .heartRateVariabilitySDNN:
            normalizedValue = HealthQuantityNormalization.milliseconds(
                value: raw.value,
                unitSymbol: raw.unitSymbol
            )
            unitSymbol = HealthUnitSymbol.milliseconds
        }

        return NormalizedHeartMetric(
            id: HealthStableIdentifier.heartMetricID(
                kind: raw.kind,
                date: raw.date,
                value: normalizedValue
            ),
            kind: raw.kind,
            date: raw.date,
            value: normalizedValue,
            unitSymbol: unitSymbol
        )
    }

    func normalizeBodyMassRecord(_ raw: HealthBodyMassRecord) -> NormalizedBodyMass {
        let valueKg = HealthQuantityNormalization.kilograms(
            value: raw.valueKg,
            unitSymbol: HealthUnitSymbol.kilograms
        )

        return NormalizedBodyMass(
            id: HealthStableIdentifier.bodyMassID(
                date: raw.date,
                valueKg: valueKg
            ),
            date: raw.date,
            valueKg: valueKg
        )
    }

    // MARK: - Deduplication

    func deduplicateWorkouts(_ workouts: [NormalizedWorkout]) -> [NormalizedWorkout] {
        var bestByID: [UUID: NormalizedWorkout] = [:]

        for workout in workouts {
            guard let existing = bestByID[workout.id] else {
                bestByID[workout.id] = workout
                continue
            }
            bestByID[workout.id] = preferredWorkout(existing, workout)
        }

        return bestByID.values.sorted { $0.startDate > $1.startDate }
    }

    func deduplicateSleepRecords(_ records: [NormalizedSleepRecord]) -> [NormalizedSleepRecord] {
        var bestByID: [UUID: NormalizedSleepRecord] = [:]

        for record in records {
            guard let existing = bestByID[record.id] else {
                bestByID[record.id] = record
                continue
            }
            bestByID[record.id] = preferredSleepRecord(existing, record)
        }

        return bestByID.values.sorted { $0.startDate < $1.startDate }
    }

    func deduplicateHeartMetrics(_ metrics: [NormalizedHeartMetric]) -> [NormalizedHeartMetric] {
        var bestByID: [UUID: NormalizedHeartMetric] = [:]

        for metric in metrics {
            if let existing = bestByID[metric.id] {
                bestByID[metric.id] = metric.date >= existing.date ? metric : existing
            } else {
                bestByID[metric.id] = metric
            }
        }

        return bestByID.values.sorted { $0.date < $1.date }
    }

    func deduplicateBodyMassRecords(_ records: [NormalizedBodyMass]) -> [NormalizedBodyMass] {
        var bestByID: [UUID: NormalizedBodyMass] = [:]

        for record in records {
            if let existing = bestByID[record.id] {
                bestByID[record.id] = record.date >= existing.date ? record : existing
            } else {
                bestByID[record.id] = record
            }
        }

        return bestByID.values.sorted { $0.date < $1.date }
    }

    // MARK: - Private

    private func preferredWorkout(_ lhs: NormalizedWorkout, _ rhs: NormalizedWorkout) -> NormalizedWorkout {
        if lhs.activeEnergyKcal == rhs.activeEnergyKcal {
            return lhs.durationMinutes >= rhs.durationMinutes ? lhs : rhs
        }
        return lhs.activeEnergyKcal >= rhs.activeEnergyKcal ? lhs : rhs
    }

    private func preferredSleepRecord(_ lhs: NormalizedSleepRecord, _ rhs: NormalizedSleepRecord) -> NormalizedSleepRecord {
        if lhs.asleepMinutes == rhs.asleepMinutes {
            return (lhs.inBedMinutes ?? 0) >= (rhs.inBedMinutes ?? 0) ? lhs : rhs
        }
        return lhs.asleepMinutes >= rhs.asleepMinutes ? lhs : rhs
    }

    private func sanitizedSourceName(_ sourceName: String?) -> String? {
        guard let sourceName else { return nil }
        let trimmed = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sanitizedActivityLabel(_ activityLabel: String) -> String {
        let trimmed = activityLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Workout" : trimmed
    }

    private func dedupeKey(for sample: HealthNormalizedSample) -> String {
        [
            sample.kind.rawValue,
            ISO8601DateFormatter().string(from: sample.startDate),
            ISO8601DateFormatter().string(from: sample.endDate),
            String(format: "%.3f", sample.value),
            sample.unitSymbol,
            sample.sourceBundleIdentifier ?? ""
        ].joined(separator: "|")
    }

    private func clamp(_ sample: HealthNormalizedSample) -> HealthNormalizedSample {
        let value: Double
        let unitSymbol: String

        switch sample.kind {
        case .stepCount:
            value = Double(HealthQuantityNormalization.stepCount(value: sample.value, unitSymbol: sample.unitSymbol))
            unitSymbol = HealthUnitSymbol.count
        case .activeEnergy:
            value = HealthQuantityNormalization.kilocalories(value: sample.value, unitSymbol: sample.unitSymbol)
            unitSymbol = HealthUnitSymbol.kilocalorie
        case .exerciseTime:
            value = HealthQuantityNormalization.minutes(value: sample.value, unitSymbol: sample.unitSymbol)
            unitSymbol = HealthUnitSymbol.minutes
        case .restingHeartRate:
            value = HealthQuantityNormalization.beatsPerMinute(value: sample.value, unitSymbol: sample.unitSymbol)
            unitSymbol = HealthUnitSymbol.beatsPerMinute
        case .heartRate:
            value = HealthQuantityNormalization.milliseconds(value: sample.value, unitSymbol: sample.unitSymbol)
            unitSymbol = HealthUnitSymbol.milliseconds
        case .sleep, .workout:
            value = HealthQuantityNormalization.minutes(value: sample.value, unitSymbol: sample.unitSymbol)
            unitSymbol = HealthUnitSymbol.minutes
        case .unknown:
            value = max(sample.value, 0)
            unitSymbol = sample.unitSymbol
        }

        return HealthNormalizedSample(
            id: sample.id,
            kind: sample.kind,
            startDate: sample.startDate,
            endDate: sample.endDate,
            value: value,
            unitSymbol: unitSymbol,
            sourceBundleIdentifier: sample.sourceBundleIdentifier
        )
    }
}

extension HealthSampleNormalizing {
    func normalize(day: HealthRawDayInput) -> HealthNormalizedDayBundle {
        normalize(day: day, calendar: .current)
    }
}
