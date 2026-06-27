//
//  OnboardingPersonalizationSummaryStepView.swift
//  Fitness Coach
//
//  Forma — Compact review before plan generation.
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
    }

    private var bannerMessage: String {
        validationMessage
            ?? OnboardingPersonalizationSummaryBuilder.validationMessage(for: formState)
            ?? FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if showsValidationBanner {
                OnboardingWarningBanner(message: bannerMessage)
            }

            compactRecapList
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactRecapList: some View {
        VStack(spacing: 0) {
            ForEach(Array(recapCards.enumerated()), id: \.element.id) { index, card in
                if index > 0 {
                    Divider()
                        .overlay(OnboardingTheme.border.opacity(0.55))
                        .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
                }

                recapRow(card)
            }
        }
        .onboardingCompactCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Review summary")
    }

    private func recapRow(_ card: OnboardingPersonalizationSummaryRecap) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(card.title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .frame(width: 92, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.value)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
        .padding(.vertical, OnboardingLayout.compactFieldVerticalPadding)
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title), \(card.value)")
    }
}

#Preview("Full data") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingPreviewData.formState
            state.toggleDietChip(.highProtein)
            state.toggleDietChip(.simpleMeals)
            state.selectedMotivations = [.confidence]
            return state
        }(),
        validationMessage: nil
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Minimal optional data") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Maintenance goal") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingPreviewData.formState
            state.goalWeightKgText = state.currentWeightKgText
            return state
        }(),
        validationMessage: nil
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Advanced pace") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingPreviewData.formState
            state.selectPaceChoice(.advanced)
            state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.45")
            return state
        }(),
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

#Preview("iPhone SE") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Large iPhone") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
    .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
}
