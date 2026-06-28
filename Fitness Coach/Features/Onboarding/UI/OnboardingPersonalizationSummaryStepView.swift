//
//  OnboardingPersonalizationSummaryStepView.swift
//  Fitness Coach
//
//  Forma — Plan-learned milestone before generation.
//

import SwiftUI

struct OnboardingPersonalizationSummaryStepView: View {
    let formState: OnboardingFormState
    let validationMessage: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var chromeVisible = false
    @State private var headlineVisible = false
    @State private var supportingVisible = false
    @State private var summaryVisible = false
    @State private var pillarsVisible = false
    @State private var didPlayAppearHaptic = false

    private var displayState: OnboardingPlanBlueprintState {
        OnboardingPlanBlueprintBuilder.build(from: formState)
    }

    private var showsValidationBanner: Bool {
        validationMessage != nil
            || !OnboardingPersonalizationSummaryBuilder.isReadyToGenerate(for: formState)
    }

    private var bannerMessage: String {
        validationMessage
            ?? OnboardingPersonalizationSummaryBuilder.validationMessage(for: formState)
            ?? FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
    }

    var body: some View {
        VStack(spacing: 0) {
            progressChrome
                .padding(.bottom, FormaTokens.Spacing.md)

            if showsValidationBanner {
                OnboardingWarningBanner(message: bannerMessage)
                    .opacity(chromeVisible ? 1 : 0)
                    .padding(.bottom, FormaTokens.Spacing.sm)
            }

            Spacer(minLength: FormaTokens.Spacing.xs)

            headlineSection
                .padding(.bottom, FormaTokens.Spacing.md)

            supportingSection
                .padding(.bottom, FormaTokens.Spacing.lg)

            summarySection
                .padding(.bottom, FormaTokens.Spacing.lg)

            Spacer(minLength: FormaTokens.Spacing.sm)

            pillarsSection

            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(displayState.accessibilityLabel)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
    }

    private var progressChrome: some View {
        OnboardingStageProgressHeader(currentStep: .review, showsTitles: false)
            .opacity(chromeVisible ? 1 : 0)
            .offset(y: chromeVisible ? 0 : 4)
    }

    private var headlineSection: some View {
        Text(displayState.headline)
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .foregroundStyle(OnboardingTheme.primaryText)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.72)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .opacity(headlineVisible ? 1 : 0)
            .offset(y: headlineVisible ? 0 : 8)
            .accessibilityAddTraits(.isHeader)
    }

    private var supportingSection: some View {
        Text(displayState.supportingParagraph)
            .font(.title3.weight(.medium))
            .foregroundStyle(OnboardingTheme.secondaryText)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.85)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .opacity(supportingVisible ? 1 : 0)
            .offset(y: supportingVisible ? 0 : 8)
    }

    private var summarySection: some View {
        OnboardingPlanBlueprintPersonalizationSummaryCard(
            summary: displayState.personalizationSummary
        )
        .opacity(summaryVisible ? 1 : 0)
        .offset(y: summaryVisible ? 0 : 8)
        .scaleEffect(summaryVisible ? 1 : 0.97)
    }

    private var pillarsSection: some View {
        OnboardingPlanBlueprintPillarsSection(
            pillars: displayState.pillars,
            accessibilityLabel: FormaProductCopy.Onboarding.Flow.Summary.Pillars.accessibilityLabel
        )
        .opacity(pillarsVisible ? 1 : 0)
        .offset(y: pillarsVisible ? 0 : 10)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            chromeVisible = true
            headlineVisible = true
            supportingVisible = true
            summaryVisible = true
            pillarsVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            chromeVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.06)) {
            headlineVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.14)) {
            supportingVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.24)) {
            summaryVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.36)) {
            pillarsVisible = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
#Preview("Loss goal") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingPreviewData.formState
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &state)
            return state
        }(),
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Gain goal") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingPreviewData.formState
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(4, in: &state)
            return state
        }(),
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Maintain goal") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingPreviewData.formState
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
            state.goalWeightKgText = state.currentWeightKgText
            return state
        }(),
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Small iPhone") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Large Dynamic Type") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility2)
}

#Preview("Fallback") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingFormState(),
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Incomplete") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingFormState()
            state.ageText = ""
            return state
        }(),
        validationMessage: FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
