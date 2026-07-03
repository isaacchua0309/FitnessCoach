//
//  HealthDailySummarySyncPayload.swift
//  Fitness Coach
//
//  Forma — Normalized daily activity rollup for remote Health Summary Sync.
//
//  Privacy boundary: rolled-up steps, energy, exercise minutes, and workout
//  aggregates only. No step samples, heart rate, sleep, or raw HealthKit metadata.
//
//  Firestore: `/users/{uid}/healthDaily/{yyyy-MM-dd}`
//

import Foundation

struct HealthDailySummarySyncPayload: Equatable, Sendable, Codable {
    let id: String
    let userId: String
    let localDate: String
    let timezone: String
    let generatedAt: String
    let source: HealthSummarySyncSource
    let confidence: HealthSyncConfidence
    let missingSignals: [String]
    let schemaVersion: Int

    let date: String
    let steps: Int?
    let activeEnergyKcal: Double?
    let exerciseMinutes: Double?
    let workoutCount: Int
    let totalWorkoutMinutes: Int
    let totalWorkoutActiveEnergyKcal: Double?

    var firestorePath: String {
        HealthSummarySyncFirestorePath.daily(userId: userId, documentID: id)
    }
}

extension HealthDailySummarySyncPayload {

    /// Maps normalized daily metrics and same-day workouts into a remote sync payload.
    ///
    /// - Parameters:
    ///   - metrics: Normalized daily rollup (no raw HealthKit samples).
    ///   - dayWorkouts: Workouts whose `startDate` falls on the metrics local day.
    ///   - context: Shared sync mapping context including authenticated user id.
    ///   - confidence: Overall confidence for the daily rollup.
    ///   - missingSignals: Signal tokens unavailable for this day (names only).
    static func make(
        from metrics: DailyHealthMetrics,
        dayWorkouts: [NormalizedWorkout],
        context: HealthSummarySyncMappingContext,
        confidence: HealthSyncConfidence = .moderate,
        missingSignals: [HealthDailySummaryMissingSignal] = []
    ) -> HealthDailySummarySyncPayload {
        let calendar = context.calendar
        let day = calendar.startOfDay(for: metrics.date)
        let localDate = HealthSummarySyncFormatting.localDateString(from: day, calendar: calendar)
        let documentID = HealthSummarySyncDocumentID.daily(localDate: day, calendar: calendar)
        let missing = missingSignals.map(\.rawValue)

        let workoutCount = dayWorkouts.count
        let totalWorkoutMinutes = dayWorkouts.reduce(0) { $0 + max($1.durationMinutes, 0) }
        let totalWorkoutActiveEnergyKcal = aggregateWorkoutActiveEnergy(from: dayWorkouts)

        return HealthDailySummarySyncPayload(
            id: documentID,
            userId: context.userId,
            localDate: localDate,
            timezone: context.timezoneIdentifier,
            generatedAt: HealthSummarySyncFormatting.iso8601UTCString(from: context.generatedAt),
            source: context.source,
            confidence: confidence,
            missingSignals: missing,
            schemaVersion: HealthSummarySyncSchemaVersion.current,
            date: localDate,
            steps: nullableIntValue(metrics.steps, missingSignal: .steps, missingSignals: missingSignals),
            activeEnergyKcal: nullableDoubleValue(
                metrics.activeEnergyKcal,
                missingSignal: .activeEnergy,
                missingSignals: missingSignals
            ),
            exerciseMinutes: nullableDoubleValue(
                metrics.exerciseMinutes,
                missingSignal: .exerciseMinutes,
                missingSignals: missingSignals
            ),
            workoutCount: workoutCount,
            totalWorkoutMinutes: totalWorkoutMinutes,
            totalWorkoutActiveEnergyKcal: totalWorkoutActiveEnergyKcal
        )
    }

    /// Convenience overload that filters workouts to the metrics day.
    static func make(
        from metrics: DailyHealthMetrics,
        workouts: [NormalizedWorkout],
        context: HealthSummarySyncMappingContext,
        confidence: HealthSyncConfidence = .moderate,
        missingSignals: [HealthDailySummaryMissingSignal] = []
    ) -> HealthDailySummarySyncPayload {
        let dayWorkouts = HealthSummarySyncFormatting.workouts(
            onLocalDay: metrics.date,
            from: workouts,
            calendar: context.calendar
        )
        return make(
            from: metrics,
            dayWorkouts: dayWorkouts,
            context: context,
            confidence: confidence,
            missingSignals: missingSignals
        )
    }

    // MARK: - Private

    private static func aggregateWorkoutActiveEnergy(from workouts: [NormalizedWorkout]) -> Double? {
        guard !workouts.isEmpty else { return nil }
        let energies = workouts.map(\.activeEnergyKcal).filter { $0 > 0 }
        guard !energies.isEmpty else { return nil }
        return energies.reduce(0, +)
    }

    private static func nullableIntValue(
        _ value: Int,
        missingSignal: HealthDailySummaryMissingSignal,
        missingSignals: [HealthDailySummaryMissingSignal]
    ) -> Int? {
        missingSignals.contains(missingSignal) ? nil : value
    }

    private static func nullableDoubleValue(
        _ value: Double,
        missingSignal: HealthDailySummaryMissingSignal,
        missingSignals: [HealthDailySummaryMissingSignal]
    ) -> Double? {
        missingSignals.contains(missingSignal) ? nil : value
    }
}
