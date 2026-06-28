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

    private typealias Harness = ProfileBootstrapTestSupport.Harness

    private func makeHarness() throws -> Harness {
        try ProfileBootstrapTestSupport.makeHarness()
    }

    func testSameOwnerProfileEditUploads() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
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
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.makeCoordinator().resolveOnboardingCompletion(uid: "signed-in-user")

        XCTAssertEqual(outcome, .uploadedToCloud)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(
            try harness.profileService.getCurrentProfile()?.ownerUID,
            "signed-in-user"
        )
    }

    func testUserConfirmedReplaceUploadsDespiteExistingCloud() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await harness.makeCoordinator().uploadDevicePlanAfterConflict(uid: "signed-in-user")

        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(
            try harness.profileService.getCurrentProfile()?.ownerUID,
            "signed-in-user"
        )
    }

    func testOwnerMismatchUploadIsBlocked() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(
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
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)
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
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)
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

        await harness.waitForPendingCloudWork()

        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testFitnessActionCenterUploadsForMatchingOwner() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness()
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        let newTargets = DailyLogServiceTestSupport.alternateTargets
        _ = try harness.actionCenter.updatePlan(UserProfileUpdate(targets: newTargets))

        await harness.waitForCloudSave()

        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(harness.cloudStore.lastSavedUID, "test-user-1")
    }
}
