//
//  CoachStarterChips.swift
//  Fitness Coach
//
//  FitPilot AI — Wrapping starter chips for the empty Coach conversation.
//

import SwiftUI

struct CoachStarterChips: View {
    let prompts: [CoachStarterPromptSpec]
    let isDisabled: Bool
    let onTap: (CoachStarterPromptSpec) -> Void

    init(
        prompts: [CoachStarterPromptSpec] = CoachStarterPrompt.defaultQuickActionSpecs,
        isDisabled: Bool = false,
        onTap: @escaping (CoachStarterPromptSpec) -> Void
    ) {
        self.prompts = prompts
        self.isDisabled = isDisabled
        self.onTap = onTap
    }

    var body: some View {
        CoachFlowLayout(
            horizontalSpacing: CoachDesignTokens.Spacing.xs,
            verticalSpacing: CoachDesignTokens.Spacing.xs
        ) {
            ForEach(prompts) { prompt in
                Button {
                    CoachHaptics.toolbarTap()
                    onTap(prompt)
                } label: {
                    HStack(spacing: CoachDesignTokens.Spacing.xs) {
                        Image(systemName: prompt.symbolName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CoachDesignTokens.Color.accent)

                        Text(prompt.label)
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
                .buttonStyle(CoachStarterChipButtonStyle())
                .disabled(isDisabled)
                .accessibilityLabel(prompt.label)
                .accessibilityHint(prompt.accessibilityHint)
            }
        }
    }
}

private struct CoachStarterChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(CoachDesignTokens.Motion.quick, value: configuration.isPressed)
    }
}

#Preview {
    CoachStarterChips(isDisabled: false) { _ in }
        .padding()
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview()
}
