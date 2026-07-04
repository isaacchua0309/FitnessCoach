//
//  AccountDataNamespaceServiceTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 local data namespace tracking tests.
//

import SwiftData
import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDataNamespaceServiceTests: XCTestCase {

    func testPrepareForSignedInUIDStoresLastActiveUID() async {
        let defaults = UserDefaults(suiteName: "AccountDataNamespaceServiceTests.\(UUID().uuidString)")!
        let service = AccountDataNamespaceService(
            userDefaults: defaults,
            uidProvider: StubAccountUIDProvider(currentUID: "user-a")
        )

        await service.prepareForSignedInUID("user-a")

        XCTAssertEqual(service.currentDataNamespaceUID(), "user-a")
        XCTAssertEqual(
            defaults.string(forKey: AccountDataNamespaceService.lastActiveUIDKey),
            "user-a"
        )
    }

    func testIsAccountSwitchDetectsDifferentUID() {
        let service = AccountDataNamespaceService(
            userDefaults: UserDefaults(suiteName: "AccountDataNamespaceServiceTests.\(UUID().uuidString)")!,
            uidProvider: StubAccountUIDProvider(currentUID: "user-b")
        )

        XCTAssertFalse(service.isAccountSwitch(from: nil, to: "user-a"))
        XCTAssertFalse(service.isAccountSwitch(from: "user-a", to: "user-a"))
        XCTAssertTrue(service.isAccountSwitch(from: "user-a", to: "user-b"))
    }

    func testPrepareForSignOutClearsActiveNamespaceButDoesNotDeleteRows() async throws {
        let defaults = UserDefaults(suiteName: "AccountDataNamespaceServiceTests.\(UUID().uuidString)")!
        let service = AccountDataNamespaceService(
            userDefaults: defaults,
            uidProvider: StubAccountUIDProvider(currentUID: "user-a")
        )
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let profileService = UserProfileService(store: store)
        _ = try profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-a"
        )

        let food = FoodEntryEntity(
            id: UUID(),
            ownerUID: "user-a",
            dailyLogId: UUID(),
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Preserved meal",
            quantity: 1,
            unit: "serving",
            calories: 400,
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
        store.modelContext.insert(food)
        try store.save()

        await service.prepareForSignedInUID("user-a")
        await service.prepareForSignOut()

        XCTAssertNil(service.currentDataNamespaceUID())
        XCTAssertNil(defaults.string(forKey: AccountDataNamespaceService.lastActiveUIDKey))
        XCTAssertEqual(try store.fetch(FetchDescriptor<FoodEntryEntity>()).count, 1)
        XCTAssertNotNil(try profileService.getCurrentProfile())
    }

    func testAuthAccountUIDProviderUsesAuthManager() {
        let authManager = AuthManager()
        let provider = AuthAccountUIDProvider(authManager: authManager)

        XCTAssertNil(provider.currentUID)
    }
}

@MainActor
private struct StubAccountUIDProvider: AccountUIDProviding {
    let currentUID: String?
}
