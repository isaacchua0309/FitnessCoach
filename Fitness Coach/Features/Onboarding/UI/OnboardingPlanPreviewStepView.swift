//
//  OnboardingPlanPreviewStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Generated plan preview step for onboarding.
//

import SwiftUI

struct OnboardingPlanPreviewStepView: View {
    let plan: CalorieTargetResult?

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Review your starting targets",
                subtitle: FormaProductCopy.Onboarding.planPreviewSubtitle
            )

            if let plan {
                GeneratedPlanSummaryCard(plan: plan)
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
    OnboardingPlanPreviewStepView(plan: OnboardingPreviewData.generatedPlan)
        .padding()
}
