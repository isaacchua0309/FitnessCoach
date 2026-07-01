//
//  AccountProfileMismatchTests.swift
//  Fitness CoachTests
//
//  Forma — Account mismatch route and resolution actions (Stage 5).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountProfileMismatchTests: XCTestCase {

    private struct Harness {
        let container: AppContainer
        let cloudStore: MockCloudUserProfileStore
        let syncStore: ProfileCloudSyncStore
        let bootstrapService: ProfileBootstrapService
        let coordinator: ProfileBootstrapCoordinatorService
    }

    private func makeHarness() throws -> Harness {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let syncStore = ProfileCloudSyncStore(userDefaults: container.onboardingUserDefaults)
        let bootstrapService = ProfileBootstrapService(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            cloudStore: cloudStore,
            cloudSyncStore: syncStore
        )
        let coordinator = ProfileBootstrapCoordinatorService(
            profileBootstrapService: bootstrapService,
            cloudSyncStore: syncStore
        )
        return Harness(
            container: container,
            cloudStore: cloudStore,
            syncStore: syncStore,
            bootstrapService: bootstrapService,
            coordinator: coordinator
        )
    }

    func testOwnerMismatchMapsToAccountMismatchRoute() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "signed-in-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: "other-user",
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: true
            )
        )

        XCTAssertEqual(decision, .showAccountMismatch(uid: "signed-in-user"))

        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "signed-in-user"),
            rootState: .accountProfileMismatch
        )
        XCTAssertEqual(shellRoute, .accountProfileMismatch)
    }

    func testRestoreGoogleAccountPlanFetchesCloud() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        let outcome = await harness.coordinator.restoreGoogleAccountPlan(uid: "signed-in-user")

        XCTAssertEqual(outcome, .restoredToMain)
        XCTAssertEqual(harness.cloudStore.fetchCallCount, 1)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
        XCTAssertEqual(
            try harness.container.userProfileService.getCurrentProfile()?.ownerUID,
            "signed-in-user"
        )
        XCTAssertTrue(harness.syncStore.isSyncedForUID("signed-in-user"))
    }

    func testRestoreCloudFoundReplacesLocalAndRoutesMain() async throws {
        let harness = try makeHarness()
        var cloudProfile = ProfileTestFixtures.sampleProfile
        cloudProfile.targets.calorieTarget = 1_888
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument(for: cloudProfile)
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.restoreGoogleAccountPlan(uid: "signed-in-user")

        XCTAssertEqual(outcome, .restoredToMain)
        let restored = try XCTUnwrap(try harness.container.userProfileService.getCurrentProfile())
        XCTAssertEqual(restored.targets.calorieTarget, 1_888)
        XCTAssertEqual(restored.ownerUID, "signed-in-user")
        XCTAssertEqual(
            RootProfileRouteResolver.resolve(bootstrapResult: .main),
            .main
        )
    }

    func testRestoreCloudMissingRoutesToMissingCloudProfile() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        let outcome = await harness.coordinator.restoreGoogleAccountPlan(uid: "signed-in-user")

        XCTAssertEqual(outcome, .missingCloudProfile)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testRestoreCloudFailureReturnsFailureOutcome() async throws {
        let harness = try makeHarness()
        harness.cloudStore.fetchError = NSError(domain: "test.cloud", code: 9)
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        let outcome = await harness.coordinator.restoreGoogleAccountPlan(uid: "signed-in-user")

        XCTAssertEqual(outcome, .cloudFetchFailed)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testUseDeviceProfileDoesNotUploadImmediatelyWhenCloudFound() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        let outcome = await harness.coordinator.prepareUseDeviceProfile(uid: "signed-in-user")

        guard case .cloudProfileConflict = outcome else {
            return XCTFail("Expected conflict, got \(outcome)")
        }
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
        XCTAssertEqual(
            try harness.container.userProfileService.getCurrentProfile()?.ownerUID,
            "other-user"
        )
    }

    func testUseDeviceProfileRequiresConfirmationWhenCloudMissing() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        let outcome = await harness.coordinator.prepareUseDeviceProfile(uid: "signed-in-user")

        XCTAssertEqual(outcome, .requiresLocalLinkConfirmation)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
        XCTAssertEqual(
            try harness.container.userProfileService.getCurrentProfile()?.ownerUID,
            "other-user"
        )
    }

    func testConfirmLinkLocalProfileAssignsOwnerWithoutUpload() throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        let profile = try harness.coordinator.confirmLinkLocalProfileToAccount(uid: "signed-in-user")

        XCTAssertEqual(profile.ownerUID, "signed-in-user")
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testSignOutPolicyPreservesLocalProfile() throws {
        XCTAssertFalse(AuthLogoutPolicy.deletesLocalProfileOnSignOut)

        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        XCTAssertNotNil(try harness.container.userProfileService.getCurrentProfile())
    }
}

extension AccountMismatchRestoreOutcome: Equatable {}
extension AccountMismatchUseDeviceOutcome: Equatable {
    static func == (lhs: AccountMismatchUseDeviceOutcome, rhs: AccountMismatchUseDeviceOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.requiresLocalLinkConfirmation, .requiresLocalLinkConfirmation):
            return true
        case (.cloudFetchFailed, .cloudFetchFailed):
            return true
        case (.cloudProfileConflict(let left), .cloudProfileConflict(let right)):
            return left == right
        default:
            return false
        }
    }
}
