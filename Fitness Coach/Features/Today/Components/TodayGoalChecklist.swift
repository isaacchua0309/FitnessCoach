//
//  TodayGoalChecklist.swift
//  Fitness Coach
//
//  Forma — State-aware next actions. Chevron = row has a destination.
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
                            FitPilotPlanRowDivider()
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
                checklistRowContent(goal)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(for: goal))
            .accessibilityHint(accessibilityHint(for: goal))
            .accessibilityAddTraits(.isButton)
        } else {
            checklistRowContent(goal)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: goal))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func checklistRowContent(_ goal: TodayGoalItem) -> some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: rowIconName(for: goal))
                .font(FormaTokens.Typography.body)
                .foregroundStyle(rowIconColor(for: goal))
                .frame(width: TodayLayout.actionIconColumnWidth, alignment: .center)

            Text(goal.label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(goal.showsChevron ? FormaTokens.Color.textPrimary : FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if goal.showsChevron {
                Image(systemName: "chevron.right")
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .center)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func rowIconName(for goal: TodayGoalItem) -> String {
        if goal.showsChevron || goal.isInformational {
            return "circle"
        }
        return "checkmark.circle"
    }

    private func rowIconColor(for goal: TodayGoalItem) -> Color {
        if goal.showsChevron || goal.isInformational {
            return FormaTokens.Color.textTertiary
        }
        return FormaTokens.Color.textSecondary
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
        trainingDataSource: .unavailable
    )
    TodayGoalChecklist(goals: incomplete, onGoalTap: { _ in })
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Completed states") {
    TodayGoalChecklist(
        goals: TodayGoalsBuilder.goals(from: TodayPreviewData.state),
        onGoalTap: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
