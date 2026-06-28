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
    @State private var insightVisible = false
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
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            headerSection
            titleSection

            if showsValidationBanner {
                OnboardingWarningBanner(message: bannerMessage)
                    .opacity(headerVisible ? 1 : 0)
            }

            goalSection
            basisSection
            insightSection
            detailsSection
            Spacer(minLength: 0)
        }
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

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.progressTitleSpacing) {
            Text(displayState.screenTitle)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(displayState.screenSubtitle)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 4)
    }

    private var goalSection: some View {
        OnboardingPlanBlueprintGoalCard(
            sectionTitle: displayState.goalSectionTitle,
            heroMetric: displayState.goalHero,
            subtitle: displayState.goalSubtitle
        )
        .opacity(goalVisible ? 1 : 0)
        .offset(y: goalVisible ? 0 : 8)
        .scaleEffect(goalVisible ? 1 : 0.97)
    }

    private var basisSection: some View {
        OnboardingPlanBlueprintBasisCard(
            title: displayState.basisTitle,
            items: displayState.basisItems
        )
        .opacity(basisVisible ? 1 : 0)
        .offset(y: basisVisible ? 0 : 8)
    }

    private var insightSection: some View {
        OnboardingPlanBlueprintInsightCard(copy: displayState.insight)
            .opacity(insightVisible ? 1 : 0)
            .offset(y: insightVisible ? 0 : 6)
    }

    private var detailsSection: some View {
        OnboardingPlanBlueprintDetailsCard(
            rows: displayState.detailRows,
            isExpanded: $isDetailsExpanded
        )
        .opacity(detailsVisible ? 1 : 0)
        .offset(y: detailsVisible ? 0 : 8)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            goalVisible = true
            basisVisible = true
            insightVisible = true
            detailsVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.10)) {
            goalVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.24)) {
            basisVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.38)) {
            insightVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.52)) {
            detailsVisible = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

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
    .padding(.horizontal, OnboardingTheme.pagePadding)
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
    .padding(.horizontal, OnboardingTheme.pagePadding)
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
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Imperial") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingPreviewData.formState
            state.unitSystem = .imperial
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
            return state
        }(),
        validationMessage: nil
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Fallback") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingFormState(),
        validationMessage: nil
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
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
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
