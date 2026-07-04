//
//  AccountSyncCursorStoreTests.swift
//  Fitness CoachTests
//
//  Forma — Per-UID cross-device sync cursor store tests (Phase 5).
//

import XCTest
@testable import Fitness_Coach

final class AccountSyncCursorStoreTests: XCTestCase {

    private let uidA = "user-a"
    private let uidB = "user-b"
    private let referenceDate = ProfileTestFixtures.referenceDate

    private var defaults: UserDefaults!
    private var store: AccountSyncCursorStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AccountSyncCursorStoreTests.\(UUID().uuidString)")!
        store = AccountSyncCursorStore(userDefaults: defaults)
    }

    override func tearDown() {
        store = nil
        defaults.removePersistentDomain(forName: defaults.suiteName!)
        defaults = nil
        super.tearDown()
    }

    func testLoadCursorDefaultsToEmptyForUnknownUID() {
        let cursor = store.loadCursor(uid: uidA)

        XCTAssertEqual(cursor.uid, uidA)
        XCTAssertNil(cursor.profileLastPulledAt)
        XCTAssertNil(cursor.dailyLogsLastPulledAt)
        XCTAssertNil(cursor.foodEntriesLastPulledAt)
        XCTAssertNil(cursor.waterEntriesLastPulledAt)
        XCTAssertNil(cursor.weightEntriesLastPulledAt)
        XCTAssertNil(cursor.dailyReviewsLastPulledAt)
        XCTAssertNil(cursor.lastForegroundRefreshAt)
        XCTAssertNil(cursor.lastManualRefreshAt)
    }

    func testUpdateCursorPersistsUIDScopedDomainTimestamp() {
        store.updateCursor(uid: uidA, domain: .foodEntries, date: referenceDate)

        XCTAssertEqual(
            defaults.object(forKey: AccountSyncCursorStoreSupport.foodEntriesLastPulledAtKey(for: uidA)) as? Date,
            referenceDate
        )
        XCTAssertNil(
            defaults.object(forKey: AccountSyncCursorStoreSupport.foodEntriesLastPulledAtKey(for: uidB)) as? Date
        )
    }

    func testUserAAndUserBCursorsAreIsolated() {
        let dateA = referenceDate
        let dateB = referenceDate.addingTimeInterval(3600)

        store.updateCursor(uid: uidA, domain: .dailyLogs, date: dateA)
        store.updateCursor(uid: uidB, domain: .dailyLogs, date: dateB)
        store.updateForegroundRefresh(uid: uidA, date: dateA)
        store.updateManualRefresh(uid: uidB, date: dateB)

        let cursorA = store.loadCursor(uid: uidA)
        let cursorB = store.loadCursor(uid: uidB)

        XCTAssertEqual(cursorA.dailyLogsLastPulledAt, dateA)
        XCTAssertEqual(cursorB.dailyLogsLastPulledAt, dateB)
        XCTAssertEqual(cursorA.lastForegroundRefreshAt, dateA)
        XCTAssertNil(cursorA.lastManualRefreshAt)
        XCTAssertNil(cursorB.lastForegroundRefreshAt)
        XCTAssertEqual(cursorB.lastManualRefreshAt, dateB)
    }

    func testPartialDomainUpdatesDoNotAffectOtherDomains() {
        store.updateCursor(uid: uidA, domain: .weightEntries, date: referenceDate)

        let cursor = store.loadCursor(uid: uidA)

        XCTAssertEqual(cursor.weightEntriesLastPulledAt, referenceDate)
        XCTAssertNil(cursor.profileLastPulledAt)
        XCTAssertNil(cursor.foodEntriesLastPulledAt)
        XCTAssertNil(cursor.dailyReviewsLastPulledAt)
    }

    func testClearRemovesOnlyRequestedUIDKeys() {
        store.updateCursor(uid: uidA, domain: .profile, date: referenceDate)
        store.updateCursor(uid: uidB, domain: .profile, date: referenceDate.addingTimeInterval(60))

        store.clear(uid: uidA)

        XCTAssertNil(store.loadCursor(uid: uidA).profileLastPulledAt)
        XCTAssertEqual(store.loadCursor(uid: uidB).profileLastPulledAt, referenceDate.addingTimeInterval(60))
    }

    func testDomainKeysMatchCrossDeviceSyncPrefix() {
        XCTAssertEqual(
            AccountSyncCursorStoreSupport.profileLastPulledAtKey(for: uidA),
            "forma.crossDeviceSync.\(uidA).profileLastPulledAt"
        )
        XCTAssertEqual(
            AccountSyncCursorStoreSupport.lastManualRefreshAtKey(for: uidA),
            "forma.crossDeviceSync.\(uidA).lastManualRefreshAt"
        )
    }

    func testUpdateCursorDoesNotMoveCursorBackward() {
        let newer = referenceDate.addingTimeInterval(120)
        let older = referenceDate

        store.updateCursor(uid: uidA, domain: .dailyReviews, date: newer)
        store.updateCursor(uid: uidA, domain: .dailyReviews, date: older)

        XCTAssertEqual(store.loadCursor(uid: uidA).dailyReviewsLastPulledAt, newer)
    }

    func testUpdateForegroundAndManualRefreshPersistSeparately() {
        let foregroundDate = referenceDate
        let manualDate = referenceDate.addingTimeInterval(90)

        store.updateForegroundRefresh(uid: uidA, date: foregroundDate)
        store.updateManualRefresh(uid: uidA, date: manualDate)

        let cursor = store.loadCursor(uid: uidA)
        XCTAssertEqual(cursor.lastForegroundRefreshAt, foregroundDate)
        XCTAssertEqual(cursor.lastManualRefreshAt, manualDate)
    }
}
