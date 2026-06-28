//
//  OnboardingStageProgressHeader.swift
//  Fitness Coach
//
//  Forma — Stage-based progress header for onboarding.
//

import SwiftUI

struct OnboardingStageProgressHeader: View {
    let currentStep: OnboardingStep

    private var progressIndex: Int {
        currentStep.flowProgressIndex
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
        .accessibilityValue(currentStep.flowProgressAccessibilityLabel)
    }

    private var stageSegmentBar: some View {
        HStack(spacing: 4) {
            ForEach(1...OnboardingStage.stageCount, id: \.self) { index in
                Capsule()
                    .fill(segmentFill(for: index))
                    .frame(height: OnboardingLayout.progressSegmentHeight)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(currentStep.flowProgressAccessibilityLabel)
    }

    private func segmentFill(for index: Int) -> Color {
        if index <= progressIndex {
            return OnboardingTheme.progress
        }
        return OnboardingTheme.progressTrack
    }
}
