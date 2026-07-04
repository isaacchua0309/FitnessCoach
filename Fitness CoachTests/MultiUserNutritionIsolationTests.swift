//
//  MultiUserNutritionIsolationTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 local UID hardening for nutrition data.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class MultiUserNutritionIsolationTests: XCTestCase {

    private var sessionUID = TestSessionUIDHolder()

    override func tearDown() {
        sessionUID.uid = nil
        super.tearDown()
    }

    func testUserBDoesNotSeeUserAFoodAfterAccountSwitch() throws {
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
        try harness.namespaceService.prepareForUID("user-b", isFreshSignIn: true)

        let entriesForB = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertTrue(entriesForB.isEmpty)
    }

    func testSameUserReLoginPreservesOwnedFood() throws {
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
        try harness.namespaceService.prepareForUID("user-a", isFreshSignIn: true)

        harness.namespaceService.recordSignedOut()
        sessionUID.uid = "user-a"
        try harness.namespaceService.prepareForUID("user-a", isFreshSignIn: true)

        let entriesForA = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertEqual(entriesForA.count, 1)
        XCTAssertEqual(entriesForA.first?.name, "User A Salad")
    }

    func testForeignAccountSwitchQuarantinesPriorUserFood() throws {
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
        try harness.namespaceService.prepareForUID("user-a", isFreshSignIn: true)

        sessionUID.uid = "user-b"
        try harness.namespaceService.prepareForUID("user-b", isFreshSignIn: true)
        XCTAssertTrue(try harness.foodLogService.getFoodEntries(for: harness.today).isEmpty)

        sessionUID.uid = "user-a"
        try harness.namespaceService.prepareForUID("user-a", isFreshSignIn: true)
        XCTAssertTrue(try harness.foodLogService.getFoodEntries(for: harness.today).isEmpty)
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
    }

    func testLegacyUnownedRowsBackfillToProfileOwner() throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )

        sessionUID.uid = nil
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Legacy Meal", calories: 400),
            date: harness.today
        )

        sessionUID.uid = "signed-in-user"
        try harness.migrationService.backfillUnownedRows(sessionUID: "signed-in-user")

        let entries = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "Legacy Meal")
    }

    func testMealSurvivesPersistenceRoundTrip() throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        sessionUID.uid = nil
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
            userProfileService: profileService
        )
        let namespaceService = AccountDataNamespaceService(
            store: store,
            migrationService: migrationService,
            lastActiveUIDStore: LastActiveAccountUIDStore(
                userDefaults: UserDefaults(suiteName: "MultiUserNutritionIsolationTests.\(UUID().uuidString)")!
            )
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
