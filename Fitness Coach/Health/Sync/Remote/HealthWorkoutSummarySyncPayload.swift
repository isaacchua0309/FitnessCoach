//
//  HealthWorkoutSummarySyncPayload.swift
//  Fitness Coach
//
//  Forma — Normalized workout summary for remote Health Summary Sync.
//
//  Privacy boundary: category, timing, duration, optional energy, intensity/demand,
//  and allowlisted source app name only. No workout titles, GPS routes, heart rate
//  series, or raw HealthKit UUIDs.
//
//  Firestore: `/users/{uid}/healthWorkouts/{workoutId}`
//

import Foundation

struct HealthWorkoutSummarySyncPayload: Equatable, Sendable, Codable {
    let id: String
    let userId: String
    let localDate: String
    let timezone: String
    let generatedAt: String
    let source: HealthSummarySyncSource
    let confidence: HealthSyncConfidence
    let missingSignals: [String]
    let schemaVersion: Int

    let workoutId: String
    let type: String
    let category: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let activeEnergyKcal: Double?
    let intensity: String
    let demand: String
    let sourceAppName: String?

    var firestorePath: String {
        HealthSummarySyncFirestorePath.workout(userId: userId, documentID: id)
    }
}

extension HealthWorkoutSummarySyncPayload {

    /// Maps a normalized workout record (or cache `WorkoutRecord` alias) into a remote sync payload.
    static func make(
        from workout: NormalizedWorkout,
        context: HealthSummarySyncMappingContext,
        intensity: WorkoutSummaryIntensity = .unknown,
        demand: WorkoutDemand = .unknown,
        confidence: HealthSyncConfidence = .moderate,
        missingSignals: [HealthDailySummaryMissingSignal] = []
    ) -> HealthWorkoutSummarySyncPayload {
        makePayload(
            from: workout,
            intensity: intensity,
            demand: demand,
            context: context,
            confidence: confidence,
            missingSignals: missingSignals
        )
    }

    /// Maps a normalized workout, optionally enriching intensity/demand from engine output.
    static func make(
        from workout: NormalizedWorkout,
        summary: WorkoutSummary?,
        context: HealthSummarySyncMappingContext,
        confidence: HealthSyncConfidence? = nil,
        missingSignals: [HealthDailySummaryMissingSignal] = []
    ) -> HealthWorkoutSummarySyncPayload {
        let resolvedConfidence = confidence ?? HealthSyncConfidence(
            workoutConfidence: summary?.confidence ?? .low
        )
        return makePayload(
            from: workout,
            intensity: summary?.intensity ?? .unknown,
            demand: summary?.demand ?? .unknown,
            context: context,
            confidence: resolvedConfidence,
            missingSignals: missingSignals
        )
    }

    // MARK: - Core mapper

    private static func makePayload(
        from workout: NormalizedWorkout,
        intensity: WorkoutSummaryIntensity,
        demand: WorkoutDemand,
        context: HealthSummarySyncMappingContext,
        confidence: HealthSyncConfidence,
        missingSignals: [HealthDailySummaryMissingSignal]
    ) -> HealthWorkoutSummarySyncPayload {
        let calendar = context.calendar
        let documentID = HealthSummarySyncDocumentID.workout(from: workout)
        let localDate = HealthSummarySyncFormatting.localDateString(
            from: workout.startDate,
            calendar: calendar
        )
        let activeEnergyKcal = resolveActiveEnergy(
            workout.activeEnergyKcal,
            missingSignals: missingSignals
        )

        return HealthWorkoutSummarySyncPayload(
            id: documentID,
            userId: context.userId,
            localDate: localDate,
            timezone: context.timezoneIdentifier,
            generatedAt: HealthSummarySyncFormatting.iso8601UTCString(from: context.generatedAt),
            source: context.source,
            confidence: confidence,
            missingSignals: missingSignals.map(\.rawValue),
            schemaVersion: HealthSummarySyncSchemaVersion.current,
            workoutId: documentID,
            type: workout.category.rawValue,
            category: workout.category.rawValue,
            startTime: HealthSummarySyncFormatting.iso8601UTCString(from: workout.startDate),
            endTime: HealthSummarySyncFormatting.iso8601UTCString(from: workout.endDate),
            durationMinutes: max(workout.durationMinutes, 0),
            activeEnergyKcal: activeEnergyKcal,
            intensity: intensity.rawValue,
            demand: demand.rawValue,
            sourceAppName: HealthSummarySyncSourceAppNameSanitizer.sanitize(workout.sourceName)
        )
    }

    private static func resolveActiveEnergy(
        _ value: Double,
        missingSignals: [HealthDailySummaryMissingSignal]
    ) -> Double? {
        if missingSignals.contains(.workoutCalories) {
            return nil
        }
        return value > 0 ? value : nil
    }
}
