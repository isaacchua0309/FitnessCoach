//
//  CoachEmptyState.swift
//  Fitness Coach
//
//  FitPilot AI — Empty conversation with today context and quick actions.
//

import SwiftUI

struct CoachEmptyState: View {
    let todayContext: CoachTodayContextState?
    let starterPrompts: [CoachStarterPromptSpec]
    let isDisabled: Bool
    let onStarterTap: (CoachStarterPromptSpec) -> Void

    init(
        todayContext: CoachTodayContextState?,
        starterPrompts: [CoachStarterPromptSpec] = CoachStarterPrompt.defaultQuickActionSpecs,
        isDisabled: Bool,
        onStarterTap: @escaping (CoachStarterPromptSpec) -> Void
    ) {
        self.todayContext = todayContext
        self.starterPrompts = starterPrompts
        self.isDisabled = isDisabled
        self.onStarterTap = onStarterTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.md) {
            Text(FormaProductCopy.EmptyState.CoachConversation.body)
                .font(CoachDesignTokens.Typography.subtitle)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let todayContext {
                CoachTodayContextCard(state: todayContext)
            }

            VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
                Text(FormaProductCopy.Coach.quickActionsSectionTitle)
                    .font(CoachDesignTokens.Typography.hintLabel)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .accessibilityAddTraits(.isHeader)

                CoachStarterChips(
                    prompts: starterPrompts,
                    isDisabled: isDisabled,
                    onTap: onStarterTap
                )
            }
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .padding(.top, CoachDesignTokens.Spacing.sm)
        .padding(.bottom, CoachDesignTokens.Spacing.md)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ScrollView {
        CoachEmptyState(
            todayContext: CoachTodayContextState(
                caloriesLine: "0 eaten · 2,249 target",
                proteinLine: "Protein 0 / 180 g",
                waterLine: "Water 0 / 3150 ml",
                suggestedFocus: FormaProductCopy.Today.focusProteinLow
            ),
            isDisabled: false
        ) { _ in }
    }
    .background(CoachDesignTokens.Color.background)
    .preferredColorScheme(.dark)
}
