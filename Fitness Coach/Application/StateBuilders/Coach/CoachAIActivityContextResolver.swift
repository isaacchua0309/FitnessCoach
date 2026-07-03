//
//  CoachAIActivityContextResolver.swift
//  Fitness Coach
//
//  Resolves Coach AI activity signals from Health Intelligence snapshots with
//  HealthActivityQueryService fallback. Avoids duplicate HealthKit reads when
//  a snapshot is already available.
//

import Foundation

struct CoachAIActivityContext: Equatable, Sendable {
    var workoutsToday: Int = 0
    var hasWorkoutToday: Bool = false
    var stepsOverride: Int?
    var healthIntelligence: CoachHealthIntelligenceContext?
    var healthIntelligenceAwarenessAvailable: Bool = false
    var sourceSnapshot: HealthIntelligenceSnapshot?
}

enum CoachAIActivityContextResolver {

    struct ResolveInput: Equatable, Sendable {
        var availability: HealthDataAvailability?
        var baseline: HealthBaselineContext?
        var lastHealthSyncAt: Date?
        var isAppleHealthConnected: Bool = false
        var syncPhase: HealthSyncPhase? = nil
        var remoteSyncConsentDecision: HealthSummarySyncConsentDecision = .notDetermined
        var isRemoteSyncCapabilityEnabled: Bool = false
    }

    static func resolve(
        date: Date = Date(),
        snapshotProvider: (any HealthIntelligenceSnapshotServing)?,
        healthActivityQuery: HealthActivityQueryService,
        loadHealthIntelligence: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence },
        resolveInput: ResolveInput = ResolveInput(),
        calendar: Calendar = .current
    ) async -> CoachAIActivityContext {
        if loadHealthIntelligence(), let snapshotProvider {
            let snapshot = await snapshotProvider.loadTodaySnapshot(for: date, calendar: calendar)
            if let snapshot {
                HealthIntelligenceEngineLogger.event(
                    "Coach activity context resolved",
                    fields: [
                        "resolveSource": "snapshot",
                        "recoveryStatus": snapshot.recovery.status.rawValue,
                        "missingSignalCount": String(snapshot.recovery.missingSignals.count)
                    ]
                )
                return context(
                    from: snapshot,
                    resolveInput: resolveInput,
                    calendar: calendar
                )
            }

            HealthIntelligenceEngineLogger.event(
                "Coach activity context resolved",
                fields: ["resolveSource": "fallback_query"]
            )
            let training = await healthActivityQuery.dailyTrainingActivity(on: date, calendar: calendar)
            return CoachAIActivityContext(
                workoutsToday: training.workoutCount,
                hasWorkoutToday: training.hasWorkout,
                stepsOverride: nil,
                healthIntelligence: unavailableHealthContext(
                    date: date,
                    resolveInput: resolveInput,
                    calendar: calendar
                ),
                healthIntelligenceAwarenessAvailable: false
            )
        }

        HealthIntelligenceEngineLogger.event(
            "Coach activity context resolved",
            fields: ["resolveSource": "disabled"]
        )
        let training = await healthActivityQuery.dailyTrainingActivity(on: date, calendar: calendar)
        return CoachAIActivityContext(
            workoutsToday: training.workoutCount,
            hasWorkoutToday: training.hasWorkout,
            stepsOverride: nil,
            healthIntelligence: CoachHealthIntelligenceContext.unavailable(
                for: calendar.startOfDay(for: date),
                lastHealthSyncAt: resolveInput.lastHealthSyncAt
            ),
            healthIntelligenceAwarenessAvailable: false
        )
    }

    static func healthIntelligenceAwarenessAvailable(
        snapshot: HealthIntelligenceSnapshot,
        healthIntelligence: CoachHealthIntelligenceContext
    ) -> Bool {
        if snapshot.nextBestAction.reason == .connectHealth,
           !snapshot.nextBestAction.id.isEmpty {
            return false
        }

        let missingCoreRecoverySignals = snapshot.recovery.missingSignals.contains(.sleep)
            && (snapshot.recovery.missingSignals.contains(.hrv)
                || snapshot.recovery.missingSignals.contains(.restingHeartRate))

        if snapshot.recovery.status == .unknown,
           snapshot.recovery.confidence == .unknown || snapshot.recovery.confidence == .low,
           missingCoreRecoverySignals,
           snapshot.activity.steps == nil,
           snapshot.workout?.hasWorkout != true {
            return false
        }

        _ = healthIntelligence
        return true
    }

    private static func context(
        from snapshot: HealthIntelligenceSnapshot,
        resolveInput: ResolveInput,
        calendar: Calendar
    ) -> CoachAIActivityContext {
        let provisional = CoachHealthIntelligenceContextBuilder.build(
            from: snapshot,
            input: CoachHealthIntelligenceContextBuilder.BuildInput(
                availability: resolveInput.availability,
                baseline: resolveInput.baseline,
                lastHealthSyncAt: resolveInput.lastHealthSyncAt,
                isAppleHealthConnected: resolveInput.isAppleHealthConnected,
                syncPhase: resolveInput.syncPhase,
                remoteSyncConsentDecision: resolveInput.remoteSyncConsentDecision,
                isRemoteSyncCapabilityEnabled: resolveInput.isRemoteSyncCapabilityEnabled,
                awarenessAvailable: true
            ),
            calendar: calendar
        )

        let awareness = healthIntelligenceAwarenessAvailable(
            snapshot: snapshot,
            healthIntelligence: provisional
        )

        let healthIntelligence = CoachHealthIntelligenceContextBuilder.build(
            from: snapshot,
            input: CoachHealthIntelligenceContextBuilder.BuildInput(
                availability: resolveInput.availability,
                baseline: resolveInput.baseline,
                lastHealthSyncAt: resolveInput.lastHealthSyncAt,
                isAppleHealthConnected: resolveInput.isAppleHealthConnected,
                syncPhase: resolveInput.syncPhase,
                remoteSyncConsentDecision: resolveInput.remoteSyncConsentDecision,
                isRemoteSyncCapabilityEnabled: resolveInput.isRemoteSyncCapabilityEnabled,
                awarenessAvailable: awareness
            ),
            calendar: calendar
        )

        return CoachAIActivityContext(
            workoutsToday: healthIntelligence.workoutCompletedToday
                ? max(snapshot.workout?.workoutCount ?? 1, 1)
                : 0,
            hasWorkoutToday: healthIntelligence.workoutCompletedToday,
            stepsOverride: healthIntelligence.stepsToday,
            healthIntelligence: healthIntelligence,
            healthIntelligenceAwarenessAvailable: awareness,
            sourceSnapshot: snapshot
        )
    }

    private static func unavailableHealthContext(
        date: Date,
        resolveInput: ResolveInput,
        calendar: Calendar
    ) -> CoachHealthIntelligenceContext {
        CoachHealthIntelligenceContext.unavailable(
            for: calendar.startOfDay(for: date),
            lastHealthSyncAt: resolveInput.lastHealthSyncAt,
            missingSignals: CoachHealthContextStatusResolver.missingSignalLabels(
                from: CoachHealthContextStatusResolver.Input(
                    snapshot: nil,
                    availability: resolveInput.availability,
                    baseline: resolveInput.baseline,
                    lastHealthSyncAt: resolveInput.lastHealthSyncAt,
                    isAppleHealthConnected: resolveInput.isAppleHealthConnected,
                    syncPhase: resolveInput.syncPhase,
                    remoteSyncConsentDecision: resolveInput.remoteSyncConsentDecision,
                    isRemoteSyncCapabilityEnabled: resolveInput.isRemoteSyncCapabilityEnabled,
                    awarenessAvailable: false
                )
            )
        )
    }
}
