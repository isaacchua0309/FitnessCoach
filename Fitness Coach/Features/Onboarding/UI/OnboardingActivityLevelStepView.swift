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
    @State private var helperVisible = false
    @State private var cardsVisible: [Bool] = Array(repeating: false, count: ActivityLevel.allCases.count)
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.Activity.self
    private let levels = OnboardingActivityLevelValues.orderedLevels

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            headerSection

            if !formState.hasConfirmedActivityLevelSelection {
                preSelectionHelper
            }

            cardsSection
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

    private var preSelectionHelper: some View {
        Text(copy.explanationPlaceholder)
            .font(FormaTokens.Typography.body)
            .foregroundStyle(OnboardingTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(helperVisible ? 1 : 0)
            .offset(y: helperVisible ? 0 : 4)
            .accessibilityAddTraits(.isStaticText)
    }

    private var cardsSection: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(Array(levels.enumerated()), id: \.element) { index, level in
                OnboardingActivityLevelCard(
                    level: level,
                    isSelected: isLevelSelected(level),
                    selectedExplanation: selectedExplanation(for: level)
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

    private func isLevelSelected(_ level: ActivityLevel) -> Bool {
        formState.hasConfirmedActivityLevelSelection && formState.activityLevel == level
    }

    private func selectedExplanation(for level: ActivityLevel) -> String? {
        guard isLevelSelected(level) else { return nil }
        return OnboardingActivityLevelExplanationBuilder.selectedExplanation(for: level)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            helperVisible = true
            cardsVisible = Array(repeating: true, count: levels.count)
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }

        withAnimation(.easeOut(duration: 0.22).delay(0.08)) {
            helperVisible = true
        }

        for index in levels.indices {
            withAnimation(.easeOut(duration: 0.24).delay(0.10 + Double(index) * 0.06)) {
                cardsVisible[index] = true
            }
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
private enum OnboardingActivityLevelStepPreviewSupport {
    static func formState(selected level: ActivityLevel?) -> OnboardingFormState {
        var state = OnboardingFormState()
        if let level {
            OnboardingActivityLevelValues.select(level, in: &state)
        }
        return state
    }
}

#Preview("Activity Level — Unselected") {
    OnboardingActivityLevelStepView(
        formState: .constant(OnboardingActivityLevelStepPreviewSupport.formState(selected: nil))
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Activity Level — Sedentary") {
    OnboardingActivityLevelStepView(
        formState: .constant(OnboardingActivityLevelStepPreviewSupport.formState(selected: .sedentary))
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Activity Level — Moderately Active") {
    OnboardingActivityLevelStepView(
        formState: .constant(
            OnboardingActivityLevelStepPreviewSupport.formState(selected: .moderatelyActive)
        )
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Activity Level — Extra Active") {
    OnboardingActivityLevelStepView(
        formState: .constant(OnboardingActivityLevelStepPreviewSupport.formState(selected: .athlete))
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
