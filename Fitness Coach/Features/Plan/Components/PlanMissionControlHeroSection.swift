//
//  PlanMissionControlHeroSection.swift
//  Fitness Coach
//
//  Forma — Strategy hero for the Plan dashboard.
//

import SwiftUI

struct PlanMissionControlHeroSection: View {
    let strategy: PlanStrategyState
    var explanation: PlanExplanationState? = nil
    var onCalculationDetailsOpened: (() -> Void)? = nil

    @State private var showsCalculationDetailsSheet = false

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

                    if let explanation, explanation.showsCalculationAction {
                        calculationDetailsButton(title: explanation.seeCalculationTitle)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(strategy.accessibilitySummary)
        }
        .sheet(isPresented: $showsCalculationDetailsSheet) {
            if let details = explanation?.calculationDetails {
                PlanCalculationDetailsSheet(details: details)
            }
        }
    }

    private var keyValuesBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let expectedPaceLabel = strategy.expectedPaceLabel,
               let expectedPaceValue = strategy.expectedPaceValue {
                FormaPlanDisplayRow(
                    label: expectedPaceLabel,
                    value: expectedPaceValue
                )
                .accessibilityHidden(true)

                FormaPlanRowDivider()
            }

            FormaPlanDisplayRow(
                label: strategy.strategyStatusLabel,
                value: strategy.strategyStatusValue
            )
            .accessibilityHidden(true)
        }
        .padding(.top, FormaTokens.Spacing.xs)
    }

    private func calculationDetailsButton(title: String) -> some View {
        Button {
            onCalculationDetailsOpened?()
            showsCalculationDetailsSheet = true
        } label: {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .padding(.top, FormaTokens.Spacing.xs)
        .accessibilityLabel(title)
        .accessibilityHint(FormaProductCopy.PlanMissionControl.seeCalculationAccessibilityHint)
    }
}

// MARK: - Previews

#Preview("Lose weight") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.loseDashboard.strategy,
        explanation: PlanMissionControlFixtures.loseDashboard.explanation
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.loseDashboard.strategy,
        explanation: PlanMissionControlFixtures.loseDashboard.explanation
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility2)
}
