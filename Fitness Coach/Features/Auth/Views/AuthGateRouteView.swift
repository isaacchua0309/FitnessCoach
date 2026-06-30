//
//  AuthGateRouteView.swift
//  Fitness Coach
//
//  Route switch for the auth-gated app shell.
//

import SwiftUI

struct AuthGateRouteView: View {
    @ObservedObject var coordinator: AuthGateCoordinator

    var body: some View {
        Group {
            switch coordinator.effectiveRoute {
            case .launchLoading, .onboardingStartInitializing, .onboardingInitializing:
                LaunchLoadingView()
                    .onAppear {
                        coordinator.bootstrapOnboardingIfNeeded()
                    }
            case .signedInProfileLoading:
                if coordinator.pendingExistingUserSignIn {
                    ExistingUserSignInResolvingView()
                } else {
                    LaunchLoadingView()
                        .onAppear {
                            coordinator.bootstrapOnboardingIfNeeded()
                        }
                }
            case .welcome:
                PublicWelcomeView(
                    analyticsLogger: coordinator.container.publicEntryAnalyticsLogger,
                    analyticsProperties: coordinator.publicEntryAnalyticsProperties(),
                    onCreateMyPlan: coordinator.beginOnboardingFromWelcome,
                    onSignIn: coordinator.beginExistingUserSignInFromWelcome
                )
            case .existingUserSignIn:
                ExistingUserSignInView(
                    analyticsLogger: coordinator.container.publicEntryAnalyticsLogger,
                    analyticsProperties: coordinator.publicEntryAnalyticsProperties(),
                    localError: coordinator.existingUserSignInError,
                    onBack: coordinator.returnToWelcomeFromExistingUserSignIn,
                    onCreateMyPlan: coordinator.beginOnboardingFromExistingUserSignIn,
                    onSignInRequested: coordinator.signInAsExistingUser
                )
            case .onboardingStart:
                AuthGateOnboardingShellView(
                    coordinator: coordinator,
                    onAppear: { coordinator.preparePreAuthOnboardingIfNeeded() },
                    onExitToWelcome: coordinator.returnToWelcomeFromOnboarding
                )
            case .noExistingProfileFound:
                NoExistingProfileFoundView(
                    analyticsLogger: coordinator.container.publicEntryAnalyticsLogger,
                    analyticsProperties: coordinator.publicEntryAnalyticsProperties(
                        profileResolutionResult: .noProfileFound
                    ),
                    onStartOnboarding: coordinator.beginOnboardingAfterNoExistingPlan,
                    onUseAnotherAccount: coordinator.useAnotherAccountAfterNoExistingPlan
                )
            case .onboardingCloudProfileConflict:
                AuthGateProfilePlanConflictHost(coordinator: coordinator)
            case .onboardingCloudCheckFailed:
                OnboardingCloudCheckFailedView {
                    coordinator.retryAccountMismatchOrOnboardingCloudCheck()
                }
            case .existingUserProfileLookupFailed:
                ExistingUserProfileLookupFailedView {
                    coordinator.retryExistingUserProfileResolution()
                }
            case .cloudProfileUploadFailed:
                CloudProfileUploadFailedView(
                    isRetrying: coordinator.isRetryingCloudUpload,
                    onRetry: coordinator.retryCloudProfileUpload,
                    onContinue: coordinator.continueAfterCloudUploadFailure
                )
            case .accountProfileMismatch:
                AccountProfileMismatchView(
                    isResolving: coordinator.isResolvingAccountMismatch,
                    onRestoreGooglePlan: coordinator.restoreGoogleAccountPlanAfterMismatch,
                    onUseDeviceProfile: coordinator.beginUseDeviceProfileAfterMismatch,
                    onSignOut: coordinator.signOutFromAccountMismatch
                )
            case .onboarding:
                AuthGateOnboardingShellView(
                    coordinator: coordinator,
                    onAppear: { coordinator.ensureOnboardingModel() },
                    onExitToWelcome: coordinator.returnToWelcomeFromOnboarding
                )
                .id(coordinator.signedInSessionID)
            case .main:
                MainTabView(container: coordinator.container)
                    .id(coordinator.signedInSessionID)
            case .profileError(let message):
                AuthGateProfileErrorView(
                    message: message,
                    onRetry: coordinator.retryProfileLoad
                )
            }
        }
    }
}
