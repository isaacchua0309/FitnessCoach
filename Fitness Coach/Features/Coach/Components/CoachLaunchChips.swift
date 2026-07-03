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
            horizontalSpacing: CoachDesignTokens.Spacing.xs,
            verticalSpacing: CoachDesignTokens.Spacing.xs
        ) {
            ForEach(chips) { chip in
                Button {
                    CoachHaptics.toolbarTap()
                    onTap(chip)
                } label: {
                    HStack(spacing: CoachDesignTokens.Spacing.xs) {
                        Image(systemName: chip.symbolName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CoachDesignTokens.Color.primary)

                        Text(chip.label)
                            .font(CoachDesignTokens.Typography.chip)
                            .foregroundStyle(CoachDesignTokens.Color.primaryText)
                    }
                    .padding(.horizontal, CoachDesignTokens.Spacing.sm + 2)
                    .frame(minHeight: CoachDesignTokens.Layout.chipMinTouch)
                    .background(CoachDesignTokens.Color.chipFill, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(CoachDesignTokens.Color.chipStroke, lineWidth: 0.5)
                    )
                }
                .buttonStyle(CoachLaunchChipButtonStyle())
                .disabled(isDisabled)
                .accessibilityLabel(chip.label)
                .accessibilityHint(chip.accessibilityHint)
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

private struct CoachLaunchChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(CoachDesignTokens.Motion.quick, value: configuration.isPressed)
    }
}
