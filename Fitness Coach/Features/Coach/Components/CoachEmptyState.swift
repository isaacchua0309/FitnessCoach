//
//  CoachEmptyState.swift
//  Fitness Coach
//
//  FitPilot AI — Empty conversation with today context and quick actions.
//

import SwiftUI

struct CoachEmptyState: View {
    let todayContext: CoachTodayContextState?
    let launchPresentation: CoachLaunchPresentation?
    let starterPrompts: [CoachStarterPromptSpec]
    let isDisabled: Bool
    let onLaunchChipTap: ((CoachLaunchChip) -> Void)?
    let onStarterTap: (CoachStarterPromptSpec) -> Void

    init(
        todayContext: CoachTodayContextState?,
        launchPresentation: CoachLaunchPresentation? = nil,
        starterPrompts: [CoachStarterPromptSpec] = CoachStarterPrompt.defaultQuickActionSpecs,
        isDisabled: Bool,
        onLaunchChipTap: ((CoachLaunchChip) -> Void)? = nil,
        onStarterTap: @escaping (CoachStarterPromptSpec) -> Void
    ) {
        self.todayContext = todayContext
        self.launchPresentation = launchPresentation
        self.starterPrompts = starterPrompts
        self.isDisabled = isDisabled
        self.onLaunchChipTap = onLaunchChipTap
        self.onStarterTap = onStarterTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.md) {
            if let launchPresentation {
                launchStarterBlock(launchPresentation)
            } else {
                Text(FormaProductCopy.EmptyState.CoachConversation.body)
                    .font(CoachDesignTokens.Typography.subtitle)
                    .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let todayContext {
                CoachTodayContextCard(state: todayContext)
            }

            if let launchPresentation, let onLaunchChipTap {
                launchChipsSection(launchPresentation.chips, onTap: onLaunchChipTap)
            } else {
                defaultQuickActionsSection
            }
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .padding(.top, CoachDesignTokens.Spacing.sm)
        .padding(.bottom, CoachDesignTokens.Spacing.md)
        .accessibilityElement(children: .contain)
    }

    private func launchStarterBlock(_ presentation: CoachLaunchPresentation) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            Text(presentation.headline)
                .font(CoachDesignTokens.Typography.largeTitle)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.body)
                .font(CoachDesignTokens.Typography.subtitle)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func launchChipsSection(
        _ chips: [CoachLaunchChip],
        onTap: @escaping (CoachLaunchChip) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            Text(FormaProductCopy.Coach.Launch.chipSectionTitle)
                .font(CoachDesignTokens.Typography.hintLabel)
                .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.4)
                .accessibilityAddTraits(.isHeader)

            CoachLaunchChips(chips: chips, isDisabled: isDisabled, onTap: onTap)
        }
    }

    private var defaultQuickActionsSection: some View {
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
}

#Preview {
    ScrollView {
        CoachEmptyState(
            todayContext: CoachTodayContextState(
                caloriesLine: "0 eaten · 2,249 target",
                proteinLine: "Protein 0 / 180 g",
                waterLine: "Water 0 / 3150 ml",
                activityLines: [],
                activityHintLine: nil,
                suggestedFocus: FormaProductCopy.Today.focusProteinLow
            ),
            launchPresentation: CoachLaunchPresentationBuilder.presentation(for: .logMeal(mealType: nil)),
            isDisabled: false,
            onLaunchChipTap: { _ in }
        ) { _ in }
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
