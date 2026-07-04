//
//  SignOutHygieneTests.swift
//  Fitness CoachTests
//
//  Forma — Sign-out preserves local data but clears session sync hints (Stage 9).
//

import SwiftData
import XCTest
@testable import Fitness_Coach

@MainActor
final class SignOutHygieneTests: XCTestCase {

    func testSignOutPolicyPreservesLocalProfile() throws {
        XCTAssertTrue(AuthLogoutPolicy.preservesLocalUserDataOnSignOut)

        let base = try DailyLogServiceTestSupport.makeHarness()
        _ = try base.seedProfile()
        let syncStore = ProfileCloudSyncStore(
            userDefaults: UserDefaults(suiteName: "SignOutHygieneTests.\(UUID().uuidString)")!
        )
        syncStore.markSynced(uid: "signed-in-user", updatedAt: ProfileTestFixtures.referenceDate)

        AuthLogoutPolicy.clearTransientSessionMetadata(cloudSyncStore: syncStore)

        XCTAssertNotNil(try base.profileService.getCurrentProfile())
    }

    func testSignOutPreservesOwnerUID() throws {
        let base = try DailyLogServiceTestSupport.makeHarness()
        _ = try base.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        let syncStore = ProfileCloudSyncStore(
            userDefaults: UserDefaults(suiteName: "SignOutHygieneTests.\(UUID().uuidString)")!
        )
        syncStore.markSynced(uid: "signed-in-user", updatedAt: ProfileTestFixtures.referenceDate)

        AuthLogoutPolicy.clearTransientSessionMetadata(cloudSyncStore: syncStore)

        XCTAssertEqual(
            try base.profileService.getCurrentProfile()?.ownerUID,
            "signed-in-user"
        )
    }

    func testSignOutClearsSyncMetadata() {
        XCTAssertTrue(AuthLogoutPolicy.clearsCloudSyncMetadataOnSignOut)

        let syncStore = ProfileCloudSyncStore(
            userDefaults: UserDefaults(suiteName: "SignOutHygieneTests.\(UUID().uuidString)")!
        )
        syncStore.markSynced(uid: "signed-in-user", updatedAt: ProfileTestFixtures.referenceDate)

        AuthLogoutPolicy.clearTransientSessionMetadata(cloudSyncStore: syncStore)

        XCTAssertNil(syncStore.lastSyncedUID)
        XCTAssertNil(syncStore.lastSyncedProfileUpdatedAt)
        XCTAssertFalse(syncStore.isSyncedForUID("signed-in-user"))
    }

    func testSameUserSignInUsesOwnerUIDAfterSignOutHygiene() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "signed-in-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: "signed-in-user",
                isFreshSignIn: true,
                rootState: .main,
                isSyncedForCurrentUID: false
            )
        )

        XCTAssertEqual(decision, .routeToMain)
    }

    func testDifferentUserSignInShowsMismatchAfterSignOutHygiene() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "other-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: "signed-in-user",
                isFreshSignIn: true,
                rootState: .main,
                isSyncedForCurrentUID: false,
                cloudResult: .found(CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate))
            )
        )

        XCTAssertEqual(decision, .showAccountMismatch(uid: "other-user"))
    }

    func testUnownedLocalWithoutSyncHintRequiresCloudLookupAfterSignOutHygiene() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "signed-in-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .main,
                isSyncedForCurrentUID: false
            )
        )

        XCTAssertEqual(decision, .requireOwnershipCloudLookup(uid: "signed-in-user"))
    }

    func testSignOutPreservesNutritionDataOnDisk() async throws {
        let base = try DailyLogServiceTestSupport.makeHarness(sessionUID: "signed-in-user")
        _ = try base.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        _ = try base.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Post-logout meal", calories: 480),
            date: base.today
        )

        let container = try AppContainer(inMemory: true)
        await container.recordSignedOutLocalUserDataNamespace()
        AuthLogoutPolicy.clearTransientSessionMetadata(cloudSyncStore: container.profileCloudSyncStore)

        XCTAssertEqual(try base.store.fetch(FetchDescriptor<FoodEntryEntity>()).count, 1)
        XCTAssertEqual(
            try base.store.fetch(FetchDescriptor<FoodEntryEntity>()).first?.ownerUID,
            "signed-in-user"
        )
    }

    func testSignOutClearsDataNamespaceTracking() async throws {
        let container = try AppContainer(inMemory: true)
        await container.prepareLocalUserDataNamespace(uid: "signed-in-user")
        XCTAssertEqual(
            container.accountDataNamespaceService.currentDataNamespaceUID(),
            "signed-in-user"
        )

        await container.recordSignedOutLocalUserDataNamespace()

        XCTAssertNil(container.accountDataNamespaceService.currentDataNamespaceUID())
    }
}
