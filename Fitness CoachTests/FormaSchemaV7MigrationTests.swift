//
//  FormaSchemaV7MigrationTests.swift
//  Fitness CoachTests
//
//  Forma — Account persistence Phase 1 SwiftData schema V7 migration tests.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class FormaSchemaV7MigrationTests: XCTestCase {

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

    func testActiveSchemaIsV7() {
        XCTAssertEqual(FormaModelContainer.schema.versionIdentifier, FormaSchemaV7.versionIdentifier)
    }

    func testFreshInstallEntitiesStampBookkeepingFields() throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let now = FormaSwiftDataMigrationTestSupport.referenceDate

        let food = FoodEntryEntity(
            id: UUID(),
            ownerUID: "signed-in-user",
            dailyLogId: UUID(),
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Test meal",
            quantity: 1,
            unit: "serving",
            calories: 400,
            protein: 20,
            carbs: 40,
            fat: 10,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: now,
            updatedAt: now
        )
        context.insert(food)
        try context.save()

        XCTAssertEqual(food.ownerUID, "signed-in-user")
        XCTAssertEqual(food.localUpdatedAt, now)
        XCTAssertEqual(food.entitySchemaVersion, UserDataEntitySchema.currentEntitySchemaVersion)
    }

    func testPreV6StoreMigratesToV7AndPreservesNutritionLogs() throws {
        let legacyContainer = try FormaModelContainer.makeLegacyContainer(FormaSchemaV6.self, storeURL: storeURL)
        let legacyContext = ModelContext(legacyContainer)
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: legacyContext)

        _ = legacyContainer
        let migratedContainer = try FormaModelContainer.migrateContainer(at: storeURL)

        XCTAssertTrue(FormaSwiftDataMigrationGate.isCoachV2MigrationComplete)
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: "forma.swiftdata.schemaVersion"),
            FormaSwiftDataMigrationGate.activeSchemaVersion
        )

        let context = ModelContext(migratedContainer)
        let food = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryEntity>()).first)
        XCTAssertEqual(food.id, seeded.foodID)
        XCTAssertEqual(food.name, "Chicken rice")
        XCTAssertNil(food.ownerUID)

        let migrationService = AccountMigrationService(
            store: SwiftDataStore(container: migratedContainer),
            userProfileService: UserProfileService(store: SwiftDataStore(container: migratedContainer)),
            uidProvider: StubSchemaMigrationUIDProvider(currentUID: "signed-in-user")
        )
        try migrationService.backfillSchemaV7BookkeepingIfNeeded()

        XCTAssertEqual(food.entitySchemaVersion, UserDataEntitySchema.currentEntitySchemaVersion)
        XCTAssertEqual(food.localUpdatedAt, food.updatedAt)
    }
}

@MainActor
private struct StubSchemaMigrationUIDProvider: AccountUIDProviding {
    let currentUID: String?
}
