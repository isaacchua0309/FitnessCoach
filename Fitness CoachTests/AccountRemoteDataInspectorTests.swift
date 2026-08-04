//
//  AccountRemoteDataInspectorTests.swift
//  Fitness CoachTests
//
//  Forma — Account remote data inspector tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

final class AccountRemoteDataInspectorTests: XCTestCase {

    private let uidA = "user-a"
    private let uidB = "user-b"
    private let referenceDate = ProfileFixtures.referenceDate
    private var localDate: String {
        CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
    }
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var remoteStore: (any AccountDataRemoteStore)!
    private var profileStore: TestCloudUserProfileStore!
    private var inspector: AccountRemoteDataInspector!

    override func setUp() async throws {
        try await super.setUp()
        remoteStore = InMemoryAccountDataRemoteStore()
        profileStore = TestCloudUserProfileStore()
        inspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: remoteStore,
            calendar: calendar
        )
    }

    override func tearDown() async throws {
        inspector = nil
        profileStore = nil
        remoteStore = nil
        try await super.tearDown()
    }

    func testRemoteInspectorDetectsNoCloudData() async {
        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertEqual(status.uid, uidA)
        XCTAssertFalse(status.hasCloudProfile)
        XCTAssertFalse(status.hasRecentDailyLogs)
        XCTAssertFalse(status.hasRecentFoodEntries)
        XCTAssertFalse(status.hasRecentWaterEntries)
        XCTAssertFalse(status.hasWeightHistory)
        XCTAssertFalse(status.hasDailyReviews)
        XCTAssertFalse(status.hasAnyRestorableData)
        XCTAssertNil(status.newestRemoteUpdatedAt)
        XCTAssertNil(status.failure)
    }

    func testRemoteInspectorDetectsCloudProfile() async throws {
        profileStore.document = CloudUserProfileDocument(
            profile: AccountRestoreTestSupport.makeProfile(ownerUID: uidA, referenceDate: referenceDate),
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertTrue(status.hasCloudProfile)
        XCTAssertTrue(status.hasAnyRestorableData)
        XCTAssertEqual(status.newestRemoteUpdatedAt, referenceDate)
        XCTAssertNil(status.failure)
    }

    func testRemoteInspectorDetectsRecentDailyLogs() async throws {
        try await remoteStore.saveDailyLog(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
                userId: uidA,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: uidA
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertTrue(status.hasRecentDailyLogs)
        XCTAssertTrue(status.hasAnyRestorableData)
        XCTAssertNil(status.failure)
    }

    func testRemoteInspectorClassifiesOffline() async {
        profileStore.fetchError = URLError(.notConnectedToInternet)
        remoteStore = ThrowingAccountDataRemoteStore(error: URLError(.notConnectedToInternet))
        inspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: remoteStore,
            calendar: calendar
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertFalse(status.hasAnyRestorableData)
        XCTAssertEqual(status.failure, .offline)
    }

    func testRemoteInspectorClassifiesPermissionDenied() async {
        profileStore.fetchError = NSError(
            domain: "FIRFirestoreErrorDomain",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."]
        )
        remoteStore = ThrowingAccountDataRemoteStore(error: NSError(
            domain: "FIRFirestoreErrorDomain",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."]
        ))
        inspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: remoteStore,
            calendar: calendar
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertEqual(status.failure, .permissionDenied)
    }

    func testNoCloudDataReturnsEmptyStatusWithoutFailure() async {
        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertEqual(status.uid, uidA)
        XCTAssertFalse(status.hasCloudProfile)
        XCTAssertFalse(status.hasAnyRestorableData)
        XCTAssertNil(status.failure)
    }

    func testRecentNutritionDataIsDetectedWithinBoundedRanges() async throws {
        profileStore.document = CloudUserProfileDocument(
            profile: AccountRestoreTestSupport.makeProfile(ownerUID: uidA, referenceDate: referenceDate),
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )

        try await remoteStore.saveDailyLog(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
                userId: uidA,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: uidA
        )
        try await remoteStore.saveFoodEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
                userId: uidA,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: uidA
        )
        try await remoteStore.saveWaterEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.waterEntry(
                userId: uidA,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: uidA
        )
        try await remoteStore.saveWeightEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
                userId: uidA,
                localDate: localDate,
                referenceDate: referenceDate,
                entryId: "weight-1"
            ),
            uid: uidA
        )
        try await remoteStore.saveDailyReview(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyReview(
                userId: uidA,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: uidA
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertTrue(status.hasRecentDailyLogs)
        XCTAssertTrue(status.hasRecentFoodEntries)
        XCTAssertTrue(status.hasRecentWaterEntries)
        XCTAssertTrue(status.hasWeightHistory)
        XCTAssertTrue(status.hasDailyReviews)
        XCTAssertTrue(status.hasAnyRestorableData)
        XCTAssertNil(status.failure)
    }

    func testDeletedRemoteDocumentsAreNotCounted() async throws {
        var dailyLog = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: uidA,
            localDate: localDate,
            referenceDate: referenceDate
        )
        dailyLog.deletedAt = referenceDate
        try await remoteStore.saveDailyLog(dailyLog, uid: uidA)

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertFalse(status.hasRecentDailyLogs)
        XCTAssertFalse(status.hasAnyRestorableData)
        XCTAssertNil(status.failure)
    }

    func testOutOfRangeWeightHistoryIsIgnored() async throws {
        let oldDate = try XCTUnwrap(calendar.date(byAdding: .day, value: -40, to: referenceDate))
        let oldLocalDate = CloudAccountDataDateCodec.localDateString(from: oldDate, calendar: calendar)
        try await remoteStore.saveWeightEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
                userId: uidA,
                localDate: oldLocalDate,
                referenceDate: referenceDate,
                entryId: "old-weight"
            ),
            uid: uidA
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertFalse(status.hasWeightHistory)
        XCTAssertFalse(status.hasAnyRestorableData)
    }

    func testOfflineFailureIsReturnedWhenNoCloudDataFound() async {
        profileStore.fetchError = URLError(.notConnectedToInternet)
        remoteStore = ThrowingAccountDataRemoteStore(error: URLError(.notConnectedToInternet))
        inspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: remoteStore,
            calendar: calendar
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertFalse(status.hasAnyRestorableData)
        XCTAssertEqual(status.failure, .offline)
    }

    func testPermissionDeniedFailureIsClassified() async {
        profileStore.fetchError = NSError(
            domain: "FIRFirestoreErrorDomain",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."]
        )
        remoteStore = ThrowingAccountDataRemoteStore(
            error: NSError(
                domain: "FIRFirestoreErrorDomain",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."]
            )
        )
        inspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: remoteStore,
            calendar: calendar
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertEqual(status.failure, .permissionDenied)
    }

    func testDecodingFailureIsClassified() async {
        profileStore.fetchError = AccountDataRemoteStoreError.decodingFailed
        remoteStore = ThrowingAccountDataRemoteStore(error: AccountDataRemoteStoreError.decodingFailed)
        inspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: remoteStore,
            calendar: calendar
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertEqual(status.failure, .decodingFailed)
    }

    func testFailureIsSuppressedWhenRestorableDataExists() async throws {
        profileStore.document = CloudUserProfileDocument(
            profile: AccountRestoreTestSupport.makeProfile(ownerUID: uidA, referenceDate: referenceDate),
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )
        remoteStore = ThrowingAccountDataRemoteStore(error: URLError(.notConnectedToInternet))
        inspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: remoteStore,
            calendar: calendar
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertTrue(status.hasCloudProfile)
        XCTAssertTrue(status.hasAnyRestorableData)
        XCTAssertNil(status.failure)
    }

    func testInspectionIsUIDScoped() async throws {
        try await remoteStore.saveFoodEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
                userId: uidB,
                localDate: localDate,
                referenceDate: referenceDate,
                entryId: "other-food"
            ),
            uid: uidB
        )

        let status = await inspector.inspectRemoteData(for: uidA, today: referenceDate)

        XCTAssertFalse(status.hasRecentFoodEntries)
        XCTAssertFalse(status.hasAnyRestorableData)
    }

    // MARK: - Fixtures

    private func makeProfile(ownerUID: String) throws -> UserProfile {
        var draft = ProfileFixtures.sampleDraft
        draft.targets = ProfileFixtures.sampleTargets
        let profile = UserProfile(
            id: UUID(),
            ownerUID: ownerUID,
            name: draft.name,
            birthDate: draft.birthDate,
            age: draft.age,
            sex: draft.sex,
            heightCm: draft.heightCm,
            currentWeightKg: draft.currentWeightKg,
            goalWeightKg: draft.goalWeightKg,
            estimatedBodyFatPercentage: draft.estimatedBodyFatPercentage,
            activityLevel: draft.activityLevel,
            trainingFrequencyPerWeek: draft.trainingFrequencyPerWeek,
            averageSteps: draft.averageSteps,
            dietPreference: draft.dietPreference,
            unitSystem: draft.unitSystem,
            targets: draft.targets,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            lastPlanUpdateReason: .onboarding
        )
        return profile
    }
}

// MARK: - Test doubles

private struct TestCloudUserProfileStore: CloudUserProfileStoring, @unchecked Sendable {
    var document: CloudUserProfileDocument?
    var fetchError: Error?

    func fetch(uid: String) async throws -> CloudUserProfileDocument? {
        _ = uid
        if let fetchError {
            throw fetchError
        }
        return document
    }

    func save(profile: UserProfile, uid: String) async throws {
        _ = profile
        _ = uid
    }
}

private actor ThrowingAccountDataRemoteStore: AccountDataRemoteStore {
    let error: Error

    init(error: Error) {
        self.error = error
    }

    func fetchDailyLog(uid: String, localDate: String) async throws -> CloudDailyLogDocument? {
        throw error
    }

    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws {
        throw error
    }

    func fetchDailyLogs(uid: String, from startDate: String, to endDate: String) async throws -> [CloudDailyLogDocument] {
        throw error
    }

    func fetchFoodEntries(uid: String, localDate: String) async throws -> [CloudFoodEntryDocument] {
        throw error
    }

    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String) async throws {
        throw error
    }

    func deleteFoodEntry(uid: String, localDate: String, entryId: String) async throws {
        throw error
    }

    func fetchWaterEntries(uid: String, localDate: String) async throws -> [CloudWaterEntryDocument] {
        throw error
    }

    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String) async throws {
        throw error
    }

    func deleteWaterEntry(uid: String, localDate: String, entryId: String) async throws {
        throw error
    }

    func fetchWeightEntries(
        uid: String,
        from startDate: String?,
        to endDate: String?
    ) async throws -> [CloudWeightEntryDocument] {
        throw error
    }

    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws {
        throw error
    }

    func deleteWeightEntry(uid: String, entryId: String) async throws {
        throw error
    }

    func fetchDailyReview(uid: String, localDate: String) async throws -> CloudDailyReviewDocument? {
        throw error
    }

    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String) async throws {
        throw error
    }

    func deleteDailyReview(uid: String, localDate: String) async throws {
        throw error
    }

    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument? {
        throw error
    }

    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws {
        throw error
    }

    func fetchDailyLogsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyLogDocument] {
        throw error
    }

    func fetchFoodEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudFoodEntryDocument] {
        throw error
    }

    func fetchWaterEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudWaterEntryDocument] {
        throw error
    }

    func fetchWeightEntriesUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudWeightEntryDocument] {
        throw error
    }

    func fetchDailyReviewsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyReviewDocument] {
        throw error
    }

    func fetchCloudProfileUpdatedSince(uid: String, since: Date?) async throws -> CloudUserProfileDocument? {
        throw error
    }
}
