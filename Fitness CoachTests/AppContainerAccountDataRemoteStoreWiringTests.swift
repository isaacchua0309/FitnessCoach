//
//  AppContainerAccountDataRemoteStoreWiringTests.swift
//  Fitness CoachTests
//
//  Forma — Verifies AccountDataRemoteStore DI wiring without enabling sync.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AppContainerAccountDataRemoteStoreWiringTests: XCTestCase {

    func testInMemoryContainerWiresInMemoryAccountDataRemoteStore() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertTrue(container.accountDataRemoteStore is InMemoryAccountDataRemoteStore)
    }

    func testContainerAcceptsInjectedAccountDataRemoteStore() throws {
        let store = InMemoryAccountDataRemoteStore()
        let container = try AppContainer(inMemory: true, accountDataRemoteStore: store)

        XCTAssertTrue(container.accountDataRemoteStore is InMemoryAccountDataRemoteStore)
    }

    func testPhase2SyncFlagsRemainDisabled() {
        XCTAssertTrue(AccountPersistenceFeatureFlags.cloudSchemaEnabled)
        XCTAssertFalse(AccountPersistenceFeatureFlags.syncEngineEnabled)
        XCTAssertFalse(AccountPersistenceFeatureFlags.restoreOnLoginEnabled)
    }
}
