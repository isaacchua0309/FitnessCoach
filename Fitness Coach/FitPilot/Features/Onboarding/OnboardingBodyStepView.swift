//
//  OnboardingBodyStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Body details step for onboarding.
//

import SwiftUI

struct OnboardingBodyStepView: View {
    @Binding var formState: OnboardingFormState
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case age
        case height
        case weight
        case bodyFat
    }

    private let selectionColumns = [
        GridItem(.adaptive(minimum: 136), spacing: 10, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Body basics",
                subtitle: "These numbers power your initial calorie, macro, and water targets."
            )

            VStack(spacing: OnboardingTheme.fieldSpacing) {
                OnboardingTextField(
                    title: "Age",
                    placeholder: "28",
                    text: $formState.ageText,
                    keyboard: .numberPad
                )
                .focused($focusedField, equals: .age)

                OnboardingTextField(
                    title: "Height",
                    placeholder: "175",
                    text: $formState.heightCmText,
                    helper: "Centimeters",
                    keyboard: .decimalPad
                )
                .focused($focusedField, equals: .height)

                OnboardingTextField(
                    title: "Current weight",
                    placeholder: "82.5",
                    text: $formState.currentWeightKgText,
                    helper: "Kilograms",
                    keyboard: .decimalPad
                )
                .focused($focusedField, equals: .weight)
            }
            .onboardingCard()

            VStack(alignment: .leading, spacing: 12) {
                OnboardingSectionTitle(title: "Gender", subtitle: "Used only for target estimation.")

                LazyVGrid(columns: selectionColumns, spacing: 10) {
                    ForEach(Sex.allCases, id: \.self) { sex in
                        OnboardingSelectionCard(
                            title: OnboardingFormatter.sex(sex),
                            icon: "person.crop.circle",
                            isSelected: formState.sex == sex
                        ) {
                            focusedField = nil
                            formState.sex = sex
                        }
                    }
                }
            }

            VStack(spacing: OnboardingTheme.fieldSpacing) {
                OnboardingTextField(
                    title: "Body fat",
                    placeholder: "Optional",
                    text: $formState.estimatedBodyFatPercentageText,
                    helper: "Optional percentage. Leave blank if you do not know.",
                    keyboard: .decimalPad
                )
                .focused($focusedField, equals: .bodyFat)

                VStack(alignment: .leading, spacing: 12) {
                    OnboardingSectionTitle(title: "Units")

                    ForEach(UnitSystem.allCases, id: \.self) { system in
                        OnboardingSelectionCard(
                            title: OnboardingFormatter.unitSystem(system),
                            subtitle: system == .metric
                                ? "Best for this setup flow."
                                : "Display preference; values are still stored in metric.",
                            icon: "ruler",
                            isSelected: formState.unitSystem == system
                        ) {
                            focusedField = nil
                            formState.unitSystem = system
                        }
                    }
                }
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
    OnboardingBodyStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
}
