//
//  ProfileBootstrapCoordinatorTests.swift
//  Fitness CoachTests
//
//  Profile bootstrap coordinator — cross-device restore and sync decisions.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class ProfileBootstrapCoordinatorTests: XCTestCase {

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

    // 1. Device A onboarding + sign-in saves cloud profile under UID.
    func testOnboardingCompletionUploadsProfileAndMarksSynced() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "device-a-user")

        XCTAssertEqual(outcome, .uploadedToCloud)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(harness.cloudStore.lastSavedUID, "device-a-user")
        XCTAssertTrue(harness.syncStore.isSyncedForUID("device-a-user"))
    }

    // 2. Device B same UID with empty local store restores cloud profile and routes main.
    func testDeviceBRestoresCloudProfileAndRoutesMain() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let bootstrapResult = try await harness.bootstrapService.resolve(uid: "device-b-user")
        let rootState = RootProfileRouteResolver.resolve(bootstrapResult: bootstrapResult)
        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "device-b-user"),
            rootState: rootState
        )

        XCTAssertEqual(bootstrapResult, .main)
        XCTAssertEqual(rootState, .main)
        XCTAssertEqual(shellRoute, .main)
        XCTAssertNotNil(try harness.container.userProfileService.getCurrentProfile())
        XCTAssertTrue(harness.syncStore.isSyncedForUID("device-b-user"))
    }

    // 3. Signed-in user with cloud profile does not enter onboarding even if local profile missing.
    func testSignedInCloudProfileRoutesMainWithoutOnboarding() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let bootstrapResult = try await harness.bootstrapService.resolve(uid: "returning-user")
        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "returning-user"),
            rootState: RootProfileRouteResolver.resolve(bootstrapResult: bootstrapResult),
            isOnboardingModelReady: true
        )

        XCTAssertEqual(shellRoute, .main)
        XCTAssertNotEqual(shellRoute, .onboarding)
    }

    // 4. Signed-in user with no local and no cloud enters onboarding only after lookup completes.
    func testMissingCloudProfileOnlyAfterLookupCompletes() async throws {
        let harness = try makeHarness()

        let bootstrapResult = try await harness.bootstrapService.resolve(uid: "new-user")
        let rootState = RootProfileRouteResolver.resolve(bootstrapResult: bootstrapResult)
        let loadingRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "new-user"),
            rootState: .loading
        )
        let resolvedRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "new-user"),
            rootState: rootState,
            isOnboardingModelReady: true
        )

        XCTAssertEqual(loadingRoute, .signedInProfileLoading)
        XCTAssertEqual(bootstrapResult, .missingCloudProfile)
        XCTAssertEqual(resolvedRoute, .missingCloudProfile)
        XCTAssertNotEqual(resolvedRoute, .onboarding)
    }

    // 5. Sign-in failure after onboarding does not clear generated plan/draft.
    func testLocalProfileRetainedAfterFailedCloudSync() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        harness.cloudStore.saveError = NSError(domain: "test", code: 1)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "user-1")

        XCTAssertEqual(outcome, .cloudSyncFailed)
        XCTAssertFalse(harness.syncStore.isSyncedForUID("user-1"))
        XCTAssertNotNil(try harness.container.userProfileService.getCurrentProfile())
    }

    // 6. Pre-auth local profile is linked/synced after auth UID becomes available.
    func testUnsyncedLocalProfileTriggersSyncDecision() async throws {
        _ = try makeHarness()
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "linked-user",
                pendingOnboardingCompletion: false,
                hasLocalProfile: true,
                isFreshSignIn: true,
                rootState: .onboarding,
                isSyncedForCurrentUID: false
            )
        )

        XCTAssertEqual(decision, .syncLocalProfileToCloud(uid: "linked-user"))
    }

    func testPreAuthLocalProfileSyncMarksUID() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await harness.coordinator.syncLocalProfileToCloud(uid: "linked-user")

        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertTrue(harness.syncStore.isSyncedForUID("linked-user"))
    }

    // 7. Cloud save failure does not falsely mark onboarding as fully synced.
    func testCloudSaveFailureDoesNotMarkSynced() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        harness.cloudStore.saveError = NSError(domain: "test", code: 1)

        do {
            try await harness.coordinator.syncOnboardingProfileToCloud(uid: "user-1")
            XCTFail("Expected sync to throw")
        } catch {
            XCTAssertFalse(harness.syncStore.isSyncedForUID("user-1"))
        }
    }

    // 8. Existing local profile still routes main when synced for UID.
    func testSyncedLocalProfileRoutesMain() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "existing-user",
                pendingOnboardingCompletion: false,
                hasLocalProfile: true,
                isFreshSignIn: false,
                rootState: .main,
                isSyncedForCurrentUID: true
            )
        )

        XCTAssertEqual(decision, .routeToMain)
    }

    // 9. Legacy existing users still skip onboarding.
    func testLegacyLocalProfileWithSyncRoutesMain() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "legacy-user",
                pendingOnboardingCompletion: false,
                hasLocalProfile: true,
                isFreshSignIn: true,
                rootState: .main,
                isSyncedForCurrentUID: true
            )
        )

        XCTAssertEqual(decision, .routeToMain)
    }

    // 10. ProfileBootstrapService does not swallow decode/network errors as “new user”.
    func testFetchFailureThrowsInsteadOfMissingCloudProfile() async throws {
        let harness = try makeHarness()
        harness.cloudStore.fetchError = NSError(domain: "test", code: 1)

        do {
            _ = try await harness.bootstrapService.resolve(uid: "user-1")
            XCTFail("Expected resolve to throw")
        } catch {
            XCTAssertEqual(harness.cloudStore.fetchCallCount, 1)
        }
    }

    func testPendingOnboardingCompletionDefersLocalShortCircuit() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "onboarding-user",
                pendingOnboardingCompletion: true,
                hasLocalProfile: true,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false
            )
        )

        XCTAssertEqual(decision, .resolveOnboardingCompletion(uid: "onboarding-user"))
    }

    func testEmptyLocalProfileLoadsCloudOnFreshSignIn() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "device-b-user",
                pendingOnboardingCompletion: false,
                hasLocalProfile: false,
                isFreshSignIn: true,
                rootState: .onboarding,
                isSyncedForCurrentUID: false
            )
        )

        XCTAssertEqual(decision, .loadCloudProfile(uid: "device-b-user"))
    }
}

extension OnboardingCompletionOutcome: Equatable {
    public static func == (lhs: OnboardingCompletionOutcome, rhs: OnboardingCompletionOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.uploadedToCloud, .uploadedToCloud):
            return true
        case (.cloudCheckFailed, .cloudCheckFailed):
            return true
        case (.cloudSyncFailed, .cloudSyncFailed):
            return true
        case (.cloudProfileConflict(let left), .cloudProfileConflict(let right)):
            return left == right
        default:
            return false
        }
    }
}

extension SignedInProfileReconcileDecision: Equatable {}
