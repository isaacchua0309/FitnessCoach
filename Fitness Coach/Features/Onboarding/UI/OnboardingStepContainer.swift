//
//  OnboardingStepContainer.swift
//  Fitness Coach
//
//  FitPilot AI — Shared scrollable shell for onboarding steps.
//

import SwiftUI

struct OnboardingStepContainer<Content: View>: View {
    let currentStep: OnboardingStep
    let viewState: OnboardingViewState
    let validationMessage: String?
    var keyboardHeight: CGFloat = 0
    @ObservedObject var fieldNavigator: OnboardingFieldNavigator
    @ViewBuilder let content: Content

    private var usesFullScreenShell: Bool {
        currentStep.usesFullScreenChrome
    }

    private var showsLoadingOverlay: Bool {
        guard viewState.showsLoadingOverlay else { return false }
        switch currentStep {
        case .generatingPlan, .planReveal, .savePlan:
            return false
        default:
            return true
        }
    }

    private var showsContainerValidationBanner: Bool {
        guard let validationMessage, !validationMessage.isEmpty else { return false }
        if currentStep == .review || currentStep == .savePlan {
            return false
        }
        return true
    }

    private var scrollBottomInset: CGFloat {
        OnboardingLayout.scrollContentBottomInset(keyboardHeight: keyboardHeight)
    }

    var body: some View {
        Group {
            if usesFullScreenShell {
                fullScreenShell
            } else {
                scrollableShell
            }
        }
        .onChange(of: currentStep) { _, _ in
            fieldNavigator.clearFocus()
            OnboardingKeyboard.dismiss()
        }
    }

    private var fullScreenShell: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, OnboardingTheme.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 16)
    }

    private var scrollableShell: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
                    progressHeader
                        .padding(.top, OnboardingLayout.progressHeaderTop)

                    if showsContainerValidationBanner {
                        OnboardingWarningBanner(message: validationMessage ?? "")
                    }

                    content

                    if showsLoadingOverlay, let message = viewState.loadingOverlayMessage {
                        OnboardingLoadingView(message: message)
                    }
                }
                .padding(.horizontal, OnboardingTheme.pagePadding)
                .padding(.bottom, scrollBottomInset)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: fieldNavigator.scrollToID) { _, target in
                guard let target else { return }
                let anchor = scrollAnchor
                withAnimation(.easeInOut(duration: 0.28)) {
                    proxy.scrollTo(target, anchor: anchor)
                }
            }
        }
    }

    private var scrollAnchor: UnitPoint {
        keyboardHeight > 0
            ? UnitPoint(x: 0.5, y: 0.12)
            : UnitPoint(x: 0.5, y: 0.38)
    }

    @ViewBuilder
    private var progressHeader: some View {
        if currentStep.showsProgressHeader {
            OnboardingStageProgressHeader(currentStep: currentStep)
        }
    }
}
