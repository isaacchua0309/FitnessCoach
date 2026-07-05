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
            horizontalSpacing: FormaTokens.Spacing.xs,
            verticalSpacing: FormaTokens.Spacing.xs
        ) {
            ForEach(prompts) { prompt in
                FormaQuickActionChip(
                    title: prompt.label,
                    action: {
                        CoachHaptics.toolbarTap()
                        onTap(prompt)
                    },
                    systemImage: prompt.symbolName,
                    accessibilityHint: prompt.accessibilityHint
                )
                .disabled(isDisabled)
            }
        }
    }
}

#Preview {
    CoachStarterChips(isDisabled: false) { _ in }
        .padding()
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview()
}
