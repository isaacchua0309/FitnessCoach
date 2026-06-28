//
//  AsyncTestSupport.swift
//  Fitness CoachTests
//
//  Deterministic async helpers — prefer Task.yield over fixed sleeps.
//

import Foundation

@MainActor
enum AsyncTestSupport {

    /// Yields until `condition` is true or `maxYields` is exhausted.
    static func waitUntil(
        maxYields: Int = 100,
        _ condition: () -> Bool
    ) async -> Bool {
        if condition() { return true }
        for _ in 0..<maxYields {
            await Task.yield()
            if condition() { return true }
        }
        return false
    }

    /// Drains fire-and-forget `Task { }` work scheduled on the main actor.
    static func drainMainActorTasks(maxYields: Int = 80) async {
        for _ in 0..<maxYields {
            await Task.yield()
        }
    }

    /// Polls until `condition` is true or `timeout` elapses (for production delays like Task.sleep).
    static func waitUntilWallClock(
        timeout: TimeInterval = 2.0,
        interval: TimeInterval = 0.05,
        _ condition: () -> Bool
    ) async -> Bool {
        if condition() { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            await Task.yield()
            if condition() { return true }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { break }
            try? await Task.sleep(nanoseconds: UInt64(min(interval, remaining) * 1_000_000_000))
        }
        return condition()
    }
}
