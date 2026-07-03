//
//  OnboardingStepContainer.swift
//  Fitness Coach
//
//  FitPilot AI — Shared shell for onboarding steps.
//

import SwiftUI

struct OnboardingStepContainer<Content: View, BottomBar: View>: View {
    let currentStep: OnboardingStep
    let viewState: OnboardingViewState
    let validationMessage: String?
    var keyboardHeight: CGFloat = 0
    @ObservedObject var fieldNavigator: OnboardingFieldNavigator
    @ViewBuilder let bottomBar: () -> BottomBar
    @ViewBuilder let content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesFullScreenShell: Bool {
        currentStep.usesFullScreenChrome
    }

    private var usesUnifiedLayoutShell: Bool {
        currentStep.usesUnifiedLayoutShell
    }

    private var usesFixedViewportShell: Bool {
        currentStep.usesFixedViewportShell
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
            } else if usesUnifiedLayoutShell {
                unifiedLayoutShell
            } else if usesFixedViewportShell {
                fixedViewportShell
            } else {
                scrollableShell
            }
        }
        .background(OnboardingTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar()
        }
        .onChange(of: currentStep) { _, _ in
            fieldNavigator.clearFocus()
            OnboardingKeyboard.dismiss()
        }
    }

    // MARK: - Unified layout (intro proof, Apple Health)

    private var unifiedLayoutShell: some View {
        GeometryReader { geometry in
            let profile = OnboardingStepLayoutProfile.resolve(
                viewportHeight: geometry.size.height,
                dynamicTypeSize: dynamicTypeSize
            )
            let showsSubtitle = !currentStep.subtitle.isEmpty
            let contentHeight = OnboardingStepLayoutMetrics.contentAreaHeight(
                viewportHeight: geometry.size.height,
                step: currentStep,
                profile: profile,
                showsSubtitle: showsSubtitle,
                dynamicTypeSize: dynamicTypeSize
            )
            let scrollable = profile.allowsScrollableContent(
                step: currentStep,
                dynamicTypeSize: dynamicTypeSize
            )

            Group {
                if scrollable {
                    ScrollView {
                        unifiedChromeColumn(
                            profile: profile,
                            showsSubtitle: showsSubtitle,
                            contentHeight: contentHeight,
                            expandsContent: false
                        )
                        .padding(.bottom, FormaTokens.Spacing.sm)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    unifiedChromeColumn(
                        profile: profile,
                        showsSubtitle: showsSubtitle,
                        contentHeight: contentHeight,
                        expandsContent: true
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func unifiedChromeColumn(
        profile: OnboardingStepLayoutProfile,
        showsSubtitle: Bool,
        contentHeight: CGFloat,
        expandsContent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingStageProgressHeader(
                currentStep: currentStep,
                showsSubtitle: showsSubtitle
            )
            .padding(.top, profile.progressTopPadding)

            if showsContainerValidationBanner {
                OnboardingWarningBanner(message: validationMessage ?? "")
                    .padding(.top, profile.sectionSpacing)
            }

            Group {
                if expandsContent {
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    content()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(.top, profile.chromeBottomSpacing)

            if showsLoadingOverlay, let message = viewState.loadingOverlayMessage {
                OnboardingLoadingView(message: message)
                    .padding(.top, profile.sectionSpacing)
            }
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .frame(maxWidth: FormaTokens.Layout.maxContentWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.onboardingStepContentHeight, contentHeight)
        .environment(\.onboardingStepLayoutProfile, profile)
    }

    // MARK: - Legacy shells

    private var fullScreenShell: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, OnboardingTheme.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 16)
    }

    private var fixedViewportShell: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsContainerValidationBanner {
                OnboardingWarningBanner(message: validationMessage ?? "")
                    .padding(.horizontal, OnboardingTheme.pagePadding)
                    .padding(.top, OnboardingLayout.progressHeaderTop)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showsLoadingOverlay, let message = viewState.loadingOverlayMessage {
                OnboardingLoadingView(message: message)
                    .padding(.horizontal, OnboardingTheme.pagePadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

                    content()

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
