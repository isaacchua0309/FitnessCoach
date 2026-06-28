//
//  OnboardingAlmostThereStepView.swift
//  Fitness Coach
//
//  Forma — plan-almost-ready milestone before forma proof.
//

import SwiftUI

struct OnboardingAlmostThereStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var headerVisible = false
    @State private var heroVisible = false
    @State private var summaryVisible = false
    @State private var featuresVisible: [Bool]
    @State private var trustVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.AlmostThere.self
    private let features = OnboardingAlmostThereValues.features

    init() {
        _featuresVisible = State(
            initialValue: Array(
                repeating: false,
                count: FormaProductCopy.Onboarding.Flow.AlmostThereFeatures.bullets.count
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            headerSection
            heroSection
            titleSection
            summarySection
            featuresSection
            trustSection
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(OnboardingAlmostThereValues.accessibilitySummary)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
    }

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .almostThere)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
    }

    private var heroSection: some View {
        OnboardingAlmostThereHeroView()
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

    private var summarySection: some View {
        OnboardingAlmostThereSummaryCard(
            headline: copy.summaryHeadline,
            supportingCopy: copy.summarySupporting
        )
        .opacity(summaryVisible ? 1 : 0)
        .offset(y: summaryVisible ? 0 : 8)
    }

    private var featuresSection: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                OnboardingAppleHealthBenefitCard(
                    icon: feature.icon,
                    title: feature.title,
                    subtitle: feature.subtitle
                )
                .opacity(featuresVisible[index] ? 1 : 0)
                .offset(y: featuresVisible[index] ? 0 : 8)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var trustSection: some View {
        OnboardingAlmostThereTrustStrip(copy: copy.trustStrip)
            .opacity(trustVisible ? 1 : 0)
            .offset(y: trustVisible ? 0 : 8)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            heroVisible = true
            summaryVisible = true
            featuresVisible = Array(repeating: true, count: features.count)
            trustVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.08)) {
            heroVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.20)) {
            summaryVisible = true
        }
        for index in features.indices {
            withAnimation(.easeOut(duration: 0.24).delay(0.32 + Double(index) * 0.07)) {
                featuresVisible[index] = true
            }
        }
        let trustDelay = 0.32 + Double(features.count) * 0.07 + 0.10
        withAnimation(.easeOut(duration: 0.26).delay(trustDelay)) {
            trustVisible = true
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
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
