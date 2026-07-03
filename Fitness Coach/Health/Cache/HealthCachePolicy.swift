//
//  HealthCachePolicy.swift
//  Fitness Coach
//
//  Forma — Retention and freshness rules for local health cache.
//

import Foundation

enum HealthCachePolicy {

    /// Local cache retains normalized domain models for this many calendar days.
    static let schemaVersion = 1
    static let retentionDays = 90

    /// Today refreshes more often; historical days use a longer TTL to avoid redundant HK queries.
    static let todayFreshnessInterval: TimeInterval = 15 * 60
    static let historicalFreshnessInterval: TimeInterval = 24 * 60 * 60
    static let anonymousUserID = "anonymous"

    static func freshnessInterval(
        for date: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> TimeInterval {
        let dayStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: now)
        return dayStart == todayStart
            ? todayFreshnessInterval
            : historicalFreshnessInterval
    }

    static func isFresh(
        cachedAt: Date,
        for date: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        now.timeIntervalSince(cachedAt) < freshnessInterval(for: date, calendar: calendar, now: now)
    }

    /// Intelligence snapshots follow the same TTL as normalized day bundles.
    static func isIntelligenceSnapshotFresh(
        cachedAt: Date,
        for date: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        isFresh(cachedAt: cachedAt, for: date, calendar: calendar, now: now)
    }

    static func pruneCutoffDate(
        keepingLastDays: Int = retentionDays,
        endingOn date: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        let endDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -(keepingLastDays - 1), to: endDay)
    }
}
