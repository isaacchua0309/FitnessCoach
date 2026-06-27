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
    @ObservedObject var fieldNavigator: OnboardingFieldNavigator
    @ViewBuilder let content: Content

    var body: some View {
        ScrollViewReader { proxy in
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
                                ? FormaProductCopy.Loading.creatingProfile
                                : FormaProductCopy.Loading.generatingPlan
                        )
                    }
                }
                .padding(.horizontal, OnboardingTheme.pagePadding)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: fieldNavigator.scrollToID) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    proxy.scrollTo(target, anchor: UnitPoint(x: 0.5, y: 0.32))
                }
            }
            .onChange(of: currentStep) { _, _ in
                fieldNavigator.clearFocus()
                OnboardingKeyboard.dismiss()
            }
        }
    }
}
