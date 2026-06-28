//
//  OnboardingAlmostThereStepView.swift
//  Fitness Coach
//
//  Forma — feature discovery screen before forma proof.
//

import SwiftUI

struct OnboardingAlmostThereStepView: View {

    var body: some View {
        OnboardingFeatureBulletList(bullets: OnboardingFeatureBullet.almostThereDefaults)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("almost there") {
    OnboardingAlmostThereStepView()
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
#endif
