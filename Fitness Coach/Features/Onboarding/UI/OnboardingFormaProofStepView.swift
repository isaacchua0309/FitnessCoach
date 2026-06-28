//
//  OnboardingFormaProofStepView.swift
//  Fitness Coach
//
//  Forma — illustrative weight-loss comparison before plan review.
//

import SwiftUI

struct OnboardingFormaProofStepView: View {

    var body: some View {
        OnboardingFormaProofComparisonCard(model: .default)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Forma Proof") {
    OnboardingFormaProofStepView()
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
#endif
