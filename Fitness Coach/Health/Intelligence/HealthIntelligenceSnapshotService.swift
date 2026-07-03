//
//  HealthIntelligenceSnapshotService.swift
//  Fitness Coach
//
//  Forma — Composes and caches Health Intelligence snapshots without UI coupling.
//

import Foundation

protocol HealthIntelligenceSnapshotServing: Sendable {
    func refreshTodaySnapshot(calendar: Calendar) async
    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot?
}

struct NoOpHealthIntelligenceSnapshotService: HealthIntelligenceSnapshotServing {
    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        nil
    }
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
        let snapshot = await loadTodaySnapshot(for: today, calendar: calendar)

        guard let snapshot else { return }

        let report = HealthIntelligenceSnapshotVerifier.buildReport(
            snapshot: snapshot,
            trainingLoad: nil,
            calendar: calendar
        )
        HealthIntelligenceSnapshotVerifier.log(report)
    }

    /// Cache-first snapshot load for Today. Composes and stores only on cache miss.
    func loadTodaySnapshot(
        for date: Date,
        calendar: Calendar = .current
    ) async -> HealthIntelligenceSnapshot? {
        guard enginesEnabled else { return nil }

        let day = calendar.startOfDay(for: date)

        if let cached = cacheStore.intelligenceSnapshot(for: day, calendar: calendar) {
            return cached
        }

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar, mode: .today)
        cacheStore.storeIntelligenceSnapshot(snapshot, for: day, calendar: calendar)
        return snapshot
    }
}
