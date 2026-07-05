//
//  PlanMissionControlHeroSection.swift
//  Fitness Coach
//
//  Forma — Strategy hero for the Plan dashboard.
//

import SwiftUI

struct PlanMissionControlHeroSection: View {
    let strategy: PlanStrategyState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.headerToCardSpacing) {
            FormaSectionLabel(title: strategy.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    MainTabHeroText(strategy.primaryGoal, tier: .goal)
                        .accessibilityHidden(true)

                    keyValuesBlock

                    Text(strategy.supportiveLine)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, FormaTokens.Spacing.xs)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(strategy.accessibilitySummary)
        }
    }

    private var keyValuesBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            FormaPlanDisplayRow(
                label: strategy.dailyTargetLabel,
                value: strategy.dailyTargetValue
            )
            .accessibilityHidden(true)

            if let expectedPaceLabel = strategy.expectedPaceLabel,
               let expectedPaceValue = strategy.expectedPaceValue {
                FormaPlanRowDivider()

                FormaPlanDisplayRow(
                    label: expectedPaceLabel,
                    value: expectedPaceValue
                )
                .accessibilityHidden(true)
            }

            FormaPlanRowDivider()

            FormaPlanDisplayRow(
                label: strategy.strategyStatusLabel,
                value: strategy.strategyStatusValue
            )
            .accessibilityHidden(true)
        }
        .padding(.top, FormaTokens.Spacing.xs)
    }
}

// MARK: - Previews

#Preview("Lose weight") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.loseDashboard.strategy
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.loseDashboard.strategy
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility3)
}

#Preview("Active user") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.activeUserDashboard.strategy
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Maintain") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.maintainDashboard.strategy
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Muscle gain") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.gainDashboard.strategy
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
