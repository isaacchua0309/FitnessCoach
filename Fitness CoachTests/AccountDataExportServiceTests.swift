//
//  AccountDataExportServiceTests.swift
//  Fitness CoachTests
//
//  Forma — Account data export foundation tests (Phase 6).
//

import SwiftData
import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDataExportServiceTests: XCTestCase {

    private let userA = "user-a"
    private let userB = "user-b"
    private let referenceDate = ProfileTestFixtures.referenceDate

    private var sessionUID: String?
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var store: SwiftDataStore!
    private var profileService: UserProfileService!
    private var foodLogService: FoodLogService!
    private var exportService: AccountDataExportService!
    private var syncCursorStore: AccountSyncCursorStore!
    private var restoreStateStore: AccountRestoreStateStore!
    private var profileCloudSyncStore: ProfileCloudSyncStore!
    private var outboxStore: SwiftDataAccountSyncOutboxStore!

    override func setUp() async throws {
        try await super.setUp()
        sessionUID = userA
        defaultsSuiteName = "AccountDataExportServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!

        let container = try FormaModelContainer.makeContainer(inMemory: true)
        store = SwiftDataStore(container: container)
        outboxStore = SwiftDataAccountSyncOutboxStore(store: store)
        let dateProvider = FixedDailyLogTestDateProvider(now: referenceDate)
        profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let uidProvider = { [weak self] in self?.sessionUID }
        let mutationTracker = AccountLocalMutationTracker(
            outbox: outboxStore,
            ownerUIDProvider: { uidProvider() ?? "" }
        )
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider,
            mutationTracker: mutationTracker
        )
        foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: mutationTracker
        )

        syncCursorStore = AccountSyncCursorStore(userDefaults: defaults)
        restoreStateStore = AccountRestoreStateStore(userDefaults: defaults)
        profileCloudSyncStore = ProfileCloudSyncStore(userDefaults: defaults)

        exportService = AccountDataExportService(
            store: store,
            accountSyncOutboxStore: outboxStore,
            profileCloudSyncStore: profileCloudSyncStore,
            accountSyncCursorStore: syncCursorStore,
            accountRestoreStateStore: restoreStateStore,
            currentSessionUIDProvider: { [weak self] in self?.sessionUID },
            isExportEnabled: { true }
        )
    }

    override func tearDown() async throws {
        exportService = nil
        foodLogService = nil
        profileService = nil
        store = nil
        outboxStore = nil
        syncCursorStore = nil
        restoreStateStore = nil
        profileCloudSyncStore = nil
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaultsSuiteName = nil
        defaults = nil
        sessionUID = nil
        try await super.tearDown()
    }

    func testExportDisabledByFeatureFlag() async {
        let disabledService = AccountDataExportService(
            store: store,
            accountSyncOutboxStore: outboxStore,
            profileCloudSyncStore: profileCloudSyncStore,
            accountSyncCursorStore: syncCursorStore,
            accountRestoreStateStore: restoreStateStore,
            currentSessionUIDProvider: { [weak self] in self?.sessionUID },
            isExportEnabled: { false }
        )

        do {
            _ = try await disabledService.buildExportBundle(for: userA)
            XCTFail("Expected featureDisabled")
        } catch let error as AccountDataExportError {
            XCTAssertEqual(error, .featureDisabled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExportIncludesOnlyCurrentUIDData() async throws {
        try seedUserAData()
        try insertOwnedFood(name: "User B Meal", calories: 510, ownerUID: userB, imageUrl: "file:///secret.jpg")
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: userB)
        sessionUID = userA

        let bundle = try await exportService.buildExportBundle(for: userA)

        XCTAssertEqual(bundle.uid, userA)
        XCTAssertEqual(bundle.foodEntries.count, 1)
        XCTAssertEqual(bundle.foodEntries.first?.name, "User A Meal")
        XCTAssertFalse(bundle.foodEntries.contains(where: { $0.name == "User B Meal" }))
        XCTAssertEqual(bundle.profile?.name, ProfileTestFixtures.sampleDraft.name)
        XCTAssertFalse(bundle.dailyLogs.isEmpty)
    }

    func testExportDoesNotIncludeRawImages() async throws {
        try seedUserAData(imageUrl: "file:///meal-photo.jpg")
        sessionUID = userA

        let fileURL = try await exportService.writeExportFile(for: userA)
        let json = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(fileURL.path.contains(AccountDataExportSupport.exportDirectoryName))
        XCTAssertTrue(json.contains("User A Meal"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("imageUrl"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("imageurl"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("file://"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("lastSyncError"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("trace"))
    }

    func testExportDoesNotIncludeOtherUserData() async throws {
        try seedUserAData()
        try insertOwnedFood(name: "User B Meal", calories: 510, ownerUID: userB)
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: userB)
        sessionUID = userA

        let bundle = try await exportService.buildExportBundle(for: userA)

        XCTAssertEqual(bundle.foodEntries.count, 1)
        XCTAssertEqual(bundle.foodEntries.first?.name, "User A Meal")
        XCTAssertNotEqual(bundle.uid, userB)
    }

    func testExportRejectsMismatchedSessionUID() async throws {
        try seedUserAData()
        sessionUID = userB

        do {
            _ = try await exportService.buildExportBundle(for: userA)
            XCTFail("Expected uidMismatch")
        } catch let error as AccountDataExportError {
            XCTAssertEqual(error, .uidMismatch)
        }
    }

    func testExportIncludesSyncMetadataSummary() async throws {
        try seedUserAData()
        sessionUID = userA
        profileCloudSyncStore.markSynced(uid: userA, updatedAt: referenceDate)
        syncCursorStore.updateForegroundRefresh(uid: userA, date: referenceDate)
        restoreStateStore.markSkipped(uid: userA, reason: .afterSignIn, now: referenceDate)

        let bundle = try await exportService.buildExportBundle(for: userA)

        XCTAssertEqual(bundle.syncMetadata.lastSuccessfulProfileSyncAt, referenceDate)
        XCTAssertEqual(bundle.syncMetadata.lastForegroundRefreshAt, referenceDate)
        XCTAssertEqual(bundle.syncMetadata.restoreStatus, AccountRestoreStatus.skipped.rawValue)
    }

    // MARK: - Helpers

    private func seedUserAData(imageUrl: String? = nil) throws {
        sessionUID = userA
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: userA)
        _ = try foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "User A Meal", calories: 420),
            date: referenceDate
        )
        if let imageUrl {
            let foods = try store.fetch(FetchDescriptor<FoodEntryEntity>())
            foods.first?.imageUrl = imageUrl
            try store.save()
        }
    }

    private func insertOwnedFood(
        name: String,
        calories: Int,
        ownerUID: String,
        imageUrl: String? = nil
    ) throws {
        let food = FoodEntryEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: UUID(),
            mealTypeRawValue: MealType.lunch.rawValue,
            name: name,
            quantity: 1,
            unit: "serving",
            calories: calories,
            protein: 20,
            carbs: 30,
            fat: 10,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: imageUrl,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        store.modelContext.insert(food)
        try store.save()
    }
}
