//
//  PlanConfidenceSection.swift
//  Fitness Coach
//
//  Forma — Plan confidence card on the Plan dashboard.
//

import SwiftUI

struct PlanConfidenceSection: View {
    let state: PlanConfidenceState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(state.scoreLabel)
                        .font(FormaTokens.Typography.sectionTitle.weight(.bold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    if !state.whyItems.isEmpty {
                        whyBlock
                    }

                    if !state.missingItems.isEmpty {
                        missingBlock
                    }

                    Text(state.footerCopy)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, FormaTokens.Spacing.xs)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var whyBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(state.whyHeading)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .accessibilityHidden(true)

            ForEach(state.whyItems) { item in
                reasonRow(symbol: "✓", text: item.text, symbolColor: FormaTokens.Color.accent)
            }
        }
    }

    private var missingBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(state.missingHeading)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .padding(.top, state.whyItems.isEmpty ? 0 : FormaTokens.Spacing.xs)
                .accessibilityHidden(true)

            ForEach(state.missingItems) { item in
                reasonRow(symbol: "–", text: item.text, symbolColor: FormaTokens.Color.textTertiary)
            }
        }
    }

    private func reasonRow(symbol: String, text: String, symbolColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
            Text(symbol)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(symbolColor)
                .frame(width: 14, alignment: .leading)

            Text(text)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("New user") {
    PlanConfidenceSection(state: PlanMissionControlFixtures.newUserDashboard.confidence)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Strong history") {
    PlanConfidenceSection(state: PlanMissionControlFixtures.activeUserDashboard.confidence)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
