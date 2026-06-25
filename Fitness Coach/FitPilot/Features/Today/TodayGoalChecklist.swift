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

            VStack(alignment: .leading, spacing: 10) {
                ForEach(goals) { goal in
                    Button {
                        onGoalTap(goal.kind)
                    } label: {
                        checklistRow(goal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func checklistRow(_ goal: TodayGoalItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: goal.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(goal.isComplete ? Color.green : Color.secondary.opacity(0.45))

            Text(goal.label)
                .font(.subheadline)
                .foregroundStyle(goal.isComplete ? .secondary : .primary)

            Spacer(minLength: 0)

            if !goal.isComplete {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    TodayGoalChecklist(
        goals: TodayGoalsBuilder.goals(from: TodayPreviewData.state),
        onGoalTap: { _ in }
    )
    .padding()
}
