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

        let report = HealthIntelligenceSnapshotVerifier.buildReport(
            snapshot: snapshot,
            trainingLoad: nil,
            calendar: calendar
        )
        HealthIntelligenceSnapshotVerifier.log(report)
    }
}
