//
//  OnboardingStepContainer.swift
//  Fitness Coach
//
//  FitPilot AI — Shared scrollable shell for onboarding steps.
//

import SwiftUI

struct OnboardingStepContainer<Content: View>: View {
    let currentStep: OnboardingStep
    let errorMessage: String?
    let isLoading: Bool
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
                OnboardingProgressHeader(currentStep: currentStep)
                    .padding(.top, 12)

                if let errorMessage {
                    OnboardingWarningBanner(message: errorMessage)
                }

                content

                if isLoading {
                    OnboardingLoadingView(
                        message: currentStep == .planPreview
                            ? "Creating your profile..."
                            : "Generating your plan..."
                    )
                }
            }
            .padding(.horizontal, OnboardingTheme.pagePadding)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
}
