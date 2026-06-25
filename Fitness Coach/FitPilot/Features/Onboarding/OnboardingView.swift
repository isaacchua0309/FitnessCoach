//
//  OnboardingView.swift
//  Fitness Coach
//
//  FitPilot AI — First-run onboarding flow.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel

    private var isLoading: Bool {
        switch model.viewState {
        case .generatingPlan, .completing:
            return true
        default:
            return false
        }
    }

    var body: some View {
        NavigationStack {
            OnboardingStepContainer(
                currentStep: model.currentStep,
                errorMessage: model.errorMessage,
                isLoading: isLoading
            ) {
                stepContent
            }
            .background(OnboardingTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                OnboardingBottomBar(
                    currentStep: model.currentStep,
                    isLoading: isLoading,
                    canContinue: model.formState.canAdvance(from: model.currentStep),
                    onBack: { model.goBack() },
                    onContinue: { model.goNext() },
                    onComplete: { model.completeOnboarding() }
                )
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var stepContent: some View {
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
            OnboardingPlanPreviewStepView(plan: model.generatedPlan)
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
