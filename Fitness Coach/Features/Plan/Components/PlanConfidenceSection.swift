//
//  PlanConfidenceSection.swift
//  Fitness Coach
//
//  Forma — Compact Plan Confidence with actionable next steps.
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
                    Text(state.scoreHeadline)
                        .font(FormaTokens.Typography.sectionTitle.weight(.bold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    if !state.improvementActions.isEmpty {
                        improvementActionsBlock
                    }

                    compactSignalsBlock

                    if state.showsAppleHealthAction,
                       let actionTitle = state.appleHealthActionTitle,
                       let onAppleHealthTap {
                        appleHealthActionButton(title: actionTitle, action: onAppleHealthTap)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var improvementActionsBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(state.improveAccuracyHeading)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .padding(.top, FormaTokens.Spacing.xs)
                .accessibilityHidden(true)

            ForEach(state.improvementActions) { action in
                actionRow(action.text)
            }
        }
    }

    private var compactSignalsBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(state.compactSignalsHeading)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .padding(.top, state.improvementActions.isEmpty ? FormaTokens.Spacing.xs : 0)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(state.compactSignals.enumerated()), id: \.element.id) { index, signal in
                    if index > 0 {
                        FormaPlanRowDivider()
                    }
                    FormaPlanDisplayRow(label: signal.label, value: signal.value)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func actionRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
            Text("•")
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .frame(width: 14, alignment: .leading)

            Text(text)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityHidden(true)
    }

    private func appleHealthActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .padding(.top, FormaTokens.Spacing.xs)
        .accessibilityLabel(title)
        .accessibilityHint(FormaProductCopy.PlanMissionControl.connectAppleHealthAccessibilityHint)
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
