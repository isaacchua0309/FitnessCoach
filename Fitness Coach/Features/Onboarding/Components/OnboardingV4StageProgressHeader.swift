//
//  OnboardingV4StageProgressHeader.swift
//  Fitness Coach
//
//  Forma — Stage-based progress header for onboarding v4.
//

import SwiftUI

struct OnboardingV4StageProgressHeader: View {
    let currentStep: OnboardingV4Step

    private var currentStage: OnboardingV4Stage {
        currentStep.stage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.progressBarSpacing) {
            stageSegmentBar

            VStack(alignment: .leading, spacing: OnboardingLayout.progressTitleSpacing) {
                Text(currentStep.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(currentStep.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .lineLimit(2)
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
            ForEach(OnboardingV4Stage.allCases) { stage in
                Capsule()
                    .fill(segmentFill(for: stage))
                    .frame(height: OnboardingLayout.progressSegmentHeight)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(currentStage.progressAccessibilityLabel)
    }

    private func segmentFill(for stage: OnboardingV4Stage) -> Color {
        if stage.progressIndex <= currentStage.progressIndex {
            return OnboardingTheme.accent
        }
        return Color.white.opacity(0.12)
    }
}
