//
//  CrossDeviceSyncLifecycleTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 5 cross-device lifecycle policy tests.
//

import XCTest
@testable import Fitness_Coach

final class CrossDeviceSyncLifecycleTests: XCTestCase {

    func testPhaseFiveFlagsAreEnabled() {
        XCTAssertTrue(AccountPersistenceFeatureFlags.foregroundCrossDeviceRefreshEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.realtimeCrossDeviceSyncEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.manualRefreshEnabled)
        XCTAssertTrue(CrossDeviceSyncLifecycle.isForegroundRefreshEnabled)
        XCTAssertTrue(CrossDeviceSyncLifecycle.isManualRefreshEnabled)
    }
}
