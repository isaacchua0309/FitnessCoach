//
//  PlanConfidenceSection.swift
//  Fitness Coach
//
//  Forma — Plan confidence card with compressed Apple Health status.
//

import SwiftUI

struct PlanConfidenceSection: View {
    let state: PlanConfidenceState
    var onAppleHealthTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
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

                    if state.showsAppleHealthStatus, let appleHealthStatusLabel = state.appleHealthStatusLabel {
                        appleHealthBlock(statusLabel: appleHealthStatusLabel)
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
                reasonRow(symbol: "✓", text: item.text, symbolColor: FormaTokens.Theme.primary)
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

    @ViewBuilder
    private func appleHealthBlock(statusLabel: String) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            FormaPlanDisplayRow(
                label: FormaProductCopy.PlanMissionControl.planAssumptionsAppleHealth,
                value: statusLabel
            )
            .accessibilityHidden(true)

            if state.showsAppleHealthAction,
               let actionTitle = state.appleHealthActionTitle,
               let onAppleHealthTap {
                Button(action: onAppleHealthTap) {
                    Text(actionTitle)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionTitle)
                .accessibilityHint(FormaProductCopy.PlanMissionControl.connectAppleHealthAccessibilityHint)
            }
        }
        .padding(.top, FormaTokens.Spacing.xs)
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
