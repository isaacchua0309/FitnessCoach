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

    @State private var heroVisible = false
    @State private var summaryVisible = false
    @State private var privacyVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self

    private var sectionSpacing: CGFloat {
        OnboardingStepLayoutMetrics.appleHealthSectionSpacing(profile: layoutProfile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            heroSection
            summarySection
            statusSection
            privacySection
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

    private var heroSection: some View {
        OnboardingAppleHealthHeroIcon(style: screenState.heroStyle)
            .opacity(heroVisible ? 1 : 0)
            .scaleEffect(heroVisible ? 1 : 0.94)
    }

    private var summarySection: some View {
        OnboardingAppleHealthPermissionSummaryCard(
            title: copy.summaryCardTitle,
            rows: copy.readableDataRows
        )
        .opacity(summaryVisible ? 1 : 0)
        .offset(y: summaryVisible ? 0 : 6)
    }

    @ViewBuilder
    private var statusSection: some View {
        if let statusMessage = screenState.statusMessage {
            Text(statusMessage)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(
                    screenState.presentation == .connected
                        ? OnboardingTheme.accent
                        : OnboardingTheme.secondaryText
                )
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(statusMessage)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var privacySection: some View {
        OnboardingAppleHealthPrivacyCard(
            title: copy.privacyTitle,
            bodyCopy: copy.privacyBody
        )
        .opacity(privacyVisible ? 1 : 0)
        .offset(y: privacyVisible ? 0 : 6)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            heroVisible = true
            summaryVisible = true
            privacyVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.24)) {
            heroVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.06)) {
            summaryVisible = true
        }
        withAnimation(.easeOut(duration: 0.22).delay(0.12)) {
            privacyVisible = true
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
            deviceState: presentation == .unavailable ? .unavailable : .notConnected
        )
    }
}

private struct OnboardingAppleHealthPreviewShell: View {
    let screenState: OnboardingAppleHealthScreenState

    var body: some View {
        OnboardingStepContainer(
            currentStep: .appleHealth,
            viewState: .editing,
            validationMessage: nil,
            fieldNavigator: OnboardingFieldNavigator(),
            bottomBar: {
                OnboardingBottomBar(
                    currentStep: .appleHealth,
                    isLoading: false,
                    canContinue: true,
                    appleHealthPrimaryTitle: screenState.primaryTitle,
                    appleHealthSecondaryTitle: screenState.secondaryTitle,
                    isAppleHealthPrimaryEnabled: screenState.isPrimaryEnabled,
                    isAppleHealthSkipEnabled: screenState.isSkipEnabled,
                    onAppleHealthSkip: {},
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

#Preview("Apple Health — Ready") {
    OnboardingAppleHealthPreviewShell(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .ready)
    )
    .formaThemePreview()
}

#Preview("Apple Health — Requesting") {
    OnboardingAppleHealthPreviewShell(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .requesting)
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

#Preview("Apple Health — Failed") {
    OnboardingAppleHealthPreviewShell(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(
            for: .failed(message: "HealthKit unavailable")
        )
    )
    .formaThemePreview()
}
#endif
