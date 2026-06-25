//
//  OnboardingPreferenceStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Preferences step for onboarding.
//

import SwiftUI

struct OnboardingPreferenceStepView: View {
    @Binding var formState: OnboardingFormState
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case diet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Make it yours",
                subtitle: "Optional details help Coach sound more personal and keep meal ideas relevant."
            )

            VStack(spacing: OnboardingTheme.fieldSpacing) {
                OnboardingTextField(
                    title: "Name",
                    placeholder: "Optional",
                    text: $formState.name,
                    helper: "Used for friendly Coach messages.",
                    capitalization: .words
                )
                .focused($focusedField, equals: .name)

                OnboardingTextField(
                    title: "Diet preference",
                    placeholder: "High protein, halal, flexible carbs...",
                    text: $formState.dietPreference,
                    helper: "Optional. Add allergies or strong preferences later in Profile if needed.",
                    capitalization: .sentences,
                    axis: .vertical,
                    lineLimit: 2...4
                )
                .focused($focusedField, equals: .diet)
            }
            .onboardingCard()

            VStack(spacing: 12) {
                OnboardingInfoCard(
                    title: "Coach-first logging",
                    message: "After setup, the Coach screen becomes your command center for food, water, weight, workouts, and daily decisions.",
                    icon: "message.fill"
                )

                OnboardingInfoCard(
                    title: "No pressure",
                    message: "Skip these if you want. You can update your profile anytime.",
                    icon: "slider.horizontal.3"
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }
}

#Preview {
    OnboardingPreferenceStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
}
