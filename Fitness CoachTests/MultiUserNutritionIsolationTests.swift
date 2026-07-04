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
    private var storeURL: URL?

    override func tearDown() {
        sessionUID.uid = nil
        if let storeURL {
            FormaSwiftDataMigrationTestSupport.removeStore(at: storeURL)
            self.storeURL = nil
        }
        super.tearDown()
    }

    // MARK: - Cross-user isolation

    func testUserBDoesNotSeeUserAFoodAfterAccountSwitch() async throws {
        let harness = try makeHarness()
        try seedProfile(ownerUID: "user-a", in: harness)

        try await logFood(name: "User A Oatmeal", calories: 320, harness: harness, uid: "user-a")
        try await switchSession(to: "user-b", harness: harness)

        XCTAssertTrue(try harness.foodLogService.getFoodEntries(for: harness.today).isEmpty)
    }

    func testUserBDoesNotSeeUserAWaterAfterAccountSwitch() async throws {
        let harness = try makeHarness()
        try seedProfile(ownerUID: "user-a", in: harness)

        try await logWater(amountMl: 350, harness: harness, uid: "user-a")
        try await switchSession(to: "user-b", harness: harness)

        XCTAssertTrue(try harness.waterLogService.getWaterEntries(for: harness.today).isEmpty)
        XCTAssertEqual(try harness.waterLogService.getWaterTotal(for: harness.today), 0)
    }

    func testUserBDoesNotSeeUserAWeightAfterAccountSwitch() async throws {
        let harness = try makeHarness()
        try seedProfile(ownerUID: "user-a", in: harness)

        try await logWeight(78.5, harness: harness, uid: "user-a")
        try await switchSession(to: "user-b", harness: harness)

        XCTAssertTrue(
            try harness.weightLogService.getWeightEntries(from: harness.today, to: harness.today).isEmpty
        )
    }

    func testDailyLogTotalsAreScopedByUID() async throws {
        let harness = try makeHarness()
        try seedProfile(ownerUID: "user-a", in: harness)

        try await logFood(name: "User A Lunch", calories: 520, harness: harness, uid: "user-a")
        try await logWater(amountMl: 400, harness: harness, uid: "user-a")

        let logForA = try harness.dailyLogService.getLog(for: harness.today)
        XCTAssertEqual(logForA?.totals.calories, 520)
        XCTAssertEqual(logForA?.waterConsumedMl, 400)

        try await switchSession(to: "user-b", harness: harness)

        let logForB = try harness.dailyLogService.getOrCreateLog(for: harness.today)
        XCTAssertEqual(logForB.totals.calories, 0)
        XCTAssertEqual(logForB.waterConsumedMl, 0)
        XCTAssertTrue(try harness.foodLogService.getFoodEntries(for: harness.today).isEmpty)
        XCTAssertEqual(try harness.waterLogService.getWaterTotal(for: harness.today), 0)
    }

    func testUserADataReturnsWhenUserALogsBackIn() async throws {
        let harness = try makeHarness()
        try seedProfile(ownerUID: "user-a", in: harness)

        try await logFood(name: "User A Salad", calories: 450, harness: harness, uid: "user-a")
        try await switchSession(to: "user-b", harness: harness)
        XCTAssertTrue(try harness.foodLogService.getFoodEntries(for: harness.today).isEmpty)

        try await switchSession(to: "user-a", harness: harness)
        let entriesForA = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertEqual(entriesForA.count, 1)
        XCTAssertEqual(entriesForA.first?.name, "User A Salad")
        XCTAssertEqual(entriesForA.first?.calories, 450)
    }

    // MARK: - Legacy ownership reads

    func testNilOwnerRowsAreNotReturnedToSignedInUser() throws {
        let harness = try makeHarness()
        try seedProfile(ownerUID: "user-a", in: harness)
        try seedLegacyUnownedNutritionRows(in: harness.store)

        sessionUID.uid = "user-a"

        XCTAssertTrue(try harness.foodLogService.getFoodEntries(for: harness.today).isEmpty)
        XCTAssertTrue(try harness.waterLogService.getWaterEntries(for: harness.today).isEmpty)
        XCTAssertTrue(
            try harness.weightLogService.getWeightEntries(from: harness.today, to: harness.today).isEmpty
        )
    }

    // MARK: - Write stamping

    func testNewWritesStampCurrentFirebaseUID() throws {
        let harness = try makeHarness()
        try seedProfile(ownerUID: "signed-in-user", in: harness)

        sessionUID.uid = "signed-in-user"
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Stamped Meal", calories: 500),
            date: harness.today
        )

        let entities = try harness.store.fetch(FetchDescriptor<FoodEntryEntity>())
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities.first?.ownerUID, "signed-in-user")
        XCTAssertEqual(entities.first?.entitySchemaVersion, UserDataEntitySchema.currentEntitySchemaVersion)
        XCTAssertNotNil(entities.first?.localUpdatedAt)
    }

    func testWritesWithoutUIDAreRejected() throws {
        let harness = try makeHarness()
        try seedProfile(ownerUID: "signed-in-user", in: harness)

        sessionUID.uid = nil
        XCTAssertThrowsError(
            try harness.foodLogService.addFoodEntry(
                DailyLogServiceTestSupport.foodDraft(name: "Blocked Meal", calories: 300),
                date: harness.today
            )
        )
    }

    // MARK: - Persistence regression

    func testCommittedMealStillSurvivesStoreReopen() throws {
        let url = FormaSwiftDataMigrationTestSupport.makeTemporaryStoreURL(
            label: "MultiUserNutritionIsolationTests.\(UUID().uuidString)"
        )
        storeURL = url

        let writeHarness = try makeHarness(storeURL: url)
        try seedProfile(ownerUID: "user-a", in: writeHarness)
        sessionUID.uid = "user-a"
        _ = try writeHarness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Kill-Safe Meal", calories: 600),
            date: writeHarness.today
        )

        let readHarness = try makeHarness(storeURL: url)
        sessionUID.uid = "user-a"
        let entries = try readHarness.foodLogService.getFoodEntries(for: readHarness.today)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "Kill-Safe Meal")
        XCTAssertEqual(entries.first?.calories, 600)
        XCTAssertEqual(entries.first?.ownerUID, "user-a")
    }

    // MARK: - Helpers

    private struct Harness {
        let store: SwiftDataStore
        let profileService: UserProfileService
        let dailyLogService: DailyLogService
        let foodLogService: FoodLogService
        let waterLogService: WaterLogService
        let weightLogService: WeightLogService
        let namespaceService: AccountDataNamespaceService
        let today: Date
    }

    private func makeHarness(storeURL: URL? = nil) throws -> Harness {
        let dateProvider = FixedDailyLogTestDateProvider(now: ProfileTestFixtures.referenceDate)
        let container: ModelContainer
        if let storeURL {
            container = try FormaModelContainer.makeContainer(inMemory: false, storeURL: storeURL)
        } else {
            container = try FormaModelContainer.makeContainer(inMemory: true)
        }
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
        let waterLogService = WaterLogService(
            store: store,
            dailyLogService: dailyLogService,
            currentUIDProvider: uidProvider
        )
        let weightLogService = WeightLogService(
            store: store,
            dailyLogService: dailyLogService,
            dateProvider: dateProvider,
            currentUIDProvider: uidProvider
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
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            namespaceService: namespaceService,
            today: dateProvider.now
        )
    }

    @discardableResult
    private func seedProfile(ownerUID: String, in harness: Harness) throws -> UserProfile {
        try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: ownerUID
        )
    }

    private func switchSession(to uid: String, harness: Harness) async throws {
        sessionUID.uid = uid
        await harness.namespaceService.prepareForSignedInUID(uid)
    }

    private func logFood(
        name: String,
        calories: Int,
        harness: Harness,
        uid: String
    ) async throws {
        sessionUID.uid = uid
        await harness.namespaceService.prepareForSignedInUID(uid)
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: name, calories: calories),
            date: harness.today
        )
    }

    private func logWater(
        amountMl: Int,
        harness: Harness,
        uid: String
    ) async throws {
        sessionUID.uid = uid
        await harness.namespaceService.prepareForSignedInUID(uid)
        _ = try harness.waterLogService.addWater(amountMl: amountMl, date: harness.today)
    }

    private func logWeight(
        _ weightKg: Double,
        harness: Harness,
        uid: String
    ) async throws {
        sessionUID.uid = uid
        await harness.namespaceService.prepareForSignedInUID(uid)
        _ = try harness.weightLogService.logWeight(weightKg, date: harness.today)
    }

    private func seedLegacyUnownedNutritionRows(in store: SwiftDataStore) throws {
        let context = store.modelContext
        _ = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: context)
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
