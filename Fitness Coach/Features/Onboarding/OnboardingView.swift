//
//  OnboardingView.swift
//  Fitness Coach
//
//  FitPilot AI — First-run onboarding flow.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    var onExistingAccount: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var fieldNavigator = OnboardingFieldNavigator()
    @StateObject private var keyboardMonitor = OnboardingKeyboardMonitor()
    @State private var hasAttemptedContinueOnStep = false

    private var isBottomBarBusy: Bool {
        model.viewState.isBottomBarBusy
    }

    private var showsBottomBar: Bool {
        if model.usesV3Steps, let step = model.currentV3Step {
            return OnboardingV3InteractionPolicy.rules(for: step).showsSharedBottomBar
        }
        return !model.currentStep.usesFullScreenChrome
            && model.currentStep != .savePlan
            && model.currentStep != .landing
    }

    private var canContinue: Bool {
        if model.usesV3Steps, let step = model.currentV3Step {
            let rules = OnboardingV3InteractionPolicy.rules(for: step)
            if rules.isOptional, !rules.validatesOnContinue {
                return true
            }
            if !rules.validatesOnContinue {
                return true
            }
            return model.formState.canAdvanceV3(from: step)
        }
        return model.formState.canAdvance(from: model.currentStep)
    }

    private var displayedValidationMessage: String? {
        guard hasAttemptedContinueOnStep else { return nil }
        return model.errorMessage
    }

    private var showsRequiredFieldsHint: Bool {
        hasAttemptedContinueOnStep && !canContinue
    }

    var body: some View {
        NavigationStack {
            OnboardingStepContainer(
                currentStep: model.currentStep,
                currentV3Step: model.usesV3Steps ? model.currentV3Step : nil,
                usesStageProgress: model.flowScope.usesV2Steps && !model.usesV3Steps,
                viewState: model.viewState,
                validationMessage: displayedValidationMessage,
                keyboardHeight: keyboardMonitor.keyboardHeight,
                fieldNavigator: fieldNavigator
            ) {
                stepContent
            }
            .background(OnboardingTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsBottomBar {
                    OnboardingBottomBar(
                        currentStep: model.currentStep,
                        currentV3Step: model.usesV3Steps ? model.currentV3Step : nil,
                        isLoading: isBottomBarBusy,
                        canContinue: canContinue,
                        showsRequiredFieldsHint: showsRequiredFieldsHint,
                        onBack: {
                            fieldNavigator.dismissFocus()
                            model.goBack()
                        },
                        onContinue: {
                            fieldNavigator.dismissFocus()
                            hasAttemptedContinueOnStep = true
                            model.goNext()
                        },
                        onComplete: {
                            fieldNavigator.dismissFocus()
                            model.completeOnboarding()
                        },
                        onAdjustPlan: isPlanRevealStep
                            ? {
                                fieldNavigator.dismissFocus()
                                model.adjustPlanFromReveal()
                            }
                            : nil
                    )
                }
            }
            .toolbar {
                OnboardingKeyboardToolbar(navigator: fieldNavigator)
            }
            .navigationBarHidden(true)
        }
        .environment(\.onboardingFieldNavigator, fieldNavigator)
        .preferredColorScheme(.dark)
        .onChange(of: model.currentStep) { _, _ in
            hasAttemptedContinueOnStep = false
        }
        .onChange(of: model.currentV3Step) { _, _ in
            hasAttemptedContinueOnStep = false
        }
        .onChange(of: model.errorMessage) { _, message in
            guard message != nil else { return }
            if model.currentStep == .summary || model.currentV3Step == .review {
                hasAttemptedContinueOnStep = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                model.flushDraftSnapshotIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        if model.usesV3Steps {
            v3StepContent
        } else if model.flowScope.usesV2Steps {
            v2StepContent
        } else {
            legacyStepContent
        }
    }

    private var isPlanRevealStep: Bool {
        model.currentV3Step == .planReveal || model.currentStep == .planReveal
    }

    @ViewBuilder
    private var v3StepContent: some View {
        switch model.currentV3Step {
        case .landing:
            OnboardingLandingStepView(
                onGetStarted: {
                    fieldNavigator.dismissFocus()
                    model.goNext()
                },
                onExistingAccount: onExistingAccount.map { handler in
                    {
                        fieldNavigator.dismissFocus()
                        handler()
                    }
                }
            )
        case .motivation:
            OnboardingMotivationStepView(formState: $model.formState)
        case .bodyBasics, .age, .sex, .height, .currentWeight:
            OnboardingBodyStepView(formState: $model.formState)
        case .goalWeight, .pace, .customPace:
            OnboardingGoalStepView(formState: $model.formState)
        case .activityLevel:
            OnboardingActivityLevelStepView(formState: $model.formState)
        case .trainingRhythm:
            OnboardingTrainingRhythmStepView(formState: $model.formState)
        case .preferences, .preferenceDetails:
            OnboardingPreferenceStepView(formState: $model.formState)
        case .review:
            OnboardingPersonalizationSummaryStepView(
                formState: model.formState,
                validationMessage: displayedValidationMessage
            )
        case .generatingPlan:
            OnboardingGeneratingPlanStepView(
                viewState: model.viewState,
                onReviewDetails: {
                    fieldNavigator.dismissFocus()
                    model.returnToSummaryAfterGenerationFailure()
                }
            )
        case .planReveal:
            OnboardingPlanRevealStepView(
                revealState: model.planRevealState,
                plan: model.generatedPlan
            )
        case .savePlan:
            OnboardingSavePlanStepView(
                requiresGoogleSignIn: model.requiresGoogleSignInAtSavePlan,
                isBusy: model.viewState == .savingProfile || model.viewState == .completing,
                allowsLocalOnlyContinuation: model.allowsLocalOnlyContinuation,
                errorMessage: model.errorMessage,
                onContinue: {
                    fieldNavigator.dismissFocus()
                    model.goNext()
                },
                onContinueWithoutAccount: {
                    fieldNavigator.dismissFocus()
                    model.completeWithoutAccount()
                },
                onBack: {
                    fieldNavigator.dismissFocus()
                    model.goBack()
                }
            )
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var v2StepContent: some View {
        switch model.currentStep {
        case .landing:
            OnboardingLandingStepView(
                onGetStarted: {
                    fieldNavigator.dismissFocus()
                    model.goNext()
                },
                onExistingAccount: onExistingAccount.map { handler in
                    {
                        fieldNavigator.dismissFocus()
                        handler()
                    }
                }
            )
        case .welcome:
            OnboardingWelcomeStepView()
        case .motivation:
            OnboardingMotivationStepView(formState: $model.formState)
        case .body:
            OnboardingBodyStepView(formState: $model.formState)
        case .goal:
            OnboardingGoalStepView(formState: $model.formState)
        case .activity:
            OnboardingActivityStepView(formState: $model.formState)
        case .preferences:
            OnboardingPreferenceStepView(formState: $model.formState)
        case .summary:
            OnboardingPersonalizationSummaryStepView(
                formState: model.formState,
                validationMessage: displayedValidationMessage
            )
        case .generatingPlan:
            OnboardingGeneratingPlanStepView(
                viewState: model.viewState,
                onReviewDetails: {
                    fieldNavigator.dismissFocus()
                    model.returnToSummaryAfterGenerationFailure()
                }
            )
        case .planReveal:
            OnboardingPlanRevealStepView(
                revealState: model.planRevealState,
                plan: model.generatedPlan
            )
        case .savePlan:
            OnboardingSavePlanStepView(
                requiresGoogleSignIn: model.requiresGoogleSignInAtSavePlan,
                isBusy: model.viewState == .savingProfile || model.viewState == .completing,
                allowsLocalOnlyContinuation: model.allowsLocalOnlyContinuation,
                errorMessage: model.errorMessage,
                onContinue: {
                    fieldNavigator.dismissFocus()
                    model.goNext()
                },
                onContinueWithoutAccount: {
                    fieldNavigator.dismissFocus()
                    model.completeWithoutAccount()
                },
                onBack: {
                    fieldNavigator.dismissFocus()
                    model.goBack()
                }
            )
        case .planPreview:
            EmptyView()
        }
    }

    @ViewBuilder
    private var legacyStepContent: some View {
        switch model.currentStep {
        case .welcome:
            OnboardingWelcomeStepView()
        case .body:
            OnboardingBodyStepView(formState: $model.formState)
        case .goal:
            OnboardingGoalStepView(formState: $model.formState)
        case .activity:
            OnboardingActivityStepView(formState: $model.formState)
        case .preferences:
            OnboardingPreferenceStepView(formState: $model.formState)
        case .planPreview:
            OnboardingPlanPreviewStepView(
                plan: model.generatedPlan,
                formState: model.formState
            )
        default:
            EmptyView()
        }
    }
}

#Preview {
    OnboardingView(
        model: OnboardingModel(
            userProfileService: try! AppContainer(inMemory: true).userProfileService,
            targetService: try! AppContainer(inMemory: true).targetService,
            onCompletion: {}
        )
    )
}
