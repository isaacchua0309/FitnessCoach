//
//  InMemorySwiftDataTestStore.swift
//  Fitness CoachTests
//
//  Shared in-memory SwiftData container/store for service and integration tests.
//

import Foundation
import SwiftData
@testable import Fitness_Coach

@MainActor
enum InMemorySwiftDataTestStore {

    static func makeContainer(
        inMemory: Bool = true,
        storeURL: URL? = nil,
        markMigrationComplete: Bool = false
    ) throws -> ModelContainer {
        if let storeURL {
            return try FormaModelContainer.makeContainer(
                inMemory: inMemory,
                storeURL: storeURL,
                markMigrationComplete: markMigrationComplete
            )
        }
        return try FormaModelContainer.makeContainer(inMemory: inMemory)
    }

    static func makeStore(
        referenceNow: Date = TestDateFixtures.referenceEpoch,
        calendar: Calendar = TestDateFixtures.utcCalendar()
    ) throws -> (store: SwiftDataStore, clock: FakeClock) {
        let clock = FakeClock(now: referenceNow, calendar: calendar)
        let container = try makeContainer()
        return (SwiftDataStore(container: container), clock)
    }

    static func makeStoreOnly(
        referenceNow: Date = TestDateFixtures.referenceEpoch,
        calendar: Calendar = TestDateFixtures.utcCalendar()
    ) throws -> SwiftDataStore {
        try makeStore(referenceNow: referenceNow, calendar: calendar).store
    }
}
