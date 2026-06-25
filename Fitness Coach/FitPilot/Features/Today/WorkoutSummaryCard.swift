//
//  WorkoutSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Today workout summary card.
//

import SwiftUI

struct WorkoutSummaryCard: View {
    let summary: TodayWorkoutSummary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: summary.hasWorkout ? "figure.strengthtraining.traditional" : "figure.walk")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(.green.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Workout")
                    .font(.headline)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if summary.workoutCaloriesBurned > 0 {
                Text("\(summary.workoutCaloriesBurned) kcal")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private var statusText: String {
        if summary.hasWorkout {
            return "\(summary.workoutCount) workout\(summary.workoutCount == 1 ? "" : "s") logged"
        }
        return "No workout logged yet"
    }
}

#Preview {
    WorkoutSummaryCard(summary: TodayPreviewData.state.workoutSummary)
        .padding()
}
