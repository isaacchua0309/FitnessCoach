//
//  MultiUserNutritionIsolationTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 local UID hardening for nutrition data.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class MultiUserNutritionIsolationTests: XCTestCase {

    private var sessionUID = TestSessionUIDHolder()

    override func tearDown() {
        sessionUID.uid = nil
        super.tearDown()
    }

    func testUserBDoesNotSeeUserAFoodAfterAccountSwitch() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-a"
        )

        sessionUID.uid = "user-a"
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "User A Oatmeal", calories: 320),
            date: harness.today
        )

        sessionUID.uid = "user-b"
        await harness.namespaceService.prepareForSignedInUID("user-b")

        let entriesForB = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertTrue(entriesForB.isEmpty)
    }

    func testSameUserReLoginPreservesOwnedFood() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-a"
        )

        sessionUID.uid = "user-a"
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "User A Salad", calories: 450),
            date: harness.today
        )
        await harness.namespaceService.prepareForSignedInUID("user-a")

        await harness.namespaceService.prepareForSignOut()
        sessionUID.uid = "user-a"
        await harness.namespaceService.prepareForSignedInUID("user-a")

        let entriesForA = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertEqual(entriesForA.count, 1)
        XCTAssertEqual(entriesForA.first?.name, "User A Salad")
    }

    func testForeignAccountSwitchHidesPriorUserFoodViaFiltering() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-a"
        )

        sessionUID.uid = "user-a"
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "User A Salad", calories: 450),
            date: harness.today
        )
        await harness.namespaceService.prepareForSignedInUID("user-a")

        sessionUID.uid = "user-b"
        await harness.namespaceService.prepareForSignedInUID("user-b")
        XCTAssertTrue(try harness.foodLogService.getFoodEntries(for: harness.today).isEmpty)

        sessionUID.uid = "user-a"
        await harness.namespaceService.prepareForSignedInUID("user-a")
        let entriesForA = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertEqual(entriesForA.count, 1)
        XCTAssertEqual(entriesForA.first?.name, "User A Salad")
    }

    func testNewWritesStampCurrentFirebaseUID() throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )

        sessionUID.uid = "signed-in-user"
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Stamped Meal", calories: 500),
            date: harness.today
        )

        let descriptor = FetchDescriptor<FoodEntryEntity>()
        let entities = try harness.store.fetch(descriptor)
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities.first?.ownerUID, "signed-in-user")
        XCTAssertEqual(entities.first?.entitySchemaVersion, UserDataEntitySchema.currentEntitySchemaVersion)
        XCTAssertNotNil(entities.first?.localUpdatedAt)
    }

    func testWritesWithoutUIDAreRejected() throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )

        sessionUID.uid = nil
        XCTAssertThrowsError(
            try harness.foodLogService.addFoodEntry(
                DailyLogServiceTestSupport.foodDraft(name: "Blocked Meal", calories: 300),
                date: harness.today
            )
        )
    }

    private func seedLegacyUnownedFoodEntry(in harness: Harness) throws {
        let context = harness.store.modelContext
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: context)
        let food = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == seeded.foodID })
        food.name = "Legacy Meal"
        food.calories = 400
        try context.save()
    }

    func testLegacyUnownedRowsBackfillToProfileOwner() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )

        try seedLegacyUnownedFoodEntry(in: harness)

        sessionUID.uid = "signed-in-user"
        let report = try await harness.migrationService.runSafeBackfill(for: "signed-in-user")
        XCTAssertTrue(report.canBackfill)
        XCTAssertEqual(report.foodEntriesUpdated, 1)

        let entries = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "Legacy Meal")
    }

    func testMealSurvivesPersistenceRoundTrip() throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )

        sessionUID.uid = "signed-in-user"
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Kill-Safe Meal", calories: 600),
            date: harness.today
        )

        let entries = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.calories, 600)
    }

    // MARK: - Harness

    private struct Harness {
        let store: SwiftDataStore
        let profileService: UserProfileService
        let dailyLogService: DailyLogService
        let foodLogService: FoodLogService
        let migrationService: AccountMigrationService
        let namespaceService: AccountDataNamespaceService
        let today: Date
    }

    private func makeHarness() throws -> Harness {
        let dateProvider = FixedDailyLogTestDateProvider(now: ProfileTestFixtures.referenceDate)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let uidProvider = { [sessionUID] in sessionUID.uid }
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider,
            currentUIDProvider: uidProvider
        )
        let foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService,
            currentUIDProvider: uidProvider
        )
        let migrationService = AccountMigrationService(
            store: store,
            userProfileService: profileService,
            uidProvider: StubNamespaceUIDProvider(uidProvider: uidProvider)
        )
        let namespaceDefaults = UserDefaults(
            suiteName: "MultiUserNutritionIsolationTests.\(UUID().uuidString)"
        )!
        let namespaceService = AccountDataNamespaceService(
            userDefaults: namespaceDefaults,
            uidProvider: StubNamespaceUIDProvider(uidProvider: uidProvider)
        )

        return Harness(
            store: store,
            profileService: profileService,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            migrationService: migrationService,
            namespaceService: namespaceService,
            today: dateProvider.now
        )
    }
}

@MainActor
private final class TestSessionUIDHolder {
    var uid: String?
}

@MainActor
private struct StubNamespaceUIDProvider: AccountUIDProviding {
    let uidProvider: () -> String?

    var currentUID: String? {
        uidProvider()
    }
}
