//
//  AuthGateCoordinatorRoutingCharacterizationTests.swift
//  Fitness CoachTests
//
//  Routing-focused behavior freeze for AuthGateCoordinator.effectiveRoute.
//  Run before extracting AuthGateRoutingCoordinator.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AuthGateCoordinatorRoutingCharacterizationTests: XCTestCase {

  private var harness: AuthGateCharacterizationTestSupport.Harness!

  override func setUp() async throws {
    harness = try AuthGateCharacterizationTestSupport.makeHarness()
  }

  override func tearDown() {
    harness = nil
    super.tearDown()
  }

  // MARK: - Pipeline parity

  func testEffectiveRoute_alwaysMatchesResolveAppShellRoutePlusOverlayPolicy() throws {
    for scenario in AuthGateCharacterizationTestSupport.allRouteScenarios() {
      let localHarness = try AuthGateCharacterizationTestSupport.makeHarness()
      try scenario.configure(on: localHarness)
      localHarness.assertEffectiveRoute(scenario.expectedRoute)
    }
  }

  // MARK: - 1. Initial route with no signed-in user

  func testEffectiveRoute_whenNoSignedInUserAndUnknownAuth_returnsLaunchLoading() {
    harness.applyUnknownAuth()

    harness.assertEffectiveRoute(.launchLoading)
  }

  func testEffectiveRoute_whenNoSignedInUserAndSignedOut_returnsWelcome() {
    harness.applySignedOut()

    harness.assertEffectiveRoute(.welcome)
  }

  func testEffectiveRoute_whenNoSignedInUserAndSigningIn_returnsWelcome() {
    harness.container.authManager.applyTestingAuthState(.signingIn)

    harness.assertEffectiveRoute(.welcome)
  }

  func testEffectiveRoute_whenNoSignedInUserAndFailedAuth_returnsWelcome() {
    harness.container.authManager.applyTestingAuthState(
      .failed(AuthSignInUserMessage.signInFailureMessage)
    )

    harness.assertEffectiveRoute(.welcome)
  }

  // MARK: - 2. Route when public entry is visible

  func testEffectiveRoute_whenPublicEntryWelcome_returnsWelcome() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .welcome

    harness.assertEffectiveRoute(.welcome)
  }

  func testEffectiveRoute_whenPublicEntryExistingUserSignIn_returnsExistingUserSignIn() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .existingUserSignIn

    harness.assertEffectiveRoute(.existingUserSignIn)
  }

  func testEffectiveRoute_whenPublicEntryOnboardingStartWithoutModel_returnsInitializing() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .onboardingStart
    harness.coordinator.onboardingModel = nil

    harness.assertEffectiveRoute(.onboardingStartInitializing)
  }

  // MARK: - 3. Route when onboarding is active

  func testEffectiveRoute_whenPreAuthOnboardingActive_returnsOnboardingStart() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = WelcomeOnboardingHandoffPolicy.createPlanDestination
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.assertEffectiveRoute(.onboardingStart)
  }

  func testEffectiveRoute_whenPreAuthOnboardingInitializing_returnsOnboardingStartInitializing() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .onboardingStart
    harness.coordinator.onboardingModel = nil

    harness.assertEffectiveRoute(.onboardingStartInitializing)
  }

  func testEffectiveRoute_whenSignedInOnboardingActive_returnsOnboarding() {
    harness.applySignedIn(uid: "onboarding-user")
    harness.coordinator.rootModel.continueFromMissingCloudProfile()
    harness.coordinator.ensureOnboardingModel()

    harness.assertEffectiveRoute(.onboarding)
  }

  func testEffectiveRoute_whenSignedInOnboardingWithoutModel_returnsOnboardingInitializing() {
    harness.applySignedIn(uid: "onboarding-user")
    harness.coordinator.rootModel.continueFromMissingCloudProfile()
    harness.coordinator.onboardingModel = nil

    harness.assertEffectiveRoute(.onboardingInitializing)
  }

  func testEffectiveRoute_whenLocalProfileAwaitingSignIn_bypassesWelcomeToOnboardingStart() throws {
    harness.applySignedOut()
    _ = try harness.container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.assertEffectiveRoute(.onboardingStart)
  }

  // MARK: - 4. Route when onboarding completes and sign-in is pending

  func testEffectiveRoute_whenPendingOnboardingCompletionBypassesWelcome_returnsOnboardingStart() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .welcome
    harness.coordinator.pendingSignInForOnboardingCompletion = true
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.assertEffectiveRoute(.onboardingStart)
  }

  func testEffectiveRoute_whenPendingOnboardingCompletionWithoutModel_returnsOnboardingStartInitializing() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .welcome
    harness.coordinator.pendingSignInForOnboardingCompletion = true
    harness.coordinator.onboardingModel = nil

    harness.assertEffectiveRoute(.onboardingStartInitializing)
  }

  func testEffectiveRoute_whenPendingOnboardingCompletionDoesNotOverrideSignedInShell() throws {
    harness.applySignedIn(uid: "signed-in-user")
    _ = try harness.seedOwnedLocalProfile(uid: "signed-in-user")
    harness.coordinator.rootModel.didCompleteOnboarding()
    harness.coordinator.pendingSignInForOnboardingCompletion = true
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.assertEffectiveRoute(.main)
  }

  // MARK: - 5. Route when signed-in shell is active

  func testEffectiveRoute_whenSignedInAndNoConflict_returnsMain() throws {
    harness.applySignedIn(uid: "main-user")
    _ = try harness.seedOwnedLocalProfile(uid: "main-user")
    harness.coordinator.rootModel.didCompleteOnboarding()

    harness.assertEffectiveRoute(.main)
  }

  func testEffectiveRoute_whenSignedInAndProfileLoading_returnsSignedInProfileLoading() {
    harness.applySignedIn(uid: "loading-user")
    harness.coordinator.rootModel.resetForSignedOutSession()

    harness.assertEffectiveRoute(.signedInProfileLoading)
  }

  func testEffectiveRoute_whenSignedInAndMissingCloudProfile_returnsNoExistingProfileFound() {
    harness.applySignedIn(uid: "missing-profile-user")
    harness.coordinator.rootModel.presentMissingCloudProfile()

    harness.assertEffectiveRoute(.noExistingProfileFound)
  }

  // MARK: - 6. Route when restore flow is presented

  func testEffectiveRoute_whenRestorePresented_overridesPublicEntry() {
    harness.applySignedIn(uid: "restore-user")
    harness.coordinator.publicEntryDestination = .existingUserSignIn
    harness.coordinator.rootModel.beginAccountRestore(uid: "restore-user")

    harness.assertEffectiveRoute(.signedInProfileLoading)
  }

  func testEffectiveRoute_whenRestoreFailed_returnsAccountRestoreFailedRoute() {
    harness.applySignedIn(uid: "restore-user")
    harness.coordinator.rootModel.beginAccountRestore(uid: "restore-user")
    harness.coordinator.rootModel.presentAccountRestoreFailed(message: "Permission denied.")

    harness.assertEffectiveRoute(.accountRestoreFailed("Permission denied."))
  }

  func testEffectiveRoute_whenAwaitingCloudSyncOnMain_overridesMainRoute() throws {
    harness.applySignedIn(uid: "sync-user")
    _ = try harness.seedOwnedLocalProfile(uid: "sync-user")
    harness.coordinator.rootModel.didCompleteOnboarding()
    harness.coordinator.awaitingCloudSync = true

    harness.assertEffectiveRoute(.signedInProfileLoading)
  }

  // MARK: - 7. Route when profile conflict / account mismatch is presented

  func testEffectiveRoute_whenProfileConflictPresented_returnsConflictRoute() throws {
    harness.applySignedIn(uid: "conflict-user")
    _ = try harness.seedOwnedLocalProfile(uid: "conflict-user")
    harness.coordinator.conflictCloudDocument = ProfileTestFixtures.cloudDocument()
    harness.coordinator.rootModel.presentProfilePlanConflict()

    harness.assertEffectiveRoute(.onboardingCloudProfileConflict)
  }

  func testEffectiveRoute_whenAccountMismatchPresented_returnsMismatchRoute() throws {
    harness.applySignedIn(uid: "mismatch-user")
    _ = try harness.container.userProfileService.createProfile(
      ProfileTestFixtures.sampleDraft,
      ownerUID: "other-user"
    )
    harness.coordinator.rootModel.presentAccountProfileMismatch()

    harness.assertEffectiveRoute(.accountProfileMismatch)
  }

  func testEffectiveRoute_whenCloudUploadFailedPresented_returnsUploadFailedRoute() {
    harness.applySignedIn(uid: "upload-user")
    harness.coordinator.rootModel.presentCloudProfileUploadFailed()

    harness.assertEffectiveRoute(.cloudProfileUploadFailed)
  }

  func testEffectiveRoute_whenExistingUserLookupFailedPresented_returnsLookupFailedRoute() {
    harness.applySignedIn(uid: "lookup-user")
    harness.coordinator.rootModel.presentExistingUserProfileLookupFailed()

    harness.assertEffectiveRoute(.existingUserProfileLookupFailed)
  }

  // MARK: - 8. Route precedence when multiple states are non-nil

  func testEffectiveRoute_whenSignedInRootStateWins_overPublicEntryDestination() {
    harness.applySignedIn(uid: "precedence-user")
    harness.coordinator.publicEntryDestination = .existingUserSignIn
    harness.coordinator.rootModel.presentMissingCloudProfile()

    harness.assertEffectiveRoute(.noExistingProfileFound)
  }

  func testEffectiveRoute_whenSignedInConflictRootStateWins_overActiveOnboardingModel() throws {
    harness.applySignedIn(uid: "precedence-user")
    harness.coordinator.ensureOnboardingModel()
    harness.coordinator.conflictCloudDocument = ProfileTestFixtures.cloudDocument()
    harness.coordinator.rootModel.presentProfilePlanConflict()

    harness.assertEffectiveRoute(.onboardingCloudProfileConflict)
  }

  func testEffectiveRoute_whenAwaitingCloudSyncWins_overMainAndOnboardingModel() throws {
    harness.applySignedIn(uid: "precedence-user")
    _ = try harness.seedOwnedLocalProfile(uid: "precedence-user")
    harness.coordinator.rootModel.didCompleteOnboarding()
    harness.coordinator.awaitingCloudSync = true
    harness.coordinator.ensureOnboardingModel()

    harness.assertEffectiveRoute(.signedInProfileLoading)
  }

  func testEffectiveRoute_whenExistingUserSignInWins_overActiveOnboardingSession() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .existingUserSignIn
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.assertEffectiveRoute(.existingUserSignIn)
  }

  func testEffectiveRoute_whenActiveOnboardingSessionWins_overWelcomeDestination() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .welcome
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.assertEffectiveRoute(.onboardingStart)
  }

  func testEffectiveRoute_whenExplicitSignOutSuppressesDraftResume_staysOnWelcome() throws {
    AuthLogoutPolicy.applyExplicitSignOut(sessionStore: harness.container.publicEntrySessionStore)
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .welcome
    var formState = OnboardingFormState()
    OnboardingModelTestSupport.seedCanonicalForm(&formState)
    harness.container.onboardingDraftStore.saveDraft(
      OnboardingDraft(formState: formState, step: .review)
    )
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.assertEffectiveRoute(.welcome)
  }

  func testEffectiveRoute_whenSignedInAuthWins_overPendingOnboardingCompletionOverlay() throws {
    harness.applySignedOut()
    harness.coordinator.pendingSignInForOnboardingCompletion = true
    harness.coordinator.ensurePreAuthOnboardingModel()
    harness.assertEffectiveRoute(.onboardingStart)

    harness.applySignedIn(uid: "handoff-user")
    _ = try harness.seedOwnedLocalProfile(uid: "handoff-user")
    harness.coordinator.rootModel.didCompleteOnboarding()

    harness.assertEffectiveRoute(.main)
  }

  // MARK: - 9. Route reset after dismissal / cancellation

  func testEffectiveRoute_afterReturnToWelcomeFromOnboarding_returnsWelcome() {
    harness.applySignedOut()
    harness.coordinator.startPreAuthOnboarding()
    XCTAssertEqual(harness.coordinator.effectiveRoute, .onboardingStart)

    harness.coordinator.returnToWelcomeFromOnboarding()

    harness.assertEffectiveRoute(.welcome)
    XCTAssertTrue(harness.container.publicEntrySessionStore.suppressAutomaticPublicEntryResume)
  }

  func testEffectiveRoute_afterReturnToWelcome_withDraftCleared_doesNotReopenViaBootstrap() throws {
    harness.applySignedOut()
    var formState = OnboardingFormState()
    OnboardingModelTestSupport.seedCanonicalForm(&formState)
    harness.container.onboardingDraftStore.saveDraft(
      OnboardingDraft(formState: formState, step: .activityLevel)
    )
    harness.coordinator.startPreAuthOnboarding()
    XCTAssertEqual(harness.coordinator.onboardingModel?.currentStep, .activityLevel)

    harness.coordinator.returnToWelcomeFromOnboarding()
    // Simulate the former race: bootstrap after model clear must not recreate session.
    harness.coordinator.bootstrapOnboardingIfNeeded()

    harness.assertEffectiveRoute(.welcome)
    XCTAssertNil(harness.coordinator.onboardingModel)
    XCTAssertFalse(harness.container.onboardingDraftStore.hasDraft)
  }

  func testReentryAfterWelcomeExit_startsCleanPreAuthSession() {
    harness.applySignedOut()
    harness.coordinator.startPreAuthOnboarding()
    harness.coordinator.onboardingModel?.goNext()
    XCTAssertEqual(harness.coordinator.onboardingModel?.currentStep, .heightWeight)

    harness.coordinator.returnToWelcomeFromOnboarding()
    harness.assertEffectiveRoute(.welcome)

    harness.coordinator.startPreAuthOnboarding()
    XCTAssertEqual(harness.coordinator.effectiveRoute, .onboardingStart)
    XCTAssertEqual(harness.coordinator.onboardingModel?.currentStep, .introProof)
    XCTAssertFalse(harness.container.publicEntrySessionStore.suppressAutomaticPublicEntryResume)
  }

  func testEffectiveRoute_afterReturnToWelcomeFromExistingUserSignIn_returnsWelcome() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .existingUserSignIn
    harness.coordinator.pendingExistingUserSignIn = true

    harness.coordinator.returnToWelcomeFromExistingUserSignIn()

    harness.assertEffectiveRoute(.welcome)
  }

  func testEffectiveRoute_afterOnboardingSignInCancelled_staysOnOnboardingStart() {
    harness.applySignedOut()
    harness.coordinator.startPreAuthOnboarding()
    harness.coordinator.pendingSignInForOnboardingCompletion = true

    harness.coordinator.applyOnboardingGoogleSignInOutcome(.cancelled)

    harness.assertEffectiveRoute(.onboardingStart)
  }

  func testEffectiveRoute_afterSignedOutTransition_returnsWelcome() throws {
    harness.applySignedIn(uid: "signed-out-user")
    harness.coordinator.rootModel.didCompleteOnboarding()

    harness.coordinator.handleSignedOutTransition(
      from: .signedIn(uid: "signed-out-user"),
      to: .signedOut,
      wasSignedIn: true
    )

    harness.assertEffectiveRoute(.welcome)
  }

  func testEffectiveRoute_afterClearProfileConflictState_keepsConflictRouteUntilRootChanges() throws {
    harness.applySignedIn(uid: "conflict-user")
    _ = try harness.seedOwnedLocalProfile(uid: "conflict-user")
    harness.coordinator.conflictCloudDocument = ProfileTestFixtures.cloudDocument()
    harness.coordinator.rootModel.presentProfilePlanConflict()
    harness.assertEffectiveRoute(.onboardingCloudProfileConflict)

    harness.coordinator.clearProfileConflictState()

    // Route is root-driven; clearing conflict document alone does not dismiss shell.
    harness.assertEffectiveRoute(.onboardingCloudProfileConflict)
  }

  func testEffectiveRoute_afterContinueFromCloudUploadFailure_returnsMain() throws {
    harness.applySignedIn(uid: "upload-user")
    _ = try harness.seedOwnedLocalProfile(uid: "upload-user")
    harness.coordinator.presentCloudProfileUploadFailure(context: .reconcileUpload)
    harness.assertEffectiveRoute(.cloudProfileUploadFailed)

    harness.coordinator.continueAfterCloudUploadFailure()

    harness.assertEffectiveRoute(.main)
  }

  // MARK: - 10. Route stability when unrelated state changes

  func testEffectiveRoute_remainsStableWhenConflictDocumentChangesWithoutRootStateChange() throws {
    harness.applySignedIn(uid: "stable-user")
    _ = try harness.seedOwnedLocalProfile(uid: "stable-user")
    harness.coordinator.rootModel.presentProfilePlanConflict()
    let baseline = harness.captureEffectiveRoute()

    harness.coordinator.conflictCloudDocument = ProfileTestFixtures.cloudDocument()
    harness.coordinator.profileConflictContext = .onboardingCompletion
    harness.coordinator.isResolvingProfileConflict = true
    harness.coordinator.showUseDevicePlanOverwriteConfirmation = true

    XCTAssertEqual(harness.captureEffectiveRoute(), baseline)
  }

  func testEffectiveRoute_remainsStableWhenExistingUserSignInErrorChanges() {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .existingUserSignIn
    let baseline = harness.captureEffectiveRoute()

    harness.coordinator.existingUserSignInError = .networkFailed
    harness.coordinator.pendingExistingUserSignIn = true
    harness.coordinator.existingUserSignInSessionActive = true

    XCTAssertEqual(harness.captureEffectiveRoute(), baseline)
  }

  func testEffectiveRoute_remainsStableWhenRestoreViewModelAttachedWithoutRootRestoreState() throws {
    harness.applySignedIn(uid: "stable-user")
    _ = try harness.seedOwnedLocalProfile(uid: "stable-user")
    harness.coordinator.rootModel.didCompleteOnboarding()
    let baseline = harness.captureEffectiveRoute()

    harness.coordinator.accountRestoreViewModel = AccountRestoreViewModel(container: harness.container)
    harness.coordinator.pendingExistingUserSignIn = true

    XCTAssertEqual(harness.captureEffectiveRoute(), baseline)
  }

  func testEffectiveRoute_remainsStableWhenUnrelatedAlertPresentationFlagsChange() throws {
    harness.applySignedIn(uid: "stable-user")
    harness.coordinator.rootModel.presentAccountProfileMismatch()
    let baseline = harness.captureEffectiveRoute()

    harness.coordinator.showUseDeviceProfileConfirmation = true
    harness.coordinator.isResolvingAccountMismatch = true
    harness.coordinator.retryFromAccountMismatch = true

    XCTAssertEqual(harness.captureEffectiveRoute(), baseline)
  }

  func testEffectiveRoute_remainsStableWhenAnalyticsColdStartFlagChanges() {
    harness.applySignedOut()
    let baseline = harness.captureEffectiveRoute()

    harness.coordinator.didLogColdStartWelcome = true
    harness.coordinator.handleEffectiveRouteChange(.welcome)

    XCTAssertEqual(harness.captureEffectiveRoute(), baseline)
  }

  func testEffectiveRoute_remainsStableWhenSignedInSessionIDRotates() throws {
    harness.applySignedIn(uid: "stable-user")
    _ = try harness.seedOwnedLocalProfile(uid: "stable-user")
    harness.coordinator.rootModel.didCompleteOnboarding()
    let baseline = harness.captureEffectiveRoute()

    harness.coordinator.signedInSessionID = UUID()

    XCTAssertEqual(harness.captureEffectiveRoute(), baseline)
  }

  func testEffectiveRoute_remainsStableWhenPendingUploadFailureContextChangesOnSameRootState() {
    harness.applySignedIn(uid: "stable-user")
    harness.coordinator.rootModel.presentCloudProfileUploadFailed()
    let baseline = harness.captureEffectiveRoute()

    harness.coordinator.pendingUploadFailureContext = .onboardingCompletion
    harness.coordinator.isRetryingCloudUpload = true

    XCTAssertEqual(harness.captureEffectiveRoute(), baseline)
  }
}
