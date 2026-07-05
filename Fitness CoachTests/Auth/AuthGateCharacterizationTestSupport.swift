//
//  AuthGateCharacterizationTestSupport.swift
//  Fitness CoachTests
//
//  Shared harness for AuthGateCoordinator decomposition characterization tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
enum AuthGateCharacterizationTestSupport {

  struct Harness {
    let container: AppContainer
    let analytics: CapturingPublicEntryAnalyticsLogger
    let coordinator: AuthGateCoordinator

    func applySignedOut() {
      container.authManager.applyTestingAuthState(.signedOut)
    }

    func applySignedIn(uid: String) {
      container.authManager.applyTestingAuthState(.signedIn(uid: uid))
      coordinator.applyTestingSignedInUID(uid)
    }

    func applyUnknownAuth() {
      container.authManager.applyTestingAuthState(.unknown)
    }

    @discardableResult
    func seedOwnedLocalProfile(uid: String) throws -> UserProfile {
      let profile = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
      return try container.userProfileService.assignOwnerUID(uid)
    }

    func waitForAsyncWork(nanoseconds: UInt64 = 100_000_000) async {
      try? await Task.sleep(nanoseconds: nanoseconds)
    }

    /// Recomputes the same pipeline `AuthGateCoordinator.effectiveRoute` uses.
    func resolveExpectedEffectiveRoute() -> AppShellRoute {
      let coordinator = coordinator
      let inputs = AuthGateRouteInputs(
        authState: container.authManager.authState,
        rootState: coordinator.rootModel.state,
        isOnboardingModelReady: coordinator.onboardingModel != nil,
        awaitingCloudSync: coordinator.awaitingCloudSync,
        pendingOnboardingCompletion: coordinator.pendingSignInForOnboardingCompletion,
        publicEntryDestination: coordinator.publicEntryDestination,
        suppressAutomaticPublicEntryResume:
          container.publicEntrySessionStore.suppressAutomaticPublicEntryResume
      )
      return AuthGateRoutingCoordinator.effectiveRoute(
        inputs: inputs,
        container: container
      )
    }

    func assertEffectiveRoute(
      _ expected: AppShellRoute,
      file: StaticString = #filePath,
      line: UInt = #line
    ) {
      XCTAssertEqual(
        coordinator.effectiveRoute,
        expected,
        "effectiveRoute mismatch",
        file: file,
        line: line
      )
      XCTAssertEqual(
        coordinator.effectiveRoute,
        resolveExpectedEffectiveRoute(),
        "effectiveRoute diverged from resolveAppShellRoute + AuthGateRoutingPolicy pipeline",
        file: file,
        line: line
      )
    }

    func captureEffectiveRoute() -> AppShellRoute {
      coordinator.effectiveRoute
    }
  }

  struct RouteScenario: Sendable {
    let name: String
    let authState: AuthState
    let rootState: RootViewState
    let publicEntryDestination: PublicEntryRoute
    let isOnboardingModelReady: Bool
    let awaitingCloudSync: Bool
    let pendingOnboardingCompletion: Bool
    let hasLocalProfile: Bool
    let hasPersistedOnboardingDraft: Bool
    let localProfileAwaitingSignIn: Bool
    let suppressAutomaticPublicEntryResume: Bool
    let expectedRoute: AppShellRoute

    func configure(on harness: Harness) throws {
      harness.container.authManager.applyTestingAuthState(authState)
      harness.coordinator.publicEntryDestination = publicEntryDestination
      harness.coordinator.awaitingCloudSync = awaitingCloudSync
      harness.coordinator.pendingSignInForOnboardingCompletion = pendingOnboardingCompletion

      if suppressAutomaticPublicEntryResume {
        AuthLogoutPolicy.applyExplicitSignOut(sessionStore: harness.container.publicEntrySessionStore)
      }

      if hasLocalProfile {
        _ = try harness.seedOwnedLocalProfile(uid: "route-scenario-user")
      }

      if hasPersistedOnboardingDraft, !hasLocalProfile {
        var formState = OnboardingFormState()
        OnboardingModelTestSupport.seedCanonicalForm(&formState)
        harness.container.onboardingDraftStore.saveDraft(
          OnboardingDraft(formState: formState, step: .review)
        )
      }

      if localProfileAwaitingSignIn, hasLocalProfile {
        harness.coordinator.rootModel.resolveLocalProfile()
      }

      applyRootState(rootState, on: harness.coordinator)

      if isOnboardingModelReady {
        harness.coordinator.ensurePreAuthOnboardingModel()
      } else {
        harness.coordinator.onboardingModel = nil
      }
    }

    private func applyRootState(_ state: RootViewState, on coordinator: AuthGateCoordinator) {
      switch state {
      case .loading:
        coordinator.rootModel.resetForSignedOutSession()
      case .restoringAccount:
        coordinator.rootModel.beginAccountRestore(uid: "route-scenario-user")
      case .accountRestoreFailed(let message):
        coordinator.rootModel.beginAccountRestore(uid: "route-scenario-user")
        coordinator.rootModel.presentAccountRestoreFailed(message: message)
      case .missingCloudProfile:
        coordinator.rootModel.presentMissingCloudProfile()
      case .onboardingCloudProfileConflict:
        coordinator.rootModel.presentProfilePlanConflict()
      case .onboardingCloudCheckFailed:
        coordinator.rootModel.presentOnboardingCloudCheckFailed()
      case .existingUserProfileLookupFailed:
        coordinator.rootModel.presentExistingUserProfileLookupFailed()
      case .cloudProfileUploadFailed:
        coordinator.rootModel.presentCloudProfileUploadFailed()
      case .accountProfileMismatch:
        coordinator.rootModel.presentAccountProfileMismatch()
      case .onboarding:
        coordinator.rootModel.continueFromMissingCloudProfile()
      case .main:
        coordinator.rootModel.didCompleteOnboarding()
      case .error(let message):
        coordinator.rootModel.resetForSignedOutSession()
        _ = message
      }
    }
  }

  static func makeHarness(
    onboardingUserDefaults: UserDefaults? = nil
  ) throws -> Harness {
    let analytics = CapturingPublicEntryAnalyticsLogger()
    let container = try AppContainer(
      inMemory: true,
      onboardingUserDefaults: onboardingUserDefaults,
      publicEntryAnalyticsLogger: analytics
    )
    let coordinator = AuthGateCoordinator(container: container)
    return Harness(container: container, analytics: analytics, coordinator: coordinator)
  }

  static func allRouteScenarios() -> [RouteScenario] {
    let uid = "route-scenario-user"
    let signedIn = AuthState.signedIn(uid: uid)
    return [
      RouteScenario(
        name: "unknown_launch_loading",
        authState: .unknown,
        rootState: .loading,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .launchLoading
      ),
      RouteScenario(
        name: "signed_out_welcome",
        authState: .signedOut,
        rootState: .loading,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .welcome
      ),
      RouteScenario(
        name: "signed_out_existing_user_sign_in",
        authState: .signedOut,
        rootState: .loading,
        publicEntryDestination: .existingUserSignIn,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .existingUserSignIn
      ),
      RouteScenario(
        name: "signed_out_onboarding_start_ready",
        authState: .signedOut,
        rootState: .loading,
        publicEntryDestination: .onboardingStart,
        isOnboardingModelReady: true,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .onboardingStart
      ),
      RouteScenario(
        name: "signed_out_onboarding_start_initializing",
        authState: .signedOut,
        rootState: .loading,
        publicEntryDestination: .onboardingStart,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .onboardingStartInitializing
      ),
      RouteScenario(
        name: "signed_out_draft_resume_overlay",
        authState: .signedOut,
        rootState: .loading,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: true,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: true,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .onboardingStart
      ),
      RouteScenario(
        name: "signed_in_profile_loading",
        authState: signedIn,
        rootState: .loading,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .signedInProfileLoading
      ),
      RouteScenario(
        name: "signed_in_restoring_account",
        authState: signedIn,
        rootState: .restoringAccount,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .signedInProfileLoading
      ),
      RouteScenario(
        name: "signed_in_restore_failed",
        authState: signedIn,
        rootState: .accountRestoreFailed("Permission denied."),
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .accountRestoreFailed("Permission denied.")
      ),
      RouteScenario(
        name: "signed_in_no_existing_profile",
        authState: signedIn,
        rootState: .missingCloudProfile,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .noExistingProfileFound
      ),
      RouteScenario(
        name: "signed_in_profile_conflict",
        authState: signedIn,
        rootState: .onboardingCloudProfileConflict,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: true,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .onboardingCloudProfileConflict
      ),
      RouteScenario(
        name: "signed_in_cloud_check_failed",
        authState: signedIn,
        rootState: .onboardingCloudCheckFailed,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .onboardingCloudCheckFailed
      ),
      RouteScenario(
        name: "signed_in_existing_user_lookup_failed",
        authState: signedIn,
        rootState: .existingUserProfileLookupFailed,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .existingUserProfileLookupFailed
      ),
      RouteScenario(
        name: "signed_in_cloud_upload_failed",
        authState: signedIn,
        rootState: .cloudProfileUploadFailed,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .cloudProfileUploadFailed
      ),
      RouteScenario(
        name: "signed_in_account_mismatch",
        authState: signedIn,
        rootState: .accountProfileMismatch,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: true,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .accountProfileMismatch
      ),
      RouteScenario(
        name: "signed_in_onboarding_ready",
        authState: signedIn,
        rootState: .onboarding,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: true,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .onboarding
      ),
      RouteScenario(
        name: "signed_in_onboarding_initializing",
        authState: signedIn,
        rootState: .onboarding,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .onboardingInitializing
      ),
      RouteScenario(
        name: "signed_in_main",
        authState: signedIn,
        rootState: .main,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: true,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .main
      ),
      RouteScenario(
        name: "signed_in_main_awaiting_cloud_sync",
        authState: signedIn,
        rootState: .main,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: false,
        awaitingCloudSync: true,
        pendingOnboardingCompletion: false,
        hasLocalProfile: true,
        hasPersistedOnboardingDraft: false,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: false,
        expectedRoute: .signedInProfileLoading
      ),
      RouteScenario(
        name: "signed_out_suppressed_resume_stays_welcome",
        authState: .signedOut,
        rootState: .loading,
        publicEntryDestination: .welcome,
        isOnboardingModelReady: true,
        awaitingCloudSync: false,
        pendingOnboardingCompletion: false,
        hasLocalProfile: false,
        hasPersistedOnboardingDraft: true,
        localProfileAwaitingSignIn: false,
        suppressAutomaticPublicEntryResume: true,
        expectedRoute: .welcome
      )
    ]
  }
}
