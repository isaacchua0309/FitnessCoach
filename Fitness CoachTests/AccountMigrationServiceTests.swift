//
//  AccountMigrationServiceTests.swift
//  Fitness CoachTests
//
//  Forma — Account persistence Phase 1 safe ownership backfill tests.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountMigrationServiceTests: XCTestCase {

    func testSafeBackfillStampsUnownedNutritionAndCoachRows() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        try seedUnownedNutritionAndCoachRows(in: harness.store)

        let report = try await harness.migrationService.runSafeBackfill(for: "signed-in-user")

        XCTAssertTrue(report.canBackfill)
        XCTAssertEqual(report.reason, "profile_owner_matches_session")
        XCTAssertEqual(report.dailyLogsUpdated, 1)
        XCTAssertEqual(report.foodEntriesUpdated, 1)
        XCTAssertEqual(report.waterEntriesUpdated, 1)
        XCTAssertEqual(report.weightEntriesUpdated, 1)
        XCTAssertEqual(report.dailyReviewsUpdated, 1)
        XCTAssertEqual(report.coachMessagesUpdated, 1)
        XCTAssertEqual(report.timelineEventsUpdated, 1)

        let food = try XCTUnwrap(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first)
        XCTAssertEqual(food.ownerUID, "signed-in-user")
        XCTAssertNotNil(food.localUpdatedAt)

        let message = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()).first
        )
        XCTAssertEqual(message.userId, "signed-in-user")
    }

    func testSafeBackfillAllowedWhenProfileIsUnowned() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)
        try seedUnownedFoodRow(in: harness.store)

        let report = try await harness.migrationService.runSafeBackfill(for: "signed-in-user")

        XCTAssertTrue(report.canBackfill)
        XCTAssertEqual(report.reason, "unowned_local_profile")
        XCTAssertEqual(report.foodEntriesUpdated, 1)
        XCTAssertEqual(
            try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first?.ownerUID,
            "signed-in-user"
        )
    }

    func testBackfillRefusesWhenProfileOwnerMismatchesSession() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-a"
        )
        try seedUnownedFoodRow(in: harness.store)

        let report = try await harness.migrationService.runSafeBackfill(for: "user-b")

        XCTAssertFalse(report.canBackfill)
        XCTAssertEqual(report.reason, "local_profile_owner_mismatch")
        XCTAssertEqual(report.totalRowsUpdated, 0)
        XCTAssertNil(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first?.ownerUID)
    }

    func testBackfillRefusesWhenForeignOwnedNutritionRowsExist() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        try seedUnownedFoodRow(in: harness.store)
        try seedOwnedFoodRow(in: harness.store, ownerUID: "other-user", name: "Foreign meal")

        let report = try await harness.migrationService.runSafeBackfill(for: "signed-in-user")

        XCTAssertFalse(report.canBackfill)
        XCTAssertEqual(report.reason, "foreign_owned_nutrition_rows_present")
        let unownedFoodCount = try harness.store.fetch(FetchDescriptor<FoodEntryEntity>())
            .filter { $0.ownerUID == nil }
            .count
        XCTAssertEqual(unownedFoodCount, 1)
    }

    func testBackfillRefusesWhenForeignOwnedCoachRowsExist() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        try seedUnownedCoachMessage(in: harness.store)
        try seedOwnedCoachMessage(in: harness.store, userId: "other-user")

        let report = try await harness.migrationService.runSafeBackfill(for: "signed-in-user")

        XCTAssertFalse(report.canBackfill)
        XCTAssertEqual(report.reason, "foreign_owned_coach_rows_present")
        let unownedCoachCount = try harness.store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>())
            .filter { $0.userId == nil }
            .count
        XCTAssertEqual(unownedCoachCount, 1)
    }

    func testBackfillIsIdempotent() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        try seedUnownedFoodRow(in: harness.store)

        let first = try await harness.migrationService.runSafeBackfill(for: "signed-in-user")
        let second = try await harness.migrationService.runSafeBackfill(for: "signed-in-user")

        XCTAssertEqual(first.foodEntriesUpdated, 1)
        XCTAssertTrue(second.canBackfill)
        XCTAssertEqual(second.foodEntriesUpdated, 0)
        XCTAssertEqual(second.totalRowsUpdated, 0)
    }

    func testEvaluateBackfillDryRunDoesNotPersistChanges() throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        try seedUnownedFoodRow(in: harness.store)

        let report = try harness.migrationService.evaluateBackfill(for: "signed-in-user")

        XCTAssertTrue(report.canBackfill)
        XCTAssertEqual(report.foodEntriesUpdated, 1)
        XCTAssertNil(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first?.ownerUID)
    }

    func testRunSafeBackfillForCurrentUserUsesAuthProvider() async throws {
        let harness = try makeHarness()
        harness.uidHolder.uid = nil

        let missingUIDReport = try await harness.migrationService.runSafeBackfillForCurrentUser()
        XCTAssertFalse(missingUIDReport.canBackfill)
        XCTAssertEqual(missingUIDReport.reason, "missing_signed_in_uid")

        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        try seedUnownedFoodRow(in: harness.store)
        harness.uidHolder.uid = "signed-in-user"

        let report = try await harness.migrationService.runSafeBackfillForCurrentUser()
        XCTAssertTrue(report.canBackfill)
        XCTAssertEqual(report.foodEntriesUpdated, 1)
    }

    // MARK: - Harness

    private struct Harness {
        let store: SwiftDataStore
        let profileService: UserProfileService
        let migrationService: AccountMigrationService
        let uidHolder: TestMigrationUIDHolder
    }

    private func makeHarness() throws -> Harness {
        let dateProvider = FixedDailyLogTestDateProvider(now: ProfileTestFixtures.referenceDate)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let uidHolder = TestMigrationUIDHolder()
        let migrationService = AccountMigrationService(
            store: store,
            userProfileService: profileService,
            uidProvider: StubMigrationUIDProvider(holder: uidHolder)
        )

        return Harness(
            store: store,
            profileService: profileService,
            migrationService: migrationService,
            uidHolder: uidHolder
        )
    }

    private func seedUnownedFoodRow(in store: SwiftDataStore) throws {
        let context = store.modelContext
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: context)
        _ = seeded
    }

    private func seedUnownedNutritionAndCoachRows(in store: SwiftDataStore) throws {
        let context = store.modelContext
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: context)
        let review = DailyReviewEntity(
            id: UUID(),
            dailyLogId: seeded.dailyLogID,
            summaryText: "Summary",
            caloriesSummary: "520",
            proteinSummary: "35",
            hydrationSummary: "500",
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: "Keep going",
            createdAt: ProfileTestFixtures.referenceDate
        )
        context.insert(review)

        let message = CoachChatTranscriptMessageEntity(
            id: UUID(),
            userId: nil,
            roleRawValue: "assistant",
            text: "Legacy coach reply",
            createdAt: ProfileTestFixtures.referenceDate,
            relatedDailyLogId: nil,
            relatedEntryId: nil,
            hasImageAttachment: false,
            imageKindRaw: nil,
            imageSourceRaw: nil,
            thumbnailJPEG: nil,
            fullImageJPEG: nil,
            originalImageByteSize: nil,
            photoSessionID: nil,
            relatedUserMessageID: nil,
            photoAnalysisLinkKindRaw: nil,
            structuredContentJSON: nil,
            updatedAt: ProfileTestFixtures.referenceDate,
            localUpdatedAt: nil
        )
        context.insert(message)

        _ = try FormaSwiftDataMigrationTestSupport.seedMalformedTimelineEvent(in: context)
        try context.save()
    }

    private func seedOwnedFoodRow(
        in store: SwiftDataStore,
        ownerUID: String,
        name: String
    ) throws {
        let context = store.modelContext
        let dailyLogID = UUID()
        let dailyLog = DailyLogEntity(
            id: dailyLogID,
            ownerUID: ownerUID,
            date: ProfileTestFixtures.referenceDate,
            weightKg: nil,
            calorieTarget: 2_000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: nil,
            aggressivenessRawValue: "moderate",
            caloriesConsumed: 0,
            proteinConsumed: 0,
            carbsConsumed: 0,
            fatConsumed: 0,
            fiberConsumed: nil,
            sodiumConsumed: nil,
            waterConsumedMl: 0,
            steps: 0,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: ProfileTestFixtures.referenceDate,
            updatedAt: ProfileTestFixtures.referenceDate
        )
        let food = FoodEntryEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: dailyLogID,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: name,
            quantity: 1,
            unit: "serving",
            calories: 300,
            protein: 20,
            carbs: 30,
            fat: 10,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: ProfileTestFixtures.referenceDate,
            updatedAt: ProfileTestFixtures.referenceDate
        )
        food.dailyLog = dailyLog
        context.insert(dailyLog)
        context.insert(food)
        try context.save()
    }

    private func seedUnownedCoachMessage(in store: SwiftDataStore) throws {
        let context = store.modelContext
        let message = CoachChatTranscriptMessageEntity(
            id: UUID(),
            userId: nil,
            roleRawValue: "assistant",
            text: "Legacy coach reply",
            createdAt: ProfileTestFixtures.referenceDate,
            relatedDailyLogId: nil,
            relatedEntryId: nil,
            hasImageAttachment: false,
            imageKindRaw: nil,
            imageSourceRaw: nil,
            thumbnailJPEG: nil,
            fullImageJPEG: nil,
            originalImageByteSize: nil,
            photoSessionID: nil,
            relatedUserMessageID: nil,
            photoAnalysisLinkKindRaw: nil,
            structuredContentJSON: nil,
            updatedAt: ProfileTestFixtures.referenceDate,
            localUpdatedAt: nil
        )
        context.insert(message)
        try context.save()
    }

    private func seedOwnedCoachMessage(in store: SwiftDataStore, userId: String) throws {
        let context = store.modelContext
        let message = CoachChatTranscriptMessageEntity(
            id: UUID(),
            userId: userId,
            roleRawValue: "assistant",
            text: "Foreign coach reply",
            createdAt: ProfileTestFixtures.referenceDate,
            relatedDailyLogId: nil,
            relatedEntryId: nil,
            hasImageAttachment: false,
            imageKindRaw: nil,
            imageSourceRaw: nil,
            thumbnailJPEG: nil,
            fullImageJPEG: nil,
            originalImageByteSize: nil,
            photoSessionID: nil,
            relatedUserMessageID: nil,
            photoAnalysisLinkKindRaw: nil,
            structuredContentJSON: nil,
            updatedAt: ProfileTestFixtures.referenceDate
        )
        context.insert(message)
        try context.save()
    }
}

@MainActor
private final class TestMigrationUIDHolder {
    var uid: String?
}

@MainActor
private struct StubMigrationUIDProvider: AccountUIDProviding {
    let holder: TestMigrationUIDHolder

    var currentUID: String? {
        holder.uid
    }
}
