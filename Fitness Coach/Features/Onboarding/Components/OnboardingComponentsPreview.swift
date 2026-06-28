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
                OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &state)
                return state
            }()
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var almostThere: some View {
        OnboardingAlmostThereStepView()
    }

    @ViewBuilder
    static var planBlueprint: some View {
        OnboardingPersonalizationSummaryStepView(
            formState: OnboardingPreviewData.formState,
            validationMessage: nil
        )
    }

    @ViewBuilder
    static var appleHealth: some View {
        OnboardingAppleHealthStepView(
            screenState: OnboardingAppleHealthPresentationBuilder.build(
                presentation: .ready,
                deviceState: .notConnected
            )
        )
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
                OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &state)
                return state
            }()
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var targetWeight: some View {
        OnboardingTargetWeightStepView(
            formState: .constant(OnboardingPreviewData.targetWeightLossFormState)
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
    }

    @ViewBuilder
    static var targetWeightRulerMaintain: some View {
        OnboardingTargetWeightRulerSelector(
            formState: .constant(OnboardingPreviewData.targetWeightMaintainFormState)
        )
    }

    @ViewBuilder
    static var targetWeightRulerLoss: some View {
        OnboardingTargetWeightRulerSelector(
            formState: .constant(OnboardingPreviewData.targetWeightLossFormState)
        )
    }

    @ViewBuilder
    static var targetWeightRulerGain: some View {
        OnboardingTargetWeightRulerSelector(
            formState: .constant(OnboardingPreviewData.targetWeightGainFormState)
        )
    }

    @ViewBuilder
    static var targetWeightRulerImperial: some View {
        OnboardingTargetWeightRulerSelector(
            formState: .constant(OnboardingPreviewData.targetWeightImperialLossFormState)
        )
    }

    @ViewBuilder
    static var generatingPlan: some View {
        OnboardingGeneratingPlanStepView(
            presentation: OnboardingGeneratingPlanCopyBuilder.build(from: {
                var state = OnboardingFormState()
                OnboardingHeightWeightValues.setWeightKg(90, in: &state)
                OnboardingTargetWeightValues.setGoalFromDeltaKg(-12, in: &state)
                return state
            }()),
            viewState: .generatingPlanAnimated,
            onRetry: {},
            onGoBack: {}
        )
    }

    @ViewBuilder
    static var generatingPlanFailed: some View {
        OnboardingGeneratingPlanStepView(
            presentation: OnboardingGeneratingPlanCopyBuilder.build(from: OnboardingFormState()),
            viewState: .generationFailed,
            onRetry: {},
            onGoBack: {}
        )
    }

    @ViewBuilder
    static var planRevealProductionSE: some View {
        if let state = OnboardingPreviewData.planRevealState {
            OnboardingPlanRevealProductionPreviewShell(
                revealState: state,
                plan: OnboardingPreviewData.generatedPlan
            )
            .frame(width: 375, height: 667)
        }
    }

    @ViewBuilder
    static var planRevealProductionProMax: some View {
        if let state = OnboardingPreviewData.planRevealState {
            OnboardingPlanRevealProductionPreviewShell(
                revealState: state,
                plan: OnboardingPreviewData.generatedPlan
            )
            .frame(width: 430, height: 932)
        }
    }

    @ViewBuilder
    static var planReveal: some View {
        if let state = OnboardingPreviewData.planRevealState {
            OnboardingPlanRevealStepView(
                revealState: state,
                plan: OnboardingPreviewData.generatedPlan
            )
        }
    }

    @ViewBuilder
    static var planRevealCards: some View {
        if let state = OnboardingPreviewData.planRevealState {
            VStack(spacing: FormaTokens.Spacing.sm) {
                OnboardingPlanRevealGoalHeroCard(
                    badge: state.goalHeroSectionTitle,
                    headline: state.goalHeroHeadline,
                    strategyLabel: state.strategyLabel,
                    direction: state.goalDirection
                )
                OnboardingPlanRevealJourneyCard(
                    sectionTitle: FormaProductCopy.Onboarding.V2.PlanReveal.Cards.journeyTitle,
                    progressLabel: state.goalProgressLabel,
                    paceLabel: state.paceLabel,
                    estimatedWeeksLabel: state.estimatedWeeksLabel,
                    beliefLine: state.journeyBeliefLine,
                    planStatus: nil
                )
                OnboardingPlanRevealFirstWeekCard(
                    sectionTitle: FormaProductCopy.Onboarding.V2.PlanReveal.Cards.firstWeekTitle,
                    missions: state.firstWeekMissions
                )
                OnboardingPlanRevealNutritionCard(
                    sectionTitle: FormaProductCopy.Onboarding.V2.PlanReveal.Cards.dailyFuelTitle,
                    explanationLine: state.calorieExplanationLine,
                    calorieLabel: state.dailyCalorieLabel,
                    proteinLabel: state.proteinLabel,
                    waterLabel: state.waterLabel,
                    secondaryMacroRows: state.secondaryMacroRows
                )
                OnboardingPlanRevealCoachCard(message: state.coachMessage)
            }
            .environment(
                \.onboardingPlanRevealVisibleStages,
                Set(OnboardingPlanRevealEntranceStage.allCases)
            )
            .padding(.horizontal, OnboardingTheme.pagePadding)
        }
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
    static var targetWeightRuler: some View {
        targetWeightRulerLoss
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
                    Text("Target weight ruler")
                        .font(.caption.weight(.semibold))
                    targetWeightRuler
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

#Preview("Plan Blueprint Screen") {
    OnboardingComponentsPreviewCatalog.planBlueprint
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

#Preview("Generating Plan Screen") {
    OnboardingComponentsPreviewCatalog.generatingPlan
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Generating Plan Failed Screen") {
    OnboardingComponentsPreviewCatalog.generatingPlanFailed
        .background(OnboardingTheme.background)
        .formaThemePreview()
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

#Preview("Target Weight Screen — Loss") {
    OnboardingComponentsPreviewCatalog.targetWeight
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Target Weight Ruler — Maintain") {
    OnboardingComponentsPreviewCatalog.targetWeightRulerMaintain
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Target Weight Ruler — Loss") {
    OnboardingComponentsPreviewCatalog.targetWeightRulerLoss
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Target Weight Ruler — Gain") {
    OnboardingComponentsPreviewCatalog.targetWeightRulerGain
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Target Weight Ruler — Imperial") {
    OnboardingComponentsPreviewCatalog.targetWeightRulerImperial
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Plan Reveal — iPhone SE") {
    OnboardingComponentsPreviewCatalog.planRevealProductionSE
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Plan Reveal — Pro Max") {
    OnboardingComponentsPreviewCatalog.planRevealProductionProMax
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Plan Reveal") {
    OnboardingComponentsPreviewCatalog.planReveal
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Plan Reveal Cards") {
    OnboardingComponentsPreviewCatalog.planRevealCards
        .background(OnboardingTheme.background)
        .formaThemePreview()
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
