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
    @StateObject private var keyboardMonitor = OnboardingKeyboardMonitor()
    @StateObject private var fieldNavigator = OnboardingFieldNavigator()

    private var isBottomBarBusy: Bool {
        model.viewState.isBottomBarBusy
    }

    private var showsBottomBar: Bool {
        !model.currentStep.usesFullScreenChrome
            && model.currentStep != .savePlan
            && model.currentStep != .landing
    }

    var body: some View {
        NavigationStack {
            OnboardingStepContainer(
                currentStep: model.currentStep,
                usesStageProgress: model.flowScope.usesV2Steps,
                viewState: model.viewState,
                errorMessage: model.errorMessage,
                fieldNavigator: fieldNavigator
            ) {
                stepContent
            }
            .background(OnboardingTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !keyboardMonitor.isVisible, showsBottomBar {
                    OnboardingBottomBar(
                        currentStep: model.currentStep,
                        isLoading: isBottomBarBusy,
                        canContinue: model.formState.canAdvance(from: model.currentStep),
                        onBack: {
                            fieldNavigator.dismissFocus()
                            model.goBack()
                        },
                        onContinue: {
                            fieldNavigator.dismissFocus()
                            model.goNext()
                        },
                        onComplete: {
                            fieldNavigator.dismissFocus()
                            model.completeOnboarding()
                        },
                        onAdjustPlan: model.currentStep == .planReveal
                            ? {
                                fieldNavigator.dismissFocus()
                                model.adjustPlanFromReveal()
                            }
                            : nil
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: keyboardMonitor.isVisible)
            .toolbar {
                OnboardingKeyboardToolbar(navigator: fieldNavigator)
            }
            .navigationBarHidden(true)
        }
        .environment(\.onboardingFieldNavigator, fieldNavigator)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                model.flushDraftSnapshotIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        if model.flowScope.usesV2Steps {
            v2StepContent
        } else {
            legacyStepContent
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
                validationMessage: model.errorMessage
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
