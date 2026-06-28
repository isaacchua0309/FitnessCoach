//
//  OnboardingPlanRevealFooterReserve.swift
//  Fitness Coach
//
//  Forma — Keeps plan-reveal footer space during generation to avoid layout snap.
//

import SwiftUI

struct OnboardingPlanRevealFooterReserve: View {
    var body: some View {
        Color.clear
            .frame(height: OnboardingLayout.planRevealFooterReservedHeight)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    OnboardingPlanRevealFooterReserve()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
