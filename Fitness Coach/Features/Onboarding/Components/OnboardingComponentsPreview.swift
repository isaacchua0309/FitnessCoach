//
//  OnboardingComponentsPreview.swift
//  Fitness Coach
//
//  Forma — Compile/preview stubs for onboarding components (no routing).
//

import SwiftUI

#if DEBUG
enum OnboardingComponentsPreviewCatalog {

    @ViewBuilder
    static var formaProof: some View {
        OnboardingFormaProofStepView(
            formState: {
                var state = OnboardingFormState()
                OnboardingHeightWeightValues.setWeightKg(70, in: &state)
                OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
                return state
            }()
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var almostThere: some View {
        OnboardingAlmostThereStepView()
            .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var appleHealth: some View {
        OnboardingAppleHealthStepView(
            screenState: OnboardingAppleHealthPresentationBuilder.build(
                presentation: .ready,
                deviceState: .notConnected
            )
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var activityLevel: some View {
        OnboardingActivityLevelStepView(
            formState: .constant({
                var state = OnboardingFormState()
                OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
                return state
            }())
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var birthday: some View {
        OnboardingBirthdayStepView(
            formState: .constant({
                var state = OnboardingFormState()
                OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
                state.sex = .female
                return state
            }())
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var targetEncouragement: some View {
        OnboardingTargetEncouragementStepView(
            formState: {
                var state = OnboardingFormState()
                OnboardingHeightWeightValues.setWeightKg(70, in: &state)
                OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
                return state
            }()
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var targetWeight: some View {
        OnboardingTargetWeightStepView(
            formState: .constant({
                var state = OnboardingFormState()
                OnboardingHeightWeightValues.setHeightCm(170, in: &state)
                OnboardingHeightWeightValues.setWeightKg(72, in: &state)
                OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
                return state
            }())
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var heightWeight: some View {
        OnboardingHeightWeightStepView(
            formState: .constant({
                var state = OnboardingFormState()
                OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
                return state
            }())
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var introProof: some View {
        OnboardingIntroProofStepView()
            .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var pageShell: some View {
        OnboardingPageShell(
            currentStep: .heightWeight,
            helperText: "You can adjust these later in Profile.",
            onBack: {},
            onPrimary: {}
        ) {
            Text("Content area")
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
        }
    }

    @ViewBuilder
    static var wheelPickers: some View {
        VStack(spacing: FormaTokens.Spacing.lg) {
            OnboardingBirthdayWheelPicker(birthDate: .constant(nil))
            OnboardingMetricWheelPicker.heightCm(selection: .constant(170))
            OnboardingMetricWheelPicker.weightKg(selection: .constant(72))
        }
    }

    @ViewBuilder
    static var rulerPickers: some View {
        VStack(spacing: FormaTokens.Spacing.lg) {
            OnboardingRulerPickerFactory.weightKg(value: .constant(72))
            OnboardingRulerPickerFactory.weightLb(value: .constant(160))
        }
    }

    @ViewBuilder
    static var featureBullets: some View {
        OnboardingFeatureBulletList(bullets: OnboardingFeatureBullet.introProofDefaults)
    }

    @ViewBuilder
    static var proofCards: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            OnboardingWeightTrajectoryComparisonProofCard(model: .introProofDefault)
            OnboardingWeightMaintenanceProofCard(model: .introDefault)
            OnboardingFormaProofComparisonCard(model: .default)
            OnboardingComparisonBarProofCard(model: .introDefault)
        }
    }

    @ViewBuilder
    static var allComponents: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xl) {
                Group {
                    Text("Page shell")
                        .font(.caption.weight(.semibold))
                    pageShell
                }

                Group {
                    Text("Wheel pickers")
                        .font(.caption.weight(.semibold))
                    wheelPickers
                }

                Group {
                    Text("Ruler pickers")
                        .font(.caption.weight(.semibold))
                    rulerPickers
                }

                Group {
                    Text("Feature bullets")
                        .font(.caption.weight(.semibold))
                    featureBullets
                }

                Group {
                    Text("Proof cards")
                        .font(.caption.weight(.semibold))
                    proofCards
                }
            }
            .padding()
        }
        .background(OnboardingTheme.background)
    }
}

#Preview("Forma Proof Screen") {
    OnboardingComponentsPreviewCatalog.formaProof
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("Almost There Screen") {
    OnboardingComponentsPreviewCatalog.almostThere
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("Apple Health Screen") {
    OnboardingComponentsPreviewCatalog.appleHealth
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("Activity Level Screen") {
    OnboardingComponentsPreviewCatalog.activityLevel
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("Birthday Screen") {
    OnboardingComponentsPreviewCatalog.birthday
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("Intro Proof Screen") {
    OnboardingComponentsPreviewCatalog.introProof
}

#Preview("Page Shell") {
    OnboardingComponentsPreviewCatalog.pageShell
}

#Preview("Wheel Pickers") {
    OnboardingComponentsPreviewCatalog.wheelPickers
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("Ruler Pickers") {
    OnboardingComponentsPreviewCatalog.rulerPickers
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("Feature Bullets") {
    OnboardingComponentsPreviewCatalog.featureBullets
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("Proof Cards") {
    OnboardingComponentsPreviewCatalog.proofCards
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("All Components") {
    OnboardingComponentsPreviewCatalog.allComponents
}
#endif
