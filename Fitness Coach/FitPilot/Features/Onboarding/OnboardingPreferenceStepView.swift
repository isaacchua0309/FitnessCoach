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
    @Environment(\.onboardingFieldNavigator) private var fieldNavigator

    private enum Field: String, Hashable {
        case name
        case diet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Make it yours",
                subtitle: FormaProductCopy.Onboarding.preferencesSubtitle
            )

            VStack(spacing: OnboardingTheme.fieldSpacing) {
                OnboardingTextField(
                    title: "Name",
                    placeholder: "Optional",
                    text: $formState.name,
                    helper: "Used for friendly Coach messages.",
                    capitalization: .words,
                    isFocused: focusedField == .name,
                    submitLabel: .next,
                    onSubmit: { focusedField = .diet }
                )
                .focused($focusedField, equals: .name)
                .id(Field.name)

                OnboardingTextField(
                    title: "Diet preference",
                    placeholder: "High protein, halal, flexible carbs...",
                    text: $formState.dietPreference,
                    helper: "Optional. Add allergies or strong preferences later in Plan if needed.",
                    capitalization: .sentences,
                    axis: .vertical,
                    lineLimit: 2...4,
                    isFocused: focusedField == .diet,
                    submitLabel: .done,
                    onSubmit: { focusedField = nil }
                )
                .focused($focusedField, equals: .diet)
                .id(Field.diet)
            }

            VStack(spacing: 12) {
                OnboardingInfoCard(
                    title: "Coach-first logging",
                    message: FormaProductCopy.Onboarding.coachFirstLoggingMessage,
                    icon: "message.fill"
                )

                OnboardingInfoCard(
                    title: "No pressure",
                    message: FormaProductCopy.Onboarding.noPressureMessage,
                    icon: "slider.horizontal.3"
                )
            }
        }
        .onChange(of: focusedField) { _, field in
            syncNavigator(for: field)
        }
        .onAppear {
            syncNavigator(for: focusedField)
        }
    }

    private func syncNavigator(for field: Field?) {
        guard let fieldNavigator else { return }

        switch field {
        case .name:
            fieldNavigator.updateFocus(
                fieldID: Field.name,
                canPrevious: false,
                canNext: true,
                onPrevious: nil,
                onNext: { focusedField = .diet },
                onDismiss: { focusedField = nil }
            )
        case .diet:
            fieldNavigator.updateFocus(
                fieldID: Field.diet,
                canPrevious: true,
                canNext: false,
                onPrevious: { focusedField = .name },
                onNext: nil,
                onDismiss: { focusedField = nil }
            )
        case nil:
            fieldNavigator.clearFocus()
        }
    }
}

#Preview {
    OnboardingPreferenceStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
}
