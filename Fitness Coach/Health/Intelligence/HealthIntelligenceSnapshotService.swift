//
//  HealthIntelligenceSnapshotService.swift
//  Fitness Coach
//
//  Forma — Composes and caches Health Intelligence snapshots without UI coupling.
//

import Foundation

protocol HealthIntelligenceSnapshotServing: Sendable {
    func refreshTodaySnapshot(calendar: Calendar) async
}

struct NoOpHealthIntelligenceSnapshotService: HealthIntelligenceSnapshotServing {
    func refreshTodaySnapshot(calendar: Calendar) async {}
}

struct HealthIntelligenceSnapshotService: HealthIntelligenceSnapshotServing {

    private let engine: any HealthIntelligenceEngineing
    private let cacheStore: any HealthCacheStore
    private let enginesEnabled: Bool

    init(
        engine: any HealthIntelligenceEngineing,
        cacheStore: any HealthCacheStore,
        enginesEnabled: Bool = HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled
    ) {
        self.engine = engine
        self.cacheStore = cacheStore
        self.enginesEnabled = enginesEnabled
    }

    func refreshTodaySnapshot(calendar: Calendar = .current) async {
        guard enginesEnabled else { return }

        let today = calendar.startOfDay(for: Date())
        let snapshot = await engine.composeSnapshot(for: today, calendar: calendar)

        cacheStore.storeIntelligenceSnapshot(snapshot, for: today, calendar: calendar)

        #if DEBUG
        logSnapshotVerification(snapshot: snapshot, calendar: calendar)
        #endif
    }

    #if DEBUG
    private func logSnapshotVerification(snapshot: HealthIntelligenceSnapshot, calendar: Calendar) {
        let dayKey = Self.dayKey(for: snapshot.date, calendar: calendar)
        HealthIntelligenceEngineLogger.snapshotComposed(
            dayKey: dayKey,
            recoveryStatus: snapshot.recovery.status.rawValue,
            hasWorkout: snapshot.workout?.hasWorkout == true,
            activitySteps: snapshot.activity.steps.map(String.init),
            nutritionShouldChange: snapshot.nutritionAdjustment.shouldChangeTarget,
            nextBestActionID: snapshot.nextBestAction.id,
            planConfidence: snapshot.planConfidence.label,
            hasWeeklyReview: snapshot.weeklyReview != nil
        )
    }
    #endif

    private static func dayKey(for day: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: day))
    }
}
