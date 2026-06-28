//
//  ProfileBootstrapCoordinatorTests.swift
//  Fitness CoachTests
//
//  Profile bootstrap coordinator — ownership-aware reconcile decisions.
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

    private func reconcileInput(
        uid: String = "signed-in-user",
        pendingOnboardingCompletion: Bool = false,
        hasLocalProfile: Bool = true,
        localOwnerUID: String? = nil,
        isFreshSignIn: Bool = false,
        rootState: RootViewState = .main,
        isSyncedForCurrentUID: Bool = false,
        cloudResult: CloudProfileLookupResult? = nil
    ) -> SignedInProfileReconcileInput {
        SignedInProfileReconcileInput(
            uid: uid,
            pendingOnboardingCompletion: pendingOnboardingCompletion,
            hasLocalProfile: hasLocalProfile,
            localOwnerUID: localOwnerUID,
            isFreshSignIn: isFreshSignIn,
            rootState: rootState,
            isSyncedForCurrentUID: isSyncedForCurrentUID,
            cloudResult: cloudResult
        )
    }

    // MARK: - Ownership reconcile (Stage 4)

    func testSameOwnerUIDRoutesToMain() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                uid: "existing-user",
                localOwnerUID: "existing-user"
            )
        )

        XCTAssertEqual(decision, .routeToMain)
    }

    func testUnownedLocalRequiresCloudLookupBeforeUpload() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                uid: "linked-user",
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .onboarding,
                isSyncedForCurrentUID: false,
                cloudResult: nil
            )
        )

        XCTAssertEqual(decision, .requireOwnershipCloudLookup(uid: "linked-user"))
    }

    func testUnownedLocalUploadsOnlyAfterCloudMissingLookup() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                uid: "linked-user",
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .onboarding,
                isSyncedForCurrentUID: false,
                cloudResult: .missing
            )
        )

        XCTAssertEqual(decision, .syncLocalProfileToCloud(uid: "linked-user"))
    }

    func testOwnerMismatchShowsAccountMismatch() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                uid: "signed-in-user",
                localOwnerUID: "other-user",
                isSyncedForCurrentUID: true
            )
        )

        XCTAssertEqual(decision, .showAccountMismatch(uid: "signed-in-user"))
    }

    func testOnboardingCompletionCloudFoundShowsConflict() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                pendingOnboardingCompletion: true,
                localOwnerUID: nil,
                cloudResult: .found(CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate))
            )
        )

        XCTAssertEqual(decision, .showProfileConflict(uid: "signed-in-user"))
    }

    func testOnboardingCompletionCloudMissingUploadsLocal() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                pendingOnboardingCompletion: true,
                localOwnerUID: nil,
                cloudResult: .missing
            )
        )

        XCTAssertEqual(decision, .syncLocalProfileToCloud(uid: "signed-in-user"))
    }

    func testOnboardingCompletionCloudFailureDoesNotUpload() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                pendingOnboardingCompletion: true,
                localOwnerUID: nil,
                cloudResult: .failed
            )
        )

        XCTAssertEqual(decision, .showCloudFetchFailed(uid: "signed-in-user"))
    }

    func testUnownedLocalCloudFailureDoesNotUpload() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                localOwnerUID: nil,
                isFreshSignIn: true,
                cloudResult: .failed
            )
        )

        XCTAssertEqual(decision, .showCloudFetchFailed(uid: "signed-in-user"))
    }

    func testPendingOnboardingCompletionWithoutCloudResultDefersToCompletionFlow() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                pendingOnboardingCompletion: true,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                cloudResult: nil
            )
        )

        XCTAssertEqual(decision, .resolveOnboardingCompletion(uid: "signed-in-user"))
    }

    func testEmptyLocalProfileLoadsCloudOnFreshSignIn() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                hasLocalProfile: false,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .onboarding,
                cloudResult: nil
            )
        )

        XCTAssertEqual(decision, .loadCloudProfile(uid: "signed-in-user"))
    }

    func testUnownedLocalCloudFoundShowsConflict() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                localOwnerUID: nil,
                cloudResult: .found(CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate))
            )
        )

        XCTAssertEqual(decision, .showProfileConflict(uid: "signed-in-user"))
    }

    func testLegacySyncedHintUsesLocalAfterCloudMissingLookup() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                localOwnerUID: nil,
                isFreshSignIn: false,
                isSyncedForCurrentUID: true,
                cloudResult: .missing
            )
        )

        XCTAssertEqual(decision, .routeToMain)
    }

    // MARK: - Integration flows

    func testOnboardingCompletionUploadsProfileAndMarksSynced() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "device-a-user")

        XCTAssertEqual(outcome, .uploadedToCloud)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(harness.cloudStore.lastSavedUID, "device-a-user")
        XCTAssertEqual(try harness.container.userProfileService.getCurrentProfile()?.ownerUID, "device-a-user")
        XCTAssertTrue(harness.syncStore.isSyncedForUID("device-a-user"))
    }

    func testOnboardingCompletionCloudFoundReturnsConflict() async throws {
        let harness = try makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "device-a-user")

        guard case .cloudProfileConflict = outcome else {
            return XCTFail("Expected cloud profile conflict")
        }
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

    func testOnboardingCompletionCloudFailureDoesNotUpload() async throws {
        let harness = try makeHarness()
        harness.cloudStore.fetchError = NSError(domain: "test", code: 1)
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "device-a-user")

        XCTAssertEqual(outcome, .cloudCheckFailed)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }

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
        XCTAssertEqual(
            try harness.container.userProfileService.getCurrentProfile()?.ownerUID,
            "device-b-user"
        )
        XCTAssertTrue(harness.syncStore.isSyncedForUID("device-b-user"))
    }

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

    func testLocalProfileRetainedAfterFailedCloudSync() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        harness.cloudStore.saveError = NSError(domain: "test", code: 1)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "user-1")

        XCTAssertEqual(outcome, .cloudSyncFailed)
        XCTAssertFalse(harness.syncStore.isSyncedForUID("user-1"))
        XCTAssertNotNil(try harness.container.userProfileService.getCurrentProfile())
    }

    func testPreAuthLocalProfileSyncMarksUID() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await harness.coordinator.syncLocalProfileToCloud(uid: "linked-user")

        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(try harness.container.userProfileService.getCurrentProfile()?.ownerUID, "linked-user")
        XCTAssertTrue(harness.syncStore.isSyncedForUID("linked-user"))
    }

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

    func testOwnedLocalProfileSkipsCloudFetchInBootstrapResolve() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "offline-local-user"
        )

        XCTAssertTrue(harness.bootstrapService.hasLocalProfile())
        let result = try await harness.bootstrapService.resolve(uid: "offline-local-user")

        XCTAssertEqual(result, .main)
        XCTAssertEqual(harness.cloudStore.fetchCallCount, 0)
    }

    func testUnownedLocalProfileDoesNotSkipCloudFetchInBootstrapResolve() async throws {
        let harness = try makeHarness()
        _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        do {
            _ = try await harness.bootstrapService.resolve(uid: "signed-in-user")
            XCTFail("Expected ownership resolution required")
        } catch {
            XCTAssertEqual(harness.cloudStore.fetchCallCount, 0)
        }
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
