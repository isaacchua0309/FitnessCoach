//
//  PublicEntryEdgeCaseTests.swift
//  Fitness CoachTests
//
//  Forma — Public entry funnel edge cases (routing + profile resolution).
//

import XCTest
@testable import Fitness_Coach

// MARK: - Signed-out shell routing

final class PublicEntryEdgeCaseRoutingTests: XCTestCase {

    // 1. Fresh install, no auth, no draft → Welcome
    func testScenario01_FreshInstallNoAuthNoDraftRoutesToWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: false,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: false
            ),
            .welcome
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(authState: .unknown),
            .launchLoading
        )
    }

    // 2. Fresh install, user taps Create My Plan → Onboarding
    func testScenario02_CreateMyPlanRoutesToOnboarding() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: WelcomeOnboardingHandoffPolicy.createPlanDestination
            ),
            .onboardingStart
        )
        XCTAssertEqual(WelcomeOnboardingHandoffPolicy.canonicalFirstStep, .introProof)
    }

    // 6. Logged-out existing user opens app → Welcome
    func testScenario06_LoggedOutUserOpensAppRoutesToWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                rootState: .main,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .requireSignIn,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
    }

    // 9. User signs out → Welcome
    func testScenario09_SignOutRoutesToWelcome() {
        XCTAssertEqual(
            AuthLogoutPolicy.publicEntryDestinationAfterSignOut(
                returnToExistingUserSignIn: false,
                hasExistingUserSignInError: false
            ),
            .welcome
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                publicEntryDestination: .welcome,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
    }

    // 10. Draft + Sign In → existing-user sign-in, not draft resume
    func testScenario10_DraftPlusSignInPrioritizesProfileLookup() {
        let input = PublicEntryRouteResolver.Input(
            destination: .existingUserSignIn,
            isOnboardingModelReady: true,
            localProfileAwaitingSignIn: false,
            hasPersistedOnboardingDraft: true,
            hasLocalProfile: false,
            pendingOnboardingCompletion: false,
            signedOutWithProfilePolicy: .requireSignIn
        )

        XCTAssertEqual(PublicEntryRouteResolver.resolveSignedOutShell(input), .existingUserSignIn)
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .existingUserSignIn,
                isSignedIn: false,
                hasActiveOnboardingSession: true
            ),
            .existingUserSignIn
        )
    }

    // 11. Draft + Create My Plan → resume onboarding per policy
    func testScenario11_DraftPlusCreateMyPlanResumesOnboarding() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: .onboardingStart,
                hasPersistedOnboardingDraft: true,
                suppressAutomaticPublicEntryResume: false
            ),
            .onboardingStart
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: false,
                hasLocalProfile: false,
                publicEntryDestination: .onboardingStart,
                hasPersistedOnboardingDraft: true,
                suppressAutomaticPublicEntryResume: false
            ),
            .onboardingStartInitializing
        )
    }

    // 14. Signed-out users with a local profile must never enter main without Firebase auth.
    func testScenario14_SignedOutLocalProfileNeverRoutesToMain() {
        let awaitingSignInRoute = AppRouteResolver.resolve(
            authState: .signedOut,
            rootState: .onboarding,
            isOnboardingModelReady: true,
            hasLocalProfile: true,
            localProfileAwaitingSignIn: true
        )
        XCTAssertEqual(awaitingSignInRoute, .onboardingStart)
        XCTAssertNotEqual(awaitingSignInRoute, .main)

        let staleMainRootRoute = AppRouteResolver.resolve(
            authState: .signedOut,
            rootState: .main,
            hasLocalProfile: true,
            signedOutWithProfilePolicy: .requireSignIn,
            suppressAutomaticPublicEntryResume: true
        )
        XCTAssertNotEqual(staleMainRootRoute, .main)
        XCTAssertEqual(staleMainRootRoute, .welcome)
    }
}

// MARK: - Signed-in profile resolution

@MainActor
final class PublicEntryEdgeCaseResolutionTests: XCTestCase {

    private let uid = "remote-user"
    private let referenceDate = ProfileTestFixtures.referenceDate

    // 3. Sign In, cloud profile exists → restore and enter app
    func testScenario03_ExistingSignInRestoresCloudProfile() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: uid,
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.profileFound(.cloudRestored)))
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
    }

    // 4. Sign In, no profile → No Existing Profile Found
    func testScenario04_ExistingSignInNoCloudProfileRoutesToInterstitial() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: "new-user",
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.noProfileFound))
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "new-user"),
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
    }

    // 5. Sign In, network fails → retry, not new user
    func testScenario05_NetworkFailureRoutesToRetryNotNoProfile() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.fetchError = NSError(domain: "PublicEntryEdgeCaseTests", code: 1)

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: uid,
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.lookupFailed))
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .existingUserProfileLookupFailed
            ),
            .existingUserProfileLookupFailed
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .existingUserProfileLookupFailed
            ),
            .noExistingProfileFound
        )
    }

    // 7. Logged-out user signs in → restore profile
    func testScenario07_LoggedOutUserSignInRestoresOwnedLocalProfile() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: uid,
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: uid,
                isFreshSignIn: true,
                rootState: .main,
                isSyncedForCurrentUID: false
            )
        )

        XCTAssertEqual(decision, .routeToMain)
        XCTAssertEqual(
            ExistingUserSignInResolutionMapper.fromReconcileDecision(decision),
            .profileFound(.localOwned)
        )
    }

    // 8. Wrong/new account sign in → No Existing Profile Found (no cloud)
    func testScenario08_WrongAccountWithNoCloudRoutesToNoProfileFound() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: "wrong-account",
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.noProfileFound))
    }

    // 12. Sign in during onboarding completion → upload, not no-profile-found
    func testScenario12_OnboardingCompletionSignInUploadsNotNoProfile() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: uid,
                pendingOnboardingCompletion: true,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: .missing
            )
        )

        XCTAssertEqual(decision, .syncLocalProfileToCloud(uid: uid))
        XCTAssertNotEqual(decision, .presentMissingCloudProfile(uid: uid))
        XCTAssertEqual(
            ProfileBootstrapCoordinator.profileSignInIntent(
                for: SignedInProfileReconcileInput(
                    uid: uid,
                    pendingOnboardingCompletion: true,
                    pendingExistingUserSignIn: true,
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    isFreshSignIn: true,
                    rootState: .loading,
                    isSyncedForCurrentUID: false
                )
            ),
            .onboardingCompletion
        )
    }

    // 13. Cloud profile conflict → conflict resolution path
    func testScenario13_CloudProfileConflictRoutesToConflictScreen() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .onboardingCloudProfileConflict
            ),
            .onboardingCloudProfileConflict
        )

        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: uid,
                pendingOnboardingCompletion: true,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: .found(CloudProfileSummary(updatedAt: referenceDate))
            )
        )

        XCTAssertEqual(decision, .showProfileConflict(uid: uid))
    }
}

// MARK: - Silent auth restore on launch

final class PublicEntryEdgeCaseSilentRestoreTests: XCTestCase {

    private let uid = "returning-user"

    // 15a. Auth restored on launch, profile exists → enter app
    func testScenario15_SilentRestoreWithOwnedLocalProfileRoutesToMain() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: uid,
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: uid,
                isFreshSignIn: false,
                rootState: .main,
                isSyncedForCurrentUID: true
            )
        )

        XCTAssertEqual(decision, .routeToMain)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
    }

    // 15b. Auth restored on launch, no local profile, still loading → cloud bootstrap
    func testScenario15_SilentRestoreWithoutLocalProfileTriggersCloudReload() {
        let input = SignedInProfileReconcileInput(
            uid: uid,
            pendingOnboardingCompletion: false,
            pendingExistingUserSignIn: false,
            hasLocalProfile: false,
            localOwnerUID: nil,
            isFreshSignIn: false,
            rootState: .loading,
            isSyncedForCurrentUID: false,
            cloudResult: nil
        )

        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: input.isFreshSignIn,
                rootState: input.rootState,
                hasLocalProfile: input.hasLocalProfile
            )
        )

        let decision = ProfileBootstrapCoordinator.mapOwnershipOutcome(
            .requireCloudLookup,
            input: input
        )
        XCTAssertEqual(decision, .loadCloudProfile(uid: uid))
    }

    // 15c. Auth restored, missing cloud profile already resolved → stay on interstitial
    func testScenario15_SilentRestoreMissingCloudDoesNotRebootstrap() {
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: false,
                rootState: .missingCloudProfile,
                hasLocalProfile: false
            )
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
    }
}

// MARK: - Draft resume after sign-out

@MainActor
final class PublicEntryEdgeCaseDraftResumeTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "PublicEntryEdgeCaseDraftResume.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testScenario11_SignOutThenCreateMyPlanResumesDraftStep() async throws {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        draftStore.saveDraft(OnboardingDraft(formState: formState, step: .targetWeight))

        let sessionDefaults = UserDefaults(suiteName: "PublicEntryEdgeCaseDraftResume.session.\(UUID().uuidString)")!
        let sessionStore = PublicEntrySessionStore(userDefaults: sessionDefaults)
        AuthLogoutPolicy.applyExplicitSignOut(sessionStore: sessionStore)

        XCTAssertTrue(sessionStore.suppressAutomaticPublicEntryResume)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasPersistedOnboardingDraft: true,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )

        sessionStore.clearExplicitSignOut()
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                publicEntryDestination: .onboardingStart,
                hasPersistedOnboardingDraft: true,
                suppressAutomaticPublicEntryResume: false
            ),
            .onboardingStart
        )

        let container = try AppContainer(
            inMemory: true,
            onboardingUserDefaults: draftDefaults
        )
        let model = OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            planTargetCalculator: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )

        XCTAssertEqual(model.currentStep, .targetWeight)
        XCTAssertNotEqual(model.currentStep, .introProof)
    }
}
