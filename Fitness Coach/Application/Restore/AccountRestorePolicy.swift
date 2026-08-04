//
//  AccountRestorePolicy.swift
//  Fitness Coach
//
//  Forma — Centralized account restore policy (Phase 4).
//
//  Lookback windows, timeouts, and scope exclusions. No restore coordinator wiring yet.
//

import Foundation

/// Central policy for account bootstrap / fresh-install restore.
enum AccountRestorePolicy {

    // MARK: - Lookback windows (days)

    /// Critical daily logs + child food/water/review documents for blocking restore.
    /// Enough for Today / recent history; extended history hydrates in background.
    static let blockingDailyLogLookbackDays = 7

    /// Weight entries for blocking restore (recent Journey baseline).
    /// Full history hydrates via background backfill.
    static let blockingWeightLookbackDays = 30

    /// Extended daily log history for background backfill.
    static let backgroundDailyLogLookbackDays = 365

    /// Extended weight history for background backfill.
    static let backgroundWeightLookbackDays = 730

    // MARK: - Blocking restore UX timeouts (seconds)

    /// Minimum time to show the blocking restore surface (avoids flicker).
    static let minimumBlockingRestoreTimeoutSeconds = 1

    /// Maximum time to block the main shell before continuing with partial progress.
    /// Critical bootstrap should finish well under this; remainder hydrates in background.
    static let maximumBlockingRestoreTimeoutSeconds = 8

    // MARK: - Scope exclusions (Phase 4)

    /// Restore never downloads raw meal image bytes — optional `imageUrl` strings only via Phase 2 DTOs.
    static let includesRawMealImages = false

    /// Restore never downloads raw HealthKit samples.
    static let includesRawHealthKitData = false

    /// Coach chat and timeline are not restored unless explicitly added in a later phase.
    static let includesCoachCloudData = false

    /// Phase 3 merge policy must skip or conflict on newer local pending edits — never overwrite.
    static let preservesLocalNewerUnsyncedEdits = true

    // MARK: - Mode helpers

    static func dailyLogLookbackDays(for mode: AccountRestoreMode) -> Int {
        switch mode {
        case .blockingInitial, .manualRetry:
            return blockingDailyLogLookbackDays
        case .backgroundBackfill:
            return backgroundDailyLogLookbackDays
        }
    }

    static func weightLookbackDays(for mode: AccountRestoreMode) -> Int {
        switch mode {
        case .blockingInitial, .manualRetry:
            return blockingWeightLookbackDays
        case .backgroundBackfill:
            return backgroundWeightLookbackDays
        }
    }

    /// Preferred blocking timeout used by restore UI before surfacing partial/offline states.
    static var preferredBlockingRestoreTimeoutSeconds: TimeInterval {
        TimeInterval(maximumBlockingRestoreTimeoutSeconds)
    }

    static func blockingRestoreTimeoutRange() -> ClosedRange<TimeInterval> {
        TimeInterval(minimumBlockingRestoreTimeoutSeconds)
            ... TimeInterval(maximumBlockingRestoreTimeoutSeconds)
    }

    /// Local calendar date range (`yyyy-MM-dd`) for daily-log-scoped pulls.
    static func dailyLogDateRange(
        for mode: AccountRestoreMode,
        referenceDate: Date = Date(),
        calendar: Calendar = defaultCalendar
    ) -> (start: String, end: String) {
        dateRange(
            lookbackDays: dailyLogLookbackDays(for: mode),
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    /// Local calendar date range (`yyyy-MM-dd`) for weight entry pulls.
    static func weightDateRange(
        for mode: AccountRestoreMode,
        referenceDate: Date = Date(),
        calendar: Calendar = defaultCalendar
    ) -> (start: String, end: String) {
        dateRange(
            lookbackDays: weightLookbackDays(for: mode),
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    // MARK: - Private

    private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func dateRange(
        lookbackDays: Int,
        referenceDate: Date,
        calendar: Calendar
    ) -> (start: String, end: String) {
        let clampedLookback = max(lookbackDays, 1)
        let end = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -(clampedLookback - 1), to: end) ?? end
        return (
            CloudAccountDataDateCodec.localDateString(from: start, calendar: calendar),
            CloudAccountDataDateCodec.localDateString(from: end, calendar: calendar)
        )
    }
}
