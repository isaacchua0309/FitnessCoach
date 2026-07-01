//
//  OnboardingView.swift
//  Fitness Coach
//
//  FitPilot AI — First-run onboarding flow.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    @EnvironmentObject private var authManager: AuthManager
    var onExistingAccount: (() -> Void)?
    var onExitToWelcome: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var fieldNavigator = OnboardingFieldNavigator()
    @StateObject private var keyboardMonitor = OnboardingKeyboardMonitor()
    @State private var hasAttemptedContinueOnStep = false

    private var isBottomBarBusy: Bool {
        model.viewState.isBottomBarBusy
    }

    private var showsBottomBar: Bool {
        let rules = OnboardingInteractionPolicy.rules(for: model.currentStep)
        return rules.showsSharedBottomBar
    }

    private var reservesPlanRevealFooterSpace: Bool {
        OnboardingInteractionPolicy.rules(for: model.currentStep).reservesPlanRevealFooterSpace
    }

    private var canContinue: Bool {
        let rules = OnboardingInteractionPolicy.rules(for: model.currentStep)
        if model.currentStep == .review {
            return OnboardingPersonalizationSummaryBuilder.isReadyToGenerate(for: model.formState)
        }
        if rules.isOptional, !rules.validatesOnContinue {
            return true
        }
        if !rules.validatesOnContinue {
            return true
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

    private var continueRequiredFieldsHint: String? {
        guard showsRequiredFieldsHint else { return nil }
        return model.formState.validationMessage(for: model.currentStep)
    }

    private var appleHealthScreenState: OnboardingAppleHealthScreenState {
        model.appleHealthScreenState
    }

    private func handleContinueTapped() {
        fieldNavigator.dismissFocus()
        hasAttemptedContinueOnStep = true
        if model.currentStep == .appleHealth {
            model.connectAppleHealth()
        } else {
            model.goNext()
        }
    }

    var body: some View {
        NavigationStack {
            OnboardingStepContainer(
                currentStep: model.currentStep,
                viewState: model.viewState,
                validationMessage: displayedValidationMessage,
                keyboardHeight: keyboardMonitor.keyboardHeight,
                fieldNavigator: fieldNavigator
            ) {
                stepContent
                    .animation(
                        .easeOut(duration: OnboardingGeneratingPlanTiming.stepTransitionAnimation),
                        value: model.currentStep
                    )
            }
            .background(OnboardingTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsBottomBar {
                    OnboardingBottomBar(
                        currentStep: model.currentStep,
                        isLoading: isBottomBarBusy,
                        canContinue: canContinue,
                        showsRequiredFieldsHint: showsRequiredFieldsHint,
                        requiredFieldsHint: continueRequiredFieldsHint,
                        appleHealthPrimaryTitle: model.currentStep == .appleHealth
                            ? appleHealthScreenState.primaryTitle
                            : nil,
                        appleHealthSecondaryTitle: model.currentStep == .appleHealth
                            ? appleHealthScreenState.secondaryTitle
                            : nil,
                        isAppleHealthPrimaryEnabled: model.currentStep == .appleHealth
                            ? appleHealthScreenState.isPrimaryEnabled
                            : true,
                        isAppleHealthSkipEnabled: model.currentStep == .appleHealth
                            ? appleHealthScreenState.isSkipEnabled
                            : true,
                        onAppleHealthSkip: model.currentStep == .appleHealth
                            ? {
                                fieldNavigator.dismissFocus()
                                model.skipAppleHealth()
                            }
                            : nil,
                        onBack: {
                            fieldNavigator.dismissFocus()
                            model.goBack()
                        },
                        onContinue: handleContinueTapped,
                        onComplete: {
                            fieldNavigator.dismissFocus()
                            model.completeOnboarding()
                        },
                        onAdjustPlan: isPlanRevealStep
                            ? {
                                fieldNavigator.dismissFocus()
                                model.adjustPlanFromReveal()
                            }
                            : nil,
                        saveTrustNote: planRevealSaveTrustNote,
                        canExitToWelcome: model.canExitToWelcome,
                        onExitToWelcome: onExitToWelcome,
                        flowFloor: model.flowFloor
                    )
                    .transition(.opacity)
                } else if reservesPlanRevealFooterSpace {
                    OnboardingPlanRevealFooterReserve()
                        .transition(.opacity)
                }
            }
            .animation(
                .easeOut(duration: OnboardingGeneratingPlanTiming.stepTransitionAnimation),
                value: showsBottomBar
            )
            .animation(
                .easeOut(duration: OnboardingGeneratingPlanTiming.stepTransitionAnimation),
                value: reservesPlanRevealFooterSpace
            )
            .toolbar {
                OnboardingKeyboardToolbar(navigator: fieldNavigator)
            }
            .navigationBarHidden(true)
        }
        .environment(\.onboardingFieldNavigator, fieldNavigator)
        .onChange(of: model.currentStep) { _, _ in
            hasAttemptedContinueOnStep = false
        }
        .onChange(of: model.errorMessage) { _, message in
            guard message != nil else { return }
            if model.currentStep == .review {
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
        switch model.currentStep {
        case .introProof:
            OnboardingIntroProofStepView()
        case .heightWeight:
            OnboardingHeightWeightStepView(formState: $model.formState)
        case .targetWeight:
            OnboardingTargetWeightStepView(formState: $model.formState)
        case .weightLossPace:
            OnboardingWeightLossPaceStepView(formState: $model.formState)
        case .targetEncouragement:
            OnboardingTargetEncouragementStepView(formState: model.formState)
        case .birthday:
            OnboardingBirthdayStepView(formState: $model.formState)
        case .appleHealth:
            OnboardingAppleHealthStepView(screenState: model.appleHealthScreenState)
        case .almostThere:
            OnboardingAlmostThereStepView()
        case .formaProof:
            OnboardingFormaProofStepView(formState: model.formState)
        case .activityLevel:
            OnboardingActivityLevelStepView(formState: $model.formState)
        case .review:
            OnboardingPersonalizationSummaryStepView(
                formState: model.formState,
                validationMessage: displayedValidationMessage
            )
        case .generatingPlan, .planReveal:
            OnboardingPlanGenerationRevealHandoffView(
                activeStep: model.currentStep,
                presentation: OnboardingGeneratingPlanCopyBuilder.build(from: model.formState),
                viewState: model.viewState,
                revealState: model.planRevealState,
                plan: model.generatedPlan,
                onRetry: {
                    fieldNavigator.dismissFocus()
                    OnboardingHaptics.primaryActionTapped()
                    model.retryGeneration()
                },
                onGoBack: {
                    fieldNavigator.dismissFocus()
                    OnboardingHaptics.selectionChanged()
                    model.returnToSummaryAfterGenerationFailure()
                }
            )
        case .savePlan:
            OnboardingSavePlanStepView(
                requiresGoogleSignIn: model.requiresGoogleSignInAtSavePlan,
                isBusy: authManager.isPerformingGoogleSignIn,
                showsSignInSuccess: model.viewState == .signInSucceeded,
                errorMessage: model.errorMessage,
                planRecap: model.planRevealState,
                onContinue: {
                    fieldNavigator.dismissFocus()
                    OnboardingHaptics.primaryActionTapped()
                    model.goNext()
                },
                onBack: {
                    fieldNavigator.dismissFocus()
                    OnboardingHaptics.selectionChanged()
                    model.goBack()
                }
            )
        }
    }

    private var isPlanRevealStep: Bool {
        model.currentStep == .planReveal
    }

    private var planRevealSaveTrustNote: String? {
        guard isPlanRevealStep else { return nil }
        if model.requiresGoogleSignInAtSavePlan {
            return FormaProductCopy.Onboarding.Flow.PlanReveal.signedOutSaveTrustNote
        }
        return FormaProductCopy.Onboarding.Flow.PlanReveal.signedInSaveTrustNote
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    return OnboardingView(
        model: OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            planTargetCalculator: container.targetService,
            onCompletion: {}
        )
    )
    .environmentObject(container.authManager)
}
