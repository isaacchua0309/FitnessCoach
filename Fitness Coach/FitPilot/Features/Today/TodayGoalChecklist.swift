//
//  TodayGoalChecklist.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only daily goal status. Taps route to Coach.
//

import SwiftUI

struct TodayGoalChecklist: View {
    let goals: [TodayGoalItem]
    let onGoalTap: (TodayGoalItem.Kind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.itemSpacing) {
            TodaySectionLabel(title: "Daily checklist")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        Button {
                            onGoalTap(goal.kind)
                        } label: {
                            checklistRow(goal)
                        }
                        .buttonStyle(.plain)

                        if index < goals.count - 1 {
                            FitPilotPlanRowDivider()
                        }
                    }
                }
            }
        }
    }

    private func checklistRow(_ goal: TodayGoalItem) -> some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Image(systemName: goal.isComplete ? "checkmark.circle.fill" : "circle")
                .font(FormaTokens.Typography.body)
                .foregroundStyle(goal.isComplete ? FormaTokens.Color.success : FormaTokens.Color.textTertiary)

            Text(goal.label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(goal.isComplete ? FormaTokens.Color.textSecondary : FormaTokens.Color.textPrimary)

            Spacer(minLength: 0)

            if !goal.isComplete {
                Image(systemName: "chevron.right")
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .center)
        .contentShape(Rectangle())
        .accessibilityLabel(goal.label + (goal.isComplete ? ", completed" : ", tap to log with Coach"))
    }
}

#Preview {
    TodayGoalChecklist(
        goals: TodayGoalsBuilder.goals(from: TodayPreviewData.state),
        onGoalTap: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
