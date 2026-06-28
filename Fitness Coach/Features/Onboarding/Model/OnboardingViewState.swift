//
//  OnboardingViewState.swift
//  Fitness Coach
//
//  FitPilot AI — Screen-level state for Onboarding.
//

import Foundation

enum OnboardingViewState: Equatable {
    /// Interactive step editing.
    case editing
    /// Legacy inline generation overlay while still on the preferences step.
    case generatingPlan
    /// V2 dedicated generating-plan screen owns loading UI (no scroll overlay).
    case generatingPlanAnimated
    /// V2 generating-plan screen failed; user can return to summary.
    case generationFailed
    /// Save-plan step waiting for Google sign-in.
    case awaitingSignIn
    /// Local profile creation in progress on the save-plan step.
    case savingProfile
    /// Legacy plan-preview completion flow creating the profile.
    case completing
    /// Apple Health permission request in progress on the v4 connect step.
    case connectingAppleHealth
    case error(String)
}

extension OnboardingViewState {

    /// Whether the shared step container should render `OnboardingLoadingView`.
    var showsLoadingOverlay: Bool {
        switch self {
        case .generatingPlan, .completing, .savingProfile:
            return true
        case .editing, .generatingPlanAnimated, .generationFailed, .awaitingSignIn, .error, .connectingAppleHealth:
            return false
        }
    }

    /// Whether bottom-bar primary actions should show a busy spinner.
    var isBottomBarBusy: Bool {
        switch self {
        case .generatingPlan, .generatingPlanAnimated, .completing, .savingProfile, .connectingAppleHealth:
            return true
        case .editing, .generationFailed, .awaitingSignIn, .error:
            return false
        }
    }

    var loadingOverlayMessage: String? {
        switch self {
        case .generatingPlan:
            return FormaProductCopy.Loading.generatingPlan
        case .completing, .savingProfile:
            return FormaProductCopy.Loading.creatingProfile
        case .editing, .generatingPlanAnimated, .generationFailed, .awaitingSignIn, .error, .connectingAppleHealth:
            return nil
        }
    }

    var isInteractive: Bool {
        switch self {
        case .editing, .awaitingSignIn, .generationFailed:
            return true
        case .generatingPlan, .generatingPlanAnimated, .savingProfile, .completing, .error, .connectingAppleHealth:
            return false
        }
    }
}
