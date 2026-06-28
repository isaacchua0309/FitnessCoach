//
//  AuthProfileRouteSafetyTests.swift
//  Fitness CoachTests
//
//  Forma — Comprehensive auth/profile route safety matrix (Stage 10).
//  Pure resolver tests + in-memory SwiftData + MockCloudUserProfileStore only.
//

import XCTest
@testable import Fitness_Coach

// MARK: - Pre-auth shell routing (scenarios 1–2)

final class AuthProfilePreAuthRouteSafetyTests: XCTestCase {

    func testScenario01_SignedOutNoLocalProfileRoutesToPreAuthOnboarding() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
            ),
            .localOnboarding
        )
        XCTAssertEqual(
            OnboardingShellRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingModelReady: true,
            ),
            .preAuthOnboarding
        )
    }

    func testScenario02_SignedOutLocalProfileRequireSignInRoutesToPreAuthNotMain() {
        let productionRoute = AppRouteResolver.resolve(
            authState: .signedOut,
            isOnboardingModelReady: true,
            hasLocalProfile: true,
            signedOutWithProfilePolicy: .requireSignIn,
            localProfileAwaitingSignIn: true
        )
        XCTAssertEqual(productionRoute, .localOnboarding)
        XCTAssertNotEqual(productionRoute, .main)
        XCTAssertNotEqual(productionRoute, .localMain)

        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .allowLocalMain,
                localProfileAwaitingSignIn: false
            ),
            .localMain
        )
    }

    func testScenario02b_SignedOutOwnedLocalProfileRoutesToSignIn() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .requireSignIn,
                localProfileAwaitingSignIn: false
            ),
            .signIn
        )
    }
}

// MARK: - Fresh install / reinstall bootstrap (scenarios 3–5, 20–22)

@MainActor
final class AuthProfileBootstrapRouteSafetyTests: XCTestCase {

    func testScenario03_SignedInNoLocalCloudFoundRestoresToMain() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let result = try await harness.bootstrapService.resolve(uid: "returning-user")
        let rootState = RootProfileRouteResolver.resolve(bootstrapResult: result)
        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "returning-user"),
            rootState: rootState
        )

        XCTAssertEqual(result, .main)
        XCTAssertEqual(rootState, .main)
        XCTAssertEqual(shellRoute, .main)
        XCTAssertEqual(
            try harness.profileService.getCurrentProfile()?.ownerUID,
            "returning-user"
        )
    }

    func testScenario04_SignedInNoLocalCloudMissingRoutesToMissingCloudHandoff() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()

        let result = try await harness.bootstrapService.resolve(uid: "new-user")
        let rootState = RootProfileRouteResolver.resolve(bootstrapResult: result)
        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "new-user"),
            rootState: rootState
        )

        XCTAssertEqual(result, .missingCloudProfile)
        XCTAssertEqual(rootState, .missingCloudProfile)
        XCTAssertEqual(shellRoute, .missingCloudProfile)
        XCTAssertNotEqual(shellRoute, .onboarding)
    }

    func testScenario05_SignedInNoLocalCloudFailedDoesNotRouteToOnboarding() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.fetchError = NSError(domain: "test", code: 1)

        do {
            _ = try await harness.bootstrapService.resolve(uid: "new-user")
            XCTFail("Expected bootstrap resolve to throw on cloud failure")
        } catch {
            XCTAssertEqual(harness.cloudStore.fetchCallCount, 1)
        }

        XCTAssertNotEqual(
            RootProfileRouteResolver.resolve(bootstrapResult: .missingCloudProfile),
            .onboarding
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "new-user"),
                rootState: .onboardingCloudCheckFailed
            ),
            .onboardingCloudCheckFailed
        )
    }

    func testScenario20_ReinstallCloudFoundRestoresProfile() async throws {
        try await testScenario03_SignedInNoLocalCloudFoundRestoresToMain()
    }

    func testScenario21_ReinstallCloudMissingHandoff() async throws {
        try await testScenario04_SignedInNoLocalCloudMissingRoutesToMissingCloudHandoff()
    }

    func testScenario22_ReinstallCloudFailureMapsToRetryShell() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.fetchError = NSError(domain: "test", code: 1)

        do {
            _ = try await harness.bootstrapService.resolve(uid: "reinstall-user")
            XCTFail("Expected cloud fetch failure")
        } catch {
            XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
        }

        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "reinstall-user"),
                rootState: .onboardingCloudCheckFailed
            ),
            .onboardingCloudCheckFailed
        )
    }
}

// MARK: - Signed-in ownership reconcile (scenarios 6–10, 18–19)

@MainActor
final class AuthProfileOwnershipRouteSafetyTests: XCTestCase {

    func testScenario06_SignedInLocalOwnerMatchesRoutesToMain() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            AuthProfileRouteSafetyTestSupport.reconcileInput(
                uid: "signed-in-user",
                localOwnerUID: "signed-in-user"
            )
        )
        XCTAssertEqual(decision, .routeToMain)
    }

    func testScenario07_SignedInLocalOwnerMismatchRoutesToAccountMismatch() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            AuthProfileRouteSafetyTestSupport.reconcileInput(
                uid: "other-user",
                localOwnerUID: "signed-in-user",
                cloudResult: .found(CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate))
            )
        )
        XCTAssertEqual(decision, .showAccountMismatch(uid: "other-user"))
        XCTAssertNotEqual(decision, .routeToMain)
    }

    func testScenario08_SignedInUnownedLocalCloudFoundRoutesToConflict() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            AuthProfileRouteSafetyTestSupport.reconcileInput(
                localOwnerUID: nil,
                isFreshSignIn: true,
                cloudResult: .found(CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate))
            )
        )
        XCTAssertEqual(decision, .showProfileConflict(uid: "signed-in-user"))
    }

    func testScenario09_SignedInUnownedLocalCloudMissingUploadOnlyInAllowedContext() {
        let allowedUpload = ProfileBootstrapCoordinator.reconcileDecision(
            AuthProfileRouteSafetyTestSupport.reconcileInput(
                localOwnerUID: nil,
                isFreshSignIn: true,
                cloudResult: .missing
            )
        )
        XCTAssertEqual(allowedUpload, .syncLocalProfileToCloud(uid: "signed-in-user"))

        let blockedByAccountSwitch = ProfileOwnershipResolver.resolve(
            AuthProfileRouteSafetyTestSupport.ownershipInput(
                localOwnerUID: nil,
                cloudResult: .missing,
                signInContext: .accountSwitch
            )
        )
        XCTAssertEqual(blockedByAccountSwitch, .showAccountMismatch)
    }

    func testScenario10_SignedInUnownedLocalCloudFailedNoUpload() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            AuthProfileRouteSafetyTestSupport.reconcileInput(
                localOwnerUID: nil,
                isFreshSignIn: true,
                cloudResult: .failed
            )
        )
        XCTAssertEqual(decision, .showCloudFetchFailed(uid: "signed-in-user"))
        XCTAssertNotEqual(decision, .syncLocalProfileToCloud(uid: "signed-in-user"))
    }

    func testScenario18_LogoutSameAccountSignInOwnerMatchRoutesToMain() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            AuthProfileRouteSafetyTestSupport.reconcileInput(
                uid: "signed-in-user",
                localOwnerUID: "signed-in-user",
                isFreshSignIn: true,
                isSyncedForCurrentUID: false
            )
        )
        XCTAssertEqual(decision, .routeToMain)
    }

    func testScenario19_LogoutDifferentAccountMismatchNoSilentUpload() async throws {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            AuthProfileRouteSafetyTestSupport.reconcileInput(
                uid: "other-user",
                localOwnerUID: "signed-in-user",
                isFreshSignIn: true,
                cloudResult: .found(CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate))
            )
        )
        XCTAssertEqual(decision, .showAccountMismatch(uid: "other-user"))

        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )

        do {
            try await harness.bootstrapService.saveProfileToCloud(
                uid: "other-user",
                intent: .ownedProfileUpdate
            )
            XCTFail("Expected silent upload to be blocked")
        } catch let error as CloudProfileWriteError {
            XCTAssertEqual(
                error,
                .blocked(.ownerMismatch(localOwnerUID: "signed-in-user", signedInUID: "other-user"))
            )
        }
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }
}

// MARK: - Onboarding completion + conflict (scenarios 11–14)

@MainActor
final class AuthProfileOnboardingConflictRouteSafetyTests: XCTestCase {

    func testScenario11_GetStartedSavePlanSignInCloudMissingUploadsToMain() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "signed-in-user")

        XCTAssertEqual(outcome, .uploadedToCloud)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertTrue(harness.syncStore.isSyncedForUID("signed-in-user"))
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "signed-in-user"),
                rootState: .main
            ),
            .main
        )
    }

    func testScenario12_GetStartedSavePlanSignInCloudFoundShowsConflict() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "signed-in-user")

        guard case .cloudProfileConflict = outcome else {
            return XCTFail("Expected onboarding completion conflict")
        }
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "signed-in-user"),
                rootState: .onboardingCloudProfileConflict
            ),
            .onboardingCloudProfileConflict
        )
    }

    func testScenario13_ConflictRestoreExistingReplacesLocalForMain() throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        var cloudProfile = ProfileTestFixtures.sampleProfile
        cloudProfile.targets.calorieTarget = 1_888
        let cloudDocument = ProfileTestFixtures.cloudDocument(for: cloudProfile)
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let restored = try harness.bootstrapService.adoptCloudProfile(
            cloudDocument,
            uid: "signed-in-user"
        )

        XCTAssertEqual(restored.targets.calorieTarget, 1_888)
        XCTAssertEqual(restored.ownerUID, "signed-in-user")
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "signed-in-user"),
                rootState: .main
            ),
            .main
        )
    }

    func testScenario14_ConflictUseDevicePlanUploadsOnlyAfterExplicitConfirmation() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let prepareOutcome = await harness.coordinator.prepareUseDeviceProfile(uid: "signed-in-user")
        guard case .cloudProfileConflict = prepareOutcome else {
            return XCTFail("Expected conflict before overwrite")
        }
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)

        do {
            try await harness.bootstrapService.syncOnboardingProfileToCloud(
                uid: "signed-in-user",
                intent: .newProfileInitialUpload
            )
            XCTFail("Expected initial upload intent to be blocked when cloud exists")
        } catch let error as CloudProfileWriteError {
            XCTAssertEqual(error, .blocked(.cloudProfileExists))
        }

        try await harness.coordinator.uploadDevicePlanAfterConflict(uid: "signed-in-user")
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
    }
}

// MARK: - Upload failure surfacing (scenarios 15–17)

@MainActor
final class AuthProfileUploadFailureRouteSafetyTests: XCTestCase {

    func testScenario15_CloudUploadFailureMapsToVisibleFailureState() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.saveError = NSError(domain: "test", code: 1)
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "signed-in-user")
        XCTAssertEqual(outcome, .cloudSyncFailed)

        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "signed-in-user"),
                rootState: .cloudProfileUploadFailed
            ),
            .cloudProfileUploadFailed
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "signed-in-user"),
                rootState: .cloudProfileUploadFailed
            ),
            .main
        )
    }

    func testScenario16_RetryCloudUploadSuccessRoutesToMain() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        try await harness.coordinator.retryCloudProfileUpload(
            uid: "signed-in-user",
            context: .reconcileUpload
        )

        XCTAssertTrue(harness.syncStore.isSyncedForUID("signed-in-user"))
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "signed-in-user"),
                rootState: .main
            ),
            .main
        )
    }

    func testScenario17_ContinueAfterUploadFailureRoutesMainWithoutSyncedMetadata() throws {
        let syncStore = ProfileCloudSyncStore(
            userDefaults: UserDefaults(suiteName: "AuthProfileRouteSafety.\(UUID().uuidString)")!
        )
        syncStore.markSynced(uid: "signed-in-user", updatedAt: ProfileTestFixtures.referenceDate)
        syncStore.clear()

        let base = try DailyLogServiceTestSupport.makeHarness()
        _ = try base.seedProfile()
        let rootModel = RootModel(
            profileBootstrapService: ProfileBootstrapService(
                userProfileService: base.profileService,
                cloudStore: MockCloudUserProfileStore()
            )
        )

        rootModel.presentCloudProfileUploadFailed()
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "signed-in-user"),
                rootState: .cloudProfileUploadFailed
            ),
            .cloudProfileUploadFailed
        )

        rootModel.continueDespiteCloudUploadFailure()
        XCTAssertEqual(rootModel.state, .main)
        XCTAssertFalse(syncStore.isSyncedForUID("signed-in-user"))
        XCTAssertNotNil(try base.profileService.getCurrentProfile())
    }
}
