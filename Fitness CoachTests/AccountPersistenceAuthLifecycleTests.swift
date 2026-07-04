//
//  AccountPersistenceAuthLifecycleTests.swift
//  Fitness CoachTests
//
//  Forma — Account persistence Phase 1 auth/bootstrap lifecycle wiring.
//

import SwiftData
import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountPersistenceAuthLifecycleTests: XCTestCase {

    func testPrepareLocalUserDataNamespaceBackfillsBeforeReturning() async throws {
        let container = try AppContainer(inMemory: true)
        _ = try container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        try seedUnownedFoodRow(in: container.store)

        await container.prepareLocalUserDataNamespace(uid: "signed-in-user")

        let food = try XCTUnwrap(try container.store.fetch(FetchDescriptor<FoodEntryEntity>()).first)
        XCTAssertEqual(food.ownerUID, "signed-in-user")
        XCTAssertEqual(
            container.accountDataNamespaceService.currentDataNamespaceUID(),
            "signed-in-user"
        )
    }

    func testPrepareLocalUserDataNamespaceRefusesBackfillOnProfileMismatch() async throws {
        let container = try AppContainer(inMemory: true)
        _ = try container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-a"
        )
        try seedUnownedFoodRow(in: container.store)

        await container.prepareLocalUserDataNamespace(uid: "user-b")

        XCTAssertNil(try container.store.fetch(FetchDescriptor<FoodEntryEntity>()).first?.ownerUID)
        XCTAssertEqual(
            container.accountDataNamespaceService.currentDataNamespaceUID(),
            "user-b"
        )
    }

    func testRecordSignedOutLocalUserDataNamespaceClearsActiveNamespace() async throws {
        let container = try AppContainer(inMemory: true)
        await container.prepareLocalUserDataNamespace(uid: "signed-in-user")

        await container.recordSignedOutLocalUserDataNamespace()

        XCTAssertNil(container.accountDataNamespaceService.currentDataNamespaceUID())
    }

    func testReconcileSignedInProfileRoutesToMainAfterNamespacePreparation() async throws {
        let container = try AppContainer(inMemory: true)
        _ = try container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        try seedUnownedFoodRow(in: container.store)

        let coordinator = AuthGateCoordinator(container: container)
        await coordinator.reconcileSignedInProfile(uid: "signed-in-user", isFreshSignIn: true)

        XCTAssertEqual(coordinator.rootModel.state, .main)
        XCTAssertEqual(
            try container.store.fetch(FetchDescriptor<FoodEntryEntity>()).first?.ownerUID,
            "signed-in-user"
        )
    }

    func testReconcileSignedInProfilePreservesAccountMismatchWithoutBackfill() async throws {
        let container = try AppContainer(inMemory: true)
        _ = try container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-a"
        )
        try seedUnownedFoodRow(in: container.store)

        let coordinator = AuthGateCoordinator(container: container)
        await coordinator.reconcileSignedInProfile(uid: "user-b", isFreshSignIn: true)

        XCTAssertEqual(coordinator.rootModel.state, .accountProfileMismatch)
        XCTAssertNil(try container.store.fetch(FetchDescriptor<FoodEntryEntity>()).first?.ownerUID)
    }

    // MARK: - Fixtures

    private func seedUnownedFoodRow(in store: SwiftDataStore) throws {
        let context = store.modelContext
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: context)
        let food = try XCTUnwrap(
            try context.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == seeded.foodID }
        )
        food.ownerUID = nil
        try context.save()
    }
}
