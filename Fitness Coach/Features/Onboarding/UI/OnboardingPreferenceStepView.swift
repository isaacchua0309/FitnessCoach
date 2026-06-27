//
//  OnboardingPreferenceStepView.swift
//  Fitness Coach
//
//  Forma — Eating and logging preferences step for onboarding (v2 journey + legacy v1).
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

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    private var feedbackMessage: String? {
        OnboardingLoggingPreferenceFeedback.message(for: formState.loggingPreferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            if !isV2 {
                legacyHeader
            }

            Text(FormaProductCopy.Onboarding.V2.Preferences.optionalHint)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(FormaProductCopy.Onboarding.V2.Preferences.optionalHint)

            nameSection

            dietSection

            loggingPreferencesSection

            if let feedbackMessage {
                OnboardingFeedbackCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: FormaProductCopy.Onboarding.V2.Preferences.feedbackTitle,
                    message: feedbackMessage,
                    style: .guidance
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityLabel(
                    "\(FormaProductCopy.Onboarding.V2.Preferences.feedbackTitle). \(feedbackMessage)"
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: formState.loggingPreferences)
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
            title: FormaProductCopy.Onboarding.V2.Preferences.title,
            subtitle: FormaProductCopy.Onboarding.V2.Preferences.subtitle
        )
    }

    // MARK: - Name

    private var nameSection: some View {
        OnboardingTextField(
            title: FormaProductCopy.Onboarding.V2.Preferences.nameLabel,
            placeholder: FormaProductCopy.Onboarding.V2.Preferences.namePlaceholder,
            text: $formState.name,
            helper: FormaProductCopy.Onboarding.V2.Preferences.nameHelper,
            capitalization: .words,
            isFocused: focusedField == .name,
            submitLabel: .next,
            onSubmit: { focusedField = .diet }
        )
        .focused($focusedField, equals: .name)
        .id(Field.name)
        .onboardingCard()
    }

    // MARK: - Diet

    private var dietSection: some View {
        OnboardingTextField(
            title: FormaProductCopy.Onboarding.V2.Preferences.eatingSectionTitle,
            placeholder: FormaProductCopy.Onboarding.V2.Preferences.dietPlaceholder,
            text: $formState.dietPreference,
            helper: FormaProductCopy.Onboarding.V2.Preferences.dietHelper,
            capitalization: .sentences,
            axis: .vertical,
            lineLimit: 2...4,
            isFocused: focusedField == .diet,
            submitLabel: .done,
            onSubmit: { focusedField = nil }
        )
        .focused($focusedField, equals: .diet)
        .id(Field.diet)
        .onboardingCard()
    }

    // MARK: - Logging preferences

    private var loggingPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(FormaProductCopy.Onboarding.V2.Preferences.loggingSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            VStack(spacing: FormaTokens.Spacing.sm) {
                ForEach(OnboardingLoggingPreference.allCases) { preference in
                    OnboardingSelectionCard(
                        title: preference.title,
                        subtitle: preference.subtitle,
                        icon: preference.symbolName,
                        isSelected: formState.loggingPreferences.contains(preference)
                    ) {
                        focusedField = nil
                        formState.toggleLoggingPreference(preference)
                    }
                }
            }
            .accessibilityLabel(FormaProductCopy.Onboarding.V2.Preferences.loggingSectionTitle)
        }
    }

    // MARK: - Keyboard navigation

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

#Preview("Empty") {
    OnboardingPreferenceStepView(formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
        .preferredColorScheme(.dark)
}

#Preview("With selections") {
    OnboardingPreferenceStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.name = "Alex"
            state.dietPreference = "High protein, simple meals"
            state.loggingPreferences = [.naturalLanguage, .quickTaps]
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
    .preferredColorScheme(.dark)
}
