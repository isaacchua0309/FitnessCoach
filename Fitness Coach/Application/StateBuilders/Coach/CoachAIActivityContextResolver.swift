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

    static func resolve(
        date: Date = Date(),
        snapshotProvider: (any HealthIntelligenceSnapshotServing)?,
        healthActivityQuery: HealthActivityQueryService,
        loadHealthIntelligence: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence },
        calendar: Calendar = .current
    ) async -> CoachAIActivityContext {
        if loadHealthIntelligence(), let snapshotProvider {
            let snapshot = await snapshotProvider.loadTodaySnapshot(for: date, calendar: calendar)
            if let snapshot {
                return context(from: snapshot, calendar: calendar)
            }
        }

        let training = await healthActivityQuery.dailyTrainingActivity(on: date, calendar: calendar)
        return CoachAIActivityContext(
            workoutsToday: training.workoutCount,
            hasWorkoutToday: training.hasWorkout,
            stepsOverride: nil,
            healthIntelligence: nil,
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
        calendar: Calendar
    ) -> CoachAIActivityContext {
        let healthIntelligence = CoachHealthIntelligenceContextBuilder.build(from: snapshot)
        let awareness = healthIntelligenceAwarenessAvailable(
            snapshot: snapshot,
            healthIntelligence: healthIntelligence
        )

        return CoachAIActivityContext(
            workoutsToday: snapshot.workout?.workoutCount ?? 0,
            hasWorkoutToday: snapshot.workout?.hasWorkout == true,
            stepsOverride: snapshot.activity.steps,
            healthIntelligence: awareness ? healthIntelligence : nil,
            healthIntelligenceAwarenessAvailable: awareness,
            sourceSnapshot: snapshot
        )
    }
}
