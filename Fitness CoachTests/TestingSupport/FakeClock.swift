//
//  FakeClock.swift
//  Fitness CoachTests
//
//  Injectable clock for services, Health Intelligence, and async test polling.
//

import Foundation
@testable import Fitness_Coach

/// Thread-safe fixed clock for deterministic tests. Normalizes `DateProviding.now` to start-of-day.
final class FakeClock: DateProviding, @unchecked Sendable {

    private let lock = NSLock()
    private var nowValue: Date
    private let calendarValue: Calendar
    private let normalizeToStartOfDay: Bool

    init(
        now: Date,
        calendar: Calendar = TestDateFixtures.utcCalendar(),
        normalizeToStartOfDay: Bool = true
    ) {
        self.calendarValue = calendar
        self.normalizeToStartOfDay = normalizeToStartOfDay
        self.nowValue = normalizeToStartOfDay ? calendar.startOfDay(for: now) : now
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return nowValue
    }

    var calendar: Calendar { calendarValue }

    func startOfDay(for date: Date) -> Date {
        calendarValue.startOfDay(for: date)
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        nowValue = nowValue.addingTimeInterval(interval)
        lock.unlock()
    }

    func advanceDays(_ days: Int) {
        lock.lock()
        if let advanced = calendarValue.date(byAdding: .day, value: days, to: nowValue) {
            nowValue = normalizeToStartOfDay ? calendarValue.startOfDay(for: advanced) : advanced
        }
        lock.unlock()
    }

    func setNow(_ date: Date) {
        lock.lock()
        nowValue = normalizeToStartOfDay ? calendarValue.startOfDay(for: date) : date
        lock.unlock()
    }
}

/// HI pipeline clock witness without colliding with `DateProviding.now`.
struct FakeHealthIntelligenceClock: HealthIntelligenceClockProviding {
    private let clock: FakeClock

    init(clock: FakeClock) {
        self.clock = clock
    }

    func now() -> Date { clock.now }

    func calendar() -> Calendar { clock.calendar }
}

/// Backward-compatible name used across SwiftData service tests.
typealias FixedDailyLogTestDateProvider = FakeClock

/// Backward-compatible name used by the HI pipeline harness.
typealias FixedPipelineClock = FakeHealthIntelligenceClock
