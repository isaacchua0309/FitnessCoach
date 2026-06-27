//
//  OnboardingPreferenceStepView.swift
//  Fitness Coach
//
//  Forma — Optional chip-based preferences (no keyboard by default).
//

import SwiftUI

struct OnboardingPreferenceStepView: View {
    @Binding var formState: OnboardingFormState
    @State private var showsCustomDietField = false
    @State private var showsNameField = false
    @FocusState private var isCustomDietFocused: Bool
    @FocusState private var isNameFocused: Bool

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    private let foodPreferenceColumns = [
        GridItem(.flexible(), spacing: OnboardingLayout.compactFieldSpacing),
        GridItem(.flexible(), spacing: OnboardingLayout.compactFieldSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if !isV2, !OnboardingV3StepPolicy.isActive {
                legacyHeader
            }

            foodPreferencesSection
            loggingStyleSection
            nameSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            syncDisclosureExpansion()
        }
        .onChange(of: formState.dietPreference) { _, _ in
            syncDisclosureExpansion()
        }
        .onChange(of: formState.name) { _, _ in
            syncDisclosureExpansion()
        }
    }

    // MARK: - Header

    private var legacyHeader: some View {
        OnboardingSectionTitle(
            title: FormaProductCopy.Onboarding.V2.Preferences.title,
            subtitle: FormaProductCopy.Onboarding.V2.Preferences.subtitle
        )
    }

    // MARK: - Food preferences

    private var foodPreferencesSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V2.Preferences.foodPreferencesSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            LazyVGrid(columns: foodPreferenceColumns, spacing: OnboardingLayout.compactFieldSpacing) {
                ForEach(OnboardingDietPreferenceChip.foodPreferenceOptions) { chip in
                    OnboardingPillButton(
                        title: chip.title,
                        isSelected: formState.selectedDietChips.contains(chip)
                    ) {
                        formState.toggleDietChip(chip)
                    }
                    .accessibilityLabel(
                        formState.selectedDietChips.contains(chip)
                            ? "\(chip.title), selected"
                            : chip.title
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(FormaProductCopy.Onboarding.V2.Preferences.foodPreferencesSectionTitle)

            if !showsCustomDietField {
                disclosureButton(
                    title: FormaProductCopy.Onboarding.V2.Preferences.customPreferenceDisclosureLabel
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsCustomDietField = true
                    }
                }
            } else {
                OnboardingTextField(
                    title: FormaProductCopy.Onboarding.V2.Preferences.customPreferenceDisclosureLabel,
                    placeholder: FormaProductCopy.Onboarding.V2.Preferences.customPreferencePlaceholder,
                    text: customDietBinding,
                    helper: FormaProductCopy.Onboarding.V2.Preferences.customPreferenceHelper,
                    capitalization: .sentences,
                    axis: .vertical,
                    lineLimit: 2...3,
                    isFocused: isCustomDietFocused
                )
                .focused($isCustomDietFocused)
                .onboardingScrollTarget(id: "preferences-custom-diet", isFocused: isCustomDietFocused)
            }
        }
    }

    private var customDietBinding: Binding<String> {
        Binding(
            get: { formState.customDietPreferenceText },
            set: { formState.customDietPreferenceText = $0 }
        )
    }

    // MARK: - Logging style

    private var loggingStyleSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V2.Preferences.loggingSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            HStack(spacing: OnboardingLayout.compactFieldSpacing) {
                ForEach(OnboardingLoggingStyleChoice.allCases) { style in
                    loggingStylePill(style)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(FormaProductCopy.Onboarding.V2.Preferences.loggingSectionTitle)
        }
    }

    private func loggingStylePill(_ style: OnboardingLoggingStyleChoice) -> some View {
        let isSelected = formState.loggingStyleChoice == style

        return OnboardingPillButton(
            title: style.title,
            isSelected: isSelected
        ) {
            if isSelected {
                formState.selectLoggingStyle(nil)
            } else {
                formState.selectLoggingStyle(style)
            }
        }
        .accessibilityLabel(isSelected ? "\(style.title), selected" : style.title)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            if !showsNameField {
                disclosureButton(
                    title: FormaProductCopy.Onboarding.V2.Preferences.nameDisclosureLabel
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsNameField = true
                    }
                }
            } else {
                OnboardingTextField(
                    title: FormaProductCopy.Onboarding.V2.Preferences.nameLabel,
                    placeholder: FormaProductCopy.Onboarding.V2.Preferences.namePlaceholder,
                    text: $formState.name,
                    helper: FormaProductCopy.Onboarding.V2.Preferences.nameHelper,
                    capitalization: .words,
                    isFocused: isNameFocused
                )
                .focused($isNameFocused)
                .onboardingScrollTarget(id: "preferences-name", isFocused: isNameFocused)
            }
        }
    }

    private func disclosureButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(OnboardingTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func syncDisclosureExpansion() {
        if !formState.customDietPreferenceText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty {
            showsCustomDietField = true
        }

        if !formState.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showsNameField = true
        }
    }
}

#Preview("Empty") {
    OnboardingPreferenceStepView(formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Multiple chips") {
    OnboardingPreferenceStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.toggleDietChip(.highProtein)
            state.toggleDietChip(.simpleMeals)
            state.selectLoggingStyle(.both)
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Custom preference") {
    OnboardingPreferenceStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.customDietPreferenceText = "Gluten free"
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Logging style") {
    OnboardingPreferenceStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.selectLoggingStyle(.chatWithCoach)
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Name expanded") {
    OnboardingPreferenceStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.name = "Alex"
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("iPhone SE") {
    OnboardingPreferenceStepView(formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Large iPhone") {
    OnboardingPreferenceStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
}
