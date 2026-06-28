//
//  OnboardingSavePlanErrorSlot.swift
//  Fitness Coach
//
//  Forma — Reserved error slot so protect-progress CTA does not jump.
//

import SwiftUI

struct OnboardingSavePlanErrorSlot: View {
    let showsError: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .frame(height: OnboardingLayout.savePlanErrorSlotHeight)
                .accessibilityHidden(true)

            if showsError {
                OnboardingProtectProgressSignInReassurance()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(!showsError)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: showsError)
    }
}

#if DEBUG
#Preview("Hidden") {
    OnboardingSavePlanErrorSlot(showsError: false)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Visible") {
    OnboardingSavePlanErrorSlot(showsError: true)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
