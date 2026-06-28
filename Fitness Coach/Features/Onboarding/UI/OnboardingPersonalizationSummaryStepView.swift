//
//  OnboardingPersonalizationSummaryStepView.swift
//  Fitness Coach
//
//  Forma — Plan blueprint milestone before generation.
//

import SwiftUI

struct OnboardingPersonalizationSummaryStepView: View {
    let formState: OnboardingFormState
    let validationMessage: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var headerVisible = false
    @State private var goalVisible = false
    @State private var mirrorVisible = false
    @State private var insightVisible = false
    @State private var anticipationVisible = false
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
        VStack(spacing: 0) {
            headerSection
                .padding(.bottom, FormaTokens.Spacing.md)

            if showsValidationBanner {
                OnboardingWarningBanner(message: bannerMessage)
                    .opacity(headerVisible ? 1 : 0)
                    .padding(.bottom, FormaTokens.Spacing.sm)
            }

            Spacer(minLength: FormaTokens.Spacing.xs)

            goalSection
                .padding(.bottom, FormaTokens.Spacing.lg)

            mirrorSection
                .padding(.bottom, FormaTokens.Spacing.md)

            insightSection
                .padding(.bottom, FormaTokens.Spacing.md)

            Spacer(minLength: FormaTokens.Spacing.sm)

            anticipationSection
                .padding(.bottom, FormaTokens.Spacing.sm)

            detailsSection

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

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .review)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
    }

    private var goalSection: some View {
        OnboardingPlanBlueprintGoalCard(
            badge: displayState.goalBadge,
            heroMetric: displayState.goalHero,
            subtitle: displayState.goalSubtitle
        )
        .opacity(goalVisible ? 1 : 0)
        .offset(y: goalVisible ? 0 : 8)
        .scaleEffect(goalVisible ? 1 : 0.96)
    }

    @ViewBuilder
    private var mirrorSection: some View {
        if !displayState.profileSignals.isEmpty {
            OnboardingPlanBlueprintProfileMirrorCard(
                title: displayState.profileMirrorTitle,
                signals: displayState.profileSignals
            )
            .opacity(mirrorVisible ? 1 : 0)
            .offset(y: mirrorVisible ? 0 : 8)
        }
    }

    private var insightSection: some View {
        OnboardingPlanBlueprintCoachInsightCard(
            title: displayState.coachInsightTitle,
            bodyCopy: displayState.coachInsightBody
        )
        .opacity(insightVisible ? 1 : 0)
        .offset(y: insightVisible ? 0 : 6)
    }

    private var anticipationSection: some View {
        OnboardingPlanBlueprintAnticipationSection(
            title: FormaProductCopy.Onboarding.Flow.Summary.Anticipation.sectionTitle,
            bullets: displayState.anticipationBullets,
            accessibilityLabel: FormaProductCopy.Onboarding.Flow.Summary.Anticipation.accessibilityLabel
        )
        .opacity(anticipationVisible ? 1 : 0)
        .offset(y: anticipationVisible ? 0 : 6)
    }

    private var detailsSection: some View {
        OnboardingPlanBlueprintDetailsCard(
            rows: displayState.detailRows,
            isExpanded: $isDetailsExpanded
        )
        .opacity(detailsVisible ? 1 : 0)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            goalVisible = true
            mirrorVisible = true
            insightVisible = true
            anticipationVisible = true
            detailsVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.30).delay(0.06)) {
            goalVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.14)) {
            mirrorVisible = true
        }
        withAnimation(.easeOut(duration: 0.22).delay(0.22)) {
            insightVisible = true
        }
        withAnimation(.easeOut(duration: 0.20).delay(0.30)) {
            anticipationVisible = true
        }
        withAnimation(.easeOut(duration: 0.18).delay(0.38)) {
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
