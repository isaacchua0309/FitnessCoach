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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OnboardingProgressHeader(currentStep: model.currentStep)

                    if let errorMessage = model.errorMessage {
                        OnboardingErrorView(message: errorMessage)
                    }

                    stepContent

                    if isLoading {
                        OnboardingLoadingView(
                            message: model.viewState == .completing
                                ? "Creating your profile..."
                                : "Generating your plan..."
                        )
                    }

                    OnboardingNavigationBar(
                        currentStep: model.currentStep,
                        isLoading: isLoading,
                        onBack: { model.goBack() },
                        onContinue: { model.goNext() },
                        onComplete: { model.completeOnboarding() }
                    )
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
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
