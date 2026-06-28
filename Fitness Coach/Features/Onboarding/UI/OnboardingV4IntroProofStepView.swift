//
//  OnboardingV4IntroProofStepView.swift
//  Fitness Coach
//
//  Forma — V4 intro proof entry with trajectory comparison card.
//

import SwiftUI

struct OnboardingV4IntroProofStepView: View {
    let onNext: () -> Void

    private let copy = FormaProductCopy.Onboarding.V4.IntroProof.self

    var body: some View {
        OnboardingV4PageShell(
            title: copy.title,
            subtitle: copy.subtitle,
            showsProgressHeader: false,
            showsBackButton: false,
            primaryTitle: copy.continueCTA,
            onPrimary: onNext
        ) {
            OnboardingV4WeightTrajectoryComparisonProofCard(
                model: .introProofDefault
            )
        }
    }
}

#if DEBUG
#Preview("V4 Intro Proof") {
    OnboardingV4IntroProofStepView(onNext: {})
}
#endif
