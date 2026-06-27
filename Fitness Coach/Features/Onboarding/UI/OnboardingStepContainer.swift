//
//  OnboardingStepContainer.swift
//  Fitness Coach
//
//  FitPilot AI — Shared scrollable shell for onboarding steps.
//

import SwiftUI

struct OnboardingStepContainer<Content: View>: View {
    let currentStep: OnboardingStep
    let usesStageProgress: Bool
    let viewState: OnboardingViewState
    let errorMessage: String?
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

    // MARK: - Full-screen (generating plan)

    private var fullScreenShell: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, OnboardingTheme.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 16)
    }

    // MARK: - Scrollable steps

    private var scrollableShell: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
                    progressHeader
                        .padding(.top, 12)

                    if let errorMessage {
                        OnboardingWarningBanner(message: errorMessage)
                    }

                    content

                    if showsLoadingOverlay, let message = viewState.loadingOverlayMessage {
                        OnboardingLoadingView(message: message)
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: fieldNavigator.scrollToID) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.28)) {
                    proxy.scrollTo(target, anchor: UnitPoint(x: 0.5, y: 0.32))
                }
            }
        }
    }

    @ViewBuilder
    private var progressHeader: some View {
        if currentStep.showsProgressHeader {
            if usesStageProgress {
                OnboardingStageProgressHeader(currentStep: currentStep)
            } else {
                OnboardingProgressHeader(currentStep: currentStep)
            }
        }
    }

    private var contentHorizontalPadding: CGFloat {
        currentStep == .landing ? 0 : OnboardingTheme.pagePadding
    }
}
