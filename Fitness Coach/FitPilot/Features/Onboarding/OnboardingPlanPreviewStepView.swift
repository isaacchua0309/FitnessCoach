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
        if let plan {
            GeneratedPlanSummaryCard(plan: plan)
        } else {
            Text("Your plan will appear here once generated.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

#Preview {
    OnboardingPlanPreviewStepView(plan: OnboardingPreviewData.generatedPlan)
        .padding()
}
