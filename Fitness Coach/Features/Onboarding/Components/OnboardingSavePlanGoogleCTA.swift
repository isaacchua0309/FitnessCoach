//
//  OnboardingSavePlanGoogleCTA.swift
//  Fitness Coach
//
//  Forma — Save-plan primary Google sign-in call to action.
//

import SwiftUI

struct OnboardingSavePlanGoogleCTA: View {
    let isLoading: Bool
    let showsSuccess: Bool
    let isDisabled: Bool
    let action: () -> Void

    private let copy = FormaProductCopy.Onboarding.V2.SavePlan.self

    var body: some View {
        FormaGoogleSignInButton(
            title: copy.googleSignInCTA,
            subtitle: copy.googleSignInCTASubtitle,
            loadingTitle: copy.googleSignInLoadingTitle,
            successTitle: copy.googleSignInSuccessTitle,
            successAccessibilityLabel: copy.googleSignInSuccessAccessibilityLabel,
            isLoading: isLoading,
            showsSuccess: showsSuccess,
            isDisabled: isDisabled,
            action: action,
            accessibilityHint: ProfileSignInCopyPolicy.googleButtonAccessibilityHint(
                for: .onboardingCompletion
            )
        )
    }
}

#if DEBUG
#Preview("Idle") {
    OnboardingSavePlanGoogleCTA(
        isLoading: false,
        showsSuccess: false,
        isDisabled: false,
        action: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Loading") {
    OnboardingSavePlanGoogleCTA(
        isLoading: true,
        showsSuccess: false,
        isDisabled: true,
        action: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
