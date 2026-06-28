//
//  OnboardingPersonalizationSummaryStepView.swift
//  Fitness Coach
//
//  Forma — Fixed-viewport plan blueprint screen before generation.
//

import SwiftUI

struct OnboardingPersonalizationSummaryStepView: View {
    let formState: OnboardingFormState
    let validationMessage: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var chromeVisible = false
    @State private var heroVisible = false
    @State private var canvasVisible = false
    @State private var goalVisible = false
    @State private var featuresVisible = false
    @State private var signalsVisible = false
    @State private var launchReady = false
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
        VStack(spacing: 6) {
            progressChrome

            if showsValidationBanner {
                OnboardingWarningBanner(message: bannerMessage)
                    .opacity(chromeVisible ? 1 : 0)
            }

            heroTitle
            visualCanvas
            goalCard
            premiumFeatures
            signalStrip
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(displayState.accessibilityLabel)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
            scheduleLaunchReady()
        }
    }

    private var progressChrome: some View {
        OnboardingStageProgressHeader(
            currentStep: .review,
            showsTitles: false,
            emphasizesLaunch: true,
            launchReady: launchReady
        )
        .opacity(chromeVisible ? 1 : 0)
    }

    private var heroTitle: some View {
        Text(displayState.heroTitle)
            .font(.system(.title2, design: .rounded).weight(.bold))
            .foregroundStyle(OnboardingTheme.primaryText)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.72)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .opacity(heroVisible ? 1 : 0)
            .offset(y: heroVisible ? 0 : 4)
            .accessibilityAddTraits(.isHeader)
    }

    private var visualCanvas: some View {
        OnboardingPlanBlueprintVisualCanvas(
            profile: displayState.visualProfile,
            launchReady: launchReady
        )
            .opacity(canvasVisible ? 1 : 0)
            .scaleEffect(canvasVisible ? 1 : 0.96)
    }

    private var goalCard: some View {
        OnboardingPlanBlueprintGoalHeroCard(
            state: displayState.goalCard,
            launchReady: launchReady
        )
            .opacity(goalVisible ? 1 : 0)
            .offset(y: goalVisible ? 0 : 6)
    }

    private var premiumFeatures: some View {
        OnboardingPlanBlueprintPremiumFeatureRow(
            features: displayState.premiumFeatures,
            accessibilityLabel: FormaProductCopy.Onboarding.Flow.Summary.PremiumFeatures.accessibilityLabel
        )
        .opacity(featuresVisible ? 1 : 0)
        .offset(y: featuresVisible ? 0 : 6)
    }

    private var signalStrip: some View {
        OnboardingPlanBlueprintPersonalizationSignalStrip(
            signals: displayState.generatedSignals,
            launchReady: launchReady
        )
            .opacity(signalsVisible ? 1 : 0)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            chromeVisible = true
            heroVisible = true
            canvasVisible = true
            goalVisible = true
            featuresVisible = true
            signalsVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.2)) { chromeVisible = true }
        withAnimation(.easeOut(duration: 0.22).delay(0.03)) { heroVisible = true }
        withAnimation(.easeOut(duration: 0.28).delay(0.08)) { canvasVisible = true }
        withAnimation(.easeOut(duration: 0.24).delay(0.16)) { goalVisible = true }
        withAnimation(.easeOut(duration: 0.22).delay(0.22)) { featuresVisible = true }
        withAnimation(.easeOut(duration: 0.20).delay(0.28)) { signalsVisible = true }
    }

    private func scheduleLaunchReady() {
        if reduceMotion {
            launchReady = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingPlanBlueprintLaunchTiming.readyDelay) {
            launchReady = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
#Preview("Maintain") {
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

#Preview("Loss") {
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

#Preview("Small iPhone") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}
#endif
