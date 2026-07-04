//
//  CrossDeviceRefreshTestSupport.swift
//  Fitness CoachTests
//
//  Forma — Shared helpers for feature-level cross-device refresh tests.
//

import Foundation
@testable import Fitness_Coach

enum CrossDeviceRefreshTestSupport {

    static let reloadDebounceNanoseconds: UInt64 = 350_000_000

    @MainActor
    static func publishAndWait(
        bus: AccountDataRefreshEventBus,
        event: AccountDataRefreshEvent
    ) async throws {
        bus.publish(event)
        bus.flushImmediately()
        try await Task.sleep(nanoseconds: reloadDebounceNanoseconds)
    }
}
