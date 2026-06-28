//
//  OnboardingMaintenancePreviewCard.swift
//  Fitness Coach
//
//  Forma — Live maintenance preview during height/weight onboarding.
//

import SwiftUI

struct OnboardingMaintenancePreviewCard: View {
    let state: OnboardingMaintenancePreviewState

    private let copy = FormaProductCopy.Onboarding.Flow.HeightWeight.self

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(copy.previewTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .textCase(.uppercase)
                .accessibilityHidden(true)

            if let maintenanceKcal = state.maintenanceKcal {
                Text("≈ \(PlanDisplayFormatter.formatKcalPerDay(maintenanceKcal))")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: maintenanceKcal)

                Text(copy.previewFootnote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(copy.previewPlaceholder)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.previewTitle)
        .accessibilityValue(state.accessibilityValue)
    }
}

#if DEBUG
#Preview("Maintenance Preview") {
    VStack(spacing: FormaTokens.Spacing.md) {
        OnboardingMaintenancePreviewCard(
            state: OnboardingHeightWeightMaintenanceEstimator.previewState(
                for: {
                    var state = OnboardingFormState()
                    OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
                    return state
                }()
            )
        )
        OnboardingMaintenancePreviewCard(state: .placeholder)
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
