//
//  CoachLaunchChips.swift
//  Fitness Coach
//
//  Forma — Intent-specific starter chips for a one-shot Coach launch session.
//

import SwiftUI

struct CoachLaunchChips: View {
    let chips: [CoachLaunchChip]
    let isDisabled: Bool
    let onTap: (CoachLaunchChip) -> Void

    var body: some View {
        CoachFlowLayout(
            horizontalSpacing: FormaTokens.Spacing.xs,
            verticalSpacing: FormaTokens.Spacing.xs
        ) {
            ForEach(chips) { chip in
                FormaQuickActionChip(
                    title: chip.label,
                    action: {
                        CoachHaptics.toolbarTap()
                        onTap(chip)
                    },
                    systemImage: chip.symbolName,
                    accessibilityHint: chip.accessibilityHint
                )
                .disabled(isDisabled)
            }
        }
    }
}

#Preview {
    CoachLaunchChips(
        chips: [.takePhoto, .describeMeal, .useVoice],
        isDisabled: false
    ) { _ in }
    .padding()
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
