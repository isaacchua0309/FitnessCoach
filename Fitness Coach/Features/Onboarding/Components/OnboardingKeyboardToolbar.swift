//
//  OnboardingKeyboardToolbar.swift
//  Fitness Coach
//
//  FitPilot AI — Styled keyboard accessory for onboarding numeric fields.
//

import SwiftUI

struct OnboardingKeyboardToolbar: ToolbarContent {
    @ObservedObject var navigator: OnboardingFieldNavigator

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            if navigator.canFocusPrevious {
                Button {
                    navigator.focusPrevious()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .accessibilityLabel("Previous field")
            }

            Spacer()

            if navigator.canFocusNext {
                Button("Next") {
                    navigator.focusNext()
                }
                .font(.body.weight(.semibold))
            } else {
                Button("Done") {
                    navigator.dismissFocus()
                }
                .font(.body.weight(.semibold))
            }
        }
    }
}
