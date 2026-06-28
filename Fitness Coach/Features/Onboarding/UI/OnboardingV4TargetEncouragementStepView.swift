//
//  OnboardingV4TargetEncouragementStepView.swift
//  Fitness Coach
//
//  Forma — V4 encouragement after target weight selection.
//

import SwiftUI

struct OnboardingV4TargetEncouragementStepView: View {
    let formState: OnboardingFormState

    private var displayCopy: OnboardingV4TargetEncouragementDisplayCopy {
        OnboardingV4TargetEncouragementCopyBuilder.build(from: formState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            headline
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(displayCopy.accessibilityHeadline)

            Text(displayCopy.subtitle)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var headline: some View {
        switch displayCopy.headline {
        case .lossAmount(let prefix, let amount, let suffix):
            (Text(prefix) + Text(amount).foregroundStyle(OnboardingTheme.accent) + Text(suffix))
        case .fallback(let title):
            Text(title)
        }
    }
}

#if DEBUG
#Preview("V4 Target Encouragement — Loss") {
    OnboardingV4TargetEncouragementStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingV4HeightWeightValues.setWeightKg(72, in: &state)
            OnboardingV4TargetWeightValues.setGoalFromLossKg(3.4, in: &state)
            state.unitSystem = .metric
            return state
        }()
    )
    .padding()
    .background(OnboardingTheme.background)
}

#Preview("V4 Target Encouragement — Fallback") {
    OnboardingV4TargetEncouragementStepView(formState: OnboardingFormState())
        .padding()
        .background(OnboardingTheme.background)
}
#endif
