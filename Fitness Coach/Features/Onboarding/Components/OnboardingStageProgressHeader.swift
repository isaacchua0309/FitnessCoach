//
//  OnboardingStageProgressHeader.swift
//  Fitness Coach
//
//  Forma — Stage-based onboarding progress (v2 journey header).
//

import SwiftUI

struct OnboardingStageProgressHeader: View {
    let currentStep: OnboardingStep

    private var currentStage: OnboardingStage {
        currentStep.stage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stageSegmentBar

            VStack(alignment: .leading, spacing: 8) {
                Text(currentStep.title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(currentStep.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue(currentStage.progressAccessibilityLabel)
    }

    private var stageSegmentBar: some View {
        HStack(spacing: 4) {
            ForEach(OnboardingStage.allCases) { stage in
                Capsule()
                    .fill(segmentFill(for: stage))
                    .frame(height: 5)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(currentStage.progressAccessibilityLabel)
    }

    private func segmentFill(for stage: OnboardingStage) -> Color {
        if stage.progressIndex <= currentStage.progressIndex {
            return OnboardingTheme.accent
        }
        return Color.white.opacity(0.12)
    }
}

#Preview("Basics") {
    OnboardingStageProgressHeader(currentStep: .body)
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Plan reveal") {
    OnboardingStageProgressHeader(currentStep: .planReveal)
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    OnboardingStageProgressHeader(currentStep: .goal)
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
