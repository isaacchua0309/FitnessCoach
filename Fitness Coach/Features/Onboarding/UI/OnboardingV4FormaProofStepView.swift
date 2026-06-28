//
//  OnboardingV4FormaProofStepView.swift
//  Fitness Coach
//
//  Forma — V4 illustrative weight-loss comparison before plan review.
//

import SwiftUI

struct OnboardingV4FormaProofStepView: View {

    var body: some View {
        OnboardingV4FormaProofComparisonCard(model: .default)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("V4 Forma Proof") {
    OnboardingV4FormaProofStepView()
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
#endif
