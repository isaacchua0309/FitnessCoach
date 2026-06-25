//
//  WorkoutListView.swift
//  Fitness Coach
//
//  FitPilot AI — Reusable workout list section.
//

import SwiftUI

struct WorkoutListView: View {
    let title: String
    let workouts: [WorkoutDisplayItem]
    let emptyMessage: String
    let onSelect: (WorkoutDisplayItem) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if workouts.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(workouts) { workout in
                        WorkoutRowView(
                            workout: workout,
                            onSelect: { onSelect(workout) },
                            onDelete: { onDelete(workout.id) }
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    WorkoutListView(
        title: "Today",
        workouts: [TrainingPreviewData.item],
        emptyMessage: "No workouts today.",
        onSelect: { _ in },
        onDelete: { _ in }
    )
    .padding()
}
