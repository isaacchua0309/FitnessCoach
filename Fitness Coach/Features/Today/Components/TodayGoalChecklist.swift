//
//  TodayGoalChecklist.swift
//  Fitness Coach
//
//  Forma — Legacy goal checklist. Retained for previews and TodayGoalsBuilder tests.
//

import SwiftUI

struct TodayGoalChecklist: View {
    let goals: [TodayGoalItem]
    let onGoalTap: (TodayGoalItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.nextActionsSectionTitle)

            TodayActionCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        goalRow(goal)

                        if index < goals.count - 1 {
                            FormaPlanRowDivider()
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func goalRow(_ goal: TodayGoalItem) -> some View {
        if goal.showsChevron {
            Button {
                onGoalTap(goal)
            } label: {
                FormaActionRow(title: goal.label, style: .navigation) {
                    rowLeadingIcon(goal)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(for: goal))
            .accessibilityHint(accessibilityHint(for: goal))
            .accessibilityAddTraits(.isButton)
        } else if goal.showsQuickActionButton {
            quickActionRow(goal)
        } else {
            staticRowContent(goal)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: goal))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func quickActionRow(_ goal: TodayGoalItem) -> some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            rowLeadingIcon(goal)

            Text(goal.label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            FormaQuickActionChip(
                title: FormaProductCopy.Today.nextActionQuickChipTitle,
                action: { onGoalTap(goal) },
                accessibilityHint: accessibilityHint(for: goal)
            )
            .accessibilityLabel(
                "\(FormaProductCopy.Today.nextActionQuickChipTitle), \(goal.label)"
            )
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }

    private func staticRowContent(_ goal: TodayGoalItem) -> some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            rowLeadingIcon(goal)

            Text(goal.label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func rowLeadingIcon(_ goal: TodayGoalItem) -> some View {
        Image(systemName: rowIconName(for: goal))
            .font(FormaTokens.Typography.body)
            .foregroundStyle(rowIconColor(for: goal))
            .frame(width: TodayLayout.actionIconColumnWidth, alignment: .center)
    }

    private func rowIconName(for goal: TodayGoalItem) -> String {
        if goal.isComplete && !goal.isInformational {
            return "checkmark.circle"
        }
        return "circle"
    }

    private func rowIconColor(for goal: TodayGoalItem) -> Color {
        if goal.isComplete && !goal.isInformational {
            return FormaTokens.Color.textSecondary
        }
        return FormaTokens.Color.textTertiary
    }

    private func accessibilityLabel(for goal: TodayGoalItem) -> String {
        if goal.isInformational {
            return "\(goal.label), informational"
        }
        if goal.isComplete {
            return "\(goal.label), completed"
        }
        return goal.label
    }

    private func accessibilityHint(for goal: TodayGoalItem) -> String {
        switch goal.tapAction {
        case .coach:
            return FormaProductCopy.Today.nextActionCoachHint
        case .openTrainingInsights:
            return FormaProductCopy.Today.nextActionTrainingInsightsHint
        case nil:
            return ""
        }
    }
}

#Preview("Mixed states") {
    let incomplete = TodayGoalsBuilder.goals(
        from: TodayPreviewData.state,
        trainingIntegration: .notConnected,
        trainingDataSource: .appleHealth
    )
    TodayGoalChecklist(goals: incomplete, onGoalTap: { _ in })
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Completed states") {
    TodayGoalChecklist(
        goals: TodayGoalsBuilder.goals(from: TodayPreviewData.state),
        onGoalTap: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
