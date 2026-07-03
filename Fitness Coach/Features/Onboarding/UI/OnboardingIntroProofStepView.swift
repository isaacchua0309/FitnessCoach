//
//  OnboardingIntroProofStepView.swift
//  Fitness Coach
//
//  Forma — intro proof entry with hero trajectory comparison.
//

import SwiftUI

struct OnboardingIntroProofStepView: View {
    private let model = OnboardingWeightTrajectoryComparisonModel.introProofDefault

    @State private var chartReveal: CGFloat = 0
    @State private var supportingVisible = false

    var body: some View {
        OnboardingIntroProofHeroSection(
            model: model,
            chartReveal: chartReveal,
            showsSupportingContent: supportingVisible
        )
        .onAppear(perform: runEntranceAnimation)
    }

    private func runEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.48).delay(0.06)) {
            chartReveal = 1
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.44)) {
            supportingVisible = true
        }
    }
}

#if DEBUG
#Preview("Intro Proof") {
    OnboardingStepContainer(
        currentStep: .introProof,
        viewState: .editing,
        validationMessage: nil,
        fieldNavigator: OnboardingFieldNavigator(),
        bottomBar: {
            OnboardingBottomBar(
                currentStep: .introProof,
                isLoading: false,
                canContinue: true,
                onBack: {},
                onContinue: {},
                onComplete: {}
            )
        }
    ) {
        OnboardingIntroProofStepView()
    }
    .formaThemePreview()
}
#endif
