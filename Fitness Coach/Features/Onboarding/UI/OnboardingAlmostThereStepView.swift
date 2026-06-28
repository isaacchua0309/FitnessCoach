//
//  OnboardingAlmostThereStepView.swift
//  Fitness Coach
//
//  Forma — Coach-waiting milestone before forma proof.
//

import SwiftUI

struct OnboardingAlmostThereStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var chromeVisible = false
    @State private var heroVisible = false
    @State private var copyVisible = false
    @State private var reelVisible = false
    @State private var footerVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.AlmostThere.self

    var body: some View {
        VStack(spacing: 0) {
            progressChrome
                .padding(.bottom, FormaTokens.Spacing.md)

            Spacer(minLength: FormaTokens.Spacing.xs)

            heroSection
                .padding(.bottom, FormaTokens.Spacing.lg)

            copySection
                .padding(.bottom, FormaTokens.Spacing.lg)

            Spacer(minLength: FormaTokens.Spacing.sm)

            benefitReelSection
                .padding(.bottom, FormaTokens.Spacing.md)

            footerSection

            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(OnboardingAlmostThereValues.accessibilitySummary)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
    }

    // MARK: - Sections

    private var progressChrome: some View {
        OnboardingStageProgressHeader(currentStep: .almostThere, showsTitles: false)
            .opacity(chromeVisible ? 1 : 0)
            .offset(y: chromeVisible ? 0 : 4)
    }

    private var heroSection: some View {
        OnboardingAlmostThereHeroView()
            .opacity(heroVisible ? 1 : 0)
            .scaleEffect(heroVisible ? 1 : 0.9)
    }

    private var copySection: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            Text(copy.headline)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(copy.supporting)
                .font(.title3.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(copyVisible ? 1 : 0)
        .offset(y: copyVisible ? 0 : 8)
    }

    private var benefitReelSection: some View {
        OnboardingAlmostThereBenefitReel(
            benefits: OnboardingAlmostThereValues.benefits,
            accessibilityLabel: OnboardingAlmostThereValues.benefitsAccessibilityLabel
        )
        .opacity(reelVisible ? 1 : 0)
        .offset(y: reelVisible ? 0 : 10)
    }

    private var footerSection: some View {
        Text(copy.trustFooter)
            .font(.footnote.weight(.medium))
            .foregroundStyle(OnboardingTheme.tertiaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(copy.trustFooter)
            .opacity(footerVisible ? 1 : 0)
    }

    // MARK: - Motion

    private func runEntranceAnimation() {
        if reduceMotion {
            chromeVisible = true
            heroVisible = true
            copyVisible = true
            reelVisible = true
            footerVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.24)) {
            chromeVisible = true
        }
        withAnimation(.easeOut(duration: 0.34).delay(0.05)) {
            heroVisible = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.14)) {
            copyVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.24)) {
            reelVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.34)) {
            footerVisible = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
#Preview("Almost There") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Almost There — Small iPhone") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Almost There — Large Dynamic Type") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .dynamicTypeSize(.accessibility2)
}

#Preview("Almost There — Dark Mode") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .preferredColorScheme(.dark)
}
#endif
