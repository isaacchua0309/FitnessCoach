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
    @State private var valueVisible = false
    @State private var trustVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.AlmostThere.self

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            headerSection
            heroSection
            summarySection
            valueSection
            trustSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
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

    private var summarySection: some View {
        OnboardingAlmostThereSummaryCard(
            headline: copy.summaryHeadline,
            supportingCopy: copy.summarySupporting
        )
        .opacity(summaryVisible ? 1 : 0)
        .offset(y: summaryVisible ? 0 : 6)
    }

    private var valueSection: some View {
        OnboardingAlmostThereValueSection(
            title: copy.valueSectionTitle,
            rows: OnboardingAlmostThereValues.valueRows,
            accessibilityLabel: OnboardingAlmostThereValues.valueSectionAccessibilityLabel
        )
        .opacity(valueVisible ? 1 : 0)
        .offset(y: valueVisible ? 0 : 6)
    }

    private var trustSection: some View {
        OnboardingAlmostThereTrustStrip(copy: copy.trustStrip, style: .compact)
            .opacity(trustVisible ? 1 : 0)
            .offset(y: trustVisible ? 0 : 6)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            heroVisible = true
            summaryVisible = true
            valueVisible = true
            trustVisible = true
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
            valueVisible = true
        }
        withAnimation(.easeOut(duration: 0.22).delay(0.24)) {
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
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Almost There — Small iPhone") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
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
