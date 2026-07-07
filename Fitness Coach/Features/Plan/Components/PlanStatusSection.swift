//
//  PlanStatusSection.swift
//  Fitness Coach
//
//  Forma — Plan Status card describing the active strategy type.
//

import SwiftUI

struct PlanStatusSection: View {
    let state: PlanStatusState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.headerToCardSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    Text(state.statusName)
                        .font(FormaTokens.Typography.sectionTitle.weight(.bold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    Text(state.explanation)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                        labeledBlock(
                            label: state.bestForLabel,
                            value: state.bestForValue
                        )
                        labeledBlock(
                            label: state.watchForLabel,
                            value: state.watchForValue
                        )
                    }
                    .padding(.top, FormaTokens.Spacing.xs)
                    .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilitySummary)
        }
    }

    private func labeledBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .textCase(.uppercase)

            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Aggressive cut") {
    PlanStatusSection(state: PlanMissionControlFixtures.loseDashboard.status)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Needs review") {
    PlanStatusSection(state: PlanMissionControlFixtures.incompleteDataDashboard.status)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
