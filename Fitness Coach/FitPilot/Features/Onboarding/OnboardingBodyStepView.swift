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
    @Environment(\.onboardingFieldNavigator) private var fieldNavigator

    private enum Field: String, Hashable {
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
                OnboardingNumberField(
                    title: "Age",
                    placeholder: "28",
                    text: $formState.ageText,
                    keyboard: .numberPad,
                    isFocused: focusedField == .age
                )
                .focused($focusedField, equals: .age)
                .id(Field.age)

                OnboardingNumberField(
                    title: "Height",
                    placeholder: "175",
                    text: $formState.heightCmText,
                    helper: "Centimeters",
                    keyboard: .decimalPad,
                    isFocused: focusedField == .height
                )
                .focused($focusedField, equals: .height)
                .id(Field.height)

                OnboardingNumberField(
                    title: "Current weight",
                    placeholder: "82.5",
                    text: $formState.currentWeightKgText,
                    helper: "Kilograms",
                    keyboard: .decimalPad,
                    isFocused: focusedField == .weight
                )
                .focused($focusedField, equals: .weight)
                .id(Field.weight)

                OnboardingNumberField(
                    title: "Body fat",
                    placeholder: "Optional",
                    text: $formState.estimatedBodyFatPercentageText,
                    helper: "Optional percentage. Leave blank if you do not know.",
                    keyboard: .decimalPad,
                    isFocused: focusedField == .bodyFat
                )
                .focused($focusedField, equals: .bodyFat)
                .id(Field.bodyFat)
            }

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
        case .age:
            fieldNavigator.updateFocus(
                fieldID: Field.age,
                canPrevious: false,
                canNext: true,
                onPrevious: nil,
                onNext: { focusedField = .height },
                onDismiss: { focusedField = nil }
            )
        case .height:
            fieldNavigator.updateFocus(
                fieldID: Field.height,
                canPrevious: true,
                canNext: true,
                onPrevious: { focusedField = .age },
                onNext: { focusedField = .weight },
                onDismiss: { focusedField = nil }
            )
        case .weight:
            fieldNavigator.updateFocus(
                fieldID: Field.weight,
                canPrevious: true,
                canNext: true,
                onPrevious: { focusedField = .height },
                onNext: { focusedField = .bodyFat },
                onDismiss: { focusedField = nil }
            )
        case .bodyFat:
            fieldNavigator.updateFocus(
                fieldID: Field.bodyFat,
                canPrevious: true,
                canNext: false,
                onPrevious: { focusedField = .weight },
                onNext: nil,
                onDismiss: { focusedField = nil }
            )
        case nil:
            fieldNavigator.clearFocus()
        }
    }
}

#Preview {
    OnboardingBodyStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
}
