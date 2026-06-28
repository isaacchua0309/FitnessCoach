//
//  OnboardingPlanGenerationRevealHandoffView.swift
//  Fitness Coach
//
//  Forma — Crossfades plan generation into plan reveal without root reset.
//

import SwiftUI

struct OnboardingPlanGenerationRevealHandoffView: View {
    let activeStep: OnboardingStep
    let presentation: OnboardingGeneratingPlanPresentation
    let viewState: OnboardingViewState
    let revealState: OnboardingPlanRevealState?
    let plan: CalorieTargetResult?
    let onRetry: () -> Void
    let onGoBack: () -> Void

    var body: some View {
        Group {
            switch activeStep {
            case .generatingPlan:
                OnboardingGeneratingPlanStepView(
                    presentation: presentation,
                    viewState: viewState,
                    onRetry: onRetry,
                    onGoBack: onGoBack
                )
            case .planReveal:
                OnboardingPlanRevealStepView(
                    revealState: revealState,
                    plan: plan,
                    showsSuccessHandoff: true,
                    defersEntranceForGenerationHandoff: true
                )
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.opacity)
    }
}

#if DEBUG
#Preview("Handoff — Generating") {
    OnboardingPlanGenerationRevealHandoffView(
        activeStep: .generatingPlan,
        presentation: OnboardingGeneratingPlanCopyBuilder.build(from: OnboardingPreviewData.formState),
        viewState: .generatingPlanAnimated,
        revealState: nil,
        plan: nil,
        onRetry: {},
        onGoBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
