//
//  ProfilePlanConflictFlowTests.swift
//  Fitness CoachTests
//
//  Forma — Generalized profile plan conflict flows (Stage 6).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class ProfilePlanConflictFlowTests: XCTestCase {

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

    func testOnboardingCompletionCloudFoundRoutesToConflict() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "signed-in-user")

        guard case .cloudProfileConflict = outcome else {
            return XCTFail("Expected onboarding completion conflict")
        }

        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "signed-in-user"),
            rootState: .onboardingCloudProfileConflict
        )
        XCTAssertEqual(shellRoute, .onboardingCloudProfileConflict)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testUnownedLocalCloudFoundRoutesToConflict() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "signed-in-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: .found(CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate))
            )
        )

        XCTAssertEqual(decision, .showProfileConflict(uid: "signed-in-user"))
    }

    func testOwnerMismatchRoutesToAccountMismatchNotConflict() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "signed-in-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: "other-user",
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: true,
                cloudResult: .found(CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate))
            )
        )

        XCTAssertEqual(decision, .showAccountMismatch(uid: "signed-in-user"))
    }

    func testAccountMismatchUseDeviceWithCloudFoundRoutesToConflict() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        let outcome = await harness.coordinator.prepareUseDeviceProfile(uid: "signed-in-user")

        guard case .cloudProfileConflict = outcome else {
            return XCTFail("Expected conflict before overwrite")
        }
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testRestoreExistingReplacesLocalAndSetsOwnerUID() throws {
        let harness = try makeHarness()
        var cloudProfile = ProfileTestFixtures.sampleProfile
        cloudProfile.targets.calorieTarget = 1_888
        let cloudDocument = ProfileTestFixtures.cloudDocument(for: cloudProfile)
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let restored = try harness.bootstrapService.adoptCloudProfile(
            cloudDocument,
            uid: "signed-in-user"
        )

        XCTAssertEqual(restored.ownerUID, "signed-in-user")
        XCTAssertEqual(restored.targets.calorieTarget, 1_888)
        XCTAssertTrue(harness.syncStore.isSyncedForUID("signed-in-user"))
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testUploadDevicePlanOnlyAfterExplicitCoordinatorCall() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)

        try await harness.coordinator.uploadDevicePlanAfterConflict(uid: "signed-in-user")

        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(harness.cloudStore.lastSavedUID, "signed-in-user")
        XCTAssertEqual(try harness.container.userProfileService.getCurrentProfile()?.ownerUID, "signed-in-user")
    }
}
