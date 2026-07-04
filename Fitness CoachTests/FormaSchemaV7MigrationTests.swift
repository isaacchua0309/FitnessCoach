//
//  FormaSchemaV7MigrationTests.swift
//  Fitness CoachTests
//
//  Forma — Account persistence Phase 1 + Phase 3 SwiftData schema migration tests.
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

    func testActiveSchemaIsV9() {
        XCTAssertEqual(FormaModelContainer.schema.versionIdentifier, FormaSchemaV9.versionIdentifier)
    }

    func testV7SchemaRegistersSyncMetadataEntities() {
        XCTAssertTrue(FormaSchemaV7AccountSyncVerification.syncMetadataEntitiesAreRegisteredInV7Schema())
        XCTAssertTrue(FormaSchemaV7AccountSyncVerification.coachEntitiesAreExcludedFromAccountSyncMetadata())
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
        XCTAssertEqual(food.syncStatus, .localOnly)
    }

    func testFreshInstallDefaultsSyncMetadataToLocalOnly() throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: context)

        let food = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == seeded.foodID })
        XCTAssertEqual(food.syncStatus, .localOnly)
        XCTAssertEqual(food.syncAttemptCount, 0)
        XCTAssertNil(food.cloudId)
        XCTAssertNil(food.cloudUpdatedAt)
        XCTAssertNil(food.lastSyncedAt)
        XCTAssertNil(food.lastSyncError)
        XCTAssertNil(food.deletedAt)
        XCTAssertNil(food.lastMutationId)
        XCTAssertNil(food.nextRetryAt)
    }

    func testV6StoreMigratesToV9AndPreservesNutritionLogsWithLocalOnlyStatus() throws {
        let legacyContainer = try FormaModelContainer.makeLegacyContainer(FormaSchemaV6.self, storeURL: storeURL)
        let legacyContext = ModelContext(legacyContainer)
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: legacyContext)

        _ = legacyContainer
        let migratedContainer = try FormaModelContainer.migrateContainer(at: storeURL)
        let context = ModelContext(migratedContainer)

        XCTAssertTrue(FormaSwiftDataMigrationGate.isCoachV2MigrationComplete)

        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(DailyLogEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(FoodEntryEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(WaterEntryEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(WeightEntryEntity.self, in: migratedContainer), 1)

        let food = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == seeded.foodID })
        XCTAssertEqual(food.name, "Chicken rice")
        XCTAssertEqual(food.calories, 520)
        XCTAssertEqual(food.syncStatus, .localOnly)
        XCTAssertNil(food.ownerUID)

        let migrationService = AccountMigrationService(
            store: SwiftDataStore(container: migratedContainer),
            userProfileService: UserProfileService(store: SwiftDataStore(container: migratedContainer)),
            uidProvider: StubSchemaMigrationUIDProvider(currentUID: "signed-in-user")
        )
        try migrationService.backfillSchemaV7BookkeepingIfNeeded()

        XCTAssertEqual(food.entitySchemaVersion, UserDataEntitySchema.currentEntitySchemaVersion)
        XCTAssertEqual(food.localUpdatedAt, food.updatedAt)

        let dailyLog = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyLogEntity>()).first { $0.id == seeded.dailyLogID })
        XCTAssertEqual(dailyLog.syncStatus, .localOnly)

        let water = try XCTUnwrap(try context.fetch(FetchDescriptor<WaterEntryEntity>()).first { $0.id == seeded.waterID })
        XCTAssertEqual(water.syncStatus, .localOnly)

        let weight = try XCTUnwrap(try context.fetch(FetchDescriptor<WeightEntryEntity>()).first { $0.id == seeded.weightID })
        XCTAssertEqual(weight.syncStatus, .localOnly)
    }

    func testEntryCloudIDDefaultsToStableLocalEntityID() {
        let id = UUID()
        XCTAssertEqual(AccountDataSyncMetadataSupport.entryCloudID(for: id), id.uuidString)
    }

    func testDailyLogCloudIDUsesLocalDateString() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 4))!
        XCTAssertEqual(
            AccountDataSyncMetadataSupport.dailyLogCloudID(for: date, calendar: calendar),
            "2026-07-04"
        )
    }
}

@MainActor
private final class StubSchemaMigrationUIDProvider: AccountUIDProviding {
    let currentUID: String?

    init(currentUID: String?) {
        self.currentUID = currentUID
    }
}
