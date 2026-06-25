//
//  TrainingRecentWorkoutsSection.swift
//  Fitness Coach
//
//  FitPilot AI — Chronological recent workout list (read-only).
//

import SwiftUI

struct TrainingRecentWorkoutsSection: View {
    let workouts: [WorkoutDisplayItem]
    let onSelect: (WorkoutDisplayItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            TrainingSectionLabel(title: "Recent workouts")

            if workouts.isEmpty {
                Text("No workouts yet. Tell Coach what you trained.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(workouts) { workout in
                        Button {
                            onSelect(workout)
                        } label: {
                            recentRow(workout)
                        }
                        .buttonStyle(.plain)

                        if workout.id != workouts.last?.id {
                            Divider()
                                .padding(.leading, 4)
                        }
                    }
                }
            }
        }
    }

    private func recentRow(_ workout: WorkoutDisplayItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(workout.dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let duration = workout.durationText {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let calories = workout.estimatedCaloriesText {
                    Text(calories)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    TrainingRecentWorkoutsSection(
        workouts: TrainingPreviewData.state.recentWorkouts,
        onSelect: { _ in }
    )
    .padding()
}
