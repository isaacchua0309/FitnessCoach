//
//  HealthSummaryRemoteSyncClientTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for remote Health Summary Sync client abstractions.
//

import Foundation
import XCTest
@testable import Fitness_Coach

final class HealthSummaryRemoteSyncClientTests: XCTestCase {

    private var calendar: Calendar!
    private var context: HealthSummarySyncMappingContext!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        self.calendar = calendar
        context = HealthSummarySyncMappingContext(
            userId: "authenticated-user",
            calendar: calendar,
            generatedAt: ISO8601DateFormatter().date(from: "2026-07-03T15:30:00Z")!,
            source: .appleHealth
        )
    }

    func testNoopClientAcceptsUploadsWithoutSideEffects() async throws {
        let client = NoopHealthSummaryRemoteSyncClient()
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let metrics = DailyHealthMetrics(date: day, steps: 100, activeEnergyKcal: 50, exerciseMinutes: 10)
        let daily = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: context)

        try await client.uploadDailySummaries([daily])
        try await client.deleteRemoteHealthSummaries()
    }

    func testMockClientRecordsUploadedSummaries() async throws {
        let mock = MockHealthSummaryRemoteSyncClient()
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let metrics = DailyHealthMetrics(date: day, steps: 100, activeEnergyKcal: 50, exerciseMinutes: 10)
        let daily = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: context)

        try await mock.uploadDailySummaries([daily])

        XCTAssertEqual(mock.uploadedDailySummaries.count, 1)
        XCTAssertEqual(mock.uploadedDailySummaries.first?.id, "2026-07-03")
    }

    func testMockClientPropagatesConfiguredErrors() async {
        let mock = MockHealthSummaryRemoteSyncClient()
        mock.uploadDailyError = .notAuthenticated

        do {
            try await mock.uploadDailySummaries([])
            XCTFail("Expected notAuthenticated")
        } catch let error as HealthSummarySyncError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMockDeleteClearsStoredSummaries() async throws {
        let mock = MockHealthSummaryRemoteSyncClient()
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let metrics = DailyHealthMetrics(date: day, steps: 100, activeEnergyKcal: 50, exerciseMinutes: 10)
        let daily = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: context)

        try await mock.uploadDailySummaries([daily])
        try await mock.deleteRemoteHealthSummaries()

        XCTAssertEqual(mock.deleteCallCount, 1)
        XCTAssertTrue(mock.uploadedDailySummaries.isEmpty)
    }

    func testResolveAuthenticatedUserIDRejectsAnonymous() {
        let provider = StaticHealthCacheUserProvider(userID: HealthCachePolicy.anonymousUserID)

        XCTAssertThrowsError(try HealthSummaryRemoteSyncSupport.resolveAuthenticatedUserID(from: provider)) { error in
            XCTAssertEqual(error as? HealthSummarySyncError, .notAuthenticated)
        }
    }

    func testValidatePayloadsRejectsUserIdMismatch() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let metrics = DailyHealthMetrics(date: day, steps: 100, activeEnergyKcal: 50, exerciseMinutes: 10)
        let mismatchedContext = HealthSummarySyncMappingContext(userId: "other-user", calendar: calendar)
        let payload = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: mismatchedContext)

        XCTAssertThrowsError(
            try HealthSummaryRemoteSyncSupport.validatePayloads([payload], authUid: "authenticated-user")
        ) { error in
            XCTAssertEqual(error as? HealthSummarySyncError, .userIdMismatch)
        }
    }

    func testFirestoreClientRequiresAuthenticatedUser() async {
        let client = FirestoreHealthSummaryRemoteSyncClient(
            userProvider: StaticHealthCacheUserProvider(userID: nil)
        )
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let metrics = DailyHealthMetrics(date: day, steps: 100, activeEnergyKcal: 50, exerciseMinutes: 10)
        let daily = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: context)

        do {
            try await client.uploadDailySummaries([daily])
            XCTFail("Expected notAuthenticated")
        } catch let error as HealthSummarySyncError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFirestoreClientRejectsMismatchedPayloadBeforeNetworkCall() async {
        let client = FirestoreHealthSummaryRemoteSyncClient(
            userProvider: StaticHealthCacheUserProvider(userID: "authenticated-user")
        )
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let metrics = DailyHealthMetrics(date: day, steps: 100, activeEnergyKcal: 50, exerciseMinutes: 10)
        let mismatchedContext = HealthSummarySyncMappingContext(userId: "other-user", calendar: calendar)
        let payload = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: mismatchedContext)

        do {
            try await client.uploadDailySummaries([payload])
            XCTFail("Expected userIdMismatch")
        } catch let error as HealthSummarySyncError {
            XCTAssertEqual(error, .userIdMismatch)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testChunkedSplitsLargeUploadBatches() {
        let values = Array(0..<905)
        let chunks = HealthSummaryRemoteSyncSupport.chunked(values, size: 400)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].count, 400)
        XCTAssertEqual(chunks[1].count, 400)
        XCTAssertEqual(chunks[2].count, 105)
    }
}
