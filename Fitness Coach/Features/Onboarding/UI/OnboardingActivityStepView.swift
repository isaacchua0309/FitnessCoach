//
//  OnboardingActivityStepView.swift
//  Fitness Coach
//
//  Forma — Activity and training rhythm step for onboarding (v2 journey + legacy v1).
//

import SwiftUI

struct OnboardingActivityStepView: View {
    @Binding var formState: OnboardingFormState
    @FocusState private var focusedField: Field?
    @Environment(\.onboardingFieldNavigator) private var fieldNavigator

    private enum Field: String, Hashable {
        case trainingDays
        case steps
    }

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    private var showsValidFeedback: Bool {
        formState.canAdvance(from: .activity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            if !isV2 {
                legacyHeader
            }

            activityLevelSection

            trainingRhythmSection

            if showsValidFeedback {
                OnboardingFeedbackCard(
                    icon: "figure.run",
                    title: FormaProductCopy.Onboarding.V2.ActivityFeedback.title,
                    message: OnboardingActivityFeedback.message(for: formState.activityLevel),
                    style: .guidance
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityLabel(
                    "\(FormaProductCopy.Onboarding.V2.ActivityFeedback.title). \(OnboardingActivityFeedback.message(for: formState.activityLevel))"
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsValidFeedback)
        .animation(.easeInOut(duration: 0.2), value: formState.activityLevel)
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
            title: FormaProductCopy.Onboarding.V2.Activity.title,
            subtitle: FormaProductCopy.Onboarding.V2.Activity.subtitle
        )
    }

    // MARK: - Activity level

    private var activityLevelSection: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                OnboardingSelectionCard(
                    title: OnboardingFormatter.activityLevel(level),
                    subtitle: OnboardingFormatter.activityLevelDescription(level),
                    icon: activityIcon(for: level),
                    isSelected: formState.activityLevel == level
                ) {
                    focusedField = nil
                    formState.activityLevel = level
                }
            }
        }
        .accessibilityLabel("Activity level options")
    }

    // MARK: - Training rhythm

    private var trainingRhythmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(FormaProductCopy.Onboarding.V2.Activity.trainingRhythmSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            VStack(spacing: OnboardingTheme.fieldSpacing) {
                OnboardingNumberField(
                    title: FormaProductCopy.Onboarding.V2.Activity.trainingDaysLabel,
                    placeholder: "3",
                    text: $formState.trainingFrequencyPerWeekText,
                    helper: FormaProductCopy.Onboarding.V2.Activity.trainingDaysHelper,
                    keyboard: .numberPad,
                    isFocused: focusedField == .trainingDays
                )
                .focused($focusedField, equals: .trainingDays)
                .id(Field.trainingDays)

                OnboardingNumberField(
                    title: FormaProductCopy.Onboarding.V2.Activity.averageStepsLabel,
                    placeholder: "5000",
                    text: $formState.averageStepsText,
                    helper: FormaProductCopy.Onboarding.V2.Activity.averageStepsHelper,
                    keyboard: .numberPad,
                    isFocused: focusedField == .steps
                )
                .focused($focusedField, equals: .steps)
                .id(Field.steps)
            }
            .onboardingCard()
        }
    }

    // MARK: - Keyboard navigation

    private func syncNavigator(for field: Field?) {
        guard let fieldNavigator else { return }

        switch field {
        case .trainingDays:
            fieldNavigator.updateFocus(
                fieldID: Field.trainingDays,
                canPrevious: false,
                canNext: true,
                onPrevious: nil,
                onNext: { focusedField = .steps },
                onDismiss: { focusedField = nil }
            )
        case .steps:
            fieldNavigator.updateFocus(
                fieldID: Field.steps,
                canPrevious: true,
                canNext: false,
                onPrevious: { focusedField = .trainingDays },
                onNext: nil,
                onDismiss: { focusedField = nil }
            )
        case nil:
            fieldNavigator.clearFocus()
        }
    }

    private func activityIcon(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return "chair.fill"
        case .lightlyActive:
            return "figure.walk"
        case .moderatelyActive:
            return "figure.run"
        case .veryActive:
            return "figure.strengthtraining.traditional"
        case .athlete:
            return "bolt.heart.fill"
        }
    }
}

#Preview("Valid") {
    OnboardingActivityStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
        .preferredColorScheme(.dark)
}

#Preview("Incomplete") {
    OnboardingActivityStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.trainingFrequencyPerWeekText = ""
            state.averageStepsText = ""
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
    .preferredColorScheme(.dark)
}
