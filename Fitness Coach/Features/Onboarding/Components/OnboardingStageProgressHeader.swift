//
//  OnboardingStageProgressHeader.swift
//  Fitness Coach
//
//  Forma — Stage-based progress header for onboarding.
//

import SwiftUI

struct OnboardingStageProgressHeader: View {
    let currentStep: OnboardingStep
    var showsTitles: Bool = true
    var showsSubtitle: Bool = true
    var emphasizesLaunch: Bool = false
    var launchReady: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var segmentPulse = false

    private var progressIndex: Int {
        currentStep.flowProgressIndex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.progressBarSpacing) {
            stageSegmentBar

            if showsTitles {
                VStack(alignment: .leading, spacing: OnboardingLayout.progressTitleSpacing) {
                    Text(currentStep.title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if showsSubtitle {
                        Text(currentStep.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue(currentStep.flowProgressAccessibilityLabel)
        .onChange(of: launchReady) { _, ready in
            guard ready, emphasizesLaunch, !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: OnboardingPlanBlueprintLaunchTiming.pulseDuration)
                    .repeatForever(autoreverses: true)
            ) {
                segmentPulse = true
            }
        }
    }

    private var stageSegmentBar: some View {
        HStack(spacing: 4) {
            ForEach(1...OnboardingStage.stageCount, id: \.self) { index in
                segmentCapsule(for: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(currentStep.flowProgressAccessibilityLabel)
    }

    private func segmentCapsule(for index: Int) -> some View {
        let isActive = index <= progressIndex
        let isLaunchSegment = emphasizesLaunch && index == progressIndex

        return Capsule()
            .fill(isActive ? OnboardingTheme.progress : OnboardingTheme.progressTrack)
            .frame(height: OnboardingLayout.progressSegmentHeight)
            .overlay {
                if isLaunchSegment, segmentPulse {
                    Capsule()
                        .fill(OnboardingTheme.accent.opacity(0.5))
                        .blur(radius: 3)
                        .scaleEffect(x: 1, y: 1.75)
                }
            }
            .scaleEffect(isLaunchSegment && segmentPulse ? 1.03 : 1, anchor: .center)
            .accessibilityHidden(true)
    }
}
