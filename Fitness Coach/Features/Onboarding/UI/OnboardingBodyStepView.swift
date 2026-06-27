//
//  OnboardingBodyStepView.swift
//  Fitness Coach
//
//  Forma — Body basics step for onboarding (v2 journey + legacy v1).
//

import SwiftUI

struct OnboardingBodyStepView: View {
    @Binding var formState: OnboardingFormState
    @FocusState private var focusedField: Field?
    @Environment(\.onboardingFieldNavigator) private var fieldNavigator
    @State private var isBodyFatExpanded = false

    private enum Field: String, Hashable {
        case age
        case height
        case weight
        case bodyFat
    }

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    private var heightBinding: Binding<String> {
        Binding(
            get: { formState.displayText(for: .height) },
            set: { formState.setDisplayText($0, for: .height) }
        )
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { formState.displayText(for: .currentWeight) },
            set: { formState.setDisplayText($0, for: .currentWeight) }
        )
    }

    private var bodyFatValidationMessage: String? {
        let message = formState.validationMessage(for: .body)
        guard message == FormaProductCopy.Onboarding.Validation.bodyFatRange else { return nil }
        return message
    }

    private var shouldShowBodyFatField: Bool {
        isBodyFatExpanded
            || !formState.estimatedBodyFatPercentageText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            || bodyFatValidationMessage != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if !isV2 {
                legacyHeader
            }

            unitPicker

            measurementsGroup

            genderSection

            bodyFatSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: focusedField) { _, field in
            syncNavigator(for: field)
        }
        .onAppear {
            syncBodyFatExpansion()
            syncNavigator(for: focusedField)
        }
        .onChange(of: formState.estimatedBodyFatPercentageText) { _, _ in
            syncBodyFatExpansion()
        }
        .onChange(of: bodyFatValidationMessage) { _, _ in
            syncBodyFatExpansion()
        }
        .onChange(of: isBodyFatExpanded) { _, _ in
            if focusedField == .weight {
                syncNavigator(for: .weight)
            }
        }
    }

    // MARK: - Legacy header

    private var legacyHeader: some View {
        OnboardingSectionTitle(
            title: FormaProductCopy.Onboarding.V2.Body.title,
            subtitle: FormaProductCopy.Onboarding.V2.Body.subtitle
        )
    }

    // MARK: - Units

    private var unitPicker: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V2.Body.unitSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            Picker(FormaProductCopy.Onboarding.V2.Body.unitSectionTitle, selection: $formState.unitSystem) {
                Text(FormaProductCopy.Onboarding.V2.Body.unitMetricLabel).tag(UnitSystem.metric)
                Text(FormaProductCopy.Onboarding.V2.Body.unitImperialLabel).tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)
            .onChange(of: formState.unitSystem) { _, _ in
                focusedField = nil
            }
            .accessibilityLabel(FormaProductCopy.Onboarding.V2.Body.unitSectionTitle)
        }
    }

    // MARK: - Core measurements

    private var measurementsGroup: some View {
        VStack(spacing: OnboardingLayout.compactFieldSpacing) {
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
                placeholder: OnboardingFormatter.heightPlaceholder(for: formState.unitSystem),
                text: heightBinding,
                helper: OnboardingFormatter.heightUnitLabel(for: formState.unitSystem),
                keyboard: .decimalPad,
                isFocused: focusedField == .height
            )
            .focused($focusedField, equals: .height)
            .id(Field.height)

            OnboardingNumberField(
                title: "Current weight",
                placeholder: OnboardingFormatter.weightPlaceholder(for: formState.unitSystem),
                text: weightBinding,
                helper: OnboardingFormatter.weightUnitLabel(for: formState.unitSystem),
                keyboard: .decimalPad,
                isFocused: focusedField == .weight
            )
            .focused($focusedField, equals: .weight)
            .id(Field.weight)
        }
        .onboardingCompactCard()
    }

    // MARK: - Gender

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactFieldSpacing) {
            Text(FormaProductCopy.Onboarding.V2.Body.genderLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            OnboardingSexPillGrid(selection: $formState.sex)
                .onChange(of: formState.sex) { _, _ in
                    focusedField = nil
                }
        }
    }

    // MARK: - Optional body fat

    private var bodyFatSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactFieldSpacing) {
            if shouldShowBodyFatField {
                OnboardingNumberField(
                    title: FormaProductCopy.Onboarding.V2.Body.bodyFatLabel,
                    placeholder: FormaProductCopy.Onboarding.V2.Body.bodyFatPlaceholder,
                    text: $formState.estimatedBodyFatPercentageText,
                    helper: FormaProductCopy.Onboarding.V2.Body.bodyFatHelper,
                    trailingUnit: FormaProductCopy.Onboarding.V2.Body.bodyFatUnit,
                    keyboard: .decimalPad,
                    isFocused: focusedField == .bodyFat
                )
                .focused($focusedField, equals: .bodyFat)
                .id(Field.bodyFat)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isBodyFatExpanded = true
                    }
                } label: {
                    HStack(spacing: OnboardingLayout.compactLabelGap) {
                        Image(systemName: "plus.circle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.accent)

                        Text(FormaProductCopy.Onboarding.V2.Body.bodyFatDisclosureLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: OnboardingLayout.selectionRowMinHeight, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FormaProductCopy.Onboarding.V2.Body.bodyFatDisclosureLabel)
            }
        }
    }

    // MARK: - Keyboard navigation

    private func syncBodyFatExpansion() {
        if shouldShowBodyFatField {
            isBodyFatExpanded = true
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
                canNext: shouldShowBodyFatField,
                onPrevious: { focusedField = .height },
                onNext: shouldShowBodyFatField ? { focusedField = .bodyFat } : nil,
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

#Preview("Empty") {
    OnboardingBodyStepView(formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
        .preferredColorScheme(.dark)
}

#Preview("Valid") {
    OnboardingBodyStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
        .preferredColorScheme(.dark)
}

#Preview("Body fat expanded") {
    OnboardingBodyStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.estimatedBodyFatPercentageText = "24"
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
    .preferredColorScheme(.dark)
}

#Preview("Body fat invalid") {
    OnboardingBodyStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.estimatedBodyFatPercentageText = "71"
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
    .preferredColorScheme(.dark)
}

#Preview("iPhone SE") {
    OnboardingBodyStepView(formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Large iPhone") {
    OnboardingBodyStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
}
