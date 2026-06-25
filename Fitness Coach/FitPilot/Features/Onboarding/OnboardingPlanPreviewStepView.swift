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
                subtitle: "These are your initial numbers. FitPilot will help you adjust as real progress data comes in."
            )

            if let plan {
                GeneratedPlanSummaryCard(plan: plan)
            } else {
                OnboardingInfoCard(
                    title: "Plan not generated yet",
                    message: "Go back and generate your plan once your setup details are complete.",
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
