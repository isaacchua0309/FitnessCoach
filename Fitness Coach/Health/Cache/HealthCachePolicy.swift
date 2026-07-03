//
//  HealthCachePolicy.swift
//  Fitness Coach
//
//  Forma — Retention and freshness rules for local health cache.
//

import Foundation

enum HealthCachePolicy {

    static let schemaVersion = 1
    static let retentionDays = 90
    static let todayFreshnessInterval: TimeInterval = 15 * 60
    static let historicalFreshnessInterval: TimeInterval = 24 * 60 * 60
    static let anonymousUserID = "anonymous"

    static func isFresh(
        cachedAt: Date,
        for date: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: now)
        let interval = dayStart == todayStart
            ? todayFreshnessInterval
            : historicalFreshnessInterval
        return now.timeIntervalSince(cachedAt) < interval
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
