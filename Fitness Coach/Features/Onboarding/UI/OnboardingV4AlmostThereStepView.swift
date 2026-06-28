//
//  OnboardingV4AlmostThereStepView.swift
//  Fitness Coach
//
//  Forma — V4 feature discovery screen before forma proof.
//

import SwiftUI

struct OnboardingV4AlmostThereStepView: View {

    var body: some View {
        OnboardingV4FeatureBulletList(bullets: OnboardingV4FeatureBullet.almostThereDefaults)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("V4 Almost There") {
    OnboardingV4AlmostThereStepView()
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
#endif
