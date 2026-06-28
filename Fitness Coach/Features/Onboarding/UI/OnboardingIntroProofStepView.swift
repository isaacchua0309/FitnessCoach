//
//  OnboardingIntroProofStepView.swift
//  Fitness Coach
//
//  Forma — intro proof entry with trajectory comparison card.
//

import SwiftUI

struct OnboardingIntroProofStepView: View {
    let onNext: () -> Void

    private let copy = FormaProductCopy.Onboarding.Flow.IntroProof.self

    var body: some View {
        OnboardingPageShell(
            title: copy.title,
            subtitle: copy.subtitle,
            showsProgressHeader: false,
            showsBackButton: false,
            primaryTitle: copy.continueCTA,
            onPrimary: onNext
        ) {
            OnboardingWeightTrajectoryComparisonProofCard(
                model: .introProofDefault
            )
        }
    }
}

#if DEBUG
#Preview("Intro Proof") {
    OnboardingIntroProofStepView(onNext: {})
}
#endif
