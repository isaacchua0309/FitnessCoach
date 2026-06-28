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

    private struct Harness {
        let container: AppContainer
        let cloudStore: MockCloudUserProfileStore
        let syncStore: ProfileCloudSyncStore
        let coordinator: ProfileBootstrapCoordinatorService
    }

    private func makeHarness() throws -> Harness {
        let cloudStore = MockCloudUserProfileStore()
        let container = try AppContainer(inMemory: true)
        let syncStore = container.profileCloudSyncStore
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
            coordinator: coordinator
        )
    }

    func testOnboardingUploadFailureMapsToUploadFailedState() async throws {
        let harness = try makeHarness()
        harness.cloudStore.saveError = NSError(domain: "test", code: 1)
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "signed-in-user")

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
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "signed-in-user")

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
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        harness.cloudStore.saveError = NSError(domain: "test", code: 1)

        do {
            try await harness.coordinator.syncLocalProfileToCloud(uid: "signed-in-user")
            XCTFail("Expected reconcile upload to fail")
        } catch {
            XCTAssertFalse(harness.syncStore.isSyncedForUID("signed-in-user"))
        }

        XCTAssertNotNil(try harness.container.userProfileService.getCurrentProfile())

        let route = AppRouteResolver.resolve(
            authState: .signedIn(uid: "signed-in-user"),
            rootState: .cloudProfileUploadFailed
        )
        XCTAssertEqual(route, .cloudProfileUploadFailed)
    }

    func testRetrySuccessMarksSyncedAndAllowsMain() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await harness.coordinator.retryCloudProfileUpload(
            uid: "signed-in-user",
            context: .reconcileUpload
        )

        XCTAssertTrue(harness.syncStore.isSyncedForUID("signed-in-user"))
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
    }

    func testContinueDespiteFailureClearsSyncMetadata() throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        harness.syncStore.markSynced(uid: "signed-in-user", updatedAt: ProfileTestFixtures.referenceDate)
        harness.syncStore.clear()

        let rootModel = harness.container.makeRootModel()
        rootModel.presentCloudProfileUploadFailed()
        XCTAssertFalse(harness.syncStore.isSyncedForUID("signed-in-user"))

        rootModel.continueDespiteCloudUploadFailure()
        XCTAssertEqual(rootModel.state, .main)
        XCTAssertFalse(harness.syncStore.isSyncedForUID("signed-in-user"))
    }

    func testUploadFailureDoesNotOverwriteCloud() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "other-user"
        )

        do {
            try await harness.coordinator.retryCloudProfileUpload(
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
        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(harness.cloudUploadFailureNotifier.pendingContext, .profileEdit)
        XCTAssertFalse(harness.syncStore.isSyncedForUID("test-user-1"))
    }
}
