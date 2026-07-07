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
        LazyVGrid(
            columns: MainTabResponsiveLayout.quickActionGridColumns(),
            alignment: .leading,
            spacing: FormaTokens.Spacing.xs
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
                .frame(maxWidth: .infinity, alignment: .leading)
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
