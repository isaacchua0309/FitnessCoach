//
//  OnboardingActivityLevelStepView.swift
//  Fitness Coach
//
//  Forma — premium activity level selection for calorie targets.
//

import SwiftUI

struct OnboardingActivityLevelStepView: View {
    @Binding var formState: OnboardingFormState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var headerVisible = false
    @State private var cardsVisible: [Bool] = Array(repeating: false, count: ActivityLevel.allCases.count)
    @State private var explanationVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.Activity.self
    private let levels = OnboardingActivityLevelValues.orderedLevels

    private var explanationState: OnboardingActivityLevelExplanationState {
        OnboardingActivityLevelExplanationBuilder.build(from: formState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            headerSection
            cardsSection
            Spacer(minLength: FormaTokens.Spacing.sm)
            explanationSection
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: formState.activityLevel)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: formState.hasConfirmedActivityLevelSelection)
        .onAppear {
            OnboardingActivityLevelValues.applyDefaultsIfNeeded(to: &formState)
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
    }

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .activityLevel)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
            .accessibilityElement(children: .contain)
    }

    private var cardsSection: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(Array(levels.enumerated()), id: \.element) { index, level in
                OnboardingActivityLevelCard(
                    level: level,
                    isSelected: isLevelSelected(level)
                ) {
                    OnboardingActivityLevelValues.select(level, in: &formState)
                    OnboardingHaptics.selectionChanged()
                }
                .opacity(cardsVisible[index] ? 1 : 0)
                .offset(y: cardsVisible[index] ? 0 : 8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(copy.optionsAccessibilityLabel)
    }

    private var explanationSection: some View {
        OnboardingActivityLevelExplanationCard(state: explanationState)
            .opacity(explanationVisible ? 1 : 0)
            .offset(y: explanationVisible ? 0 : 8)
    }

    private func isLevelSelected(_ level: ActivityLevel) -> Bool {
        formState.hasConfirmedActivityLevelSelection && formState.activityLevel == level
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            cardsVisible = Array(repeating: true, count: levels.count)
            explanationVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }

        for index in levels.indices {
            withAnimation(.easeOut(duration: 0.24).delay(0.10 + Double(index) * 0.06)) {
                cardsVisible[index] = true
            }
        }

        let explanationDelay = 0.10 + Double(levels.count) * 0.06 + 0.12
        withAnimation(.easeOut(duration: 0.26).delay(explanationDelay)) {
            explanationVisible = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
#Preview("Activity Level") {
    OnboardingActivityLevelStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
            return state
        }())
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Activity Level — Unselected") {
    OnboardingActivityLevelStepView(formState: .constant(OnboardingFormState()))
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
