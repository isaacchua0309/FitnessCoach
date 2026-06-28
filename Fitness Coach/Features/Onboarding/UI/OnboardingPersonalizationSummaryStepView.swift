//
//  OnboardingPersonalizationSummaryStepView.swift
//  Fitness Coach
//
//  Forma — Plan blueprint review before generation.
//

import SwiftUI

struct OnboardingPersonalizationSummaryStepView: View {
    let formState: OnboardingFormState
    let validationMessage: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var headerVisible = false
    @State private var goalVisible = false
    @State private var basisVisible = false
    @State private var trustVisible = false
    @State private var detailsVisible = false
    @State private var isDetailsExpanded = false
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
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            headerSection

            if showsValidationBanner {
                OnboardingWarningBanner(message: bannerMessage)
                    .opacity(headerVisible ? 1 : 0)
            }

            goalSection
            basisSection
            trustSection
            detailsSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(displayState.accessibilityLabel)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
    }

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .review)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
    }

    private var goalSection: some View {
        OnboardingPlanBlueprintGoalCard(
            heroMetric: displayState.goalHero,
            subtitle: displayState.goalSubtitle
        )
        .opacity(goalVisible ? 1 : 0)
        .offset(y: goalVisible ? 0 : 6)
        .scaleEffect(goalVisible ? 1 : 0.98)
    }

    private var basisSection: some View {
        OnboardingPlanBlueprintBasisCard(
            title: displayState.basisTitle,
            items: displayState.basisItems
        )
        .opacity(basisVisible ? 1 : 0)
        .offset(y: basisVisible ? 0 : 6)
    }

    private var trustSection: some View {
        OnboardingPlanBlueprintTrustLine(copy: displayState.insight)
            .opacity(trustVisible ? 1 : 0)
            .offset(y: trustVisible ? 0 : 4)
    }

    private var detailsSection: some View {
        OnboardingPlanBlueprintDetailsCard(
            rows: displayState.detailRows,
            isExpanded: $isDetailsExpanded
        )
        .opacity(detailsVisible ? 1 : 0)
        .offset(y: detailsVisible ? 0 : 6)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            goalVisible = true
            basisVisible = true
            trustVisible = true
            detailsVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.06)) {
            goalVisible = true
        }
        withAnimation(.easeOut(duration: 0.22).delay(0.12)) {
            basisVisible = true
        }
        withAnimation(.easeOut(duration: 0.20).delay(0.18)) {
            trustVisible = true
        }
        withAnimation(.easeOut(duration: 0.20).delay(0.24)) {
            detailsVisible = true
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
            OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
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

#Preview("Collapsed details") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
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
