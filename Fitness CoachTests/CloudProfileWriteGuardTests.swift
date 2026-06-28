//
//  CloudProfileWriteGuardTests.swift
//  Fitness CoachTests
//
//  Forma — Cloud profile write authorization guards (Stage 7).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CloudProfileWriteGuardTests: XCTestCase {

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
            userProfileService: container.userProfileService,
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

    func testSameOwnerProfileEditUploads() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )

        try await harness.bootstrapService.saveProfileToCloud(
            uid: "signed-in-user",
            intent: .ownedProfileUpdate
        )

        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(harness.cloudStore.fetchCallCount, 0)
    }

    func testNewOnboardingCloudMissingUploads() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "signed-in-user")

        XCTAssertEqual(outcome, .uploadedToCloud)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(
            try harness.container.userProfileService.getCurrentProfile()?.ownerUID,
            "signed-in-user"
        )
    }

    func testUserConfirmedReplaceUploadsDespiteExistingCloud() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await harness.coordinator.uploadDevicePlanAfterConflict(uid: "signed-in-user")

        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(
            try harness.container.userProfileService.getCurrentProfile()?.ownerUID,
            "signed-in-user"
        )
    }

    func testOwnerMismatchUploadIsBlocked() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        do {
            try await harness.bootstrapService.saveProfileToCloud(
                uid: "signed-in-user",
                intent: .ownedProfileUpdate
            )
            XCTFail("Expected owner mismatch to block upload")
        } catch let error as CloudProfileWriteError {
            XCTAssertEqual(
                error,
                .blocked(.ownerMismatch(localOwnerUID: "other-user", signedInUID: "signed-in-user"))
            )
        }

        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testUnownedLocalCloudUnknownUploadIsBlocked() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        do {
            try await harness.bootstrapService.syncOnboardingProfileToCloud(
                uid: "signed-in-user",
                intent: .newProfileInitialUpload
            )
            XCTFail("Expected existing cloud profile to block initial upload")
        } catch let error as CloudProfileWriteError {
            XCTAssertEqual(error, .blocked(.cloudProfileExists))
        }

        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testCloudFetchFailureBlocksUpload() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        harness.cloudStore.fetchError = NSError(domain: "test", code: 1)

        do {
            try await harness.bootstrapService.syncOnboardingProfileToCloud(
                uid: "signed-in-user",
                intent: .newProfileInitialUpload
            )
            XCTFail("Expected cloud lookup failure to block upload")
        } catch let error as CloudProfileWriteError {
            XCTAssertEqual(error, .blocked(.cloudLookupFailed))
        }

        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testFitnessActionCenterDoesNotOverwriteCloudForMismatchedOwner() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness()
        try harness.seedProfile(ownerUID: "other-user")
        _ = try harness.actionCenter.ensureTodayLog()

        let newTargets = DailyLogServiceTestSupport.alternateTargets
        _ = try harness.actionCenter.updatePlan(UserProfileUpdate(targets: newTargets))

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testFitnessActionCenterUploadsForMatchingOwner() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness()
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        let newTargets = DailyLogServiceTestSupport.alternateTargets
        _ = try harness.actionCenter.updatePlan(UserProfileUpdate(targets: newTargets))

        try await harness.waitForCloudSave()

        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(harness.cloudStore.lastSavedUID, "test-user-1")
    }
}
