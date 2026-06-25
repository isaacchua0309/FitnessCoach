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

            VStack(spacing: 0) {
                summaryRow("Workouts", value: "\(weekly.workoutsCompleted)")
                Divider().padding(.leading, 4)
                summaryRow("Calories burned", value: "\(weekly.totalCalories) kcal")
                Divider().padding(.leading, 4)
                summaryRow("Duration", value: TrainingFormatter.totalDuration(weekly.totalDurationMinutes))
                Divider().padding(.leading, 4)
                summaryRow("Training streak", value: "\(weekly.trainingStreak) days")
            }
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    TrainingWeeklySummarySection(weekly: TrainingPreviewData.state.weekly)
        .padding()
}
