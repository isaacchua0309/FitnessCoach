//
//  OnboardingPlanPreviewStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Legacy v1 generated plan preview (`.planPreview` step only).
//  V2 onboarding uses `OnboardingPlanRevealStepView` instead; do not wire this into v2 flows.
//

import SwiftUI

@available(*, deprecated, message: "Use OnboardingPlanRevealStepView for v2 onboarding.")
struct OnboardingPlanPreviewStepView: View {
    let plan: CalorieTargetResult?
    let formState: OnboardingFormState

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Review your starting targets",
                subtitle: FormaProductCopy.Onboarding.planPreviewSubtitle
            )

            if let plan {
                GeneratedPlanSummaryCard(
                    plan: plan,
                    pacePreview: formState.pacePreview(),
                    paceLabel: formState.paceDisplayLabel(result: plan)
                )
            } else {
                OnboardingInfoCard(
                    title: FormaProductCopy.Onboarding.planNotGeneratedTitle,
                    message: FormaProductCopy.Onboarding.planNotGeneratedMessage,
                    icon: "doc.text.magnifyingglass"
                )
            }
        }
    }
}

#Preview {
    OnboardingPlanPreviewStepView(
        plan: OnboardingPreviewData.generatedPlan,
        formState: OnboardingPreviewData.formState
    )
    .padding()
}
