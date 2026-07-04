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

    func testPhase3SyncFlagsMatchRolloutPolicy() {
        XCTAssertTrue(AccountPersistenceFeatureFlags.cloudSchemaEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.syncEngineEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled)
        XCTAssertFalse(AccountPersistenceFeatureFlags.pullRecentDataEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.restoreOnLoginEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.foregroundCrossDeviceRefreshEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.realtimeCrossDeviceSyncEnabled)
        XCTAssertTrue(AccountPersistenceFeatureFlags.manualRefreshEnabled)
    }

    func testInMemoryContainerWiresCrossDeviceSyncStack() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.crossDeviceSyncCoordinator)
        XCTAssertNotNil(container.accountIncrementalPuller)
        XCTAssertNotNil(container.accountSyncCursorStore)
        XCTAssertNotNil(container.accountDataRefreshEventBus)
        XCTAssertTrue(container.accountRealtimeChangeListener is NoOpAccountRealtimeChangeListener)
    }

    func testInMemoryContainerWiresAccountSyncUploader() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.accountSyncUploader)
    }

    func testInMemoryContainerWiresAccountSyncPuller() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.accountSyncPuller)
    }

    func testInMemoryContainerWiresAccountSyncCoordinator() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.accountSyncCoordinator)
    }

    func testInMemoryContainerWiresAccountSyncDiagnostics() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.accountSyncDiagnostics)
        XCTAssertNotNil(container.accountRestoreDiagnostics)
    }

    func testInMemoryContainerWiresAccountRestoreCoordinator() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.accountRestoreCoordinator)
        XCTAssertNotNil(container.accountDataNamespaceService)
        XCTAssertNotNil(container.accountMigrationService)
        XCTAssertNotNil(container.accountInitialRestoreService)
        XCTAssertNotNil(container.accountRestoreStateStore)
    }
}
