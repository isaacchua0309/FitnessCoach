//
//  HealthCacheStore.swift
//  Fitness Coach
//
//  Forma — In-memory cache for normalized Health Intelligence day bundles.
//

import Foundation

struct HealthCacheEntry: Equatable, Sendable {
    let date: Date
    let bundle: HealthNormalizedDayBundle
    let cachedAt: Date
}

protocol HealthCacheStoring: Sendable {
    func entry(for date: Date, calendar: Calendar) -> HealthCacheEntry?
    func store(_ entry: HealthCacheEntry, calendar: Calendar)
    func invalidate(through date: Date, calendar: Calendar)
    func cachedDayCount(calendar: Calendar) -> Int
}

final class HealthCacheStore: HealthCacheStoring, @unchecked Sendable {

    private var entries: [Date: HealthCacheEntry] = [:]
    private let lock = NSLock()

    func entry(for date: Date, calendar: Calendar = .current) -> HealthCacheEntry? {
        let key = calendar.startOfDay(for: date)
        lock.lock()
        defer { lock.unlock() }
        return entries[key]
    }

    func store(_ entry: HealthCacheEntry, calendar: Calendar = .current) {
        let key = calendar.startOfDay(for: entry.date)
        lock.lock()
        entries[key] = entry
        lock.unlock()
    }

    func invalidate(through date: Date, calendar: Calendar = .current) {
        let cutoff = calendar.startOfDay(for: date)
        lock.lock()
        entries = entries.filter { $0.key >= cutoff }
        lock.unlock()
    }

    func cachedDayCount(calendar: Calendar = .current) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}
