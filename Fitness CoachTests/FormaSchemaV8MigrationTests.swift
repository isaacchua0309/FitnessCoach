//
//  FormaSchemaV8MigrationTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync outbox schema migration tests (Phase 3).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class FormaSchemaV8MigrationTests: XCTestCase {

    private var storeURL: URL!

    override func setUp() {
        super.setUp()
        FormaSwiftDataMigrationGate.resetForTesting()
        storeURL = FormaSwiftDataMigrationTestSupport.makeTemporaryStoreURL()
    }

    override func tearDown() {
        FormaSwiftDataMigrationTestSupport.removeStore(at: storeURL)
        FormaSwiftDataMigrationGate.resetForTesting()
        storeURL = nil
        super.tearDown()
    }

    func testActiveSchemaIsV9WithSyncOutboxEntity() {
        XCTAssertTrue(FormaSchemaV9AccountSyncVerification.syncMetadataEntitiesAreRegisteredInActiveSchema())
        XCTAssertTrue(FormaSchemaV9AccountSyncVerification.syncOutboxEntityIsRegisteredInActiveSchema())
        XCTAssertTrue(FormaSchemaCoachV2Verification.coachV2EntitiesAreRegisteredInActiveSchema())
        XCTAssertTrue(FormaSchemaV9AccountSyncVerification.coachEntitiesAreExcludedFromAccountSyncMetadata())
    }

    func testFreshInstallSupportsEmptyOutboxTable() throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(AccountSyncMutationEntity.self, in: container), 0)
    }

    func testV7StoreMigratesToV8AndPreservesNutritionLogs() throws {
        let legacyContainer = try FormaModelContainer.makeLegacyContainer(FormaSchemaV7.self, storeURL: storeURL)
        let legacyContext = ModelContext(legacyContainer)
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: legacyContext)

        _ = legacyContainer
        let migratedContainer = try FormaModelContainer.migrateContainer(at: storeURL)
        let context = ModelContext(migratedContainer)

        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(DailyLogEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(FoodEntryEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(AccountSyncMutationEntity.self, in: migratedContainer), 0)

        let food = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == seeded.foodID })
        XCTAssertEqual(food.name, "Chicken rice")
        XCTAssertEqual(food.syncStatus, .localOnly)
    }
}
