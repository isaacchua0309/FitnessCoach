//
//  OnboardingTargetWeightStepView.swift
//  Fitness Coach
//
//  Forma — target weight step (absolute goal-weight ruler).
//

import SwiftUI

struct OnboardingTargetWeightStepView: View {
    @Binding var formState: OnboardingFormState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var headerVisible = false
    @State private var summaryVisible = false
    @State private var rulerVisible = false
    @State private var guidanceVisible = false
    @State private var isContentPrepared = false

    private var guidanceState: OnboardingTargetWeightGuidanceState? {
        OnboardingTargetWeightGuidanceBuilder.guidanceState(for: formState)
    }

    var body: some View {
        GeometryReader { geometry in
            let layoutProfile = OnboardingVisionLayoutProfile.resolve(
                verticalSizeClass: verticalSizeClass,
                contentHeight: geometry.size.height
            )
            let isCompact = layoutProfile == .compact

            VStack(alignment: .leading, spacing: sectionSpacing(isCompact: isCompact)) {
                headerSection

                if isContentPrepared, formState.parsedCurrentWeightKg != nil {
                    heroSummarySection(isCompact: isCompact)

                    if rulerVisible {
                        targetWeightRuler(isCompact: isCompact)
                    }

                    guidanceSection(isCompact: isCompact)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .onAppear {
            OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
            isContentPrepared = true
            runEntranceAnimation()
        }
    }

    private func sectionSpacing(isCompact: Bool) -> CGFloat {
        isCompact
            ? OnboardingLayout.targetWeightCompactSectionSpacing
            : OnboardingLayout.targetWeightSectionSpacing
    }

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .targetWeight, showsSubtitle: false)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func heroSummarySection(isCompact: Bool) -> some View {
        if let valueLine = OnboardingTargetWeightValues.displayValueHeadline(for: formState) {
            OnboardingTargetWeightHeroSummary(
                valueLine: valueLine,
                journeyLine: OnboardingTargetWeightValues.currentToTargetSummary(for: formState),
                deltaLine: OnboardingTargetWeightValues.differenceLabel(for: formState),
                isCompact: isCompact
            )
            .opacity(summaryVisible ? 1 : 0)
            .offset(y: summaryVisible ? 0 : 6)
        }
    }

    @ViewBuilder
    private func guidanceSection(isCompact: Bool) -> some View {
        if let guidanceState {
            OnboardingTargetWeightGuidanceCard(state: guidanceState, isCompact: isCompact)
                .opacity(guidanceVisible ? 1 : 0)
                .offset(y: guidanceVisible ? 0 : 6)
        }
    }

    @ViewBuilder
    private func targetWeightRuler(isCompact: Bool) -> some View {
        OnboardingTargetWeightRulerSelector(
            formState: $formState,
            rulerHeight: isCompact
                ? OnboardingLayout.premiumRulerCompactHeight
                : OnboardingLayout.premiumRulerHeight
        )
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            summaryVisible = true
            rulerVisible = true
            guidanceVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.24)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.08)) {
            summaryVisible = true
        }
        withAnimation(.easeOut(duration: 0.30).delay(0.16)) {
            rulerVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.28)) {
            guidanceVisible = true
        }
    }
}

#if DEBUG
#Preview("Target Weight — Maintain") {
    OnboardingTargetWeightStepView(
        formState: .constant(OnboardingPreviewData.targetWeightMaintainFormState)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target Weight — Loss") {
    OnboardingTargetWeightStepView(
        formState: .constant(OnboardingPreviewData.targetWeightLossFormState)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target Weight — Gain") {
    OnboardingTargetWeightStepView(
        formState: .constant(OnboardingPreviewData.targetWeightGainFormState)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target Weight — Imperial") {
    OnboardingTargetWeightStepView(
        formState: .constant(OnboardingPreviewData.targetWeightImperialLossFormState)
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target Weight — SE Compact") {
    OnboardingTargetWeightStepView(
        formState: .constant(OnboardingPreviewData.targetWeightLossFormState)
    )
    .frame(height: 360)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
