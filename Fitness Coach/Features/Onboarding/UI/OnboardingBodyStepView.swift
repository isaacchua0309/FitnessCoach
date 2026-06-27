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

    private enum Field: String, Hashable {
        case age
        case height
        case weight
        case bodyFat
    }

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    private var showsValidFeedback: Bool {
        formState.canAdvance(from: .body)
    }

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

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            if !isV2 {
                legacyHeader
            }

            unitPicker

            measurementsGroup

            genderSection

            bodyFatField

            if showsValidFeedback {
                OnboardingFeedbackCard(
                    icon: "checkmark.circle.fill",
                    title: FormaProductCopy.Onboarding.V2.BodyFeedback.title,
                    message: FormaProductCopy.Onboarding.V2.BodyFeedback.message,
                    style: .success
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityLabel(
                    "\(FormaProductCopy.Onboarding.V2.BodyFeedback.title). \(FormaProductCopy.Onboarding.V2.BodyFeedback.message)"
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsValidFeedback)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: focusedField) { _, field in
            syncNavigator(for: field)
        }
        .onAppear {
            syncNavigator(for: focusedField)
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
        VStack(alignment: .leading, spacing: 8) {
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
        .onboardingCard()
    }

    // MARK: - Gender

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(FormaProductCopy.Onboarding.V2.Body.genderLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)

                Text(FormaProductCopy.Onboarding.V2.Body.genderHelper)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 136), spacing: FormaTokens.Spacing.sm, alignment: .top)],
                spacing: FormaTokens.Spacing.sm
            ) {
                ForEach(Sex.allCases, id: \.self) { sex in
                    OnboardingSelectionCard(
                        title: OnboardingFormatter.sex(sex),
                        icon: sexIcon(for: sex),
                        isSelected: formState.sex == sex
                    ) {
                        focusedField = nil
                        formState.sex = sex
                    }
                }
            }
            .accessibilityLabel(FormaProductCopy.Onboarding.V2.Body.genderLabel)
        }
    }

    // MARK: - Optional body fat

    private var bodyFatField: some View {
        OnboardingNumberField(
            title: FormaProductCopy.Onboarding.V2.Body.bodyFatLabel,
            placeholder: FormaProductCopy.Onboarding.V2.Body.bodyFatPlaceholder,
            text: $formState.estimatedBodyFatPercentageText,
            helper: FormaProductCopy.Onboarding.V2.Body.bodyFatHelper,
            keyboard: .decimalPad,
            isFocused: focusedField == .bodyFat
        )
        .focused($focusedField, equals: .bodyFat)
        .id(Field.bodyFat)
    }

    // MARK: - Keyboard navigation

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

    private func sexIcon(for sex: Sex) -> String {
        switch sex {
        case .male:
            return "figure.stand"
        case .female:
            return "figure.stand.dress"
        case .other:
            return "person.2.fill"
        case .preferNotToSay:
            return "person.crop.circle"
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
