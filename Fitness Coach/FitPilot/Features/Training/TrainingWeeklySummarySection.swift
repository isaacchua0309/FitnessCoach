//
//  TrainingWeeklySummarySection.swift
//  Fitness Coach
//
//  FitPilot AI — Weekly training summary (read-only).
//

import SwiftUI

struct TrainingWeeklySummarySection: View {
    let weekly: TrainingWeeklySummary

    var body: some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            TrainingSectionLabel(title: "This week")

            FitPilotPlanCard {
                VStack(spacing: 0) {
                    summaryRow("Workouts", value: "\(weekly.workoutsCompleted)")
                    FitPilotPlanRowDivider()
                    summaryRow("Calories burned", value: "\(weekly.totalCalories) kcal")
                    FitPilotPlanRowDivider()
                    summaryRow("Duration", value: TrainingFormatter.totalDuration(weekly.totalDurationMinutes))
                    FitPilotPlanRowDivider()
                    summaryRow("Training streak", value: "\(weekly.trainingStreak) days")
                }
            }
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
            Spacer()
            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .padding(.vertical, FormaTokens.Spacing.xs + 2)
    }
}

#Preview {
    TrainingWeeklySummarySection(weekly: TrainingPreviewData.state.weekly)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
