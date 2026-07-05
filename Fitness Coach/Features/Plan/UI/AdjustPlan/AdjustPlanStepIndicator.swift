//
//  AdjustPlanStepIndicator.swift
//  Fitness Coach
//
//  Forma — Wizard step progress indicator for the Adjust Plan flow.
//

import SwiftUI

enum AdjustPlanStepIndicatorLayout {
    static let progressHeight: CGFloat = 3
    static let segmentSpacing: CGFloat = 6
}

struct AdjustPlanStepIndicator: View {
    let stepCount: Int
    let currentStepIndex: Int

    @Environment(\.formaPlanColors) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AdjustPlanStepIndicatorLayout.segmentSpacing) {
            ForEach(0..<max(stepCount, 1), id: \.self) { index in
                Capsule()
                    .fill(
                        index <= currentStepIndex
                            ? theme.progressFill
                            : theme.progressTrack
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: AdjustPlanStepIndicatorLayout.progressHeight)
            }
        }
        .animation(
            PlanEditMotion.animation(PlanEditMotion.progress, reduceMotion: reduceMotion),
            value: currentStepIndex
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FormaProductCopy.PlanEditAccessibility.progressLabel)
        .accessibilityValue(
            PlanEditAccessibility.progressValue(
                currentStep: currentStepIndex,
                stepCount: stepCount
            )
        )
        .formaThemeReactive()
    }
}

#if DEBUG
#Preview {
    AdjustPlanStepIndicator(stepCount: 5, currentStepIndex: 1)
        .padding()
        .background(FormaPlanTokens.Color.planBackground)
        .formaThemePreview()
}
#endif
