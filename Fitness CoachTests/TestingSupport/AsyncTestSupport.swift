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
}
