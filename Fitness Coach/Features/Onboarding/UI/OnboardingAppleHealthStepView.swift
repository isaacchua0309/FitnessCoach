//
//  OnboardingAppleHealthStepView.swift
//  Fitness Coach
//
//  Forma — Apple Health permission and value screen for onboarding.
//

import SwiftUI

struct OnboardingAppleHealthStepView: View {
    let screenState: OnboardingAppleHealthScreenState

    @Environment(\.onboardingStepLayoutProfile) private var layoutProfile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self

    private var sectionSpacing: CGFloat {
        OnboardingStepLayoutMetrics.appleHealthSectionSpacing(profile: layoutProfile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            if screenState.showsHeroIcon {
                OnboardingAppleHealthHeroIcon(style: screenState.heroStyle)
                    .opacity(contentVisible ? 1 : 0)
                    .scaleEffect(contentVisible ? 1 : 0.96)
            }

            if screenState.showsPermissionCard {
                OnboardingAppleHealthPermissionSummaryCard(
                    title: copy.summaryCardTitle,
                    items: copy.permissionItems
                )
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 4)
            }

            if let statusMessage = screenState.statusMessage {
                OnboardingAppleHealthStatusBanner(
                    message: statusMessage,
                    style: bannerStyle(for: screenState.presentation)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if screenState.showsPrivacyCard {
                OnboardingAppleHealthPrivacyCard(
                    title: copy.privacyTitle,
                    bodyCopy: copy.privacyBody
                )
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(screenState.accessibilitySummary)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: screenState.presentation)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
        .onChange(of: screenState.presentation) { _, newValue in
            if newValue == .connected {
                OnboardingHaptics.selectionChanged()
            }
        }
    }

    private func bannerStyle(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> OnboardingAppleHealthStatusBanner.Style {
        switch presentation {
        case .connected:
            return .success
        case .denied, .unavailable, .failed:
            return .warning
        case .notDetermined, .requesting:
            return .neutral
        }
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            contentVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            contentVisible = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
private enum OnboardingAppleHealthPreviewFactory {

    static func screenState(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> OnboardingAppleHealthScreenState {
        OnboardingAppleHealthPresentationBuilder.build(
            presentation: presentation,
            deviceState: deviceState(for: presentation)
        )
    }

    private static func deviceState(
        for presentation: OnboardingAppleHealthPresentationState
    ) -> TrainingIntegrationState {
        switch presentation {
        case .connected:
            return .connected
        case .denied:
            return .denied
        case .unavailable:
            return .unavailable
        case .requesting:
            return .requestingPermission
        case .failed(let message):
            return .failed(message: message)
        case .notDetermined:
            return .notConnected
        }
    }
}

private struct OnboardingAppleHealthPreviewShell: View {
    let screenState: OnboardingAppleHealthScreenState
    var isLoading: Bool = false

    var body: some View {
        OnboardingStepContainer(
            currentStep: .appleHealth,
            viewState: isLoading ? .connectingAppleHealth : .editing,
            validationMessage: nil,
            fieldNavigator: OnboardingFieldNavigator(),
            bottomBar: {
                OnboardingBottomBar(
                    currentStep: .appleHealth,
                    isLoading: isLoading,
                    canContinue: true,
                    appleHealthPrimaryTitle: screenState.primaryTitle,
                    appleHealthSecondaryTitle: screenState.showsSkipButton
                        ? screenState.skipTitle
                        : nil,
                    isAppleHealthPrimaryEnabled: screenState.isPrimaryEnabled,
                    isAppleHealthSkipEnabled: screenState.showsSkipButton,
                    onAppleHealthSkip: screenState.showsSkipButton ? {} : nil,
                    onBack: {},
                    onContinue: {},
                    onComplete: {}
                )
            }
        ) {
            OnboardingAppleHealthStepView(screenState: screenState)
        }
    }
}

#Preview("Apple Health — Not Determined") {
    OnboardingAppleHealthPreviewShell(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .notDetermined)
    )
    .formaThemePreview()
}

#Preview("Apple Health — Requesting") {
    OnboardingAppleHealthPreviewShell(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .requesting),
        isLoading: true
    )
    .formaThemePreview()
}

#Preview("Apple Health — Connected") {
    OnboardingAppleHealthPreviewShell(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .connected)
    )
    .formaThemePreview()
}

#Preview("Apple Health — Denied") {
    OnboardingAppleHealthPreviewShell(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .denied)
    )
    .formaThemePreview()
}

#Preview("Apple Health — Unavailable") {
    OnboardingAppleHealthPreviewShell(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .unavailable)
    )
    .formaThemePreview()
}
#endif
