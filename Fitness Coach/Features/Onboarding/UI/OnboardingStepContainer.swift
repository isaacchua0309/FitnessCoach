//
//  OnboardingStepContainer.swift
//  Fitness Coach
//
//  FitPilot AI — Shared scrollable shell for onboarding steps.
//

import SwiftUI

struct OnboardingStepContainer<Content: View>: View {
    let currentStep: OnboardingStep
    var currentV3Step: OnboardingV3Step?
    var currentV4Step: OnboardingV4Step?
    let usesStageProgress: Bool
    let viewState: OnboardingViewState
    let validationMessage: String?
    var keyboardHeight: CGFloat = 0
    @ObservedObject var fieldNavigator: OnboardingFieldNavigator
    @ViewBuilder let content: Content

    private var usesFullScreenShell: Bool {
        if let currentV4Step {
            return currentV4Step.usesFullScreenChrome
        }
        if let currentV3Step {
            return currentV3Step.usesFullScreenChrome
        }
        return currentStep.usesFullScreenChrome
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
        if currentV4Step == .review || currentV4Step == .savePlan {
            return false
        }
        if currentV3Step == .review || currentV3Step == .savePlan {
            return false
        }
        switch currentStep {
        case .summary, .savePlan:
            return false
        default:
            return true
        }
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
        .onChange(of: currentV3Step) { _, _ in
            fieldNavigator.clearFocus()
            OnboardingKeyboard.dismiss()
        }
        .onChange(of: currentV4Step) { _, _ in
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
                .padding(.horizontal, contentHorizontalPadding)
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
        if showsProgressHeader {
            if let currentV4Step {
                OnboardingV4StageProgressHeader(currentStep: currentV4Step)
            } else if let currentV3Step {
                OnboardingV3StageProgressHeader(currentStep: currentV3Step)
            } else if usesStageProgress {
                OnboardingStageProgressHeader(currentStep: currentStep)
            } else {
                OnboardingProgressHeader(currentStep: currentStep)
            }
        }
    }

    private var showsProgressHeader: Bool {
        currentV4Step?.showsProgressHeader
            ?? currentV3Step?.showsProgressHeader
            ?? currentStep.showsProgressHeader
    }

    private var contentHorizontalPadding: CGFloat {
        currentStep == .landing ? 0 : OnboardingTheme.pagePadding
    }
}
