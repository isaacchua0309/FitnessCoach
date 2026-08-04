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
    private let referenceDate = ProfileFixtures.referenceDate

    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var store: AccountSyncCursorStore!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "AccountSyncCursorStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
        store = AccountSyncCursorStore(userDefaults: defaults)
    }

    override func tearDown() {
        store = nil
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testCursorIsScopedByUID() {
        let dateA = referenceDate
        store.updateCursor(uid: uidA, domain: .foodEntries, date: dateA)

        XCTAssertEqual(store.loadCursor(uid: uidA).foodEntriesLastPulledAt, dateA)
        XCTAssertNil(store.loadCursor(uid: uidB).foodEntriesLastPulledAt)
        XCTAssertEqual(
            defaults.object(forKey: AccountSyncCursorStoreSupport.foodEntriesLastPulledAtKey(for: uidA)) as? Date,
            dateA
        )
        XCTAssertNil(
            defaults.object(forKey: AccountSyncCursorStoreSupport.foodEntriesLastPulledAtKey(for: uidB)) as? Date
        )
    }

    func testUpdateDailyLogsCursorDoesNotAffectFoodCursor() {
        store.updateCursor(uid: uidA, domain: .dailyLogs, date: referenceDate)

        let cursor = store.loadCursor(uid: uidA)
        XCTAssertEqual(cursor.dailyLogsLastPulledAt, referenceDate)
        XCTAssertNil(cursor.foodEntriesLastPulledAt)
        XCTAssertNil(cursor.waterEntriesLastPulledAt)
        XCTAssertNil(cursor.weightEntriesLastPulledAt)
        XCTAssertNil(cursor.dailyReviewsLastPulledAt)
    }

    func testUpdateCursorForUserADoesNotAffectUserB() {
        let dateA = referenceDate
        let dateB = referenceDate.addingTimeInterval(3600)

        store.updateCursor(uid: uidA, domain: .dailyLogs, date: dateA)
        store.updateCursor(uid: uidB, domain: .dailyLogs, date: dateB)

        XCTAssertEqual(store.loadCursor(uid: uidA).dailyLogsLastPulledAt, dateA)
        XCTAssertEqual(store.loadCursor(uid: uidB).dailyLogsLastPulledAt, dateB)
    }

    func testForegroundRefreshThrottleUsesUIDScopedTimestamp() {
        let foregroundA = referenceDate
        let foregroundB = referenceDate.addingTimeInterval(120)

        store.updateForegroundRefresh(uid: uidA, date: foregroundA)
        store.updateForegroundRefresh(uid: uidB, date: foregroundB)

        XCTAssertEqual(store.loadCursor(uid: uidA).lastForegroundRefreshAt, foregroundA)
        XCTAssertEqual(store.loadCursor(uid: uidB).lastForegroundRefreshAt, foregroundB)
        XCTAssertNil(store.loadCursor(uid: uidA).lastManualRefreshAt)
        XCTAssertNil(store.loadCursor(uid: uidB).lastManualRefreshAt)
    }

    func testClearRemovesOnlyOneUserCursor() {
        store.updateCursor(uid: uidA, domain: .profile, date: referenceDate)
        store.updateCursor(uid: uidB, domain: .profile, date: referenceDate.addingTimeInterval(60))
        store.updateForegroundRefresh(uid: uidA, date: referenceDate)
        store.updateForegroundRefresh(uid: uidB, date: referenceDate.addingTimeInterval(30))

        store.clear(uid: uidA)

        XCTAssertNil(store.loadCursor(uid: uidA).profileLastPulledAt)
        XCTAssertNil(store.loadCursor(uid: uidA).lastForegroundRefreshAt)
        XCTAssertEqual(store.loadCursor(uid: uidB).profileLastPulledAt, referenceDate.addingTimeInterval(60))
        XCTAssertEqual(store.loadCursor(uid: uidB).lastForegroundRefreshAt, referenceDate.addingTimeInterval(30))
    }
}
