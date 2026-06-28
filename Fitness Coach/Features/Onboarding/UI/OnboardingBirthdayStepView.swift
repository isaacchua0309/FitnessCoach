//
//  OnboardingBirthdayStepView.swift
//  Fitness Coach
//
//  Forma — birthday wheel and biological sex capture for calorie targets.
//

import SwiftUI

struct OnboardingBirthdayStepView: View {
    @Binding var formState: OnboardingFormState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var headerVisible = false
    @State private var pickerVisible = false
    @State private var agePreviewVisible = false
    @State private var sexVisible = false
    @State private var trustVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.Birthday.self

    private var agePreviewState: OnboardingBirthdayAgePreviewState {
        OnboardingBirthdayAgePreviewBuilder.build(from: formState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.birthdaySectionSpacing) {
            headerSection
            birthdaySection
            agePreviewSection
            sexSection
            trustSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            OnboardingBirthdayAgePreviewBuilder.voiceOverSummary(from: formState)
        )
        .onAppear {
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &formState)
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
        .onChange(of: formState.birthDate) { _, _ in
            formState.syncAgeTextFromBirthDate()
        }
    }

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .birthday)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
            .accessibilityElement(children: .contain)
    }

    private var birthdaySection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(copy.birthdayLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .textCase(.uppercase)

            OnboardingBirthdayWheelPicker(birthDate: $formState.birthDate)
        }
        .opacity(pickerVisible ? 1 : 0)
        .offset(y: pickerVisible ? 0 : 8)
        .accessibilityElement(children: .contain)
    }

    private var agePreviewSection: some View {
        OnboardingBirthdayAgePreviewCard(state: agePreviewState)
            .opacity(agePreviewVisible ? 1 : 0)
            .offset(y: agePreviewVisible ? 0 : 8)
    }

    private var sexSection: some View {
        OnboardingBiologicalSexSelector(selection: $formState.sex)
            .opacity(sexVisible ? 1 : 0)
            .offset(y: sexVisible ? 0 : 8)
    }

    private var trustSection: some View {
        OnboardingBirthdayTrustNote(copy: copy.trustNote)
            .opacity(trustVisible ? 1 : 0)
            .offset(y: trustVisible ? 0 : 8)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            pickerVisible = true
            agePreviewVisible = true
            sexVisible = true
            trustVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.10)) {
            pickerVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.24)) {
            agePreviewVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.38)) {
            sexVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.52)) {
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
#Preview("Birthday — iPhone SE") {
    OnboardingBirthdayStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
            state.sex = .female
            return state
        }())
    )
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Birthday — Complete") {
    OnboardingBirthdayStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
            state.sex = .female
            return state
        }())
    )
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Birthday — Incomplete") {
    OnboardingBirthdayStepView(formState: .constant(OnboardingFormState()))
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
#endif
