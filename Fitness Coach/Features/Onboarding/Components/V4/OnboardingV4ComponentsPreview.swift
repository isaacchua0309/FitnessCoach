//
//  OnboardingV4ComponentsPreview.swift
//  Fitness Coach
//
//  Forma — Compile/preview stubs for v4 onboarding components (no routing).
//

import SwiftUI

#if DEBUG
enum OnboardingV4ComponentsPreviewCatalog {

    @ViewBuilder
    static var formaProof: some View {
        OnboardingV4FormaProofStepView()
    }

    @ViewBuilder
    static var almostThere: some View {
        OnboardingV4AlmostThereStepView()
    }

    @ViewBuilder
    static var appleHealth: some View {
        OnboardingV4AppleHealthStepView()
    }

    @ViewBuilder
    static var activityLevel: some View {
        OnboardingV4ActivityLevelStepView(formState: .constant(OnboardingPreviewData.formState))
    }

    @ViewBuilder
    static var birthday: some View {
        OnboardingV4BirthdayStepView(
            formState: .constant({
                var state = OnboardingFormState()
                OnboardingV4BirthdayValues.applyDefaultsIfNeeded(to: &state)
                state.sex = .female
                return state
            }())
        )
    }

    @ViewBuilder
    static var targetEncouragement: some View {
        OnboardingV4TargetEncouragementStepView(
            formState: {
                var state = OnboardingFormState()
                OnboardingV4HeightWeightValues.setWeightKg(72, in: &state)
                OnboardingV4TargetWeightValues.setGoalFromLossKg(3.4, in: &state)
                return state
            }()
        )
    }

    @ViewBuilder
    static var targetWeight: some View {
        OnboardingV4TargetWeightStepView(
            formState: .constant({
                var state = OnboardingFormState()
                OnboardingV4HeightWeightValues.setHeightCm(170, in: &state)
                OnboardingV4HeightWeightValues.setWeightKg(72, in: &state)
                OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &state)
                return state
            }())
        )
    }

    @ViewBuilder
    static var heightWeight: some View {
        OnboardingV4HeightWeightStepView(
            formState: .constant({
                var state = OnboardingFormState()
                OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &state)
                return state
            }())
        )
    }

    @ViewBuilder
    static var introProof: some View {
        OnboardingV4IntroProofStepView(onNext: {})
    }

    @ViewBuilder
    static var pageShell: some View {
        OnboardingV4PageShell(
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
            OnboardingV4BirthdayWheelPicker(birthDate: .constant(nil))
            OnboardingV4MetricWheelPicker.heightCm(selection: .constant(170))
            OnboardingV4MetricWheelPicker.weightKg(selection: .constant(72))
        }
    }

    @ViewBuilder
    static var rulerPickers: some View {
        VStack(spacing: FormaTokens.Spacing.lg) {
            OnboardingV4RulerPickerFactory.weightKg(value: .constant(72))
            OnboardingV4RulerPickerFactory.weightLb(value: .constant(160))
        }
    }

    @ViewBuilder
    static var featureBullets: some View {
        OnboardingV4FeatureBulletList(bullets: OnboardingV4FeatureBullet.introProofDefaults)
    }

    @ViewBuilder
    static var proofCards: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            OnboardingV4WeightTrajectoryComparisonProofCard(model: .introProofDefault)
            OnboardingV4WeightMaintenanceProofCard(model: .introDefault)
            OnboardingV4FormaProofComparisonCard(model: .default)
            OnboardingV4ComparisonBarProofCard(model: .introDefault)
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

#Preview("V4 Forma Proof Screen") {
    OnboardingV4ComponentsPreviewCatalog.formaProof
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("V4 Almost There Screen") {
    OnboardingV4ComponentsPreviewCatalog.almostThere
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("V4 Apple Health Screen") {
    OnboardingV4ComponentsPreviewCatalog.appleHealth
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("V4 Activity Level Screen") {
    OnboardingV4ComponentsPreviewCatalog.activityLevel
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("V4 Birthday Screen") {
    OnboardingV4ComponentsPreviewCatalog.birthday
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("V4 Intro Proof Screen") {
    OnboardingV4ComponentsPreviewCatalog.introProof
}

#Preview("V4 Page Shell") {
    OnboardingV4ComponentsPreviewCatalog.pageShell
}

#Preview("V4 Wheel Pickers") {
    OnboardingV4ComponentsPreviewCatalog.wheelPickers
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("V4 Ruler Pickers") {
    OnboardingV4ComponentsPreviewCatalog.rulerPickers
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("V4 Feature Bullets") {
    OnboardingV4ComponentsPreviewCatalog.featureBullets
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("V4 Proof Cards") {
    OnboardingV4ComponentsPreviewCatalog.proofCards
        .padding()
        .background(OnboardingTheme.background)
}

#Preview("V4 All Components") {
    OnboardingV4ComponentsPreviewCatalog.allComponents
}
#endif
