//
//  OnboardingPersonalizationSummaryStepView.swift
//  Fitness Coach
//
//  Forma — Personalization summary before plan generation (onboarding v2).
//

import SwiftUI

struct OnboardingPersonalizationSummaryStepView: View {
    let formState: OnboardingFormState
    let validationMessage: String?

    private var recapCards: [OnboardingPersonalizationSummaryRecap] {
        OnboardingPersonalizationSummaryBuilder.recapCards(for: formState)
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
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            if showsValidationBanner {
                OnboardingWarningBanner(message: bannerMessage)
            }

            VStack(spacing: FormaTokens.Spacing.sm) {
                ForEach(recapCards) { card in
                    recapCard(card)
                }
            }

            OnboardingInfoCard(
                title: "Ready when you are",
                message: FormaProductCopy.Onboarding.V2.adjustsWithRealData,
                icon: "arrow.triangle.2.circlepath"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recapCard(_ card: OnboardingPersonalizationSummaryRecap) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.4)

            Text(card.value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title), \(card.value)")
    }
}

#Preview("Ready") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
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
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
