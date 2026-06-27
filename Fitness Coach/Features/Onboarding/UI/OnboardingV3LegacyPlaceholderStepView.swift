//
//  OnboardingV3LegacyPlaceholderStepView.swift
//  Fitness Coach
//
//  Forma — Temporary bridge content until v3 picker screens land (Stage 2+).
//

import SwiftUI

/// Shows the legacy combined step UI with a v3 migration notice until dedicated pickers ship.
struct OnboardingV3LegacyPlaceholderStepView: View {
    let step: OnboardingV3Step
    @Binding var formState: OnboardingFormState

    private var rules: OnboardingV3InteractionRules {
        OnboardingV3InteractionPolicy.rules(for: step)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingInfoCard(
                title: "Coming next",
                message: placeholderMessage,
                icon: "hand.tap.fill"
            )

            legacyStepContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var legacyStepContent: some View {
        switch step {
        case .age, .sex, .height, .currentWeight:
            OnboardingBodyStepView(formState: $formState)
        case .trainingRhythm:
            EmptyView()
        default:
            EmptyView()
        }
    }

    private var placeholderMessage: String {
        "\(rules.primaryJob) — dedicated tap controls ship in the next onboarding stage. Continue uses the current form until then."
    }
}

#Preview {
    OnboardingV3LegacyPlaceholderStepView(step: .age, formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
