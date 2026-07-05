//
//  AuthGateCoordinatorDecompositionCharacterizationTests.swift
//  Fitness CoachTests
//
//  Freezes current AuthGateCoordinator behavior before lifecycle decomposition.
//  Run this suite before and after each extraction PR.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AuthGateCoordinatorDecompositionCharacterizationTests: XCTestCase {

  private var harness: AuthGateCharacterizationTestSupport.Harness!

  override func setUp() async throws {
    harness = try AuthGateCharacterizationTestSupport.makeHarness()
  }

  override func tearDown() {
    harness = nil
    super.tearDown()
  }

  // MARK: - 1. Route resolution
  //
  // Deep routing precedence, reset, and stability coverage lives in
  // AuthGateCoordinatorRoutingCharacterizationTests.

  func testEffectiveRoute_matchesAllConfiguredShellRoutes() throws {
    for scenario in AuthGateCharacterizationTestSupport.allRouteScenarios() {
      let localHarness = try AuthGateCharacterizationTestSupport.makeHarness()
      try scenario.configure(on: localHarness)

      XCTAssertEqual(
        localHarness.coordinator.effectiveRoute,
        scenario.expectedRoute,
        "Route mismatch for scenario \(scenario.name)"
      )
    }
  }

  func testEffectiveRoute_profileError_matchesResolverOutput() throws {
    harness.applySignedIn(uid: "profile-error-user")
    harness.coordinator.rootModel.resetForSignedOutSession()

    let expected = AppRouteResolver.resolve(
      authState: .signedIn(uid: "profile-error-user"),
      rootState: .error("bootstrap failed"),
      hasLocalProfile: false
    )
    XCTAssertEqual(expected, .profileError("bootstrap failed"))
  }

  func testEffectiveRoute_activeOnboardingSessionOverridesWelcome() throws {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .welcome
    harness.coordinator.ensurePreAuthOnboardingModel()

    XCTAssertEqual(harness.coordinator.effectiveRoute, .onboardingStart)
  }

  func testEffectiveRoute_existingUserSignInWinsOverActiveOnboardingSession() throws {
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .existingUserSignIn
    harness.coordinator.ensurePreAuthOnboardingModel()

    XCTAssertEqual(harness.coordinator.effectiveRoute, .existingUserSignIn)
  }

  // MARK: - 2. Public entry flow

  func testWelcome_defaultPublicState() throws {
    harness.applySignedOut()

    XCTAssertEqual(harness.coordinator.publicEntryDestination, .welcome)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .welcome)
    XCTAssertNil(harness.coordinator.onboardingModel)
  }

  func testBeginExistingUserSignIn_setsDestinationAndClearsOnboarding() throws {
    harness.applySignedOut()
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.coordinator.beginExistingUserSignInFromWelcome()

    XCTAssertEqual(harness.coordinator.publicEntryDestination, .existingUserSignIn)
    XCTAssertNil(harness.coordinator.onboardingModel)
    XCTAssertNil(harness.coordinator.existingUserSignInError)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .existingUserSignIn)
  }

  func testReturnToWelcomeFromExistingUserSignIn_clearsSessionFlags() {
    harness.coordinator.pendingExistingUserSignIn = true
    harness.coordinator.existingUserSignInSessionActive = true
    harness.coordinator.existingUserSignInError = .networkFailed
    harness.coordinator.publicEntryDestination = .existingUserSignIn

    harness.coordinator.returnToWelcomeFromExistingUserSignIn()

    XCTAssertFalse(harness.coordinator.pendingExistingUserSignIn)
    XCTAssertFalse(harness.coordinator.existingUserSignInSessionActive)
    XCTAssertNil(harness.coordinator.existingUserSignInError)
    XCTAssertEqual(harness.coordinator.publicEntryDestination, .welcome)
  }

  func testSignInAsExistingUser_setsPendingFlagsAndLogsAnalytics() {
    harness.coordinator.signInAsExistingUser()

    XCTAssertTrue(harness.coordinator.pendingExistingUserSignIn)
    XCTAssertTrue(harness.coordinator.existingUserSignInSessionActive)
    XCTAssertNil(harness.coordinator.existingUserSignInError)
    XCTAssertTrue(harness.analytics.contains(.existingSignInStarted))
  }

  func testApplyExistingUserGoogleSignInOutcome_cancelledResetsSession() {
    harness.coordinator.existingUserSignInSessionActive = true
    harness.coordinator.pendingExistingUserSignIn = true

    harness.coordinator.applyExistingUserGoogleSignInOutcome(.cancelled)

    XCTAssertFalse(harness.coordinator.existingUserSignInSessionActive)
    XCTAssertFalse(harness.coordinator.pendingExistingUserSignIn)
    XCTAssertNil(harness.coordinator.existingUserSignInError)
    XCTAssertEqual(harness.container.authManager.authState, .signedOut)
  }

  func testApplyExistingUserGoogleSignInOutcome_failedSetsErrorAndDestination() {
    harness.coordinator.existingUserSignInSessionActive = true
    harness.coordinator.pendingExistingUserSignIn = true
    harness.container.authManager.applyTestingAuthState(
      .failed(AuthSignInUserMessage.signInFailureMessage)
    )

    harness.coordinator.applyExistingUserGoogleSignInOutcome(
      .failed(message: AuthSignInUserMessage.signInFailureMessage)
    )

    XCTAssertFalse(harness.coordinator.existingUserSignInSessionActive)
    XCTAssertFalse(harness.coordinator.pendingExistingUserSignIn)
    XCTAssertEqual(harness.coordinator.existingUserSignInError, .networkFailed)
    XCTAssertEqual(harness.coordinator.publicEntryDestination, .existingUserSignIn)
    XCTAssertTrue(harness.analytics.contains(.existingSignInFailed))
  }

  func testBeginOnboardingFromWelcome_setsCreatePlanDestinationAndModel() throws {
    harness.applySignedOut()

    harness.coordinator.beginOnboardingFromWelcome()

    XCTAssertEqual(
      harness.coordinator.publicEntryDestination,
      WelcomeOnboardingHandoffPolicy.createPlanDestination
    )
    XCTAssertNotNil(harness.coordinator.onboardingModel)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .onboardingStart)
  }

  func testHandleEffectiveRouteChange_logsWelcomeAnalyticsOnceForColdStart() {
    harness.applySignedOut()

    harness.coordinator.handleEffectiveRouteChange(.welcome)

    XCTAssertTrue(harness.analytics.contains(.welcomeViewed))
    XCTAssertTrue(harness.coordinator.didLogColdStartWelcome)
    XCTAssertEqual(
      harness.analytics.lastProperties(for: .welcomeViewed)?["entry_source"],
      PublicEntryEntrySource.freshInstall.rawValue
    )
  }

  func testHandleEffectiveRouteChange_logsLogoutEntrySourceWhenPending() {
    harness.applySignedOut()
    harness.container.publicEntrySessionStore.markUserInitiatedLogout()

    harness.coordinator.handleEffectiveRouteChange(.welcome)

    XCTAssertTrue(harness.analytics.contains(.welcomeViewed))
    XCTAssertTrue(harness.analytics.contains(.logoutCompletedPublicEntryShown))
    XCTAssertEqual(
      harness.analytics.lastProperties(for: .welcomeViewed)?["entry_source"],
      PublicEntryEntrySource.logout.rawValue
    )
  }

  // MARK: - 3. Pre-auth onboarding handoff

  func testStartPreAuthOnboarding_createsOnboardingModel() throws {
    harness.applySignedOut()

    harness.coordinator.startPreAuthOnboarding()

    XCTAssertNotNil(harness.coordinator.onboardingModel)
    XCTAssertEqual(
      harness.coordinator.publicEntryDestination,
      WelcomeOnboardingHandoffPolicy.createPlanDestination
    )
  }

  func testReturnToWelcomeFromOnboarding_clearsModelAndDraft() throws {
    harness.applySignedOut()
    var formState = OnboardingFormState()
    OnboardingModelTestSupport.seedCanonicalForm(&formState)
    harness.container.onboardingDraftStore.saveDraft(
      OnboardingDraft(formState: formState, step: .review)
    )
    harness.coordinator.startPreAuthOnboarding()

    harness.coordinator.returnToWelcomeFromOnboarding()

    XCTAssertNil(harness.coordinator.onboardingModel)
    XCTAssertEqual(harness.coordinator.publicEntryDestination, .welcome)
    XCTAssertFalse(harness.container.onboardingDraftStore.hasDraft)
  }

  func testHandleOnboardingCompletionRequest_whenSignedOut_setsPendingSignIn() {
    harness.applySignedOut()
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.coordinator.handleOnboardingCompletionRequest()

    XCTAssertTrue(harness.coordinator.pendingSignInForOnboardingCompletion)
  }

  func testApplyOnboardingGoogleSignInOutcome_cancelledClearsPendingState() {
    harness.coordinator.pendingSignInForOnboardingCompletion = true
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.coordinator.applyOnboardingGoogleSignInOutcome(.cancelled)

    XCTAssertFalse(harness.coordinator.pendingSignInForOnboardingCompletion)
    XCTAssertNil(harness.coordinator.conflictCloudDocument)
    XCTAssertFalse(harness.coordinator.isResolvingProfileConflict)
    XCTAssertEqual(harness.container.authManager.authState, .signedOut)
  }

  func testApplyOnboardingGoogleSignInOutcome_failedClearsPendingState() {
    harness.coordinator.pendingSignInForOnboardingCompletion = true
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.coordinator.applyOnboardingGoogleSignInOutcome(
      .failed(message: AuthSignInUserMessage.signInFailureMessage)
    )

    XCTAssertFalse(harness.coordinator.pendingSignInForOnboardingCompletion)
    XCTAssertNil(harness.coordinator.conflictCloudDocument)
    XCTAssertFalse(harness.coordinator.isResolvingProfileConflict)
    XCTAssertEqual(harness.container.authManager.authState, .signedOut)
  }

  func testClearOnboardingCompletionState_clearsModelAndConflict() {
    harness.coordinator.pendingSignInForOnboardingCompletion = true
    harness.coordinator.conflictCloudDocument = ProfileTestFixtures.cloudDocument()
    harness.coordinator.isResolvingProfileConflict = true
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.coordinator.clearOnboardingCompletionState()

    XCTAssertFalse(harness.coordinator.pendingSignInForOnboardingCompletion)
    XCTAssertNil(harness.coordinator.conflictCloudDocument)
    XCTAssertFalse(harness.coordinator.isResolvingProfileConflict)
    XCTAssertNil(harness.coordinator.onboardingModel)
  }

  func testBootstrapOnboardingSkippedAfterExplicitSignOutUntilCreateMyPlan() throws {
    AuthLogoutPolicy.applyExplicitSignOut(sessionStore: harness.container.publicEntrySessionStore)
    harness.applySignedOut()
    harness.coordinator.publicEntryDestination = .welcome

    harness.coordinator.bootstrapOnboardingIfNeeded()

    XCTAssertNil(harness.coordinator.onboardingModel)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .welcome)
  }

  func testReEntryAfterWelcomeCreatePlan_bootstrapsOnboardingModel() throws {
    harness.applySignedOut()
    AuthLogoutPolicy.applyExplicitSignOut(sessionStore: harness.container.publicEntrySessionStore)
    harness.coordinator.publicEntryDestination = .welcome
    harness.coordinator.bootstrapOnboardingIfNeeded()
    XCTAssertNil(harness.coordinator.onboardingModel)

    harness.coordinator.beginOnboardingFromWelcome()
    harness.coordinator.bootstrapOnboardingIfNeeded()

    XCTAssertNotNil(harness.coordinator.onboardingModel)
  }

  // MARK: - 4. Signed-in flow

  func testHandleAuthStateChange_freshSignInRotatesSignedInSessionID() async throws {
    let priorSessionID = harness.coordinator.signedInSessionID
    _ = try harness.seedOwnedLocalProfile(uid: "fresh-sign-in-user")

    harness.coordinator.handleAuthStateChange(
      from: .signedOut,
      to: .signedIn(uid: "fresh-sign-in-user")
    )
    await harness.waitForAsyncWork()

    XCTAssertNotEqual(harness.coordinator.signedInSessionID, priorSessionID)
    XCTAssertEqual(harness.coordinator.publicEntryDestination, .welcome)
  }

  func testHandleAuthStateChange_resumedSignInDoesNotRotateSessionID() async throws {
    harness.applySignedIn(uid: "resumed-user")
    _ = try harness.seedOwnedLocalProfile(uid: "resumed-user")
    let priorSessionID = harness.coordinator.signedInSessionID

    harness.coordinator.handleAuthStateChange(
      from: .signedIn(uid: "resumed-user"),
      to: .signedIn(uid: "resumed-user")
    )
    await harness.waitForAsyncWork()

    XCTAssertEqual(harness.coordinator.signedInSessionID, priorSessionID)
  }

  func testReconcileSignedInProfile_routesToMainForOwnedLocalProfile() async throws {
    _ = try harness.seedOwnedLocalProfile(uid: "signed-in-user")

    await harness.coordinator.reconcileSignedInProfile(uid: "signed-in-user", isFreshSignIn: true)

    XCTAssertEqual(harness.coordinator.rootModel.state, .main)
  }

  func testReconcileSignedInProfile_preservesAccountMismatchForOwnerConflict() async throws {
    _ = try harness.container.userProfileService.createProfile(
      ProfileTestFixtures.sampleDraft,
      ownerUID: "user-a"
    )

    await harness.coordinator.reconcileSignedInProfile(uid: "user-b", isFreshSignIn: true)

    XCTAssertEqual(harness.coordinator.rootModel.state, .accountProfileMismatch)
  }

  func testHandleRootStateChange_mainCompletesExistingUserSignInSession() {
    harness.coordinator.existingUserSignInSessionActive = true
    harness.coordinator.lastExistingUserResolutionResult = .profileFound(.localOwned)

    harness.coordinator.handleRootStateChange(.main)

    XCTAssertFalse(harness.coordinator.existingUserSignInSessionActive)
    XCTAssertNil(harness.coordinator.existingUserSignInError)
    XCTAssertFalse(harness.coordinator.pendingExistingUserSignIn)
    XCTAssertTrue(harness.analytics.contains(.existingSignInSucceeded))
  }

  func testHandleRootStateChange_missingCloudProfileClearsExistingUserFlags() {
    harness.coordinator.pendingExistingUserSignIn = true
    harness.coordinator.existingUserSignInSessionActive = true
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.coordinator.handleRootStateChange(.missingCloudProfile)

    XCTAssertNil(harness.coordinator.onboardingModel)
    XCTAssertFalse(harness.coordinator.pendingExistingUserSignIn)
    XCTAssertFalse(harness.coordinator.existingUserSignInSessionActive)
  }

  func testHandleRootStateChange_accountMismatchClearsOnboardingModel() {
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.coordinator.handleRootStateChange(.accountProfileMismatch)

    XCTAssertNil(harness.coordinator.onboardingModel)
  }

  func testHandleRootStateChange_onboardingBootstrapsModelWhenNeeded() {
    harness.applySignedIn(uid: "onboarding-user")
    harness.coordinator.rootModel.continueFromMissingCloudProfile()

    harness.coordinator.handleRootStateChange(.onboarding)

    XCTAssertNotNil(harness.coordinator.onboardingModel)
  }

  func testHandleSignedOutTransition_resetsAuthenticatedShellState() throws {
    harness.applySignedIn(uid: "signed-in-user")
    harness.coordinator.rootModel.didCompleteOnboarding()
    harness.coordinator.awaitingCloudSync = true
    harness.coordinator.accountRestoreViewModel = AccountRestoreViewModel(container: harness.container)
    let priorSessionID = harness.coordinator.signedInSessionID

    harness.coordinator.handleSignedOutTransition(
      from: .signedIn(uid: "signed-in-user"),
      to: .signedOut,
      wasSignedIn: true
    )

    XCTAssertEqual(harness.coordinator.publicEntryDestination, .welcome)
    XCTAssertEqual(harness.coordinator.rootModel.state, .loading)
    XCTAssertNil(harness.coordinator.onboardingModel)
    XCTAssertFalse(harness.coordinator.awaitingCloudSync)
    XCTAssertNil(harness.coordinator.accountRestoreViewModel)
    XCTAssertNotEqual(harness.coordinator.signedInSessionID, priorSessionID)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .welcome)
  }

  func testPrepareAuthenticatedSignOut_resetsShellBeforeSignOut() throws {
    harness.applySignedIn(uid: "signed-in-user")
    harness.coordinator.rootModel.didCompleteOnboarding()
    harness.coordinator.ensureOnboardingModel()

    harness.coordinator.prepareAuthenticatedSignOut(source: "account_settings")

    XCTAssertEqual(harness.coordinator.rootModel.state, .loading)
    XCTAssertNil(harness.coordinator.onboardingModel)
    XCTAssertEqual(harness.coordinator.publicEntryDestination, .welcome)
  }

  // MARK: - 5. Profile conflict / account mismatch

  func testPresentProfileConflict_setsDocumentAndRoutesToConflict() throws {
    harness.applySignedIn(uid: "conflict-user")
    _ = try harness.seedOwnedLocalProfile(uid: "conflict-user")
    let document = ProfileTestFixtures.cloudDocument()

    harness.coordinator.conflictCloudDocument = document
    harness.coordinator.profileConflictContext = .onboardingCompletion
    harness.coordinator.rootModel.presentProfilePlanConflict()

    XCTAssertEqual(harness.coordinator.rootModel.state, .onboardingCloudProfileConflict)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .onboardingCloudProfileConflict)
    XCTAssertEqual(harness.coordinator.conflictCloudDocument, document)
  }

  func testBeginUseDevicePlanAfterConflict_presentsOverwriteConfirmation() {
    harness.coordinator.beginUseDevicePlanAfterConflict()

    XCTAssertTrue(harness.coordinator.showUseDevicePlanOverwriteConfirmation)
  }

  func testClearProfileConflictState_resetsConflictPresentation() {
    harness.coordinator.conflictCloudDocument = ProfileTestFixtures.cloudDocument()
    harness.coordinator.isResolvingProfileConflict = true
    harness.coordinator.profileConflictContext = .onboardingCompletion

    harness.coordinator.clearProfileConflictState()

    XCTAssertNil(harness.coordinator.conflictCloudDocument)
    XCTAssertFalse(harness.coordinator.isResolvingProfileConflict)
    XCTAssertEqual(
      harness.coordinator.profileConflictContext,
      .accountOrOwnershipReconcile
    )
  }

  func testPresentCloudProfileUploadFailure_setsFailureContextAndRootState() {
    harness.applySignedIn(uid: "upload-user")

    harness.coordinator.presentCloudProfileUploadFailure(context: .onboardingCompletion)

    XCTAssertEqual(harness.coordinator.pendingUploadFailureContext, .onboardingCompletion)
    XCTAssertEqual(harness.coordinator.rootModel.state, .cloudProfileUploadFailed)
    XCTAssertFalse(harness.coordinator.awaitingCloudSync)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .cloudProfileUploadFailed)
  }

  func testAccountMismatchPresentationRoutesToMismatchSurface() throws {
    harness.applySignedIn(uid: "mismatch-user")
    _ = try harness.container.userProfileService.createProfile(
      ProfileTestFixtures.sampleDraft,
      ownerUID: "other-user"
    )
    harness.coordinator.rootModel.presentAccountProfileMismatch()

    XCTAssertEqual(harness.coordinator.rootModel.state, .accountProfileMismatch)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .accountProfileMismatch)
  }

  func testBeginUseDeviceProfileAfterMismatch_whenCloudMissing_requestsConfirmation() async throws {
    harness.applySignedIn(uid: "mismatch-user")
    _ = try harness.container.userProfileService.createProfile(
      ProfileTestFixtures.sampleDraft,
      ownerUID: "other-user"
    )
    harness.coordinator.rootModel.presentAccountProfileMismatch()

    harness.coordinator.beginUseDeviceProfileAfterMismatch()
    await harness.waitForAsyncWork(nanoseconds: 300_000_000)

    XCTAssertFalse(harness.coordinator.isResolvingAccountMismatch)
    XCTAssertTrue(harness.coordinator.showUseDeviceProfileConfirmation)
  }

  func testApplyExistingUserSignInResolution_conflictPresentsConflictFlow() {
    harness.applySignedIn(uid: "conflict-user")
    harness.coordinator.existingUserSignInSessionActive = true

    harness.coordinator.applyExistingUserSignInResolution(.conflict, uid: "conflict-user")

    XCTAssertEqual(harness.coordinator.profileConflictContext, .accountOrOwnershipReconcile)
    XCTAssertFalse(harness.coordinator.pendingExistingUserSignIn)
    XCTAssertFalse(harness.coordinator.awaitingCloudSync)
  }

  func testContinueAfterCloudUploadFailure_clearsPendingContextAndRoutesToMain() throws {
    harness.applySignedIn(uid: "upload-user")
    _ = try harness.seedOwnedLocalProfile(uid: "upload-user")
    harness.coordinator.pendingUploadFailureContext = .reconcileUpload
    harness.coordinator.rootModel.presentCloudProfileUploadFailed()

    harness.coordinator.continueAfterCloudUploadFailure()

    XCTAssertNil(harness.coordinator.pendingUploadFailureContext)
    XCTAssertFalse(harness.coordinator.awaitingCloudSync)
    XCTAssertEqual(harness.coordinator.rootModel.state, .main)
  }

  // MARK: - 6. Account restore routing

  func testRouteToMainWithAccountRestore_whenDisabled_skipsRestoreViewModel() throws {
    let uid = "direct-main-user"
    harness.applySignedIn(uid: uid)
    _ = try harness.seedOwnedLocalProfile(uid: uid)

    harness.coordinator.routeToMainWithAccountRestore(uid: uid, reason: .afterSignIn)

    if AccountRestoreCoordinatorSupport.isRestoreEnabled {
      XCTAssertNotNil(harness.coordinator.accountRestoreViewModel)
      XCTAssertEqual(harness.coordinator.rootModel.state, .restoringAccount)
    } else {
      XCTAssertNil(harness.coordinator.accountRestoreViewModel)
      XCTAssertEqual(harness.coordinator.rootModel.state, .main)
    }
  }

  func testCompleteRouteToMain_entersMainShell() throws {
    let uid = "restored-user"
    let summary = RestoreAwareTestSupport.makeRestoreSummary(uid: uid, status: .completed)
    harness.applySignedIn(uid: uid)
    _ = try harness.seedOwnedLocalProfile(uid: uid)

    harness.coordinator.completeRouteToMain(uid: uid, restoreSummary: summary)

    XCTAssertEqual(harness.coordinator.rootModel.state, .main)
    XCTAssertFalse(harness.container.accountRestoreSessionState.isBlockingRestoreActive)
    XCTAssertNil(harness.coordinator.accountRestoreViewModel)
  }

  func testScheduleRouteToMainWithAccountRestore_presentsRestoreViewModel() async throws {
    let uid = "scheduled-restore-user"
    harness.applySignedIn(uid: uid)
    _ = try harness.seedOwnedLocalProfile(uid: uid)

    harness.coordinator.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
    await harness.waitForAsyncWork()

    if AccountRestoreCoordinatorSupport.isRestoreEnabled {
      XCTAssertNotNil(harness.coordinator.accountRestoreViewModel)
      XCTAssertEqual(harness.coordinator.rootModel.state, .restoringAccount)
    } else {
      XCTAssertEqual(harness.coordinator.rootModel.state, .main)
    }
  }

  func testRetryAccountRestore_forwardsToViewModel() {
    let viewModel = AccountRestoreViewModel(container: harness.container)
    harness.coordinator.accountRestoreViewModel = viewModel
    harness.coordinator.rootModel.presentAccountRestoreFailed(message: "failed")

    harness.coordinator.retryAccountRestore()

    XCTAssertNotNil(harness.coordinator.accountRestoreViewModel)
  }

  func testSignedOutTransition_cancelsRestoreTaskAndViewModel() throws {
    harness.coordinator.rootModel.beginAccountRestore(uid: "user-a")
    harness.coordinator.accountRestoreViewModel = AccountRestoreViewModel(container: harness.container)
    harness.container.accountRestoreSessionState.beginBlockingRestore()

    harness.coordinator.handleSignedOutTransition(
      from: .signedIn(uid: "user-a"),
      to: .signedOut,
      wasSignedIn: true
    )

    XCTAssertNil(harness.coordinator.accountRestoreViewModel)
    XCTAssertFalse(harness.container.accountRestoreSessionState.isBlockingRestoreActive)
    XCTAssertEqual(harness.coordinator.rootModel.state, .loading)
  }

  func testApplyExistingUserSignInResolution_noProfileRoutesToInterstitial() {
    harness.applySignedIn(uid: "new-user")
    harness.coordinator.existingUserSignInSessionActive = true

    harness.coordinator.applyExistingUserSignInResolution(.noProfileFound, uid: "new-user")

    XCTAssertEqual(harness.coordinator.rootModel.state, .missingCloudProfile)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .noExistingProfileFound)
    XCTAssertNil(harness.coordinator.accountRestoreViewModel)
    XCTAssertTrue(harness.analytics.contains(.existingSignInNoProfileFound))
  }

  // MARK: - 7. Existing-user sign-in error paths

  func testCompleteExistingUserSignInFailure_setsErrorAndDestination() {
    harness.coordinator.existingUserSignInSessionActive = true
    harness.coordinator.pendingExistingUserSignIn = true

    harness.coordinator.completeExistingUserSignInFailure(.networkFailed)

    XCTAssertEqual(harness.coordinator.existingUserSignInError, .networkFailed)
    XCTAssertEqual(harness.coordinator.publicEntryDestination, .existingUserSignIn)
    XCTAssertFalse(harness.coordinator.existingUserSignInSessionActive)
    XCTAssertFalse(harness.coordinator.pendingExistingUserSignIn)
    XCTAssertTrue(harness.analytics.contains(.existingSignInFailed))
  }

  func testApplyExistingUserSignInResolution_lookupFailedRoutesToRetrySurface() {
    harness.applySignedIn(uid: "failed-user")
    harness.coordinator.existingUserSignInSessionActive = true

    harness.coordinator.applyExistingUserSignInResolution(.lookupFailed, uid: "failed-user")

    XCTAssertEqual(harness.coordinator.rootModel.state, .existingUserProfileLookupFailed)
    XCTAssertEqual(harness.coordinator.effectiveRoute, .existingUserProfileLookupFailed)
    XCTAssertFalse(harness.coordinator.existingUserSignInSessionActive)
    XCTAssertTrue(harness.analytics.contains(.existingSignInFailed))
  }

  func testHandleSignedOutTransition_existingUserSignInFailureDuringSigningIn() {
    harness.coordinator.existingUserSignInSessionActive = true
    harness.coordinator.pendingExistingUserSignIn = true

    harness.coordinator.handleSignedOutTransition(
      from: .signingIn,
      to: .failed(AuthSignInUserMessage.signInFailureMessage),
      wasSignedIn: false
    )

    XCTAssertEqual(harness.coordinator.existingUserSignInError, .networkFailed)
    XCTAssertEqual(harness.coordinator.publicEntryDestination, .existingUserSignIn)
    XCTAssertFalse(harness.coordinator.existingUserSignInSessionActive)
  }

  func testHandleSignedOutTransition_onboardingSignInFailureClearsPendingCompletion() {
    harness.coordinator.pendingSignInForOnboardingCompletion = true
    harness.coordinator.conflictCloudDocument = ProfileTestFixtures.cloudDocument()
    harness.coordinator.isResolvingProfileConflict = true
    harness.coordinator.ensurePreAuthOnboardingModel()

    harness.coordinator.handleSignedOutTransition(
      from: .signingIn,
      to: .failed(AuthSignInUserMessage.signInFailureMessage),
      wasSignedIn: false
    )

    XCTAssertFalse(harness.coordinator.pendingSignInForOnboardingCompletion)
    XCTAssertNil(harness.coordinator.conflictCloudDocument)
    XCTAssertFalse(harness.coordinator.isResolvingProfileConflict)
  }

  func testUseAnotherAccountAfterNoExistingPlan_preparesReturnToExistingUserSignIn() throws {
    harness.applySignedIn(uid: "no-plan-user")
    harness.coordinator.rootModel.presentMissingCloudProfile()

    harness.coordinator.useAnotherAccountAfterNoExistingPlan()

    XCTAssertTrue(harness.coordinator.returnToExistingUserSignInAfterSignOut)
    XCTAssertNil(harness.coordinator.onboardingModel)
    XCTAssertEqual(harness.container.authManager.authState, .signedOut)
  }

  func testIsUIDStillCurrent_respectsTestingOverride() {
    harness.coordinator.applyTestingSignedInUID("override-user")

    XCTAssertTrue(harness.coordinator.isUIDStillCurrent("override-user"))
    XCTAssertFalse(harness.coordinator.isUIDStillCurrent("other-user"))
  }
}
