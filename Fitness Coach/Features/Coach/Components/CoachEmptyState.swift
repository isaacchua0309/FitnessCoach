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
        VStack(alignment: .leading, spacing: FormaMainTabLayout.sectionSpacing) {
            if let launchPresentation {
                launchStarterBlock(launchPresentation)
            }

            if let todayContext {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    SectionLabel(title: FormaProductCopy.Coach.todaySoFarSectionTitle)
                    CoachTodayContextCard(state: todayContext)
                }
            }

            if let launchPresentation, let onLaunchChipTap {
                launchChipsSection(launchPresentation.chips, onTap: onLaunchChipTap)
            } else {
                defaultQuickActionsSection
            }
        }
        .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
        .padding(.bottom, FormaMainTabLayout.scrollContentBottomPadding)
        .accessibilityElement(children: .contain)
    }

    private func launchStarterBlock(_ presentation: CoachLaunchPresentation) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            Text(presentation.headline)
                .font(CoachDesignTokens.Typography.confirmationTitle)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !presentation.body.isEmpty {
                Text(presentation.body)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func launchChipsSection(
        _ chips: [CoachLaunchChip],
        onTap: @escaping (CoachLaunchChip) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            SectionLabel(title: FormaProductCopy.Coach.Launch.chipSectionTitle)

            CoachLaunchChips(chips: chips, isDisabled: isDisabled, onTap: onTap)
        }
    }

    private var defaultQuickActionsSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            SectionLabel(title: FormaProductCopy.Coach.quickActionsSectionTitle)

            CoachStarterChips(
                prompts: starterPrompts,
                isDisabled: isDisabled,
                onTap: onStarterTap
            )
        }
    }
}

#Preview {
    MainTabPageScaffold(
        title: FormaProductCopy.Coach.screenTitle,
        subtitle: FormaProductCopy.Coach.headerSubtitle,
        scrollMode: .embedded
    ) {
        ScrollView {
            CoachEmptyState(
                todayContext: CoachTodayContextState(
                    caloriesLine: "0 eaten · 2,249 target",
                    proteinLine: "Protein 0 / 180 g",
                    waterLine: "Water 0 / 3150 ml",
                    activityLines: ["0 steps"],
                    activityHintLine: nil,
                    suggestedFocus: FormaProductCopy.Today.focusProteinLow
                ),
                isDisabled: false
            ) { _ in }
        }
    }
    .formaThemePreview()
}
