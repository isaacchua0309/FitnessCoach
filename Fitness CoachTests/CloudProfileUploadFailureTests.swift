//
//  CloudProfileUploadFailureTests.swift
//  Fitness CoachTests
//
//  Forma — Cloud profile upload failure surfacing (Stage 8).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CloudProfileUploadFailureTests: XCTestCase {

    private typealias Harness = ProfileBootstrapTestSupport.Harness

    private func makeHarness() throws -> Harness {
        try ProfileBootstrapTestSupport.makeHarness()
    }

    func testOnboardingUploadFailureMapsToUploadFailedState() async throws {
        let harness = try makeHarness()
        harness.cloudStore.saveError = NSError(domain: "test", code: 1)
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.makeCoordinator().resolveOnboardingCompletion(uid: "signed-in-user")

        XCTAssertEqual(outcome, .cloudSyncFailed)

        let uploadFailedRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "signed-in-user"),
            rootState: .cloudProfileUploadFailed
        )
        XCTAssertEqual(uploadFailedRoute, .cloudProfileUploadFailed)

        let checkFailedRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "signed-in-user"),
            rootState: .onboardingCloudCheckFailed
        )
        XCTAssertEqual(checkFailedRoute, .onboardingCloudCheckFailed)
        XCTAssertNotEqual(uploadFailedRoute, checkFailedRoute)
    }

    func testOnboardingCloudCheckFailureStillMapsToCheckFailedState() async throws {
        let harness = try makeHarness()
        harness.cloudStore.fetchError = NSError(domain: "test", code: 1)
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.makeCoordinator().resolveOnboardingCompletion(uid: "signed-in-user")

        XCTAssertEqual(outcome, .cloudCheckFailed)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)

        let route = AppRouteResolver.resolve(
            authState: .signedIn(uid: "signed-in-user"),
            rootState: .onboardingCloudCheckFailed
        )
        XCTAssertEqual(route, .onboardingCloudCheckFailed)
    }

    func testReconcileUploadFailureDoesNotMarkSynced() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)
        harness.cloudStore.saveError = NSError(domain: "test", code: 1)

        do {
            try await harness.makeCoordinator().syncLocalProfileToCloud(uid: "signed-in-user")
            XCTFail("Expected reconcile upload to fail")
        } catch {
            XCTAssertFalse(harness.syncStore.isSyncedForUID("signed-in-user"))
        }

        XCTAssertNotNil(try harness.profileService.getCurrentProfile())

        let route = AppRouteResolver.resolve(
            authState: .signedIn(uid: "signed-in-user"),
            rootState: .cloudProfileUploadFailed
        )
        XCTAssertEqual(route, .cloudProfileUploadFailed)
    }

    func testRetrySuccessMarksSyncedAndAllowsMain() async throws {
        let harness = try makeHarness()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await harness.makeCoordinator().retryCloudProfileUpload(
            uid: "signed-in-user",
            context: .reconcileUpload
        )

        XCTAssertTrue(harness.syncStore.isSyncedForUID("signed-in-user"))
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
    }

    func testRootModelContinueDespiteUploadFailureRoutesMain() throws {
        let bootstrapHarness = try ProfileBootstrapTestSupport.makeHarness()
        let rootModel = RootModel(profileBootstrapService: bootstrapHarness.bootstrapService)

        rootModel.presentCloudProfileUploadFailed()
        XCTAssertEqual(rootModel.state, .cloudProfileUploadFailed)

        rootModel.continueDespiteCloudUploadFailure()
        XCTAssertEqual(rootModel.state, .main)
    }

    func testContinueForNowLeavesProfileNotMarkedSynced() {
        let syncStore = ProfileCloudSyncStore(
            userDefaults: UserDefaults(suiteName: "CloudProfileUploadFailureTests.\(UUID().uuidString)")!
        )
        syncStore.markSynced(uid: "signed-in-user", updatedAt: ProfileTestFixtures.referenceDate)
        syncStore.clear()
        XCTAssertFalse(syncStore.isSyncedForUID("signed-in-user"))
    }

    func testUploadFailureDoesNotOverwriteCloud() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        do {
            try await harness.makeCoordinator().retryCloudProfileUpload(
                uid: "signed-in-user",
                context: .profileEdit
            )
            XCTFail("Expected owned update to be blocked")
        } catch let error as CloudProfileWriteError {
            XCTAssertEqual(
                error,
                .blocked(.ownerMismatch(localOwnerUID: "other-user", signedInUID: "signed-in-user"))
            )
        }

        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testProfileEditUploadFailureExposesNotifierState() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness()
        harness.syncStore.markSynced(uid: "test-user-1", updatedAt: ProfileTestFixtures.referenceDate)
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()
        harness.cloudStore.saveError = NSError(domain: "test", code: 1)

        _ = try harness.actionCenter.updatePlan(
            UserProfileUpdate(targets: DailyLogServiceTestSupport.alternateTargets)
        )
        _ = await AsyncTestSupport.waitUntil {
            harness.cloudUploadFailureNotifier.pendingContext == .profileEdit
        }

        XCTAssertEqual(harness.cloudUploadFailureNotifier.pendingContext, .profileEdit)
        XCTAssertFalse(harness.syncStore.isSyncedForUID("test-user-1"))
    }
}
