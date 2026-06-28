//
//  OnboardingAppleHealthStepView.swift
//  Fitness Coach
//
//  Forma — Apple Health permission and value screen for onboarding.
//

import SwiftUI

struct OnboardingAppleHealthStepView: View {
    let screenState: OnboardingAppleHealthScreenState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var headerVisible = false
    @State private var heroVisible = false
    @State private var summaryVisible = false
    @State private var privacyVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            headerSection
            heroSection
            summarySection
            statusSection
            privacySection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
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

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .appleHealth)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
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
            headerVisible = true
            heroVisible = true
            summaryVisible = true
            privacyVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.06)) {
            heroVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.12)) {
            summaryVisible = true
        }
        withAnimation(.easeOut(duration: 0.22).delay(0.18)) {
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

#Preview("Apple Health — Ready") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .ready)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Requesting") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .requesting)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Connected") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .connected)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Denied") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .denied)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Unavailable") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .unavailable)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Failed") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(
            for: .failed(message: "HealthKit unavailable")
        )
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Small iPhone") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .ready)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .previewDevice(PreviewDevice(rawValue: "iPhone 16e"))
}
#endif
