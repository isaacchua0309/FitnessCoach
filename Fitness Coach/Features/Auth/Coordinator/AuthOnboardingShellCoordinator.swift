//
//  AuthOnboardingShellCoordinator.swift
//  Fitness Coach
//
//  Onboarding model lifecycle and onboarding-to-sign-in handoff for the auth gate shell.
//

import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
protocol AuthOnboardingShellCoordinatorDelegate: AnyObject {
    var onboardingModel: OnboardingModel? { get set }
    var pendingSignInForOnboardingCompletion: Bool { get set }
    var publicEntryDestination: PublicEntryRoute { get }
    var awaitingCloudSync: Bool { get set }
    var conflictCloudDocument: CloudUserProfileDocument? { get set }
    var isResolvingProfileConflict: Bool { get set }

    func notifyObjectWillChange()
    func resolveLocalProfile()
    func isSignedIn() -> Bool
    func currentUID() -> String?
    func isUIDStillCurrent(_ uid: String) -> Bool
    func rootState() -> RootViewState
    func clearProfileConflictState()
    func prepareSignedInAccountNamespace(uid: String) async
    func beginOnboardingCompletionCloudCheck()
    func resolveOnboardingCompletion(uid: String) async -> OnboardingCompletionOutcome
    func presentProfilePlanConflict()
    func presentOnboardingCloudCheckFailed()
    func presentCloudProfileUploadFailure(context: CloudProfileUploadFailureContext)
    func scheduleRouteToMainWithAccountRestore(uid: String, reason: AccountRestoreReason)
    func suppressAutomaticPublicEntryResume() -> Bool
    func hasLocalProfile() -> Bool
    func localProfileAwaitingSignIn() -> Bool
    func hasPersistedOnboardingDraft() -> Bool
}

@MainActor
final class AuthOnboardingShellCoordinator {

    private weak var delegate: AuthOnboardingShellCoordinatorDelegate?
    private let container: AppContainer
    private let authManager: AuthManager
    private var onboardingModelCancellable: AnyCancellable?

    init(container: AppContainer, authManager: AuthManager) {
        self.container = container
        self.authManager = authManager
    }

    func configure(delegate: AuthOnboardingShellCoordinatorDelegate) {
        self.delegate = delegate
    }

    // MARK: - Pre-auth onboarding

    func preparePreAuthOnboardingIfNeeded() {
        guard let delegate, !delegate.isSignedIn() else { return }
        delegate.resolveLocalProfile()
        if delegate.publicEntryDestination == WelcomeOnboardingHandoffPolicy.createPlanDestination {
            ensurePreAuthOnboardingModel()
        } else {
            ensureOnboardingModel()
        }
    }

    // MARK: - Onboarding model lifecycle

    /// Ensures the onboarding model exists whenever routing targets an initializing onboarding shell.
    /// Without this, `.onboardingInitializing` shows only
    /// `LaunchLoadingView` and never reach the views whose `onAppear` used to create the model.
    func bootstrapOnboardingIfNeeded() {
        guard let delegate else { return }
        let signedIn = delegate.isSignedIn()

        // After explicit sign-out, stay on welcome until the user chooses Create My Plan.
        if !signedIn,
           delegate.suppressAutomaticPublicEntryResume(),
           delegate.publicEntryDestination == .welcome {
            return
        }

        let hasLocalProfile = delegate.hasLocalProfile()
        let awaitingSignInHandoff = delegate.localProfileAwaitingSignIn()
        let shouldBootstrapPreAuth = !signedIn && (
            delegate.publicEntryDestination == WelcomeOnboardingHandoffPolicy.createPlanDestination
                || WelcomeOnboardingHandoffPolicy.shouldBypassWelcome(
                    PublicEntryRouteResolver.Input(
                        destination: delegate.publicEntryDestination,
                        isOnboardingModelReady: delegate.onboardingModel != nil,
                        localProfileAwaitingSignIn: awaitingSignInHandoff,
                        hasPersistedOnboardingDraft: delegate.hasPersistedOnboardingDraft(),
                        hasLocalProfile: hasLocalProfile,
                        pendingOnboardingCompletion: delegate.pendingSignInForOnboardingCompletion,
                        signedOutWithProfilePolicy: .requireSignIn,
                        suppressAutomaticPublicEntryResume: delegate.suppressAutomaticPublicEntryResume()
                    )
                )
        )

        let needsSignedInOnboarding = signedIn && delegate.rootState() == .onboarding

        if shouldBootstrapPreAuth {
            delegate.resolveLocalProfile()
            if delegate.publicEntryDestination == WelcomeOnboardingHandoffPolicy.createPlanDestination {
                ensurePreAuthOnboardingModel()
            } else {
                ensureOnboardingModel()
            }
        }

        if needsSignedInOnboarding {
            ensureOnboardingModel()
        }
    }

    func ensurePreAuthOnboardingModel() {
        guard let delegate else { return }
        guard delegate.onboardingModel == nil else { return }
        delegate.onboardingModel = container.makeOnboardingModel(
            entry: WelcomeOnboardingHandoffPolicy.preAuthEntry,
            onCompletion: { [weak self] in self?.handleOnboardingCompletionRequest() }
        )
        bindOnboardingModelChanges()
    }

    func ensureOnboardingModel() {
        guard let delegate else { return }
        guard delegate.onboardingModel == nil else { return }
        let entry = NoExistingProfileFoundPolicy.onboardingEntry(
            isSignedIn: delegate.isSignedIn()
        )
        delegate.onboardingModel = container.makeOnboardingModel(entry: entry) { [weak self] in
            self?.handleOnboardingCompletionRequest()
        }
        bindOnboardingModelChanges()
    }

    func handleOnboardingCompletionRequest() {
        guard let delegate else { return }
        if delegate.isSignedIn() {
            guard let uid = delegate.currentUID() else {
                finishOnboardingLocally()
                return
            }
            Task { await resolveOnboardingCompletionAfterSignIn(uid: uid) }
            return
        }

        delegate.pendingSignInForOnboardingCompletion = true
        delegate.onboardingModel?.logSavePlanSignInStarted()
        Task {
            let outcome = await authManager.signInWithGoogle()
            applyOnboardingGoogleSignInOutcome(outcome)
        }
    }

    func applyOnboardingGoogleSignInOutcome(_ outcome: GoogleSignInAttemptOutcome) {
        guard let delegate else { return }
        switch outcome {
        case .success:
            return
        case .cancelled:
            guard delegate.pendingSignInForOnboardingCompletion else { return }
            delegate.pendingSignInForOnboardingCompletion = false
            delegate.conflictCloudDocument = nil
            delegate.isResolvingProfileConflict = false
            delegate.onboardingModel?.handleGoogleSignInCancelled()
            authManager.clearTransientAuthState()
        case .failed:
            guard delegate.pendingSignInForOnboardingCompletion else { return }
            delegate.pendingSignInForOnboardingCompletion = false
            delegate.conflictCloudDocument = nil
            delegate.isResolvingProfileConflict = false
            delegate.onboardingModel?.handleGoogleSignInFailed()
            authManager.clearTransientAuthState()
        }
    }

    /// Signed-in onboarding completion: probe cloud, then sync or show conflict UI.
    func resolveOnboardingCompletionAfterSignIn(uid: String) async {
        guard let delegate else { return }
        await delegate.prepareSignedInAccountNamespace(uid: uid)
        guard delegate.isUIDStillCurrent(uid) else { return }
        delegate.beginOnboardingCompletionCloudCheck()

        let outcome = await delegate.resolveOnboardingCompletion(uid: uid)

        switch outcome {
        case .uploadedToCloud:
            finishOnboardingCompletionAfterSuccessfulSync()
        case .cloudProfileConflict(let document):
            delegate.conflictCloudDocument = document
            delegate.presentProfilePlanConflict()
        case .cloudCheckFailed:
            delegate.presentOnboardingCloudCheckFailed()
        case .cloudSyncFailed:
            delegate.presentCloudProfileUploadFailure(context: .onboardingCompletion)
        }
    }

    func finishOnboardingCompletionAfterSuccessfulSync() {
        guard let delegate else { return }
        delegate.onboardingModel?.markSignInSucceededForHandoff()

        Task { @MainActor in
            guard let uid = delegate.currentUID() else { return }
            let handoffDelayNanoseconds: UInt64 = UIAccessibility.isReduceMotionEnabled
                ? 280_000_000
                : 720_000_000
            try? await Task.sleep(nanoseconds: handoffDelayNanoseconds)
            clearOnboardingCompletionState()
            delegate.awaitingCloudSync = false
            delegate.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
        }
    }

    func clearOnboardingCompletionState() {
        guard let delegate else { return }
        delegate.pendingSignInForOnboardingCompletion = false
        delegate.clearProfileConflictState()
        delegate.onboardingModel = nil
    }

    func retryOnboardingCompletionCloudCheck() {
        guard let delegate, let uid = delegate.currentUID() else { return }
        Task { await resolveOnboardingCompletionAfterSignIn(uid: uid) }
    }

    func finishOnboardingLocally() {
        guard let delegate else { return }
        delegate.onboardingModel?.finalizeAfterSuccessfulSignIn()
        delegate.onboardingModel = nil
        delegate.awaitingCloudSync = false
        guard let uid = delegate.currentUID() else { return }
        delegate.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
    }

    // MARK: - Teardown helpers

    func clearOnboardingModel() {
        delegate?.onboardingModel = nil
    }

    func resetOnboardingForAuthenticatedSignOut() {
        guard let delegate else { return }
        delegate.onboardingModel = nil
        delegate.pendingSignInForOnboardingCompletion = false
    }

    func resetOnboardingForSignedOutTransition() {
        guard let delegate else { return }
        delegate.onboardingModel = nil
        delegate.pendingSignInForOnboardingCompletion = false
    }

    func clearOnboardingModelIfPolicyRequires(wasSignedIn: Bool) {
        guard let delegate else { return }
        guard AppRouteResolver.shouldClearOnboardingModel(
            wasSignedIn: wasSignedIn,
            isSignedIn: false,
            hasLocalProfile: delegate.hasLocalProfile(),
            hasPersistedOnboardingDraft: delegate.hasPersistedOnboardingDraft()
        ) else {
            return
        }
        delegate.onboardingModel = nil
    }

    func handleOnboardingSignInAttemptFailedIfNeeded(
        from previous: AuthState,
        to state: AuthState
    ) {
        guard let delegate else { return }
        guard delegate.pendingSignInForOnboardingCompletion,
              didSignInAttemptFail(from: previous, to: state) else {
            return
        }

        let wasCancelled: Bool
        if case .signedOut = state {
            wasCancelled = true
        } else {
            wasCancelled = false
        }
        if wasCancelled {
            delegate.onboardingModel?.handleGoogleSignInCancelled()
        } else {
            delegate.onboardingModel?.handleGoogleSignInFailed()
        }
        delegate.pendingSignInForOnboardingCompletion = false
        delegate.conflictCloudDocument = nil
        delegate.isResolvingProfileConflict = false
        authManager.clearTransientAuthState()
    }

    // MARK: - Conflict / upload completion hooks

    func commitLocalProfileForSavePlan() {
        delegate?.onboardingModel?.commitLocalProfileForSavePlan()
    }

    func finalizeAfterRestoredExistingPlanAndClearCompletionState() {
        delegate?.onboardingModel?.finalizeAfterRestoredExistingPlan()
        clearOnboardingCompletionState()
    }

    func finalizeAfterSuccessfulSignInAndClearCompletionState() {
        delegate?.onboardingModel?.finalizeAfterSuccessfulSignIn()
        clearOnboardingCompletionState()
    }

    // MARK: - Private

    private func bindOnboardingModelChanges() {
        onboardingModelCancellable = delegate?.onboardingModel?.objectWillChange
            .sink { [weak self] _ in self?.delegate?.notifyObjectWillChange() }
    }

    private func didSignInAttemptFail(from previous: AuthState, to state: AuthState) -> Bool {
        switch (previous, state) {
        case (.signingIn, .signedOut), (.signingIn, .failed):
            return true
        default:
            return false
        }
    }
}
