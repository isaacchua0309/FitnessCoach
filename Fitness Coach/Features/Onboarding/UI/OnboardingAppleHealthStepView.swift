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
    @State private var benefitsVisible: [Bool]
    @State private var privacyVisible = false
    @State private var optionalVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self

    init(screenState: OnboardingAppleHealthScreenState) {
        self.screenState = screenState
        _benefitsVisible = State(
            initialValue: Array(repeating: false, count: FormaProductCopy.Onboarding.Flow.AppleHealth.benefits.count)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            headerSection
            heroSection
            titleSection
            benefitsSection
            statusSection
            privacySection
            optionalSection
            Spacer(minLength: 0)
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

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.progressTitleSpacing) {
            Text(copy.title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(copy.subtitle)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 4)
    }

    private var benefitsSection: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(Array(copy.benefits.enumerated()), id: \.offset) { index, benefit in
                OnboardingAppleHealthBenefitCard(
                    icon: benefit.icon,
                    title: benefit.title,
                    subtitle: benefit.subtitle
                )
                .opacity(benefitsVisible[index] ? 1 : 0)
                .offset(y: benefitsVisible[index] ? 0 : 8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(copy.benefitsAccessibilityLabel)
    }

    @ViewBuilder
    private var statusSection: some View {
        if let statusMessage = screenState.statusMessage {
            Text(statusMessage)
                .font(FormaTokens.Typography.body.weight(.medium))
                .foregroundStyle(
                    screenState.presentation == .connected
                        ? OnboardingTheme.accent
                        : OnboardingTheme.secondaryText
                )
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, FormaTokens.Spacing.xs)
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
        .offset(y: privacyVisible ? 0 : 8)
    }

    private var optionalSection: some View {
        Text(copy.optionalNote)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(OnboardingTheme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(optionalVisible ? 1 : 0)
            .accessibilityLabel(copy.optionalNote)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            heroVisible = true
            benefitsVisible = Array(repeating: true, count: copy.benefits.count)
            privacyVisible = true
            optionalVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.08)) {
            heroVisible = true
        }
        for index in copy.benefits.indices {
            withAnimation(.easeOut(duration: 0.24).delay(0.18 + Double(index) * 0.07)) {
                benefitsVisible[index] = true
            }
        }
        let privacyDelay = 0.18 + Double(copy.benefits.count) * 0.07 + 0.10
        withAnimation(.easeOut(duration: 0.26).delay(privacyDelay)) {
            privacyVisible = true
        }
        withAnimation(.easeOut(duration: 0.22).delay(privacyDelay + 0.10)) {
            optionalVisible = true
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
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Requesting") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .requesting)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Connected") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .connected)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Denied") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .denied)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Unavailable") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(for: .unavailable)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Apple Health — Failed") {
    OnboardingAppleHealthStepView(
        screenState: OnboardingAppleHealthPreviewFactory.screenState(
            for: .failed(message: "HealthKit unavailable")
        )
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
