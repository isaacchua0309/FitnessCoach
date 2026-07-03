//
//  HealthSummaryRemoteSyncTestSupport.swift
//  Fitness CoachTests
//
//  Shared helpers for Health Summary Remote Sync tests.
//

import Foundation
import XCTest
@testable import Fitness_Coach

enum HealthSummaryRemoteSyncTestSupport {

    static let forbiddenPayloadKeys: Set<String> = [
        "samples",
        "raw",
        "healthKit",
        "healthkit",
        "hksample",
        "timeSeries",
        "heartRateSeries",
        "heartRate",
        "restingHeartRate",
        "hrvValue",
        "route",
        "gps",
        "detail"
    ]

    static func makeRemoteSyncClient(
        inMemory: Bool,
        userProvider: any HealthCacheUserProviding
    ) -> any HealthSummaryRemoteSyncing {
        let enabled = HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
        if inMemory || !enabled {
            return NoopHealthSummaryRemoteSyncClient()
        }
        return FirestoreHealthSummaryRemoteSyncClient(userProvider: userProvider)
    }

    static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    static func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func assertNoForbiddenPayloadKeys(in json: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) else {
            XCTFail("Expected valid JSON object", file: file, line: line)
            return
        }
        assertNoForbiddenPayloadKeys(in: object, path: "$", file: file, line: line)
    }

    static func seedDay(
        _ day: Date,
        in cache: MemoryHealthCacheStore,
        calendar: Calendar,
        steps: Int = 1000,
        workouts: [NormalizedWorkout] = []
    ) {
        let bundle = HealthNormalizedDayBundle(
            dailyMetrics: DailyHealthMetrics(
                date: day,
                steps: steps,
                activeEnergyKcal: 100,
                exerciseMinutes: 10
            ),
            workouts: workouts,
            sleepRecords: [],
            heartMetrics: [],
            bodyMassRecords: []
        )
        cache.store(
            HealthCacheEntry(date: day, bundle: bundle, cachedAt: Date()),
            calendar: calendar
        )
    }

    static func seedConsecutiveDays(
        count: Int,
        endingOn endDay: Date,
        in cache: MemoryHealthCacheStore,
        calendar: Calendar
    ) -> [Date] {
        let end = calendar.startOfDay(for: endDay)
        guard count > 0,
              let start = calendar.date(byAdding: .day, value: -(count - 1), to: end) else {
            return []
        }

        var days: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        while cursor <= end {
            days.append(cursor)
            seedDay(cursor, in: cache, calendar: calendar, steps: 1000 + days.count)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return days
    }

    static func makeWorkout(on day: Date, calendar: Calendar) -> NormalizedWorkout {
        let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
        let end = calendar.date(byAdding: .minute, value: 45, to: start)!
        return NormalizedWorkout(
            id: HealthStableIdentifier.workoutID(
                sourceName: "Apple Watch",
                startDate: start,
                endDate: end,
                durationMinutes: 45,
                category: .running
            ),
            category: .running,
            activityLabel: "Running",
            startDate: start,
            endDate: end,
            durationMinutes: 45,
            activeEnergyKcal: 300,
            sourceName: "Apple Watch"
        )
    }

    static func makeMappingContext(
        userId: String = "user-123",
        calendar: Calendar
    ) -> HealthSummarySyncMappingContext {
        HealthSummarySyncMappingContext(
            userId: userId,
            calendar: calendar,
            generatedAt: ISO8601DateFormatter().date(from: "2026-07-03T15:30:00Z")!,
            source: .appleHealth
        )
    }

    // MARK: - Private

    private static func assertNoForbiddenPayloadKeys(
        in value: Any,
        path: String,
        file: StaticString,
        line: UInt
    ) {
        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary {
                let nextPath = "\(path).\(key)"
                XCTAssertFalse(
                    forbiddenPayloadKeys.contains(key),
                    "Forbidden payload key at \(nextPath)",
                    file: file,
                    line: line
                )
                assertNoForbiddenPayloadKeys(in: nested, path: nextPath, file: file, line: line)
            }
            return
        }

        if let array = value as? [Any] {
            for (index, nested) in array.enumerated() {
                assertNoForbiddenPayloadKeys(
                    in: nested,
                    path: "\(path)[\(index)]",
                    file: file,
                    line: line
                )
            }
        }
    }
}

final class SummarySyncMockRepository: HealthDataRepositorying, @unchecked Sendable {
    var availability = HealthDataAvailability(
        isHealthDataAvailable: true,
        permissionStatus: .uniform(.available, isHealthDataAvailable: true),
        cachedDayCount: 1
    )

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] { [] }
    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        .empty(for: date)
    }
    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] { [] }
    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { [] }
    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] { [] }
    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }
    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }
    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }
    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }
    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }
    func getHealthDataAvailability() async -> HealthDataAvailability { availability }
    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: days, refreshedAt: Date())
    }
}
