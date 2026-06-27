//
//  OnboardingInputComponentsPreview.swift
//  Fitness Coach
//
//  Forma — Design-time gallery for tap-first onboarding input components.
//

import SwiftUI

#Preview("Input component gallery") {
    OnboardingInputComponentsGallery()
        .preferredColorScheme(.dark)
}

private struct OnboardingInputComponentsGallery: View {
    @State private var sex: Sex = .female
    @State private var stepsBand: OnboardingDailyStepsBand = .moderate
    @State private var trainingDays: OnboardingTrainingDaysOption = .three
    @State private var logging: Set<OnboardingLoggingPreference> = [.quickTaps]
    @State private var pace: WeightLossPaceChoice = .moderate
    @State private var trainingDayCount: Int = 3
    @State private var age = OnboardingV3PickerDefaults.defaultAge
    @State private var height = OnboardingV3PickerDefaults.defaultHeightCm
    @State private var weight = OnboardingV3PickerDefaults.defaultWeightKg

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                section("Field summary") {
                    OnboardingFieldSummary(label: "Current weight", value: "70", unit: "kg", action: {})
                }

                section("Value pickers") {
                    OnboardingMetricValuePicker.age(selection: $age)
                    OnboardingMetricValuePicker.heightMetric(selection: $height)
                    OnboardingMetricValuePicker.weightMetric(
                        label: "Current weight",
                        selection: $weight
                    )
                }

                section("Number stepper") {
                    OnboardingNumberStepper(
                        title: "Training days",
                        value: $trainingDayCount,
                        range: 0...7,
                        unit: "days",
                        fineTuneLabel: "Pick on wheel",
                        onFineTune: {}
                    )
                }

                section("Pill grids") {
                    OnboardingPillGrid(
                        items: Sex.allCases,
                        selection: $sex,
                        titleForItem: { OnboardingFormatter.sex($0) },
                        columnCount: 2
                    )
                    OnboardingPillGrid(
                        items: OnboardingDailyStepsBand.allCases,
                        selection: $stepsBand,
                        titleForItem: \.title,
                        subtitleForItem: \.subtitle,
                        columnCount: 2
                    )
                    OnboardingPillGrid(
                        items: OnboardingTrainingDaysOption.allCases,
                        selection: $trainingDays,
                        titleForItem: \.displayLabel,
                        columnCount: 4
                    )
                }

                section("Choice grid") {
                    OnboardingChoiceGrid(
                        items: WeightLossPaceChoice.allCases.filter {
                            OnboardingV3InteractionPolicy.visiblePaceChoices.contains($0)
                        },
                        iconForItem: { choice in
                            switch choice {
                            case .gentle: return "leaf.fill"
                            case .moderate: return "gauge.medium"
                            case .aggressive: return "flame.fill"
                            case .advanced: return "slider.horizontal.3"
                            }
                        },
                        titleForItem: \.displayName,
                        subtitleForItem: \.subtitle,
                        selection: $pace
                    )
                }

                section("Multi select") {
                    OnboardingMultiPillGrid(
                        items: OnboardingLoggingPreference.allCases,
                        selections: $logging,
                        titleForItem: \.title,
                        subtitleForItem: \.subtitle,
                        columnCount: 1
                    )
                }

                section("Compact footer") {
                    OnboardingCompactFooter(
                        continueTitle: FormaProductCopy.Common.continueAction,
                        canContinue: true,
                        onBack: {},
                        onContinue: {}
                    )
                }
            }
            .padding(.horizontal, OnboardingTheme.pagePadding)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .background(OnboardingTheme.background)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .textCase(.uppercase)
            content()
        }
    }
}
